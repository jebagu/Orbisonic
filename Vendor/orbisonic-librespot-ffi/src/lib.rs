use data_encoding::HEXLOWER;
use futures_util::StreamExt;
use librespot::{
    connect::{ConnectConfig, Spirc},
    core::{Session, SessionConfig, cache::Cache, config::DeviceType},
    discovery::Discovery,
    metadata::audio::UniqueFields,
    playback::{
        audio_backend,
        config::{AudioFormat, Bitrate, PlayerConfig},
        mixer::{self, MixerConfig},
        player::{Player, PlayerEvent, PlayerEventChannel},
    },
};
use sha1::{Digest, Sha1};
use std::{
    ffi::{CStr, c_char},
    fs,
    path::PathBuf,
    sync::{Mutex, OnceLock},
    thread,
    time::Duration,
};
use tokio::sync::{mpsc, oneshot};

const ORBISONIC_LIBRESPOT_OK: i32 = 0;
const ORBISONIC_LIBRESPOT_INVALID_CONFIG: i32 = -1;
const ORBISONIC_LIBRESPOT_ALREADY_RUNNING: i32 = 1;
const ORBISONIC_LIBRESPOT_NOT_STARTED: i32 = -2;
const ORBISONIC_LIBRESPOT_START_FAILED: i32 = -3;

#[repr(C)]
pub struct OrbisonicLibrespotConfig {
    pub receiver_name: *const c_char,
    pub loopback_device_name: *const c_char,
    pub loopback_device_uid: *const c_char,
    pub support_dir: *const c_char,
    pub cache_dir: *const c_char,
    pub log_dir: *const c_char,
}

#[derive(Clone)]
struct ReceiverConfig {
    receiver_name: String,
    loopback_device_name: String,
    loopback_device_uid: String,
    support_dir: PathBuf,
    cache_dir: PathBuf,
    log_dir: PathBuf,
}

struct ReceiverHandle {
    shutdown_tx: oneshot::Sender<()>,
    control_tx: mpsc::UnboundedSender<ReceiverCommand>,
    join_handle: thread::JoinHandle<()>,
}

#[derive(Debug)]
enum ReceiverCommand {
    PlayPause,
    Previous,
    Next,
    Seek(u32),
    SetVolume(u16),
}

#[derive(Default)]
struct SpotifyState {
    title: Option<String>,
    album: Option<String>,
    artists: Vec<String>,
    album_artists: Vec<String>,
    uri: Option<String>,
    duration_ms: Option<u32>,
    position_ms: Option<u32>,
    is_playing: bool,
    is_explicit: bool,
    popularity: Option<u8>,
    track_number: Option<u32>,
    disc_number: Option<u32>,
    cover_url: Option<String>,
    volume: Option<u16>,
    shuffle: Option<bool>,
    repeat_context: Option<bool>,
    repeat_track: Option<bool>,
    auto_play: Option<bool>,
    client_name: Option<String>,
    session_active: bool,
}

static RECEIVER: OnceLock<Mutex<Option<ReceiverHandle>>> = OnceLock::new();
static LAST_ERROR: OnceLock<Mutex<i32>> = OnceLock::new();

#[unsafe(no_mangle)]
pub extern "C" fn orbisonic_librespot_abi_version() -> u32 {
    1
}

#[unsafe(no_mangle)]
pub extern "C" fn orbisonic_librespot_linked_version() -> *const c_char {
    b"librespot vendored\0".as_ptr().cast()
}

