# Task 013: Pure Spherical Lossless Validator And Badge

## Status

complete

## Goal

Implement Pure Spherical Lossless validation and the only allowed UI badge.

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
- Add validator.
- Add metadata parser stubs or implementation.
- Add badge presenter.
- Place badge in existing UI surface only.
- Add UI freeze tests.
```

## Out Of Scope

Do not:

```text
- Do not add inspector or export view.
- Do not trust filename alone.
- Do not change workflows.
```

## Acceptance Criteria

This task is complete when:

```text
- Valid file shows badge.
- Invalid file does not show badge.
- Badge is only UI addition.
- UI freeze tests pass.
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
Orbisonic status: completed Task 013; ready for Task 014: Pure Spherical Reader.
```
