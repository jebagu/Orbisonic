# Dimension 8: Ambisonics and HOA -- The Mathematical Foundation for Full-Sphere Audio

## Comprehensive Research Findings

---

## 1. Spherical Harmonics: The Mathematical Basis

### 1.1 Definition and Core Properties

Spherical harmonics (SH) form the mathematical foundation of Ambisonics. They are the angular portion of the solution to Laplace's equation in spherical coordinates and provide a complete orthonormal basis for functions defined on the surface of a sphere [^153^].

**Claim:** Spherical harmonics are defined as $Y_{l,m}(\theta,\phi)$ where $l$ is the order (degree) and $m$ is the degree (order), with the range $0 \leq l \leq N$ and $-l \leq m \leq l$. [^153^]
**Source:** Wolfram MathWorld
**URL:** https://mathworld.wolfram.com/SphericalHarmonic.html
**Date:** 2004-01-03
**Excerpt:** "The spherical harmonics are the angular portion of the solution to Laplace's equation in spherical coordinates where azimuthal symmetry is not present... The spherical harmonics satisfy the spherical harmonic differential equation, which is given by the angular part of Laplace's equation in spherical coordinates."
**Confidence:** High

**Claim:** In audio applications, the real form of spherical harmonics is commonly used. The decomposition of a function $f(\Omega)$ on the unit sphere is given by: $f(\Omega) = \sum_{n=0}^{\infty} \sum_{m=-n}^{n} f_{nm} Y_n^m(\Omega)$, where coefficients $f_{nm}$ are calculated via the spherical harmonic transform. [^37^]
**Source:** Springer / EURASIP Journal on Audio, Speech, and Music Processing
**URL:** https://link.springer.com/article/10.1186/s13636-025-00393-7
**Date:** 2025-02-12
**Excerpt:** "Consider a function $f(\theta, \phi) = f(\Omega) \in L^2(S^2)$ on the unit 2-sphere $S^2 := \{\textbf{x} \in \mathbb{R}^3 : \Vert \textbf{x} \Vert_2 = 1\}$, then the SH decomposition of f is given by: $f(\Omega) = \sum_{n=0}^{\infty} \sum_{m=-n}^{n} f_{nm} Y_n^m(\Omega)$"
**Confidence:** High

### 1.2 Coordinate System Convention

**Claim:** The ambisonics community uses a coordinate system where the x-axis points to the front, y-axis to the left, and z-axis to the top. The angle $\phi$ (azimuth) is zero at the frontal direction and increases counterclockwise; $\theta$ (elevation) is zero at the horizontal plane and positive above, ranging from $-90°$ (nadir/below) to $+90°$ (zenith/above). [^37^] [^64^]
**Source:** AmbiX Format Specification / Springer
**URL:** https://ambisonics.iem.at/proceedings-of-the-ambisonics-symposium-2011/ambix-a-suggested-ambisonics-format
**Date:** 2011-06-02
**Excerpt:** "As a coordinate system, it is useful to define the x-axis pointing into the main look direction of the listener, the y-axis as the left, and the z-axis as the top direction... The angle $\phi$ is the azimuth angle starting at the frontal direction and running counterclockwise, $\vartheta$ is the elevation, which is zero at the horizontal plane and negative below."
**Confidence:** High

### 1.3 Real-Valued Spherical Harmonics for Audio

**Claim:** The real-valued form of spherical harmonics used in Ambisonics is defined as [^64^]:
$Y_n^m(\phi, \vartheta) = N_n^{|m|} P_n^{|m|}(\sin(\vartheta)) \times \begin{cases} \sin(|m|\phi) & \text{for } m < 0 \\ \cos(|m|\phi) & \text{for } m \geq 0 \end{cases}$

where $P_n^{|m|}$ are the associated Legendre functions and $N_n^{|m|}$ is a normalization term.
**Source:** AmbiX Paper, Ambisonics Symposium 2011
**URL:** https://ambisonics.iem.at/proceedings-of-the-ambisonics-symposium-2011/ambix-a-suggested-ambisonics-format
**Date:** 2011-06-02
**Excerpt:** "As definition for real spherical harmonics, the following scheme seems to provide an agreeable definition: $Y_n^m(\phi, \vartheta) = N_n^{|m|} P_n^{|m|}(\sin(\vartheta)) \times [\sin(|m|\phi) \text{ for } m<0, \cos(|m|\phi) \text{ for } m \geq 0]$"
**Confidence:** High

### 1.4 Orthonormality Property

**Claim:** Spherical harmonics satisfy the orthonormality condition: $\oint |Y_{l,m}(\theta,\phi)|^2 \, d\Omega = 1$, and more generally $\int_0^{2\pi} d\phi \int_0^{\pi} \sin\theta \, d\theta \, Y_{l'}^{m'*} (\theta,\phi) Y_l^m(\theta,\phi) = \delta_{l,l'} \delta_{m,m'}$. [^150^] [^151^]
**Source:** Binghamton University / LibreTexts Physics
**URL:** https://bingweb.binghamton.edu/~suzuki/QuantumMechanicsII/4-9_Spherical_harmonics.pdf
**Date:** 2023-03-03
**Excerpt:** "Orthogonality: $\langle l', m' | l, m \rangle = \delta_{l,l} \delta_{m,m'} = \int d\Omega \langle l', m' | n \rangle \langle n | l, m \rangle = \int_0^{2\pi} d\phi \int_0^{\pi} \sin\theta \, d\theta \, Y_{l'}^{m'*} (\theta,\phi) Y_l^m(\theta,\phi)$"
**Confidence:** High

---

## 2. Ambisonic Encoding: Converting Point Sources to Spherical Harmonic Coefficients

### 2.1 The Encoding Process

**Claim:** The encoding process converts a point source signal $s(t)$ at direction $(\theta, \phi)$ into spherical harmonic coefficients $B_{nm}$ (also written $a_n^m$). For a plane wave source, the encoding equation is: $B_{nm}(t) = s(t) \cdot Y_n^m(\theta, \phi)$. [^36^] [^39^]
**Source:** Cambridge University Press (APSIPA) / Grokipedia
**URL:** https://www.cambridge.org/core/journals/apsipa-transactions-on-signal-and-information-processing/article/immersive-audio-capture-transport-and-rendering-a-review/A39094D58238A0F66750D48362D5FF17
**Date:** 2026-04-23
**Excerpt:** "Assuming plane wave source signal s in the direction of ($\theta, \varphi$), for example, we can derive the second-order ambisonic components as below (equation (7)), which constitutes an ambisonic encoding process expressed in general by $s \cdot Y_n^m(\theta, \varphi)$."
**Confidence:** High

### 2.2 First-Order Encoding (B-Format)

