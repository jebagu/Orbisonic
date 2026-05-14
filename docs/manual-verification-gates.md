# Manual Verification Gates

## Purpose

This document records the hardware and service gates that must be run before Orbisonic can be called hardware-ready or release-ready.

Automated tests can prove contracts, formatting, route-fact validation, and fake-backend behavior. They do not prove physical Dante routing, SonicSphere speaker order, real Roon or Spotify capture, macOS permissions, app launch behavior, signing, or installer behavior.

## Evidence Rule

Use these result labels:

```text
PASS: the exact gate was exercised and evidence was recorded.
FAIL: the exact gate was exercised and did not meet the pass criteria.
BLOCKED: the gate could not be exercised because a required app, route, device, service, permission, or artifact was unavailable.
NOT RUN: the gate was not attempted in this pass.
```

Do not mark a gate as `PASS` from unit tests, VU activity, logs, app presence, or route names alone.

## Required Evidence Header

Every manual run must record:

```text
date:
operator:
Orbisonic build or git ref:
macOS version:
app launch path:
test location:
monitor route:
production route:
Dante device or DVS route:
SonicSphere profile:
Roon zone:
Spotify account/session:
installer package path, if installer is in scope:
```

## Dante Controller Gate

Prerequisites:

```text
Dante Controller is installed.
Dante Virtual Soundcard, Dante Application Library, or an approved Dante endpoint is running.
The intended Dante route is visible in Dante Controller.
The test machine is on the intended Dante network.
```

Checks:

```text
record transmit device name
record receive device name
record route subscriptions for Orbisonic output channels
record Dante sample rate
record Dante encoding bit depth
record Dante clock leader and lock state
record Dante latency setting
record warnings or unresolved subscriptions
confirm the selected Orbisonic production route is the same route observed in Dante Controller
confirm CoreAudio host Float32 exposure is not used as proof of Dante network Float32
```

Pass criteria:

```text
subscriptions are resolved
sample rate matches the target Dante profile
encoding bit depth matches the target Dante profile
clock is locked
route latency is recorded
no unresolved subscriptions or clock warnings remain
```

## Physical Channel-Walk Gate

Prerequisites:

```text
SonicSphere or equivalent Dante physical outputs are connected.
Output levels are safe.
The production route is selected intentionally.
The active output map is known.
```

Checks:

```text
walk logical channels 1 through 30
walk LFE or channel 31 when the active profile uses 30.1
verify each logical channel appears on the expected physical speaker
verify adjacent speakers do not receive the walked signal
verify polarity, trim, and delay are not obviously wrong
verify reserved physical channel 32 remains silent when a 32-channel Dante route is used
record any speaker ID, Dante transmit channel, and physical output mismatch
```

Pass criteria:

```text
every active logical output reaches the expected physical speaker
reserved/silent outputs stay silent
no channel swap, truncation, duplication, or hidden downmix is observed
```

## Route And Permission Gate

Prerequisites:

```text
Orbisonic launches through LaunchServices.
The required loopback inputs are installed.
The target monitor and production routes are visible to CoreAudio.
```

Checks:

```text
confirm Output 1 Monitor is a safe stereo monitor route
confirm Output 2 Main Renderer is a deliberate production route
confirm monitor actions do not mutate production route selection
confirm production refuses built-in output, Bluetooth, AirPlay, BlackHole, or unknown stereo routes
confirm Orbisonic Roon Input is visible when Roon is in scope
confirm Orbisonic Aux Cable is visible when Aux is in scope
confirm Orbisonic Spotify Input is visible when Spotify is in scope
record microphone permission prompt, granted/denied state, and resulting diagnostics
record sample-rate and channel-count facts for every selected input and output route
```

Pass criteria:

```text
all required routes are visible
permissions allow intended live capture
unsafe routes are rejected or diagnosed
monitor and production routes remain independent
```

## Roon Gate

Checks:

```text
Roon is routed to Orbisonic Roon Input
Orbisonic selected source is Roon
captured route facts are recorded
captured signal is present, or no-signal diagnostics are explicit
Roon bridge metadata and transport state remain separate from captured signal truth
multichannel Roon monitor downmix is upstream stereo or an explicitly selected owner only
```

Pass criteria:

```text
Roon loopback capture is proven by signal and route facts, not metadata alone
sample-rate and channel-count mismatches are visible
no hidden Roon downmix is claimed
```

## Spotify Gate

Checks:

```text
Spotify can see the intended Orbisonic Connect target, if Connect is in scope
Orbisonic selected source is Spotify
dedicated Spotify input route is recorded
source policy remains stereo
captured signal is present, or no-signal diagnostics are explicit
tokens, credentials, and private caches are not recorded
```

Pass criteria:

```text
Spotify live capture is proven by signal and route facts
Spotify does not inherit local or Roon multichannel metadata
stale metadata after pause or stop is diagnosed
```

## Installer And Signing Gate

Checks:

```text
app-only installer installs Orbisonic.app into /Applications
suite installer installs Orbisonic.app plus all required HAL loopback drivers
codesign verification result is recorded
Info.plist lint result is recorded
LaunchServices open result is recorded
installed app build metadata matches the verified artifact
installer log summary is recorded without private data
notarization status is recorded when public distribution is in scope
```

Pass criteria:

```text
installed files match expected payloads
app launches through LaunchServices
signing/notarization status is explicit
installed artifact matches the tested build
```

## Current Gate Record

Date: 2026-05-09

Scope: Task 018 machine-readable readiness check plus manual gate documentation.

Results:

```text
Dante Virtual Soundcard app present: PASS
DVS HAL driver present: PASS
DVS launch daemon running: PASS
Dante Controller installed: BLOCKED
Dante Controller subscriptions, encoding, clock, latency: BLOCKED
physical SonicSphere/Dante channel walk: NOT RUN
reserved channel 32 silence on hardware: NOT RUN
Roon real loopback capture: NOT RUN
Spotify real capture: NOT RUN
Aux real capture: NOT RUN
macOS microphone permission prompt: NOT RUN
app-only installer execution: NOT RUN
suite installer execution: NOT RUN
code signing/notarization for release artifact: NOT RUN
```

Evidence commands run:

```sh
ls -ld /Applications/Dante\ Virtual\ Soundcard.app /Applications/Dante\ Controller.app /Library/Audio/Plug-Ins/HAL/DvsAudioPlugIn.driver
launchctl print system/com.audinate.dante.DanteVirtualSoundcard
find /Applications -maxdepth 2 -iname '*Dante*' -print
```

Current blockers:

```text
Dante Controller is not installed in /Applications, so network subscriptions, encoding, clock lock, and latency were not verified.
No physical SonicSphere/Dante channel walk was run.
No real Roon, Spotify, or Aux capture was run.
No installer execution or release signing/notarization verification was run in this pass.
```

## Imported Pre-Merge Candidate Gate Record

Date: 2026-05-10

Scope: package rebuild, local package inspection, local service checks, and bounded loopback capture-access probes from the imported app-source branch before the canonical merge.

Results:

```text
Full SwiftPM suite: PASS, 648 tests, 0 failures
package signatures: BLOCKED, no signature
Dante Virtual Soundcard app present: PASS
DVS HAL driver present: PASS
DVS launch daemon running: PASS
Dante Controller installed: BLOCKED
Orbisonic Roon Input visible/openable: PASS, 48 kHz 7.1, silent
Orbisonic Aux Cable visible/openable: PASS, 48 kHz 64-channel, silent
Orbisonic Spotify Input visible/openable: PASS, 44.1 kHz stereo, silent
Roon bridge paired to Roon Core: PASS, Orbisonic zone stopped
positive Roon source-audio capture: NOT RUN
positive Spotify source-audio capture: NOT RUN
positive Aux source-audio capture: NOT RUN
physical SonicSphere/Dante channel walk: NOT RUN
app-only installer execution: NOT RUN
suite installer execution: NOT RUN
notarization: NOT RUN
```

Current blockers:

```text
The canonical merged repo still needs fresh package rebuild evidence.
The imported packages were unsigned and not notarized.
The imported packages were not installed.
Bounded loopback probes opened the devices but measured silence, so positive source-audio capture remains unverified.
Dante Controller is not installed in /Applications, so Dante network subscriptions, encoding, clock lock, and latency remain unverified.
No physical SonicSphere/Dante channel walk was run.
```

## Current Installer And Signing Gate Requirements

Run these gates after rebuilding packages from the canonical merged repo:

```sh
./scripts/build-installer.sh
./scripts/build-suite-installer.sh
sudo installer -pkg installer/Orbisonic-1.3.pkg -target /
codesign --verify --deep --strict --verbose=2 /Applications/Orbisonic.app
plutil -lint /Applications/Orbisonic.app/Contents/Info.plist
pkgutil --pkg-info audio.orbisonic.app.pkg
pkgutil --pkg-info audio.orbisonic.inputs.pkg
security find-identity -v -p codesigning
security find-identity -v -p basic
```
