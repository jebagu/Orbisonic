# Task 07 - libVLC Callback Decode Bridge

## Scope

Task 7 evaluates whether libVLC audio callbacks can replace Orbisonic's demux/decode stage while preserving Orbisonic's router, renderer, and device output.

This is a docs-only task. No Orbisonic app code, tests, scripts, resources, installer files, vendor files, calibration files, or binary media assets were changed.

## Evidence Commands

- `git status --short`
- `sed -n '451,522p' orbisonic_vlc_codex_prompt_sequence.md`
- `rg -n "Callback prototype for audio playback|libvlc_audio_set_callbacks|libvlc_audio_set_format_callbacks|supported formats|S16N|FL32|setup the audio playback" _external/vlc/include/vlc/libvlc_media_player.h _external/vlc-3.0/include/vlc/libvlc_media_player.h`
- `nl -ba _external/vlc/include/vlc/libvlc_media_player.h | sed -n '1117,1297p'`
- `nl -ba _external/vlc-3.0/include/vlc/libvlc_media_player.h | sed -n '603,782p'`
- `nl -ba _external/vlc/lib/media_player.c | sed -n '1360,1412p'`
- `nl -ba _external/vlc-3.0/lib/media_player.c | sed -n '1288,1335p'`
- `nl -ba _external/vlc/modules/audio_output/amem.c | sed -n '31,398p'`
- `nl -ba _external/vlc-3.0/modules/audio_output/amem.c | sed -n '31,285p'`
- `nl -ba _external/vlc/include/vlc/libvlc_media.h | sed -n '200,392p'`
- `nl -ba _external/vlc-3.0/include/vlc/libvlc_media.h | sed -n '330,520p'`
- `nl -ba _external/vlc/modules/access/http/access.c | sed -n '150,315p'`
- `nl -ba _external/vlc/modules/access/http/resource.c | sed -n '55,325p'`
- `nl -ba _external/vlc/modules/access/http/file.c | sed -n '1,220p'`
- `nl -ba _external/vlc/src/audio_output/dec.c | sed -n '330,430p;860,930p'`
- `nl -ba _external/vlc/src/audio_output/filters.c | sed -n '490,650p;780,830p'`
- `nl -ba _external/vlc/include/vlc_es.h | sed -n '53,144p'`
- `nl -ba Sources/Orbisonic/OrbisonicEngine.swift | sed -n '640,805p;978,1035p;2100,2185p'`
- `nl -ba Sources/Orbisonic/OrbisonicViewModel.swift | sed -n '2428,2560p;5996,6100p;6748,6960p'`
- `nl -ba Sources/Orbisonic/OrbisonicViewModel.swift | sed -n '2544,2608p'`
- `nl -ba Sources/Orbisonic/AudioFileLoader.swift | sed -n '1,35p;126,215p;430,560p'`
- `nl -ba Sources/AudioContracts/AudioContracts.swift | sed -n '179,230p;283,330p;420,435p'`

## Current VLC Source Context

The Task 6 source map cloned current VLC and VLC 3.0 under ignored `_external/` checkouts.

- Current VLC: `_external/vlc`, `https://github.com/videolan/vlc.git`, branch `master`, commit `b91572e7424a472bbf80d3ad5025fc20ca3fbd1d`.
- VLC 3.0: `_external/vlc-3.0`, `https://github.com/videolan/vlc-3.0.git`, branch `master`, commit `e30973a45e8c4f075cf5a6094f500cd3100665f5`.

## Direct Answers

### 1. Can libVLC decode without writing audio to the OS?

Yes, when using the decoded audio callback path.

The public header says audio callbacks override any other audio output mechanism and that LibVLC will not output audio in any way when callbacks are set at `_external/vlc/include/vlc/libvlc_media_player.h:1196` through `:1204`. The implementation writes callback pointers to `amem-*` variables and sets `aout` to `amem,none` at `_external/vlc/lib/media_player.c:1364` through `:1380`.

VLC 3.0 has the same public contract at `_external/vlc-3.0/include/vlc/libvlc_media_player.h:682` through `:689`, and the same `aout = amem,none` selection at `_external/vlc-3.0/lib/media_player.c:1294` through `:1302`.

