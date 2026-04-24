# Dimension 2: Atmos Objects, OAMD Metadata, and the 3D Panner

## Deep Technical Research Report

**Date:** 2025-07-17
**Topic:** Dolby Atmos Object Audio Metadata (OAMD), 3D Object Structure, Coordinate Systems, Spatial Coding, and 3D Panning
**Search Count:** 16 independent web searches
**Sources:** Dolby whitepapers, SMPTE standards documentation, DAW manufacturer documentation, academic papers, industry technical guides

---

## Table of Contents

1. [Object Structure: Mono/Stereo Signals with OAMD Metadata](#1-object-structure)
2. [OAMD Format: Metadata Fields Specification](#2-oamd-format)
3. [Coordinate System: 3D Position Representation](#3-coordinate-system)
4. [Object Size Parameter: Rendering and Speaker Spread](#4-object-size)
5. [Snap to Speaker Functionality](#5-snap-to-speaker)
6. [The 118 Object Limit and Spatial Coding Clustering](#6-118-limit)
7. [3D Panner Metadata Generation in DAWs](#7-3d-panner)
8. [Real-Time Metadata Interpolation and Smoothing](#8-interpolation)
9. [Static vs Dynamic Objects](#9-static-vs-dynamic)
10. [Key Standards: SMPTE ST 2098-1/2098-2, PMD, ED2](#10-standards)
11. [Summary of Key Findings](#11-summary)
12. [Unresolved Questions and Research Gaps](#12-gaps)
13. [Complete Reference List](#13-references)

---

## 1. Object Structure: Mono/Stereo Signals with OAMD Metadata

### Core Finding: Object = Audio Signal + OAMD Metadata

A Dolby Atmos **object** is fundamentally defined as a mono or stereo audio signal plus associated **Object Audio Metadata (OAMD)** that describes its spatial position and rendering properties.

```
Claim: An Atmos object consists of a mono or stereo audio signal paired with OAMD metadata containing X, Y, Z positional coordinates, size/spread parameters, and optional rendering controls. [^1^][^2^][^3^]
Source: Dolby Atmos Renderer Guide, Wikipedia, Eventide
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Date: 2018-08-02
Excerpt: "Object tracks for a Dolby Atmos mix use mono and stereo signal paths...These tracks provide controls to write automation for Dolby Atmos metadata (pan position, size, and other object metadata) to the track."
Confidence: High
```

### Signal Types and Channel Allocation

Objects can be **mono** or **stereo** (stereo objects consume two of the 128 available channel paths). Each object track sends audio content and spatial positioning information to the renderer. [^4^][^5^]

The 128-channel architecture works as follows:
- **Total channels available:** 128
- **Bed channels:** Up to 10 channels for a 7.1.2 bed (L, R, C, LFE, Lss, Rss, Lsr, Rsr, Tfl, Tfr)
- **Objects available:** Up to 118 mono objects (128 - 10 bed channels)
- **Stereo objects:** Each stereo object consumes 2 of the 118 available slots
- **LFE channel:** Only beds can feed the LFE channel; objects cannot route directly to LFE [^6^]

```
Claim: With a standard 7.1.2 bed, up to 118 objects are available. Each stereo object uses 2 slots. [^7^]
Source: Logic Pro for Mac documentation (Apple)
URL: https://support.apple.com/en-asia/guide/logicpro/lgcp73f9b9ac/mac
Date: Current
Excerpt: "The Dolby Atmos plug-in can have up to 118 objects...A stereo track uses two objects."
Confidence: High
```

### Three Primary Types of Audio Elements in an Atmos Mix

1. **Bed Audio:** Channel-based premixes/stems with multichannel panning (fixed speaker positions)
2. **Object Audio:** Mono or stereo content with dedicated panning metadata
3. **Dolby Atmos Metadata:** Panner automation for objects, plus additional rendering metadata [^8^]

### Object-based Beds (oBeds)

A hybrid technique exists where static objects are used to build a custom "bed." Individual objects are placed at the exact same positions as traditional bed channels, providing the spatial stability of a bed with the additional control that objects provide. [^9^]

---

## 2. OAMD Format: Metadata Fields Specification

### OAMD Defined

**Object Audio Metadata (OAMD)** is the positional and rendering metadata carried alongside audio objects. The term encompasses the full set of parameters that describe how an object should be rendered in 3D space. [^10^][^11^]

```
Claim: OAMD contains positional X, Y, Z panning coordinates recorded along with object size and other rendering parameters. [^12^]
Source: Barry Rudolph - Dolby ATMOS Glossary
URL: https://www.barryrudolph.com/extras/dolby_definitions.html
Excerpt: "OAMD: Object Audio Metadata. Positional X, Y, Z, panning coordinates recorded along with object size."
Confidence: High
```

### OAMD Metadata Fields (Comprehensive List)

Based on SMPTE ST 2098-1, PMD (Professional Metadata) format, and Dolby Atmos documentation, the OAMD metadata fields include:

#### Core Position Fields
| Field | Description | Range | Notes |
|-------|-------------|-------|-------|
| `X_Pos` | Left-Right position | [0,1] or [-1,1] | 0/ -1 = full left; 1/1 = full right |
| `Y_Pos` | Front-Back position | [0,1] or [-1,1] | 0/ -1 = front; 1/1 = back |
| `Z_Pos` | Elevation (height) | [0,1] or [0,1] | 0 = listening plane; 1 = ceiling |

```
Claim: OAMD XYZ coordinates are normalized to the range [0.00, 1.00] in PMD and [−1, 1] in the allocentric cube coordinate system. [^13^][^14^]
Source: Dolby PMD Application Guide
URL: https://datahacker.blog/files/94/Technical/126/Dolby-Professional-MetaData-Guide.pdf
Excerpt: "<X_Pos>0.50</X_Pos><Y_Pos>1.00</Y_Pos><Z_Pos>0.00</Z_Pos>"
Confidence: High
```

#### Size and Spread Fields
| Field | Description | Range | Notes |
|-------|-------------|-------|-------|
| `Size` | Object size (spread from point source) | 0.0 to 1.0+ | 0 = point source; higher = more spread |
| `Size_Vertical` | Enable/disable vertical spread | True/False | Constrains 3D size to 2D disc |
| `ObjectSpreadMode` | Spread dimensionality mode | 0x00, 0x01, 0x02 | 1D, LowRes, or full (per ST 2098-2) |

#### Rendering Control Fields
| Field | Description | Range | Notes |
|-------|-------------|-------|-------|
| `Diverge` | Mirror-image divergence | True/False | Creates symmetric copy at -3dB |
| `SnapToExists` | Snap to nearest speaker | 0 or 1 | Overrides position to nearest speaker |
| `ObjectSnapTolerance` | Priority of timbre vs position | Range | High = snap to speaker for timbre |
| `ObjectDecorCoeff` | Decorrelation coefficient | 0x0 or 0x1 | Controls signal decorrelation between speakers |
| `BinauralRenderMode` | Headphone rendering mode | Off/Near/Mid/Far | Distance model for binaural rendering |

#### Object Classification Fields
| Field | Description | Notes |
|-------|-------------|-------|
| `Class` | Content type (Dialog, VDS, Voiceover, Generic) | Used for conditional routing |
| `DynamicUpdates` | Whether object has intra-frame position updates | True/False |
| `ObjectIdentifier` | Unique object ID | Static for object duration |

#### Gain Fields
| Field | Description | Range |
|-------|-------------|-------|
| `SourceGain` | Source signal gain in dB | Typically 0.00dB |
| `ObjectGain` | Object-specific gain | 0 dB reference |

### Zone Metadata

SMPTE ST 2098-1 defines **zone metadata** for controlling which speaker groups participate in rendering:

- **ZoneControl:** Excludes specified zones from rendering
- **ZoneGain:** Degree to which a zone is included (0 = fully disabled, 1 = fully enabled)
- Zones partition the speaker array into non-overlapping regions (e.g., front, sides, rears, heights) [^15^]

```
Claim: Zone metadata allows mixers to exclude specific speaker groups from rendering individual objects, enabling precise control over which speakers participate in reproducing each object. [^16^]
Source: SMPTE ST 2098-1 Immersive Audio Metadata presentation
URL: https://www.smpte.org/hubfs/2018-08-08-ST-Immersive-Vessa-Handout.pdf
Excerpt: "Zone metadata allows the user to define this for each object. Most panning GUI's will have panning 'modes' that use zone exclusion as part of the panning algorithm, invisible to the user."
Confidence: High
```

### Decorrelation Metadata

SMPTE ST 2098-1 formalizes **decorrelation** as a metadata parameter:

> "The decorrelation metadata item refers to processing the source signals used to reproduce an auditory event to alter their relationship while maintaining the original sound for each individual signal. The minimum value indicates that no decorrelation effect is intended, and the maximum value indicates that the maximum decorrelation effect is intended." [^17^]

This directly controls the perceived diffuseness of the object: correlated signals yield pinpoint localization, while decorrelated signals yield broader, more diffuse images.

### PMD (Professional Metadata) Format

For broadcast workflows, Dolby uses the **PMD** format which includes:

- **Audio Object Description (AOD):** Object definitions with X_Pos, Y_Pos, Z_Pos, Size, Size_Vertical, Diverge, Class, DynamicUpdates
- **Dynamic Position Update (XYZ):** Intra-video-frame position updates at 32-sample increments
- **ED2 Substream Description (ESD):** Transport metadata for Dolby ED2 mezzanine codec [^18^]

---

## 3. Coordinate System: 3D Position Representation

### Allocentric vs. Egocentric Coordinate Systems

Dolby Atmos uses an **allocentric** (environmental) frame of reference rather than an egocentric (observer-relative) one. This was a fundamental design decision documented by Riedmiller and Tsingos of Dolby Laboratories. [^19^]

```
Claim: Dolby Atmos uses an allocentric frame of reference where object positions are defined relative to the room environment, not the listener's head position. [^20^]
Source: AVSForum citing Riedmiller & Tsingos (Dolby Labs), 2015 NCTA Technical Forum
URL: https://www.avsforum.com/threads/atmos-speaker-placement-is-not-necessarily-based-solely-on-angles.3261739/
Excerpt: "An allocentric frame of reference represents (or encodes) an audio object's location using a reference location and direction relative to other objects in the environment. An allocentric reference is better suited for a scene description that is independent of a single observer's position and when the relationship between elements in the environment is of interest."
Confidence: High
```

### Cartesian Room-Normalized Coordinate System

The Dolby Atmos coordinate system is a **Cartesian room-normalized system** defined on a unit cube/hemi-cube:

**SMPTE ST 2098-1 Standard Definition:**
- **X-axis:** Left to Right (left face = 0; right face = 1)
- **Y-axis:** Front to Back (front face = 0; rear face = 1)
- **Z-axis:** Bottom to Top (bottom = 0; top = 1; midpoint = 0.5) [^21^]

**Alternative [-1, 1] representation (from Dolby's allocentric design):**
- **X:** −1 = full left, +1 = full right, 0 = center
- **Y:** −1 = front, +1 = back, 0 = middle
- **Z:** 0 = traditional surround plane (ear level), 1 = overhead plane [^22^]

```
Claim: The coordinate system uses a normalized room cube where X represents left-right, Y represents front-back, and Z represents elevation, with values normalized to the unit cube. [^23^]
Source: SMPTE ST 2098-1 Immersive Audio Metadata
URL: https://www.smpte.org/hubfs/2018-08-08-ST-Immersive-Vessa-Handout.pdf
Excerpt: "X axis: left face value=0; right face value=1. Y axis: front face value=0; rear face value=1. Z axis: bottom value=0; top value=1; midpoint value=0.5. A coordinate of [0.5, 0, 0.5] will be located on the center of the front face."
Confidence: High
```

### Reference Points and Speaker Assumptions

The coordinate system maps to speaker positions within the normalized room:

| Speaker Position | X | Y | Z |
|------------------|---|---|---|
| Front Left | 0.0 or -1 | 0.0 or -1 | 0.5 or 0 |
| Front Center | 0.5 or 0 | 0.0 or -1 | 0.5 or 0 |
| Front Right | 1.0 or +1 | 0.0 or -1 | 0.5 or 0 |
| Left Surround | 0.0 or -1 | 0.5 or 0 | 0.5 or 0 |
| Right Surround | 1.0 or +1 | 0.5 or 0 | 0.5 or 0 |
| Left Rear Surround | 0.0 or -1 | 1.0 or +1 | 0.5 or 0 |
| Right Rear Surround | 1.0 or +1 | 1.0 or +1 | 0.5 or 0 |
| Center Height | 0.5 or 0 | 0.0 or -1 | 1.0 or +1 |
| Top Front Left | 0.25 or -0.75 | 0.25 or -0.75 | 1.0 or +1 |
| Top Front Right | 0.75 or +0.75 | 0.25 or -0.75 | 1.0 or +1 |
| Top Rear Left | 0.25 or -0.75 | 0.75 or +0.75 | 1.0 or +1 |
| Top Rear Right | 0.75 or +0.75 | 0.75 or +0.75 | 1.0 or +1 |

```
Claim: The renderer assumes specific speaker positions within the normalized cube. For example, the Center speaker is assumed to be at x=0.5 (midway between left and right front speakers), and Wides are assumed at y=0.17 (about 1/6 of the distance from front to rear). [^24^]
Source: AVSForum citing Dolby Object Audio Metadata Specification
URL: https://www.avsforum.com/threads/atmos-speaker-placement-is-not-necessarily-based-solely-on-angles.3261739/
Excerpt: "The Wides in an Atmos layout are not exactly mid way between the Fronts and Sides, but have rendering assumptions of y = 0.17. You can convert that to 17% or 1/6th the distance from Front speaker to Rear speaker."
Confidence: Medium (from forum, citing Dolby documentation)
```

### Extended Z-Axis (Below Listening Plane)

The Z coordinate can extend below the listening plane (Z = −1 representing a floor plane). However, most consumer workflows constrain Z to [0, 1] (listening level and above). [^25^]

---

## 4. Object Size Parameter: Rendering and Speaker Spread

### Size Parameter Fundamentals

The **Size** parameter controls how localized or diffused an object sounds by determining how its energy is distributed across multiple speakers. It effectively controls the apparent "size" of the sound source in 3D space. [^26^][^27^]

```
Claim: The size parameter works like inflating a balloon around the object's position point. A size of zero means all energy comes from the nearest single speaker. As size increases, a sphere of energy grows outward, distributing sound to additional speakers while maintaining constant overall energy. [^28^]
Source: Dolby PMD Application Guide
URL: https://datahacker.blog/files/94/Technical/126/Dolby-Professional-MetaData-Guide.pdf
Excerpt: "A size value of zero indicates that an Audio Object is a single point source, i.e. if you positioned the object in the bottom front left corner then all the energy would only come out of the front left speaker. If the size is greater than zero then a sphere of energy grows outwards from the point source, just as if an amount of air was blown into the balloon. This energy spread now gets distributed into other speakers, however the overall amount of energy is the same as the single point source."
Confidence: High
```

### Size Parameter Range

In most DAW implementations (Pro Tools, Logic Pro, Nuendo), the size parameter uses a **0-100 scale** (representing 0% to 100% spread). In the metadata file formats (PMD, IAB), this is normalized to **0.0 to 1.0**.

### Size Rendering Behavior

The size parameter affects rendering in several ways:

1. **Speaker count energization:** At size=0, only the nearest speaker reproduces the object. At higher values, more speakers are energized proportionally.

2. **Energy conservation:** The total energy across all speakers remains constant regardless of size setting. Energy is distributed across more speakers at lower per-speaker levels.

3. **Decorrelation at high sizes:** At sizes above approximately 20 (on a 0-100 scale), spatial coding can cause decorrelation artifacts, potentially splitting the same object across multiple clusters. [^29^]

```
Claim: Increasing object size beyond approximately 20 can cause the object to appear in more than one spatial coding cluster, potentially creating decorrelation artifacts. [^30^]
Source: Avid - Encoding and Delivering Dolby Atmos Music
URL: https://www.avid.com/resource-center/encoding-and-delivering-dolby-atmos-music
Excerpt: "If you increase size of an object so that it is more than around 20, then the same object could appear in more than one cluster or there could be decorrelation artefacts, which in turn will skew the sound of your mix."
Confidence: High
```

4. **Phase considerations:** The size parameter may employ decorrelation (short allpass or FIR filtering) to spread the signal. This can introduce phase-related artifacts depending on listening position. [^31^]

```
Claim: The size parameter likely feeds to peripheral channels through some type of decorrelation (short allpass or FIR), making the signal sound "more distant or 'fuzzy'." [^32^]
Source: Avid DUC Forums (development partner speculation)
URL: https://duc.avid.com/showthread.php?t=427141
Excerpt: "I suspect the size actually feeds to peripheral channels by some type of decorrelation (perhaps a short allpass or FIR). You can hear the overall enlarged signal as sounding just a bit more distant or 'fuzzy'."
Confidence: Medium (expert speculation; Dolby does not publish algorithm details)
```

### Size Dimensionality Modes (per SMPTE ST 2098-2)

The standard defines three object spread modes:

| Mode | Value | Description |
|------|-------|-------------|
| OBJECT_SPREAD_1D | 0x02 | Spread equally in all dimensions (12-bit coding) |
| OBJECT_SPREAD_LOWRES | — | Spread equally in all dimensions (8-bit coding) |
| OBJECT_SPREAD_3D | — | Independent spreading in each dimension (X, Y, Z separately) |

Dolby IAB Profile 1 mandates `ObjectSpreadMode = 0x02` (OBJECT_SPREAD_1D) and does not support 3D spread. [^33^]

### Size_Vertical Parameter

The `Size_Vertical` boolean parameter (in PMD) controls whether size operates in 3D or is constrained to 2D:
- **True:** Full 3D spread (spherical energy distribution)
- **False:** 2D spread only (disc-shaped energy distribution on the horizontal plane) [^34^]

---

## 5. Snap to Speaker Functionality

### Snap to Speaker Overview

**Snap to Speaker** is a rendering mode that forces an object to play from only a single physical speaker—the one nearest to the object's specified position—rather than being distributed across multiple speakers as a phantom image. [^35^]

```
Claim: Snap to Speaker forces an object to play exclusively from the nearest physical speaker. If that speaker is not present in the playback configuration, the object snaps to the next closest available speaker. [^36^]
Source: Reddit /r/hometheater citing Dolby documentation
URL: https://www.reddit.com/r/hometheater/comments/11sqvz3/how_dolby_atmos_actually_works_marketing_vs/
Excerpt: "The mastering software also has a function that can snap an object to a speaker, and the sound will play from only that speaker if it's present in the final playback."
Confidence: High
```

### Snap Tolerance Metadata

SMPTE ST 2098-1 defines **Snap Tolerance** as formal metadata:

> "This metadata item indicates the degree to which preservation of object timbre has priority over preservation of object position. This property has extreme values indicating 'preserving object timbre has highest priority' and 'preserving object position has highest priority', respectively." [^37^]

**Behavior:**
- **Snap Tolerance = High (preserve timbre):** The object snaps to the nearest single loudspeaker, maintaining the timbre/color of the sound at the expense of precise spatial positioning.
- **Snap Tolerance = Low (preserve position):** The object is reproduced across multiple loudspeakers using amplitude panning to best preserve the intended spatial position, potentially altering timbre due to comb filtering.

### ISDCF IAB Profile Constraints

For cinema delivery via IAB (Immersive Audio Bitstream), the ISDCF profile mandates:
- `ObjectSnapToExists` field, when present, must be set to "0"
- The bitstream shall not contain the `ObjectSnapTolerance` element
- This implies that snap-to-speaker behavior is standardized to a specific mode in cinema distribution [^38^]

### Visual Behavior in Panner UI

Important implementation detail: **Speaker Snap does not move the pan location cursor in the virtual room display.** The panner UI continues to show the object's authored position, while the renderer internally snaps the output to the nearest speaker. The Dolby Atmos Monitor application shows the actual speaker being used. [^39^]

---

## 6. The 118 Object Limit and Spatial Coding Clustering

### The 128-Channel Architecture

Dolby Atmos supports a maximum of **128 simultaneous audio channels** during content creation. This limit originates from the PCIe bandwidth of the hardware interfaces connecting DAWs to the RMU (Rendering and Mastering Unit). [^40^]

With a 7.1.2 bed consuming 10 channels:
- **Maximum mono objects:** 118
- **Maximum stereo objects:** 59 (if no other beds/objects)

### Spatial Coding: Reducing 128 Channels to 16 Elements

For home distribution (DD+JOC), spatial coding reduces the 128 bed/object channels to **12 or 16 elements** (effectively 11.1 or 15.1, since LFE doesn't move). [^41^]

```
Claim: Spatial coding dynamically groups nearby objects into clusters (aggregate objects) to reduce the channel count from 128 to 12-16 elements for consumer delivery, while preserving perceived spatial quality. [^42^]
Source: Hybrik Documentation
URL: https://docs.hybrik.com/tutorials/dolby_atmos/
Excerpt: "Spatial coding is employed to reduce 128 bed and object channels to 12 or 16 elements or 'clusters'. Actually, this is really 11.1 or 15.1 as the LFE doesn't move. Spatial coding works by employing an algorithm to dynamically group audio into dynamic elements. Audio can move from cluster to cluster and the clusters themselves move as needed."
Confidence: High
```

### How Spatial Coding Clustering Works

The spatial coding algorithm operates as follows:

1. **Proximity-based grouping:** Objects that are spatially close to each other are grouped into the same cluster.

2. **Perceptual loudness weighting:** The clustering process is driven by **perceptual loudness** in addition to spatial proximity—louder objects have more influence on cluster formation. [^43^]

```
Claim: Spatial coding clustering is driven by perceptual loudness and proximity. The algorithm dynamically groups nearby objects into spatial clusters. [^44^]
Source: Dolby Atmos Renderer Guide
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Excerpt: "At a high level, this is achieved by dynamically grouping nearby objects into spatial clusters. The process is driven by perceptual loudness..."
Confidence: High
```

3. **Dynamic clusters:** Clusters are not fixed. Objects can move between clusters, and clusters themselves can move to follow objects.

4. **No audio discarded:** All original object audio is preserved in the clusters; only the spatial representation is consolidated.

5. **Cluster count options:** 12, 14, or 16 elements (configurable in the renderer). Default is 12. [^45^]

6. **Limiting:** Spatial coding emulation in the renderer includes a limiter that represents the limiting applied during final encoding. This affects monitoring only, not the master recording. [^46^]

### Spatial Coding Emulation for Monitoring

The renderer provides a **Spatial Coding Emulation** mode that allows mixers to hear how the mix will sound after spatial coding is applied. Critical guidelines:

- Enable emulation **only when all mix elements are present** (clustering depends on content, position, and loudness of all objects)
- Increasing object size above ~20 can cause objects to span multiple clusters
- Emulation is for monitoring only—clustering is NOT exported to ADM or DAMF master files [^47^]

### JOC (Joint Object Coding)

After spatial coding, the audio is encoded as **Dolby Digital Plus JOC**:
- Each cluster element carries its **OAMD** and **JOC payload** in the bitstream
- Minimum bitrate: 384 kbps (12 elements) or 448 kbps (16 elements)
- Non-Atmos devices decode the 5.1 "core"; Atmos devices extract elements and OAMD for rendering [^48^]

### Object Audio Renderer (OAR)

In the consumer playback chain, the **OAR** uses OAMD to render the spatially-coded elements to the listener's specific speaker configuration. [^49^]

---

## 7. 3D Panner Metadata Generation in DAWs

### Panner Fundamentals

The 3D panner in DAWs (Pro Tools, Nuendo, Logic Pro) generates OAMD metadata by mapping GUI interactions to XYZ coordinates. The panner sends this metadata separately from the audio signal to the renderer. [^50^][^51^]

```
Claim: The 3D Object Panner in DAWs generates XYZ position metadata that is sent separately from the audio signal to the Dolby Atmos plugin/renderer. The position is referenced to XYZ coordinates in 3D space, not to specific speakers. [^52^]
Source: Logic Pro User Guide (Apple)
URL: https://support.apple.com/guide/logicpro/3d-object-panner-parameters-lgcpa01bed87/mac
Excerpt: "Creating a pan position generates metadata that is sent separately from the audio signal to the same corresponding object input of the Dolby Atmos plug-in. The three-dimensional position where you place the signal with the pan puck has no reference to a specific speaker setup and is only referenced to a XYZ coordinate in the three-dimensional space."
Confidence: High
```

### Pro Tools | Ultimate Panner

Pro Tools provides a built-in **Dolby Atmos Panner** on object tracks:
- Automation is written to standard Pro Tools automation playlists (X, Y, Z parameters)
- Supports automation write modes: Write, Touch, Latch, Read
- Can convert from external Dolby Atmos Music Panner plug-in automation to native pan automation [^53^][^54^]

```
Claim: Pro Tools stores object positions as XYZ coordinates in automation playlists. The internal renderer was added in Pro Tools 2023.12. [^55^]
Source: Avid Knowledge Base
URL: https://kb.avid.com/pkb/articles/en_US/faq/Pro-Tools-and-the-Dolby-Atmos-Renderer-FAQ
Excerpt: "When panning objects in Dolby Atmos, their positions are stored as XYZ co-ordinates until the mix reaches the renderer."
Confidence: High
```

### Nuendo VST MultiPanner

Nuendo uses the **VST MultiPanner** in Object Mode:
- Objects are mapped via Devices > Object Mapping dialog
- The VST MultiPanner provides the same XYZ positioning as Pro Tools
- Object buses are created as mono output buses in Audio Connections
- Supports up to 118 mono objects or combinations of mono/stereo [^56^]

### Logic Pro 3D Object Panner

Logic Pro's **3D Object Panner** provides:
- Two-grid interface: upper grid for X/Y (left-right, front-back), lower grid for X/Z (left-right, up-down)
- Parameters: Left/Right, Back/Front, Elevation, Size, Spread (stereo only)
- Stereo objects represented by three pucks (L, R, and center dot)
- Automation can be written and edited as standard track automation [^57^][^58^]

### Metadata Transport Pathways

Metadata flows from DAW to renderer through several pathways:

1. **Pro Tools + External RMU:** Audio via MADI/Dante; metadata via Ethernet
2. **Pro Tools + Internal Renderer:** Metadata travels within the DAW host process
3. **Nuendo + External Renderer:** Audio via Dolby Audio Bridge; metadata via internal protocol
4. **LTC sync:** Used to synchronize metadata timing across systems [^59^]

---

## 8. Real-Time Metadata Interpolation and Smoothing

### Metadata Update Rates

Metadata can be updated at different rates depending on the workflow:

1. **Per-video-frame updates:** Standard OAMD updates once per video frame (e.g., every 41.67ms at 24fps)

2. **Intra-frame updates (Dynamic Position Updates):** In compressed audio workflows (ED2, AC-4), position updates can occur at **32-sample increments** within a video frame, enabling much higher temporal resolution for fast-moving objects. [^60^]

```
Claim: Dynamic Position Updates in PMD use an optimized binary payload with sample_time parameters stepping in increments of 32 samples, enabling high positional update rates even with limited bandwidth. [^61^]
Source: Dolby PMD Application Guide
URL: https://datahacker.blog/files/94/Technical/126/Dolby-Professional-MetaData-Guide.pdf
Excerpt: "The intra-video frame update to an Audio Object's positional uses an optimized binary payload to maximize transmission bandwidth efficiency. The sample_time parameter specifies the number of samples following video sync that the positional update applies to, the value steps in increments of 32 samples."
Confidence: High
```

### Pan Sub Blocks (SMPTE ST 2098-2)

For cinema delivery via IAB, **Pan Sub Blocks** divide the IAFrame into sub-divisions that can contain different panning metadata, effectively increasing the metadata update rate within a frame. [^62^]

```
Claim: SMPTE ST 2098-2 defines Pan Sub Blocks as subdivisions within an IAFrame that can contain different panning metadata, effectively increasing the position update rate. [^63^]
Source: ISDCF IAB Profile 1 Draft
URL: https://files.isdcf.com/MeetingNotes/ISDCF-IAB-Profile-1_DRAFT-20200407.pdf
Excerpt: "Pan Sub Blocks: Sub divisions within an IAFrame that can contain different panning metadata. Pan Sub Blocks must be supported. (ST 2098-2 Reference: 10.5.3, 10.5.4, Table 23)"
Confidence: High
```

### Interpolation and Smoothing

While explicit interpolation algorithms are not publicly documented by Dolby, the following is known:

1. **Sample-accurate metadata:** The renderer applies metadata at audio sample rate (48 kHz or 96 kHz), interpolating between metadata waypoints.

2. **Smooth panning curves:** DAW automation systems (Pro Tools, Nuendo) support standard automation curve interpolation (linear, S-curve, etc.) between keyframes.

3. **Overlap panning:** The renderer's speaker calibration includes a "Rotate" mode that maintains continuous panning volume with overlapping signals, and a "Rotate and Snap" mode that switches one channel at a time. [^64^]

4. **Crossfade between speakers:** When objects move between speaker zones, the renderer crossfades between speakers to maintain perceived velocity. The exact crossfade law is proprietary to Dolby.

```
Claim: The renderer includes continuous panning modes where signals overlap during transitions (maintaining continuous volume) and snap modes where signals switch sequentially. [^65^]
Source: Dolby Atmos Renderer Guide
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Excerpt: "To enable rotate, click Rotate. This pans the signal through each channel sequentially, while maintaining a continuous panning volume. As signal in one channel starts to end, the signal in the next channel begins, such that the signals overlap in a smooth fashion. To enable rotate and snap, click Rotate and Snap. This pans the signal through each channel sequentially, one channel at a time, with only one signal present at any time."
Confidence: High
```

### Latency Considerations

For compressed audio workflows (ED2, AC-4):
- The encoder has **one video frame of latency**
- This allows the encoder to "see into the future" and optimize metadata delivery
- PMD updates that occur multiple times within a video frame are grouped by priority to meet the 1-frame decode and render latency requirement [^66^]

---

## 9. Static vs Dynamic Objects

### Static Objects

**Static objects** have fixed positions that do not change over time:
- Position metadata is written once and remains constant
- Examples: dialogue anchored to screen center, fixed ambience elements
- In PMD: `DynamicUpdates = False`
- Rendered identically at each frame; no interpolation needed
- Can be used to create "object-based beds" (oBeds) by placing static objects at canonical speaker positions [^67^]

### Dynamic Objects

**Dynamic objects** have time-varying positions:
- Position metadata changes over time via automation
- Examples: flying vehicles, moving sound effects, panned musical elements
- In PMD: `DynamicUpdates = True`
- Receive intra-frame position updates for smooth motion trajectories
- The renderer interpolates between position waypoints [^68^]

### Metadata Time-Varying Assumption

```
Claim: Per SMPTE ST 2098-1, ALL object metadata is considered dynamic (time-varying) unless explicitly stated otherwise. [^69^]
Source: SMPTE ST 2098-1 Immersive Audio Metadata presentation
URL: https://www.smpte.org/hubfs/2018-08-08-ST-Immersive-Vessa-Handout.pdf
Excerpt: "Note that all object metadata is considered to be dynamic (time-varying) unless explicitly stated differently"
Confidence: High
```

### Practical Differences

| Aspect | Static Objects | Dynamic Objects |
|--------|---------------|-----------------|
| Metadata update rate | Once per session | Continuous (per-frame or per-sample) |
| PMD DynamicUpdates flag | False | True |
| Renderer interpolation | None | Interpolated between waypoints |
| Intra-frame updates | Not needed | Supported via Dynamic Position Updates |
| CPU processing | Lower | Higher |
| Use cases | Dialogue, fixed ambience, oBeds | Moving effects, panned instruments |

---

## 10. Key Standards: SMPTE ST 2098-1/2098-2, PMD, ED2

### SMPTE ST 2098-1: Immersive Audio Metadata (2018)

Defines the metadata model for immersive audio in cinema, including:
- 3D Cartesian coordinate system (unit cube)
- Object metadata (position, spread, gain, lifetime, decorrelation, snap tolerance)
- Bed metadata (channel lists, remap coefficients)
- Zone metadata (zone control, zone gain)
- Conditional objects and beds [^70^]

### SMPTE ST 2098-2: Immersive Audio Bitstream (2018/2019)

Defines the coded bitstream representation carrying audio essence and metadata:
- **IAFrame:** Smallest editable unit, containing all audio and metadata for one frame
- **IAFrame Rate:** Matches picture edit rate (24, 25, 30, 48, 50, 60 fps)
- **Pan Sub Blocks:** Sub-divisions within frames for higher update rates
- **ObjectDefinition:** Contains all object metadata with MetalD <= 118
- **MaxRendered:** Maximum of 128 (bed channels + objects) [^71^][^72^]

```
Claim: SMPTE ST 2098-2 defines the IAB frame structure where the ObjectDefinition MetalD must be <= 118, SubElementCount = 0, and MaxRendered = 128. [^73^]
Source: ISDCF IAB Profile 1 Draft
URL: https://files.isdcf.com/MeetingNotes/ISDCF-IAB-Profile-1_DRAFT-202006010.pdf
Excerpt: "ObjectDefinition MetalD value shall be less than or equal to 118... MaxRendered field shall have a value of 128 or less."
Confidence: High
```

### PMD (Professional Metadata)

Dolby's professional metadata format for broadcast/live workflows:
- XML-structured metadata carried alongside audio
- Supports Dynamic Position Updates at 32-sample granularity
- Used with Dolby ED2 mezzanine codec and AC-4 [^74^]

### Dolby ED2 (Enhanced Dolby E)

- Extension of Dolby E mezzanine codec for immersive audio
- Supports up to 16 audio channels (two 8-channel substreams)
- Carries PMD metadata alongside audio essence
- Backward compatible with Dolby E decoders
- Frame-aligned to video [^75^]

---

## 11. Summary of Key Findings

### Architecture Overview

Dolby Atmos represents a paradigm shift from channel-based to object-based audio. At its core, an Atmos object consists of a mono or stereo audio signal paired with Object Audio Metadata (OAMD) that describes where and how that sound should be reproduced in three-dimensional space. The system supports up to 128 simultaneous channels during authoring: typically 10 channels for a 7.1.2 bed and up to 118 channels for objects.

### OAMD Format

OAMD is a rich metadata format encompassing XYZ position coordinates (in a Cartesian normalized cube), object size/spread parameters, decorrelation controls, snap tolerance, zone gain settings, and binaural render mode settings. The format is formally standardized in SMPTE ST 2098-1 for cinema and implemented in Dolby's PMD format for broadcast. Position metadata uses an allocentric (room-relative) coordinate system where X represents left-right, Y represents front-back, and Z represents elevation, with coordinates normalized to the unit cube [0,1].

### Object Size Parameter

The size parameter (0-100 scale in DAWs, 0.0-1.0 in normalized metadata) controls how an object's energy is distributed across speakers. At size=0, the object is a point source reproduced by a single speaker. As size increases, a sphere of energy expands outward, energizing more speakers while maintaining constant total energy. At very high sizes (>20), spatial coding can cause objects to span multiple clusters, potentially introducing decorrelation artifacts. Dolby does not publicly document the exact algorithm for energy distribution, though experts speculate it involves short decorrelation filters.

### Snap to Speaker

Snap to Speaker overrides the normal amplitude-panning behavior and forces an object to play exclusively from the single nearest physical speaker. This preserves timbral purity at the expense of precise spatial positioning. SMPTE ST 2098-1 formalizes this as Snap Tolerance metadata. The feature is particularly useful when no speaker exists near the authored position.

### Spatial Coding and the 118 Object Limit

For consumer delivery, spatial coding dynamically clusters the 128 authoring channels into 12-16 elements based on spatial proximity and perceptual loudness. This process is entirely transparent to the mixer—all original audio is preserved. The 118 object limit (after a 7.1.2 bed) originates from hardware interface bandwidth (PCIe lanes on the RMU). Clustering is content-dependent and dynamic: objects can move between clusters and clusters themselves can move.

### 3D Panner Metadata Generation

DAW panner plug-ins (Pro Tools Ultimate Panner, Nuendo VST MultiPanner, Logic Pro 3D Object Panner) generate OAMD by mapping GUI interactions to XYZ coordinates. Metadata is sent separately from audio to the renderer. Stereo objects use three pan pucks (L, R, and center). Automation is written as standard DAW automation curves and stored in the master file.

### Metadata Interpolation

Position metadata can be updated at per-frame rates or at higher intra-frame rates via Dynamic Position Updates (32-sample increments in PMD) or Pan Sub Blocks (in IAB). The renderer interpolates between metadata waypoints at audio sample rate. DAW automation curves provide additional smoothing between keyframes.

### Static vs Dynamic Objects

All object metadata is considered time-varying by default per SMPTE ST 2098-1. Static objects (DynamicUpdates=False) have fixed positions and require no interpolation. Dynamic objects receive continuous position updates for smooth motion. The distinction is primarily a workflow optimization—dynamic objects require more CPU processing and metadata bandwidth.

---

## 12. Unresolved Questions and Research Gaps

1. **Exact Size Algorithm:** Dolby does not publicly document the exact mathematical algorithm for energy distribution as size increases. The specific pan law, energy weighting, and decorrelation method remain proprietary.

2. **Spatial Coding Algorithm Details:** While the clustering is described as "proximity and perceptual loudness driven," the exact clustering algorithm (k-means, hierarchical, etc.), its parameters, and its time constants are not published.

3. **Crossfade/Pan Law in Renderer:** The specific panning law used when distributing objects across multiple speakers is not publicly documented. It is known to differ from conventional pan laws.

4. **Metadata Interpolation Method:** While the renderer interpolates between metadata waypoints, the exact interpolation algorithm (linear, cubic, etc.) is not specified in public documentation.

5. **Decorrelation Filter Design:** The decorrelation filters hypothesized to be used for size spreading have not been confirmed by Dolby. Their type (allpass, FIR, stochastic), length, and spectral characteristics are unknown.

6. **Coordinate System Discrepancy:** There appears to be some inconsistency in published coordinate ranges. Some sources use [0,1], others use [-1,1]. The exact coordinate system used at different points in the chain (DAW, RMU, OAMD bitstream, renderer) may vary.

7. **Real-Time Metadata Bandwidth:** The Ethernet bandwidth and packet format used for metadata transport between DAW and RMU is not publicly documented.

8. **Binaural Rendering Algorithm:** The specific HRTF-based algorithm used for binaural rendering (Near/Mid/Far modes) is proprietary.

---

## 13. Complete Reference List

[^1^]: Dolby Atmos Renderer Guide, Dolby Laboratories, 2018. https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf

[^2^]: "Dolby Atmos," Wikipedia. https://en.wikipedia.org/wiki/Dolby_Atmos

[^3^]: "Dolby Atmos Demystified," Eventide Audio, 2025. https://www.eventideaudio.com/blog/atmos-demystified/

[^4^]: "Objects and Beds Explained," Audient, 2024. https://audient.com/tutorial/objects-and-beds-explained/

[^5^]: "Music & Dolby Atmos - How Does 3D Mixing Work?" HOFA College, 2025. https://hofa-college.de/en/blog/music-dolby-atmos-how-does-3d-mixing-work/

[^6^]: Audient, "Objects and Beds Explained" (LFE limitation). https://audient.com/tutorial/objects-and-beds-explained/

[^7^]: "Bed tracks and object tracks in Logic Pro for Mac," Apple Support. https://support.apple.com/en-asia/guide/logicpro/lgcp73f9b9ac/mac

[^8^]: Dolby Atmos Renderer Guide, Section 9.1 "Dolby Atmos mix overview."

[^9^]: "Beds, Objects, and New Tools for Immersive Audio Production," Omni Soundlab. https://omnisoundlab.com/en/beds-objects-and-new-tools-for-immersive-audio-production/

[^10^]: Hybrik Documentation, "Dolby Atmos Tutorial." https://docs.hybrik.com/tutorials/dolby_atmos/

[^11^]: "Dolby ATMOS Glossary/Definitions," Barry Rudolph. https://www.barryrudolph.com/extras/dolby_definitions.html

[^12^]: Barry Rudolph, OAMD definition.

[^13^]: Dolby PMD Application Guide, "Audio Object Description (AOD)." https://datahacker.blog/files/94/Technical/126/Dolby-Professional-MetaData-Guide.pdf

[^14^]: SMPTE ST 2098-1 Immersive Audio Metadata presentation, "Three dimensional space representation." https://www.smpte.org/hubfs/2018-08-08-ST-Immersive-Vessa-Handout.pdf

[^15^]: SMPTE ST 2098-1, Zone Metadata section.

[^16^]: SMPTE ST 2098-1 presentation, Zone metadata slide.

[^17^]: SMPTE ST 2098-1 presentation, Decorrelation metadata slide.

[^18^]: Dolby PMD Application Guide.

[^19^]: Riedmiller, J.C. and Tsingos, N., "How a Paradigm Shift in Audio Spatial Representation & Delivery Will Change the Future of Consumer Audio Experiences," Dolby Laboratories, 2015 NCTA Spring Technical Forum.

[^20^]: AVSForum discussion citing Riedmiller & Tsingos. https://www.avsforum.com/threads/atmos-speaker-placement-is-not-necessarily-based-solely-on-angles.3261739/

[^21^]: SMPTE ST 2098-1 presentation.

[^22^]: AVSForum, Riedmiller & Tsingos citation.

[^23^]: SMPTE ST 2098-1 presentation.

[^24^]: AVSForum, citing Dolby Object Audio Metadata Specification.

[^25^]: Dolby PMD Application Guide, Z-axis note.

[^26^]: Dolby Atmos Renderer Guide, "Object size" display description.

[^27^]: Logic Pro 3D Object Panner documentation.

[^28^]: Dolby PMD Application Guide, Object Size section.

[^29^]: Avid, "Encoding and Delivering Dolby Atmos Music," 2021. https://www.avid.com/resource-center/encoding-and-delivering-dolby-atmos-music

[^30^]: Avid, "Encoding and Delivering Dolby Atmos Music."

[^31^]: Avid DUC Forums, "Atmos bug: phase weirdness with size parameter." https://duc.avid.com/showthread.php?t=427141

[^32^]: Avid DUC Forums.

[^33^]: ISDCF IAB Profile 1 Draft, Object Spread constraints. https://files.isdcf.com/MeetingNotes/ISDCF-IAB-Profile-1_DRAFT-202006010.pdf

[^34^]: Dolby PMD Application Guide, Size_Vertical description.

[^35^]: Reddit /r/hometheater, "How Dolby Atmos actually works!" https://www.reddit.com/r/hometheater/comments/11sqvz3/how_dolby_atmos_actually_works_marketing_vs/

[^36^]: Reddit /r/hometheater.

[^37^]: SMPTE ST 2098-1 presentation, Snap Tolerance slide.

[^38^]: ISDCF IAB Profile 1 Draft, Snap Tolerance constraints.

[^39^]: Avid DUC Forums, "Dolby Atmos Speaker Snap not working." https://duc.avid.com/showthread.php?t=394690

[^40^]: Reddit /r/hometheater, citing 2018 Dolby documentation.

[^41^]: Hybrik Documentation.

[^42^]: Hybrik Documentation.

[^43^]: Dolby Atmos Renderer Guide, Section 24.3 "Spatial coding."

[^44^]: Dolby Atmos Renderer Guide.

[^45^]: Dolby Atmos Renderer Guide, Processing preferences.

[^46^]: Dolby Atmos Renderer Guide, Limiter meter description.

[^47^]: Avid, "Encoding and Delivering Dolby Atmos Music."

[^48^]: Hybrik Documentation.

[^49^]: "Dolby Atmos for the Home Theater," Dolby whitepaper. https://professional.dolby.com/siteassets/tv/home/dolby-atmos/dolby-atmos-for-home-theater.pdf

[^50^]: Logic Pro 3D Object Panner documentation.

[^51^]: "Mixing Spatial Audio in Dolby Atmos," NYT R&D, 2022. https://rd.nytimes.com/projects/mixing-spatial-audio-in-dolby-atmos/

[^52^]: Logic Pro 3D Object Panner documentation.

[^53^]: Avid Knowledge Base, Pro Tools and Dolby Atmos Renderer FAQ. https://kb.avid.com/pkb/articles/en_US/faq/Pro-Tools-and-the-Dolby-Atmos-Renderer-FAQ

[^54^]: Dolby support, "Deep Dive: Using the Pro Tools Ultimate Panner for Dolby Atmos mixing." https://professionalsupport.dolby.com/s/article/Deep-Dive-Using-the-Pro-Tools-Ultimate-Panner-for-Dolby-Atmos-mixing

[^55^]: Avid Knowledge Base.

[^56^]: Dolby Atmos Renderer Guide, Chapter 8 "Setting up the Renderer for use with Nuendo."

[^57^]: "3D objects in Logic Pro," Killander Music Records, 2023. https://killandermusicrecords.com/en/guides/3d-objects-in-logic-pro/

[^58^]: Apple Support, "3D Object Panner parameters in Logic Pro for Mac." https://support.apple.com/guide/logicpro/3d-object-panner-parameters-lgcpa01bed87/mac

[^59^]: Dolby Atmos Renderer Guide, workflow overview sections.

[^60^]: Dolby PMD Application Guide, Dynamic Position Update section.

[^61^]: Dolby PMD Application Guide.

[^62^]: SMPTE ST 2098-2:2019, Section on moving objects and sub blocks. https://www.normsplash.com/Samples/SMPTE/159251622/SMPTE-ST-2098-2-2019-en.pdf

[^63^]: ISDCF IAB Profile 1 Draft.

[^64^]: Dolby Atmos Renderer Guide, Speaker Calibration section.

[^65^]: Dolby Atmos Renderer Guide.

[^66^]: Dolby PMD Application Guide, Dynamic Updates latency description.

[^67^]: Omni Soundlab, "Beds, Objects, and New Tools for Immersive Audio Production."

[^68^]: Dolby PMD Application Guide, DynamicUpdates parameter description.

[^69^]: SMPTE ST 2098-1 presentation.

[^70^]: "SMPTE Publishes Immersive Audio Standards for Cinema," SMPTE Press Release, Sept 25, 2018. http://www.wallstcom.com/SMPTE/180925SMPTE.docx

[^71^]: SMPTE ST 2098-2:2019.

[^72^]: ISDCF IAB Profile 1 Draft.

[^73^]: ISDCF IAB Profile 1 Draft.

[^74^]: Dolby PMD Application Guide.

[^75^]: "Dolby ED2 Whitepaper," Dolby Laboratories. https://professional.dolby.com/siteassets/tv/home/dolby-atmos/dolby-ed2-whitepaper.pdf

[^76^]: "A Deep Dive into Dolby MAT," AVPro Global, 2022. https://www.avproglobal.com/blogs/news/a-deep-dive-into-dolby-mat

[^77^]: SMPTE ST 2098-5:2018, D-Cinema Immersive Audio Channels and Soundfield Groups.

[^78^]: Dolby Atmos Renderer Guide, CPU meter section.

[^79^]: "Dolby Atmos Documentation," Dolby Professional. https://professional.dolby.com/gaming/gaming-getting-started/dolby-atmos-documentation/

[^80^]: "Dolby Atmos Audio Best Practices," UMG Content Guide, 2025. https://contentguide.universalmusic.com/dolby-atmos-audio-best-practices/

[^81^]: "Dolby Atmos Standards, Settings & Deliverables Guide (2025)," Ralph Sutton. https://ralphsutton.com/dolby-atmos-standards-deliverables-2025/

[^82^]: "What is Object-based Audio?" Sound Particles blog, 2022. https://blog.soundparticles.com/what-is-object-based-audio

[^83^]: "Acoustic Metadata Design on Object-Based Audio," MDPI Applied Sciences, 2026. https://www.mdpi.com/2624-599X/8/1/3

[^84^]: "ATMOS - Differences between Beds and Objects," Steinberg Forums, 2021. https://forums.steinberg.net/t/atmos-differences-between-beds-and-objects/750117

[^85^]: "Dolby Atmos bed vs object," Gearspace, 2021. https://gearspace.com/board/post-production-forum/1368482-dolby-atmos-bed-vs-object.html

[^86^]: "Pro Tools and the Dolby Atmos Renderer FAQ," Avid Knowledge Base. https://kb.avid.com/pkb/articles/Knowledge/Pro-Tools-and-the-Dolby-Atmos-Renderer-FAQ

[^87^]: "Understanding Dolby Atmos and its QC Challenges," Venera Technologies, 2023. https://www.veneratech.com/understanding-dolby-atmos-and-its-qc-challenges

[^88^]: "Dolby Atmos," JH Wiki Collection. https://jhmovie.fandom.com/wiki/Dolby_Atmos

[^89^]: "Where Is My Atmos, and What Is An IAB?" Celluloid Junkie, 2022. https://celluloidjunkie.com/2022/06/13/where-is-my-atmos-and-what-is-an-iab/

[^90^]: "Getting started with Atmos part 2: Dolby Atmos Renderer," Jigsaw24. https://media.jigsaw24.com/resource/artist-getting-started-with-dolby-atmos

[^91^]: "Demystifying the Myths of Dolby Atmos," Film Mixing, 2015. https://film-mixing.com/2015/08/14/demystifying-the-myths-of-dolby-atmos/

[^92^]: "Dolby Atmos Speaker Position Tool," Grayspark Academy, 2026. https://academy.gray-spark.com/elementor-page-9634/dolby-atmos-speaker-position-tool/

[^93^]: "What is a Dolby Atmos ADM?" Production Expert, 2024. https://www.production-expert.com/production-expert-1/what-is-a-dolby-atmos-adm

[^94^]: Dolby Audio Encoder DP591 Product Specification. https://www.hhb.co.uk/wp-content/uploads/m_dp591_product_spec_final.pdf

[^95^]: Dolby Professional Reference Decoder DP580 Product Specification. https://www.dmtpro.com/uploadfile/2020/0316/20200316111908684.pdf

[^96^]: Dolby Atmos Home Theater Installation Guidelines. https://www.dolby.com/siteassets/technologies/dolby-atmos/atmos-installation-guidelines-121318_r3.1.pdf

[^97^]: "3D Immersive Surround Formats and Loudspeaker Layouts," Audioholics, 2015. https://www.audioholics.com/audio-technologies/immersive-audio-loudspeaker-layouts

[^98^]: "Guidelines for Dolby Atmos installation," Focal. https://www.focal.com/dolby-atmos-installation

[^99^]: "Dolby Atmos & the 7.1.2 Dilemma," VI-Control forums, 2024. https://vi-control.net/community/threads/dolby-atmos-the-7-1-2-dilemma.149490/

[^100^]: "Dolby Atmos for the Home Theater," Dolby whitepaper.

---

*Document compiled from 16+ independent web searches across authoritative sources including Dolby whitepapers, SMPTE standards, DAW manufacturer documentation, academic papers, and industry technical guides.*
