# Task 10 - Architecture Decision Comparison

## Scope

Task 10 compares Orbisonic's current playback architecture against VLC's architecture to identify design differences that plausibly explain why VLC standalone playback can sound correct while Orbisonic playback can sound bad.

This is a diagnostic comparison, not an implementation recommendation. The evidence is not yet decisive enough to choose a replacement path. No Orbisonic app code, tests, scripts, resources, installer files, vendor files, calibration files, or binary media assets were changed.

## Source Basis

This synthesis uses the previous investigation files:

- `docs/audio-vlc-investigation/task-01-baseline.md`
- `docs/audio-vlc-investigation/task-02-orbisonic-architecture.md`
- `docs/audio-vlc-investigation/task-03-playback-module-boundaries.md`
- `docs/audio-vlc-investigation/task-04-bad-audio-reproduction.md`
- `docs/audio-vlc-investigation/task-05-reference-tests.md`
- `docs/audio-vlc-investigation/task-06-vlc-source-map.md`
- `docs/audio-vlc-investigation/task-07-libvlc-callback-bridge.md`
- `docs/audio-vlc-investigation/task-08-vlc-aout-and-device-backends.md`
- `docs/audio-vlc-investigation/task-09-vlc-channel-feasibility.md`

Key current-state facts from those files:

- Orbisonic is a native Swift/AVFoundation/Core Audio app with separate local-file, live-loopback, normal-monitor, renderer/meter, and PureAudio contract layers.
- Orbisonic local paths normalize decoded audio toward Float32 non-interleaved PCM and preserve source channel count where admitted.
- Orbisonic's current audible monitor path is a two-channel AVAudioEngine normal monitor path, not a direct audible 30.1 Sonic Sphere output path.
- Orbisonic has custom Direct 30 and Direct 31 renderer semantics, and a 64-channel source cap, but no automatic Direct 52 renderer mode.
- VLC is a layered media engine: access/demux/decode in the input pipeline, filter and audio-output orchestration in `src/audio_output/`, and platform output modules under `modules/audio_output/`.
- VLC has better ordinary media-player codec/container/protocol breadth and clearer output lifecycle/timing contracts.
- VLC's mapped speaker model is capped at 9 standard bitmap speaker channels, and stock current `amem` callback output is capped at 8 channels.

## Decision Comparison

### 1. Media Opening

Orbisonic does:

- Local file opening is owned by `AudioFileProbe`, `AudioFileLoader`, `StreamingAudioFileSource`, and `LocalAudioFileSource`.
- No active Plex `Part.key` playback owner was found in current source during Task 1 and Task 2.
- NAS handling is effectively mounted-local-file handling, not a separate SMB/NAS protocol reader.
- Matroska/FLAC and FLAC fallback paths use ffmpeg-assisted temporary conversion when AVFoundation cannot open the source directly.
- Error handling is app-specific: local load status, route/source diagnostics, and typed loader errors.

VLC does:

- VLC has a mature access/demux architecture for local files, network URLs, redirects, range behavior, and container probing.
- Public libVLC accepts media locations, media options, and input callbacks.
- VLC's HTTP access supports standard redirects and selected request options such as user-agent, referrer, and cookies, but arbitrary Plex headers were not proven through the stock URL path in Task 7.

Why Orbisonic may have chosen its approach:

- Orbisonic is local-first and audio-route-first. Its source model has to distinguish Local Files, Roon, Spotify, Aux, Test Tone, and Off rather than behave like one general media URL player.
- AVFoundation/Core Audio are native, easy to bundle, and aligned with a Swift macOS app.
- Mounted local files and local-library state are simpler and safer than owning a general network media stack.

Why VLC likely chose its approach:

- VLC is a general media player and multimedia engine. It needs access modules, demuxers, probes, redirects, options, and fallback behavior for many containers and protocols.
- Its architecture lets the same source stack feed device output, file output, memory callbacks, and different platform backends.

Better for ordinary playback:

- VLC. Its media-opening layer is broader and more battle-tested for container/protocol variation.

Better for 30 and 52 channel spatial playback:

- Orbisonic for app-owned local CAF/direct-discrete fixtures and selected live sources, because it can preserve an Orbisonic-specific source contract. VLC is not proven to preserve custom 30/52 identities through its normal mapped-speaker model.

How this difference could produce bad audio:

- If the problematic media uses a container, codec, remote URL, range behavior, or metadata shape that AVFoundation/Orbisonic fallback handles poorly but VLC handles correctly, corruption can happen before Orbisonic's renderer or output code sees PCM.
- If Plex or NAS delivery differs from local byte-for-byte media, Orbisonic may be testing a different source than VLC.

Test to confirm or reject:

- Use the Task 5 representative real-media harness. Compare source bytes, ffprobe metadata, trusted ffmpeg decode, VLC decode or callback capture, and Orbisonic post-decode PCM before channel split. For Plex/NAS, prove whether the delivered bytes and container metadata match the local reference.

### 2. Demux And Decode

Orbisonic does:

- AVFoundation/`AVAudioFile` owns most local demux/decode.
- Matroska/FLAC and some FLAC failure cases use ffmpeg-assisted conversion to CAF before `AVAudioFile` reads the result.
- Live Roon and Aux paths do not demux/decode in Orbisonic; they capture already-produced Core Audio PCM from loopback devices.
- Spotify is a separate embedded receiver boundary, not the local file decoder.
- Timestamp handling is mostly source-frame and AVAudioPlayerNode based, not a full media PTS pipeline.

VLC does:

- VLC has dedicated access, demux, packetizer, decoder, and audio-output stream boundaries.
- Decoded audio is queued into `vlc_aout_stream_Play`, then filtered, synchronized, and sent to a selected output backend.
- VLC has broad codec coverage and recovery logic across many demuxer/decoder modules.
- VLC callbacks deliver decoded and post-processed samples asynchronously from an internal thread.

Why Orbisonic may have chosen its approach:

- Native decode reduced dependency and licensing complexity.
- The app's value is routing and Sonic Sphere rendering, not being a universal codec player.
- The live paths are already PCM and need route diagnostics more than demuxers.

Why VLC likely chose its approach:

- General playback requires broad container and codec support, timestamp continuity, bad-packet tolerance, and reusable decode across many output modes.

Better for ordinary playback:

- VLC. It is designed to survive varied files and imperfect streams.

Better for 30 and 52 channel spatial playback:

- Mixed. Orbisonic is better if its decoder actually preserves every source channel and layout. VLC can admit some unmapped counts internally, but Task 9 did not prove 30/52 preservation through callback/output/filter paths.

How this difference could produce bad audio:

- AVFoundation or the ffmpeg-to-CAF fallback could decode the same media differently from VLC, trim/pad incorrectly, lose layout metadata, change channel order, or mishandle an uncommon codec/container.
- VLC may sound good simply because it decodes the source correctly before ordinary stereo output, not because its output model is suitable for Sonic Sphere.

Test to confirm or reject:

- Capture Orbisonic PCM immediately after `AudioFileLoader`, `StreamingAudioFileSource`, or `LocalAudioFileSource` conversion. Compare channel hashes, impulse offsets, peak/RMS, duration, and layout metadata against ffmpeg and VLC callback/file captures.

### 3. PCM Format

Orbisonic does:

- Current local and live paths normalize toward Float32 non-interleaved PCM.
- Prepared loading splits multichannel buffers into one mono buffer per source channel.
- Streaming/gapless paths also shape chunks for per-channel scheduling.
- Live capture requests Float32 non-interleaved data from the HAL input unit and copies samples into ring buffers.
- AudioCore contracts reject format mismatches for production-style render kernels.

VLC does:

- VLC internally handles multiple PCM formats and converter filters.
- Current libVLC `amem` can request `S16N`, `S32N`, or `FL32`, but callback samples are interleaved for multichannel audio according to the public callback format contract recorded in Task 7.
- VLC filter/resampler modules generally require matching channel counts across conversion boundaries.

Why Orbisonic may have chosen its approach:

- Float32 non-interleaved buffers fit AVAudioEngine, meters, matrix renderers, and per-channel Sonic Sphere processing.
- One-channel buffers make direct channel identity easier to reason about.

