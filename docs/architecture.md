# Orbisonic Architecture

## Realtime Audio Family Inheritance

This project inherits the Realtime Audio Family Standards Package. The Bencina Realtime Callback Doctrine is mandatory for every callback and every callback-reachable function. Project-specific requirements may add stricter rules but may not weaken the family standard.

The adopted standards package lives under `docs/realtime-audio-family/`. Orbisonic-specific specialization lives in `docs/project/orbisonic-realtime-audio-profile.md`.

## Overview

Orbisonic is a native Swift/macOS app that routes, monitors, and renders local and live multichannel audio for Sonic Sphere. The current repository is a Swift Package Manager project with one executable target and three library targets:

- `AudioContracts`: shared value types, error vocabulary, channel/layout/session descriptors, metering snapshots, conversion ledger types, route descriptors, and monitor capability/status types.
- `AudioImport`: local asset readiness and managed import policy.
- `AudioCore`: pure audio planning, source adapters, render graph planning, render kernels, output adapters, metering telemetry, and Apple spatial headphone monitor logic.
- `Orbisonic`: the executable app, SwiftUI shell, AVAudioEngine ownership, live loopback capture, Core Audio route discovery, source integrations, renderer UI/model, monitor implementation, diagnostics, web state, app resources, and packaging-facing runtime code.

The architecture is a retrofit baseline. It describes the app as it exists now and should not be read as a rewrite plan.

## Core Subsystems

### Shared Audio Vocabulary

`Sources/AudioContracts/AudioContracts.swift` defines shared language for sample rates, channel roles, channel layouts, source kinds, source descriptors, Dante and desktop output formats, route capabilities, render modes, desktop monitor modes, meters, conversion ledgers, managed assets, readiness, and typed audio errors.

This target has no package dependency on app code. Its job is to keep app, import, and core audio layers using the same value language.

### Local Asset Import Policy

`Sources/AudioImport/LocalAssetImport.swift` classifies local assets for production readiness and managed import. It depends on `AudioContracts` and uses AVFoundation for file inspection and conversion-related work.

Its visible concepts include `LocalAssetProbeResult`, `ProductionLocalAssetGate`, and `ManagedAssetImporter`.

### Pure Audio Core

`Sources/AudioCore/` contains the package-level audio planning and deterministic processing layer:

- `AudioControl.swift`: high-level command and telemetry shell for source selection, session start, gain, route, import, and audit concepts.
- `AudioSessionPlanning.swift`: session planning, route capability validation, sample-rate policy, and stop/rebuild decisions.
- `SourceAdapters.swift`: typed local, live, Roon, Spotify, Aux, test tone, and off-source adapters.
- `RenderGraphPlan.swift`: immutable render graph plans, downmix and Dante plan structures, meters, validation, and publication.
- `RenderKernels.swift`: canonical audio blocks, source bus, matrix render kernel, desktop monitor renderer, Dante Sonic Sphere renderer, and render audit data.
- `OutputAdapters.swift`: offline desktop/Dante adapters and a dual-output render coordinator.
- `MeteringTelemetry.swift`: meter copy bus, accumulator, snapshots, display surfaces, and metering service.
- `Monitors/AppleSpatialHeadphoneMonitor.swift`: Apple spatial headphone route classification and monitor status logic.

This layer can use `AudioContracts` and `AudioImport`, but should not depend on SwiftUI or app UI state.

### Executable App

`Sources/Orbisonic/` owns the user-facing app and the concrete platform integrations:

- SwiftUI entry and shell: `OrbisonicApp.swift`, `ContentView.swift`, `DiagnosticsView.swift`, `OrbisonicDisclosureTray.swift`.
- App state and orchestration: `OrbisonicViewModel.swift`.
- AVAudioEngine ownership: `OrbisonicEngine.swift`.
- Live loopback capture: `LiveAudioBridge.swift`, `LoopbackSourceSupport.swift`, `RealtimeAtomicPrimitives.swift`, `RealtimeCallbackSafetyInstrumentation.swift`.
- Local file and library paths: `AudioFileLoader.swift`, `AudioFileProbe.swift`, `LocalAudioFileSource.swift`, `StreamingAudioFileSource.swift`, `LocalGaplessScheduler.swift`, `LocalGaplessTypes.swift`, `LocalMusicLibrary.swift`, `LocalMusicMetadataEnrichment.swift`, `MatroskaFLACSupport.swift`.
- Renderer and monitor paths: `RendererModule.swift`, `RendererMatrixSampleRenderer.swift`, `NormalMonitorStereoDownmixer.swift`, `NormalMonitorGraphTopology.swift`, `NormalMonitorRouteDescriptor.swift`, `NormalMonitorConversionLedger.swift`, `SpatialTuning.swift`, `PureAudioRouteCapabilityBridge.swift`.
- Integrations: `RoonNowPlayingMonitor.swift`, `RoonBridgeClient.swift`, `RoonArtworkCache.swift`, `SpotifyReceiverClient.swift`.
- Diagnostics and routes: `AppLogger.swift`, `DiagnosticsLogStore.swift`, `DebugTimingLog.swift`, `OutputRouteMonitor.swift`, `BlackHoleRouteRepair.swift`, `AudioSpatialUsageAudit.swift`, `MeteringService.swift`, `TestToneSupport.swift`, `OrbisonicWebServer.swift`.
  `MeteringService.swift` publishes fixed-size raw meter values from callback/tap ingress and leaves smoothing, calibration, and display-level mapping to value reads outside the callback path.
  `RealtimeCallbackSafetyInstrumentation.swift` defines Orbisonic's current callback performance budget, standard stress scene, preallocated timing probe, report counters, and gate status model. It is evidence plumbing; the current performance gate report still blocks full callback compliance for live matrix scratch allocation.

## Runtime Architecture

At runtime, the SwiftUI app starts through `OrbisonicApp` and renders `ContentView`. The view layer uses `OrbisonicViewModel` as the primary app state owner. The view model coordinates source selection, local library state, Roon and Spotify status, route choices, renderer settings, diagnostics, meters, and calls into `OrbisonicEngine` or integration services as needed.

The runtime flow is:

1. `ContentView` displays app state, source controls, meters, renderer controls, local music, diagnostics, and settings.
2. `OrbisonicViewModel` owns user-facing state and translates UI actions into source, route, engine, bridge, library, and diagnostics operations.
3. Source-specific services provide input material or metadata:
   - Local source code decodes and schedules file audio.
   - `LiveAudioBridge` captures live input from selected loopback devices.
   - Roon code reads logs and talks to the optional Roon bridge helper.
   - Spotify code talks to the embedded librespot FFI boundary.
4. `OrbisonicEngine` owns the live AVAudioEngine graph for local playback and live capture.
5. Renderer and monitor code derive Sonic Sphere production matrices, meter-only renderer data, or normal monitor downmixes.
6. Diagnostics and web state expose selected status to the native UI and local public/control web surfaces.

## Audio Architecture

Orbisonic has separate local-file and live-loopback paths. Local playback decodes file-backed audio through AVFoundation/FFmpeg-assisted helpers where needed, schedules it through engine-local code, and keeps playlist/gapless behavior in local source modules. Live playback captures selected Core Audio input devices through `LiveAudioBridge`.

The product-level output distinction is:

- Sonic Sphere production output: the primary spatial output target, represented by a 30.1 topology by default.
- Headphone or normal monitor output: a setup and preview path that should not become the source of truth for Sonic Sphere topology.

Current code and tests also represent an in-progress PureAudio architecture with typed session plans, source adapters, render graph plans, render kernels, output adapters, and metering telemetry. Some production runtime code still lives in the executable target because this is a retrofit, not a completed extraction.

Important audio constraints already visible in the repo:

- The source-channel cap is 64.
- The default production sample rate in shared contracts is 48 kHz.
- Dante 31-channel production eligibility is limited by sample rate and route capability rules.
- Direct 30 and Direct 30.1 renderer modes bypass bed rendering when source width matches.
- Sample-rate mismatch and channel-count mismatch are modeled as validation or diagnostic failures, not silent policy choices.
- Orbisonic renders channel beds or discrete channels exposed by Core Audio or upstream tools; it does not decode Dolby Atmos object metadata in the current README contract.

## Source Architecture

Current user-facing source modes are represented by `SourceMode`:

- `Off`
- `Roon`
- `Spotify`
- `Atmos DRP` (displayed as `Atmos`)
- `Aux Cable`
- `Local Files`
- `Test Tone`

