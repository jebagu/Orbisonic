# Task 03 - Playback Module Boundaries

## Scope

Task 3 isolates the current modules that "play audio" in Orbisonic and separates transport, media opening, decode, PCM conversion, resampling, channel mapping, renderer, timing, flush/drain, and OS output responsibilities.

This document uses the architecture map in `docs/audio-vlc-investigation/task-02-orbisonic-architecture.md`. No app code was changed.

## Evidence Commands

- `git status --short`
- `rg -n "func (loadAudioFile|commitPreparedLoadedFile|play|pause|stop|seek|startSelectedLiveInput)|loadPreparedFile|startStreamingPlayback|startLiveInput|scheduleStreamingChunk|scheduleFromCurrentPosition|setOutputDevicePreservingPlayback" Sources/Orbisonic/OrbisonicViewModel.swift Sources/Orbisonic/OrbisonicEngine.swift`
- `rg -n "Plex|Part\\.key|part key|partKey|plex|NAS|smb" Sources Tests README.md Package.swift AGENTS.md`
- `rg -n "struct LoadedAudioFile|final class AudioFileLoader|func load\\(|makeProcessingFormat|AVAudioConverter|monoBuffers|split|sampleRate|channelCount|unsupportedChannelCount|MatroskaFLACDemuxer|demuxToCAF" Sources/Orbisonic/AudioFileLoader.swift Sources/Orbisonic/MatroskaFLACSupport.swift Sources/Orbisonic/StreamingAudioFileSource.swift Sources/Orbisonic/LocalAudioFileSource.swift`
- `rg -n "RendererRenderMode|direct30|direct31|RendererMatrix|RendererMatrixBuilder|SonicSphereAudioRenderer|FeyStaticBedRenderer|NormalMonitorRoutePlanner|usesAVAudioEnvironmentNode|usesHRTF|usesAudibleDirectSonicSphereMatrix|NormalMonitorDownmixPolicy|configureNormalMonitorNode|RendererMatrixSampleRenderer" Sources/Orbisonic/RendererModule.swift Sources/Orbisonic/RendererMatrixSampleRenderer.swift Sources/Orbisonic/NormalMonitorRouteDescriptor.swift Sources/Orbisonic/OrbisonicEngine.swift Tests/OrbisonicTests`
- `rg -n "final class LiveInputCapture|configureAudioUnit|AudioUnitRender|write\\(|func render\\(|renderMeterSnapshot|status\\(|underflow|overflow|latencySeconds|targetLatencyFrames|sampleRate|channelCount|LiveAudioPipe" Sources/Orbisonic/LiveAudioBridge.swift Tests/OrbisonicTests/LiveAudioBridgeTests.swift Tests/OrbisonicTests/SonicSphereMeteringTests.swift`
- `rg -n "AVAudioEngine|preVolumeMixer|outputGainMixer|mainMixerNode|connect\\(|outputAudioUnit|kAudioOutputUnitProperty_CurrentDevice|setOutputDevicePreservingPlayback|engine\\.start|engine\\.stop|installTap|removeTap" Sources/Orbisonic/OrbisonicEngine.swift Sources/Orbisonic/OutputRouteMonitor.swift`
- `rg -n "completion|scheduledBufferDidFinish|retainedBuffers|generation|seek\\(|pause\\(|stop\\(|requestFill|scheduledAheadFrames|retainedPCMBytes|sourceFrameRange|queueEnded|sourceFailed" Sources/Orbisonic/LocalGaplessScheduler.swift Tests/OrbisonicTests/LocalGaplessSchedulerTests.swift`
- `rg -n "currentTime|playbackFrame|playerTime|lastRenderTime|elapsed|framePosition|sourceFrame|timestamp|PTS|pts|duration|progress|seek" Sources/Orbisonic/OrbisonicEngine.swift Sources/Orbisonic/StreamingAudioFileSource.swift Sources/Orbisonic/LocalAudioFileSource.swift Sources/Orbisonic/LocalGaplessScheduler.swift Sources/AudioCore`

## Direct Answers

### 1. Which module receives play, pause, stop, seek, and track-load commands?

Current owner:

- `Sources/Orbisonic/OrbisonicViewModel.swift` receives user-facing local transport commands:
  - `playLocalTransport` at `Sources/Orbisonic/OrbisonicViewModel.swift:2435`
  - `pauseLocalTransport` at `Sources/Orbisonic/OrbisonicViewModel.swift:2505`
  - `stopLocalTransport` at `Sources/Orbisonic/OrbisonicViewModel.swift:2544`
  - queue playback entry points including `playQueueIndex` at `Sources/Orbisonic/OrbisonicViewModel.swift:5727`
  - live-input start through `startLiveInputForCurrentRoute` at `Sources/Orbisonic/OrbisonicViewModel.swift:5882`
  - Roon transport delegates at `Sources/Orbisonic/OrbisonicViewModel.swift:6159`, `:6163`, `:6167`, `:6171`, and `:6175`
  - Spotify transport helpers at `Sources/Orbisonic/OrbisonicViewModel.swift:9747`, `:9751`, and `:9755`

