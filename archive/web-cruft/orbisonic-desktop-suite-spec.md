# Orbisonic Desktop Suite Spec

## Purpose

Replace the browser-first prototype with a **macOS desktop suite** built for real multichannel output, stable Core Audio routing, and saved spatial shows.

The suite has two apps:

1. **Orbisonic Studio**
   - 4-channel movable bed cueing
   - 2 movable objects
   - 3D "space DJ" rig
   - basic synth
   - Atmos-inspired renderer
   - BlackHole64 / Dante Virtual Soundcard output
   - save/load Orbisonic shows

2. **Orbisonic Jukebox**
   - iTunes-like library + playlists
   - multichannel WAV / FLAC / MKA playback
   - album art
   - M3U playlist support
   - renderer tab using the same render core as Orbisonic Studio

This document is the implementation spec I should follow when building or adapting the current work.

---

## Non-Negotiables

- macOS-first, not cross-platform-first
- same visual language as **DomeLab**
- no real-time audio in JS
- one shared renderer core used by both apps
- saved projects must be first-class, not an afterthought
- output must target actual Core Audio devices, especially:
  - `BlackHole 64ch`
  - `Dante Virtual Soundcard`

---

## Visual Direction

Use the local DomeLab look as the canonical UI reference, not the current web prototype's greener radar styling.

### DomeLab Tokens To Reuse

- Background: `#071014`
- Main panel: `rgba(13, 24, 29, 0.88)`
- Hairline border: `rgba(217, 251, 255, 0.14)`
- Primary text: `#effcff`
- Secondary text: `#9fb9bd`
- Cyan accent: `#5eead4`
- Blue accent: `#60a5fa`
- Amber warning: `#facc15`
- Red danger: `#fb7185`
- Shadow: `0 18px 55px rgba(0, 0, 0, 0.36)`
- Radius: `8px`
- Heavy use of glassy panels and blurred overlays
- Dense top metric chips
- Left control rail + main workspace split
- Monospace readouts only where technical data matters

### Visual Rules

- The app should feel like a pro tool, not a game toy.
- 3D sphere view can glow and animate, but controls should stay crisp and restrained.
- Use cyan/blue/amber/red as the semantic system.
- Keep the overall shell dark teal/charcoal, not black/neon green.
- VU meters can be more vivid than the rest of the UI.

---

## Recommended Technical Direction

### Platform Choice

Build this as a **native macOS app suite**:

- **UI shell**: SwiftUI + AppKit interop where needed
- **3D viewport**: SceneKit first, Metal only if SceneKit becomes a bottleneck
- **Audio engine**: AVAudioEngine + Core Audio HAL
- **Basic synth**: AudioKit
- **Media decode / mux / demux**: FFmpeg libraries
- **Matroska support**: libmatroska / MKVToolNix knowledge for tooling and validation

### Why This Direction

- Core Audio device enumeration, channel mapping, and stable multichannel playback are easiest on macOS in native code.
- Offline rendering is available through `AVAudioEngine` manual rendering mode.
- SwiftUI can reproduce the DomeLab visual system without the complexity of a webview plus native audio sidecar.
- The current `etheric` React prototype should be treated as an **interaction and layout prototype**, not as production audio software.

### What Not To Do

- Do not ship the audio engine in Web Audio.
- Do not make Electron or Tauri the center of the architecture if the result still requires a native audio helper for everything important.
- Do not try to claim native Dolby Atmos authoring compatibility in v1.

---

## Product Model

The suite is one codebase with shared modules and two macOS app targets.

### Proposed Repo Layout

```text
orbisonic/
  apps/
    OrbisonicStudio/
    OrbisonicJukebox/
  packages/
    ThemeKit/
    RendererCore/
    MediaCore/
    ProjectFormat/
    DeviceIO/
    MeteringAndAnalysis/
    Persistence/
  docs/
    orbisonic-desktop-suite-spec.md
  prototypes/
    etheric-web-prototype/
```

Rules:

- `apps/OrbisonicStudio` and `apps/OrbisonicJukebox` are thin app shells.
- Core logic belongs in `packages/`, not duplicated per app.
- The current React work should be copied into `prototypes/etheric-web-prototype/` as a behavior and layout reference, not shipped as production code.

### Shared Modules

1. **ThemeKit**
   - DomeLab color tokens, spacing, typography, panel chrome, metric chips, VU styling

2. **RendererCore**
   - source model
   - speaker layouts
   - gain solving
   - binaural preview mode
   - multichannel output buses
   - per-channel meters

3. **MediaCore**
   - decode WAV, FLAC, AIFF, CAF, MKA/MKV audio
   - artwork extraction
   - chapter/cue parsing
   - playlist import/export

4. **ProjectFormat**
   - Orbisonic show schema
   - automation curve schema
   - cue list schema
   - import/export adapters

