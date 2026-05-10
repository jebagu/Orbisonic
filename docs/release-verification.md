# Orbisonic Release Verification

## Purpose

This document defines the release and installer checks for Orbisonic. It separates automated repository checks from manual runtime checks that require macOS app launch, loopback devices, Roon, Spotify, Aux audio, Sonic Sphere, Dante, headphones, microphone permission, signing, or installer actions.

Use this document before calling an app bundle or installer release-ready. Do not treat a unit-test pass as proof that hardware, route, service, or installer behavior was verified.

## Release Artifacts

Current release-facing artifacts in this repository:

- `Orbisonic.app`: repo-root development app bundle.
- `installer/Orbisonic-2.0.pkg`: current app-only 2.0 installer candidate. It installs `Orbisonic.app` into `/Applications`.
- `installer/OrbisonicSuite-2.0.pkg`: current 2.0 suite installer candidate. It contains the app package plus `OrbisonicInputsComponent-0.2.0.pkg`.
- `installer/Orbisonic-1.1.pkg` and `installer/OrbisonicSuite-1.1.pkg`: historical 1.1 artifacts. Do not use them as the current 2.0 candidate.
- `scripts/refresh-orbisonic-app.sh`: canonical build, bundle refresh, metadata stamp, ad hoc signing, codesign verify, and plist lint path.
- `scripts/reopen-orbisonic-app.sh`: canonical LaunchServices quit and reopen path.
- `scripts/build-installer.sh`: app-only package build path.
- `scripts/build-suite-installer.sh`: suite package assembly path. It combines the current app package with the existing input-driver component.
- `scripts/install-roon-bridge.sh`: optional Roon bridge dependency install path.
- `scripts/build-embedded-librespot.sh`: embedded Spotify receiver static-library build path.
- `Orbisonic.entitlements`: entitlement template for Xcode signing when Apple spatial/head-tracking features are being verified.

The suite installer payload should be verified as containing:

- `Orbisonic-2.0.pkg` with `/Applications/Orbisonic.app`
- `OrbisonicInputsComponent-0.2.0.pkg` with:
  - `/Library/Audio/Plug-Ins/HAL/OrbisonicRoonInput.driver`
  - `/Library/Audio/Plug-Ins/HAL/OrbisonicAuxCable.driver`
  - `/Library/Audio/Plug-Ins/HAL/OrbisonicSpotifyInput.driver`

## Automated Repository Checks

