## 2. The Atmos Bed: Channel-Based Foundation

### 2.1 Bed Architecture and Channel Specification

Every Dolby Atmos presentation rests on a channel-based substrate called the *bed* — a fixed-layout, multichannel submix that occupies Renderer inputs 1 through 10 in the standard home entertainment configuration. The Renderer accepts a maximum of 128 simultaneous inputs, of which the bed consumes 10 channels (7.8% of the channel budget), leaving 118 for audio objects [^230^][^101^]. The bed is not an optional legacy layer; it is a mandatory component providing the only deterministic pathway for LFE (Low-Frequency Effects) routing and the primary vehicle for ambient and music content [^56^][^5^].

#### 2.1.1 The 7.1.2 Bed Structure and SMPTE Channel Ordering

The canonical home entertainment bed format is **7.1.2**: seven ear-level full-range channels, one LFE channel, and two overhead channels. In SMPTE (Society of Motion Picture and Television Engineers) order, the ten channels are: **L, R, C, LFE, Ls, Rs, Lsr, Rsr, Lts, Rts** — Left, Right, Center, Low-Frequency Effects, Left Side Surround, Right Side Surround, Left Surround Rear, Right Surround Rear, Left Top Surround, and Right Top Surround [^227^][^5^]. This ordering is mandatory when assigning bed audio to the Renderer; deviation causes incorrect channel-to-speaker mapping that misroutes, for instance, rear surround content to overhead speakers [^228^]. Multiple nomenclature conventions coexist — SMPTE ST 428-12 defines an alternative labeling scheme [^92^][^156^], while home theater documentation often uses Ltf/Rtf/Ltr/Rtr for 7.1.4 playback layouts — but the Renderer itself expects the Dolby convention: LFE fourth, height channels last [^47^].

#### 2.1.2 Angular Positions per ITU-R BS.775-3

Speaker placement corresponding to bed channels follows ITU-R BS.775-3 (Recommendation ITU-R BS.775-3, August 2012), the international standard for multichannel stereophonic sound systems [^229^][^56^]. Front L and R speakers sit at $\pm30$ degrees azimuth, forming a 60-degree arc. The center channel is at 0 degrees. Side surrounds (Ls, Rs) occupy the 90–110 degree sector, and rear surrounds (Lsr, Rsr) are placed at 135–150 degrees [^51^][^53^]. The two height channels, Lts and Rts, are oriented toward the listening position at a **45-degree vertical elevation angle**, adjustable between 30 and 55 degrees depending on room constraints [^163^][^191^]. This angle provides consistent overhead coverage across a broad listening area. The LFE channel carries no directional metadata; it is a non-positional, band-limited channel (nominal 120 Hz cutoff) routed directly to the subwoofer output.

#### 2.1.3 The 9.1 Cinema Bed Variant

Cinema Atmos installations use a **9.1 bed** that adds **Lw** (Left Wide) and **Rw** (Right Wide) channels between the front L/R speakers (30 degrees) and side surrounds (90–110 degrees). The ideal wide position is approximately **45 degrees** from center, with $\pm5$ degrees tolerance [^123^]. The 9.1 roster totals 12 channels: L, C, R, Lw, Rw, Ls, Rs, Lsr, Rsr, LFE, Lts, Rts. The home entertainment Renderer is limited to 7.1.2 beds, so cinema 9.1 content requires the wide channels to fold into adjacent speakers or render via static objects at wide speaker positions [^47^][^155^]. These wide channels fill the angular gap between front and side speakers, enabling smoother front-to-side pans for sounds traversing the frontal arc.

### 2.2 The Role of Beds in the Hybrid Paradigm

Dolby Atmos is fundamentally a **hybrid** system combining channel-based beds with object-based audio in a single presentation [^6^][^56^]. The bed serves technical and creative functions that objects cannot replicate.

#### 2.2.1 Why Beds Persist

Beds provide spatial stability for content that benefits from fixed speaker anchoring: environmental ambience (room tone, crowd backgrounds), music stems, center-channel dialogue, and 3D reverb returns are conventionally bed-routed [^230^][^56^]. Diffuse ambient material does not require per-sample positional metadata, and treating it as bed audio eliminates the computational and bandwidth overhead of object metadata streaming [^105^][^106^]. In theatrical environments, bed channels activate entire speaker arrays — all side surround speakers receive the Ls signal simultaneously — producing an enveloping, diffuse quality that single-speaker object rendering cannot match [^155^][^194^]. Beds also allow mixers to use familiar surround panning interfaces rather than positioning every element as an individual object [^5^][^155^].

#### 2.2.2 The LFE Routing Constraint

A critical architectural limitation is that **audio objects cannot feed the LFE channel**; only bed channels provide a signal path to the subwoofer [^38^]. Content requiring low-frequency extension — explosions, rumbles, sub-bass musical elements — must be routed through a bed LFE channel, or embedded within an object's full-range signal for post-render bass management. The distinction matters: bed LFE routing is direct and deterministic, while bass management is a frequency-dependent, device-variable process.

#### 2.2.3 Channel-Based Rendering Path

