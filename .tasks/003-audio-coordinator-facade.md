# Task 003: Audio Coordinator Facade

## Status

complete

## Goal

Create the coordinator layer under the frozen UI without changing user workflows.

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
- Add OrbisonicAudioCoordinator2 skeleton.
- Add ExistingOrbisonicUIFacade adapter if needed.
- Map existing commands to coordinator methods.
- Add tests for path selection decisions.
```

## Out Of Scope

Do not:

```text
- Do not implement actual VLC or Dante audio.
- Do not add UI controls.
- Do not change source workflows.
```

## Acceptance Criteria

This task is complete when:

```text
- Local monitor selects future VLC path.
- Roon selects live PCM path.
- Spotify selects stereo path.
- Pure Spherical selects validator path.
- UI freeze tests still pass.
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
Orbisonic status: completed Task 003; ready for Task 004: VLC Build Guard And Capability Probe.
```
