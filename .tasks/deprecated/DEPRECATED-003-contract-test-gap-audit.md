# DEPRECATED

Deprecated historical Orbisonic task material from the former split workspace. Retained for reference only; do not treat it as active instructions.

# 003: Contract Test Gap Audit

Status: Complete

## Goal

Find claims in `docs/contracts.md`, `docs/system-flows.md`, `docs/test-strategy.md`, and product/setup docs that are not protected by automated tests or explicitly marked as manual verification.

## Background

The retrofit should harden the current app through tests before production changes. This audit identifies the highest-value missing contract coverage across source isolation, live loopback diagnostics, renderer topology, monitor isolation, module boundaries, installer behavior, and hardware-only verification.

## Relevant Docs To Read

- `AGENTS.md`
- `docs/status.md`
- `docs/contracts.md`
- `docs/system-flows.md`
- `docs/implementation-map.md`
- `docs/test-strategy.md`
- `README.md`
- `docs/product-brief.md`
- `docs/decisions/`
- `.tasks/004-contract-test-gap-pass.md`
- `Package.swift`
- `Tests/`
- Relevant `Sources/` files for claims being audited.

## Scope

- Produce a contract-test gap audit under `docs/audits/`.
- Map each uncovered claim to an existing test target or proposed test target.
- Include product/setup claims from README and product docs when they affect live inputs, source names, installer expectations, supported routes, or operator setup.
- Separate automated-test gaps from manual hardware verification gaps.
- Rank test gaps by audio risk and implementation cost.

## Out Of Scope

- Adding tests.
- Changing source code.
- Changing production behavior.
- Fixing docs unless the fix is limited to `docs/status.md`.

## Contract References

- All sections in `docs/contracts.md`.
- `docs/test-strategy.md` sections `Contract-To-Test Map`, `Critical Audio Invariants`, `Known Test Gaps`, and `Coverage Expectations`.
- `docs/decisions/0004-selected-source-only-rule.md`.
- `docs/decisions/0005-sonic-sphere-30-1-primary-output.md`.
- `docs/decisions/0007-roon-loopback-boundary.md`.

## Expected Files

- `docs/audits/0002-contract-test-gap-audit.md`
- `docs/status.md`

## Acceptance Criteria

- Audit lists contract claims, current test evidence, gap severity, and proposed test files.
- Audit includes relevant product/setup claims, not only module contracts.
- Hardware-only gaps are clearly marked as manual verification, not missing unit tests.
- Highest-priority gaps are suitable inputs for Task 004.
- No source or test files change.

## Verification Commands

```sh
find Tests -maxdepth 2 -type f | sort
rg -n "func test" Tests/AudioContractsTests Tests/AudioImportTests Tests/AudioCoreTests Tests/OrbisonicTests
git diff --name-only -- README.md Package.swift Sources Tests scripts installer Vendor calibration
git diff --check
```

## Stopping Conditions

- A contract claim appears false relative to current source.
- A gap cannot be classified without hardware or service access.
- The audit discovers a critical production-risk issue that should pause further planning.
- Source or test edits would be required to finish the audit.

## Required Final Summary

Use the standard summary format from `AGENTS.md` and include the top test gaps, manual-only gaps, and recommended first test pass.

## Completion Notes

- Completed by `docs/audits/0002-contract-test-gap-audit.md`.
- Identified selected live-source no-signal diagnostics as the highest-value automated test gap.
- Separated manual-only gaps for Sonic Sphere / Dante, real Roon loopback, real Spotify Connect, real Aux capture, microphone permission, signing/entitlements, installer behavior, and Roon bridge authorization.
- Carried the README `Orbisonic Spotify Input` setup mismatch forward until it was fixed by the release-verification docs pass.
- No source or test files were changed by the audit task.