**Claim:** For first-order Ambisonics (FOA), the encoding matrix for a source at direction $(\theta, \phi)$ is [^39^]:
$$[W, X, Y, Z]^T = s(t) \cdot [1/2, \cos\phi\cos\theta, \sin\phi\cos\theta, \sin\theta]^T$$

Note: In SN3D/ACN (AmbiX), W uses $1/\sqrt{2}$ rather than $1/2$.
**Source:** Grokipedia - Ambisonics
**URL:** https://grokipedia.com/page/Ambisonics
**Date:** Unknown
**Excerpt:** "The first-order encoding matrix for a virtual source signal s(t) at direction ($\theta, \phi$) is given by: [W X Y Z] = s(t) [1/2 cos(\phi)cos(\theta) sin(\phi)cos(\theta) sin(\theta)]"
**Confidence:** High

### 2.3 Higher-Order Encoding

**Claim:** In higher orders, the weights for the B-format channels are given by the real spherical harmonic functions $Y_n^m(\theta, \phi)$ evaluated at the source direction $(\theta, \phi)$, scaled by the source amplitude, providing finer control over directional resolution. [^39^]
**Source:** Grokipedia - Ambisonics
**URL:** https://grokipedia.com/page/Ambisonics
**Date:** Unknown
**Excerpt:** "In higher orders, the weights for the B_nm channels are given by the real spherical harmonic functions Y_n^m (\theta, \phi) evaluated at the source direction (\theta, \phi), scaled by the source amplitude, providing finer control over directional resolution."
**Confidence:** High

---

## 3. Channel Count Formula: n = (m+1)² for 3D HOA of Order m

**Claim:** For 3D Higher Order Ambisonics of order $N$, the number of channels required is $(N+1)^2$. This gives: 1st order = 4 channels, 2nd order = 9 channels, 3rd order = 16 channels, 4th order = 25 channels, 5th order = 36 channels. [^12^] [^41^] [^80^]
**Source:** Mashav HOA Encoder / MATLAB Documentation
**URL:** https://mashav.com/sha/praat/scripts/Higher-Order_Ambisonic_(HOA)_Encoder.html
**Date:** Unknown
**Excerpt:** "Channel count formula: (order + 1)² channels. 1st: (1+1)² = 4 channels. 2nd: (2+1)² = 9 channels. 3rd: (3+1)² = 16 channels."
**Confidence:** High

**Claim:** The channel count formula arises because each order $n$ contributes $2n+1$ harmonics (for $m = -n, -n+1, ..., 0, ..., n-1, n$), and summing from $n=0$ to $N$ gives $\sum_{n=0}^{N} (2n+1) = (N+1)^2$. [^70^]
**Source:** Grokipedia - Mixed-order Ambisonics
**URL:** https://grokipedia.com/page/mixed_order_ambisonics
**Date:** 2026-01-08
**Excerpt:** "Higher orders introduce additional components, with each order n contributing 2n+1 harmonics, for a total of (N+1)^2 channels in a full periphonic (3D) representation up to order N; for example, second order requires 9 channels, while third order uses 16."
**Confidence:** High

---

## 4. Full-Sphere Coverage: Elevation from -90° (Nadir) to +90° (Zenith)

**Claim:** Full-sphere (periphonic) Ambisonics provides complete coverage over the entire sphere, with elevation ranging from -90° (directly below/nadir) through 0° (horizontal plane) to +90° (directly above/zenith). This is in contrast to horizontal-only (pantophonic) systems that operate only in the 2D plane. [^12^] [^71^]
**Source:** Mashav HOA Encoder / Acta Acustica 2024
**URL:** https://mashav.com/sha/praat/scripts/Higher-Order_Ambisonic_(HOA)_Encoder.html
**Date:** Unknown
**Excerpt:** "Elevation: -90° to +90° (vertical plane). +90° = Directly above (zenith). 0° = Horizontal plane (same height as listener). -90° = Directly below (nadir)."
**Confidence:** High

**Claim:** Periphonic (3D) rendering methods show improved vertical localization compared to horizontal-only methods, particularly for elevated sources. However, the perceptual advantage depends on scene complexity -- it disappears in complex acoustic environments. [^71^]
**Source:** Acta Acustica 2024
**URL:** https://acta-acustica.edpsciences.org/articles/aacus/full_html/2024/01/aacus230027/aacus230027.html
**Date:** 2024-04-01
**Excerpt:** "The results show that an improvement in vertical localization can be obtained by using periphonic rendering instead of horizontal rendering. The perceptual advantage of periphonic rendering depends on the spatial complexity of the scene; it disappears in complex acoustic environments."
**Confidence:** High

---

## 5. Ambisonic Decoding: Converting HOA Coefficients to Speaker Feeds

### 5.1 The Decoding Problem

**Claim:** The decoding step aims at reconstructing the primary acoustic wave by a loudspeaker setup. Given an array of $N_L$ emitters, the goal is to derive loudspeaker signals $s_l$ such that the spherical harmonic expansion of the primary and synthesized waves are matched (mode-matching principle): $B_{mn} = \sum_{l=1}^{N_L} s_l(\omega) L_{l=mn}(\omega)$, which yields a set of $(M+1)^2$ equations with $N_L$ unknowns. [^46^]
**Source:** IRCAM - Proceedings of 2nd International Symposium on Ambisonics and Spherical Acoustics
**URL:** https://ambisonics10.ircam.fr/drupal/files/proceedings/keynotes/K4.pdf
**Date:** Unknown
**Excerpt:** "The decoding step aims at reconstructing the primary acoustic wave by a loudspeaker setup... To derive the s_l signals to feed the loudspeaker, the spherical harmonic expansion of the primary and the synthesized waves are matched (mode-matching principle): $B_{mn} = \sum_{l=1}^{N_L} s_l(\omega) L_{l=mn}(\omega)$, which yields a set of $(M+1)^2$ equations with $N_L$ unknowns."
**Confidence:** High

### 5.2 Projection Decoding (SAD - Sampling Ambisonic Decoding)

**Claim:** Projection decoding, also called "sampling ambisonic decoding" (SAD), is the simplest form of ambisonic decoding. It samples the virtual panning function at the loudspeaker directions. SAD is optimal for loudspeakers arranged as t-design layouts, with $t \geq (2N+1)$ where N is the Ambisonics order. Typically, SAD should only be used for 2D loudspeaker layouts. [^40^]
**Source:** SPAT Revolution Documentation / Flux Audio
**URL:** https://doc.flux.audio/spat-revolution/Spatialisation_Technology_Ambisonic_transcoding.html
**Date:** Unknown
**Excerpt:** "Projection decoding is also sometimes called 'sampling ambisonic decoding' (SAD). It is the simplest form of ambisonic decoding. It samples the virtual panning function at the loudspeaker directions. SAD is optimal for loudspeakers arranged as t-design layouts, with t >= (2N+1). Typically, the SAD should only be used for 2D loudspeaker layouts."
**Confidence:** High

