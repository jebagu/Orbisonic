# Task 004: VLC Build Guard And Capability Probe

## Status

complete

## Goal

Add a guarded VLC reference module and capability probe without changing default UI.

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
- Add build flag for VLC reference module.
- Add runtime availability check.
- Add capability report.
- Add tests that default build works when VLC is unavailable.
```

## Out Of Scope

Do not:

```text
- Do not make VLC required for app launch.
- Do not expose VLC in UI.
- Do not implement playback yet.
```

## Acceptance Criteria

This task is complete when:

```text
- Default build works without VLC.
- VLC unavailable is diagnostic, not crash.
- No UI strings mention VLC in normal UI.
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
Orbisonic status: completed Task 004; ready for Task 005: VLC Local Stereo Monitor Source.
```
