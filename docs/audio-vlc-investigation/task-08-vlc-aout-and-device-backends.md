# Task 08 - VLC aout and Device Backends

## Scope

Task 8 inspects VLC's internal audio output abstraction and platform backends to decide which concepts Orbisonic could safely imitate.

This is a docs-only task. No Orbisonic app code, tests, scripts, resources, installer files, vendor files, calibration files, or binary media assets were changed.

## Source Inventory

The Task 6 source map cloned two ignored VLC research checkouts under `_external/`.

- Current VLC checkout: `_external/vlc`, commit `b91572e7424a472bbf80d3ad5025fc20ca3fbd1d`.
- VLC 3.0 checkout: `_external/vlc-3.0`, commit `e30973a45e8c4f075cf5a6094f500cd3100665f5`.

Current VLC audio-output files inspected:

- `include/vlc_aout.h`
- `src/audio_output/aout_internal.h`
- `src/audio_output/common.c`
- `src/audio_output/dec.c`
- `src/audio_output/filters.c`
- `src/audio_output/meter.c`
- `src/audio_output/output.c`
- `src/audio_output/volume.c`
- `modules/audio_output/alsa.c`
- `modules/audio_output/amem.c`
- `modules/audio_output/apple/auhal.c`
- `modules/audio_output/apple/coreaudio_common.c`
- `modules/audio_output/jack.c`
- `modules/audio_output/mmdevice.c`
- `modules/audio_output/pipewire.c`
- `modules/audio_output/pulse.c`
- `modules/audio_output/wasapi.c`

Existence notes:

- Current VLC has `wasapi.c`, `mmdevice.c`, `alsa.c`, `pulse.c`, `apple/auhal.c`, `apple/coreaudio_common.c`, `jack.c`, `pipewire.c`, and `amem.c`.
- Current VLC does not have `modules/audio_output/directsound.c`.
- VLC 3.0 has `modules/audio_output/directsound.c`.
- VLC 3.0 does not have `modules/audio_output/pipewire.c` in the inspected tree.
- No `ASIO` or `asio` matches were found in the inspected current or 3.0 `modules/audio_output/` trees.

## Evidence Commands

- `git status --short`
- `sed -n '526,593p' orbisonic_vlc_codex_prompt_sequence.md`
- `find _external/vlc/modules/audio_output _external/vlc/modules/audio_output/apple -maxdepth 1 -type f | sort`
- `find _external/vlc-3.0/modules/audio_output -maxdepth 1 -type f | sort`
- `rg -n "ASIO|asio" _external/vlc/modules/audio_output _external/vlc-3.0/modules/audio_output _external/vlc-3.0/modules/MODULES_LIST`
- `nl -ba _external/vlc/include/vlc_aout.h | sed -n '128,184p;185,263p;285,326p;366,423p;608,620p'`
- `nl -ba _external/vlc/src/audio_output/output.c | sed -n '264,310p;422,463p;594,696p;698,829p;888,946p'`
- `nl -ba _external/vlc/src/audio_output/dec.c | sed -n '342,430p;870,958p;978,1047p;1055,1127p'`
- `nl -ba _external/vlc/modules/audio_output/wasapi.c | sed -n '120,185p;315,360p;620,855p;955,972p'`
- `nl -ba _external/vlc/modules/audio_output/mmdevice.c | sed -n '1215,1265p;1358,1378p;1530,1568p'`
- `nl -ba _external/vlc/modules/audio_output/alsa.c | sed -n '780,890p;1095,1125p;1188,1210p'`
- `nl -ba _external/vlc/modules/audio_output/pulse.c | sed -n '900,1040p;1100,1190p;1240,1270p'`
- `nl -ba _external/vlc/modules/audio_output/jack.c | sed -n '100,285p;336,385p;390,480p;509,525p'`
- `nl -ba _external/vlc/modules/audio_output/pipewire.c | sed -n '200,285p;310,385p;425,555p;585,630p;703,785p;894,940p'`
- `nl -ba _external/vlc/modules/audio_output/apple/auhal.c | sed -n '1035,1105p;1124,1160p;1485,1655p;1711,1788p'`
- `nl -ba _external/vlc/modules/audio_output/apple/coreaudio_common.c | sed -n '430,475p;595,620p;735,795p'`
- `nl -ba _external/vlc/modules/audio_output/amem.c | sed -n '33,68p;101,145p;216,330p;333,380p'`
- `nl -ba _external/vlc-3.0/modules/audio_output/directsound.c | sed -n '60,100p;377,510p;601,810p;839,888p;1052,1088p'`
- `nl -ba Sources/Orbisonic/OrbisonicEngine.swift | sed -n '640,805p;978,1035p;2102,2185p;2390,2445p'`
- `nl -ba Sources/AudioCore/OutputAdapters.swift | sed -n '1,245p;300,405p'`
- `nl -ba Sources/AudioCore/RenderKernels.swift | sed -n '250,276p;430,452p'`
- `nl -ba Sources/Orbisonic/OutputRouteMonitor.swift | sed -n '1,260p'`
- `nl -ba Sources/Orbisonic/LiveAudioBridge.swift | sed -n '1,260p;500,760p'`
- `nl -ba Sources/Orbisonic/NormalMonitorRouteDescriptor.swift | sed -n '80,145p'`
- `nl -ba Sources/Orbisonic/LocalAudioFileSource.swift | sed -n '80,115p;240,272p'`
- `rg -n "kAudioDevicePropertyLatency|AudioDevicePropertyLatency|hardware latency|latency" Sources/Orbisonic Sources/AudioCore Sources/AudioContracts`