Bed channels follow a fundamentally different rendering path than objects. Where objects are rendered in real-time using Vector Base Amplitude Panning (VBAP) — selecting the nearest 2–3 speakers and computing gain factors such that the vector sum matches the target direction [^223^][^7^] — bed channels map directly to their correspondingly named physical speakers. The L bed channel goes to the Left speaker; the Ls channel goes to the Left Side Surround. If the playback system has fewer speakers than the bed provides, fixed downmix coefficients are applied [^5^]. This direct mapping guarantees predictable playback but also means bed channels cannot be individually repositioned in 3D space — only the bed as a whole can be panned [^56^][^105^]. The restriction to two height channels further constrains overhead content to lateral panning only; front-to-back height movement is impossible within the bed, a limitation known as the "7.1.2 dilemma" [^29^].

### 2.3 Bed Rendering to Arbitrary Configurations

#### 2.3.1 Direct Render Mode

In direct render mode, bed channels map one-to-one to physical speaker counterparts. A 7.1.2 bed on a 7.1.4 system routes L to Left, R to Right, C to Center, and so on; the two additional overhead speakers in 7.1.4 receive no direct bed signal and are reserved for object rendering [^129^]. When rendering to 7.1 (no height speakers), the Lts and Rts content folds to ear-level speakers via the downmix matrix selected by the mixer.

#### 2.3.2 Downmix Coefficients for Missing Speakers

For **Lo/Ro stereo fold-down**, the Renderer applies [^5^]:

$$Lo = L + (-3\ \text{dB} \times C) + (-3\ \text{dB} \times Ls)$$
$$Ro = R + (-3\ \text{dB} \times C) + (-3\ \text{dB} \times Rs)$$

The center channel is attenuated by 3 dB and distributed equally to both outputs, creating a phantom center. Surrounds fold to their respective fronts at $-3$ dB, and LFE is discarded. This compensates for the 6 dB level increase that would otherwise occur when correlated signals are summed. For 7.1-to-5.1 downmix, the standard mode sums side and rear surrounds at unity gain ($Ls_{\text{out}} = Lss + Lrs$), while the Pro Logic IIx mode applies weighted blending with cross-feed attenuation to preserve matrix decodability [^5^][^221^].

#### 2.3.3 Bed Channel Mapping Across Configurations

| Bed Channel | 2.0 Stereo | 5.1 Surround | 7.1 Surround | 7.1.4 Home | Theatrical (64-ch) |
|:---|:---|:---|:---|:---|:---|
| L (1) | Lo mix | L speaker | L speaker | L speaker | Left screen array |
| R (2) | Ro mix | R speaker | R speaker | R speaker | Right screen array |
| C (3) | Lo/Ro at $-3$ dB | C speaker | C speaker | C speaker | Center screen array |
| LFE (4) | Discarded | LFE/sub | LFE/sub | LFE/sub | Subwoofer array |
| Ls (5) | Lo at $-3$ dB | Ls speaker | Ls speaker | Ls speaker | Left side array |
| Rs (6) | Ro at $-3$ dB | Rs speaker | Rs speaker | Rs speaker | Right side array |
| Lsr (7) | Lo at $-3$ dB | Mixed to Ls (0 dB) | Lsr speaker | Lsr speaker | Left rear array |
| Rsr (8) | Ro at $-3$ dB | Mixed to Rs (0 dB) | Rsr speaker | Rsr speaker | Right rear array |
| Lts (9) | Lo fold-down | Front L mix | Front L mix | Lts overhead | Left overhead array |
| Rts (10) | Ro fold-down | Front R mix | Front R mix | Rts overhead | Right overhead array |

The table reveals the Renderer's fold-down logic across the configuration spectrum. At the stereo extreme, all spatial differentiation collapses into two channels: the center becomes a phantom image, surrounds fold to fronts, height content redistributes to front L/R, and LFE is lost. In 5.1, rear surrounds sum with side surrounds (5.1 has no dedicated rear speaker), while height channels fold to front L/R. The 7.1 layout achieves full ear-level coverage but still lacks height speakers, so Lts and Rts continue to fold downward. Only at 7.1.4 do the bed's two overhead channels find dedicated physical speakers; the remaining two overhead positions are available exclusively for object content.

In theatrical configurations, the mapping changes qualitatively: each bed channel feeds a *speaker array* rather than a single driver — the Ls channel activates all left side surround speakers simultaneously [^155^][^194^]. This array-activation behavior is a key reason beds persist in cinema workflows: a single object would activate only one speaker, lacking the enveloping quality of a full side-array signal.

During spatial coding for home delivery, bed channels not reserved in an output bed configuration are converted to **static objects** at predefined canonical positions [^5^]. These static objects cluster with dynamic objects into 12–16 elements for DD+ JOC (Dolby Digital Plus Joint Object Coding) delivery [^103^][^24^]. Even content authored as beds ultimately traverses the object rendering pipeline — a design choice that underscores the hybrid nature of the Atmos architecture and preserves the creative intent encoded in the bed's channel relationships across all playback configurations.