5. **DeviceIO**
   - Core Audio device discovery
   - channel count / sample rate validation
   - output routing presets
   - BlackHole64 and Dante templates

6. **MeteringAndAnalysis**
   - input meters
   - post-render speaker meters
   - spectrum analyzer
   - overload detection

7. **Persistence**
   - app settings
   - recent files
   - jukebox library database
   - renderer presets

---

## Shared Audio / Renderer Architecture

This is **Atmos-inspired**, not Dolby-compatible.

### Source Model

- 4 movable **bed channels**
- 2 movable **object channels**
- each source can have:
  - gain
  - mute / solo
  - time offset
  - loop flag
  - automation
  - analyzer tap

### Key Difference From Atmos

Atmos beds are fixed layout concepts. Orbisonic beds are **movable 4-channel anchors**.

Therefore:

- do not model this as a literal Atmos bed
- do model it as a custom scene format using:
  - bed-like stems
  - object-like point sources
  - render-time speaker mapping

### Render Modes

1. **Binaural Preview**
   - headphone monitoring
   - HRTF-based
   - near-real-time preview only

2. **Home Layout Preview**
   - 5.1 and 7.1 preview targets
   - useful for sanity checking

3. **Sonic Sphere Render**
   - main target layout
   - 30.1 or configurable large-array target

### Rendering Strategy

Use a custom gain-matrix renderer with the following stages:

1. Resolve source positions and automation at current play time
2. Convert bed anchors and objects into target-space vectors
3. Solve gains for the chosen layout
4. Sum into speaker buses
5. Derive LFE feed by low-passed contribution rules
6. Publish post-render per-speaker meters

### Panning / Math

Initial implementation:

- VBAP-style or triplet-based gain solving for object sources
- speaker layout defined as cartesian vectors
- smooth gain interpolation to avoid zipper noise
- constant-power normalization

Future option:

- add distance cues / room coloration
- add ambisonic intermediate stage for binaural mode if needed

---

## File Format Strategy

### Working Project Format

Do **not** use raw MKV as the editable project format.

Use a native **Orbisonic Show** package:

- extension: `.orbshow`
- internally: zipped bundle or macOS package directory

Contents:

- `show.json`
- `/audio/bed-1.wav`
- `/audio/bed-2.wav`
- `/audio/bed-3.wav`
- `/audio/bed-4.wav`
- `/audio/object-a.wav` or synth patch
- `/audio/object-b.wav` or synth patch
- `/artwork/cover.*`
- `/metadata/adm-like.xml` optional
- `/analysis/cache.json` optional

### Why Not Raw MKV For Authoring

- hard to live-edit
- awkward for version control
- poor fit for constantly changing automation
- better as interchange / archive than as the working document

### Interchange / Delivery Format

Use **Matroska audio** as an export/import container later:

- `.mka` for audio-focused packages
- `.mkv` if we need video or timeline visuals later

Matroska export can hold:

- rendered stems or multichannel masters
- chapters / cues
- attachments for artwork
- attached metadata payloads

### Atmos-Informed Metadata Decision

For v1:

- use an **ADM-inspired** metadata schema for objects, beds, and layout intent
- do not promise native Dolby Atmos master import/export
- if Atmos interoperability matters later, target:
  - ADM / BW64 workflows
  - decoded stems plus metadata conversion

---

## App 1: Orbisonic Studio

Orbisonic Studio is the creation tool.

### Module 1: Bed Cue Deck

Purpose:

- manage the 4 bed channels as performance lanes

Requirements:

- each bed lane supports a cue stack or clip list
- support one-shot and loop cues
- cue start quantization optional
- clip pre-roll waveform
- per-cue gain
- per-cue fade in / fade out
- per-lane mute / solo
- longest active bed region defines show section length when needed

Nice-to-have later:

- follow actions
- scene recall
- clip color tags

### Module 2: 3D Spacing Rig

Purpose:

- live spatial performance surface for the 4 beds + 2 objects

Requirements:

- fixed sphere reference view
- bed anchors visible on sphere
- objects visible as draggable orbs
- camera orbit / pan / zoom
- object trails
- automation modes:
  - manual
  - orbit
  - up/down
  - through-center
  - path
- position recording
- automation lane editor
- tempo sync where useful

Important behavior:

- bed channels are movable anchors on the sphere
- objects move freely inside or across the sphere
- renderer consumes resolved positions in real time

### Module 3: Basic Synth

Purpose:

- give each object a minimal internal synth option

Requirements:

- waveform select: sine / triangle / saw / square
- ADSR
- filter cutoff / resonance
- simple reverb / delay / chorus
- 16-step sequencer
- 8 pattern slots
- scale quantize
- preview note

Not in v1:

- modular synth graph
- deep modulation matrix
- advanced sampling instruments

