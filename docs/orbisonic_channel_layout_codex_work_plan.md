# Orbisonic Channel Layout Work Plan for Codex

## Purpose

Orbisonic currently has evidence of a channel-order bug when handling VLC-originated surround audio. The immediate confirmed example is VLC WG4 5.1, where center and LFE are not at indices `2` and `3`; they are later in the interleaved buffer. This work plan generalizes the fix so Orbisonic no longer interprets multichannel audio by channel count alone.

The goal is to create a centralized channel-layout layer that resolves input channels into semantic roles before any Orbisonic downmixing, spatialization, binauralization, or rendering happens.

## Current Decision

For this implementation phase, ambiguous or unknown multichannel layouts must be treated as an error.

Do **not** silently guess.
Do **not** show a custom popup yet.
Do **not** create a JSON sidecar file yet.
Do **not** add a channel-layout mapper UI yet.

Future work may add:

- a channel-layout mapper UI;
- a JSON sidecar file format for per-song layout overrides;
- metadata-based channel-layout overrides;
- a user-facing repair workflow for ambiguous files.

For now, if the layout cannot be resolved with adequate confidence, Orbisonic must flag it as an error and avoid applying the surround renderer to incorrectly mapped audio.

---

# 1. Core Problem Statement

Orbisonic must support many multichannel layouts and backend conventions, including but not limited to:

- VLC internal WG4 order;
- SMPTE/FFmpeg-style order;
- WAVEFORMATEXTENSIBLE speaker masks;
- Core Audio / AVFoundation layout tags;
- stereo and mono sources;
- 5.1 rear;
- 5.1 side;
- 7.1 variants;
- unknown or malformed channel layouts.

The old approach is unsafe:

```text
6 channels detected
therefore index 2 = center
therefore index 3 = LFE
```

This is wrong for VLC-originated 5.1 WG4 buffers.

The correct approach is:

```text
backend/source metadata
        ↓
source-specific channel layout resolver
        ↓
canonical Orbisonic semantic channel map
        ↓
Orbisonic renderer/downmixer
```

The renderer should consume semantic roles, not raw numeric channel assumptions.

---

# 2. Non-Negotiable Rules

1. Orbisonic must never infer surround channel meaning from channel count alone.

2. Fixed-index assumptions such as these must be removed, quarantined, or explicitly labeled as source-specific:

   ```swift
   center = input[2]
   lfe = input[3]
   surroundLeft = input[4]
   surroundRight = input[5]
   ```

3. VLC-originated audio must use VLC WG4 channel order and the VLC physical channel mask when available.

4. If VLC-originated six-channel audio has no mask, do not use the old SMPTE assumption. Either:

   - resolve through a known VLC callback/setup path that proves WG4 order, or
   - mark the layout as ambiguous/error until the runtime path is proven.

5. Unknown or ambiguous multichannel layouts must be flagged as errors for now.

6. Stereo and mono should still work without unnecessary failure.

7. The final live audio path must log the resolved layout clearly enough that a channel-ID test file can prove whether the mapping is correct.

---

# 3. Terminology

## Channel Count

The number of channels in the buffer.

Examples:

```text
1 channel
2 channels
6 channels
8 channels
```

Channel count alone does not define channel meaning.

## Channel Layout

The semantic speaker arrangement.

Examples:

```text
mono
stereo
5.1 rear
5.1 side
7.1 rear
7.1 wide
unknown/custom
```

## Channel Order

The order in which the channels appear in an interleaved buffer.

Examples:

```text
SMPTE/FFmpeg-style 5.1:
    L, R, C, LFE, SL/BL, SR/BR

VLC WG4 5.1 rear:
    L, R, REAR_LEFT, REAR_RIGHT, C, LFE

VLC WG4 5.1 side/middle:
    L, R, MIDDLE_LEFT, MIDDLE_RIGHT, C, LFE
```

## Semantic Role

