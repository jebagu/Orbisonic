## 4. The Rendering Pipeline: From Objects to Speakers

### 4.1 Pipeline Overview

The Dolby Atmos rendering pipeline transforms a master file containing up to 128 independent audio tracks — bed channels and dynamic objects — into a set of loudspeaker feed signals. This transformation occurs in six distinct stages: speaker configuration parsing, object positioning, spatial coding, Vector Base Amplitude Panning (VBAP) gain calculation, additive summation, and output formatting. Each stage operates under strict real-time constraints: metadata interpolation must be sample-accurate at 48 kHz (the standard delivery rate) or 96 kHz (the archival rate), and gain recalculation must keep pace with object motion that can traverse the entire soundfield within a single second [^12^].

The following ASCII diagram illustrates the complete rendering chain from master file to physical output:

```
+-----------------------------------------------------------------------------+
|                     DOLBY ATMOS MASTER FILE INPUT                           |
|         (up to 128 tracks: 10 bed channels + 118 objects)                    |
|                   48 kHz / 24-bit PCM + OAMD metadata                       |
+-----------------------------------------------------------------------------+
                                       |
                                       v
+-----------------------------------------------------------------------------+
| STAGE 1: SPEAKER CONFIGURATION PARSING                                      |
|  - Load .dad configuration (Dolby Atmos Designer)                          |
|  - Discover speaker count, positions (azimuth/elevation/distance)           |
|  - Build internal speaker array model (up to 64 for cinema)                 |
|  - Compute convex hull and Delaunay triangulation for VBAP                  |
+-----------------------------------------------------------------------------+
                                       |
                                       v
+-----------------------------------------------------------------------------+
| STAGE 2: OBJECT POSITIONING                                                |
|  - Parse OAMD Cartesian coordinates (x, y, z) per frame                    |
|  - Convert to spherical coordinates (azimuth, elevation, distance)          |
|  - Normalize to room geometry; interpolate between metadata frames          |
|  - Bed channels converted to static objects at fixed speaker positions      |
+-----------------------------------------------------------------------------+
                                       |
                                       v
+-----------------------------------------------------------------------------+
| STAGE 3: SPATIAL CODING (Consumer Delivery Path Only)                       |
|  - Cluster nearby objects into spatial object groups                        |
|  - Reduce 128 tracks to 12 / 14 / 16 elements (11.1 / 13.1 / 15.1)        |
|  - Dynamic reclustering frame-by-frame; preserve power and position         |
|  - Cinema path: bypass — render all objects individually                    |
+-----------------------------------------------------------------------------+
                                       |
                                       v
+-----------------------------------------------------------------------------+
| STAGE 4: VBAP - VECTOR BASE AMPLITUDE PANNING                               |
|  - Select speaker pair (2D) or triplet (3D) via convex hull lookup          |
|  - Solve g = L^(-1) * p for unnormalized gain factors                      |
|  - Apply p-norm normalization (p=2 energy norm, or frequency-dependent)     |
|  - Optional: MDAP spread for sized objects; dual-band VBAP/VBIP            |
+-----------------------------------------------------------------------------+
                                       |
                                       v
+-----------------------------------------------------------------------------+
| STAGE 5: ADDITIVE MIXING                                                    |
|  - Linear summation of all bed and object contributions per output channel  |
|  - Gain compensation (-3 dB) to prevent level buildup during summation      |
|  - Apply trim, downmix metadata, and loudness normalization                 |
+-----------------------------------------------------------------------------+
                                       |
                                       v
+-----------------------------------------------------------------------------+
| STAGE 6: OUTPUT FORMATTING                                                  |
|  - Speaker output: up to 64 discrete feeds (cinema) / 22 (home monitoring)  |
|  - Re-render stems: 5.1, 7.1, stereo, AmbiX for downstream compatibility    |
|  - Binaural path: HRTF convolution for headphone output                     |
+-----------------------------------------------------------------------------+
```

