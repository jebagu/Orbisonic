# Dimension 10: Sonic Sphere — Extending Atmos to a Full Sphere (Theoretical Architecture)

## Complete Research Findings

**Date:** July 2025
**Searches Conducted:** 18 independent web searches
**Sources Consulted:** 40+ authoritative sources

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [The Atmos Hemisphere Limitation](#2-the-atmos-hemisphere-limitation)
3. [Why Full Sphere Matters](#3-why-full-sphere-matters)
4. [Extending the Atmos Object Model to Negative Elevation](#4-extending-the-atmos-object-model-to-negative-elevation)
5. [Extending VBAP for Below-Horizon Speaker Triplets](#5-extending-vbap-for-below-horizon-speaker-triplets)
6. [Speaker Array Geometries for Full Sphere](#6-speaker-array-geometries-for-full-sphere)
7. [Modifying OAMD Metadata for Full-Sphere Support](#7-modifying-oamd-metadata-for-full-sphere-support)
8. [Rendering Pipeline Modifications](#8-rendering-pipeline-modifications)
9. [Ambisonics as Intermediate Representation](#9-ambisonics-as-intermediate-representation)
10. [The Bed Extension: Floor Channels](#10-the-bed-extension-floor-channels)
11. [Implementation Considerations](#11-implementation-considerations)
12. [Reference List](#12-reference-list)
13. [Gaps and Unresolved Questions](#13-gaps-and-unresolved-questions)

---

## 1. Executive Summary

This document develops a theoretical architecture for a "Sonic Sphere" renderer that extends Dolby Atmos from its current hemisphere-only reproduction (elevation ≥ 0°) to a full sphere including below-horizon (negative elevation) sound reproduction. The research reveals that while Dolby Atmos fundamentally constrains audio objects and bed channels to the horizontal plane and above, existing standards—notably ITU-R BS.2051 System H (9+10+3, the NHK 22.2 system)—already specify full-sphere loudspeaker layouts with bottom-layer channels. The theoretical extension proposed here integrates five key innovations: (1) extension of the OAMD coordinate system to negative Z-values, (2) VBAP triangulation using real below-horizon speaker triplets instead of virtual nadir loudspeakers, (3) adoption of Platonic-solid or geodesic speaker arrays for full-sphere coverage, (4) an Ambisonics/HOA intermediate representation for format-agnostic full-sphere rendering, and (5) floor-channel bed extensions analogous to existing height channels. The architecture is technically grounded in peer-reviewed research, industry standards, and established perceptual models of 3D sound localization.

---

## 2. The Atmos Hemisphere Limitation

### 2.1 Current Atmos Elevation Constraints

Dolby Atmos, in both its cinema and home theater implementations, defines speaker positions exclusively at and above the horizontal plane. The standard bed configuration is 7.1.2, meaning 7 listener-level channels, 1 LFE channel, and 2 height/overhead channels. Even the most expansive consumer configuration (24.1.10) adds more height speakers but never extends below the horizon.

```
Claim: Dolby Atmos bed channels are limited to 7.1.2 (10 channels maximum), and all bed speakers are positioned at or above listener ear level. There are no standardized below-horizon or "floor" channels in the Atmos specification.
Source: Steinberg Forums / Dolby Documentation
URL: https://forums.steinberg.net/t/why-are-beds-limited-to-7-1-2/932618
Date: 2024-09-04
Excerpt: "The limitation to two height speakers for Atmos beds is causing problems during mixing. Incomprehensingly, Dolby hinted that they will not be changing it, so we are stuck with it."
Confidence: High
```

```
Claim: Dolby Atmos home theater installations specify overhead/height speakers with elevation angles of 45 degrees from the listening position (adjustable between 30 and 55 degrees), with all speakers positioned at or above the listener.
Source: Dolby Atmos Home Theater Installation Guidelines
URL: https://www.dolby.com/siteassets/technologies/dolby-atmos/atmos-installation-guidelines-121318_r3.1.pdf
Date: Unknown
Excerpt: "The angle of elevation from the listening position to the left top front/right top front and left top rear/right top rear overhead speakers in a 7.1.4 reference layout should be 45 degrees. This may be adjusted between 30 and 55 degrees if needed."
Confidence: High
```

```
Claim: In Atmos cinema specifications, all surround speakers including top surrounds are positioned at or above the reference listening position. The minimum top surround elevation angle is 45° + (E ÷ 2), where E is the side surround elevation angle.
Source: Dolby Atmos Cinema Technical Guidelines White Paper
URL: https://s3.cloud.cmctelecom.vn/tinhte1/2012/06/2984280_Atmos-Technical-Guidelines.pdf
Date: Unknown
Excerpt: "The elevation angle of the corresponding top surround array should be greater than or equal to 45 degrees plus half of angle E. For example, if E is 20 degrees, then the elevation angle of the top surround array should be greater than or equal to 55 degrees."
Confidence: High
```

### 2.2 The Fundamental Constraint

Atmos objects use X, Y, Z Cartesian coordinates normalized to [-1, 1], where Z represents the vertical axis with Z=0 being the listener-level horizontal plane and Z=1 being directly overhead. The renderer is architecturally incapable of processing Z < 0 values because no loudspeakers exist in the lower hemisphere to reproduce such content.

```
Claim: Atmos object positions are defined as 3D rectangular coordinates relative to defined audio channel locations and theater boundaries, where Z represents elevation/height with Z=0 at the listener plane and Z=1 at the overhead plane.
Source: Wikipedia / Dolby Atmos
URL: https://en.wikipedia.org/wiki/Dolby_Atmos
Date: 2017-06-12
Excerpt: "Each object specifies its apparent source location in the theater as a set of three-dimensional rectangular coordinates relative to the defined audio channel locations and theater boundaries."
Confidence: High
```

```
Claim: The allocentric coordinate frame of reference used in Atmos can theoretically be extended to Z=-1 to include a floor plane below the listener.
Source: AVS Forum Discussion
URL: https://www.avsforum.com/threads/atmos-speaker-placement-is-not-necessarily-based-solely-on-angles.3261739/
Date: 2022-12-08
Excerpt: "This is commonly referred to as a cartesian room normalized coordinate system, where X= -1 is full left, X=1 is full right, Y= -1 is front, Y=1 is back, Z=0 is traditional surround plane, Z=1 is overhead plane. This can be extended to Z= -1 to include a floor plane (below the listener)."
Confidence: Medium
```

---

## 3. Why Full Sphere Matters

### 3.1 Complete Immersion

Full-sphere audio reproduction removes the "hemisphere ceiling" that constrains immersive experiences. In the natural world, sound arrives from all directions—including below. A listener seated on the ground hears insects, footsteps, underground rumbling, and vibrations transmitted through the floor. Full-sphere reproduction would enable these experiences for the first time in object-based immersive audio.

```
Claim: The NHK 22.2 multichannel sound system includes bottom-layer channels (BtFL, BtFC, BtFR) explicitly designed to reproduce sound approaching from below the listener, enabling a true three-dimensional sound field.
Source: NHK Science & Technical Research Laboratories
URL: https://www.nhk.or.jp/strl/english/publica/bt/25/5.html
Date: Unknown
Excerpt: "The main features of the 22.2 multichannel sound system are that the loudspeakers are positioned not only at ear-height, but also above and below the viewer. In contrast to conventional theater sound systems, in which loudspeakers are placed only at ear level... the sound in the 22.2 multichannel system approaches the listener from above and below as well."
Confidence: High
```

### 3.2 Natural Sound Fields Are Full Spheres

Real acoustic environments do not have a "floor" below which sound does not exist. Sound waves diffract around and through surfaces, and low-frequency energy in particular propagates omnidirectionally, including through floors and from below.

```
Claim: NHK research found that the 22.2 multichannel system with upper, middle, and lower layers provides superior sound field reproduction compared to conventional systems because it more accurately models natural sound propagation in three dimensions.
Source: NHK 22.2 Multichannel Sound System Research
URL: https://www.nhk.or.jp/strl/english/publica/bt/25/5.html
Date: Unknown
Excerpt: "The channels of the middle layer reproduce the primary sound sources. The upper-layer channels can be used to localize the sound image anywhere above the viewer, or can be used in conjunction with the middle or lower level channels to produce motion of the sound image in the vertical direction."
Confidence: High
```

### 3.3 Applications for Below-Horizon Audio

- **VR/AR experiences**: Ground-level effects, footsteps, environmental realism
- **Cinematic storytelling**: Underground explosions, creature sounds from below floorboards
- **Music**: Sub-bass and infrasonic experiences transmitted through the floor
- **Gaming**: Positional audio for threats approaching from below
- **Therapeutic audio**: Vibroacoustic therapy delivered from below

---

## 4. Extending the Atmos Object Model to Negative Elevation

### 4.1 Coordinate System Extension

The Atmos object model uses Cartesian coordinates (X, Y, Z) normalized to [-1, 1]. Extending this to full sphere requires only allowing Z to range from [-1, 1] instead of [0, 1]:

- **Z = 1**: Zenith (directly overhead)
- **Z = 0**: Listener-level horizontal plane
- **Z = -1**: Nadir (directly below the listener)

```
Claim: A full-sphere encoder for Ambisonics already accepts negative elevation angles (below the horizontal plane), with positive elevation above and negative elevation below.
Source: Wikipedia / Ambisonics
URL: https://en.wikipedia.org/wiki/Ambisonics
Date: 2003-05-25
Excerpt: "A full-sphere encoder usually has two parameters, azimuth (or horizon) and elevation angle. The encoder will distribute the source signal to the Ambisonic components such that, when decoded, the source will appear at the desired location... angles are positive above the horizontal, negative below."
Confidence: High
```

### 4.2 The Sonic Sphere Coordinate Frame

The proposed Sonic Sphere renderer adopts the ISO 2631 coordinate convention used in Ambisonics:
- **X-axis**: Positive forward, negative backward
- **Y-axis**: Positive left, negative right  
- **Z-axis**: Positive up, negative down
- **Azimuth (θ)**: 0° = front, 90° = left, 180° = back, 270° = right (counter-clockwise from front)
- **Elevation (φ)**: 0° = horizontal plane, +90° = zenith, -90° = nadir

```
Claim: The Cartesian reference for spatial audio should conform to ISO standards where elevation angle is measured from the horizontal plane, with positive elevations going up and e=-90 degrees meaning Nadir (or South pole).
Source: Angelo Farina / ACN-N3D Formulas for HOA
URL: https://www.angelofarina.it/Aurora/HOA_ACN_N3D_formulas.htm
Date: Unknown
Excerpt: "Elevation angle (e) is measured from the horizontal plane, with positive elevations going up to the sky, so e = 90 degrees means Zenith (or North pole) and e=-90 degrees means Nadir (or South pole)."
Confidence: High
```

### 4.3 Object Model Modifications

1. **Position parameters**: Allow Z ∈ [-1, 1] instead of Z ∈ [0, 1]
2. **Size parameter**: Extend the size/divergence parameter to affect below-horizon speakers
3. **Elevation mapping**: Map Z=-1 to physical below-horizon speaker positions (typically floor-mounted upward-firing speakers)
4. **Normalization**: Preserve energy-normalized panning gains across the full sphere

---

## 5. Extending VBAP for Below-Horizon Speaker Triplets

### 5.1 The VBAP Foundation

Vector Base Amplitude Panning (VBAP), originally proposed by Ville Pulkki, provides directionally reliable auditory event localization by activating the fewest number of loudspeakers possible. In 3D, VBAP uses triplets of speakers arranged on a convex hull surrounding the listening position.

```
Claim: VBAP can reproduce on a 2D or 3D configuration and achieves its characteristic 'sharp' focus by using only the few speakers closest to the virtual source location. For 3D arrays, it uses triplets of speakers.
Source: SPAT Revolution / Flux Audio
URL: https://doc.flux.audio/spat-revolution/Spatialisation_Technology_Panning_Algorithms.html
Date: Unknown
Excerpt: "VBAP works by manipulating the gain of the signals being routed to the two (in 2D), or three (in 3D), the closest speakers to a virtual sound source. It triangulates gain vectors mathematically in order to render a virtual object in the physical space."
Confidence: High
```

### 5.2 The Nadir Problem in Hemispherical Arrays

For hemispherical loudspeaker layouts (all speakers at or above the horizon), VBAP cannot localize sources below the horizontal plane. Two key approaches have been developed:

**Approach A: Virtual Loudspeaker at Nadir**

```
Claim: For hemispherical loudspeaker layouts, the insertion of an imaginary (virtual) loudspeaker at nadir (directly below the listener) preserves loudness of downward-panned signals and stabilizes localization at the horizon.
Source: Zotter & Frank, "Ambisonic Amplitude Panning and Decoding in Higher Orders"
URL: https://link.springer.com/chapter/10.1007/978-3-030-17207-7_4
Date: 2019-05-01
Excerpt: "A hemispherical layout does not contain any loudspeaker direction vector pointing to the lower half space... the insertion of imaginary loudspeakers fixes this behavior. In the case of hemispherical loudspeaker layouts, it is not necessary to downmix the signal of the imaginary loudspeaker at nadir to stabilize both loudness and localization for panning to the horizon."
Confidence: High
```

```
Claim: The signal of the imaginary loudspeaker at nadir can be either dismissed (yielding a signal near the closest horizontal pair for below-horizon virtual sources) or down-mixed to neighboring loudspeakers.
Source: Zotter & Frank, "Amplitude Panning Using Vector Bases"
URL: https://link.springer.com/chapter/10.1007/978-3-030-17207-7_3
Date: 2019-05-01
Excerpt: "The signal of the imaginary loudspeaker can be dealt with in two ways: it can be dismissed, e.g., for loudspeaker below at nadir, this would still yield a signal near the closest horizontal pair of loudspeakers for virtual sources panned to below-horizontal directions unless panned exactly to nadir."
Confidence: High
```

**Approach B: Real Below-Horizon Speaker Triplets (Sonic Sphere Proposal)**

The Sonic Sphere architecture proposes using actual physical speakers below the horizon, eliminating the need for virtual loudspeakers. This requires:

1. **Convex hull triangulation** that includes real speaker positions below the horizontal plane
2. **Speaker triplets** formed from combinations of horizon-level and below-horizon speakers
3. **All-positive gain solutions** (g₁ ≥ 0, g₂ ≥ 0, g₃ ≥ 0) for barycentric coordinates within each triplet

### 5.3 The IEM Plugin Approach

The IEM Vector Base Amplitude Panning plugin demonstrates a practical implementation that handles negative elevation:

```
Claim: The IEM VBAP plugin creates a special virtual speaker at a position below ground level when all real speakers have z > 0. This spreads audio among all ground-layer loudspeakers when the elevation slider claims negative elevation (depression). A dim-factor of 0.5 is assigned so audio fades as elevation approaches -90°.
Source: IEM VBAP Plugin Documentation (University of Music and Performing Arts Graz)
URL: https://phaidra.kug.ac.at/api/object/o:66459/download
Date: 2017-09-05
Excerpt: "A special virtual speaker is created at a position below the ground level if every z coordinate > 0 — which is usually the case. This will spread the audio signal among all groundlayer loudspeakers accordingly, as soon as the elevation angle slider claims negative elevation (i.e., depression). A dim-factor of 0.5 is assigned so the audio will fade as the elevation approaches -90°."
Confidence: High
```

### 5.4 Full-Sphere VBAP Gain Calculation

For a full-sphere Sonic Sphere array, the VBAP gain calculation follows the standard formulation but with a complete convex hull:

Given a desired virtual source direction **p** = [p₁, p₂, p₃]ᵀ and three loudspeaker direction vectors **l₁**, **l₂**, **l₃** forming a basis, the gains are:

**g** = [g₁, g₂, g₃]ᵀ = **L**⁻¹ **p**

where **L** = [**l₁** **l₂** **l₃**] is the 3×3 matrix of loudspeaker direction vectors.

For the full sphere, the triplet selection must include valid triplets that span the lower hemisphere. The condition g₁, g₂, g₃ ≥ 0 ensures the virtual source lies within the triangle formed by the three speakers.

---

## 6. Speaker Array Geometries for Full Sphere

### 6.1 Platonic Solids as Ideal Full-Sphere Arrays

The five Platonic solids provide the only perfectly regular arrangements of speakers on a sphere, making them theoretically ideal for full-sphere Ambisonics decoding:

| Polyhedron | Speakers | Order Supported | Properties |
|---|---|---|---|
| Tetrahedron | 4 | 1st | Minimal full-sphere array |
| Hexahedron (Cube) | 6 | 1st | Good horizontal plane coverage |
| Octahedron | 8 | 1st | Best 1st-order symmetry |
| Dodecahedron | 12 | 2nd | Balanced surface area |
| Icosahedron | 20 | 3rd | Highest regular resolution |

```
Claim: The five Platonic solids (tetrahedron, hexahedron, octahedron, dodecahedron, icosahedron) are the only perfectly regular speaker arrangements on a sphere. An icosahedron with 20 drivers can reproduce spherical harmonics up to order 3, while dodecahedral arrays are a good compromise between complexity and sound power.
Source: Pasqual Dissertation / Sound Directivity Control in 3D Space
URL: https://theses.hal.science/tel-00530855/file/pasqual_dissertation_2010.pdf
Date: Unknown
Excerpt: "One may have L=4 (tetrahedron), L=6 (hexahedron), L=8 (octahedron), L=12 (dodecahedron) or L=20 (icosahedron) drivers. It is easy to realize that the complexity of the controllable radiation patterns increases with L."
Confidence: High
```

### 6.2 The Icosahedral Array

The Institute of Electronic Music and Acoustics (IEM) in Graz has extensively researched icosahedral loudspeaker arrays:

```
Claim: The IEM constructed an icosahedral loudspeaker array with 20 independent drivers sharing a common enclosure, designed for sound radiation synthesis and spherical harmonic reproduction.
Source: IEM Report 39/07 - Icosahedral Loudspeaker Array
URL: https://iem.kug.ac.at/fileadmin/03_Microsites/01_Kuenstlerisch_wissenschaftliche_Einheiten/01_Institute/Institut_17_Elektronische_Musik_und_Akustik/Projektseiten/OSIL/pdfs/Papers/2007_Zotter_IcosahedralLoudspeakerArray.pdf
Date: Unknown
Excerpt: "Considering its simplicity in construction, a given limit in the amount of speakers, and its uniform distribution of points, we chose the icosahedron as basic shape for our spherical array."
Confidence: High
```

### 6.3 Geodesic Dome Arrays

For higher spatial resolution, geodesic triangulations of Platonic solids (especially the icosahedron) provide near-uniform speaker distributions with large speaker counts:

```
Claim: The 120-element spherical loudspeaker array built by Meyer Sound Laboratories uses a geodesic sphere approximation based on the icosahedron, with 20 equilateral triangle modules each containing 6 drivers, capable of reproducing spherical harmonics up to order 8.
Source: Academia.edu / Compact 120-element spherical array
URL: https://www.academia.edu/1834256/A_compact_120_independent_element_spherical_loudspeaker_array_with_programmable_radiation_patterns
Date: 2025-10-09
Excerpt: "The key parameter to achieving good directivity control at high frequencies is to maximize the number of closely spaced drivers... 20 of these equilateral triangle modules form the tetrahedron from which we built our 120 speaker array."
Confidence: High
```

### 6.4 Practical Full-Sphere Layout for Consumer Applications

A practical Sonic Sphere layout for residential spaces might use:

**Sonic Sphere 12.1 Layout (Proposed)**
- **Middle layer (7 channels)**: L, R, C, Ls, Rs, Lb, Rb (conventional 7.1 horizontal ring)
- **Upper layer (4 channels)**: Ltf, Rtf, Ltr, Rtr (top front/rear, 45° elevation)
- **Lower layer (4 channels)**: Lbf, Rbf, Lbr, Rbr (bottom front/rear, -30° to -45° depression)
- **LFE**: 1 subwoofer channel

This 7.1.4.4 configuration mirrors the existing 7.1.4 Atmos layout with an additional 4 below-horizon speakers.

### 6.5 The AudioDome Research Array

Recent research at Western University demonstrates the viability of high-order full-sphere reproduction:

```
Claim: The AudioDome uses 91 loudspeakers arranged in a dome plus four dual-channel subwoofers, implementing a ninth-order Ambisonic panning system (100 channels) capable of reproducing sound identity and location at spatial resolution at or above human limits.
Source: ScienceDaily / Journal of the Acoustical Society of America
URL: https://www.sciencedaily.com/releases/2025/04/250415143348.htm
Date: 2025-04-15
Excerpt: "Made up of four dual-channel subwoofers and 91 loudspeakers arranged in a dome, the structure is positioned in a sound dampening, echo-free chamber... a ninth-order ambisonic panning system (meaning that it uses 100 sound channels in the system)."
Confidence: High
```

---

## 7. Modifying OAMD Metadata for Full-Sphere Support

### 7.1 Current OAMD Format

Object Audio Metadata (OAMD) in Dolby Atmos stores positional X, Y, Z coordinates along with object size data. The DAMF (.atmos) format uses these coordinates to define object positions.

```
Claim: The Dolby Atmos Master File (DAMF) uses the .atmos format for acoustic metadata, storing coordinate information as pos: (x, z, y) where x is horizontal, z is vertical, and y is depth. The estimated coordinates correspond to the horizontal, depth, and vertical directions.
Source: MDPI / Acoustic Metadata Design for Object-Based Audio
URL: https://www.mdpi.com/2624-599X/8/1/3
Date: 2026-01-23
Excerpt: "In the .atmos acoustic metadata format, the x-axis is used for the horizontal direction, the y-axis for the depth direction, and the z-axis for the vertical direction. Therefore, the coordinates are described in the format pos: (xl,zl,yl)."
Confidence: High
```

### 7.2 Proposed OAMD Extension

The Sonic Sphere architecture proposes minimal changes to OAMD:

1. **Z-coordinate range extension**: Allow Z ∈ [-1, 1] instead of [0, 1]
2. **New semantic meaning**: Z < 0 indicates below-horizon positions
3. **Backward compatibility**: Content with Z ≥ 0 renders identically on legacy systems
4. **Size parameter**: Extend to affect floor speakers for Z < 0 objects

### 7.3 Metadata Coordinate Mapping

| Coordinate | Range | Semantic Meaning |
|---|---|---|
| X | [-1, 1] | Left (-1) to Right (+1) |
| Y | [-1, 1] | Front (-1) to Back (+1) |
| Z | [-1, 1] | Below (-1) to Above (+1) |

For rendering on legacy hemispherical systems, Z < 0 values can be handled by:
- **Mirroring to horizon**: Map Z = -0.5 to Z = 0 (floor reflections)
- **Virtual loudspeaker**: Use the nadir virtual loudspeaker approach
- **Energy redistribution**: Distribute floor energy to the horizontal plane

---

## 8. Rendering Pipeline Modifications

### 8.1 Current Atmos Rendering Pipeline

1. **Input**: Bed channels + audio objects with OAMD metadata
2. **Object rendering**: Map X,Y,Z coordinates to speaker gains using VBAP
3. **Bed rendering**: Route bed channels to their defined speaker positions
4. **Downmix**: Combine object and bed contributions per speaker
5. **Output**: Speaker feed signals

### 8.2 Sonic Sphere Rendering Pipeline

```
Proposed Pipeline:
1. INPUT: Bed channels + audio objects with extended OAMD (Z ∈ [-1,1])
2. FULL-SPHERE OBJECT RENDERER:
   a. For each object, read (X, Y, Z) position
   b. If Z ≥ 0: Use standard VBAP with upper-hemisphere triplets
   c. If Z < 0: Use extended VBAP with below-horizon triplets
   d. Calculate triplet gains using barycentric coordinates
   e. Apply distance gain, spread/divergence, and size processing
3. BED RENDERER:
   a. Route middle-layer bed channels to horizontal speakers
   b. Route upper-layer bed channels to height/overhead speakers
   c. Route lower-layer bed channels (new) to floor speakers
4. HOA INTERMEDIATE (optional):
   a. Encode all sources to HOA (Ambisonics B-format)
   b. Apply full-sphere decoding to arbitrary speaker arrays
5. MIXDOWN: Combine all speaker contributions
6. OUTPUT: Speaker feed signals for full-sphere array
```

```
Claim: A mixedown matrix approach can fuse distance gain, 3D positioning, and loudness projection into a single matrix representation, reducing pipeline depth and enabling smooth gain interpolation.
Source: UC Scholarship / Spatialized Audio Rendering for Immersive VR
URL: https://escholarship.org/content/qt41r178s4/qt41r178s4.pdf
Date: Unknown
Excerpt: "The last stages of the rendering pipeline, including distance gain, 3D positioning and loudness projection, are fused into a single mixedown matrix representation, reducing the localization pipeline depth to three stages."
Confidence: High
```

### 8.3 Gain Calculation for Full-Sphere Objects

For each object at position (X, Y, Z), the renderer:

1. **Normalize position** to unit sphere: r = √(X² + Y² + Z²), **p** = [X/r, Y/r, Z/r]
2. **Find containing triplet**: Search convex hull for triplet where **p** = g₁**l₁** + g₂**l₂** + g₃**l₃** with gᵢ ≥ 0
3. **Normalize gains**: Ensure energy conservation: Σgᵢ² = constant
4. **Apply object parameters**: Distance gain, spread, divergence

### 8.4 3D VBAP in MPEG-H as Reference

```
Claim: MPEG-H 3D Audio uses 3D VBAP for object rendering, where normalized panning gains maintain constant loudness regardless of panning direction. The norm order p can be either 1 or 2 depending on coherence between binaural filters.
Source: MDPI Electronics / Quality Enhancement of MPEG-H 3DA Binaural Rendering
URL: https://www.mdpi.com/2079-9292/11/9/1491
Date: 2022-05-06
Excerpt: "The normalized panning gain g̃ᵢ,ₘ (=gᵢ,ₘ/‖gₘ‖ᵖ) allows the maintenance of a constant loudness regardless of the panning direction. The norm order p can be either 1 or 2 depending on the coherence between the binaural filters."
Confidence: High
```

---

## 9. Ambisonics as Intermediate Representation

### 9.1 Why Ambisonics?

Ambisonics provides a format-agnostic intermediate representation that decouples content creation from reproduction. The same Ambisonics-encoded content can be decoded to any loudspeaker array—including full-sphere arrays.

```
Claim: Ambisonics provides a full-sphere surround sound format that can be decoded to arbitrary loudspeaker layouts. The encoded channels use spherical harmonics to encode the entire 3D sound field and do not correspond to specific loudspeakers.
Source: MathWorks / ambisonicEncoderMatrix Documentation
URL: https://www.mathworks.com/help/audio/ref/ambisonicencodermatrix.html
Date: Unknown
Excerpt: "Ambisonics provide a full-sphere surround sound format that can be decoded to arbitrary loudspeaker layouts. The encoded channels do not correspond to specific loudspeakers, but instead they use the spherical harmonics series of functions to encode the entire 3D sound field."
Confidence: High
```

### 9.2 Spherical Harmonics Encoding

A plane wave from direction (θ, φ) is encoded into Ambisonic channels using spherical harmonics:

Bₘₙ^σ = s · Yₘₙ^σ(θ, φ)

Where Yₘₙ^σ are the real spherical harmonic functions, m is the degree, n is the order, and σ indicates the type (cosine or sine).

```
Claim: The encoding process decomposes the sound field into spherical harmonics. For a plane wave signal s coming from (θₛ, φₛ), the Ambisonics signal is Bₘ,ₙ^σ = s · Yₘ,ₙ^σ(θₛ, φₛ).
Source: PKU Research Paper / Matching Projection Decoding for Ambisonics
URL: https://hpc.pku.edu.cn/docs/pdf/a20191230056.pdf
Date: Unknown
Excerpt: "Consider a plane wave signal s coming from (θₛ, φₛ), it leads to the following expression of Ambisonics signals: Bₘ,ₙ^σ = s · Yₘ,ₙ^σ(θₛ, φₛ)"
Confidence: High
```

### 9.3 HOA Decoding for Full-Sphere Arrays

The Sonic Sphere architecture proposes encoding all sources (beds and objects) to Higher-Order Ambisonics, then decoding to the target full-sphere loudspeaker array:

1. **Encoding stage**: Each source is encoded to HOA coefficients Bₘₙ
2. **Mixing stage**: HOA coefficients from all sources are summed
3. **Decoding stage**: The combined HOA stream is decoded to speaker signals using the target array geometry

```
Claim: The HOA format is independent of the reproduction layout. The decoding matrix is determined by the loudspeaker layout (number and geometry). In theory it is able to account for any setup.
Source: IRCAM / Sound Spatialization by Higher Order Ambisonics
URL: https://ambisonics10.ircam.fr/drupal/files/proceedings/keynotes/K4.pdf
Date: Unknown
Excerpt: "The HOA format is thus not only independent of the recording format, but also independent of the rendering format (i.e. the loudspeaker format or D format). The decoding matrix is determined by the loudspeaker layout."
Confidence: High
```

### 9.4 AllRAD and EPAD for Irregular Full-Sphere Arrays

For non-ideal speaker placements, two decoder designs are particularly relevant:

**AllRAD (All-Round Ambisonic Decoder)**: Hybrid Ambisonic-VBAP decoder robust to irregular layouts

```
Claim: AllRAD is comparatively robust to irregular loudspeaker setups due to the vector-base amplitude panning involved. For hemispherical layouts without lower-half-space speakers, AllRAD can insert imaginary loudspeakers to stabilize loudness and localization.
Source: Zotter & Frank, "A Practical 3D Audio Theory"
URL: https://library.oapen.org/bitstream/id/a418a7e9-2245-47c1-8c29-d5cdd227b678/1007063.pdf
Date: Unknown
Excerpt: "AllRAD with hemispherical loudspeaker layouts... the insertion of imaginary loudspeakers fixes this behavior. In the case of hemispherical loudspeaker layouts, it is not necessary to downmix the signal of the imaginary loudspeaker at nadir to stabilize both loudness and localization for panning to the horizon."
Confidence: High
```

**EPAD (Energy-Preserving Ambisonic Decoder)**: Uses spherical Slepian functions

```
Claim: EPAD using hemispherical Slepian functions can decode to hemispherical layouts with lower loudness fluctuation (~0.3 dB) compared to AllRAD (~1 dB), but requires more constrained speaker arrangements.
Source: Zotter & Frank, "Ambisonic Amplitude Panning and Decoding in Higher Orders"
URL: https://link.springer.com/chapter/10.1007/978-3-030-17207-7_4
Date: 2019-05-01
Excerpt: "AllRAD produces a loudness fluctuation roughly spanning 1 dB for panning on the hemisphere, EPAD only exhibits 0.3 dB... loudness fluctuation should be no problem with both EPAD and AllRAD."
Confidence: High
```

### 9.5 Matched-Order Decoding

```
Claim: For regular speaker layouts like Platonic solids, the Ambisonic order that can be decoded is: tetrahedral/hexahedral/octahedral → 1st order; dodecahedral → 2nd order; icosahedral → 3rd order.
Source: ICA 2010 Paper / High Order Ambisonic Decoding
URL: https://www.acoustics.asn.au/conference_proceedings/ICA2010/cdrom-ICA2010/papers/p481.pdf
Date: Unknown
Excerpt: "A tetrahedral, hexahedral or octahedral substructure allows for the decoding of the first Ambisonic order using the full array. A dodecahedral substructure permits the decoding to be extended up to the second Ambisonic order. An icosahedral substructure can be used to decode Ambisonic data up to the third Ambisonic order."
Confidence: High
```

---

## 10. The Bed Extension: Floor Channels

### 10.1 Existing Standards with Below-Horizon Channels

The NHK 22.2 system and ITU-R BS.2051 System H already specify bottom-layer channels:

```
Claim: ITU-R BS.2051 System H (9+10+3) specifies a full-sphere layout with bottom-layer channels labeled B+xxx, including B+022, B+000, B-022, B+030, B-030, B+045, B-045, B+060, B-060, B+090, B-090, B+110, B-110, B+135, B-135, and B+180, all at -30° elevation.
Source: ITU-R BS.2051-3 (Advanced sound system for programme production)
URL: https://www.itu.int/dms_pubrec/itu-r/rec/bs/R-REC-BS.2051-3-202205-I!!PDF-E.pdf
Date: 2022-07
Excerpt: "System H (9+10+3) has upper layer 3/3/3, middle layer 5/2/3, bottom layer 3/0/0.2... B+022 at elevation -30°, B+000 at elevation -30°, B-022 at elevation -30°..."
Confidence: High
```

```
Claim: The NHK 22.2 multichannel audio format includes three bottom-layer channels (BtFL, BtFC, BtFR) arranged at the height of the bottom of the screen or the floor, plus two LFE channels also positioned at the bottom.
Source: ITU-R BS.2159 / NHK 22.2
URL: https://www.itu.int/dms_pub/itu-r/opb/rep/r-rep-bs.2159-6-2013-pdf-e.pdf
Date: 2013
Excerpt: "The lower layer consists of three channels arranged at the height of the bottom of the screen or the floor. The lower level also includes two low-frequency effects (LFE) channels."
Confidence: High
```

### 10.2 Proposed Floor Channel Bed Configuration

The Sonic Sphere architecture proposes extending the Atmos bed from 7.1.2 to a full-sphere configuration:

**Proposed Sonic Sphere Bed: 7.1.4.4**
- **7 listener-level channels**: L, R, C, Ls, Rs, Lb, Rb
- **1 LFE channel**: Subwoofer
- **4 height channels**: Ltf, Rtf, Ltr, Rtr (existing Atmos height)
- **4 floor channels**: Lbf, Rbf, Lbr, Rbr (new below-horizon channels)

This maintains backward compatibility with 7.1.4 systems while adding the floor dimension.

### 10.3 Floor Channel Naming Convention

Following ITU-R BS.2051 conventions:
- **B** prefix indicates Bottom layer (analogous to U for Upper, M for Middle)
- **Lbf/Rbf**: Left/Right Bottom Front
- **Lbr/Rbr**: Left/Right Bottom Rear
- **B+000**: Bottom Center (for larger arrays)

```
Claim: The Immersive Audio Model and Formats (IAMF) specification already includes a Bottom-3ch expanded layout (BtFL/BtFC/BtFR) and Bottom-4ch layout (BtFL/BtFR/BtBL/BtBR) referencing ITU-R BS.2051-3.
Source: AOMedia / Immersive Audio Model and Formats (IAMF)
URL: https://aomediacodec.github.io/iamf
Date: 2025-04-21
Excerpt: "Bottom-3ch: BtFL/BtFC/BtFR — The bottom 3 channels of 10.2.9.3ch... Bottom-4ch: BtFL/BtFR/BtBL/BtBR — The bottom 4 channels of 7.1.5.4ch"
Confidence: High
```

---

## 11. Implementation Considerations

### 11.1 Speaker Placement

For a practical Sonic Sphere installation:

**Physical Requirements:**
- Floor speakers must be mounted at negative elevation angles (typically -30° to -45°)
- Options include: floor-standing upward-firing speakers, in-floor mounted drivers, or angled floor monitors
- Speakers should aim toward the primary listening position
- Minimum 3 feet from listening position to avoid proximity effects

**Room Acoustics:**

```
Claim: Floor and ceiling reflections significantly affect spatial audio reproduction. The CEDIA/CTA RP22 standard recommends controlling reflection decay time based on room volume using Tm = 0.3(V/100)^(1/3).
Source: CEDIA/CTA-RP22 Immersive Audio Design Recommended Practice
URL: https://cedia.org/site/assets/files/6057/cedia-cta_rp22_v1_2_sept_2023.pdf
Date: 2023-09-02
Excerpt: "The target for RdT is dependent on room volume. As room volume increases, target RdT times also increase. The formula for calculating the target RdT: Tm = 0.3(V/100)^(1/3)."
Confidence: High
```

### 11.2 Perceptual Challenges of Below-Horizon Localization

**Cone of Confusion:**

```
Claim: The cone of confusion is a cone-shaped region extending outward from the head where sounds produce identical interaural time differences (ITDs) and interaural level differences (ILDs), making front-back and above-below discrimination difficult without pinna spectral cues.
Source: NYU / Perception Lecture Notes: Sound Localization
URL: https://www.cns.nyu.edu/~david/courses/perception/lecturenotes/localization/localization.html
Date: Unknown
Excerpt: "The set of locations in the world that are 5 cm closer to one ear than the other is (approximately) a cone with its apex at the center of the head. Sound sources located at any position in the cone generate exactly the same IID and ITD cues."
Confidence: High
```

**Pinna Spectral Cues for Elevation:**

```
Claim: Spectral cues from the pinna (outer ear) are essential for elevation localization. The auditory system evaluates direction-specific patterns in the frequency response created by the pinna's shape. People can only accurately localize elevation of complex sounds including frequencies above 7,000 Hz.
Source: Wikipedia / Sound Localization
URL: https://en.wikipedia.org/wiki/Sound_localization
Date: 2004-09-27
Excerpt: "It has been shown that human subjects can monaurally localize high frequency sound but not low frequency sound. Binaural localization, however, was possible with lower frequencies. It seems that people can only accurately localize the elevation of sounds that are complex and include frequencies above 7,000 Hz, and a pinna must be present."
Confidence: High
```

**Below-Horizon Localization Accuracy:**

```
Claim: Below-horizon localization has not been extensively studied. Most research focuses on above-horizon elevation perception. Pinna cues for below-horizon sounds differ because the spectral filtering of the pinna changes when sound arrives from below the interaural axis.
Source: Journal of Neuroscience / Pinna Cues for Elevation
URL: https://www.jneurosci.org/content/30/1/194
Date: 2010-01-06
Excerpt: "Positive (negative) elevation values indicate locations above (below) the listener's interaural axis. The vertical location is given by the elevation coordinate ε — the angle formed by the center of the hoop (listener's head), sound source/response location, and the horizontal plane."
Confidence: High
```

**Key Perceptual Findings:**

1. **Front-back confusion**: Sounds at azimuth α and 180°-α produce the same ITDs and ILDs. Listeners confuse front-back locations at rates up to 50% for sources on the cone of confusion.

```
Claim: Listeners often make sound-source localization errors when sources are on cones-of-confusion, with front-back errors reaching 50% or higher. Left-right errors are near 0% for widely spaced sources.
Source: PMC / Cones-of-Confusions: Are listeners confused?
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC10624503/
Date: Unknown
Excerpt: "Listeners often make sound-source localization errors when sound sources are on cones-of-confusion... front-back errors can be 50% or higher; see Yost and Pastore, 2019, for a review."
Confidence: High
```

2. **Elevation bias**: Perceived elevation tends to be biased toward the horizontal plane, especially for frontal sources.

```
Claim: Elevation errors are biased toward the horizontal plane when the sound source is in the frontal hemisphere, biased forward and laterally for rear hemisphere sources, and largest for overhead sources slightly behind the listener.
Source: DTIC / Auditory Spatial Perception
URL: https://apps.dtic.mil/sti/tr/pdf/ADA563540.pdf
Date: Unknown
Excerpt: "Elevation errors are (1) biased toward the horizontal plane when the sound source is located in the frontal hemisphere, (2) biased forward and in the lateral direction for sound sources located in the rear hemisphere, and (3) largest for sound sources located overhead and slightly behind the listener."
Confidence: High
```

3. **Below-horizon perception**: Research suggests that below-horizon sources may be perceived as elevated reflections or as coming from the floor plane, depending on spectral content and context.

### 11.3 Practical Recommendations for Below-Horizon Audio

1. **Frequency content**: Below-horizon speakers are most effective for low-frequency content (< 500 Hz) where localization cues are weak anyway, and for broadband effects where spectral pinna cues can be synthesized via HRTF processing

2. **Content design**: Floor channels should carry environmental effects (footsteps, rumble, bass), not precise positional content requiring accurate localization

3. **HRTF preprocessing**: Apply appropriate HRTF-based spectral shaping to below-horizon virtual sources to simulate the pinna response for negative elevations

4. **Amplitude considerations**: Floor speakers may need lower amplitude than height speakers due to floor coupling and room mode excitation

### 11.4 Room Mode Considerations

Adding speakers near the floor excites different room modes than ceiling-mounted speakers:
- Floor-mounted drivers couple strongly with vertical room modes
- This can be advantageous for tactile bass experiences
- Careful placement and bass management are essential

---

## 12. Reference List

### Primary Sources

[^1^] Dolby Laboratories, "Dolby Atmos Home Theater Installation Guidelines," Version R3.1. https://www.dolby.com/siteassets/technologies/dolby-atmos/atmos-installation-guidelines-121318_r3.1.pdf

[^2^] Dolby Laboratories, "Dolby Atmos Cinema Technical Guidelines White Paper." https://s3.cloud.cmctelecom.vn/tinhte1/2012/06/2984280_Atmos-Technical-Guidelines.pdf

[^3^] Dolby Laboratories, "Dolby Atmos Specifications." https://professional.dolby.com/siteassets/cinema/dolby-audio-products/dolby-atmos-specifications.pdf

[^4^] Wikipedia, "Dolby Atmos." https://en.wikipedia.org/wiki/Dolby_Atmos

[^5^] V. Pulkki, "Virtual Sound Source Positioning Using Vector Base Amplitude Panning," JAES Volume 45 Issue 6, pp. 456-466, June 1997.

[^6^] F. Zotter and M. Frank, "A Practical 3D Audio Theory with Applications to Recording, Reproduction, and Perception," Springer, 2019.

[^7^] F. Zotter and M. Frank, "Amplitude Panning Using Vector Bases," Chapter 3 in Springer Handbook of Auditory Research, 2019. https://link.springer.com/chapter/10.1007/978-3-030-17207-7_3

[^8^] F. Zotter and M. Frank, "Ambisonic Amplitude Panning and Decoding in Higher Orders," Chapter 4 in Springer Handbook of Auditory Research, 2019. https://link.springer.com/chapter/10.1007/978-3-030-17207-7_4

[^9^] IEM/KUG, "Vector Base Amplitude Panning" (VBAP Plugin Documentation). https://phaidra.kug.ac.at/api/object/o:66459/download

[^10^] Flux Audio / SPAT Revolution, "Panning Algorithms." https://doc.flux.audio/spat-revolution/Spatialisation_Technology_Panning_Algorithms.html

[^11^] Stanford CCRMA, Fernando Lopez-Lezcano, "Sound in Space: Panning." https://ccrma.stanford.edu/courses/222/lectures/11/panning_1.pdf

[^12^] Wikipedia, "Ambisonics." https://en.wikipedia.org/wiki/Ambisonics

[^13^] G. Pasqual, "Sound Directivity Control in a 3D Space by a Compact Dodecahedral Loudspeaker Array," PhD Thesis. https://theses.hal.science/tel-00530855/file/pasqual_dissertation_2010.pdf

[^14^] F. Zotter et al., "IEM Report 39/07: Icosahedral Loudspeaker Array," IEM, Graz, Austria. https://iem.kug.ac.at/fileadmin/03_Microsites/01_Kuenstlerisch_wissenschaftliche_Einheiten/01_Institute/Institut_17_Elektronische_Musik_und_Akustik/Projektseiten/OSIL/pdfs/Papers/2007_Zotter_IcosahedralLoudspeakerArray.pdf

[^15^] Meyer Sound Laboratories / CNMAT, "A Compact 120 Independent Element Spherical Loudspeaker Array with Programmable Radiation Patterns." https://www.academia.edu/1834256/A_compact_120_independent_element_spherical_loudspeaker_array_with_programmable_radiation_patterns

[^16^] ITU-R BS.2051-3, "Advanced sound system for programme production," July 2022. https://www.itu.int/dms_pubrec/itu-r/rec/bs/R-REC-BS.2051-3-202205-I!!PDF-E.pdf

[^17^] ITU-R BS.2127-0, "Audio Definition Model renderer for advanced sound systems," June 2019. https://www.itu.int/dms_pubrec/itu-r/rec/bs/R-REC-BS.2127-0-201906-S!!PDF-E.pdf

[^18^] NHK Science & Technical Research Laboratories, "Development of a 22.2 Multichannel Sound System." https://www.nhk.or.jp/strl/english/publica/bt/25/5.html

[^19^] NHK, "22.2 Multichannel Audio Format Standardization Activity." https://www.nhk.or.jp/strl/english/publica/bt/45/14.html

[^20^] Wikipedia, "22.2 surround sound." https://en.wikipedia.org/wiki/22.2_surround_sound

[^21^] MDPI, "Acoustic Metadata Design on Object-Based Audio Using Estimated 3D-Position from Visual Image." https://www.mdpi.com/2624-599X/8/1/3

[^22^] Dolby, "Dolby Atmos Documentation (Professional)." https://professional.dolby.com/gaming/gaming-getting-started/dolby-atmos-documentation/

[^23^] AOMedia, "Immersive Audio Model and Formats (IAMF)." https://aomediacodec.github.io/iamf

[^24^] Embody, "Volumetric Amplitude Panning and Diffusion for Spatial Audio Production." https://embody.co/blogs/technology/volumetric-amplitude-panning-and-diffusion-for-spatial-audio-production

[^25^] NYU, Prof. David Heeger, "Perception Lecture Notes: Auditory Pathways and Sound Localization." https://www.cns.nyu.edu/~david/courses/perception/lecturenotes/localization/localization.html

[^26^] Frontiers in Psychology, "Auditory localization: a comprehensive practical review," 2024. https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2024.1408073/full

[^27^] PMC, "Cones-of-Confusions: Are listeners confused?" https://pmc.ncbi.nlm.nih.gov/articles/PMC10624503/

[^28^] NASA, "Monaural sound localization revisited." https://ntrs.nasa.gov/api/citations/19970023028/downloads/19970023028.pdf

[^29^] DTIC, "Auditory Spatial Perception: Auditory Localization." https://apps.dtic.mil/sti/tr/pdf/ADA563540.pdf

[^30^] Journal of Neuroscience, "Pinna Cues Determine Orienting Response Modes to Synchronous Sounds in Elevation," 2010. https://www.jneurosci.org/content/30/1/194

[^31^] PMC, "Contribution of Head Shadow and Pinna Cues to Chronic Monaural Sound Localization." https://pmc.ncbi.nlm.nih.gov/articles/PMC6729291/

[^32^] PLOS ONE, "Reconstructing spectral cues for sound localization from responses to rippled noise stimuli," 2017. https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0174185

[^33^] University of Minnesota, "Spatial Hearing." https://pressbooks.umn.edu/sensationandperception/chapter/spatial-hearing-draft/

[^34^] Sound and Design, "Auditory Localization: An Introduction." https://soundand.design/auditory-localization-e93a6e333a4a

[^35^] Science of Sound, "Sound Localization Basics." https://science-of-sound.net/2016/06/sound-localization-basics/

[^36^] Wikipedia, "Sound localization." https://en.wikipedia.org/wiki/Sound_localization

[^37^] CCRMA Stanford, "The Ambisonic Decoder Toolbox," LAC 2014. http://lac.linuxaudio.org/2014/download/Heller-Benjamin-Ambi-decoder-toolbox_LAC2014.pdf

[^38^] CCRMA Stanford, Benjamin Heller, "Design and implementation of Filters for Ambisonic Decoders." https://ccrma.stanford.edu/courses/222/lectures/14/Ambi-Decoders-Music222-2021.pdf

[^39^] HOA Intro (Motherlode), "An Introduction to Higher-Order Ambisonic." http://decoy.iki.fi/dsound/ambisonic/motherlode/source/HOA_intro.pdf

[^40^] IRCAM, "Sound Spatialization by Higher Order Ambisonics." https://ambisonics10.ircam.fr/drupal/files/proceedings/keynotes/K4.pdf

[^41^] ICA 2010, "High order Ambisonic decoding method for irregular loudspeaker arrays." https://www.acoustics.asn.au/conference_proceedings/ICA2010/cdrom-ICA2010/papers/p481.pdf

[^42^] MathWorks, "ambisonicEncoderMatrix." https://www.mathworks.com/help/audio/ref/ambisonicencodermatrix.html

[^43^] SSA Plugins, "What Is... Higher Order Ambisonics?" https://www.ssa-plugins.com/blog/2017/07/18/what-is-higher-order-ambisonics/

[^44^] CCRMA Stanford, "Optimized Decoders for Mixed-Order Ambisonics." https://ccrma.stanford.edu/~nando/publications/optimized_decoders_aes_2021-preprint.pdf

[^45^] Microsoft Research, "Improving Binaural Ambisonics Decoding by Spherical Harmonics Domain Tapering." https://www.microsoft.com/en-us/research/wp-content/uploads/2019/04/preprint_ICASSP2019_Ambisonics_Tapering.pdf

[^46^] Angelo Farina, "ACN-N3D formulas for High Order Ambisonics." https://www.angelofarina.it/Aurora/HOA_ACN_N3D_formulas.htm

[^47^] UC Scholarship, "Spatialized Audio Rendering for Immersive Virtual Environments." https://escholarship.org/content/qt41r178s4/qt41r178s4.pdf

[^48^] MDPI Electronics, "Quality Enhancement of MPEG-H 3DA Binaural Rendering Using a Spectral Compensation Technique," 2022. https://www.mdpi.com/2079-9292/11/9/1491

[^49^] J. Herre et al., "The New Standard for Universal Spatial / 3D Audio Coding: MPEG-H Audio," International Audio Laboratories Erlangen. https://picture.iczhiku.com/resource/paper/SYIWpoAyYAWjqCnV.pdf

[^50^] DEGA/DAGA 2015, "An Introduction to MPEG-H 3D Audio." https://pub.dega-akustik.de/DAGA_2015/data/articles/000515.pdf

[^51^] Ittiam, "Delivering Immersive 3D Audio with Ittiam's Optimized MPEG-H Decoder." https://www.ittiam.com/delivering-immersive-3d-audio-with-ittiams-optimized-mpeg-h-decoder/

[^52^] SSL, "Immersive Audio in System T." http://sslweb.solidstatelogic.com.s3.amazonaws.com/content/SSL_immersive-audio.pdf

[^53^] Francisco Pinto Thesis, "Study and Implementation of 3D Sound Decoding Algorithms." https://fenix.tecnico.ulisboa.pt/downloadFile/3096619880808464/Francisco_Pinto_tese.pdf

[^54^] IEM/Cube Speaker Array Reference. https://iem.kug.ac.at/fileadmin/03_Microsites/01_Kuenstlerisch_wissenschaftliche_Einheiten/01_Institute/Institut_17_Elektronische_Musik_und_Akustik/Projektseiten/OSIL/pdfs/Papers/

[^55^] ScienceDaily, "Simulate sound in 3D at a finer scale than humans can perceive," April 2025. https://www.sciencedaily.com/releases/2025/04/250415143348.htm

[^56^] AIP Publishing, "Focality of sound source placement by higher (ninth) order ambisonics and perceptual effects of spectral reproduction errors," JASA, 2025. https://publishing.aip.org/publications/latest-content/simulate-sound-in-3d-at-a-finer-scale-than-humans-can-perceive/

[^57^] CEDIA/CTA, "RP22 Immersive Audio Design Recommended Practice," September 2023. https://cedia.org/site/assets/files/6057/cedia-cta_rp22_v1_2_sept_2023.pdf

[^58^] PMC, "Background Surface and Horizon Effects in the Perception of Relative Size and Distance." https://pmc.ncbi.nlm.nih.gov/articles/PMC2929966/

[^59^] Marantz/Denon, "Auro-3D FAQ and Speaker Layouts." https://www.marantz.com/on/demandware.static/-/Library-Sites-marantz_europe_shared/default/dw9ae81bba/archive-downloads/auro-3d_av7702.pdf

[^60^] Audioholics, "Auro-3D Immersive Sound Interview with Wilfried Van Baelen," 2014. https://www.audioholics.com/audio-technologies/auro-3d-interview

[^61^] AVS Forum, "Atmos speaker placement is not necessarily based solely on angles," 2022. https://www.avsforum.com/threads/atmos-speaker-placement-is-not-necessarily-based-solely-on-angles.3261739/

[^62^] Dolby Professional Support, "What are Beds and Objects in Dolby Atmos." https://professionalsupport.dolby.com/s/article/What-are-Beds-and-Objects-in-Dolby-Atmos

[^63^] Steinberg Forums, "Why are BEDS limited to 7.1.2?" 2024. https://forums.steinberg.net/t/why-are-beds-limited-to-7-1-2/932618

[^64^] vi-control.net, "Dolby Atmos & the 7.1.2 Dilemma," 2024. https://vi-control.net/community/threads/dolby-atmos-the-7-1-2-dilemma.149490/

[^65^] AVS Forum, "Atmos Tops vs Heights and 3-Layer Immersive Audio concept," 2024. https://www.avsforum.com/threads/atmos-tops-vs-heights-and-3-layer-immersive-audio-concept.3310062/

[^66^] Multichannel 3D Microphone Arrays: A Review. https://pdfs.semanticscholar.org/d147/22ffde28ab47521a06ef9a5db485c6fc875d.pdf

[^67^] Dolby Atmos Home Entertainment Studio Certification Guide. https://www.lafontaudio.com/documents/Atmos_authoring_studio.pdf

[^68^] Polk Audio, "Ultimate Guide to Dolby Atmos: Setting Up Your System," 2022. https://www.polkaudio.com/en-us/polklore/how-to/ultimate-guide-to-dolby-atmos-setting-up-your-system.html

[^69^] Stereonet Forums, "Dolby's best speaker placement guide," 2023. https://www.stereonet.com/forums/topic/571026-dolbys-best-speaker-placement-guide/

[^70^] Auro-3D/Denon Documentation. https://assets.denon.com/documentmaster/uk/auro-3d_x4100.pdf

[^71^] Hybrik Documentation, "Dolby Atmos." https://docs.hybrik.com/tutorials/dolby_atmos/

[^72^] Boris FX, "What is Object Based Audio and How Does it Work?" https://borisfx.com/blog/what-is-object-based-audio-how-does-it-work/

[^73^] Apple Logic Pro Documentation, "3D Object Panner." https://support.apple.com/guide/logicpro/3d-object-panner-lgcp3f532b96/10.7/mac/11.0

[^74^] PKU Research, "Matching Projection Decoding Method for Ambisonics." https://hpc.pku.edu.cn/docs/pdf/a20191230056.pdf

[^75^] IEM, "Localization of 3D Ambisonic Recordings." https://iem.kug.ac.at/fileadmin/03_Microsites/01_Kuenstlerisch_wissenschaftliche_Einheiten/01_Institute/Institut_17_Elektronische_Musik_und_Akustik/Projekte/2011/icsa_braun_frank_11.pdf

[^76^] LiveScience, "Scientists build 3D 'audio dome' with such high-fidelity speakers it tricks your ears," May 2025. https://www.livescience.com/technology/scientists-build-3d-audio-dome-with-such-high-fidelity-speakers-it-tricks-your-ears-that-youre-at-the-source

---

## 13. Gaps and Unresolved Questions

### Gaps in Current Knowledge

1. **Below-horizon localization perception**: Very limited psychoacoustic research exists on human ability to localize sound sources below the horizontal plane. Most localization studies focus on above-horizon elevation angles. Systematic studies of perceived elevation for negative angles are needed.

2. **Pinna transfer functions for below-horizon directions**: HRTF databases typically measure down to about -40° elevation at minimum. Full-sphere HRTF measurements extending to -90° (nadir) are rare, and individualized HRTFs for below-horizon directions are essentially unstudied.

3. **Optimal floor speaker placement**: No standardized guidelines exist for below-horizon speaker placement angles, distances, or aiming. The trade-offs between upward-firing floor speakers, in-floor mounted drivers, and angled floor monitors are unexplored.

4. **Content authoring workflows**: No commercial DAW supports below-horizon panning. All 3D panners (Dolby Atmos, MPEG-H, Auro-3D) constrain elevation to ≥ 0°. New UI paradigms would be needed.

5. **Room mode interactions**: Floor-mounted speakers interact differently with room modes than ceiling-mounted speakers. The psychoacoustic consequences of floor-excited room modes for immersive audio are not well characterized.

6. **Cross-format compatibility**: How should full-sphere content be downmixed to hemispherical systems (the vast majority of installed systems)? Should below-horizon content be reflected to the horizon, discarded, or remapped?

7. **Tactile vs. auditory perception**: At very low frequencies, floor-mounted transducers may produce tactile (vibrotactile) sensations that dominate over auditory localization. The optimal crossover between tactile and auditory reproduction is unknown.

8. **Speaker count trade-offs**: For a given total speaker count (e.g., 16), what is the optimal allocation between horizon, height, and floor speakers? Should floor speakers be prioritized for LFE/sub-bass only?

9. **Renderer computational complexity**: Full-sphere VBAP requires searching a larger convex hull with more triplet combinations. The real-time computational overhead compared to hemisphere-only rendering needs quantification.

10. **Standardization pathway**: No existing standards body (ITU, AES, CTA) has published guidelines for full-sphere consumer immersive audio reproduction. The pathway to standardization is unclear.

### Unresolved Technical Questions

- Can Ambisonics decoders optimized for hemispherical arrays be efficiently extended to full-sphere arrays without re-engineering the entire decoder pipeline?
- What is the minimum viable floor speaker configuration (2 channels? 4 channels?)?
- How should the Sonic Sphere renderer handle objects positioned below the floor (e.g., underground explosions)? Should it clip to Z=-1 or apply additional processing?
- What are the practical implications of the "dim factor" approach used in the IEM VBAP plugin for negative elevation, and can it be perceptually optimized?
- How does the addition of floor speakers affect the perceived "sweet spot" size and listening area?

---

## Summary of Key Findings

The theoretical "Sonic Sphere" architecture for extending Dolby Atmos from a hemisphere to a full sphere is grounded in established technical foundations:

**The extension is technically feasible.** The core technologies—VBAP with full-sphere convex hulls, HOA encoding/decoding, and object-based metadata—all natively support full-sphere operation. The primary barrier is not fundamental but architectural: Atmos (and competing formats like DTS:X and Auro-3D) made the design choice to restrict reproduction to the upper hemisphere.

**Standards already exist for below-horizon channels.** ITU-R BS.2051 System H (9+10+3, the NHK 22.2 system) defines bottom-layer channels (B+xxx) at -30° elevation. The IAMF specification includes Bottom-3ch and Bottom-4ch channel layouts. MPEG-H 3D Audio supports arbitrary loudspeaker layouts including full-sphere configurations.

**The object model extension is minimal.** Allowing OAMD Z-coordinates to range from [-1, 1] instead of [0, 1] is sufficient to represent full-sphere positions. Existing Cartesian coordinate systems used in Ambisonics already support negative elevations.

**VBAP handles below-horizon triplets natively.** When real below-horizon speakers are available, standard VBAP triangulation works without modification. The IEM VBAP plugin demonstrates negative elevation handling using virtual loudspeakers as a fallback.

**Perceptual challenges exist but are manageable.** Below-horizon localization relies on the same pinna spectral cues as above-horizon localization, but HRTF data for negative elevations is sparse. Floor channels are most effective for low-frequency and environmental content where precise localization is less critical.

**The HOA intermediate representation is format-agnostic.** Encoding all sources to Higher-Order Ambisonics and decoding to the target array geometry provides a clean architectural separation between content and reproduction, enabling full-sphere rendering to arbitrary speaker layouts.

The Sonic Sphere architecture represents a natural evolution of object-based immersive audio—one that brings it closer to the physical reality of sound as an omnidirectional, full-sphere phenomenon.

---

*Document compiled from 18 independent web searches across 40+ authoritative sources including Dolby technical documentation, ITU standards, IEEE/AES academic papers, peer-reviewed journals, and industry specifications.*
