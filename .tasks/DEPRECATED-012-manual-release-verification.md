# DEPRECATED

This file is deprecated legacy Orbisonic instruction material copied into the Orbisonic 2.0 workspace. Use `project-control/` at the Orbisonic 2.0 root for current instructions. Retained for reference only.

# 012: Manual Release Verification

Status: Partial / blocked by admin, hardware, and service checks

## Goal

Run and record the manual release-verification checklist for the current Orbisonic app bundle and installer artifacts.

## Background

The retrofit sequence is documented and the automated SwiftPM checks have passed in prior hardening prompts, but release readiness still depends on environment-specific checks that cannot be proved by docs or unit tests.

## Relevant Docs To Read

- `AGENTS.md`
- `README.md`
- `RELEASE_NOTES.md`
- `docs/status.md`
- `docs/readiness-summary.md`
- `docs/release-verification.md`
- `docs/test-strategy.md`
- `scripts/refresh-orbisonic-app.sh`
- `scripts/reopen-orbisonic-app.sh`
- `installer/`

## Scope

- Run or explicitly mark not tested the manual checks in `docs/release-verification.md`.
- Record evidence for app bundle refresh, LaunchServices reopen, app-only installer, suite installer, loopback driver visibility, Roon bridge, Roon loopback, Aux loopback, Spotify receiver, monitor output, Sonic Sphere / Dante output, microphone permission, signing, and entitlements.
- Update `docs/status.md` and `docs/readiness-summary.md` with the actual release-readiness result.

## Out Of Scope

- Production code changes.
- Test changes unless manual verification exposes a reproducible code defect and the user explicitly approves a fix.
- Installer rebuilds unless the user explicitly wants a new package.
- Committing private logs, private media, credentials, tokens, local usernames, or machine-specific absolute paths.

## Acceptance Criteria

- Each manual checklist item is marked pass, fail, or not tested.
- Release blockers are explicit.
- Hardware-only gaps are not represented as automated passes.
- Any failure includes enough route, device, sample-rate, channel-count, log, or command evidence to reproduce the problem without committing private data.

## Verification Commands

Use `docs/release-verification.md` as the command checklist. At minimum, before runtime checks:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
./scripts/refresh-orbisonic-app.sh
./scripts/reopen-orbisonic-app.sh
```

Run installer commands only when the user approves admin/system audio changes.

## Stopping Conditions

- A manual check requires hardware, admin privileges, or external-service authorization that is unavailable.
- A failed check indicates a public contract may be wrong.
- A fix would require production code changes outside this task.
- Evidence would require committing private runtime data.

## Required Final Summary

Use the standard summary format from `AGENTS.md` and include manual checks passed, manual checks failed, manual checks not tested, release blockers, and recommended next action.

## Verification Notes

- Full SwiftPM verification passed: 544 tests, 0 failures.
- `scripts/refresh-orbisonic-app.sh` passed: build completed, `Orbisonic.app` was refreshed, ad hoc codesign verification passed, and `Info.plist` lint passed.
- `scripts/reopen-orbisonic-app.sh` passed and Orbisonic opened through LaunchServices.
- Computer Use confirmed the `Orbisonic` window is open from `audio.orbisonic.app`.
- App-only package payload inspection passed for `Orbisonic.app`, app resources, Roon bridge resources, and bundled `ffmpeg` / `ffprobe`.
- Suite package payload inspection passed for `Orbisonic-1.1.pkg`, `OrbisonicInputsComponent-0.2.0.pkg`, and all three input driver bundle identifiers.
- Both current package files report `Status: no signature` from `pkgutil --check-signature`.
- The repo-root app bundle is version `1.1`, bundle identifier `audio.orbisonic.app`, arm64, branch `main`, and stamped with a dirty working-tree suffix.
- The app-only installer initially failed from the project-folder path under administrator authorization. Copying `Orbisonic-1.1.pkg` to `/private/tmp` and installing from there passed.
- The suite installer passed from `/private/tmp`.
- The installed `/Applications/Orbisonic.app` verifies with codesign, has a valid `Info.plist`, is version `1.1`, has bundle identifier `audio.orbisonic.app`, is arm64, and launches through LaunchServices.
- The installed `/Applications/Orbisonic.app` is stamped `main` commit `8ffa977`, while the tested working tree is `64f7fea` plus uncommitted changes. Rebuild installers before claiming the packages represent the currently tested working tree.
- The app bundle has `NSMicrophoneUsageDescription` and ad hoc signature verification passes. Entitlement output is empty, so Apple spatial/head-tracking entitlement behavior is not verified.
- The suite package payload contains input drivers with `CFBundleShortVersionString` `0.2.0`.
- The installed system HAL drivers are visible at `/Library/Audio/Plug-Ins/HAL/`, report `CFBundleShortVersionString` `0.2.0`, and verify with codesign after the suite install.
- AVFoundation sees `Orbisonic Roon Input`, `Orbisonic Aux Cable`, and `Orbisonic Spotify Input`.
- Roon bridge dependency installation passed and the app-managed support folder contains `bridge.js`, `package.json`, lockfile, `node_modules`, and local config.
- Embedded librespot static library exists at the expected SwiftPM link artifact path.
- Dante Virtual Soundcard daemon is running.
- Roon was not running beyond the Orbisonic input driver. Spotify was running, but Spotify Connect routing to Orbisonic and capture into `Orbisonic Spotify Input` were not tested. Dante Virtual Soundcard daemon was running, but Sonic Sphere / Dante channel walk was not tested.
- Roon, Spotify, Aux live capture, monitor listening, Sonic Sphere / Dante channel walk, microphone permission prompts, and entitlement-gated Apple spatial behavior were not tested in this pass.
