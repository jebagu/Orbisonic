# Quadraphonic to Apple Spatial Audio: Implementation Guide

## The Problem

You have a 4-channel WAV file (FL, FR, RL, RR — front-left, front-right, rear-left, rear-right) and you want to play it through AirPods as spatial audio with head tracking. The challenge: AirPods expect binaural stereo (2 channels) with embedded head-tracking metadata. You need to convert 4 discrete directional channels into a convincing 3D soundfield.

---

## Approach Overview

There are three viable paths, from simplest to most powerful:

| Approach | Quality | Head Tracking | Complexity | Best For |
|----------|---------|---------------|------------|----------|
| **AVAudioEnvironmentNode** | Good | Basic | Low | Quick implementation, macOS/iOS |
| **PHASE Framework** | Excellent | Full (6-DOF) | Medium | Production apps, precise spatial control |
| **Manual HRTF** | Customizable | None (without IMU) | High | Cross-platform, research, custom HRTFs |

For AirPods specifically, **PHASE** is the correct choice because it integrates directly with Apple's spatial audio pipeline and the AirPods' H1/H2 chip handles the final binaural rendering with full head tracking.

---

## Understanding the Input Format

### 4-Channel WAV Structure

A quadraphonic WAV file is a standard RIFF/WAVE file with 4 channels in the `fmt` chunk:

```
[RIFF header]
  <fmt-ck>
    wFormatTag: 1 (WAVE_FORMAT_PCM) or 3 (IEEE float)
    nChannels: 4
    nSamplesPerSec: 44100 or 48000
    wBitsPerSample: 16 or 24
  <data>
    Interleaved samples: [FL₀][FR₀][RL₀][RR₀][FL₁][FR₁][RL₁][RR₁]...
```

**The channel ordering problem**: WAV files with >2 channels do not have a standardized channel order in the base RIFF spec. The most common conventions are:

| Convention | Channel Order | Source |
|------------|---------------|--------|
| **WaveFormatExtensible** | FL, FR, RL, RR | Microsoft multichannel standard |
| **SMPTE/ITU** | FL, FR, FC, LFE, RL, RR... | 5.1+ layouts (quad is first 4) |
| **Pro Tools** | FL, FR, RL, RR | DAW default for quad |
| **Ambisonic B-Format** | W, X, Y, Z | Ambisonics (not quad!) |

For this implementation, assume **WaveFormatExtensible ordering: FL, FR, RL, RR** but provide a channel remapping UI.

### Quad Speaker Positions

Standard quadraphonic speaker layout (known as "Quad" or "4.0"):

| Channel | Azimuth | Elevation | Description |
|---------|---------|-----------|-------------|
| Front Left (FL) | +30° | 0° | 30° left of center, ear level |
| Front Right (FR) | -30° | 0° | 30° right of center, ear level |
| Rear Left (RL) | +110° | 0° | 110° left (slightly behind) |
| Rear Right (RR) | -110° | 0° | 110° right (slightly behind) |

(Alternative: RL/RR at ±135° for "diamond" quad layout. Make this configurable.)

---

## Approach 1: AVAudioEnvironmentNode (Simplest)

`AVAudioEnvironmentNode` is Apple's built-in 3D audio mixer. It does HRTF-based spatialization internally and outputs binaural stereo. It works on macOS 10.15+ and iOS 8+.

### How It Works

```
[4ch WAV File]
    │
    ├──→ Deinterleave into 4 mono buffers
    │
    ├──→ [AVAudioPlayerNode: FL] ──┐
    ├──→ [AVAudioPlayerNode: FR] ──┼──→ [AVAudioEnvironmentNode] ──→ [MainMixer] ──→ [OutputNode] ──→ Headphones
    ├──→ [AVAudioPlayerNode: RL] ──┤         (HRTF spatialization)        (binaural stereo)
    └──→ [AVAudioPlayerNode: RR] ──┘
```

Each player node is connected to the environment node as a separate **spatial source**. The environment node positions each source in 3D space and applies HRTF filtering.

### Swift Implementation

