# Orbisonic Implementation Map

## Purpose

This map helps a future Orbisonic maintainer or Codex session find the files and project control surfaces that implement or govern a feature without first reading the whole repository. It is descriptive, not a contract. Binding behavior belongs in `docs/contracts.md`, accepted ADRs, and the current source/tests.

## Top-Level Structure

- `AGENTS.md`: repo-specific operating rules for Codex work.
- `README.md`: product overview, run instructions, installer notes, Roon bridge notes, and head-tracking note.
- `Package.swift`: SwiftPM products, targets, resources, linker settings, and test targets.
- `Sources/`: Swift package source for `AudioContracts`, `AudioImport`, `AudioCore`, and `Orbisonic`.
- `Tests/`: XCTest coverage for all SwiftPM targets.
- `docs/`: feature, migration, project control, and design docs.
- `docs/audits/`: retrofit audit reports and follow-up planning evidence.
- `docs/PureAudio/`: PureAudio migration and boundary docs. Treat these as historical migration evidence unless a current contract, system flow, or accepted ADR elevates a claim.
- `docs/realtime-audio-family/`: adopted Realtime Audio Family Standards Package, including callback doctrine, architecture standards, contracts, testing guidance, OpenSpec baseline, and templates.
- `docs/project/`: Orbisonic-specific project profiles and specialization docs for inherited family standards.
- `docs/release-verification.md`: release, installer, app bundle, LaunchServices, helper, and manual hardware verification checklist.
- `docs/readiness-summary.md`: current readiness result, automated evidence, manual verification still required, release blockers, and recommended next action.
- `.tasks/`: bounded sequential task files for audits, test-gap passes, hardening, realtime/orbital VU work, release verification docs, readiness refresh, and manual release verification.
- Root `Open Orbisonic.command`: the single double-clickable daily opener for the canonical app bundle, currently including the VU quiet-signal fix. It delegates to the repo LaunchServices reopen script, which forces the repo-root app bundle path so an installed `/Applications/Orbisonic.app` with the same bundle ID is not selected instead. It does not rebuild or re-sign the app.
- Root `Open Orbisonic - VU Quiet Fix.command`: named alias for the same canonical VU quiet-signal build. It delegates to the same LaunchServices reopen script and does not rebuild or re-sign the app.
- `scripts/`: app refresh, repo-bundle-forced LaunchServices reopen, app installer, suite installer, Roon bridge, branch/deprecated-ref launcher helpers, and embedded librespot build scripts.
- `installer/`: app-only and suite package artifacts. Historical packages may remain for evidence, but current packages must be rebuilt from the merged canonical HEAD before release use.
- `Vendor/`: vendored librespot source and Orbisonic librespot FFI crate.
- `calibration/`: Sonic Sphere speaker layout JSON files.
- `Orbisonic.app`: current double-clickable macOS app bundle.
- `Orbisonic.entitlements`: entitlement template for Xcode/signing work.
- `RELEASE_NOTES.md`: release notes for packaged versions.
- `archive/` and `deprecated/`: historical web or launcher artifacts, not active product source.

## Realtime Audio Governance Map

- Adopted family standard package: `docs/realtime-audio-family/`
- Mandatory package rules: `docs/realtime-audio-family/PACKAGE-RULES.md`
- Callback safety doctrine: `docs/realtime-audio-family/docs/standards/realtime-callback-safety-doctrine.md`
- Realtime architecture standard: `docs/realtime-audio-family/docs/standards/realtime-audio-architecture-standard.md`
- Event and state publication standard: `docs/realtime-audio-family/docs/standards/event-queue-and-state-publication-standard.md`
- Performance gate standard: `docs/realtime-audio-family/docs/standards/performance-gate-standard.md`
- Callback impact template: `docs/realtime-audio-family/examples/callback-impact-report.template.md`
- Performance report template: `docs/realtime-audio-family/examples/performance-report.template.md`
- Orbisonic inheritance ADR: `docs/decisions/0013-realtime-audio-family-standards-inheritance.md`
- Orbisonic project profile: `docs/project/orbisonic-realtime-audio-profile.md`
- Current callback reachability audit: `docs/audits/0003-callback-reachability-audit.md`
- Current callback performance gate report: `docs/audits/0004-callback-safety-performance-gates.md`
- Current final realtime compliance audit: `docs/audits/0005-realtime-family-compliance-final-audit.md`
- Active work package: `.tasks/020-realtime-family-orbital-vu-work-package.md`

