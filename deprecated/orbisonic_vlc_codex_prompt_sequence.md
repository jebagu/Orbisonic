# Codex Prompt Sequence: Orbisonic Audio Playback and VLC Replacement Investigation

## Purpose

Use this prompt sequence to drive a methodical Codex investigation into Orbisonic's bad audio playback after modularization. The goal is to isolate the module or boundary that is degrading audio, compare Orbisonic's architecture against VLC/libVLC's architecture, and decide whether to replace, wrap, or repair Orbisonic's audio path.

The investigation should not start from "replace the player with VLC." It should start from "which stage corrupts or degrades the signal?" Then it should decide whether VLC helps at the decoder, callback bridge, output backend, filter, resampler, clocking, device negotiation, or not at all.

Orbisonic must preserve custom high-channel playback, including 30-channel and possible 52-channel layouts. Do not silently downmix. Do not let standard 5.1 or 7.1 assumptions overwrite custom Sonic Sphere, Ambisonic, or unmapped discrete layouts.

## How to use these prompts

Run these prompts one at a time in Codex, from the Orbisonic repository root.

For every task:

- Do not skip ahead to the next task.
- Do not make app code changes unless the specific task asks for them.
- Prefer evidence from source files, tests, logs, and command output over guesses.
- Record exact file paths, function names, class names, module names, branch names, and commit hashes.
- Every substantive claim must point to a source path, line number, command output, or test result.
- Put investigation notes under `docs/audio-vlc-investigation/`.
- Avoid tables unless a table is genuinely clearer than bullets.
- When blocked, explain the blocker, the command or file that exposed it, and the next best path.
- At the end of each task, the final line must be exactly the handoff sentence specified in that prompt.

## Seed facts about VLC to verify, not assume

Codex must verify these against the exact VLC version or commit it inspects:

- VLC's README describes VLC as a media player and multimedia engine, and describes libVLC as the embeddable engine for third-party applications.
- VLC is generally GPLv2-or-later, while libVLC is generally LGPLv2-or-later. That distinction matters if Orbisonic links libVLC instead of copying VLC source.
- In VLC 3.0 headers, `libvlc_audio_set_callbacks` is documented as overriding normal LibVLC audio output. With callbacks set, LibVLC does not output audio itself.
- VLC's internal `audio_output_t` abstraction is built around lifecycle and timing callbacks such as `start`, `stop`, `time_get`, `play`, `pause`, `flush`, `drain`, `volume_set`, `mute_set`, and `device_select`.
- VLC's channel model distinguishes mapped speaker channels from unmapped or input channels. Constants such as `AOUT_CHAN_MAX`, `INPUT_CHAN_MAX`, `i_channels`, `i_physical_channels`, and `channel_type` must be inspected carefully before saying 30 or 52 channels will work.
- The relevant VLC source targets are likely:
  - `README.md`
  - `COPYING`
  - `COPYING.LIB`
  - `include/vlc/libvlc_media_player.h`
  - `include/vlc_aout.h`
  - `include/vlc_es.h`
  - `lib/audio.c`
  - `src/audio_output/`
  - `modules/audio_output/`
  - `modules/audio_filter/`
  - `modules/MODULES_LIST`

Official source locations to inspect when internet access is available:

- `https://github.com/videolan/vlc`
- `https://github.com/videolan/vlc-3.0`
- `https://raw.githubusercontent.com/videolan/vlc/master/README.md`
- `https://raw.githubusercontent.com/videolan/vlc/master/include/vlc_aout.h`
- `https://raw.githubusercontent.com/videolan/vlc/master/include/vlc_es.h`
- `https://raw.githubusercontent.com/videolan/vlc-3.0/master/include/vlc/libvlc_media_player.h`

---

## Prompt 1: Establish the investigation workspace and repo baseline

You are Codex operating inside the Orbisonic repository.

Task 1 is to create the investigation workspace and capture a baseline before analyzing code.

Do the following:

1. Confirm the current working directory and Git branch.
2. Capture the current commit hash, dirty state, and recent modularization-related commits.
3. Create this directory if it does not exist:

   `docs/audio-vlc-investigation/`

4. Create `docs/audio-vlc-investigation/task-01-baseline.md`.
5. In that file, record:
   - repository root,
   - branch,
   - commit hash,
   - dirty state,
   - top-level directory map,
   - build system,
   - detected languages,
   - package/dependency files,
   - test directories,
   - likely native-service directories,
   - likely frontend/control-plane directories,
   - any audio-related modules obvious from filenames.
6. Run targeted searches to orient yourself. Start with:

   ```bash
   rg -n "audio|playback|player|decoder|decode|renderer|render|route|router|channel|ambisonic|ambisonics|sphere|Sonic|Plex|Part.key|ffmpeg|libav|gstreamer|juce|libsndfile|resample|interleave|deinterleave|buffer|ring|callback|device|wasapi|alsa|coreaudio|asio|pulse|jack" .
   ```

   If the repo is too large, scope the search and document what you skipped.

7. Add an initial hypothesis list:
   - where playback probably starts,
   - where decode probably happens,
   - where channel routing probably happens,
   - where device output probably happens,
   - where modularization may have changed ownership boundaries.