Roon, Spotify, Atmos DRP, and Aux are live input modes. Local files, Atmos DRP, and test tones own their own transport path. Spotify is fixed to two live input channels in current source support. Roon, Spotify, Atmos DRP, and Aux use expected loopback device identities when available. Atmos DRP currently routes DRP output into `Orbisonic Aux Cable` through `AtmosDRPRoutingPolicy`; that temporary route is not the same selected source as Aux Cable.

The current model is selected-source oriented, not a mixer. Source switching code and tests should preserve the rule that Roon, Spotify, Atmos DRP, Aux, test tone, and local playback do not accidentally sum into each other.

## Renderer Architecture

Renderer code exists in both the app target and the PureAudio target:

- `Sources/Orbisonic/RendererModule.swift` defines the user-facing Sonic Sphere renderer model, FEY static-bed renderer, preset store, supported bed modes, Auro modes, Direct 30, and Direct 30.1 behavior.
- `Sources/Orbisonic/RendererMatrixSampleRenderer.swift` renders matrix sample windows for tests and metering support.
- `Sources/Orbisonic/OrbitalVUMeterModel.swift` maps value-only meter snapshots to orbital monitor or Sonic Sphere marker state without owning audio graph, route, tap, buffer, or SceneKit objects.
- `Sources/Orbisonic/ContentView.swift` owns the active Renderer tab orbital VU presentation through `OrbitalSonicSphereMeterPanel` and `SonicSphereRendererSceneView`, fed only by value meter state.
- `Sources/AudioCore/RenderGraphPlan.swift` and `Sources/AudioCore/RenderKernels.swift` model immutable render graph planning and deterministic render kernels.

The current default production topology is Sonic Sphere 30.1: 30 full-range spatial outputs plus one LFE output. Renderer changes should be treated as high risk because they can alter production output.

## Monitor Architecture

The normal monitor path is separate from Sonic Sphere production topology. Its implementation surface includes:

- `NormalMonitorStereoDownmixer.swift`
- `NormalMonitorGraphTopology.swift`
- `NormalMonitorRouteDescriptor.swift`
- `NormalMonitorConversionLedger.swift`
- `AudioSpatialUsageAudit.swift`
- `AudioCore/Monitors/AppleSpatialHeadphoneMonitor.swift`

Tests currently assert that the normal monitor path does not use direct Sonic Sphere audible output, does not silently enable spatial fallback, omits LFE by default unless an audition policy is explicit, and keeps meters from mutating audible output.

Apple spatial headphone code is present as a monitor feature boundary, but route and entitlement behavior requires real runtime verification.

## UI Architecture

The UI is native SwiftUI with supporting AppKit and SceneKit pieces. `ContentView.swift` is the large shell and includes the current `StageTab` set:

- `Input`
- `Renderer`
- `Output`
- `VU`
- `Local Music`
- `Diagnostics`
- `Settings`

The left/player area and detailed tabs are driven by `OrbisonicViewModel`, source-specific row models, meter models, local music models, and diagnostics models. `DiagnosticsView.swift` holds the dedicated troubleshooting surface.

`AGENTS.md`, this architecture document, and the current `StageTab` source are aligned on these tab names as of Prompt 08.

Naming note: `Local Files` is the source-mode/raw value used by source contracts and web/control values. `Local Music` is the current operator-facing label in the native UI and public/control surfaces.

## External Integrations

- Core Audio and AVFoundation: audio file decoding, AVAudioEngine graph, live input capture, output and input route discovery, route repair, and audio formats.
- Roon logs: `RoonNowPlayingMonitor.swift` parses Roon server logs for now-playing and signal-path data.
- Roon bridge helper: `Sources/Orbisonic/Resources/RoonBridge/bridge.js` and `package.json` define an optional Node helper for Roon transport control.
- Spotify receiver: `SpotifyReceiverClient.swift`, `Vendor/librespot/`, `Vendor/orbisonic-librespot-ffi/`, and `scripts/build-embedded-librespot.sh` define the embedded librespot boundary.
- FFmpeg tools: `MatroskaFLACSupport.swift`, `AudioFileProbe.swift`, and `Sources/Orbisonic/Resources/Tools/FFmpegTools.md` support probing or demuxing paths for formats Core Audio may not expose directly.
- Local web surface: `OrbisonicWebServer.swift` exposes public/control state and commands.
- Orbisonic Inputs: the runtime expects dedicated loopback devices for Roon, Aux, and Spotify live capture when those source modes are used.

