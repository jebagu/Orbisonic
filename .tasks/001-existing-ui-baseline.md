# Task 001: Existing UI Baseline And Freeze Tests

## Status

complete

## Goal

Capture the existing UI contract and create tests that prevent UI drift.

## Background

Orbisonic is a UI-frozen audio-chain rewrite. The existing UI must remain unchanged except for the Pure Spherical Lossless badge.

## Relevant Docs

Read before starting:

```text
AGENTS.md
docs/product-brief.md
docs/ui-freeze.md
docs/architecture.md
docs/audio-path-invariants.md
docs/contracts.md
docs/system-flows.md
docs/test-strategy.md
docs/status.md
```

## Scope

Implement or perform:

```text
- Inspect existing UI files.
- Record baseline screens, controls, source workflows, and transport control behavior.
- Add UI freeze tests.
- Add Pure Spherical Lossless badge allowance only.
- Update docs/status.md and docs/implementation-map.md.
```

## Out Of Scope

Do not:

```text
- Do not alter UI layout.
- Do not implement audio chain.
- Do not add new screens or controls.
```

## Acceptance Criteria

This task is complete when:

```text
- UI baseline is documented.
- Tests fail if new screens or transport controls are added.
- Tests allow only Pure Spherical Lossless badge.
```

## Verification Commands

Run relevant commands that exist in the repository. Expected examples:

```text
swift test
```

If a command does not exist, document that.

## Stopping Conditions

Stop and report if:

```text
UI freeze would be violated
audio invariants would be violated
a public contract must change
a major dependency is needed but not authorized
the task touches unrelated subsystems
verification is impossible
```

## Required Final Summary

Return:

```text
Summary:
Files changed:
Tests added or updated:
Commands run:
Results:
Documentation updated:
Assumptions:
Risks or blockers:
Recommended next task:
Orbisonic status: completed Task 001; ready for Task 002: Core Audio Contracts.
```
