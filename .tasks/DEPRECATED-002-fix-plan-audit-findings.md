# DEPRECATED

This file is deprecated legacy Orbisonic instruction material copied into the Orbisonic 2.0 workspace. Use `project-control/` at the Orbisonic 2.0 root for current instructions. Retained for reference only.

# 002: Fix Plan Audit Findings

Status: Complete

## Goal

Apply accepted fixes from the plan audit to project-control docs and task files only.

## Background

Task 001 is expected to produce a read-only audit. This task is the bounded follow-up that corrects accepted documentation and task-graph issues before contract-test gap work begins.

## Relevant Docs To Read

- `AGENTS.md`
- `docs/status.md`
- `docs/audits/0001-plan-audit.md`
- `docs/product-brief.md`
- `docs/architecture.md`
- `docs/contracts.md`
- `docs/system-flows.md`
- `docs/implementation-map.md`
- `docs/test-strategy.md`
- `docs/decisions/`
- `.tasks/`

## Scope

- Fix accepted audit findings in docs and `.tasks/`.
- Clarify task ordering, acceptance criteria, stopping conditions, or verification commands.
- Correct stale docs when the current source evidence is clear and the fix does not change a public contract.
- Update `docs/status.md`.

## Out Of Scope

- Production code changes.
- Test changes.
- Behavior changes.
- Public contract changes unless explicitly approved before this task starts.
- Fixing findings that require implementation work.

## Contract References

- `docs/contracts.md` section `Contract Rules`.
- `docs/decisions/0001-retrofit-not-rewrite.md`.
- `docs/decisions/0002-swiftpm-target-boundaries.md`.
- `AGENTS.md` sections `Task Discipline`, `Documentation Requirements`, and `Stopping Conditions`.

## Expected Files

- `docs/status.md`
- `docs/audits/0001-plan-audit.md`
- Any affected file under `docs/`
- Any affected file under `.tasks/`

## Acceptance Criteria

- Every fixed audit finding is traceable back to the audit.
- Deferred findings remain documented with reason and target task.
- Docs and task files remain internally consistent.
- No source or test files change.

## Verification Commands

```sh
find docs .tasks -maxdepth 2 -type f | sort
git diff --name-only -- README.md Package.swift Sources Tests scripts installer Vendor calibration
git diff --check
```

## Stopping Conditions

- A fix requires a public contract change.
- A fix requires source or test changes.
- An audit finding is ambiguous and needs user prioritization.
- The fix would touch unrelated docs or task files without clear linkage.

## Required Final Summary

Use the standard summary format from `AGENTS.md` and list fixed, deferred, and blocked audit findings.
