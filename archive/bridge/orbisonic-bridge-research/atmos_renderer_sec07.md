## 7. The Sonic Sphere Renderer: Full-Sphere Extension

The preceding chapters examined Dolby Atmos as it exists: a hemispherical system in which every bed channel, object, and loudspeaker resides at or above the listener's horizontal plane. This chapter proposes the Sonic Sphere renderer — a theoretical extension enabling full-sphere audio reproduction using the same object-based architecture. The technical barriers are neither algorithmic (VBAP naturally supports below-horizon triplets) nor representational (HOA encodes the full sphere natively), but architectural: the Atmos specification defines no speakers below the floor.

### 7.1 The Hemispherical Limitation of Atmos

#### 7.1.1 Elevation Constraint: Z ≥ 0

Dolby Atmos restricts all bed channels and object positions to the upper hemisphere. The standard bed is 7.1.2 (seven listener-level channels, one LFE, two height channels), and even the most expansive consumer layout (24.1.10) adds only more overhead speakers, never below-horizon channels [^1^]. Object positions use normalized Cartesian coordinates where Z = 0 is the listener plane and Z = 1 is directly overhead; Z is never negative in practice because no reproduction infrastructure exists for it [^4^]. SMPTE ST 2098-1 codifies this: while the coordinate cube theoretically permits Z < 0, the minimum rendering requirement spans only from the Z-axis midpoint to the top of the cube [^138^].

#### 7.1.2 Root Cause: No Standardized Below-Horizon Speakers

The constraint is configurational, not mathematical. No Atmos specification — home theater, cinema, or professional — includes a loudspeaker below the horizontal plane. Home theater guidelines specify overhead speakers at +45° elevation (adjustable +30° to +55°) [^1^]; cinema top surrounds must be at ≥ 45° + (E ÷ 2) [^2^]. Without physical transducers in the lower half-space, the renderer has no destination for below-horizon content.

This contrasts sharply with ITU-R BS.2051 System H (the NHK 22.2 multichannel system), which defines three bottom-layer channels — BtFL, BtFC, BtFR — at −15° to −30° elevation, positioned explicitly below the listener's ear height [^16^] [^18^]. NHK 22.2 was deployed for 8K Super Hi-Vision broadcasts of the 2012 London Olympics, establishing that full-sphere audio is production-proven [^19^].

#### 7.1.3 The Perceptual Asymmetry of the Pinna

The elevation gap coincides with a genuine perceptual asymmetry. Human elevation localization depends on spectral cues introduced by the pinna (outer ear), which creates direction-dependent notches and peaks above approximately 4–7 kHz [^30^]. These pinna spectral notches are effective for the upper hemisphere but substantially weaker below the horizontal plane. Research by Middlebrooks (1992) established that below-horizon localization accuracy degrades significantly, with front-back confusion rates reaching 50% or higher for sources on the cone of confusion — the conical region where identical ITDs and ILDs render azimuth ambiguous [^27^] [^29^]. Below the horizon, the pinna's filtering becomes symmetric with its above-horizon counterpart: a source at −30° produces spectral cues similar to one at +30°, and discrimination requires head movement [^30^]. This limitation defines the appropriate content strategy for floor channels rather than invalidating them.

### 7.2 Extending the Object Model to Negative Elevation

#### 7.2.1 Coordinate System Extension: Z from [0, 1] to [−1, 1]

The Sonic Sphere extension requires a single coordinate change: allowing Z to range from −1 to +1. In the extended frame, Z = +1 is zenith (directly overhead), Z = 0 is the listener-level horizontal plane, and Z = −1 is nadir (directly below). X and Y remain unchanged at [−1, 1]. The spherical coordinate mapping follows the ISO Ambisonics convention: azimuth θ = 0° at front, increasing counterclockwise; elevation φ = 0° at the horizontal plane, +90° at zenith, −90° at nadir [^46^]. Cartesian-to-spherical conversion follows:

$$\theta = \arctan2(Y, X), \quad \phi = \arcsin(Z / r) \quad \text{where} \quad r = \sqrt{X^2 + Y^2 + Z^2}$$

