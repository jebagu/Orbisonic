# Sonic Sphere Renderer — Desktop Playback Application

## Purpose

Build a desktop application that can open, parse, and play **Sonic Sphere BW64 files** (`.ssb` extension — ADM BW64 files with Sonic Sphere extensions). The renderer takes a spatial audio composition (4 bed channels + 2 moving objects with 3D position metadata) and renders it in real-time to the listener's playback device: headphones (binaural), a 5.1 surround system, or a full 30.1 Sonic Sphere array.

This is a **playback/renderer tool**, not a creation tool. Think VLC for spatial audio — drop a file, pick an output mode, press play. The 3D view is for visualization only (to see where sound is coming from), not for editing.

---

## Supported File Format

### Primary: Sonic Sphere BW64 (`.ssb`)

A RIFF/WAVE file with the following structure:

```
[WAVE header]
  <ds64>          — 64-bit addressing (ITU-R BS.2088)
  <fmt-ck>        — PCM, 48kHz, 24-bit, 6 tracks (interleaved)
  <chna>          — Channel allocation table (ITU-R BS.2076)
                      Track 1: BED1 (DirectSpeakers)
                      Track 2: BED2 (DirectSpeakers)
                      Track 3: BED3 (DirectSpeakers)
                      Track 4: BED4 (DirectSpeakers)
                      Track 5: Object A (Objects)
                      Track 6: Object B (Objects)
  <axml>          — ADM XML (ITU-R BS.2076) containing:
                      - audioProgramme (project metadata)
                      - 4 x audioObject → audioChannelFormat (DirectSpeakers, fixed positions)
                      - 2 x audioObject → audioChannelFormat (Objects, animated positions)
                      - audioBlockFormat with time-varying position data
                      - Sonic Sphere extensions (JSON in <extension> element)
  <data>          — Interleaved 6-channel PCM audio samples
```

### Secondary: Standard ADM BW64 (`.bw64`, `.adm`)

Any standards-compliant ADM BW64 file that conforms to ITU-R BS.2076/2088. The renderer must handle standard ADM files that lack Sonic Sphere extensions — it will use default positions for objects and a default 7.1.4 speaker layout for beds.

### Tertiary: Standard ADM BWF (`.wav` with `axml` chunk)

Standard Broadcast Wave Files containing ADM XML in the `axml` chunk. Limited to 4GB due to the 32-bit RIFF size field (no `ds64` chunk).

---

## Core Rendering Pipeline

The renderer must implement this exact signal flow:

```
[Audio File] → [libbw64 reader] → [libadm parser]
    │
    ├──→ Track 1-4 (Bed Channels)
    │       ├──→ Parse DirectSpeakers position (azimuth, elevation, distance)
    │       ├──→ Parse optional Sonic Sphere bed offsets (elevation, rotateZ, rotateY)
    │       └──→ Route to VBAP renderer with fixed position
    │
    ├──→ Track 5-6 (Object Channels)
    │       ├──→ Parse Object position path (audioBlockFormat with rtime timestamps)
    │       ├──→ Interpolate position at current playback time
    │       ├──→ Parse Sonic Sphere movement extensions (orbit, path, etc.)
    │       └──→ Route to VBAP renderer with animated position
    │
    └──→ [VBAP Gain Calculator]
            ├──→ For each source, find 3 nearest speakers (Delaunay triangulation)
            ├──→ Compute gain vector: g = L⁻¹ · p
            ├──→ Normalize: p-norm with p=2 (constant power)
            └──→ Distribute source audio to 3 speakers with computed gains
                    │
                    ├──→ BINAURAL mode (2ch):
                    │       └──→ HRTF convolution per source → sum L/R → headphone output
                    │
                    ├──→ 5.1 mode (6ch):
                    │       └──→ VBAP to L, R, C, LFE, Ls, Rs → multichannel output
                    │
                    └──→ SONIC SPHERE 30.1 mode (31ch):
                            └──→ VBAP to 30 Fibonacci-sphere speakers + LFE
```

### VBAP Algorithm (Required Implementation)

For each audio source at position **p** (unit vector [x, y, z]):

1. **Find the 3 nearest speakers** to **p** using precomputed Delaunay triangulation of the speaker array.
2. **Build the vector base matrix L** (3×3) where each column is a speaker direction vector:
   ```
   L = [l₁ | l₂ | l₃]
   ```
3. **Solve for gain vector g**:
   ```
   g = L⁻¹ · p
   ```
