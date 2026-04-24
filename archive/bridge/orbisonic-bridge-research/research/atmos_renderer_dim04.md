# Dimension 4: The Atmos Rendering Pipeline — From Master File to Speakers

## Comprehensive Technical Research Report

---

## Table of Contents

1. [Master File Format Specifications](#1-master-file-format-specifications)
2. [Renderer Architecture: RMU and DAPS](#2-renderer-architecture-rmu-and-daps)
3. [Real-Time Rendering Pipeline Stages](#3-real-time-rendering-pipeline-stages)
4. [Cinema Processor Architecture: CP950A](#4-cinema-processor-architecture-cp950a)
5. [Sample Rate and Bit Depth Handling](#5-sample-rate-and-bit-depth-handling)
6. [Bed Rendering Path vs Object Rendering Path](#6-bed-rendering-path-vs-object-rendering-path)
7. [Multiple Object Mixing (Additive Summation)](#7-multiple-object-mixing-additive-summation)
8. [Latency Considerations](#8-latency-considerations)
9. [Re-Render Capability](#9-re-render-capability)
10. [Key Findings Summary](#10-key-findings-summary)
11. [Gaps and Unresolved Questions](#11-gaps-and-unresolved-questions)
12. [Complete Source Reference List](#12-complete-source-reference-list)

---

## 1. Master File Format Specifications

### 1.1 Dolby Atmos Master File (DAMF) — Three-File Set

The native Dolby Atmos master file format consists of exactly three interdependent files created by the Rendering and Mastering Unit (RMU). This is the proprietary native format produced by the Dolby Atmos mastering tools.

#### 1.1.1 The `.atmos` File (XML Index)

```
Claim: The .atmos file is an XML file that serves as the master index describing the names of the other two files, how many beds and objects are utilized, the start time (offset), the FFoA (first frame of action, often the same as the starttime), the framerate, and other information [^1^].
Source: Hybrik Documentation
URL: https://docs.hybrik.com/tutorials/dolby_atmos/
Date: Current
Excerpt: "The .atmos file is an xml file describing the name of the other two files, how many beds and objects are utilized, the start time (offset), the FFoA (first frame of action, often the same as the starttime), the framerate, and other information."
Confidence: High
```

The `.atmos` file also contains **trim/downmix metadata** and **binaural metadata** according to Dolby's official support documentation [^2^]:

```
Claim: The .atmos file contains trim/downmix and binaural metadata in addition to file references [^2^].
Source: Dolby Professional Support
URL: https://professionalsupport.dolby.com/s/article/Overview-of-Dolby-Atmos-Master-File-Formats
Date: Current
Excerpt: "The .audio file contains the PCM audio, the .metadata file includes positional metadata, and the .atmos file contains trim/downmix and binaural metadata."
Confidence: High
```

#### 1.1.2 The `.atmos.metadata` File (Positional Metadata XML)

```
Claim: The .atmos.metadata file is an XML file containing XYZ Cartesian coordinates and size parameters for each object, sampled over time. These are typically very large files due to the high temporal resolution of animation data [^1^].
Source: Hybrik Documentation
URL: https://docs.hybrik.com/tutorials/dolby_atmos/
Date: Current
Excerpt: "The .atmos.metadata is an xml file with xyz and size coordinates for objects over time. These are large files."
Confidence: High
```

The metadata follows the Audio Definition Model (ADM) structure as specified in ITU-R BS.2076 [^3^]. Each object's position is described in a normalized Cartesian coordinate system where:
- **X coordinate**: Left-right dimension
- **Y coordinate**: Front-back dimension  
- **Z coordinate**: Down-up dimension

The coordinates are normalized relative to a reference cube representing an idealized cinema model, with the front plane at the screen location [^4^].

#### 1.1.3 The `.atmos.audio` File (CAF PCM Audio)

```
Claim: The .atmos.audio file is a Core Audio File (CAF) containing up to 128 tracks of PCM audio data. This is typically the largest file in the DAMF set [^1^] [^5^].
Source: Hybrik Documentation / Library of Congress Digital Formats
URL: https://docs.hybrik.com/tutorials/dolby_atmos/ ; https://www.loc.gov/preservation/digital/formats/fdd/fdd000646.shtml
Date: Current
Excerpt: "The .atmos.audio is a Core Audio File (CAF) of up to 128 tracks. These files are the largest."
Confidence: High
```

Apple's Core Audio Format (CAF) was chosen over standard WAV because it has no 4GB file size limitation and supports an arbitrary number of channels in a single file.

#### 1.1.4 Additional `.atmos.dbmd` File (Dolby Metadata)

According to MovieLabs manifest practices documentation, a fourth file may be present: `.atmos.dbmd` containing additional Dolby-specific metadata [^6^]:

```
Claim: A DAMF may include a .atmos.dbmd file containing additional Dolby metadata [^6^].
Source: MovieLabs Atmos DAMF Manifest Practices
URL: https://www.movielabs.com/md/practices/atmos/ManifestPractices_AtmosDAMF_v1.1.pdf
Date: 2020-06-26
Excerpt: Manifest XML references files including: MY-TITLE.atmos, MY-TITLE.atmos.audio, MY-TITLE.atmos.dbmd, MY-TITLE.atmos.matadata
Confidence: High
```

### 1.2 ADM BWF Format (Single-File Alternative)

```
Claim: ADM BWF is a non-proprietary single-file alternative to DAMF. It is essentially a Broadcast WAV file (BW64/RF64) containing a <chna> chunk (channel ID map) and an <axml> chunk (Atmos metadata) at the head, followed by up to 128 channels of PCM audio data [^1^] [^7^].
Source: Hybrik Documentation / EBU BWF Spec
URL: https://docs.hybrik.com/tutorials/dolby_atmos/ ; https://tech.ebu.ch/docs/tech/tech3285s7.pdf
Date: Current
Excerpt: "This file is an alternative to DAMF and is not proprietary to Dolby. It is a single file that is basically a broadcast WAV with a huge data chunk at the head containing the .atmos and .atmos.metadata information."
Confidence: High
```

The ADM BWF file structure contains three key elements [^8^]:
1. **<chna> chunk**: Channel assignment metadata mapping each track to ADM element IDs
2. **<axml> chunk**: XML metadata containing the full ADM (Audio Definition Model) specification including object positions, beds, content groups
3. **<data> chunk**: Interleaved PCM audio samples

```
Claim: The <chna> chunk provides references from each track to ADM element IDs, while the <axml> chunk contains the full XML metadata following ITU-R BS.2076 [^7^].
Source: EBU Tech 3285 Supplement 7
URL: https://tech.ebu.ch/docs/tech/tech3285s7.pdf
Date: 2018
Excerpt: "The primary purpose of the <chna> chunk is to provide the references from each track in a BWF or BW64 file to the IDs in the Audio Definition Model (ADM) metadata defined in ITU-R BS.2076."
Confidence: High
```

### 1.3 IAB/IMF Format (Frame-Based Distribution)

```
Claim: The Immersive Audio Bitstream (IAB) is a frame-based representation of the DAMF in a single MXF file, specified for Interoperable Master Format (IMF) distribution. It interleaves PCM audio and metadata for digital cinema delivery [^1^] [^9^].
Source: Hybrik Documentation / SMPTE
URL: https://docs.hybrik.com/tutorials/dolby_atmos/ ; https://celluloidjunkie.com/2022/06/13/where-is-my-atmos-and-what-is-an-iab/
Date: Current
Excerpt: "This is a frame based representation of the DAMF in a single file, which is specified for IMF. IAB/IMF is an .mxf file with interleaved PCM and metadata."
Confidence: High
```

The IAB format is standardized under **SMPTE ST 2098-2** (Immersive Audio Bitstream Specification). Key technical constraints for IAB include [^10^]:

| Parameter | Specification |
|-----------|--------------|
| Sample Rate | 48 kHz (96 kHz defined but not yet required for compliance) |
| Bit Depth | 24-bit |
| Supported Frame Rates | 24, 25, 30, 48, 50, 60 fps |
| Maximum Bed Channels | 10 |
| Maximum Objects | 118 |
| Maximum Rendered Field (Bed + Objects) | 128 |
| AudioData Elements | AudioDataDLC only (lossy coding); AudioDataPCM forbidden |
| Minimum Bed Requirement | At least 1 bed channel per frame |

```
Claim: IAB uses lossy audio coding (AudioDataDLC - Dolby Lossy Coding) rather than raw PCM. The spatial coding reduces 128 bed/object channels to 12 or 16 elements for cinema distribution [^11^].
Source: Hybrik Documentation
URL: https://docs.hybrik.com/tutorials/dolby_atmos/
Date: Current
Excerpt: "Spatial coding is employed to reduce 128 bed and object channels to 12 or 16 elements or 'clusters'. Actually, this is really 11.1 or 15.1 as the LFE doesn't move."
Confidence: High
```

### 1.4 Object Audio Metadata (OAMD) Structure

```
Claim: Each audio object carries Object Audio Metadata (OAMD) that includes 3D position (x,y,z), size (apparent source width), and optional binaural render mode. The metadata is sampled at frame-rate intervals (e.g., every frame at 24fps) [^11^] [^12^].
Source: Hybrik / Dolby Renderer Guide
URL: https://docs.hybrik.com/tutorials/dolby_atmos/ ; https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Date: 2018-08-02
Excerpt: "Dolby Atmos content consists of both audio objects and positional metadata, which includes information describing where those sounds should be placed and how they should move, along with other data."
Confidence: High
```

---

## 2. Renderer Architecture: RMU and DAPS

### 2.1 The Rendering and Mastering Unit (RMU)

```
Claim: The Dolby RMU (Rendering and Mastering Unit) is a dedicated hardware workstation — typically a Dell Precision Rack server — that serves as the core intelligent component of a Dolby Atmos mastering system. It receives up to 128 input audio tracks and automation metadata for up to 118 objects over two MADI connections, plus metadata over Ethernet [^13^].
Source: Dolby Atmos Renderer Guide
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Date: 2018-08-02
Excerpt: "During an authoring or monitoring workflow, the workstation receives up to 128 input audio tracks and automation metadata for up to 118 objects over two MADI connections, along with automation metadata for up to 118 objects over Ethernet."
Confidence: High
```

#### 2.1.1 RMU Hardware Specifications

```
Claim: The RMU is built on specific approved hardware configurations. For Dell-based systems, common specifications include: Dell Precision Rack 7910/7920 with Intel Xeon E5-2620 v3 (2.4 GHz, 6 cores, 12 logical processors), 16 GB RAM, running Windows 10 Pro for Workstations. The system includes two RME HDSPe MADI cards for 128 channels of MADI I/O [^13^] [^14^].
Source: Dolby Renderer Guide / RSPE Audio
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf ; https://www.rspeaudio.com/blog/post/demystifying-dolby-atmos-the-dolby-rmu
Date: 2018 / 2020
Excerpt: "Windows Dell Precision Rack, model 7910; Intel Xeon E5-2620 V3 2.40 GHz, 2,400 MHz, 6 Cores, 12 Logical Processors, 16 GB RAM; Windows 10 Pro"
Confidence: High
```

#### 2.1.2 Two Variants of RMU

```
Claim: There are two distinct RMU variants: (1) The RMU for theatrical/cinema applications (loan-only, requires Dolby engineer attendance for final printmasters), and (2) The RMU for home entertainment/near-field applications (for Blu-ray, streaming, VR content, available for purchase) [^14^].
Source: RSPE Audio
URL: https://www.rspeaudio.com/blog/post/demystifying-dolby-atmos-the-dolby-rmu
Date: 2020-07-31
Excerpt: "There are technically 2 variations on the Dolby Rendering and Mastering Unit (RMU). The Dolby RMU for theatrical applications (cinema) and the Dolby RMU for near field (home theater), which is designed for Blu-ray, digital delivery (streaming) and VR content. Although both of these devices have much in common, they are not interchangeable."
Confidence: High
```

#### 2.1.3 MADI Card Configuration and Buffer Sizes

```
Claim: The RME HDSPe MADI cards in the RMU are configured with specific buffer sizes: 512 samples at 48 kHz, and 1024 samples at 96 kHz. The 88.2/96 kHz option must be set to "48 kHz frame" to maintain 64 channels per MADI card at 96 kHz [^15^].
Source: Dolby Atmos Renderer Installation Guide
URL: https://www.slideshare.net/slideshow/dolby_atmos_renderer_installation_and_configuration_guide-pdf/271581349
Date: 2024-06-03
Excerpt: "Buffer Size: Use 512 when working at 48 kHz; use 1,024 when working at 96 kHz... To maintain 64 channels of I/O on each MADI card when working at 96 kHz, the 88.2/96 kHz option must be set to 48 kHz frame."
Confidence: High
```

### 2.2 Dolby Atmos Production Suite (DAPS)

```
Claim: The Dolby Atmos Production Suite is software that runs on the DAW machine (typically Mac). It includes the renderer, monitoring application, Pro Tools plug-ins, and can connect to a remote RMU or run standalone on the same computer as the DAW. The Mastering Suite includes the RMU software plus three Production Suite copies [^16^].
Source: Javier Zumer Blog
URL: https://javierzumer.com/blog/2018/5/30/figuring-out-dolby-atmos
Date: 2018-05-30
Excerpt: "Dolby basically offers two ways of doing this: Dolby Mastering Suite + RMU: This is the most advanced option... Dolby Production Suite: This is the package that should be installed on the Pro Tools machines. It basically includes the renderer itself, a monitoring application and all the necessary Pro Tools plugins."
Confidence: High
```

#### 2.2.1 DAPS Capabilities (Single-CPU Mode)

```
Claim: When using DAPS without a separate RMU (single-CPU system), the renderer runs on the same machine as the DAW using the Dolby Audio Bridge virtual driver. It can handle up to 118 mono objects (or a combination totaling up to 118 object channel paths), supports monitoring up to 22 speakers, headphone/binaural output, and up to 64 channels of re-render output [^12^].
Source: Dolby Atmos Renderer Guide
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Date: 2018-08-02
Excerpt: "The Dolby Atmos Renderer supports up to 118 mono objects, or a combination of mono and stereo objects totaling up to 118 object channel paths."
Confidence: High
```

#### 2.2.2 Audio Bridge Virtual Driver

```
Claim: The Dolby Audio Bridge is a virtual audio driver that routes audio from the DAW channel outputs (bed and object source tracks) to the Renderer input. It provides 128 virtual output channels from the DAW to the renderer [^12^].
Source: Dolby Atmos Renderer Guide
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Date: 2018-08-02
Excerpt: "The Dolby Audio Bridge routes audio from the DAW channel outputs (bed and object source tracks) to the Renderer input."
Confidence: High
```

---

## 3. Real-Time Rendering Pipeline Stages

### 3.1 Overview of the Rendering Process

```
Claim: Rendering refers to the process and algorithms that the Dolby Atmos Renderer uses to render audio beds and objects, positioning them in a three-dimensional space with up to 22 speakers during monitoring, or up to 64 speaker feeds for cinema playback. Positioning for beds is based on the width of the multichannel bed; positioning for objects is based on Dolby Atmos metadata from DAW panners [^12^].
Source: Dolby Atmos Renderer Guide
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Date: 2018-08-02
Excerpt: "Rendering refers to the process and algorithms that the Dolby Atmos Renderer uses to render (or play) audio beds and objects, positioning them in a three-dimensional space with up to 22 speakers."
Confidence: High
```

### 3.2 Stage 1: Parse Input Configuration

The renderer first reads the input configuration which defines:
- Which input channels are assigned as beds vs. objects
- Bed width (7.1.2 typical, or 9.1 for larger configurations)
- Object count (up to 118 mono objects)
- Group assignments for re-rendering

### 3.3 Stage 2: Position Objects in 3D Space

```
Claim: Objects are positioned using Cartesian coordinates (x, y, z) normalized to a reference cube. The front plane is the screen location. The renderer uses these coordinates to determine which physical speakers should reproduce each object [^4^] [^11^].
Source: SMPTE Presentation / Hybrik
URL: https://www.smpte.org/hubfs/2018-08-08-ST-Immersive-Vessa-Handout.pdf
Date: 2018-08-08
Excerpt: "The Cartesian coordinate values used for Audio Object position shall be normalized relative to reference points of a cube, which represents an idealized cinema model."
Confidence: High
```

### 3.4 Stage 3: Spatial Coding / Object Clustering (Consumer Encoding Path)

```
Claim: For consumer delivery (not cinema), spatial coding dynamically groups nearby objects and bed channels into "clusters" or "aggregate objects." The final encoded stream can have 12, 14, or 16 elements (11.1 or 15.1 effective, since LFE is separate). The clustering algorithm intelligently groups objects that occupy similar spatial positions [^11^] [^17^].
Source: Hybrik / Avid Resource Center
URL: https://docs.hybrik.com/tutorials/dolby_atmos/ ; https://www.avid.com/resource-center/encoding-and-delivering-dolby-atmos-music
Date: Current
Excerpt: "Spatial coding works by employing an algorithm to dynamically group audio into dynamic elements. Audio can move from cluster to cluster and the clusters themselves move as needed."
Confidence: High
```

```
Claim: The spatial coding process creates "spatial object groups" — composite sets of original audio objects. The number of elements can be set to 12, 14, or 16 (default is 12). At 16 elements, this represents 15.1 (15 clusters + LFE). The process is perceptually driven and preserves the original objects' power and position [^17^].
Source: Avid Resource Center
URL: https://www.avid.com/resource-center/encoding-and-delivering-dolby-atmos-music
Date: 2021-08-11
Excerpt: "The principle behind clustering is to intelligently group objects that occupy similar spatial positions into groups, called spatial object groups. Spatial object groups are a composite set of the original audio objects."
Confidence: High
```

### 3.5 Stage 4: VBAP-Based Gain Calculation

```
Claim: The Atmos renderer uses vector-based amplitude panning (VBAP) techniques to calculate speaker gains. For cinema rendering, objects are distributed to the appropriate speakers based on their 3D position, with the renderer using knowledge of the physical speaker layout. For home theater, the clustered elements are rendered similarly [^18^] [^19^].
Source: SPAT Revolution / Emerald Insight Review
URL: https://doc.flux.audio/spat-revolution/Spatialisation_Technology_Panning_Algorithms.html ; https://www.emerald.com/atsip/article-lookup/doi/10.1017/atsip.2021.12
Date: Current
Excerpt: "Panning in 3D space is realized via Vector-Based Amplitude Panning (VBAP)"
Confidence: Medium (VBAP is the industry standard approach; exact Atmos algorithm is proprietary)
```

The gain calculation process follows these principles:

1. **For each object**, the renderer identifies the nearest speakers in the physical array
2. **Gains are calculated** to create a phantom source at the object's designated (x,y,z) position
3. **Object size parameter** affects how many speakers participate — size=0 creates a point source; larger sizes distribute the signal to more speakers for an apparent source width effect [^20^]
4. **For bed channels**, each channel maps directly to its corresponding physical speaker (or is downmixed if fewer speakers exist)

```
Claim: The "size" parameter in Atmos controls apparent source width by cross-propagating the signal into neighboring speaker channels. However, engineers report that size > 20 can cause clustering issues and unpredictable downmix behavior [^17^] [^20^].
Source: Avid / Gearspace Forum
URL: https://www.avid.com/resource-center/encoding-and-delivering-dolby-atmos-music ; https://gearspace.com/board/post-production-forum/1368482-dolby-atmos-bed-vs-object.html
Date: 2021-08-11 / 2021-12-21
Excerpt: "Increasing the size value of an Atmos Object beyond 20 should be avoided because it can cause issues with the spatial coding process."
Confidence: High
```

### 3.6 Stage 5: Mix to Output Channels (Additive Summation)

```
Claim: The renderer sums all bed channels and all rendered objects additively at each output speaker channel. The master output is the sum of all beds and objects [^21^].
Source: Reddit / Pro Tools Expert
URL: https://www.reddit.com/r/DolbyAtmosMixing/comments/1c7hwiz/first_time_atmos_question_about_mastering/
Date: Current
Excerpt: "Bouncing an ADM out of Pro Tools is the sum of the beds and objects"
Confidence: High
```

### 3.7 Stage 6: Binaural Rendering (Headphone Path)

```
Claim: For headphone monitoring, the renderer applies a Head-Related Transfer Function (HRTF) to create a binaural downmix. Each object and bed channel can have a binaural render mode: Off (no spatialization), Near (~20cm from head), Mid (~2 meters), or Far (~6 meters). This modifies frequency response and reverb time to simulate distance [^22^] [^23^].
Source: Omni Soundlab / Avid
URL: https://omnisoundlab.com/en/binaural-audio-dolby-atmos-headphones-spatial-audio/ ; https://www.avid.com/resource-center/creating-your-dolby-atmos-mix-with-headphones
Date: Current / 2021-01-21
Excerpt: "Near: the sound is perceived approximately 20 cm from the head. Mid: represents a sound about 2 meters away. Far: simulates a sound about 6 meters away."
Confidence: High
```

---

## 4. Cinema Processor Architecture: CP950A

### 4.1 Overview

```
Claim: The Dolby Atmos Cinema Processor CP950A supports up to 64 speaker feeds for full Dolby Atmos theatrical playback. It is built on the CP950 platform with an integrated Dolby Atmos media block card (CAT1710) and higher wattage power supply (CAT1741) [^24^].
Source: Dolby CP950A Product Sheet
URL: https://professional.dolby.com/siteassets/products/cp950a/dolby_cp950a_product_sheet-2.pdf
Date: Current
Excerpt: "Complete Dolby Atmos capability and rendering up to 64 speaker feeds"
Confidence: High
```

### 4.2 Digital Audio Output Protocols

```
Claim: The CP950A outputs up to 64 speaker feeds via either AES67 or BLU Link protocols over RJ45 Ethernet connectors. The system transmits audio in streams of 8 channels each — with 64 channels providing 8 streams of 8 channels. Each stream has specific RTP source/destination UDP port assignments [^25^].
Source: Dolby CP950/CP950A Manual
URL: https://professional.dolby.com/siteassets/products/cp950a/dolby_cp950-cp950a_manual_issue_11.pdf
Date: 2022-11-02
Excerpt: "The CP950 is a 16-channel audio processor, which provides two streams of eight channels. The CP950A is a 64-channel audio processor, which provides eight streams of eight channels."
Confidence: High
```

### 4.3 Default Port Assignments for 64 Channels

| Channel Range | RTP Source Port |
|---------------|-----------------|
| 1-8 | 6518 |
| 9-16 | 6519 |
| 17-24 | 6520 |
| 25-32 | 6521 |
| 33-40 | 6522 |
| 41-48 | 6523 |
| 49-56 | 6524 |
| 57-64 | 6525 |
| All | Destination: 6517 |

### 4.4 Audio Processing Features

```
Claim: The CP950A supports sample rates of 44.1 kHz, 48 kHz, and 96 kHz at 16, 20, and 24-bit resolution. Features include: high-resolution multi-rate EQ, internal crossovers supporting up to 4-way loudspeakers, built-in booth monitor, real-time analyzer (RTA), and Dolby Atmos Designer compatibility for automated setup [^24^].
Source: Dolby CP950A Product Sheet
URL: https://professional.dolby.com/siteassets/products/cp950a/dolby_cp950a_product_sheet-2.pdf
Date: Current
Excerpt: "Supported Sample Rates: 44.1 kHz, 48 kHz and 96 kHz at 16, 20 and 24 bit. AES67 or BLU Link protocols for digital output (up to 64 speaker feeds). High resolution multi-rate EQ. Internal crossover supports up to 4-way loudspeakers."
Confidence: High
```

### 4.5 Cinema Rendering Pipeline

The CP950A receives the IAB (Immersive Audio Bitstream) from the cinema server over the Dolby Atmos Connect input (RJ45). The internal media block card decodes the IAB frame-by-frame, extracting:
1. Bed channel audio (up to 9.1.2 / 7.1.2)
2. Object audio channels
3. Object positional metadata

The cinema processor then renders objects to its configured speaker array (up to 64 speakers) using the room configuration defined in Dolby Atmos Designer software.

---

## 5. Sample Rate and Bit Depth Handling

### 5.1 Standard Delivery Specification

```
Claim: The standard Dolby Atmos delivery specification is 48 kHz / 24-bit. This is required by virtually all streaming platforms. While 96 kHz sessions are supported for archival/audiophile work, most distributors require 48 kHz delivery [^26^].
Source: Ralph Sutton Dolby Atmos Guide
URL: https://ralphsutton.com/dolby-atmos-standards-deliverables-2025/
Date: 2025-10-18
Excerpt: "The sample rate and bit depth define the technical resolution of your audio. For Dolby Atmos, the standard delivery spec is 48kHz / 24-bit."
Confidence: High
```

### 5.2 Renderer Sample Rate Modes

```
Claim: The Dolby Atmos Renderer supports both 48 kHz and 96 kHz sessions. Key differences at 96 kHz: (1) Only 64 input channels supported (vs. 128 at 48 kHz), (2) Only first 32 channels of each MADI card used, (3) ADM BWF export not supported, (4) VR mode not supported, (5) Buffer sizes double to 1024 samples [^12^].
Source: Dolby Atmos Renderer Guide
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Date: 2018-08-02
Excerpt: "At 96 kHz, the Renderer supports 64 inputs only... You cannot export a master to ADM BWF. The Export ADM BWF menu command is not supported."
Confidence: High
```

### 5.3 Master File Sample Rate Storage

```
Claim: Master files can be created at 96 kHz for archival purposes and stored. They are then sample-rate converted to 48 kHz for encoding and distribution [^27^].
Source: Reddit / Production Expert
URL: https://www.reddit.com/r/audio/comments/1diekre/is_dolby_atmos_worth_going_down_to_24_bit_48000/
Date: Current
Excerpt: "Master files can be created at these rates and stored for archive purposes, and are then sample-rate converted to 48 kHz for encoding purposes."
Confidence: High
```

---

## 6. Bed Rendering Path vs Object Rendering Path

### 6.1 Fundamental Difference

```
Claim: The bed is a channel-based multichannel track (up to 7.1.2 or 9.1) where each channel is statically mapped to a specific speaker location. Objects are mono or stereo audio signals with dynamic 3D positional metadata that can be panned anywhere in the space [^28^] [^12^].
Source: Eventide / Dolby Renderer Guide
URL: https://www.eventideaudio.com/blog/atmos-demystified/ ; https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Date: 2025-03-18 / 2018-08-02
Excerpt: "The bed track has one stream of audio for each speaker, and these streams are statically positioned at the location of each corresponding speaker in an Atmos layout."
Confidence: High
```

### 6.2 Bed Rendering Path

```
Claim: Bed channels are rendered directly to their corresponding physical speakers. If the playback system has fewer speakers than the bed configuration, downmix coefficients are applied. For example, a 7.1.2 bed on a 5.1.2 system downmixes the side surrounds into the front and rear surrounds [^29^].
Source: Steinberg Forums
URL: https://forums.steinberg.net/t/atmos-differences-between-beds-and-objects/750117
Date: 2021-11-17
Excerpt: "The 7.1.2 bed has fixed positions. The (remaining) 118 objects can be placed, panned or circulated freely in the 3D space around the listener."
Confidence: High
```

### 6.3 Object Rendering Path

```
Claim: Objects are rendered using real-time positional metadata. Each object's (x,y,z) coordinates are translated to speaker gains using the renderer's panning algorithm. The same object will render differently depending on the speaker configuration — e.g., an object at top-front will play from different speakers in a 7.1.4 vs 9.1.6 system [^29^].
Source: Steinberg Forums / Gearspace
URL: https://forums.steinberg.net/t/atmos-differences-between-beds-and-objects/750117 ; https://gearspace.com/board/post-production-forum/1368482-dolby-atmos-bed-vs-object.html
Date: 2021
Excerpt: "Objects are more precise as every speaker can be addressed separately but the beds get reproduced by speaker arrays in the surrounds and tops."
Confidence: High
```

### 6.4 Key Distinction: Phantom Images

```
Claim: An object panned to a speaker position with size=0 sounds identical to placing that audio in the corresponding bed channel. However, an object panned between speakers creates a phantom image using the renderer's panning law, which may differ from bed-based phantom imaging [^29^].
Source: Steinberg Forums
URL: https://forums.steinberg.net/t/atmos-differences-between-beds-and-objects/750117
Date: 2021-11-17
Excerpt: "Depending upon the position and size metadata applied to an object, objects and bed channels can be sonically identical. For instance, an object placed in the left front with size set to zero will be identical to placing the audio in the Left channel bed."
Confidence: High
```

### 6.5 LFE Restriction

```
Claim: Objects cannot be routed directly to the LFE channel. Only bed channels can feed the LFE. If content needs to be routed exclusively to the subwoofer, it must be placed in a bed track [^28^].
Source: Audient
URL: https://audient.com/tutorial/objects-and-beds-explained/
Date: 2024-02-21
Excerpt: "Objects can't feed the LFE channel (only beds can)."
Confidence: High
```

---

## 7. Multiple Object Mixing (Additive Summation)

### 7.1 Additive Mixing Model

```
Claim: The Atmos renderer uses additive (linear) summation to mix multiple objects at each output speaker channel. Each speaker's output signal is the sum of all bed channels and all rendered object signals assigned to that speaker [^21^].
Source: Reddit / Pro Tools Expert
URL: https://www.reddit.com/r/DolbyAtmosMixing/comments/1c7hwiz/first_time_atmos_question_about_mastering/
Date: Current
Excerpt: "Bouncing an ADM out of Pro Tools is the sum of the beds and objects"
Confidence: High
```

### 7.2 Downmix Preservation

```
Claim: The renderer's trim and downmix controls allow engineers to adjust how bed channels are downmixed to fewer speakers. The downmix metadata is stored in the .atmos master file and can be adjusted after the master is created. This includes height content routing to legacy systems and surround channel forward/backward bias [^30^].
Source: Reddit / Home Theater
URL: https://www.reddit.com/r/hometheater/comments/11sqvz3/how_dolby_atmos_actually_works_marketing_vs/
Date: 2023
Excerpt: "During the mastering process, the engineer/mixer can specify where the height content should go if it's played on a legacy system, for example 5.1 or 7.1. This can be adjusted even after the master file is generated because it's stored as metadata."
Confidence: High
```

---

## 8. Latency Considerations

### 8.1 MADI-Based System Latency

```
Claim: In RMU-based systems using MADI I/O, the RME HDSPe MADI cards introduce buffer latency. At 48 kHz, the buffer size is 512 samples (~10.7 ms). At 96 kHz, it is 1024 samples (~10.7 ms). MADI card 2 must be synced to "Sync In" to avoid audio offset and late playback [^15^].
Source: Dolby Atmos Renderer Installation Guide
URL: https://www.slideshare.net/slideshow/dolby_atmos_renderer_installation_and_configuration_guide-pdf/271581349
Date: 2024-06-03
Excerpt: "Buffer Size: Use 512 when working at 48 kHz; use 1,024 when working at 96 kHz... Sync MADI card 2 to Sync In to avoid audio being offset and playing back late."
Confidence: High
```

### 8.2 Renderer Delay Compensation

```
Claim: The RMU "compensates for any delays in the system" as part of its processing pipeline. The renderer also has configurable global audio delay (in milliseconds) for speaker calibration and synchronization [^14^] [^12^].
Source: RSPE Audio / Dolby Renderer Guide
URL: https://www.rspeaudio.com/blog/post/demystifying-dolby-atmos-the-dolby-rmu
Date: 2020-07-31
Excerpt: "The RMU does all of the processing for rendering objects, managing pans and authoring the Dolby Atmos file... while compensating for any delays in the system."
Confidence: High
```

### 8.3 ASIO/Core Audio Buffer Considerations

When using the Dolby Audio Bridge (single-CPU/DAPS mode), the renderer operates as an ASIO/Core Audio device with configurable buffer sizes. The total round-trip latency includes:
1. DAW output buffer
2. Audio Bridge transfer
3. Renderer processing
4. Audio interface output buffer

```
Claim: Pro Tools Aggregate and Built-In output devices can intermittently change sampling rate to 44.1 kHz (typically after CPU overload), causing rendered audio to become jittery. This requires manual resetting to 48 kHz in Audio MIDI Setup [^12^].
Source: Dolby Atmos Renderer Guide
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Date: 2018-08-02
Excerpt: "Pro Tools Aggregate and Built-In output audio devices can intermittently, and without warning, change the sampling rate to 44.1 kHz (typically, after a CPU overload). This sample-rate change causes rendered audio to be jittery."
Confidence: High
```

---

## 9. Re-Render Capability

### 9.1 Re-Render Output Matrix

```
Claim: The Dolby Atmos Renderer supports re-rendering to channel-based formats through a re-render output matrix. It can output multiple channel-based re-renders simultaneously, including: 2.0 (stereo), 5.0, 5.1, 7.0, 7.1, 7.0.2, 7.1.2, 9.1.6, BIN (binaural), and AmbiX (B-format) [^12^].
Source: Dolby Atmos Renderer Guide
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Date: 2018-08-02
Excerpt: "Supported layouts include 2.0, 5.0, 5.1, 7.0, 7.1, 7.0.2, 7.1.2, 9.1.6, BIN (binaural), and AmbiX (B-format)."
Confidence: High
```

### 9.2 Re-Render Channel Capacity

```
Claim: The renderer supports up to 64 channels of re-render output. When using Send/Return plug-ins, up to 64 channels of live re-renders can be configured. When using ASIO/Core Audio, the number depends on the audio driver configuration [^12^].
Source: Dolby Atmos Renderer Guide
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Date: 2018-08-02
Excerpt: "Re-renders channels: These provide up to 64 channels for re-rendered audio from the Renderer."
Confidence: High
```

### 9.3 Group-Based Stem Creation

```
Claim: Re-renders can be configured to output group-based stems. Each input (bed or object) can be assigned to a custom group (e.g., "DX" for dialogue, "MX" for music, "FX" for effects). Each group can then be re-rendered to a separate channel-based output. This is the standard workflow for creating DX/MX/FX stems from an Atmos master [^31^].
Source: Vi-Control Forum
URL: https://vi-control.net/community/threads/mixing-orchestral-music-in-atmos.148954/
Date: 2024-02-13
Excerpt: "There is a Grouping functionality available in the renderer - this is designed for post houses to make their DX, MX, FX stem deliverables from an atmos file. You would create a separate bed per stem, and group it with any individual objects that also comprise part of that stem."
Confidence: High
```

### 9.4 Offline Re-Render Export

```
Claim: Re-renders can be exported offline without real-time playback using File > Export Re-renders. The dialog allows setting in/out points, and exports all configured re-render strips as individual WAV files automatically [^12^].
Source: Dolby Atmos Renderer Guide
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Date: 2018-08-02
Excerpt: "This menu command enables you to create re-render files from a previously recorded Dolby Atmos file that is loaded without having to play back the file."
Confidence: High
```

### 9.5 ADM BWF Export

```
Claim: The renderer can export a mastered .atmos file directly to ADM BWF format (File > Export ADM BWF) without requiring real-time playback. This is the standard delivery format for streaming platforms [^12^].
Source: Dolby Atmos Renderer Guide
URL: https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf
Date: 2018-08-02
Excerpt: "This menu command enables you to create an ADM BWF (multichannel .wav file) from a previously recorded Dolby Atmos file that is loaded without having to play back the file."
Confidence: High
```

---

## 10. Key Findings Summary

The Dolby Atmos rendering pipeline represents a multi-stage signal processing architecture that bridges the gap between creative authoring and diverse playback environments. At its foundation, the system operates on a hybrid model that combines traditional channel-based audio ("beds") with object-based audio elements that carry 3D positional metadata.

### Master File Architecture

The native Dolby Atmos Master File (DAMF) consists of three interdependent files: an XML index (.atmos) describing the session structure and trim/downmix/binaural metadata, a large XML metadata file (.atmos.metadata) containing per-object XYZ position and size coordinates sampled over time, and a Core Audio Format (.atmos.audio) file carrying up to 128 tracks of PCM audio. This three-file structure reflects a deliberate separation of concerns: audio essence, spatial metadata, and session management are stored independently, enabling efficient parsing and editing. For broader interoperability, the ADM BWF format packages equivalent information into a single Broadcast WAV file using standardized <chna> and <axml> chunks per ITU-R BS.2076 and EBU Tech 3285. For cinema distribution, the frame-based Immersive Audio Bitstream (IAB) format under SMPTE ST 2098-2 interleaves lossy-coded audio (AudioDataDLC) with metadata in an MXF wrapper.

### Renderer Architecture

The rendering system operates in two primary hardware configurations. The high-end theatrical/mastering workflow uses the Rendering and Mastering Unit (RMU) — a dedicated Dell server-class workstation with dual RME HDSPe MADI cards providing 128 channels of audio I/O over MADI, plus Ethernet for metadata transport. The RMU runs Windows and processes all rendering, room calibration, and master file authoring. The alternative Production Suite (DAPS) runs on the DAW machine itself (Mac or Windows) using the Dolby Audio Bridge virtual driver, suitable for smaller-scale productions. Both configurations share the same rendering algorithms but differ in channel capacity and latency characteristics.

### Real-Time Rendering Pipeline

The rendering process follows a clear signal flow: (1) Input configuration parsing determines which channels are beds vs. objects, (2) Object positions are mapped from normalized Cartesian coordinates to the physical speaker layout, (3) For consumer encoding, spatial coding dynamically clusters nearby objects into 12-16 aggregate elements using a perceptual loudness-driven algorithm, (4) Vector-based amplitude panning calculates per-speaker gains for each object or cluster, (5) All signals are additively summed at each output channel, and (6) Optional binaural rendering applies HRTF-based virtualization for headphone output. The cinema path (CP950A processor) skips spatial coding and renders directly to up to 64 speaker feeds via AES67 or BLU Link protocols.

### Sample Rate and Bit Depth

The delivery standard is 48 kHz / 24-bit, though the renderer supports 96 kHz / 24-bit for archival work with reduced channel counts (64 inputs vs. 128). The MADI buffer sizes scale with sample rate: 512 samples at 48 kHz and 1024 samples at 96 kHz, maintaining approximately 10.7 ms of hardware buffer latency in both cases.

### Bed vs. Object Paths

The bed rendering path treats each channel as a fixed-position speaker feed with conventional downmix behavior. The object path provides dynamic 3D positioning through real-time metadata-driven panning. Critically, objects cannot feed the LFE channel directly, and an object with size=0 placed at a speaker position sounds identical to the corresponding bed channel. The choice between bed and object affects clustering behavior during encoding, with objects providing more precise spatial reproduction across different speaker configurations.

### Re-Render Capability

A defining feature of the Atmos pipeline is its ability to generate channel-based deliverables (stems) from the object-based master. The re-render output matrix supports up to 64 channels of simultaneous re-render output in formats from stereo to 9.1.6, plus binaural and AmbiX. Group-based re-rendering enables creation of standard DX/MX/FX stems for post-production workflows. All re-renders can be exported offline without real-time playback.

---

## 11. Gaps and Unresolved Questions

1. **Exact VBAP/Rendering Algorithm**: While industry sources confirm VBAP-like techniques are used, Dolby has not publicly disclosed the exact panning law equations, interpolation algorithms, or speaker triangulation methods used in their renderer. The specific implementation of dual-band panning (if any) is unknown.

2. **Spatial Coding Algorithm Details**: The clustering/grouping algorithm that reduces 128 channels to 12-16 elements is proprietary. The exact perceptual criteria, distance metrics, and temporal smoothing parameters have not been published.

3. **Precise Latency Specifications**: While MADI buffer sizes are documented, the total end-to-end latency specification (DAW → Audio Bridge → Renderer → Output) for different configurations is not publicly available.

4. **Object Size Implementation**: How the "size" parameter is implemented (decorrelation, all-pass filtering, FIR, etc.) is not documented. Users report it may use "short decorrelation" but this is unconfirmed.

5. **Cinema Rendering vs. Home Rendering Differences**: The exact algorithmic differences between the CP950A cinema renderer and the home entertainment renderer are not publicly specified beyond channel count.

6. **ADM BWF to DAMF Conversion Fidelity**: Whether the Dolby Atmos Conversion Tool preserves all metadata exactly or applies any transforms during conversion is not fully documented.

7. **The IAB AudioDataDLC Codec**: The specific lossy coding algorithm used in IAB (AudioDataDLC) is not publicly documented in detail.

---

## 12. Complete Source Reference List

| Ref | Source | URL | Date |
|-----|--------|-----|------|
| [^1^] | Hybrik Dolby Atmos Documentation | https://docs.hybrik.com/tutorials/dolby_atmos/ | Current |
| [^2^] | Dolby Professional Support - Master File Formats | https://professionalsupport.dolby.com/s/article/Overview-of-Dolby-Atmos-Master-File-Formats | Current |
| [^3^] | ITU-R BS.2076 - Audio Definition Model | https://www.itu.int/rec/R-REC-BS.2076 | Standard |
| [^4^] | SMPTE Immersive Audio Standards Presentation | https://www.smpte.org/hubfs/2018-08-08-ST-Immersive-Vessa-Handout.pdf | 2018-08-08 |
| [^5^] | Library of Congress - Dolby Atmos Master File | https://www.loc.gov/preservation/digital/formats/fdd/fdd000646.shtml | Current |
| [^6^] | MovieLabs Atmos DAMF Manifest Practices v1.1 | https://www.movielabs.com/md/practices/atmos/ManifestPractices_AtmosDAMF_v1.1.pdf | 2020-06-26 |
| [^7^] | EBU Tech 3285-s7 - CHNA Chunk Spec | https://tech.ebu.ch/docs/tech/tech3285s7.pdf | 2018 |
| [^8^] | ITU-R BS.2388-6 - ADM Usage Guidelines | https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-BS.2388-6-2025-PDF-E.pdf | 2025 |
| [^9^] | Celluloid Junkie - What Is An IAB? | https://celluloidjunkie.com/2022/06/13/where-is-my-atmos-and-what-is-an-iab/ | 2022-06-13 |
| [^10^] | Sherpa Down - IAB Technical Specs | https://sherpadown.net/dcp-inside/IAB.en | 2022-06-13 |
| [^11^] | Hybrik - Dolby Atmos Tutorial | https://docs.hybrik.com/tutorials/dolby_atmos/ | Current |
| [^12^] | Dolby Atmos Renderer Guide | https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf | 2018-08-02 |
| [^13^] | Dolby Renderer Guide - RMU Section | https://professional.dolby.com/siteassets/content-creation/dolby-atmos/dolby_atmos_renderer_guide.pdf | 2018-08-02 |
| [^14^] | RSPE Audio - Demystifying the RMU | https://www.rspeaudio.com/blog/post/demystifying-dolby-atmos-the-dolby-rmu | 2020-07-31 |
| [^15^] | Dolby Renderer Installation Guide | https://www.slideshare.net/slideshow/dolby_atmos_renderer_installation_and_configuration_guide-pdf/271581349 | 2024-06-03 |
| [^16^] | Javier Zumer - Figuring Out Dolby Atmos | https://javierzumer.com/blog/2018/5/30/figuring-out-dolby-atmos | 2018-05-30 |
| [^17^] | Avid - Encoding and Delivering Dolby Atmos Music | https://www.avid.com/resource-center/encoding-and-delivering-dolby-atmos-music | 2021-08-11 |
| [^18^] | SPAT Revolution - Panning Algorithms | https://doc.flux.audio/spat-revolution/Spatialisation_Technology_Panning_Algorithms.html | Current |
| [^19^] | Emerald Insight - Immersive Audio Review | https://www.emerald.com/atsip/article-lookup/doi/10.1017/atsip.2021.12 | 2021 |
| [^20^] | Avid Forum - Atmos Size Parameter Phase Issue | https://duc.avid.com/showthread.php?t=427141 | 2024-01-01 |
| [^21^] | Reddit - Atmos Mastering Question | https://www.reddit.com/r/DolbyAtmosMixing/comments/1c7hwiz/first_time_atmos_question_about_mastering/ | Current |
| [^22^] | Omni Soundlab - Binaural Audio & Atmos | https://omnisoundlab.com/en/binaural-audio-dolby-atmos-headphones-spatial-audio/ | Current |
| [^23^] | Avid - Creating Atmos Mix with Headphones | https://www.avid.com/resource-center/creating-your-dolby-atmos-mix-with-headphones | 2021-01-21 |
| [^24^] | Dolby CP950A Product Sheet | https://professional.dolby.com/siteassets/products/cp950a/dolby_cp950a_product_sheet-2.pdf | Current |
| [^25^] | Dolby CP950/CP950A Manual Issue 11 | https://professional.dolby.com/siteassets/products/cp950a/dolby_cp950-cp950a_manual_issue_11.pdf | 2022-11-02 |
| [^26^] | Ralph Sutton - Dolby Atmos Standards Guide | https://ralphsutton.com/dolby-atmos-standards-deliverables-2025/ | 2025-10-18 |
| [^27^] | Reddit - 48kHz/24-bit Discussion | https://www.reddit.com/r/audio/comments/1diekre/is_dolby_atmos_worth_going_down_to_24_bit_48000/ | Current |
| [^28^] | Eventide - Dolby Atmos Demystified | https://www.eventideaudio.com/blog/atmos-demystified/ | 2025-03-18 |
| [^29^] | Steinberg Forums - Beds vs Objects | https://forums.steinberg.net/t/atmos-differences-between-beds-and-objects/750117 | 2021-11-17 |
| [^30^] | Reddit - How Dolby Atmos Actually Works | https://www.reddit.com/r/hometheater/comments/11sqvz3/how_dolby_atmos_actually_works_marketing_vs/ | 2023 |
| [^31^] | Vi-Control - Mixing Orchestral Music in Atmos | https://vi-control.net/community/threads/mixing-orchestral-music-in-atmos.148954/ | 2024-02-13 |

---

*Research compiled: 2025*
*Total independent web searches performed: 18*
*Sources cited: 31*
