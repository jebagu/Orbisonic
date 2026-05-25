# Orbisonic Test Strategy And Verification Map

## Purpose

This document maps the current Orbisonic tests to the contracts and audio risks described in `docs/contracts.md` and `docs/system-flows.md`. It is a retrofit control document, not a claim that all hardware paths have been verified.

## Testing Goals

- Enforce the adopted Realtime Audio Family Standards Package: callback-reachable code must not allocate, block, wait, log, perform I/O, call UI, parse, discover routes, mutate graphs, or perform unbounded work.
- Protect the selected-source model: Roon, Spotify, Aux, Local Files, Test Tone, and dormant Atmos DRP must stay separate unless a future mixer contract is accepted.
- Protect Sonic Sphere 30.1 production output from silent renderer topology drift.
- Protect the headphone or normal monitor path from mutating Sonic Sphere production output.
- Keep sample-rate mismatch, channel-count mismatch, route mismatch, underflow, dropped frames, all-zero live input, and missing hardware visible.
- Keep `AudioContracts`, `AudioImport`, and `AudioCore` independent from app/UI/runtime integration boundaries.
- Prefer deterministic unit and integration tests for pure logic, and explicit manual verification for hardware and external-service behavior.
- Avoid private media, personal paths, credentials, tokens, device-specific secrets, and runtime logs in tracked fixtures or docs.

## Test Types

- Contract tests: validate shared value types, sample-rate rules, source-channel caps, conversion ledgers, and forbidden imports.
- Import policy tests: validate local asset readiness, offline import, managed CAF output, and no hidden realtime production sample-rate conversion.
- Pure audio planning tests: validate source adapters, session planning, immutable render graph plans, render kernels, output adapters, metering telemetry, and Apple spatial headphone monitor values.
- App integration tests: validate source switching, local file playback, live loopback policy, Roon/Spotify status models, web state, diagnostics, renderer module behavior, monitor topology, metering isolation, and UI model text.
- Golden audio tests: validate deterministic monitor downmix, matrix rendering, direct renderer modes, LFE behavior, and no duplicate/stale audible paths.
- Architecture boundary tests: validate SwiftPM dependency direction, forbidden dependencies, source-integration ownership boundaries, monitor/production topology separation, and prevent lower-level targets from reaching into UI/runtime ownership.
- Callback safety and performance gate tests: validate callback reachability, zero callback allocations, zero callback blocking locks or waits, bounded overload behavior, telemetry drops, deadline misses, and callback p95/p99/max duration under stress.
- Manual hardware checks: validate Sonic Sphere / Dante, loopback devices, Roon, Spotify Connect, Aux capture, microphone permission, app signing/entitlements, installer behavior, and dormant Atmos DRP before re-exposing it in a real environment.

## Existing Test Target Map

| Test target | Current scope | Approximate test count from current files |
| --- | --- | ---: |
| `AudioContractsTests` | Shared sample rates, session formats, Dante eligibility, source descriptors, layout fallback, conversion ledger, meter snapshot values, forbidden imports. | 12 |
| `AudioImportTests` | Local asset gate, sample-rate mismatch policy, stopped-session restart policy, managed import, conversion ledger, layout preservation. | 7 |
| `AudioCoreTests` | Audio control, session planner, source adapters, render graph plan, render kernels, output adapters, metering telemetry, Apple spatial headphone monitor. | 102 |
| `OrbisonicTests` | App runtime boundaries: local files, local library, live loopback, Roon, Spotify, dormant Atmos DRP, Aux, renderer module, monitor path, diagnostics, web state, VU/metering, UI model behavior, build metadata, callback performance gates, and architecture rules. | 435+ |

Counts are descriptive snapshots from the current repository. The completion rule below controls future work, not the raw count.

## Contract-To-Test Map