Run these before release documentation or source changes are accepted:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
git diff --name-only -- AGENTS.md README.md Package.swift Sources Tests scripts installer Vendor calibration
```

For docs-only changes, the Swift test suite is not required unless source, tests, scripts, installer files, vendor files, resources, or calibration files changed by mistake.

If app code changed, refresh the app bundle:

```sh
./scripts/refresh-orbisonic-app.sh
```

Expected refresh evidence:

- Swift build completes.
- `Orbisonic.app/Contents/MacOS/Orbisonic` is replaced.
- resource bundle is copied when present.
- git ref metadata is written into `Info.plist`.
- `codesign --verify --deep --strict --verbose=2` succeeds.
- `plutil -lint Orbisonic.app/Contents/Info.plist` reports OK.

If GUI or audio behavior changed and runtime verification is being performed, reopen through LaunchServices:

```sh
./scripts/reopen-orbisonic-app.sh
```

Expected reopen evidence:

- any running `Orbisonic` process exits.
- `open Orbisonic.app` launches the app bundle.
- the app opens without using `Orbisonic.app/Contents/MacOS/Orbisonic` directly.

## Package Inspection

Inspect the app-only package payload:

```sh
pkgutil --payload-files installer/Orbisonic-2.0.pkg
```

Expected app-only package evidence:

- `/Applications/Orbisonic.app`
- `Orbisonic.app/Contents/MacOS/Orbisonic`
- app resources, including the SwiftPM resource bundle
- bundled `ffmpeg` and `ffprobe` tools when present in the package

Inspect the suite package by expanding it into a temporary directory:

```sh
tmpdir="$(mktemp -d)"
pkgutil --expand-full installer/OrbisonicSuite-2.0.pkg "$tmpdir/pkg"
find "$tmpdir/pkg" -maxdepth 5 -name PackageInfo -print
```

Expected suite package evidence:

- component package `Orbisonic-2.0.pkg`
- component package `OrbisonicInputsComponent-0.2.0.pkg`
- PackageInfo for `audio.orbisonic.app.pkg`
- PackageInfo for `audio.orbisonic.inputs.pkg`
- bundle identifiers:
  - `audio.orbisonic.app`
  - `audio.orbisonic.rooninput`
  - `audio.orbisonic.auxcable`
  - `audio.orbisonic.spotifyinput`

Do not commit expanded package contents or installer logs.

## Installer Verification

Installer execution requires an admin-capable macOS environment. Do not run installer commands during a docs-only task unless the user explicitly asks for runtime installer verification.

App-only installer manual check:

```sh
sudo installer -pkg installer/Orbisonic-2.0.pkg -target /
```

Record:

- macOS version
- installer package path and version
- whether `/Applications/Orbisonic.app` was installed
- `codesign --verify --deep --strict --verbose=2 /Applications/Orbisonic.app` result
- `plutil -lint /Applications/Orbisonic.app/Contents/Info.plist` result
- LaunchServices open result
- relevant `/var/log/install.log` installer entries, summarized without private data

Suite installer manual check:

```sh
sudo installer -pkg installer/OrbisonicSuite-2.0.pkg -target /
```

Record everything from the app-only installer check plus:

- the three HAL drivers exist under `/Library/Audio/Plug-Ins/HAL/`
- Core Audio sees `Orbisonic Roon Input`
- Core Audio sees `Orbisonic Aux Cable`
- Core Audio sees `Orbisonic Spotify Input`
- whether logout, reboot, or Core Audio restart was required before the devices appeared
- whether macOS microphone permission was prompted when Orbisonic first captured a loopback input

If any driver or app component is missing after the suite install, stop and treat the release as not verified.

## Roon Bridge Verification

Install helper dependencies only when Roon transport verification is part of the release check:

```sh
scripts/install-roon-bridge.sh
```

Record:

- `npm install --omit=dev` success or failure
- whether the support directory contains `bridge.js`, `package.json`, and installed dependencies
- whether Roon shows `Orbisonic Roon Bridge` under Settings > Extensions
- whether the extension is authorized
- whether Orbisonic can read bridge state
- transport control results for play, pause, stop, previous, and next
- whether bridge metadata stays separate from loopback signal truth

Roon bridge verification is not proof of audio capture. It only proves local Roon API helper readiness and transport/metadata behavior.

## Roon Loopback Verification

Manual prerequisites:

- Roon or Roon Server is running.
- The suite installer or separate input driver install has provided `Orbisonic Roon Input`.
- Roon output is routed to `Orbisonic Roon Input`.
- Orbisonic is launched through LaunchServices.

Record:

- selected Orbisonic source is `Roon`
- Roon zone/output name
- Roon output sample rate, if visible
- `Orbisonic Roon Input` nominal sample rate
- selected input route name and channel count
- live meter peak or no-signal state
- underflow and dropped-frame counters
- route mismatch, sample-rate mismatch, channel-count mismatch, or permission warnings
- a short summary of any Roon log signal-path facts used

A Roon log line or Roon bridge playback state is not proof that audio reached the loopback input. Captured signal and route facts are authoritative.

## Aux Loopback Verification

Manual prerequisites:

- `Orbisonic Aux Cable` is installed and visible to Core Audio.
- An external app or system audio source can route audio to `Orbisonic Aux Cable`.
- Orbisonic is launched through LaunchServices.

Record:

- selected Orbisonic source is `Aux Cable`
- external app or system route used
- selected input route name and channel count
- nominal sample rate
- active channels
- live meter peak or no-signal state
- no feedback-loop warning, or the exact warning if one appears
- underflow and dropped-frame counters

Aux should not show Roon or Spotify metadata as the source of truth. Its health is route, capture, and signal based.

## Spotify Receiver Verification

Manual prerequisites:

- embedded librespot static library is present or `scripts/build-embedded-librespot.sh` has been run successfully.
- `Orbisonic Spotify Input` is installed and visible to Core Audio.
- Spotify can see Orbisonic as a Spotify Connect target.
- Orbisonic is launched through LaunchServices.

Record:

- Spotify receiver status in Orbisonic
- selected Orbisonic source is `Spotify`
- Spotify Connect target selected in the Spotify app
- now-playing metadata, if available
- dedicated input route is `Orbisonic Spotify Input`
- source policy remains stereo
- live meter peak or no-signal state
- stale metadata behavior after pause/stop
- control readiness and any control failures

Do not commit Spotify credentials, tokens, caches, or private receiver state. Spotify metadata does not override captured signal truth.

## Sonic Sphere And Dante Verification

Manual prerequisites:

- Sonic Sphere output hardware or Dante Virtual Soundcard route is available.
- Output 2 Main Renderer route is selected intentionally.
- Orbisonic is launched through LaunchServices.
- Test material or diagnostic tones are safe for the connected system.

Record:

- output route name, manufacturer, transport, channel count, and nominal sample rate
- production route is Output 2 Main Renderer, not Output 1 Monitor
- Sonic Sphere 30.1 topology is expected: 30 full-range outputs plus one LFE
- renderer mode used: bed mode, Direct 30, or Direct 30.1
- source channel count and layout
- sample-rate match or mismatch
- channel-walk result for all intended outputs
- physical speaker order
- LFE/sub behavior
- physical channel 32 behavior when a 32-channel Dante route is used
- renderer meter behavior as supplemental evidence only

If physical speakers, Dante routing, or channel order cannot be exercised, record this as not verified. Do not infer it from unit tests or VU activity.

## Dante Controller Gate

Manual prerequisites:

- Dante Controller is installed.
- Dante Virtual Soundcard, Dante Application Library, or an approved Dante endpoint is running.
- the intended Dante transmit and receive devices are visible on the Dante network.
- Orbisonic production output route is selected intentionally.

Record:

- Dante Controller app version
- transmit device name
- receive device name
- route subscriptions for Orbisonic output channels
- sample rate shown in Dante Controller
- encoding bit depth shown in Dante Controller
- clock leader and lock state
- Dante latency setting
- unresolved subscriptions, mute state, or clock warnings
- confirmation that the route in Dante Controller matches the Core Audio route selected in Orbisonic

Pass criteria:

- subscriptions are resolved
- Dante sample rate matches the target profile
- Dante encoding bit depth matches the target profile
- Dante clock is locked
- route latency is recorded
- no unresolved subscriptions or clock warnings remain

Do not treat Core Audio host Float32 exposure as proof of Dante network Float32. Dante Controller or endpoint documentation must provide the network encoding evidence.

## Physical Channel-Walk Gate

Manual prerequisites:

- Sonic Sphere or equivalent physical outputs are connected.
- levels are safe for a channel walk.
- active output map is known.
- Output 2 Main Renderer route is selected intentionally.

Record:

- logical channels walked
- expected speaker ID for each logical channel
- observed physical speaker for each logical channel
- LFE/sub behavior for 30.1 profiles
- adjacent-channel bleed or crosstalk observations
- polarity, trim, or delay anomalies
- reserved physical channel 32 behavior when a 32-channel Dante route is used

Pass criteria:

- every active logical output reaches the expected physical speaker
- reserved/silent outputs stay silent
- no channel swap, truncation, duplication, or hidden downmix is observed

If any physical output cannot be safely exercised, mark that channel as not verified rather than passing the full gate.

## Route And Permission Gate

Manual prerequisites:

- Orbisonic launches through LaunchServices.
- required loopback inputs are installed for the selected source tests.
- monitor and production output routes are visible to Core Audio.

Record:

- Output 1 Monitor route name, UID, manufacturer, transport, channel count, and sample rate
- Output 2 Main Renderer route name, UID, manufacturer, transport, channel count, and sample rate
- whether monitor route changes leave production route selection unchanged
- whether production refuses built-in output, Bluetooth, AirPlay, BlackHole, or unknown stereo routes
- `Orbisonic Roon Input` visibility when Roon is in scope
- `Orbisonic Aux Cable` visibility when Aux is in scope
- `Orbisonic Spotify Input` visibility when Spotify is in scope
- microphone permission prompt state and grant/deny result
- route, sample-rate, channel-count, or permission diagnostics shown by Orbisonic

Pass criteria:

- all required routes are visible
- permissions allow intended live capture
- unsafe production routes are rejected or clearly diagnosed
- monitor and production routes remain independent

## Headphone Or Normal Monitor Verification

Manual prerequisites:

- a monitor output route is selected for Output 1 Monitor.
- source playback is available through Local Files, Roon, Spotify, Aux, or Test Tone.
- Orbisonic is launched through LaunchServices.

Record:

- monitor route name and channel count
- selected source
- monitor output is stereo downmix where expected
- monitor volume behavior
- LFE omitted by default unless an explicit audition policy is selected
- monitor meters versus audible monitor behavior
- confirmation that changing monitor route or monitor volume does not reroute or mutate Output 2 Main Renderer
- any Apple spatial/headphone status shown by Orbisonic

Monitor verification does not prove Sonic Sphere production output. It only verifies the setup/preview path.

## Microphone Permission

macOS labels all input-device capture as microphone access, including virtual loopback inputs. During release verification, record:

- whether the microphone permission prompt appeared
- whether permission was granted
- whether selected loopback capture started after permission
- whether denial produced a visible diagnostic state

The prompt does not mean Orbisonic selected the physical microphone unless the selected input route says so.

## Signing And Entitlements

The repo refresh script signs `Orbisonic.app` ad hoc. Use this to verify local development bundle integrity, but do not treat ad hoc signing as proof of entitlement-gated Apple spatial/head-tracking behavior.

Record:

- `codesign --verify --deep --strict --verbose=2` result
- bundle identifier in `Info.plist`
- `NSMicrophoneUsageDescription` presence
- whether a release build was signed with `Orbisonic.entitlements`
- whether `com.apple.developer.coremotion.head-pose` is present when head tracking is being verified
- whether `com.apple.developer.spatial-audio.profile-access` is present when personalized spatial profile access is being verified

If entitlement signing is unavailable, record Apple spatial/head-tracking behavior as disabled or unverified rather than failed audio playback.

## Logs To Inspect

Use logs as supporting evidence only. Do not commit raw private logs.

- Orbisonic Diagnostics tab and bounded app log view.
- route and live-loopback diagnostics: route name, sample rate, channel count, signal, underflow, dropped frames.
- Roon bridge state and Roon extension authorization status.
- Roon Server signal-path log facts only as metadata context.
- Spotify receiver status and now-playing facts, excluding private tokens or caches.
- installer summaries and relevant `/var/log/install.log` lines.
- codesign and plist command output.

## Manual Smoke-Test Checklist

Before release-ready signoff, record pass/fail/not-tested for:

- app-only installer installs and opens `Orbisonic.app`
- suite installer installs app plus all three loopback inputs
- LaunchServices opens the app bundle
- Local Files playback starts and stops
- Roon source shows route, metadata, and loopback signal or a clear no-signal diagnostic
- Roon bridge can be authorized and transport commands work, when Roon is in scope
- Aux Cable captures external app/system audio or reports a clear no-signal diagnostic
- Spotify Connect sees Orbisonic and `Orbisonic Spotify Input` captures stereo audio or reports a clear no-signal diagnostic
- Output 1 Monitor produces expected stereo monitor audio
- Output 2 Main Renderer is selected intentionally and does not get changed by monitor actions
- Sonic Sphere / Dante channel walk passes, including LFE behavior, when hardware is available
- sample-rate and channel-count mismatches stay visible
- microphone permission path is verified or explicitly not tested
- signing and entitlement status is recorded

## Current Hardware Gate Record

Date: 2026-05-09

Scope: local machine-readable readiness checks plus manual gate documentation. Physical Sonic Sphere/Dante, real Roon, real Spotify, real Aux, installer execution, and release signing were not exercised in this pass.

Commands run:

```sh
ls -ld /Applications/Dante\ Virtual\ Soundcard.app /Applications/Dante\ Controller.app /Library/Audio/Plug-Ins/HAL/DvsAudioPlugIn.driver
launchctl print system/com.audinate.dante.DanteVirtualSoundcard
find /Applications -maxdepth 2 -iname '*Dante*' -print
```

Results:

- Dante Virtual Soundcard app present: PASS.
- DVS HAL driver present: PASS.
- DVS launch daemon running: PASS.
- Dante Controller installed: BLOCKED; `/Applications/Dante Controller.app` was not present and `/Applications` search found only Dante Virtual Soundcard.
- Dante Controller subscriptions, encoding, clock lock, and latency: BLOCKED because Dante Controller is not installed.
- physical Sonic Sphere/Dante channel walk: NOT RUN.
- reserved physical channel 32 silence on hardware: NOT RUN.
- Roon real loopback capture: NOT RUN.
- Spotify real capture: NOT RUN.
- Aux real capture: NOT RUN.
- macOS microphone permission prompt: NOT RUN.
- app-only installer execution: NOT RUN.
- suite installer execution: NOT RUN.
- release code signing/notarization: NOT RUN.

Current release readiness conclusion:

```text
Do not call this build hardware-ready or release-ready from Task 018. DVS is installed and running on this Mac, but Dante Controller/network evidence, physical channel-walk evidence, live-source capture evidence, installer execution, and release signing evidence remain open gates.
```

## Current Default Switch Review

Date: 2026-05-10

Task 019 conclusion:

```text
No new default switches are approved.
The project is ready for implementation milestone review, not release-ready signoff.
Rollback remains available because no source-code defaults changed.
```

Default decisions:

- real libVLC runtime integration is not a release default until packaging, plugin discovery, signing/notarization, and license inventory are solved.
- Roon 5.1 VLC live PCM downmix remains proof-only and explicitly selected.
- DVS/CoreAudio production output remains strict and validation-backed, but not hardware-proven until Dante Controller and physical channel-walk gates pass.
- Pure Spherical Lossless direct playback remains metadata-gated and route-gated.
- current 2.0 installer artifacts are not release-ready from this review because installer execution, package signing, notarization, and hardware/service gates are not proven.

## Current 2.0 Candidate Artifact Record

Date: 2026-05-10

Scope: local package rebuild and machine-verifiable release checks for the current 2.0 candidate. This pass did not run administrator installer execution, public release signing, notarization, monitor listening, positive Roon/Spotify/Aux source-audio playback, or physical Sonic Sphere/Dante channel walk.

Commands run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/orbisonic-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/orbisonic-swift-cache swift test --disable-sandbox
bash -n scripts/refresh-orbisonic-app.sh
bash -n scripts/build-installer.sh
bash -n scripts/build-suite-installer.sh
./scripts/build-installer.sh 2.0
./scripts/build-suite-installer.sh 2.0
pkgutil --expand-full installer/Orbisonic-2.0.pkg /private/tmp/orbisonic-app-2.0-verify
pkgutil --expand-full installer/OrbisonicSuite-2.0.pkg /private/tmp/orbisonic-suite-2.0-verify
pkgutil --payload-files installer/Orbisonic-2.0.pkg
pkgutil --check-signature installer/Orbisonic-2.0.pkg
pkgutil --check-signature installer/OrbisonicSuite-2.0.pkg
shasum -a 256 installer/Orbisonic-2.0.pkg installer/OrbisonicSuite-2.0.pkg
codesign --verify --deep --strict --verbose=2 Orbisonic.app
plutil -lint Orbisonic.app/Contents/Info.plist
```

