# 010: Installer And Release Verification Docs

Status: Complete

## Goal

Create or update release verification documentation for app bundle, installer, LaunchServices, loopback devices, Roon, Aux, Spotify, monitor, and Sonic Sphere / Dante workflows.

## Background

Installer and hardware behavior cannot be fully proved by unit tests. The retrofit needs a concrete release verification document that records which checks are automated, which are manual, and what evidence must be captured before a release is called ready.

## Relevant Docs To Read

- `AGENTS.md`
- `README.md`
- `RELEASE_NOTES.md`
- `Package.swift`
- `docs/status.md`
- `docs/product-brief.md`
- `docs/architecture.md`
- `docs/contracts.md`
- `docs/system-flows.md`
- `docs/implementation-map.md`
- `docs/test-strategy.md`
- `scripts/refresh-orbisonic-app.sh`
- `scripts/reopen-orbisonic-app.sh`
- `scripts/build-installer.sh`
- `scripts/install-roon-bridge.sh`
- `scripts/build-embedded-librespot.sh`
- `installer/`

## Scope

- Create `docs/release-verification.md`.
- Document app-only and suite-installer checks.
- Document LaunchServices reopen rules.
- Document manual Sonic Sphere / Dante, loopback, Roon, Aux, Spotify, microphone permission, signing, entitlement, and installer checks.
- Update `docs/status.md`.
- Modify scripts only if explicitly necessary, low risk, and directly required by the verification doc.

## Out Of Scope

- Production code changes.
- Test changes unless script behavior is explicitly changed.
- Installer rebuilds unless explicitly requested.
- Hardware verification unless the hardware is available and the user asks to perform it.
- Major packaging redesign.

## Contract References

- `docs/contracts.md` section `Installer And App Bundle Scripts Boundary`.
- `docs/test-strategy.md` sections `Required Checks`, `Manual Verification Requirements`, and `Known Test Gaps`.
- `AGENTS.md` sections `Testing Requirements` and `Local Hosting`.

## Expected Files

- `docs/release-verification.md`
- `docs/status.md`
- `README.md` only if release instructions need a narrow doc correction
- `RELEASE_NOTES.md` only if release verification references are missing and a narrow doc correction is needed
- `scripts/refresh-orbisonic-app.sh`, `scripts/reopen-orbisonic-app.sh`, or `scripts/build-installer.sh` only if explicitly necessary

## Acceptance Criteria

- Release verification doc separates automated checks from manual checks.
- Manual checks specify what route, source, device, app bundle, installer, and observed evidence must be recorded.
- App bundle refresh and LaunchServices reopen paths are explicit.
- Hardware-only gaps are not represented as automated pass criteria.
- No production code changes occur.

## Verification Commands

```sh
git diff --name-only -- Sources Tests Vendor calibration
git diff --name-only -- scripts installer Package.swift README.md RELEASE_NOTES.md
git diff --check
```

If scripts change, also run the narrowest safe script verification and document whether installer rebuilds were skipped. If scripts do not change, the second command should either be empty or list only intentional doc/package metadata edits from this task.

## Stopping Conditions

- Verification requires hardware or admin actions that the user has not requested.
- A script change is not low risk or requires broad packaging redesign.
- Release docs reveal a contract conflict that should be resolved before release readiness.
- The task would require committing runtime logs, tokens, local paths, or private device facts.

## Required Final Summary

Use the standard summary format from `AGENTS.md` and include release docs created, script changes if any, and manual verification still required.

## Completion Notes

- Created `docs/release-verification.md` with automated repository checks and manual release checks for app bundle refresh, LaunchServices reopen, app-only installer, suite installer, Roon bridge, Roon loopback, Aux loopback, Spotify receiver, Sonic Sphere / Dante, monitor output, microphone permission, signing, entitlements, logs, smoke testing, hardware requirements, and limitations.
- Documented package-inspection expectations for `installer/Orbisonic-1.1.pkg` and `installer/OrbisonicSuite-1.1.pkg`, including the app component and the Roon, Aux, and Spotify HAL driver component identifiers.
- Updated README setup wording so the live-capture input list includes `Orbisonic Spotify Input`.
- Updated `docs/status.md`, `docs/implementation-map.md`, and `docs/test-strategy.md` so release verification is part of the project-control map.
- No production source, test, script, installer, vendor, resource, or calibration files were intentionally changed for this task.
- Installer execution, LaunchServices runtime launch, Roon bridge authorization, loopback capture, Spotify Connect, Sonic Sphere / Dante, microphone permission, and signing checks remain manual release evidence.
