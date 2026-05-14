# Task 014: Pure Spherical Reader

## Status

complete

## Goal

Implement direct LPCM reader for validated Pure Spherical Lossless files.

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
- Read LPCM into RenderedSphereBlock.
- Preserve channel order.
- Bypass VLC and renderer.
- Add tests.
```

## Out Of Scope

Do not:

```text
- Do not decode through VLC.
- Do not re-render.
- Do not downmix.
```

## Acceptance Criteria

This task is complete when:

```text
- Reader outputs rendered sphere blocks.
- No VLC calls occur.
- No renderer calls occur.
- Channel identity passes.
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
Orbisonic status: completed Task 014; ready for Task 015: Diagnostics And Conversion Ledger Integration.
```