The actual meaning of a channel.

Examples:

```text
left
right
center
lfe
sideLeft
sideRight
rearLeft
rearRight
rearCenter
unknown
```

---

# 4. Implementation Overview

Create a new centralized channel-layout subsystem.

Suggested location:

```text
Sources/OrbisonicCore/ChannelLayout/
```

or, if the repo structure suggests another better location:

```text
Sources/Orbisonic/ChannelLayout/
```

The subsystem should contain:

```text
OrbisonicChannelRole
OrbisonicChannelLayoutSource
OrbisonicChannelLayoutConfidence
OrbisonicChannelLayoutDescriptor
OrbisonicChannelLayoutResolver
OrbisonicChannelLayoutError
VLCChannelLayoutResolver
SMPTEChannelLayoutResolver
WaveExtensibleChannelLayoutResolver, if applicable
CoreAudioChannelLayoutResolver, if applicable
ChannelLayoutDiagnostics
```

The exact file names can vary if the project structure requires it, but the concepts should remain centralized.

---

# 5. Phase 0 — Baseline Investigation

## Goal

Before refactoring, identify every current place where Orbisonic interprets multichannel samples by numeric index.

## Tasks

Search the repo for:

```text
channelCount
channels
numChannels
i_channels
i_physical_channels
physicalChannelMask
layoutTag
surround
5.1
7.1
center
lfe
rear
side
middle
left
right
downmix
binaural
render
processAudio
PCM
interleaved
AVAudioPCMBuffer
AudioBufferList
floatChannelData
mData
VlcLivePCMDownmixPrototype
OrbisonicVLCReference
```

Search specifically for suspicious fixed-index access:

```text
[2]
[3]
[4]
[5]
channel == 2
channel == 3
channel == 4
channel == 5
frameIndex * channelCount + 2
frameIndex * channelCount + 3
frameIndex * channelCount + 4
frameIndex * channelCount + 5
```

## Deliverable

Create an inventory in the Codex response:

```text
File/function:
    current behavior:
    suspected source convention:
    safe/unsafe:
    action needed:
```

Do not change renderer tuning in this phase.

---

# 6. Phase 1 — Define Canonical Channel Roles

## Goal

Create a semantic role model that can represent common channel layouts without relying on raw indices.

## Proposed Swift Model

```swift
public enum OrbisonicChannelRole: Equatable, Hashable, Codable, Sendable {
    case mono
    case left
    case right
    case center
    case lfe
    case sideLeft
    case sideRight
    case rearLeft
    case rearRight
    case rearCenter
    case frontLeftOfCenter
    case frontRightOfCenter
    case topLeft
    case topRight
    case topCenter
    case topRearLeft
    case topRearRight
    case unknown(Int)
}
```

If the existing project does not use `Sendable` or `Codable`, omit those conformances.

## Notes

- `mono` and `center` should be treated intentionally.
- Do not map mono to left-only.
- Do not collapse side and rear roles too early.
- The renderer/downmixer can decide how to use side/rear roles later.

## Acceptance Criteria

- Roles are defined once in a central location.
- Existing code can ask for semantic roles without knowing backend-specific channel order.

---

# 7. Phase 2 — Define Layout Source, Confidence, and Error Types

## Goal

Every resolved layout should say where it came from and how trustworthy it is.

## Proposed Models

```swift
public enum OrbisonicChannelLayoutSource: Equatable, Codable, Sendable {
    case vlc
    case ffmpeg
    case smpte
    case waveExtensible
    case coreAudio
    case avFoundation
    case manual
    case unknown
}
```

```swift
public enum OrbisonicChannelLayoutConfidence: Equatable, Codable, Sendable {
    case exact
    case inferred
    case fallback
    case ambiguous
    case unknown
}
```

