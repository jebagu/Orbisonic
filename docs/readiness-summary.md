# Orbisonic Readiness Summary

## Scope

This summary records the state after the project control retrofit, contract-test audit, focused hardening work, and release-verification documentation pass. It is a current-state document for maintainers and future Codex sessions, not a claim that installer or hardware release checks have been completed.

## Readiness Result

Current result: partial manual release verification is complete for automated tests, prior app bundle/package inspection, installed input-driver visibility, Roon bridge dependency install, loopback input visibility, bounded silent-capture access checks, and local prerequisite checks. Historical 1.1 app-only and suite installer execution passed on 2026-05-05, but packages have not yet been rebuilt and installed from the canonical merged repo.

Orbisonic is not yet release-verified for a new public release because current package artifacts must be rebuilt from the merged canonical repo, signed/notarized if distribution requires it, installer-executed, and verified with real Roon / Aux / Spotify positive-audio loopback capture, Sonic Sphere / Dante channel walk, monitor listening, microphone permission prompts, and entitlement-gated Apple spatial behavior in the target macOS environment.

## Completed Retrofit Work

- Project-control docs now cover status, product scope, architecture, contracts, system flows, implementation map, test strategy, release verification, readiness, audits, decisions, and task tracking.
- Repo-level `AGENTS.md` now defines active-product scope, privacy rules, LaunchServices app verification, docs/test requirements, hardware honesty, and prompt-sequence final reporting.
- Accepted ADRs record the retrofit-not-rewrite baseline, SwiftPM target boundaries, `AudioContracts` shared language, selected-source-only behavior, Sonic Sphere 30.1 production output, embedded librespot boundary, and Roon loopback boundary.
- The plan audit and contract-test gap audit are complete.
- The README setup mismatch around `Orbisonic Spotify Input` is fixed.
- The standalone audio-boundary hardening plan task was superseded by the actual Prompt 15 through Prompt 17 hardening sequence and is recorded as skipped rather than still pending.

## Completed Hardening Work

- Selected Roon, Spotify, and Aux no-signal web/control-state coverage was added.
- Static architecture boundary tests now protect SwiftPM dependency direction, lower-target runtime leakage, source-integration renderer ownership, and monitor/production topology separation.
- Live loopback diagnostics now expose route, sample-rate, channel-count, permission, signal, buffer, and player/source activity facts as separate diagnostic summaries.
- Source isolation now clears stale local playback snapshots when switching to Off or Test Tone and keeps Spotify health inside the fixed stereo boundary.
- Renderer/monitor boundary hardening now covers normal-monitor route selection across all renderer modes, including Direct 30 and Direct 30.1, and verifies monitor planning does not mutate the Sonic Sphere 30.1 scene topology.
- Release verification is mapped in `docs/release-verification.md`.

## Automated Checks Run During Retrofit

Focused and full SwiftPM test commands were run during the code-affecting prompts:

- Prompt 13: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter OrbisonicWebStateTests`
- Prompt 13: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- Prompt 14: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter PureAudioArchitectureBoundaryTests`
- Prompt 14: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- Prompt 15: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter LoopbackSourceSupportTests`
- Prompt 15: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- Prompt 16: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter OrbisonicWebStateTests`
- Prompt 16: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- Prompt 17: focused renderer/monitor tests plus `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`

App bundle refresh was run after source changes in Prompts 15, 16, and 17. LaunchServices reopen was run after Prompt 16.

Prompt 19 was docs-only. Task 012 reran the full suite: 544 tests, 0 failures.

The current release-gate slice on 2026-05-10 reran the full suite: 648 tests, 0 failures.

## Manual Checks Run