4. **Normalize gains** using p-norm (default p=2 for constant power):
   ```
   gᵢ = gᵢ / (Σ|gⱼ|ᵖ)^(1/p)
   ```
5. **Clamp negative gains to zero** and re-normalize.
6. **Route audio** to the 3 selected speakers with computed gain values.

For sources below the horizon (elevation < 0°), the algorithm is identical — VBAP is direction-agnostic. The presence of floor speakers in the speaker mesh enables natural below-horizon rendering.

### Binaural Rendering (HRTF)

When output mode is **BINAURAL** (headphones):

1. Each source gets its own 3D position (interpolated at block rate, ~100Hz).
2. For each source, compute the direction vector from listener to source.
3. Look up the HRTF pair (left ear filter, right ear filter) for that direction.
   - Use the built-in HRTF database from the operating system (Apple's PHASE framework on macOS, Microsoft's Spatial Audio API on Windows, or MIT KEMAR dataset as fallback).
4. Convolve the source audio with both HRTF filters.
5. Sum all left-ear signals → left output channel.
6. Sum all right-ear signals → right output channel.
7. Apply a light head shadow model (optional): attenuate high frequencies for sources behind the listener.

### LFE Channel Derivation

The Low Frequency Effects (LFE/.1) channel is derived from all 6 sources:
- Apply a 120Hz lowpass filter to each source.
- Sum all filtered signals.
- Apply -10dB gain offset (LFE reference level).
- Send to LFE output channel.

---

## Speaker Configurations

The renderer must support these three output configurations, selectable at runtime:

### Configuration 1: Binaural (2 channels)
- **Output**: Stereo headphone output
- **Method**: HRTF convolution per source
- **Speaker count**: Virtual (2 ears)
- **Use case**: Listening on any headphones
- **Latency**: Low priority (slight HRTF processing delay acceptable)

### Configuration 2: 5.1 Surround (6 channels)
- **Output**: 6 discrete audio channels (L, R, C, LFE, Ls, Rs)
- **Method**: VBAP to physical speaker positions
- **Speaker positions** (ITU-R BS.775-3):
  - L: azimuth +30°, elevation 0°
  - R: azimuth -30°, elevation 0°
  - C: azimuth 0°, elevation 0°
  - Ls: azimuth +110°, elevation 0°
  - Rs: azimuth -110°, elevation 0°
  - LFE: non-directional (subwoofer)
- **Use case**: Home theater systems
- **Device selection**: Must enumerate available audio output devices and let user select the 5.1 device

### Configuration 3: Sonic Sphere 30.1 (31 channels)
- **Output**: 31 discrete audio channels (30 directional + 1 LFE)
- **Method**: VBAP to 30 speakers on a sphere + LFE
- **Speaker positions**: Spherical Fibonacci lattice for near-uniform distribution:
  ```
  For speaker i (0 to 29) on a sphere of radius r:
    theta = 2 * PI * i / goldenRatio    (azimuth)
    phi = acos(1 - 2 * (i + 0.5) / 30)  (polar angle from top)
    x = r * sin(phi) * cos(theta)
    y = r * cos(phi)                     (up is +Y)
    z = r * sin(phi) * sin(theta)
  ```
- **LFE**: Derived from all sources below 120Hz (see above)
- **Use case**: Professional Sonic Sphere installations
- **Device selection**: Must support multichannel audio interfaces (e.g., MOTU, RME, Dante Virtual Soundcard)

### Configuration 4: Stereo Downmix (Bonus)
- **Output**: Standard 2-channel stereo
- **Method**: Lo/Ro downmix matrix
  ```
  Lo = L + (-3dB × C) + (-3dB × Ls)
  Ro = R + (-3dB × C) + (-3dB × Rs)
  ```
- LFE is discarded. Height content folds to ear level at -3dB.
- **Use case**: Fallback when no other output mode is available

---

## User Interface

### Design Philosophy
**Minimal, focused, dark.** The UI is a playback tool, not a DAW. The layout prioritizes the 3D visualization and essential playback controls. Think "spatial audio VLC" not "Pro Tools Lite."

### Color Palette
| Element | Color | Hex |
|---------|-------|-----|
| Background | Near-black | #0A0A0F |
| Panel BG | Dark gray | #12121A |
| Primary accent | Phosphor green | #00FF41 |
| Bed speakers | Cyan | #00D4FF |
| Object A | Magenta | #FF00FF |
| Object B | Yellow | #FFFF00 |
| Text primary | White | #FFFFFF |
| Text secondary | Gray | #888899 |
| Progress bar | Green | #00FF41 |
| Danger/Error | Red | #FF4444 |