```swift
public enum OrbisonicChannelLayoutError: Error, Equatable {
    case invalidChannelCount(Int)
    case missingRequiredLayoutMetadata(source: OrbisonicChannelLayoutSource, channelCount: Int)
    case ambiguousLayout(source: OrbisonicChannelLayoutSource, channelCount: Int, reason: String)
    case unsupportedLayout(source: OrbisonicChannelLayoutSource, channelCount: Int, reason: String)
    case duplicateRole(OrbisonicChannelRole)
    case missingRequiredRole(OrbisonicChannelRole)
}
```

## Acceptance Criteria

- Ambiguous layouts can be represented distinctly from exact layouts.
- Unknown multichannel layouts can fail cleanly.
- Error messages are specific enough to diagnose the issue.

---

# 8. Phase 3 — Define the Layout Descriptor

## Goal

Create a single object that represents how a source buffer's numeric indices map to semantic channel roles.

## Proposed Model

```swift
public struct OrbisonicChannelLayoutDescriptor: Equatable, Codable, Sendable {
    public let source: OrbisonicChannelLayoutSource
    public let channelCount: Int
    public let physicalChannelMask: UInt32?
    public let layoutTag: UInt32?
    public let rolesByIndex: [OrbisonicChannelRole]
    public let confidence: OrbisonicChannelLayoutConfidence
    public let notes: [String]

    public func index(of role: OrbisonicChannelRole) -> Int? {
        rolesByIndex.firstIndex(of: role)
    }

    public func firstIndex(ofAny roles: [OrbisonicChannelRole]) -> Int? {
        for role in roles {
            if let index = index(of: role) {
                return index
            }
        }
        return nil
    }
}
```

## Validation Rules

Add a validation method or initializer checks:

```swift
rolesByIndex.count == channelCount
no duplicate concrete roles unless explicitly allowed
unknown roles are allowed only if the layout is not exact
exact layouts should not contain unknown roles
```

## Acceptance Criteria

- Every audio path can carry a descriptor.
- The descriptor is the only accepted way to map index to semantic meaning.
- Renderer/downmixer code can retrieve center, LFE, side, rear, left, and right semantically.

---

# 9. Phase 4 — Add Source-Specific Resolvers

## Goal

Implement resolvers that convert source/backend metadata into `OrbisonicChannelLayoutDescriptor`.

## Proposed Protocol

```swift
public protocol OrbisonicChannelLayoutResolving {
    func resolveChannelLayout(
        channelCount: Int,
        physicalChannelMask: UInt32?,
        layoutTag: UInt32?
    ) throws -> OrbisonicChannelLayoutDescriptor
}
```

This signature can be adjusted to fit the repo, but the resolver must receive enough metadata to avoid count-only guesses.

---

# 10. Phase 4A — VLC WG4 Resolver

## Goal

Implement VLC's internal WG4 channel ordering as a source-specific resolver.

## Required VLC WG4 Order

The VLC order to model is:

```text
LEFT
RIGHT
MIDDLELEFT
MIDDLERIGHT
REARLEFT
REARRIGHT
REARCENTER
CENTER
LFE
```

Map this to Orbisonic roles:

```text
AOUT_CHAN_LEFT        -> left
AOUT_CHAN_RIGHT       -> right
AOUT_CHAN_MIDDLELEFT  -> sideLeft
AOUT_CHAN_MIDDLERIGHT -> sideRight
AOUT_CHAN_REARLEFT    -> rearLeft
AOUT_CHAN_REARRIGHT   -> rearRight
AOUT_CHAN_REARCENTER  -> rearCenter
AOUT_CHAN_CENTER      -> center
AOUT_CHAN_LFE         -> lfe
```

## Required Behavior

Given a VLC physical channel mask, walk the WG4 order and include only roles present in the mask.

Pseudo-code:

```swift
func resolveVLC(channelCount: Int, mask: UInt32?) throws -> OrbisonicChannelLayoutDescriptor {
    guard let mask else {
        if channelCount <= 2 {
            return resolveSimpleMonoOrStereo(channelCount)
        }

        throw OrbisonicChannelLayoutError.missingRequiredLayoutMetadata(
            source: .vlc,
            channelCount: channelCount
        )
    }

    var roles: [OrbisonicChannelRole] = []

    for entry in vlcWG4Order {
        if maskContains(mask, entry.bit) {
            roles.append(entry.role)
        }
    }

    guard roles.count == channelCount else {
        throw OrbisonicChannelLayoutError.ambiguousLayout(
            source: .vlc,
            channelCount: channelCount,
            reason: "VLC physical mask produced \(roles.count) roles, but buffer has \(channelCount) channels."
        )
    }

    return OrbisonicChannelLayoutDescriptor(
        source: .vlc,
        channelCount: channelCount,
        physicalChannelMask: mask,
        layoutTag: nil,
        rolesByIndex: roles,
        confidence: .exact,
        notes: []
    )
}
```

## Important Policy

For this phase, do **not** silently assume VLC no-mask six-channel order.

Earlier investigation suggested a possible VLC no-mask six-channel fallback, but the current product decision is stricter:

```text
No mask + multichannel VLC input = error for now.
```

This prevents accidentally shipping another incorrect mapping.

## Must-Pass Cases

```text
VLC rear 5.1 mask 0x1067:
    index 0 = left
    index 1 = right
    index 2 = rearLeft
    index 3 = rearRight
    index 4 = center
    index 5 = lfe

VLC side/middle 5.1 mask 0x1307:
    index 0 = left
    index 1 = right
    index 2 = sideLeft
    index 3 = sideRight
    index 4 = center
    index 5 = lfe
```

---

# 11. Phase 4B — SMPTE / FFmpeg-Style Resolver

## Goal

Support sources that explicitly provide SMPTE/FFmpeg-style order.

## Typical 5.1 Order

```text
index 0 = left
index 1 = right
index 2 = center
index 3 = lfe
index 4 = sideLeft or rearLeft, depending on explicit layout
index 5 = sideRight or rearRight, depending on explicit layout
```

## Required Behavior

This resolver may only be used when the source path proves the data is SMPTE/FFmpeg-style.

Do not use this resolver for VLC-originated data.

## Acceptance Criteria

- SMPTE/FFmpeg 5.1 tests pass.
- The resolver is impossible to accidentally use for `.vlc` source data.
- Side vs rear remains explicit when possible.

---

# 12. Phase 4C — WAVEFORMATEXTENSIBLE Resolver, If Applicable

## Goal

If the repo reads WAV or WAVEFORMATEXTENSIBLE data directly, resolve channel roles from the speaker mask.

## Required Behavior

Use the WAVE speaker mask to assign semantic roles.

Do not infer from channel count if the WAVE file claims to be extensible but does not provide a valid mask.

## Acceptance Criteria

- Valid WAVE masks produce exact layouts.
- Missing or inconsistent WAVE masks throw layout errors.
- No silent fallback for unknown multichannel WAVE layouts.

---

# 13. Phase 4D — Core Audio / AVFoundation Resolver, If Applicable

## Goal

If the repo receives `AudioChannelLayout`, layout tags, or AVFoundation channel layout metadata, use that metadata to resolve roles.

## Required Behavior

Prefer explicit layout tags or channel descriptions.

If the layout tag is missing for multichannel input, flag as error unless another trusted source-specific resolver applies.

## Acceptance Criteria

- Known Core Audio stereo/mono layouts work.
- Known Core Audio 5.1/7.1 layouts resolve semantically.
- Unknown multichannel Core Audio layouts are errors.

---

# 14. Phase 5 — Add a Central Resolution Entry Point

## Goal

Provide one API that all audio ingestion paths call before rendering.

## Proposed API

