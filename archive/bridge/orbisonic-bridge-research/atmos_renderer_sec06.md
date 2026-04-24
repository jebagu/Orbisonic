## 6. Binaural Rendering and Headphone Playback

The preceding chapter examined how Atmos renderers map object-based content to physical loudspeaker arrays. This chapter addresses the alternative reproduction path: headphone delivery, where the renderer must synthesize the acoustic cues of a full speaker array within a two-channel stereo signal. The techniques differ markedly across delivery platforms, creating one of the most consequential compatibility divides in the spatial audio ecosystem.

### 6.1 Binaural Synthesis Architecture

#### 6.1.1 HRTF Convolution: Filtering Each Object for Left and Right Ears

Binaural reproduction through headphones relies on Head-Related Transfer Functions (HRTFs) to encode the acoustic filtering imposed by the listener's head, torso, and pinnae. Each HRTF represents the frequency-domain transfer function from a free-field point source to the eardrum; its time-domain counterpart, the Head-Related Impulse Response (HRIR), is typically 256–1024 samples at 48 kHz [^27^]. For a source at coordinates $(\theta, \phi)$, a pair of HRTFs $H_L(f, \theta, \phi)$ and $H_R(f, \theta, \phi)$ defines left- and right-ear filtering [^185^]. The HRTF encodes three spatial cue classes: Interaural Time Differences (ITDs) below ~1.5 kHz (maximum ~660 microseconds for an adult head), Interaural Level Differences (ILDs) above ~1.5 kHz from head shadowing, and spectral cues (pinna notches between 5–12 kHz) that enable elevation and front-back disambiguation [^189^], [^27^]. The standard binaural renderer convolves each audio object with HRIRs selected from a measurement database (stored in AES69-2015 SOFA format [^156^]) and sums all outputs to produce stereo. Real-time implementations use overlap-add or overlap-save fast convolution.

#### 6.1.2 Dolby's Approach: Approximately 85% Amplitude Panning + 15% HRTF Convolution

Independent reverse-engineering research by Grathwohl (January 2026) revealed a striking finding: Dolby Atmos binaural rendering consists of approximately **85% amplitude panning and only ~15% HRTF convolution** [^27^]. Two independent ADM-BWF renderers (a JavaScript prototype and a Rust/Steam Audio implementation) were systematically compared against Dolby's official binaural output. Full HRTF processing produced consistent 10–15 dB spectral dips at 6.5 kHz and 9–10 kHz; a blend of 0.15 reproduced Dolby's output to within ~1 dB RMS across all tested material [^27^]:

$$\text{output} = 0.85 \cdot \text{panning}(o) + 0.15 \cdot \text{HRTF}(o)$$

The panning algorithm is Dolby's patented Center of Mass Amplitude Panning (CMAP), which solves a quadratic optimization to find speaker gains $g$ that minimize a cost function combining directional alignment and proximity penalties [^27^]. This limited HRTF blend is an intentional tradeoff: full per-object convolution of 20–30 simultaneous objects causes cumulative pinna notches that darken the mix. At 15% blend, HRTF personalization yields at most $6\ \text{dB} \times 0.15 = 0.9\ \text{dB}$ improvement — below the ~1 dB just-noticeable difference — explaining Dolby's July 2025 discontinuation of consumer HRTF personalization [^27^]. Critically, bed channels render via amplitude panning regardless of HRTF settings; only objects receive HRTF spatialization [^27^].

#### 6.1.3 Apple's Approach: Full Personalized HRTF with Real-Time Head Tracking

Apple's Spatial Audio uses a fundamentally different architecture. Apple Music delivers a DD+ JOC bitstream to the device, where Apple's on-device renderer performs binaural processing [^11^], [^82^], [^68^]. Head tracking creates the impression of a fixed external sound field: AirPods Pro/Max transmit IMU sensor data, and the renderer updates the sound field approximately 100 times per second with ~17 ms end-to-end latency [^127^]. iOS 16 added Personalized Spatial Audio, using the iPhone's TrueDepth camera to photogrammetrically capture head and ear geometry, processed entirely on-device [^133^]. This targets full HRTF personalization — in contrast to Dolby's discontinued system, which captured up to 50,000 surface points yet delivered sub-JND improvement due to the 15% blend [^105^].