Callback-adjacent work includes audio callbacks, render closures, event queues, controls used by audio, route plans, meter publication, panic/recovery, device I/O, and backend adapter boundaries.

## UI Theme And Settings

- `Sources/Orbisonic/OrbisonicTheme.swift`: owns `OrbisonicColorScheme`, `OrbisonicPalette`, VU ramp stops, the SwiftUI palette environment, and the `LabTheme` compatibility facade used by current SwiftUI surfaces.
- `Sources/Orbisonic/ContentView.swift`: owns the fixed-height non-scrollable Player rail, four-row Player metadata cap, `Settings` color theme selector, natural equal-height panel row layout behavior, themed horizontal linear controls with direct visible-track drag handling, palette-aware VU fills, `Sound Settings`, and app-wide palette application.
- Tests: `Tests/OrbisonicTests/OrbisonicThemeTests.swift` for palette defaults/migration/ramp behavior and `Tests/OrbisonicTests/OrbisonicUITweakTests.swift` for Player rail, Settings, and Renderer surface structure.

## SwiftPM Target Map

### `AudioContracts`

- Product: library `AudioContracts`
- Source: `Sources/AudioContracts/AudioContracts.swift`
- Depends on: no package targets
- Apparent responsibility: shared value vocabulary for sample rates, processing format, channel roles, layout descriptors, source descriptors, output formats, route capabilities, render modes, desktop monitor modes, meters, conversion ledgers, managed assets, readiness, and audio errors.
- Tests: `Tests/AudioContractsTests/AudioContractsTests.swift`

### `AudioImport`

- Product: library `AudioImport`
- Source: `Sources/AudioImport/LocalAssetImport.swift`
- Depends on: `AudioContracts`
- Apparent responsibility: local asset production readiness, sample-rate policy, managed import, and conversion ledger generation for local files.
- Tests: `Tests/AudioImportTests/LocalAssetImportTests.swift`

### `AudioCore`

- Product: library `AudioCore`
- Sources:
  - `Sources/AudioCore/AudioControl.swift`
  - `Sources/AudioCore/AudioSessionPlanning.swift`
  - `Sources/AudioCore/MeteringTelemetry.swift`
  - `Sources/AudioCore/Monitors/AppleSpatialHeadphoneMonitor.swift`
  - `Sources/AudioCore/OutputAdapters.swift`
  - `Sources/AudioCore/RenderGraphPlan.swift`
  - `Sources/AudioCore/RenderKernels.swift`
  - `Sources/AudioCore/SourceAdapters.swift`
- Depends on: `AudioContracts`, `AudioImport`
- Apparent responsibility: session planning, source adapter policy, render graph plans, pure render kernels, output adapter behavior, metering telemetry, Apple spatial headphone monitor boundary, and command/telemetry shell types.
- Tests: `Tests/AudioCoreTests/`

### `Orbisonic`

- Product: executable `Orbisonic`
- Source: `Sources/Orbisonic/`
- Depends on: `AudioContracts`, `AudioImport`, `AudioCore`
- Resources:
  - `Sources/Orbisonic/Resources/AppIcon/`
  - `Sources/Orbisonic/Resources/AppLogos/`
  - `Sources/Orbisonic/Resources/LayoutIcons/`
  - `Sources/Orbisonic/Resources/RoonBridge/`
  - `Sources/Orbisonic/Resources/Tools/`