#### 7.2.2 OAMD Metadata Modification

Object Audio Metadata in SMPTE ST 2098-1 stores positional data as normalized Cartesian triplets. The Sonic Sphere extension requires no structural bitstream change — only a semantic expansion of the Z-field interpretation. Content with Z ≥ 0 renders identically on both legacy Atmos and Sonic Sphere systems [^21^]. On legacy systems, Z < 0 content is handled via horizon-clipping (mapping Z < 0 to Z = 0) or energy redistribution to the horizontal plane. ITU-R BS.2076-3 already supports this range natively: its position metadata accepts elevation from −90° to +90° [^306^].

#### 7.2.3 Rendering Implication: VBAP Works Unchanged

The critical insight, developed in Section 7.4, is that the VBAP gain calculation $\mathbf{g} = \mathbf{L}^{-1} \cdot \mathbf{p}$ is direction-agnostic. It finds the three closest loudspeakers to any direction vector — including below the horizon — and computes barycentric gains. When floor speakers exist, triplet selection naturally includes them.

### 7.3 Full-Sphere Speaker Array Geometries

#### 7.3.1 Platonic Solids as Ideal Arrays

The five Platonic solids provide the only perfectly regular point arrangements on a sphere, making them theoretically ideal for full-sphere Ambisonics decoding [^13^]:

| Polyhedron | Speakers | Max HOA Order | Properties |
|:---:|:---:|:---:|:---|
| Tetrahedron | 4 | 1st | Minimal viable full-sphere array |
| Octahedron | 6 | 1st | Best 1st-order symmetry; natural XYZ alignment |
| Dodecahedron | 12 | 2nd | Balanced surface area per speaker |
| Icosahedron | 20 | 3rd | Highest regular resolution for moderate channel count |

The octahedron's six vertices correspond to the ±X, ±Y, ±Z cardinal directions — the natural reference geometry for full-sphere audio. The IEM at Graz constructed an icosahedral array with 20 independent drivers for spherical harmonic reproduction [^14^]; Meyer Sound Laboratories built a 120-element geodesic sphere capable of HOA up to order 8 [^15^]. Recent research (the "AudioDome" at Western University) achieved ninth-order Ambisonic panning with 91 loudspeakers — spatial resolution at or above human perceptual limits [^55^].

#### 7.3.2 The NHK 22.2 Precedent: ITU-R BS.2051 System H

NHK 22.2 (ITU-R BS.2051 System H, configuration 9+10+3) is the only internationally standardized format with dedicated below-horizon speakers [^16^] [^290^]. Its 24 channels are arranged in three layers: 9 top channels at +30° to +45° elevation (overhead ambience and reverberation), 10 middle channels at 0° to +15° (primary imaging and sound field formation), and 3 bottom channels at −15° to −30° (BtFL, BtFC, BtFR for floor-level effects), plus 2 LFE channels [^18^] [^322^]. NHK's research found that the three-layer structure provides superior sound field reproduction compared to conventional systems because it more accurately models natural three-dimensional sound propagation — sound in real environments approaches the listener from above and below as well as from the sides [^18^]. The bottom layer specifically reproduces sounds of water, ground-level scenes, and structural vibrations that contribute to environmental immersion. The IAMF specification (Samsung/Google, Alliance for Open Media) already includes Bottom-3ch (BtFL/BtFC/BtFR) and Bottom-4ch (BtFL/BtFR/BtBL/BtBR) layouts referencing ITU-R BS.2051-3 [^23^].

#### 7.3.3 Practical Sonic Sphere Layout: 7.1.4.4

For consumer applications, the Sonic Sphere proposes a **7.1.4.4** bed extending the Atmos 7.1.4 reference: 7 listener-level channels (L, R, C, Ls, Rs, Lb, Rb), 1 LFE, 4 height channels (Ltf, Rtf, Ltr, Rtr at +45°), and 4 floor channels (Lbf, Rbf, Lbr, Rbr at −30° to −45°). This yields 16 main channels plus LFE — four additional channels over 7.1.4 that achieve vertical completeness. Floor channels follow the ITU-R BS.2051 **B** (Bottom) prefix convention [^16^].