8. Add an "Architecture decision notes" section:
   - What architectural boundaries are already visible?
   - Which boundaries look intentional?
   - Which boundaries look risky for audio quality?
   - Which boundaries look risky for 30 or 52 channels?

Do not change app code in this task.

End your response with exactly:

`I just finished task 1 and I'm ready for task 2.`

---

## Prompt 2: Build the current Orbisonic playback architecture map

You are Codex operating inside the Orbisonic repository.

Task 2 is to identify Orbisonic's current playback pipeline from media source to device output and explain the architecture decisions behind it.

Use the baseline from `docs/audio-vlc-investigation/task-01-baseline.md`.

Create `docs/audio-vlc-investigation/task-02-orbisonic-architecture.md`.

Investigate and document the full pipeline:

`media location -> opener/fetcher -> demuxer -> decoder -> PCM converter -> resampler -> channel mapper -> spatial renderer -> device backend -> OS/hardware`

For each stage, document:

- actual file path,
- classes, functions, or modules,
- responsibility,
- input type,
- output type,
- sample format assumptions,
- channel-count assumptions,
- channel-layout assumptions,
- thread ownership,
- buffer ownership,
- error handling,
- logging,
- tests if any.

Run searches like:

```bash
rg -n "sample_rate|samplerate|channels|channel_count|layout|channel_map|channel_order|downmix|mix|gain|volume|clip|float|int16|int24|int32|f32|s16|s24|s32|pcm|planar|interleaved|pts|timestamp|clock|latency|underrun|overrun|drift|flush|drain" .
```

Also inspect recent modularization commits. Identify which files changed around:

- transport controls,
- decoder ownership,
- buffer transfer,
- channel mapping,
- renderer input,
- device output,
- seek/pause/flush/drain,
- sample format conversion,
- resampling.

Add a dedicated section called "Why Orbisonic may have been designed this way."

For each major architecture choice, explain:

- likely reason for the decision,
- benefit,
- cost,
- audio-quality risk,
- high-channel-count risk,
- how the decision differs from a conventional media player,
- whether the decision is still appropriate for a 30 or 52 channel spatial player.

Do not propose VLC yet. This task is about understanding Orbisonic.

End your response with exactly:

`I just finished task 2 and I'm ready for task 3.`

---

## Prompt 3: Isolate the current audio playback module and its boundaries

You are Codex operating inside the Orbisonic repository.

Task 3 is to identify the exact module or modules that "play audio" in Orbisonic, then separate decoding, routing, rendering, clocking, and device output responsibilities.

Use the architecture map from `docs/audio-vlc-investigation/task-02-orbisonic-architecture.md`.

Create `docs/audio-vlc-investigation/task-03-playback-module-boundaries.md`.

Answer these questions with file and function evidence:

1. Which module receives play, pause, stop, seek, and track-load commands?
2. Which module opens Plex Part.key URLs, local files, or NAS paths?
3. Which module demuxes or decodes compressed media?
4. Which module outputs decoded PCM?
5. Which module converts sample formats?
6. Which module resamples?
7. Which module owns channel order and channel layout?
8. Which module routes source channels into Orbisonic renderer inputs?
9. Which module applies spatial rendering, Sonic Sphere mapping, Ambisonics handling, or custom layout logic?
10. Which module writes to the OS audio device?
11. Which module owns audio timing, PTS, latency, queue depth, underrun tracking, and drift correction?
12. Which module owns flush and drain semantics?

Create a boundary diagram in plain text. Use this style:

```text
[Transport/API]
    -> [MediaSource/Open]
    -> [Decode]
    -> [PCM Format Conversion]
    -> [Resample]
    -> [Channel Map]
    -> [Spatial Renderer]
    -> [Device Output]
```

Under each box, list:

- current owner,
- whether it should be replaceable,
- whether VLC could plausibly replace this stage,
- what would break if this stage were replaced wholesale.

Add a section called "Boundary risks introduced by modularization." Focus on:

- stale buffers crossing module boundaries,
- thread mismatches,
- losing PTS or latency metadata,
- implicit interleaved versus planar assumptions,
- implicit float versus int assumptions,
- hidden downmix,
- channel-order erosion,
- resampling twice,
- wrong device format negotiation,
- shared-mode OS conversion.

Do not implement anything in this task.

End your response with exactly:

`I just finished task 3 and I'm ready for task 4.`

---

## Prompt 4: Reproduce and characterize the bad audio

You are Codex operating inside the Orbisonic repository.

Task 4 is to turn "sounds like shit" into reproducible failure modes and instrumentation requirements.

Create `docs/audio-vlc-investigation/task-04-bad-audio-reproduction.md`.

First, find existing issue reports, logs, comments, test files, or sample references related to bad audio. Search for terms like:

```bash
rg -n "distort|distortion|clip|clipping|crackle|crackling|pop|popping|glitch|underrun|overrun|dropout|drop out|latency|drift|bad audio|sounds|noise|artifact|stutter|resample|downmix|channel" .
```

Then define a reproduction matrix in prose, not a table, covering:

- stereo,
- 5.1,
- 7.1,
- Ambisonics,
- custom Sonic Sphere layout,
- 30-channel,
- 52-channel if supported by current tooling,
- Plex remote URL,
- local file,
- NAS path,
- sample rates such as 44.1 kHz, 48 kHz, 96 kHz,
- common sample formats such as int16, int24, int32, float32.