- Linker settings: links local `orbisonic_librespot_ffi` static library from `.build/orbisonic-librespot` and Apple audio/system frameworks.
- Apparent responsibility: UI shell, app state, concrete AVAudioEngine graph, live input capture, Core Audio routes, local playback, source integrations, renderer/monitor UI and implementation, diagnostics, local web surface, and app bundle runtime behavior.
- Tests: `Tests/OrbisonicTests/`

## Feature Map

### Local File Playback

- Implementation:
  - `Sources/Orbisonic/AudioFileLoader.swift`
  - `Sources/Orbisonic/AudioFileProbe.swift`
  - `Sources/Orbisonic/LocalAudioFileSource.swift`
  - `Sources/Orbisonic/StreamingAudioFileSource.swift`
  - `Sources/Orbisonic/LocalGaplessScheduler.swift`
  - `Sources/Orbisonic/LocalGaplessTypes.swift`
  - `Sources/Orbisonic/LegacyLocalFileProductionGate.swift`
  - `Sources/AudioImport/LocalAssetImport.swift`
  - `Sources/AudioCore/SourceAdapters.swift`
- Related tests:
  - `Tests/OrbisonicTests/AudioFileProbeTests.swift`
  - `Tests/OrbisonicTests/LocalAudioFileSourceTests.swift`
  - `Tests/OrbisonicTests/StreamingAudioFileSourceTests.swift`
  - `Tests/OrbisonicTests/LocalGaplessSchedulerTests.swift`
  - `Tests/OrbisonicTests/LocalGaplessTypesTests.swift`
  - `Tests/OrbisonicTests/LocalGaplessPlaybackPolicyTests.swift`
  - `Tests/OrbisonicTests/LocalPlayerStabilizationTests.swift`
  - `Tests/AudioImportTests/LocalAssetImportTests.swift`
  - `Tests/AudioCoreTests/SourceAdapterTests.swift`
- Related docs:
  - `README.md`
  - `docs/LocalGaplessPlaybackPlan.md`
  - `docs/PureAudio/SAMPLE_RATE_AND_LOCAL_FILE_POLICY.md`

### Playlist And Local Library Support

- Implementation:
  - `Sources/Orbisonic/LocalMusicLibrary.swift`
  - `Sources/Orbisonic/LocalMusicMetadataEnrichment.swift`
  - `Sources/Orbisonic/LocalGaplessScheduler.swift`
  - `Sources/Orbisonic/OrbisonicViewModel.swift`
  - `Sources/Orbisonic/ContentView.swift`
- Related tests:
  - `Tests/OrbisonicTests/LocalMusicMetadataEnrichmentTests.swift`
  - `Tests/OrbisonicTests/LocalPlayerStabilizationTests.swift`
  - `Tests/OrbisonicTests/OrbisonicUITweakTests.swift`
  - `Tests/OrbisonicTests/MatroskaFLACSupportTests.swift`
- Related docs:
  - `docs/LocalGaplessPlaybackPlan.md`
  - `docs/product-brief.md`

### Source Selection And Isolation

- Implementation:
  - `Sources/Orbisonic/OrbisonicViewModel.swift`
  - `Sources/Orbisonic/LoopbackSourceSupport.swift`
  - `Sources/Orbisonic/OrbisonicWebServer.swift`
- Related tests:
  - `Tests/OrbisonicTests/OrbisonicWebStateTests.swift`
  - `Tests/OrbisonicTests/LocalPlayerStabilizationTests.swift`
  - `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift`
  - `Tests/AudioCoreTests/SourceAdapterTests.swift`
- Related docs:
  - `docs/contracts.md`
  - `docs/system-flows.md`
  - `docs/test-strategy.md`
  - `docs/decisions/0004-selected-source-only-rule.md`

### Live Loopback Capture