Playback engine owner:

- `Sources/Orbisonic/OrbisonicEngine.swift` owns actual local/live engine operations:
  - `loadPreparedFile` at `Sources/Orbisonic/OrbisonicEngine.swift:301`
  - `startLiveInput` at `Sources/Orbisonic/OrbisonicEngine.swift:515`
  - `play` at `Sources/Orbisonic/OrbisonicEngine.swift:640`
  - `pause` at `Sources/Orbisonic/OrbisonicEngine.swift:713`
  - `stop` at `Sources/Orbisonic/OrbisonicEngine.swift:788`
  - `seek(toProgress:)` at `Sources/Orbisonic/OrbisonicEngine.swift:978`

Boundary:

- `OrbisonicViewModel` is transport/API and source-state owner.
- `OrbisonicEngine` is runtime playback graph owner.
- Roon and Spotify transport methods control external services; they are not the same boundary as local PCM playback.

### 2. Which module opens Plex Part.key URLs, local files, or NAS paths?

Current owner:

- No active `Plex`, `Part.key`, `partKey`, `NAS`, or `smb` owner was found in `Sources`, `Tests`, `README.md`, `Package.swift`, or `AGENTS.md`; the command `rg -n "Plex|Part\\.key|part key|partKey|plex|NAS|smb" Sources Tests README.md Package.swift AGENTS.md` returned no matches.
- Local file probing is owned by `Sources/Orbisonic/AudioFileProbe.swift`, with `probeAVAudioFile` opening `AVAudioFile` at `Sources/Orbisonic/AudioFileProbe.swift:123` and `Sources/Orbisonic/AudioFileProbe.swift:125`.
- Prepared local-file opening/loading is owned by `Sources/Orbisonic/AudioFileLoader.swift`, with `AudioFileLoader` at `Sources/Orbisonic/AudioFileLoader.swift:126` and `load` at `Sources/Orbisonic/AudioFileLoader.swift:127`.
- Streaming local-file opening is owned by `Sources/Orbisonic/StreamingAudioFileSource.swift`, which opens `AVAudioFile` at `Sources/Orbisonic/StreamingAudioFileSource.swift:327`.
- Gapless local-file opening is owned by `Sources/Orbisonic/LocalAudioFileSource.swift`, which opens `AVAudioFile` at `Sources/Orbisonic/LocalAudioFileSource.swift:58`.

Boundary:

- There is no current Plex-specific URL opener in active source.
- A mounted NAS file path would enter as a normal local file URL if selected by the app or library; no separate NAS protocol reader was found.

### 3. Which module demuxes or decodes compressed media?

Current owner:

- AVFoundation-backed local decode is through `AVAudioFile` in `AudioFileLoader`, `StreamingAudioFileSource`, and `LocalAudioFileSource`:
  - prepared loader opens `AVAudioFile` at `Sources/Orbisonic/AudioFileLoader.swift:257` and `Sources/Orbisonic/AudioFileLoader.swift:302`
  - streaming source opens `AVAudioFile` at `Sources/Orbisonic/StreamingAudioFileSource.swift:327`
  - gapless source opens `AVAudioFile` at `Sources/Orbisonic/LocalAudioFileSource.swift:58`
- Matroska/FLAC fallback demux is owned by `Sources/Orbisonic/MatroskaFLACSupport.swift`:
  - `MatroskaFLACDemuxer` at `Sources/Orbisonic/MatroskaFLACSupport.swift:315`
  - `demuxToCAF` at `Sources/Orbisonic/MatroskaFLACSupport.swift:316`
  - `AudioFileLoader` invokes it at `Sources/Orbisonic/AudioFileLoader.swift:206`
- Compressed probing uses ffprobe through `CompressedAudioProbe` at `Sources/Orbisonic/MatroskaFLACSupport.swift:366` and `AudioFileProbe` fallback ffprobe parsing at `Sources/Orbisonic/AudioFileProbe.swift:152`.

Boundary:

- Local compressed-media decode/demux is not in `OrbisonicEngine`; it is upstream in loader/source classes.
- Live Roon/Aux loopback has no Orbisonic demux/decode stage; `LiveInputCapture` captures PCM from Core Audio.

### 4. Which module outputs decoded PCM?

Current owner:

- Prepared local decode outputs `LoadedAudioFile`, declared at `Sources/Orbisonic/AudioFileLoader.swift:5`, with `monoBuffers` at `Sources/Orbisonic/AudioFileLoader.swift:12`.
- The prepared loader returns loaded PCM after conversion and channel split at `Sources/Orbisonic/AudioFileLoader.swift:551` through `Sources/Orbisonic/AudioFileLoader.swift:555`.
- Streaming and gapless sources output decoded chunks:
  - `StreamingAudioFileSource` reads chunks around `Sources/Orbisonic/StreamingAudioFileSource.swift:386`.
  - `LocalAudioFileSource` emits `sourceFrameRange` and chunks at `Sources/Orbisonic/LocalAudioFileSource.swift:153` through `Sources/Orbisonic/LocalAudioFileSource.swift:166`.