The pipeline operates on a frame-accurate basis. Object Audio Metadata (OAMD) samples arrive at the frame rate of the content (24, 25, 30, 48, 50, or 60 fps), while audio samples advance at the sampling rate (48 kHz or 96 kHz). The renderer must interpolate metadata positions between frames to avoid discrete spatial jumps — a requirement that has driven the adoption of sample-accurate linear or spherical interpolation in all production-grade implementations [^12^]. At 48 kHz with 24 fps content, each metadata frame spans exactly 2000 audio samples; the renderer interpolates the position vector $p$ across each span so that gain factors $g$ evolve smoothly.

### 4.2 Stage 1: Speaker Configuration Parsing

Before any audio processing can occur, the renderer must build an internal geometric model of the playback environment. This begins with speaker discovery: the system determines how many loudspeakers are available, their three-dimensional positions relative to the listening position, their types (screen channels, surrounds, overheads, subwoofers), and any calibration data such as delay compensation and equalization settings.

In theatrical installations, this configuration is generated by the Dolby Atmos Designer software, a calibration tool that produces a `.dad` (Dolby Atmos Designer) configuration file [^24^]. The `.dad` file encodes each speaker's Cartesian or spherical coordinates, channel routing assignments, and distance compensation parameters. The file is loaded into the cinema processor — typically the Dolby CP950A — which supports up to 64 independent speaker feeds delivered via AES67 or BLU Link protocols over RJ45 Ethernet connectors [^25^]. The CP950A transmits audio in eight streams of eight channels each, with dedicated RTP source and destination port assignments (source ports 6518–6525, destination port 6517) [^25^].

Once speaker positions are loaded, the renderer performs a critical preprocessing step that determines which speakers will participate in VBAP for every possible virtual source direction. The set of valid speaker pairs (in two dimensions) or triplets (in three dimensions) is computed by constructing the convex hull of all loudspeaker position vectors projected onto the unit sphere [^3^][^5^]. The convex hull algorithm produces a triangulated mesh where each facet is a spherical triangle formed by three loudspeakers; this mesh partitions the entire sphere into non-overlapping regions, guaranteeing that every virtual source direction falls within exactly one triplet's domain. The triangulation typically employs the Delaunay criterion, which maximizes the minimum interior angle of each triangle and produces well-conditioned vector base matrices [^6^]. For each valid triplet $(k, m, n)$, the renderer precomputes and stores the inverse matrix $L_{kmn}^{-1}$, reducing the runtime gain calculation to a single matrix-vector multiplication per object [^1^].

### 4.3 Stage 2: Object Positioning

With the speaker array model established, the renderer processes incoming Object Audio Metadata (OAMD) to determine where each object should be placed in the three-dimensional soundfield. The master file stores positions in normalized Cartesian coordinates $(x, y, z)$ relative to a reference cube representing an idealized cinema model, with the front plane at the screen location [^4^]. The X axis spans left to right, Y spans front to back, and Z spans bottom to top. These coordinates are normalized to the range $[-1, 1]$ or $[0, 1]$ depending on the axis convention.

The first operation is coordinate transformation from Cartesian to spherical form $(\theta, \phi, d)$, where $\theta$ is the azimuthal angle (horizontal bearing), $\phi$ is the elevation angle (vertical inclination), and $d$ is the distance from the listener. The conversion follows the standard geometric relations:

$$d = \sqrt{x^2 + y^2 + z^2}, \quad \theta = \arctan2(x, y), \quad \phi = \arcsin\left(\frac{z}{d}\right)$$

The azimuth $\theta$ is measured clockwise from the forward (Y-positive) axis, consistent with the cinematic convention where $0°$ is center-front, $+90°$ is right, and $-90°$ is left. Elevation $\phi$ ranges from $0°$ (listener plane) to $+90°$ (zenith). Dolby Atmos restricts object positions to elevation $\geq 0°$ (above the horizon), though this is a specification choice rather than a technical limitation of the VBAP engine [^4^].

Bed channels follow a parallel but simpler path. Each bed channel — Left, Right, Center, LFE, Left Surround, Right Surround, Left Rear Surround, Right Rear Surround, Left Top Surround, Right Top Surround — is treated as a "static object" pinned to its corresponding speaker position in the standard layout [^5^]. Bed channels that do not have a reserved output in the target speaker configuration are reclassified as static objects and enter the spatial coding stage alongside dynamic objects [^5^]. The LFE channel is always preserved separately and does not participate in positional panning [^24^].