### 2. Can libVLC deliver PCM into an application callback?

Yes.

The `libvlc_audio_play_cb` documentation says LibVLC decodes and post-processes the audio signal asynchronously in an internal thread, then invokes the callback whenever samples are ready to be queued to output at `_external/vlc/include/vlc/libvlc_media_player.h:1117` through `:1128`. The callback receives a sample pointer, sample count, and PTS at `_external/vlc/include/vlc/libvlc_media_player.h:1134` through `:1140`.

The current `amem` output module calls the application `play` callback with `block->p_buffer`, `block->i_nb_samples`, and the converted timestamp at `_external/vlc/modules/audio_output/amem.c:101` through `:108`.

### 3. Can Orbisonic request float32 PCM?

Current VLC: yes, as `FL32`, with native endianness and interleaved samples for more than one channel.

The current public header lists `S16N`, `S32N`, and `FL32` as supported fixed decoded formats at `_external/vlc/include/vlc/libvlc_media_player.h:1275` through `:1287`. Current `amem` maps `FL32` to `VLC_CODEC_FL32` at `_external/vlc/modules/audio_output/amem.c:37` through `:48`, and converts the requested string to the selected fourcc at `_external/vlc/modules/audio_output/amem.c:271` through `:282`.

VLC 3.0: not safely proven for float32 in the inspected `amem` implementation. The 3.0 public header gives examples such as `S16N` or `f32l` at `_external/vlc-3.0/include/vlc/libvlc_media_player.h:761` through `:776`, but the 3.0 `amem` source rejects any format other than `S16N` in `_external/vlc-3.0/modules/audio_output/amem.c:190` through `:195` and sets `VLC_CODEC_S16N` at `_external/vlc-3.0/modules/audio_output/amem.c:235` through `:236`.

### 4. Can Orbisonic request or observe the decoded source channel count?

Request: yes, but only as callback output channel count, not as a separate source-layout contract.

`libvlc_audio_set_format` takes caller-selected `format`, `rate`, and `channels` at `_external/vlc/include/vlc/libvlc_media_player.h:1289` through `:1297`, and the implementation stores them as `amem-format`, `amem-rate`, and `amem-channels` at `_external/vlc/lib/media_player.c:1401` through `:1408`.

Observe: partially, through the setup callback. The setup callback receives `format`, `rate`, and `channels` as in/out parameters at `_external/vlc/include/vlc/libvlc_media_player.h:1238` through `:1250`. Current `amem` initializes `channels` from `aout_FormatNbChannels(fmt)` before invoking the setup callback at `_external/vlc/modules/audio_output/amem.c:223` through `:233`.

Important limitation: the callback API exposes only channel count and sample rate, not the full VLC `audio_format_t`. The public setup callback does not expose `i_physical_channels`, `i_chan_mode`, or `channel_type`. Those fields exist internally in `audio_format_t` at `_external/vlc/include/vlc_es.h:62` through `:95`, but they are not part of the libVLC callback signature.

### 5. Does libVLC expose channel layout metadata sufficient for Sonic Sphere or Ambisonic routing?

No, not through the public decoded audio callback API inspected here.

Internally, VLC has channel metadata: `audio_format_t` contains `i_physical_channels`, `i_chan_mode`, `channel_type`, and `i_channels` at `_external/vlc/include/vlc_es.h:62` through `:95`, and `AUDIO_CHANNEL_TYPE_AMBISONICS` is defined at `_external/vlc/include/vlc_es.h:53` through `:57`.

The public audio callback setup only exposes mutable `format`, `rate`, and `channels` at `_external/vlc/include/vlc/libvlc_media_player.h:1238` through `:1250`. It does not expose the physical channel bitmap, Ambisonics order, spherical harmonic metadata, or Sonic Sphere speaker mapping. Current `amem` also maps channel counts 1 through 8 into conventional bitmap layouts at `_external/vlc/modules/audio_output/amem.c:295` through `:329`; it does not pass a source channel-layout object to the application.