- Live capture writes decoded/live PCM to `LiveAudioPipe`, with HAL callback write at `Sources/Orbisonic/LiveAudioBridge.swift:291` and pipe buffer-list writes at `Sources/Orbisonic/LiveAudioBridge.swift:598` through `:616`.

Boundary:

- PCM output from decode is owned by loader/source/live-pipe classes.
- `OrbisonicEngine` consumes PCM and schedules/renders it; it is not the local compressed decoder.

### 5. Which module converts sample formats?

Current owner:

- Prepared local conversion is owned by `AudioFileLoader`, which creates an `AVAudioConverter` at `Sources/Orbisonic/AudioFileLoader.swift:431`.
- Prepared loader creates the mono Float format at `Sources/Orbisonic/AudioFileLoader.swift:470`.
- Streaming conversion is owned by `StreamingAudioFileSource`, which creates `AVAudioConverter` at `Sources/Orbisonic/StreamingAudioFileSource.swift:350` and output format at `Sources/Orbisonic/StreamingAudioFileSource.swift:481`.
- Gapless local conversion is owned by `LocalAudioFileSource`, which creates `AVAudioConverter` at `Sources/Orbisonic/LocalAudioFileSource.swift:92`.
- Live capture asks HAL for the stream format in `LiveAudioBridge`, with sample-rate fields at `Sources/Orbisonic/LiveAudioBridge.swift:170`.
- PureAudio's canonical contract is Float32 non-interleaved PCM:
  - `ProcessingFormat.float32NonInterleavedPCM` is referenced as the default in `Sources/AudioContracts/AudioContracts.swift:427`.
  - `AudioBlockFormat` validates block format in `Sources/AudioCore/RenderKernels.swift:5` through `:40`.

Boundary:

- Format conversion is before `OrbisonicEngine` for local files and at HAL setup for live capture.
- Newer AudioCore render kernels validate format rather than performing broad implicit conversion.

### 6. Which module resamples?

Current owner:

- No general active local/live runtime resampler owner was found in the inspected path.
- Prepared local loader preserves source sample rate when constructing output PCM; `AudioFileLoader` uses `inputFormat.sampleRate` in its internal processing format at `Sources/Orbisonic/AudioFileLoader.swift:406` and final output metadata at `Sources/Orbisonic/AudioFileLoader.swift:539`.
- Streaming output format uses source sample rate at `Sources/Orbisonic/StreamingAudioFileSource.swift:485` and `:493`.
- `LocalAudioFileSource` has ratio logic when source and output formats differ at `Sources/Orbisonic/LocalAudioFileSource.swift:249` through `:254`, but the streaming/gapless owner controls the requested output format.
- AudioCore validates sample-rate mismatches rather than hiding them:
  - `SourceDescriptor.validate` reports source sample-rate mismatch at `Sources/AudioContracts/AudioContracts.swift:326` through `:327`.
  - `MatrixRenderKernel` rejects source/destination sample-rate mismatch at `Sources/AudioCore/RenderKernels.swift:267` through `:270`.
  - `RenderKernelAudit` records `sampleRateConversionOccurred: false` at `Sources/AudioCore/RenderKernels.swift:443` through `:449`.

Boundary:

- Sample-rate conversion is not currently a broad opaque module.
- If resampling appears in future work, it should be explicit and audited because hidden SRC could double-convert or mask route mismatch.

### 7. Which module owns channel order and channel layout?

Current owner:

- Current app layout detection and fallback use `SurroundLayoutDetector` and `ChannelRoleLayout` in `Sources/Orbisonic/`.
- Prepared local loader detects layout at `Sources/Orbisonic/AudioFileLoader.swift:364` and splits channels into mono buffers at `Sources/Orbisonic/AudioFileLoader.swift:480` through `:509`.
- Streaming sources validate channel count and output format at `Sources/Orbisonic/StreamingAudioFileSource.swift:329` through `:350`.
- PureAudio contract layouts live in `Sources/AudioContracts/AudioContracts.swift`:
  - named layouts start around `Sources/AudioContracts/AudioContracts.swift:179`
  - `.direct30` at `Sources/AudioContracts/AudioContracts.swift:210`
  - `.direct31` at `Sources/AudioContracts/AudioContracts.swift:214`
  - fallback layout at `Sources/AudioContracts/AudioContracts.swift:226` through `:247`
  - `SourceDescriptor` holds sample rate, channel count, and layout at `Sources/AudioContracts/AudioContracts.swift:283` through `:301`
- Direct-mode renderer layouts are also represented in `RendererRenderMode`, including `direct30` and `direct31` at `Sources/Orbisonic/RendererModule.swift:72` and `:73`.

Boundary:

- The current runtime owns layout in the Orbisonic target.
- The newer contract layer owns canonical layout language in `AudioContracts`.
- Replacing decode without preserving channel order would be unsafe for 30/31-channel and possible 52-channel material.

### 8. Which module routes source channels into Orbisonic renderer inputs?

Current owner:

- `OrbisonicEngine` routes one player/source node per channel into the normal monitor graph:
  - live source nodes are created at `Sources/Orbisonic/OrbisonicEngine.swift:600` through `:613`
  - streaming player nodes are connected at `Sources/Orbisonic/OrbisonicEngine.swift:1672` through `:1673`
  - prepared local player nodes are connected at `Sources/Orbisonic/OrbisonicEngine.swift:2116` through `:2117`
- `configureNormalMonitorNode` applies normal monitor gain/pan at `Sources/Orbisonic/OrbisonicEngine.swift:2155` through `:2161`.
- Sonic Sphere scene/matrix routing is modeled by `RendererMatrixBuilder.sceneModel` at `Sources/Orbisonic/RendererModule.swift:927` and `:931`.

Boundary:

- The current audible route is normal monitor routing in `OrbisonicEngine`.
- Sonic Sphere renderer-input mapping exists in renderer/matrix modules and AudioCore plans, but current audible monitor routing is separate.

### 9. Which module applies spatial rendering, Sonic Sphere mapping, Ambisonics handling, or custom layout logic?

Current owner:

- `Sources/Orbisonic/RendererModule.swift` owns renderer modes and Sonic Sphere static-bed mapping:
  - `RendererRenderMode` at `Sources/Orbisonic/RendererModule.swift:59`
  - direct modes at `Sources/Orbisonic/RendererModule.swift:72` and `:73`
  - `SonicSphereAudioRenderer` at `Sources/Orbisonic/RendererModule.swift:710`
  - `RendererMatrixBuilder` at `Sources/Orbisonic/RendererModule.swift:927`
  - `FeyStaticBedRenderer` at `Sources/Orbisonic/RendererModule.swift:991`
  - direct bypass matrix branches at `Sources/Orbisonic/RendererModule.swift:1287` and `:1289`
- Sample-to-matrix rendering is owned by `RendererMatrixSampleRenderer`, declared at `Sources/Orbisonic/RendererMatrixSampleRenderer.swift:3`.
- Normal monitor route planning explicitly avoids HRTF/AVAudioEnvironment/direct Sonic Sphere audible routing:
  - route descriptor fields at `Sources/Orbisonic/NormalMonitorRouteDescriptor.swift:19` through `:24`
  - route planner sets them false at `Sources/Orbisonic/NormalMonitorRouteDescriptor.swift:42` through `:47`
  - tests assert this for normal routes at `Tests/OrbisonicTests/NormalMonitorRouteDescriptorTests.swift:155` through `:160`
  - tests assert this for live routes at `Tests/OrbisonicTests/LiveNormalMonitorRouteTests.swift:186` through `:191`

Boundary:

- Current code has custom layout and Sonic Sphere static-bed mapping.
- No active Ambisonics decoder was identified in Task 3 searches. Renderer mode names and matrix code are custom/static-bed oriented.
- A wholesale replacement by a conventional media player renderer would risk downmix, speaker-order erosion, or loss of Direct 30/31 bypass semantics.

### 10. Which module writes to the OS audio device?

Current owner:

- `OrbisonicEngine` owns the active AVAudioEngine graph:
  - `AVAudioEngine` instance at `Sources/Orbisonic/OrbisonicEngine.swift:241`
  - mixer nodes at `Sources/Orbisonic/OrbisonicEngine.swift:242` and `:243`
  - graph connections `preVolumeMixer -> outputGainMixer -> mainMixerNode` at `Sources/Orbisonic/OrbisonicEngine.swift:1202` and `:1203`
  - engine starts for local/streaming/live paths at `Sources/Orbisonic/OrbisonicEngine.swift:413`, `:620`, `:654`, and `:2048`
- Output device selection is owned by `OrbisonicEngine.setOutputDevicePreservingPlayback` at `Sources/Orbisonic/OrbisonicEngine.swift:769`.
- Core Audio output device binding uses `kAudioOutputUnitProperty_CurrentDevice` at `Sources/Orbisonic/OrbisonicEngine.swift:500` and `:754`.
- `OrbisonicViewModel` delegates output route selection to the engine at `Sources/Orbisonic/OrbisonicViewModel.swift:8318`, `:8350`, and `:8392`.

Boundary:

- OS audio write is AVAudioEngine/Core Audio output.
- `OutputRouteMonitor` discovers routes; it does not write samples.
- `LiveInputCapture` is input-side HAL capture, not output-device writing.

### 11. Which module owns audio timing, PTS, latency, queue depth, underrun tracking, and drift correction?

Current owner:

