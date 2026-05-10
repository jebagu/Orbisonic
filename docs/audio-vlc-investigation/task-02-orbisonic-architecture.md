# Task 02 - Orbisonic Playback Architecture

## Scope

This note maps Orbisonic's current audio playback architecture before any VLC/libVLC decision is made. It uses the Task 01 baseline in `docs/audio-vlc-investigation/task-01-baseline.md` and current source inspection in this repository.

No app code was changed for this task. This document does not propose VLC, libVLC, FFmpeg, AVFoundation, or any other replacement. It only records how playback is currently structured.

## Baseline From Task 01

- Repository root for this investigation: `<repo-root>`.
- Baseline commit at Task 01 start: `a81af94927857569d39e4e8a24abec391206abf1`.
- Pre-existing untracked investigation prompt file: `orbisonic_vlc_codex_prompt_sequence.md`.
- No active source evidence was found for a current Plex `Part.key` playback path.
- Initial evidence pointed to:
  - Local file playback through `Sources/Orbisonic/OrbisonicViewModel.swift`, `Sources/Orbisonic/AudioFileLoader.swift`, `Sources/Orbisonic/StreamingAudioFileSource.swift`, and `Sources/Orbisonic/OrbisonicEngine.swift`.
  - Live Roon/Aux/Spotify-style input through route selection, loopback capture, and `Sources/Orbisonic/LiveAudioBridge.swift`.
  - Renderer and meter calculations through `Sources/Orbisonic/RendererModule.swift` and `Sources/Orbisonic/RendererMatrixSampleRenderer.swift`.
  - Output route discovery through `Sources/Orbisonic/OutputRouteMonitor.swift`.

## Evidence Commands

- `git status --short`
- `sed -n '1,260p' docs/audio-vlc-investigation/task-01-baseline.md`
- `rg -n "sample_rate|samplerate|channels|channel_count|layout|channel_map|channel_order|downmix|mix|gain|volume|clip|float|int16|int24|int32|f32|s16|s24|s32|pcm|planar|interleaved|pts|timestamp|clock|latency|underrun|overrun|drift|flush|drain" Sources Tests docs README.md Package.swift AGENTS.md`
- `rg -n "Plex|Part\\.key|part key|partKey|plex|URLSession|NAS|smb|file://|AVAudioFile\\(|Matroska|ffmpeg|ffprobe|demux|decode" Sources Tests docs README.md Package.swift AGENTS.md`
- `git show --stat --oneline --name-only a81af94 8f2532b cd15daa b267e44 58cdaae 0c954dc 15df898 b9af469 a968df1 e8754a9 728a95f 6fed762`
- Targeted reads of the files listed throughout this document.

## High-Level Architecture

Orbisonic currently has three related but distinct audio paths:

1. Local file playback:
   - The SwiftUI view model selects a file or library track.
   - The app probes the asset.
   - Depending on file size and policy, it uses either prepared full-buffer loading or streaming/gapless chunk loading.
   - Local PCM is represented as Float32 non-interleaved channel data.
   - `OrbisonicEngine` schedules one mono player/source path per source channel into the normal monitor mixer path.

2. Live loopback playback:
   - The view model selects a source mode such as Roon, Spotify, or Aux.
   - The selected source resolves to an expected input route.
   - `LiveInputCapture` opens the Core Audio HAL input device.
   - Captured Float32 non-interleaved PCM is written to `LiveAudioPipe` ring buffers.
   - `OrbisonicEngine` exposes one `AVAudioSourceNode` per channel, reading from the live pipe into the normal monitor mixer path.

3. Renderer, production topology, and metering:
   - `RendererModule.swift` builds Sonic Sphere 30.1-style renderer scenes and matrices.
   - `RendererMatrixSampleRenderer.swift` renders source samples through matrices for Sonic Sphere meter snapshots.
   - The current audible route descriptors and tests say normal monitor playback stays a two-channel monitor route and does not use AVAudioEnvironmentNode, HRTF, or an audible direct Sonic Sphere matrix.
   - `Sources/AudioCore/` contains a newer PureAudio planning and adapter layer for canonical buses, render kernels, desktop monitor output, Dante/Sonic Sphere output, and audits. Those contracts are stronger than the legacy runtime graph but are not the only code currently involved in local playback.

## End-To-End Pipeline Summary

### Local Prepared File

`media location -> opener/fetcher -> demuxer -> decoder -> PCM converter -> resampler -> channel mapper -> spatial renderer -> device backend -> OS/hardware`

