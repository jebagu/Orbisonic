# ADM BW64 / Sonic Sphere File Format Integration and macOS Desktop Implementation

## 1. The ADM BW64 Ecosystem — A Technical Overview

### 1.1 The Standards Stack

The Audio Definition Model (ADM) is an open metadata framework specified in **ITU-R BS.2076** that describes the structure, content, and spatial characteristics of audio programmes^1^. It is not itself an audio file format — rather, it is a standard for writing XML metadata that accompanies audio essence, enabling any renderer to interpret how that audio should be reproduced in space. ADM can represent **channel-based**, **object-based**, and **scene-based** (HOA/Ambisonic) audio simultaneously within the same programme^2^.

The ADM metadata travels inside a **BW64** file — the 64-bit successor to Broadcast Wave Format (BWF), specified in **ITU-R BS.2088**^3^. BW64 is structurally a RIFF/WAVE file with four key extensions that overcome BWF's 4GB limitation and add metadata carrying capacity:

- **`<ds64>` chunk**: 64-bit addressing enabling files larger than 4GB
- **`<fmt-ck>`**: Extended format chunk for PCM and non-PCM audio
- **`<chna>` chunk**: Channel allocation — maps each audio track to ADM metadata IDs^4^- **`<axml>` chunk**: Contains the full ADM XML metadata tree^5^The `chna` chunk is particularly critical: it contains per-track records of `audioTrackFormatID`, `audioPackFormatID`, and `audioTrackUID` — the unique identifiers that link each audio track in the file to its corresponding description in the ADM XML metadata^4^. This indirection means tracks can be reordered in the file without breaking the metadata associations^1^.

Additionally, **ITU-R BS.2125** defines a **Serial ADM (S-ADM)** format for live production and streaming, where ADM metadata is segmented into time-stamped frames suitable for real-time transport over AES3, MADI, or IP networks^6^. This is directly relevant to live spatial music performance.

### 1.2 Core Libraries — libadm and libbw64

**`ebu/libadm`** is a C++11 library providing the foundational data structures for parsing, modifying, creating, and writing ADM XML metadata conforming to ITU-R BS.2076^7^. It defines the complete entity hierarchy: `audioProgramme`, `audioContent`, `audioObject`, `audioPackFormat`, `audioChannelFormat`, `audioStreamFormat`, and `audioTrackFormat` — all the building blocks of an ADM document.

**`ebu/libbw64`** is a header-only C++ library for reading and writing BW64 files^8^. It handles the low-level RIFF chunk I/O — reading/writing the `ds64`, `chna`, `axml`, `bxml`, and `sxml` chunks — and presents audio sample data as iterable blocks. The two libraries are designed to work together: libbw64 extracts the raw XML from the `axml` chunk and the track allocation table from the `chna` chunk; libadm parses that XML into a navigable object model.

Together, these two libraries form the **de facto standard foundation** for any C++ application that needs to read or write ADM content. They are both Apache 2.0 licensed and actively maintained by the EBU.

### 1.3 The EBU ADM Renderer (EAR)

**`ebu/ebu_adm_renderer`** is the **Python reference implementation** of the EBU ADM Renderer, also serving as the ITU-R BS.2127 reference^9^. This is the most important project to study when building a custom renderer, as it defines the canonical interpretation of every ADM metadata parameter in terms of loudspeaker gains^10^.

The EAR implements:
- **Rendering item selection**: determines which audio elements (channels, objects, HOA components) are active at any given time
- **Track processing**: converts ADM track descriptions into rendering-ready audio streams
- **Gain calculation**: the core VBAP-style algorithm that maps objects and channels to loudspeaker feeds
- **Loudspeaker layout support**: all configurations defined in ITU-R BS.2051 (including 22.2)
- **Screen/room adaptation**: handles different reproduction environments

From version 2.0, the EAR also serves as the reference implementation of **ITU-R BS.2127** (the ITU ADM Renderer specification)^11^. The command-line tools `ear-render` and `ear-utils` provide practical entry points for experimentation.