### 6.2 Binaural Render Modes

#### 6.2.1 Near/Mid/Far Distance Modes and Per-Object Metadata

The Dolby Atmos Renderer embeds per-object metadata assigning each source one of four distance settings [^8^], [^26^], [^28^]. Mixers set these through the Dolby Atmos Binaural Settings plug-in (AAX, AU, VST3) [^30^], [^31^]:

| Mode | Perceived Distance | Technical Behavior |
|------|-------------------|-------------------|
| **Off** | No distance modeling | Object centered, no spatialization; universal use fails QC |
| **Near** | ~20 cm from head | Short reverb, dry signal, high direct-to-reverb ratio; RT < 100 ms [^102^] |
| **Mid** | ~2 meters | Moderate room reverb; RT 150–250 ms [^102^] |
| **Far** | ~6 meters | Long reverb tail, greater delay, more air absorption; RT > 300 ms [^102^] |

The setting is **not automatable** and remains fixed throughout the session; the LFE channel is always Off [^8^].

#### 6.2.2 Perceptual Basis: Reverb Control Rather Than HRTF Intensity

Recent research suggests Near/Mid/Far modes **do not control HRTF processing intensity** but instead control room reverb presets, because the global HRTF blend remains fixed at ~15% regardless of mode settings [^27^]. Near mode applies a shorter reverb tail simulating close proximity; Far mode applies a longer tail with greater arrival delay and air absorption modeled as $e^{-k(d - d_{\text{ref}})}$ with $k \approx 0.05\ \text{m}^{-1}$ [^27^], [^28^]. Each mode additionally modifies the direct-to-reverberant energy ratio and early reflection patterns to replicate how sounds are physically perceived at different distances in an acoustic space [^28^].

### 6.3 Speaker Virtualization

#### 6.3.1 Virtualizing 7.1.4 Through Stereo Soundbars: HRTF Plus Crosstalk Cancellation

Dolby provides technical guidance for sound bar manufacturers, supporting configurations from 2.0.2 to full 7.1.4 arrays [^67^], [^85^], [^155^]. The virtualization pipeline combines HRTF-based binaural synthesis with crosstalk cancellation to decouple left and right channels at the listener's ears. The Dolby Surround Virtualizer uses HRTFs plus crosstalk cancellation so listeners perceive sound from virtual surround speakers rather than the physical sound bar [^67^], [^85^].

#### 6.3.2 Crosstalk Cancellation: 20–30 dB at Optimal Frequencies

Practical crosstalk cancellation achieves **20–30 dB of cancellation** at optimal frequencies at the design sweet spot [^72^]. Performance degrades rapidly with listener movement, particularly lateral shifts that disrupt the precise phase relationships required for channel separation. When the listener's HRTF differs from the calibration HRTF used to design the cancellation filters, average cancellation degrades to approximately 17 dB — enough to preserve some spatial impression but insufficient for precise virtual source placement [^72^].

#### 6.3.3 Height Virtualization: Simulating Overhead From Ear-Level Speakers

For sound bars without upward-firing drivers, Dolby Atmos Height Virtualization applies height-cue filters to overhead audio components before mixing them into listener-level speakers [^155^], [^157^]. These filters simulate the natural spectral cues the pinna imparts to elevated sounds — primarily a characteristic high-frequency shaping distinct from ear-level arrivals. Dolby supports height virtualization across 2 to 7 listener-level channels to create the sensation of either 2 or 4 overhead speakers. The Dolby Surround upmixer operates in the frequency domain, processing perceptually-spaced bands for fine-grained virtual source steering [^67^], [^85^].

### 6.4 Codec Delivery Paths

#### 6.4.1 AC-4 IMS (Tidal/Amazon): Preserves Binaural Metadata, Static Output

