# Task 011: Production Output Session Fake Backend

## Status

 complete

## Goal

Implement strict production output lifecycle with fake backend before hardware integration.

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
- Add ProductionOutputSession protocol.
- Add fake backend.
- Add route validation tests.
- Add flush/drain/generation tests.
```

## Out Of Scope

Do not:

```text
- Do not integrate real Dante hardware yet.
- Do not change UI.
```

## Acceptance Criteria

This task is complete when:

```text
- Route mismatch fails before playback.
- Flush discards queued audio.
- Drain finishes queued audio.
- Channel-walk passes in fake backend.
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
Orbisonic status: completed Task 011; ready for Task 012: CoreAudio Dante Session.
```