**`libear`** is the C++ extraction of the EAR's core gain calculation and DSP components, released by BBC R&D in 2019 under Apache 2.0^12^. It is designed for **real-time applications** where the Python implementation is insufficient. libear handles the most complex part of the renderer: computing gain values for each input channel based on ADM metadata, using a single function call^13^.

### 1.4 The EBU ADM Toolbox (EAT)

**`ebu/ebu-adm-toolbox`** is a newer Python-based toolkit for processing ADM files in production pipelines^14^. It provides:
- **Profile conversion**: converting ADM files between different conformance levels
- **Validation**: checking ADM files for compliance and common errors
- **Rendering**: rendering ADM content to loudspeaker layouts
- **Repair tools**: fixing common ADM issues automatically

This is the most practical starting point for building an ADM processing pipeline, as it combines validation, conversion, and rendering in a single toolchain.

### 1.5 EAR Production Suite

**`ebu/ear-production-suite`** is an open-source VST plugin suite and REAPER extension for producing immersive audio using ADM^15^. Originally developed by BBC R&D and IRT as an EBU project, it enables native ADM production without tying the work to any specific codec or manufacturer^16^.

Key components include:
- **REAPER ADM Extension**: reads and writes ADM/BW64/BWF files using libbw64 and libadm^17^- **Monitoring plugins**: renders ADM content to ITU-R BS.2051 loudspeaker configurations for monitoring
- **ADM authoring tools**: create and edit ADM metadata within REAPER

The REAPER ADM Extension is particularly relevant for Sonic Sphere because it demonstrates a complete DAW integration of the libadm/libbw64 stack, providing a working reference for how to embed ADM I/O into a digital audio workstation.

### 1.6 ADM-OSC — Live Object Control

**`immersive-audio-live/ADM-OSC`** is an industry initiative (backed by Adamson, d&b, DiGiCo, Dolby, Lawo, Magix, Merging, Meyer Sound, and Steinberg) that defines a protocol for transmitting ADM-style object positioning data over **Open Sound Control (OSC)**^18^ ^19^.

ADM-OSC is critical for **live performance workflows** because ADM BWF is fundamentally a file-based format — it is not suitable for real-time streaming^6^. ADM-OSC bridges this gap by providing:
- Real-time object position streaming (X/Y/Z or azimuth/elevation/distance)
- Object gain control
- Synchronization cues
- A standard namespace that mirrors ADM semantics^2^The core address space maps directly to ADM concepts: `/adm/obj/id/xyz` for Cartesian coordinates, `/adm/obj/id/gain` for amplitude, and `/adm/obj/id/azim`/`elev`/`dist` for spherical coordinates^2^. This means a live performance controller can send object movements in real-time, and an ADM-OSC-capable renderer can interpret those movements using the same coordinate system as the file-based ADM metadata.

### 1.7 Adjacent and Experimental Projects

**`iluvcapra/soundobjects_blender_addon`** is a Blender add-on that generates ADM BWF files from a 3D environment^20^. While older and with some compatibility issues, it demonstrates the concept of exporting 3D scene data (object positions, animations) directly to ADM format — conceptually similar to how Sonic Sphere's 3D editor would author ADM content.

**`Mach1Studios/m1-admparser`** provides MIT-licensed tools for inspecting, debugging, and transcoding ADM and Atmos metadata^21^. It is useful for understanding the binary structure of ADM files and for experimental work around metadata conversion.

**`VoidXH/Cavern`** is an open-source C# audio framework with Atmos-related functionality and room correction^22^. While not standards-aligned, it demonstrates practical object-based rendering outside the official Dolby ecosystem.

**`AOMediaCodec/iamf-tools`** supports the **IAMF** (Immersive Audio Model and Formats) open standard from AOMedia^23^. While not ADM BWF, IAMF represents the broader next-generation audio ecosystem and includes tools for rendering to stereo and binaural formats.

---

## 2. How Sonic Sphere Uses ADM BW64

### 2.1 The Sonic Sphere Data Model Mapped to ADM

Sonic Sphere's six audio sources (4 bed channels + 2 moving objects) map naturally to ADM entities. The following table shows the correspondence:

| Sonic Sphere Concept | ADM Entity | ADM Type | Notes |
|---------------------|-----------|----------|-------|
| Project (entire composition) | `audioProgramme` | Container | Top-level programme description |
| Bed Channel Group | `audioContent` | Content grouping | Groups all bed channels as "bed" |
| Bed Channel 1–4 | `audioObject` → `audioChannelFormat` | DirectSpeakers | Fixed speaker positions |
| Object A, Object B | `audioObject` | Objects | Moving sources with `audioBlockFormat` position metadata |
| 3D Position (X,Y,Z) | `audioBlockFormat` → `position` | Cartesian coordinates | Normalized [-1, 1] mapped to ADM's coordinate system |
| Object Motion Path | `audioBlockFormat` → `position` (time-varying) | Animated metadata | Multiple block formats with different timestamps |
| Object Size/Spread | `audioBlockFormat` → `width`/`height`/`depth` | Object extent | Controls perceived source size |
| Master Gain | `audioObject` → `gain` | Gain element | Per-object level |
| Synth/Sample Toggle | `audioObject` → `audioTrackUID` | Track reference | Links to either sample track or silent (synth external) |

### 2.2 Bed Channels as DirectSpeakers

The 4 bed channels in Sonic Sphere are modeled as **DirectSpeakers** in ADM — each represents audio intended for a specific speaker position. In the ADM metadata:

```xml
<audioChannelFormat audioChannelFormatID="AC_00010001"
                    audioChannelFormatName="Bed Front Left High"
                    typeLabel="0001" typeDefinition="DirectSpeakers">
  <audioBlockFormat audioBlockFormatID="AB_00010001_00000001">
    <position coordinate="azimuth">-45.0</position>
    <position coordinate="elevation">30.0</position>
    <position coordinate="distance">1.0</position>
    <speakerLabel>BED1</speakerLabel>
  </audioBlockFormat>
</audioChannelFormat>
```

Each bed channel has a fixed `audioBlockFormat` with azimuth, elevation, and distance. When the user adjusts bed position in the 3D view (elevation slider, rotate Z, rotate Y), Sonic Sphere updates these position values and rewrites the ADM metadata.

### 2.3 Objects as Animated Objects

The 2 moving objects are modeled as ADM **Objects** — the key feature that enables object-based audio. Each object has multiple `audioBlockFormat` entries with timestamps, creating a time-varying position path:

```xml
<audioChannelFormat audioChannelFormatID="AC_00010005"
                    audioChannelFormatName="Object A"
                    typeLabel="0002" typeDefinition="Objects">
  <audioBlockFormat audioBlockFormatID="AB_00010005_00000001"
                    rtime="00:00:00.000000">
    <position coordinate="X">0.5</position>
    <position coordinate="Y">0.0</position>
    <position coordinate="Z">0.3</position>
  </audioBlockFormat>
  <audioBlockFormat audioBlockFormatID="AB_00010005_00000002"
                    rtime="00:00:02.500000">
    <position coordinate="X">-0.3</position>
    <position coordinate="Y">0.4</position>
    <position coordinate="Z">0.1</position>
  </audioBlockFormat>
</audioChannelFormat>
```

The `rtime` (reference time) attribute specifies when each position becomes active. Sonic Sphere generates these blocks automatically from the object's motion path (orbit, up-down, through-center, or recorded path). The interpolation between blocks is handled by the renderer.

### 2.4 File Format — Sonic Sphere BW64

Sonic Sphere uses BW64 as its native project file format, with the following structure:

```
[WAVE header]
  <ds64>          — 64-bit addressing
  <fmt-ck>        — Audio format (PCM, 48kHz, 24-bit, 6 tracks)
  <chna>          — Track allocation:
                      Track 1: BED1 (DirectSpeakers)
                      Track 2: BED2 (DirectSpeakers)
                      Track 3: BED3 (DirectSpeakers)
                      Track 4: BED4 (DirectSpeakers)
                      Track 5: Object A (Objects)
                      Track 6: Object B (Objects)
  <axml>          — Full ADM XML with:
                      - audioProgramme (project)
                      - 4 audioObject + audioChannelFormat (bed, DirectSpeakers)
                      - 2 audioObject + audioChannelFormat (objects, Objects)
                      - audioBlockFormat position animations for objects
                      - Sonic Sphere extensions (see §2.5)
  <data>          — Interleaved 6-channel audio:
                      Ch1-4: Bed audio samples
                      Ch5: Object A audio samples (or silence if synth)
                      Ch6: Object B audio samples (or silence if synth)
```

