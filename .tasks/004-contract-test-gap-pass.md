# 004: Contract Test Gap Pass

Status: Complete

## Goal

Add or update focused tests for the highest-priority contract coverage gaps found in Task 003.

## Background

The contract-test gap audit should identify missing automated protection. This task makes one bounded test pass against the most important gaps without changing production behavior unless a failing test exposes a genuine bug and the user explicitly expands the task.

## Relevant Docs To Read

- `AGENTS.md`
- `docs/status.md`
- `docs/audits/0002-contract-test-gap-audit.md`
- `docs/contracts.md`
- `docs/system-flows.md`
- `docs/implementation-map.md`
- `docs/test-strategy.md`
- Relevant `docs/decisions/`
- Relevant `Sources/` and `Tests/` files named by the audit.

## Scope

- Add or update deterministic tests for accepted high-priority contract gaps.
- Prefer the smallest relevant test target.
- Use generated fixtures, deterministic PCM, temporary directories, or existing safe fixtures.
- Update test strategy docs if new coverage changes the contract-to-test map.
- Update `docs/status.md`.

## Out Of Scope

- Production behavior changes unless explicitly expanded after a failing test proves a genuine bug.
- Hardware or service end-to-end tests.
- Major refactors.
- New dependencies.
- Broad fixture rewrites.

## Contract References

- `docs/contracts.md` section matching the selected gap.
- `docs/test-strategy.md` sections `Coverage Expectations`, `Test Data Rules`, and `Completion Rule`.
- Relevant ADRs under `docs/decisions/`.

## Expected Files

- One or more focused files under `Tests/AudioContractsTests/`, `Tests/AudioImportTests/`, `Tests/AudioCoreTests/`, or `Tests/OrbisonicTests/`
- `docs/test-strategy.md` when coverage maps change
- `docs/status.md`

## Acceptance Criteria

- Each added or updated test maps to a specific audit gap.
- Tests remain deterministic and do not require private media, real loopback devices, Roon, Spotify, Sonic Sphere, Dante, microphone prompts, signing entitlements, or installers.
- No production code changes occur unless the task is explicitly expanded.
- The full SwiftPM test suite passes or blockers are documented.

## Verification Commands

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```

## Stopping Conditions

- A proposed test requires hardware, private data, or external services.
- A failing test indicates a production bug that cannot be safely fixed inside this task.
- A public contract needs to change.
- Adding coverage requires a major dependency or broad refactor.

## Required Final Summary

Use the standard summary format from `AGENTS.md` and list each gap covered, tests added or updated, commands run, and any remaining gaps.