```swift
import AVFoundation

class QuadSpatialPlayer {
    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    private var playerNodes: [AVAudioPlayerNode] = []
    private var audioFiles: [AVAudioFile] = []
    
    // Speaker positions for standard quad layout
    private let speakerPositions: [(azimuth: Float, elevation: Float, distance: Float)] = [
        (30.0, 0.0, 1.0),   // Front Left
        (-30.0, 0.0, 1.0),  // Front Right
        (110.0, 0.0, 1.0),  // Rear Left
        (-110.0, 0.0, 1.0)  // Rear Right
    ]
    
    func setup() throws {
        // Attach environment node
        engine.attach(environment)
        
        // Connect environment to main mixer
        engine.connect(environment, to: engine.mainMixerNode, format: nil)
        
        // Create 4 player nodes, one per quad channel
        for i in 0..<4 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            
            // Connect player to environment as source at index i
            engine.connect(player, to: environment, fromBus: 0, toBus: i, format: nil)
            
            // Position this source in 3D space
            let pos = speakerPositions[i]
            environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
            
            // Convert spherical to Cartesian for environment node
            let azRad = pos.azimuth * .pi / 180
            let elRad = pos.elevation * .pi / 180
            let x = pos.distance * cos(elRad) * sin(azRad)
            let y = pos.distance * sin(elRad)
            let z = pos.distance * cos(elRad) * cos(azRad)
            
            environment.setSourcePosition(AVAudio3DPoint(x: x, y: y, z: z), forInput: i)
            environment.setSourceType(.pointSource, forInput: i)
            environment.setSourceRenderingAlgorithm(.HRTF, forInput: i)
            
            playerNodes.append(player)
        }
        
        // Set environment to headphone rendering
        environment.listenerAngularOrientation = AVAudio3DAngularOrientation(
            yaw: 0, pitch: 0, roll: 0
        )
        
        try engine.start()
    }
    
    func loadQuadFile(url: URL) throws {
        // Open the 4-channel file
        let file = try AVAudioFile(forReading: url)
        
        guard file.processingFormat.channelCount == 4 else {
            throw QuadError.notQuadraphonic("File has \(file.processingFormat.channelCount) channels, expected 4")
        }
        
        // Read entire file into buffer
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw QuadError.bufferAllocationFailed
        }
        try file.read(into: buffer)
        
        // Deinterleave: extract each channel into its own mono buffer
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: file.processingFormat.sampleRate,
            channels: 1,
            interleaved: false
        )!
        
        for channelIndex in 0..<4 {
            guard let monoBuffer = AVAudioPCMBuffer(pcmFormat: format, 
                                                     frameCapacity: buffer.frameLength) else { continue }
            
            // Copy samples from the specified channel
            let srcPtr = buffer.floatChannelData![0]  // interleaved: all data in channel 0
            let dstPtr = monoBuffer.floatChannelData![0]
            
            for frame in 0..<Int(buffer.frameLength) {
                dstPtr[frame] = srcPtr[frame * 4 + channelIndex]
            }
            monoBuffer.frameLength = buffer.frameLength
            
            // Schedule on corresponding player node
            playerNodes[channelIndex].scheduleBuffer(monoBuffer, at: nil, 
                                                       options: .loops, 
                                                       completionHandler: nil)
        }
    }
    
    func play() {
        for player in playerNodes {
            player.play()
        }
    }
    
    func stop() {
        for player in playerNodes {
            player.stop()
        }
    }
    
    enum QuadError: Error {
        case notQuadraphonic(String)
        case bufferAllocationFailed
    }
}
```

### Key Points

- `AVAudioEnvironmentNode` renders internally using HRTF. You get 3D positioning without writing convolution code.
- The output is **binaural stereo** (2 channels). AirPods receive this as standard stereo, but because it's HRTF-processed, the brain perceives it as coming from specific directions.
- Set `.HRTF` as the rendering algorithm for best spatial quality. Alternative is `.sphericalHead` (simpler, lower CPU).
- The `listenerPosition` is at the origin. All source positions are relative to this.

### Limitations of This Approach

- **No head tracking** — `AVAudioEnvironmentNode` does not integrate with AirPods' IMU sensors. The spatial image is static (rotates with your head).
- **CPU usage** — 4 HRTF convolutions running simultaneously. Manageable on modern hardware but significant.
- **No elevation** — Quadraphonic is all ear-level, so this is fine, but you can't add height.