## Direct Answers

### 1. What is the VLC `audio_output_t` lifecycle?

`audio_output_t` is the device-output abstraction for decoded or pass-through audio samples. The public internal header defines three lifecycle states: `stopped`, `playing`, and `paused`. The object is created and destroyed in `stopped`; `start()` moves it from stopped to playing; `stop()` moves it from playing or paused back to stopped at `_external/vlc/include/vlc_aout.h:140` through `:151`.

The lifecycle is enforced through module loading and mandatory callbacks. `aout_New` creates the audio output object, initializes device lists and events, loads the selected `audio output` module, and asserts that `start` and `stop` are present at `_external/vlc/src/audio_output/output.c:264` through `:310`. `aout_OutputDelete` calls the selected backend's `stop` under the owner lock at `_external/vlc/src/audio_output/output.c:823` through `:829`.

### 2. What does `start` negotiate?

`start` receives `audio_sample_format_t *fmt` as an in/out argument: the stream sample format on entry, and the selected output stream format on return at `_external/vlc/include/vlc_aout.h:159` through `:168`.

The common output path prepares linear formats, applies the chosen mix mode, handles Ambisonics by constraining output to 7.1 as the maximum rendered sink setup, picks an implementation-friendly sample format, calls `aout->start(aout, fmt)`, and then prints the negotiated output format with `aout_FormatPrint(aout, "output", fmt)` at `_external/vlc/src/audio_output/output.c:698` through `:820`.

Backend examples:

- WASAPI chooses shared or exclusive mode and checks the Windows endpoint's supported format at `_external/vlc/modules/audio_output/wasapi.c:768` through `:855`.
- ALSA opens the PCM device, disables ALSA auto-resampling, negotiates sample format, channel count, and sample rate, and fails if hardware parameters cannot be set at `_external/vlc/modules/audio_output/alsa.c:780` through `:890`.
- AUHAL selects the Core Audio output device, reads the preferred device channel layout, computes latency, initializes the AudioUnit, and starts it at `_external/vlc/modules/audio_output/apple/auhal.c:1037` through `:1104` and `:1485` through `:1647`.
- JACK forces float32, adopts the JACK server sample rate, creates one JACK output port per VLC output channel, activates the client, and logs channel/rate initialization at `_external/vlc/modules/audio_output/jack.c:119` through `:280`.
- PipeWire maps VLC sample format and channels into a PipeWire raw format, applies aux channel positions where needed, creates a stream, and errors on unsupported formats or too many channels at `_external/vlc/modules/audio_output/pipewire.c:461` through `:630`.
- `amem` negotiates callback format/rate/channel count from the callback setup function or module variables, then maps 1 through 8 channels to standard VLC channel layouts at `_external/vlc/modules/audio_output/amem.c:216` through `:330`.

### 3. What does `play` receive?

`play` receives a `block_t *block` containing audio samples and a system-time `date` for when the first sample should render. The contract says the block is queued for playback and that the first play after start or flush will often be in the future at `_external/vlc/include/vlc_aout.h:213` through `:226`.

