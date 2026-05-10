# DEPRECATED

This file is deprecated legacy Orbisonic instruction material copied into the Orbisonic 2.0 workspace. Use `project-control/` at the Orbisonic 2.0 root for current instructions. Retained for reference only.

# High-Channel VU Meter Lab Webapp Spec

Status: implementation spec only. Do not write webapp or Orbisonic app code from this document until the user explicitly asks to implement it.

## Purpose

Build a compact browser-based design lab for experimenting with high-channel-count VU meter visuals for Orbisonic and Sonic Sphere workflows.

The tool should let a user try visual layouts, motion styles, channel labels, thresholds, grouping, and simulated signal behavior for `1` through `64` channels, then export the selected design as a portable settings JSON file.

The end product is not a DAW meter, not a scientific analyzer, and not a marketing mockup. It is an operator-facing meter-design workbench for finding readable, dense, fast-scanning ways to answer:

- Which channels exist?
- Which channels are active?
- Which channels are hot or clipping?
- Which groups or regions of the sphere are carrying energy?
- Can a human identify a specific channel quickly when something is wrong?

## Current Orbisonic Meter Baseline

Orbisonic currently has two meter shapes:

- `LiveSurroundVUView`: older horizontal scrolling bar meters. Good for obvious low channel counts, but too wide for dense renderer outputs.
- `DenseVUMeterPanel`: newer compact Canvas meter surface used for input, monitor, and renderer views.

The dense meter currently:

- Uses `ChannelMeterStore` as the UI-facing model: each channel has a `SurroundChannel` plus normalized `level` from `0...1`.
- Sorts meters by `SurroundChannelRole.displayOrder`, then channel index.
- Shows compact summary pills for total channels, active channels, and hot channels.
- Uses `TimelineView(.animation)` and `Canvas` for animated rendering.
- Offers four styles: `Square Pulse`, `Square Flicker`, `Hex Pulse`, and `Hex Flicker`.
- Computes adaptive square or hex cell grids that optimize cell size within the available panel.
- Hides per-cell labels when cells are too small.
- Uses level thresholds roughly as semantic bands:
  - low: cyan
  - medium: blue
  - hot: amber above about `0.72`
  - clip/near-clip: red above about `0.90` to `0.96`
- Uses real signal data. Live input levels come from RMS over captured buffers; renderer levels are projected through `rendererScene.matrix.gains`, so the renderer meter reflects current output topology rather than a decorative pattern.

This webapp should preserve those principles, then go broader: more layouts, more pulse systems, richer labeling, better high-count abstraction, and settings export.

## Product Shape

Name placeholder: `Orbisonic Meter Lab`.

Recommended implementation target:

- Standalone Vite + React + TypeScript app.
- Canvas 2D renderer for the meter surface.
- No dependency on the old archived Orbisonic web prototype.
- State stored in browser local storage while editing.
- Export/import as JSON.
- Optional static deployment later, but local dev is enough for the first build.

The first screen should be the actual lab, not a landing page.

## Primary Layout

Use a dense technical interface in the Orbisonic app-family style:

- Dark glass background.
- Compact labels.
- Cyan as the primary accent.
- Blue for mid-level signal.
- Amber for hot signal.
- Red for clip/near-clip.
- Restrained dashboard density.
- Radius no larger than `8px` for panels and controls.
- No decorative blobs, oversized marketing hero sections, or explanatory feature panels.

Screen regions:

- Left control rail: channel count, channel preset, label mode, layout, motion style, thresholds, color mode, signal simulation.
- Center meter stage: large live preview with responsive aspect controls.
- Right inspector: selected channel/group details, label editor, JSON preview, export/import.
- Bottom strip: compact preset thumbnails for fast A/B testing.

The center preview is the priority. Controls should not crowd it.

## Channel Count Behavior

Support exactly `1...64` channels.

Use explicit presets:

- `1.0 Mono`
- `2.0 Stereo`
- `4.0 Quad`
- `5.1`
- `7.1`
- `7.1.4`
- `9.1.6`
- `30.1 Sonic Sphere`
- `64 Discrete`
- `Custom`

For `1...8`, offer obvious spatial layouts first:

- mono center
- stereo left/right
- quad corners
- 5.1 ring with LFE separated
- 7.1 ring with side/rear distinction

For `9...64`, prioritize compact abstract layouts over literal speaker placement. At these counts, the user needs signal topology and anomaly detection more than exact geometry.

## Layout Families

Each layout family must define:

- cell positions in normalized `0...1` preview coordinates
- hit regions for hover/select
- label anchor policy
- group boundaries or guide marks
- high-count compaction behavior
- optional animation propagation metadata

### Adaptive Grid

Baseline utilitarian view.

- Square cells.
- Finds best rows/columns for the panel aspect ratio.
- Best for exact channel lookup and exports that need predictable positions.
- Label strategy: show short labels when cell size permits; otherwise show labels on hover/selection only.

### Hex Hive

Direct successor to current `Hex Pulse` / `Hex Flicker`.

- Honeycomb packing.
- Dense, compact, less grid-like than squares.
- Good default for `16...64`.
- Label strategy: show labels above a minimum cell radius; otherwise use group gutters and hover labels.

### Sphere Rings

Abstract Sonic Sphere view.

- Channels arranged in nested rings by elevation or group.
- Low-numbered/default surround channels can sit on the inner ring; high discrete channels fill outer rings.
- LFE channels sit on a small isolated bass node or bottom rail.
- Good for visually conveying "inside a sphere" without pretending to be a full 3D renderer.

### Subway Sphere Map

Most important new exploration mode.

Goal: make high channel counts readable like a transit map, not like 64 tiny LEDs.

- Channels are stations.
- Groups are colored route lines.
- Lines can represent rings, elevation bands, renderer output zones, or user-defined groups.
- Energy travels as glow along route segments, with station nodes pulsing at channel level.
- Active routes subtly brighten; hot stations get amber halos; clips get red station rings.
- Supports labels outside the densest node cluster using short leader lines.
- Good for Sonic Sphere because a sphere layout can become legible as bands, routes, and transfer nodes.

Default subway route concepts:

- `Front Arc`
- `Side Arc`
- `Rear Arc`
- `Upper Ring`
- `Middle Ring`
- `Lower Ring`
- `LFE / Sub`
- `Discrete Extension`

### Spiral Numbering

Useful for physical Sonic Sphere layouts where channel numbering spirals around rings.

- Places channels along a compact spiral from center outward or bottom-to-top.
- Highlights sequence direction.
- Good for setup/debugging when a tech is walking channel numbers.

### Orbit Lanes

Good for animated "where is energy moving?" views.

- Channels sit on two to six elliptical lanes.
- Motion pattern can send comet highlights around each lane.
- Stronger channels enlarge station nodes instead of making the whole lane noisy.

### Micro Bars

Compact fallback for users who still want traditional VU language.

- Tiny vertical bars in grouped lanes.
- Supports peak hold ticks.
- Works well for exact level comparison but is less visually distinctive.

## Motion And Pulse Patterns

Motion must help scanning. It should not make silent channels look active.

Every motion pattern should use the same normalized input:

```text
channel.level: 0...1
channel.peakHold: 0...1 optional
channel.isClipping: boolean optional
channel.isMuted: boolean optional
channel.groupId: string optional
timeSeconds: number
```

Pattern options:

- `solidPulse`: current-style inner shape grows with level.
- `flickerPixels`: noisy block flicker weighted by level.
- `ripple`: radial or station ripple that only appears on active channels.
- `railGlow`: subway-line glow propagates between active stations.
- `signalTrain`: small packets move along route lines, with packet opacity derived from nearby channel levels.
- `breathingField`: slow synchronized group pulse for sustained energy.
- `cometOrbit`: orbit-lane highlight that speeds up with group energy.
- `peakHoldTick`: traditional peak marker layered over any layout.
- `clipLatch`: short red latch/ring when a channel crosses clip threshold.
- `silenceFade`: channels below active threshold remain visible but desaturated.

Expose motion controls:

- speed
- decay
- intensity
- shimmer/noise amount
- peak hold duration
- clip latch duration
- group sync vs per-channel phase
- reduced motion mode

## Labeling

The user must be able to choose and edit channel labels.

Label modes:

- `Auto`: surround labels where known, otherwise `CH1...CH64`.
- `Numbers`: `1...64`.
- `Short Roles`: `FL`, `FR`, `C`, `LFE`, `SL`, etc.
- `Long Roles`: `Front Left`, `Front Right`, etc.
- `Sphere Outputs`: `S1...S30`, `LFE`.
- `Custom`: editable table.

Label controls:

- show/hide labels
- minimum cell size for inline labels
- selected-only labels
- hover labels
- group labels
- label density: low / medium / high
- label collision avoidance for map-style layouts
- custom label import/export via pasted CSV text

