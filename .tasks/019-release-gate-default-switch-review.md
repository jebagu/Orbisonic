# Task 019: Release Gate And Default Switch Review

## Status

completed

## Goal

Review whether any new path is ready to become default.

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
- Review test results.
- Review UI freeze compliance.
- Review audio invariants.
- Review packaging and license obligations.
- Decide default switches only if evidence supports them.
```

## Out Of Scope

Do not:

```text
- Do not switch defaults without evidence.
- Do not remove rollback path.
```

## Acceptance Criteria

This task is complete when:

```text
- Release readiness is documented.
- Default paths are justified.
- Rollback remains available.
```

## Completion Notes

```text
- Added release-gate and default-switch decision record.
- Documented that no new default switches are approved.
- Documented that rollback remains available because no source-code defaults changed.
- Recorded current decision as ready for implementation milestone review, not release-ready or hardware-ready.
- Preserved the frozen UI and audio invariants.
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
Orbisonic status: completed Task 019; ready for Project ready for implementation milestone review.
```
