# Task 012: CoreAudio Dante Session

## Status

complete

## Goal

Implement DVS/CoreAudio production session integration behind strict contracts.

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
- Query CoreAudio ASBD and route facts.
- Validate against DanteTargetProfile.
- Log host format versus target Dante profile.
- Add simulated tests and manual gate docs.
```

## Out Of Scope

Do not:

```text
- Do not assume CoreAudio Float32 means Dante network float.
- Do not silently route to stereo.
- Do not add UI workflows.
```

## Acceptance Criteria

This task is complete when:

```text
- Actual route facts are logged.
- Production refuses invalid route.
- Manual Dante verification checklist is updated.
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
Orbisonic status: completed Task 012; ready for Task 013: Pure Spherical Lossless Validator And Badge.
```
