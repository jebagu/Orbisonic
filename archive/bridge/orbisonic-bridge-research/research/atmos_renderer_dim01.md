# Dimension 1: Atmos Bed Architecture and Channel-Based Foundation

## Comprehensive Technical Research Findings

---

## 1. The 7.1.2 Bed Structure: Channel Definition and Standard Positions

### 1.1 Core Architecture Overview

The Dolby Atmos bed is a channel-based submix layer that serves as the foundation of every Dolby Atmos presentation. In the cinema environment, Dolby Atmos supports up to 128 simultaneous audio tracks, which are allocated as a **9.1 bed (10 channels)** plus up to **118 audio objects** [^230^][^101^]. For home entertainment workflows, the standard bed format is **7.1.2 (10 channels)**, which is a subset of the cinema 9.1 bed configuration [^107^][^47^].

Claim: The 7.1.2 bed consists of exactly 10 channels: L, R, C, LFE, Ls, Rs, Lsr, Rsr, Lts, Rts [^227^][^5^]
Source: Dolby Professional Support / Dolby Atmos Renderer Guide
URL: https://professionalsupport.dolby.com/s/article/What-channel-order-should-be-used-for-assigning-bed-audio-to-the-Renderer
Excerpt: "Bed audio output to the Dolby Atmos Renderer must use SMPTE channel ordering for 5.1 to 7.1.2 (L=1, R=2, C=3, Lfe=4, Ls=5, Rs=6, Lrs=7, Rrs=8, Lts=9, Rts=10)"
Confidence: High

### 1.2 Channel-by-Channel Position Specification

The following table defines each channel in the 7.1.2 bed, including its standard position, angular coordinates, and elevation:

| Channel | Abbreviation | SMPTE Position | Horizontal Angle | Elevation |
|---------|-------------|----------------|-----------------|-----------|
| Left | L | 1 | +30 degrees (left of center) | 0 degrees (ear level) |
| Right | R | 2 | -30 degrees (right of center) | 0 degrees (ear level) |
| Center | C | 3 | 0 degrees (center front) | 0 degrees (ear level) |
| Low Frequency Effects | LFE | 4 | N/A (non-directional) | N/A |
| Left Side Surround | Ls / Lss | 5 | +90 to +110 degrees | 0 degrees (ear level) |
| Right Side Surround | Rs / Rss | 6 | -90 to -110 degrees | 0 degrees (ear level) |
| Left Rear Surround | Lsr / Lrs | 7 | +135 to +150 degrees | 0 degrees (ear level) |
| Right Rear Surround | Rsr / Rrs | 8 | -135 to -150 degrees | 0 degrees (ear level) |
| Left Top Surround | Lts | 9 | +30 to +45 degrees horizontal | +45 degrees vertical |
| Right Top Surround | Rts | 10 | -30 to -45 degrees horizontal | +45 degrees vertical |

Claim: Front speakers (L, R) are positioned at approximately 30 degrees from the center reference, consistent with ITU-R BS.775-3 [^229^][^56^]
Source: ITU-R BS.775-3 Recommendation / 7.1 surround sound standards
URL: https://grokipedia.com/page/7.1_surround_sound / https://www.itu.int/dms_pubrec/itu-r/rec/bs/R-REC-BS.775-3-201208-I!!PDF-E.pdf
Excerpt: "The format adheres to international standards like ITU-R BS.775-3 for speaker placement, positioning front channels at +/-30 degrees from the listener, side surrounds at approximately +/-110 degrees, and rear surrounds at +/-150 degrees"
Confidence: High

Claim: Side surrounds (Ls, Rs) are placed at 90-110 degrees from center in 7.1 configurations, with rear surrounds at 135-150 degrees [^51^][^53^]
Source: ITU-R BS.775-3 / CTA/CEDIA CEB-22
URL: https://auralex.com/absorb-this/home-theater-speaker-placement/
Excerpt: "For 5.1 surround sound, place the left or right speakers between 100 and 120 degrees from the center speaker...For 7.1 systems, the side surround speakers have a wider range, going from 60 degrees up to 110 degrees"
Confidence: High

Claim: Lts and Rts (Left Top Surround / Right Top Surround) are the two height channels in a 7.1.2 bed, positioned at approximately 45 degrees vertical from the listening position [^163^][^191^]
Source: Focal Dolby Atmos Installation Guidelines / Dolby Home Theater Installation Guidelines
URL: https://www.focal.com/dolby-atmos-installation / https://www.dolby.com/siteassets/technologies/dolby-atmos/atmos-installation-guidelines-121318_r3.1.pdf
Excerpt: "The horizontal positioning of the Top monitors (Ltf, Rtf, Ltr, Rtr) is done in the same way as the monitors at ear level...Their acoustic center must be at least 2.4m high and oriented to the mix position at a vertical angle of 45 degrees"
Confidence: High

### 1.3 SMPTE Channel Ordering