Dolby AC-4 (ETSI TS 103 190) provides Immersive Stereo (IMS), a binaural rendering mode encoding immersive audio as two channels plus spatial control data [^84^], [^75^], [^187^]. IMS achieves near-transparent quality at 256 kbps with 3–4× lower playback complexity than full object-based decoding [^84^]. **AC-4 IMS preserves Near/Mid/Far binaural render mode metadata** set by mixers [^77^], [^69^]. AC-4 Level 4 additionally supports head tracking [^76^].

#### 6.4.2 DD+ JOC (Apple Music): Full Head Tracking, Discards Binaural Metadata

Apple Music uses DD+ JOC, in which spatial coding reduces 128 channels to 12 or 16 elements, encoded at 384–768 kbps [^24^], [^104^], [^168^]. The Apple device decodes and renders binaural output using Apple's engine [^68^], [^11^]. The critical consequence: **Apple's pipeline discards binaural render mode metadata** (Near/Mid/Far) [^69^]. Apple's renderer makes its own spatial interpretation, so engineers cannot control the headphone presentation. No Apple Spatial Audio emulation exists during mixing; engineers must export an MP4, transfer to an iPhone, and audition through AirPods for every revision [^69^].

#### 6.4.3 Binaural Rendering Approaches Across Delivery Platforms

<table>
<thead style="background-color:#f0f0f0">
<tr><th>Parameter</th><th>Dolby Renderer (Studio/AC-4 IMS)</th><th>Apple Spatial Audio (DD+ JOC)</th><th>Speaker Virtualization (Sound Bars)</th></tr>
</thead>
<tbody>
<tr><td><b>Binaural method</b></td><td>~15% HRTF + 85% CMAP panning [^27^]</td><td>Full HRTF with personalized profile [^133^]</td><td>HRTF synthesis + crosstalk cancellation [^67^]</td></tr>
<tr><td><b>Head tracking</b></td><td>Not supported (static)</td><td>~100 Hz update rate [^127^]</td><td>Not supported</td></tr>
<tr><td><b>Personalized HRTF</b></td><td>Discontinued (July 2025) [^105^]</td><td>TrueDepth camera scan [^133^]</td><td>Generic only</td></tr>
<tr><td><b>Binaural metadata</b></td><td><b>Preserved</b> [^77^]</td><td><b>Discarded</b> [^69^]</td><td>N/A</td></tr>
<tr><td><b>Bed rendering</b></td><td>Amplitude panning to stereo [^27^]</td><td>Virtual speaker downmix [^82^]</td><td>Physical/virtual hybrid</td></tr>
<tr><td><b>Codec/bitrate</b></td><td>AC-4 IMS (64–256 kbps) [^84^]</td><td>DD+ JOC (384–768 kbps) [^104^]</td><td>DD+ JOC or AC-4</td></tr>
<tr><td><b>Mixer control</b></td><td>Yes (metadata respected)</td><td>No (renderer overrides)</td><td>Limited</td></tr>
<tr><td><b>Representative services</b></td><td>Tidal, Amazon Music</td><td>Apple Music</td><td>Netflix via Atmos sound bars</td></tr>
</tbody>
</table>

The divergence between these paths creates a fundamental compatibility challenge. The Dolby renderer preserves binaural metadata but offers no head tracking and uses a minimal HRTF blend that approaches a sophisticated stereo panner. Apple Spatial Audio delivers the most technically advanced headphone experience — full personalized HRTF with real-time head tracking — but discards the mixer's distance settings, making the headphone presentation unpredictable from the studio. Speaker virtualization occupies a middle ground using HRTF synthesis plus crosstalk cancellation, though its 20–30 dB cancellation performance is highly position-dependent [^72^]. Industry sources report that "the Apple Spatial and Dolby Binaural renderers sound very different," making cross-platform mix translation a persistent challenge [^82^], [^69^]. The Apple renderer tends to emphasize reverb tails and ambient elements compared to the Dolby renderer's drier presentation [^74^]. For engineers, practical headphone monitoring must span multiple renderers to achieve acceptable translation across the delivery ecosystem.