For each failure class, document how to detect it objectively:

1. Decode corruption:
   - compare Orbisonic decoded PCM to `ffmpeg` or another known-good reference.
2. Format conversion error:
   - check int and float normalization, endian, clipping, and planar/interleaved handling.
3. Resampling error:
   - check source rate, renderer rate, device rate, and whether OS resamples again.
4. Buffering/timing error:
   - log callback cadence, queue depth, underruns, overruns, and drift.
5. Channel routing error:
   - use one-channel-at-a-time impulse tests.
6. Gain/mixing error:
   - check summed peaks, duplicate channels, hidden normalization, and clipping.
7. Device backend error:
   - log actual OS device format, shared/exclusive mode, channel count, and latency.

If the repo already has logging hooks, identify exact places to add diagnostics in a later task. If it does not, propose where hooks should be added.

Do not make app code changes yet unless a harmless docs-only helper is needed.

End your response with exactly:

`I just finished task 4 and I'm ready for task 5.`

---

## Prompt 5: Design the reference media and objective test harness

You are Codex operating inside the Orbisonic repository.

Task 5 is to define or create the test assets and objective checks needed to prove whether Orbisonic, VLC, or a bridge preserves audio correctly.

Create `docs/audio-vlc-investigation/task-05-reference-tests.md`.

Find any existing test media generation scripts. If none exist, propose scripts under a non-invasive location such as:

`tools/audio-test-assets/`

Do not add large binary media files to the repo unless the project already has a convention for that.

Design tests for:

1. Stereo impulse file.
2. 5.1 impulse file.
3. 7.1 impulse file.
4. 30-channel impulse file, one impulse per channel at known time offsets.
5. 52-channel impulse file, one impulse per channel at known time offsets.
6. 30-channel pink-noise sweep, one active channel at a time.
7. 52-channel pink-noise sweep, one active channel at a time.
8. Representative real Orbisonic media that currently sounds bad.
9. Plex URL playback with the same media if possible.

For each asset, specify:

- container,
- codec,
- sample rate,
- sample format,
- channel count,
- layout metadata,
- expected peak/RMS behavior,
- expected channel identity behavior,
- expected PTS behavior,
- expected result through current Orbisonic path,
- expected result through VLC standalone,
- expected result through libVLC callback bridge,
- expected result through Orbisonic renderer.

If writing scripts is safe, create a minimal generator script or pseudocode for generating impulse WAVs using available tools. Prefer small deterministic assets. Make sure generation supports 30 and 52 channels or explicitly records the blocker.

Define acceptance tolerances:

- decoded PCM must match reference within a documented tolerance,
- no hidden downmix,
- no unexpected sample-rate conversion,
- channel N impulse must appear at renderer input N for unmapped layouts,
- any Ambisonic convention must be preserved or explicitly mapped,
- no stale audio after seek,
- no underruns during long playback.

Add a section called "Why these tests diagnose architecture differences." Explain which architecture decision each test exposes.

End your response with exactly:

`I just finished task 5 and I'm ready for task 6.`

---

## Prompt 6: Acquire and map the VLC source architecture

You are Codex operating inside the Orbisonic repository.

Task 6 is to inspect VLC source architecture, not to integrate it.

Create `docs/audio-vlc-investigation/task-06-vlc-source-map.md`.

If internet and shell access are available, clone or fetch these into a clearly external directory that is not mixed into Orbisonic source:

```bash
mkdir -p _external
git clone https://github.com/videolan/vlc.git _external/vlc
git clone https://github.com/videolan/vlc-3.0.git _external/vlc-3.0
```

If cloning is not available, document the blocker and use any vendored, cached, or browser-accessible source that exists.

Record:

- VLC repo URL,
- VLC branch,
- VLC commit hash,
- VLC 3.0 branch and commit hash if available,
- file paths inspected.

Inspect at least:

```text
README.md
COPYING
COPYING.LIB
include/vlc/libvlc_media_player.h
include/vlc_aout.h
include/vlc_es.h
lib/audio.c
src/audio_output/
modules/audio_output/
modules/audio_filter/
modules/MODULES_LIST
```

Run searches like:

```bash
rg -n "libvlc_audio_set_callbacks|libvlc_audio_set_format|libvlc_audio_set_format_callbacks|audio_set_callbacks|audio_set_format" _external/vlc _external/vlc-3.0

rg -n "audio_output_t|aout_|AOUT_CHAN_MAX|INPUT_CHAN_MAX|audio_format_t|channel_type|AMBISONICS|i_physical_channels|i_channels|i_chan_mode" _external/vlc/include _external/vlc/src _external/vlc/modules

rg -n "ChannelReorder|ChannelExtract|Interleave|Deinterleave|channel.*reorder|channel.*map|remap|spatialaudio|spatializer|channel_mixer|simple_channel_mixer|trivial_channel_mixer" _external/vlc/include _external/vlc/src _external/vlc/modules

rg -n "WASAPI|IAudioClient|IAudioRenderClient|AUDCLNT|exclusive|shared|CoreAudio|AUHAL|AudioUnit|snd_pcm|PulseAudio|PipeWire|JACK|DirectSound|MMDevice|amem" _external/vlc/modules/audio_output _external/vlc/src
```