Results:

- Full SwiftPM suite passed: 648 tests, 0 failures.
- `scripts/refresh-orbisonic-app.sh` and `scripts/build-installer.sh` pass `bash -n`.
- The refresh and installer scripts now default new local artifacts to version `2.0`.
- `installer/Orbisonic-2.0.pkg` was rebuilt from the current dirty working tree.
- `installer/OrbisonicSuite-2.0.pkg` was assembled with `scripts/build-suite-installer.sh 2.0`, combining `Orbisonic-2.0.pkg` plus `OrbisonicInputsComponent-0.2.0.pkg`.
- Expanded app package `PackageInfo` reports `audio.orbisonic.app.pkg` version `2.0`, `CFBundleShortVersionString` `2.0`, and `CFBundleVersion` `2.0`.
- Expanded suite `Distribution` title is `Orbisonic 2.0`, references `Orbisonic-2.0.pkg`, and lists the app bundle as version `2.0`.
- The app package and suite package both contain an app bundle stamped `OrbisonicGitCommit` `a81af94-dirty`.
- App package SHA-256: `9c7a60e350b1464dd5ccd0b7674824ec360316d8f470805580362c282d64927a`.
- Suite package SHA-256: `a1b06e47d31600ea97e683637fa2a804de4ce6aba8b93fec6379f09bd85251d4`.
- `pkgutil --check-signature` reports `Status: no signature` for both 2.0 package files.

