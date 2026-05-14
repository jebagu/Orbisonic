# DEPRECATED

Deprecated historical Orbisonic task material from the former split workspace. Retained for reference only; do not treat it as active instructions.

# 008: Source Isolation Hardening

Status: Complete

## Goal

Harden Roon, Aux, Spotify, Local Files, and Test Tone source isolation so source switching cannot leave stale audible paths, metadata, route state, or web state behind.

## Background

Orbisonic is selected-source oriented, not a mixer. Local playback and live loopback capture are separate paths. Roon, Spotify, Aux, Local Files, and Test Tone must remain isolated unless a future accepted mixer contract changes that.

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
- `docs/decisions/0006-embedded-librespot-boundary.md`
- `docs/decisions/0007-roon-loopback-boundary.md`
- `Sources/Orbisonic/OrbisonicViewModel.swift`
- `Sources/Orbisonic/OrbisonicEngine.swift`
- `Sources/Orbisonic/LoopbackSourceSupport.swift`
- `Sources/Orbisonic/RoonNowPlayingMonitor.swift`
- `Sources/Orbisonic/RoonBridgeClient.swift`
- `Sources/Orbisonic/SpotifyReceiverClient.swift`
- `Sources/Orbisonic/OrbisonicWebServer.swift`
- Relevant source-switching and web-state tests.

## Scope

- Add or strengthen source-switching tests.
- Harden state reset, stale metadata handling, route selection, and public/control web state when changing sources.
- Preserve separate local file and live loopback paths.
- Update docs and flows if user-visible source behavior changes.

## Out Of Scope

- Simultaneous source mixing.
- New source modes.
- Roon API migration.
- Spotify transport redesign.
- Renderer topology changes.
- Monitor path redesign.

## Contract References

- `docs/contracts.md` sections `Orbisonic Executable App Shell`, `OrbisonicEngine`, `Local File Source And Local Library Path`, `Roon Integration Boundary`, `Spotify Integration Boundary`, and `Aux Source Boundary`.
- `docs/system-flows.md` source-specific flows.
- `docs/test-strategy.md` invariants `Local file path stays separate from live loopback path` and `Roon, Spotify, Aux, and local sources stay isolated`.

## Expected Files

- `Sources/Orbisonic/OrbisonicViewModel.swift`
- `Sources/Orbisonic/OrbisonicEngine.swift`
- `Sources/Orbisonic/LoopbackSourceSupport.swift`
- `Sources/Orbisonic/RoonNowPlayingMonitor.swift`
- `Sources/Orbisonic/RoonBridgeClient.swift`
- `Sources/Orbisonic/SpotifyReceiverClient.swift`
- `Sources/Orbisonic/OrbisonicWebServer.swift`
- `Tests/OrbisonicTests/LocalPlayerStabilizationTests.swift`
- `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift`
- `Tests/OrbisonicTests/OrbisonicWebStateTests.swift`
- `Tests/OrbisonicTests/SpotifyReceiverClientTests.swift`
- `Tests/OrbisonicTests/RoonNowPlayingMonitorTests.swift`
- `docs/status.md`
- `docs/system-flows.md` if flows change
- `docs/test-strategy.md` if coverage changes

## Acceptance Criteria

- Source switches do not preserve stale audible live capture, local playback, metadata, or web state outside the selected source contract.
- Tests cover the selected-source isolation behavior changed by the task.
- No source mixing is introduced.
- Full SwiftPM tests pass or blockers are documented.
- Manual checks for real live sources remain listed unless actually performed.

## Completion Notes

- Prompt 16 hardened `OrbisonicViewModel` source transitions so Off and Test Tone clear stale local playback snapshots, Roon metadata, and loaded source metadata before publishing their selected-source state.
- Spotify source health now reports the current fixed stereo policy instead of promoting stale local multichannel metadata as a Spotify stream format.
- `OrbisonicWebStateTests` covers Off and Test Tone stale local snapshot cleanup plus the Spotify stale multichannel metadata boundary.
- Real Roon, Aux, Spotify Connect, loopback permission, and Sonic Sphere hardware checks remain manual.

## Verification Commands

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
./scripts/refresh-orbisonic-app.sh
./scripts/reopen-orbisonic-app.sh
git diff --check
```

Run the app refresh and reopen only when app code or GUI/audio behavior changes. Document any skipped manual hardware checks.

## Stopping Conditions

- The requested fix would require a mixer contract.
- A stale-state issue cannot be reproduced or protected with deterministic tests.
- A public contract needs to change.
- The task would require hardware-only verification before implementation can be trusted.

## Required Final Summary

Use the standard summary format from `AGENTS.md` and include source paths hardened, tests run, and any remaining live-source manual checks.