Audio samples are stored as interleaved PCM. When an object is in **synth mode**, its corresponding track contains silence — the synthesizer generates audio in real-time and is not stored in the file. When in **sample mode**, the track contains the loaded audio file content.

### 2.5 Sonic Sphere ADM Extensions

Sonic Sphere extends the standard ADM with custom attributes in the `axml` chunk, stored in an `<extension>` element within the ADM XML tree:

| Extension Attribute | Type | Description |
|--------------------|------|-------------|
| `sonicsphere:version` | String | File format version (e.g., "1.0") |
| `sonicsphere:bpm` | Float | Project tempo in BPM |
| `sonicsphere:length` | Timecode | Total project length (determined by longest bed) |
| `sonicsphere:objectModeA` | Enum | "sample" or "synth" |
| `sonicsphere:objectModeB` | Enum | "sample" or "synth" |
| `sonicsphere:objectStartA` | Float | Object A start time offset in seconds |
| `sonicsphere:objectStartB` | Float | Object B start time offset in seconds |
| `sonicsphere:objectMovementA` | JSON | Movement parameters (mode, speed, path keyframes) |
| `sonicsphere:objectMovementB` | JSON | Movement parameters (mode, speed, path keyframes) |
| `sonicsphere:renderMode` | Enum | "binaural", "51", "sonicsphere" |
| `sonicsphere:synthPatchA` | JSON | Synth parameters (waveform, filter, envelope, effects) |
| `sonicsphere:synthPatchB` | JSON | Synth parameters for Object B |
| `sonicsphere:sequencerPatternA` | JSON | 16-step sequencer data |
| `sonicsphere:sequencerPatternB` | JSON | 16-step sequencer data |

These extensions are stored in a namespace-qualified XML element that standard ADM parsers will ignore (graceful degradation), while Sonic Sphere-aware tools can read the full project state.

### 2.6 Export to Standard ADM (without extensions)

When exporting for interoperability with other ADM tools (EAR Production Suite, REAPER ADM Extension, etc.), Sonic Sphere can render a **standard ADM file** with all extensions stripped:

- Object motion paths are converted to standard `audioBlockFormat` position animations
- Synth-generated audio is rendered to audio samples and included in the file
- Bed positions are converted to standard DirectSpeakers
- The result is a fully standards-compliant ADM BW64 file that any ITU-R BS.2076 renderer can process

This two-tier approach — **native format with extensions** for Sonic Sphere editing, **standard ADM** for interoperability — ensures both rich functionality and ecosystem compatibility.

### 2.7 The ADM → Sonic Sphere → Renderer Pipeline

The complete data flow for a Sonic Sphere project:

```
Sonic Sphere Project (.ssb — BW64 with extensions)
    │
    ├──→ Read via libbw64 → extract axml + chna + audio samples
    │
    ├──→ Parse axml via libadm → ADM object model
    │   ├──→ Bed channels: DirectSpeakers → fixed positions
    │   ├──→ Objects: animated audioBlockFormat → position path
    │   └──→ Extensions: synth patches, sequencer patterns, movement params
    │
    ├──→ Real-time playback:
    │   ├──→ Bed audio: routed to DirectSpeakers positions
    │   ├──→ Object audio: synthesized (real-time) or sampled → position path
    │   └──→ Movement engine: interpolates position at audio sample rate
    │
    └──→ Render to output:
        ├──→ BINAURAL: HRTF via Core Audio Spatialization API
        ├──→ 5.1: VBAP triangulation to 6 speakers
        └──→ SONIC SPHERE 30.1: VBAP to 30 Fibonacci-sphere speakers + LFE
```

---

## 3. macOS Desktop Implementation

### 3.1 Architecture Overview