Local route and service evidence:

- Dante Virtual Soundcard app present: PASS.
- DVS HAL driver present: PASS.
- DVS launch daemon running: PASS.
- Dante Controller installed: BLOCKED; `/Applications/Dante Controller.app` is not present.
- Installed Orbisonic HAL drivers are present, version `0.2.0`, and codesign verification passes.
- AVFoundation sees `Orbisonic Roon Input`, `Orbisonic Aux Cable`, and `Orbisonic Spotify Input`.
- Bounded captures could open `Orbisonic Roon Input` at 48 kHz 7.1, `Orbisonic Aux Cable` at 48 kHz 64-channel, and `Orbisonic Spotify Input` at 44.1 kHz stereo.
- Those bounded captures measured silence (`Peak level dB: -inf`), so they prove route visibility and capture access only, not source-audio success.
- The Roon bridge HTTP endpoint is paired to Roon Core `2.64 (build 1646) production` and sees an `Orbisonic` zone in `stopped` state.

Current 2.0 release readiness conclusion:

```text
Do not call the 2.0 candidate release-ready yet. The 2.0 app and suite packages now match the current dirty working tree by version and app metadata stamp, but they are unsigned, not notarized, not installer-executed, and not proven by positive live-source audio, monitor listening, Dante Controller route, or physical Sonic Sphere/Dante channel-walk evidence.
```

