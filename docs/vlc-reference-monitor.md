# VLC Reference Monitor Path

## Purpose

This document defines how VLC is used in Orbisonic.

VLC is canonical for local-file stereo monitor playback.

VLC is not the production renderer and not the Dante output owner.

## Local Monitor Flow

```text
local file
    -> libVLC media
    -> VLC access module
    -> VLC demuxer
    -> VLC decoder
    -> VLC audio filter pipeline
        -> channel reorder
        -> ordinary multichannel-to-stereo downmix
        -> optional requested monitor resample
        -> format conversion to FL32
    -> libVLC audio callback / amem
    -> Orbisonic stereo monitor ring
    -> StereoMonitorOutputSession
    -> existing stereo monitor route
```

## Why VLC Owns This Path

VLC is a mature ordinary media-player pipeline.

For monitor listening, the desired operation is ordinary:

```text
make this local file sound correct in stereo
```

Orbisonic should not rewrite this downmix. The previous native monitor downmix is a suspected failure point.

## Callback Contract

Orbisonic requests:

```text
format = FL32
channels = 2
sample rate = monitor output rate or configured monitor rate
```

The callback is treated as finished stereo monitor PCM.

Orbisonic may copy the samples, buffer them, meter them, and output them. Orbisonic must not reinterpret the samples as multichannel source material.

## Ring-Fenced Module

VLC code lives only in:

```text
Sources/OrbisonicVLCReference/
```

or the repo-equivalent protected module.

Proposed files:

```text
Sources/OrbisonicVLCReference/CLibVLCBridge.swift
Sources/OrbisonicVLCReference/VlcLocalStereoMonitorSource.swift
Sources/OrbisonicVLCReference/VlcStereoMonitorDiagnostics.swift
Sources/OrbisonicVLCReference/VlcCapabilityProbe.swift
```

Initial guarded implementation:

```text
Sources/OrbisonicVLCReference/VlcCapabilityProbe.swift
Sources/OrbisonicVLCReference/VlcLocalStereoMonitorSource.swift
Tests/OrbisonicVLCReferenceTests/VlcCapabilityProbeTests.swift
Tests/OrbisonicVLCReferenceTests/VlcLocalStereoMonitorSourceTests.swift
```

The default build does not link libVLC and does not require VLC at app launch.

The guarded compile flag is:

```text
ORBISONIC_ENABLE_VLC_REFERENCE
```

When the flag is off or runtime files are missing, the probe returns a diagnostic capability report instead of crashing.

The local monitor source currently implements the guarded session, FL32 stereo callback validation, generation-safe ring, `StereoMonitorBlock` emission, and diagnostics. The native `CLibVLCBridge` that opens real libVLC media is still a separate implementation step.

Forbidden:

```text
UI imports libVLC
SonicSphereRenderer imports libVLC
DanteOutputFormatter imports libVLC
Roon capture imports libVLC by default
Pure Spherical Lossless reader imports libVLC
```

## Local Monitor Source Contract

Input:

```text
local file URL
sourceID
generation
requested monitor sample rate
```

Output:

```text
StereoMonitorBlock
format: Float32
channels: 2
layout: stereo
PTS or generated source frame index
discontinuity flag
```

Errors:

```text
vlcUnavailable
vlcPluginMissing
mediaOpenFailed
unsupportedCallbackFormat
callbackDidNotReturnStereo
ringOverflow
ringUnderflow
staleGenerationRejected
```

## Downmix Ownership

For local files, `downmixOwner` in the ledger must be:

```text
VLC
```

`OrbisonicNativeLocalDownmix` is forbidden in the local VLC monitor path.

## Resampling In Monitor Path

Monitor resampling may be VLC-owned if the callback requests a rate different from source rate.

This is allowed for monitor playback only.

The ledger must record:

```text
monitorSRC = VLC or none
sourceRate
callbackRate
```

Production SRC rules are separate and stricter.

## High-Channel Warning

Stock libVLC callback output is not treated as a high-channel SonicSphere bridge.

Do not use VLC local monitor callback for:

```text
Direct 30 production
Direct 31 production
52-channel source preservation
Pure Spherical Lossless playback
```

## Roon Warning

Roon does not naturally enter this path.

A future `VlcLivePcmDownmixBridge` may be built only after an explicit proof harness. It must not be smuggled into the default Roon path.

## Required Tests

- VLC capability probe test.
- Local stereo file gives stereo FL32 callback.
- Local 5.1 file gives stereo FL32 callback.
- Local 7.1 file gives stereo FL32 callback.
- Orbisonic native local downmixer is not called.
- The UI does not expose VLC.
- Ring buffer rejects stale generation blocks.
- Callback teardown cannot write into released state.
- Diagnostics show `downmixOwner = VLC`.

## Acceptance Criteria

This path is accepted when:

```text
local stereo monitor playback works through VLC
local 5.1 stereo monitor playback works through VLC
local 7.1 stereo monitor playback works through VLC
PCM measurements match reference expectations
no double downmix occurs
no production path consumes VLC stereo callback
UI remains unchanged except Pure Spherical Lossless badge
```