- Media location: a file URL selected or resolved by `OrbisonicViewModel`.
- Opener/fetcher: `AudioFileLoader.load(url:)` opens local files after existence checks.
- Demuxer: `AVAudioFile` for AVFoundation-supported containers; `MatroskaFLACDemuxer.demuxToCAF` for Matroska/FLAC cases; FFmpeg fallback for some FLAC handling.
- Decoder: `AVAudioFile` after direct open or after conversion to CAF.
- PCM converter: `AVAudioConverter` into Float32 non-interleaved PCM.
- Resampler: no explicit local prepared-file resampler was found; the loader preserves the file sample rate in the output format.
- Channel mapper: `AudioFileLoader` detects layout and splits source PCM into one mono buffer per source channel.
- Spatial renderer: `SonicSphereAudioRenderer` and `FeyStaticBedRenderer` build renderer matrices; current audible monitor path uses normal-monitor gain/pan policy rather than an audible Sonic Sphere output branch.
- Device backend: `OrbisonicEngine` uses `AVAudioEngine`, `AVAudioPlayerNode`, mixer nodes, and selected Core Audio output device.
- OS/hardware: AVFoundation, AVAudioEngine, Core Audio output route, and attached monitor/Sonic Sphere/Dante hardware where present.

### Local Streaming/GAPLESS File

`media location -> opener/fetcher -> demuxer -> decoder -> PCM converter -> resampler -> channel mapper -> spatial renderer -> device backend -> OS/hardware`

- Media location: local library track descriptors and file URLs.
- Opener/fetcher: `StreamingAudioFileSource` and `LocalAudioFileSource`.
- Demuxer/decoder: `AVAudioFile` for chunk reads after probe/admission.
- PCM converter: Float32 non-interleaved chunk conversion with `AVAudioConverter` when needed.
- Resampler: streaming output format is constructed at the source file sample rate. No hidden production SRC is documented in this path.
- Channel mapper: chunks are split into per-channel mono buffers before scheduling.
- Spatial renderer: renderer scene and matrix are kept for route state and metering; current audible monitor path remains normal monitor.
- Device backend: `OrbisonicEngine.rebuildStreamingPlaybackGraph`, `scheduleStreamingChunk`, and `LocalGaplessScheduler`.
- OS/hardware: AVFoundation/AVAudioEngine/Core Audio output.

### Live Loopback

`media location -> opener/fetcher -> demuxer -> decoder -> PCM converter -> resampler -> channel mapper -> spatial renderer -> device backend -> OS/hardware`

- Media location: a selected Core Audio input route, usually an Orbisonic loopback device for Roon, Spotify, or Aux.
- Opener/fetcher: `LiveInputCapture` opens the selected HAL input device.
- Demuxer: none inside Orbisonic for the live path; upstream apps and loopback devices already provide PCM to Core Audio.
- Decoder: none inside Orbisonic for Roon/Aux loopback PCM. Spotify decoding belongs to the embedded Spotify receiver boundary before Orbisonic captures or receives the resulting stream.
- PCM converter: `LiveInputCapture` requests Float32 native-endian packed non-interleaved PCM from the HAL audio unit.
- Resampler: no explicit live resampler was found in `LiveAudioBridge`; sample-rate mismatch is treated as diagnostic/admission risk, not hidden correction.
- Channel mapper: `LiveAudioPipe` owns one ring buffer per captured channel and renders per-channel source-node output.
- Spatial renderer: `LiveAudioPipe.render(matrix:)` and `RendererMatrixSampleRenderer` support matrix/meter rendering; audible playback still uses normal monitor source nodes.
- Device backend: input side uses a HAL input audio unit; output side uses `OrbisonicEngine`/AVAudioEngine normal monitor graph.
- OS/hardware: Core Audio input devices, macOS microphone permission, loopback drivers, Core Audio output devices, and attached hardware.

## Stage Details

### 1. Media Location

Actual files:

- `Sources/Orbisonic/OrbisonicViewModel.swift`
- `Sources/Orbisonic/LocalMusicLibrary.swift`
- `Sources/Orbisonic/LoopbackSourceSupport.swift`
- `Sources/Orbisonic/OutputRouteMonitor.swift`

Classes, functions, and modules:

- `OrbisonicViewModel.loadAudioFile`, `commitPreparedLoadedFile`, `startSelectedLiveInput`, `prepareOutputForMusicPlayback`, and route-selection helpers.
- `LocalMusicLibrary` and local track descriptors for local-library state.
- `LoopbackSourceSupport` for expected loopback devices.
- `OutputRouteMonitor` for current and available input/output routes.

Responsibility:

- Convert user source selection into a local file URL, playlist/library track, or selected input route.
- Keep Roon, Spotify, Aux, Local Files, Test Tone, and Off as selected-source paths rather than an implicit mixer.

Input type:

- Local `URL`, local library track descriptor, or `InputRouteInfo`.

Output type:

- A file load request, streaming track descriptor, or live input start request.

