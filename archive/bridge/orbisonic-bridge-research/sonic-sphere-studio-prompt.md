# Sonic Sphere Live Spatial Music Studio — Complete Build Specification

## Overview

Build a single-page web application that is a live spatial music creation tool for the Sonic Sphere audio format. The app is both a synthesizer/sampler and a 3D spatial audio authoring environment. Users load audio into 4 bed channels and 2 spatial objects, position them in a 3D sonic sphere, optionally synthesize sounds, and render the output to various speaker configurations (binaural headphones, 5.1 home theater, or a full 30.1 Sonic Sphere array).

The aesthetic is **dark, minimal, and technical** — think Ableton Live meets a radar display. The 3D view is a **green-on-black wireframe** (classic oscilloscope/military radar aesthetic). The entire UI is dark-mode with green accents, monospace fonts for technical readouts, and clean sans-serif for labels.

**Stack**: React 19 + TypeScript + Vite + Tailwind CSS + shadcn/ui + Three.js (React Three Fiber) + Web Audio API + Tone.js

---

## Architecture

The app has **4 tabs** controlled by a top navigation bar:

1. **MUSIC** — Load and manage audio files for the 4 bed channels and 2 objects
2. **3D SPACE** — Green-on-black wireframe 3D view of the sonic sphere with all speakers and objects
3. **SYNTH** — Built-in synthesizer and tempo/sequencer for the 2 objects
4. **RENDER** — Render output to binaural, 5.1, or 30.1 Sonic Sphere with playback controls

Global state is managed via React Context:
- `AudioContext` — manages all audio playback, Web Audio graph, Tone.js instances
- `SpatialContext` — manages 3D positions, rotations, and animation state for all objects and bed channels
- `ProjectContext` — manages file references, loop settings, start times, tempo

---

## Tab 1: MUSIC

### Layout
Left sidebar (280px wide) with a **master transport** at top (play/pause/stop button, tempo BPM 60-180 slider, global volume fader). Below transport, a list of 6 channel strips stacked vertically.

Each channel strip is a horizontal card containing:
- **Channel label** (BED 1–4 or OBJ A–B) with a colored indicator (bed = cyan, obj = magenta)
- **Waveform display** — a canvas showing the loaded audio waveform (or empty state with "Drop audio file" / "Click to load")
- **Duration display** in MM:SS format
- **Type toggle** — For OBJ A and OBJ B only: a switch between "SAMPLE" and "SYNTH" modes
- **Start time offset** — number input (0.0s) for when this channel begins relative to project start
- **Loop toggle** — For bed channels: always looping. For objects: toggleable.
- **Volume fader** — vertical slider 0-100%
- **Mute/solo buttons**

### Bed Channels (Channels 1–4)
- Fixed at project creation. The longest bed channel defines the project length.
- All bed channels loop seamlessly.
- The 4 bed channels together form the "bed" — ambient/drone/music that fills the space.
- File loading via drag-and-drop or file picker. Accept .wav, .mp3, .ogg, .flac.
- Bed channels display their waveform once loaded.

### Object Channels (OBJ A, OBJ B)
- Each object has a type toggle: **SAMPLE** (audio file) or **SYNTH** (generated sound)
- In SAMPLE mode: same file loading as beds. Duration must be <= project length. Has start time offset.
- In SYNTH mode: the SYNTH tab defines the sound. The MUSIC tab shows "SYNTH" badge instead of waveform.
- Objects also have a **POSITION AUTOMATION** button that opens the path editor in the 3D SPACE tab.

### Transport
- **Play/Pause** button (Space bar hotkey)
- **Stop** button (returns to start)
- **BPM** slider: 60–180 BPM
- **Master Volume**: 0–100% fader
- **Current Time**: MM:SS.mmm display showing playback position
- **Project Length**: derived from the longest bed channel

---

## Tab 2: 3D SPACE

This is the visual heart of the application. A **full-viewport 3D scene** rendered with React Three Fiber.