Orbisonic's current contract is richer than the libVLC callback surface. It models direct 30 and direct 30.1 layouts at `Sources/AudioContracts/AudioContracts.swift:210` through `:217`, arbitrary discrete fallback layouts at `Sources/AudioContracts/AudioContracts.swift:219` through `:226`, and source descriptors with explicit layout at `Sources/AudioContracts/AudioContracts.swift:283` through `:329`.

### 6. Does libVLC downmix when the callback asks for fewer channels?

The source shows VLC builds an audio filter/conversion pipeline between decoded input and requested output. That is enough to expect conversion or downmix behavior when output channels differ, but the exact coefficients depend on the selected channel mixer/filter path and source layout.

Current `amem` sets the callback output format and requested channel layout in its `Start` function at `_external/vlc/modules/audio_output/amem.c:216` through `:330`. The audio-output stream then asks the selected output to produce a mixer/filter format and builds filters with `aout_FiltersNewWithClock` at `_external/vlc/src/audio_output/dec.c:416` through `:430`. During playback, decoded blocks pass through `aout_FiltersPlay` before software volume and final `aout->play` at `_external/vlc/src/audio_output/dec.c:894` through `:923`.

The filter builder handles channel-type conversion, unknown channel maps, remap filters, user filters, and pipeline playback at `_external/vlc/src/audio_output/filters.c:545` through `:650` and `_external/vlc/src/audio_output/filters.c:787` through `:817`. VLC also has channel mixer modules including trivial, simple, remap, and spatialaudio in the current build definitions at `_external/vlc/modules/audio_filter/meson.build:161` through `:193`.

Conclusion: yes, a request for fewer channels can cause VLC to transform the decoded audio before the callback. That is useful for normal stereo callbacks but unsafe if Orbisonic expects untouched source channel identity.

### 7. Does libVLC support 30-channel callback output?

No, not in the stock callback path inspected here.

Current VLC `amem` defines `AMEM_CHAN_MAX 8` at `_external/vlc/modules/audio_output/amem.c:33` through `:35`, exposes the option range `1...AMEM_CHAN_MAX` at `_external/vlc/modules/audio_output/amem.c:61` through `:68`, and rejects any callback format with `channels > AMEM_CHAN_MAX` at `_external/vlc/modules/audio_output/amem.c:284` through `:292`.

VLC 3.0 uses `AOUT_CHAN_MAX` for the option range at `_external/vlc-3.0/modules/audio_output/amem.c:50` through `:52`; `AOUT_CHAN_MAX` is 9 at `_external/vlc/include/vlc_es.h:132` through `:136`, and 3.0 rejects channels above that at `_external/vlc-3.0/modules/audio_output/amem.c:190` through `:199`.

### 8. Does libVLC support 52-channel callback output?

No, not in the stock callback path inspected here.

The same current `amem` cap of 8 channels rejects 52-channel output at `_external/vlc/modules/audio_output/amem.c:284` through `:292`. VLC's internal source-side constants include `INPUT_CHAN_MAX 64` at `_external/vlc/include/vlc_es.h:132` through `:136`, but the callback output path is limited by `amem`, not by that broader input constant.

There is also an internal ambiguity for very high discrete source counts: `audio_format_t.i_channels` is commented as "must be <=32" at `_external/vlc/include/vlc_es.h:91` through `:95`, while `INPUT_CHAN_MAX` is 64 at `_external/vlc/include/vlc_es.h:132` through `:136`. That ambiguity does not change the callback-output conclusion because `amem` rejects anything above 8 in current VLC.

### 9. If 30 or 52 cannot be proven, what exact experiment would prove it?

Use a minimal libVLC harness against the exact VLC build intended for Orbisonic:

1. Create deterministic 30-channel and 52-channel PCM fixtures with per-channel impulse IDs and steady-state per-channel tones, matching the Task 5 reference-test design.
2. Create media using `libvlc_media_new_path` for local files and `libvlc_media_new_location` for HTTP URLs.
3. Register `libvlc_audio_set_callbacks` with play, pause, resume, flush, and drain callbacks.
4. Run one pass with `libvlc_audio_set_format(mp, "FL32", 48000, 30)` and one pass with `channels = 52`.
5. Run another pass with `libvlc_audio_set_format_callbacks`; in setup, log the incoming `format`, `rate`, and `channels`, then return `FL32`, 48000, and the incoming source channel count unchanged.
6. Capture every play callback's sample count, byte count, PTS, and first non-zero frame per channel.
7. Treat success as all requested channels being delivered with impulse identity preserved and no VLC `format not supported` log.
8. Treat failure as no play callback, a setup failure, or `amem` rejecting the format. Current source predicts failure because `_external/vlc/modules/audio_output/amem.c:284` through `:292` rejects channels above 8.

