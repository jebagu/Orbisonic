## 3. Atmos Objects: The Heart of Immersive Audio

The bed architecture provides the spatial foundation of a Dolby Atmos mix, but it is the object layer that delivers the format's defining capability: free positioning of discrete sound sources anywhere within a three-dimensional volume, independent of any fixed speaker layout. This chapter dissects the internal structure of Atmos objects, the Object Audio Metadata (OAMD) stream that governs their rendering behavior, and the perceptual controls—size, snap tolerance, and dynamic updates—that allow a mixer to shape not only where a sound is heard but how it occupies space.

### 3.1 Object Structure and OAMD Metadata

#### 3.1.1 Object Anatomy: Mono or Stereo Signal Plus Time-Varying OAMD

An Atmos object is a logical construct consisting of a mono or stereo audio signal paired with a temporally synchronized stream of Object Audio Metadata (OAMD)[^1^][^2^]. The audio signal itself is conventional pulse-code modulation—typically 48 kHz, 24-bit—and is indistinguishable from any other DAW track until it reaches the renderer. The spatial behavior is encoded entirely in the metadata stream, which travels on a separate pathway from the audio essence[^52^]. In the 128-channel authoring architecture, a 7.1.2 bed consumes 10 channels, leaving up to 118 slots for mono objects[^7^]. A stereo object consumes two slots because its left and right components require independent signal paths while sharing a single metadata instance[^4^]. Objects cannot route directly to the LFE channel; only bed channels have this privilege[^6^], making the bed mandatory in any mix requiring subwoofer content.

#### 3.1.2 OAMD Coordinate System: The Allocentric Normalized Cube

Dolby Atmos adopts an **allocentric** (environment-relative) frame of reference, meaning object coordinates are defined relative to room geometry rather than the listener's head position—a design choice documented by Riedmiller and Tsingos of Dolby Laboratories[^20^]. This ensures scene independence: a mix authored on one stage translates to any playback environment because the coordinate system does not encode listener-specific cues.

SMPTE ST 2098-1 defines the coordinate system as a Cartesian room-normalized unit cube[^21^]: the **X-axis** spans Left to Right (0 or −1 to 1), the **Y-axis** spans Front to Back (0 or −1 to 1), and the **Z-axis** spans Bottom to Top (listening plane at 0, ceiling at 1). The IAB cinema format uses [0, 1] normalization, while PMD broadcast and many DAW implementations use [−1, 1] for X and Y[^13^][^14^]. The renderer maps these normalized coordinates to physical speaker positions via VBAP triplet selection (detailed in Chapter 4). The Z coordinate can theoretically extend below the listening plane (Z < 0), though consumer workflows constrain Z to [0, 1][^25^], creating the elevation gap discussed in Chapter 2.

#### 3.1.3 Metadata Parameters: Position, Size, Snap Tolerance, Zone Gain, and Binaural Mode

OAMD comprises five functional field categories standardized in SMPTE ST 2098-1 and implemented in Dolby's PMD format. **Core position fields** (X_Pos, Y_Pos, Z_Pos) provide the primary inputs to VBAP gain calculation. **Size and spread fields** include `Size` (0–100 in DAWs, 0.0–1.0 normalized), which controls spatial extent via MDAP spreading[^12^]; `Size_Vertical`, which constrains 3D spread to a 2D disc when disabled[^34^]; and `ObjectSpreadMode`, which selects between 1D, low-resolution, and full 3D spreading per ST 2098-2[^33^]. **Rendering control fields** include `SnapToExists` and `ObjectSnapTolerance` for timbre-position tradeoffs[^37^], `ObjectDecorCoeff` for decorrelation[^17^], and `BinauralRenderMode` (Off/Near/Mid/Far) for headphone distance modeling. **Zone metadata** (`ZoneControl`, `ZoneGain`) allows exclusion of specific speaker groups from rendering an individual object, partitioning the array into non-overlapping regions[^15^][^16^]. **Classification fields** include `Class` (Dialog, VDS, Voiceover, Generic) for conditional routing and `DynamicUpdates` for signaling intra-frame motion[^68^].

### 3.2 Object Size and Spatial Extent

#### 3.2.1 Size Parameter Mechanics: MDAP Spread Control

The size parameter determines how an object's energy distributes across the speaker array by modulating MDAP (Multiple Direction Amplitude Panning) spread. MDAP, introduced by Pulkki in 1999, addresses a fundamental VBAP limitation: perceived source width collapses when the panning direction aligns with a single loudspeaker and broadens only between speakers[^13^]. MDAP solves this by panning the same signal to multiple virtual directions simultaneously, creating auxiliary spread sources around the primary direction[^14^].