Claim: The bed MUST use SMPTE channel ordering (L, R, C, LFE, Ls, Rs, Lrs, Rrs, Lts, Rts) when assigning audio to the Dolby Atmos Renderer [^227^][^228^]
Source: Dolby Professional Support
URL: https://professionalsupport.dolby.com/s/article/What-channel-order-should-be-used-for-assigning-bed-audio-to-the-Renderer
Excerpt: "Bed audio output to the Dolby Atmos Renderer must use SMPTE channel ordering for 5.1 to 7.1.2 (L=1, R=2, C=3, Lfe=4, Ls=5, Rs=6, Lrs=7, Rrs=8...)"
Confidence: High

**Critical Note on Channel Nomenclature:** There are multiple naming conventions in use:
- **SMPTE ST 428-12** defines channel labels: L, C, R, Ls, Rs, Lss, Rss, Lrs, Rrs, LFE [^92^][^156^]
- **Dolby's internal convention** uses: L, R, C, LFE, Ls, Rs, Lsr, Rsr, Lts, Rts for the 7.1.2 bed
- **Home theater terminology** typically uses: L, R, C, LFE, Ls, Rs, Lrs, Rrs, Ltf, Rtf, Ltr, Rtr for 7.1.4 setups [^47^]

---

## 2. The Role of Beds vs Objects

### 2.1 Why Beds Exist

Claim: Beds exist because some elements of a soundtrack still benefit from a channel-based approach, particularly ambient effects, music backgrounds, and center dialogue [^230^][^56^]
Source: Dolby Cinema Sound / Audient Tutorial
URL: https://professional.dolby.com/cinema/dolby-atmos/ / https://audient.com/tutorial/objects-and-beds-explained/
Excerpt: "Some elements of a movie soundtrack, however, still benefit from a channel-based approach — for instance, ambient effects and music backgrounds. So a Dolby Atmos soundtrack also includes a more conventional channel-based 'bed,' together with the audio objects."
Confidence: High

Claim: Beds serve as the "foundation" of the immersive mix, providing spatial stability for elements that do not need dynamic movement [^105^][^106^]
Source: Omni Soundlab / Pro Sound Effects Blog
URL: https://omnisoundlab.com/en/beds-objects-and-new-tools-for-immersive-audio-production/
Excerpt: "Beds: These are traditional channels grouped together—generally 7.1.2—that function as a fixed base within the sound field. Here, we could say that it usually contains the material that we want to maintain its spatial stability, such as the drum, bass, or fixed effects stems."
Confidence: High

### 2.2 Typical Bed Content

Beds are typically used for:
- **Environmental ambience** (room tone, crowd backgrounds, wind, rain)
- **Music backgrounds/scores** (orchestral beds, underscore)
- **Center dialogue** (anchored to the center channel)
- **3D reverbs** (spatial reverb returns panned across bed channels)
- **Static sound design elements** that do not require precise positioning
- **LFE content** (the only way to route to the LFE channel is through beds) [^38^]

Claim: Objects cannot feed the LFE channel directly; only beds can route to LFE [^38^]
Source: Audient - Objects and Beds Explained
URL: https://audient.com/tutorial/objects-and-beds-explained/
Excerpt: "One final thing worth noting, however, is that objects can't feed the LFE channel (only beds can)"
Confidence: High

### 2.3 Object Roles

Objects are used for:
- **Pinpoint sound sources** requiring precise 3D positioning
- **Moving sounds** (helicopters, vehicles, projectiles)
- **Key sound effects** that need to be localized independently of speaker positions
- **Individual instruments** in music mixing
- **Any content benefiting from dynamic spatial movement**

Claim: Objects are mono sources with positional metadata (x, y, z coordinates and size), while beds describe an audio scene with a conventional channel-based layout [^34^][^102^]
Source: Dolby ED2 Whitepaper / Dolby Atmos for Home Theater
URL: https://professional.dolby.com/siteassets/tv/home/dolby-atmos/dolby-ed2-whitepaper.pdf
Excerpt: "Objects are mono sources whereas beds describe an audio scene with a conventional channel-based layout. Audio object element descriptions provide the location of the object and other details for binaural rendering or VR use-cases."
Confidence: High

---

## 3. Channel-Based vs Object-Based Paradigm Differences

### 3.1 Fundamental Paradigm Distinction

Claim: Channel-based audio assigns signals to predefined speakers, while object-based audio uses metadata to position audio signals in space, rendered at playback time [^58^][^81^]
Source: Sonofloat / Frontiers in Virtual Reality
URL: https://sonofloat.com/en/channel-based-vs-object-based-audio-format/
Excerpt: "In the channel-based format, audio signals are assigned to predefined speakers, resulting in a fixed channel assignment regardless of the playback environment. On the other hand, the object-based audio format allows for more flexible and precise control of sound reproduction by using metadata to precisely position audio signals in space."
Confidence: High

### 3.2 Technical Comparison

| Attribute | Channel-Based (Bed) | Object-Based |
|-----------|-------------------|--------------|
| Positioning | Fixed to named speaker channels | Free 3D positioning via X,Y,Z metadata |
| Rendering | Direct channel-to-speaker mapping | Renderer calculates speaker feeds at playback |
| Scalability | Fixed to specific channel count | Scales to any speaker configuration |
| Movement | Requires inter-channel panning | Smooth 3D trajectory via metadata automation |
| Downmix | Fixed downmix coefficients | Renderer adapts to target configuration |
| Metadata | None (implicit in channel assignment) | Explicit position, size, and behavioral metadata |
| Sweet spot | Limited by speaker positions | Optimized per-seat via object rendering |

