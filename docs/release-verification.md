# Orbisonic Release Verification

## Purpose

This document defines the release and installer checks for Orbisonic. It separates automated repository checks from manual runtime checks that require macOS app launch, loopback devices, Roon, Spotify, Aux audio, Sonic Sphere, Dante, headphones, microphone permission, signing, or installer actions.

Use this document before calling an app bundle or installer release-ready. Do not treat a unit-test pass as proof that hardware, route, service, or installer behavior was verified.

## Release Artifacts

Current release-facing artifacts in this repository:

- `Orbisonic.app`: repo-root development app bundle.
- `installer/Orbisonic-1.1.pkg`: app-only installer. It installs `Orbisonic.app` into `/Applications`.
- `installer/OrbisonicSuite-1.1.pkg`: suite installer. It contains the app package plus `OrbisonicInputsComponent-0.2.0.pkg`.
- `scripts/refresh-orbisonic-app.sh`: canonical build, bundle refresh, metadata stamp, ad hoc signing, codesign verify, and plist lint path.
- `scripts/reopen-orbisonic-app.sh`: canonical LaunchServices quit and reopen path.
- `scripts/build-installer.sh`: app-only package build path.
- `scripts/install-roon-bridge.sh`: optional Roon bridge dependency install path.
- `scripts/build-embedded-librespot.sh`: embedded Spotify receiver static-library build path.
- `Orbisonic.entitlements`: entitlement template for Xcode signing when Apple spatial/head-tracking features are being verified.

The suite installer payload should be verified as containing:

- `Orbisonic-1.1.pkg` with `/Applications/Orbisonic.app`
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
pkgutil --payload-files installer/Orbisonic-1.1.pkg
```

Expected app-only package evidence:

- `/Applications/Orbisonic.app`
- `Orbisonic.app/Contents/MacOS/Orbisonic`
- app resources, including the SwiftPM resource bundle
- bundled `ffmpeg` and `ffprobe` tools when present in the package

Inspect the suite package by expanding it into a temporary directory:

```sh
tmpdir="$(mktemp -d)"
pkgutil --expand-full installer/OrbisonicSuite-1.1.pkg "$tmpdir/pkg"
find "$tmpdir/pkg" -maxdepth 5 -name PackageInfo -print
```

Expected suite package evidence:

- component package `Orbisonic-1.1.pkg`
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
sudo installer -pkg installer/Orbisonic-1.1.pkg -target /
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
sudo installer -pkg installer/OrbisonicSuite-1.1.pkg -target /
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