The Dolby PMD guide describes the behavior physically: at size = 0, all energy emanates from the nearest speaker; as size increases, a sphere of energy grows outward "as if inflating a balloon," distributing sound to additional speakers while total energy remains constant[^28^]. The renderer achieves this by progressively engaging more speakers surrounding the object's position, with per-speaker gains scaled for power preservation. Expert speculation suggests peripheral channels may receive the signal through short decorrelation filters, producing a slightly more diffuse timbre[^32^].

#### 3.2.2 Size = 0 as Point Source

At size = 0, the object is a true point source: the renderer selects the single nearest speaker (or active VBAP triplet for inter-speaker positions) and concentrates all energy there. This yields the sharpest localization and is appropriate for dialogue, solo instruments, and any source requiring precise placement. For stereo objects, size controls the spread of the stereo pair while maintaining left-right angular separation relative to the center point. The energy conservation property of MDAP ensures that integrated loudness remains constant regardless of size setting—only the spatial distribution changes.

#### 3.2.3 Practical Limit: Size > 20 Risks Spatial Coding Artifacts

When size exceeds approximately 20 (on the 0–100 DAW scale), the object's spatial footprint can span multiple spatial coding clusters[^30^]. Spatial coding reduces 128 authoring channels to 12–16 elements for DD+ JOC delivery by grouping nearby objects based on proximity and perceptual loudness[^42^]. An oversized object intersecting multiple clusters causes decorrelation artifacts—the same source is encoded through independent cluster paths, producing a split or phase-incoherent image. For streaming content where spatial coding is mandatory, conservative size settings (0–15) are recommended for sources requiring tight spatial focus.

### 3.3 Snap to Speaker and Timbre Preservation

#### 3.3.1 Snap Functionality: Forcing Object to Nearest Physical Speaker

Snap to Speaker overrides normal VBAP amplitude panning and forces an object to play exclusively from the single physical speaker nearest to its authored position[^35^][^36^]. The renderer abandons phantom imaging and routes the full signal to one loudspeaker, snapping to the next closest available speaker if the nearest is absent. SMPTE ST 2098-1 formalizes this through **Snap Tolerance** metadata: "the degree to which preservation of object timbre has priority over preservation of object position"[^37^]. At maximum tolerance, timbre preservation dominates—single-speaker playback avoids comb filtering from multi-speaker path-length differences. At minimum tolerance, position preservation dominates—the renderer uses amplitude panning across multiple speakers for accurate spatial placement, accepting associated timbral changes.

Notably, Snap to Speaker does not move the pan cursor in the DAW display. The UI shows the authored position while the renderer internally snaps output; the Dolby Atmos Monitor application reveals the actual speaker being used[^39^].

#### 3.3.2 When to Use Snap: Dialogue, Instruments, and Spectral Consistency

Snap mode is indicated whenever spectral consistency outweighs spatial precision. Dialogue is the canonical use case: a voice snapped to the center channel retains its full spectral character without phantom-center comb filtering. Solo acoustic instruments and lead vocals similarly benefit. However, the ISDCF IAB Profile 1 for cinema mandates `ObjectSnapToExists` = 0 and prohibits `ObjectSnapTolerance` in the bitstream[^38^], meaning cinema distribution standardizes to non-snapped rendering regardless of authoring intent. Home entertainment workflows retain full snap control, creating a divergence between theatrical and consumer rendering for the same mastered content.

### 3.4 Static vs Dynamic Objects

#### 3.4.1 All Objects Are Time-Varying by Default

Per SMPTE ST 2098-1, all object metadata is considered dynamic (time-varying) unless explicitly stated otherwise[^69^]. The specification assumes motion; static positioning requires signaling. In PMD, the `DynamicUpdates` flag controls intra-frame position updates—when False, the position is written once and held constant[^67^]. Static objects require no interpolation and consume less CPU and metadata bandwidth.

#### 3.4.2 Metadata Update Rates: 32-Sample Increments and Pan Sub Blocks

Standard OAMD updates occur once per video frame (~41.67 ms at 24 fps). For smoother motion, ED2 and AC-4 workflows support **Dynamic Position Updates** at 32-sample increments within a frame[^61^]. The `sample_time` parameter specifies the offset in 32-sample steps at 48 kHz, yielding an effective 1,500 Hz update rate—sufficient for fast-moving sources without audible stair-stepping. For cinema IAB delivery, SMPTE ST 2098-2 defines **Pan Sub Blocks** as IAFrame subdivisions, each carrying independent panning metadata[^62^][^63^]. This achieves equivalent temporal resolution within the IAB frame structure, which is locked to the picture edit rate (24–60 fps). The renderer interpolates between metadata waypoints at the audio sample rate (48 kHz or 96 kHz), ensuring that even coarse per-frame updates produce smooth speaker gain transitions without audible discontinuities.

