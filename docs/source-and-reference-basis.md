# Source And Reference Basis

## Purpose

This document records the evidence base for Orbisonic UI-Frozen Audio Chain.

The package is self-contained for Codex execution. It also preserves the original reasoning basis so future changes do not drift into speculative audio architecture.

## Project-control basis

Orbisonic follows a plan-first project control workflow.

The repository must contain, before implementation:

```text
AGENTS.md
README.md
docs/product-brief.md
docs/architecture.md
docs/contracts.md
docs/system-flows.md
docs/implementation-map.md
docs/test-strategy.md
docs/status.md
docs/decisions/*.md
.tasks/*.md
```

Codex must receive one bounded task at a time. A task is not complete until tests and human-readable docs are updated.

## Current Orbisonic investigation basis

The previous Orbisonic investigation established these facts:

```text
Current playback ownership is split.
The UI/view model owns transport and source state.
The engine owns the AVAudioEngine runtime graph.
Local decoding is owned by loader/source classes.
Roon/Aux style input is live CoreAudio PCM capture, not local decode.
Normal monitor playback is a stereo preview path.
SonicSphere production is a separate topology.
```

The investigation also found that the bad-audio symptom was not isolated to a single stage. Plausible fault classes included decode corruption, PCM conversion error, channel layout mismatch, buffering or stale-generation errors, monitor downmix/gain errors, resampling or clock drift, and output-device negotiation. That is why Orbisonic must make every audio boundary measurable.

## Greenfield decision versus retrofit decision

The earlier retrofit recommendation was conservative: do not add VLC to the existing app until the failing layer is measured.

Orbisonic is a different decision. It is a greenfield rewrite whose purpose is to preserve the existing UI while replacing the audio chain.

The greenfield decision is:

```text
Use VLC as the reference owner for local-file stereo monitor playback.
Use Orbisonic as the owner of live PCM capture, source identity, SonicSphere rendering, Pure Spherical Lossless validation, and Dante production output.
```

This does not mean VLC owns the whole app. It means VLC owns the local-file ordinary media-player chain that it is best at:

```text
local file access
container demux
codec decode
ordinary channel reorder
ordinary multichannel-to-stereo downmix
format conversion to stereo FL32 callback
```

## VLC basis

The VLC source investigation established these points:

```text
libVLC audio callbacks suppress normal VLC OS output.
The callback receives decoded and post-processed audio from VLC.
The callback format can request FL32 in current VLC builds inspected.
For multichannel callbacks, stock amem output is ordinary-channel scale, not a 30 or 52 channel SonicSphere bridge.
VLC's mapped speaker model is standard-surround-oriented.
VLC's output lifecycle has useful concepts: start, play, pause, flush, drain, timing, device selection, and negotiated output format.
```

Orbisonic uses those findings as follows:

```text
Local monitor path:
    VLC owns local decode and stereo downmix.

Production path:
    Orbisonic owns channel identity, renderer, and Dante output.

High-channel custom files:
    Do not rely on stock libVLC callback output for 30 or 52 channels.
```

## Dante and Audinate basis

Orbisonic treats Dante as a PCM network-output target with a configured session rate, configured bit depth, and explicit channel map.

The relevant public Audinate material says:

```text
Dante Virtual Soundcard supports PCM 16-, 24-, or 32-bit encoding.
Standard DVS channel capacity is 64x64 at 44.1/48 kHz, 32x32 at 88.2/96 kHz, and 8x8 at 176.4/192 kHz.
Dante Virtual Soundcard Pro expands those capacities.
Dante Application Library is published as supporting up to 64 input and 64 output channels, sample rates 44.1, 48, 88.2, and 96 kHz, and PCM 16/24/32-bit or custom encoding.
DVS encoding in Dante Controller is audio bit depth.
Changing Dante sample rate or encoding interrupts audio.
The preferred encoding is not guaranteed unless both Dante endpoints support it.
```

Orbisonic therefore defaults production output to:

```text
48 kHz
24-bit PCM Dante print
explicit logical channel count
explicit physical Dante channel map
strict route validation
```

## Audio best-practice basis

Orbisonic follows these audio rules:

```text
Keep processing in float until the final output boundary.
Perform sample-rate conversion exactly once when needed.
Use a high-quality band-limited SRC with declared settings.
Do not hide SRC inside the OS or output device.
Dither only at final fixed-point word-length reduction.
Use TPDF dither for float-to-24-bit or float-to-16-bit fixed PCM unless a profile explicitly says otherwise.
Measure true peak before final output.
Use headroom so render/matrix summing does not clip.
```

References for this are listed in `docs/audio-best-practices-rationale.md`.

## BW64 and Pure Spherical Lossless basis

The preferred rendered SonicSphere file is a direct speaker-bed LPCM file.

The package uses the display label:

```text
Pure Spherical Lossless
```

The earlier phrase `True Spherical Lossless` is treated as historical planning vocabulary. The app UI must show only `Pure Spherical Lossless` unless a later accepted product decision changes the label.

The file format policy is:

```text
BW64 preferred for shareable wave-family rendered sphere files.
CAF acceptable for Mac-only internal working files.
32-bit float LPCM for render masters.
24-bit PCM for Dante prints.
Orbisonic metadata is mandatory for custom sphere channel identity.
```

## UI freeze basis

The rewrite is audio-chain-only from the user's point of view.

The app interface must remain the same. The only allowed visible addition is the Pure Spherical Lossless indicator in an existing UI surface.

No new screens, no new tabs, no new panels, no new VLC controls, no new Roon workflow, no new Dante workflow, no new transport controls, and no separate pause/stop controls are allowed.