- Implementation:
  - `Sources/Orbisonic/LiveAudioBridge.swift`
    - Owns `LiveInputCapture`, preallocated `LiveInputCaptureBufferStorage`, fixed-capacity `LiveChannelRingBuffer`, and `LiveAudioPipe`.
    - `LiveInputCaptureBufferStorage` prepares a fixed 8,192-frame HAL callback buffer capacity before capture starts; oversized callback blocks return an error status rather than allocating in the callback.
    - `LiveChannelRingBuffer` uses preallocated raw Float storage, atomic read/write cursors, atomic status counters, and nonblocking trim/read/peek coordination instead of callback-facing `NSLock`.
    - `RealtimeMeterLevelStorage` stores latest live meter levels in fixed atomic slots so UI snapshots do not block the audio transfer path.
  - `Sources/Orbisonic/RealtimeAtomicPrimitives.swift`
    - Owns the project-local realtime atomic integer, flag, float, max-counter, and fixed meter-level storage helpers shared by live transfer, metering publication, and callback safety instrumentation.
  - `Sources/Orbisonic/RealtimeCallbackSafetyInstrumentation.swift`
    - Owns the Slice 8 callback performance budget, standard stress scene, preallocated callback duration probe, explicit safety counters, gate report, and synthetic local stress harness. Current gates warn on missing host-level malloc/free and lock/wait interposition and block on explicit nonzero callback allocation counts.
  - `Sources/Orbisonic/LoopbackSourceSupport.swift`
    - Owns `LiveLoopbackDiagnostics`, the deterministic route/sample-rate/channel/signal/buffer/permission/player-activity diagnostic snapshot for live sources.
  - `Sources/Orbisonic/OrbisonicEngine.swift`
  - `Sources/Orbisonic/OrbisonicViewModel.swift`
  - `Sources/AudioCore/SourceAdapters.swift`
- Related tests:
  - `Tests/OrbisonicTests/LiveAudioBridgeTests.swift`
  - `Tests/OrbisonicTests/RealtimeCallbackSafetyInstrumentationTests.swift`
  - `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift`
  - `Tests/OrbisonicTests/LiveNormalMonitorRouteTests.swift`
  - `Tests/OrbisonicTests/OrbisonicWebStateTests.swift`
  - `Tests/AudioCoreTests/SourceAdapterTests.swift`
- Related docs:
  - `docs/orbisonic-loopback-input-support-spec.md`
  - `docs/audits/0003-callback-reachability-audit.md`
  - `docs/audits/0004-callback-safety-performance-gates.md`
  - `docs/status.md`

### Roon Bridge And Roon Now-Playing Support

- Implementation:
  - `Sources/Orbisonic/RoonNowPlayingMonitor.swift`
  - `Sources/Orbisonic/RoonBridgeClient.swift`
  - `Sources/Orbisonic/RoonArtworkCache.swift`
  - `Sources/Orbisonic/Resources/RoonBridge/bridge.js`
  - `Sources/Orbisonic/Resources/RoonBridge/package.json`
  - `scripts/install-roon-bridge.sh`
  - `Sources/Orbisonic/LoopbackSourceSupport.swift`
  - `Sources/AudioCore/SourceAdapters.swift`
- Related tests:
  - `Tests/OrbisonicTests/RoonNowPlayingMonitorTests.swift`
  - `Tests/OrbisonicTests/RoonBridgeClientTests.swift`
  - `Tests/OrbisonicTests/OrbisonicWebStateTests.swift`
  - `Tests/AudioCoreTests/SourceAdapterTests.swift`
- Related docs:
  - `README.md`
  - `docs/orbisonic-loopback-input-support-spec.md`

### Spotify Embedded Receiver Support

- Implementation:
  - `Sources/Orbisonic/SpotifyReceiverClient.swift`
  - `Sources/Orbisonic/LoopbackSourceSupport.swift`
  - `Sources/Orbisonic/OrbisonicViewModel.swift`
  - `Vendor/librespot/`
  - `Vendor/orbisonic-librespot-ffi/`
  - `scripts/build-embedded-librespot.sh`
  - `Package.swift`