Between metadata frames, the renderer interpolates object positions to maintain smooth motion. Early implementations used linear interpolation of Cartesian coordinates; modern implementations use orthodromic (great-circle) interpolation on the spherical surface, which produces physically accurate trajectories for moving sources [^24^]. The number of interpolation points is typically proportional to the angular distance traveled, with $n = \text{round}(5 \cdot \sqrt{d - 1})$ intermediate positions for an orthodromic distance $d$ measured in degrees [^24^].

### 4.4 Stage 3: Spatial Coding — Object Clustering

Spatial coding is the mechanism that bridges the gap between the unconstrained creativity of theatrical Atmos mixing — 128 simultaneous, independently positioned audio tracks — and the bandwidth-limited reality of consumer delivery. The uncompressed Atmos master data rate is approximately 147 Mbps ($48\,\text{kHz} \times 24\,\text{bits} \times 128\,\text{channels}$), far exceeding any consumer delivery pipeline capacity [^131^]. Spatial coding reduces this to 12, 14, or 16 composite elements, achieving an effective compression ratio of up to 390:1 before perceptual audio coding (DD+ JOC, TrueHD, or AC-4) is even applied [^61^].

The clustering algorithm operates on a proximity-based grouping principle. At each time instant, the renderer analyzes the 3D positional coordinates of all active objects and assigns them to a limited number of clusters — composite sets called **spatial object groups** [^24^][^28^]. Objects occupying similar positions in the soundfield are grouped together because, on a typical consumer speaker system (5.1.2 to 7.1.4 channels), multiple nearby objects would activate largely the same physical speakers during reproduction anyway. The human auditory system has limited spatial resolution for simultaneous sources, making this grouping perceptually benign [^131^].

The clustering process is fundamentally dynamic. Objects can move from cluster to cluster as their positions change, and the clusters themselves can reposition to track moving sound sources [^24^]. This frame-by-frame adaptation is crucial for maintaining spatial accuracy during continuous motion — a helicopter traversing the ceiling, for instance, must not be locked to a static cluster that lags behind its trajectory. When a single object's spatial extent exceeds one cluster's representational capacity, its energy may be distributed across multiple aggregate objects to preserve both power and perceived position [^28^].

Bed channels are fully integrated into this process. Bed input signals not reserved for an output bed configuration are treated as "static objects with a fixed position in space" and are combined with dynamic moving objects before clustering [^5^]. The LFE channel remains untouched throughout, yielding effective configurations of 11.1 (12 elements), 13.1 (14 elements), or 15.1 (16 elements) [^24^]. Content creators can control clustering strength via the Dolby Atmos Production Suite, and the renderer provides Spatial Coding Emulation so mixers can audition clustering artifacts before final encoding [^5^][^131^].

The choice of element count is determined by target bitrate: 384 kbps delivery mandates 12 elements, while 448 kbps and above uses 16 elements [^49^]. Most streaming platforms — Netflix, Apple Music, Amazon — deliver Atmos at 768 kbps using 16 elements [^104^]. Netflix's internal testing concluded that DD+ at 640 kbps and above is "perceptually transparent" [^104^]. The clustering algorithm is proprietary; the exact distance metrics, threshold parameters, and temporal smoothing coefficients have not been published by Dolby.

### 4.5 Stage 4: VBAP — Vector Base Amplitude Panning

Vector Base Amplitude Panning (VBAP), introduced by Ville Pulkki in 1997 [^1^], is the foundational rendering algorithm that maps a virtual source position to loudspeaker gain factors. VBAP reformulates amplitude panning as a linear algebra problem: the virtual source direction vector is decomposed into a linear combination of loudspeaker direction vectors, and the scalar coefficients of this decomposition become the loudspeaker gains. This reformulation is general — it applies to any loudspeaker configuration without requiring pre-derived panning laws — and computationally efficient, requiring only a single matrix inversion per speaker triplet during initialization.