The recommended architecture for a native macOS Sonic Sphere application is a **Swift + Objective-C++** hybrid, leveraging Apple's audio frameworks and wrapping the EBU's C++ libraries:

| Layer | Technology | Responsibility |
|-------|-----------|---------------|
| UI Layer | SwiftUI | Main window, tab navigation, control panels, 3D view integration |
| 3D Rendering | Metal (via MTKView) | Green-on-black wireframe sphere, speaker cones, object orbs, trails |
| Audio Engine | AVAudioEngine + Core Audio | Real-time audio graph, multi-channel output, spatialization |
| ADM I/O | Objective-C++ wrappers | libadm + libbw64 integration, ADM parsing/writing |
| DSP/C++ | C++ | VBAP renderer, custom audio processing, libear gain calculation |
| File System | Swift (Foundation) | Project load/save, audio file import/export |
| MIDI/OSC | Swift (CocoaAsyncSocket) | ADM-OSC live control, MIDI controller input |

The use of **Objective-C++ bridging headers** is essential: the EBU libraries (libadm, libbw64, libear) are all C++17 code, which cannot be called directly from Swift. A thin Objective-C++ wrapper layer exposes C++ functionality to Swift via `@objc` annotated classes.

### 3.2 Project Structure

```
SonicSphere/
├── SonicSphere/
│   ├── App/
│   │   ├── SonicSphereApp.swift          — App entry point
│   │   └── MainWindowController.swift    — Window management
│   ├── UI/
│   │   ├── ContentView.swift             — Root view with tab router
│   │   ├── MusicTabView.swift            — Channel strips, transport
│   │   ├── SpatialTabView.swift          — 3D view container + controls
│   │   ├── SynthTabView.swift            — Synth controls + sequencer
│   │   ├── RenderTabView.swift           — Output configuration + meters
│   │   └── Shared/
│   │       ├── TransportView.swift       — Play/pause/BPM controls
│   │       ├── ChannelStripView.swift    — Single channel UI
│   │       ├── WaveformView.swift        — Audio waveform display
│   │       └── VUMeterView.swift         — Level meter
│   ├── Rendering/
│   │   └── Metal/
│   │       ├── SphereRenderer.swift      — MTKView delegate
│   │       ├── SphereShaders.metal       — Wireframe shaders
│   │       ├── SpeakerMesh.swift         — Speaker cone geometry
│   │       ├── ObjectOrb.swift           — Glowing orb + trail
│   │       └── CameraController.swift    — Orbit controls
│   ├── AudioEngine/
│   │   ├── SonicAudioEngine.swift        — AVAudioEngine setup
│   │   ├── VBAPRenderer.swift            — VBAP gain calculation
│   │   ├── BinauralRenderer.swift        — HRTF renderer
│   │   ├── SpeakerConfiguration.swift    — Speaker layout definitions
│   │   └── MovementEngine.swift          — Object animation
│   ├── ADM/
│   │   ├── ADMBridge.mm                  — Objective-C++ wrapper
│   │   ├── ADMBridge.h                   — Public header
│   │   ├── ADMFileReader.swift           — libbw64 + libadm read
│   │   ├── ADMFileWriter.swift           — libbw64 + libadm write
│   │   ├── ADMProject.swift              — Sonic Sphere data model
│   │   └── SonicSphereExtensions.swift   — Custom ADM extensions
│   └── Synth/
│       ├── SynthEngine.swift             — AVAudioUnitMIDISynth
│       ├── SequencerEngine.swift         — Step sequencer logic
│       └── EffectsChain.swift            — Reverb, delay, chorus
├── CppBridge/                            — Objective-C++ wrapper classes
│   ├── BridgeADMParser.mm                — Wraps libadm
│   ├── BridgeBW64Reader.mm               — Wraps libbw64
│   ├── BridgeBW64Writer.mm               — Wraps libbw64 write
│   └── BridgeGainCalculator.mm           — Wraps libear
├── ThirdParty/
│   ├── libadm/                           — Git submodule (ebu/libadm)
│   ├── libbw64/                          — Git submodule (ebu/libbw64)
│   ├── libear/                           — Git submodule (ebu/libear)
│   └── oscpack/                          — OSC library for ADM-OSC
└── SonicSphere.xcodeproj/
```