#### 7.3.4 Proposed Sonic Sphere Speaker Layouts

| Layout Name | Speakers | Configuration | Use Case |
|:---:|:---:|:---|:---|
| Tetrahedral 4.0 | 4 | 4.0.0 (tetrahedral vertices) | Research, minimal full-sphere |
| Compact 8.0 | 8 | 4.0.4 (horizontal ring + floor quad) | Small-room consumer install |
| Sonic Sphere 12.1 | 13 | 5.1.4.4 (5 ear + 1 LFE + 4 height + 4 floor) | Entry-level home theater |
| **Sonic Sphere 16.1** | **17** | **7.1.4.4 (7 ear + 1 LFE + 4 height + 4 floor)** | **Reference consumer layout** |
| NHK 22.2 | 24 | 9.10.3 (ITU-R BS.2051 System H) | Professional broadcast |
| Icosahedral 20.0 | 20 | 20.0.0 (icosahedron vertices) | Research, HOA to 3rd order |

This progression demonstrates that full-sphere audio does not require massive channel counts. The Compact 8.0 layout achieves below-horizon reproduction with only 8 speakers — fewer than an Atmos 7.1.4 installation (12 speakers). The critical difference is placement, not count: replacing two overhead speakers with two floor speakers converts a hemispherical array into a full-sphere array, provided the renderer supports negative elevation.

### 7.4 Extending VBAP for Full-Sphere Panning

#### 7.4.1 No Algorithm Change Required

VBAP computes loudspeaker gain factors via matrix inversion (Chapter 4):

$$\mathbf{g} = [g_1, g_2, g_3]^T = \mathbf{L}^{-1} \cdot \mathbf{p}$$

where $\mathbf{L} = [\mathbf{l}_1 \; \mathbf{l}_2 \; \mathbf{l}_3]$ is the 3×3 loudspeaker direction matrix and $\mathbf{p}$ is the unit-length virtual source direction [^5^]. This formulation is entirely direction-agnostic: it operates on Cartesian coordinates without any hemisphere assumption. When floor speakers are present, convex hull triangulation automatically produces lower-hemisphere triangles, and the standard selection criterion — choose the triplet with all-positive gains ($g_i \geq 0$) — naturally routes below-horizon sources to floor triplets [^7^].

The proof is immediate: for $\mathbf{p} = [p_x, p_y, p_z]^T$ with $p_z < 0$, the algorithm searches all convex hull triplets. If a triplet contains speakers with negative Z-coordinates, the barycentric coordinates $\mathbf{g} = \mathbf{L}^{-1} \cdot \mathbf{p}$ are all-positive precisely when $\mathbf{p}$ lies within the spherical triangle defined by those three speakers. No "below-horizon special case" is required — the general triplet search handles all directions uniformly.

#### 7.4.2 Convex Hull Reconstruction

Adding floor speakers extends the point set into the lower hemisphere; the Delaunay triangulation of the augmented set produces a complete spherical mesh covering both upper and lower hemispheres [^6^]. For the 7.1.4.4 layout (15 non-collinear points on the unit sphere, excluding LFE), the convex hull yields approximately 26 triangular facets by Euler's formula ($F = 2V - 4$ for $V$ vertices in general position). Each facet defines one valid loudspeaker triplet with a precomputed inverse matrix $\mathbf{L}^{-1}$, making runtime triplet selection a matter of testing which facet contains the virtual source direction — a computation involving only dot products and comparisons that remains trivially inexpensive for real-time operation even with hundreds of simultaneously active objects [^1^].

#### 7.4.3 Virtual Nadir Loudspeaker