### Layout (Single Window)

```
┌─────────────────────────────────────────────────────────────┐
│  [Open File]  Sonic Sphere Renderer          [—] [□] [×]   │
├─────────────┬───────────────────────────────────────────────┤
│             │                                               │
│  TRANSPORT  │                                               │
│             │           3D VISUALIZATION VIEW               │
│  [▶] [■]    │      (green-on-black wireframe sphere)        │
│             │                                               │
│  00:02:14   │      Shows: sphere wireframe, 4 bed          │
│  / 00:05:00 │      speaker positions, 2 moving objects      │
│             │      with trails, active speaker glow         │
│  ■■■■■■□□□  │                                               │
│  progress   │                                               │
│             │                                               │
├─────────────┤                                               │
│  OUTPUT     │                                               │
│  MODE       │                                               │
│             │                                               │
│  ○ Binaural │                                               │
│    (Headph) │                                               │
│             │                                               │
│  ○ 5.1      │                                               │
│    (Surrnd) │                                               │
│             │                                               │
│  ● 30.1     │                                               │
│    (Sphere) │                                               │
│             │                                               │
├─────────────┤                                               │
│  CHANNEL    │                                               │
│  METERS     │                                               │
│             │                                               │
│  BED 1 ████ │                                               │
│  BED 2 ███░ │                                               │
│  BED 3 ░░░░ │                                               │
│  BED 4 ░░░░ │                                               │
│  OBJ A ████ │                                               │
│  OBJ B ███░ │                                               │
│             │                                               │
├─────────────┤                                               │
│  INFO       │                                               │
│             │                                               │
│  File:      │                                               │
│  project.ssb│                                               │
│             │                                               │
│  Tracks: 6  │                                               │
│  Length:    │                                               │
│  5:00       │                                               │
│  Mode:      │                                               │
│  30.1       │                                               │
│             │                                               │
└─────────────┴───────────────────────────────────────────────┘
```

#### Left Panel (280px fixed width, collapsible)

**Transport Section** (top):
- **Open File** button (⌘O) — file picker dialog, filters for `.ssb`, `.bw64`, `.adm`, `.wav`
- **Play/Pause** button (Space) — toggles playback
- **Stop** button (Escape) — stops and returns to start
- **Time display**: current time / total duration (MM:SS format)
- **Progress bar**: draggable scrubber, shows playback position
- **Volume slider**: master output gain, 0–100%

**Output Mode Section**:
- Three radio buttons:
  - **Binaural** (headphones icon) — 2ch HRTF output
  - **5.1 Surround** (speaker icon) — 6ch VBAP output
  - **Sonic Sphere 30.1** (sphere icon) — 31ch VBAP output
- Only available modes are shown based on detected audio hardware:
  - If only stereo output available, show Binaural + Stereo Downmix
  - If multichannel interface detected, show all three + device selector

**Channel Meters Section**:
- 6 vertical bar meters showing real-time level for each source channel
- BED 1–4: cyan bars
- OBJ A: magenta bar
- OBJ B: yellow bar
- Peak hold indicator (decays after 1 second)

**Info Section**:
- Filename
- Track count
- Duration
- Current output mode
- ADM programme name (from metadata)
- Sample rate / bit depth

#### Main Area (3D Visualization)

A **full-viewport 3D wireframe visualization** using the platform's 3D API:

**The Sphere**:
- Wireframe geodesic sphere, radius = 1.0 (unit sphere)
- Green (#00FF41) wireframe lines, 50% opacity
- Latitude/longitude grid lines every 30°
- Compass labels: F (front), R (right), B (back), L (left), TOP, BOTTOM

**Bed Speakers** (4):
- Small cyan wireframe cones at their ADM-specified positions on the sphere surface
- Cone points outward from center
- Label: "B1", "B2", "B3", "B4"
- Glows brighter when audio is present (amplitude-responsive)

**Objects** (2):
- Glowing orbs: magenta for Object A, yellow for Object B
- Radius proportional to audio amplitude
- **Motion trail**: fading line showing the last 5 seconds of movement
- Label: "A", "B"

**Camera**:
- Default position: (0, 0, 3) looking at origin
- Orbit controls: click-drag to rotate, scroll to zoom, right-drag to pan
- Auto-rotate option: slow continuous rotation for showcase

**Active Speaker Visualization** (30.1 mode only):
- 30 small dots on the sphere surface showing speaker positions
- Dots glow green proportional to current gain level
- Creates a visual "constellation" of active speakers

---

## Technical Stack

### macOS (Primary Target)
| Component | Technology | Reason |
|-----------|-----------|--------|
| Language | Swift + Objective-C++ | Native macOS, bridge to EBU C++ libs |
| UI Framework | SwiftUI or AppKit | Native, lightweight |
| 3D Rendering | Metal (MTKView) | Native performance, green wireframe |
| Audio I/O | AVAudioEngine | Real-time graph, multi-channel support |
| Spatial Audio | PHASE framework (macOS 12+) | HRTF for binaural mode |
| ADM Parsing | libadm (C++) via Obj-C++ bridge | Reference implementation |
| BW64 I/O | libbw64 (C++) via Obj-C++ bridge | Reference implementation |
| Gain Calc | libear (C++) via Obj-C++ bridge | ITU reference VBAP renderer |
| File Dialog | NSOpenPanel | Native file picker |
| Audio Device | AVAudioSession + Core Audio | Device enumeration, multi-channel |

### Windows (Secondary Target)
| Component | Technology | Reason |
|-----------|-----------|--------|
| Language | C++17 or C# (.NET 6+) | Native Windows performance |
| UI Framework | WinUI 3 or WPF | Modern Windows UI |
| 3D Rendering | DirectX 11 | Native Windows graphics |
| Audio I/O | WASAPI (low-latency) | Direct hardware access |
| Spatial Audio | Windows Sonic / Spatial Audio API | Built-in HRTF |
| ADM Parsing | libadm (C++) | Reference implementation |
| BW64 I/O | libbw64 (C++) | Reference implementation |
| Gain Calc | libear (C++) | ITU reference VBAP renderer |

### Cross-Platform (Alternative)
| Component | Technology | Reason |
|-----------|-----------|--------|
| Language | C++17 | Portable, direct EBU lib integration |
| UI Framework | Dear ImGui | Lightweight, immediate-mode, audio industry standard |
| 3D Rendering | OpenGL | Cross-platform wireframe rendering |
| Audio I/O | PortAudio or RtAudio | Cross-platform low-latency audio |
| ADM Parsing | libadm (C++) | Reference implementation |
| BW64 I/O | libbw64 (C++) | Reference implementation |
| Gain Calc | libear (C++) | ITU reference VBAP renderer |
| Build | CMake | Cross-platform build system |

---

## File Loading and Parsing Flow

```
1. User selects file via Open dialog
2. Detect file type by extension and content inspection:
   a. Check for RIFF/WAVE magic bytes
   b. Check for ds64 chunk (BW64) vs standard WAVE
   c. Check for axml chunk (ADM metadata)
   d. Check for Sonic Sphere extension signature
3. Open file with libbw64 reader
4. Extract chna chunk → map tracks to ADM format IDs
5. Extract axml chunk → parse with libadm → ADM document tree
6. Read Sonic Sphere extensions (if present) from <extension> element
7. Build internal project representation:
   - Bed channels: extract DirectSpeakers positions
   - Objects: extract position paths (audioBlockFormat with rtime)
   - Duration: determined by longest audio track
   - Sample rate / format: from fmt-ck chunk
8. Preload audio samples into memory (for files < 500MB) or set up streaming
9. Initialize audio engine with appropriate output configuration
10. Update UI with file info and enable playback controls
```

---

## Real-Time Rendering Loop

```
Every audio callback (block size: 512 samples @ 48kHz = 10.7ms):

1. Read current playback time from audio clock

2. For each of the 6 source channels:
   a. Read next 512 audio samples from file (or synthesis buffer)
   b. If channel is an Object (tracks 5-6):
      i.   Interpolate position at current time from audioBlockFormat path
      ii.  If Sonic Sphere movement extensions present, apply them
      iii. Convert position to speaker gains via VBAP
   c. If channel is a Bed (tracks 1-4):
      i.   Use fixed DirectSpeakers position
      ii.  Convert position to speaker gains via VBAP

3. VBAP Gain Calculation (per source):
   a. Get source position unit vector p = [x, y, z]
   b. Find 3 nearest speakers (precomputed triangulation lookup)
   c. Build L matrix from speaker direction vectors
   d. Solve g = L⁻¹ · p
   e. Normalize: gᵢ = gᵢ / ||g||₂
   f. Clamp negative gains to 0, re-normalize

4. Mix sources to output channels:
   a. For each source, multiply samples by gain vector g
   b. Distribute to 3 selected speakers
   c. Sum all contributions at each output channel
   d. Apply master volume

5. Binaural mode special handling:
   a. Instead of speaker distribution, convolve each source with HRTF
   b. Sum left-ear contributions → output channel 0
   c. Sum right-ear contributions → output channel 1

6. LFE derivation:
   a. 120Hz lowpass all sources, sum, -10dB → LFE channel

7. Write output buffer to audio hardware

8. Update visualization (decoupled, ~60fps):
   a. Send current positions to 3D view
   b. Send levels to channel meters
   c. Update progress bar
```

---

## Audio Block Interpolation

ADM `audioBlockFormat` entries have timestamps (`rtime` for start, `duration` for length). The renderer must interpolate object positions between blocks:

```
Given:
  Block N:   rtime = t₁, position = p₁
  Block N+1: rtime = t₂, position = p₂
  Current time: t where t₁ ≤ t < t₂

Interpolation:
  fraction = (t - t₁) / (t₂ - t₁)
  p(t) = p₁ + (p₂ - p₁) × smoothstep(fraction)

smoothstep(x) = 3x² - 2x³  (smooth Hermite interpolation, no discontinuities)
```

If the current time falls outside all defined blocks, use the position of the nearest block (hold last position).

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| File not found | Show error dialog, return to empty state |
| Not a valid RIFF/WAVE | Show error: "Unsupported file format" |
| No axml chunk (not ADM) | Show error: "No ADM metadata found" |
| axml parse error | Show error: "Corrupted ADM metadata" |
| Unsupported audio format | Show error: "Only 48kHz/24-bit PCM supported" |
| Mismatched chna/track count | Show warning, attempt to parse anyway |
| No audio output device | Show error: "No audio output available" |
| Device disconnection during playback | Pause playback, show "Device disconnected" warning |
| Object position out of bounds | Clamp to sphere surface, log warning |
| Missing Sonic Sphere extensions | Use default positions (standard ADM rendering) |

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| ⌘O / Ctrl+O | Open file |
| Space | Play / Pause |
| Escape | Stop |
| ← / → | Seek backward/forward 5 seconds |
| ↑ / ↓ | Volume up/down 5% |
| M | Mute/unmute |
| 1 | Switch to Binaural mode |
| 2 | Switch to 5.1 mode |
| 3 | Switch to 30.1 mode |
| F | Toggle fullscreen 3D view |
| R | Toggle auto-rotate camera |
| 0 | Reset camera to default |
| + / - | Zoom in/out in 3D view |

---

## Performance Requirements

| Metric | Target |
|--------|--------|
| Audio latency | < 15ms (512 samples @ 48kHz) |
| 3D frame rate | 60fps for visualization |
| File load time | < 2 seconds for 5-minute file |
| Memory usage | < 500MB for 30-minute file (streaming) |
| CPU usage | < 15% on modern quad-core processor |
| Supported file size | Unlimited (BW64 streaming for large files) |

---

## Deliverables

1. **Source code** in a public or private Git repository
2. **Build instructions** (README with step-by-step compilation guide)
3. **Pre-built binaries** for macOS (universal: Intel + Apple Silicon)
4. **Example test files**: 2-3 sample `.ssb` files for testing
5. **Documentation**: this specification + user guide

---

## Sample Test Files to Create

The developer should create these test files for validation:

### Test 1: `basic_bed.ssb`
- 4 bed channels, no objects
- Each bed plays a different sustained drone note
- Bed positions: standard corners
- Duration: 30 seconds
- Purpose: Verify bed channel rendering, speaker output

### Test 2: `orbiting_object.ssb`
- 2 bed channels (simple stereo pad), 1 object
- Object orbits horizontally at ear level
- Object plays a bell tone
- Duration: 30 seconds
- Purpose: Verify object animation, VBAP panning, smooth motion

### Test 3: `full_sphere.ssb`
- 4 bed channels (ambient texture)
- Object A: orbits at +45° elevation
- Object B: figure-8 pattern passing through center
- Duration: 60 seconds
- Purpose: Full Sonic Sphere rendering, below-horizon panning, two simultaneous objects

### Test 4: `standard_adm.bw64`
- Standard ADM BW64 file (no Sonic Sphere extensions)
- Standard 7.1.4 bed + 2 objects
- Purpose: Verify compatibility with standard ADM files