Map VLC architecture in prose:

- public libVLC embedding API,
- decoded audio callback API,
- internal audio output abstraction,
- platform-specific output modules,
- audio filters,
- resamplers,
- channel mapping and reordering,
- memory/custom output paths.

Add a section called "VLC design decisions." Explain why VLC separates:

- demux/decode from output,
- public libVLC from internal libvlccore,
- filters from output modules,
- channel mapping from platform device output,
- timing reports from buffer submission,
- GPL application code from LGPL embeddable engine.

Do not recommend an implementation yet.

End your response with exactly:

`I just finished task 6 and I'm ready for task 7.`

---

## Prompt 7: Analyze libVLC audio callbacks as a decode bridge

You are Codex operating inside the Orbisonic repository.

Task 7 is to determine whether libVLC audio callbacks can replace Orbisonic's demux/decode stage while preserving Orbisonic's router and renderer.

Create `docs/audio-vlc-investigation/task-07-libvlc-callback-bridge.md`.

Inspect the relevant VLC 3.0 and current headers and source. Focus on:

- `libvlc_audio_set_callbacks`
- `libvlc_audio_set_volume_callback`
- `libvlc_audio_set_format`
- `libvlc_audio_set_format_callbacks`
- setup callback
- cleanup callback
- play callback
- pause callback
- resume callback
- flush callback
- drain callback
- sample format strings such as `f32l`, `S16N`, or current equivalents
- threading guarantees or lack of guarantees
- channel-count negotiation
- sample-rate negotiation
- whether callbacks override OS output
- whether source channel count is preserved or caller-selected
- what happens when requested callback channels differ from source channels.

Answer these questions with exact source references:

1. Can libVLC decode without writing audio to the OS?
2. Can libVLC deliver PCM into an application callback?
3. Can Orbisonic request float32 PCM?
4. Can Orbisonic request or observe the decoded source channel count?
5. Does libVLC expose channel layout metadata sufficient for Sonic Sphere or Ambisonic routing?
6. Does libVLC downmix when the callback asks for fewer channels?
7. Does libVLC support 30-channel callback output?
8. Does libVLC support 52-channel callback output?
9. If 30 or 52 cannot be proven, what exact experiment would prove it?
10. Can this path support Plex Part.key URLs, headers, redirects, and range requests?
11. How do seek, pause, flush, drain, and stop map to Orbisonic transport?

Propose a bridge architecture, but do not implement it yet:

```text
MediaSource/PlexUrl/LocalPath
    -> LibVlcAudioSource
    -> DecodedPcmRingBuffer
    -> OrbisonicChannelRouter
    -> OrbisonicSpatialRenderer
    -> OrbisonicDeviceOutput
```

Explain why this architecture is safer than:

```text
MediaSource
    -> FullVlcPlayer
    -> OS default audio output
```

Add a section called "Architectural difference being tested." Explain the difference between:

- replacing decode,
- replacing render,
- replacing device output,
- replacing the entire player.

End your response with exactly:

`I just finished task 7 and I'm ready for task 8.`

---

## Prompt 8: Analyze VLC's internal audio output abstraction and platform backends

You are Codex operating inside the Orbisonic repository.

Task 8 is to understand whether Orbisonic should imitate VLC's audio output architecture or reuse parts of it.

Create `docs/audio-vlc-investigation/task-08-vlc-aout-and-device-backends.md`.

Inspect:

```text
include/vlc_aout.h
src/audio_output/
modules/audio_output/wasapi*
modules/audio_output/mmdevice*
modules/audio_output/directsound*
modules/audio_output/alsa*
modules/audio_output/pulse*
modules/audio_output/auhal*
modules/audio_output/coreaudio*
modules/audio_output/jack*
modules/audio_output/pipewire*
modules/audio_output/amem*
```

Not all files will exist in every VLC version. Document what exists.

Answer:

1. What is the VLC `audio_output_t` lifecycle?
2. What does `start` negotiate?
3. What does `play` receive?
4. What does `time_get` or timing report provide?
5. What does `flush` mean?
6. What does `drain` mean?
7. How are pause and resume handled?
8. How are device selection and hotplug handled?
9. How are latency and drift handled?
10. Which backends support explicit device selection?
11. Which backends support high channel counts?
12. Which backends are likely limited by OS shared-mode conversion?
13. Which backends can fail loudly instead of downmixing?
14. Does VLC include ASIO support, JACK support, PipeWire support, or other pro-audio paths relevant to 30 or 52 outputs?

Add a section called "Why VLC's output architecture sounds reliable." Focus on decisions, not mythology:

- explicit lifecycle,
- negotiated output format,
- bounded timing model,
- flush and drain semantics,
- separation of filters from device output,
- latency reports,
- backend-specific handling.

Then compare to Orbisonic:

- Does Orbisonic have the same lifecycle clarity?
- Does Orbisonic log the negotiated device format?
- Does Orbisonic know actual hardware latency?
- Does Orbisonic treat flush and drain differently?
- Does Orbisonic have a clock owner?
- Does Orbisonic make downmix or resampling explicit?

Do not copy VLC code. Identify concepts that Orbisonic could imitate safely.