The decoder-facing stream path applies filters, software volume, clock delay changes, drift correction, and metering before handing the block and converted `play_date` to `aout->play(aout, block, play_date)` at `_external/vlc/src/audio_output/dec.c:870` through `:958`.

Backend examples:

- `amem` passes `block->p_buffer`, sample count, and timestamp to the app callback, then releases the block at `_external/vlc/modules/audio_output/amem.c:101` through `:108`.
- PipeWire queues blocks, tracks injected frames, and reports timing as the stream process callback consumes the queue at `_external/vlc/modules/audio_output/pipewire.c:200` through `:248`.
- JACK writes VLC samples into a ring buffer; JACK's real-time process callback de-interleaves that ring buffer into per-port buffers at `_external/vlc/modules/audio_output/jack.c:390` through `:428`.

### 4. What does `time_get` or timing report provide?

`time_get` estimates playback-buffer latency: the delay until the next sample written to the output buffer would be rendered. The header explicitly says this is essential for sync and long-term drift between the audio-output clock and the upstream media clock at `_external/vlc/include/vlc_aout.h:185` through `:208`.

The preferred modern path is timing reports. `aout_TimingReport` reports a mapping from system timestamp to audio PTS, and the header recommends reporting the first timing point as soon as possible and later points around once per second at `_external/vlc/include/vlc_aout.h:303` through `:326`.

Backend examples:

- WASAPI uses `IAudioClock_GetPosition` and `IAudioClock_GetFrequency`, then reports audio time against QPC/system time at `_external/vlc/modules/audio_output/wasapi.c:132` through `:165`.
- PipeWire reports timing from queued/injected frame counts and system time at `_external/vlc/modules/audio_output/pipewire.c:206` through `:218`.
- JACK's `TimeGet` returns graph latency plus ring-buffer read-space duration at `_external/vlc/modules/audio_output/jack.c:376` through `:385`, and its graph callback updates maximum playback latency from JACK port latency ranges at `_external/vlc/modules/audio_output/jack.c:462` through `:480`.
- AUHAL computes device, safety-offset, and stream latency from Core Audio properties and logs the total at `_external/vlc/modules/audio_output/apple/auhal.c:1485` through `:1528`.

### 5. What does `flush` mean?

`flush` discards playback buffers. It is mandatory and cannot be called in stopped state at `_external/vlc/include/vlc_aout.h:244` through `:248`.

The decoder-facing stream flush calls `aout->flush(aout)` and resets stream timing/state at `_external/vlc/src/audio_output/dec.c:1036` through `:1047`.

Backend examples:

- WASAPI stops and resets the `IAudioClient` buffer at `_external/vlc/modules/audio_output/wasapi.c:346` through `:360`.
- PipeWire releases queued frames, clears timing/draining state, and flushes the PipeWire stream without draining at `_external/vlc/modules/audio_output/pipewire.c:349` through `:366`.
- JACK resets its ring-buffer read and write pointers at `_external/vlc/modules/audio_output/jack.c:349` through `:356`.
- `amem` invokes the app's flush callback if one was provided at `_external/vlc/modules/audio_output/amem.c:124` through `:133`.

### 6. What does `drain` mean?

`drain` means finish already queued audio asynchronously instead of discarding it. It can be cancelled by `flush` or `stop`, and the backend must call `aout_DrainedReport()` when complete. If the backend does not implement `drain`, the caller waits for the delay returned by `time_get` before stopping at `_external/vlc/include/vlc_aout.h:250` through `:262`.

The decoder-facing path drains filters first, optionally submits final filtered blocks, then calls backend `drain` if present. Otherwise it computes a drain deadline from current output delay at `_external/vlc/src/audio_output/dec.c:1069` through `:1127`.

Backend examples:

- PipeWire marks draining, lets the process loop run the queued audio out, then reports drained from its stream-drained callback at `_external/vlc/modules/audio_output/pipewire.c:259` through `:285` and `:369` through `:385`.
- `amem` calls the app drain callback, then immediately reports drained at `_external/vlc/modules/audio_output/amem.c:136` through `:145`.

### 7. How are pause and resume handled?

