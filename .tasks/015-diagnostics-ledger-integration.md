# Task 015: Diagnostics And Conversion Ledger Integration

## Status

completed

## Completion Notes

```text
Implemented diagnostics completeness checks in AudioContracts.
Integrated coordinator ledgers for local monitor, local production, Roon, Spotify, Aux, and Pure Spherical direct paths.
Exposed diagnostics rows and failure messages through ExistingDiagnosticsState.
Added ledger completeness tests and reran UI freeze tests.
```

## Goal

Integrate ledger and diagnostics across all implemented paths.

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
- Emit PlaybackDiagnosticSnapshot for local, Roon, Spotify, production, and Pure Spherical paths.
- Ensure existing diagnostics surface receives data without redesign.
- Add tests for ledger completeness.
```

## Out Of Scope

Do not:

```text
- Do not create new diagnostics UI screen.
- Do not expose VLC implementation details in normal UI.
```

## Acceptance Criteria

This task is complete when:

```text
- Ledger records every conversion owner.
- Existing diagnostics/status can show failures.
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
Orbisonic status: completed Task 015; ready for Task 016: Reference Fixture Harness.
```