For high channel counts, labels should become contextual rather than always visible. The preview should make it possible to identify a channel by hover/selection even when inline labels are hidden.

## Data Model

Keep exported settings separate from live audio data. The JSON describes how to render meters, not current meter values.

All exported `channel` values are one-based user-facing channel numbers: `1` means the first channel shown to the operator, and `64` means the sixty-fourth channel. Implementation code may use zero-based arrays internally, but the JSON should not expose zero-based channel indices.

Top-level shape:

```json
{
  "schema": "orbisonic.vuMeterDesign",
  "version": 1,
  "name": "Sonic Sphere Subway Map",
  "channelCount": 31,
  "channelPreset": "sonicSphere30Point1",
  "layout": {},
  "labels": {},
  "groups": [],
  "colors": {},
  "motion": {},
  "thresholds": {},
  "rendering": {},
  "metadata": {}
}
```

Required settings:

- `schema`
- `version`
- `name`
- `channelCount`
- `layout.kind`
- `motion.kind`
- `thresholds.active`
- `thresholds.hot`
- `thresholds.clip`

Optional but recommended:

- channel label overrides
- group definitions
- user notes
- preview aspect ratio
- reduced motion fallback
- creation app/version metadata

## Export JSON Example

```json
{
  "schema": "orbisonic.vuMeterDesign",
  "version": 1,
  "name": "Sonic Sphere Subway Map",
  "channelCount": 31,
  "channelPreset": "sonicSphere30Point1",
  "layout": {
    "kind": "subwaySphereMap",
    "density": "compact",
    "routeMode": "sphereBands",
    "labelPlacement": "outsideWithLeaders",
    "lfePlacement": "bottomRail",
    "showGroupGuides": true
  },
  "labels": {
    "mode": "sphereOutputs",
    "showInline": true,
    "minInlineCellSize": 34,
    "showOnHover": true,
    "overrides": [
      { "channel": 31, "label": "LFE", "longLabel": "Low Frequency Effects" }
    ]
  },
  "groups": [
    { "id": "front", "name": "Front Arc", "channels": [1, 2, 3, 4, 5], "color": "#5EEAD4" },
    { "id": "side", "name": "Side Arc", "channels": [6, 7, 8, 9, 10], "color": "#60A5FA" },
    { "id": "rear", "name": "Rear Arc", "channels": [11, 12, 13, 14, 15], "color": "#A78BFA" },
    { "id": "upper", "name": "Upper Ring", "channels": [16, 17, 18, 19, 20], "color": "#22D3EE" },
    { "id": "lower", "name": "Lower Ring", "channels": [21, 22, 23, 24, 25, 26, 27, 28, 29, 30], "color": "#38BDF8" },
    { "id": "lfe", "name": "LFE / Sub", "channels": [31], "color": "#FACC15" }
  ],
  "colors": {
    "background": "#071014",
    "panel": "rgba(255,255,255,0.045)",
    "line": "rgba(217,251,255,0.14)",
    "low": "#5EEAD4",
    "mid": "#60A5FA",
    "hot": "#FACC15",
    "clip": "#FB7185",
    "muted": "#4B6268"
  },
  "motion": {
    "kind": "railGlow",
    "speed": 0.72,
    "intensity": 0.86,
    "decay": 0.62,
    "noise": 0.18,
    "peakHoldMs": 900,
    "clipLatchMs": 1400,
    "phaseMode": "groupSynced",
    "reducedMotionFallback": "solidPulse"
  },
  "thresholds": {
    "active": 0.005,
    "hot": 0.72,
    "clip": 0.96
  },
  "rendering": {
    "showSummaryPills": true,
    "showActiveCount": true,
    "showHotCount": true,
    "showPeakHold": true,
    "pixelSnap": true
  },
  "metadata": {
    "createdBy": "Orbisonic Meter Lab",
    "notes": "Compact transit-map meter for 30.1 renderer output."
  }
}
```

## Simulator

The webapp needs a useful signal simulator so designs can be judged without live audio.

Simulation modes:

- static manual levels
- pink-noise random activity
- channel walk
- group sweep
- hot-channel fault
- clipped-channel fault
- sparse ambience
- full-scale stress test across all channels
- renderer-style energy spread, where a few input sources light several outputs

Controls:

- play/pause simulation
- seed
- average activity
- dynamics
- channel focus
- fault injection
- snapshot current levels

The simulator exists only for design preview. Exported JSON must not include current simulated levels unless the user explicitly exports a separate demo preset.