End your response with exactly:

`I just finished task 8 and I'm ready for task 9.`

---

## Prompt 9: Analyze VLC channel mapping, Ambisonics, and 30/52-channel feasibility

You are Codex operating inside the Orbisonic repository.

Task 9 is to determine whether VLC's channel model can preserve Orbisonic's custom high-channel layouts.

Create `docs/audio-vlc-investigation/task-09-vlc-channel-feasibility.md`.

Inspect:

```text
include/vlc_es.h
include/vlc_aout.h
src/audio_output/
src/audio_output/filters.c
modules/audio_filter/channel_mixer/
modules/audio_filter/remap*
modules/audio_filter/spatializer*
modules/audio_filter/spatialaudio*
modules/codec/
modules/demux/
```

Search for:

```bash
rg -n "AOUT_CHAN_MAX|INPUT_CHAN_MAX|i_channels|i_physical_channels|channel_type|AMBISONIC|AMBISONICS|Ambisonic|ambisonic|WG4|aout_CheckChannelReorder|aout_ChannelReorder|aout_CheckChannelExtraction|aout_ChannelExtract|remap|channel_mixer|downmix|binaural|spatial" _external/vlc
```

Answer these questions with exact evidence:

1. What is VLC's maximum number of mapped speaker channels?
2. What is VLC's maximum number of unmapped input channels?
3. Is there any separate limit on `i_channels`, decoded channels, or output channels?
4. What does VLC mean by `i_physical_channels`?
5. What does VLC mean by `channel_type`?
6. What does VLC do with Ambisonics?
7. What channel order does VLC consider canonical?
8. Where does VLC reorder channels?
9. Where does VLC extract channels?
10. Where does VLC downmix?
11. Where does VLC resample?
12. Which code paths would reject, truncate, downmix, reorder, or reinterpret 30 channels?
13. Which code paths would reject, truncate, downmix, reorder, or reinterpret 52 channels?

Be extremely careful about the difference between these cases:

- source stream can contain N channels,
- demuxer can describe N channels,
- decoder can produce N channels,
- libVLC callback can deliver N channels,
- VLC filters can process N channels,
- mapped speaker layout can represent N channels,
- OS audio backend can render N channels,
- target hardware can expose N physical outputs.

Add a section called "Preliminary 30/52 go/no-go."

Use only these answer forms:

- "30 channels are proven viable through path X because ..."
- "30 channels are not proven yet because ..."
- "30 channels are blocked by exact code path X because ..."
- "52 channels are proven viable through path X because ..."
- "52 channels are not proven yet because ..."
- "52 channels are blocked by exact code path X because ..."

Do not write "should work" without evidence.

End your response with exactly:

`I just finished task 9 and I'm ready for task 10.`

---

## Prompt 10: Compare Orbisonic and VLC architecture decisions to find the real difference

You are Codex operating inside the Orbisonic repository.

Task 10 is the key diagnostic task. Compare Orbisonic's current architecture against VLC's architecture and explain which design differences plausibly explain why VLC sounds good and Orbisonic sounds bad.

Create `docs/audio-vlc-investigation/task-10-architecture-decision-comparison.md`.

Use all previous task files.

Do a decision-by-decision comparison in prose. For each category below, write:

- what Orbisonic does,
- what VLC does,
- why Orbisonic may have chosen its approach,
- why VLC likely chose its approach,
- which choice is better for ordinary playback,
- which choice is better for 30 and 52 channel spatial playback,
- how this difference could produce bad audio,
- what test would confirm or reject this as the root cause.

Categories:

1. Media opening:
   - Plex/local/NAS handling,
   - range requests,
   - metadata extraction,
   - error handling.

2. Demux and decode:
   - codec coverage,
   - timestamp handling,
   - source channel count,
   - recovery from bad packets.

3. PCM format:
   - float versus int,
   - planar versus interleaved,
   - endian handling,
   - normalization.

4. Resampling:
   - resampler quality,
   - drift correction,
   - source rate versus device rate,
   - accidental double resampling.

5. Channel layout:
   - standard surround layouts,
   - Ambisonics,
   - Sonic Sphere,
   - unmapped discrete channels,
   - channel-order authority.

6. Buffer ownership:
   - who allocates,
   - who frees,
   - copy versus reference,
   - lifetime across callbacks.

7. Thread ownership:
   - decode thread,
   - render thread,
   - device callback thread,
   - UI/control thread.

8. Clock ownership:
   - media clock,
   - audio device clock,
   - system monotonic clock,
   - renderer timeline.

9. Flush/drain/seek:
   - stale buffer prevention,
   - generation counters,
   - end-of-stream behavior.

10. Device negotiation:
    - shared versus exclusive mode,
    - actual output format,
    - actual channel count,
    - actual latency.

11. Gain and mixing:
    - hidden gain,
    - volume,
    - normalization,
    - limiter,
    - clipping,
    - duplicate channels.

12. Failure policy:
    - fail loudly,
    - fallback to stereo,
    - fallback to OS default,
    - silent downmix,
    - logged warnings.

End this file with a ranked list of the most likely root causes. Each root cause must include:

- evidence so far,
- why it explains the symptoms,
- why VLC would avoid it,
- specific next test.

