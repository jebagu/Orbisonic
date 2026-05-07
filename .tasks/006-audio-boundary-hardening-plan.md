# 006: Audio Boundary Hardening Plan

Status: Skipped / superseded

## Goal

Produce a code-hardening plan based on docs, audits, and test gaps without changing production code.

## Background

After the plan audit and initial test passes, the next step is to choose the safest hardening order for live loopback diagnostics, source isolation, and renderer/monitor boundaries. This task turns evidence into a bounded plan before touching production audio code.

## Relevant Docs To Read

- `AGENTS.md`
- `docs/status.md`
- `docs/audits/0001-plan-audit.md`
- `docs/audits/0002-contract-test-gap-audit.md`
- `docs/contracts.md`
- `docs/system-flows.md`
- `docs/implementation-map.md`
- `docs/test-strategy.md`
- Relevant `docs/decisions/`
- Relevant source and test files for live loopback, source isolation, renderer, monitor, diagnostics, and metering.

## Scope

- Produce a hardening plan under `docs/audits/` or `docs/`.
- Order code-affecting work by safety, dependency, and test readiness.
- Identify required tests before each production change.
- Identify hardware-only verification steps for each hardening area.
- Update `docs/status.md`.

## Out Of Scope

- Production code changes.
- Test changes.
- Behavior changes.
- Major dependencies.
- Rewriting the audio engine or renderer.

## Contract References

- `docs/contracts.md` sections `OrbisonicEngine`, `LiveAudioBridge`, `Roon Integration Boundary`, `Spotify Integration Boundary`, `Aux Source Boundary`, `Renderer And Sonic Sphere Output Boundary`, `Headphone Or Normal Monitor Boundary`, and `Diagnostics And Logging Boundary`.
- `docs/decisions/0004-selected-source-only-rule.md`.
- `docs/decisions/0005-sonic-sphere-30-1-primary-output.md`.
- `docs/decisions/0007-roon-loopback-boundary.md`.

## Original Expected Files

- `docs/audits/0003-audio-boundary-hardening-plan.md`
- `docs/status.md`

This task was superseded before `docs/audits/0003-audio-boundary-hardening-plan.md` was created. Current readiness state is recorded in `docs/readiness-summary.md`.

## Acceptance Criteria

- Plan separates live loopback diagnostics, source isolation, renderer/monitor hardening, and release verification work.
- Plan identifies tests that must exist before production changes.
- Plan states manual verification gaps without treating them as automated acceptance.
- No source or test files change.

## Verification Commands

```sh
git diff --name-only -- README.md Package.swift Sources Tests scripts installer Vendor calibration
git diff --check
```

## Stopping Conditions

- The plan requires a contract change before it can be written.
- Source inspection contradicts an accepted contract.
- A hardening step would mask live audio failures instead of diagnosing them.
- Hardware access is required to decide task ordering.

## Required Final Summary

Use the standard summary format from `AGENTS.md` and include the recommended hardening order and any blocked decisions.

## Supersession Notes

- The prompt sequence did not include a separate execution prompt for this planning task before Prompt 15.
- The hardening sequence proceeded directly through Prompt 15 live loopback diagnostics, Prompt 16 source isolation, and Prompt 17 renderer/monitor boundary hardening.
- Those prompts added the tests and bounded source changes that this plan would have ordered: live loopback diagnostics first, selected-source isolation second, renderer/monitor boundary third, release verification docs fourth.
- `docs/readiness-summary.md` now records the actual hardening order, automated evidence, remaining manual verification, and release blockers.
- Do not backfill this as a pre-implementation plan unless a future maintenance task explicitly wants retrospective planning evidence.
