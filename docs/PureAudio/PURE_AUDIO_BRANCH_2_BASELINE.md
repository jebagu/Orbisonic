# Pure Audio Branch 2 Baseline

This document is the governing baseline for `pure-audio-branch-2`. Prompt 1 creates the branch, records the current audio truth, and defines the architecture rules for later prompts. It does not implement the rewrite.

## Branch Marker

- Previous branch before this work: `codex/pure-audio-branch`
- End marker commit on previous branch: `4063298a7c466d46c6694487baee5d8cb3eac91e`
- End marker commit message: `End of current branch: codex/pure-audio-branch`
- New branch for this rewrite track: `pure-audio-branch-2`
- This branch starts from the end marker commit above.

## Current Audio Truth

Orbisonic currently has one audible output path:

```text
source PCM
-> Normal Monitor stereo downmix
-> outputGainMixer
-> mainMixerNode
-> selected Core Audio output
```

The current Sonic Sphere renderer produces a 31-channel projection for analysis and meters, but it is not currently connected as an audible 31-channel output.

The current Normal Monitor topology is represented by `NormalMonitorGraphTopology.audible(...)` as a single path:

```text
sourcePCM
-> normalMonitorStereoDownmixer
-> outputGainMixer
-> mainMixerNode
-> systemOutput
```

`NormalMonitorAudibleRouteSelector` currently ignores renderer mode, active output route, renderer output route, and required Sonic Sphere output channel count, then returns the Normal Monitor audible route. `RendererAudioRoutingPolicy.usesDirectRendererAudio(...)` currently returns `false`.

## Target Architecture

The rewrite target is a sealed `AudioCore` subsystem:

- Only `AudioCore` mutates live audio.
- Everything outside `AudioCore` requests changes through typed commands or observes read-only snapshots.
- No UI, VU, metadata parser, renderer display, route picker, or view model may mutate live audio objects.
- Audio mutation is command-only and validation-gated.
- Runtime state leaves `AudioCore` as immutable snapshots and lossy telemetry.

The two production outputs are siblings:

1. Desktop stereo monitor: headphones, MacBook speakers, or a selected ordinary stereo Core Audio output.
2. Dante renderer output: 31 logical channels, meaning 30 full-range Sonic Sphere channels plus 1 LFE/sub.

If the physical Dante device exposes 32 channels, channel 32 is reserved and silent unless explicitly assigned later.

There must be one session sample rate. The production audio engine must not hide sample-rate conversion.

All real-time audio buffers inside `AudioCore` must be:

- Float32.
- Non-interleaved or explicitly deinterleaved.
- Explicit about channel count.
- Explicit about channel layout.
- At the session sample rate.

Metering is copy-only and lossy. It must never block, mutate the graph, install random graph taps, own render buffers, or influence output.

Dante is the production output. Desktop monitor is a sibling confidence output. Desktop failure must not perturb Dante.

A VU stack rewrite must be unable to affect audible audio.

## Current Known Files

Normal Monitor stereo path:

- `Sources/Orbisonic/NormalMonitorGraphTopology.swift`
- `Sources/Orbisonic/NormalMonitorRouteDescriptor.swift`
- `Sources/Orbisonic/NormalMonitorStereoDownmixer.swift`
- `Sources/Orbisonic/NormalMonitorConversionLedger.swift`
- `Sources/Orbisonic/OrbisonicEngine.swift`

Engine and live graph:

- `Sources/Orbisonic/OrbisonicEngine.swift`
- `Sources/Orbisonic/LiveAudioBridge.swift`
- `Sources/Orbisonic/LoopbackSourceSupport.swift`
- `Sources/Orbisonic/BlackHoleRouteRepair.swift`

Local file probing, loading, streaming, and external tool support:

- `Sources/Orbisonic/AudioFileProbe.swift`
- `Sources/Orbisonic/AudioFileLoader.swift`
- `Sources/Orbisonic/StreamingAudioFileSource.swift`
- `Sources/Orbisonic/MatroskaFLACSupport.swift`
- `Sources/Orbisonic/LocalMusicLibrary.swift`

Renderer and Sonic Sphere matrix support:

- `Sources/Orbisonic/RendererModule.swift`
- `Sources/Orbisonic/RendererMatrixSampleRenderer.swift`
- `Sources/Orbisonic/SpatialTuning.swift`
- `Sources/Orbisonic/SurroundSupport.swift`

Metering and route discovery:

- `Sources/Orbisonic/MeteringService.swift`
- `Sources/Orbisonic/OutputRouteMonitor.swift`

Test tone support:

- `Sources/Orbisonic/TestToneSupport.swift`
- Diagnostic tone entry points in `Sources/Orbisonic/OrbisonicEngine.swift`
- UI command wiring in `Sources/Orbisonic/OrbisonicViewModel.swift`, `Sources/Orbisonic/ContentView.swift`, `Sources/Orbisonic/DiagnosticsView.swift`, and `Sources/Orbisonic/OrbisonicWebServer.swift`

State, UI, and web surfaces that currently touch or expose audio state:

- `Sources/Orbisonic/OrbisonicViewModel.swift`
- `Sources/Orbisonic/ContentView.swift`
- `Sources/Orbisonic/InputSourceStatusPanelModel.swift`
- `Sources/Orbisonic/DiagnosticsView.swift`
- `Sources/Orbisonic/OrbisonicWebServer.swift`

Pure Audio layers added during this branch:

