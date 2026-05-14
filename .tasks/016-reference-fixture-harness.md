# Task 016: Reference Fixture Harness

## Status

completed

## Completion Notes

```text
Implemented a test-only reference fixture harness in AudioCoreTests.
Generated deterministic in-memory stereo, 5.1, 7.1, Direct 30, and 52-channel fixtures.
Compared stable hashes, peak/RMS, first non-zero frames, and channel identity.
Verified downmix, truncation, and channel-swap mutations are detected.
Added explicit ffmpeg skip behavior for external-tool fixture generation.
Confirmed metric summaries do not expose private paths.
```

## Goal

Build generated fixture and objective comparison harness.

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
- Generate deterministic stereo, 5.1, 7.1, Direct 30, and high-channel fixtures when tooling allows.
- Compare hashes, peak/RMS, first non-zero frames, and channel identity.
- Skip external-tool tests explicitly when unavailable.
```

## Out Of Scope

Do not:

```text
- Do not commit private media.
- Do not add large binary fixtures by default.
```

## Acceptance Criteria

This task is complete when:

```text
- Fixtures are deterministic.
- Channel identity tests catch downmix/truncation/swap.
- No private paths are logged.
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
Orbisonic status: completed Task 016; ready for Task 017: Optional VLC Live PCM Downmix Prototype.
```