### 3.3 The C++ Bridging Layer

The most critical implementation detail is the **Objective-C++ bridge** that connects Swift to the EBU C++ libraries. Each bridge class wraps a C++ object and exposes it to Swift:

**ADMBridge.h** (public header, callable from Swift):
```objc
#import <Foundation/Foundation.h>

@interface ADMBridge : NSObject
- (instancetype)initWithPath:(NSString *)path;
- (NSArray<NSString *> *)trackFormatIDs;
- (NSArray<NSString *> *)packFormatIDs;
- (NSDictionary *)objectPositionsAtTime:(double)seconds;
- (BOOL)writeToPath:(NSString *)path error:(NSError **)error;
- (NSString *)admXMLString;
@end
```

**ADMBridge.mm** (Objective-C++ implementation):
```objc
#import "ADMBridge.h"
#import <libadm/adm.hpp>
#import <libbw64/bw64.hpp>

@interface ADMBridge () {
    std::shared_ptr<adm::Document> _admDocument;
    std::unique_ptr<bw64::Bw64Reader> _bw64Reader;
}
@end

@implementation ADMBridge

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        try {
            _bw64Reader = bw64::read([path UTF8String]);
            std::string axml = _bw64Reader->axmlChunk()->data();
            _admDocument = adm::parseXml(axml);
        } catch (const std::exception& e) {
            NSLog(@"ADM parse error: %s", e.what());
            return nil;
        }
    }
    return self;
}

- (NSDictionary *)objectPositionsAtTime:(double)seconds {
    NSMutableDictionary *positions = [NSMutableDictionary dictionary];
    
    for (auto& object : _admDocument->getElements<adm::AudioObject>()) {
        NSString *objID = [NSString stringWithUTF8String:object->get<adm::AudioObjectId>().get().c_str()];
        
        auto channel = object->getReference<adm::AudioChannelFormat>();
        auto blocks = channel->getElements<adm::AudioBlockFormat>();
        
        for (auto& block : blocks) {
            if (block.has<adm::CartesianPosition>()) {
                auto pos = block.get<adm::CartesianPosition>();
                positions[objID] = @{
                    @"x": @(pos.get<adm::X>().get()),
                    @"y": @(pos.get<adm::Y>().get()),
                    @"z": @(pos.get<adm::Z>().get())
                };
            }
        }
    }
    return positions;
}

@end
```

### 3.4 Audio Engine — AVAudioEngine

The audio engine uses **AVAudioEngine**, Apple's modern real-time audio graph framework. For Sonic Sphere's 6 input channels (4 bed + 2 objects), the engine is configured as follows:

```swift
import AVFoundation

class SonicAudioEngine {
    private let engine = AVAudioEngine()
    private var bedPlayers: [AVAudioPlayerNode] = []
    private var objectPlayers: [AVAudioPlayerNode] = []
    private var vbapMixer: AVAudioMixerNode!
    private let sampleRate: Double = 48000.0
    private let channelCount = 6
    
    func setup() throws {
        // Configure for multi-channel output
        let outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 31  // 30.1 Sonic Sphere mode
        )!
        
        engine.outputNode.installTap(onBus: 0, bufferSize: 512,
                                     format: outputFormat) { buffer, time in
            self.renderCallback(buffer: buffer, at: time)
        }
        
        // Create 6 input player nodes (4 bed + 2 objects)
        for _ in 0..<channelCount {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            bedPlayers.append(player)
        }
        
        // Connect through VBAP renderer
        vbapMixer = AVAudioMixerNode()
        engine.attach(vbapMixer)
        
        for player in bedPlayers {
            engine.connect(player, to: vbapMixer, format: nil)
        }
        
        engine.connect(vbapMixer, to: engine.mainMixerNode, format: outputFormat)
        try engine.start()
    }
    
    private func renderCallback(buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        // VBAP gain calculation per sample block
        // 1. Get current object positions from ADM animation
        // 2. Find 3 nearest speakers for each object
        // 3. Compute g = L^(-1) * p for each triplet
        // 4. Apply gains and sum contributions
        // 5. Route to output channels
    }
}
```

