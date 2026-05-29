# Orbisonic Changelog

## 2026-05-29

### Fixed

- Fixed Output 2 Renderer diagnostic channel-walk preparation so renderer diagnostics use the selected renderer route instead of the Output 1 Monitor route.
- Removed the runtime Dock icon override so the app relies on its signed bundle icon normally.

### Changed

- Reworked loaded local-file monitor playback around a prepared reference stereo monitor buffer, while preserving source-channel buffers for input and Sonic Sphere analysis.
- Restarted remaining multichannel local and streaming playback nodes from a shared host time after paused resume to reduce resume skew.
- Added channel-layout confidence, layout evidence, and ambiguity warnings to source metadata.
- Split the Renderer tab status surface into `Monitor Downmix` and `Sonic Sphere Render` panels, with explicit normal-monitor downmix rules and warnings for ambiguous multichannel layouts.
- Updated the active app icon resources with rounded macOS app-icon assets and preserved before/after icon evidence under `docs/app-icon-rounded-fix-2026-05-27/`.

### Added

- Added `MonitorDownmixPanelModel` and tests for stereo, explicit 5.1, ambiguous 5.1, live multichannel fallback, and Atmos-bed-only monitor downmix panel states.
- Added a focused renderer diagnostic routing regression test that guards the private `prepareDiagnosticOutput(for:)` branch.
- Added source-grounded audio rewrite context under `docs/audio-system-flow-rendering-timing-rewrite-context.md`.
- Added the local-player responsiveness preservation note under `docs/orbisonic-real-time-transport-responsiveness-tweak.md`.
- Added an ignore rule so locally built installer package artifacts stay out of ordinary Git pushes.

### Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter DiagnosticRoutingRegressionTests` passed.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` passed with 707 tests and 0 failures.
- `git diff --check` passed.
- `./scripts/refresh-orbisonic-app.sh` refreshed and signed `Orbisonic.app`.

### Remaining Manual Gates

- Sonic Sphere / Dante route proof remains manual.
- The Output 2 Renderer diagnostic fix still needs remote DVS verification showing `rendererWalk` logs `output=Dante Virtual Soundcard`.
- Installer package artifacts are local/release assets, not part of this GitHub push. Installer execution, signing/notarization decisions, and hardware/service release gates remain governed by `docs/release-verification.md`.