For 52-channel input specifically, add a variant using `libvlc_media_new_callbacks` so Orbisonic's HTTP layer supplies bytes while libVLC demuxes/decodes. That separates "can VLC decode the file" from "can VLC's stock HTTP access satisfy Plex-specific headers."

### 10. Can this path support Plex Part.key URLs, headers, redirects, and range requests?

URL shape: likely yes for URL-based access, because public libVLC accepts media locations. Current `libvlc_media_new_location` creates media for a given media resource location, including valid URLs, at `_external/vlc/include/vlc/libvlc_media.h:274` through `:288`. VLC 3.0 has the same URL constructor at `_external/vlc-3.0/include/vlc/libvlc_media.h:389` through `:406`.

Per-media options: partially. Public `libvlc_media_add_option` allows per-media reading/streaming options but warns that available options and semantics vary by LibVLC version and build at `_external/vlc/include/vlc/libvlc_media.h:367` through `:385`.

HTTP options in current VLC: current HTTP access inherits `http-user-agent`, `http-referrer`, and cookie forwarding at `_external/vlc/modules/access/http/access.c:166` through `:186`, and declares those options at `_external/vlc/modules/access/http/access.c:294` through `:309`. It adds `Referer`, cookies, and user-agent headers when building requests at `_external/vlc/modules/access/http/resource.c:64` through `:75`.

Redirects: yes for standard HTTP redirects. Current HTTP access detects a redirect URL and returns `VLC_ACCESS_REDIRECT` at `_external/vlc/modules/access/http/access.c:229` through `:234`. Redirect URL handling reads `Location` for 201 and 3xx status codes, resolves it against the base URL, and strips anchors at `_external/vlc/modules/access/http/resource.c:236` through `:297`.

Range requests: yes in current HTTP file access. It sends `Range: bytes=<offset>-` at `_external/vlc/modules/access/http/file.c:48` through `:75`, validates `Content-Range` for partial responses at `_external/vlc/modules/access/http/file.c:78` through `:105`, detects seek support via `206`, `416`, or `Accept-Ranges: bytes` at `_external/vlc/modules/access/http/file.c:169` through `:176`, and reopens at a requested byte offset in `_external/vlc/modules/access/http/file.c:204` through `:220`.

Arbitrary Plex headers: not proven through the stock URL path. The inspected current HTTP module exposes user-agent, referrer, and cookies, but the search for HTTP option names only found those public options, not a generic "add arbitrary request header" option in the inspected files. If Plex authentication can be carried in the URL query, cookies, user-agent, or referrer, stock URL access may be enough. If Plex requires arbitrary custom headers, Orbisonic should either prove the exact option in the intended VLC build or use `libvlc_media_new_callbacks` so Orbisonic owns HTTP and supplies the bitstream to VLC.

The custom input callback path supports app-owned read and seek callbacks: current libVLC declares open/read/seek/close callback types at `_external/vlc/include/vlc/libvlc_media.h:218` through `:272`, and `libvlc_media_new_callbacks` at `_external/vlc/include/vlc/libvlc_media.h:326` through `:355`. The docs warn that input callbacks can be asynchronous and must avoid deadlocks at `_external/vlc/include/vlc/libvlc_media.h:339` through `:345`.

### 11. How do seek, pause, flush, drain, and stop map to Orbisonic transport?

Orbisonic currently receives local play, pause, and stop commands in `OrbisonicViewModel`: `playLocalTransport` at `Sources/Orbisonic/OrbisonicViewModel.swift:2435` through `:2503`, `pauseLocalTransport` at `Sources/Orbisonic/OrbisonicViewModel.swift:2505` through `:2542`, and `stopLocalTransport` at `Sources/Orbisonic/OrbisonicViewModel.swift:2544` through `:2573`.

