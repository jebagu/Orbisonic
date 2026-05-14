# Audio Path Invariants

## Purpose

This document defines non-negotiable audio rules for Orbisonic.

If a task conflicts with these invariants, Codex must stop.

## Global Invariant

```text
Source selection is shared.
Stereo monitor and SonicSphere production are separate products.
```

A source may feed both products, but the products do not share downmix or output policy.

## Monitor Path Invariant

For local files:

```text
VLC owns local-file access, demux, decode, channel reorder, multichannel-to-stereo downmix, optional requested monitor resample, and FL32 stereo callback.
```

Orbisonic receives finished stereo PCM.

Orbisonic must not apply its old/native local multichannel-to-stereo downmix after VLC local monitor downmix.

## Production Path Invariant

For SonicSphere production:

```text
Orbisonic owns source channel identity, renderer policy, output mapping, and Dante formatting.
```

The VLC stereo monitor callback is never production input.

## Roon Invariant

Roon is not a file decode path inside Orbisonic.

```text
Roon opens and decodes the file upstream.
Orbisonic captures PCM from CoreAudio loopback.
```

If Roon is stereo, monitor pass-through is allowed.

If Roon is multichannel, monitor downmix requires an explicit owner. There is no hidden native Roon downmix.

An optional VLC live PCM bridge may be used only as an explicitly selected proof path. It must not change default Roon monitor admission, and it must log downmix owner, latency, and drift.

## Spotify Invariant

Spotify is stereo.

```text
Spotify source channel count = 2 unless a future contract proves otherwise.
```

Spotify does not use VLC for downmix.

## Pure Spherical Lossless Invariant

Pure Spherical Lossless is already rendered.

```text
No VLC.
No renderer.
No downmix.
No source-channel reinterpretation.
Direct validated speaker-bed playback only.
```

## Internal Format Invariant

Production internal audio is:

```text
Float32 planar minimum
Float64 allowed or preferred for accumulation
explicit sample rate
explicit channel count
explicit layout or output map
```

## Dante Format Invariant

Dante output is not the internal float bus.

Dante output is configured PCM.

Default:

```text
48 kHz
24-bit PCM
explicit logical channel count
explicit physical channel map
```

The output session must query and log actual host/device format.

## SRC Invariant

Sample-rate conversion must be explicit.

Allowed:

```text
source rate differs from Dante session rate
SourceRateConverter performs one high-quality SRC stage
conversion ledger records algorithm and rates
```

Forbidden:

```text
silent OS SRC in production
silent CoreAudio SRC in production
double SRC
SRC hidden inside renderer
SRC hidden inside output fallback
```

## Dither Invariant

Dither happens only at final fixed-point word-length reduction.

Allowed:

```text
Float32/Float64 -> 24-bit PCM Dante print: TPDF dither at final output formatter
Float32/Float64 -> 16-bit PCM: TPDF or explicit noise-shaped dither profile
```

Forbidden:

```text
dither inside renderer
dither before SRC
dither before matrix rendering
dither in monitor path unless exporting fixed PCM
repeated dither at multiple stages
```

## True-Peak And Headroom Invariant

Before production output:

```text
measure sample peak
measure true peak or approved approximation
count clipped samples
count NaN and Inf
```

Default production target:

```text
max true peak <= -1 dBTP
```

unless a calibrated installation profile explicitly states otherwise.

## Channel Identity Invariant

Channel count is not channel identity.

Every production block must have:

```text
layout authority
channel order
render policy
output map
```

A 34-channel file is not automatically SonicSphere. It becomes Pure Spherical Lossless only after metadata and route validation.

## Failure Policy Invariant

Production failures are visible.

Forbidden:

```text
silent downmix
silent truncation
silent stereo fallback
silent channel duplication
synthetic channels
fake activity
hidden gain normalization
route fallback without diagnosis
```

## Diagnostics Invariant

Every session emits a `PlaybackDiagnosticSnapshot` and `AudioConversionLedger`.

Minimum facts:

```text
source kind
source sample rate
source channel count
decode owner
captured or decoded format
downmix owner
SRC owner
renderer owner
Dante/output formatter owner
requested output format
actual output format
route channel count
underflow/overflow counters
stale generation rejection count
```