Why VLC likely chose its approach:

- General media playback needs to accept and convert many sample formats, including packed/interleaved layouts that match common backend APIs.

Better for ordinary playback:

- VLC. Flexible PCM conversion is better for varied sources and devices.

Better for 30 and 52 channel spatial playback:

- Orbisonic, if all conversion boundaries are verified. Non-interleaved explicit channels are safer for a custom renderer than opaque interleaved callback memory.

How this difference could produce bad audio:

- A planar/interleaved mismatch, int/float scale mismatch, endian mismatch, or normalization error can produce clipping, noise, channel bleed, or harsh output even if the decoder itself is correct.
- A future VLC callback bridge could easily corrupt Orbisonic if interleaved `FL32` samples were copied as if they were planar channel buffers.

Test to confirm or reject:

- Use int16, int24, int32, and Float32 impulse fixtures. Compare post-conversion Orbisonic Float32 samples against a trusted canonical decode within the Task 5 tolerances. Include per-channel inactive-floor checks below -96 dBFS.

### 4. Resampling

Orbisonic does:

- No broad hidden local/live resampler owner was found in Tasks 2 and 3.
- Prepared and streaming local paths generally preserve source sample rate in their output PCM.
- Live path treats source/route sample-rate mismatch as diagnostic risk, not a hidden repair.
- AudioCore production-style validation rejects mismatched sample rates and records no sample-rate conversion in render audits.
- Core Audio or AVAudioEngine may still convert to the selected device format, but Orbisonic does not currently emit one VLC-style negotiated-output record proving the exact active conversion state.

VLC does:

- VLC inserts resamplers after channel/filter conversion when input and output rates differ.
- VLC's audio-output stream owns clock conversion, drift correction, and backend timing reports.
- Resampler modules reject unequal channel counts and do not perform remapping.
- Some VLC backends try to set strict device rates; others run through shared/server conversion paths.

Why Orbisonic may have chosen its approach:

- Sample-rate mismatch can be dangerous in live loopback and Sonic Sphere contexts, so making mismatch visible is safer than silently repairing it.
- Avoiding a hidden resampler preserves evidence when diagnosing routing and hardware configuration.

Why VLC likely chose its approach:

- Ordinary media playback must play 44.1, 48, 96, and other rates on whatever device is selected. Resampling and drift correction are necessary for a consumer media player.

Better for ordinary playback:

- VLC. It is built to adapt source rate to output rate and maintain sync.

Better for 30 and 52 channel spatial playback:

- Orbisonic's explicit validation is better for production truth, but only if diagnostics show the real output route and no hidden Core Audio conversion. A high-quality explicit resampler may be needed later, but that is not proven by Task 10.

How this difference could produce bad audio:

- If Orbisonic preserves source rate but AVAudioEngine/Core Audio converts later without a clear ledger, the audible path may contain unknown SRC. If another conversion happens earlier, there may be double SRC.
- Sample-rate mismatch can also make live loopback capture silent, unstable, or misleading while VLC standalone adapts gracefully.

Test to confirm or reject:

- For 44.1, 48, and 96 kHz fixtures, record source rate, post-decode rate, scheduler/session rate, AVAudioEngine output format, selected device nominal rate, and captured output if possible. Compare against VLC logs/capture for the same media and route.

### 5. Channel Layout

Orbisonic does:

- Orbisonic owns custom layout language through runtime `ChannelRoleLayout`/`SurroundLayoutDetector` and PureAudio layout descriptors.
- It models Direct 30 and Direct 31 as custom/direct layouts and has fallback layouts for arbitrary admitted source counts.
- The normal monitor path is explicitly separate from production Sonic Sphere routing.
- Current Task 3 evidence did not identify an active Ambisonics decoder; Orbisonic's renderer is static-bed/discrete-channel oriented.

VLC does:

- VLC uses a bitmap speaker layout for known standard channels, capped at 9 mapped channels.
- VLC's canonical internal mapped order is WG4.
- VLC has explicit reorder and extraction helpers.
- VLC marks Ambisonics through `channel_type` and renders supported Ambisonics order 1 through 3 into binaural or standard speaker layouts.
- Unknown channel maps can be converted to WAVE physical order, capped at 9, with extra channels dropped when a mapped output is needed.