### 5.3 Mode Matching / Pseudoinverse Decoding

**Claim:** The mode-matching decoder (MMAD), also known as pseudoinverse decoding, is suitable for both 2D and 3D. It is based on a pseudo-inverse of the re-encoding matrix. MMAD is well-behaved for regular loudspeaker arrangements but can become unstable with strongly irregular setups. [^40^] [^72^] [^75^]
**Source:** SPAT Revolution / SuperCollider / Ambisonic Decoder Toolbox
**URL:** https://depts.washington.edu/dxscdoc/Help/Classes/HoaMatrixDecoder.html
**Date:** Unknown
**Excerpt:** "Decode a Higher Order Ambisonic signal (HOA) via the mode matching method. Also known as Pseudoinverse Decoding, aka Pinv. NOTE: Comprehensive modal discarding is not applied. More evenly distributed directions will return a more stable decoder."
**Confidence:** High

**Claim:** In the general case, the encoding matrix K (whose columns are spherical harmonics sampled at speaker positions) is rank-deficient, so the inversion must be done by least-squares or by using singular-value decomposition (SVD) and the Moore-Penrose pseudoinverse. Problems arise when a loudspeaker array does a poor job of sampling some spherical harmonics -- K becomes ill-conditioned and the decoder has greater energy gain in certain directions. [^75^]
**Source:** The Ambisonic Decoder Toolbox (LAC 2014)
**URL:** http://lac.linuxaudio.org/2014/papers/17.pdf
**Date:** Unknown
**Excerpt:** "Because K is 'encoding' the speaker positions, some authors call it the reencoding matrix and refer to the inversion as mode matching. In the general case, K is rank deficient, so the inversion must be done by least-squares or by using singular-value decomposition (SVD) and the Moore-Penrose pseudoinverse."
**Confidence:** High

### 5.4 Regularized Pseudo-Inverse (RMMAD)

**Claim:** The regularized mode-matching decoder (RMMAD) uses a regularization factor (alpha) for stabilization. At alpha = 0%, results are similar to MMAD. At alpha = 100%, it generates even energy distribution (similar to EPAD). Intermediate values blend MMAD and EPAD characteristics. [^40^]
**Source:** SPAT Revolution Documentation
**URL:** https://doc.flux.audio/spat-revolution/Spatialisation_Technology_Ambisonic_transcoding.html
**Date:** Unknown
**Excerpt:** "The regularized pseudo-inverse decoder or 'regularized-mode-matching decoder' (RMMAD) is somehow similar to MMAD. However, it uses a regularization factor for the stabilization of the pseudo-inverse. This regularization factor (alpha) varies from 0% to 100%."
**Confidence:** High

### 5.5 Gerzon's Velocity and Energy Vectors (rV and rE)

**Claim:** Gerzon developed two key metrics for evaluating decoder performance. The velocity localization vector $r_V$ predicts low-frequency localization (ITD cues), and the energy localization vector $r_E$ predicts mid-to-high-frequency localization (ILD cues). The magnitude indicates localization "quality" (unity is optimal) and the direction indicates perceived source direction. [^116^] [^117^]
**Source:** A Toolkit for the Design of Ambisonic Decoders / AES Convention Paper
**URL:** http://lac.linuxaudio.org/2012/papers/18.pdf
**Date:** Unknown
**Excerpt:** "Gerzon developed a series of metrics for predicting localization... The simplest of these metrics are the velocity localization vector, rV, and the energy localization vector, rE. The direction of each indicates the direction of the expected localization perception, while the magnitude indicates the quality of the localization. In natural hearing from a single source, the magnitude of each vector should be exactly 1."
**Confidence:** High

**Claim:** The formulas for these vectors are:
- Pressure (amplitude gain): $P = \sum_{i=1}^{n} G_i$
- Energy gain: $E = \sum_{i=1}^{n} (G_i G_i^*)$
- Velocity vector: $r_V \vec{r_V} = \frac{1}{P} \text{Re} \sum_{i=1}^{n} G_i \vec{u}_i$
- Energy vector: $r_E \vec{r_E} = \frac{1}{E} \sum_{i=1}^{n} (G_i G_i^*) \vec{u}_i$ [^116^]

where $G_i$ are the complex gains from source to the i-th loudspeaker and $\vec{u}_i$ is a unit vector in the direction of the loudspeaker.
**Source:** A Toolkit for the Design of Ambisonic Decoders
**URL:** http://lac.linuxaudio.org/2012/papers/18.pdf
**Date:** Unknown
**Excerpt:** "$r_V \vec{r_V} = \frac{1}{P} \text{Re} \sum_{i=1}^n G_i \vec{u}_i$ ... $r_E \vec{r_E} = \frac{1}{E} \sum_{i=1}^n (G_i G_i^*) \vec{u}_i$"
**Confidence:** High

### 5.6 maxrE and In-Phase Decoder Optimization

**Claim:** Decoder optimization strategies include:
- **Basic/Projection**: Standard decoding, no optimization
- **InPhase**: Optimizes phase across the full spectrum, eliminating secondary lobes while preserving energy criteria -- suitable for expanded listening zones
- **MaxRe (max rE)**: Optimizes energy concentration in the source direction, best for high frequencies where ILD dominates
- **Hybrid approaches**: Split the signal into two frequency bands (typically crossover at ~700 Hz), applying MaxRe to low frequencies and InPhase to high frequencies, or vice versa [^90^] [^94^] [^98^]
**Source:** SPAT Revolution / Mashav Ambisonic Decoder
**URL:** https://doc.flux.audio/spat-revolution/Spatialisation_Technology_Ambisonic_transcoding.html
**Date:** Unknown
**Excerpt:** "As phase optimization is more efficient in the low frequencies, and energy optimization is prominent in the high frequencies, this method takes this phenomenon to its advantage by splitting the signal into two frequency bands. The crossover frequency is by default set to 700 Hz."
**Confidence:** High

### 5.7 AllRAD (All-Round Ambisonic Decoding)

**Claim:** AllRAD is a hybrid approach that decodes HOA to a large number of virtual speakers on a uniform t-design sphere, then maps those virtual speakers to the real loudspeaker array using VBAP (Vector Base Amplitude Panning). This approach is particularly suitable for irregular or partial-coverage loudspeaker arrays. The implementation typically uses 240 virtual speaker directions. [^114^] [^75^] [^120^]
**Source:** Stanford CCRMA / LAC 2014 Paper / Daga 2022
**URL:** https://ccrma.stanford.edu/courses/222/resources/ambisonics_decoders.pdf
**Date:** 2025
**Excerpt:** "ALLRAD: use an ideal high density speaker array (240+ point t-design). Invert matrix, create decoder for ideal array. Result: big decoding matrix for virtual speakers. Tesselate real speaker array (plus virtual speaker). Calculate contribution of each virtual to each real triad using VBAP. Generate real speaker decoding matrix."
**Confidence:** High