The `pause` callback receives a Boolean and the request timestamp. VLC wants pause to stop producing sound quickly while retaining queued samples for later resume. If a backend cannot pause, the core flushes it when entering pause at `_external/vlc/include/vlc_aout.h:228` through `:242`.

The decoder-facing pause path also adjusts timing state so the last timing point remains meaningful across pause duration. It calls `aout->pause` when available, or flushes on pause if it is not available at `_external/vlc/src/audio_output/dec.c:978` through `:1024`.

Backend examples:

- WASAPI disarms timing, stops on pause, and restarts on resume at `_external/vlc/modules/audio_output/wasapi.c:322` through `:343`.
- PipeWire toggles stream active state and adjusts pending start timing at `_external/vlc/modules/audio_output/pipewire.c:330` through `:347`.
- JACK records the pause date and suppresses reading frames in its process callback while paused at `_external/vlc/modules/audio_output/jack.c:336` through `:347` and `:401` through `:411`.
- `amem` invokes separate app pause or resume callbacks if present at `_external/vlc/modules/audio_output/amem.c:111` through `:121`.

### 8. How are device selection and hotplug handled?

The common abstraction has an optional `device_select(audio_output_t *, const char *id)` callback at `_external/vlc/include/vlc_aout.h:285` through `:292`. Device and hotplug reports are sent through event callbacks at `_external/vlc/include/vlc_aout.h:128` through `:137` and helper functions at `_external/vlc/include/vlc_aout.h:366` through `:380`.

The common device setter calls backend `device_select` under the owner lock and fails if the backend does not provide one at `_external/vlc/src/audio_output/output.c:888` through `:897`. Device listing reads the owner device list populated by backend hotplug reports at `_external/vlc/src/audio_output/output.c:899` through `:946`.

Backend examples:

- MMDevice stores and loads a selected Windows endpoint, reports the default endpoint, loads a concrete stream backend such as WASAPI, and restarts or falls back when an endpoint is invalidated at `_external/vlc/modules/audio_output/mmdevice.c:1219` through `:1265`, `:1358` through `:1378`, and `:1550` through `:1563`.
- AUHAL sets `device_select = SwitchAudioDevice`, attaches Core Audio listeners for device-list and default-device changes, reads the stored `auhal-audio-device`, rebuilds the device list, and reports the selected device at `_external/vlc/modules/audio_output/apple/auhal.c:1711` through `:1788`.
- ALSA exposes `alsa-audio-device`, sets `device_select = DeviceSelect`, and reports startup enumeration, but notes that ALSA does not support hotplug events in this module at `_external/vlc/modules/audio_output/alsa.c:1108` through `:1124` and `:1196` through `:1204`.
- PulseAudio assigns `device_select = StreamMove`, listens for moved/latency/suspend/underflow callbacks, and can refuse to use PulseAudio when it is actually connected to PipeWire and the PipeWire backend exists at `_external/vlc/modules/audio_output/pulse.c:1107` through `:1134` and `:1240` through `:1264`.
- PipeWire can update a stream target by object serial and sets `device_select = DeviceSelect` while registry-listening to enumerate device nodes at `_external/vlc/modules/audio_output/pipewire.c:425` through `:436` and `:894` through `:929`.
- VLC 3.0 DirectSound exposes `directx-audio-device`, implements `DeviceSelect`, requests an output restart, enumerates devices, and notes that DirectSound itself does not support hotplug events unless via WASAPI at `_external/vlc-3.0/modules/audio_output/directsound.c:80` through `:83` and `:1052` through `:1088`.

### 9. How are latency and drift handled?

VLC treats the backend's output clock as a timing participant. `time_get` or timing reports describe actual output delay, and the decoder-facing stream converts media PTS to system render time, adjusts delay, synchronizes drift, and only then calls backend `play` at `_external/vlc/include/vlc_aout.h:185` through `:208` and `_external/vlc/src/audio_output/dec.c:891` through `:958`.

The abstraction is bounded:

- Backends report device or stream timing when they can.
- The common stream owns media-clock conversion and drift correction.
- Filters and volume sit before final backend playback.
- Flush and drain reset or complete timing state explicitly.

This is why the same core can support both callback-like outputs such as `amem` and clocked device backends such as WASAPI, AUHAL, JACK, and PipeWire.

### 10. Which backends support explicit device selection?