---

## Approach 2: PHASE Framework (Best for AirPods)

**PHASE (Physical Audio Spatialization Engine)** is Apple's modern spatial audio framework, introduced in iOS 15 / macOS 12. It is the correct API for AirPods Spatial Audio because:

1. It integrates directly with the AirPods H1/H2 chip
2. It supports **full head tracking** (the AirPods' accelerometer/gyroscope feeds head orientation data back to the app)
3. It handles the HRTF rendering in the AirPods firmware, not on the host CPU
4. It supports **Audio Ray Tracing** — simulating sound bouncing off virtual walls

### How PHASE Works for Quadraphonic

```
[4ch WAV]
    │
    ├──→ Deinterleave to 4 mono streams
    │
    ├──→ [PHASESoundEvent: FL] ──┐
    ├──→ [PHASESoundEvent: FR] ──┼──→ [PHASEEngine] ──→ [PHASESource] ──→ AirPods
    ├──→ [PHASESoundEvent: RL] ──┤     (spatial mixer)      (head-tracked
    └──→ [PHASESoundEvent: RR] ──┘                         binaural output)
```

The `PHASEEngine` manages the spatial scene. Each `PHASESoundEvent` is attached to a `PHASESource` at a 3D position. The engine renders the scene to a binaural output that the AirPods process with head tracking.

### Swift Implementation (PHASE)

```swift
import PHASE
import AVFoundation

@available(macOS 12.0, iOS 15.0, *)
class QuadSpatialPHASEPlayer {
    
    private let engine: PHASEEngine
    private let source: PHASESource
    private var soundEvents: [PHASESoundEvent] = []
    private var assetRegistry: PHASEAssetRegistry {
        return engine.defaultAssetRegistry
    }
    
    // Quad speaker positions (azimuth, elevation, distance in meters)
    private let positions: [(az: Double, el: Double, dist: Double)] = [
        (30.0, 0.0, 2.0),    // Front Left
        (-30.0, 0.0, 2.0),   // Front Right
        (110.0, 0.0, 2.0),   // Rear Left
        (-110.0, 0.0, 2.0)   // Rear Right
    ]
    
    init() throws {
        // Initialize PHASE engine for headphone spatial audio
        engine = PHASEEngine(updateMode: .automatic)
        
        // Set the spatial pipeline mode for headphone rendering
        // "spatialPipeline" enables full head-tracked spatial audio
        try engine.setSpatialPipeline(options: [.spatialPipeline])
        
        // Create a single source at the listener position
        // (All 4 channels will be attached to this source as sub-mixes)
        source = PHASESource(transform: matrix_identity_double4x4)
        try engine.addSource(source)
        
        // Enable head tracking (this connects to AirPods IMU)
        engine.headphoneSpatializationMode = .automatic
    }
    
    func loadAndPlay(quadFileURL: URL) throws {
        // Load 4-channel file and deinterleave
        let file = try AVAudioFile(forReading: quadFileURL)
        
        guard file.processingFormat.channelCount == 4 else {
            throw NSError(domain: "QuadPlayer", code: 1)
        }
        
        // Read interleaved buffer
        let buffer = try readInterleavedBuffer(from: file)
        
        // For each channel, create a PHASE sound event at the quad position
        for channelIndex in 0..<4 {
            
            // Extract mono audio for this channel
            let monoURL = try extractChannel(buffer, channelIndex: channelIndex,
                                               sampleRate: file.processingFormat.sampleRate)
            
            // Register audio asset
            let audioAsset = PHASEAsset(identifier: "quad_ch\(channelIndex)",
                                         url: monoURL,
                                         assetType: .sound,
                                         channelLayout: nil,
                                         mixerParameters: nil)
            assetRegistry.registerAsset(audioAsset)
            
            // Create spatial pipeline for this source
            let spatialPipeline = PHASESpatialPipeline(flags: [.directPathTransmission])
            spatialPipeline.entries[.directPathTransmission]?.gain = 1.0
            
            // Create spatial mixer with distance attenuation
            let mixer = PHASESpatialMixerDefinition(spatialPipeline: spatialPipeline)
            
            // Set the source's directivity (omnidirectional speaker)
            let sourceDirectivity = PHASECardioidDirectivitySubbandParameters()
            sourceDirectivity.cardioidFactor = 0.0  // omnidirectional
            mixer.addDirectivity(sourceDirectivityParameters: sourceDirectivity,
                                 identifier: nil)
            
            // Create sound event
            let soundEvent = PHASESoundEvent(eventIdentifier: "quad_event_\(channelIndex)",
                                              source: source,
                                              assetIdentifier: "quad_ch\(channelIndex)",
                                              mixerDefinition: mixer,
                                              completionHandler: nil)
            
            // Position this sound event at the quad speaker location
            let pos = positions[channelIndex]
            let azRad = pos.az * .pi / 180
            let elRad = pos.el * .pi / 180
            let x = pos.dist * cos(elRad) * sin(azRad)
            let y = pos.dist * sin(elRad)
            let z = pos.dist * cos(elRad) * cos(azRad)
            
            var transform = matrix_identity_double4x4
            transform.columns.3 = SIMD4(x, y, z, 1.0)
            soundEvent.source.transform = transform
            
            soundEvents.append(soundEvent)
        }
        
        // Start all sound events simultaneously
        for event in soundEvents {
            try event.start()
        }
        
        // Start the engine render loop
        try engine.start()
    }
    
    func enableHeadTracking() {
        // PHASE automatically uses AirPods IMU data when available
        // The engine.headphoneSpatializationMode = .automatic handles this
        // Head orientation updates are delivered via CoreMotion + CoreBluetooth
        
        // For custom head tracking integration:
        // CMHeadphoneMotionManager provides AirPods motion data
        let motionManager = CMHeadphoneMotionManager()
        motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
            guard let motion = motion else { return }
            
            // motion.attitude contains roll, pitch, yaw
            // This is automatically fed to PHASE when using .automatic mode
            // But you can read it for visualization:
            let yaw = motion.attitude.yaw * 180 / .pi
            let pitch = motion.attitude.pitch * 180 / .pi
            let roll = motion.attitude.roll * 180 / .pi
            print("Head orientation: yaw=\(yaw)°, pitch=\(pitch)°, roll=\(roll)°")
        }
    }
    
    func stop() {
        for event in soundEvents {
            event.stop()
        }
        engine.stop()
    }
    
    // Helper: read interleaved 4ch buffer
    private func readInterleavedBuffer(from file: AVAudioFile) throws -> AVAudioPCMBuffer {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                             frameCapacity: AVAudioFrameCount(file.length)) else {
            throw NSError(domain: "QuadPlayer", code: 2)
        }
        try file.read(into: buffer)
        return buffer
    }
    
    // Helper: extract single channel to temp mono file
    private func extractChannel(_ buffer: AVAudioPCMBuffer, 
                                channelIndex: Int,
                                sampleRate: Double) throws -> URL {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                    sampleRate: sampleRate,
                                    channels: 1,
                                    interleaved: false)!
        guard let mono = AVAudioPCMBuffer(pcmFormat: format,
                                          frameCapacity: buffer.frameLength) else {
            throw NSError(domain: "QuadPlayer", code: 3)
        }
        
        let src = buffer.floatChannelData![0]  // interleaved
        let dst = mono.floatChannelData![0]     // non-interleaved mono
        
        for i in 0..<Int(buffer.frameLength) {
            dst[i] = src[i * 4 + channelIndex]
        }
        mono.frameLength = buffer.frameLength
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("quad_ch\(channelIndex).wav")
        let outFile = try AVAudioFile(forWriting: url, settings: format.settings)
        try outFile.write(from: mono)
        return url
    }
}
```

### Key Differences from AVAudioEnvironmentNode

| Feature | AVAudioEnvironmentNode | PHASE |
|---------|----------------------|-------|
| Head tracking | No | Yes (AirPods IMU) |
| HRTF rendering | On host CPU | In AirPods firmware |
| CPU usage | Higher (4× HRTF convolutions) | Lower (offloaded to AirPods) |
| Audio ray tracing | No | Yes |
| macOS version | 10.15+ | 12.0+ |
| API complexity | Lower | Higher |
| Per-source reverb | Yes (built-in) | Yes (customizable) |

---

## Approach 3: Manual HRTF (Cross-Platform)

If you need this to work on non-Apple platforms, or want complete control over the HRTF, implement the binaural renderer manually.

### The Algorithm

For each audio sample, for each of the 4 quad channels:

1. **Determine the direction** from listener to the virtual speaker (from the azimuth/elevation table above).
2. **Look up the HRTF** — a pair of FIR filters (left ear, right ear) for that direction. The HRTF encodes how sound from that direction is filtered by the listener's head, pinna, and torso before reaching each ear.
3. **Convolve** the channel's audio sample with both HRTF filters.
4. **Sum all contributions** — add all left-ear convolutions to the left output, all right-ear convolutions to the right output.

### HRTF Databases (Free)

| Database | Measurements | Sample Rate | License |
|----------|-------------|-------------|---------|
| **MIT KEMAR** | 710 directions | 44.1kHz | Free (CIPIC) |
| **IRCAM Listen** | 187 directions | 44.1kHz | Free for research |
| **SADIE II** | 2330 directions | 48kHz | Free (Creative Commons) |
| **SONICOM** | ~1500 directions | 48kHz | Free (EU project) |

### Minimal Implementation (Python/NumPy for illustration)

```python
import numpy as np
from scipy.signal import fftconvolve
import wave
import struct

# Load HRTF (simplified — real implementation uses .sofa files)
def load_hrtf(azimuth, elevation, hrtf_database):
    """Return left and right HRTF filters for a given direction."""
    nearest = find_nearest_measurement(azimuth, elevation, hrtf_database)
    return nearest['left_filter'], nearest['right_filter']

# Quad speaker positions
QUAD_POSITIONS = [
    (30, 0),    # FL
    (-30, 0),   # FR
    (110, 0),   # RL
    (-110, 0),  # RR
]

def render_quad_to_binaural(input_file, output_file, hrtf_db):
    # Read 4-channel WAV
    with wave.open(input_file, 'rb') as wf:
        nchannels = wf.getnchannels()
        assert nchannels == 4, f"Expected 4 channels, got {nchannels}"
        samplerate = wf.getframerate()
        nframes = wf.getnframes()
        raw = wf.readframes(nframes)
        samples = np.array(struct.unpack(f'{nframes * 4}h', raw), dtype=np.float32)
        interleaved = samples.reshape(-1, 4)  # [FL, FR, RL, RR] per frame
    
    # Deinterleave
    channels = [interleaved[:, i] for i in range(4)]
    
    # Load HRTFs for all 4 quad positions
    hrtfs = []
    for az, el in QUAD_POSITIONS:
        h_left, h_right = load_hrtf(az, el, hrtf_db)
        hrtfs.append((h_left, h_right))
    
    # Convolve each channel with its HRTF pair
    left_out = np.zeros(len(channels[0]) + len(hrtfs[0][0]) - 1)
    right_out = np.zeros(len(channels[0]) + len(hrtfs[0][1]) - 1)
    
    for i, ch in enumerate(channels):
        h_left, h_right = hrtfs[i]
        left_out += fftconvolve(ch, h_left, mode='full')
        right_out += fftconvolve(ch, h_right, mode='full')
    
    # Trim to original length and normalize
    length = len(channels[0])
    left_out = left_out[:length]
    right_out = right_out[:length]
    
    # Normalize to prevent clipping
    max_val = max(np.max(np.abs(left_out)), np.max(np.abs(right_out)))
    if max_val > 32767:
        left_out *= 32767 / max_val
        right_out *= 32767 / max_val
    
    # Interleave to stereo and write output WAV
    stereo = np.stack([left_out, right_out], axis=1).flatten().astype(np.int16)
    
    with wave.open(output_file, 'wb') as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(samplerate)
        wf.writeframes(stereo.tobytes())

# Usage
render_quad_to_binaural('input_quad.wav', 'output_binaural.wav', hrtf_database)
```

### To Add Head Tracking (Without AirPods)

For manual head tracking, you need a head orientation sensor:

1. **Read IMU data** from a connected device (iPhone as sensor via SensorLog app, or a dedicated IMU like Bosch BNO055).
2. **Compute head rotation matrix** from quaternion or Euler angles.
3. **Rotate all source positions** by the inverse head rotation (sources move opposite to head movement).
4. **Recompute HRTFs** for the new source directions each frame (or use a fast interpolation between precomputed HRTF directions).
5. **Re-convolve** with the updated HRTFs.

At 48kHz with 512-sample blocks, you have ~10.7ms to do this. Precomputing HRTF lookup tables and using FFT-based fast convolution is essential.

---

## Complete Recommended Architecture (macOS, AirPods)

For the best AirPods experience, combine the strengths of both Apple APIs:

```
┌─────────────────────────────────────────────────────────────────┐
│                          macOS App                               │
│                                                                  │
│  ┌──────────────┐  ┌──────────────────────────────────────┐     │
│  │  File Reader │  │           Audio Pipeline             │     │
│  │              │  │                                      │     │
│  │  libbw64 /   │  │  ┌─────────┐    ┌──────────────┐   │     │
│  │  AVAudioFile │  │  │Deinter- │    │  PHASEEngine │   │     │
│  │              │──┼─→│ leave 4 │───→│              │   │     │
│  │  Read 4ch    │  │  │ channels│    │  ┌────────┐  │   │     │
│  │  WAV         │  │  └─────────┘    │  │Source 1│ (FL)│     │
│  └──────────────┘  │                 │  │Source 2│ (FR)│     │
│                    │                 │  │Source 3│ (RL)│     │
│  ┌──────────────┐  │                 │  │Source 4│ (RR)│     │
│  │ Head Tracking│  │                 │  └────────┘  │   │     │
│  │              │  │                 │              │   │     │
│  │ CMHeadphone  │──┼────────────────→│  Head-tracked│   │     │
│  │ MotionManager│  │                 │  binaural mix│   │     │
│  └──────────────┘  │                 └──────┬───────┘   │     │
│                    │                        │            │     │
│  ┌──────────────┐  │                 ┌──────┴──────┐    │     │
│  │    3D UI     │  │                 │  AVAudioSink │    │     │
│  │   (Metal)    │  │                 │  (2ch output)│    │     │
│  │              │  │                 └──────┬──────┘    │     │
│  │  Visualize   │  │                        │            │     │
│  │  speaker/    │  │                 ┌──────┴──────┐    │     │
│  │  head pos    │  │                 │   AirPods    │    │     │
│  └──────────────┘  │                 │  (HRTF +     │    │     │
│                    │                 │   head track)│    │     │
│                    │                 └──────────────┘    │     │
│                    └──────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

### Key Integration Points

1. **PHASEEngine** handles all spatial rendering and sends 2ch binaural to the audio output.
2. **CMHeadphoneMotionManager** reads AirPods head orientation and feeds it to PHASE automatically (when `headphoneSpatializationMode = .automatic`).
3. **AVAudioFile** reads and deinterleaves the 4-channel WAV.
4. **Metal view** (optional) shows a 3D visualization of the quad speakers and head orientation for user feedback.

### Build Settings

| Setting | Value |
|---------|-------|
| macOS Deployment Target | 12.0+ (Monterey) |
| Frameworks | PHASE, AVFoundation, CoreMotion |
| AirPods Requirement | AirPods Pro / AirPods Max / AirPods (3rd gen) or later |
| Audio Format | 48kHz / 24-bit (convert 44.1kHz on load if needed) |
| Buffer Size | 512 samples (10.7ms latency) |

---

## Summary: Which Approach to Use

| Goal | Use This |
|------|----------|
| Quick prototype / macOS app | **AVAudioEnvironmentNode** |
| Best AirPods experience with head tracking | **PHASE** |
| Cross-platform (Linux, Windows) | **Manual HRTF** |
| Lowest CPU usage on Mac | **PHASE** (offloads to AirPods) |
| Full control over spatialization | **Manual HRTF** |

For a production app targeting AirPods, **PHASE is the only choice** that gives you full head-tracked spatial audio. The AVAudioEnvironmentNode approach works and sounds good, but the spatial image rotates with your head — it doesn't feel "stuck in the room" the way true AirPods Spatial Audio does.