- Related tests:
  - `Tests/OrbisonicTests/SpotifyReceiverClientTests.swift`
  - `Tests/OrbisonicTests/OrbisonicWebStateTests.swift`
  - `Tests/AudioCoreTests/SourceAdapterTests.swift`
- Related docs:
  - `docs/embedded-librespot-integration.md`
  - `Vendor/librespot/ORBISONIC_VENDOR.md`
  - `README.md`

### Aux Source Support

- Implementation:
  - `Sources/Orbisonic/LoopbackSourceSupport.swift`
  - `Sources/Orbisonic/LiveAudioBridge.swift`
  - `Sources/Orbisonic/OrbisonicEngine.swift`
  - `Sources/Orbisonic/OrbisonicViewModel.swift`
  - `Sources/AudioCore/SourceAdapters.swift`
- Related tests:
  - `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift`
  - `Tests/OrbisonicTests/LiveNormalMonitorRouteTests.swift`
  - `Tests/OrbisonicTests/OrbisonicWebStateTests.swift`
  - `Tests/AudioCoreTests/SourceAdapterTests.swift`
- Related docs:
  - `docs/orbisonic-loopback-input-support-spec.md`
  - `README.md`

### Atmos DRP Source Support

Atmos DRP remains implemented but dormant. It is not exposed in current native or web source selectors.

- Implementation:
  - `Sources/Orbisonic/DolbyReferencePlayerController.swift`
    - Owns DRP device-list parsing, command argument construction, process lifecycle, pause/resume signals, and `--print-info` / `audio.csv` metadata parsing.
    - Owns `AtmosDRPRoutingPolicy`, which currently maps DRP output and Orbisonic capture to `Orbisonic Aux Cable` until a dedicated Atmos loopback exists.
  - `Sources/Orbisonic/LoopbackSourceSupport.swift`
    - Retains `SourceMode.atmosDRP` raw value `Atmos DRP`, display title `Atmos`, and temporary expected loopback policy, while current source-button order hides it from user-facing source selectors.
  - `Sources/Orbisonic/OrbisonicViewModel.swift`
    - Starts Aux-loopback capture for the selected Atmos source, launches/stops DRP, wires experimental pause/resume, and disables seek behavior.
  - `Sources/Orbisonic/OrbisonicWebServer.swift`
  - `Sources/Orbisonic/InputSourceStatusPanelModel.swift`
  - `Sources/Orbisonic/ContentView.swift`
  - `Sources/Orbisonic/LocalMusicLibrary.swift`
- Related tests:
  - `Tests/OrbisonicTests/DolbyReferencePlayerControllerTests.swift`
  - `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift`
  - `Tests/OrbisonicTests/LiveNormalMonitorRouteTests.swift`
  - `Tests/OrbisonicTests/NormalMonitorRouteDescriptorTests.swift`
  - `Tests/OrbisonicTests/OrbisonicWebStateTests.swift`
- Related docs:
  - `docs/contracts.md`
  - `docs/system-flows.md`
  - `docs/test-strategy.md`

### Renderer And Sonic Sphere Output

- Implementation:
  - `Sources/Orbisonic/RendererModule.swift`
  - `Sources/Orbisonic/RendererMatrixSampleRenderer.swift`
  - `Sources/Orbisonic/OrbitalVUMeterModel.swift`
    - Owns dormant value-only orbital VU state mapping.
  - `Sources/Orbisonic/ContentView.swift`
    - Owns the simplified active Renderer tab controls: `Always Mono`, `Stereo 90`, `Binaural 180`, equal-height mode/status panels, renderer status rows, and collapsible tuning controls.
  - `Sources/Orbisonic/SpatialTuning.swift`
  - `Sources/Orbisonic/PureAudioRouteCapabilityBridge.swift`
  - `Sources/AudioCore/RenderGraphPlan.swift`
  - `Sources/AudioCore/RenderKernels.swift`
  - `Sources/AudioCore/OutputAdapters.swift`
  - `calibration/`