---

## 6. The Ambisonic Channel Number (ACN) Ordering

### 6.1 ACN Formula

**Claim:** The Ambisonic Channel Number (ACN) ordering scheme assigns each spherical harmonic $Y_n^m$ to a channel index according to: $ACN(n,m) = n^2 + n + m$. When using 1-based indexing (as in some implementations), this becomes $n^2 + n + m + 1$. [^42^] [^44^] [^64^]
**Source:** AES 142nd Convention Paper (Normalization Schemes) / JSAmbisonics
**URL:** https://hal.science/hal-01527757v1/file/aes142_hoa_normalization-author.pdf
**Date:** 2017
**Excerpt:** "On the y-axis, the Ambisonic components are sorted according to the Ambisonic Channel Number (ACN) scheme where: $\forall(n,m) \in \mathbb{N}^2, ACN(n,m) = n^2 + n + m + 1$."
**Confidence:** High

### 6.2 ACN vs FuMa Channel Ordering

**Claim:** For first-order Ambisonics, ACN ordering corresponds to channels [W, Y, Z, X] (ACN indices 0,1,2,3), while FuMa ordering uses [W, X, Y, Z]. The conversion between them requires channel reordering. [^52^]
**Source:** SuperCollider HOA Tutorial
**URL:** https://depts.washington.edu/dxscdoc/Help/Tutorials/Exercise_02_HOA_converting_SN3D_N3D_FuMa.html
**Date:** Unknown
**Excerpt:** "|order|ACN channel #|FuMa as ACN channel #|FuMa name| 0|0|0|W| 1|1|2|Y| 1|2|3|Z| 1|3|1|X|"
**Confidence:** High

---

## 7. SN3D/N3D Normalization Conventions

### 7.1 N3D (Fully-Normalized / 4pi-Normalized)

**Claim:** The N3D normalization is defined as [^42^]:
$$N_n^{|m|, N3D} = \begin{cases} \sqrt{2n+1} & \text{if } m=0 \\ (-1)^m \sqrt{2(2n+1) \frac{(n-m)!}{(n+m)!}} & \text{if } m \neq 0 \end{cases}$$

N3D provides energy normalization -- when encoding an ideally diffuse sound field, all components exhibit the same RMS level. N3D is chosen in various Ambisonic standards but adoption has been limited. [^42^] [^44^]
**Source:** AES 142nd Convention Paper (Carpentier)
**URL:** https://hal.science/hal-01527757v1/file/aes142_hoa_normalization-author.pdf
**Date:** 2017
**Excerpt:** "The fully-normalized (or 4pi-normalized) scheme, noted N3D... N3D is the chosen normalization in various Ambisonic standards (e.g. [3, 4])."
**Confidence:** High

### 7.2 SN3D (Schmidt Semi-Normalized)

**Claim:** The SN3D normalization is defined as [^42^] [^64^]:
$$N_n^{|m|, SN3D} = \begin{cases} 1 & \text{if } m=0 \\ (-1)^m \sqrt{2 \frac{(n-m)!}{(n+m)!}} & \text{if } m \neq 0 \end{cases}$$

SN3D ensures that the peak amplitude of single point sources will never exceed the level of the 0th order component (W), making it easier to use when dealing with audio data as clipping of higher order signals can be avoided. SN3D in ACN ordering is the basis of the AmbiX format. [^42^] [^55^]
**Source:** AES 142nd Convention Paper / Blue Ripple Sound
**URL:** http://www.blueripplesound.com/notes/bformat
**Date:** Unknown
**Excerpt:** "SN3D in the ACN channel ordering convention is used in the AmbiX file format and is sometimes known as AmbiX... With SN3D, unlike N3D, no component will ever exceed the peak value of the 0th order component (W) for single point sources."
**Confidence:** High

### 7.3 Conversion Between N3D and SN3D

**Claim:** Conversion between N3D and SN3D is straightforward [^44^]:
$$x_{nm|SN3D} = x_{nm|N3D} / \sqrt{2n+1}$$
$$x_{nm|N3D} = \sqrt{2n+1} \cdot x_{nm|SN3D}$$
**Source:** JSAmbisonics Paper
**URL:** https://www.york.ac.uk/sadie-project/IASS2016/IASS_Papers/IASS_2016_paper_16.pdf
**Date:** Unknown
**Excerpt:** "Conversion between the two is trivial and given by: $x_{nm|SN3D} = x_{nm|N3D}/\sqrt{2n+1}$, $x_{nm|N3D} = \sqrt{2n+1} \cdot x_{nm|SN3D}$."
**Confidence:** High

### 7.4 Other Normalization Schemes

**Claim:** MaxN and FuMa guarantee amplitude normalization (harmonics remain in [-1, 1] range). MaxN and FuMa do not have straightforward closed-form expressions for higher orders, making them less suitable for arbitrary-order work compared to N3D/SN3D which have generic closed-form expressions and efficient recursion algorithms. [^42^]
**Source:** AES 142nd Convention Paper
**URL:** https://hal.science/hal-01527757v1/file/aes142_hoa_normalization-author.pdf
**Date:** 2017
**Excerpt:** "By definition, MaxN and FuMa guarantee amplitude normalization i.e. they ensure that the crest level of the harmonics remains in the range [-1; 1]... there is no straightforward formulation of MaxN and FuMa for higher orders."
**Confidence:** High

---

## 8. Limitations of HOA

### 8.1 Sweet Spot Size

**Claim:** The sweet spot (region of accurate reproduction) in HOA is frequency-dependent and order-dependent. A commonly cited rule of thumb gives the validity limit as $kr \leq N$, where $k = 2\pi f/c$ is the wavenumber, $r$ is the distance from center, and $N$ is the HOA order. Rearranging: $r \leq N \cdot c / (2\pi f) = N / k$. For $N = kr$, the relative truncation error is 4% (approximately -14 dB). [^152^] [^96^]
**Source:** Sound Field Synthesis for Psychoacoustic Research / IRCAM
**URL:** https://mediatum.ub.tum.de/doc/1723355/qb5di6jwkj34s8j6ofdq1vx4t.pdf
**Date:** Unknown
**Excerpt:** "The theoretical r=N/k sweet-spot size should be halved to give a realistic prediction of a measured sweet-spot. For instance, level errors below 2 dB can be achieved in a sweet-spot of 50 cm radius... by using HOA with the basic decoder for frequencies up to 2 kHz."
**Confidence:** High

**Claim:** At order 5, the sweet-spot radius is only 13 cm at 2 kHz. The equation $f_{max} \approx cN/(2\pi R)$ relates maximum frequency, HOA order N, and sweet-spot radius R, where c is the speed of sound. [^54^]
**Source:** Perceptual Evaluation of Adaptive Higher Order Ambisonics
**URL:** https://amu.hal.science/hal-04207740v1/document
**Date:** 2023-09-14
**Excerpt:** "According to this equation, at order 5 the radius of the sweet-spot is only 13cm at 2 kHz."
**Confidence:** High