pub fn orbisonic_librespot_semver_marker() -> &'static str {
    librespot::core::version::SEMVER
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn orbisonic_librespot_start(config: *const OrbisonicLibrespotConfig) -> i32 {
    let Some(config) = parse_config(config) else {
        set_last_error(ORBISONIC_LIBRESPOT_INVALID_CONFIG);
        return ORBISONIC_LIBRESPOT_INVALID_CONFIG;
    };

    let receiver_slot = RECEIVER.get_or_init(|| Mutex::new(None));
    let Ok(mut receiver) = receiver_slot.lock() else {
        set_last_error(ORBISONIC_LIBRESPOT_START_FAILED);
        return ORBISONIC_LIBRESPOT_START_FAILED;
    };

    if receiver.is_some() {
        return ORBISONIC_LIBRESPOT_ALREADY_RUNNING;
    }

    let (shutdown_tx, shutdown_rx) = oneshot::channel();
    let (control_tx, control_rx) = mpsc::unbounded_channel();
    let join_handle = match thread::Builder::new()
        .name("orbisonic-librespot".to_string())
        .spawn(move || {
            let runtime = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build();

            match runtime {
                Ok(runtime) => {
                    if run_result_to_code(runtime.block_on(run_receiver(
                        config,
                        shutdown_rx,
                        control_rx,
                    )))
                        != ORBISONIC_LIBRESPOT_OK
                    {
                        set_last_error(ORBISONIC_LIBRESPOT_START_FAILED);
                    }
                }
                Err(_) => set_last_error(ORBISONIC_LIBRESPOT_START_FAILED),
            }
        }) {
        Ok(join_handle) => join_handle,
        Err(_) => {
            set_last_error(ORBISONIC_LIBRESPOT_START_FAILED);
            return ORBISONIC_LIBRESPOT_START_FAILED;
        }
    };

    *receiver = Some(ReceiverHandle {
        shutdown_tx,
        control_tx,
        join_handle,
    });
    set_last_error(ORBISONIC_LIBRESPOT_OK);
    ORBISONIC_LIBRESPOT_OK
}

#[unsafe(no_mangle)]
pub extern "C" fn orbisonic_librespot_stop() -> i32 {
    let receiver_slot = RECEIVER.get_or_init(|| Mutex::new(None));
    let Ok(mut receiver) = receiver_slot.lock() else {
        return ORBISONIC_LIBRESPOT_START_FAILED;
    };

    let Some(receiver) = receiver.take() else {
        return ORBISONIC_LIBRESPOT_NOT_STARTED;
    };

    let _ = receiver.shutdown_tx.send(());
    let _ = receiver.join_handle.join();
    set_last_error(ORBISONIC_LIBRESPOT_OK);
    ORBISONIC_LIBRESPOT_OK
}

#[unsafe(no_mangle)]
pub extern "C" fn orbisonic_librespot_play_pause() -> i32 {
    send_receiver_command(ReceiverCommand::PlayPause)
}

#[unsafe(no_mangle)]
pub extern "C" fn orbisonic_librespot_previous() -> i32 {
    send_receiver_command(ReceiverCommand::Previous)
}

#[unsafe(no_mangle)]
pub extern "C" fn orbisonic_librespot_next() -> i32 {
    send_receiver_command(ReceiverCommand::Next)
}

#[unsafe(no_mangle)]
pub extern "C" fn orbisonic_librespot_seek(position_ms: u32) -> i32 {
    send_receiver_command(ReceiverCommand::Seek(position_ms))
}

#[unsafe(no_mangle)]
pub extern "C" fn orbisonic_librespot_set_volume(volume: u16) -> i32 {
    send_receiver_command(ReceiverCommand::SetVolume(volume))
}

#[unsafe(no_mangle)]
pub extern "C" fn orbisonic_librespot_last_error_code() -> i32 {
    LAST_ERROR
        .get_or_init(|| Mutex::new(ORBISONIC_LIBRESPOT_OK))
        .lock()
        .map(|error| *error)
        .unwrap_or(ORBISONIC_LIBRESPOT_START_FAILED)
}