For arrays without physical floor speakers — all existing Atmos installations — below-horizon content can be handled via Zotter and Frank's virtual nadir approach: insert a virtual speaker at $\mathbf{p} = [0, 0, -1]^T$, then dismiss its signal (yielding audio at the closest horizontal speaker pair) or downmix to neighbors [^8^]. The IEM VBAP plugin implements this with a dim-factor of 0.5, fading below-horizon audio toward the horizon [^9^]. This is a perceptual compromise — the virtual speaker cannot reproduce the physical floor coupling of a real transducer.

#### 7.4.4 Gain Normalization Across the Horizon

When a source crosses the horizontal plane, it switches from an upper-hemisphere triplet to a lower-hemisphere triplet, changing the number and angular spread of active speakers. AllRAD decoding exhibits loudness fluctuations of approximately 1 dB for such panning [^8^]; EPAD reduces this to ~0.3 dB [^8^]. Sonic Sphere mitigates this via matched-distance placement (floor and ceiling speakers equidistant from the listener) and compensating gain scaling derived from each triplet's subtended solid angle.

### 7.5 Ambisonics as Intermediate Representation

#### 7.5.1 HOA Encoding

The Sonic Sphere architecture proposes HOA as an optional intermediate representation that decouples content creation from playback. For a plane-wave source $s(t)$ from direction $(\theta, \phi)$:

$$B_{nm}(t) = s(t) \cdot Y_n^m(\theta, \phi)$$

where $Y_n^m(\theta, \phi)$ are the real spherical harmonic functions of order $n$ and degree $m$ ($-n \leq m \leq n$) [^36^] [^39^]. The spherical harmonics form a complete orthonormal basis on the unit sphere, enabling decomposition of any directional soundfield into weighted basis functions [^153^]. For first-order Ambisonics in SN3D/ACN (AmbiX) convention:

$$[W, Y, Z, X]^T = s(t) \cdot [1/\sqrt{2}, \; \cos\theta\cos\phi, \; \sin\phi, \; \sin\theta\cos\phi]^T$$

where W is the omnidirectional component and X, Y, Z are the figure-of-eight components [^39^].

#### 7.5.2 Full-Sphere Coverage: −90° to +90°

HOA natively supports the full sphere, with elevation from −90° (nadir) to +90° (zenith) [^12^]. The encoding equation accepts any $(\theta, \phi)$ on the sphere without special-casing negative elevations. The associated Legendre functions $P_n^{|m|}(\sin\phi)$ are defined for all $\phi \in [-90°, +90°]$ [^64^]. Objects below the horizon encode identically to objects above it; the decoder distributes coefficients to whatever array is available.

#### 7.5.3 The AllRAD Decoder

AllRAD bridges HOA's format-agnostic representation and VBAP's robust panning in two stages [^114^]: (1) decode HOA to ~240 virtual loudspeaker directions arranged as a t-design on a uniform sphere using a sampling decoder, and (2) remap each virtual speaker to the real array via VBAP. This hybrid design is particularly valuable for full-sphere Sonic Sphere installations because practical consumer arrays rarely exhibit the geometric regularity of Platonic solids — floor speakers may use different driver sizes, different elevation angles, or asymmetric placement relative to their ceiling counterparts. AllRAD absorbs these irregularities in the VBAP remapping stage while the HOA decode stage provides a mathematically clean full-sphere representation [^75^]. For hemispherical fallback playback, AllRAD inserts imaginary loudspeakers at nadir to stabilize loudness and localization at the horizon boundary [^8^].

#### 7.5.4 Channel Count: $(N+1)^2$

The number of HOA channels for 3D rendering at order $N$ is $(N+1)^2$, growing quadratically because each order $n$ contributes $2n+1$ harmonics [^70^]. First-order yields 4 channels, second-order 9, third-order 16. For Sonic Sphere delivery, 3rd-order HOA (16 channels) offers a practical balance — sufficient spatial resolution for full-sphere localization while remaining within modern codec capacity. MPEG-H HOA spatial compression can reduce 4th-order content (25 channels) to 6 transport signals plus metadata [^113^].

### 7.6 The Sonic Sphere Rendering Pipeline

#### 7.6.1 Pipeline Architecture