The engine owns actual local playback state transitions: `play` starts the engine, schedules buffers, starts player nodes, resumes pause state, and marks `.playing` at `Sources/Orbisonic/OrbisonicEngine.swift:640` through `:711`; `pause` captures the current playback frame, pauses schedulers/player nodes, and marks `.paused` at `Sources/Orbisonic/OrbisonicEngine.swift:713` through `:727`; `stop` cancels schedulers and streaming, stops nodes and engine, resets frame state, and returns to `.idle` or `.ready` at `Sources/Orbisonic/OrbisonicEngine.swift:788` through `:804`.

Seek currently maps from UI scrub progress to engine frame position. `scrubEditingChanged` calls `engine.seek(toProgress:)` when editing ends at `Sources/Orbisonic/OrbisonicViewModel.swift:6939` through `:6950`. `OrbisonicEngine.seek(toProgress:)` cancels streaming decode on streaming playback, or stops/reschedules prepared/gapless player nodes around a new frame at `Sources/Orbisonic/OrbisonicEngine.swift:978` through `:1035`.

libVLC transport would map as follows:

- Play: `OrbisonicViewModel` still owns the user command. `LibVlcAudioSource` calls `libvlc_media_player_play`, then the play callback fills `DecodedPcmRingBuffer`.
- Pause: call `libvlc_media_player_set_pause` or `libvlc_media_player_pause`; the libVLC pause callback becomes a ring-buffer pause marker. The current API documents pause/resume callbacks at `_external/vlc/include/vlc/libvlc_media_player.h:1142` through `:1163`.
- Resume: libVLC resume callback wakes the ring buffer and renderer scheduling. The resume callback is documented at `_external/vlc/include/vlc/libvlc_media_player.h:1153` through `:1163`.
- Seek: call `libvlc_media_player_set_time` or `libvlc_media_player_set_position`. Current VLC documents that seek may not work for every format/protocol at `_external/vlc/include/vlc/libvlc_media_player.h:1317` through `:1329` and `_external/vlc/include/vlc/libvlc_media_player.h:1354` through `:1365`. On seek, the bridge must flush ring-buffered PCM before accepting post-seek audio.
- Flush: libVLC invokes flush when pending buffers should be discarded, typically on stop, at `_external/vlc/include/vlc/libvlc_media_player.h:1165` through `:1174`. Current `amem` calls the flush callback under lock at `_external/vlc/modules/audio_output/amem.c:124` through `:133`; the bridge should clear `DecodedPcmRingBuffer` and reset PTS continuity.
- Drain: libVLC may invoke drain at decoded audio track end while already queued buffers should still render at `_external/vlc/include/vlc/libvlc_media_player.h:1176` through `:1185`. Current `amem` invokes drain and reports drained at `_external/vlc/modules/audio_output/amem.c:136` through `:145`; the bridge should mark end-of-stream and let Orbisonic render queued PCM before natural-end handling.
- Stop: current VLC 4-style API exposes asynchronous stop at `_external/vlc/include/vlc/libvlc_media_player.h:305` through `:316`, while VLC 3.0 exposes synchronous `libvlc_media_player_stop` at `_external/vlc-3.0/include/vlc/libvlc_media_player.h:270` through `:275`. On stop, Orbisonic should call libVLC stop, flush the ring buffer, stop its own renderer/device graph, and then return to the current `.ready` or `.idle` semantics.

## Proposed Bridge Architecture

```text
MediaSource/PlexUrl/LocalPath
    -> LibVlcAudioSource
    -> DecodedPcmRingBuffer
    -> OrbisonicChannelRouter
    -> OrbisonicSpatialRenderer
    -> OrbisonicDeviceOutput
```

`MediaSource/PlexUrl/LocalPath` owns source identity and credentials. Local paths can use `libvlc_media_new_path`; normal URLs can use `libvlc_media_new_location`; Plex URLs that need exact headers or range policy can use app-owned HTTP plus `libvlc_media_new_callbacks`.

`LibVlcAudioSource` owns one libVLC media player instance, callback registration, callback format negotiation, libVLC transport calls, and source-read errors. It should emit decoded PCM, source timing, and format observations only. It must not own Orbisonic renderer mode, Sonic Sphere layout policy, output device selection, or UI state.

