# DEPRECATED

This file is deprecated legacy Orbisonic instruction material copied into the Orbisonic 2.0 workspace. Use `project-control/` at the Orbisonic 2.0 root for current instructions. Retained for reference only.

# 007: Live Loopback Diagnostics Hardening

Status: Completed (2026-05-05)

## Goal

Harden live loopback diagnostics so silent or unhealthy Roon, Spotify, and Aux capture is visible and explainable without masking all-zero input.

## Background

Roon, Spotify, and Aux can show player or metadata activity while live Core Audio capture is silent or misrouted. The app must compare route identity, sample rate, channel count, live meter peak, underflow count, dropped frames, and signal state rather than treating metadata as proof of audio.

## Relevant Docs To Read

- `AGENTS.md`
- `docs/status.md`
- `docs/contracts.md`
- `docs/system-flows.md`
- `docs/implementation-map.md`
- `docs/test-strategy.md`
- `docs/audits/0002-contract-test-gap-audit.md`
- `docs/readiness-summary.md`
- `docs/decisions/0004-selected-source-only-rule.md`
- `docs/decisions/0007-roon-loopback-boundary.md`
- `Sources/Orbisonic/LiveAudioBridge.swift`
- `Sources/Orbisonic/LoopbackSourceSupport.swift`
- `Sources/Orbisonic/OrbisonicEngine.swift`
- `Sources/Orbisonic/OrbisonicViewModel.swift`
- `Sources/Orbisonic/InputSourceStatusPanelModel.swift`
- `Sources/Orbisonic/DiagnosticsView.swift`
- Relevant live loopback tests.

## Scope

- Improve diagnostic state, status text, or telemetry around missing routes, wrong routes, sample-rate mismatch, channel-count mismatch, no-signal state, underflows, and dropped frames.
- Add or update focused tests before or with changes.
- Update docs and flows if user-visible diagnostics change.
- Keep live silence visible.

## Out Of Scope

- Generating fake signal.
- Increasing gain or buffering to hide silence.
- Source mixing.
- Roon API replacement.
- Spotify transport expansion.
- Production renderer topology changes.

## Contract References

- `docs/contracts.md` sections `LiveAudioBridge`, `Roon Integration Boundary`, `Spotify Integration Boundary`, `Aux Source Boundary`, and `Diagnostics And Logging Boundary`.
- `docs/system-flows.md` sections `Live Roon Loopback Flow`, `Aux Loopback Flow`, `Spotify Receiver Flow`, and `Route Diagnostics Flow`.
- `docs/test-strategy.md` invariants `All-zero live input is diagnosed rather than hidden` and `Sample-rate and channel-count mismatches are visible`.

## Expected Files

- `Sources/Orbisonic/LiveAudioBridge.swift`
- `Sources/Orbisonic/LoopbackSourceSupport.swift`
- `Sources/Orbisonic/OrbisonicEngine.swift`
- `Sources/Orbisonic/OrbisonicViewModel.swift`
- `Sources/Orbisonic/InputSourceStatusPanelModel.swift`
- `Sources/Orbisonic/DiagnosticsView.swift`
- `Tests/OrbisonicTests/LiveAudioBridgeTests.swift`
- `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift`
- `Tests/OrbisonicTests/OrbisonicWebStateTests.swift`
- `Tests/OrbisonicTests/VURoutingViewTests.swift`
- `docs/status.md`
- `docs/system-flows.md` if flows change
- `docs/test-strategy.md` if coverage changes

## Acceptance Criteria

- Diagnostics distinguish player activity from captured loopback audio.
- All-zero live input remains a visible no-signal or unhealthy state.
- Underflow and dropped-frame counters remain visible and are not reset misleadingly.
- Tests cover the changed diagnostic behavior.
- Full SwiftPM tests pass or blockers are documented.
- Any real loopback, Roon, Spotify, Aux, or microphone-permission verification remains marked manual unless actually performed.

## Completion Notes

- Added `LiveLoopbackDiagnostics` as a deterministic diagnostic snapshot for live sources.
- Diagnostics now separate route, sample-rate, channel, signal, buffer, permission, and player/source activity.
- Silent live-input warning logs include the structured diagnostic summary.
- Added regression tests for silent Roon capture while Roon is playing, wrong selected input, channel mismatch, sample-rate mismatch, permission denial, and buffer counters.
- Hardware and external-service verification remains manual.

## Verification Commands

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
./scripts/refresh-orbisonic-app.sh
./scripts/reopen-orbisonic-app.sh
git diff --check
```

Run the app refresh and reopen only when app code or GUI/audio behavior changes. Document any skipped manual hardware checks.

## Stopping Conditions

- A fix would hide or synthesize live signal.
- A fix requires real hardware or service access that is unavailable.
- A public contract needs to change.
- The change touches renderer, monitor, installer, or unrelated subsystems without a direct diagnostic reason.

## Required Final Summary

Use the standard summary format from `AGENTS.md` and include diagnostic behavior changed, tests run, and manual live-capture checks still needed.
