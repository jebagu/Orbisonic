# Task 008: Source Rate Converter

## Status

complete

## Goal

Implement explicit high-quality SRC contract and fake or real converter.

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
- Add SourceRateConverter protocol/profile.
- Add deterministic tests for rate conversion behavior.
- Add ledger events.
- If real SRC dependency is needed, stop unless task explicitly authorizes it.
```

## Out Of Scope

Do not:

```text
- Do not hide SRC in output session.
- Do not dither.
- Do not downmix.
```

## Acceptance Criteria

This task is complete when:

```text
- SRC is explicit and logged.
- No channel bleed.
- No double SRC.
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
Orbisonic status: completed Task 008; ready for Task 009: SonicSphere Renderer Contracts.
```