```swift
public struct OrbisonicChannelLayoutResolver {
    public static func resolve(
        source: OrbisonicChannelLayoutSource,
        channelCount: Int,
        physicalChannelMask: UInt32? = nil,
        layoutTag: UInt32? = nil
    ) throws -> OrbisonicChannelLayoutDescriptor {
        switch source {
        case .vlc:
            return try VLCChannelLayoutResolver().resolveChannelLayout(
                channelCount: channelCount,
                physicalChannelMask: physicalChannelMask,
                layoutTag: layoutTag
            )
        case .smpte, .ffmpeg:
            return try SMPTEChannelLayoutResolver().resolveChannelLayout(
                channelCount: channelCount,
                physicalChannelMask: physicalChannelMask,
                layoutTag: layoutTag
            )
        case .waveExtensible:
            return try WaveExtensibleChannelLayoutResolver().resolveChannelLayout(
                channelCount: channelCount,
                physicalChannelMask: physicalChannelMask,
                layoutTag: layoutTag
            )
        case .coreAudio, .avFoundation:
            return try CoreAudioChannelLayoutResolver().resolveChannelLayout(
                channelCount: channelCount,
                physicalChannelMask: physicalChannelMask,
                layoutTag: layoutTag
            )
        case .manual:
            throw OrbisonicChannelLayoutError.unsupportedLayout(
                source: source,
                channelCount: channelCount,
                reason: "Manual channel layout mapping is future work."
            )
        case .unknown:
            if channelCount <= 2 {
                return try SimpleChannelLayoutResolver().resolveChannelLayout(
                    channelCount: channelCount,
                    physicalChannelMask: nil,
                    layoutTag: nil
                )
            }
            throw OrbisonicChannelLayoutError.missingRequiredLayoutMetadata(
                source: source,
                channelCount: channelCount
            )
        }
    }
}
```

## Acceptance Criteria

- Every live audio path goes through this central resolver.
- Unknown multichannel input fails before reaching the surround renderer.
- Mono/stereo continue to work.

---

# 15. Phase 6 — Replace Fixed-Index Extraction

## Goal

Remove direct fixed-index semantic assumptions from downmixing, rendering, and diagnostics.

## Before

```swift
let left = frame[0]
let right = frame[1]
let center = frame[2]
let lfe = frame[3]
let surroundLeft = frame[4]
let surroundRight = frame[5]
```

## After

```swift
let leftIndex = layout.index(of: .left)
let rightIndex = layout.index(of: .right)
let centerIndex = layout.index(of: .center)
let lfeIndex = layout.index(of: .lfe)
let sideLeftIndex = layout.index(of: .sideLeft)
let sideRightIndex = layout.index(of: .sideRight)
let rearLeftIndex = layout.index(of: .rearLeft)
let rearRightIndex = layout.index(of: .rearRight)
```

Then use semantic accessors.

Example:

```swift
let surroundLeftIndex = layout.firstIndex(ofAny: [.sideLeft, .rearLeft])
let surroundRightIndex = layout.firstIndex(ofAny: [.sideRight, .rearRight])
```

## Important

Do not collapse side and rear into a single permanent role inside the layout descriptor. It is acceptable for the renderer/downmixer to choose a preferred role at the point of rendering.

## Acceptance Criteria

- No VLC-originated path uses `input[2]` as center by assumption.
- No VLC-originated path uses `input[3]` as LFE by assumption.
- Any remaining fixed-index logic is explicitly source-specific and tested.

---

# 16. Phase 7 — Live Playback Path Integration

## Goal

Ensure the real live playback path uses the new layout resolver, not only the reference/prototype path.

## Tasks

Trace and update every live audio ingestion path:

```text
libVLC callbacks
VLCMediaPlayer paths
PCM callback handlers
AVAudioPCMBuffer paths
AudioBufferList paths
Orbisonic render/process paths
```

At the point where audio first enters Orbisonic, create or require a layout descriptor.

## Required Data To Capture

```text
source/backend
sample rate
sample format
channel count
physical channel mask, if available
layout tag, if available
resolved rolesByIndex
confidence
```