### 8.2 Decode Quality for Irregular Arrays

**Claim:** HOA decoding with non-regular loudspeaker arrays is challenging. The decoding matrix is obtained by inversion of the matrix of ambisonic components, which becomes ill-conditioned for non-regular loudspeaker arrays, resulting in potentially poor sound quality. The same issue applies with regular arrays when the listener is off-centered, since the loudspeaker array seen by the listener then becomes non-regular. [^54^]
**Source:** HAL Archives - Perceptual Evaluation Paper
**URL:** https://amu.hal.science/hal-04207740v1/document
**Date:** 2023-09-14
**Excerpt:** "HOA decoding with non-regular loudspeaker arrays is challenging. Indeed, the decoding matrix is obtained by the inversion of the matrix of ambisonics components. This matrix is ill-conditioned for non-regular loudspeaker arrays and the resulting sound may be of poor quality."
**Confidence:** High

**Claim:** Advanced decoding techniques for non-regular arrays include: All-Round (AllRAD) decoding, Energy-Preserving decoding, and regularized pseudo-inverse (RMMAD). These approaches trade off various reproduction criteria to achieve more robust decoding across different array geometries. [^54^] [^75^]
**Source:** HAL Archives / LAC 2014
**URL:** https://amu.hal.science/hal-04207740v1/document
**Date:** 2023-09-14
**Excerpt:** "Two advanced decoding techniques particularly suitable for non-regular arrays were proposed: the All-Round [7] and the Energy-Preserving [8] decodings."
**Confidence:** High

### 8.3 Spatial Aliasing at High Frequencies

**Claim:** HOA performance degrades at high frequencies due to spatial aliasing. A practical approach is hybrid decoding: using HOA with the basic decoder at low frequencies (where wavefront reconstruction is accurate) and switching to methods like Nearest Loudspeaker Selection (NLS) or VBAP above a crossover frequency (e.g., 2 kHz). [^152^]
**Source:** Sound Field Synthesis for Psychoacoustic Research
**URL:** https://mediatum.ub.tum.de/doc/1723355/qb5di6jwkj34s8j6ofdq1vx4t.pdf
**Date:** Unknown
**Excerpt:** "Using HOA with the basic decoder up to 2 kHz and the NLS above 2 kHz seems like a good option to reduce level errors at high frequencies and remedy the shortcomings of Ambisonics at high frequencies, while providing a more accurate, direction-dependent sound field at low frequencies."
**Confidence:** High

### 8.4 HOA Compression Challenges

**Claim:** The primary barrier to widespread adoption of Ambisonics is that higher orders are required for high spatial resolution, but the number of audio channels scales quadratically with encoding order, making bandwidth prohibitive for streaming. Compression codecs (e.g., MPEG-H HOA spatial compression, Opus) have been explored. MPEG-H can reduce 4th-order HOA (25 channels) to as few as 6 transport signals plus metadata. [^113^] [^115^]
**Source:** arXiv / EBU Tech Review
**URL:** https://arxiv.org/pdf/2401.13401
**Date:** 2024-01-24
**Excerpt:** "The primary reason for the lack of widespread adoption of Ambisonics is that higher-orders are required to deliver a high spatial resolution... the number of audio channels scales quadratically with the encoding order, which means that the bandwidth required to transmit HOA scenes can be prohibitive."
**Confidence:** High

---

## 9. Comparison: HOA (Scene-Based) vs Atmos (Object-Based)

### 9.1 Fundamental Paradigm Differences

**Claim:** Spatial audio systems fall into three categories: Channel-Based Audio (CBA), Object-Based Audio (OBA), and Scene-Based Audio (SBA). HOA is the dominant scene-based approach, representing the entire soundfield using spherical harmonic coefficients. Dolby Atmos is the dominant object-based approach, representing audio as discrete sound sources with positional metadata. [^47^] [^48^] [^91^]
**Source:** arXiv Survey / Analogic Tips / AudioCube
**URL:** https://arxiv.org/html/2503.12948v1
**Date:** 2025-03-17
**Excerpt:** "Two broad classes of soundfield representation are object-based or on-line panning, commonly employed in game engines, Dolby Atmos and MPEG-H, in which soundfields are described as the superposition of sound source objects with corresponding spatial metadata, and scene-based, such as Ambisonics and Higher-Order Ambisonics (HOA), both special cases in the field of Fourier Acoustics in which soundfields are represented by approximating the physical behavior of acoustics over a region of interest."
**Confidence:** High

### 9.2 Technical Architecture Comparison

**Claim:** Dolby Atmos supports up to 128 independent channels: 10 bed channels (typically 7.1.2) plus up to 118 audio objects with 3D positional metadata. The renderer adapts object positions to the playback speaker configuration in real time. For home delivery, this is typically reduced to a maximum of 16 channels. [^142^] [^145^] [^148^]
**Source:** Analogic Tips / Dolby Support / Reddit
**URL:** https://professionalsupport.dolby.com/s/article/What-are-Beds-and-Objects-in-Dolby-Atmos
**Date:** 2025-07-15
**Excerpt:** "Typically, Dolby Atmos music mixes will use one Bed and up to 118 Objects."
**Confidence:** High

**Claim:** Scene-based audio (HOA) treats the audio environment as a sphere aimed at the center where the microphone/listener is located. The format is loudspeaker-independent -- the same HOA signal can be decoded to any speaker array or binaural headphones. HOA enables easy rotation of the entire soundfield (using Wigner D-matrices) and scene manipulation after recording. [^53^] [^91^]
**Source:** PCMag / AudioCube
**URL:** https://www.pcmag.com/encyclopedia/term/immersive-audio
**Date:** Unknown
**Excerpt:** "Higher Order Ambisonics (HOA) treats the audio environment as a sphere all aimed at the center where the microphone is located. Ambisonics has not yet been endorsed by major studios."
**Confidence:** High

### 9.3 Key Trade-offs

| Aspect | HOA (Scene-Based) | Dolby Atmos (Object-Based) |
|--------|-------------------|---------------------------|
| Representation | Spherical harmonic coefficients | Discrete objects + channel beds |
| Speaker dependency | Independent (decode to any layout) | Renderer adapts to layout |
| Post-processing | Easy rotation, zoom, manipulation | Fixed once rendered |
| Channel count | $(N+1)^2$ (quadratic with order) | Up to 128 total (118 objects + 10 beds) |
| Spatial resolution | Order-dependent, sweet spot limited | Object-dependent, panning resolution |
| VR/AR suitability | Excellent (natural head rotation) | Moderate (requires renderer) |
| Standardization | Open (AmbiX standard) | Proprietary (Dolby) |
| Compression | MPEG-H HOA spatial compression | Dolby Digital Plus / Dolby TrueHD / AC-4 |