async fn run_receiver(
    config: ReceiverConfig,
    mut shutdown_rx: oneshot::Receiver<()>,
    mut control_rx: mpsc::UnboundedReceiver<ReceiverCommand>,
) -> Result<(), String> {
    if config.loopback_device_uid.trim().is_empty() {
        return Err("Spotify loopback UID is required.".to_string());
    }

    fs::create_dir_all(&config.support_dir).map_err(|error| error.to_string())?;
    fs::create_dir_all(&config.cache_dir).map_err(|error| error.to_string())?;
    fs::create_dir_all(&config.log_dir).map_err(|error| error.to_string())?;

    let credentials_dir = config.cache_dir.join("credentials");
    let volume_dir = config.cache_dir.join("volume");
    let audio_dir = config.cache_dir.join("audio");
    let tmp_dir = config.support_dir.join("tmp");

    fs::create_dir_all(&credentials_dir).map_err(|error| error.to_string())?;
    fs::create_dir_all(&volume_dir).map_err(|error| error.to_string())?;
    fs::create_dir_all(&audio_dir).map_err(|error| error.to_string())?;
    fs::create_dir_all(&tmp_dir).map_err(|error| error.to_string())?;

    let cache = Cache::new(
        Some(credentials_dir),
        Some(volume_dir),
        Some(audio_dir),
        None,
    )
    .map_err(|error| error.to_string())?;

    let mut session_config = SessionConfig::default();
    session_config.device_id = stable_device_id(&config.receiver_name);
    session_config.tmp_dir = tmp_dir;

    let connect_config = ConnectConfig {
        name: config.receiver_name.clone(),
        device_type: DeviceType::Speaker,
        initial_volume: u16::MAX,
        disable_volume: true,
        volume_steps: 64,
        emit_set_queue_events: false,
        is_group: false,
    };

    let player_config = PlayerConfig {
        bitrate: Bitrate::Bitrate320,
        position_update_interval: Some(Duration::from_secs(1)),
        ..PlayerConfig::default()
    };

    let mixer = mixer::find(None).ok_or_else(|| "No librespot mixer is available.".to_string())?(
        MixerConfig::default(),
    )
    .map_err(|error| error.to_string())?;

    let soft_volume = mixer.get_soft_volume();
    let backend = audio_backend::find(Some("rodio".to_string()))
        .or_else(|| audio_backend::find(None))
        .ok_or_else(|| "No librespot audio backend is available.".to_string())?;
    let loopback_device_name = config.loopback_device_name.clone();
    let mut session = Session::new(session_config.clone(), Some(cache.clone()));
    let state_path = config.support_dir.join("state.json");
    write_spotify_state(&state_path, &SpotifyState::default());

    let player = Player::new(player_config, session.clone(), soft_volume, move || {
        backend(Some(loopback_device_name), AudioFormat::F32)
    });
    tokio::spawn(write_player_events(
        player.get_player_event_channel(),
        state_path.clone(),
    ));

    let mut discovery = Discovery::builder(
        session_config.device_id.clone(),
        session_config.client_id.clone(),
    )
    .name(connect_config.name.clone())
    .device_type(connect_config.device_type)
    .port(0)
    .launch()
    .map_err(|error| error.to_string())?;

    let mut spirc: Option<Spirc> = None;

    loop {
        tokio::select! {
            _ = &mut shutdown_rx => {
                write_spotify_state(&state_path, &SpotifyState::default());
                if let Some(spirc) = spirc.take() {
                    let _ = spirc.shutdown();
                }
                session.shutdown();
                return Ok(());
            }
            command = control_rx.recv() => {
                if let Some(command) = command {
                    handle_receiver_command(command, spirc.as_ref());
                }
            }
            credentials = discovery.next() => {
                let Some(credentials) = credentials else {
                    return Err("Spotify Connect discovery stopped unexpectedly.".to_string());
                };

                if let Some(spirc) = spirc.take() {
                    let _ = spirc.shutdown();
                }
                if session.is_invalid() {
                    session = Session::new(session_config.clone(), Some(cache.clone()));
                    player.set_session(session.clone());
                }

                let (next_spirc, spirc_task) = Spirc::new(
                    connect_config.clone(),
                    session.clone(),
                    credentials,
                    player.clone(),
                    mixer.clone(),
                )
                .await
                .map_err(|error| error.to_string())?;

                tokio::spawn(spirc_task);
                spirc = Some(next_spirc);
            }
        }
    }
}

fn send_receiver_command(command: ReceiverCommand) -> i32 {
    let receiver_slot = RECEIVER.get_or_init(|| Mutex::new(None));
    let Ok(receiver) = receiver_slot.lock() else {
        return ORBISONIC_LIBRESPOT_START_FAILED;
    };

    let Some(receiver) = receiver.as_ref() else {
        return ORBISONIC_LIBRESPOT_NOT_STARTED;
    };

    match receiver.control_tx.send(command) {
        Ok(()) => ORBISONIC_LIBRESPOT_OK,
        Err(_) => ORBISONIC_LIBRESPOT_NOT_STARTED,
    }
}

fn handle_receiver_command(command: ReceiverCommand, spirc: Option<&Spirc>) {
    let Some(spirc) = spirc else {
        return;
    };

    match command {
        ReceiverCommand::PlayPause => {
            let _ = spirc.play_pause();
        }
        ReceiverCommand::Previous => {
            let _ = spirc.prev();
        }
        ReceiverCommand::Next => {
            let _ = spirc.next();
        }
        ReceiverCommand::Seek(position_ms) => {
            let _ = spirc.set_position_ms(position_ms);
        }
        ReceiverCommand::SetVolume(volume) => {
            let _ = spirc.set_volume(volume);
        }
    }
}