Supported in the inspected source:

- MMDevice / WASAPI path: MMDevice owns endpoint selection through `mmdevice-audio-device` and loads a concrete `aout stream` backend such as WASAPI at `_external/vlc/modules/audio_output/mmdevice.c:1237` through `:1242` and `:1562`.
- AUHAL / Core Audio: AUHAL sets `device_select = SwitchAudioDevice` and selects the AudioUnit device via `kAudioOutputUnitProperty_CurrentDevice` at `_external/vlc/modules/audio_output/apple/auhal.c:1055` through `:1064` and `:1734` through `:1738`.
- ALSA: the module exposes `alsa-audio-device` and sets `device_select = DeviceSelect` at `_external/vlc/modules/audio_output/alsa.c:1108` through `:1117` and `:1196` through `:1204`.
- PulseAudio: the module sets `device_select = StreamMove` at `_external/vlc/modules/audio_output/pulse.c:1240` through `:1246`.
- PipeWire: the module sets `device_select = DeviceSelect` and can update stream target properties at `_external/vlc/modules/audio_output/pipewire.c:425` through `:436` and `:914` through `:924`.
- VLC 3.0 DirectSound: `directx-audio-device` and `DeviceSelect` are present at `_external/vlc-3.0/modules/audio_output/directsound.c:80` through `:83` and `:1060` through `:1080`.

Limited or different:

- JACK has configurable client name and auto-connect regex, creates one port per output channel, and connects to matching JACK input ports, but it is not a simple OS-device picker in the same sense as MMDevice or AUHAL at `_external/vlc/modules/audio_output/jack.c:100` through `:115` and `:242` through `:276`.
- `amem` is an app callback output, not a device backend, and has no device selection at `_external/vlc/modules/audio_output/amem.c:333` through `:379`.

### 11. Which backends support high channel counts?

The safe answer is: VLC has some backend shapes that are pro-audio friendly, but the inspected stock output path does not prove 30-channel or 52-channel output.

High-channel-friendly backend shapes:

- JACK creates one JACK output port per VLC output channel and uses the JACK server's sample rate at `_external/vlc/modules/audio_output/jack.c:156` through `:184` and `:214` through `:280`.
- PipeWire maps unmapped channels to aux positions after standard positions and only rejects when `fmt->i_channels > SPA_AUDIO_MAX_CHANNELS` at `_external/vlc/modules/audio_output/pipewire.c:520` through `:555`.
- ALSA sets explicit channel count with `snd_pcm_hw_params_set_channels` and fails if the device cannot provide the requested channel count at `_external/vlc/modules/audio_output/alsa.c:860` through `:883`.

Stock VLC limitations:

- The common aout stream rejects mapped channel layouts above `AOUT_CHAN_MAX` and rejects input channel counts above `INPUT_CHAN_MAX` at `_external/vlc/src/audio_output/dec.c:342` through `:360`.
- The common mix-mode UI choices top out at 7.1, and Ambisonics output is constrained to 7.1 in the common output path at `_external/vlc/src/audio_output/output.c:594` through `:643` and `:725` through `:731`.
- Current `amem` caps callback output at 8 channels and rejects more at `_external/vlc/modules/audio_output/amem.c:33` through `:68` and `:284` through `:292`.
- VLC 3.0 DirectSound clamps Windows speaker configuration to mono, stereo, quad, 5.1, or 7.1 in the inspected path at `_external/vlc-3.0/modules/audio_output/directsound.c:681` through `:785`.

Conclusion: JACK and PipeWire are the most relevant VLC backend concepts for high channel counts, but they do not make stock VLC a proven 30-channel or 52-channel output engine for Orbisonic without a targeted harness and probably changes to VLC's common channel-layout assumptions.

### 12. Which backends are likely limited by OS shared-mode conversion?

Likely shared-mode or server-mixer conversion risk:

- WASAPI shared mode: the module defaults to `AUDCLNT_SHAREMODE_SHARED` unless `wasapi-exclusive` is set. Its option text says exclusive mode provides a direct connection and can assure the stream will not be modified by the OS, while also being more likely to fail if the soundcard format is unsupported at `_external/vlc/modules/audio_output/wasapi.c:844` through `:855` and `:955` through `:968`.
- DirectSound: the 3.0 source explicitly describes secondary buffers mixed by DirectSound into the primary buffer, then chooses speaker configurations up to 7.1 at `_external/vlc-3.0/modules/audio_output/directsound.c:377` through `:386` and `:681` through `:785`.
- PulseAudio: the module creates a server-managed playback stream with flags including automatic timing updates and fixed rate, then connects to a sink at `_external/vlc/modules/audio_output/pulse.c:960` through `:1030` and `:1107` through `:1140`.
- PipeWire: the module creates a PipeWire stream with autoconnect and notes an exclusive flag as a TODO, so the inspected implementation is a server-graph stream rather than a proven exclusive hardware path at `_external/vlc/modules/audio_output/pipewire.c:612` through `:616`.
- CoreAudio/AUHAL: AUHAL uses HAL AudioUnit output and device layouts, and CoreAudio may negotiate through the selected output unit; the inspected code logs and sets the current AU stream format but does not make a general 30-channel exclusive-output guarantee at `_external/vlc/modules/audio_output/apple/coreaudio_common.c:748` through `:790`.

ALSA is more nuanced. VLC disables ALSA auto-resampling and explicitly sets channels/rate at `_external/vlc/modules/audio_output/alsa.c:811` through `:890`, which makes failures visible for many strict devices. But the default ALSA device can still be a plugin route depending on the system configuration; Orbisonic should treat `default` differently from a proven strict hardware route.

### 13. Which backends can fail loudly instead of downmixing?

The following inspected paths have explicit failure points that can surface unsupported device or format behavior:

- WASAPI exclusive mode checks `IAudioClient_IsFormatSupported`; its option text says exclusive mode is more likely to fail when unsupported and can avoid OS modification at `_external/vlc/modules/audio_output/wasapi.c:627` through `:765` and `:955` through `:968`.
- ALSA reports errors when it cannot open the device, set format, set channels, or set sample rate at `_external/vlc/modules/audio_output/alsa.c:780` through `:890`.
- AUHAL fails if it cannot select the device, initialize/start the AudioUnit, or open analog/digital output, and reports an error when the selected SPDIF device is exclusively in use at `_external/vlc/modules/audio_output/apple/auhal.c:1055` through `:1104`, `:1149` through `:1156`, and `:1642` through `:1654`.
- JACK fails if it cannot connect to the JACK server, register output ports, activate the client, or allocate buffers at `_external/vlc/modules/audio_output/jack.c:142` through `:150`, `:214` through `:239`, and `:283` through `:285`.
- PipeWire fails on unknown formats or too many channels at `_external/vlc/modules/audio_output/pipewire.c:514` through `:528`.
- `amem` fails unsupported callback format/rate/channel count and rejects channel counts above 8 at `_external/vlc/modules/audio_output/amem.c:284` through `:292`.

Backends most likely to silently conform to consumer output are shared/server paths such as WASAPI shared, DirectSound, PulseAudio, PipeWire without an exclusive path, and CoreAudio through normal device format negotiation. They may still report useful negotiated formats, but Orbisonic should not treat them as proof that no downmix, remap, or resampling happened unless the backend exposes and logs that fact.

### 14. Does VLC include ASIO support, JACK support, PipeWire support, or other pro-audio paths relevant to 30 or 52 outputs?

ASIO: no ASIO backend was found in the inspected current or VLC 3.0 `modules/audio_output/` trees. The search for `ASIO|asio` returned no matches.

JACK: yes. Current VLC and VLC 3.0 both include `jack.c`. The current JACK backend is pro-audio relevant because it uses the JACK server clock/rate, creates one output port per VLC output channel, exposes graph-latency timing, and avoids OS consumer shared-mode routing at `_external/vlc/modules/audio_output/jack.c:119` through `:280` and `:462` through `:480`.

PipeWire: yes in current VLC, not in the inspected VLC 3.0 tree. The current PipeWire backend is pro-audio relevant because it supports explicit node targeting and aux channel positions, but the implementation uses autoconnect and leaves exclusive mode as TODO in the inspected source at `_external/vlc/modules/audio_output/pipewire.c:425` through `:436`, `:520` through `:555`, and `:612` through `:616`.

Other relevant paths:

- ALSA can be strict when pointed at an appropriate PCM device and currently disables ALSA's auto-resampler before setting hardware parameters at `_external/vlc/modules/audio_output/alsa.c:780` through `:890`.
- AUHAL/CoreAudio provides direct device selection, device-layout inspection, and latency accounting on macOS, but the inspected common VLC path and normal CoreAudio output do not prove Sonic Sphere-scale discrete output on their own.
- WASAPI exclusive mode is relevant for lower-latency and non-OS-modified Windows output, but it is not an Orbisonic macOS target and does not solve Sonic Sphere routing directly.

## Why VLC's Output Architecture Sounds Reliable

VLC's output architecture sounds reliable because it separates decisions into bounded ownership layers:

- The `audio_output_t` state machine is explicit: stopped, playing, paused, start, stop, play, pause, flush, drain.
- The output format is negotiated through a single `start` in/out format object and then logged by the common output path.
- Timing is a first-class backend contract through `time_get` or timing reports instead of an implicit guess.
- Flush and drain are separate operations: discard buffered audio versus let queued audio finish.
- Filters, volume, clock conversion, and drift correction happen before the backend device callback.
- Device selection and hotplug are backend-specific but report through common events.
- Backends expose where strict behavior is possible and where server or OS shared-mode behavior is likely.

The reliable part is not that VLC magically avoids bad audio. It is that VLC gives each backend a small contract and makes negotiation, timing, restart, and failure behavior visible enough for the core to manage.

## Comparison To Orbisonic

### Does Orbisonic have the same lifecycle clarity?

Partially.

The active app engine has `play`, `pause`, `stop`, output-device selection, seek, graph rebuild, and playback-frame methods in `OrbisonicEngine` at `Sources/Orbisonic/OrbisonicEngine.swift:640` through `:805`, `:978` through `:1035`, `:2102` through `:2185`, and `:2395` through `:2433`. These methods are concrete and understandable, but they are not a small backend-facing output contract with explicit `start`, `play(block,date)`, `pause/resume`, `flush`, `drain`, and `stop` semantics.

There is a more contract-shaped `AudioOutputAdapter` protocol in `Sources/AudioCore/OutputAdapters.swift:134` through `:143`, but it is currently an offline/validation-oriented adapter model and does not match the live AVAudioEngine output lifecycle.

### Does Orbisonic log the negotiated device format?

Partially, but not with VLC's clarity.

Orbisonic's route monitor models output device name, transport, output channel count, and nominal sample rate at `Sources/Orbisonic/OutputRouteMonitor.swift:4` through `:12` and displays route details at `Sources/Orbisonic/OutputRouteMonitor.swift:129` through `:139`. The engine chooses the Core Audio output device with `kAudioOutputUnitProperty_CurrentDevice` and logs the selected device ID at `Sources/Orbisonic/OrbisonicEngine.swift:735` through `:766`.

The engine also derives monitor channel count and preferred output sample rate from AVAudioEngine formats at `Sources/Orbisonic/OrbisonicEngine.swift:1158` through `:1165` and `:2228` through `:2235`.

What is missing compared with VLC is a single logged "requested format -> negotiated output format" record at output start, including route ID, requested channel count, actual hardware channel count, actual sample rate, processing format, channel layout, selected renderer/monitor mode, and whether any conversion path is active.

### Does Orbisonic know actual hardware latency?

No comparable live output latency owner was found in the inspected Orbisonic source.

The route model stores nominal sample rate and channel count, not device latency, at `Sources/Orbisonic/OutputRouteMonitor.swift:4` through `:12`. A targeted search found no `kAudioDevicePropertyLatency` or equivalent output hardware-latency query in `Sources/Orbisonic`, `Sources/AudioCore`, or `Sources/AudioContracts`.

Orbisonic does model live-input pipe target latency and buffer status for loopback capture at `Sources/Orbisonic/LiveAudioBridge.swift:502` through `:536` and `:539` through `:568`, but that is app-buffer latency, not actual output hardware latency.

### Does Orbisonic treat flush and drain differently?

Not with VLC's explicit output semantics.

Orbisonic `stop` cancels local gapless scheduling, stops player nodes, cancels streaming playback, stops live input/test tones, stops the engine, resets frame state, and returns to idle/ready at `Sources/Orbisonic/OrbisonicEngine.swift:788` through `:804`. Seek during playback stops and reschedules player nodes around the new frame at `Sources/Orbisonic/OrbisonicEngine.swift:1005` through `:1035`.