**Claim:** Ambisonics is faithful to the real acoustic environment (captures the complete soundfield), while Atmos gives mixers control, flexibility, and creative freedom through object-based positioning. Many engineers work with both: capturing space with Ambisonics, then shaping and scaling it in Atmos. [^95^]
**Source:** OLLO Audio Blog
**URL:** https://olloaudio.com/blogs/ollo-blog/dolby-atmos-explained
**Date:** 2025-12-17
**Excerpt:** "Ambisonics is faithful to the real acoustic environment. Atmos gives mixers control, flexibility, and creative freedom. In many cases, engineers work with both -- capturing space with Ambisonics, then shaping and scaling it in Atmos."
**Confidence:** High

### 9.4 MPEG-H: The Hybrid Approach

**Claim:** MPEG-H 3D Audio is a standardized (ISO/IEC 23008-3) format that combines channel-based, object-based, and scene-based (HOA) audio in a single codec. It natively supports HOA coding and includes integrated binaural rendering. MPEG-H was chosen for broadcast standards in South Korea (UHD TV) and Brazil (TV 3.0) to avoid vendor lock-in. [^91^] [^79^]
**Source:** AudioCube / MPEG-H Whitepaper
**URL:** https://www.qualcomm.com/media/documents/files/scene-based-audio-for-mpeg-h-whitepaper.pdf
**Date:** Unknown
**Excerpt:** "Scene-based audio representation is a disruptive innovation that overcomes some of the biggest challenges in spatial audio coding... True 3D sound: The technology enables content creators to easily capture or create truly 3D sound scenes including proximity and depth components."
**Confidence:** High

---

## 10. The AmbiX Format and Standardization

### 10.1 AmbiX Specification

**Claim:** AmbiX is the de facto standard for HOA file exchange. It uses:
- Apple's Core Audio Format (.caf) as container
- ACN channel ordering
- SN3D normalization
- Scales to arbitrarily high orders
- No practical file size limitation (unlike .amb/WAV which has 4GB limit)

The basic format mandates a complete full-sphere signal set. The extended format includes an "adaptor matrix" for converting from other formats/channelings to standard AmbiX. [^61^] [^64^]
**Source:** Wikipedia / AmbiX Paper
**URL:** https://en.wikipedia.org/wiki/Ambisonic_data_exchange_formats
**Date:** 2013-12-19
**Excerpt:** "AmbiX adopts Apple's Core Audio Format or .caf. It scales to arbitrarily high orders and has no practically relevant limitation of file size. AmbiX files contain linear PCM data... It uses ACN channel ordering with SN3D normalisation."
**Confidence:** High

### 10.2 Historical Format Evolution

**Claim:** Prior to AmbiX, the dominant format was FuMa (Furse-Malham), an extension of classic B-format (WXYZ) up to 3rd order (16 channels), using MaxN normalization with a -3dB W correction. FuMa was limited to 3rd order, while ACN/SN3D (AmbiX) supports any order. [^52^] [^63^]
**Source:** SuperCollider / RWDobson AMB Format
**URL:** http://www.rwdobson.com/bformat.html
**Date:** 2012-10-26
**Excerpt:** "Encoding follows the Furse-Malham (FuMa) scheme. This reflects the original form of the B-Format specification, not least as associated with the Soundfield microphone."
**Confidence:** High

---

## 11. Mixed-Order Ambisonics (MOA)

**Claim:** Mixed-order Ambisonics assigns higher orders to the horizontal plane than to vertical directions, trading vertical resolution for improved horizontal performance. A #H#V configuration with horizontal order H and vertical order V uses $(H+1)^2 - (H-V)^2$ channels. For example, 3H2V uses 15 channels (vs. 16 for full 3rd order), omitting only the highest-order vertical zonal harmonic. [^70^] [^74^]
**Source:** Grokipedia / Travis (Ambisonics Symposium 2009)
**URL:** https://grokipedia.com/page/mixed_order_ambisonics
**Date:** 2026-01-08
**Excerpt:** "The total number of components follows the formula (H+1)^2 - (H - V)^2, bridging horizontal-only signals (V=0) and full periphonic signals (V=H)."
**Confidence:** High

---

## 12. HOA for Binaural and VR/AR Rendering

**Claim:** HOA signals can be rendered to headphones through binaural decoding: decode HOA to virtual loudspeaker signals, then convolve each with HRTFs corresponding to the virtual speaker directions. The formula is: $g_{left} = \sum_{l=1}^{L} g_l * HRIR_{left,l}$ and $g_{right} = \sum_{l=1}^{L} g_l * HRIR_{right,l}$. Using individualized HRTFs (e.g., from DNN-based prediction) significantly reduces front-back confusion rates compared to generic HRTFs. [^92^]
**Source:** CCRMA Stanford / AES Convention Paper
**URL:** https://ccrma.stanford.edu/~zhangmf/paper/AES2021.pdf
**Date:** Unknown
**Excerpt:** "The subjective experiments' results show that the front-back confusion rates of the individualized renderer are significantly lower than the generic renderer. Therefore, our paper effectively validates that the individualized binaural renderer performs better than generic binaural renderer after decoding the HOA signals to loudspeaker signals and then convolving loudspeaker signals with HRTFs."
**Confidence:** High

**Claim:** libspatialaudio is a modern open-source C++ library that provides rendering from spatial audio representations (HOA, Objects, Direct speakers) to target output layouts. It supports AmbiX conventions (ACN/SN3D) up to 3rd order (16 channels), uses AllRAD for decoding to irregular layouts, and supports binauralization with custom HRTF files in SOFA format. [^89^]
**Source:** VideoLAN/libspatialaudio
**URL:** https://jbkempf.com/blog/2025/libspatialaudio-0.4/
**Date:** 2025-12-21
**Excerpt:** "libspatialaudio provides the classic set of processors (Encoder, Rotator, Zoomer, Decoders), supporting up to 3rd order, i.e. 16 channels. The HOA signals use the AmbiX conventions (ACN channel ordering and SN3D normalization)."
**Confidence:** High

---

## Summary of Key Findings

Higher Order Ambisonics (HOA) provides a mathematically rigorous, scene-based approach to spatial audio that is fundamentally different from object-based systems like Dolby Atmos. At its core, HOA decomposes the entire soundfield around a reference point into spherical harmonic basis functions $Y_n^m(\theta, \phi)$, yielding a set of $(N+1)^2$ channel coefficients for order $N$ that completely characterize the acoustic scene independent of any playback system.

The mathematical foundation rests on the orthonormality of spherical harmonics on the sphere, which allows any function on the sphere (such as the directional response of a soundfield) to be decomposed into a weighted sum of these basis functions. Encoding a point source at direction $(\theta, \phi)$ simply involves computing $B_{nm} = s(t) \cdot Y_n^m(\theta, \phi)$, while decoding involves finding loudspeaker gains that best reconstruct these spherical harmonic components at the listening position.