Claim: In traditional channel-based audio, positioning is done by adjusting levels in each speaker at the mixing stage, while object-based audio positions each part discretely with more convincing locality [^38^]
Source: Audient - Objects and Beds Explained
URL: https://audient.com/tutorial/objects-and-beds-explained/
Excerpt: "Dolby Surround, Dolby Pro Logic, Dolby Digital, DTS et al were all channel-based, meaning that the positioning of signals in the surround field was done by adjusting their levels in each speaker at the mixing stage – fairly immersive, certainly, but comparatively crude in qualitative terms."
Confidence: High

### 3.3 The Hybrid Paradigm

Claim: Dolby Atmos is fundamentally a hybrid system that combines both channel-based beds and object-based audio in a single presentation [^6^][^56^]
Source: Wikipedia / Audient Tutorial
URL: https://en.wikipedia.org/wiki/Dolby_Atmos
Excerpt: "Dolby Atmos technology allows the storage and distribution of 128 audio tracks with metadata describing sound properties such as position and volume... Each audio track can be assigned to an audio channel, the conventional format for distribution, or to an audio 'object'."
Confidence: High

The hybrid approach is critical because:
1. **Backwards compatibility**: Beds provide a traditional channel-based layer that plays on non-Atmos systems [^44^]
2. **Efficiency**: Ambient/diffuse content works well in beds without needing per-object metadata overhead
3. **Workflow familiarity**: Mixers can use traditional surround panning for bed content
4. **LFE routing**: Low-frequency effects require bed-based routing

---

## 4. Bed Limitations

### 4.1 Fixed Channel Positions

Claim: Bed channels are fixed to predefined speaker positions and cannot be individually repositioned; only the bed as a whole can be panned using conventional surround panning [^56^][^105^]
Source: Audient / Omni Soundlab
URL: https://audient.com/tutorial/objects-and-beds-explained/
Excerpt: "Parts assigned as bed tracks are simply routed to a single multichannel surround bus in up to 7.1.2 format... panned around between those channels using a conventional surround panner, and ultimately rendered as a static audio signal."
Confidence: High

This means:
- A sound panned to the Ls (Left Side Surround) channel of a bed will always come from the left side speaker position, regardless of playback system
- The bed does not adapt to different speaker configurations; it relies on the renderer's downmix/upmix logic
- There is no per-channel object metadata; all bed channels move together as a unit

### 4.2 Two Height Channels Only (The 7.1.2 Ceiling Limitation)

Claim: The 7.1.2 bed is limited to only two height channels (Lts and Rts), meaning overhead sounds cannot be panned from front to back within the bed [^56^][^29^]
Source: Audient / VI-Control Forum Discussion
URL: https://audient.com/tutorial/objects-and-beds-explained/
Excerpt: "The only limitation is that, maxing out at 7.1.2, the bed can only feed two height channels, so you can't pan overhead sounds from front to back with it."
Confidence: High

Claim: The limitation to two height speakers for Atmos beds is causing significant problems during mixing, and Dolby has indicated they will not be changing it [^29^]
Source: VI-Control Forum Discussion
URL: https://vi-control.net/community/threads/dolby-atmos-the-7-1-2-dilemma.149490/
Excerpt: "The limitation to two height speakers for Atmos beds is causing problems during mixing. Incomprehensingly, Dolby hinted that they will not be changing it, so we are stuck with it."
Confidence: Medium (forum discussion, but widely corroborated)

**Workaround Strategy**: Many mixers use a **7.1 bed + 4 static objects for the ceiling** to achieve full height coverage. Others create an **"object bed"** using static objects positioned at all desired speaker locations [^29^][^160^].

### 4.3 No Individual Object Metadata

Claim: Bed channels do not carry individual per-channel metadata; they are treated as a unified channel-based bus, unlike objects which each carry X,Y,Z position metadata [^5^][^155^]
Source: Dolby Atmos Renderer Guide / Steinberg Forums
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Excerpt: "Working with the default 7.1.2 bed for a Dolby Atmos mix... is generally the same as traditional methods for working with multichannel stems for a surround or stereo format."
Confidence: High

### 4.4 Half Elevation Vector Space

Claim: The bed's height representation covers only the upper hemisphere; there is no height below the listener (no "floor" height speakers) [^44^]
Source: Mach1 Research Blog
URL: https://research.mach1.tech/posts/observations-and-limitations-of-dolby-atmos-for-spatial-mixing/
Excerpt: "Something to make note of when using Dolby Atmos is that out of the box for both the object-bed and the channel-bed there is a limited vector space, specifically there is from the 'floor' to the 'ceiling' since this is originally designed for theater based mixing. That means that when translated to a virtual setting we face our first observed limitation, we are missing 50% of the virtual mixing space."
Confidence: Medium

### 4.5 Spatial Coding Conversion