- Related tests:
  - `Tests/OrbisonicTests/RendererModuleTests.swift` including Sonic Sphere 30.1 topology, `Stereo 90` / `Binaural 180` two-channel spread coverage, Direct 30/31, and normal-monitor planning non-mutation coverage.
  - `Tests/OrbisonicTests/RendererMatrixSampleRendererTests.swift`
  - `Tests/OrbisonicTests/SonicSphereMeteringTests.swift` including Sonic Sphere meter independence and dormant orbital VU value-model mapping coverage.
  - `Tests/OrbisonicTests/OrbisonicUITweakTests.swift` including simplified Renderer tab, VU options, and Settings surface coverage.
  - `Tests/AudioCoreTests/RenderGraphPlanTests.swift`
  - `Tests/AudioCoreTests/RenderKernelTests.swift`
  - `Tests/AudioCoreTests/OutputAdapterTests.swift`
- Related docs:
  - `README.md`
  - `docs/PureAudio/SYSTEM_AUDIO_FLOW.md`
  - `docs/PureAudio/AUDIO_BOUNDARY_RULES.md`
  - `docs/PureAudio/CONVERSION_LEDGER_REQUIREMENTS.md`

### Headphone Or Normal Monitor Path

- Implementation:
  - `Sources/Orbisonic/NormalMonitorStereoDownmixer.swift`
  - `Sources/Orbisonic/NormalMonitorGraphTopology.swift`
  - `Sources/Orbisonic/NormalMonitorRouteDescriptor.swift`
  - `Sources/Orbisonic/NormalMonitorConversionLedger.swift`
  - `Sources/Orbisonic/AudioSpatialUsageAudit.swift`
  - `Sources/AudioCore/Monitors/AppleSpatialHeadphoneMonitor.swift`
  - `Sources/AudioCore/RenderKernels.swift`
- Related tests:
  - `Tests/OrbisonicTests/NormalMonitorStereoDownmixerTests.swift`
  - `Tests/OrbisonicTests/NormalMonitorGraphTopologyTests.swift`
  - `Tests/OrbisonicTests/NormalMonitorRouteDescriptorTests.swift`
  - `Tests/OrbisonicTests/NormalMonitorRouteBranchRemovalTests.swift` including route-selection invariance across all renderer modes and Direct 30/31 bypass modes.
  - `Tests/OrbisonicTests/NormalMonitorConversionLedgerTests.swift`
  - `Tests/OrbisonicTests/NormalMonitorGoldenAudioTests.swift`
  - `Tests/OrbisonicTests/AudioSpatialUsageAuditTests.swift`
  - `Tests/AudioCoreTests/AppleSpatialHeadphoneMonitorTests.swift`
- Related docs:
  - `docs/PureAudio/APPLE_SPATIAL_HEADPHONE_MONITOR.md`
  - `docs/PureAudio/AUDIO_BOUNDARY_RULES.md`

### Diagnostics And Logs

- Implementation:
  - `Sources/Orbisonic/AppLogger.swift`
  - `Sources/Orbisonic/DebugTimingLog.swift`
  - `Sources/Orbisonic/DiagnosticsLogStore.swift`
  - `Sources/Orbisonic/DiagnosticsView.swift`
  - `Sources/Orbisonic/InputSourceStatusPanelModel.swift`
  - `Sources/Orbisonic/LoopbackSourceSupport.swift`
  - `Sources/Orbisonic/OrbisonicWebServer.swift`
  - `Sources/Orbisonic/MeteringService.swift`
    - Owns fixed per-signal app meter publication for input, desktop monitor, and Sonic Sphere analysis meters; callback/tap ingress publishes bounded raw RMS/peak values while UI reads apply smoothing, trims, display mapping, and low-signal visual release.