#### 3.4.3 Table: Comparison of Bed vs. Object Characteristics

| Attribute | Bed (Channel-Based) | Object (Metadata-Driven) |
|:---|:---|:---|
| **Signal structure** | Multichannel stem routed to named channels[^5^] | Mono/stereo signal plus OAMD stream[^1^] |
| **Positioning** | Fixed to predefined speaker positions | Free 3D positioning via X, Y, Z coordinates[^21^] |
| **Spatial movement** | Inter-channel panning; bed moves as unit | Smooth 3D trajectory via per-object automation[^68^] |
| **Metadata** | Channel list only | Per-object OAMD: position, size, snap, zone gain, decorrelation[^12^] |
| **LFE routing** | Available via bed channels[^6^] | Not available for objects |
| **Rendering** | Direct channel-to-speaker mapping[^5^] | VBAP gain calculation to nearest triplet[^223^] |
| **Spatial coding** | Converted to static objects at canonical positions[^42^] | Rendered as dynamic or static objects per content |
| **Array behavior** | Activates entire speaker arrays in cinemas[^155^] | Can target individual speakers within arrays |
| **Scalability** | Fixed downmix coefficients | Renderer adapts to any speaker layout |
| **Typical content** | Ambience, music beds, reverb, center dialogue[^38^] | Effects, moving sources, solo instruments |
| **Authoring limit** | 10 channels (7.1.2) or 10 channels (9.1) | Up to 118 mono objects (with 7.1.2 bed)[^7^] |

The significance of this comparison lies in the deliberate partitioning of labor. The bed provides spatial stability and backward compatibility: it *is* a conventional surround mix, ensuring graceful degradation to 5.1 or stereo. Objects provide spatial precision and creative freedom: unbound to any speaker position, they can move through space in ways impossible with channel-based panning. Spatial coding ultimately dissolves this distinction by converting bed channels to static objects before clustering[^42^], but at the authoring stage, the choice between bed and object directly affects mix quality.

#### 3.4.4 Table: OAMD Metadata Parameters and Their Perceptual Effects

| Parameter | Range / Values | Perceptual Effect | Rendering Mechanism |
|:---|:---|:---|:---|
| **X_Pos, Y_Pos** | [0, 1] or [−1, 1] | Horizontal localization | VBAP gain across triplet[^21^] |
| **Z_Pos** | [0, 1] | Elevation: ear level to ceiling | Triplet with height speakers |
| **Size** | 0–100 / 0.0–1.0 | Source width and diffuseness[^28^] | MDAP auxiliary spread sources[^13^] |
| **Size_Vertical** | True / False | Horizontal disc vs. full sphere[^34^] | Z-axis spreading enable/disable |
| **ObjectDecorCoeff** | 0x0 or 0x1 | Diffuseness vs. pinpoint imaging[^17^] | Decorrelation across spread channels |
| **SnapToExists** | 0 or 1 | Spectral purity vs. spatial precision[^37^] | Single-speaker override of VBAP |
| **ObjectSnapTolerance** | Continuous range | Timbre priority over position[^37^] | Graduated snap behavior |
| **BinauralRenderMode** | Off / Near / Mid / Far | Perceived distance on headphones | Distance-model HRTF selection |
| **ZoneGain** | [0, 1] per zone | Attenuation of speaker groups[^15^] | Zone exclusion from triplet selection |
| **DynamicUpdates** | True / False | Motion smoothness vs. anchoring[^69^] | Intra-frame position interpolation |

This parameter set reveals the sophistication of OAMD design. The metadata encodes not merely position but a complete spatial behavior profile. Size and decorrelation work in concert to control how a source occupies space—tight and focused for a solo violin, diffuse and enveloping for a rainstorm. Snap tolerance encodes a perceptual priority (timbre versus position) impossible to express in channel-based formats. And binaural render mode ensures spatial intent survives the transition from loudspeakers to earphones. It is this multi-dimensional richness—not merely X, Y, Z coordinates—that enables a single Atmos master to render plausibly on configurations from a smartphone to a 64-speaker cinema, and that makes the object layer the operational heart of immersive audio production.