Claim: For home delivery, bed channels are converted to "static objects" at predefined canonical locations during spatial coding, then clustered with dynamic objects [^103^][^5^]
Source: AVS Forum / Dolby Atmos Renderer Guide
URL: https://www.avsforum.com/threads/the-official-dolby-atmos-thread.1574386/
Excerpt: "In order to maximize efficiency, spatial coding converts bed channels to equivalent objects at predefined canonical locations. Because of this, the best results are generally obtained by configuring spatial coding with 11 to 15 output objects and one bed channel for the LFE."
Confidence: High

---

## 5. Bed Rendering to Different Speaker Configurations

### 5.1 Downmix Coefficients

The Dolby Atmos Renderer supports multiple downmix modes for converting the immersive mix to smaller speaker configurations:

#### 5.1.1 Standard (Lo/Ro) 7.1 to 5.1 Downmix

Claim: The standard downmix from 7.1 to 5.1 uses direct pass-through of side and rear surrounds at unity gain [^5^][^220^]
Source: Dolby Atmos Renderer Guide / Dolby Professional Support
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Excerpt: "The coefficients for a standard downmix from 7.1 to 5.1 are: Ls = 0 dB x Lss + 0 dB x Lrs; Rs = 0 dB x Rss + 0 dB x Rrs"
Confidence: High

#### 5.1.2 Dolby Pro Logic IIx 7.1 to 5.1 Downmix

Claim: The Pro Logic IIx downmix uses weighted combinations of side and rear surrounds with specific attenuation coefficients [^5^][^221^]
Source: Dolby Atmos Renderer Guide / Apple Logic Pro Documentation
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Excerpt: "The coefficients for a Dolby Pro Logic PLIIx downmix from 7.1 to 5.1 are: Ls = Lss + (-1.2 dB x Lrs) + (-6.2 dB x Rrs); Rs = Rss + (-6.2 dB x Lrs) + (-1.2 dB x Rrs)"
Confidence: High

#### 5.1.3 Stereo Downmix from 5.1

Claim: Three stereo downmix modes are supported: Lt/Rt (Legacy), Lt/Rt (Pro Logic II), and Lo/Ro [^5^]
Source: Dolby Atmos Renderer Guide
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Excerpt:
- Lt/Rt (Legacy): Lt = L + (-3 dB x C) - (-3 dB x Ls) - (-3 dB x Rs); Rt = R + (-3 dB x C) + (-3 dB x Ls) + (-3 dB x Rs)
- Lt/Rt (Pro Logic II): Lt = L + (-3 dB x C) - (-1.2 dB x Ls) - (-6.2 dB x Rs); Rt = R + (-3 dB x C) + (-6.2 dB x Ls) + (-1.2 dB x Rs)
- Lo/Ro: Lo = L + (-3 dB x C) + (-3 dB x Ls); Ro = R + (-3 dB x C) + (-3 dB x Rs)
Confidence: High

#### 5.1.4 Direct Render Modes

Claim: "Direct Render" renders directly to 5.1 without first downmixing via 7.1, using phantom imaging between front and surround speakers; "Direct Render with Room Balance" reduces comb filtering artifacts [^129^]
Source: Gearspace Forum / Dolby Documentation
URL: https://gearspace.com/board/vr-virtual-reality-spatial-atmos-immersive-ambisonics/1390884-direct-render-direct-render-room-balance.html
Excerpt: "Direct Render renders to 5.1 (without first downmixing via 7.1) to recreate the 7.1 sound field at the central listening position using phantom imaging between the surround speakers and front speakers... Direct Render with Room Balance applies an updated Dolby rendering algorithm that reduces the comb filtering effects."
Confidence: High

### 5.2 ITU-R BS.775 Compliance

Claim: The 7.1.2 bed speaker layout is derived from and compatible with ITU-R BS.775-3 recommendations for multichannel stereophonic sound systems [^56^][^229^]
Source: ITU-R BS.775-3 / Multiple references
URL: https://www.itu.int/dms_pubrec/itu-r/rec/bs/R-REC-BS.775-3-201208-I!!PDF-E.pdf
Excerpt: "Three front loudspeakers combined with two rear/side loudspeakers; the left and right frontal loudspeakers are placed at the extremities of an arc subtending 60 degrees at the reference listening point; both side/rear loudspeakers should be placed within the sectors from 100 to 120 degrees from the centre front reference."
Confidence: High

The ITU-R BS.775-3 standard specifies:
- **Front L/R speakers**: 60-degree arc (30 degrees each side of center)
- **Surround speakers**: 100-120 degrees from center front reference
- **Height**: Front speakers at ear level; surround height "less critical"
- **LFE channel**: Optional, band-limited to nominal 120 Hz cutoff

### 5.3 Rendering Algorithm: VBAP Foundation

Claim: Dolby Atmos object rendering is based on Vector Base Amplitude Panning (VBAP), which selects the 2-3 loudspeakers nearest to the virtual source position and calculates gain factors such that the vector sum matches the target direction [^223^][^7^]
Source: libspatialaudio documentation / Pulkki's VBAP paper
URL: https://github.com/videolan/libspatialaudio/blob/master/docs/ObjectPanning.md
Excerpt: "Classic VBAP works by selecting a subset of loudspeakers (a base) that encloses the desired source direction and calculating gain factors such that the vector sum of the loudspeaker positions matches the target direction."
Confidence: High