- Related tests:
  - `Tests/OrbisonicTests/DiagnosticsLogStoreTests.swift`
  - `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift`
  - `Tests/OrbisonicTests/OrbisonicWebStateTests.swift`
  - `Tests/OrbisonicTests/VURoutingViewTests.swift`
  - `Tests/OrbisonicTests/MeteringServiceTests.swift`
  - `Tests/OrbisonicTests/MeteringIsolationTests.swift`
  - `Tests/AudioCoreTests/MeteringTelemetryTests.swift`
- Related docs:
  - `AGENTS.md`
  - `docs/orbisonic-loopback-input-support-spec.md`
  - `docs/PureAudio/ARCHITECTURE_BOUNDARY_TESTS.md`

### Route Monitoring And Repair

- Implementation:
  - `Sources/Orbisonic/OutputRouteMonitor.swift`
  - `Sources/Orbisonic/BlackHoleRouteRepair.swift`
  - `Sources/Orbisonic/LoopbackSourceSupport.swift`
  - `Sources/Orbisonic/PureAudioRouteCapabilityBridge.swift`
  - `Sources/AudioCore/AudioSessionPlanning.swift`
- Related tests:
  - `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift`
  - `Tests/OrbisonicTests/NormalMonitorRouteDescriptorTests.swift`
  - `Tests/OrbisonicTests/NormalMonitorRouteBranchRemovalTests.swift`
  - `Tests/AudioCoreTests/AudioSessionPlannerTests.swift`
- Related docs:
  - `docs/PureAudio/SAMPLE_RATE_AND_LOCAL_FILE_POLICY.md`
  - `docs/orbisonic-loopback-input-support-spec.md`

### Test Tones

- Implementation:
  - `Sources/Orbisonic/TestToneSupport.swift`
  - `Sources/Orbisonic/SpatialTuning.swift`
  - `Sources/AudioCore/SourceAdapters.swift`
  - `Sources/AudioCore/OutputAdapters.swift`
- Related tests:
  - `Tests/OrbisonicTests/TestToneSupportTests.swift`
  - `Tests/OrbisonicTests/SpatialTuningTests.swift`
  - `Tests/OrbisonicTests/VURoutingViewTests.swift`
  - `Tests/AudioCoreTests/SourceAdapterTests.swift`
  - `Tests/AudioCoreTests/OutputAdapterTests.swift`

### Installer And App Bundle Scripts

- Implementation:
  - `scripts/refresh-orbisonic-app.sh`
  - `scripts/reopen-orbisonic-app.sh`
  - `scripts/build-installer.sh`
  - `scripts/build-suite-installer.sh`
  - `Sources/Orbisonic/OrbisonicResourceLocator.swift`
  - `scripts/install-roon-bridge.sh`
  - `scripts/build-embedded-librespot.sh`
  - `scripts/launch-orbisonic-ref.sh`
  - `scripts/deprecated-orbisonic-ref.sh`
  - `installer/`
    - canonical package paths when rebuilt: `Orbisonic-1.3.1.pkg` and `OrbisonicSuite-1.3.1.pkg`
    - deprecated packaging-hotfix predecessor: `Orbisonic-1.3.pkg` and `OrbisonicSuite-1.3.pkg`
    - historical artifacts: `Orbisonic-1.1.pkg` and `OrbisonicSuite-1.1.pkg`
  - `Orbisonic.app`
  - `Orbisonic.entitlements`
- Related tests:
  - `Tests/OrbisonicTests/AppBuildInfoTests.swift`
- Related docs:
  - `README.md`
  - `RELEASE_NOTES.md`
  - `docs/release-verification.md`

### Vendor Dependencies

- Implementation:
  - `Vendor/librespot/`
  - `Vendor/orbisonic-librespot-ffi/`
  - `scripts/build-embedded-librespot.sh`
  - `Package.swift`
- Related tests:
  - `Tests/OrbisonicTests/SpotifyReceiverClientTests.swift`
- Related docs:
  - `docs/embedded-librespot-integration.md`
  - `Vendor/librespot/ORBISONIC_VENDOR.md`