- Local prepared/streaming playback time is primarily `OrbisonicEngine` and AVAudioPlayerNode time:
  - `currentTime` at `Sources/Orbisonic/OrbisonicEngine.swift:1069`
  - `playbackFrame` at `Sources/Orbisonic/OrbisonicEngine.swift:2395`
  - `player.lastRenderTime` and `playerTime(forNodeTime:)` at `Sources/Orbisonic/OrbisonicEngine.swift:2398` through `:2400`
- Streaming/gapless source frame ranges are owned by local sources and scheduler:
  - `LocalAudioFileSource` records `sourceFrameRange` at `Sources/Orbisonic/LocalAudioFileSource.swift:153` through `:166`
  - `LocalGaplessScheduler` retains source frame ranges at `Sources/Orbisonic/LocalGaplessScheduler.swift:774`, `:785`, and `:811`
- Queue depth and retained scheduled PCM are owned by `LocalGaplessScheduler`:
  - snapshot fields `retainedPCMBytes` and `scheduledAheadFrames` at `Sources/Orbisonic/LocalGaplessScheduler.swift:44` and `:45`
  - retained/scheduled accounting at `Sources/Orbisonic/LocalGaplessScheduler.swift:516` through `:520` and `:816` through `:817`
- Live latency and underrun/drop counters are owned by `LiveAudioPipe` and `LiveChannelRingBuffer`:
  - target latency and capacity setup at `Sources/Orbisonic/LiveAudioBridge.swift:557` through `:560`
  - underflow counters at `Sources/Orbisonic/LiveAudioBridge.swift:358` through `:360`
  - underflow accounting at `Sources/Orbisonic/LiveAudioBridge.swift:422` through `:423`
  - aggregate pipe status at `Sources/Orbisonic/LiveAudioBridge.swift:731` through `:744`
  - tests cover underflow and overflow at `Tests/OrbisonicTests/LiveAudioBridgeTests.swift:62` through `:91`
- AudioCore adapter paths carry frame indices:
  - source frame index fields in `Sources/AudioCore/OutputAdapters.swift:45`, `:111`, and `:141`
  - output coordinator uses `sourceBus.frameIndex` at `Sources/AudioCore/OutputAdapters.swift:608` through `:654`

Boundary:

- Current local playback does not expose a VLC-style PTS domain. It mostly uses source frames and AVAudioPlayerNode render time.
- Live capture owns latency/underrun counters in ring buffers.
- No active drift-correction module was identified in the current runtime search; sample-rate mismatch is diagnostic/validation-oriented.

### 12. Which module owns flush and drain semantics?

Current owner:

- `LocalGaplessScheduler` owns closest current flush-like behavior for local/gapless buffers:
  - `stop` invalidates generation and clears queue/source state at `Sources/Orbisonic/LocalGaplessScheduler.swift:189` through `:205`
  - `seek` invalidates generation, closes stale future sources, seeks, and refills at `Sources/Orbisonic/LocalGaplessScheduler.swift:230` through `:269`
  - scheduled-buffer completion releases retained buffers at `Sources/Orbisonic/LocalGaplessScheduler.swift:495` through `:543`
  - `flushPendingWorkForTesting` exists only for test synchronization at `Sources/Orbisonic/LocalGaplessScheduler.swift:548`
- `OrbisonicEngine.stop` clears live/local/test-tone paths at `Sources/Orbisonic/OrbisonicEngine.swift:788`.
- No general public runtime `drain` API was found by Task 3 searches. The only `drain` matches outside docs were `MeteringTelemetry.drainCopies` at `Sources/AudioCore/MeteringTelemetry.swift:154`, which drains copied metering blocks, not OS playback.

Boundary:

- Orbisonic has stop/seek/generation invalidation and completion-based release semantics.
- It does not currently expose a media-output lifecycle API shaped like VLC's `flush`/`drain` callbacks.

## Boundary Diagram

```text
[Transport/API]
    -> [MediaSource/Open]
    -> [Decode]
    -> [PCM Format Conversion]
    -> [Resample]
    -> [Channel Map]
    -> [Spatial Renderer]
    -> [Device Output]
```

### [Transport/API]

- Current owner: `OrbisonicViewModel` for user/source state and command entry points; `OrbisonicEngine` for playback graph commands.
- Evidence: `OrbisonicViewModel.playLocalTransport` at `Sources/Orbisonic/OrbisonicViewModel.swift:2435`; `OrbisonicEngine.play` at `Sources/Orbisonic/OrbisonicEngine.swift:640`; `OrbisonicEngine.pause` at `:713`; `OrbisonicEngine.stop` at `:788`; `OrbisonicEngine.seek(toProgress:)` at `:978`.
- Should it be replaceable: Partly. The UI command facade could be adapted, but source-state isolation must remain Orbisonic-owned.
- Could VLC plausibly replace this stage: Only for media-player transport semantics. It should not replace Orbisonic source-mode selection, Sonic Sphere routing state, Roon/Spotify service controls, or diagnostics ownership wholesale.
- What would break if replaced wholesale: selected-source isolation, live-loopback controls, Roon/Spotify boundary behavior, local library queue semantics, and diagnostics state could collapse into a conventional single media-player state.

