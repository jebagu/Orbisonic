# Dante Production Output

## Purpose

This document defines the Orbisonic production output policy for Dante and other strict multichannel routes.

Dante is treated as a configured PCM endpoint.

Orbisonic internal float rendering is not the Dante network format.

## Default Dante Profile

Default production profile:

```text
sampleRate = 48000
encoding = PCM 24-bit
logicalChannelCount = active SonicSphere profile output count
physicalChannelCount = Dante route output count
clockDomain = Dante network clock
latency = route profile or Dante Controller profile
```

The default is 48 kHz / 24-bit PCM because it is the common professional Dante profile and gives the safest channel-capacity margin.

## Why Not Follow Source Rate

Dante production should not change network sample rate track by track.

Forbidden default behavior:

```text
44.1 kHz album changes Dante network to 44.1
48 kHz track changes Dante network to 48
96 kHz file changes Dante network to 96
```

Correct behavior:

```text
Dante session rate is configured.
Orbisonic converts source material into that session rate when needed.
```

## Dante Target Profile

```swift
struct DanteTargetProfile: Equatable, Sendable {
    var backend: DanteBackend
    var sampleRate: Double
    var encodingBitDepth: Int
    var encodingKind: DanteEncodingKind
    var logicalChannelCount: Int
    var physicalChannelCount: Int
    var outputMapID: String
    var allowSampleRateConversion: Bool
    var requireStrictRoute: Bool
    var requireDitherForIntegerOutput: Bool
    var maxTruePeakDbTP: Double
}
```

Default values:

```text
sampleRate = 48000
encodingBitDepth = 24
encodingKind = PCM integer
allowSampleRateConversion = true, explicit only
requireStrictRoute = true
requireDitherForIntegerOutput = true
maxTruePeakDbTP = -1.0
```

## Backend Choices

Initial backend:

```text
Dante Virtual Soundcard through CoreAudio
```

Future backend:

```text
Dante Application Library
```

Both are behind the same `ProductionOutputSession` and `DanteOutputFormatter` contracts.

## Host Format Versus Dante Encoding

CoreAudio may expose an app-facing Float32 stream format even when Dante is configured for PCM 24-bit network encoding.

The output session must distinguish:

```text
host API format
Dante Controller encoding setting
Dante endpoint negotiated encoding
network PCM profile
```

Do not assume that CoreAudio Float32 means Dante network float.

## Route Validation

Before production playback starts, validate:

```text
selected device is the intended Dante route
actual sample rate equals target sample rate
actual channel count is at least required physical channel count
Dante encoding is configured and compatible
route is not Bluetooth, AirPlay, system-default stereo, or unknown
Dante clock domain is compatible
output map exists
reserved channels are marked silent
```

If validation fails, production does not start.

## Conversion Order

Reference production order:

```text
source PCM
    -> explicit SRC to Dante session rate if needed
    -> SonicSphere render at Dante session rate
    -> headroom and true-peak guard
    -> final dither if fixed integer output
    -> final quantization and packing
    -> ProductionOutputSession
```

For a simple linear matrix, SRC before rendering is preferred because it resamples fewer channels than resampling the rendered output.

## Sample-Rate Converter

SRC module:

```text
SourceRateConverter
```

Requirements:

```text
high-quality band-limited SRC
linear phase default for reference mode
minimum/apodizing phase only as explicit profile
declared passband and stopband behavior
declared latency
deterministic tests for impulses and sweeps
same settings for all channels
```

SRC ledger fields:

```text
srcOccurred
srcAlgorithm
srcPhaseMode
srcInputRate
srcOutputRate
srcLatencyFrames
srcChannels
```

## Dither Policy

Dither occurs only at final fixed-point reduction.

Default:

```text
Float32 or Float64 -> 24-bit PCM:
    TPDF dither at DanteOutputFormatter
```

No dither:

```text
Float internal -> Float host buffer with no fixed-point reduction
24-bit source widened to 32-bit integer with no processing and no rounding
metadata-only read path
```

Dither required:

```text
Float -> 24-bit fixed PCM
Float -> 16-bit fixed PCM
32-bit fixed -> 24-bit fixed
any DSP-processed signal reduced to a shorter fixed-point word length
```

## Headroom And True Peak

Production output must measure:

```text
sample peak
true peak
clip count
NaN count
Inf count
per-channel max
```