| Contract or boundary | Existing tests that protect it | Current coverage read |
| --- | --- | --- |
| `AudioContracts` | `Tests/AudioContractsTests/AudioContractsTests.swift`, `Tests/OrbisonicTests/PureAudioArchitectureBoundaryTests.swift` | Good coverage for value validation, source cap, sample-rate mismatch, conversion ledger invalidation, meter snapshot values, SwiftPM dependency direction, forbidden imports, app runtime leakage, and filesystem implementation leakage. |
| `AudioImport` | `Tests/AudioImportTests/LocalAssetImportTests.swift`, `Tests/OrbisonicTests/PureAudioIntegrationHardeningTests.swift`, `Tests/OrbisonicTests/PureAudioArchitectureBoundaryTests.swift` | Good coverage for local asset readiness, managed imports, offline conversion ledger, rejection of hidden production SRC, and no app UI/live runtime back-dependency. |
| `AudioCore` | `Tests/AudioCoreTests/AudioControlTests.swift`, `AudioSessionPlannerTests.swift`, `SourceAdapterTests.swift`, `RenderGraphPlanTests.swift`, `RenderKernelTests.swift`, `OutputAdapterTests.swift`, `MeteringTelemetryTests.swift`, `AppleSpatialHeadphoneMonitorTests.swift`, `Tests/OrbisonicTests/PureAudioArchitectureBoundaryTests.swift` | Strong deterministic coverage for planning and offline render boundaries, plus static checks against app runtime ownership leakage; does not prove the live AVAudioEngine path has been fully migrated to AudioCore. |
| App shell, settings, and theme | `Tests/OrbisonicTests/OrbisonicUITweakTests.swift`, `ExistingUIFreezeTests.swift`, `OrbisonicThemeTests.swift`, `OrbisonicWebStateTests.swift`, `LocalPlayerStabilizationTests.swift`, `VURoutingViewTests.swift`, `AppBuildInfoTests.swift` | Good model and state coverage, including selected-source transition cleanup for Off and Test Tone, fixed-height non-scrollable Player rail guards, four single-line Player metadata row guards, simplified natural equal-height Renderer and Settings panels, cleaned `Sound Settings`, app-wide color theme palette defaults/migration, themed linear slider controls with direct visible-track drag handling, cached unit-test detection that avoids bundle enumeration in app runtime paths, Core Audio route snapshot collection outside main-actor application and outside XCTest runtime, Daft Punk compressed-rainbow VU treatment, and source-level coverage that the active Renderer tab no longer hosts the orbital VU panel. GUI rendering and LaunchServices behavior remain manual when app behavior changes. |
| `OrbisonicEngine` | `LocalPlayerStabilizationTests.swift`, `StreamingAudioFileSourceTests.swift`, `LiveNormalMonitorRouteTests.swift`, `SonicSphereMeteringTests.swift`, `MeteringIsolationTests.swift` | Good deterministic and engine-adjacent coverage. Real output-device and live capture behavior still needs manual runtime verification. |
| `LiveAudioBridge` | `Tests/OrbisonicTests/LiveAudioBridgeTests.swift`, `RealtimeCallbackSafetyInstrumentationTests.swift`, `LiveNormalMonitorRouteTests.swift`, `MeteringIsolationTests.swift`, `SonicSphereMeteringTests.swift` | Covers source cap, HAL capture storage reuse, oversized callback-frame rejection, fixed-capacity transfer priming, underflow, drop behavior, non-consuming meter peeks, shared realtime atomic primitives, the no-`NSLock` live transfer guard, and Slice 8 callback gate reporting. The current live matrix render gate blocks on explicit scratch allocation evidence. Does not prove a real loopback driver is installed or permissioned. |
| Local files and library | `AudioFileProbeTests.swift`, `LocalAudioFileSourceTests.swift`, `StreamingAudioFileSourceTests.swift`, `LocalGaplessSchedulerTests.swift`, `LocalGaplessTypesTests.swift`, `LocalGaplessPlaybackPolicyTests.swift`, `LocalPlayerStabilizationTests.swift`, `LocalMusicMetadataEnrichmentTests.swift`, `MatroskaFLACSupportTests.swift` | Broad coverage for file probing, streaming, gapless scheduling, metadata, playlist persistence, FFmpeg fallback fixtures, and source switching. Some fixture tests can skip when FFmpeg tools are unavailable. |
| Roon boundary | `RoonNowPlayingMonitorTests.swift`, `RoonBridgeClientTests.swift`, `OrbisonicWebStateTests.swift`, `AudioCoreTests/SourceAdapterTests.swift`, `LoopbackSourceSupportTests.swift` | Good parser/client/status coverage, including diagnostic separation between Roon playback activity and captured loopback audio. No automated end-to-end proof that Roon playback reaches a real loopback input. |
| Spotify boundary | `SpotifyReceiverClientTests.swift`, `OrbisonicWebStateTests.swift`, `AudioCoreTests/SourceAdapterTests.swift`, `LoopbackSourceSupportTests.swift` | Covers configuration, receiver state copy, stale metadata separation, loopback identity, stereo policy, fixed-stereo source health, and wrong-route diagnostic behavior. Real Spotify Connect session remains manual. |
| Atmos DRP boundary | `DolbyReferencePlayerControllerTests.swift`, `LoopbackSourceSupportTests.swift`, `LiveNormalMonitorRouteTests.swift`, `NormalMonitorRouteDescriptorTests.swift`, `OrbisonicWebStateTests.swift` | Covers dormant DRP device-list parsing, command argument construction, no PCM output argument, stdout/CSV bitstream parsing, hidden source-button policy, temporary Aux route policy, normal-monitor route isolation, and internal web metadata behavior. Real DRP/iLok, loopback capture, actual Atmos playback, and re-exposure remain manual. |
| Aux boundary | `LoopbackSourceSupportTests.swift`, `LiveNormalMonitorRouteTests.swift`, `AudioCoreTests/SourceAdapterTests.swift`, `OrbisonicWebStateTests.swift` | Covers expected route identity, selected-source policy, channel handling, monitor-only route policy, selected-source no-signal web/control status, channel mismatch, and permission diagnostic behavior. Real external-app audio capture remains manual. |
| Renderer and Sonic Sphere output | `RendererModuleTests.swift`, `RendererMatrixSampleRendererTests.swift`, `SonicSphereMeteringTests.swift`, `OrbisonicUITweakTests.swift`, `AudioCoreTests/RenderGraphPlanTests.swift`, `RenderKernelTests.swift`, `OutputAdapterTests.swift`, `MeteringTelemetryTests.swift`, `Tests/OrbisonicTests/PureAudioArchitectureBoundaryTests.swift` | Strong deterministic renderer/topology coverage, including `Stereo 90`, `Binaural 180`, Direct 30/31, channel 32 silence, dormant orbital VU value-model mapping, simplified Renderer tab UI, and a monitor-planning non-mutation invariant for the Sonic Sphere 30.1 scene. Physical Sonic Sphere / Dante output remains manual. |
| Headphone or normal monitor | `NormalMonitorStereoDownmixerTests.swift`, `NormalMonitorGraphTopologyTests.swift`, `NormalMonitorRouteDescriptorTests.swift`, `NormalMonitorRouteBranchRemovalTests.swift`, `NormalMonitorConversionLedgerTests.swift`, `NormalMonitorGoldenAudioTests.swift`, `AudioSpatialUsageAuditTests.swift`, `AudioCoreTests/AppleSpatialHeadphoneMonitorTests.swift`, `Tests/OrbisonicTests/PureAudioArchitectureBoundaryTests.swift` | Strong monitor isolation coverage, including static checks that monitor files do not own production renderer topology and route-selection coverage that all renderer modes, including Direct 30/31, stay on the same normal monitor path. Route, entitlement, and actual headphone behavior remain manual. |
| Diagnostics and logging | `DiagnosticsLogStoreTests.swift`, `LoopbackSourceSupportTests.swift`, `OrbisonicWebStateTests.swift`, `VURoutingViewTests.swift`, `MeteringServiceTests.swift`, `MeteringIsolationTests.swift`, `AudioCoreTests/MeteringTelemetryTests.swift` | Good coverage for bounded logs, public/control web separation, source status, live loopback diagnostic snapshots, nonblocking legacy meter ingress, overload drop counters, low-level VU visual release, and metering side effects. Runtime log contents still require manual inspection during hardware checks. |
| Installer and app bundle scripts | `AppBuildInfoTests.swift`; `docs/release-verification.md`; manual script and installer verification | Automated coverage is limited to build metadata. Script behavior, package installation, app signing, LaunchServices reopen, and hardware/service checks are now mapped in the release verification checklist and remain manual unless actually run. |