Sample-format assumptions:

- Media location stage does not own PCM format. It records enough metadata to allow later probing and admission.

Channel-count assumptions:

- Local files are admitted later against the source-channel ceiling.
- Live routes are admitted later by expected route role and available channel count.

Channel-layout assumptions:

- Local layout is detected later.
- Live source layout is inferred from source mode and capture channel count.

Thread ownership:

- View-model source selection runs on the app/view-model side, with decode work moved off the main actor for prepared-file loading.

Buffer ownership:

- No PCM buffers are owned yet.

Error handling:

- Source-selection failures update `statusMessage` and `lastError`.
- Route failures are logged through `AppLogger`.

Logging:

- Source and route transitions use `AppLogger` categories such as `route`, `input`, and source-specific status messages.

Tests:

- `Tests/OrbisonicTests/OrbisonicWebStateTests.swift` covers selected-source state isolation.
- `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift` covers loopback route diagnostics.

### 2. Opener / Fetcher

Actual files:

- `Sources/Orbisonic/AudioFileProbe.swift`
- `Sources/Orbisonic/AudioFileLoader.swift`
- `Sources/Orbisonic/StreamingAudioFileSource.swift`
- `Sources/Orbisonic/LocalAudioFileSource.swift`
- `Sources/Orbisonic/LiveAudioBridge.swift`

Classes, functions, and modules:

- `AudioFileProbe.descriptor(for:)`
- `AudioFileLoader.load(url:)`
- `StreamingAudioFileSource.open()` and chunk reads.
- `LocalAudioFileSource` for gapless local track sources.
- `LiveInputCapture.start()` and HAL configuration.

Responsibility:

- Open a local file or Core Audio input route.
- Decide whether a local file can be read directly, converted through a fallback, or rejected.
- For live input, bind to the selected Core Audio device.

Input type:

- Local file `URL`, local track descriptor, or Core Audio device ID.

Output type:

- `AVAudioFile`, `AudioAssetDescriptor`, `LoadedAudioFile`, `LocalTrackSource`, or active `LiveInputCapture`.

Sample-format assumptions:

- File opener can encounter many source formats, but downstream app-owned PCM normalizes to Float32 non-interleaved.
- Live opener requests Float32 non-interleaved from the HAL input unit.

Channel-count assumptions:

- Local and live source channel counts must stay inside `OrbisonicAudioLimits.maxSourceChannelCount`.
- Live capture channel count is capped to the route and source ceiling.

Channel-layout assumptions:

- Local opener relies on descriptors and layout detection.
- Live opener is route/channel-count based.

Thread ownership:

- Prepared local decode is started from a detached task in the view model.
- Streaming/gapless scheduling uses background queues.
- Live input uses a Core Audio realtime callback.

Buffer ownership:

- Local openers own file handles and temporary converted CAF files when fallback conversion is used.
- Live capture owns HAL audio-unit buffer lists during callbacks and forwards samples to `LiveAudioPipe`.

Error handling:

- Missing files, unsupported files, file-too-large conditions, invalid formats, and route failures throw typed/localized errors.
- Live capture setup errors are surfaced through `startLiveInput`.

Logging:

- Local load/streaming state is logged through view-model status and `AppLogger`.
- Live route/capture failures are logged with route details.

Tests:

- `Tests/OrbisonicTests/StreamingAudioFileSourceTests.swift`
- `Tests/OrbisonicTests/LocalGaplessSchedulerTests.swift`
- `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift`

### 3. Demuxer

Actual files:

- `Sources/Orbisonic/MatroskaFLACSupport.swift`
- `Sources/Orbisonic/AudioFileLoader.swift`
- `Sources/Orbisonic/StreamingAudioFileSource.swift`

Classes, functions, and modules:

- `MatroskaFLACDemuxer.demuxToCAF`
- `MatroskaFLACDetector`
- `CompressedAudioProbe`
- `AVAudioFile`

Responsibility:

- Separate or expose audio streams from a local container so they can be decoded as PCM.
- For Matroska/FLAC cases, call FFmpeg to write CAF Float32 PCM.
- For AVFoundation-supported files, rely on `AVAudioFile`.

Input type:

- Local file URL and optional probe metadata.

Output type:

- Direct `AVAudioFile` or temporary CAF file URL opened by `AVAudioFile`.

Sample-format assumptions:

- FFmpeg demux-to-CAF path requests `pcm_f32le`.
- AVFoundation path may start in source format but downstream conversion normalizes it.

Channel-count assumptions:

- Demuxed/probed channel counts are checked against source limits.

Channel-layout assumptions:

- Channel layout is probed where possible; otherwise fallback layout rules apply later.

Thread ownership:

- Demuxing runs in the local file load/streaming workflow, not the Core Audio realtime output callback.

Buffer ownership:

- FFmpeg fallback owns temporary CAF files.
- AVAudioFile owns file-level read state.

Error handling:

- Demux/probe failures throw loader errors and include fallback-failure descriptions.

Logging:

- FFmpeg/fallback failures are reflected in load errors and status.

Tests:

- `Tests/OrbisonicTests/LocalPlayerStabilizationTests.swift` and streaming tests exercise local file admission behavior.

### 4. Decoder

Actual files:

- `Sources/Orbisonic/AudioFileLoader.swift`
- `Sources/Orbisonic/StreamingAudioFileSource.swift`
- `Sources/Orbisonic/MatroskaFLACSupport.swift`
- `Sources/Orbisonic/LiveAudioBridge.swift`
- `Sources/Orbisonic/SpotifyReceiverClient.swift`

Classes, functions, and modules:

- `AVAudioFile.read`
- `AVAudioConverter`
- `MatroskaFLACDemuxer`
- `LiveInputCapture`
- Embedded Spotify receiver boundary represented by `SpotifyReceiverClient`

Responsibility:

- Produce PCM frames from local encoded files.
- Treat live loopback as already-decoded PCM from Core Audio.
- Keep Spotify receiver integration at a boundary separate from general local-file decode.

Input type:

- `AVAudioFile`, CAF fallback file, or live input callback buffers.

Output type:

- `AVAudioPCMBuffer`, local decoded chunks, mono channel buffers, or live pipe writes.

Sample-format assumptions:

- Decoder output is normalized toward Float32 non-interleaved PCM before app-owned rendering/metering.

Channel-count assumptions:

- Local decode keeps the source channel count rather than folding to stereo at decode time.
- Live decode does not occur in Orbisonic; live channel count is route-derived.

Channel-layout assumptions:

- Decoder preserves or exposes layout metadata where possible.

Thread ownership:

- Local prepared decode is off the main actor.
- Streaming reads are scheduled by local source/scheduler infrastructure.
- Live decode is not owned by Orbisonic; capture is realtime callback-owned.

Buffer ownership:

- Prepared decode retains full mono buffers when under memory budget.
- Streaming decode retains scheduled chunks while needed for playback/gapless metering.
- Live capture does not retain the callback buffers beyond ring-buffer writes.

Error handling:

- Decode failures stop or reject file load.
- Scheduler source failures emit `LocalGaplessSchedulerEvent.sourceFailed`.

Logging:

- View-model status and `AppLogger` record decode/load failures.

Tests:

- `Tests/OrbisonicTests/LocalGaplessSchedulerTests.swift`
- `Tests/OrbisonicTests/StreamingAudioFileSourceTests.swift`
- `Tests/OrbisonicTests/LocalPlayerStabilizationTests.swift`

### 5. PCM Converter

Actual files:

- `Sources/Orbisonic/AudioFileLoader.swift`
- `Sources/Orbisonic/StreamingAudioFileSource.swift`
- `Sources/Orbisonic/LiveAudioBridge.swift`
- `Sources/AudioContracts/AudioContracts.swift`
- `Sources/AudioCore/RenderKernels.swift`

Classes, functions, and modules:

- `AudioFileLoader.makeProcessingFormat`
- `StreamingAudioFileSource.makeOutputFormat`
- `AVAudioConverter`
- `LiveInputCapture.configureAudioUnit`
- `ProcessingFormat.float32NonInterleavedPCM`
- `AudioBlockFormat`

Responsibility:

- Normalize local and live samples into the app's expected non-interleaved Float32 PCM shape.
- Make sample format explicit for newer PureAudio contracts.

Input type:

- `AVAudioFile.processingFormat`, decoded `AVAudioPCMBuffer`, or HAL callback buffers.

Output type:

- Float32 non-interleaved `AVAudioPCMBuffer`, `PCMChunk`, `CanonicalAudioBlock`, or live ring samples.

Sample-format assumptions:

- Float32 non-interleaved PCM is the app-owned internal format.
- `AudioCore` rejects non-Float32/non-noninterleaved blocks for production render kernels.

Channel-count assumptions:

- Channel count must match source layout and block descriptors.

Channel-layout assumptions:

- Layout must be valid for the channel count or explicitly fallback.

Thread ownership:

- Local conversion happens during load/read work.
- Live conversion request is installed before HAL callback execution.

Buffer ownership:

- Converted local buffers are retained by `LoadedAudioFile` or streaming chunks.
- PureAudio blocks own channel arrays by value.
- Live converter output is callback-owned until copied into ring buffers.

Error handling:

- Converter creation failure throws loader/source errors.
- AudioCore format mismatch throws validation errors.

Logging:

- Loader and render-audit paths record format failures and conversion decisions.

Tests:

- `Tests/AudioCoreTests/`
- `Tests/OrbisonicTests/StreamingAudioFileSourceTests.swift`
- `Tests/OrbisonicTests/LocalPlayerStabilizationTests.swift`

### 6. Resampler

Actual files:

- `Sources/Orbisonic/AudioFileLoader.swift`
- `Sources/Orbisonic/StreamingAudioFileSource.swift`
- `Sources/Orbisonic/LiveAudioBridge.swift`
- `Sources/AudioCore/SourceAdapters.swift`
- `Sources/AudioCore/RenderKernels.swift`
- `Sources/AudioContracts/AudioContracts.swift`

Classes, functions, and modules:

- `AudioFileLoader.makeProcessingFormat`
- `StreamingAudioFileSource.makeOutputFormat`
- `LiveLoopbackSourceAdapter.validateSampleRate`
- `ManagedLocalAssetSourceAdapter.validateSampleRate`
- `MatrixRenderKernel`
- `RenderKernelAudit`

Responsibility:

- The current inspected local playback code preserves source sample rate when it builds Float32 non-interleaved buffers.
- The live path validates and diagnoses sample-rate mismatch rather than hiding it.
- The newer AudioCore path records `sampleRateConversionOccurred=false` for render-kernel audits and rejects mismatches in production-style adapters.

Input type:

- Source sample rate from file, live route, or canonical block.

Output type:

- PCM at the source or admitted session sample rate.

Sample-format assumptions:

- Resampling is not a general hidden repair step in the inspected local/live paths.
- Any future production sample-rate conversion would need an explicit contract and audit trail.

Channel-count assumptions:

- Resampling, where absent or rejected, does not change channel count.

Channel-layout assumptions:

- Layout is independent from sample-rate validation.

Thread ownership:

- Current local conversion decisions are made during loader/source work.
- AudioCore validation is synchronous contract validation.

Buffer ownership:

- No separate resampler-owned buffer pool was found for the current local/live path.

Error handling:

- Sample-rate mismatch is diagnostic or rejecting behavior, not silent correction, in the inspected contract/adapters.

Logging:

- Roon/live diagnostics record sample-rate mismatch as a visible route problem.
- AudioCore audits record sample rates and the absence of conversion.

Tests:

- `Tests/AudioCoreTests/`
- `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift`
- `Tests/OrbisonicTests/LocalPlayerStabilizationTests.swift`

### 7. Channel Mapper

Actual files:

- `Sources/Orbisonic/AudioFileLoader.swift`
- `Sources/Orbisonic/StreamingAudioFileSource.swift`
- `Sources/Orbisonic/LiveAudioBridge.swift`
- `Sources/Orbisonic/RendererModule.swift`
- `Sources/Orbisonic/NormalMonitorStereoDownmixer.swift`
- `Sources/Orbisonic/NormalMonitorRouteDescriptor.swift`
- `Sources/AudioContracts/AudioContracts.swift`

Classes, functions, and modules:

- `SurroundLayoutDetector`
- `ChannelRoleLayout`
- `AudioFileLoader` mono-buffer split
- `StreamingAudioFileSource` chunk channel split
- `LiveAudioPipe`
- `RendererMatrixBuilder`
- `FeyStaticBedRenderer`
- `NormalMonitorDownmixPolicy`
- `NormalMonitorStereoDownmixer`

Responsibility:

- Preserve discrete source channels.
- Attach or infer channel roles.
- Map source layouts into normal monitor gain/pan and Sonic Sphere matrix/meter outputs.

Input type:

- Multi-channel PCM buffers, `ChannelRoleLayout`, live ring data, or canonical blocks.

Output type:

- Per-channel mono buffers, matrix output channels, normal monitor gain/pan, or stereo downmix buffers in tests/helpers.

Sample-format assumptions:

- Channel mapping expects Float32 sample arrays/buffers after PCM conversion.

Channel-count assumptions:

- Source layouts can be mono, stereo, quad, 5.1, Auro-style layouts, Direct 30, Direct 31, or fallback layouts depending on detected/declared channel count.
- Direct 30 and Direct 31 are bypass modes only when source width matches.

Channel-layout assumptions:

- Layout role order matters. Low-confidence layouts remain visible as warnings rather than being silently reinterpreted.

Thread ownership:

- Mapping for scheduled local playback occurs during graph rebuild/scheduling.
- Live ring mapping occurs inside source-node render and metering paths.
- Renderer/matrix builders are ordinary synchronous code.

Buffer ownership:

- Local mono buffers are retained by loaded files or scheduled chunks.
- Live rings are owned by `LiveAudioPipe`.
- Renderer matrix renderers write into destination buffers owned by the caller.