### [MediaSource/Open]

- Current owner: `AudioFileProbe`, `AudioFileLoader`, `StreamingAudioFileSource`, `LocalAudioFileSource`, and `LiveInputCapture`.
- Evidence: `AudioFileProbe.probeAVAudioFile` at `Sources/Orbisonic/AudioFileProbe.swift:123`; `AudioFileLoader.load` at `Sources/Orbisonic/AudioFileLoader.swift:127`; `StreamingAudioFileSource` opens `AVAudioFile` at `Sources/Orbisonic/StreamingAudioFileSource.swift:327`; `LiveInputCapture` at `Sources/Orbisonic/LiveAudioBridge.swift:44`.
- Should it be replaceable: Yes, if the replacement preserves file/local/library/live-source separation and explicit diagnostics.
- Could VLC plausibly replace this stage: Possibly for local media opening, network URLs, or container access, but no active Plex/Part.key opener exists to replace in current source.
- What would break if replaced wholesale: mounted-local-file assumptions, library metadata, Matroska fallback behavior, live loopback capture, and app-specific source admission could be bypassed.

### [Decode]

- Current owner: `AudioFileLoader`, `StreamingAudioFileSource`, `LocalAudioFileSource`, `MatroskaFLACDemuxer`, and AVFoundation. Live loopback does not decode in Orbisonic.
- Evidence: `MatroskaFLACDemuxer.demuxToCAF` at `Sources/Orbisonic/MatroskaFLACSupport.swift:316`; `AudioFileLoader` invokes it at `Sources/Orbisonic/AudioFileLoader.swift:206`; AVAudioFile opens at `Sources/Orbisonic/AudioFileLoader.swift:257`, `:302`, `Sources/Orbisonic/StreamingAudioFileSource.swift:327`, and `Sources/Orbisonic/LocalAudioFileSource.swift:58`.
- Should it be replaceable: Yes for local compressed media, but not for live loopback PCM capture.
- Could VLC plausibly replace this stage: Plausible for demux/decode of local or network media if callbacks preserve PCM/channel metadata.
- What would break if replaced wholesale: existing Matroska/ffmpeg fallback, source-channel limit handling, layout detection, cancellation behavior, prepared-vs-streaming policy, and error/status semantics.

### [PCM Format Conversion]

- Current owner: `AudioFileLoader`, `StreamingAudioFileSource`, `LocalAudioFileSource`, `LiveInputCapture`, and AudioCore format validators.
- Evidence: `AVAudioConverter` in `AudioFileLoader` at `Sources/Orbisonic/AudioFileLoader.swift:431`; streaming converter at `Sources/Orbisonic/StreamingAudioFileSource.swift:350`; gapless converter at `Sources/Orbisonic/LocalAudioFileSource.swift:92`; live HAL stream format at `Sources/Orbisonic/LiveAudioBridge.swift:170`; AudioCore block format at `Sources/AudioCore/RenderKernels.swift:5`.
- Should it be replaceable: Only with a very explicit contract.
- Could VLC plausibly replace this stage: It could provide decoded sample callbacks in a requested sample format, but Orbisonic still needs to validate Float32/non-interleaved versus interleaved/int formats at the boundary.
- What would break if replaced wholesale: implicit interleaving, integer PCM, or packed channel assumptions could corrupt channel buffers, meters, or renderer matrices.

### [Resample]

- Current owner: no broad active resampler owner was found; local paths mostly preserve source sample rate and AudioCore validates mismatch.
- Evidence: prepared loader final sample rate from source format at `Sources/Orbisonic/AudioFileLoader.swift:539`; streaming output source sample rate at `Sources/Orbisonic/StreamingAudioFileSource.swift:485` and `:493`; AudioCore mismatch checks at `Sources/AudioCore/RenderKernels.swift:267` through `:270`; audit says conversion false at `Sources/AudioCore/RenderKernels.swift:443` through `:449`.
- Should it be replaceable: If introduced, it should be a separate auditable module.
- Could VLC plausibly replace this stage: VLC has resampling internally, but using it here would need proof that Orbisonic does not also resample or let Core Audio convert again.
- What would break if replaced wholesale: hidden SRC, double SRC, wrong route format negotiation, and masked sample-rate mismatch diagnostics.

### [Channel Map]

- Current owner: `AudioFileLoader`, `StreamingAudioFileSource`, `LocalAudioFileSource`, `LiveAudioPipe`, `NormalMonitorDownmixPolicy`, `RendererMatrixBuilder`, and AudioContracts layout descriptors.
- Evidence: prepared channel split at `Sources/Orbisonic/AudioFileLoader.swift:480` through `:509`; normal monitor gain/pan at `Sources/Orbisonic/OrbisonicEngine.swift:2155` through `:2161`; direct layouts at `Sources/AudioContracts/AudioContracts.swift:210` and `:214`; fallback layouts at `Sources/AudioContracts/AudioContracts.swift:226` through `:247`.
- Should it be replaceable: No, not wholesale. It is core Orbisonic product logic.
- Could VLC plausibly replace this stage: VLC might pass channel metadata, but Orbisonic must own final mapping to Sonic Sphere/normal monitor layouts.
- What would break if replaced wholesale: Direct 30/31, custom discrete layouts, 52-channel feasibility, and Sonic Sphere channel identity.