## Critical Audio Invariants

| Invariant | Existing automated protection | Remaining verification |
| --- | --- | --- |
| Source channel count cap and layout handling | `AudioContractsTests`, `LiveAudioBridgeTests`, `RendererModuleTests`, `ChannelRoleLayoutDescriptorTests`, `LocalAssetImportTests`, `SourceAdapterTests` | Real files and live devices above expected channel counts should be manually rejected during release smoke tests when available. |
| Local file path stays separate from live loopback path | `LocalPlayerStabilizationTests`, `LiveNormalMonitorRouteTests`, `LoopbackSourceSupportTests`, `OrbisonicWebStateTests`, `SourceAdapterTests` | Automated web-state tests now cover stale local snapshot cleanup when switching to Off or Test Tone. Manual source switching with running Roon/Aux/Spotify should verify no stale audible path remains. |
| Roon, Spotify, Aux, local sources, and dormant Atmos DRP stay isolated | `LoopbackSourceSupportTests`, `OrbisonicWebStateTests`, `LocalPlayerStabilizationTests`, `SourceAdapterTests`, `DolbyReferencePlayerControllerTests` | Automated tests cover inactive Roon/Spotify/local web-state separation, Off/Test Tone local snapshot cleanup, Spotify's fixed-stereo health boundary, hidden Atmos source buttons, and dormant Atmos DRP as a separate source that temporarily uses the Aux route policy. Manual live-player checks should confirm visible source and captured signal match the selected source. |
| Renderer topology does not drift silently | `RendererModuleTests`, `RendererMatrixSampleRendererTests`, `RenderGraphPlanTests`, `RenderKernelTests`, `OutputAdapterTests`, `SonicSphereMeteringTests` | Automated coverage now includes a monitor-planning invariant proving Sonic Sphere 30.1 scene topology is unchanged by monitor planning plus orbital VU value-model checks for 30.1 markers and channel 32 reserved silence. Manual Sonic Sphere / Dante checks should confirm physical channel order and LFE behavior. |
| Monitor path does not mutate production Sonic Sphere path | `NormalMonitor*Tests`, `AudioSpatialUsageAuditTests`, `AppleSpatialHeadphoneMonitorTests`, `MeteringIsolationTests`, `OutputAdapterTests`, `PureAudioArchitectureBoundaryTests` | Automated coverage now includes every renderer mode, including `Binaural 180` and Direct 30/31, resolving to the same normal-monitor route. Manual monitor route changes should confirm Output 1 Monitor changes do not reroute Output 2 Main Renderer. |
| Hardware-unavailable behavior is explicit | `LoopbackSourceSupportTests`, `SpotifyReceiverClientTests`, `RoonBridgeClientTests`, `DiagnosticsLogStoreTests`, `OrbisonicWebStateTests` | Manual missing-device, permission, and helper-unavailable cases should be recorded in release verification. |
| All-zero live input is diagnosed rather than hidden | `LiveAudioBridgeTests`, `LiveNormalMonitorRouteTests`, `LoopbackSourceSupportTests`, `OrbisonicWebStateTests`, `MeteringServiceTests`, `MeteringTelemetryTests` | Automated web/control status tests cover selected Roon, Spotify, Aux, and dormant Atmos source state, and diagnostic snapshot tests cover player activity separate from silent capture. Manual Roon/Spotify/Aux playback with silent capture should still verify diagnostics show no-signal state and route/sample-rate facts in the real environment. |
| Sample-rate and channel-count mismatches are visible | `AudioContractsTests`, `AudioImportTests`, `AudioSessionPlannerTests`, `SourceAdapterTests`, `LoopbackSourceSupportTests`, `RenderGraphPlanTests`, `NormalMonitorConversionLedgerTests`, `OutputAdapterTests` | Automated live diagnostic snapshot tests cover sample-rate and active-channel mismatch messages. Manual device sample-rate mismatch should be captured with route names, nominal sample rates, and diagnostics. |
| Metering cannot affect playback | `MeteringIsolationTests`, `MeteringTelemetryTests`, `SonicSphereMeteringTests`, `OrbisonicUITweakTests`, `NormalMonitorGoldenAudioTests`, `MeteringServiceTests`, `VURoutingViewTests` | Automated coverage now includes legacy meter overload/drop behavior, low-signal VU display release, dormant orbital VU state derived from snapshots only, simplified visible VU options, and a calibration non-mutation check for audible sample hashes and renderer coefficients. Manual visual meter load should not be used as proof of audio correctness; it only supplements route/audio checks. |

