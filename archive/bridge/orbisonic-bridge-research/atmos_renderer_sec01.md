## 1. Introduction

### 1.1 The Paradigm Shift from Channel-Based to Object-Based Audio

#### 1.1.1 The Adaptation Problem in Channel-Based Audio

For decades, audio production operated within a channel-based paradigm: signals were assigned to predefined loudspeaker channels at the mixing stage, and that assignment was frozen into the delivery medium. In a stereophonic mix, a sound panned left was committed to the left loudspeaker; in 5.1 surround, the rear channels carried signals for specific positions defined by ITU-R BS.775-3 [^229^]. The spatial image was baked into the channel assignment, and any mismatch between the production layout and the consumer playback system degraded the experience. A 7.1 array could not recover spatial information missing from a 5.1 stream; a stereo downmix could only fold surrounds forward through coarse level-based matrices. Channel-based audio assigns signals to predefined speakers, yielding a fixed channel assignment regardless of playback environment [^58^]. The adaptation problem was therefore architectural: content was rendered once at the mixing console, and every downstream system received a fixed feed that could not be spatially re-interpreted.

#### 1.1.2 The Object-Based Breakthrough

Object-based audio decouples the sound source from the loudspeaker configuration. Each element is transmitted as an independent audio signal paired with metadata describing its desired position, size, and rendering behavior in three-dimensional space [^58^][^81^]. Mapping to physical loudspeakers is deferred to playback time, performed by a renderer with knowledge of the specific speaker layout at the listener's location. A single master adapts to stereo headphones, a 5.1 living room system, a 7.1.4 home theatre, or a 64-channel cinema array—without re-authoring. In traditional channel-based audio, positioning is achieved by adjusting levels in each speaker at the mix stage; object-based audio positions each part discretely with more convincing locality [^38^]. This separation of content from configuration is the architectural foundation of all modern immersive audio systems.

### 1.2 Dolby Atmos: Architecture at a Glance

#### 1.2.1 The 128-Track Structure: Beds and Objects

Dolby Atmos implements the object-based paradigm through a hybrid architecture combining a channel-based bed with an object-based layer. The system supports 128 simultaneous audio tracks: a 10-channel 7.1.2 bed (L, R, C, LFE, Ls, Rs, Lsr, Rsr, Lts, Rts) plus up to 118 mono objects [^230^][^101^]. The bed provides fixed-position spatial stability for ambience, dialogue, and music submixes [^230^][^56^]. Objects are mono or stereo signals carrying Object Audio Metadata (OAMD) with X, Y, Z coordinates in a normalized Cartesian cube, object size controlling spatial extent, snap tolerance trading position for timbral fidelity, and zone gain restricting rendering to specific speaker groups [^12^][^13^][^10^][^11^][^15^]. SMPTE ST 2098-1 formalizes this model, with the Z-axis spanning the listening plane (Z = 0) to the overhead plane (Z = 1) [^21^].

#### 1.2.2 The Renderer as Universal Translator

The Dolby Atmos renderer transforms the 128-channel master into loudspeaker feeds for the specific playback configuration. Bed channels receive direct channel-to-speaker mapping or fixed-coefficient downmix matrices [^5^]. Objects are rendered via Vector Base Amplitude Panning (VBAP), computing gain factors for the two or three nearest loudspeakers such that the vector sum matches the intended virtual source direction [^223^][^7^]. The same master thus produces a binaural feed via HRTF processing, a 5.1 downmix via the Lo/Ro matrix (−3 dB center/surround attenuation), a 7.1.4 output via full VBAP triangulation, or a theatrical 64-speaker deployment [^5^][^49^].

For consumer delivery, spatial coding clusters 128 authoring channels into 12–16 elements via perceptual proximity grouping, enabling transmission at 768 kbps through Dolby Digital Plus with Joint Object Coding (DD+ JOC) [^41^][^42^][^48^]. Without this stage, 128 channels of 48 kHz/24-bit audio would require ~147 Mbps, a figure incompatible with consumer distribution [^41^]. The Object Audio Renderer (OAR) in playback devices expands these elements to the local speaker configuration using embedded OAMD.

### 1.3 Enter Sonic Sphere: The Full-Sphere Extension

#### 1.3.1 Atmos's Hemispherical Limitation

A structural constraint of the Atmos architecture is its restriction to the upper hemisphere. The Z coordinate in SMPTE ST 2098-1 spans 0 (listening plane) to 1 (ceiling) with no negative values [^21^][^44^]. All bed channels sit at or above ear level; the two top surround channels (Lts, Rts) are positioned at approximately +45° elevation [^163^][^191^]. Objects traverse the full horizontal plane and range from horizon to overhead, but cannot be placed below the listener. This reflects Atmos's cinematic origins—the audience faces a screen above the horizon, and no meaningful sources exist below the floor. The result is that approximately 50% of the spherical vector space around the listener is unavailable [^44^].

#### 1.3.2 The Sonic Sphere Concept

The Sonic Sphere extension removes this hemispherical boundary while preserving Atmos's architectural framework. Extending the Z coordinate to [−1, +1] permits positioning anywhere on the full sphere, including below-horizon reproduction. This is not speculative: ITU-R BS.2051 System H (NHK 22.2) already defines a standardized full-sphere loudspeaker arrangement with three bottom-layer channels (Bottom Front Left, Bottom Front Center, Bottom Front Right at −15° to −30° elevation), deployed since the 2012 London Olympics. The Sonic Sphere renderer leverages the same object-based architecture—signals plus positional metadata, spatial coding for delivery, and VBAP-based rendering at playback—while expanding the valid coordinate domain to include below-horizon loudspeakers. The VBAP engine requires no algorithmic change; it triangulates gain factors from the three nearest speakers regardless of whether those speakers lie above or below the equatorial plane [^223^]. Sonic Sphere extends the same content-configuration separation that made Atmos transformative, completing the sphere that Atmos left half-closed.