## Current 2.0 Installer And Signing Attempt

Date: 2026-05-10

Scope: 2.0 installer execution attempt, installed-app state check, signing identity check, and notarization credential check.

Commands run:

```sh
cp installer/Orbisonic-2.0.pkg /private/tmp/Orbisonic-2.0.pkg
cp installer/OrbisonicSuite-2.0.pkg /private/tmp/OrbisonicSuite-2.0.pkg
sudo -n installer -pkg /private/tmp/Orbisonic-2.0.pkg -target /
codesign --verify --deep --strict --verbose=2 /Applications/Orbisonic.app
plutil -lint /Applications/Orbisonic.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' /Applications/Orbisonic.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :OrbisonicGitCommit' /Applications/Orbisonic.app/Contents/Info.plist
pkgutil --pkg-info audio.orbisonic.app.pkg
pkgutil --pkg-info audio.orbisonic.inputs.pkg
security find-identity -v -p codesigning
security find-identity -v -p basic
productsign --sign 'Developer ID Installer' installer/Orbisonic-2.0.pkg /private/tmp/Orbisonic-2.0-signed.pkg
xcrun notarytool history --output-format json
```

Results:

- CLI app-only installer execution did not run: `sudo -n installer` returned `sudo: a password is required`.
- `/Applications/Orbisonic.app` still verifies with codesign and has a valid `Info.plist`.
- Installed `/Applications/Orbisonic.app` remains version `1.1` and `OrbisonicGitCommit` `8ffa977`.
- Installed package receipts still report `audio.orbisonic.app.pkg` version `1.1` and `audio.orbisonic.inputs.pkg` version `0.2.0`.
- `security find-identity -v -p codesigning` reports `0 valid identities found`.
- `security find-identity -v -p basic` reports `0 valid identities found`.
- `productsign` failed because no `Developer ID Installer` identity is available.
- `xcrun notarytool history` failed because notarization credentials are not configured.