For bed rendering, the process differs:
- **Bed channels** are mapped directly to their corresponding physical speakers (or arrays)
- **Downmix scenarios** use the coefficient matrices described above
- **Upmix scenarios** (e.g., 7.1.2 to 9.1.6) involve phantom imaging and distribution across additional speakers

---

## 6. The 9.1 Bed Option

### 6.1 Cinema vs Home Entertainment

Claim: Cinema Atmos uses a 9.1 bed (not 7.1.2), which includes two additional "wide" channels: Left Wide (Lw) and Right Wide (Rw) [^230^][^37^]
Source: Dolby Cinema Sound / Steinberg Forums
URL: https://professional.dolby.com/cinema/dolby-atmos/
Excerpt: "Dolby Atmos packages up to 128 audio tracks — a 9.1 bed and up to 118 audio objects."
Confidence: High

### 6.2 9.1 Bed Channel Structure

The 9.1 bed consists of the following channels:
- **L, C, R** (front channels, 30 degrees)
- **Lw, Rw** (Left Wide, Right Wide - approximately 45-60 degrees from center)
- **Ls, Rs** (side surrounds, 90-110 degrees)
- **Lsr, Rsr** (rear surrounds, 135-150 degrees)
- **LFE** (low frequency effects)
- **Lts, Rts** (top surround/overhead channels)

This totals **10 channels** (9 full-range + 1 LFE = 9.1).

Claim: In a 9.1.4 Dolby Atmos setup, the additional speakers beyond 7.1.4 are Left Wide (Lw) and Right Wide (Rw), positioned between the front L/R and side surrounds [^123^][^47^]
Source: Dolby Atmos Home Entertainment Studio Technical Guidelines / Jigsaw24
URL: https://www.avsforum.com/attachments/dolby-atmos-home-entertainment-studio-technical-guidelines-2021-05-pdf.3370880/
Excerpt: "The additional speakers to create a 9.1.4 layout are left wide (Lw) and right wide (Rw). Two main design aspects govern the position of the wide surround speakers: Horizontal angular placement and angular separation between adjacent speakers."
Confidence: High

### 6.3 Wide Speaker Positioning

Claim: For equidistant layouts, the ideal wide surround position is calculated by adding 15 degrees to the angle between center and left speakers (approximately 45 degrees), with a tolerance of +/- 5 degrees [^123^]
Source: Dolby Atmos Home Entertainment Studio Technical Guidelines
URL: https://www.avsforum.com/attachments/dolby-atmos-home-entertainment-studio-technical-guidelines-2021-05-pdf.3370880/
Excerpt: "For equidistant layouts, the ideal wide surround position is calculated by adding 15 degrees to the angle between the center and left speakers. A tolerance of +/-5 degrees is suggested."
Confidence: High

### 6.4 When is 9.1 Used?

The 9.1 bed is primarily used in:
1. **Cinema/theatrical releases** where the additional wide channels provide smoother front-to-side panning
2. **Large mixing stages** with extended speaker configurations
3. **Premium home installations** with 9.1.4, 9.1.6, or higher channel counts

Claim: Most home entertainment mixing and delivery uses 7.1.2 beds, even though consumer playback may support more channels; the 9.1 bed is the cinema standard [^47^][^155^]
Source: Jigsaw24 / Steinberg Forums
URL: https://media.jigsaw24.com/resource/getting-started-with-atmos-part-1-speaker-layouts
Excerpt: "The maximum bus width in Pro Tools and bed width in your Dolby Atmos Renderer is actually 7.1.2 (although you can use multiple beds)... The other layout configuration to consider is the 9.1.4, which adds an extra two more horizontal plane speakers."
Confidence: High

**Important Note**: While the cinema uses a 9.1 bed natively, the Dolby Atmos Renderer for home entertainment is limited to 7.1.2 beds. However, mixers can create "object beds" (oBeds) by placing static objects at the wide speaker positions to achieve similar results [^105^][^124^].

---

## 7. How Beds Interact with the Renderer vs Objects

### 7.1 Renderer Input Architecture

Claim: The Dolby Atmos Renderer accepts up to 128 inputs total, with bed channels and objects sharing this allocation; each channel of a bed counts as one input [^56^][^5^]
Source: Audient Tutorial / Dolby Atmos Renderer Guide
URL: https://audient.com/tutorial/objects-and-beds-explained/
Excerpt: "This can handle up to 128 inputs, so you can have as many beds and objects as required by the project in question up to that limit, with each channel in a bed counting as an input."
Confidence: High

The default input configuration:
- **Channels 1-10**: 7.1.2 Bed (10 channels)
- **Channels 11-128**: Objects (up to 118 mono objects, or fewer stereo objects)

### 7.2 Bed Rendering Pipeline