Error handling:

- Channel-count mismatch throws validation errors.
- Renderer validation rejects wrong output counts and direct-mode mismatches.

Logging:

- Route/channel-count diagnostics are surfaced through view-model and diagnostic rows.

Tests:

- `Tests/OrbisonicTests/RendererModuleTests.swift`
- `Tests/OrbisonicTests/RendererMatrixSampleRendererTests.swift`
- `Tests/OrbisonicTests/ChannelRoleLayoutDescriptorTests.swift`
- `Tests/OrbisonicTests/NormalMonitorRouteDescriptorTests.swift`
- `Tests/OrbisonicTests/LiveNormalMonitorRouteTests.swift`

### 8. Spatial Renderer

Actual files:

- `Sources/Orbisonic/RendererModule.swift`
- `Sources/Orbisonic/RendererMatrixSampleRenderer.swift`
- `Sources/Orbisonic/OrbisonicEngine.swift`
- `Sources/Orbisonic/NormalMonitorRouteDescriptor.swift`
- `Sources/AudioCore/RenderGraphPlan.swift`
- `Sources/AudioCore/RenderKernels.swift`
- `Sources/AudioCore/OutputAdapters.swift`

Classes, functions, and modules:

- `RendererRenderMode`
- `RendererMatrix`
- `RendererMatrixBuilder`
- `SonicSphereAudioRenderer`
- `FeyStaticBedRenderer`
- `RendererMatrixSampleRenderer`
- `NormalMonitorRoutePlanner`
- `NormalMonitorAudibleRouteSelector`
- `DanteSonicSphereRenderer`
- `DesktopMonitorRenderer`

Responsibility:

- Model Sonic Sphere 30.1 renderer scenes and matrices.
- Render samples through matrices for metering and PureAudio output-adapter paths.
- Keep normal monitor audible playback separate from production topology.

Input type:

- Source layout, renderer mode, source PCM buffers, canonical audio blocks, or live ring snapshots.

Output type:

- Renderer matrices, Sonic Sphere meter buffers/snapshots, desktop-monitor blocks, or Dante/Sonic Sphere output blocks in AudioCore.

Sample-format assumptions:

- Renderer math expects Float samples.

Channel-count assumptions:

- Sonic Sphere logical production plan uses 31 channels: 30 full-range outputs plus LFE.
- Some physical plans reserve a 32nd physical channel.
- Direct 30 and Direct 31 are identity/bypass matrix modes for matching source widths.

Channel-layout assumptions:

- `FeyStaticBedRenderer` handles already-decoded channel beds/discrete channels. It explicitly does not decode object metadata, Auro-Codec-in-FLAC, or adaptive steering.

Thread ownership:

- Matrix construction is synchronous.
- Sample rendering happens where requested by engine metering/live/render paths.

Buffer ownership:

- Matrix render callers provide destination storage.
- Metering must not consume live playback buffers or mutate audible output.

Error handling:

- Renderer validation throws for invalid source/output sizes.
- AudioCore render kernels throw on format/channel/sample-rate mismatches.

Logging:

- Engine renderer updates log mode, layout, and `directAudio=false` in current runtime paths.
- Render audits record format, sample-rate, channel, and conversion facts.

Tests:

- `Tests/OrbisonicTests/RendererModuleTests.swift`
- `Tests/OrbisonicTests/RendererMatrixSampleRendererTests.swift`
- `Tests/OrbisonicTests/MeteringIsolationTests.swift`
- `Tests/AudioCoreTests/`

### 9. Device Backend

Actual files:

- `Sources/Orbisonic/OrbisonicEngine.swift`
- `Sources/Orbisonic/OutputRouteMonitor.swift`
- `Sources/Orbisonic/LiveAudioBridge.swift`
- `Sources/AudioCore/OutputAdapters.swift`

Classes, functions, and modules:

- `OrbisonicEngine`
- `AVAudioEngine`
- `AVAudioPlayerNode`
- `AVAudioSourceNode`
- `preVolumeMixer`
- `outputGainMixer`
- `engine.mainMixerNode`
- `setOutputDevicePreservingPlayback`
- `OutputRouteMonitor`
- `LiveInputCapture`
- `DualOutputRenderCoordinator`

Responsibility:

- Schedule local prepared/streaming buffers into AVAudioEngine.
- Pull live PCM from ring buffers into source nodes.
- Apply normal monitor gain/pan and output gain.
- Select a Core Audio output device where possible.
- Capture live input through a separate HAL input audio unit.
- In AudioCore, coordinate desktop monitor and Dante/Sonic Sphere output adapters in a contract-tested path.

Input type:

- Mono local buffers, streaming chunks, live source-node render requests, or canonical render blocks.