Why Orbisonic may have chosen its approach:

- Sonic Sphere is not a standard 7.1 speaker target. Orbisonic needs custom direct/discrete identity, renderer modes, and diagnostics.

Why VLC likely chose its approach:

- Standard media playback benefits from known surround roles, common speaker orders, Ambisonics rendering, and per-backend remap to consumer/pro-audio outputs.

Better for ordinary playback:

- VLC. It has clearer standard surround and Ambisonics handling.

Better for 30 and 52 channel spatial playback:

- Orbisonic. VLC's mapped model cannot represent Orbisonic's 30/52 speaker identities, and stock callback output cannot deliver those counts.

How this difference could produce bad audio:

- Orbisonic may misdetect or low-confidence-map ordinary 5.1/7.1 layouts that VLC handles with mature role/order logic.
- VLC may sound correct in stereo because it downmixes or maps standard roles well, while Orbisonic may route center, LFE, side, rear, or high-numbered discrete channels incorrectly.

Test to confirm or reject:

- Use 5.1, 7.1, Ambisonics-labeled, Direct 30, and 52-channel impulse fixtures. Verify source channel N, role labels, renderer input N, monitor downmix coefficient, and output/meter channel independently.

### 6. Buffer Ownership

Orbisonic does:

- Prepared local playback can retain full decoded mono buffers.
- Streaming/gapless playback retains scheduled chunks and uses completion callbacks to release buffers.
- `LocalGaplessScheduler` uses generation counters and a serial queue to avoid stale scheduled work.
- Live capture copies HAL callback samples into `LiveAudioPipe` ring buffers.
- Metering is copy-only by design and must not consume live playback buffers.

VLC does:

- VLC uses block ownership through decoder/filter/aout paths. Backends or callbacks receive blocks, then release or queue them according to a small output contract.
- `amem` passes sample pointers to the app callback, then releases the VLC block.
- Backend examples such as JACK and PipeWire own explicit queues/rings and report consumption/timing.

Why Orbisonic may have chosen its approach:

- AVAudioPlayerNode scheduling and live HAL callbacks require retained buffers or rings in Swift/AVFoundation.
- Per-channel buffers match renderer and meter needs.

Why VLC likely chose its approach:

- C block ownership and backend contracts scale across many decoders, filters, outputs, and platforms.

Better for ordinary playback:

- VLC. Its block lifecycle is simpler and more uniform.

Better for 30 and 52 channel spatial playback:

- Orbisonic, if generation counters and retention are correct, because per-channel buffers and rings preserve custom identities. It is also higher risk because more app-owned buffer transitions exist.

How this difference could produce bad audio:

- Stale buffers after seek/source switch, retained chunks released too early, live-ring underflow, callback lifetime mistakes, or copying from interleaved memory into mono buffers incorrectly can create repeats, gaps, distortion, or channel bleed.

Test to confirm or reject:

- Run impulse fixtures through seek, pause/resume, stop, source switch, and long 30-channel noise sweeps. Assert no stale samples from previous generations, no inactive-channel bleed, no underflow/drop counter growth, and no retained-buffer mismatch.

### 7. Thread Ownership

Orbisonic does:

- UI/source state lives in `OrbisonicViewModel`.
- Prepared local decode runs off the main actor.
- Streaming/gapless scheduling uses a serial scheduler queue.
- AVAudioEngine render callbacks and HAL input callbacks are realtime audio boundaries.
- Live capture writes to rings from the HAL callback; source nodes read from rings during render.

VLC does:

- VLC's access/demux/decode pipeline, internal callback delivery, and audio-output backend callbacks are separate internal threads or backend callbacks.
- Public callback docs warn that decoded audio callbacks are asynchronous and that input callbacks must avoid deadlocks.
- Output backends isolate their realtime process callbacks from core decode where needed.

Why Orbisonic may have chosen its approach:

- Native Swift app structure, AVAudioEngine, and HAL capture dictate several thread domains.
- Source-specific diagnostics and SwiftUI state are app concerns.

Why VLC likely chose its approach:

- A general media engine needs strict separation between I/O, decode, filters, device callbacks, and UI/control APIs.

Better for ordinary playback:

- VLC. It has mature separation for general media pipeline threading.

Better for 30 and 52 channel spatial playback:

- Orbisonic can be better if it keeps realtime render work small and preserves per-channel rings, but this is a higher-risk custom path.

How this difference could produce bad audio:

- Blocking decode or file I/O on a scheduler/render boundary can starve buffers. UI-triggered source changes can race with scheduled chunks. Live input and output threads can drift without a clear bridge clock.

Test to confirm or reject:

- Add timing instrumentation around decode, scheduler refill, player-node scheduling, HAL input writes, live source-node reads, and render callbacks. Stress with long 30-channel and 52-channel fixtures while recording queue depth, underflows, and scheduler lag.

### 8. Clock Ownership

Orbisonic does:

- Local playback progress is frame-based and uses `AVAudioPlayerNode.lastRenderTime`/`playerTime`.
- Streaming chunks track source frame ranges.
- Live capture has ring-buffer latency counters.
- No active VLC-style media clock plus backend timing-report owner was identified.
- Output hardware latency is not currently modeled with the same clarity as VLC backend timing.

VLC does:

- VLC's audio-output stream converts media PTS to system render time.
- Backends report latency through `time_get` or timing reports.
- VLC uses backend timing for synchronization, drift correction, pause timing, and drain behavior.

Why Orbisonic may have chosen its approach:

- AVAudioEngine provides practical render timing for local player nodes.
- The app's early focus appears to have been routing, metering, and source separation rather than a full media-clock subsystem.

Why VLC likely chose its approach:

- A media player must synchronize audio/video/subtitles, keep long-running playback stable, and handle device-specific latency.

Better for ordinary playback:

- VLC.

Better for 30 and 52 channel spatial playback:

- Orbisonic's frame-domain approach is acceptable for deterministic offline-like channel preservation, but a production high-channel live output still needs explicit device-clock and latency ownership.

How this difference could produce bad audio:

- Drift, wrong start host time, inaccurate latency, or missing output timing can produce crackles, buffer starvation, repeated chunks, or subjective harshness, while VLC's backend timing keeps ordinary playback stable.

Test to confirm or reject:

- Log media/source frame, scheduled frame, AVAudioPlayerNode frame, host time, output route sample rate, output latency if available, and live ring latency for the same playback. Check for monotonicity and drift across a long sweep.

### 9. Flush, Drain, And Seek

Orbisonic does:

- `OrbisonicEngine.stop` resets local, streaming, live, and test-tone paths.
- Seek stops/reschedules prepared or streaming playback around a target frame.
- `LocalGaplessScheduler` invalidates generations, closes stale future sources, refills after seek, and releases retained buffers on completion.
- No general runtime drain API was found for "let queued output finish naturally."

VLC does:

- VLC has separate `flush` and `drain` semantics at the output contract.
- Flush discards pending buffers.
- Drain lets already queued audio complete and reports drained.
- Pause/resume adjusts timing and can retain queued samples.

Why Orbisonic may have chosen its approach:

- AVAudioPlayerNode and scheduler completion callbacks encourage transport-level stop/reschedule semantics.
- The app needs source-switch safety more than media-player drain correctness in its current state.

Why VLC likely chose its approach:

- Gapless playback, end-of-stream behavior, pause/resume, seek, and backend latency all require explicit distinction between discard and complete.

Better for ordinary playback:

- VLC.

Better for 30 and 52 channel spatial playback:

- Orbisonic's generation invalidation is valuable for source isolation, but high-channel production still needs unambiguous flush/drain behavior to avoid stale or truncated channel beds.

How this difference could produce bad audio:

- Stale queued buffers can play after seek/source switch. Natural end may cut off queued audio. Pause/resume may duplicate or skip frames. These can make Orbisonic sound broken while VLC's lifecycle handles the same user action cleanly.

Test to confirm or reject:

- Use impulse fixtures with known frames before and after seek points. Exercise seek, pause/resume, stop/start, and natural end. Verify each impulse appears once, stale previous-source samples never appear, and final queued frames are either drained or explicitly discarded according to the operation.