The Sonic Sphere pipeline extends Atmos with three modifications: full-sphere object rendering, an optional HOA intermediate, and floor-aware bed routing:

**Input Parser** → **Full-Sphere Object Renderer** → **Bed Renderer** → **HOA Intermediate (optional)** → **Mixdown** → **Output**

The Input Parser decodes beds and objects with extended OAMD (Z ∈ [−1, 1]), parsing the same SMPTE ST 2098-1 bitstream structure as legacy Atmos but interpreting Z-values across the full [−1, 1] range. The Full-Sphere Object Renderer applies VBAP per object: for Z ≥ 0, standard upper-hemisphere triplets are selected from the precomputed convex hull; for Z < 0, the triplet search automatically spans into lower-hemisphere facets that include floor speakers. Object size and spread parameters (Section 4.3) extend naturally to the lower hemisphere, with MDAP auxiliary sources distributed around the panning direction including negative elevation orientations. The Bed Renderer maintains a three-layer routing matrix: middle-layer beds (L, R, C, Ls, Rs, Lb, Rb) to ear-level speakers, upper-layer beds (Ltf, Rtf, Ltr, Rtr) to height speakers, and the new lower-layer beds (Lbf, Rbf, Lbr, Rbr) to floor speakers. The optional HOA Intermediate stage encodes all rendered sources — both bed contributions and object gains — to Ambisonic coefficients $B_{nm}(t)$, enabling a single encoded stream to be distributed and decoded to arbitrary target arrays including headphone binaural via HRTF convolution. The Mixdown stage combines object contributions, bed contributions, and decoded HOA signals into final per-speaker output feeds with headroom-managed summing to prevent inter-sample overloads.

#### 7.6.2 Spatial Coding Adaptation

Atmos spatial coding clusters 128 objects into 12–16 elements based on 3D proximity. For Sonic Sphere, the clustering metric $d_{ij} = \sqrt{(\Delta X)^2 + (\Delta Y)^2 + (\Delta Z)^2}$ spans the full sphere with Z ∈ [−1, 1]. Objects in the lower hemisphere cluster separately from those at equivalent (X, Y) with positive Z. The perceptual basis — nearby objects activate similar speaker subsets — remains valid across the full sphere, and compression ratios (~191:1 for DD+ JOC at 768 kbps) should be comparable [^3^].

#### 7.6.3 Backward Compatibility

Sonic Sphere content must play on hemispherical Atmos systems. Three compatibility modes are defined: **Horizon clip** (default): Z < 0 maps to Z = 0, folding below-horizon objects onto the horizontal plane. **Virtual nadir**: Z < 0 renders via the virtual speaker approach with progressive fade. **Energy redistribution**: floor channel energy redistributes to nearest ear-level speakers with power-preserving coefficients $w_{dmx} = 1/\sqrt{n}$ [^7^]. Content with Z ≥ 0 renders identically on Sonic Sphere systems — the positive-Z path is unchanged.

#### 7.6.4 Comparison: Atmos vs. Sonic Sphere

| Dimension | Dolby Atmos | Sonic Sphere |
|:---|:---|:---|
| Coordinate range (Z) | [0, 1] — horizon to overhead | [−1, 1] — floor to ceiling |
| Bed configuration | 7.1.2 (max 10 bed channels) | 7.1.4.4 (16 bed channels) |
| Speaker layers | 2 (ear-level + height) | 3 (ear-level + height + floor) |
| Reference layout | 7.1.4 (12 speakers + LFE) | 7.1.4.4 (16 speakers + LFE) |
| VBAP coverage | Upper hemisphere only | Full sphere |
| Convex hull | Hemispherical Delaunay | Full-sphere Delaunay |
| HOA intermediate | Not used | Optional (format-agnostic decode) |
| Elevation range | 0° to +90° | −90° to +90° |
| Spatial coding | XY + Z≥0 proximity | Full 3D XYZ proximity |
| Backward compat | N/A (native) | Horizon clip / virtual nadir / redistribution |
| Standards basis | Dolby proprietary + SMPTE ST 2098 | ITU-R BS.2051 System H precedent |
| Below-horizon localization | Not supported | Supported (reduced accuracy) |