Default target:

```text
max true peak <= -1 dBTP
```

A safety limiter may exist only as an explicit profile. It is not a loudness maximizer.

## Dante Output Formatter

Responsibilities:

```text
receive RenderedSphereBlock
validate sample rate
validate channel count
apply final gain if profile allows
measure peak and true peak
apply dither when fixed integer reduction is required
quantize to target PCM encoding
pack/interleave as backend requires
map logical output channels to Dante/device channels
```

Non-responsibilities:

```text
decode source files
downmix monitor audio
infer source channel layouts
perform SonicSphere rendering
select UI route
silently resample
silently downmix
```

## ProductionOutputSession

Lifecycle:

```text
open route
configure target profile
validate actual device format
start
submit blocks
pause internal if needed
flush
Drain natural end
stop
close
```

Flush and drain are different:

```text
flush = discard queued audio immediately
Drain = play queued audio to completion then report drained
```

Internal lifecycle may have these concepts. The UI does not gain new buttons.

Current implementation:

```text
ProductionOutputSession protocol
FakeProductionOutputSession
FakeProductionOutputBackend
CoreAudioDanteOutputSession
ProductionOutputNegotiation
OutputTimingReport
ProductionChannelWalkReport
```

The fake backend validates route facts against `DanteTargetProfile`, queues formatted packets, discards queued packets on flush, writes queued packets only on drain, rejects stale flushed generations, and verifies channel-walk packets without opening hardware.

`CoreAudioDanteOutputSession` queries CoreAudio device facts and host output ASBD, validates the intended Dante route against `DanteTargetProfile`, logs CoreAudio host format separately from target Dante network profile, and refuses invalid routes before playback. Live Dante/DVS packet submission remains separate hardware-integration work.

## Manual Dante Verification Checklist

The complete release/hardware gate is tracked in:

```text
docs/manual-verification-gates.md
docs/release-verification.md
```

Record this checklist before claiming a route is production-proven:

```text
date:
operator:
Orbisonic build:
Dante route name:
Dante route UID:
CoreAudio deviceID:
manufacturer:
transport:
```

Verify:

```text
selected route is Dante Virtual Soundcard, Dante Application Library, or an approved Audinate/Dante endpoint
selected route is not built-in output, system default stereo, Bluetooth, AirPlay, BlackHole, or another loopback-only route
CoreAudio nominal sample rate equals the target Dante profile, default 48000 Hz
CoreAudio output channel count equals the target physical channel count, default 32
CoreAudio host ASBD is recorded: sample rate, channels, format ID, flags, bit depth, interleaving, bytes per frame, frames per packet
Dante Controller separately confirms network encoding, bit depth, clock lock, and route subscription state
CoreAudio Float32 host exposure is not treated as proof of Dante network Float32
channel walk verifies logical channels 1-31 on the expected physical outputs
reserved physical channel 32 remains silent
verification artifact is linked from status or release notes
```

Current Task 018 note:

```text
Dante Virtual Soundcard is installed and its launch daemon is running on the checked Mac.
Dante Controller is not installed in /Applications, so Dante subscriptions, encoding, clock lock, and latency are not verified.
No physical channel walk has been run for this build.
```

## Channel Mapping

Dante does not know SonicSphere geometry.

Orbisonic must define:

```text
logical output channel
speaker ID
Dante transmit channel
device channel
trim
delay
polarity
reserved/silent flag
```

A route is production-proven only after a channel-walk test.

## Required Tests

- Target profile validation.
- CoreAudio ASBD query test with fake backend.
- DVS route validation with simulated route facts.
- Bit-depth mismatch classification.
- Sample-rate mismatch failure.
- Channel-count mismatch failure.
- SRC ledger test.
- Dither final-stage test.
- True-peak guard test.
- Dante output packing test.
- Channel-walk fixture test.
- Reserved-channel silence test.
- Long-run no-underrun test with fake backend.

## Acceptance Criteria

Dante production output is accepted only when:

```text
requested-vs-actual route facts are logged
production refuses insufficient routes before playback
source-rate mismatch is corrected only by explicit SRC
final fixed PCM uses final-stage dither
no hidden downmix occurs
no hidden OS SRC is allowed in strict production
channel identity passes through output map
Pure Spherical Lossless direct playback uses the same strict route validation
```