Those operations behave more like transport stop/reset/reschedule. The inspected engine code does not expose a backend-level distinction between "flush buffered output immediately" and "drain queued output until natural completion".

### Does Orbisonic have a clock owner?

Partially and implicitly.

For local playback progress, Orbisonic reads `lastRenderTime` and `playerTime(forNodeTime:)` from the first player node, adds the current start frame, and clamps to the source duration at `Sources/Orbisonic/OrbisonicEngine.swift:2395` through `:2433`. `startPlayers` starts player nodes at a host-time offset at `Sources/Orbisonic/OrbisonicEngine.swift:2222` through `:2225`.

This uses AVAudioEngine/AVAudioPlayerNode as the practical render clock, but the app does not yet have a named output-clock owner comparable to VLC's `vlc_clock` plus backend timing-report contract.

### Does Orbisonic make downmix or resampling explicit?

Downmix: yes for the Normal Monitor path. Normal monitor route planning is explicitly a stereo preview branch that must not be altered by production renderer mode or Sonic Sphere channel count at `Sources/Orbisonic/NormalMonitorRouteDescriptor.swift:80` through `:91`. Normal monitor pan/gain are computed through `NormalMonitorDownmixPolicy` at `Sources/Orbisonic/NormalMonitorRouteDescriptor.swift:95` through `:112`, and engine nodes apply those gains/pans at `Sources/Orbisonic/OrbisonicEngine.swift:2155` through `:2165`.

Production render kernels: yes, they reject sample-rate mismatches and report no sample-rate conversion in the audit object at `Sources/AudioCore/RenderKernels.swift:267` through `:273` and `:435` through `:452`.

Local gapless source conversion: partly explicit. `LocalAudioFileSource` creates an `AVAudioConverter` when processing format does not match the requested output format and computes output frame capacity from the source/output sample-rate ratio at `Sources/Orbisonic/LocalAudioFileSource.swift:91` through `:96` and `:248` through `:256`.

Remaining gap: the live AVAudioEngine output path does not have VLC-style negotiated-output logging that proves whether Core Audio or AVAudioEngine inserted output conversion for a selected device.

## Concepts Orbisonic Could Imitate Safely

Orbisonic should not copy VLC code. The useful takeaways are contracts and diagnostics:

1. Add a small live output-session contract with explicit `prepare/start/play/pause/flush/drain/stop` semantics for Orbisonic-owned device output. It can stay Swift-native and AVAudioEngine/CoreAudio-based.
2. Record negotiated output format as a structured event whenever output starts or restarts: requested format, actual engine output format, device route, nominal device sample rate, output channel count, channel layout, renderer mode, monitor mode, and conversion flags.
3. Add an output timing owner that records actual hardware or backend latency when available, plus the render-clock source used for progress and drift decisions.
4. Separate flush and drain semantics in transport and output code. Stop/seek should flush; natural track end and gapless boundaries should drain or explicitly state why they do not.
5. Give each output route a capability record: explicit device selection, hotplug confidence, max exposed channels, strict sample-rate behavior, shared-mode conversion risk, failure-loudness, measured latency, and whether high-channel direct output is proven.
6. Make downmix and resampling ledgers user-visible in diagnostics. Orbisonic already has many of the pieces; the gap is a single negotiated output report that proves the active device path.
7. Treat pro-audio output as a route class, not as a VLC dependency. JACK and PipeWire are useful architecture references for per-channel ports, graph latency, and strict routing, but Orbisonic's active macOS product should keep Core Audio ownership unless a future contract explicitly changes the output backend.

## Verdict

Orbisonic should imitate VLC's output architecture concepts, not reuse VLC's device backends.

VLC's `audio_output_t` contract is a strong reference for lifecycle clarity, negotiated format logging, timing reports, flush/drain separation, and backend capability reporting. Reusing VLC platform output directly would hand device ownership, conversion, and route behavior to VLC, which conflicts with Orbisonic's Sonic Sphere routing, Normal Monitor policy, Direct 30/30.1 semantics, and live diagnostics.

The highest-value next step is an Orbisonic-native output-session audit/design pass: define what the live output contract should report, then add diagnostics before changing behavior.
