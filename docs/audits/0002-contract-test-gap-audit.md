# 0002: Contract-Test Gap Audit

Status: Complete

Date: 2026-05-05

## Scope

This audit maps `docs/contracts.md`, `docs/system-flows.md`, `docs/test-strategy.md`, selected ADRs, and product/setup claims to the current SwiftPM tests. It is audit-only: no source, test, dependency, script, installer, vendor, resource, or calibration files were changed.

The read focused first on the highest-risk audio invariants: shared vocabulary boundaries, import policy, pure AudioCore separation, selected-source-only behavior, live loopback silence diagnostics, sample-rate and channel-count mismatch visibility, monitor/production separation, renderer topology stability, and hardware-only verification limits.

## Contract Coverage Summary

| Contract or claim group | Current coverage read | Key existing test evidence | Gap severity | Proposed target if expanded |
| --- | --- | --- | --- | --- |
| `AudioContracts` shared vocabulary and forbidden imports | Covered | `Tests/AudioContractsTests/AudioContractsTests.swift`, `Tests/OrbisonicTests/PureAudioArchitectureBoundaryTests.swift` | Low | Keep in `AudioContractsTests` when value types change. |
| `AudioImport` local asset readiness and no hidden production SRC | Covered | `Tests/AudioImportTests/LocalAssetImportTests.swift`, `Tests/OrbisonicTests/PureAudioIntegrationHardeningTests.swift` | Low | Keep in `AudioImportTests` for import-policy changes. |
| `AudioCore` independent planning, adapters, kernels, output, and metering | Covered for deterministic planning; partial for proving app runtime migration | `Tests/AudioCoreTests/*`, `Tests/OrbisonicTests/PureAudioArchitectureBoundaryTests.swift` | Medium | Add app-boundary tests only when current app runtime behavior changes. |
| Local file playback separate from live loopback capture | Mostly covered | `Tests/OrbisonicTests/LocalPlayerStabilizationTests.swift`, `Tests/OrbisonicTests/LiveNormalMonitorRouteTests.swift`, `Tests/AudioCoreTests/SourceAdapterTests.swift` | Medium | Add focused transition tests only if local/live switching code changes. |
| Selected-source-only behavior for Roon, Spotify, Aux, Local Files, and Test Tone | Mostly covered | `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift`, `Tests/OrbisonicTests/OrbisonicWebStateTests.swift`, `Tests/OrbisonicTests/LocalPlayerStabilizationTests.swift`, `Tests/AudioCoreTests/SourceAdapterTests.swift` | Medium | `OrbisonicWebStateTests` or a new input-source panel test file. |
| Roon metadata versus captured audio separation | Covered for parser/client/status logic; manual for real loopback | `Tests/OrbisonicTests/RoonNowPlayingMonitorTests.swift`, `RoonBridgeClientTests.swift`, `OrbisonicWebStateTests.swift`, `Tests/AudioCoreTests/SourceAdapterTests.swift` | Medium | Add only small status tests unless Roon behavior changes. |
| Spotify dedicated input, stereo policy, stale metadata separation | Mostly covered; manual for real Spotify Connect | `Tests/OrbisonicTests/SpotifyReceiverClientTests.swift`, `LoopbackSourceSupportTests.swift`, `OrbisonicWebStateTests.swift`, `Tests/AudioCoreTests/SourceAdapterTests.swift` | Medium | Add selected no-signal status coverage before runtime hardening. |
| Aux dedicated input and no metadata ownership | Partially covered | `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift`, `LiveNormalMonitorRouteTests.swift`, `NormalMonitorRouteDescriptorTests.swift`, `Tests/AudioCoreTests/SourceAdapterTests.swift` | High | Add selected Aux no-signal/status-panel tests first. |
| All-zero live loopback input diagnosed, not hidden | Partially covered | `LiveAudioBridgeTests.swift`, `OrbisonicWebStateTests.swift`, `LiveNormalMonitorRouteTests.swift`, `MeteringIsolationTests.swift`, `SonicSphereMeteringTests.swift` | High | Add compact Roon/Spotify/Aux no-signal status tests. |
| Sample-rate and channel-count mismatch surfaced | Mostly covered | `AudioContractsTests.swift`, `LocalAssetImportTests.swift`, `AudioSessionPlannerTests.swift`, `SourceAdapterTests.swift`, `RenderGraphPlanTests.swift`, `NormalMonitorConversionLedgerTests.swift`, `OutputAdapterTests.swift` | Medium | Add app diagnostics tests only when route status UI changes. |
| Monitor path cannot mutate Sonic Sphere production topology | Covered | `NormalMonitor*Tests.swift`, `AudioSpatialUsageAuditTests.swift`, `Tests/AudioCoreTests/AppleSpatialHeadphoneMonitorTests.swift`, `MeteringIsolationTests.swift`, `OutputAdapterTests.swift` | Low | Keep monitor tests current with monitor changes. |
| Renderer topology and Direct 30/31 bypass stability | Covered deterministically; manual for physical Sonic Sphere / Dante | `RendererModuleTests.swift`, `RendererMatrixSampleRendererTests.swift`, `SonicSphereMeteringTests.swift`, `RenderGraphPlanTests.swift`, `RenderKernelTests.swift`, `OutputAdapterTests.swift` | Low | Add renderer tests only with renderer behavior changes. |
| Diagnostics and logging boundedness/public-control separation | Mostly covered | `DiagnosticsLogStoreTests.swift`, `OrbisonicWebStateTests.swift`, `VURoutingViewTests.swift`, `MeteringServiceTests.swift`, `MeteringTelemetryTests.swift` | Medium | Add input-source status matrix tests. |
| Installer and app bundle script behavior | Manual-only for release behavior | `Tests/OrbisonicTests/AppBuildInfoTests.swift`; script/manual verification docs | Medium | `docs/release-verification.md`, not Prompt 13 unit tests. |
| Product/setup claims for live inputs | Contradiction carried forward | Source/tests include `Orbisonic Spotify Input`; README requirements/setup still omit it in one setup path | High for setup docs | Fix README/release docs in a docs prompt, not Prompt 13. |