### [Spatial Renderer]

- Current owner: `RendererModule`, `RendererMatrixSampleRenderer`, and newer AudioCore render graph/kernels.
- Evidence: `RendererMatrixBuilder` at `Sources/Orbisonic/RendererModule.swift:927`; `FeyStaticBedRenderer` at `Sources/Orbisonic/RendererModule.swift:991`; `RendererMatrixSampleRenderer` at `Sources/Orbisonic/RendererMatrixSampleRenderer.swift:3`; direct bypass branches at `Sources/Orbisonic/RendererModule.swift:1287` and `:1289`.
- Should it be replaceable: No, unless replacing Orbisonic's core Sonic Sphere renderer intentionally.
- Could VLC plausibly replace this stage: Not as a drop-in. VLC can decode and output conventional audio, but Orbisonic's Sonic Sphere/static-bed/custom layout mapping must remain Orbisonic-owned unless the product is redesigned.
- What would break if replaced wholesale: Sonic Sphere 30.1, custom static-bed rendering, Direct 30/31 identity behavior, and meter isolation.

### [Device Output]

- Current owner: `OrbisonicEngine` via AVAudioEngine/Core Audio; AudioCore has contract-tested adapter plans.
- Evidence: AVAudioEngine at `Sources/Orbisonic/OrbisonicEngine.swift:241`; mixer graph connection at `Sources/Orbisonic/OrbisonicEngine.swift:1202` through `:1203`; output device property at `Sources/Orbisonic/OrbisonicEngine.swift:500` and `:754`; output route delegate calls at `Sources/Orbisonic/OrbisonicViewModel.swift:8318`, `:8350`, and `:8392`.
- Should it be replaceable: Possibly, but only if the replacement can preserve monitor route, production route, channel-count negotiation, and hardware diagnostics.
- Could VLC plausibly replace this stage: VLC's OS audio output could replace conventional output, but doing so wholesale would likely bypass Orbisonic route diagnostics and Sonic Sphere output planning.
- What would break if replaced wholesale: output route control, normal monitor / renderer output separation, LaunchServices-tested app behavior, live diagnostics, and production topology guarantees.

## Boundary Risks Introduced By Modularization

### Stale Buffers Crossing Module Boundaries

- Risk: prepared buffers, streaming chunks, and gapless retained buffers can outlive the user command that created them.
- Evidence: `LocalGaplessScheduler` uses generations at `Sources/Orbisonic/LocalGaplessScheduler.swift:129`, `:191`, `:235`, and `:787` through `:790` to reject stale work.
- Current mitigation: generation invalidation, source closure, scheduled completion release, and stop/seek reset paths.
- Replacement concern: any VLC callback bridge would need equivalent generation/session ownership or stale decoded buffers could play after a source switch.

### Thread Mismatches

- Risk: view-model commands, decode work, scheduler queues, AVAudioEngine render callbacks, and HAL input callbacks have different timing and blocking rules.
- Evidence: `LiveInputCapture` calls `AudioUnitRender` at `Sources/Orbisonic/LiveAudioBridge.swift:278` and writes to the pipe at `:291`; `LocalGaplessScheduler` uses a serial `stateQueue` around scheduling state at `Sources/Orbisonic/LocalGaplessScheduler.swift:84`.
- Current mitigation: realtime code writes to ring buffers; scheduler state is serialized; prepared decode is outside the realtime callback.
- Replacement concern: a blocking decode/open call on the wrong boundary could create underflows or UI stalls.

### Losing PTS Or Latency Metadata

- Risk: current local playback is frame-based and AVAudioPlayerNode-time based, not a full media PTS pipeline.
- Evidence: `OrbisonicEngine.playbackFrame` uses `lastRenderTime` and `playerTime` at `Sources/Orbisonic/OrbisonicEngine.swift:2395` through `:2400`; local chunk ranges are tracked at `Sources/Orbisonic/LocalAudioFileSource.swift:153` through `:166`; live target latency is built at `Sources/Orbisonic/LiveAudioBridge.swift:557` through `:560`.
- Current mitigation: local frame positions and live ring latency counters.
- Replacement concern: a decode bridge that drops media timestamps could make seek, queue position, latency, and diagnostics less reliable.

### Implicit Interleaved Versus Planar Assumptions

- Risk: Orbisonic's internal PCM path expects non-interleaved channel buffers; many media APIs can provide interleaved PCM by default.
- Evidence: `AudioFileLoader` splits into mono buffers at `Sources/Orbisonic/AudioFileLoader.swift:480` through `:509`; AudioCore's processing format defaults to Float32 non-interleaved at `Sources/AudioContracts/AudioContracts.swift:427`.
- Current mitigation: loader/source conversion and format validation.
- Replacement concern: a VLC callback bridge must not pass interleaved frames into code expecting one channel per buffer/ring.

