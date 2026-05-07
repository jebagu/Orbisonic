# 000: Retrofit Control Docs

Status: Complete

## Goal

Document the docs-only retrofit already performed by Prompts 02 through 08 and make its outputs discoverable for later tasks.

## Background

The retrofit established project-control documents before any hardening work. Those documents describe the current native Swift/macOS app, its module boundaries, audio contracts, system flows, test strategy, retrospective decisions, and repo-level operating rules. This task records that the baseline control package exists and should be audited before implementation work starts.

## Relevant Docs To Read

- `AGENTS.md`
- `docs/status.md`
- `docs/product-brief.md`
- `docs/architecture.md`
- `docs/contracts.md`
- `docs/system-flows.md`
- `docs/implementation-map.md`
- `docs/test-strategy.md`
- `docs/decisions/0001-retrofit-not-rewrite.md`
- `docs/decisions/0002-swiftpm-target-boundaries.md`
- `docs/decisions/0003-audio-contracts-as-shared-language.md`
- `docs/decisions/0004-selected-source-only-rule.md`
- `docs/decisions/0005-sonic-sphere-30-1-primary-output.md`
- `docs/decisions/0006-embedded-librespot-boundary.md`
- `docs/decisions/0007-roon-loopback-boundary.md`

## Scope

- Confirm that Prompts 02 through 08 produced the expected docs.
- Confirm that `AGENTS.md` now acts as the repo operating file.
- Keep this task as the checkpoint for the completed docs-only baseline.

## Out Of Scope

- Source changes.
- Test changes.
- Behavior changes.
- New audit findings or fixes beyond recording the baseline.

## Contract References

- `docs/contracts.md` section `Contract Rules`.
- `docs/decisions/0001-retrofit-not-rewrite.md`.
- `docs/decisions/0002-swiftpm-target-boundaries.md`.
- `docs/decisions/0003-audio-contracts-as-shared-language.md`.

## Expected Files

- `AGENTS.md`
- `docs/status.md`
- `docs/product-brief.md`
- `docs/architecture.md`
- `docs/contracts.md`
- `docs/system-flows.md`
- `docs/implementation-map.md`
- `docs/test-strategy.md`
- `docs/decisions/`
- `.tasks/000-retrofit-control-docs.md`

## Acceptance Criteria

- Baseline control docs exist and are referenced from `docs/status.md`.
- Retrospective ADRs exist for the accepted baseline decisions.
- No source or test files were changed by this checkpoint task.
- Remaining retrofit work is represented by later `.tasks/` files.

## Verification Commands

```sh
find docs .tasks -maxdepth 2 -type f | sort
git diff --name-only -- README.md Package.swift Sources Tests scripts installer Vendor calibration
git diff --check
```

## Stopping Conditions

- A required Prompt 02 through Prompt 08 artifact is missing.
- Existing docs contradict current source in a way that changes task ordering.
- Source or test files changed during this docs-only checkpoint.

## Required Final Summary

Use the standard summary format from `AGENTS.md` and include whether this task remained docs-only.
