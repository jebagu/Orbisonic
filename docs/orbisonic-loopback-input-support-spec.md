# Orbisonic Loopback Input Support Spec

Status: implementation spec only. Do not write app code from this document until the user explicitly asks to implement it.

## Purpose

Update Orbisonic so its source model matches the two Orbisonic virtual loopback drivers being built in the sibling virtual soundcard project:

- `Orbisonic Roon Input`
- `Orbisonic Aux Cable`

The app should expose exactly three user-facing music inputs:

- `Roon`
- `Aux`
- `Local Files`

`Roon` is a dedicated, opinionated source that always expects the `Orbisonic Roon Input` loopback device by Core Audio UID. `Aux` is a general-purpose live source for Ableton, Apple Music, Spotify, browsers, guest laptops, and other apps, and it should normally expect the `Orbisonic Aux Cable` loopback device by UID. `Local Files` remains the app-owned local player/library/queue path.

The app must keep the selected-source-only rule: one active source feeds the monitor path and renderer path at a time. Orbisonic must not sum Roon and Aux unless a future explicit mixer mode is designed.

## Source Documents

This spec is based on:

- `orbisonic-loopback-build-spec.md` in the sibling Orbisonic Virtual Soundcard project
- Current app source model in `Sources/Orbisonic/OrbisonicViewModel.swift`
- Current SwiftUI shell in `Sources/Orbisonic/ContentView.swift`
- Current direct HAL capture path in `Sources/Orbisonic/LiveAudioBridge.swift`
- Current route discovery in `Sources/Orbisonic/OutputRouteMonitor.swift`
- Current Roon log parser in `Sources/Orbisonic/RoonNowPlayingMonitor.swift`

Do not use the old web prototype or the archived bridge prototype as the active product source.

## Non-Goals

- Do not build the loopback drivers in the Orbisonic app repository.
- Do not make Orbisonic a mixer between Roon and Aux.
- Do not require macOS Sound Input to switch to a loopback device.
- Do not use the latest Roon log line as proof that audio is reaching the loopback.
- Do not add fake meters or simulated live signal to mask routing problems.
- Do not add Spotify, Apple Music, Ableton, or browser transport controls. Those apps own their playback.
- Do not add production Roon API transport control in this implementation unless the Roon bridge/helper exists first.
- Do not expose BlackHole as a first-class user-facing source after the Orbisonic drivers are available. Keep any BlackHole compatibility behind diagnostics/development fallback only.

## Loopback Driver Contract

Orbisonic should discover the two loopbacks by stable UID, not display name.

### Roon Loopback

Display name:

```text
Orbisonic Roon Input
```

Core Audio device UID:

```text
audio.orbisonic.rooninput.device
```

Expected role:

```text
Roon -> Orbisonic Roon Input -> Orbisonic -> Dante Virtual Soundcard Pro
```

### Aux Loopback

Display name:

```text
Orbisonic Aux Cable
```

Core Audio device UID:

```text
audio.orbisonic.auxcable.device
```

Expected role:

```text
Spotify / Apple Music / browser / Ableton / guest app -> Orbisonic Aux Cable -> Orbisonic -> Dante Virtual Soundcard Pro
```

### Shared Capabilities

Both loopbacks are expected to advertise:

- `64 input / 64 output`
- `44.1`, `48`, `88.2`, `96`, `176.4`, and `192 kHz`
- `16-bit`, `24-bit`, and `32-bit` app-facing PCM where supported by the HAL implementation
- `32-bit float PCM` internally

Orbisonic should normalize capture to `32-bit float PCM` internally regardless of incoming bit depth.

## Core Product Model

Replace the current public source model with three product-level music inputs.

Suggested app model names:

```text
InputSourceKind.roon
InputSourceKind.aux
InputSourceKind.localFiles
```

Do not preserve `blackHoleOtherInput` as a public source. If needed during migration, keep it as a private diagnostic/development route.

### Source Profiles

Add a source profile layer so UI and engine behavior do not rely on scattered `if sourceMode == ...` checks.

Each profile should define:

- Stable source kind
- User-facing name
- Expected Core Audio input UID, if live
- Expected Core Audio display name, for fallback messages
- Whether the source is live capture or app-owned playback
- Whether Orbisonic owns play/pause/seek/next/previous
- Whether the source can expose rich metadata in Orbisonic
- Whether source-specific setup guidance is available
- Whether selected source can be manually overridden in normal UI