Current installer/signing conclusion:

```text
The 2.0 installer gate is blocked on admin authentication for CLI installation. The 2.0 signing and notarization gates are blocked on missing local signing identities and missing notarization credentials. The installed app is still the historical 1.1 install, not the 2.0 candidate payload.
```

## Known Hardware Requirements

- macOS 14 or newer.
- Xcode or Xcode command line tools for local build verification.
- Sonic Sphere or Dante-capable output route for production output verification.
- Orbisonic Roon Input, Orbisonic Aux Cable, and Orbisonic Spotify Input for live-source verification.
- Roon or Roon Server for Roon metadata, bridge, transport, and loopback verification.
- Spotify client account/session for Spotify Connect verification.
- external app or system audio route for Aux verification.
- headphones or normal stereo output for monitor verification.
- admin-capable account for installer and HAL driver installation.

## Known Blockers And Limitations

- Automated tests do not prove physical Sonic Sphere / Dante output.
- Automated tests do not prove real Roon, Aux, or Spotify audio reached a loopback input.
- Automated tests do not exercise macOS microphone permission prompts.
- Automated tests do not prove installer behavior or LaunchServices behavior.
- Ad hoc signing does not prove entitlement-gated Apple spatial/head-tracking behavior.
- Roon bridge metadata and logs do not prove captured audio signal.
- Spotify source policy is currently stereo unless a future accepted contract changes it.
- The embedded librespot build depends on local Rust tooling and the expected static library artifact.
- Installer verification may require admin privileges and may affect system audio plug-ins.