## Module Map

- `AudioContracts`: pure shared value vocabulary and validation types.
- `AudioImport`: local asset readiness and managed import decisions.
- `AudioCore`: deterministic audio planning, adapters, kernels, output and metering logic.
- `Orbisonic`: concrete app runtime, UI, engine, platform integration, diagnostics, and packaging surface.
- `RoonBridge` resource folder: optional local Node helper packaged inside app resources.
- `Vendor/orbisonic-librespot-ffi`: Rust FFI bridge for the embedded Spotify receiver.
- `Vendor/librespot`: vendored upstream Spotify Connect implementation used by the FFI bridge.

## Test Map

- `Tests/AudioContractsTests/`: sample rates, session formats, output capabilities, source descriptors, conversion ledgers, meter snapshots, and forbidden imports.
- `Tests/AudioImportTests/`: local asset gate, sample-rate mismatch policy, offline import, conversion ledger, and layout preservation.
- `Tests/AudioCoreTests/`: audio control API, session planner, source adapters, render graph plan, render kernels, output adapters, metering telemetry, and Apple spatial headphone monitor.
- `Tests/OrbisonicTests/`: app-specific tests covering local playback, local library, Roon, Spotify, dormant Atmos DRP boundaries, loopback, renderer module, matrix renderer, normal monitor, diagnostics, web state, route policy, metering, Player rail/UI model behavior, build metadata, and architecture boundaries.
- `Tests/OrbisonicTests/PureAudioArchitectureBoundaryTests.swift`: static boundary checks for SwiftPM dependency direction, forbidden imports, app runtime leakage, source-integration renderer ownership, monitor/production topology separation, and documented migration exceptions.
- `Tests/OrbisonicTests/ArchitectureBoundaryAllowlist.swift`: explicit pattern and file allowlists used by architecture boundary tests.

## Related Docs

- `docs/status.md`: project control panel.
- `docs/product-brief.md`: product scope and success criteria.
- `docs/readiness-summary.md`: current readiness and release-blocker summary.
- `docs/release-verification.md`: manual release-verification checklist.
- `docs/PureAudio/SYSTEM_AUDIO_FLOW.md`: current PureAudio flow and contract notes.
- `docs/PureAudio/AUDIO_BOUNDARY_RULES.md`: boundary rules and forbidden dependencies.
- `docs/PureAudio/ARCHITECTURE_BOUNDARY_TESTS.md`: boundary test intent and allowlist guidance.
- `docs/PureAudio/SAMPLE_RATE_AND_LOCAL_FILE_POLICY.md`: production sample-rate and local asset policy.
- `docs/PureAudio/CONVERSION_LEDGER_REQUIREMENTS.md`: conversion ledger requirements.
- `docs/PureAudio/APPLE_SPATIAL_HEADPHONE_MONITOR.md`: Apple spatial headphone monitor boundary.
- `docs/orbisonic-loopback-input-support-spec.md`: Roon/Aux loopback support and UI architecture spec.
- `docs/embedded-librespot-integration.md`: Spotify embedded receiver notes.
- `docs/LocalGaplessPlaybackPlan.md`: local gapless playback plan and status.
- `docs/high-channel-vu-meter-lab-webapp-spec.md`: high-channel VU design-lab spec.
- `README.md`: current product overview and run/install basics.
- `RELEASE_NOTES.md`: packaged release notes.

## Last Updated

- 2026-05-04: Created by Prompt 03 as the baseline feature-to-file map for the project control retrofit.
- 2026-05-05: Refreshed by Prompt 19 to include release verification, readiness summary, and manual release-verification task ownership.
- 2026-05-23: Refreshed during Task 020 Slice 9 of 10 to include realtime family governance, callback safety instrumentation, orbital VU source/tests, and release-gate ownership.
- 2026-05-23: Refreshed during Task 020 Slice 10 of 10 to include the final realtime compliance audit location.
