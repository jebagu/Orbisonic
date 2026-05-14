# Task 000: Plan Audit

## Status

complete

## Goal

Audit the full planning package before implementation.

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
- Read all docs.
- Do not change source code.
- Identify missing contracts, contradictions, UI-freeze risks, and untestable tasks.
- Return proposed doc/task corrections.
```

## Out Of Scope

Do not:

```text
- Do not implement code.
- Do not change UI.
- Do not add dependencies.
```

## Acceptance Criteria

This task is complete when:

```text
- Audit report lists issues.
- Blocking questions are separated from assumptions.
- Recommended doc and task changes are concrete.
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
Orbisonic status: completed Task 000; ready for Task 001: Existing UI Baseline And Freeze Tests.
```