## Error-Handling Model

The repo favors typed errors and explicit diagnostic state:

- `AudioContracts.AudioError` describes shared audio validation failures.
- `AudioImport` returns readiness and managed import decisions rather than silently converting for production.
- `AudioCore` validates session, route, source, graph, and output plan failures.
- App modules expose localized errors for live input, file loading, streaming, probing, Roon bridge, Spotify, local library mutation, and diagnostics.
- Live silence is represented as a state to diagnose, not as a condition to hide with synthetic signal.

## Logging And Diagnostics Model

Logging and diagnostics are split across:

- `AppLogger.swift` for app logging.
- `DebugTimingLog.swift` for timing diagnostics.
- `DiagnosticsLogStore.swift` for bounded log reads and filtering.
- `DiagnosticsView.swift` for native troubleshooting UI.
- `InputSourceStatusPanelModel.swift` for source status text.
- `OrbisonicWebServer.swift` for public and control state.
- Roon and live-loopback-specific status models.

For live Roon issues, AGENTS.md requires comparing Roon output sample rate, Orbisonic Roon Input nominal sample rate, input route name/channel count, live meter peak, and buffer underflow/drop counters. A Roon log line is not proof that audio reached Orbisonic's loopback capture path.

## Security And Privacy Model

Tracked files should avoid secrets, personal names, local usernames, machine-specific absolute paths, and private data. Repo docs should use repo-relative paths and app-managed runtime locations.

Runtime integrations can involve local logs, Application Support data, Roon authorization, Spotify receiver state, microphone permission for loopback devices, local web controls, and app signing or entitlements. Those surfaces should be documented and tested without committing tokens, caches, or personal paths.

## Deployment And Installer Model

Current deployment surfaces include:

- `Orbisonic.app` in the repo root as the double-clickable app bundle.
- `scripts/refresh-orbisonic-app.sh` to build, copy the executable and resources, stamp git metadata, clear xattrs, sign ad hoc, verify codesign, and lint the plist.
- `scripts/reopen-orbisonic-app.sh` to quit and reopen through LaunchServices.
- `scripts/build-installer.sh` to build an app package.
- `installer/Orbisonic-*.pkg` for app-only packages.
- `installer/OrbisonicSuite-*.pkg` for suite packages that include the virtual input drivers.
- `scripts/install-roon-bridge.sh` for the optional local Roon bridge dependencies.
- `scripts/build-embedded-librespot.sh` for the Rust static library used by the Spotify receiver boundary.

GUI or audio behavior should be judged through the app bundle and LaunchServices, not by running `Orbisonic.app/Contents/MacOS/Orbisonic` directly.

## Architecture Rules

- Work only in the active Orbisonic repo for active product changes.
- Preserve current behavior unless a prompt explicitly allows behavior changes.
- Keep audio-path correctness ahead of UI polish.
- Do not hide all-zero live input with buffering, fake gain, synthetic signal, or fake channels.
- Keep local file playback separate from live loopback capture.
- Keep Roon, Spotify, Atmos DRP, Aux, local files, and test tones isolated unless a future mixer contract is accepted.
- Treat Sonic Sphere 30.1 as the primary production output topology.
- Treat headphone or normal monitor output as a monitor path.
- Do not silently change public contracts or module boundaries.
- Avoid major dependencies during the control-doc retrofit.
- Document hardware-only verification instead of faking it in automated tests.

## Known Risks

- Historical migration notes under `docs/PureAudio/` may not all match current source and should be revalidated before a claim is elevated into a binding contract.
- Some runtime audio behavior requires hardware or external-service verification: Sonic Sphere / Dante, loopback devices, Roon, Spotify, Dolby Reference Player, microphone permission, LaunchServices, signing, entitlements, and installer behavior.
- The app target still owns substantial concrete audio behavior while the PureAudio target set exists beside it, so boundary docs must distinguish current implementation from target direction.
- Embedded librespot linking depends on local build artifacts under `.build/orbisonic-librespot`.
- Roon log parsing can show player activity without proving live loopback signal.
- Monitor and renderer boundary regressions can be subtle because both paths expose metering and preview surfaces.
- The current release state is ready for manual verification, not yet release-verified.

## Last Updated

- 2026-05-05: Refreshed by Prompt 19 after the hardening and readiness sequence.