Recommended capability table:

| Source | Capture/playback owner | Expected device | Orbisonic transport | Scrub | Queue | Metadata |
| --- | --- | --- | --- | --- | --- | --- |
| Roon | External live app | `audio.orbisonic.rooninput.device` | Monitor/mute only for now | No | No | Roon log now, Roon API later |
| Aux | External live app | `audio.orbisonic.auxcable.device` | Monitor/mute only | No | No | Capture format and signal only |
| Local Files | Orbisonic | None | Full player controls | Yes | Yes | File/library metadata |

## Source Selection Behavior

Source switching must be deterministic and low-risk.

When switching to `Roon`:

- Stop local file playback if active.
- Stop Aux capture if active.
- Clear Aux-only metadata.
- Resolve `Orbisonic Roon Input` by UID.
- If available, prepare a Roon live capture session but do not fake signal presence.
- Show Roon metadata only if the Roon parser has current data.
- Keep inactive Aux capture stopped and hard muted.

When switching to `Aux`:

- Stop local file playback if active.
- Stop Roon capture if active.
- Clear Roon-specific signal-path warnings from the primary surface.
- Resolve `Orbisonic Aux Cable` by UID.
- If available, prepare an Aux live capture session.
- Show generic live input status, channel count, sample rate, meters, buffer health, and silence/clipping state.
- Keep inactive Roon capture stopped and hard muted.

When switching to `Local Files`:

- Stop any live capture session.
- Preserve local library, queue, selected track, and scrub state where possible.
- Restore local file metadata and transport controls.
- Reset live buffer/silence statuses so live-source errors do not linger on local playback.

Switching sources while muted should still tear down the previous capture path. Mute is not a background-monitoring or multi-source feature.

## Live Capture State Model

The current `isPlaying` flag conflates file playback, live capture, and diagnostic tone state. Introduce explicit runtime state for the selected source.

Suggested states:

```text
SourceRuntimeState.unavailable(reason)
SourceRuntimeState.ready
SourceRuntimeState.monitoring
SourceRuntimeState.muted
SourceRuntimeState.silent
SourceRuntimeState.error(message)
```

For local files, either use a parallel player state or make state variants precise:

```text
LocalPlayerState.empty
LocalPlayerState.ready
LocalPlayerState.playing
LocalPlayerState.paused
LocalPlayerState.ended
LocalPlayerState.error(message)
```

The UI can still present one status chip, but the model should not depend on one boolean to mean both "file is playing" and "live input is being monitored."

## Monitor, Mute, And Transport Semantics

Live sources are not players. The app should stop presenting Roon and Aux as if Orbisonic owns their playback.

### Roon Controls

Primary controls in the Now Playing card:

- `Monitor Roon`: start capturing and rendering `Orbisonic Roon Input`.
- `Mute Roon`: keep capture and meters active, but mute output to monitor and renderer.
- `Resume Monitor`: unmute a muted Roon capture.
- `Stop Monitor`: secondary control to release the device and reset live capture.

Playback controls:

- Play/pause, next, previous, queue controls, and scrubber should be disabled or hidden for the first implementation.
- If controls remain visible for layout stability, they must be visibly disabled with tooltip/help text: `Playback is controlled in Roon.`
- Roon metadata can show title, artist, zone, format, source channel mapping, and upstream paused state.
- If the future Roon API bridge is present, Roon transport may be promoted from disabled to active only when the bridge reports a controllable zone ID.

### Aux Controls

Primary controls in the Now Playing card:

- `Monitor Aux`: start capturing and rendering `Orbisonic Aux Cable`.
- `Mute Aux`: keep capture and meters active, but mute output to monitor and renderer.
- `Resume Monitor`: unmute a muted Aux capture.
- `Stop Monitor`: secondary control to release the device.

Playback controls:

- Play/pause, next, previous, queue controls, and scrubber should be disabled or hidden.
- Disabled help text should read: `Playback is controlled in the source app.`
- Aux status should focus on input device health, signal level, channel count, sample rate, buffer status, silence, clipping, and output safety.

### Local File Controls

Local files keep full player behavior:

- Play/pause
- Stop
- Scrub
- Previous/next queue item
- Play all
- Shuffle
- Add/remove/reorder queue entries
- File duration, current time, metadata, and artwork if present

The local player should not show live monitor/mute controls unless a future monitor-only local mode is explicitly added.

## Engine Requirements