### Aesthetic
- **Background**: pure black (#000000)
- **Wireframe color**: bright phosphor green (#00FF41) with 60% opacity for distant lines
- **Accent colors**: 
  - Bed channel indicators: cyan (#00D4FF) 
  - Object A: magenta (#FF00FF)
  - Object B: yellow (#FFFF00)
  - Sphere wireframe: green (#00FF41)
  - Labels: white (#FFFFFF) with dark translucent background
- **Camera**: perspective, positioned at (0, 0, 12) looking at origin. Orbit controls enabled (rotate, zoom, pan).
- **Fog**: subtle dark fog for depth cues

### The Sonic Sphere (Fixed)
- A **wireframe sphere** at the origin with **7-meter diameter** (radius = 3.5)
- Rendered as a geodesic sphere with 3 subdivisions for clean wireframe lines
- Lines are bright green, 1px width, 50% opacity
- A subtle **grid overlay** on the sphere surface showing latitude/longitude lines every 30 degrees
- **Compass labels** around the sphere: "F" (front, +Z), "R" (right, +X), "B" (back, -Z), "L" (left, -X), "TOP" (+Y), "BOTTOM" (-Y)
- The sphere does NOT move — it is the fixed reference.

### Bed Channel Positions (4 Channels)
The 4 bed channels are represented as **small speaker icons** (cyan wireframe cones) positioned on the surface of the sphere. Default positions:

- **BED 1**: Front-Left-High at azimuth -45deg, elevation +30deg
- **BED 2**: Front-Right-High at azimuth +45deg, elevation +30deg  
- **BED 3**: Rear-Right-Low at azimuth +135deg, elevation -15deg
- **BED 4**: Rear-Left-Low at azimuth -135deg, elevation -15deg

Each bed speaker shows:
- A cyan wireframe cone pointing outward from sphere center
- A label "B1", "B2", "B3", "B4" floating above it
- A small dot at the exact speaker position on the sphere surface
- When audio plays through it: the cone pulses/glows brighter proportional to amplitude

**Bed Channel Controls** (right-side panel, 260px wide):
Each bed channel has a control group:
- **Elevation slider**: -90deg to +90deg (moves the speaker up/down relative to the sphere)
- **Rotate Z (azimuth) slider**: 0deg to 360deg (rotates around vertical axis)
- **Rotate Y (tilt) slider**: -45deg to +45deg (tilts the speaker pair forward/back)
- **RESET** button: returns to default position
- Visual feedback: speaker moves in real-time as sliders change

### Object Positions (2 Objects)

Objects are represented as **glowing orbs** that can move freely inside and around the sphere:
- **OBJ A**: magenta orb (default radius 0.15m), with a trail showing recent path
- **OBJ B**: yellow orb (default radius 0.15m), with a trail showing recent path

Each object has:
- A glowing orb mesh (slightly larger when louder)
- A **motion trail** — a fading line showing the last N positions (green, fading opacity)
- A label "A" or "B" floating above

**Object Control Panel** (right-side panel, below bed controls):
Each object has its own section:

#### Movement Mode Selector
Radio buttons for movement mode:
1. **MANUAL** — Click-drag in 3D space to position. Position held until moved again.
2. **ORBIT** — Object orbits around a defined axis at adjustable speed.
3. **UP-DOWN** — Object oscillates vertically (elevation sine wave).
4. **THROUGH CENTER** — Object moves along a line passing through sphere center (front to back, or any defined axis).
5. **PATH** — Object follows a user-drawn 3D path that loops.

#### Per-Mode Controls

**MANUAL mode:**
- X, Y, Z coordinate inputs (range: -3.5 to +3.5, matching sphere radius)
- "Center" button (snaps to origin)
- "Surface" button (snaps to sphere surface at current angle)

**ORBIT mode:**
- Center point: X, Y, Z inputs (default: 0, 0, 0)
- Radius slider: 0.5m to 3.5m
- Speed: 0.1 to 10 RPM
- Axis selector: XY plane, XZ plane, YZ plane, or custom (defined by 2 angles)
- Tilt: -90 to +90 degrees for the orbital plane
- Direction: clockwise / counter-clockwise toggle
- Phase offset: 0 to 360 degrees

**UP-DOWN mode:**
- Center elevation: -45 to +45 degrees
- Amplitude: 0 to 90 degrees (how far up/down from center)
- Speed: 0.1 to 10 cycles per minute
- Phase offset: 0 to 360 degrees

**THROUGH CENTER mode:**
- Axis azimuth: 0 to 360 degrees (which horizontal direction)
- Axis elevation: -45 to +45 degrees (tilt from horizontal)
- Speed: 0.1 to 10 crossings per minute
- Pause at endpoints: 0 to 2 seconds

**PATH mode:**
- "Record Path" button: while held, object movement (manual drag) is recorded as a keyframe path
- "Stop Recording" button: finalizes the path
- Path smoothness: slider controlling interpolation between keyframes (linear to smooth bezier)
- Speed: 0.1 to 10 loops per minute
- "Show Path" toggle: displays the recorded path as a green wireframe curve
- "Clear Path" button

#### Movement Triggers
- **"Movement On/Off"** toggle for each object — enables/disables the animation while audio plays
- **"Sync to Tempo"** toggle — when on, movement speed is quantized to the project BPM (1/1, 1/2, 1/4, 1/8 note options)

### 3D Scene Interaction
- **Click and drag** on empty space: rotate camera (orbit controls)
- **Scroll**: zoom in/out
- **Right-click drag**: pan camera
- **Click on object**: select it (shows selection ring, updates right panel)
- **Drag object**: in MANUAL mode, reposition it in 3D
- **Double-click**: reset camera to default view
- **Grid floor**: a subtle reference grid on the Y=-3.5 plane (bottom of sphere) for spatial reference
- **Axis helper**: small X/Y/Z axis indicator in bottom-left corner

---

## Tab 3: SYNTH

A dedicated synthesizer and sequencer panel for when objects are set to SYNTH mode.

### Layout
Split view: left side has **synth controls** for the selected object (OBJ A or OBJ B toggle at top), right side has a **step sequencer**.

### Synth Engine (Tone.js)
Each object gets an independent synth with these controls:

**Oscillator Section:**
- Waveform selector: Sine, Triangle, Sawtooth, Square
- Detune: -100 to +100 cents
- Width/Pulse Width: for square wave (0-100%)

**Filter Section:**
- Filter type: Lowpass, Highpass, Bandpass
- Cutoff: 20Hz to 20kHz with log scale
- Resonance: 0 to 20dB
- Filter envelope: Attack (0-2s), Decay (0-2s), Sustain (0-100%), Release (0-5s)

**Amplitude Envelope:**
- Attack: 0-5 seconds
- Decay: 0-5 seconds  
- Sustain: 0-100%
- Release: 0-10 seconds

**Effects (per object):**
- Reverb: amount (0-100%), room size (0-100%), decay (0.1-10s)
- Delay: time (1/32 to 2 beats), feedback (0-90%), mix (0-100%)
- Chorus: rate (0.1-20Hz), depth (0-100%), mix (0-100%)

### Step Sequencer
A 16-step grid for triggering the synth:
- **16 step buttons** per row, 4 rows (pitch, velocity, filter cutoff, probability)
- **Tempo**: synced to global BPM
- **Playback indicator**: moving highlight showing current step
- **Randomize** button per row: fills row with random values
- **Clear** button per row
- **Scale quantize**: dropdown (Major, Minor, Dorian, Phrygian, Chromatic, Pentatonic)
- **Octave range**: -2 to +2
- Steps can be individually toggled on/off

### Pattern Storage
- 8 **pattern slots** per object (save/load)
- Pattern selector: 1-8 buttons
- "Copy" and "Paste" between patterns

---

## Tab 4: RENDER

The rendering output stage. This tab controls how the 6 audio sources (4 bed + 2 objects) are spatially rendered to the output device.

### Layout
Left panel: **Output Configuration** (300px). Right area: **VU Meters and Visualizer**.

### Output Modes
Three renderer configurations selectable via large toggle buttons:

#### 1. BINAURAL (Headphones)
- HRTF-based binaural rendering using Web Audio API's `PannerNode` with HRTF panning model
- Objects are positioned in 3D space using the PannerNode's positionX/Y/Z
- Bed channels are mixed down to stereo with their spatial position encoded as HRTF direction
- Controls:
  - Head size selector: Small / Medium / Large (affects HRTF)
  - Crossfade mix: Dry (original) to Wet (fully spatialized)

#### 2. HOME 5.1 (6 channels)
- Traditional 5.1 surround output
- Channel mapping: L, R, C, LFE, Ls, Rs
- Bed channels are mapped to the 5.1 speaker array using VBAP-style amplitude panning
- Objects are panned using the 5 speaker positions using VBAP triangulation
- Speaker layout diagram showing 5 speakers in standard ITU-R BS.775-3 positions
- Per-channel VU meters

#### 3. SONIC SPHERE 30.1 (31 channels)
- Full-sphere rendering to 30 speakers + 1 LFE
- Speaker positions: approximately equally distributed on a sphere surface using a spherical Fibonacci lattice algorithm for near-uniform distribution
- VBAP triangulation: for each object, find the 3 nearest speakers and compute gain using the VBAP matrix equation g = L^(-1) * p
- Bed channels are also spatially rendered using the same VBAP algorithm
- Speaker layout diagram: small dots on a sphere showing all 31 speaker positions, with gain indicators (brightness = current gain)
- LFE channel: derived from all sources below 120Hz

### Visualizer
- **31-channel VU meter array** — vertical bars showing real-time level of each output channel
- **3D speaker visualization** (when in Sonic Sphere mode): same green-on-black wireframe sphere with 30 speaker dots that glow brighter when active
- **Spectrum analyzer**: shows frequency content of the rendered output

### Master Output Controls
- **Render** button: starts real-time rendering (applies spatial processing)
- **Bypass** button: passes audio through without spatial processing (for comparison)
- **Output format**: 44.1kHz / 48kHz selector
- **Bit depth**: 16 / 24 bit selector
- **Export**: "Export as WAV" — renders the spatial mix to a multi-channel WAV file (31 channels for Sonic Sphere mode, 6 for 5.1, 2 for binaural)

### Web Audio Graph Architecture
```
[Bed 1 Source] ──┐
[Bed 2 Source] ──┼──> [Bed Gain/Mix] ──> [Spatial Panner] ──> [Master Gain] ──> [Destination]
[Bed 3 Source] ──┤                                          
[Bed 4 Source] ──┘                                          
                                                            
[Obj A Source] ────> [Obj A Gain] ──> [Spatial Panner A] ──┤
                                                            ├─> [VBAP Renderer] ──> [Speaker Outputs]
[Obj B Source] ────> [Obj B Gain] ──> [Spatial Panner B] ──┘
```

The VBAP Renderer node:
- Takes N input sources with 3D positions
- For each output frame:
  1. Get listener position (origin)
  2. For each source, find 3 nearest speakers (using speaker mesh triangulation)
  3. Compute VBAP gain vector: g = L^(-1) * p
  4. Normalize gains (p-norm, default p=2 for constant power)
  5. Route source audio to the 3 speakers with computed gain
  6. Sum all contributions at each speaker
- Output: M speaker channels (6 for 5.1, 31 for Sonic Sphere, 2 for binaural)

For binaural mode, replace VBAP with HRTF binaural synthesis: each source is convolved with the HRTF for its direction, left and right ear signals summed.

---

## Global Audio Engine

### Tone.js Setup
- Master output is a `Tone.Gain` node connected to `Tone.Destination`
- All bed and object sources feed into their individual gain nodes
- A `Tone.Limiter` at -0.5dB on the master bus prevents clipping
- All audio starts/stops synchronized via `Tone.Transport`

### Spatial Audio Engine
- Custom `SpatialRenderer` class manages the VBAP calculation
- Speaker mesh: precomputed Delaunay triangulation of the speaker positions
- Per-frame update: positions are interpolated for smooth movement
- For 30.1 mode: 30 speakers + 1 LFE, positions stored as unit vectors

### File Loading
- Uses `Tone.Player` for each audio file
- Waveform visualization via Web Audio `AnalyserNode` + canvas rendering
- Files loaded via `URL.createObjectURL()` for drag-and-drop

---

## UI Design System

### Color Palette
| Role | Color | Hex |
|------|-------|-----|
| Background (main) | Near-black | #0A0A0F |
| Background (panel) | Dark gray | #12121A |
| Background (input) | Slightly lighter | #1A1A24 |
| Primary accent | Phosphor green | #00FF41 |
| Bed channel | Cyan | #00D4FF |
| Object A | Magenta | #FF00FF |
| Object B | Yellow | #FFFF00 |
| Text primary | White | #FFFFFF |
| Text secondary | Gray | #888899 |
| Text muted | Dark gray | #555566 |
| Border | Subtle gray | #222233 |
| Danger/Stop | Red | #FF4444 |
| Play/Active | Green | #00FF41 |

### Typography
- **Labels and UI text**: Inter, 12-14px, weight 400-500
- **Technical readouts** (coordinates, times): JetBrains Mono or similar monospace, 11-13px
- **Section headers**: Inter, 16-18px, weight 600
- **Tab labels**: Inter, 13px, weight 600, uppercase, letter-spacing 0.08em

### Component Style
- All panels: background #12121A, border 1px solid #222233, border-radius 6px
- Sliders: custom styled, green track with white thumb
- Buttons: 
  - Default: bg #1A1A24, border #222233, text #888899, hover bg #222233
  - Primary: bg #00FF41, text #000000, hover bg #33FF66
  - Danger: bg #FF4444, text #FFFFFF
- Toggle switches: green when on, gray when off
- Inputs: dark background, green border on focus, monospace font for numeric values
- Scrollbars: thin, dark track, green thumb

### Animations
- Tab switches: 150ms fade transition
- 3D object movement: smooth interpolated motion (no jumps)
- VU meters: fast response, 60fps
- Play button pulse: subtle green glow when playing

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Space | Play/Pause |
| Escape | Stop |
| 1 | Switch to MUSIC tab |
| 2 | Switch to 3D SPACE tab |
| 3 | Switch to SYNTH tab |
| 4 | Switch to RENDER tab |
| M | Toggle mute for selected channel |
| S | Toggle solo for selected channel |
| Delete | Clear selected channel's file |
| R | Toggle recording for path mode |
| +/- | Zoom in/out in 3D view |
| 0 | Reset camera in 3D view |

---

## Default State / First Load

On first load, the app shows:
- MUSIC tab active
- All 6 channels empty (showing "Drop audio file or click to load" placeholders)
- 3D SPACE tab: sphere visible with default bed/object positions
- SYNTH tab: default synth settings (sine wave, basic envelope)
- RENDER tab: BINAURAL mode selected, render not active
- A **demo project** can be loaded via "Load Demo" button that creates simple synthesized tones for all 6 channels with basic orbiting animation

---

## Responsive Behavior

- Minimum supported width: 1280px (desktop only — this is a pro audio tool)
- The 3D view fills available space; panels collapse to icons at smaller widths
- On screens < 1400px, the side panels in 3D SPACE tab can be collapsed with a toggle button
- The 3D canvas always maintains aspect ratio and fills its container

---

## File Structure

```
src/
  main.tsx                          — Entry point
  App.tsx                           — Root component with tab router
  index.css                         — Global styles, Tailwind
  components/
    layout/
      TabBar.tsx                    — Top tab navigation (1-4)
      Transport.tsx                 — Master transport (play/stop/BPM/volume)
      Sidebar.tsx                   — Collapsible side panel
    music/
      MusicTab.tsx                  — MUSIC tab container
      ChannelStrip.tsx              — Individual channel strip (bed or obj)
      WaveformDisplay.tsx           — Canvas waveform visualizer
      FileDropZone.tsx              — Drag-and-drop file loader
    spatial/
      SpatialTab.tsx                — 3D SPACE tab container
      SphereView.tsx                — React Three Fiber 3D canvas
      SonicSphere.tsx               — Wireframe sphere mesh
      BedSpeaker.tsx                — Speaker cone mesh + label
      ObjectOrb.tsx                 — Glowing orb mesh + trail
      ControlPanel.tsx              — Right-side control panel
      BedControls.tsx               — Bed channel rotation controls
      ObjectControls.tsx            — Object movement controls
    synth/
      SynthTab.tsx                  — SYNTH tab container
      SynthEngine.tsx               — Tone.js synth wrapper
      EnvelopeControls.tsx          — ADSR sliders
      FilterControls.tsx            — Filter section
      EffectsControls.tsx           — Reverb/Delay/Chorus
      StepSequencer.tsx             — 16-step grid
      PatternSelector.tsx           — Pattern save/load
    render/
      RenderTab.tsx                 — RENDER tab container
      OutputSelector.tsx            — Binaural/5.1/30.1 toggle
      VUMeter.tsx                   — Single channel VU meter
      VUMeterArray.tsx              — Array of VU meters
      SpectrumAnalyzer.tsx          — FFT spectrum display
      SpeakerVisualizer.tsx         — 3D speaker activity view
      ExportPanel.tsx               — WAV export controls
    ui/
      Slider.tsx                    — Custom styled range slider
      Knob.tsx                      — Rotary knob control
      Toggle.tsx                    — On/off toggle switch
      Button.tsx                    — Styled buttons
      Input.tsx                     — Numeric/text input
      Select.tsx                    — Dropdown selector
      Panel.tsx                     — Bordered panel container
  hooks/
    useAudioContext.ts              — Web Audio / Tone.js management
    useSpatialContext.ts            — 3D positions and animation
    useProjectContext.ts            — Project settings and files
    useVBAP.ts                      — VBAP calculation engine
    useBinauralRenderer.ts          — HRTF binaural rendering
    useAnimationFrame.ts            — Smooth animation loop
    useKeyboardShortcuts.ts         — Global keyboard handler
  types/
    index.ts                        — All TypeScript types/interfaces
  utils/
    vbap.ts                         — VBAP math (matrix inversion, triangulation)
    hrtf.ts                         — HRTF lookup/filtering
    spherical.ts                    — Spherical coordinate conversions
    audio.ts                        — Audio buffer utilities
    fibonacci.ts                    — Fibonacci sphere speaker placement
```

---

## Technical Notes

### VBAP Implementation
- Speaker triangulation uses Delaunay triangulation on the unit sphere
- Matrix inversion for 3x3 speaker vector base: compute gains for any source direction
- For 5.1 mode: speaker positions are L(+30,0), R(-30,0), C(0,0), Ls(+110,0), Rs(-110,0) in azimuth/elevation
- For 30.1 mode: 30 speakers placed via spherical Fibonacci lattice for near-uniform coverage, plus LFE

### HRTF for Binaural
- Use Web Audio API's built-in `PannerNode` with `panningModel = 'HRTF'`
- Each object gets its own PannerNode positioned in 3D
- Bed channels: compute average direction vector, apply to single PannerNode per bed channel
- The `distanceModel` should be `'inverse'` with appropriate refDistance

### Performance
- 3D scene: target 60fps with <100 draw calls
- Audio processing: maintain stable 128-sample buffer, no dropouts
- Use `requestAnimationFrame` for visual updates, synced to audio clock
- Tone.js `Draw.schedule` for frame-accurate visual synchronization

### Data Model
```typescript
interface Project {
  bpm: number;
  length: number;           // seconds, derived from longest bed
  masterVolume: number;
  bedChannels: BedChannel[4];
  objects: ObjectChannel[2];
  renderMode: 'binaural' | '5.1' | 'sonicsphere';
}

interface BedChannel {
  id: string;               // 'B1', 'B2', 'B3', 'B4'
  audioFile: File | null;
  buffer: AudioBuffer | null;
  volume: number;
  muted: boolean;
  position: SphericalPosition;
  rotationZ: number;        // azimuth rotation
  rotationY: number;        // tilt
  elevation: number;        // up/down movement
}

interface ObjectChannel {
  id: string;               // 'A' or 'B'
  type: 'sample' | 'synth';
  audioFile: File | null;
  buffer: AudioBuffer | null;
  volume: number;
  muted: boolean;
  startTime: number;        // offset in seconds
  position: Vector3;        // current position in 3D space (meters)
  movementMode: 'manual' | 'orbit' | 'updown' | 'through' | 'path';
  movementParams: MovementParams;
  movementEnabled: boolean;
  syncToTempo: boolean;
  synth: SynthSettings;
  sequencer: SequencerPattern;
}

interface SphericalPosition {
  azimuth: number;          // 0-360 degrees
  elevation: number;        // -90 to +90 degrees
  distance: number;         // 0 to 3.5 meters (sphere radius)
}

interface Vector3 {
  x: number;
  y: number;
  z: number;
}
```