Output type:

- AVAudioEngine output to selected Core Audio device, live input ring data, or AudioCore adapter blocks.

Sample-format assumptions:

- Current AVAudioEngine graph uses mono source/player nodes into a stereo normal monitor path.
- AudioCore adapters require declared Float32 non-interleaved block formats.

Channel-count assumptions:

- Normal monitor output is two channels.
- Production/Dante/Sonic Sphere output plans expect the declared production topology.

Channel-layout assumptions:

- Normal monitor route does not become production Sonic Sphere routing.
- Output route channel counts are discovered and validated.

Thread ownership:

- AVAudioEngine render callbacks are realtime audio owned by the engine.
- `LocalGaplessScheduler` owns a serial queue for scheduling state.
- HAL input callback owns live capture timing.

Buffer ownership:

- AVAudioPlayerNode owns scheduled buffers until playback completion callbacks release scheduler retention.
- `LiveAudioPipe` owns live rings.
- Output adapters own or consume canonical blocks.

Error handling:

- Output selection can fail and reports route errors.
- Playback graph rebuild failures throw and update user-visible state.
- Local scheduler stop/pause/seek invalidates generations and closes old sources.

Logging:

- Route selection, output changes, graph rebuilds, and playback errors use `AppLogger`.

Tests:

- `Tests/OrbisonicTests/LocalGaplessSchedulerTests.swift`
- `Tests/OrbisonicTests/LocalPlayerStabilizationTests.swift`
- `Tests/OrbisonicTests/VURoutingViewTests.swift`
- `Tests/AudioCoreTests/`

### 10. OS / Hardware

Actual files:

- `Sources/Orbisonic/OutputRouteMonitor.swift`
- `Sources/Orbisonic/LiveAudioBridge.swift`
- `Sources/Orbisonic/BlackHoleRouteRepair.swift`
- `scripts/refresh-orbisonic-app.sh`
- `scripts/reopen-orbisonic-app.sh`
- `docs/release-verification.md`

Classes, functions, and modules:

- Core Audio route enumeration in `OutputRouteMonitor`.
- HAL input audio unit setup in `LiveInputCapture`.
- BlackHole route repair helpers.
- LaunchServices app refresh/reopen scripts.

Responsibility:

- Discover actual macOS input/output devices.
- Capture loopback devices.
- Output audio through the selected system/Core Audio route.
- Keep app-bundle verification honest through LaunchServices.

Input type:

- Core Audio device list, route IDs, nominal sample rates, channel counts, and permission state.

Output type:

- Route snapshots, live capture state, user-visible diagnostics, or audible Core Audio output.

Sample-format assumptions:

- Core Audio devices may advertise different nominal rates. Mismatch must remain visible.

Channel-count assumptions:

- Hardware route channel counts may be lower than Sonic Sphere production requirements.
- Sonic Sphere, Dante, loopback devices, Spotify, Roon, microphone permission, and installers require manual verification.

Channel-layout assumptions:

- Hardware route channel order must not be assumed from channel count alone.

Thread ownership:

- macOS/Core Audio owns device callbacks and engine render timing.

Buffer ownership:

- OS audio units own callback buffers. Orbisonic copies live input samples into its rings and schedules local buffers into AVAudioEngine.

Error handling:

- Permission denial, route mismatch, sample-rate mismatch, channel mismatch, underflow, and overflow are diagnostic states.

Logging:

- Route monitor and live diagnostics log route/device facts.

Tests:

- Hardware behavior is manually verified.
- Deterministic route and diagnostic logic is covered in unit tests where possible.

## Recent Modularization Notes

Recent modularization and hardening commits show that the current code has been moving toward explicit boundaries rather than one monolithic player:

- `6fed762 Add Pure Audio architecture boundary tests`
  - Added architecture tests to enforce target boundaries.
- `728a95f Add Pure Audio contract types`
  - Introduced shared format, source, route, and layout language in `AudioContracts`.
- `e8754a9 Add AudioControl facade and AudioCore shell`
  - Added control/core separation groundwork.
- `a968df1 Add Pure Audio session and route validation`
  - Added sample-rate and route validation concepts.
- `b9af469 Add immutable Pure Audio render graph plan`
  - Made render graph plans explicit and immutable.
- `15df898 Add Pure Audio canonical bus and render kernels`
  - Added canonical bus/render-kernel concepts for format-checked sample processing.
- `0c954dc Add Pure Audio source adapters`
  - Added source adapter validation, including live loopback and local asset rules.
- `58cdaae Add Pure Audio dual output adapter architecture`
  - Added desktop monitor and Dante/Sonic Sphere output adapter separation.
- `b267e44 Add Pure Audio copy-only metering telemetry`
  - Reinforced that metering copies samples and does not mutate the audible path.
