# Task 009: SonicSphere Renderer Contracts

## Status

complete

## Goal

Implement or adapt renderer contracts for source-to-sphere production rendering.

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
- Enforce source layout authority.
- Enforce render policy.
- Add Direct 30 identity tests.
- Add 52-channel policy blocker test.
```

## Out Of Scope

Do not:

```text
- Do not use VLC stereo callback as production input.
- Do not output to Dante directly.
- Do not change UI.
```

## Acceptance Criteria

This task is complete when:

```text
- Direct 30 identity passes.
- 52-channel source is blocked or preserved according to contract.
- Renderer emits RenderedSphereBlock.
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
Orbisonic status: completed Task 009; ready for Task 010: Dante Output Formatter.
```
