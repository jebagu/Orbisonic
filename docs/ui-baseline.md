# Existing UI Baseline

## Purpose

This document records the visible Orbisonic app structure that Task 001 freezes before audio-chain implementation begins.

The baseline is taken from:

```text
Sources/Orbisonic/ContentView.swift
Sources/Orbisonic/LoopbackSourceSupport.swift
```

## Primary App Structure

The app uses a left sidebar and right stage layout.

The stage tabs are:

```text
Input
Renderer
Output
VU
Local Music
Diagnostics
Settings
```

No new screen, tab, modal, inspector, export view, source workflow, route workflow, or audio-engine settings panel is part of the baseline.

## Source Workflow

The source selector uses the existing `SourceMode.musicInputs` order:

```text
Local Music
Spotify
Roon
Aux Cable
Off
```

`Test Tone` remains an internal/source-support mode and is not in the primary music input selector.

## Local Music Workflow

The Local Music surface has these panels:

```text
Music
Playlists
Session Queue
```

## Transport Workflow

The visible player transport row is defined by `PlayerTransportKind.allCases`:

```text
Back
Play
Pause
Forward
```

The source contains a `stop` enum case, but it is not part of the visible transport row baseline.

## Allowed Future Visible Addition

The only approved new visible label is:

```text
Pure Spherical Lossless
```

Accepted badge variants:

```text
Pure Spherical Lossless
Pure Spherical Lossless, different sphere
Pure Spherical Lossless, route not ready
```

## Forbidden Normal UI Strings

Normal UI must not expose implementation terms such as:

```text
VLC
libVLC
amem
FL32
SRC
Dither
DanteOutputFormatter
OutputSession
AudioConversionLedger
Audio Chain
```

Existing diagnostics surfaces may continue to expose technical facts where they already do so.

## Verification

The baseline is enforced by:

```text
Tests/OrbisonicTests/ExistingUIFreezeTests.swift
```
