# DEPRECATED

Deprecated historical Orbisonic task material from the former split workspace. Retained for reference only; do not treat it as active instructions.

# 001: Plan Audit

Status: Complete

## Goal

Audit the project control docs and `.tasks/` graph for correctness, gaps, contradictions, risky sequencing, and unclear acceptance criteria without changing source or tests.

## Background

The retrofit has created a baseline architecture, contracts, flows, test strategy, ADRs, operating instructions, and task graph. Before implementation work starts, the plan itself needs a read-only audit so future tasks do not build on contradictions or stale assumptions.

## Relevant Docs To Read

- `AGENTS.md`
- `README.md`
- `Package.swift`
- `docs/status.md`
- `docs/product-brief.md`
- `docs/architecture.md`
- `docs/contracts.md`
- `docs/system-flows.md`
- `docs/implementation-map.md`
- `docs/test-strategy.md`
- `docs/decisions/`
- `.tasks/`
- Relevant `Sources/` and `Tests/` files only as evidence for audit findings.

## Scope

- Produce a plan-audit document under `docs/audits/`.
- Check task ordering and dependency assumptions.
- Check whether docs overclaim hardware verification.
- Check whether tasks separate docs-only, test-only, and code-affecting work.
- Check whether acceptance criteria are executable and bounded.

## Out Of Scope

- Fixing the docs being audited.
- Source changes.
- Test changes.
- Production behavior changes.
- Dependency additions.

## Contract References

- `docs/contracts.md` section `Contract Rules`.
- `docs/contracts.md` sections `AudioContracts`, `AudioImport`, `AudioCore`, and `Orbisonic Executable App Shell`.
- `docs/test-strategy.md` section `Completion Rule`.
- `docs/decisions/0001-retrofit-not-rewrite.md`.

## Expected Files

- `docs/audits/0001-plan-audit.md`
- `docs/status.md`

## Acceptance Criteria

- Audit findings are prioritized and include file references.
- Findings distinguish contradictions, missing docs, missing tests, unclear sequencing, and manual hardware gaps.
- The audit does not silently fix the findings.
- `docs/status.md` records the audit as a recent change.
- No source or test files change.

## Verification Commands

```sh
find .tasks docs -maxdepth 2 -type f | sort
git diff --name-only -- README.md Package.swift Sources Tests scripts installer Vendor calibration
git diff --check
```

## Stopping Conditions

- The task graph is missing or incomplete.
- A public contract appears wrong and would need immediate revision.
- The repo appears to be stale or not the active native Swift app.
- Source or test edits would be required to complete the audit.

## Required Final Summary

Use the standard summary format from `AGENTS.md` and list the highest-priority audit findings or state that none were found.