This task should make the real architectural differences explicit. Do not recommend implementation yet unless the evidence is already decisive.

End your response with exactly:

`I just finished task 10 and I'm ready for task 11.`

---

## Prompt 11: Design Path A, libVLC demux/decode bridge with Orbisonic renderer

You are Codex operating inside the Orbisonic repository.

Task 11 is to design the safest VLC-based architecture if VLC is useful primarily for media opening, demuxing, decoding, buffering, and callback delivery.

Create `docs/audio-vlc-investigation/task-11-path-a-libvlc-decode-bridge-design.md`.

Design this path:

```text
MediaSource/PlexUrl/LocalPath
    -> LibVlcAudioSource
    -> DecodedPcmRingBuffer
    -> OrbisonicChannelRouter
    -> OrbisonicSpatialRenderer
    -> OrbisonicDeviceOutput
```

Write a concrete design for a new module such as:

- `LibVlcAudioSource`
- `VlcDecodeBridge`
- `LibVlcPcmSource`

Choose names that fit the repo's existing conventions.

Define interfaces in pseudocode using the repo's style. Include something like:

```cpp
class IAudioDecodeSource {
public:
    virtual OpenResult open(const MediaLocation& location,
                            const DecodeOptions& options) = 0;
    virtual void start() = 0;
    virtual void pause() = 0;
    virtual void seek(AudioTime t) = 0;
    virtual void stop() = 0;
    virtual AudioStreamInfo streamInfo() const = 0;
    virtual bool read(AudioBlock& out) = 0;
    virtual ~IAudioDecodeSource() = default;
};
```

Adjust language and syntax to the actual repo.

Specify:

1. Module boundary.
2. Ownership of libVLC instance, media, media player, and callbacks.
3. How Plex URLs and headers are passed.
4. How local and NAS paths are passed.
5. Requested callback sample format.
6. How actual sample format is validated.
7. How actual channel count is validated.
8. How source channel layout metadata is captured.
9. How Sonic Sphere metadata is preserved outside VLC.
10. How Ambisonic metadata is preserved or mapped.
11. Ring buffer design.
12. Callback threading.
13. How to avoid blocking inside callbacks.
14. How PTS is captured or generated.
15. How seek, pause, flush, drain, stop, and teardown work.
16. How stale buffers are rejected.
17. How errors are surfaced.
18. How fallback to the existing path works.
19. What feature flag controls this path.
20. What logs must be emitted.

Add a section called "Why this path preserves Orbisonic's architecture."

Explain:

- VLC replaces decode, not Orbisonic's spatial renderer.
- Orbisonic remains the channel-layout authority.
- Orbisonic remains the high-channel renderer.
- Orbisonic remains responsible for 30 and 52 channel mapping.
- VLC's standard speaker layout limits are less dangerous because OS output is bypassed.
- The remaining risk is whether callbacks preserve high channel PCM.

Add a section called "Path A acceptance criteria."

Include at least:

- stereo reference decode passes,
- 5.1 and 7.1 channel identity passes,
- 30 channel identity passes or exact blocker is documented,
- 52 channel identity passes or exact blocker is documented,
- no hidden downmix,
- no clipping,
- seek does not play stale buffers,
- 20 minute playback has no underruns on target hardware.

Do not implement yet.

End your response with exactly:

`I just finished task 11 and I'm ready for task 12.`

---

## Prompt 12: Design Path B, VLC-inspired native Orbisonic audio output backend

You are Codex operating inside the Orbisonic repository.

Task 12 is to design a path where Orbisonic keeps its current decoder and channel router, but repairs or replaces its device-output backend using VLC's architecture as a model.

Create `docs/audio-vlc-investigation/task-12-path-b-native-output-backend-design.md`.

This path is appropriate if previous tasks indicate decoded PCM is already good and distortion is introduced by rendering, buffering, timing, or OS device output.

Design this path:

```text
OrbisonicMediaSource
    -> OrbisonicDecoder
    -> OrbisonicChannelRouter
    -> OrbisonicSpatialRenderer
    -> NewOrRepairedOrbisonicDeviceOutput
```

Use VLC's `audio_output_t` as a conceptual model, not as copied code.

Define a backend lifecycle in repo style:

- open/configure,
- start,
- submit/play,
- pause,
- resume,
- flush,
- drain,
- stop,
- close,
- report timing,
- report underrun,
- report actual device format,
- select device.

Specify:

1. Which current Orbisonic backend files would be replaced or modified.
2. Which device APIs are relevant for target OSes:
   - WASAPI shared,
   - WASAPI exclusive,
   - CoreAudio/AUHAL,
   - ALSA,
   - PulseAudio/PipeWire,
   - JACK,
   - ASIO if needed.
3. How device format negotiation works.
4. How the backend refuses unsupported channel counts.
5. How 30 and 52 channel devices are opened.
6. How shared-mode downmixing is detected.
7. How resampling is avoided or made explicit.
8. How latency is measured.
9. How drift is handled.
10. How buffers are queued.
11. How flush and drain differ.
12. How seek clears stale buffers.
13. How channel identity is preserved.
14. How output format is logged.
15. How feature flag and rollback work.

Add a section called "Why this path may be better than libVLC."

Explain:

- It avoids libVLC channel-count uncertainty.
- It preserves Orbisonic's existing decoder if decode is proven good.
- It directly attacks timing, buffer, and device problems.
- It can target pro-audio hardware more explicitly than VLC.
- It avoids full player black-box behavior.

Add a section called "Why this path may be worse than libVLC."

Explain:

- More platform-specific engineering.
- More risk of repeating bugs VLC already solved.
- More testing burden.
- Codec/demux issues remain unresolved if decode is the problem.

Do not implement yet.

End your response with exactly:

`I just finished task 12 and I'm ready for task 13.`

---

## Prompt 13: Evaluate Path C and Path D, full libVLC playback and VLC memory/custom output

You are Codex operating inside the Orbisonic repository.

Task 13 is to evaluate two less-preferred VLC strategies so the final recommendation is not blind.

Create `docs/audio-vlc-investigation/task-13-path-c-d-evaluation.md`.

Path C:

```text
MediaSource
    -> FullLibVlcPlayer
    -> VLC-selected OS audio output
```

Evaluate full libVLC playback as:

- a diagnostic baseline,
- a possible quick workaround,
- a possible final architecture.

Answer:

1. Does standalone VLC or full libVLC playback sound clean with the same bad sample?
2. Does it preserve all channels?
3. Does it output 30 discrete channels?
4. Does it output 52 discrete channels?
5. Does it preserve Sonic Sphere routing?
6. Can Orbisonic control channel mapping?
7. Can Orbisonic integrate spatial rendering?
8. Does it bypass Orbisonic's value proposition?

Likely conclusion to verify:

Full libVLC playback may be useful as a baseline, but it is probably not the final architecture unless it proves high-channel routing and custom layouts.

Path D:

```text
MediaSource
    -> VLC demux/decode
    -> VLC memory/custom audio output module
    -> Orbisonic PCM ingest
    -> Orbisonic renderer
```

Investigate VLC memory/custom output mechanisms, including `amem` if present.

Answer:

1. Is a memory audio output module present in inspected VLC versions?
2. Is it public and stable enough?
3. Is it better than libVLC callbacks?
4. Does it preserve high channel counts?
5. Does it expose better timing or layout metadata?
6. Does it require internal VLC APIs?
7. Does it increase licensing or packaging risk?
8. Is it supported by libVLC distribution packages?

Add a section called "What these paths teach us architecturally."

Explain the difference between:

- using VLC as a whole player,
- using VLC as a decode engine,
- using VLC as an output engine,
- using VLC as an architectural reference.

Do not implement anything in this task.

End your response with exactly:

`I just finished task 13 and I'm ready for task 14.`

---

## Prompt 14: Licensing, dependency, and packaging risk analysis

You are Codex operating inside the Orbisonic repository.

Task 14 is to document the licensing and packaging risks of each VLC integration path.

Create `docs/audio-vlc-investigation/task-14-licensing-packaging.md`.

Inspect Orbisonic's own license and distribution assumptions if available.

Inspect VLC license files and headers:

```text
COPYING
COPYING.LIB
README.md
license headers in files under include/
license headers in files under lib/
license headers in files under src/
license headers in modules/audio_output/
license headers in modules/audio_filter/
```

Answer:

1. What is Orbisonic's license or likely distribution model?
2. Does Orbisonic currently statically link, dynamically link, or bundle third-party native libraries?
3. Would dynamic linking to libVLC be acceptable under LGPL obligations?
4. What obligations appear if Orbisonic distributes libVLC binaries?
5. What obligations appear if Orbisonic modifies libVLC?
6. What obligations appear if Orbisonic copies VLC source files?
7. Which inspected VLC files are LGPL?
8. Which inspected VLC files are GPL?
9. Are any useful VLC modules GPL-only?
10. Are platform codecs or VLC plugin dependencies a packaging risk?
11. How difficult is Windows packaging?
12. How difficult is macOS packaging?
13. How difficult is Linux packaging?
14. Does adding libVLC increase app size or plugin management complexity?
15. Is code signing, notarization, or plugin discovery relevant?
16. Does the feature flag need to support "VLC unavailable" at runtime?

Do not provide legal advice. Provide engineering risk analysis and say where legal review is required.

Add a section called "Licensing impact by architecture."

Cover:

- Path A: libVLC callback bridge.
- Path B: VLC-inspired native backend with no copied code.
- Path C: full libVLC playback.
- Path D: custom VLC module or copied internal module code.

End with a recommended low-risk legal/packaging path, if one exists.

End your response with exactly:

`I just finished task 14 and I'm ready for task 15.`

---

## Prompt 15: Create a guarded prototype plan and minimal spike only if evidence supports it

You are Codex operating inside the Orbisonic repository.

Task 15 is to prepare an implementation spike, but only after reading all prior task files.

Create `docs/audio-vlc-investigation/task-15-prototype-plan.md`.

First, state which path is currently most supported by evidence:

- Path A: libVLC decode bridge.
- Path B: VLC-inspired native output backend.
- Path C: full libVLC playback.
- Path D: VLC memory/custom output.
- No VLC integration yet, fix current Orbisonic bug first.

Then create a prototype plan with PR-sized steps.

The default PR sequence should look like this, adjusted to the actual repo:

1. Add diagnostics and logging for current playback.
2. Add reference decode comparison.
3. Add impulse and channel identity tests.
4. Add optional libVLC dependency or build flag only if Path A or C is viable.
5. Add new VLC bridge module behind a feature flag if Path A is viable.
6. Add seek, pause, flush, drain, and teardown handling.
7. Validate stereo, 5.1, and 7.1.
8. Validate 30 channels.
9. Validate 52 channels or document exact blocker.
10. Validate Plex/local/NAS paths.
11. Validate long playback.
12. Validate packaging.
13. Switch default only after acceptance criteria pass.

If and only if the repo structure and prior evidence make a minimal code spike safe, create a small non-default prototype skeleton behind a feature flag. It must not change the default playback path.

If creating code:

- keep VLC-specific types out of core interfaces,
- do not copy VLC source,
- add build guard such as `ORBISONIC_ENABLE_LIBVLC` or repo-appropriate equivalent,
- add a runtime feature flag,
- add logs for negotiated sample rate, format, channel count, and layout,
- add tests or compile checks,
- keep old backend available,
- provide `git diff --stat`.

If not creating code, explain why not and provide exact next implementation step.

Add a section called "Rollback and safety."

Include:

- feature flag,
- fallback backend,
- build without VLC,
- runtime unavailable VLC behavior,
- failing loudly on unsupported channel counts,
- preserving old path until tests pass.

End your response with exactly:

`I just finished task 15 and I'm ready for task 16.`

---

## Prompt 16: Write the final technical report and go/no-go recommendation

You are Codex operating inside the Orbisonic repository.

Task 16 is to synthesize all findings into a final technical report.

Create:

`docs/audio-vlc-investigation/final-report-orbisonic-vlc-audio.md`

Use all prior task files. Do not invent findings not supported by those files.

The report must have these sections:

1. Executive recommendation

State one direct recommendation:

- Use libVLC callback bridge first.
- Repair Orbisonic's native renderer using VLC's architecture as a reference.
- Use full libVLC playback.
- Use VLC memory/custom output.
- Do not use VLC yet.
- More investigation required because a specific blocker remains.

2. Current Orbisonic playback architecture

Describe the actual pipeline with file paths and functions:

`media location -> opener/fetcher -> demuxer -> decoder -> PCM converter -> resampler -> channel mapper -> spatial renderer -> device backend -> OS/hardware`

3. What changed during modularization

Summarize relevant recent changes and how they may affect:

- buffer ownership,
- thread ownership,
- callback timing,
- sample format,
- channel order,
- seek/flush/drain,
- device negotiation.

4. Reproduction of bad audio

Describe symptoms, test assets, logs, and objective measurements.

5. Failure-mode analysis

Rank likely root causes:

- decode,
- format conversion,
- resampling,
- channel routing,
- buffering,
- timing,
- gain/clipping,
- device output,
- OS conversion.

6. VLC architecture relevant to Orbisonic

Explain:

- libVLC public API,
- audio callbacks,
- internal audio output abstraction,
- platform output modules,
- filters,
- resamplers,
- channel mapping.

7. Architecture decision comparison

This is the main explanatory section. For each major difference between Orbisonic and VLC, explain:

- decision,
- why Orbisonic likely made it,
- why VLC made its choice,
- what it improves,
- what it risks,
- whether it matters for ordinary playback,
- whether it matters for 30 and 52 channel playback,
- how it could cause bad audio.

8. 30 and 52 channel feasibility

Give a concrete answer for each:

- proven viable,
- not proven,
- blocked.

Explain decode feasibility, callback feasibility, mapped channel limits, unmapped channel handling, output-device feasibility, platform constraints, and Sonic Sphere mapping constraints.

9. Implementation options

Analyze Path A, Path B, Path C, and Path D.

For each, include:

- what changes,
- what stays the same,
- expected audio-quality benefit,
- channel-count risk,
- latency risk,
- integration complexity,
- licensing risk,
- packaging risk,
- testability,
- rollback strategy.

10. Recommended architecture

Specify exact module names, interfaces, boundaries, feature flags, logging, buffer ownership, timestamp handling, channel-layout handling, error handling, and fallback path.

11. Incremental implementation plan

Break into PR-sized steps. Include tests before default replacement.

12. Acceptance criteria

At minimum:

- current bad-audio sample sounds clean through proposed path,
- decoded PCM matches reference within tolerance,
- no clipping,
- no hidden downmix,
- 30-channel impulse identity test passes or exact blocker is documented,
- 52-channel impulse identity test passes or exact blocker is documented,
- seek, pause, flush, drain, and stop behave correctly,
- no stale audio after seek,
- no underruns in a 20 minute playback test,
- actual device format is logged,
- fallback to old backend is possible,
- packaging works on target OSes,
- licensing review items are documented.

13. Risks and unresolved questions

Each risk must include a mitigation or resolving test.

14. Final go/no-go

End with a direct go/no-go and the next concrete engineering action.

The report must be concrete enough for implementation. It must not say "VLC should sound better" without explaining which VLC architectural decision is responsible and how Orbisonic can adopt it without breaking 30 or 52 channel playback.

End your response with exactly:

`I just finished task 16 and I'm ready for task 17.`