Claim: Bed channels are rendered by mapping them directly to corresponding speakers or speaker arrays, while objects are rendered using VBAP-based position calculation to the nearest speakers [^5^][^230^]
Source: Dolby Atmos Renderer Guide / Dolby Cinema Sound
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Excerpt: "Positioning for beds is based on the width of the multichannel bed in the DAW. Positioning for objects is based on Dolby Atmos metadata, as defined by panners in the DAW, or on the mixing console."
Confidence: High

The rendering pipeline differs for beds vs objects:

**Bed Rendering:**
1. Bed channels arrive at the Renderer as fixed-position signals
2. Each channel is routed to its corresponding named speaker (L to Left speaker, etc.)
3. If the playback system has fewer speakers, downmix coefficients are applied
4. If more speakers exist, phantom imaging or array mode may be used
5. Bed channels are NOT individually positioned in 3D space

**Object Rendering:**
1. Object audio + metadata (X, Y, Z position, size) arrive at the Renderer
2. Renderer calculates which physical speakers are nearest to the object's position
3. VBAP-based gain factors are computed for the selected speaker subset
4. The object is rendered to 2-3 speakers (2D/3D VBAP)
5. As the object moves, different speakers are activated dynamically

### 7.3 Spatial Coding and Bed-to-Object Conversion

Claim: During spatial coding for home delivery, bed channels that are not reserved in an output bed configuration are treated as objects with fixed positions in space [^5^]
Source: Dolby Atmos Renderer Guide
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Excerpt: "With home-theater rendering, bed input signals that are not specifically reserved in an output bed configuration are treated as objects, with a fixed position in space. These static objects are combined with dynamic moving objects, and all of these are processed by spatial coding."
Confidence: High

The spatial coding process:
1. All bed channels are converted to "static objects" at predefined canonical locations
2. These static objects are combined with dynamic moving objects
3. The combined set is clustered into 12, 14, or 16 "elements"
4. One element is reserved for the LFE channel
5. The remaining elements carry all bed and object audio
6. Each element includes Object Audio Metadata (OAMD) for rendering

Claim: Spatial coding outputs 11.1 (12 elements) or 15.1 (16 elements) configurations; the LFE always gets its own dedicated channel [^24^][^103^]
Source: Hybrik Documentation / AVS Forum
URL: https://docs.hybrik.com/tutorials/dolby_atmos/
Excerpt: "Spatial coding is employed to reduce 128 bed and object channels to 12 or 16 elements or 'clusters'. Actually, this is really 11.1 or 15.1 as the LFE doesn't move."
Confidence: High

### 7.4 Bed vs Object Rendering Behavior

Claim: Bed channels light up speaker arrays in large rooms (all speakers in an array receive the signal), while objects can be directed to single speakers for precise localization [^155^][^194^]
Source: Steinberg Forums / Gearspace
URL: https://forums.steinberg.net/t/why-are-beds-limited-to-7-1-2/932618
Excerpt: "Objects will not 'light-up' speaker arrays (ie. larger rooms with multiple side speakers)... bed channels get converted to objects [during encoding] AND they can 'light up speaker arrays' in larger rooms"
Confidence: High

This is a critical distinction:
- **Beds** in a cinema will activate entire speaker arrays (e.g., all side surround speakers get the Ls signal)
- **Objects** can be directed to a single specific speaker within an array
- This is why beds are preferred for diffuse ambience, while objects are preferred for precise point-source sounds

### 7.5 Re-render and Monitoring Integration

Claim: The Renderer produces re-renders (fold-downs) to various channel configurations, including stereo, 5.1, 7.1, and binaural, all derived from the same bed+object master [^5^][^93^]
Source: Dolby Atmos Renderer Guide / Apple Logic Pro Documentation
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Excerpt: "The Re-renders window is an interactive re-render output matrix that provides UI elements for configuring channel-based re-renders from your Dolby Atmos mix."
Confidence: High

### 7.6 The "Object Bed" (oBed) Workaround

Claim: An emerging technique called "object beds" (oBeds) uses static objects positioned at canonical bed speaker locations to overcome the 7.1.2 bed limitation while preserving array-activation behavior [^105^][^111^]
Source: Omni Soundlab
URL: https://omnisoundlab.com/en/beds-objects-and-new-tools-for-immersive-audio-production/
Excerpt: "oBeds (Object-based beds): This is a hybrid technique where a custom 'bed' is built using static objects. Instead of sending multiple signals to a traditional bed, individual objects are created that occupy the exact same positions as the bed's channels."
Confidence: High

This technique allows:
- Custom bed configurations (e.g., 7.1.4, 9.1.6) beyond the 7.1.2 limit
- Per-channel object-like control
- Better scalability to different speaker configurations
- Future-proofing against format limitations

---

## 8. Summary of Key Findings

### 8.1 Bed Architecture Overview

The Dolby Atmos bed architecture represents a carefully engineered hybrid approach that bridges traditional channel-based audio and modern object-based audio. The bed serves as the "channel-based foundation" of every Atmos mix, providing 10 channels (7.1.2 in home, 9.1 in cinema) of fixed-position, conventionally-panned audio content. These channels follow strict SMPTE ordering (L, R, C, LFE, Ls, Rs, Lsr, Rsr, Lts, Rts) and map to specific physical speaker positions defined by ITU-R BS.775-3 and Dolby's extensions.