## Interaction Details

Expected interactions:

- Click a channel to pin the inspector.
- Hover a channel to show long label, group, current level, peak, and threshold state.
- Drag channels only in custom/manual layouts.
- Multi-select channels for bulk label or group assignment.
- Use keyboard arrows to move selected manual-layout nodes.
- Press a reset control to regenerate layout positions.
- Toggle "operator view" to hide design controls and judge the meter as it would appear in Orbisonic.
- Toggle "small panel view" to preview constrained Orbisonic panel sizes.

Inspector should show:

- channel number
- short label
- long label
- group
- role
- current simulated level
- threshold state
- optional position metadata

## Preset Thumbnails

Include built-in starting points:

- `Orbisonic Hex Flicker`: close to current app behavior.
- `Orbisonic Square Pulse`: close to current square behavior.
- `Sonic Sphere Rings`: elevation/ring inspired view.
- `Subway Sphere Map`: transit map abstraction.
- `Spiral Channel Walk`: numbered setup/debug view.
- `Dense Micro Bars`: practical exact-level fallback.
- `Fault Finder`: labels and hot/clip visibility prioritized.

Each thumbnail should run a tiny deterministic animation so the user can compare motion styles quickly.

## Import

Allow importing:

- previously exported meter design JSON
- simple channel-label CSV

CSV label import format:

```text
channel,label,longLabel,group
1,FL,Front Left,front
2,FR,Front Right,front
31,LFE,Low Frequency Effects,lfe
```

Validation should report:

- invalid channel numbers
- duplicate channel definitions
- labels that are too long for inline display
- missing required JSON fields
- unknown schema version

Do not silently discard imported data.

## Orbisonic Integration Contract

The future native app should be able to consume this design JSON and render it against live meter data.

Runtime data contract:

```ts
type RuntimeChannelLevel = {
  channel: number;
  normalizedLevel: number;
  peakHold?: number;
  isClipping?: boolean;
  isMuted?: boolean;
};
```

The native app remains responsible for:

- channel count
- live normalized levels
- source/monitor/renderer meter selection
- real threshold state if it differs from design defaults
- input, monitor, and renderer distinction

The design JSON controls:

- layout family
- labels
- groups
- colors
- motion
- threshold defaults
- display density

Important: never let the design JSON fake signal. If live audio is silent, the meter should be visually silent.

## Build Plan

1. Scaffold `meter-lab` as a standalone Vite + React + TypeScript app when implementation starts.
2. Define the TypeScript schema types and JSON validation first.
3. Build a deterministic sample-level engine with seedable simulation modes.
4. Build layout generators for adaptive grid, hex hive, sphere rings, subway map, spiral, orbit lanes, and micro bars.
5. Build a single Canvas renderer that accepts generated layout geometry plus runtime levels.
6. Build controls around real state, not one-off component state.
7. Add JSON preview/export/import.
8. Add channel label editor and CSV import.
9. Add preset thumbnails.
10. Add operator-view and small-panel preview modes.
11. Verify at `1`, `2`, `4`, `6`, `8`, `16`, `31`, and `64` channels.

## Acceptance Criteria

- User can select any channel count from `1` through `64`.
- User can switch layout families without losing labels or groups.
- User can edit channel labels and groups.
- User can preview multiple pulse/motion patterns.
- User can export valid settings JSON.
- User can re-import exported JSON and get the same design.
- `1...8` channel layouts are immediately recognizable.
- `31` and `64` channel views remain compact and scannable.
- Subway map mode clearly communicates channel groups and active/hot/clip states.
- Reduced motion mode remains readable.
- The exported JSON contains no local machine paths or personal identifiers.

## Non-Goals

- Do not build live audio capture in the webapp.
- Do not replace Orbisonic's native SwiftUI meter implementation yet.
- Do not use the old archived web prototype as the app foundation.
- Do not export screenshots as the primary artifact.
- Do not make an exact 3D Sonic Sphere renderer; the point is compact meter readability.

## Open Design Questions

- Should Sonic Sphere `30.1` group defaults come from calibration files, renderer output topology, or a separate user-authored grouping preset?
- Should the native app consume the JSON directly, or should the JSON be compiled into Swift-native preset structs during build?
- Should layout positions be deterministic from channel count and preset, or should exported JSON include explicit generated coordinates for perfect repeatability?
- Should the Subway Sphere Map support user-drawn route lines in the first implementation, or start with generated routes only?