## Error Behavior

If the source is multichannel and no exact/inferred layout can be resolved:

```text
raise/return OrbisonicChannelLayoutError
set playback/render state to channel-layout error
avoid surround rendering with guessed mapping
log the error clearly
```

No custom popup in this phase.

The app may surface the error through its existing error mechanism if one already exists.

## Acceptance Criteria

- Actual surround playback uses the new descriptor.
- The prototype/reference path and the live path are not confused.
- Logs clearly identify which path is active.

---

# 17. Phase 8 — Diagnostics and Logging

## Goal

Make layout mistakes immediately visible during test playback.

## Add Log At Layout Resolution

Log this once per playback item or when the audio format changes:

```text
ORBISONIC CHANNEL LAYOUT RESOLVED
source: VLC
sampleRate: 48000
channels: 6
physicalMask: 0x1067
layoutTag: nil
confidence: exact
index 0: left
index 1: right
index 2: rearLeft
index 3: rearRight
index 4: center
index 5: lfe
centerIndex: 4
lfeIndex: 5
```

## Add Error Log For Ambiguous Layouts

```text
ORBISONIC CHANNEL LAYOUT ERROR
source: VLC
channels: 6
physicalMask: nil
layoutTag: nil
reason: missing required layout metadata for multichannel VLC input
result: surround rendering disabled for this item
futureWork: channel layout mapper / JSON sidecar override
```

## Add Warning For Any Quarantined Fixed-Index Path

```text
ORBISONIC CHANNEL LAYOUT WARNING
source: SMPTE
mappingMode: explicit SMPTE fixed-order resolver
reason: source path explicitly identifies SMPTE/FFmpeg order
```

## Acceptance Criteria

- Logs distinguish exact, inferred, fallback, ambiguous, and error states.
- Logs make it obvious whether VLC 5.1 center is index `4`, not index `2`.
- Logs make it impossible to confuse the reference path with the real live path.

---

# 18. Phase 9 — Optional RMS Diagnostic Mode

## Goal

Add a temporary or debug-only RMS diagnostic that makes channel-ID files easy to verify.

## Behavior

For the first few seconds of playback, compute per-channel RMS and log index plus semantic role.

Example:

```text
ORBISONIC LIVE INPUT RMS
index 0, semantic left:      -60.0 dB
index 1, semantic right:     -60.0 dB
index 2, semantic rearLeft:  -60.0 dB
index 3, semantic rearRight: -60.0 dB
index 4, semantic center:    -12.1 dB
index 5, semantic lfe:       -60.0 dB
```

## Requirements

- Keep this diagnostic off by default if it is noisy.
- Enable with a debug flag, environment variable, build setting, or temporary development flag.
- Do not affect audio output.

## Acceptance Criteria

- A 5.1 channel-ID test file proves where each channel lands.
- Center tone appears at semantic center.
- LFE tone appears at semantic LFE.

---

# 19. Phase 10 — Tests

## Goal

Add focused tests that prevent this class of bug from coming back.

## Required Tests

### VLC Rear 5.1

Input:

```text
source: VLC
channelCount: 6
physicalMask: 0x1067
```

Expected:

```text
index 0 = left
index 1 = right
index 2 = rearLeft
index 3 = rearRight
index 4 = center
index 5 = lfe
```

### VLC Side/Middle 5.1

Input:

```text
source: VLC
channelCount: 6
physicalMask: 0x1307
```

Expected:

```text
index 0 = left
index 1 = right
index 2 = sideLeft
index 3 = sideRight
index 4 = center
index 5 = lfe
```

### VLC Multichannel Without Mask

Input:

```text
source: VLC
channelCount: 6
physicalMask: nil
```

Expected:

```text
throws OrbisonicChannelLayoutError.missingRequiredLayoutMetadata
```

### SMPTE/FFmpeg 5.1

Input:

```text
source: SMPTE or FFmpeg
channelCount: 6
explicit layout: 5.1 side or 5.1 rear
```

Expected side layout:

```text
index 0 = left
index 1 = right
index 2 = center
index 3 = lfe
index 4 = sideLeft
index 5 = sideRight
```

Expected rear layout:

```text
index 0 = left
index 1 = right
index 2 = center
index 3 = lfe
index 4 = rearLeft
index 5 = rearRight
```

### Stereo

Input:

```text
channelCount: 2
```

Expected:

```text
index 0 = left
index 1 = right
```

### Mono

Input:

```text
channelCount: 1
```

Expected:

```text
index 0 = mono
```

or, if renderer policy requires it:

```text
index 0 = center
```

Choose one policy and document it. Do not treat mono as left-only.

### Unknown Six-Channel

Input:

```text
source: unknown
channelCount: 6
physicalMask: nil
layoutTag: nil
```

Expected:

```text
throws OrbisonicChannelLayoutError.missingRequiredLayoutMetadata
```

## Acceptance Criteria

- Tests fail if center/LFE regress to indices `2` and `3` for VLC WG4 5.1.
- Tests pass for stereo and mono.
- Unknown multichannel input fails intentionally.

---

# 20. Phase 11 — Error Surfacing

## Goal

Flag ambiguous channel layouts as errors without adding the future mapper UI yet.

## Required Behavior

When layout resolution fails for multichannel input:

1. Stop or bypass surround rendering for that item.
2. Set a clear internal error state.
3. Log the failure.
4. Use the app's existing error display mechanism if available.
5. Do not create a JSON sidecar file.
6. Do not offer a mapper UI yet.

## Suggested User-Facing Error Text

```text
Orbisonic could not determine the channel layout for this multichannel audio file, so surround processing was not applied. This prevents incorrect center, bass, or surround routing.
```

## Suggested Developer Log

```text
ORBISONIC CHANNEL LAYOUT ERROR
The multichannel input does not provide enough layout metadata to safely map channels.
source: <source>
channelCount: <count>
physicalMask: <mask or nil>
layoutTag: <tag or nil>
futureWork: add channel layout mapper and JSON sidecar override support
```

## Acceptance Criteria

- Ambiguous multichannel layout does not proceed through the renderer as if it were valid.
- The error explains why playback/rendering was blocked or downgraded.
- The code contains future-work markers for mapper/sidecar support, but no sidecar implementation yet.

---

# 21. Phase 12 — Future Work Markers Only

## Goal

Record the intended future direction without implementing it now.

Add comments or TODOs in appropriate locations:

```swift
// TODO(ChannelLayoutMapper): Add a UI that lets the user manually map unknown channel layouts.
// TODO(ChannelLayoutSidecar): Add JSON sidecar support for per-song channel layout overrides.
// TODO(ChannelLayoutMetadata): Investigate writing/reading channel layout overrides from metadata where supported.
```

## Important

Do not implement the sidecar file yet.
Do not implement the mapper UI yet.
Do not show a custom popup yet.

The only current behavior is an error for ambiguous multichannel layouts.

---

# 22. Phase 13 — Remove or Quarantine Old Prototype Logic

## Goal

Ensure the earlier prototype fix does not leave duplicated or conflicting layout logic.

## Tasks

Inspect:

```text
Sources/OrbisonicVLCReference/VlcLivePCMDownmixPrototype.swift
Tests/OrbisonicVLCReferenceTests/VlcLivePCMDownmixPrototypeTests.swift
```

Update the prototype to use the central channel-layout resolver instead of its own local copy of VLC WG4 mapping.

If the prototype must retain local code for reference purposes, clearly mark it as deprecated or test-only.

## Acceptance Criteria

- VLC WG4 mapping exists in one central implementation.
- Tests for the prototype and live path both use the same resolver.
- No duplicate hard-coded resolver remains unless explicitly justified.