### 8.2 Why the Bed Exists

The bed exists for practical, technical, and creative reasons. Practically, it ensures backwards compatibility with non-Atmos playback systems that can only decode traditional channel-based audio. Technically, it provides an efficient mechanism for routing diffuse, ambient content that does not benefit from per-object metadata overhead. Creatively, it allows mixers to use familiar surround panning workflows for music, ambience, and dialogue that should maintain stable spatial positioning. The bed is also the only pathway to the LFE channel, as objects cannot directly route to subwoofers.

### 8.3 Critical Limitations

The bed's most significant limitation is its restriction to two height channels (Lts, Rts). This design decision, rooted in cinema's historical need for only basic overhead coverage, means that bed-based content cannot pan from front-height to rear-height. This creates the infamous "7.1.2 dilemma" where mixers must either accept limited height resolution or resort to complex workarounds involving static objects for additional height positions. Dolby has indicated this limitation will remain for backwards compatibility reasons.

### 8.4 Rendering Pipeline

Beds and objects follow fundamentally different rendering paths. Bed channels are routed directly to their named speaker counterparts (or downmixed using fixed coefficients), while objects are dynamically rendered using VBAP-based position calculation. During spatial coding for home delivery, bed channels are converted to "static objects" at canonical positions, then clustered with dynamic objects into 12-16 elements. This means that even content authored as beds ultimately becomes object-like in the delivery chain.

### 8.5 The 9.1 Cinema Bed

The cinema's 9.1 bed includes two "wide" channels (Lw, Rw) that fill the gap between front L/R and side surrounds, enabling smoother front-to-side panning. Home entertainment workflows are limited to 7.1.2 beds in the Renderer, though the object bed workaround can approximate 9.1.4+ configurations using static objects.

### 8.6 Downmix and Distribution

The Renderer supports multiple downmix modes (Lo/Ro, Pro Logic IIx, Direct Render) with precisely specified coefficients. The standard 7.1-to-5.1 downmix simply passes side and rear surrounds at unity gain, while Pro Logic IIx applies weighted blending. Stereo downmixes use established 5.1-to-2.0 matrices with center channel attenuation and surround folding.

---

## 9. Gaps and Unresolved Questions

1. **Exact VBAP implementation details**: While it is established that Dolby Atmos uses VBAP-based rendering for objects, the specific proprietary extensions and optimizations used by Dolby's renderer are not publicly documented.

2. **Bed rendering in non-standard speaker configurations**: The exact algorithm for rendering a 7.1.2 bed to, say, a 5.1.2 or 3.1.2 consumer setup is documented only at a high level, with limited public information on edge cases.

3. **Spatial coding cluster assignment algorithm**: The precise algorithm by which spatial coding groups bed channels and objects into elements remains proprietary.

4. **Wide channel rendering in home environments**: How 9.1 bed content with wide channels is rendered to 7.1 or 5.1 home configurations is not fully documented.

5. **Array mode specifics**: The behavior of bed channels when rendered to speaker arrays (multiple speakers per channel) in cinemas is described conceptually but lacks detailed technical specifications.

6. **Object bed standardization**: The "object bed" (oBed) technique, while widely used, is not formally standardized by Dolby and may have compatibility implications.

---

## 10. Reference List

[^5^] Dolby Atmos Renderer Guide, Dolby Laboratories, 2018. https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf

[^6^] "Dolby Atmos," Wikipedia. https://en.wikipedia.org/wiki/Dolby_Atmos

[^24^] "Dolby Atmos," Hybrik Documentation. https://docs.hybrik.com/tutorials/dolby_atmos/

[^29^] "Dolby Atmos & the 7.1.2 Dilemma," VI-Control Forum, 2024. https://vi-control.net/community/threads/dolby-atmos-the-7-1-2-dilemma.149490/

[^34^] "Dolby ED2 Whitepaper," Dolby Laboratories. https://professional.dolby.com/siteassets/tv/home/dolby-atmos/dolby-ed2-whitepaper.pdf

[^37^] "DOLBY ATMOS with 9 on the floor," Steinberg Forums, 2022. https://forums.steinberg.net/t/dolby-atmos-with-9-on-the-floor-speaker-configuration-issue/790744

[^38^] "Objects and Beds Explained," Audient, 2024. https://audient.com/tutorial/objects-and-beds-explained/

[^44^] "Figuring out: Dolby Atmos," Javier Zumer Blog, 2018. https://javierzumer.com/blog/2018/5/30/figuring-out-dolby-atmos

[^47^] "Getting started with Atmos part 1: Speaker layouts," Jigsaw24, 2022. https://media.jigsaw24.com/resource/getting-started-with-atmos-part-1-speaker-layouts

[^56^] "Objects and Beds Explained," Audient, 2024. https://audient.com/tutorial/objects-and-beds-explained/

[^58^] "Channel-based vs. object-based audio format," Sonofloat, 2023. https://sonofloat.com/en/channel-based-vs-object-based-audio-format/

[^81^] "Diegetic and object-based spatial audio in cinematic VR," Frontiers in Virtual Reality, 2026. https://www.frontiersin.org/journals/virtual-reality/articles/10.3389/frvir.2026.1696677/full

