# DEPRECATED

Deprecated historical Orbisonic task material from the former split workspace. Retained for reference only; do not treat it as active instructions.

# 011: Documentation Refresh And Readiness

Status: Complete

## Goal

Refresh project control docs after hardening and produce a release-readiness summary.

## Background

After audits, tests, hardening, and release verification docs, the repo needs a final documentation pass that reflects what changed, what was verified, what remains manual, and what risks remain before release.

## Relevant Docs To Read

- `AGENTS.md`
- `README.md`
- `RELEASE_NOTES.md`
- `docs/status.md`
- `docs/product-brief.md`
- `docs/architecture.md`
- `docs/contracts.md`
- `docs/system-flows.md`
- `docs/implementation-map.md`
- `docs/test-strategy.md`
- `docs/release-verification.md`
- `docs/audits/`
- `docs/decisions/`
- `.tasks/`
- Relevant source and test files changed by Tasks 004 through 010.

## Scope

- Refresh docs that are stale after hardening.
- Produce a release-readiness summary under `docs/`.
- Confirm implementation map, flows, contracts, test strategy, and release verification agree.
- Update task statuses where appropriate.
- Update `docs/status.md`.

## Out Of Scope

- New production behavior changes.
- New tests unless a documentation claim cannot be supported without one.
- New dependencies.
- Rewriting historical docs unrelated to current readiness.

## Contract References

- All sections in `docs/contracts.md`.
- `docs/test-strategy.md` section `Completion Rule`.
- All accepted ADRs under `docs/decisions/`.
- `docs/release-verification.md`.

## Expected Files

- `docs/readiness-summary.md`
- `docs/status.md`
- `docs/product-brief.md`
- `docs/architecture.md`
- `docs/contracts.md`
- `docs/system-flows.md`
- `docs/implementation-map.md`
- `docs/test-strategy.md`
- `.tasks/`

## Acceptance Criteria

- Readiness summary lists automated checks run, manual checks run, manual checks still required, known risks, and release blockers.
- Docs align with the current source, tests, and accepted decisions.
- Any stale claim is corrected or marked historical.
- No new production behavior is introduced.
- Final status points to the next release or maintenance action.

## Verification Commands

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```

Run full tests if source or test files changed since the last verified baseline. For docs-only refresh, use the docs-only no-source-change check from `AGENTS.md`.

## Stopping Conditions

- A readiness claim cannot be supported by tests, docs, or manual evidence.
- Docs disagree with current source in a way that requires implementation work.
- A contract needs to change.
- Release blockers require user prioritization.

## Required Final Summary

Use the standard summary format from `AGENTS.md` and include readiness result, blockers, automated checks, manual checks, and recommended next action.

## Completion Notes

- Created `docs/readiness-summary.md`.
- Refreshed stale project control claims in `docs/status.md`, `docs/product-brief.md`, `docs/architecture.md`, and `docs/implementation-map.md`.
- Corrected task status drift for the contract-test gap audit and documented why the standalone audio-boundary hardening plan was superseded by Prompts 15 through 17.
- Added the next manual release-verification task under `.tasks/012-manual-release-verification.md`.
- No production source or test files were changed by this task.