## Required Checks

Run checks from the canonical repository root, where source, tests, scripts, docs, and task files now live directly. Do not use a wrapper workspace, copied app source tree, or separate control folder as an active verification source.

Run the full SwiftPM test suite before accepting source or test changes:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

After changing app code, refresh and verify the app bundle:

```sh
./scripts/refresh-orbisonic-app.sh
```

When GUI or audio behavior needs runtime verification, reopen through LaunchServices:

```sh
./scripts/reopen-orbisonic-app.sh
```

Do not launch the raw GUI executable for GUI/audio verification.

The root `Open Orbisonic.command` should remain a LaunchServices opener only and should force the repo-root app bundle path through the reopen script when another Orbisonic bundle is installed. App refreshes, package rebuilds, signing, and installer work stay as explicit script or release-verification steps.

For docs-only prompts, a build is not required unless source, tests, scripts, installer files, vendor files, or calibration files changed by mistake. The minimum docs-only checks are:

```sh
git diff --name-only -- AGENTS.md README.md Package.swift Sources Tests scripts installer Vendor calibration
git diff --check
```

Privacy checks before committing docs or tests should search for personal paths, local usernames, secrets, tokens, and runtime logs. Fixtures must use generated data, repo-safe relative fixture paths, or temporary directories.

For callback-adjacent prompts, the final result must include a callback impact summary:

```text
Callback impact:
New callback-reachable functions:
Allocation risk:
Lock/wait risk:
I/O/logging/UI risk:
Worst-case loop bounds:
Queue-full or overload policy:
Tests or instrumentation run:
```

Callback-adjacent work is not release-ready until the relevant family performance gates under `docs/realtime-audio-family/docs/standards/performance-gate-standard.md` are satisfied or explicitly recorded as blockers.

Orbisonic's current callback performance budget is the family starting budget: p95 <= 50 percent of minimum observed block duration, p99 <= 70 percent, max <= 90 percent during qualification, deadline misses = 0, callback allocations/deallocations = 0, callback blocking locks = 0, and callback waits/sleeps = 0. Telemetry and meter overload must drop or coalesce without blocking audio, and route mismatch must be blocked before arming or converted to bounded silence/status without graph mutation inside the callback.

The project-specific local stress command is:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter RealtimeCallbackSafetyInstrumentationTests
```

The current callback reachability baseline is `docs/audits/0003-callback-reachability-audit.md`. The current performance gate report is `docs/audits/0004-callback-safety-performance-gates.md`. Future callback-adjacent test work should update those audits or supersede them with newer reports when callback entry points, render-block reachability, unsafe operations, budgets, or measured stress results change.

## Manual Verification Requirements

Manual checks must record what hardware, route, source, and app bundle were actually exercised.

- Sonic Sphere / Dante or production output hardware verification: confirm Output 2 Main Renderer route, production channel count, sample rate, channel walk, Direct 30/31 behavior where relevant, LFE behavior, and physical speaker order.
- Orbital VU visual verification: launch through LaunchServices, open the active Renderer tab, confirm the visible meter source label is truthful, confirm inactive/active/hot/clipping/LFE/reserved-output marker states where safely reproducible, and confirm no `Dante Output Meter` label appears unless actual post-render Dante/output bus metering exists and is verified.
- Realtime callback stress verification: run the standard scene long enough to record p50/p95/p99/max durations, deadline misses, allocation/deallocation counts, blocking lock counts, wait/sleep counts, denormal policy, telemetry/meter drops or coalesces, and route-mismatch behavior.
- Roon loopback device verification: route Roon to `Orbisonic Roon Input`, compare Roon output sample rate, loopback nominal sample rate, selected input route name/channel count, live meter peak, underflow count, dropped-frame count, and no-signal warnings.
- Aux loopback device verification: route an external app to `Orbisonic Aux Cable`, confirm selected Aux source, route identity, sample rate, active channels, live signal, and no feedback-loop warning.
- Spotify Connect receiver verification: choose Orbisonic in Spotify Connect, confirm receiver status, dedicated `Orbisonic Spotify Input`, stereo policy, live signal, stale metadata behavior, and control readiness.
- macOS microphone permission behavior: confirm loopback input capture is permitted and that the OS microphone prompt is treated as expected loopback capture, not proof of physical mic selection.
- App signing or entitlement gaps: confirm Apple spatial/head-tracking behavior only when the app is signed with the required entitlements; otherwise record disabled/fallback behavior.
- Installer verification: follow `docs/release-verification.md`; install app-only and suite packages as appropriate, confirm `Orbisonic.app` opens through LaunchServices, helper resources are present, loopback drivers are available when suite-installed, and package behavior matches release notes.
- Roon bridge verification: install helper dependencies when needed, authorize the Roon extension, verify snapshot/transport controls, and confirm transport metadata does not override live capture truth.

## Test Data Rules

- Use generated audio fixtures, deterministic PCM buffers, temporary directories, or repo-safe fixture data.
- Do not commit private music files, Roon logs, Spotify credentials, helper tokens, local runtime caches, or local absolute paths.
- If a fixture depends on FFmpeg or FFprobe, the test may skip when those tools are unavailable, but the skip should be explicit.
- Golden audio tests should keep expected values deterministic and small enough to review.
- Hardware-specific facts belong in release verification notes, not unit fixtures.
- Test data should preserve real source facts: sample rate, channel count, channel role confidence, layout source, and conversion ledger facts.

## Coverage Expectations

- Any change to `AudioContracts` updates or adds `AudioContractsTests`.
- Any change to local asset readiness, import, or conversion policy updates or adds `AudioImportTests`.
- Any change to AudioCore source, planner, render, output, meter, or monitor logic updates or adds `AudioCoreTests`.
- Any change to app source selection, local playback, live loopback, Roon, Spotify, Aux, renderer UI/model, normal monitor, diagnostics, web state, or VU behavior updates or adds focused `OrbisonicTests`.
- Any renderer topology change must include deterministic matrix/render tests plus at least one invariant that prevents monitor output from redefining production output.
- Any live source change must include selected-source isolation, route mismatch, sample-rate or channel-count mismatch, no-signal, and diagnostics coverage where practical.
- Any monitor change must include no direct Sonic Sphere audible route, two-channel monitor output where required, no environment/spatial fallback where forbidden, and no metering side effect.
- Any SwiftPM target, import-boundary, source-integration, or monitor/production boundary change must update `PureAudioArchitectureBoundaryTests.swift` and keep `ArchitectureBoundaryAllowlist.swift` explicit.
- Any script, package, signing, or LaunchServices behavior change must update release verification docs and run the smallest safe manual check.
- Public setup and product claims in `README.md`, `docs/product-brief.md`, and release docs should be included in contract-gap audits when they describe live inputs, source names, installer behavior, supported routes, or operator-facing setup.
- Public/raw naming pairs such as `Local Files` and `Local Music` should be tested together when they appear in native UI, public web state, or control-state values.

## Completion Rule

A task is not complete until the narrowest relevant automated tests pass, required app bundle refresh or LaunchServices checks have been run when app behavior changed, docs/contracts/flows are updated when behavior changed, and any hardware-only behavior is explicitly marked manual rather than implied by automated tests.

If a change cannot be tested automatically because it depends on Sonic Sphere, Dante, loopback devices, Roon, Spotify, microphone permission, signing entitlements, or installers, the final result must say which manual checks remain.

## Known Test Gaps

- No automated test proves actual Sonic Sphere / Dante hardware output, physical channel order, or acoustic speaker behavior.
- No automated test or orbital VU activity proves actual Sonic Sphere / Dante hardware output; the orbital VU still needs manual visual verification for the operator-facing Renderer tab.
- Slice 8 installs a callback safety harness and performance gate report, but it does not yet prove full compliance. The current report warns because host-level malloc/free interposition, lock/wait interposition, and denormal verification are missing, and it blocks because `LiveAudioPipe.render(matrix:audioBufferList:frameCount:)` still records callback scratch allocation.
- No automated test proves real Roon audio reaches `Orbisonic Roon Input`; current tests cover parser, bridge, source adapter, status, and web behavior.
- No automated test proves real Aux capture from an external app through `Orbisonic Aux Cable`.
- No automated test proves a real Spotify Connect session reaches `Orbisonic Spotify Input`; current tests cover receiver configuration/status, stale metadata separation, and fixed-stereo health reporting.
- No automated test exercises macOS microphone permission prompts for loopback devices.
- No automated test proves app signing entitlements enable Apple spatial/head-tracking behavior on real headphones.
- Installer and package behavior is covered by `docs/release-verification.md` as manual release evidence, not by automated tests.
- Some local media fixture coverage depends on FFmpeg/FFprobe availability and can skip in a reduced environment.
- AudioCore output adapters and render kernels are deterministic/offline tests; they do not by themselves prove that the live app runtime is fully using those paths.
- Current tests are strong around monitor isolation and now cover all renderer modes, including Direct 30/31, against monitor route mutation. Manual runtime route changes are still needed to catch device-specific route behavior.
- Automated no-signal status coverage now includes selected Roon, Spotify, and Aux web/control-state cases plus live diagnostic snapshot cases for route, sample-rate, channel-count, permission, and buffer-counter diagnostics. Automated source-isolation coverage also includes Off/Test Tone stale local snapshot cleanup and Spotify stale multichannel metadata suppression, but it still does not prove real loopback capture, permission prompts, route, or hardware behavior.
- No CI policy is documented here beyond the local command because this prompt did not add or inspect a CI system.

## Maintenance Rules

- Keep this file aligned with `docs/contracts.md`, `docs/system-flows.md`, and `docs/implementation-map.md`.
- Add new test files to the contract-to-test map when they become part of the retrofit.
- Do not convert manual hardware requirements into automated acceptance claims unless the tests actually exercise the hardware or service.
- When a contract changes, update this strategy in the same change or explicitly record why no test-strategy change was needed.