The live capture path needs a true mute path rather than using only stop/start.

Current behavior can start and stop live input through `OrbisonicEngine.startLiveInput(...)` and `stop()`. New behavior should add a way to mute rendered output while keeping capture, buffer health, and input meters active.

Implementation direction:

- Insert a source gain or per-path gain stage between live source nodes and the environment/renderer feed.
- `Mute` should set live source output gain to zero for monitor and renderer outputs.
- Input meters must continue to read from captured buffers while muted.
- Monitor and renderer meters should either show post-mute silence or explicitly label pre-mute vs post-mute meters. Recommended: input meters remain pre-mute; monitor/renderer meters are post-mute.
- `Stop Monitor` should tear down the HAL input unit and release the selected input device.
- Muting one source must never allow another source to leak through.

If the existing graph cannot cheaply support a single gain stage for all live source nodes, add a small internal live-source mixer node per live session. Do not solve mute by repeatedly stopping and restarting the HAL input unit.

## Route Discovery Requirements

Update route discovery to classify devices by UID and role.

Add stable constants:

```text
LoopbackDeviceUID.roonInput = audio.orbisonic.rooninput.device
LoopbackDeviceUID.auxCable = audio.orbisonic.auxcable.device
```

Recommended classifications:

```text
InputDeviceRole.roonLoopback
InputDeviceRole.auxLoopback
InputDeviceRole.blackHoleCompatibility
InputDeviceRole.physicalInput
InputDeviceRole.otherVirtualInput
```

Output route discovery should also identify dangerous output targets:

- Any selected live source loopback
- The other Orbisonic loopback if it would create a virtual feedback path
- Legacy BlackHole devices

If the active monitor/output route is one of the Orbisonic loopbacks, live monitoring should block with a clear warning. Orbisonic must not output back into its own input cable.

## Device Resolution Policy

Normal UI should not require users to choose Core Audio devices for the two dedicated live sources.

Resolution order for Roon:

1. Find input route with UID `audio.orbisonic.rooninput.device`.
2. If missing, show `Orbisonic Roon Input is not installed or Core Audio has not loaded it.`
3. Offer diagnostics/setup guidance.
4. Only in Diagnostics/Advanced, allow a temporary development fallback such as BlackHole.

Resolution order for Aux:

1. Find input route with UID `audio.orbisonic.auxcable.device`.
2. If missing, show `Orbisonic Aux Cable is not installed or Core Audio has not loaded it.`
3. Offer setup guidance for routing macOS output or app output to Aux.
4. Only in Diagnostics/Advanced, allow manual fallback to another input.

The existing global `selectedInputDeviceUID` preference should be migrated or retired. Persist selected source kind separately from any advanced manual route override. Do not let an old BlackHole preference cause Roon to miss `Orbisonic Roon Input`.

## Roon-Specific Behavior

Roon mode should be stricter than Aux mode.

Roon setup assumptions:

- Roon output device is `Orbisonic Roon Input`.
- Roon channel layout is configured upstream, typically up to `7.1`.
- Roon converts DSD to PCM before the loopback.
- Roon metadata currently comes from `RoonServer_log.txt`.

Roon health checks:

- Loopback device available by UID.
- Loopback input channel count is greater than zero.
- Requested active channel count is less than or equal to available channels and app source limit.
- Roon log parser has a recent now-playing entry, if available.
- Roon signal path does not show downmixing to stereo when the selected source is expected to be multichannel.
- Roon output sample rate and loopback nominal sample rate match, when both are known.
- Live input meter peak rises after monitoring starts and Roon is not paused.

Roon silence messages should be causal:

- `Roon is paused upstream.`
- `Roon is playing, but Orbisonic Roon Input is silent. Check the selected Roon output zone.`
- `Roon is streaming at a different sample rate than the loopback device.`
- `Roon is downmixing before Orbisonic. Change the Roon zone channel layout.`

Rename or generalize BlackHole-specific repair code for this path. `BlackHoleRouteRepair` should become a virtual-input repair helper if it can safely apply to the new drivers. If the helper depends on BlackHole-specific behavior, keep it as compatibility-only and do not run it automatically against Orbisonic drivers until tested.

## Aux-Specific Behavior

Aux mode should be permissive and source-agnostic.

Aux setup assumptions:

- Apps without per-app output selection can use macOS Sound Output set to `Orbisonic Aux Cable`.
- Apps with per-app device selection, such as Ableton, can target `Orbisonic Aux Cable` directly.
- Orbisonic does not know or control which app is feeding Aux.

