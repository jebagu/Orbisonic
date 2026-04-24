# Dimension 3: VBAP — The Core Rendering Algorithm

## Comprehensive Technical Research on Vector Base Amplitude Panning

**Date:** 2025-07-17
**Researcher:** AI Research Agent
**Searches Conducted:** 20+
**Sources:** IEEE, AES, ITU, Springer, Aalto University Research

---

## Table of Contents

1. [Introduction and Overview](#1-introduction-and-overview)
2. [Full Mathematical Derivation of VBAP](#2-full-mathematical-derivation-of-vbap)
3. [The Vector Base Matrix L and Gain Calculation](#3-the-vector-base-matrix-l-and-gain-calculation)
4. [Speaker Triplet Selection](#4-speaker-triplet-selection)
5. [Gain Normalization](#5-gain-normalization)
6. [Elevation Handling](#6-elevation-handling)
7. [Spread Parameter and MDAP](#7-spread-parameter-and-mdap)
8. [Limitations](#8-limitations)
9. [VBIP and Frequency-Dependent Panning](#9-vbip-and-frequency-dependent-panning)
10. [SPCAP as an Alternative](#10-spcap-as-an-alternative)
11. [Crossfade Interpolation](#11-crossfade-interpolation)
12. [Key Findings Summary](#12-key-findings-summary)
13. [References](#13-references)

---

## 1. Introduction and Overview

Vector Base Amplitude Panning (VBAP) is the foundational rendering algorithm underlying most modern object-based spatial audio systems, including Dolby Atmos, MPEG-H, and the ITU-R ADM Renderer. Proposed by Ville Pulkki in 1997 [^1^], VBAP reformulates traditional amplitude panning using vector algebra, enabling computationally efficient positioning of virtual sound sources in arbitrary loudspeaker configurations.

The key innovation of VBAP is its geometric approach: instead of relying on panning laws derived for specific loudspeaker configurations (e.g., the tangent law for stereo), VBAP uses vector bases formed by loudspeaker direction vectors. By inverting a matrix composed of these vectors, gain factors are computed directly for any virtual source direction.

---

## 2. Full Mathematical Derivation of VBAP

### 2.1 Two-Dimensional VBAP

The derivation begins with a reformulation of stereophonic amplitude panning. Consider two loudspeakers positioned symmetrically at angles $\pm\varphi_0$ relative to the forward axis, with unit-length direction vectors $l_1 = [l_{11}, l_{12}]^T$ and $l_2 = [l_{21}, l_{22}]^T$. The virtual source direction is given by unit vector $p = [p_1, p_2]^T$ pointing toward the desired virtual source position.

**Claim:** In 2D VBAP, the virtual source position vector is treated as a linear combination of loudspeaker vectors [^1^].

**Source:** Pulkki, V., "Virtual Sound Source Positioning Using Vector Base Amplitude Panning," JAES, 1997
**URL:** https://www.audiolabs-erlangen.de/resources/aps-w23/papers/sap_Pulkki1997.pdf
**Excerpt (verbatim):**
> "In the two-dimensional VBAP method presented in this section, the two-channel stereophonic loudspeaker configuration is reformulated as a two-dimensional vector base. The base is defined by unit-length vectors $l_1 = [l_{11}, l_{12}]^T$ and $l_2 = [l_{21}, l_{22}]^T$, which are pointing toward loudspeakers 1 and 2, respectively... The unit-length vector $p = [p_1, p_2]^T$, which points toward the virtual source, can be treated as a linear combination of loudspeaker vectors:"

$$p = g_1 l_1 + g_2 l_2 \quad \text{(Equation 7 in Pulkki 1997)}$$

In matrix form:

$$p^T = g \cdot L_{12}$$

where $g = [g_1, g_2]$ and $L_{12} = [l_1, l_2]^T$ is the 2x2 vector base matrix.

Solving for the gain vector:

$$g = p^T \cdot L_{12}^{-1} = [p_1 \quad p_2] \begin{bmatrix} l_{11} & l_{12} \\ l_{21} & l_{22} \end{bmatrix}^{-1} \quad \text{(Equation 9)}$$

**Claim:** The inverse $L_{12}^{-1}$ exists when $\varphi_0 \neq 0°$ and $\varphi_0 \neq 90°$ [^1^].

**Source:** Pulkki 1997, JAES
**Excerpt:** "$L_{12}^{-1}$ exists when $\varphi_0 \neq 0°$ and $\varphi_0 \neq 90°$, both problem cases corresponding to quite uninteresting stereophonic loudspeaker placements."

**Confidence:** High

### 2.2 Equivalence to the Tangent Law

**Claim:** VBAP in 2D is mathematically equivalent to the stereophonic tangent law [^1^][^2^].

**Source:** Pulkki 1997, Appendix; Zotter & Frank, "A Practical 3D Audio Theory"
**URL:** https://www.audiolabs-erlangen.de/resources/aps-w23/papers/sap_Pulkki1997.pdf
**Excerpt (verbatim proof from Pulkki):**
> "The statement that gain factors calculated using Eq.(9) will satisfy the tangent law [Eq.(3)] will now be proved."

With $l_{11} = l_{21} = \cos\varphi_0$, $l_{12} = -l_{22} = \sin\varphi_0$, $p_1 = \cos\varphi$, $p_2 = \sin\varphi$:

$$g_1 = \frac{\cos\varphi \sin\varphi_0 + \sin\varphi \cos\varphi_0}{2\cos\varphi_0 \sin\varphi_0}$$

$$g_2 = \frac{\cos\varphi \sin\varphi_0 - \sin\varphi \cos\varphi_0}{2\cos\varphi_0 \sin\varphi_0}$$

The relation:

$$\frac{g_1 - g_2}{g_1 + g_2} = \frac{2\sin\varphi\cos\varphi_0}{2\cos\varphi\sin\varphi_0} = \frac{\tan\varphi}{\tan\varphi_0} \quad \text{(Equation 28)}$$

This is exactly the tangent law: $\frac{\tan\varphi}{\tan\varphi_0} = \frac{g_1 - g_2}{g_1 + g_2}$

**Confidence:** High

### 2.3 Three-Dimensional VBAP

In 3D, three loudspeakers arranged in a triangle form a vector base. Each loudspeaker $k, m, n$ has a unit-length position vector $l_k, l_m, l_n$ in Cartesian coordinates.

**Claim:** The 3D vector base matrix is defined as $L_{kmn} = [l_k, l_m, l_n]$ and the virtual source position is decomposed using this base [^1^][^3^].

**Source:** Pulkki 1997; Zotter & Frank, "Amplitude Panning Using Vector Bases," Springer 2019
**URL:** https://link.springer.com/chapter/10.1007/978-3-030-17207-7_3
**Excerpt (verbatim):**
> "The system of equations for VBAP uses 3 loudspeaker directions and gains to model the panning direction $\theta$:
> $$\theta = [\theta_1, \theta_2, \theta_3] \begin{bmatrix} \tilde{g}_1 \\ \tilde{g}_2 \\ \tilde{g}_3 \end{bmatrix} = L \cdot \tilde{g} \Rightarrow \tilde{g} = L^{-1} \theta, \quad g = \frac{\tilde{g}}{\|\tilde{g}\|}$$"

The desired direction $\Omega = (\theta, \phi)$ is given by azimuth $\phi$ and elevation/inclination $\theta$. The unit-length position vector in Cartesian coordinates:

$$p(\Omega) = (\cos\phi \sin\theta, \sin\phi \sin\theta, \cos\theta)^T$$

A virtual source position is represented as:

$$p(\Omega) = L_{kmn} \cdot g(\Omega) = \bar{g}_k l_k + \bar{g}_m l_m + \bar{g}_n l_n$$

The gain factors are computed by matrix inversion:

$$g(\Omega) = L_{kmn}^{-1} \cdot p(\Omega)$$

**Confidence:** High

### 2.4 Gain Scaling in 3D

After computing the raw gains via matrix inversion, the gains must be normalized. Pulkki's original energy-normalized formulation [^1^]:

$$g^{scaled} = \frac{\sqrt{C} \cdot g}{\sqrt{g_1^2 + g_2^2 + g_3^2}}$$

where $C > 0$ is a volume control parameter.

**Claim:** When three loudspeakers are placed in an orthogonal grid, 3D VBAP gains are equivalent to the absolute values of 3D Ambisonics gains [^1^].

**Excerpt (verbatim):**
> "When the three loudspeakers are placed in an orthogonal grid, the gain factors calculated with the three-dimensional VBAP are equivalent to the absolute values of gain factors calculated in the three-dimensional Ambisonics system. This is easily proved. From the orthogonality of the loudspeaker vector base we see that $L_{123} = I = L_{123}^{-1}$. Using Eq.(18) we see directly that $g = p^T$. The gain factors are thus the Cartesian coordinates of the head of the virtual source direction vector p, similarly as in the three-dimensional Ambisonics system."

**Confidence:** High

---

## 3. The Vector Base Matrix L and Gain Calculation

### 3.1 Matrix Structure

For a 3D loudspeaker triplet with directions given in Cartesian coordinates on the unit sphere:

$$L_{kmn} = \begin{bmatrix} l_{kx} & l_{mx} & l_{nx} \\ l_{ky} & l_{my} & l_{ny} \\ l_{kz} & l_{mz} & l_{nz} \end{bmatrix}$$

Each column is a unit-length loudspeaker direction vector. The matrix $L_{kmn}$ must span 3D space (i.e., the three loudspeakers must not be collinear) for the inverse to exist.

**Claim:** The gain calculation $g = L^{-1} \cdot p$ is a projection of the virtual source direction vector onto the vector base defined by the loudspeaker triplet [^1^].

**Excerpt:** "Eq.(18) makes a projection of vector p to a vector base defined by $L_{123}$ in a similar way as in the two-dimensional case."

### 3.2 Precomputation for Real-Time Use

**Claim:** For real-time implementations, $L^{-1}$ matrices are precomputed for all valid loudspeaker triplets/pairs during initialization [^1^].

**Excerpt (verbatim):**
> "When the tool is initialized, the directions of the loudspeakers are measured relative to the best listening position and loudspeaker pairs are formed from adjacent loudspeakers. $L_m^{-1}$ matrices are calculated for each pair and stored in the memory of the panning system."

This precomputation makes runtime gain calculation extremely efficient—requiring only a single matrix-vector multiplication per virtual source per triplet.

### 3.3 Triplet Selection at Runtime

**Claim:** The correct triplet is selected by testing all candidate triplets and choosing the one with all-positive gain factors [^1^][^4^].

**Source:** Pulkki 1997; Aalto VBAP Library
**URL:** http://research.spa.aalto.fi/projects/vbap-lib/vbap.html
**Excerpt (from Zotter & Frank 2019):**
> "The triplet with all-positive weights, $g_1 \geq 0$, $g_2 \geq 0$, and $g_3 \geq 0$, is selected from the list of all loudspeaker triplets in order to determine which one needs to be activated."

In practice, the selection criterion uses the **minimum gain test**: for each triplet, compute unscaled gains and evaluate $\bar{g}_{min} = \min\{\bar{g}_k, \bar{g}_m, \bar{g}_n\}$. The triplet with the highest $\bar{g}_{min}$ is selected. This criterion is numerically robust against small negative gains caused by floating-point error [^1^].

**Confidence:** High

---

## 4. Speaker Triplet Selection

### 4.1 Convex Hull and Delaunay Triangulation

**Claim:** Loudspeaker triplets are found by computing the convex hull of the loudspeaker positions projected onto the unit sphere [^4^][^5^].

**Source:** Zotter & Frank 2019; Aalto VBAP Library; ITU-R BS.2127
**URL:** https://link.springer.com/chapter/10.1007/978-3-030-17207-7_3
**Excerpts:**
> "In order to choose which loudspeakers to activate for playback, all speakers arranged along the convex hull are grouped into loudspeaker triplets." [^4^]

> "findLsTriplets: Computes the 3D convex-hull of a spherical grid of loudspeaker directions." [^5^]

The convex hull of points on a sphere produces a triangulated mesh where each facet is a spherical triangle formed by three loudspeakers. This triangulation is typically computed using Delaunay triangulation on the spherical surface.

**Claim:** The Delaunay triangulation maximizes minimum angles, producing well-conditioned triangles [^6^].

**Source:** Gamper, H., "Selection and interpolation of head-related transfer functions," DAFX 2013
**URL:** https://dafx.de/paper-archive/2013/papers/53.dafx2013_submission_59.pdf
**Excerpt:** "The proposed method is based on grouping HRTF measurement points into non-overlapping triangles on the surface of a sphere by calculating the convex hull. The resulting Delaunay triangulation maximises minimum angles."

### 4.2 The ITU-R ADM Renderer Approach

**Claim:** The ITU-R ADM renderer (BS.2127) extends basic VBAP triplet selection with quadrilateral regions and virtual loudspeakers for more robust broadcast rendering [^7^].

**Source:** ITU-R BS.2127-1, "Audio Definition Model renderer for advanced sound systems"
**URL:** https://www.itu.int/dms_pubrec/itu-r/rec/bs/R-REC-BS.2127-1-202311-I!!PDF-E.pdf
**Excerpt (verbatim):**
> "The point source panner in this renderer is based on the VBAP formulation [Pulkki1997], with several enhancements which make it more suitable for use in broadcast environments:
> - In addition to the triplets of loudspeakers as in VBAP, the point source panner supports atomic quadrilaterals of loudspeakers. This solves the same problems as the use of virtual loudspeakers in other systems, but results in a smoother overall panning function.
> - Triangulation of the loudspeaker layout is performed on the nominal loudspeaker positions and warped to match the real loudspeaker positions, which ensures that the panning behaviour is always consistent within adaptations of a given layout.
> - Virtual loudspeakers and down-mixing are used to modify the rendering in some situations in order to correct for observed perceptual effects and produce desirable behaviours in sparse layouts."

The ADM renderer configuration process:
1. Update nominal azimuths for screen-channel loudspeakers (M+SC, M-SC)
2. Determine virtual loudspeakers to add
3. Create nominal and real position lists
4. Append virtual loudspeakers at (0,0,-1) [below] and optionally (0,0,1) [above]
5. Take convex hull of nominal positions
6. Create regions: Triplet (3-edge facets), QuadRegion (4-edge facets), or VirtualNgon (virtual speakers)

**Confidence:** High

### 4.3 QuadRegion: Beyond Triplets

**Claim:** The ADM renderer's QuadRegion handler produces smoother panning than triplet-only VBAP by using bilinear interpolation over four loudspeakers [^7^].

**Excerpt (verbatim):**
> "Given the Cartesian position of four loudspeakers, $P = [p_1, p_2, p_3, p_4]$ in anticlockwise order from the perspective of the listener, the gain vector g is computed as:
> $$g' = [(1-x)(1-y), x(1-y), xy, (1-x)y]$$
> $$g = \frac{g'}{\|g'\|_2}$$
> Where x and y are chosen such that the velocity vector $g \cdot P$ has the desired direction d."

The QuadRegion produces gains that are "infinitely differentiable with respect to the position within the region, producing results comparable to pair-wise panning between virtual loudspeakers."

**Confidence:** High

---

## 5. Gain Normalization

### 5.1 Constant Power (Energy) Normalization

**Claim:** VBAP uses energy normalization ($\sum g_l^2 = 1$) as the default, corresponding to incoherent signal summation [^1^][^8^].

**Source:** Zotter & Frank, "A Practical 3D Audio Theory for Spatial Audio"
**URL:** https://library.oapen.org/bitstream/id/a418a7e9-2245-47c1-8c29-d5cdd227b678/1007063.pdf
**Excerpt (verbatim):**
> "At a measurement point in the free field, the same signal fed to equalized loudspeakers of exactly the same acoustic distance would superimpose constructively (+6 dB). In a room with early reflections and a less strict equality of the incoming pair of sounds... the superposition can be regarded as stochastically constructive (+3 dB) in particular at frequencies that aren't very low. For the above reasoning, typical amplitude panning rules try to keep the weights distributing the signal to the loudspeakers normalized by root of squares instead of normalizing to the linear sum:"

$$g_l \leftarrow \frac{g_l}{\sqrt{\sum_{l=1}^{L} g_l^2}} \quad \text{(Equation 2.1)}$$

### 5.2 Constant Velocity (Amplitude) Normalization

**Claim:** Amplitude normalization ($\sum g_l = 1$) is more appropriate at low frequencies and in dry playback environments due to coherent summation [^8^][^9^].

**Source:** Laitinen et al., "Gain normalization in amplitude panning as a function of frequency and room reverberance," AES 55th International Conference, 2014
**URL:** http://research.spa.aalto.fi/projects/vbap-lib/vbap.html
**Excerpt (verbatim):**
> "More generally, the gain normalization factor for L loudspeakers can be defined as [root p of sum g^p], where p=1 corresponds to amplitude normalization and p=2 to standard power normalization. Amplitude normalization is more appropriate at low frequencies and in dry playback environments due to coherent summation of the loudspeaker channels. Power normalization can cause a clearly perceived bass-boosting effect in these cases."

### 5.3 The Generalized p-Norm

The generalized normalization uses a frequency-dependent p-value:

$$g_l^{normalized} = \frac{g_l}{(\sum_{l=1}^{L} g_l^p)^{1/p}}$$

where:
- $p = 1$: Amplitude normalization (coherent summation, low frequencies, anechoic)
- $p = 2$: Energy normalization (incoherent summation, mid-high frequencies, reverberant rooms)
- $1 < p < 2$: Frequency-dependent transition [^9^]

**Claim:** The SPARTA Panner plugin implements frequency-dependent loudness normalization with adjustable p-value via the DTT (Direct-to-Total energy ratio) parameter [^8^][^10^].

**Excerpt:** "The parameter DTT can be varied between 0 (standard, frequency-independent VBAP normalization, i.e. diffuse-field normalization), 0.5 for typical listening environments, and 1 for the anechoic chamber."

**Confidence:** High

---

## 6. Elevation Handling

### 6.1 VBAP 3D with Height Speakers

VBAP handles elevation natively through 3D triplet selection. When height speakers are present (e.g., Dolby Atmos 7.1.4), the convex hull triangulation automatically produces triangles that span both horizontal and vertical dimensions.

**Claim:** The Aalto VBAP library and SPARTA framework support full 3D VBAP with automatic height speaker detection via convex hull triangulation [^5^].

**Source:** VBAP Rust crate documentation
**URL:** https://docs.rs/vbap
**Excerpt:** "3D Panning (Height Speakers): Atmos 7.1.4 layout with height speakers (3D auto-detected)."

### 6.2 Layer-Based Amplitude Panning (LBAP)

**Claim:** LBAP is an alternative elevation handling approach used in some Atmos-like systems, splitting the speaker setup into horizontal layers and applying 2D VBAP within each layer [^11^].

**Source:** SPAT Revolution Documentation; Holophonix Documentation
**URL:** https://doc.flux.audio/spat-revolution/Spatialisation_Technology_Panning_Algorithms.html
**Excerpt (verbatim):**
> "Layer-based amplitude panning can be explained as multiple 2D VBAP layers: The speaker setup is split into several layers, depending on the speaker elevation. The panning used between speakers on the same layer is the VBAP 2D. Between these layers, a crossfade is applied between the two nearest layers."

**Claim:** LBAP uses 4 speakers for inter-layer positioning versus 3 for pure VBAP 3D [^11^][^12^].

**Excerpt:** "The difference between VBAP 3D and LBAP is the number of speakers that will be active between the layers: three in VBAP versus four in LBAP."

### 6.3 Virtual Loudspeakers for Elevation Coverage

**Claim:** The ITU ADM renderer adds virtual loudspeakers above and below the listener to ensure complete spherical coverage [^7^].

**Excerpt (verbatim):**
> "{0,0,-1} (below the listener) is always added, as no loudspeaker layouts defined in Recommendation ITU-R BS.2051-2 have a loudspeaker in this position. {0,0,1} (above the listener) is added if there is no loudspeaker in the layout with the label T+000 or UH+180."

These virtual loudspeakers are downmixed to physical loudspeakers using power-preserving coefficients ($w_{dmx} = 1/\sqrt{n}$).

**Confidence:** High

---

## 7. Spread Parameter and MDAP

### 7.1 The Source Width Problem

**Claim:** Standard VBAP produces virtual sources whose perceived width varies with panning direction—narrowest when aligned with a single loudspeaker and widest between loudspeakers [^13^].

**Source:** Pulkki, V., "Uniform Spreading of Amplitude Panned Virtual Sources," WASPAA 1999
**URL:** http://decoy.iki.fi/dsound/ambisonic/motherlode/source/00810881.pdf
**Excerpt (verbatim):**
> "The perceived spatial spread of amplitude panned virtual sources is dependent on the number of loudspeakers that are used to produce them. When pair-wise or triplet-wise panning is applied, the number of active loudspeakers varies as a function of the panning direction. This may cause unwanted changes in spatial spread and coloration of a virtual source if it is moved in the sound stage."

### 7.2 Multiple-Direction Amplitude Panning (MDAP)

**Claim:** MDAP creates a constant perceived source width by panning the same signal to multiple directions simultaneously [^13^][^14^].

**Source:** Pulkki 1999; Zotter & Frank 2019
**Excerpt (verbatim from Pulkki 1999):**
> "The pair-wise and triplet-wise amplitude panned virtual sources can be spread by panning the same sound signal to multiple directions. This technique is called multiple-direction amplitude panning (MDAP). When applying MDAP, the sound signal never emanates from only one loudspeaker. The directional spread is increased on directions coincident with loudspeakers, but the directional spread between loudspeakers remains on same value as in pair-wise or triplet-wise panning."

### 7.3 MDAP Mathematical Implementation

For 2D loudspeaker rings with uniform angular spacing $360°/L$, MDAP uses B virtual VBAP sources distributed around the panning direction $\theta_s$ within a spread of $\pm\varphi_{MDAP}$ [^14^][^15^].

**Claim:** The optimal spread angle is $\alpha = 90\% \times \frac{180°}{L}$, producing optimally flat width for all panning directions [^14^].

**Source:** Zotter & Frank 2019
**Excerpt:** "$\alpha = 90\% \frac{180°}{L}$ yields optimally flat width for all panning directions... Moreover, MDAP seems to equalize the aiming of the $r_E$ measure to the aiming of the $r_V$ measure."

For 3D layouts, MDAP can use additional virtual sources arranged ring-like around the main panning direction (e.g., 8 additional virtual sources at 45° distance with half amplitude) [^14^].

### 7.4 Spread in the Aalto VBAP Library

**Claim:** The reference VBAP implementation supports spread control via an extra parameter, using auxiliary spread sources arranged around the main panning direction [^5^].

**Excerpt:** "Spread can be controlled if an extra spread parameter is added to the vbap() function. This parameter determines the extent of the source in degrees. The spread effect is created by using auxiliary spread sources around the main panning direction. If no additional arguments are passed along the desired spread, a default of 8 auxiliary sources are used."

For 3D cases, spread sources are arranged on a ring around the panning direction, with optional multiple rings [^5^].

**Confidence:** High

---

## 8. Limitations

### 8.1 Sweet Spot Dependency

**Claim:** VBAP assumes the listener is at a specific "sweet spot" surrounded by equidistant loudspeakers [^11^][^16^].

**Source:** SPAT Revolution; Embody Volumetric Panning Paper
**URL:** https://embody.co/blogs/technology/volumetric-amplitude-panning-and-diffusion-for-spatial-audio-production
**Excerpts:**
> "One such limitation found in VBAP and MDAP is the assumption that the listener be placed in a 'sweet spot' surrounded by equidistantly positioned loudspeakers, rendering both techniques incompatible with irregular loudspeaker layouts."

> "The positions of the loudspeakers must be equidistant from the listener, and is often standardized, therefore difficult to reproduce according to the installation constraints."

### 8.2 Speaker Distance Assumptions

**Claim:** VBAP assumes all loudspeakers are equidistant from the listener. Violations cause localization errors and timbral variations [^1^][^16^].

**Excerpt (from Pulkki 1997):**
> "The loudspeakers are required to be nearly equidistant from the listener, and the listening room is assumed to be not very reverberant."

Modern implementations compensate for unequal distances using delay and gain alignment [^11^].

### 8.3 Spatial Jumps at Triplet Boundaries

**Claim:** When a virtual source crosses a common edge between adjacent loudspeaker triplets, VBAP can produce audible spatial jumps [^16^][^17^].

**Excerpt:** "VBAP, which renders sound sources between adjacent loudspeaker triplets in 3D layouts, can incur intense spatial jumps across the loudspeakers' common edge. When representing moving sound sources, VBAP causes unintended fluctuations in both perceived spatial spread and spectral coloration."

### 8.4 Off-Center Listening Positions

**Claim:** At off-center listening positions, the nearest loudspeaker dominates localization, causing the apparent direction to be attracted toward closer loudspeakers [^14^].

**Source:** Zotter & Frank 2019
**Excerpt:** "While localization is slightly attracted by the closer loudspeaker at 0°, the larger spread causes a more monotonic outcome that is less split than with VBAP."

**Claim:** VBAP can produce ITD deviations exceeding 5° at certain azimuth angles in irregular loudspeaker placements [^18^].

**Source:** "Adaptive Binaural Cue-Based Amplitude Panning in Irregular Loudspeaker Configurations," Applied Sciences, 2025
**URL:** https://www.mdpi.com/2076-3417/15/9/4689
**Excerpt:** "The VBAP algorithm still produces ITD deviations in irregular loudspeaker placements, with errors exceeding 5° at certain azimuth angles. This phenomenon arises because of the VBAP algorithm's inherent limitation of disregarding the unique acoustic environment and treating the loudspeaker configuration as a standard setup."

### 8.5 Frequency Dependence

**Claim:** VBAP's vector model (velocity vector $r_V$) accurately predicts localization only below ~700 Hz; above this frequency, the energy vector $r_E$ becomes the better predictor [^19^].

**Source:** Frank, "Localization of Amplitude-Panned Virtual Sources"
**Excerpt:** "The direction of the velocity vector was proposed as a simple predictor for the localization of low frequencies ($\leq$ 700 Hz)... The energy vector $r_E$ was defined as... This model assumes an energetic superposition of the loudspeaker signals and is expected to model the localization direction for higher frequencies or broadband signals."

**Confidence:** High

---

## 9. VBIP and Frequency-Dependent Panning

### 9.1 Vector Base Intensity Panning (VBIP)

**Claim:** VBIP is the energy-vector analogue of VBAP, designed to optimize high-frequency localization [^11^][^20^].

**Source:** SPAT Revolution; Menzies & Fazi
**Excerpt (verbatim):**
> "VBIP was designed to improve on VBAP when calculating the high-frequency (above 700 Hz) localization criteria. The selection of which speakers to use to render a virtual sound source is similar to VBAP, only the gain calculations differ."

### 9.2 VBIP Mathematical Derivation

**Claim:** VBIP computes gains such that the Gerzon Energy Vector $r_E$ aligns with the virtual source direction. This is achieved by taking the square root of VBAP gains [^20^][^21^].

**Source:** "A Low Frequency Panning Method with Compensation for Head Rotation"
**URL:** https://eprints.soton.ac.uk/415939/1/08115309.pdf
**Excerpt (verbatim):**
> "The Gerzon Energy Vector $r_E$ provides an estimate of the image direction cue produced by panning high frequency signals, and is independent of head direction. It is defined by:
> $$r_E = \frac{\sum \tilde{g}_i^2 \tilde{r}_i}{\sum \tilde{g}_i^2}$$
> where the hat is used to indicate the gains are for high frequency. By comparison with (20) the gains can be found by first calculating the low frequency gains using the Tangent Law/VBAP then applying the mapping $\tilde{g}_i = \sqrt{g_i}$. The gains can then be modified to satisfy the normalisation $\sum \tilde{g}_i^2 = 1$. This technique is known as Vector Base Intensity Panning (VBIP)."

### 9.3 Dual-Band Vector Based Panning

**Claim:** The optimal panning approach combines VBAP for low frequencies and VBIP for high frequencies, with a crossover at 700 Hz by default [^11^][^22^].

**Source:** SPAT Revolution Documentation; Holophonix Guide
**Excerpt (verbatim):**
> "Both Intensity and Amplitude Vector Based panning have an ideal frequency range of action:
> - Localization of low frequencies is better with Amplitude Panning.
> - Localization of high frequencies is better with Intensity Panning.
> A hybrid approach of vector-based panning has been developed in this way: the Dual Band Vector Based Panning. This panning type merges the two approaches in order to combine the best of both worlds and to reach a better localization. Amplitude panning is applied below the crossover frequency, while intensity panning is applied above. The crossover frequency has been defined to 700 Hz by default."

**Confidence:** High

### 9.4 Frequency-Dependent p-Value

**Claim:** Laitinen et al. (2014) proposed a frequency-dependent p-value that transitions smoothly from amplitude normalization (p=1) at low frequencies to energy normalization (p=2) at high frequencies, based on the room's direct-to-total energy ratio (DTT) [^9^].

**Source:** Laitinen, M.-V. et al., "Gain normalization in amplitude panning as a function of frequency and room reverberance," AES 55th International Conference, 2014
**Excerpt (from VBAP library documentation):**
> "A solution is proposed in [ref.7], where the p-value becomes frequency-dependent, with respect to a room-related parameter corresponding roughly to the direct-to-total energy ratio."

The p-value curves are derived for listening with pairs of loudspeakers but have been successfully applied in 3D setups [^9^].

**Confidence:** High

---

## 10. SPCAP as an Alternative

### 10.1 Speaker-Placement Correction Amplitude Panning

**Claim:** SPCAP extends VBAP by selecting any number of speakers (not just 2 or 3) and weighting gains according to each speaker's contribution to the overall power output [^23^].

**Source:** SPAT Revolution Documentation
**URL:** https://doc.flux.audio/spat-revolution/Spatialisation_Technology_Panning_Algorithms.html
**Excerpt (verbatim):**
> "SPCAP is a 3D panning algorithm that takes its inspiration from VBAP. SPCAP selects not just 2 or 3, but any number of speakers to render a virtual source and weights signal gains according to how much each selected speaker is actually contributing to the overall power output of the speaker configuration. Using this method SPCAP guarantees conservation of loudspeakers power output across any speaker arrangement."

### 10.2 SPCAP Advantages

**Claim:** SPCAP's strengths lie in downmixing/upmixing between different channel-based speaker arrangements and rendering wider sound sources by using more speakers [^23^].

**Excerpt:** "Its strengths lie in the down-mixing and up-mixing of virtual scenes from very different channel-based speaker arrangements, and in being able to render wider sound sources by smartly using more speakers."

SPCAP produces a wider sweet spot than VBAP while maintaining spatial imaging quality [^23^].

**Confidence:** Medium

---

## 11. Crossfade Interpolation

### 11.1 Two-Level Interpolation in Pulkki's Implementation

**Claim:** Pulkki's original VBAP implementation used two-level interpolation for smooth virtual source movement [^1^].

**Excerpt (verbatim):**
> "The tool has two levels of interpolation for virtual source direction movement. The user may update the direction vectors $p_{1...n}$ approximately once per second. The panning tool calculates for example 50 vectors $p_{1...x}(1,...,50)$ between new and old direction vectors. With each interpolating direction vector set $p_{1...x}(n)$ new loudspeaker triplets are selected and new gain factors are calculated using the VBAP method."

### 11.2 Linear Crossfade

**Claim:** Gain factors are crossfaded linearly between old and new values to avoid audible clicks during triplet changes [^1^].

**Excerpt (verbatim):**
> "The previous gain factors $p_{1...x}(n-1)$ are cross faded to calculate factors $p_{1...x}(n)$ linearly. One interpolation is completed with equal steps during approximately 100 sample intervals. All eight gain factor triplets are cross faded simultaneously. The gain factors do not exactly satisfy Eq.(11) during fading. However, when the angle between starting-point and end-point direction vectors is small (~1°), no disturbing effects can be heard."

### 11.3 Modern Interpolation Approaches

**Claim:** Modern implementations use orthodromic (great-circle) interpolation for more accurate source movement trajectories [^24^].

**Source:** "Vector Base Amplitude Panning" (KUG Thesis)
**URL:** https://phaidra.kug.ac.at/api/object/o:66459/download
**Excerpt (verbatim):**
> "Two points (given in spherical coordinates, with elevation $\theta$ and azimuth $\phi$) are lying on a unit sphere (radius = 1). Then the shortest distance between these two points — taking the path on the spheric surface — is defined by the arc segment enclosed by their central angle. It is called orthodromic distance or great-circle distance."

The number of interpolated points is empirically determined:

$$n = \text{round}(5 \cdot \sqrt{d - 1})$$

where $d$ is the orthodromic distance. The audio buffer is split into segments and VBAP is applied separately for each segment.

### 11.4 Real-Time Block Processing

**Claim:** In real-time block processing, crossfade interpolation is applied per-block when source position changes exceed a threshold [^24^].

**Excerpt:** "If the source did move slightly, the gain will be recomputed by the calculateHullGain() function implementing the VBAP method. All zero gain entries will clear the corresponding channel, while non-zero gain values will be crossfaded (old to new gain value, linear)."

**Confidence:** High

---

## 12. Key Findings Summary

### 12.1 Summary of Key Findings

Vector Base Amplitude Panning (VBAP), introduced by Ville Pulkki in 1997, represents one of the most significant advances in spatial audio rendering. Its vector-based reformulation of amplitude panning provides a mathematically elegant and computationally efficient framework for positioning virtual sound sources in arbitrary loudspeaker configurations.

**Mathematical Foundation.** At its core, VBAP treats virtual source positioning as a linear algebra problem. The virtual source direction vector $p$ is decomposed into a linear combination of loudspeaker direction vectors arranged as columns of the vector base matrix $L$. Gain factors are computed via matrix inversion: $g = L^{-1} \cdot p$. In 2D, this formulation is provably equivalent to the classical tangent law of stereophony. In 3D, three loudspeakers form a triplet that can position a source anywhere within the spherical triangle they define on the unit sphere.

**Triplet Selection and Convex Hull.** A critical preprocessing step computes the convex hull of all loudspeaker positions on the sphere, producing a Delaunay triangulation that partitions the sphere into non-overlapping spherical triangles. At runtime, the triplet containing the virtual source direction is found by testing all triplets and selecting the one yielding all-positive gains. The ITU-R ADM renderer extends this with quadrilateral regions and virtual loudspeakers for smoother panning in broadcast applications.

**Gain Normalization.** VBAP's default energy normalization ($\sum g_l^2 = 1$) assumes incoherent signal summation, appropriate for reverberant environments and mid-to-high frequencies. However, research by Laitinen et al. (2014) established that a frequency-dependent p-value should be used: amplitude normalization (p=1) at low frequencies transitioning to energy normalization (p=2) at high frequencies. The SPARTA Panner implements this via the DTT parameter, varying from 0 (diffuse field) to 1 (anechoic).

**Dual-Band Panning and VBIP.** Human sound localization relies on different cues in different frequency ranges: interaural time differences (ITDs) below ~700 Hz and interaural level differences (ILDs) above. VBAP optimizes the velocity vector alignment (ITD cues), while Vector Base Intensity Panning (VBIP) optimizes the energy vector alignment (ILD cues) by taking $\tilde{g}_i = \sqrt{g_i}$. The Dual-Band Vector Based Panning approach combines both: VBAP below 700 Hz and VBIP above, implemented via crossover filters.

**Spread and MDAP.** A fundamental limitation of basic VBAP is that perceived source width varies with panning direction—sources collapse to a single loudspeaker when aligned with it. Multiple-Direction Amplitude Panning (MDAP) solves this by distributing the same signal to multiple virtual source positions around the desired direction. For a ring of $L$ equally-spaced loudspeakers, the optimal MDAP spread is $\alpha = 90\% \times 180°/L$, producing constant perceived width across all directions. This is implemented in the Aalto VBAP library via a spread parameter that controls the number and arrangement of auxiliary spread sources.

**Limitations.** VBAP assumes: (1) the listener is at a central sweet spot, (2) all loudspeakers are equidistant, (3) the room is not highly reverberant, and (4) the listener faces forward. Off-center listening causes localization attraction toward nearer loudspeakers. Triplet boundary crossings can produce audible spatial jumps. In irregular layouts, ITD errors can exceed 5° at certain angles. Modern alternatives like Distance-Based Amplitude Panning (DBAP), Volumetric Amplitude Panning, and SPCAP address some of these limitations at the cost of increased computational complexity or reduced localization precision.

**Crossfade Interpolation.** For moving sources, Pulkki's original implementation used two-level interpolation: first interpolating direction vectors (e.g., 50 intermediate steps), then computing new gains and crossfading linearly over ~100 samples. Modern implementations use orthodromic (great-circle) interpolation for more physically accurate trajectories, with the number of interpolation points proportional to the angular distance traveled.

**ADM Renderer Integration.** The ITU-R BS.2127 ADM renderer—used in broadcast object-based audio—implements an enhanced VBAP with support for quadrilateral regions (smoother than triplet-only VBAP), virtual loudspeakers for complete spherical coverage, warped triangulation for consistent behavior across layout adaptations, and downmix matrices for handling sparse layouts. The EBU TECH 3388 specification documents this implementation.

### 12.2 Unresolved Questions and Gaps

1. **Optimal crossover frequency for dual-band panning:** While 700 Hz is the commonly cited default, the exact optimal crossover depends on room acoustics and individual HRTF variations. Adaptive crossover frequencies have not been extensively studied.

2. **MDAP in 3D irregular layouts:** While MDAP is well-characterized for 2D loudspeaker rings, optimal virtual source arrangements for 3D irregular layouts remain an open research problem. Epain's optimization approach (cited in Zotter & Frank) requires solving a non-convex optimization per panning direction.

3. **Frequency-dependent triplet selection:** Current VBAP selects the same triplet across all frequencies. At high frequencies where ILD cues dominate, a different triplet might produce better localization due to the energy vector vs. velocity vector discrepancy.

4. **Listener-adaptive VBAP:** While CAP (Compensated Amplitude Panning) adapts to head orientation, integrating this into standard VBAP pipelines remains challenging for real-time systems without head tracking.

5. **VBAP for near-field sources:** Standard VBAP assumes far-field (plane wave) sources. Extensions for near-field rendering (distance-dependent virtual sources) are not part of the classical formulation.

6. **Perceptual impact of triplet boundary transitions:** While crossfading mitigates audible artifacts, the exact perceptual thresholds for detecting triplet switches as a function of signal content and movement speed have not been fully characterized.

---

## 13. References

[^1^]: Pulkki, V. (1997). "Virtual Sound Source Positioning Using Vector Base Amplitude Panning." *Journal of the Audio Engineering Society*, 45(6), 456-466. https://www.audiolabs-erlangen.de/resources/aps-w23/papers/sap_Pulkki1997.pdf

[^2^]: Lyons, R. (2019). "Stereophonic Amplitude-Panning: A Derivation of the 'Tangent Law'." *DSPRelated.com*. https://www.dsprelated.com/showarticle/1230.php

[^3^]: Zotter, F. & Frank, M. (2019). "Amplitude Panning Using Vector Bases." In *Ambisonics: A Practical 3D Audio Theory for Recording, Studio Production, Sound Reinforcement, and Virtual Reality*, Springer. https://link.springer.com/chapter/10.1007/978-3-030-17207-7_3

[^4^]: Zotter, F. & Frank, M. (2019). *A Practical 3D Audio Theory for Spatial Audio*. Springer. https://library.oapen.org/bitstream/id/a418a7e9-2245-47c1-8c29-d5cdd227b678/1007063.pdf

[^5^]: Politis, A. (2015). "Vector-Base Amplitude Panning Library." Aalto University. http://research.spa.aalto.fi/projects/vbap-lib/vbap.html

[^6^]: Gamper, H. (2013). "Selection and interpolation of head-related transfer functions based on convex hull Delaunay triangulation." *DAFX 2013*. https://dafx.de/paper-archive/2013/papers/53.dafx2013_submission_59.pdf

[^7^]: ITU-R BS.2127-1 (2023). "Audio Definition Model renderer for advanced sound systems." https://www.itu.int/dms_pubrec/itu-r/rec/bs/R-REC-BS.2127-1-202311-I!!PDF-E.pdf

[^8^]: Zotter, F. & Frank, M. (2019). "A Practical 3D Audio Theory for Spatial Audio." Springer. https://library.oapen.org/bitstream/id/a418a7e9-2245-47c1-8c29-d5cdd227b678/1007063.pdf

[^9^]: Laitinen, M.-V., Vilkamo, J., Jussila, K., Politis, A., & Pulkki, V. (2014). "Gain normalization in amplitude panning as a function of frequency and room reverberance." *AES 55th International Conference*, Helsinki, Finland.

[^10^]: McCormack, L. "SPARTA Panner Plugin." Aalto University. https://leomccormack.github.io/sparta-site/docs/plugins/sparta-suite/

[^11^]: FLUX:: Immersive. "SPAT Revolution - Panning Algorithms." https://doc.flux.audio/spat-revolution/Spatialisation_Technology_Panning_Algorithms.html

[^12^]: Holophonix. "A Guide to Amplitude Panning." https://holophonix.xyz/documentation/docs/guides/ap-guide/

[^13^]: Pulkki, V. (1999). "Uniform Spreading of Amplitude Panned Virtual Sources." *IEEE Workshop on Applications of Signal Processing to Audio and Acoustics (WASPAA)*. http://decoy.iki.fi/dsound/ambisonic/motherlode/source/00810881.pdf

[^14^]: Zotter, F. & Frank, M. (2019). "Multiple-Direction Amplitude Panning (MDAP)." In *Ambisonics*, Springer. https://link.springer.com/chapter/10.1007/978-3-030-17207-7_3

[^15^]: Wabnik, S. et al. (2014). "Localization using different amplitude-panning methods in the horizontal plane." *EAA Joint Symposium on Auralization and Ambisonics*. https://d-nb.info/1153064278/34

[^16^]: Embody. "Volumetric Amplitude Panning and Diffusion for Spatial Audio Production." (2022). https://embody.co/blogs/technology/volumetric-amplitude-panning-and-diffusion-for-spatial-audio-production

[^17^]: Gamper, H. (2013). "VBAP-Derived Panning Functions for 3D Loudspeaker Systems." *Ambisonics Symposium*. https://ambisonics10.ircam.fr/drupal/files/proceedings/presentations/O14_47.pdf

[^18^]: "Adaptive Binaural Cue-Based Amplitude Panning in Irregular Loudspeaker Configurations." *Applied Sciences*, 15(9), 4689, 2025. https://www.mdpi.com/2076-3417/15/9/4689

[^19^]: Frank, M. "Localization of Amplitude-Panned Virtual Sources, Part 1: Stereophonic Panning." https://www.researchgate.net/publication/263008227

[^20^]: Menzies, D. & Fazi, F.M. (2019). "Multichannel Compensated Amplitude Panning, An Adaptive Object-Based Reproduction Method." *Journal of the Audio Engineering Society*, 67(7/8). https://eprints.soton.ac.uk/432463/

[^21^]: Menzies, D. & Fazi, F.M. "A Low Frequency Panning Method with Compensation for Head Rotation." https://eprints.soton.ac.uk/415939/1/08115309.pdf

[^22^]: FLUX:: Immersive. "SPAT Revolution User Guide." https://www.espaceconcept.eu/wp-content/uploads/2025/04/manuel-utilisation-spat-revolution-flux-distributeur-espace-concept.pdf

[^23^]: FLUX:: Immersive. "Speaker-Placement Correction Amplitude (SPCAP)." https://doc.flux.audio/spat-revolution/Spatialisation_Technology_Panning_Algorithms.html

[^24^]: "Vector Base Amplitude Panning" (Master's thesis, KUG, 2017). https://phaidra.kug.ac.at/api/object/o:66459/download

[^25^]: VBAP Rust Crate. https://docs.rs/vbap

[^26^]: ITU-R BS.2127-0 (2019). "Audio Definition Model renderer for advanced sound systems." https://www.itu.int/dms_pubrec/itu-r/rec/bs/R-REC-BS.2127-0-201906-S!!PDF-E.pdf

[^27^]: EBU TECH 3388. "Audio Definition Model renderer for advanced sound systems." https://tech.ebu.ch/docs/tech/tech3388v1.pdf

[^28^]: ETSI TS 103 584 V1.1.1 (2018). "DTS-UHD Point Source Renderer." https://www.etsi.org/deliver/etsi_ts/103500_103599/103584/01.01.01_60/ts_103584v010101p.pdf

[^29^]: Arbane Groupe. "Comparison of VBAP and DBAP." https://www.arbane-groupe.com/en/blog.html

[^30^]: Politis, A. (2015). "Vector-Base-Amplitude-Panning" GitHub Repository. https://github.com/polarch/Vector-Base-Amplitude-Panning

[^31^]: McCormack, L. "Spatial Audio Framework - VBAP." https://leomccormack.github.io/Spatial_Audio_Framework/group___v_b_a_p.html

[^32^]: ITU-R BS.2466-1 (2022). "Guidelines for the use of the ITU-R ADM Renderer." https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-BS.2466-1-2022-PDF-E.pdf

[^33^]: Pulkki, V. (1997). AES Journal Forum. https://secure.aes.org/forum/pubs/journal/?elib=7853

---

*Document compiled from 20+ independent web searches across academic databases (IEEE, AES), standards bodies (ITU, EBU, ETSI), university research repositories (Aalto, University of Southampton, KUG), software documentation (SPARTA, SPAT Revolution, Holophonix), and technical books (Springer).*