async fn write_player_events(mut events: PlayerEventChannel, state_path: PathBuf) {
    let mut state = SpotifyState::default();
    write_spotify_state(&state_path, &state);

    while let Some(event) = events.recv().await {
        apply_player_event(&mut state, event);
        write_spotify_state(&state_path, &state);
    }
}

fn apply_player_event(state: &mut SpotifyState, event: PlayerEvent) {
    match event {
        PlayerEvent::TrackChanged { audio_item } => {
            state.session_active = true;
            state.title = Some(audio_item.name.clone());
            state.uri = Some(audio_item.uri.clone());
            state.duration_ms = Some(audio_item.duration_ms);
            state.position_ms = Some(0);
            state.is_explicit = audio_item.is_explicit;
            state.cover_url = audio_item
                .covers
                .iter()
                .max_by_key(|cover| cover.width.saturating_mul(cover.height))
                .map(|cover| cover.url.clone());

            match &audio_item.unique_fields {
                UniqueFields::Track {
                    artists,
                    album,
                    album_artists,
                    popularity,
                    number,
                    disc_number,
                } => {
                    state.album = Some(album.clone());
                    state.artists = artists.iter().map(|artist| artist.name.clone()).collect();
                    state.album_artists = album_artists.clone();
                    state.popularity = Some(*popularity);
                    state.track_number = Some(*number);
                    state.disc_number = Some(*disc_number);
                }
                UniqueFields::Local {
                    artists,
                    album,
                    album_artists,
                    number,
                    disc_number,
                    ..
                } => {
                    state.album = album.clone();
                    state.artists = artists.clone().into_iter().collect();
                    state.album_artists = album_artists.clone().into_iter().collect();
                    state.popularity = None;
                    state.track_number = *number;
                    state.disc_number = *disc_number;
                }
                UniqueFields::Episode { show_name, .. } => {
                    state.album = Some(show_name.clone());
                    state.artists = Vec::new();
                    state.album_artists = Vec::new();
                    state.popularity = None;
                    state.track_number = None;
                    state.disc_number = None;
                }
            }
        }
        PlayerEvent::Playing { position_ms, .. } => {
            state.session_active = true;
            state.is_playing = true;
            state.position_ms = Some(position_ms);
        }
        PlayerEvent::Paused { position_ms, .. }
        | PlayerEvent::Seeked { position_ms, .. }
        | PlayerEvent::PositionCorrection { position_ms, .. }
        | PlayerEvent::PositionChanged { position_ms, .. } => {
            state.session_active = true;
            state.is_playing = false;
            state.position_ms = Some(position_ms);
        }
        PlayerEvent::Stopped { .. } => {
            state.session_active = true;
            state.is_playing = false;
            state.position_ms = Some(0);
        }
        PlayerEvent::VolumeChanged { volume } => {
            state.volume = Some(volume);
        }
        PlayerEvent::ShuffleChanged { shuffle } => {
            state.shuffle = Some(shuffle);
        }
        PlayerEvent::RepeatChanged { context, track } => {
            state.repeat_context = Some(context);
            state.repeat_track = Some(track);
        }
        PlayerEvent::AutoPlayChanged { auto_play } => {
            state.auto_play = Some(auto_play);
        }
        PlayerEvent::SessionClientChanged { client_name, .. } => {
            state.session_active = true;
            state.client_name = Some(client_name);
        }
        PlayerEvent::SessionDisconnected { .. } => {
            *state = SpotifyState::default();
        }
        _ => {}
    }
}

fn write_spotify_state(state_path: &PathBuf, state: &SpotifyState) {
    let _ = fs::write(state_path, state_json(state));
}