Aux health checks:

- Loopback device available by UID.
- Input channel count is greater than zero.
- Requested active channel count fits available input channels.
- Live buffer is healthy.
- Signal is present after the source app starts playback.
- Output route is not a loopback feedback target.

Aux silence messages should be generic:

- `Aux is silent. Start playback in the source app or check that it outputs to Orbisonic Aux Cable.`
- `Aux capture is active, but no input channels are available.`
- `Aux source is sending fewer active channels than the selected live channel count.`

Do not show Roon zone, Roon map, or Roon log parser warnings in Aux mode.

## Local Files Behavior

Local files remain the only app-owned music source.

Expected behavior:

- The app owns playback.
- The app owns queue state.
- The app owns play/pause/next/previous/scrub.
- The app can preserve file position while switching away, as long as the engine state remains coherent.
- Switching from live source to local file should restore local metadata without keeping live-source warnings.

Local file UI should be clearly separate from live input routing. Keep local playlist as a contained scrolling list. The whole window should not become a giant scroll region just because a library is large.

## Output And Dante Safety

Orbisonic's output target is separate from its loopback input devices.

The intended full path is:

```text
Selected source -> Orbisonic renderer/router -> Dante Virtual Soundcard Pro -> Dante network
```

Monitor path:

```text
Selected source -> Orbisonic monitor render/downmix -> headphones or selected monitor output
```

The app should make it obvious when the user is configuring input versus output. Do not let the `Orbisonic Roon Input` or `Orbisonic Aux Cable` devices appear as valid renderer/monitor destinations in normal flow.

Dante Virtual Soundcard Pro safety from the loopback driver spec:

- `44.1`, `48`, `88.2`, and `96 kHz` are safe for up to `128x128`.
- `176.4` and `192 kHz` are limited to `16x16`.
- If renderer output channel count is greater than `16` and selected output sample rate is `176.4` or `192 kHz`, block or require an explicit choice.

Blocking warning text:

```text
Dante Virtual Soundcard Pro supports only 16x16 channels at 176.4/192 kHz. For this Orbisonic layout, downsample to 88.2/96 kHz or reduce the output channel count.
```

Choices:

- Downsample to `88.2 kHz` or `96 kHz` for multichannel Dante output.
- Continue high-rate mode capped to `16` output channels.
- Cancel and keep the current route unchanged.

If the selected source has more than `64` channels, warn that the Orbisonic loopbacks expose `64` channels and the live source path cannot represent more than that. Local file handling may still be capped by the app's current source-channel limit.

## UI Architecture

Keep the dark technical Orbisonic app-family design:

- Compact control surface
- Dark glass panels
- Cyan active states
- Amber warnings
- Red/pink errors
- Dense labels and stable dimensions
- No decorative clutter
- No nested decorative cards

The first-level source selector should be a segmented control or three equal source cards, not a generic Core Audio picker.

Recommended main tabs:

- `Input`
- `Output`
- `Renderer`
- `Scene Tuning`
- `Local Playlist`
- `Diagnostics`

This aligns the UI around the actual operator workflow rather than exposing current implementation names like `Routing`, `VU Meter`, or `Settings`.

## Left Rail Flow

The left rail should remain the persistent session surface.

Sections:

- App title/header
- Active source/now playing
- Source controls
- Source status
- Route summary
- Compact live meters or meter summary, if space allows

### Now Playing Card

For Roon:

- Title from Roon metadata when available.
- Subtitle from artist/album or Roon zone.
- State chip: `MONITORING`, `MUTED`, `SILENT`, `READY`, or `MISSING`.
- Primary action: `Monitor Roon`, `Mute Roon`, or `Resume Monitor`.
- Secondary action: `Stop Monitor`.
- Disabled transport row or hidden transport row.
- Metadata rows: format, source channels, Roon map, zone.

For Aux:

- Title: `Aux Input` or selected device display name.
- Subtitle: `Orbisonic Aux Cable`.
- State chip: `MONITORING`, `MUTED`, `SILENT`, `READY`, or `MISSING`.
- Primary action: `Monitor Aux`, `Mute Aux`, or `Resume Monitor`.
- Secondary action: `Stop Monitor`.
- Disabled transport row or hidden transport row.
- Metadata rows: sample rate, active channels, buffer, signal.

For Local Files:

- Title from selected/current track.
- Subtitle from artist/album or file metadata.
- State chip: `PLAYING`, `PAUSED`, `READY`, or `EMPTY`.
- Primary action: `Play` or `Pause`.
- Secondary action: `Stop`.
- Queue controls and scrubber active.
- Metadata rows: codec, layout, channels, rate, length.

The card should reserve stable space for mode-specific controls so switching sources does not reshape the sidebar dramatically.

## Input Tab Flow

The `Input` tab should be the primary source selection and health view.

Top section:

- Three source cards or segmented controls: `Roon`, `Aux`, `Local Files`.
- Each source shows status: `Available`, `Missing`, `Monitoring`, `Muted`, `Silent`, or `Needs Setup`.
- Selecting a source changes active source, not transport state.

Roon details:

- Device: `Orbisonic Roon Input`
- UID-found status
- Channel count
- Sample rate
- Roon now-playing summary
- Roon signal-path warning if downmixed
- Setup hint: route Roon to `Orbisonic Roon Input`

Aux details:

- Device: `Orbisonic Aux Cable`
- UID-found status
- Channel count
- Sample rate
- Setup hint: route macOS output or app output to `Orbisonic Aux Cable`
- Generic source health

Local details:

- Current file or queue item
- Library count
- Selected playlist/queue summary
- Buttons for open file and local library actions, or links to the Local Playlist tab

Flow graphic:

```text
Source -> Capture/Player -> Monitor + Renderer -> Output
```

The flow graphic should show only the active source. Inactive sources should be visible in the selector, not in the active signal chain.

Meters:

- Input meter shows active source only.
- For Roon and Aux, input meter is pre-mute.
- For Local Files, input meter follows file playback.
- If source is muted, output/renderer meters should show post-mute silence.

## Output Tab Flow

The `Output` tab should focus on where Orbisonic sends audio.

Sections:

- Monitor output
- Renderer output
- Dante Virtual Soundcard Pro status
- Sample-rate and channel-count safety
- Output meters

The tab should clearly distinguish:

- Loopback input devices are not output destinations.
- Monitor output is for local checking.
- Renderer output is for Sonic Sphere/Dante routing.

Add explicit feedback prevention status:

- `Safe`: output route is not a loopback input.
- `Blocked`: output route is one of Orbisonic's input loopbacks.
- `Warning`: output route is unknown, virtual, or legacy BlackHole.

## Renderer And Scene Tuning Flow

The renderer remains source-agnostic. It should consume the currently active source layout.

Renderer tab:

- Renderer preset
- Input layout derived from active source
- Matrix dimensions
- Output speaker topology
- Renderer VU meters
- 3D scene visualization

Scene Tuning tab:

- Spatial tuning controls currently embedded in the renderer/settings flow
- Bed radius, front/rear angle, head tracking toggle, and related tuning controls
- Tuning should apply equally to Roon, Aux, and Local Files

Do not put source setup controls in Renderer or Scene Tuning.

## Local Playlist Flow

Keep Local Playlist focused on local media management:

- Music
- Playlists
- Session Queue
- Watch folders
- M3U imports
- Scan settings

The local playlist should remain a contained scrolling list. Selecting local media should switch active source to `Local Files`, but scanning or editing the library should not unexpectedly interrupt live capture unless the user starts playback.

## Diagnostics Flow

Diagnostics should hold tools that are not one of the three user-facing inputs.

Move or keep these here:

- Test tone
- Channel walk
- Advanced/manual input override
- Driver install detection
- Core Audio device list
- Roon log parser status
- Loopback UID check
- Sample-rate mismatch details
- Buffer underflow/drop counters
- Feedback-loop warnings

Test tone is a diagnostic source, not a fourth user-facing input.

If BlackHole compatibility remains, show it only here with clear development wording.

## Setup And Missing Driver UX

If either Orbisonic loopback is missing, the app should not fail silently.

Missing Roon driver message:

```text
Orbisonic Roon Input is not available. Install Orbisonic Inputs, then restart Core Audio or reboot.
```

Missing Aux driver message:

```text
Orbisonic Aux Cable is not available. Install Orbisonic Inputs, then restart Core Audio or reboot.
```

If both are missing:

```text
Orbisonic Inputs are not installed or Core Audio has not loaded them.
```

The app may include a button or help link labelled `Check Inputs` or `Open Setup`, but it should not attempt privileged driver installation unless a separate installer flow is intentionally designed.