- `Sources/AudioContracts/`
- `Sources/AudioCore/AudioControl.swift`
- `Sources/AudioCore/AudioCoreShell.swift`
- `Sources/AudioCore/AudioSessionPlanner.swift`
- `Sources/AudioCore/RenderGraphPlan.swift`
- `Sources/AudioCore/RenderGraphPlanner.swift`
- `Sources/AudioCore/RenderKernels.swift`
- `Sources/AudioCore/SourceAdapters.swift`
- `Sources/AudioCore/OutputAdapters.swift`
- `Sources/AudioImport/`

Repo structure note:

- The repository already has lowercase `docs/` for older documents.
- On this macOS checkout, the requested `Docs/PureAudio/` path resolved into the existing lowercase `docs/` tree.
- The actual tracked baseline location is `docs/PureAudio/`.

## Current Known Tests

Normal Monitor topology and audible route shape:

- `Tests/OrbisonicTests/NormalMonitorGraphTopologyTests.swift`
- `Tests/OrbisonicTests/NormalMonitorRouteDescriptorTests.swift`
- `Tests/OrbisonicTests/NormalMonitorRouteBranchRemovalTests.swift`
- `Tests/OrbisonicTests/LiveNormalMonitorRouteTests.swift`

Golden audio and stereo downmix:

- `Tests/OrbisonicTests/NormalMonitorGoldenAudioTests.swift`
- `Tests/OrbisonicTests/NormalMonitorStereoDownmixerTests.swift`

Renderer matrix and meter-only Sonic Sphere projection:

- `Tests/OrbisonicTests/RendererModuleTests.swift`
- `Tests/OrbisonicTests/RendererMatrixSampleRendererTests.swift`
- `Tests/OrbisonicTests/SonicSphereMeteringTests.swift`
- `Tests/OrbisonicTests/SpatialTuningTests.swift`
- `Tests/OrbisonicTests/VURoutingViewTests.swift`

Metering isolation:

- `Tests/OrbisonicTests/MeteringServiceTests.swift`
- `Tests/OrbisonicTests/MeteringIsolationTests.swift`

Loopback policy and route safety:

- `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift`
- `Tests/OrbisonicTests/LiveAudioBridgeTests.swift`
- `Tests/OrbisonicTests/SpotifyReceiverClientTests.swift`
- `Tests/OrbisonicTests/AudioSpatialUsageAuditTests.swift`

Local file probing, loading, and streaming:

- `Tests/OrbisonicTests/AudioFileProbeTests.swift`
- `Tests/OrbisonicTests/StreamingAudioFileSourceTests.swift`
- `Tests/OrbisonicTests/MatroskaFLACSupportTests.swift`
- `Tests/OrbisonicTests/LocalPlayerStabilizationTests.swift`

Conversion ledger:

- `Tests/OrbisonicTests/NormalMonitorConversionLedgerTests.swift`

Test tone support:

- `Tests/OrbisonicTests/TestToneSupportTests.swift`
- Tone-related assertions also exist in `Tests/OrbisonicTests/VURoutingViewTests.swift` and `Tests/OrbisonicTests/SpatialTuningTests.swift`.

Pure Audio tests added during this branch:

- `Tests/AudioContractsTests/`
- `Tests/AudioCoreTests/AudioControlTests.swift`
- `Tests/AudioCoreTests/AudioSessionPlannerTests.swift`
- `Tests/AudioCoreTests/RenderGraphPlanTests.swift`
- `Tests/AudioCoreTests/RenderKernelTests.swift`
- `Tests/AudioCoreTests/SourceAdapterTests.swift`
- `Tests/AudioCoreTests/OutputAdapterTests.swift`
- `Tests/AudioImportTests/`
- Architecture boundary tests under `Tests/OrbisonicTests/`

## High-Level Migration Order

1. Freeze this baseline and keep current behavior intact.
2. Introduce `AudioCore` contracts, commands, snapshots, validation types, and immutable render graph planning without moving the live engine yet.
3. Introduce `AudioImport` contracts for probing, decoding, and offline managed-asset conversion.
4. Move route/device validation behind `AudioCore` boundary adapters.
5. Move local file source adaptation into canonical Float32, non-interleaved buffers at the session rate.
6. Move loopback/live capture into canonical source adapters.
7. Build an immutable render graph planner for desktop monitor and Dante renderer siblings.
8. Add production Dante output validation and a 31-channel output adapter.
9. Replace current meter plumbing with copy-only `MeterCopyBus` snapshots.
10. Update UI/view model/web surfaces to command-only mutation and read-only snapshots.
11. Add boundary tests that prevent UI, VU, metadata, route picker, or renderer display code from mutating live audio objects.
12. Only after those boundaries exist, connect Dante production output.

Prompt 10 adds the dual-output adapter architecture as validation/offline structure:

- Desktop and Dante are now modeled as separate output adapter protocols.
- `DualOutputRenderCoordinator` renders desktop and Dante from one canonical source bus as sibling blocks.
- Desktop route failure is isolated from Dante render output.
- Dante route failure is treated as production-output failure.
- The offline adapters consume deterministic blocks and expose value-only status snapshots.
- Live dual physical output is not implemented yet. The code must not claim Dante is audible until a real AudioCore-owned live Dante adapter is added and verified.

## Prompt 1 Non-Goals

Prompt 1 does not:

- Implement `AudioCore`.
- Implement `AudioImport`.
- Connect Dante.
- Rewrite VU.
- Remove current Normal Monitor behavior.
- Remove existing tests.
- Change local playback, loopback capture, route selection, renderer math, or test tone behavior.
- Refactor Swift source files.
- Change the app bundle.

## Governing Rule

Only `AudioCore` mutates audio. Everything else requests changes or observes snapshots.