fn state_json(state: &SpotifyState) -> String {
    let updated_at = format!("{:?}", std::time::SystemTime::now());
    format!(
        concat!(
            "{{",
            "\"title\":{},",
            "\"album\":{},",
            "\"artists\":{},",
            "\"albumArtists\":{},",
            "\"uri\":{},",
            "\"durationMs\":{},",
            "\"positionMs\":{},",
            "\"isPlaying\":{},",
            "\"isExplicit\":{},",
            "\"popularity\":{},",
            "\"trackNumber\":{},",
            "\"discNumber\":{},",
            "\"coverURL\":{},",
            "\"volume\":{},",
            "\"shuffle\":{},",
            "\"repeatContext\":{},",
            "\"repeatTrack\":{},",
            "\"autoPlay\":{},",
            "\"clientName\":{},",
            "\"sessionActive\":{},",
            "\"updatedAt\":{}",
            "}}"
        ),
        json_option_string(state.title.as_deref()),
        json_option_string(state.album.as_deref()),
        json_string_array(&state.artists),
        json_string_array(&state.album_artists),
        json_option_string(state.uri.as_deref()),
        json_option_u32(state.duration_ms),
        json_option_u32(state.position_ms),
        state.is_playing,
        state.is_explicit,
        json_option_u8(state.popularity),
        json_option_u32(state.track_number),
        json_option_u32(state.disc_number),
        json_option_string(state.cover_url.as_deref()),
        json_option_u16(state.volume),
        json_option_bool(state.shuffle),
        json_option_bool(state.repeat_context),
        json_option_bool(state.repeat_track),
        json_option_bool(state.auto_play),
        json_option_string(state.client_name.as_deref()),
        state.session_active,
        json_option_string(Some(updated_at.as_str()))
    )
}

fn json_option_string(value: Option<&str>) -> String {
    value.map(json_string).unwrap_or_else(|| "null".to_string())
}

fn json_string_array(values: &[String]) -> String {
    format!(
        "[{}]",
        values
            .iter()
            .map(|value| json_string(value))
            .collect::<Vec<_>>()
            .join(",")
    )
}

fn json_string(value: &str) -> String {
    let mut output = String::from("\"");
    for character in value.chars() {
        match character {
            '"' => output.push_str("\\\""),
            '\\' => output.push_str("\\\\"),
            '\n' => output.push_str("\\n"),
            '\r' => output.push_str("\\r"),
            '\t' => output.push_str("\\t"),
            c if c.is_control() => output.push_str(&format!("\\u{:04x}", c as u32)),
            c => output.push(c),
        }
    }
    output.push('"');
    output
}

fn json_option_u8(value: Option<u8>) -> String {
    value.map(|number| number.to_string()).unwrap_or_else(|| "null".to_string())
}

fn json_option_u16(value: Option<u16>) -> String {
    value.map(|number| number.to_string()).unwrap_or_else(|| "null".to_string())
}

fn json_option_u32(value: Option<u32>) -> String {
    value.map(|number| number.to_string()).unwrap_or_else(|| "null".to_string())
}

fn json_option_bool(value: Option<bool>) -> String {
    value.map(|flag| flag.to_string()).unwrap_or_else(|| "null".to_string())
}

fn run_result_to_code(result: Result<(), String>) -> i32 {
    match result {
        Ok(()) => ORBISONIC_LIBRESPOT_OK,
        Err(_) => ORBISONIC_LIBRESPOT_START_FAILED,
    }
}

fn parse_config(pointer: *const OrbisonicLibrespotConfig) -> Option<ReceiverConfig> {
    if pointer.is_null() {
        return None;
    }

    let config = unsafe { &*pointer };
    Some(ReceiverConfig {
        receiver_name: c_string(config.receiver_name)?,
        loopback_device_name: c_string(config.loopback_device_name)?,
        loopback_device_uid: c_string(config.loopback_device_uid)?,
        support_dir: PathBuf::from(c_string(config.support_dir)?),
        cache_dir: PathBuf::from(c_string(config.cache_dir)?),
        log_dir: PathBuf::from(c_string(config.log_dir)?),
    })
}

fn c_string(pointer: *const c_char) -> Option<String> {
    if pointer.is_null() {
        return None;
    }

    let value = unsafe { CStr::from_ptr(pointer) };
    Some(value.to_string_lossy().into_owned())
}

fn stable_device_id(receiver_name: &str) -> String {
    HEXLOWER.encode(&Sha1::digest(receiver_name.as_bytes()))
}

fn set_last_error(error: i32) {
    if let Ok(mut last_error) = LAST_ERROR
        .get_or_init(|| Mutex::new(ORBISONIC_LIBRESPOT_OK))
        .lock()
    {
        *last_error = error;
    }
}