## Logging Requirements

Log source transitions and route decisions with enough detail to diagnose audio routing.

Log on source selection:

- Previous source
- Next source
- Whether previous source was monitoring/playing
- Selected source expected UID
- Resolved device name and UID, if available

Log on live capture start:

- Source kind
- Device name
- UID
- Input channels
- Active channels
- Sample rate
- Output route
- Renderer output count

Log on mute/unmute:

- Source kind
- Mute state
- Whether capture remains active

Log on silence:

- Source kind
- Elapsed seconds
- Peak
- Input device
- Input sample rate
- Roon output sample rate, only in Roon mode
- Output route

Do not log real personal paths in new app logs unless they are runtime user-selected file paths necessary for debugging. Do not commit logs.

## Code Areas To Change Later

Planned implementation files:

- `Sources/Orbisonic/OutputRouteMonitor.swift`
  - Add UID-based Orbisonic loopback detection.
  - Add input device roles.
  - Add feedback-risk output classification.

- `Sources/Orbisonic/OrbisonicViewModel.swift`
  - Replace public `SourceMode` with the three-input source model.
  - Add source profiles/capabilities.
  - Separate live monitor state from local player state.
  - Resolve Roon and Aux by UID.
  - Add source-switch transitions.
  - Add mute/unmute monitor actions.
  - Remove BlackHole-specific public strings from normal Roon/Aux flow.

- `Sources/Orbisonic/OrbisonicEngine.swift`
  - Add live source mute/unmute without stopping capture.
  - Keep input meters active while muted.
  - Ensure inactive source nodes are detached or silent.
  - Keep file player transport separate from live monitor control.

- `Sources/Orbisonic/LiveAudioBridge.swift`
  - Keep direct HAL input capture generic.
  - Ensure capture works by selected device ID resolved from UID.
  - Surface buffer health for both Roon and Aux.

- `Sources/Orbisonic/BlackHoleRouteRepair.swift`
  - Rename/generalize only if the same operations are valid for Orbisonic drivers.
  - Otherwise keep it as a legacy compatibility helper and avoid applying it to Orbisonic loopbacks.

- `Sources/Orbisonic/RoonNowPlayingMonitor.swift`
  - Keep log parsing scoped to Roon mode.
  - Do not use Roon metadata as proof of live loopback signal.
  - Prepare future seam for Roon API bridge data without forcing it into Aux.

- `Sources/Orbisonic/ContentView.swift`
  - Refactor tabs to the proposed workflow.
  - Add three-source Input selector.
  - Replace live playback buttons with monitor/mute controls.
  - Keep local player transport active only for Local Files.
  - Move test tone out of source selector and into Diagnostics.

- Tests under `Tests/OrbisonicTests/`
  - Add source profile tests.
  - Add route classification tests.
  - Add source transition tests.
  - Add transport capability tests.
  - Add Dante safety policy tests.

## Migration Plan

Phase 1: device identity and pure logic

- Add loopback UID constants.
- Add route role classification.
- Add source profile/capability model.
- Add tests for classification and capabilities.
- No UI behavior changes yet.

Phase 2: source model refactor

- Replace public `SourceMode` cases with `Roon`, `Aux`, and `Local Files`.
- Move test tone to diagnostics-only state.
- Preserve local library and queue behavior.
- Migrate stored selected input preferences safely.
- Add tests for source switching.

Phase 3: live capture actions

- Implement `monitorSource`, `muteSource`, `resumeMonitor`, and `stopMonitor`.
- Resolve Roon and Aux by UID.
- Keep capture active while muted.
- Reset and label meters correctly.
- Add tests for action enablement and state transitions.

Phase 4: UI flow

- Update tabs to `Input`, `Output`, `Renderer`, `Scene Tuning`, `Local Playlist`, and `Diagnostics`.
- Add three-source selector and source cards.
- Refactor Now Playing card to mode-specific controls.
- Disable or hide playback controls for Roon and Aux.
- Keep layout stable across mode switches.

Phase 5: output safety

- Add feedback-loop blocking for Orbisonic loopbacks and legacy virtual inputs.
- Add Dante sample-rate/channel-count warnings.
- Add output safety statuses to Output tab.
- Add tests for policy decisions.

Phase 6: diagnostics and setup guidance

- Add loopback install/UID check.
- Add Roon parser status and signal-path diagnostics.
- Add Aux capture diagnostics.
- Keep advanced/manual input override out of the main flow.