For **binaural mode**, use **Phase Audio's Spatialization API** (available in macOS 12+ via PHASE framework) or the `AVAudioEnvironmentNode` which provides built-in HRTF spatialization:

```swift
let environment = AVAudioEnvironmentNode()
engine.attach(environment)

// Connect each object to an environment input
let source = AVAudioEnvironmentNode.EnvironmentNodeSource()
source.position = AVAudio3DPoint(x: 0.5, y: 0.3, z: 0.0)
source.reverbSendLevel = 0.2
environment.connect(input: source, to: engine.mainMixerNode)
```

### 3.5 VBAP Renderer Implementation

The VBAP renderer is implemented in **C++** for performance, wrapped for Swift access:

```cpp
// VBAPRenderer.hpp
#include <libear/gain_calculator.hpp>
#include <vector>
#include <array>

struct SpeakerPosition {
    float azimuth;
    float elevation;
    float distance;
};

class VBAPRenderer {
public:
    // Initialize with speaker configuration
    void configure(const std::vector<SpeakerPosition>& speakers);
    
    // Compute gains for a source at (x, y, z)
    std::vector<float> computeGains(float x, float y, float z);
    
    // Render one sample block
    void render(const float* const* inputs, float* const* outputs,
                int numSamples, int numInputs, int numOutputs);
    
private:
    std::vector<std::array<int, 3>> speakerTriplets;  // Delaunay triangles
    ear::GainCalculator gainCalculator;
    
    void buildTriangulation();
};
```

The Fibonacci sphere speaker layout for 30.1 mode:

```cpp
std::vector<SpeakerPosition> generateFibonacciSphere(int count, float radius) {
    std::vector<SpeakerPosition> speakers;
    const float goldenRatio = (1.0f + sqrtf(5.0f)) / 2.0f;
    
    for (int i = 0; i < count; i++) {
        float theta = 2.0f * M_PI * i / goldenRatio;
        float phi = acosf(1.0f - 2.0f * (i + 0.5f) / count);
        
        speakers.push_back({
            .azimuth = theta * 180.0f / M_PI,
            .elevation = (M_PI_2 - phi) * 180.0f / M_PI,
            .distance = radius
        });
    }
    return speakers;
}
```

### 3.6 3D Visualization — Metal

The 3D SPACE tab uses **Metal** for the green-on-black wireframe rendering. This is more efficient than using a cross-platform solution like Three.js, and integrates natively with macOS.

**Vertex shader** (`SphereShaders.metal`):
```metal
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPos;
};

vertex VertexOut vertexSphere(VertexIn in [[stage_in]],
                               constant float4x4& mvp [[buffer(1)]]) {
    VertexOut out;
    out.position = mvp * float4(in.position, 1.0);
    out.worldPos = in.position;
    return out;
}

fragment float4 fragmentSphere(VertexOut in [[stage_in]],
                                constant float3& color [[buffer(2)]]) {
    // Distance fade for depth cue
    float depth = length(in.worldPos) / 4.0;
    float alpha = 1.0 - depth * 0.5;
    return float4(color, alpha);
}
```

The sphere is rendered as a **geodesic icosahedron** (3 subdivisions = 642 vertices, 1280 triangles) with line topology. Speaker cones use cone geometry, and object orbs use sphere geometry with an emissive glow post-processing pass.

### 3.7 ADM-OSC for Live Control

Sonic Sphere implements **ADM-OSC** to receive live object position data:

```swift
import CocoaAsyncSocket

class ADMOSCReceiver: NSObject, GCDAsyncUdpSocketDelegate {
    private var socket: GCDAsyncUdpSocket!
    
    func startListening(port: UInt16 = 8000) {
        socket = GCDAsyncUdpSocket(delegate: self, delegateQueue: .main)
        try? socket.bind(toPort: port)
        try? socket.beginReceiving()
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket,
                   didReceive data: Data,
                   fromAddress address: Data,
                   withFilterContext filterContext: Any?) {
        // Parse OSC message
        // /adm/obj/1/xyz fff → position update for object 1
        // /adm/obj/1/gain f → gain update
        // Apply to active project objects in real-time
    }
}
```