#### 4.5.1 Two-Dimensional VBAP and the Tangent Law

The derivation begins with stereophonic amplitude panning. Consider two loudspeakers positioned symmetrically at angles $\pm\varphi_0$ relative to the forward axis, with unit-length direction vectors $l_1 = [l_{11}, l_{12}]^T$ and $l_2 = [l_{21}, l_{22}]^T$. The virtual source direction is given by the unit vector $p = [p_1, p_2]^T$. VBAP treats $p$ as a linear combination of the loudspeaker vectors [^1^]:

$$p = g_1 l_1 + g_2 l_2$$

In matrix form, with $g = [g_1, g_2]$ and $L_{12} = [l_1, l_2]^T$ the 2×2 vector base matrix:

$$p^T = g \cdot L_{12}$$

Solving for the gain vector $g$:

$$g = p^T \cdot L_{12}^{-1} = [p_1 \quad p_2] \begin{bmatrix} l_{11} & l_{12} \\ l_{21} & l_{22} \end{bmatrix}^{-1}$$

The inverse exists provided $\varphi_0 \neq 0°$ and $\varphi_0 \neq 90°$ — both corresponding to degenerate stereophonic configurations [^1^]. For the symmetric case $l_{11} = l_{21} = \cos\varphi_0$, $l_{12} = -l_{22} = \sin\varphi_0$, and virtual source direction $p_1 = \cos\varphi$, $p_2 = \sin\varphi$, the explicit solutions are:

$$g_1 = \frac{\cos\varphi \sin\varphi_0 + \sin\varphi \cos\varphi_0}{2\cos\varphi_0 \sin\varphi_0}, \quad g_2 = \frac{\cos\varphi \sin\varphi_0 - \sin\varphi \cos\varphi_0}{2\cos\varphi_0 \sin\varphi_0}$$

Pulkki proved the equivalence to the stereophonic tangent law by direct substitution [^1^][^2^]:

$$\frac{g_1 - g_2}{g_1 + g_2} = \frac{2\sin\varphi\cos\varphi_0}{2\cos\varphi\sin\varphi_0} = \frac{\tan\varphi}{\tan\varphi_0}$$

This is precisely the tangent law: $\tan\varphi / \tan\varphi_0 = (g_1 - g_2)/(g_1 + g_2)$. Thus, VBAP in 2D reduces to the classical result; its power lies in extending this principle to arbitrary 3D configurations.

#### 4.5.2 Three-Dimensional VBAP: The Triplet Formulation

In three dimensions, three loudspeakers arranged in a triangle form a vector base. Each loudspeaker $k$, $m$, $n$ has a unit-length position vector $l_k$, $l_m$, $l_n$ in Cartesian coordinates. The 3D vector base matrix is defined as [^1^][^3^]:

$$L_{kmn} = \begin{bmatrix} l_{kx} & l_{mx} & l_{nx} \\ l_{ky} & l_{my} & l_{ny} \\ l_{kz} & l_{mz} & l_{nz} \end{bmatrix}$$

Each column is a unit-length loudspeaker direction vector. The matrix must span $\mathbb{R}^3$ (the three loudspeakers must not be collinear) for $L_{kmn}^{-1}$ to exist. A virtual source at direction $\Omega = (\theta, \phi)$ is represented by the unit vector:

$$p(\Omega) = (\cos\phi \sin\theta, \; \sin\phi \sin\theta, \; \cos\theta)^T$$

The virtual source position is decomposed onto the loudspeaker vector base:

$$p(\Omega) = L_{kmn} \cdot g(\Omega) = \bar{g}_k l_k + \bar{g}_m l_m + \bar{g}_n l_n$$

The unnormalized gain factors are obtained by matrix inversion — the fundamental VBAP equation:

$$g(\Omega) = L_{kmn}^{-1} \cdot p(\Omega)$$

This is a projection of the virtual source direction vector onto the vector base defined by the loudspeaker triplet [^1^]. When three loudspeakers are placed in an orthogonal grid, $L_{kmn} = I$ (the identity matrix), and the gains reduce to the Cartesian coordinates of $p$, equivalent to 3D Ambisonics encoding [^1^].