### 10. Device Negotiation

Orbisonic does:

- `OutputRouteMonitor` records device name, transport, output channel count, and nominal sample rate.
- `OrbisonicEngine` selects a Core Audio output device through the output node's audio unit.
- The audible monitor graph is currently stereo normal monitor into AVAudioEngine's main mixer.
- AudioCore has stricter output-adapter validation for desktop stereo and Dante/Sonic Sphere physical output plans, but those contracts are not proof of the live AVAudioEngine path.
- Hardware-only behavior remains manual.

VLC does:

- VLC output backends negotiate device formats through a common `audio_output_t` lifecycle.
- Backends report timing, selected device, output format, latency, and failure conditions with backend-specific detail.
- Some VLC backends can fail loudly when a device cannot accept a requested format; others use shared/server paths that may convert.

Why Orbisonic may have chosen its approach:

- AVAudioEngine is the native macOS output engine and convenient for selected-device output.
- Orbisonic's current monitor path prioritizes setup/preview and diagnostics over owning every backend detail.

Why VLC likely chose its approach:

- VLC must run on many OS backends and make backend negotiation explicit enough for reliable ordinary playback.

Better for ordinary playback:

- VLC. Its output abstraction gives more mature backend negotiation and timing clarity.

Better for 30 and 52 channel spatial playback:

- Neither is proven by default. Orbisonic's product contract is more relevant, but it needs a live output-session audit to prove actual high-channel device negotiation. VLC's stock mapped model is not enough.

How this difference could produce bad audio:

- Orbisonic may think it selected the right route but actually run through a stereo/shared-mode/Core Audio conversion path. Device sample rate, channel count, layout, or latency may differ from assumptions. VLC may choose or adapt to a better ordinary output path automatically.

Test to confirm or reject:

- At output start/restart, record requested source/monitor/render format, AVAudioEngine connection formats, selected Core Audio device ID, actual output format, device nominal sample rate, channel count, and latency where available. Compare to VLC's logged backend negotiation and external capture when possible.

### 11. Gain And Mixing

Orbisonic does:

- Normal monitor pan/gain are applied per source/player node.
- There is an output-gain mixer before the main mixer.
- Metering must not mutate audible output, and tests cover some normal-monitor and Sonic Sphere metering isolation.
- Direct 30/31 renderer semantics are intended to preserve direct channel identity when source width matches.

VLC does:

- VLC applies filters, then software volume, then backend playback in the decoder-facing output path.
- Downmix choices are explicit in common output mode selection and channel-mixer modules.
- VLC's ordinary downmix and volume behavior is designed for consumer playback and standard layouts.

Why Orbisonic may have chosen its approach:

- Per-channel gain/pan makes stereo monitor preview possible while keeping production topology conceptually separate.
- Sonic Sphere requires custom renderer/matrix behavior outside standard media-player downmix.

Why VLC likely chose its approach:

- Users expect volume, stereo output, standard surround folds, and device-compatible playback even when the source is multichannel.

Better for ordinary playback:

- VLC, because its downmix/volume pipeline is a mature ordinary media-player path.

Better for 30 and 52 channel spatial playback:

- Orbisonic, provided Direct 30 and future high-channel policies remain explicit and do not silently pass through normal consumer downmix.

How this difference could produce bad audio:

- Wrong normal-monitor coefficients, duplicate channels, hidden gain, output gain too high, or LFE/center handling mistakes can make audio harsh, right-heavy, hollow, clipped, or spatially wrong even with correct decoded PCM.

Test to confirm or reject:

- Use per-channel impulse and pink-noise fixtures. Capture post-decode, post-monitor-mix, post-render, and meter snapshots. Verify expected gain in dB, no clipping, no duplicate channel contribution, no unexpected LFE fold, and inactive channels below the tolerance.

### 12. Failure Policy

Orbisonic does:

- Many audio-specific failure states are intentionally visible: route mismatch, sample-rate mismatch, channel-count mismatch, permission denial, underflow, dropped frames, all-zero live input, and Roon downmix warnings.
- The app does not generally hide live-source failure by substituting fake audio.
- Some ordinary playback paths may still fall back through AVFoundation or ffmpeg without a single end-to-end conversion ledger.

