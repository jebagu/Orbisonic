# Task 002: Core Audio Contracts

## Status

complete

## Goal

Implement or update shared audio contract types for blocks, layouts, routes, ledgers, diagnostics, and badge state.

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
- Add SourceDescriptor, SourceLayout, StereoMonitorBlock, CanonicalSourceBlock, RenderedSphereBlock.
- Add AudioConversionLedger and PlaybackDiagnosticSnapshot.
- Add PureSphericalLosslessState.
- Add unit tests.
```

## Out Of Scope

Do not:

```text
- Do not implement VLC.
- Do not implement Dante backend.
- Do not change UI except wiring badge state type if needed.
```

## Acceptance Criteria

This task is complete when:

```text
- Contracts compile.
- Contract tests pass.
- Ledger can represent local VLC monitor, Roon capture, Dante production, and Pure Spherical direct playback.
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
Orbisonic status: completed Task 002; ready for Task 003: Audio Coordinator Facade.
```
