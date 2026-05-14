# DEPRECATED

Deprecated historical Orbisonic task material from the former split workspace. Retained for reference only; do not treat it as active instructions.

# 005: Architecture Boundary Test Pass

Status: Complete

## Goal

Add or strengthen tests that protect SwiftPM module boundaries and prevent lower-level targets from reaching into app/UI/runtime ownership.

## Background

Orbisonic is a native SwiftPM app with `AudioContracts`, `AudioImport`, `AudioCore`, and `Orbisonic` targets. The retrofit depends on keeping shared contracts and pure audio planning independent from SwiftUI/app runtime code while acknowledging that substantial concrete behavior still lives in the executable target.

## Relevant Docs To Read

- `AGENTS.md`
- `Package.swift`
- `docs/architecture.md`
- `docs/contracts.md`
- `docs/implementation-map.md`
- `docs/test-strategy.md`
- `docs/decisions/0002-swiftpm-target-boundaries.md`
- `docs/decisions/0003-audio-contracts-as-shared-language.md`
- `Tests/OrbisonicTests/PureAudioArchitectureBoundaryTests.swift`
- `Tests/OrbisonicTests/ArchitectureBoundaryAllowlist.swift`
- Relevant source imports under `Sources/`

## Scope

- Strengthen forbidden-import and boundary tests.
- Keep allowlists explicit and narrow.
- Confirm `AudioContracts`, `AudioImport`, and `AudioCore` do not import app/UI/runtime-only dependencies outside documented exceptions.
- Update docs if boundary coverage expectations change.

## Out Of Scope

- Moving source files between targets.
- Refactoring production code.
- Changing public APIs.
- Adding dependencies.

## Contract References

- `docs/contracts.md` sections `AudioContracts`, `AudioImport`, `AudioCore`, and `Orbisonic Executable App Shell`.
- `docs/test-strategy.md` sections `Architecture boundary tests` and `Coverage Expectations`.
- `docs/decisions/0002-swiftpm-target-boundaries.md`.
- `docs/decisions/0003-audio-contracts-as-shared-language.md`.

## Expected Files

- `Tests/OrbisonicTests/PureAudioArchitectureBoundaryTests.swift`
- `Tests/OrbisonicTests/ArchitectureBoundaryAllowlist.swift`
- `docs/test-strategy.md` if coverage mapping changes
- `docs/status.md`

## Acceptance Criteria

- Boundary tests fail on forbidden imports or unauthorized cross-target dependency drift.
- Any allowlist entry has a short rationale.
- No production code moves occur in this task.
- Full SwiftPM tests pass or blockers are documented.

## Verification Commands

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```

## Stopping Conditions

- A boundary failure reveals production code that must move or be refactored.
- Fixing the issue would require changing target dependencies.
- The task would need a public contract change.
- Test changes require broad fixture or infrastructure work.

## Required Final Summary

Use the standard summary format from `AGENTS.md` and include boundary rules added or strengthened plus any deferred boundary risks.