- `cd15daa Integrate and harden Pure Audio architecture`
  - Connected PureAudio contracts to integration rules and legacy local-file gates.
- `8f2532b Add feature-gated local gapless playback`
  - Added streaming/gapless local file ownership through local source types, scheduler, metering, and engine integration.
- `a81af94 1.2 - orbisonic refactored`
  - Refactored current app modules around loopback support, normal monitor route descriptors, view-model behavior, diagnostics, and tests.

These commits touch transport controls, decode ownership, buffer transfer, channel mapping, renderer separation, device output boundaries, sample-format validation, metering isolation, and scheduling behavior. They also show a split between current AVAudioEngine runtime code and newer contract-tested PureAudio layers.

## Transport, Seek, Pause, Flush, And Drain Ownership

- `OrbisonicViewModel` owns user-facing transport state and delegates to `OrbisonicEngine`.
- `OrbisonicEngine.play`, `pause`, `stop`, and `seek` own AVAudioEngine/player-node behavior.
- `LocalGaplessScheduler` owns queued/gapless scheduling state on a serial `DispatchQueue`.
- Seeking invalidates the scheduler generation, closes stale future sources, stops the player if needed, seeks the current source, and refills scheduled audio.
- Pause pauses scheduler/player nodes. Stop closes sources, clears retained buffers, invalidates generations, and stops player nodes.
- No general-purpose public drain API was found in the active runtime path. Buffer release is handled by player-node completion callbacks and scheduler retention bookkeeping.
- `flushPendingWorkForTesting` exists on `LocalGaplessScheduler` for deterministic tests.

## Logging And Diagnostics Surfaces

- `AppLogger` records route selection, playback, live capture, and diagnostic messages.
- `LoopbackSourceSupport` and related tests distinguish Roon playback activity from captured audio.
- Live diagnostics expose sample-rate mismatch, channel-count mismatch, permission denial, underflow, overflow, and all-zero input conditions.
- AudioCore render audits record sample-rate, channel-count, and conversion facts for planned/contract paths.
- Normal monitor route tests guard against accidentally introducing HRTF, AVAudioEnvironmentNode, or audible Sonic Sphere direct matrix behavior into the monitor path.

## Why Orbisonic May Have Been Designed This Way

The current shape appears driven by Orbisonic's product constraints rather than by a generic media-player architecture:

- Orbisonic is not just a file player. It must also capture live loopback sources, route monitor output, preserve selected-source isolation, and model Sonic Sphere 30.1 production topology.
- Local file playback and live loopback capture have different failure modes. Keeping them separate makes silent input, route mismatch, sample-rate mismatch, and decode errors easier to diagnose honestly.
- Float32 non-interleaved PCM gives the renderer, meters, and Core Audio code a common internal shape while preserving discrete channels.
- Preserving channel count and layout is important because Sonic Sphere behavior depends on source width and channel role, especially for direct 30/31 bypass modes.
- The normal monitor path is deliberately limited and test-protected. It lets users hear setup/preview audio without redefining the production Sonic Sphere topology.
- The newer PureAudio contracts appear to be a retrofit/hardening layer around the existing app, not a wholesale replacement of every runtime code path.
- Manual hardware verification remains necessary because no unit test can prove the actual Dante, Sonic Sphere, loopback, Roon, Spotify, microphone-permission, or installer behavior on a user's machine.

## Current Architecture Risks Relevant To Later Investigation

- There are multiple local playback paths: prepared full-buffer load, streaming playback, and gapless scheduling. A future replacement discussion must identify which path is in scope.
- Current local playback preserves source sample rate; if harsh audio is caused by route/sample-rate mismatch, replacing a demuxer alone may not address it.
- Live playback captures already-produced PCM and does not share the same demux/decode path as local files.
- Renderer/meter math is distinct from audible normal monitor routing. A meter that looks correct does not prove the audible output route is correct.
- AudioCore contracts are stricter than some legacy runtime paths; a future change must avoid assuming the PureAudio layer already owns all playback.
- Hardware-only failures must remain visible as diagnostics, not hidden by fallback routing, fake levels, or implicit conversion.

## Task 02 Conclusion

Orbisonic's current architecture is a native Swift/AVFoundation/Core Audio system with explicit local-file, live-loopback, renderer/meter, normal-monitor, and PureAudio contract layers. The current local file paths normalize decoded audio to Float32 non-interleaved PCM and preserve discrete source channels. The live path captures Float32 non-interleaved PCM from selected Core Audio loopback routes. The current audible monitor path is two-channel normal monitor output through AVAudioEngine, while Sonic Sphere renderer matrices are used for production modeling, metering, and newer AudioCore output-adapter contracts.