### Module 4: Renderer Panel

Purpose:

- expose the shared render engine inside the authoring app

Requirements:

- render mode selector
- layout preset selector
- post-render multichannel VU meter array
- speaker activity visualization
- spectrum analyzer
- bypass / compare
- overload / clipping warnings
- dry run validation before output start

### Module 5: Output Routing

Purpose:

- target real Core Audio devices safely

Requirements:

- enumerate output devices
- detect channel count
- validate expected sample rate
- save named routing presets
- include templates for:
  - BlackHole 64ch
  - Dante Virtual Soundcard
- show channel map table before render start
- fail clearly if selected device does not have required channel count

### Module 6: Show Save / Load

Purpose:

- make spatial shows a stable artifact, not just app state

Requirements:

- save `.orbshow`
- reopen without broken media references
- embed or copy referenced audio
- save bed/object automation
- save renderer preset and device preset name
- save cue lists and chapters
- save artwork and notes

### Module 7: Offline Render / Export

Purpose:

- export reproducible deliverables

Requirements:

- offline render using AVAudioEngine manual rendering mode or equivalent engine path
- export:
  - stereo preview
  - 5.1 preview
  - 7.1 preview
  - full multichannel master
- export meters / peak report
- export optional `.mka` package later

---

## App 2: Orbisonic Jukebox

Orbisonic Jukebox is the playback and library tool.

### Overall UX

- should feel closer to classic iTunes / Music.app than to a DAW
- sidebar for library sections and playlists
- main pane for albums / tracks
- bottom transport
- inspector drawer for renderer and file metadata

### Module 1: Library

Requirements:

- indexed music library
- album art
- artist / album / genre / playlist views
- drag-and-drop import
- supports:
  - WAV
  - FLAC
  - AIFF
  - CAF
  - MKA / MKV audio
- remembers folders

Storage:

- SQLite library database
- artwork cache
- waveform cache

### Module 2: Playlist / Queue

Requirements:

- M3U import/export
- queue view
- playlist editing
- shuffle / repeat
- gapless playback where possible
- chapter / cue jump if source container supports it

### Module 3: Multichannel Playback

Requirements:

- decode and play multichannel WAV and other supported formats
- preserve original channel count when possible
- show source channel layout
- support track inspector with:
  - sample rate
  - channel count
  - duration
  - artwork
  - embedded chapters / cues

### Module 4: Renderer Tab

Purpose:

- send library playback through the same renderer core as Studio

Requirements:

- renderer tab inside Jukebox
- choose play mode:
  - direct playback
  - Orbisonic render
- channel mapping presets
- optional extraction of mono channels into object lanes
- same multichannel VU meter array as Studio
- same output routing preset system

### Module 5: Album / Show Package Playback

Requirements:

- if a file carries Orbisonic metadata, load it into the renderer automatically
- if the file is just a plain multichannel WAV, fall back to layout mapping presets
- show artwork and notes if present

---

## Module Delineation

This is the build breakdown I should actually implement against.

### ThemeKit

- shared colors
- panel styles
- metric chips
- buttons / toggles / segmented controls
- VU meter component
- typography system

### TransportModule

- play / pause / stop
- scrubber
- clock
- loop controls
- pre-roll / count-in options where applicable

### CueModule

- cue lists
- clip state
- trigger rules
- fades
- scene recall

### SpatialRigModule

- 3D sphere scene
- selection model
- drag handles
- automation curves
- motion presets

### SynthModule

- object synth engines
- step sequencer
- patch storage

### RendererCore

- layout definitions
- gain solver
- speaker bus accumulation
- binaural preview
- metering taps

### DeviceIOModule

- Core Audio discovery
- route validation
- output format negotiation
- BlackHole / Dante presets

### MediaCore

- decode
- waveform analysis
- artwork extraction
- metadata extraction
- playlist parsing

### ProjectFormat

- `.orbshow` schema
- migration/versioning
- import/export adapters

### LibraryModule

- scan folders
- build library DB
- search / filter / sort
- playlist store

---

## Build Phases

### Phase 0: Architecture Spike

- prove native multichannel output to BlackHole64
- prove 31-channel output bus to a Core Audio device
- prove post-render multichannel metering
- prove offline multichannel export

If this fails, stop and simplify before building UI depth.

### Phase 1: Shared Engine

- build RendererCore
- build DeviceIO
- build MediaCore
- build ThemeKit
- build `.orbshow` schema

### Phase 2: Orbisonic Studio MVP

- 4 bed lanes
- 2 objects
- 3D rig
- manual object movement
- simple cueing
- simple synth
- render panel with multichannel VU array
- save/load project

### Phase 3: Jukebox MVP

- library
- playlists
- artwork
- multichannel playback
- renderer tab

### Phase 4: Advanced Save / Interchange

- `.mka` export/import
- chapters / cues
- attached metadata payloads

