# Pure Spherical Lossless

## Display Label

The app label is:

```text
Pure Spherical Lossless
```

This is the only new visible UI label approved for Orbisonic.

The earlier planning phrase `True Spherical Lossless` is retired from UI copy. It may appear only as a migration alias in code or metadata readers if old files were created with that wording.

## Definition

A Pure Spherical Lossless file is:

```text
Orbisonic-rendered
SonicSphere-specific
discrete speaker-bed
lossless LPCM
validated metadata
ready for direct production playback
```

It is not:

```text
a generic multichannel WAV
an Ambisonic source file
an object-audio file
a 5.1 source file
a VLC downmix candidate
a file that still needs SonicSphere rendering at playback
```

## Playback Rule

Pure Spherical Lossless playback path:

```text
file
-> PureSphericalLosslessValidator
-> PureSphericalLosslessReader
-> RenderedSphereBlock
-> DanteOutputFormatter
-> ProductionOutputSession
```

Forbidden:

```text
VLC decode
VLC downmix
SonicSphereRenderer at playback
native monitor downmix as production input
source-layout reinterpretation
```

## Format Recommendation

Preferred shareable format:

```text
BW64
uncompressed LPCM
Orbisonic metadata
ADM/chna/axml when useful
ORBI private chunk
sidecar fallback
```

Acceptable internal working format:

```text
CAF
uncompressed LPCM
Orbisonic metadata or sidecar
```

Avoid plain RIFF WAV as the default because large high-channel files can hit practical size limits.

## Render Master Profile

```text
container = BW64 preferred, CAF acceptable internally
sampleFormat = 32-bit float LPCM
sampleRate = SonicSphere production session rate, default 48 kHz
channelCount = active SonicSphere profile output count
channelMask = 0 for custom direct speaker bed in WAVE/BW64
metadata = required
Dither = none
playback = direct production output
```

## Dante Print Profile

```text
container = BW64
sampleFormat = 24-bit PCM preferred
sampleRate = 48 kHz default
channelCount = active Dante/SonicSphere route count
Dither = TPDF if converted from float
truePeakTarget = <= -1 dBTP unless installation profile says otherwise
playback = direct production output
```

## Channel Count Rule

Do not hard-code 34.

Correct rule:

```text
PureSphericalLossless.channelCount == SphereProfile.outputChannelCount
```

A 34-channel file is Pure Spherical Lossless for a 34-channel sphere only if metadata proves the exact sphere profile and output map.

A 31-channel file is Pure Spherical Lossless for a 31-channel sphere if metadata and route validation pass.

## Metadata Requirements

Minimum manifest:

```json
{
  "schema": "com.orbisonic.pure-spherical-lossless.v1",
  "displayLabel": "Pure Spherical Lossless",
  "renderKind": "sonicSphere.discreteSpeakerBed",
  "lossless": true,
  "codec": "LPCM",
  "alreadyRendered": true,
  "requiresRendererAtPlayback": false,
  "requiresVlcDownmix": false,
  "sampleRate": 48000,
  "channelCount": 34,
  "sampleFormat": "float32",
  "sphereProfileID": "example-sphere-34",
  "calibrationID": "example-calibration",
  "outputMapID": "example-dante-map",
  "rendererVersion": "orbisonic-renderer-v2",
  "rendererMatrixHash": "sha256:...",
  "channels": []
}
```

Task 013 implementation accepts metadata from:

```text
embedded ORBI metadata stub marked by ORBI\n followed by the JSON manifest
sidecar at <filename>.<extension>.orbi.json
sidecar at <filename>.orbi.json
```

Filename text alone must never enable the badge.

Each channel entry must include:

```text
index
channelID
speakerID
logicalOutputChannel
physicalOutputChannel or Dante transmit channel
role
azimuth/elevation/radius when known
trimDb
delayMs
polarity
reserved/silent flag
```

## Validation States

```swift
enum PureSphericalLosslessState: Equatable, Sendable {
    case none
    case candidate
    case validForCurrentSphere
    case validForDifferentSphere
    case routeNotReady
    case invalid(reason: String)
}
```

UI badge states:

```text
validForCurrentSphere -> Pure Spherical Lossless
validForDifferentSphere -> Pure Spherical Lossless, different sphere
routeNotReady -> Pure Spherical Lossless, route not ready
```

These are indicators, not new workflows.

## Validation Algorithm

```text
1. Read container header.
2. Confirm LPCM.
3. Confirm channel count.
4. Confirm sample rate.
5. Parse ORBI metadata if present.
6. Parse ADM/chna/axml if present.
7. Parse sidecar if embedded metadata is missing or stripped.
8. Confirm schema is known.
9. Confirm alreadyRendered = true.
10. Confirm requiresRendererAtPlayback = false.
11. Confirm downmixOccurred = false.
12. Confirm lossyCodec = false.
13. Confirm channel list length equals audio channel count.
14. Confirm sphereProfileID is known.
15. Confirm outputMapID is known.
16. Confirm current route can carry channel count and sample rate.
17. Confirm reserved channels are silent when required.
18. Emit badge state.
```

## Reader Contract

Input:

```text
validated Pure Spherical Lossless file
```

Output:

```text
RenderedSphereBlock
Float32 planar internally
M output channels
sample rate from file or explicit route-converted path
output map identity
```

Reader may perform:

```text
LPCM read
deinterleave
integer-to-float widening for internal output block
metadata validation
```

Task 014 implementation reads:

```text
BW64/WAVE 32-bit float LPCM render masters
BW64/WAVE signed 24-bit PCM Dante prints
CAF 32-bit float LPCM render masters
```

The reader streams from the audio payload, returns Float32 planar samples plus a
`RenderedSphereBlock`, preserves file channel order, rejects non-current-sphere
validation states before reading, and verifies manifest-marked reserved channels
remain silent.

Reader must not perform:

```text
VLC decode
downmix
renderer matrix application
source-channel remap beyond declared output map
sample-rate conversion unless an explicit production SRC stage is invoked and logged
```

## Stereo Preview

Pure Spherical Lossless production playback is direct multichannel playback.

Stereo preview is separate.

Allowed preview options:

```text
pre-rendered stereo preview sidecar
Orbisonic sphere-to-stereo preview fold using declared speaker map
```

Forbidden:

```text
ask VLC to interpret a 34-channel custom sphere bed as ordinary surround
```

## Required Tests

- Valid BW64/CAF candidate detection.
- Invalid metadata rejection.
- Filename-only badge rejection.
- Wrong sphere profile detection.
- Current sphere exact badge detection.
- Route-not-ready badge detection.
- Direct reader no-render test.
- Direct reader no-VLC test.
- Direct reader no-downmix test.
- Reserved channel silence test.
- Sidecar fallback test.
- Metadata stripping recovery test.
- UI badge appears in existing surface only.
- UI freeze remains intact.

## Acceptance Criteria

A file may show `Pure Spherical Lossless` only when:

```text
container and LPCM are valid
metadata is valid
channel count matches declared sphere profile
file is already rendered
no downmix occurred
no lossy codec occurred
renderer playback is not required
current route can play it directly or route state is shown
```