---

# 23. Phase 14 — Manual Test Plan

## Required Test Files

Use or create channel-identification files for:

```text
stereo
mono
VLC 5.1 rear
VLC 5.1 side/middle
SMPTE/FFmpeg-style 5.1
unknown/ambiguous six-channel
```

## Test: VLC 5.1 Rear

Expected log:

```text
ORBISONIC CHANNEL LAYOUT RESOLVED
source: VLC
channels: 6
physicalMask: 0x1067
confidence: exact
index 0: left
index 1: right
index 2: rearLeft
index 3: rearRight
index 4: center
index 5: lfe
```

Expected listening result:

```text
center/dialog is centered
LFE/bass is not routed as surround
rear channels are not treated as center/LFE
no thin/tinny center caused by channel swap
```

## Test: VLC 5.1 Side/Middle

Expected log:

```text
ORBISONIC CHANNEL LAYOUT RESOLVED
source: VLC
channels: 6
physicalMask: 0x1307
confidence: exact
index 0: left
index 1: right
index 2: sideLeft
index 3: sideRight
index 4: center
index 5: lfe
```

## Test: Unknown Six-Channel

Expected log:

```text
ORBISONIC CHANNEL LAYOUT ERROR
source: unknown
channels: 6
physicalMask: nil
layoutTag: nil
reason: missing required layout metadata
result: surround rendering disabled for this item
futureWork: channel layout mapper / JSON sidecar override
```

Expected behavior:

```text
The app flags an error.
The app does not guess channel order.
The app does not create a sidecar file.
The app does not show a custom mapper UI.
```

---

# 24. Phase 15 — Final Verification Checklist

Before considering the work complete, verify all of the following:

```text
[ ] Central channel-role enum exists.
[ ] Central layout descriptor exists.
[ ] Layout confidence/error types exist.
[ ] VLC WG4 resolver exists.
[ ] VLC 0x1067 test maps center to index 4 and LFE to index 5.
[ ] VLC 0x1307 test maps center to index 4 and LFE to index 5.
[ ] SMPTE/FFmpeg resolver is source-specific and not used for VLC.
[ ] Unknown multichannel layouts throw an error.
[ ] Mono and stereo still work.
[ ] Live playback path uses the central resolver.
[ ] Prototype/reference path uses the central resolver or is clearly quarantined.
[ ] Fixed-index 5.1 assumptions are removed or explicitly source-specific.
[ ] Layout resolution logs are present.
[ ] Ambiguous layout error logs are present.
[ ] Optional RMS diagnostics are available or clearly planned.
[ ] No JSON sidecar implementation was added yet.
[ ] No channel-layout mapper UI was added yet.
[ ] Future-work TODOs exist for mapper and JSON sidecar support.
```

---

# 25. Expected Codex Deliverables

When finished, return a summary with:

1. Files changed.
2. New channel-layout types created.
3. Source-specific resolvers implemented.
4. Live playback path files/functions updated.
5. Prototype/reference path files/functions updated.
6. Fixed-index assumptions removed or quarantined.
7. Tests added.
8. Test results.
9. Example logs for:
   - VLC rear 5.1;
   - VLC side/middle 5.1;
   - SMPTE/FFmpeg 5.1;
   - stereo;
   - mono;
   - unknown six-channel error.
10. Any remaining ambiguity.
11. Future-work TODOs added for:
   - channel layout mapper;
   - JSON sidecar overrides;
   - metadata-based overrides.

---

# 26. Final Implementation Principle

The important architectural rule is:

```text
Orbisonic should render semantic channels, not numeric channels.
```

The renderer should receive:

```text
left
right
center
lfe
sideLeft
sideRight
rearLeft
rearRight
```

not:

```text
channel 0
channel 1
channel 2
channel 3
channel 4
channel 5
```

If the semantic meaning cannot be known, the correct behavior for this phase is to flag an error instead of guessing.