## Highest-Risk Untested Claims

1. High: Selected live-source no-signal diagnostics are not covered evenly across Roon, Spotify, and Aux.
   Existing tests prove important pieces: Roon playback with no live signal stays an audio problem, Spotify stale metadata does not imply active connection, ring buffers expose underflow/drop state, and meters do not consume playback buffers. The gap is a compact automated check that each selected live source reports the right no-signal state and source-specific route/status rows, especially Aux.

2. High: Aux status is under-tested compared with Roon and Spotify.
   Aux has route identity, adapter, and normal monitor coverage, but lacks the same explicit no-signal web/control status coverage currently present for Roon and partially present for Spotify.

3. Medium: Source switching is covered across topology, local play-now transitions, and stale web state, but not by one selected input-status transition matrix.
   Current tests cover live-to-live topology rebuilds, live-to-local topology cleanup, local play-now from Spotify/Roon, stale Spotify metadata, stale Roon metadata, and stale local state. The remaining useful gap is a small status-panel check that stale inactive source state does not win immediately after a source switch.

4. Medium: Runtime route/sample-rate/channel-count diagnostics are well covered in pure adapters and conversion ledgers, but less directly in app-level status rows.
   AudioCore rejects mismatches and monitor ledgers report suspicious rates. App status tests should be added only where the native or web diagnostic surface is expected to show those facts.

5. High for setup readiness, not a test failure: README live-input setup still omits `Orbisonic Spotify Input` in the requirements/setup text while source, product docs, and tests treat Spotify as a dedicated selected live source.
   This is a product/setup documentation mismatch carried from the plan audit. It should be fixed before release readiness, but it is not the first Prompt 13 test target.

## Existing Tests That Already Cover Important Contracts

- `Tests/AudioContractsTests/AudioContractsTests.swift` covers sample-rate validation, Dante 31-channel eligibility, session format validation, source-channel ceiling, meter snapshot value semantics, conversion-ledger invalidation, and forbidden imports.
- `Tests/AudioImportTests/LocalAssetImportTests.swift` covers local asset readiness, sample-rate mismatch policy, managed import, conversion ledger records, and layout preservation.
- `Tests/AudioCoreTests/SourceAdapterTests.swift` covers Roon route identity, Roon metadata/sample-rate separation, Spotify stereo-only policy, Aux channel policy, source sample-rate mismatch, local managed/unmanaged asset handling, test tone output, and off-source silence.
- `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift` covers source button order/raw/display naming, loopback UIDs, route acceptance/rejection, Spotify setup message, source live-channel policies, and source-switch capture-stop rules.
- `Tests/OrbisonicTests/OrbisonicWebStateTests.swift` covers public/control separation, source button labels and values, local/Roon/Spotify player state isolation, Roon no-signal with active playback, Spotify stale metadata, and Spotify receiving-audio override behavior.
- `Tests/OrbisonicTests/LiveAudioBridgeTests.swift` covers source-channel cap, priming, underflow recovery, and bounded drop behavior.
- `Tests/OrbisonicTests/LiveNormalMonitorRouteTests.swift`, `NormalMonitorRouteDescriptorTests.swift`, and `NormalMonitorGraphTopologyTests.swift` cover live/local monitor-only routing, two-channel monitor output, no spatial fallback, no audible Sonic Sphere matrix fallback, and stale topology cleanup.
- `Tests/OrbisonicTests/MeteringIsolationTests.swift`, `SonicSphereMeteringTests.swift`, and `Tests/AudioCoreTests/MeteringTelemetryTests.swift` cover non-consuming meter peeks and meter-only side-effect boundaries.
- `Tests/OrbisonicTests/RendererModuleTests.swift`, `RendererMatrixSampleRendererTests.swift`, and `Tests/AudioCoreTests/RenderGraphPlanTests.swift` / `RenderKernelTests.swift` / `OutputAdapterTests.swift` cover renderer topology, Direct 30/31 behavior, channel 32 silence, output route validation, and monitor/production output separation.
- `Tests/OrbisonicTests/PureAudioArchitectureBoundaryTests.swift` covers forbidden imports and ownership boundaries for package and UI/runtime layers.

