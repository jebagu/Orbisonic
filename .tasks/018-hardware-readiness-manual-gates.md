# Task 018: Hardware Readiness And Manual Gates

## Status

completed

## Goal

Create and run manual gate checklist for Dante, SonicSphere, Roon, Spotify, and installer behavior.

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
- Update release/manual verification docs.
- Add Dante Controller checks.
- Add physical channel-walk checklist.
- Add route and permission checklist.
```

## Out Of Scope

Do not:

```text
- Do not mark untested hardware as verified.
- Do not change UI.
```

## Acceptance Criteria

This task is complete when:

```text
- Manual gates are explicit.
- Unknown hardware behavior is not claimed.
- Status docs record results or blockers.
```

## Completion Notes

```text
- Added explicit manual gates for Dante Controller, physical channel walk, route and permission checks, Roon, Spotify, installer, and signing.
- Recorded the current 2026-05-09 machine-readable gate results.
- Verified Dante Virtual Soundcard is installed and its launch daemon is running.
- Recorded Dante Controller as blocked because it is not installed in /Applications.
- Left physical SonicSphere/Dante channel walk, real Roon/Spotify/Aux capture, permission prompt, installer execution, and release signing as NOT RUN.
- No UI changes were made.
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
Orbisonic status: completed Task 018; ready for Task 019: Release Gate And Default Switch Review.
```