Phase 7: verification and bundle refresh

- Run the standard test command.
- Refresh the app bundle.
- Verify code signing and plist.
- Open the app and manually verify source switching, muted live capture, and UI state.

## Test Plan

Unit tests:

- `Orbisonic Roon Input` UID resolves to Roon source profile.
- `Orbisonic Aux Cable` UID resolves to Aux source profile.
- Display names alone do not override UID identity.
- Missing Roon loopback yields Roon missing state.
- Missing Aux loopback yields Aux missing state.
- Roon and Aux expose monitor/mute controls, not local transport controls.
- Local Files exposes play/pause/scrub/queue controls.
- Switching Roon -> Aux stops Roon capture before starting Aux.
- Switching Aux -> Local Files stops Aux capture and restores local metadata.
- Switching Local Files -> Roon preserves local queue state.
- Muted live capture keeps input meter source active and zeroes monitor/renderer output levels.
- Roon log parser data is ignored outside Roon mode.
- Dante high-rate output warning fires when output channels are greater than `16` at `176.4/192 kHz`.
- Dante high-rate output warning does not fire when output channels are `16` or fewer.
- Output route matching either Orbisonic loopback is blocked for live monitoring.

Manual tests with drivers installed:

- Both Orbisonic loopbacks appear in Audio MIDI Setup.
- Orbisonic detects both devices by UID.
- Roon source card reports available when `Orbisonic Roon Input` exists.
- Aux source card reports available when `Orbisonic Aux Cable` exists.
- Roon can play into `Orbisonic Roon Input`.
- Aux can receive macOS system audio from Spotify, Apple Music, or browser playback.
- Ableton can target `Orbisonic Aux Cable` directly.
- Orbisonic monitors Roon without requiring macOS Sound Input to change.
- Orbisonic monitors Aux without showing Roon metadata.
- Source switching never sums Roon and Aux.
- Muting Roon keeps Roon input meters alive and silences monitor/renderer output.
- Muting Aux keeps Aux input meters alive and silences monitor/renderer output.
- Stopping monitor releases the capture path.
- Local file playback still supports play/pause/scrub/queue.
- Test tone remains available only in Diagnostics.
- Feedback warning appears if output is set to either Orbisonic loopback.
- Dante safety warning appears for invalid high-rate multichannel combinations.

Build verification after implementation:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
cp .build/arm64-apple-macosx/debug/Orbisonic Orbisonic.app/Contents/MacOS/Orbisonic
chmod +x Orbisonic.app/Contents/MacOS/Orbisonic
codesign --force --deep --sign - Orbisonic.app
codesign --verify --deep --strict --verbose=2 Orbisonic.app
plutil -lint Orbisonic.app/Contents/Info.plist
```

## Acceptance Criteria

- The app exposes exactly three user-facing music inputs: `Roon`, `Aux`, and `Local Files`.
- Roon uses `audio.orbisonic.rooninput.device` by UID.
- Aux uses `audio.orbisonic.auxcable.device` by UID.
- Local Files remains app-owned playback.
- Roon and Aux do not show active app-owned play/pause/scrub/queue controls.
- Roon and Aux support monitor, mute, resume monitor, and stop monitor.
- Muting a live source does not stop input metering.
- Stopping a live source releases capture.
- The inactive live source is not captured, mixed, or rendered.
- The app blocks output feedback into either Orbisonic loopback.
- Roon metadata and signal-path diagnostics appear only in Roon mode.
- Aux remains source-agnostic and does not display Roon-specific UI.
- Local Playlist remains contained and does not make the whole app window scroll.
- Test tone is diagnostics-only, not a fourth music input.
- Dante Virtual Soundcard Pro channel/sample-rate safety is enforced.
- New docs and repo-tracked text do not include personal absolute paths or old workspace references.

## Implementation Notes For Future Codex Run

Start with route/source pure logic before editing UI. The risky part is not the segmented control; it is avoiding accidental source mixing, feedback loops, and misleading transport semantics.

Do not try to preserve every old BlackHole string. The new product language should say `Roon`, `Aux`, `Orbisonic Roon Input`, and `Orbisonic Aux Cable` where appropriate. Internal compatibility names are acceptable only where they describe legacy code.

After code changes, inspect the live audio path carefully. If meters are silent, diagnose route, sample rate, source app output, and HAL capture state before touching renderer math.