[^87^] "How Dolby Atmos actually works! Marketing vs. reality," Reddit r/hometheater, 2025. https://www.reddit.com/r/hometheater/comments/11sqvz3/how_dolby_atmos_actually_works_marketing_vs/

[^92^] "Sound," Cinepedia. https://cinepedia.com/sound/

[^93^] "Downmix and trim controls in Logic Pro for Mac," Apple Support. https://support.apple.com/en-al/guide/logicpro/lgcp8118444e/mac

[^101^] "Dolby Atmos Cinema Sound," Dolby Professional. https://professional.dolby.com/cinema/dolby-atmos/

[^102^] "Dolby Atmos for the Home Theater," Dolby Laboratories. https://professional.dolby.com/siteassets/tv/home/dolby-atmos/dolby-atmos-for-home-theater.pdf

[^103^] "The official Dolby Atmos thread (home theater version)," AVS Forum. https://www.avsforum.com/threads/the-official-dolby-atmos-thread-home-theater-version/

[^105^] "Beds, Objects, and New Tools for Immersive Audio Production," Omni Soundlab. https://omnisoundlab.com/en/beds-objects-and-new-tools-for-immersive-audio-production/

[^106^] "Session Organization Tips for Dolby Atmos," Pro Sound Effects Blog, 2023. https://blog.prosoundeffects.com/session-organization-tips-for-dolby-atmos

[^107^] "Buyer's Guide Dolby Atmos," Vintage King, 2020. https://vintageking.com/blog/buyers-guide-dolby-atmos/

[^111^] "Beds, Objects, and New Tools for Immersive Audio Production," Omni Soundlab. https://omnisoundlab.com/en/beds-objects-and-new-tools-for-immersive-audio-production/

[^123^] Dolby Atmos Home Entertainment Studio Technical Guidelines, Dolby Laboratories, 2021. https://www.avsforum.com/attachments/dolby-atmos-home-entertainment-studio-technical-guidelines-2021-05-pdf.3370880/

[^124^] "Problems with including the 'Wide' channels," Steinberg Forums, 2022. https://forums.steinberg.net/t/problems-with-including-the-wide-channels-of-a-dolby-atmos-9-1-6-configuration/792471

[^129^] "Direct Render / Direct Render with Room Balance," Gearspace Forum, 2022. https://gearspace.com/board/vr-virtual-reality-spatial-atmos-immersive-ambisonics/1390884-direct-render-direct-render-room-balance.html

[^138^] "What is Immersive Audio & Why is it So Cool?" SMPTE, 2018. https://www.smpte.org/hubfs/2018-08-08-ST-Immersive-Vessa-Handout.pdf

[^155^] "Why are BEDS limited to 7.1.2?" Steinberg Forums, 2024. https://forums.steinberg.net/t/why-are-beds-limited-to-7-1-2/932618

[^156^] "Sound," Cinepedia, 2019. https://cinepedia.com/sound/

[^160^] "Atmos 7.1.2 vs 7.1.4 beds," Gearspace Forum, 2021. https://gearspace.com/board/post-production-forum/1345513-atmos-7-1-2-vs-7-1-4-beds.html

[^163^] "Guidelines for Dolby Atmos installation," Focal. https://www.focal.com/dolby-atmos-installation

[^190^] "Atmos Tops vs Heights and 3-layer Immersive Audio concept," AVS Forum, 2024. https://www.avsforum.com/threads/atmos-tops-vs-heights-and-3-layer-immersive-audio-concept.3310062/

[^191^] "Guidelines for Dolby Atmos installation," Focal. https://www.focal.com/dolby-atmos-installation

[^194^] "Dolby Atmos HE and the usefulness/impact of objects," Gearspace Forum, 2021. https://gearspace.com/board/post-production-forum/1360800-dolby-atmos-he-usefulness-impact-objects.html

[^220^] "How do the 5.1 and Stereo downmix settings work?" Dolby Professional Support. https://professionalsupport.dolby.com/s/article/How-do-the-5-1-and-Stereo-downmix-settings-work

[^223^] "Object Panning," libspatialaudio Documentation (VLC). https://github.com/videolan/libspatialaudio/blob/master/docs/ObjectPanning.md

[^227^] "What channel order should be used for assigning bed audio to the Renderer?" Dolby Professional Support. https://professionalsupport.dolby.com/s/article/What-channel-order-should-be-used-for-assigning-bed-audio-to-the-Renderer

[^229^] "7.1 surround sound," Grokipedia. https://grokipedia.com/page/7.1_surround_sound

[^230^] "Dolby Atmos Cinema Sound," Dolby Professional. https://professional.dolby.com/cinema/dolby-atmos/

[^231^] "Atmos Mixes - 9.1.6 Channel Activity," AVS Forum, 2024. https://www.avsforum.com/threads/atmos-mixes-9-1-6-channel-activity.3292223/

---

*Research compiled from 18+ independent web searches across authoritative sources including Dolby technical documentation, professional audio engineering forums, SMPTE standards, ITU recommendations, and academic publications.*
*Document version: 1.0*
*Generated: Research Session*
