# Orbisonic Agent Notes

## Scope

- The canonical project root is `this repository`.
- If a Codex thread or inherited environment starts in `older Orbisonic prototype workspace`, treat that as stale launch context. Switch all active Orbisonic work to `this repository`.
- Work only in `this repository` unless the user explicitly says otherwise.
- Do not use, inspect, or ask about the old `etheric` workspace or archived `OrbisonicBridge` folders for active Orbisonic work unless the user explicitly asks for old context.
- Orbisonic is a native Swift/macOS app. Do not treat the old `etheric` web app or the earlier `OrbisonicBridge` prototype as the active product.
- `Orbisonic.app` is the user-facing double-clickable app bundle in the project root.
- Sonic Sphere is the physical spatial audio system. Orbisonic is the software tool for interfacing with it.

## Design Reference

- For UI, branding, icon, and visual-system work, use the shared style guide at `adjacent Orbisonic app-family design language document`.
- Treat that style guide as the Orbisonic app-family source of truth before making visual design decisions.
- Keep the DomeLab-inspired visual language: dark technical glass UI, compact labels, cyan accents, restrained dashboard density.

## Build And Verify

Use Xcode's developer dir for tests:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

After changing app code, refresh the bundle:

```sh
cp .build/arm64-apple-macosx/debug/Orbisonic Orbisonic.app/Contents/MacOS/Orbisonic
chmod +x Orbisonic.app/Contents/MacOS/Orbisonic
codesign --force --deep --sign - Orbisonic.app
codesign --verify --deep --strict --verbose=2 Orbisonic.app
plutil -lint Orbisonic.app/Contents/Info.plist
```

If the app is already running, quit and reopen it before judging UI/audio behavior.

## Audio Priorities

- The audio path is the most important part of this app. Prefer correctness, stability, and low-risk architecture over quick UI-visible fixes.
- Do not mask live audio failures with buffering tricks. If the input is all zeros, diagnose routing/sample-rate/source-device problems.
- The Roon live path captures the app-selected input device, expected to be `BlackHole 64ch`, without requiring macOS Sound Input to switch away from the user's mic.
- macOS presents all input-device capture as "Microphone" permission, including BlackHole. That prompt is expected and does not by itself mean the physical mic is selected.
- Local file playback and Roon live capture are separate paths. Do not assume a fix in one path fixes the other.
- For Roon/BlackHole problems, inspect `~/Library/Logs/Orbisonic/orbisonic.log` and compare:
  - Roon output sample rate
  - BlackHole nominal sample rate
  - input route name/channel count
  - live meter peak
  - buffer underflow/drop counters
- Roon logs may show playback while BlackHole capture is silent. Treat this as a routing or device-rate problem, not automatically as an engine/render problem.

## Roon Data

Current code reads Roon metadata from:

```text
~/Library/RoonServer/Logs/RoonServer_log.txt
```

Parser:

```text
Sources/Orbisonic/RoonNowPlayingMonitor.swift
```

The log parser extracts now-playing lines and signal-path details such as `Source Format=`, `ChannelMapping`, `Raat Device=`, and `Output`.

Future direction:

- Use the official Roon API for production metadata and transport control.
- Add a small `orbisonic-roon-bridge` helper if needed, likely Node-based, because Roon's public API tooling is Node-oriented.
- Use Roon API as the authoritative source for zones, zone IDs, state, seek position, duration, now playing, queue info, and transport commands.
- Keep Roon log parsing only as a fallback for signal-path data that the public API does not expose.
- Do not use latest Roon log line as proof that audio is reaching BlackHole.

## UI Direction

- Left rail keeps Now Playing and session status.
- Current main tabs are `Input`, `Output`, `Renderer`, `Scene Tuning`, `Local Playlist`, and `Diagnostics`.
- Local playlist should remain a contained scrolling list, not make the whole window scroll.
- Avoid adding nonfunctional clutter. Placeholder UI should be clearly scoped and not interfere with the core audio workflow.

## Existing Important Files

- `Sources/Orbisonic/ContentView.swift`: SwiftUI shell and tabs.
- `Sources/Orbisonic/OrbisonicViewModel.swift`: app state, Roon status, routing, playlist behavior.
- `Sources/Orbisonic/OrbisonicEngine.swift`: AVAudioEngine graph and playback/live input.
- `Sources/Orbisonic/LiveAudioBridge.swift`: live BlackHole capture bridge and buffer status.
- `Sources/Orbisonic/RoonNowPlayingMonitor.swift`: current Roon log metadata parser.
- `Sources/Orbisonic/BlackHoleRouteRepair.swift`: BlackHole mute/volume/sample-rate repair.
- `Sources/Orbisonic/OutputRouteMonitor.swift`: Core Audio route discovery.
- `calibration/`: Sonic Sphere layout JSON files.