## Tests To Add First

1. Add a deterministic live-source no-signal status test for Roon, Spotify, and Aux.
   Suggested target: `Tests/OrbisonicTests/OrbisonicWebStateTests.swift` or a new `Tests/OrbisonicTests/InputSourceStatusPanelTests.swift`.
   The test should use existing test setters to select each live source, set the expected loopback route, set `.noSignal` plus a silence duration, and assert source-specific panel rows/headlines keep captured audio truth separate from metadata or player activity.

2. Add an Aux-specific no-signal test.
   Suggested target: same as above.
   The test should assert Aux shows the dedicated Aux input row, route/channel facts where available, and `No signal`/waiting copy without borrowing Roon or Spotify metadata concepts.

3. Add one compact stale-state transition test around the input source panel.
   Suggested target: `Tests/OrbisonicTests/OrbisonicWebStateTests.swift`.
   The test should seed inactive Roon/Spotify/local state, switch to another selected source, and assert source panel/player status reflects only the selected source.

4. Defer route/sample-rate/channel-count UI diagnostics unless Prompt 13 has room after the live no-signal tests.
   Existing pure coverage is strong. App-level diagnostics should be added only as focused status-row assertions, not broad app rewrites.

## Tests That Should Not Be Automated Because They Require Hardware

- Physical Sonic Sphere / Dante speaker order, acoustic output, LFE behavior, and Direct 30/31 channel walks.
- Real Roon playback reaching `Orbisonic Roon Input`.
- Real Spotify Connect session reaching `Orbisonic Spotify Input`.
- Real external-app Aux capture through `Orbisonic Aux Cable`.
- macOS microphone permission prompts for loopback capture.
- App signing/entitlement behavior for Apple spatial/head-tracking routes.
- Installer behavior, suite loopback-driver installation, LaunchServices app open, and packaged helper availability.
- Roon bridge authorization against a live Roon Server.

These should be documented in release verification notes when exercised, not represented as passed unit tests.

## Suggested Scope For Prompt 13

Prompt 13 should be tests-only and target the smallest useful contract pass:

- Add 2-4 deterministic `OrbisonicTests` around selected live-source no-signal diagnostics.
- Prefer `OrbisonicWebStateTests.swift` or a new small `InputSourceStatusPanelTests.swift`.
- Cover Roon, Spotify, and Aux using existing `OrbisonicViewModel` test setters.
- Assert captured audio truth stays separate from player metadata and stale inactive source state.
- Do not change production code unless a new test exposes a real behavior bug; if that happens, stop and report the required behavior fix.
- Run the full SwiftPM test suite after test changes.

## Contradictions Between Contracts And Tests

No direct contradiction was found where current tests assert behavior that conflicts with `docs/contracts.md`.

One product/setup contradiction remains from the plan audit: README setup text omits the dedicated Spotify loopback in one live-input setup path while source and tests expose `Orbisonic Spotify Input`. That is a docs/setup readiness issue, not an automated-test contradiction.

One coverage over-read was found in project-control docs: `docs/test-strategy.md` correctly lists all-zero live input as a critical invariant, but the automated coverage is uneven by source. Roon has explicit active-playback/no-signal status coverage, Spotify has stale-metadata/no-signal-adjacent coverage, and Aux needs a direct no-signal status test.

## Recommended Next Prompt

Prompt 13: Contract Test Gap Pass, Tests Only.