VLC does:

- VLC often falls back or adapts for ordinary playback: resampling, downmixing, shared-mode output, and device-compatible formats.
- Some backends can fail loudly in strict modes, but shared/server outputs may conform to the system route.
- VLC warnings and logs can reveal conversion and backend behavior if captured.

Why Orbisonic may have chosen its approach:

- Audio truth matters for Sonic Sphere and live loopback. Bad routes should be diagnosed rather than hidden.

Why VLC likely chose its approach:

- Consumer playback should usually produce audible output even when source and device do not match.

Better for ordinary playback:

- VLC. It is more likely to make a difficult file audible.

Better for 30 and 52 channel spatial playback:

- Orbisonic, because silent downmix or fallback to stereo would be a wrong production result.

How this difference could produce bad audio:

- VLC may avoid the symptom by gracefully adapting to stereo/output constraints. Orbisonic may expose the underlying mismatch or partially adapt through AVAudioEngine without a clear ledger, producing bad audio instead of either clean playback or loud failure.

Test to confirm or reject:

- For each failure class, record whether Orbisonic rejects, warns, falls back, downmixes, resamples, or proceeds silently. Run the same media through VLC with verbose logs and compare what each system changed before audio reached the output.

## Ranked Likely Root Causes

### 1. Decode or PCM conversion corruption before Orbisonic routing

Evidence so far:

- Tasks 2 and 3 show Orbisonic relies on AVFoundation/`AVAudioFile`, `AVAudioConverter`, Matroska/FLAC ffmpeg fallback, and per-channel Float32 splitting.
- Task 4 defines decode corruption and format conversion error as first-class failure classes.
- Task 5 defines exact post-decode capture points and tolerances because this stage is not yet objectively proven against representative bad media.

Why it explains the symptoms:

- If Orbisonic's decoded PCM already differs from a trusted decode, every downstream renderer, meter, monitor, or output route can sound bad while VLC standalone sounds good.
- Harshness, clipping, wrong channel energy, endian/scale mistakes, and missing channels can all originate here.

Why VLC would avoid it:

- VLC has broader demux/decode coverage and mature conversion filters for ordinary playback. It may decode the problematic file correctly where AVFoundation or the app's fallback path does not.

Specific next test:

- Capture Orbisonic post-decode/post-conversion Float32 per-channel PCM for the exact problematic media and compare it against ffmpeg and VLC callback/file decode. Do not involve Sonic Sphere rendering or device output in this first comparison.

### 2. Output device negotiation or hidden output conversion in the normal monitor path

Evidence so far:

- Task 3 shows Orbisonic writes audible output through an AVAudioEngine stereo normal monitor graph.
- Task 8 shows VLC's output path has a clearer lifecycle, backend format negotiation, timing reports, flush/drain, and backend capability/failure reporting.
- Task 8 also found Orbisonic does not currently log one complete "requested format to negotiated output format" record comparable to VLC.

Why it explains the symptoms:

- The same correct PCM can sound bad if Core Audio/AVAudioEngine converts to an unexpected sample rate, channel count, route, format, or latency state.
- VLC may sound good because it adapts to the device format or reports and corrects timing more robustly.

Why VLC would avoid it:

- VLC makes output negotiation a first-class backend contract and applies filters, volume, drift correction, and timing before backend playback.

Specific next test:

- Record source rate/channel count, AVAudioEngine connection formats, selected output route, actual output unit format, nominal device rate, output channel count, and latency where available while playing the same fixture in Orbisonic and VLC.

### 3. Channel layout or channel-order mismatch

Evidence so far:

- Task 3 shows Orbisonic owns custom layout detection, per-channel splits, normal monitor policy, and Direct 30/31 renderer modes.
- Task 9 shows VLC has strong ordinary WG4/mapped-channel handling but cannot represent custom 30/52 mapped speaker identity.
- Task 4 identifies channel routing error as a core failure class.

Why it explains the symptoms:

- Wrong center/LFE/side/rear interpretation can make music sound unbalanced, hollow, right-heavy, harsh, or missing key content.
- VLC may sound good by applying mature standard surround/downmix rules, while Orbisonic may use a low-confidence or wrong local interpretation.

Why VLC would avoid it:

- For ordinary stereo, 5.1, 7.1, and supported Ambisonics, VLC has explicit mapped channel order, reorder, extraction, and downmix logic.

Specific next test:

- Run 5.1, 7.1, Direct 30, and 52-channel impulse fixtures. Verify channel identity at post-decode, post-split, renderer input, normal monitor mix, and output/capture. Include explicit LFE and center assertions.

### 4. Buffer scheduling, stale buffers, or seek/flush behavior

Evidence so far:

- Task 3 shows Orbisonic uses prepared buffers, streaming chunks, `LocalGaplessScheduler`, generation counters, completion release, and source-node live rings.
- Task 8 shows VLC has explicit flush and drain semantics at the audio-output boundary.
- Task 5 requires seek/pause/resume/flush/drain facts because stale buffers are a realistic architecture risk.

Why it explains the symptoms:

- Bad audio may be repeated samples, old source samples after a switch, missing chunks, queue starvation, or bursty underflow rather than decode failure.
- The issue can be intermittent and easier to miss than static channel-order errors.

Why VLC would avoid it:

- VLC's output lifecycle separates flush from drain, uses backend timing, and owns block queues in a uniform playback pipeline.

Specific next test:

- Use impulse and pink-noise sweep fixtures. Exercise seek, pause/resume, stop/start, source switch, and natural end. Assert generation IDs, scheduled ranges, retained buffer counts, and rendered frames match the intended operation.

### 5. Gain, downmix, or duplicate-channel error in the normal monitor branch

Evidence so far:

- Task 2 and Task 3 show the current audible path is normal monitor stereo, while Sonic Sphere matrices are separate.
- Task 4 identifies gain/mixing error as a failure class and points to normal monitor gain/pan and meter isolation tests.
- Task 8 shows VLC's ordinary playback path has explicit software volume and known downmix modules.

Why it explains the symptoms:

- Even with correct decode and routing, bad gain coefficients, duplicate feeds, clipping, LFE leakage, or wrong pan can make playback subjectively bad.
- VLC may sound good because its ordinary stereo downmix is conventional.

Why VLC would avoid it:

- VLC uses established ordinary downmix/volume behavior for standard layouts and keeps software volume in the output stream path.

Specific next test:

- Capture post-monitor-mix PCM for stereo, 5.1, 7.1, and Direct 30 fixtures. Check expected coefficients, peak/RMS, clipping, inactive-channel leakage, duplicate contribution, and output gain.

### 6. Resampling or clock drift issue

Evidence so far:

- Task 3 found no broad active Orbisonic local/live resampler owner; Orbisonic mostly preserves source rate and validates mismatch.
- Task 8 shows VLC's output stream handles timing, drift correction, and resampler insertion.
- Task 4 lists sample-rate mismatch as a required diagnostic dimension.

Why it explains the symptoms:

- If source, engine, live input, and output route rates differ, Orbisonic may suffer hidden Core Audio conversion, underflow, or drift while VLC adapts more gracefully.

Why VLC would avoid it:

- VLC owns SRC and drift correction as part of ordinary playback.

Specific next test:

- Run 44.1, 48, and 96 kHz fixtures on the same selected output. Record every rate boundary and measure drift over time against source frame positions and external capture if available.

## Diagnostic Bottom Line

The real architectural difference is not simply "VLC uses better audio code." VLC is stronger at ordinary media-player responsibilities: source access, demux/decode breadth, standard channel layouts, resampling, clocking, flush/drain, and device negotiation. Orbisonic is stronger at preserving product-specific intent: selected-source isolation, live loopback diagnostics, Sonic Sphere 30.1 topology, Direct 30/31 semantics, and explicit high-channel truth.

That means VLC can sound better for ordinary playback while still being the wrong owner for Orbisonic's 30/52-channel spatial identity. The next diagnostic work should prove where Orbisonic first diverges from trusted PCM: source open/decode, PCM conversion, channel layout, scheduler/clock, monitor mix, or actual output device negotiation.