`DecodedPcmRingBuffer` absorbs libVLC's asynchronous callback timing. It records PTS, discontinuity, pause/resume, flush, drain, underrun, overflow, and channel-count observations. The read side presents stable blocks to Orbisonic's existing render/device clock.

`OrbisonicChannelRouter` preserves or reconstructs Orbisonic layout semantics. This is mandatory because libVLC's callback API exposes only count/rate/format, while Orbisonic has direct 30/direct 30.1 and 1...64 source-channel contracts at `Sources/AudioContracts/AudioContracts.swift:210` through `:217` and `Sources/AudioContracts/AudioContracts.swift:283` through `:329`.

`OrbisonicSpatialRenderer` remains the owner of Sonic Sphere, direct-mode, static-bed, and future Ambisonic behavior. A decoded PCM bridge must feed this renderer; it should not use VLC's spatialaudio or platform output routing as the production render path.

`OrbisonicDeviceOutput` remains AVAudioEngine/Core Audio output. Current engine output device selection is owned by `OrbisonicEngine.setOutputDevicePreservingPlayback` at `Sources/Orbisonic/OrbisonicEngine.swift:769` through `:785`, and Core Audio device binding uses `kAudioOutputUnitProperty_CurrentDevice` at `Sources/Orbisonic/OrbisonicEngine.swift:751` through `:759`.

## Why This Is Safer Than Full VLC Player Output

Unsafe architecture:

```text
MediaSource
    -> FullVlcPlayer
    -> OS default audio output
```

The full-player path lets VLC own decode, channel conversion, renderer/filter selection, and platform audio output. That would bypass Orbisonic's selected output route, normal-monitor policy, Sonic Sphere routing, Direct 30/30.1 semantics, metering, and app diagnostics.

The callback bridge keeps VLC at the demux/decode boundary only. VLC may still post-process into the requested callback format, so Orbisonic must choose the request carefully, but Orbisonic remains responsible for layout, router, renderer, device selection, and diagnostics.

The callback path also provides a hard safety boundary: when callbacks are set, the public header says LibVLC will not output audio in any way at `_external/vlc/include/vlc/libvlc_media_player.h:1202` through `:1204`, and the implementation selects `amem,none` at `_external/vlc/lib/media_player.c:1372` through `:1380`. That makes it possible to test decode without accidentally writing to the macOS default device.

## Architectural Difference Being Tested

Replacing decode means replacing AVFoundation/Matroska demux and PCM preparation with libVLC demux/decode, while keeping Orbisonic's source metadata, channel router, renderer, metering, and AVAudioEngine output. This is the bridge architecture under test.

Replacing render means letting VLC's audio filters, spatialaudio module, channel mixer, or downmix path decide how source channels become speaker or headphone output. That is not acceptable for Sonic Sphere routing unless a future contract explicitly accepts VLC's renderer semantics.

Replacing device output means using VLC's platform audio modules such as AUHAL/CoreAudio, WASAPI, ALSA, PulseAudio, PipeWire, or JACK. That would bypass Orbisonic's output-device selection and current AVAudioEngine graph. It is not part of this bridge.

Replacing the entire player means adopting VLC's media-player transport, filters, render path, and OS output as the audible app. That is the highest-risk option because Orbisonic would lose control over channel identity, route diagnostics, Sonic Sphere mapping, direct modes, and current UI transport semantics.

## Callback Bridge Verdict

libVLC callbacks are viable as a decode bridge only for source formats and channel counts that can be delivered through `amem` without destroying Orbisonic channel identity.

The current stock callback path is promising for ordinary mono/stereo/5.1/7.1 decode into Orbisonic, especially with `FL32` output. It is not sufficient for 30-channel or 52-channel callback output as-is because current `amem` rejects output channel counts above 8.

For Sonic Sphere production use, the next proof must be an executable callback harness using deterministic channel-identity fixtures. The harness should prove whether libVLC can decode the desired media without OS output, preserve source channel identity into callbacks, handle Plex access requirements, and report seek/flush/drain semantics cleanly enough for Orbisonic's transport.