#### 4.5.3 Speaker Triplet Selection: Convex Hull and Delaunay Triangulation

The triplet selection problem — determining which three loudspeakers should render a given virtual source — is solved geometrically. The renderer computes the convex hull of all loudspeaker position vectors projected onto the unit sphere [^3^][^5^]. The convex hull produces a triangulated mesh where each facet is a spherical triangle; this triangulation is the Delaunay triangulation, which maximizes the minimum interior angle of each triangle and yields numerically well-conditioned $L_{kmn}$ matrices [^6^].

At runtime, the correct triplet is selected by testing all candidate triplets and choosing the one yielding all-positive gain factors [^1^][^5^]. In practice, the selection uses the **minimum gain test**: for each triplet, compute unnormalized gains and evaluate $\bar{g}_{\text{min}} = \min\{\bar{g}_k, \bar{g}_m, \bar{g}_n\}$. The triplet with the highest $\bar{g}_{\text{min}}$ is selected, a criterion that is numerically robust against small negative gains caused by floating-point error [^1^].

The ITU-R ADM renderer (BS.2127) extends this framework with quadrilateral regions (QuadRegions) formed by four loudspeakers, producing smoother panning than triplet-only VBAP [^7^]. For a QuadRegion with loudspeaker positions $P = [p_1, p_2, p_3, p_4]$ in anticlockwise order, gains are computed via bilinear interpolation:

$$g' = [(1-x)(1-y), \; x(1-y), \; xy, \; (1-x)y], \quad g = \frac{g'}{\|g'\|_2}$$

where $x$ and $y$ are chosen such that the velocity vector $g \cdot P$ aligns with the desired direction [^7^]. The ADM renderer also adds virtual loudspeakers at positions $(0,0,-1)$ (below the listener) and optionally $(0,0,1)$ (above the listener) to ensure complete spherical coverage, with virtual speakers downmixed to physical loudspeakers using power-preserving coefficients $w_{\text{dmx}} = 1/\sqrt{n}$ [^7^].

#### 4.5.4 Gain Normalization: The Generalized p-Norm

After computing raw gains via matrix inversion, the gains must be normalized. The generalized p-norm normalization is [^9^]:

$$g_l^{\text{normalized}} = \frac{g_l}{\left(\sum_{l=1}^{L} g_l^p\right)^{1/p}}$$

The choice of $p$ depends on frequency and room acoustics:

- **$p = 1$ (amplitude normalization):** Preserves coherent summation; appropriate for low frequencies ($\lesssim 700$ Hz) and anechoic or dry environments where loudspeaker signals add in phase at the listening position [^8^][^9^].
- **$p = 2$ (energy normalization):** Preserves power for incoherent summation; the VBAP default, appropriate for reverberant environments and mid-to-high frequencies [^1^][^8^].
- **$1 < p < 2$ (frequency-dependent):** Laitinen et al. (2014) established that a smooth transition from $p=1$ at low frequencies to $p=2$ at high frequencies, governed by the room's direct-to-total energy ratio (DTT), yields optimal results [^9^].

Research by Laitinen et al. demonstrated that applying energy normalization ($p=2$) across all frequencies in a dry room produces a "clearly perceived bass-boosting effect" because low-frequency signals coherently sum to yield $+6$ dB (free field) or $+3$ dB (moderately reverberant room), rather than the $0$ dB sum that energy normalization assumes [^8^].

#### 4.5.5 Frequency-Dependent Panning: VBAP Below, VBIP Above

Human sound localization relies on different physical cues in different frequency ranges: interaural time differences (ITDs) dominate below approximately 700 Hz, while interaural level differences (ILDs) dominate above [^19^]. VBAP optimizes the velocity vector $\mathbf{r}_V$, which accurately predicts ITD-based localization at low frequencies. For high frequencies, Vector Base Intensity Panning (VBIP) optimizes the energy vector $\mathbf{r}_E$ [^11^][^20^].

VBIP is derived from VBAP by taking the square root of the low-frequency gains [^21^]:

$$\tilde{g}_i = \sqrt{g_i}, \quad \text{then normalize such that } \sum \tilde{g}_i^2 = 1$$

The Gerzon energy vector is defined as $\mathbf{r}_E = \sum \tilde{g}_i^2 \tilde{\mathbf{r}}_i / \sum \tilde{g}_i^2$, which aligns with the virtual source direction when $\tilde{g}_i = \sqrt{g_i}$ [^21^]. The dual-band approach — VBAP below 700 Hz and VBIP above, implemented via crossover filters — is known as **Dual-Band Vector Based Panning** and is the state of the art in production renderers [^11^][^22^].

#### 4.5.6 MDAP Spread: Spatial Extent for Sized Objects

A fundamental limitation of basic VBAP is that perceived source width varies with panning direction: sources are narrowest when aligned with a single loudspeaker and widest when panned between loudspeakers [^13^]. Multiple-Direction Amplitude Panning (MDAP), introduced by Pulkki in 1999, solves this by panning the same signal to multiple virtual directions simultaneously [^13^][^14^].

For a ring of $L$ equally spaced loudspeakers, MDAP distributes $B$ virtual VBAP sources around the panning direction $\theta_s$ within a spread of $\pm\varphi_{\text{MDAP}}$. The optimal spread angle is $\alpha = 90\% \times 180°/L$, producing constant perceived width across all panning directions [^14^]. In 3D, spread sources are arranged on one or more rings around the main panning direction; the reference Aalto VBAP implementation uses 8 auxiliary sources by default, with the spread parameter determining their angular distance from the primary direction [^5^]. The Atmos "size" parameter controls this spatial extent: size $= 0$ creates a point source rendered by standard VBAP, while larger values activate progressively more spread sources, distributing energy across multiple speaker triplets for an apparent source width effect [^17^][^20^]. Engineers report that size values beyond 20 should be avoided, as they can cause clustering issues and unpredictable downmix behavior [^17^].

### 4.6 Stage 5: Additive Mixing

After VBAP has computed per-speaker gain factors for every object and cluster, the renderer performs linear (additive) summation at each output channel. Each speaker feed $S_j$ is the sum of all bed channel contributions and all rendered object signals assigned to that speaker:

$$S_j = \sum_{b \in \text{beds}} s_b \cdot \delta_{bj} + \sum_{o \in \text{objects}} x_o \cdot g_{oj}$$

where $s_b$ is the bed channel signal, $\delta_{bj}$ is the bed-to-speaker mapping (1 if bed $b$ maps to speaker $j$, 0 otherwise), $x_o$ is the object audio signal, and $g_{oj}$ is the VBAP gain for object $o$ on speaker $j$. This summation is unconditional: every object contributes to every speaker for which it has a non-zero gain factor [^21^].

Because multiple objects and bed channels may contribute to the same speaker simultaneously, the renderer applies gain compensation to prevent level buildup. A $-3$ dB attenuation factor ($1/\sqrt{2}$) is typically applied during channel summation, reflecting the assumption that two uncorrelated signals at full scale should sum to approximately $+3$ dB above each individual level rather than $+6$ dB (which would occur with coherent summation) [^28^]. This compensation is consistent with the energy-normalized VBAP formulation where $\sum g_l^2 = 1$ ensures that the total power of a panned virtual source remains constant regardless of direction [^1^]. The renderer also applies any trim and downmix metadata specified in the `.atmos` master file, including height content routing for legacy systems and surround channel forward/backward bias adjustments [^30^].

### 4.7 Stage 6: Output Formatting

The final stage formats the mixed speaker signals for the target output device. In theatrical installations, the CP950A cinema processor delivers up to 64 discrete speaker feeds via AES67 or BLU Link digital audio protocols at sample rates of 44.1 kHz, 48 kHz, or 96 kHz with 16-, 20-, or 24-bit resolution [^24^]. The processor includes high-resolution multi-rate EQ, internal crossovers supporting up to 4-way loudspeakers, a built-in booth monitor, and a real-time analyzer (RTA) for calibration [^24^]. For home monitoring during production, the Dolby Atmos Renderer supports up to 22 speakers, headphone/binaural output, and up to 64 channels of re-render output [^12^].

A defining feature of the Atmos pipeline is its **re-render** capability: the ability to generate channel-based deliverables from the object-based master. The renderer can simultaneously output multiple channel-based formats including 2.0 (stereo), 5.1, 7.1, 7.1.2, 7.1.4, 9.1.6, binaural (BIN), and AmbiX (B-format) [^12^]. Group-based re-rendering enables creation of standard post-production stems — DX (dialogue), MX (music), FX (effects) — by assigning each input bed or object to a custom group and re-rendering each group to a separate channel-based output [^31^]. All re-renders can be exported offline without requiring real-time playback [^12^].

The following table summarizes each pipeline stage with its input and output specifications, governing algorithm, and processing requirements.

<table>
<thead style="background-color: #f0f0f0;">
<tr><th>Stage</th><th>Input</th><th>Output</th><th>Core Algorithm / Operation</th><th>Key Parameters</th></tr>
</thead>
<tbody>
<tr><td>1. Speaker Config. Parsing</td><td>.dad file, speaker positions</td><td>Triplet list, $L^{-1}$ matrices</td><td>Convex hull, Delaunay triangulation</td><td>Up to 64 speakers; precomputed inverses</td></tr>
<tr><td>2. Object Positioning</td><td>OAMD (x,y,z) per frame</td><td>Spherical coords $(\theta, \phi, d)$</td><td>Cartesian-to-spherical conversion; interpolation</td><td>48/96 kHz sample rate; frame-rate metadata</td></tr>
<tr><td>3. Spatial Coding</td><td>128 tracks (beds + objects)</td><td>12/14/16 elements + LFE</td><td>Proximity-based dynamic clustering</td><td>Bitrate-dependent: 384 kbps→12, 448+→16</td></tr>
<tr><td>4. VBAP Gain Calculation</td><td>Object direction $p(\Omega)$</td><td>Per-speaker gain vector $g$</td><td>$g = L^{-1} \cdot p$; p-norm normalization</td><td>2D pair or 3D triplet; MDAP spread for size>0</td></tr>
<tr><td>5. Additive Mixing</td><td>All bed and object signals</td><td>Mixed output per channel</td><td>Linear summation; $-3$ dB compensation</td><td>Trim/downmix metadata applied</td></tr>
<tr><td>6. Output Formatting</td><td>Mixed channel signals</td><td>Speaker feeds, re-renders, binaural</td><td>Format routing; HRTF convolution (headphones)</td><td>64 ch cinema / 22 ch home / binaural</td></tr>
</tbody>
</table>

The table reveals a deliberate architectural separation of concerns. Stage 1 is purely geometric — it knows nothing about audio content. Stage 2 is purely kinematic — it converts metadata to spatial coordinates. Stage 3 is the only stage that discards information (reducing 128 tracks to 16 elements), and it is bypassed entirely in the cinematic path where all 64 speaker feeds are rendered individually. Stage 4 is the mathematical core — the only stage that performs signal-level operations on a per-sample basis. Stage 5 is a simple linear mixer, and Stage 6 is a format adapter. This modular structure is what enables the same master to play on configurations ranging from stereo headphones to a 64-speaker theatrical array: the early stages (1–3) adapt to the playback environment, while the mathematical core (Stage 4) remains invariant.

The computational load of the pipeline is dominated by Stage 4. For a full cinematic mix with 118 objects rendered to 64 speakers, the renderer must perform up to 118 triplet selections and matrix-vector multiplications per sample. At 48 kHz, this translates to approximately $118 \times 48000 = 5.66 \times 10^6$ VBAP calculations per second. In practice, many objects are silent at any given instant, and triplet lookup tables reduce the selection to a simple index operation, bringing the real-time load well within the capabilities of modern DSP hardware. The Dolby RMU — typically a Dell Precision Rack server with an Intel Xeon E5-2620 v3 (6 cores at 2.4 GHz) — handles this workload with ample headroom [^13^].

