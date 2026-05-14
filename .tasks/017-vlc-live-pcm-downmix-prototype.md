# Task 017: Optional VLC Live PCM Downmix Prototype

## Status

completed

## Goal

Prototype a VLC live PCM downmix bridge for Roon multichannel only if prior tasks authorize it.

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
- Build proof harness only.
- Feed captured 5.1 PCM into VLC-readable raw stream.
- Return stereo FL32.
- Measure latency and drift.
```

## Out Of Scope

Do not:

```text
- Do not make it default.
- Do not hide latency.
- Do not change Roon UI.
```

## Acceptance Criteria

This task is complete when:

```text
- Latency and drift are measured.
- DownmixOwner = VLC live bridge only when selected.
- Default Roon path remains unchanged.
```

## Completion Notes

```text
- Added a proof-only VLC live PCM downmix harness for captured Roon 5.1 PCM.
- The harness feeds a VLC-readable raw FL32 5.1 stream and returns stereo FL32 monitor PCM.
- Latency and drift are measured in the prototype result and ledger note.
- DownmixOwner is VLC live PCM bridge only when the harness is explicitly selected.
- The default Roon 5.1 monitor path remains blocked unless an explicit downmix owner is supplied.
- No Roon UI, default path, or visible workflow was changed.
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
Orbisonic status: completed Task 017; ready for Task 018: Hardware Readiness And Manual Gates.
```