### Implicit Float Versus Int Assumptions

- Risk: renderer and meter code operate on Float samples; integer PCM could clip, scale incorrectly, or be misread.
- Evidence: `RendererMatrixSampleRenderer` is the sample renderer at `Sources/Orbisonic/RendererMatrixSampleRenderer.swift:3`; AudioCore render block format is explicit in `Sources/AudioCore/RenderKernels.swift:5` through `:40`; live ring writes accept `UnsafePointer<Float>` at `Sources/Orbisonic/LiveAudioBridge.swift:374`.
- Current mitigation: `AVAudioConverter`, HAL format setup, and AudioCore format validation.
- Replacement concern: a decoder replacement must declare scaling, sample type, endian, and planar/interleaved layout.

### Hidden Downmix

- Risk: conventional media-player output stages may silently fold multichannel media to stereo or standard 5.1/7.1.
- Evidence: normal monitor routing is two-channel by design, but tests assert it does not use HRTF or an audible direct Sonic Sphere matrix at `Tests/OrbisonicTests/NormalMonitorRouteDescriptorTests.swift:155` through `:160`; Direct 30/31 bypass is preserved in renderer tests at `Tests/OrbisonicTests/RendererModuleTests.swift:353` through `:361`.
- Current mitigation: separate normal monitor and production renderer concepts.
- Replacement concern: using a conventional playback output wholesale could erase discrete source channels before Orbisonic sees them.

### Channel-Order Erosion

- Risk: layout metadata can degrade from named roles to "N channels" while crossing modules.
- Evidence: `AudioChannelLayoutDescriptor` direct and fallback layouts are in `Sources/AudioContracts/AudioContracts.swift:210` through `:247`; source descriptors validate layout and channel count at `Sources/AudioContracts/AudioContracts.swift:320` through `:329`.
- Current mitigation: layout descriptors, renderer-mode tests, and source-channel validation.
- Replacement concern: VLC or any decoder bridge must preserve physical/mapped/unmapped channel identity, especially for 30/31 and possible 52-channel sources.

### Resampling Twice

- Risk: a future decoder or output backend may resample while Core Audio or AudioCore validation also expects a specific rate.
- Evidence: current local paths preserve source rate at `Sources/Orbisonic/AudioFileLoader.swift:539` and `Sources/Orbisonic/StreamingAudioFileSource.swift:485`; AudioCore mismatch checks exist at `Sources/AudioCore/RenderKernels.swift:267` through `:270`.
- Current mitigation: visible mismatch validation and no broad hidden SRC owner in the inspected runtime path.
- Replacement concern: a VLC resampler plus Core Audio shared-mode conversion could create double SRC and make bad audio harder to attribute.

### Wrong Device Format Negotiation

- Risk: route/output channel count and sample rate can differ from source, monitor, or production expectations.
- Evidence: `OutputAdapters` validate desktop sample rate and stereo count at `Sources/AudioCore/OutputAdapters.swift:187` through `:204`; Dante validation checks sample rate and physical channel count at `Sources/AudioCore/OutputAdapters.swift:319` through `:350`; current runtime binds Core Audio output device at `Sources/Orbisonic/OrbisonicEngine.swift:500` and `:754`.
- Current mitigation: route validation, diagnostics, and output selection errors.
- Replacement concern: replacing OS output wholesale could hide the route format negotiated by the OS/backend.

### Shared-Mode OS Conversion

- Risk: macOS/Core Audio can adapt to the current output device, while Orbisonic also tracks source and route formats.
- Evidence: `OrbisonicEngine` connects the normal monitor graph as stereo into the main mixer at `Sources/Orbisonic/OrbisonicEngine.swift:1202` through `:1203`; output device changes restart the engine at `Sources/Orbisonic/OrbisonicEngine.swift:1226` through `:1255`.
- Current mitigation: visible route selection and restart logging.
- Replacement concern: if a backend hides OS conversion, Task 4 bad-audio reproduction needs instrumentation at source PCM, post-conversion PCM, post-channel-map PCM, and actual device format.

## Task 03 Conclusion

The exact current "plays audio" owner is not one module. `OrbisonicViewModel` owns user-facing transport/source state. `OrbisonicEngine` owns the AVAudioEngine playback graph, local/live scheduling, normal monitor output, and output-device binding. Local compressed-media opening/decode/conversion is owned by `AudioFileLoader`, `StreamingAudioFileSource`, `LocalAudioFileSource`, and `MatroskaFLACSupport`. Live loopback PCM capture is owned by `LiveInputCapture` and `LiveAudioPipe`. Channel/layout/renderer logic is split between Orbisonic runtime modules and newer `AudioContracts`/`AudioCore` contracts. Any future VLC/libVLC analysis must target a specific boundary rather than replacing the whole audio path by assumption.