This comparison reveals Sonic Sphere as an architectural superset: every Atmos capability is preserved, with only the extended Z-range, floor speaker support, and optional HOA intermediate added. The standards infrastructure already supports this — ITU-R BS.2051 defines the layouts, BS.2076 the metadata coordinates, and SMPTE ST 2098 requires only a semantic Z-field expansion.

### 7.7 Implementation Considerations

#### 7.7.1 Psychoacoustic Constraints

Below-horizon reproduction operates under different perceptual constraints than above-horizon audio. Pinna spectral cues — the direction-dependent notches and peaks above approximately 4 kHz created by the outer ear's convoluted geometry — enable elevation discrimination but are substantially weaker for negative elevations because the pinna's filtering function is asymmetric across the horizontal plane [^30^] [^36^]. Below-horizon localization therefore relies more on head movement and dynamic interaural differences (changes in ITD and ILD as the listener rotates) than on static monaural spectral features. This has direct implications for content design: floor channels are most effective for low-frequency ambience below ~500 Hz where the human auditory system's localization mechanisms are inherently coarse regardless of direction; environmental effects such as footsteps, structural rumble, and subterranean vibrations; and atmospheric depth cues that create a sense of a complete acoustic environment extending below the listener. Precise point-source localization — dialog, solo instruments, narrative-critical effects — should remain in the upper hemisphere where pinna cues provide the necessary elevation resolution. NHK's production experience with 22.2 confirms this: bottom-layer channels were used primarily for environmental sound effects and low-frequency ambience rather than localized sources [^18^].

#### 7.7.2 Room Acoustic and Hardware Challenges

Floor-mounted speakers couple strongly with vertical room modes, particularly the fundamental height axial mode ($f = c / 2H$ where $H$ is room height and $c \approx 343$ m/s). In a typical residential room with $H = 2.7$ m, this mode occurs at approximately 63 Hz, squarely within the sub-bass range where floor channels are most effective. The boundary effect (pressure doubling at a rigid surface) yields a +6 dB boost at the floor plane, which enhances tactile bass impact but can create uneven frequency response when combined with ceiling reflections forming a comb filter. The CEDIA/CTA RP22 standard recommends $T_m = 0.3(V/100)^{1/3}$ for reflection decay time control, a guideline that applies with particular force to full-sphere installations where floor reflections now actively contribute to the spatial image [^57^]. Three mounting strategies are viable: upward-firing floor monitors (simplest installation, limited to front/side positions), in-floor mounted drivers (optimal acoustic coupling and boundary effect utilization, requires construction-level installation with protective grilles), and floor-standing speakers on tilted platforms (most accessible retrofit option). Floor speakers require minimum ~1 m distance from the listening position to avoid proximity-effect bass boost and prevent the listener from physically occluding the acoustic path. Crossover design warrants attention: floor speakers should operate full-range only if room correction EQ is applied; otherwise, a high-pass filter at ~40 Hz protects against excessive modal excitation while preserving the sub-bass content for which floor channels are intended.

#### 7.7.3 Computational Overhead

The convex hull of a 7.1.4.4 array contains ~26 facets versus ~18 for 7.1.4 — a 44% increase with negligible runtime impact, as all $\mathbf{L}^{-1}$ matrices are precomputed [^1^]. The optional 3rd-order HOA decode to 16 speakers requires a 16×16 matrix multiplication per frame — trivial for modern DSPs. Full-sphere Sonic Sphere rendering adds minimal computational cost to the existing Atmos pipeline.

The Sonic Sphere architecture thus presents a technically feasible, standards-grounded, and perceptually informed path from hemispherical to full-sphere reproduction. It requires no new algorithms, no new codecs, and no new mathematics — only the extension of existing coordinates to their full natural range, the installation of loudspeakers in the half-space that existing formats have left silent, and a rendering pipeline that treats the entire sphere as a single continuous acoustic space rather than a half-space bounded by the floor.
