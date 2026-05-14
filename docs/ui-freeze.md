# UI Freeze Contract

## Status

Binding.

No implementation task may violate this document.

## Purpose

Orbisonic is an audio-chain rewrite, not a UI rewrite.

The existing Orbisonic interface is already accepted. The new project must preserve it.

## Absolute Rule

```text
The Orbisonic UI must remain the same as the current Orbisonic UI.
```

The only approved visible addition is:

```text
Pure Spherical Lossless
```

as a badge or indicator in an existing UI surface.

## Allowed UI Addition

The Pure Spherical Lossless indicator may appear in:

```text
existing now-playing/status area
existing local file row
existing file metadata area
existing diagnostics/status line if the current UI already has one
```

It must be small and informational. It must not create a new workflow.

Accepted display strings:

```text
Pure Spherical Lossless
Pure Spherical Lossless, different sphere
Pure Spherical Lossless, route not ready
```

The base accepted string is `Pure Spherical Lossless`. The variants are allowed only when the app already needs to communicate validation state in an existing status area.

## Forbidden UI Additions

Codex must not add:

```text
new screens
new tabs
new modal sheets
new inspector view
new export view
new source picker workflow
new route workflow
new Dante workflow
new Roon workflow
new Spotify workflow
new VLC workflow
new audio-engine settings panel
new transport controls
separate pause button
separate stop button when the current UI uses a combined Play/Stop control
new waveform display
new channel meter surface unless the current app already has the same surface
new user-facing SRC setting
new user-facing dither setting
new user-facing VLC setting
```

## Existing Transport Behavior

The current user-facing transport model must be preserved.

If the current app uses one Play/Stop style control, Orbisonic must keep that control.

Internal audio sessions may have:

```text
start
play
pause
resume
flush
drain
stop
close
```

These are internal lifecycle operations. They must not become new buttons.

## Existing Source Workflows

The following workflows must remain visually and behaviorally the same:

```text
Local Files
Roon
Spotify
SonicSphere / production route
output route selection
now-playing status
playback start and stop
```

The audio coordinator can change underneath these workflows. The user-facing path cannot.

## Existing Labels

Existing labels should remain unless they are internally wrong and not visible.

The only new user-facing label is:

```text
Pure Spherical Lossless
```

Avoid showing:

```text
VLC
libVLC
amem
FL32
DanteOutputFormatter
SRC
TPDF
AudioConversionLedger
```

These belong in diagnostics or developer logs, not normal UI.

## UI Dependency Boundary

UI may depend on:

```text
ExistingOrbisonicUIFacade
existing view model state types
PureSphericalLosslessBadgeState
```

UI must not depend on:

```text
OrbisonicVLCReference
CLibVLCBridge
VlcLocalStereoMonitorSource
DanteOutputFormatter
ProductionOutputSession internals
SourceRateConverter internals
SonicSphereRenderer internals
ring buffers
CoreAudio HAL internals
```

## Required Tests

Before audio implementation begins, create UI freeze tests.

Required test types:

```text
snapshot or structural tests for existing primary screens
forbidden string tests
forbidden component tests
transport-control count test
source-workflow presence test
Pure Spherical Lossless badge test
```

Forbidden strings in normal UI:

```text
VLC
libVLC
amem
FL32
SRC
Dither
Dante Formatter
Output Session
Audio Chain
```

Allowed developer/diagnostic logs may contain those strings only if they do not alter the normal UI.

## Task Stopping Condition

Codex must stop and report if a requested implementation requires:

```text
new UI surface beyond the badge
new transport control
new workflow
renaming existing user-facing controls
showing VLC details to the user
changing Roon/Spotify/local source workflow
```

## Acceptance Criteria

The UI freeze is satisfied when:

```text
existing UI screenshots or structural descriptions match baseline
existing transport control behavior matches baseline
existing source workflows match baseline
only the Pure Spherical Lossless badge is new
UI code does not import audio-chain internals
all UI freeze tests pass
```