Two key standardization developments have enabled HOA's modern resurgence: the Ambisonic Channel Number (ACN) ordering scheme ($ACN = n^2 + n + m$) and the SN3D normalization convention. Together these form the AmbiX format, which has been adopted by Google for VR, YouTube for 360 video, and the MPEG-H Audio standard for broadcast. AmbiX uses Apple's Core Audio Format (.caf) container and scales to arbitrarily high orders without the 4GB file size limitation of the older FuMa/.amb format.

The practical limitations of HOA center on the sweet spot problem. The region of accurate wavefront reconstruction is bounded by $kr \leq N$ (where $k = 2\pi f/c$), meaning that at order 5, the usable sweet spot is only about 13 cm at 2 kHz. This limits HOA's practical effectiveness for large listening areas at high frequencies. Various decoder optimization strategies -- maxrE for energy vector optimization, InPhase for phase coherence, hybrid frequency-dependent decoders, and the AllRAD approach for irregular arrays -- help mitigate but do not eliminate these constraints.

Compared to Dolby Atmos (object-based), HOA offers inherent advantages for certain applications: easy rotation of the entire soundfield (using Wigner D-matrices), natural capture of real acoustic environments via spherical microphone arrays, and speaker-independent representation. However, Atmos dominates commercial cinema and music distribution due to its precise per-object control, mature authoring tools, and extensive industry support. MPEG-H 3D Audio represents an important hybrid approach, supporting both HOA scene-based and object-based content within a single open standard, and has been adopted by several national broadcast standards.

For VR/AR applications, HOA remains particularly relevant because head-tracked binaural rendering from HOA is computationally efficient (rotate the soundfield once, then decode) and the format naturally captures full-sphere immersive content. The ongoing development of HOA compression techniques -- particularly the MPEG-H HOA spatial compression that can reduce 4th-order content from 25 to 6 transport channels -- addresses the primary barrier to adoption: the quadratic channel count growth with order.

---

## Gaps and Unresolved Questions

1. **Optimal decoder design for irregular arrays**: While AllRAD and regularized pseudo-inverse methods provide practical solutions, there is no universally accepted optimal approach for highly irregular consumer speaker layouts (e.g., soundbars with upward-firing drivers).

2. **HOA at very high orders**: Practical implementations above 5th order remain rare due to channel count (36+ channels) and computational demands. The perceptual benefits above 3rd order in typical listening rooms require further study.

3. **Distance coding in HOA**: Near-field compensation (NFC-HOA) can encode source distance, but practical implementations are limited and the perceptual effectiveness of distance rendering in HOA compared to object-based approaches is not fully characterized.

4. **Compression efficiency**: While MPEG-H provides HOA spatial compression, the performance gap between scene-based and object-based compression at very low bitrates remains an open question.

5. **Personalized binaural rendering**: The quality gap between individualized HRTFs and generic HRTFs for HOA binaural decoding is significant, but practical methods for HRTF individualization remain limited.

---

## Complete Reference List

[^12^] Mashav, "Higher-Order Ambisonic (HOA) Encoder -- User Guide," https://mashav.com/sha/praat/scripts/Higher-Order_Ambisonic_(HOA)_Encoder.html

[^36^] R. Wang et al., "Immersive audio, capture, transport, and rendering: a review," *APSIPA Transactions on Signal and Information Processing*, Cambridge University Press, 2026. https://www.cambridge.org/core/journals/apsipa-transactions-on-signal-and-information-processing/article/immersive-audio-capture-transport-and-rendering-a-review/A39094D58238A0F66750D48362D5FF17

[^37^] "Investigations on higher-order spherical harmonic input features for deep learning-based multiple speaker detection and localization," *Springer EURASIP Journal on Audio, Speech, and Music Processing*, 2025. https://link.springer.com/article/10.1186/s13636-025-00393-7

[^39^] "Ambisonics," Grokipedia. https://grokipedia.com/page/Ambisonics

[^40^] "Ambisonic Transcoding -- SPAT Revolution," Flux Audio Documentation. https://doc.flux.audio/spat-revolution/Spatialisation_Technology_Ambisonic_transcoding.html

[^41^] MathWorks, "ambisonicEncoderMatrix -- Generate matrix for ambisonics encoding," MATLAB Documentation. https://www.mathworks.com/help/audio/ref/ambisonicencodermatrix.html

[^42^] T. Carpentier, "Normalization schemes in Ambisonic: does it matter?" *142nd Convention of the Audio Engineering Society*, Berlin, 2017. https://hal.science/hal-01527757v1/file/aes142_hoa_normalization-author.pdf

[^44^] "JSAmbisonics: A Web Audio library for interactive spatial..." *Proceedings of ICSA 2016*. https://www.york.ac.uk/sadie-project/IASS2016/IASS_Papers/IASS_2016_paper_16.pdf

[^46^] J. Daniel, "Sound Spatialization by Higher Order Ambisonics," *Proceedings of the 2nd International Symposium on Ambisonics and Spherical Acoustics*. https://ambisonics10.ircam.fr/drupal/files/proceedings/keynotes/K4.pdf

[^47^] "Past, Present, and Future of Spatial Audio and Room Acoustics," *arXiv:2503.12948*, 2025. https://arxiv.org/html/2503.12948v1

[^48^] "What's the difference between object- and channel-based audio?" Analogic Tips, 2023. https://www.analogictips.com/whats-the-difference-between-object-and-channel-based-audio/

[^50^] "libambix: The ambix format," IEM Projects. https://iem-projects.github.io/ambix/apiref/format.html

[^52^] "HOA Tutorial Exercise 02 | SuperCollider 3.13.0 Help." https://depts.washington.edu/dxscdoc/Help/Tutorials/Exercise_02_HOA_converting_SN3D_N3D_FuMa.html

[^53^] "Definition of Immersive Audio," PCMag Encyclopedia. https://www.pcmag.com/encyclopedia/term/immersive-audio

[^54^] "Perceptual Evaluation of Adaptive Higher Order Ambisonics," *HAL Archives*, 2023. https://amu.hal.science/hal-04207740v1/document

[^55^] "HOA Technical Notes - SN3D B-Format," Blue Ripple Sound. http://www.blueripplesound.com/notes/bformat

[^56^] "Ambisonic Software," Ambisonic.info. https://ambisonic.info/practical/software.html

[^61^] "Ambisonic data exchange formats," Wikipedia. https://en.wikipedia.org/wiki/Ambisonic_data_exchange_formats

[^62^] "Ambisonics for Beginners," FH St. Polten. https://audiodesign.fhstp.ac.at/wp-content/uploads/2020/07/AmbisonicsTutorial_Beginners_200701.pdf