### Phase 5: Polish / Reliability

- crash recovery
- auto-save
- damaged-media recovery
- device disconnect handling
- route mismatch warnings

---

## Open Source Projects To Crib From

These are reference candidates, not blind-copy dependencies.

### Strong Candidates

1. **AudioKit**
   - Use for simple synth building blocks and macOS-friendly DSP utilities.
   - Why: native Apple stack, MIT license, already aligned with Swift.
   - Reference:
     - https://github.com/AudioKit/AudioKit
     - https://github.com/AudioKit/AudioKitUI

2. **FFmpeg**
   - Use for media decoding, multichannel file ingest, artwork/chapter parsing, and possible container export helpers.
   - Why: battle-tested decode/mux/demux stack.
   - Reference:
     - https://ffmpeg.org/
     - https://github.com/FFmpeg/FFmpeg

3. **EBU ADM Renderer / EAR**
   - Use as the semantic reference for open, codec-agnostic object/beds metadata thinking.
   - Why: it gives an open reference path for Atmos-like concepts without depending on Dolby internals.
   - Reference:
     - https://github.com/ebu/ebu_adm_renderer
     - https://ear-production-suite.ebu.io/

4. **libspatialaudio**
   - Use as a rendering reference for object, speaker, and binaural processing concepts.
   - Why: it already spans loudspeaker and binaural workflows.
   - Reference:
     - https://github.com/videolabs/libspatialaudio

5. **Open Binaural Renderer**
   - Use as a binaural reference, especially if headphone preview quality needs to exceed AVFoundation defaults.
   - Reference:
     - https://github.com/google/obr

6. **Matroska libraries / MKVToolNix**
   - Use for the `.mka` / `.mkv` interchange layer, validation, and testing.
   - Reference:
     - https://www.matroska.org/downloads/libraries.html
     - https://github.com/Matroska-Org/libmatroska
     - https://mkvtoolnix.org/source/

### UI / Product References

1. **Cog**
   - Crib library/player UX patterns, metadata handling expectations, and playlist behavior.
   - Do not directly reuse GPL code in a non-GPL app without deciding licensing first.
   - Reference:
     - https://cog.losno.co/
     - https://github.com/losnoco/Cog

2. **IINA**
   - Crib modern macOS player UX ideas, music mode organization, and playlist/inspector patterns.
   - Again, GPL code means reference patterns, not copy-paste.
   - Reference:
     - https://github.com/iina/iina
     - https://iina.io/

3. **JUCE**
   - Crib architecture ideas around audio app structure and device handling if native Swift becomes too limiting.
   - Licensing needs a deliberate choice before adoption.
   - Reference:
     - https://github.com/juce-framework/JUCE
     - https://juce.com/legal/juce-8-licence/

### Licensing Rule

- MIT / BSD / Apache / LGPL references are easier to use directly.
- GPL references are for architecture, UX, and behavior study unless the product is intentionally GPL.
- JUCE requires explicit licensing review before adoption.

---

## Testing Plan

### Audio Engine Tests

- source routing correctness
- gain normalization correctness
- no channel index drift
- export file channel count correctness
- LFE derivation sanity

### Device Tests

- BlackHole64 route validation
- Dante Virtual Soundcard route validation
- output device disappearance while playing
- sample-rate mismatch handling

### Project Tests

- save/load round trip
- missing file recovery
- cue timing persistence
- automation persistence

### Jukebox Tests

- M3U import/export
- album art extraction
- multichannel file metadata parsing
- queue persistence

### UI Tests

- DomeLab token conformance
- 3D rig interaction
- VU meter performance
- renderer tab state persistence

---

## Risks

1. **True Atmos compatibility**
   - High risk if interpreted as direct Dolby-authoring support.
   - Plan: stay Atmos-inspired and ADM-informed in v1.

2. **MKV as working format**
   - Bad fit for live authoring.
   - Plan: `.orbshow` for authoring, `.mka/.mkv` for interchange/export.

3. **Multichannel device reality**
   - Core Audio routing will expose edge cases quickly.
   - Plan: architecture spike first.

4. **Renderer complexity**
   - A custom full renderer is easy to overbuild.
   - Plan: solve 4 beds + 2 objects well before generalizing.

5. **Licensing contamination**
   - GPL projects are excellent references but risky as embedded code.
   - Plan: keep a dependency ledger from day one.

---

## First Build Target

The first version I should actually build is:

- macOS app target: **Orbisonic Studio**
- native audio engine
- 4 cueable bed lanes
- 2 objects
- SceneKit sphere rig
- simple synth for objects
- 5.1 + 30.1 render modes
- multichannel VU array
- BlackHole64 output preset
- `.orbshow` save/load

Only after that is stable should I build **Orbisonic Jukebox** on top of the same shared engine.
