# Audio Best Practices Rationale

## Purpose

This document explains why Orbisonic makes its audio-format decisions.

The goal is not audiophile mysticism. The goal is controlled conversion, visible evidence, and no hidden damage.

## Reference Summary

Orbisonic uses these reference standards and vendor documents:

```text
VLC public callback and audio-output architecture for local monitor reference behavior.
Audinate Dante Virtual Soundcard and Dante Application Library docs for Dante output limits and format language.
Audinate Dante Controller docs for sample rate, encoding, and endpoint compatibility.
ITU-R BS.1770-5 for true-peak measurement.
EBU R 128 and EBU true-peak guidance for signal-chain upper limit thinking.
SoXR/libsoxr documentation for high-quality SRC with configurable phase, bandwidth, aliasing, and rejection.
Dither and word-length-reduction literature for final-stage dither policy.
BW64/ADM references for high-channel LPCM and metadata.
```

## Keep Internal Audio Float

Decision:

```text
Use Float32 planar minimum for internal production blocks.
Use Float64 for renderer accumulation where matrix summing or calibration math benefits.
```

Rationale:

```text
matrix rendering and gain changes need headroom and precision
float avoids repeated integer quantization during processing
rendering should not be quantized until the final output boundary
```

## Do Not Treat Dante As Internal Float

Decision:

```text
Dante output is configured PCM.
Internal float must be converted or submitted according to the actual backend format.
```

Rationale:

```text
Dante device encoding is configured by sample rate and bit depth.
CoreAudio may expose Float32 to the app, but Dante network encoding can still be configured PCM 24-bit.
The app must query and log actual backend facts.
```

## Default Dante Profile

Decision:

```text
48 kHz / 24-bit PCM default
```

Rationale:

```text
48 kHz / 24-bit PCM is the common pro Dante profile.
48 kHz provides more channel-capacity headroom than 96 kHz on standard DVS.
SonicSphere is high channel count, so channel capacity matters more than marketing sample-rate claims.
```

## Explicit SRC

Decision:

```text
If source rate differs from Dante session rate, perform one explicit high-quality SRC stage.
```

Rationale:

```text
Changing Dante session rate track by track is operationally unstable.
Hidden OS or CoreAudio SRC makes audio problems hard to diagnose.
A named SRC stage can be tested with impulses, sweeps, and channel-identity fixtures.
```

Default SRC profile:

```text
high-quality band-limited converter
linear phase reference mode
same settings across all channels
ledger records algorithm, rates, latency, phase mode, and channel count
```

## SRC Before Or After Rendering

Decision:

```text
For linear matrix rendering, resample source channels before rendering to the Dante session rate.
```

Rationale:

```text
resampling 2, 6, or 8 source channels is cheaper than resampling 31 or 34 rendered channels
for a linear time-invariant matrix, SRC before rendering is equivalent if every channel uses identical SRC settings
filters or convolution require sample-rate-specific profiles
```

## Dither Final Only

Decision:

```text
Dither only when reducing to a fixed integer word length, and only at the final output formatter.
```

Rationale:

```text
word-length reduction without dither creates quantization distortion
adding dither before later DSP is wrong because later processing invalidates the final quantization step
repeated dither adds unnecessary noise
```

Default dither:

```text
TPDF dither for float-to-24-bit PCM
TPDF or explicit noise-shaped dither profile for float-to-16-bit PCM
```

## True Peak

Decision:

```text
Measure true peak before final production output.
Default target <= -1 dBTP.
```

Rationale:

```text
sample peaks can miss inter-sample peaks
SRC, filtering, and DAC reconstruction can create peaks above sample maximum
high-channel matrix summing needs headroom
```

## Headroom

Decision:

```text
Reserve render headroom and avoid clipping.
```

Default:

```text
ordinary render: at least 3 dB internal headroom
stress/matrix render: 6 dB headroom unless calibration says otherwise
final true peak target: <= -1 dBTP
```

Rationale:

```text
multiple source channels can sum into one output channel
clipping is more damaging than preserving a slightly lower level
normalization and limiting must be explicit, never hidden
```

## Monitor Downmix

Decision:

```text
Local-file stereo monitor downmix is VLC-owned.
```

Rationale:

```text
VLC is the reference ordinary media player.
The current Orbisonic native monitor downmix is a likely failure point.
Local monitor playback needs finished stereo, not source-preserving production identity.
```

## SonicSphere Production

Decision:

```text
SonicSphere production is Orbisonic-owned.
```

Rationale:

```text
VLC standard speaker maps do not represent SonicSphere geometry.
Dante transports channels, not Orbisonic speaker meaning.
Custom sphere channel identity needs Orbisonic metadata, renderer policy, and output map.
```

## Pure Spherical Lossless

Decision:

```text
Pure Spherical Lossless is direct rendered speaker-bed LPCM.
```

Rationale:

```text
an already-rendered sphere file should not be decoded through VLC or re-rendered
metadata must prove exact sphere profile and output map
BW64/CAF LPCM preserves channels without lossy coding
```

## References

Official and technical references used by this package:

```text
Audinate Dante Virtual Soundcard comparison:
https://www.getdante.com/products/software-essentials/dante-virtual-soundcard/compare/

Audinate Dante Virtual Soundcard encoding settings:
https://dev.audinate.com/GA/dvs/userguide/webhelp/content/settings_available_in_dante_controller.htm

Audinate Dante Application Library datasheet:
https://www.getdante.com/docs/dante-application-library-datasheet/

Audinate Dante network administrator guide:
https://audinateweb.sfo2.cdn.digitaloceanspaces.com/wp-content/uploads/2022/03/dante-information-for-network-admins.pdf

ITU-R BS.1770-5:
https://www.itu.int/rec/R-REC-BS.1770

SoX Resampler library:
https://github.com/chirlu/soxr

Benchmark Media word-length reduction note:
https://benchmarkmedia.com/blogs/application_notes/12142585-word-length-reduction-of-digital-audio

Library of Congress/Pohlmann ADC measurement document:
https://www.loc.gov/static/programs/national-recording-preservation-board/documents/Pohlmann.pdf

EBU BW64 and ADM:
https://adm.ebu.io/reference/excursions/bw64_and_adm.html

VLC libVLC callback docs:
https://github.com/videolan/vlc-3.0/blob/master/include/vlc/libvlc_media_player.h
```
