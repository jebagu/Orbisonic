# Task 006: Stereo Monitor Output Session

## Status

complete

## Goal

Implement or wrap stereo monitor output session for finished stereo PCM.

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
- Accept StereoMonitorBlock only.
- Log requested and actual monitor route facts.
- Add tests for stereo-only admission and flush/stop.
```

## Out Of Scope

Do not:

```text
- Do not implement production output.
- Do not downmix multichannel audio here.
- Do not add UI controls.
```

## Acceptance Criteria

This task is complete when:

```text
- Stereo output session rejects non-stereo blocks.
- Existing UI transport still behaves the same.
- Ledger and diagnostics are emitted.
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
Orbisonic status: completed Task 006; ready for Task 007: Roon And Spotify Boundaries.
```