[^63^] R. Dobson, "AMB File Format." http://www.rwdobson.com/bformat.html

[^64^] C. Nachbar et al., "AMBIX -- A Suggested Ambisonics Format," *Ambisonics Symposium 2011*, Lexington, KY. https://ambisonics.iem.at/proceedings-of-the-ambisonics-symposium-2011/ambix-a-suggested-ambisonics-format

[^70^] "Mixed-order Ambisonics," Grokipedia. https://grokipedia.com/page/mixed_order_ambisonics

[^71^] "Comparison of 2D and 3D multichannel audio rendering methods for hearing research," *Acta Acustica*, 2024. https://acta-acustica.edpsciences.org/articles/aacus/full_html/2024/01/aacus230027/aacus230027.html

[^72^] "HoaMatrixDecoder | SuperCollider 3.13.0 Help." https://depts.washington.edu/dxscdoc/Help/Classes/HoaMatrixDecoder.html

[^74^] C. Travis, "A New Mixed-Order Scheme for Ambisonic Signals," *Ambisonics Symposium 2009*. https://ambisonics.iem.at/symposium2009/proceedings/ambisym09-travis-newmixedorder.pdf

[^75^] "The Ambisonic Decoder Toolbox: Extensions for Partial-Coverage Loudspeaker Arrays," *LAC 2014*. http://lac.linuxaudio.org/2014/papers/17.pdf

[^78^] Qualcomm, "Scene-Based Audio for MPEG-H Whitepaper." https://www.qualcomm.com/media/documents/files/scene-based-audio-for-mpeg-h-whitepaper.pdf

[^79^] "The New Standard for Universal Spatial / 3D Audio Coding." https://picture.iczhiku.com/resource/paper/SYIWpoAyYAWjqCnV.pdf

[^80^] MathWorks, "Ambisonic Plugin Generation." https://www.mathworks.com/help/audio/ug/ambisonic-plugin-generation.html

[^88^] "Array-Aware Ambisonics and HRTF Encoding for Binaural Reproduction With Wearable Arrays," *arXiv:2507.11091*, 2025. https://arxiv.org/html/2507.11091v2

[^89^] J-B. Kempf, "libspatialaudio 0.4: a modern spatial audio library," VideoLAN, 2025. https://jbkempf.com/blog/2025/libspatialaudio-0.4/

[^90^] "Ambisonic Transcoding -- SPAT Revolution," Flux Audio. https://doc.flux.audio/spat-revolution/Spatialisation_Technology_Ambisonic_transcoding.html

[^91^] "R3 -- Spatial Audio Formats: A Technical Deep Dive," AudioCube, 2025. https://www.audiocube.app/blog/r3-spatial-audio-formats

[^92^] M. Zhang et al., "Individualized HRTF-based Binaural Renderer for HOA," *AES Convention Paper*, CCRMA Stanford. https://ccrma.stanford.edu/~zhangmf/paper/AES2021.pdf

[^93^] "Rendering virtual source at various distances using Near-Field Compensated Higher Order Ambisonics," *ICA 2019*. https://pub.dega-akustik.de/ICA2019/data/articles/000014.pdf

[^94^] S. Cohen, "Ambisonic Decoder -- User Guide," Mashav. https://mashav.com/sha/praat/scripts/Ambisonic_Decoder.html

[^95^] "Dolby Atmos for Music Producers: What You Need to Know," OLLO Audio, 2025. https://olloaudio.com/blogs/ollo-blog/dolby-atmos-explained

[^96^] J. Daniel, "Spatial Sound Encoding Including Near Field Effect," *Proceedings of the 2nd International Symposium on Ambisonics and Spherical Acoustics*. https://ambisonics10.ircam.fr/drupal/files/proceedings/keynotes/K4.pdf

[^97^] "ASAudio: A Survey of Advanced Spatial Audio Research," *arXiv:2508.10924*, 2025. https://arxiv.org/html/2508.10924v2

[^98^] "Evaluation of ambisonics decoding methods," *EAA Joint Symposium on Auralization and Ambisonics*, Berlin, 2014. https://d-nb.info/1153065304/34

[^113^] "HO-DirAC Parametric Spatial Audio Compression," *arXiv:2401.13401*, 2024. https://arxiv.org/pdf/2401.13401

[^114^] F. Lopez-Lezcano, "Ambisonics Decoders," *Stanford CCRMA Music 222 course materials*, 2025. https://ccrma.stanford.edu/courses/222/resources/ambisonics_decoders.pdf

[^115^] EBU, "Scene-Based Audio and Higher Order Ambisonics Technology Overview," *EBU Tech Review*, 2019. https://tech.ebu.ch/docs/techreview/trev_2019-Q4_SBA_HOA_Technology_Overview.pdf

[^116^] "A Toolkit for the Design of Ambisonic Decoders," *LAC 2012*. http://lac.linuxaudio.org/2012/papers/18.pdf

[^117^] P. Moore and J. Wakefield, "Off-centre Optimisation of Ambisonic Decoders," *AES 128th Convention*, 2010. https://core.ac.uk/download/pdf/53526.pdf

[^120^] "All-Round Ambisonic Decoding: Spread and Correlation," *DAGA 2022*. https://pub.dega-akustik.de/DAGA_2022/data/articles/000344.pdf

[^142^] "What's the difference between object- and channel-based audio?" Analogic Tips. https://www.analogictips.com/whats-the-difference-between-object-and-channel-based-audio/

[^145^] "What are Beds and Objects in Dolby Atmos," Dolby Professional Support. https://professionalsupport.dolby.com/s/article/What-are-Beds-and-Objects-in-Dolby-Atmos

[^148^] Reddit r/hometheater discussion on Atmos channel counts. https://www.reddit.com/r/hometheater/comments/ev7q4o/dolby_atmos_blurays_are_technically_a_scam_11/

[^149^] "Spatial Audio Perception," *arXiv:2510.10883*. https://arxiv.org/pdf/2510.10883

[^150^] "Spherical Harmonics in Quantum Mechanics," Binghamton University. https://bingweb.binghamton.edu/~suzuki/QuantumMechanicsII/4-9_Spherical_harmonics.pdf

[^151^] "Spherical Harmonics," LibreTexts Physics. https://phys.libretexts.org/Bookshelves/Quantum_Mechanics/Introductory_Quantum_Mechanics_(Fitzpatrick)/07%3A_Orbital_Angular_Momentum/7.06%3A_Spherical_Harmonics

[^152^] "Sound field synthesis for psychoacoustic research," TU Munich. https://mediatum.ub.tum.de/doc/1723355/qb5di6jwkj34s8j6ofdq1vx4t.pdf

[^153^] "Spherical Harmonic," Wolfram MathWorld. https://mathworld.wolfram.com/SphericalHarmonic.html

---

*Research compiled from 17 independent web searches across academic papers, technical documentation, standards documents, and authoritative web sources.*