The ADM-OSC address space maps Sonic Sphere objects directly:
- `/adm/obj/1/xyz x y z` → Object A position (Cartesian)
- `/adm/obj/2/xyz x y z` → Object B position (Cartesian)
- `/adm/obj/1/azim elev dist a e d` → Object A position (spherical alternative)
- `/adm/obj/1/gain g` → Object A gain

This enables external controllers (TouchOSC, Lemur, custom hardware) to manipulate Sonic Sphere objects in real-time during live performance.

### 3.8 File I/O — Project Load/Save

**Save Project** (Swift):
```swift
class ProjectWriter {
    func save(project: SonicSphereProject, to url: URL) throws {
        // 1. Build ADM document via ADMBridge
        let admXML = buildADMXML(from: project)
        
        // 2. Write BW64 via libbw64 wrapper
        let writer = ADMFileWriter(path: url.path)
        
        // 3. Write interleaved 6-channel audio
        let audioData = interleaveChannels(project.bedChannels,
                                            project.objectChannels)
        
        // 4. Write chna chunk with track allocations
        let chna = buildCHNA(project: project)
        
        // 5. Write axml chunk with ADM + extensions
        writer.write(axml: admXML, chna: chna, audio: audioData)
        writer.close()
    }
    
    private func buildADMXML(from project: SonicSphereProject) -> String {
        // Generate ITU-R BS.2076 compliant XML
        // Include Sonic Sphere extensions in <extension> element
    }
}
```

### 3.9 Recommended Build Configuration

| Setting | Recommendation |
|---------|---------------|
| **macOS Target** | macOS 14.0+ (Sonoma) |
| **Swift Version** | Swift 6.0 |
| **Xcode** | Xcode 16+ |
| **Architecture** | Universal (ARM64 + x86_64) |
| **C++ Standard** | C++17 (required by libadm/libbw64) |
| **Audio Format** | 48kHz / 24-bit (broadcast standard) |
| **Buffer Size** | 512 samples (10.7ms latency at 48kHz) |
| **Code Signing** | Developer ID for distribution outside App Store |
| **Sandbox** | No (required for audio device access) |

### 3.10 External Dependencies

| Library | Version | Source | License | Purpose |
|---------|---------|--------|---------|---------|
| libadm | latest | ebu/libadm | Apache 2.0 | ADM XML parsing/writing |
| libbw64 | latest | ebu/libbw64 | Apache 2.0 | BW64 file I/O |
| libear | latest | ebu/libear | Apache 2.0 | Gain calculation |
| oscpack | 1.1.0 | ossia/oscpack | MIT | ADM-OSC protocol |
| Kiss FFT | 1.3.1 | mborgerson/kissfft | BSD | Spectrum analysis |

All EBU libraries are managed as **Git submodules** in the `ThirdParty/` directory. A CMake or Xcode build script compiles them as static libraries, which are then linked into the main application.

### 3.11 Implementation Roadmap

| Phase | Duration | Deliverables |
|-------|----------|-------------|
| **Phase 1: Foundation** | 4 weeks | Xcode project setup, C++ bridge layer, libadm/libbw64 integration, basic BW64 read/write |
| **Phase 2: Audio Engine** | 4 weeks | AVAudioEngine setup, VBAP renderer, 3 output modes (binaural/5.1/30.1), real-time playback |
| **Phase 3: 3D Visualization** | 3 weeks | Metal sphere renderer, wireframe, speaker/object meshes, camera controls, animation |
| **Phase 4: Music Tab** | 2 weeks | Channel strips, file loading, waveform display, transport controls |
| **Phase 5: Synth + Sequencer** | 3 weeks | AVAudioUnitMIDISynth integration, ADSR/filter/FX, 16-step sequencer, pattern storage |
| **Phase 6: ADM-OSC + Polish** | 2 weeks | Live OSC input, MIDI control, export to standard ADM, UI polish, performance optimization |

Total estimated development time: **18 weeks** for a functional v1.0 with a small team (2–3 developers).
