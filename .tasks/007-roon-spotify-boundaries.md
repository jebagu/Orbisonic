# Task 007: Roon And Spotify Boundaries

## Status

complete

## Goal

Implement explicit Roon live PCM and Spotify stereo source boundaries.

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
- Add or adapt Roon live PCM capture contract.
- Add Spotify stereo source contract.
- Add tests for Roon stereo, Roon 5.1 detection, and Spotify stereo.
```

## Out Of Scope

Do not:

```text
- Do not decode Roon files.
- Do not insert VLC into Roon by default.
- Do not secretly downmix Roon 5.1.
```

## Acceptance Criteria

This task is complete when:

```text
- Roon 5.1 monitor downmix is blocked unless explicit owner exists.
- Spotify reports stereo.
- No stale metadata crosses source modes.
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
Orbisonic status: completed Task 007; ready for Task 008: Source Rate Converter.
```
