# Pure Audio Branch 2 Status

## Implemented

- `AudioContracts` is a separate pure value module.
- `AudioImport` owns probing, explicit offline managed import, and local asset production readiness.
- `AudioCore` contains the command facade, telemetry surface, session planner, route capability validator, immutable render graph plans, canonical source bus, pure render kernels, source adapters, validation/offline output adapters, dual-output coordinator, and copy-only metering.
- Architecture boundary tests scan source files for forbidden imports and graph symbols outside explicit migration exceptions.
- Local file production playback is now gated before the legacy engine can stream or commit a file when Output 2 Renderer is selected.
- Mismatched local files in a renderer-selected production path are blocked with the managed-import/restart message.
- `AudioSessionPlanner` rejects feedback-loop risk routes for desktop and Dante production planning.
- Sonic Sphere UI metering remains labeled `Sonic Sphere Analysis Meter`, not `Dante Output Meter`.
- Channel 32 remains reserved/silent in 32-channel Dante validation/offline plans.

## Still Legacy

- Current audible playback still runs through `OrbisonicEngine` and the Normal Monitor compatibility graph.
- `OrbisonicViewModel` still calls the legacy engine for play, pause, route selection, local file commit, live loopback start, and test tones.
- `OutputRouteMonitor` and `BlackHoleRouteRepair` still own legacy Core Audio route discovery/repair.
- `MeteringService` still supports the existing Normal Monitor and analysis-meter surfaces.
- `RendererModule` and `RendererMatrixSampleRenderer` still support legacy analysis/projection behavior.

## Live Dante Output Status

Live Dante output is not complete.

The branch contains validated/offline Dante planning, rendering, output adapter structure, status snapshots, channel-count validation, sample-rate validation, and channel-32 silence enforcement. It does not yet bind a real live output adapter to Dante hardware and does not prove that 31-channel audio is leaving the Mac.

UI and diagnostics must not say `Dante Output active` until a real `AudioCore`-owned live output adapter is implemented and tested.

## Remaining Bypasses

- Live Roon, Spotify, and Aux starts still use legacy view-model/engine paths instead of `AudioControl` source adapter commands.
- Output route changes still call the legacy engine route mutation path.
- Test tones still use legacy test-tone support for current audible behavior.
- The managed import API exists, but the UI does not yet offer a complete convert-and-retry flow.
- Session ledgers are planner/import artifacts, not yet persisted as authoritative live session ledgers.
- Current VU display stores are not fully derived from `MeterSnapshot` yet.
- Desktop and Dante live output independence is proven by offline coordinator tests, not physical dual-device output.

## Bypasses Closed In Prompt 12

- Renderer-selected local file playback can no longer feed a mismatched file into the legacy engine without consulting the Pure Audio local file gate.
- Renderer-selected local file playback can no longer admit more than 64 source channels.
- Feedback-loop risk routes are rejected by the session planner.
- `OrbisonicViewModel` no longer has an `AVAudioEngine` symbol allowlist exception.

## Test Commands Run

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter PureAudioIntegrationHardeningTests
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter AudioSessionPlannerTests
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter PureAudioArchitectureBoundaryTests
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Results:

- `PureAudioIntegrationHardeningTests`: passed, 5 tests.
- `AudioSessionPlannerTests`: passed, 17 tests.
- `PureAudioArchitectureBoundaryTests`: passed, 7 tests.
- Full `swift test`: passed, 432 tests.

## Known Failures

No known Prompt 12 focused test failures remain.

## Shipping Risk

Do not ship this as completed Pure Audio production Dante output.

The branch is useful as a hardened architecture baseline and validation layer. It is not a complete live Dante renderer. The highest shipping risks are the remaining legacy engine ownership, live route mutation outside `AudioControl`, and no real physical Dante output adapter.

## Manual Verification

Local file mismatch:

1. Select a renderer output route that resolves to Dante Virtual Soundcard.
2. Load a local file whose sample rate differs from the renderer route nominal sample rate.
3. Playback should be blocked before streaming/full decode commit.
4. The displayed error should explain that production playback requires matching sample rates and should offer managed conversion or a stopped-session rebuild.

Route validation:

1. Choose a BlackHole or Orbisonic loopback output as a production candidate.
2. Planning should reject it as a feedback-loop risk.
3. A safe desktop route and a Dante route with at least 31 channels at 44.1, 48, 88.2, or 96 kHz should validate.
4. Dante Virtual Soundcard at 176.4 or 192 kHz must be rejected for 31-channel production.

Meter labels:

1. Open the app meter surfaces.
2. Current Sonic Sphere projection labels should read `Sonic Sphere Analysis Meter`.
3. They should not read `Dante Output Meter` unless the source is the actual post-render Dante bus and live Dante output is implemented.

Desktop and Dante independence:

- Current live output cannot manually prove this because live Dante is not implemented.
- Use the offline dual-output coordinator tests to verify that desktop gain/failure cannot alter Dante output hashes and Dante gain/failure cannot alter desktop output hashes.

## Next Recommended Engineering Prompt

Move live session start/source selection/route selection behind `AudioControl`, then implement a real `AudioCore`-owned live output execution path. If AUHAL/Core Audio live dual-device binding is too large for one prompt, first replace legacy source start and local file commit with `AudioControl` commands while keeping live output validation-only.
