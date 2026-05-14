# Task 010: Dante Output Formatter

## Status

complete

## Goal

Implement Dante output formatting, headroom, true-peak, dither, quantization, and channel packing.

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
- Add DanteTargetProfile.
- Add DanteOutputFormatter.
- Add final-stage dither for fixed output.
- Add true-peak/headroom guard.
- Add channel map tests.
```

## Out Of Scope

Do not:

```text
- Do not select hardware route.
- Do not render SonicSphere.
- Do not downmix.
```

## Acceptance Criteria

This task is complete when:

```text
- Float to 24-bit PCM uses final TPDF dither.
- Float host output does not dither.
- True peak is measured.
- Channel order and reserved silence are tested.
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
Orbisonic status: completed Task 010; ready for Task 011: Production Output Session Fake Backend.
```