Partial manual release verification was run on 2026-05-05:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` passed with 544 tests and 0 failures.
- `scripts/refresh-orbisonic-app.sh` passed. The app bundle was rebuilt, ad hoc signed, codesign verification passed, and `Info.plist` lint passed.
- `scripts/reopen-orbisonic-app.sh` passed and the app opened through LaunchServices.
- Computer Use confirmed the `Orbisonic` app window is open.
- `Orbisonic.app` is bundle identifier `audio.orbisonic.app`, version `1.1`, arm64, branch `main`, and stamped with a dirty working-tree suffix.
- The app-only installer initially failed from the project-folder path under administrator authorization, then passed when copied to `/private/tmp`.
- The suite installer passed from `/private/tmp`.
- The installed `/Applications/Orbisonic.app` verifies with codesign, has a valid `Info.plist`, is version `1.1`, has bundle identifier `audio.orbisonic.app`, is arm64, and launches through LaunchServices.
- The installed `/Applications/Orbisonic.app` is stamped `main` commit `8ffa977`, while the tested working tree is `64f7fea` plus uncommitted changes. Rebuild installers before claiming the packages represent the currently tested working tree.
- The app bundle contains `NSMicrophoneUsageDescription`; ad hoc codesign verification passes; entitlement output is empty.
- App-only package payload inspection passed for `Orbisonic.app`, resources, Roon bridge files, and bundled `ffmpeg` / `ffprobe`.
- Suite package payload inspection passed for the app component and input-driver component. The suite payload contains `Orbisonic Roon Input`, `Orbisonic Aux Cable`, and `Orbisonic Spotify Input` driver bundles at version `0.2.0`.
- `pkgutil --check-signature` reports `Status: no signature` for both current package files.
- Installed system HAL driver bundles report `CFBundleShortVersionString` `0.2.0`, verify with codesign, and AVFoundation sees `Orbisonic Roon Input`, `Orbisonic Aux Cable`, and `Orbisonic Spotify Input`.
- Roon bridge dependency installation passed and installed app-managed support files plus `node_modules`.
- The embedded librespot static library exists at the expected SwiftPM link artifact path.
- Dante Virtual Soundcard daemon is running.
- Roon was not running beyond the Orbisonic input driver. Spotify was running, but Spotify Connect routing to Orbisonic and capture into `Orbisonic Spotify Input` were not tested.

Imported candidate artifact and route checks were run on 2026-05-10 before the canonical directory merge:

- The imported app-source branch rebuilt and inspected app and suite package candidates.
- The imported app payload was stamped from a dirty working tree.
- `pkgutil --check-signature` reported `Status: no signature` for both imported package files.
- Dante Virtual Soundcard remains installed and running; Dante Controller is still not installed.
- AVFoundation sees `Orbisonic Roon Input`, `Orbisonic Aux Cable`, and `Orbisonic Spotify Input`.
- Bounded captures could open all three inputs, but all measured silence; this is route and permission/access evidence only, not live-source audio success.
- The Roon bridge is paired to a Roon Core and sees an `Orbisonic` zone in stopped state.

Imported installer and signing gates were attempted on 2026-05-10:

- The imported app and suite packages were copied to `/private/tmp`.
- CLI app-only installation was blocked because non-interactive `sudo installer` requires a password.
- The installed `/Applications/Orbisonic.app` still verifies with codesign and has a valid `Info.plist`, but it remains version `1.1` stamped `8ffa977`.
- Installed package receipts still report `audio.orbisonic.app.pkg` version `1.1` and `audio.orbisonic.inputs.pkg` version `0.2.0`.
- The local keychain has `0 valid identities found` for both codesigning and basic identity searches.
- `productsign` cannot sign with `Developer ID Installer` because no matching identity is available.
- `xcrun notarytool history` reports that credentials must be provided or stored before notarization can run.

## Manual Checks Still Required Before Release

Follow `docs/release-verification.md` and record pass, fail, or not tested for:

- rebuild current app-only and suite packages from the canonical merged repo.
- provide admin authentication or run the rebuilt package installers manually, then verify installed app/package receipts.
- install or configure Developer ID signing identities for package signing.
- configure notarization credentials for `notarytool`, if public distribution requires notarization.
- Roon extension authorization, metadata, and transport controls against a running Roon environment.
- Roon loopback capture from `Orbisonic Roon Input`.
- Aux loopback capture from `Orbisonic Aux Cable`.
- Spotify Connect receiver status and stereo capture from `Orbisonic Spotify Input`.
- Output 1 Monitor listening and route behavior.
- Output 2 Main Renderer route behavior.
- Sonic Sphere / Dante channel walk, physical speaker order, LFE behavior, and channel 32 behavior where relevant.
- macOS microphone permission behavior for loopback capture.
- signing, `Info.plist`, and entitlement status, especially for Apple spatial/head-tracking features.

## Known Risks

- A player or bridge can report activity while loopback capture is silent; captured signal and route facts remain authoritative.
- Physical Sonic Sphere / Dante output cannot be inferred from tests or VU meters.
- Installer path/access behavior can differ under administrator authorization; installing from `/private/tmp` worked in this pass.
- Current package files have not yet been rebuilt from the canonical merged repo.
- The installed `/Applications/Orbisonic.app` was not replaced by an imported package during the 2026-05-10 pass.
- CLI installer execution is blocked in the current non-interactive shell because `sudo` requires a password.
- Developer ID signing and notarization are blocked because no local signing identity or notarytool credentials are configured.
- Spotify Connect readiness is session-dependent and currently stereo by contract.
- Roon log parsing is useful context but not proof of audio capture.
- Apple spatial/head-tracking behavior depends on runtime route support and signing entitlements.
- Historical `docs/PureAudio/` files remain migration evidence unless a current contract, flow, or ADR elevates a claim.
- The app target still owns substantial runtime audio behavior while `AudioCore` owns deterministic planning and offline processing; boundary tests should stay current as extraction work continues.

## Release Blockers

- Manual release verification is only partially complete.
- Current package artifacts must be rebuilt from the canonical merged repo.
- Current package signing/notarization is blocked on missing signing identity and notarization credentials.
- Current installer execution has not been run.
- Current CLI installer execution requires administrator authentication.
- The refreshed app bundle must be rebuilt after the merge is committed.
- Roon, Aux, Spotify Connect, monitor listening, Sonic Sphere / Dante, microphone permission prompt, and entitlement-gated Apple spatial behavior remain unverified.
- No reference Sonic Sphere / Dante hardware setup has been recorded as the release-verification environment.
- App-only versus suite-installer release-readiness criteria are still an open product decision.
- Spotify transport-control stability expectations remain an open product decision.

## Current Test Status

The imported app-source branch passed the full SwiftPM suite on 2026-05-10 with 648 tests and 0 failures. The canonical merged repo needs a fresh full-suite run and app refresh.

## Recommended Next Action

Run canonical full-suite verification and app refresh, then rebuild current installer artifacts with administrator-authenticated installer execution. Configure Developer ID signing and notarization credentials if this is intended for public distribution, then run live-source and hardware verification in the real macOS, loopback, Roon, Spotify, monitor, Sonic Sphere, and Dante environment.
