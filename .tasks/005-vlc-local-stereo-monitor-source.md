# Task 005: VLC Local Stereo Monitor Source

## Status

complete

## Goal

Implement local-file stereo monitor source using VLC callbacks.

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
- Implement VlcLocalStereoMonitorSource.
- Request FL32 stereo callback.
- Emit StereoMonitorBlock.
- Add ring buffer with generation safety.
- Add local stereo and 5.1 fixture tests if VLC is available.
```

## Out Of Scope

Do not:

```text
- Do not use VLC for production.
- Do not call native local downmixer.
- Do not add UI controls.
```

## Acceptance Criteria

This task is complete when:

```text
- DownmixOwner = VLC.
- Callback output is stereo.
- Native local downmix is not called.
- Stale generation rejected.
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
Orbisonic status: completed Task 005; ready for Task 006: Stereo Monitor Output Session.
```
