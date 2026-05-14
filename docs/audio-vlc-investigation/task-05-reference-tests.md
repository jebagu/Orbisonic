# Task 05 - Reference Media And Objective Test Harness

## Scope

Task 5 defines the reference media, generated fixture strategy, and objective acceptance checks needed to prove whether the current Orbisonic path, VLC standalone, a future libVLC callback bridge, or Orbisonic's renderer preserves audio correctly.

This is a docs-only task. No app code, tests, scripts, resources, installer files, vendor files, calibration files, or binary media assets were changed.

## Evidence Commands

- `git status --short`
- `sed -n '300,380p' orbisonic_vlc_codex_prompt_sequence.md`
- `rg -n "ffmpeg|fixture|fixtures|generate|generator|impulse|pink|noise|sine|tone|wav|flac|caf|matroska|mka|AudioFileProbe|AVAudioFile|reference media|test asset|golden" Tests Sources scripts docs README.md Package.swift`
- `find Tests Sources scripts docs -maxdepth 3 -type f | sort`
- `find . -maxdepth 4 -type f \( -iname '*.wav' -o -iname '*.flac' -o -iname '*.caf' -o -iname '*.mka' -o -iname '*.aiff' -o -iname '*.pcm' \) | sort`
- `rg -n "makeTemporaryDirectory|write.*AudioFile|AVAudioFile\(forWriting|ffmpeg|ffprobe|XCTSkip|frameLength|standardFormatWithSampleRate|interleaved|floatChannelData|channelMap|impulse|pink|sweep|RMS|peak|hash|direct30|sampleRateConversionOccurred|underrun|dropped" Tests/OrbisonicTests Tests/AudioCoreTests Sources/Orbisonic Sources/AudioCore`
- Targeted reads of the existing fixture and golden-output tests listed below.

## Existing Fixture Convention

No committed audio media fixture directory or standalone media-generation script was found. The current convention is to generate deterministic fixtures inside temporary directories, or to build deterministic in-memory audio blocks directly in tests.

Existing generated-file evidence:

- `Tests/OrbisonicTests/AudioFileProbeTests.swift:7` through `:20` generate a temporary stereo WAV and probe it without prepared buffers.
- `Tests/OrbisonicTests/AudioFileProbeTests.swift:24` through `:59` generate a 96 kHz 7.1 Matroska/FLAC fixture with ffmpeg/ffprobe when those tools are available, and skip explicitly when unavailable.
- `Tests/OrbisonicTests/MatroskaFLACSupportTests.swift:209` through `:256` generate a temporary 7.1 Matroska/FLAC fixture and load it through `AudioFileLoader`.
- `Tests/OrbisonicTests/MatroskaFLACSupportTests.swift:262` through `:310` generate a temporary 7.1 Matroska/PCM fixture and load it through `AudioFileLoader`.
- `Tests/OrbisonicTests/LocalAudioFileSourceTests.swift:1` through `:120` generate temporary local WAV files and validate chunking, seek ranges, source sample-rate handling, and output format normalization.
- `Tests/OrbisonicTests/StreamingAudioFileSourceTests.swift:7` through `:164` generate temporary WAV files and validate bounded chunk decode, queue limits, engine start, RMS behavior, and meter independence from output volume.

Existing in-memory reference evidence:

- `Tests/OrbisonicTests/NormalMonitorGoldenAudioTests.swift:1` through `:134` use deterministic channel samples and impulses for stereo identity, duplicate-path detection, 5.1 downmix, LFE silence, and no HRTF/environment-node behavior.
- `Tests/AudioCoreTests/RenderKernelTests.swift:232` through `:255` assert Direct 30 golden output hash stability and no sample-rate conversion in render-kernel audit.
- `Tests/AudioCoreTests/MeteringTelemetryTests.swift:41` through `:57` validate peak/RMS math for deterministic samples.
- `Tests/AudioCoreTests/MeteringTelemetryTests.swift:309` through `:386` build direct31 in-memory impulse blocks and hash them with FNV-1a.
- `Tests/AudioCoreTests/OutputAdapterTests.swift:1` through `:120` use direct31 and stereo impulse blocks to prove desktop and Dante failure/gain isolation.

Fixture policy evidence:

- `docs/test-strategy.md:100` says privacy checks should search for personal paths, secrets, tokens, and runtime logs.
- `docs/test-strategy.md:117` says fixtures should use generated audio, deterministic PCM buffers, temporary directories, or repo-safe fixture data.
- `docs/test-strategy.md:119` says ffmpeg/ffprobe-dependent tests may skip when unavailable, but must skip explicitly.
- `docs/test-strategy.md:121` says hardware-specific facts belong in release verification notes, not unit fixtures.

Therefore Task 5 should not add binary media files. The least invasive future location for reusable generators is `tools/audio-test-assets/`, but this task records that as a proposal rather than adding scripts.

## Reference Asset Set

### 1. Stereo Impulse File

- Container: WAV as the primary asset; CAF as an optional Core Audio control.
- Codec: Float32 PCM first, then int16, int24, and int32 PCM variants.
- Sample rate: 44.1 kHz, 48 kHz, and 96 kHz.
- Sample format: Float32 non-interleaved as the canonical internal comparison; integer variants should normalize into Float32.
- Channel count: 2.
- Layout metadata: Stereo, front-left then front-right.
- Expected peak/RMS behavior: each channel has one full-scale or -6 dBFS impulse at a known frame; RMS equals `abs(impulse) / sqrt(frameCount)` for that channel and silence for all other frames.
- Expected channel identity behavior: left impulse appears only in channel 1 and right impulse appears only in channel 2, using one-based report labels and zero-based test indexes.
- Expected PTS behavior: first channel impulse at frame 1, second channel impulse at frame 1 plus a fixed offset such as 4,096 frames; after seek, no pre-seek impulse repeats.
- Expected result through current Orbisonic path: `AudioFileProbe`, prepared load, streaming source, and gapless source preserve two channels; normal monitor is stereo identity by the existing golden tests.
- Expected result through VLC standalone: audible output may be shaped by the OS/device output configuration, so standalone playback is a listening/control comparison rather than proof of decoded PCM identity until VLC internals are inspected.
- Expected result through libVLC callback bridge: callback PCM must preserve sample rate, channel count, impulse offsets, and float scale within tolerance; this remains unproven until Task 7.
- Expected result through Orbisonic renderer: stereo renderer receives channel 1 and 2 without swap, hidden mono sum, duplicate path, or meter side effect.

### 2. 5.1 Impulse File

- Container: WAV/WAVEEX primary; CAF optional if WAVEEX layout metadata is unreliable.
- Codec: Float32 PCM and int24 PCM.
- Sample rate: 48 kHz and 96 kHz primary; 44.1 kHz mismatch case for sample-rate diagnostics.
- Sample format: Float32 canonical, int24 conversion stress variant.
- Channel count: 6.
- Layout metadata: 5.1 with FL, FR, FC, LFE, SL, SR roles.
- Expected peak/RMS behavior: one impulse per channel at unique frame offsets; LFE is not silently boosted or folded into normal monitor unless the documented route says so.
- Expected channel identity behavior: channel N impulse appears only in source channel N before renderer input; normal-monitor downmix follows existing golden coefficients for front, center, side, and LFE policy.
- Expected PTS behavior: impulse offsets remain exact after decode and chunking; seek to the frame before an impulse produces that impulse once.
- Expected result through current Orbisonic path: local file probe/load should preserve six channels and layout confidence when metadata is present; normal-monitor output follows `NormalMonitorGoldenAudioTests`.
- Expected result through VLC standalone: device playback may downmix to stereo, so standalone must be inspected with VLC logs or external capture before treating it as a routing oracle.
- Expected result through libVLC callback bridge: six callback channels should preserve role order or expose enough metadata to map roles; unproven until libVLC callback inspection.
- Expected result through Orbisonic renderer: renderer input receives six distinct channels; production renderer applies the selected Sonic Sphere matrix without mutating normal-monitor policy.

### 3. 7.1 Impulse File

- Container: Matroska `.mka` with FLAC primary because the repo already tests this path; WAV/WAVEEX and CAF optional controls.
- Codec: FLAC for Matroska, Float32 PCM for WAV/CAF, int24 PCM for conversion stress.
- Sample rate: 96 kHz primary, plus 48 kHz and 44.1 kHz variants.
- Sample format: lossless FLAC decoded to Float32 canonical; int24 PCM for conversion checks.
- Channel count: 8.
- Layout metadata: 7.1 Surround when container metadata can express it; otherwise discrete channel count with explicit fixture manifest.
- Expected peak/RMS behavior: one impulse per channel at known offsets; no clipping, gain normalization, or channel dropout.
- Expected channel identity behavior: eight source channels survive probe, demux, decode, conversion, split, and renderer input.
- Expected PTS behavior: Matroska demux and FLAC decode preserve frame offsets; any encoder priming or padding must be recorded in the manifest.
- Expected result through current Orbisonic path: Matroska/FLAC probe and loader should preserve eight channels, matching current generated 7.1 tests.
- Expected result through VLC standalone: useful for container compatibility comparison, but OS output may downmix or reorder.
- Expected result through libVLC callback bridge: callback decode must prove whether 7.1 order and sample rate are caller-selected, source-preserved, or VLC-reordered.
- Expected result through Orbisonic renderer: automatic renderer policy must not silently reinterpret unsupported 7.1 content as the wrong layout; channel preservation must be visible even when renderer policy is constrained.

### 4. 30-Channel Impulse File

- Container: CAF primary for Core Audio high-channel PCM; WAV/WAVEEX secondary if the writer and reader preserve 30 channels; Matroska/FLAC optional if ffmpeg can generate and tag it deterministically.
- Codec: Float32 PCM primary; FLAC optional lossless transport.
- Sample rate: 48 kHz primary, 96 kHz stress variant.
- Sample format: Float32 canonical; int24 optional conversion variant.
- Channel count: 30.
- Layout metadata: Direct/discrete 30-channel manifest. The manifest must state that channel labels are ordinal, not conventional surround roles.
- Expected peak/RMS behavior: channel N contains one impulse at `baseFrame + N * spacing`; every other channel is silent at that frame.
- Expected channel identity behavior: source channel N appears at renderer input N and, in Direct 30 mode, output N.
- Expected PTS behavior: all impulse offsets survive decode and seek without frame drift; frame positions remain monotonic across chunk boundaries.
- Expected result through current Orbisonic path: source-channel admission is within the 64-channel cap, and automatic renderer policy currently resolves 30 channels to Direct 30.
- Expected result through VLC standalone: standalone output is unlikely to prove 30-channel identity without a matching multichannel device or file capture; it should mainly prove whether VLC can open/decode the asset.
- Expected result through libVLC callback bridge: must prove whether libVLC accepts 30 callback channels and whether it preserves all 30 source channels without downmix.
- Expected result through Orbisonic renderer: Direct 30 bypass must have no hidden downmix, no channel swap, no high-channel truncation, no gain normalization, and no sample-rate conversion.

### 5. 52-Channel Impulse File

- Container: CAF primary; WAV/WAVEEX and Matroska/FLAC optional only if tooling proves channel-count preservation.
- Codec: Float32 PCM primary; FLAC optional lossless transport.
- Sample rate: 48 kHz primary, 96 kHz stress variant.
- Sample format: Float32 canonical; int24 optional conversion variant.
- Channel count: 52.
- Layout metadata: Direct/discrete 52-channel manifest. The current source does not define an automatic 52-channel render mode.
- Expected peak/RMS behavior: channel N contains one impulse at `baseFrame + N * spacing`; all other samples remain zero.
- Expected channel identity behavior: decode/probe/source conversion preserve all 52 channels before renderer policy is applied.
- Expected PTS behavior: impulse offsets survive decode, chunking, and seek; no late-channel offsets collapse to zero or repeat.
- Expected result through current Orbisonic path: the 52-channel source is inside the 64-channel cap, but renderer policy lacks Direct 52, so tests must separate loader/source preservation from render support.
- Expected result through VLC standalone: useful only for open/decode capability unless an external multichannel capture path exists.
- Expected result through libVLC callback bridge: must prove whether libVLC accepts 52 callback channels; if it refuses, the failure must be recorded as a bridge constraint rather than an Orbisonic renderer finding.
- Expected result through Orbisonic renderer: current renderer support is expected to block or require explicit mode/contract work; it must not silently downmix 52 channels to a misleading lower count.

### 6. 30-Channel Pink-Noise Sweep

- Container: CAF primary; WAV/WAVEEX secondary if channel preservation is proven.
- Codec: Float32 PCM.
- Sample rate: 48 kHz.
- Sample format: Float32 canonical.
- Channel count: 30.
- Layout metadata: Direct/discrete 30-channel manifest.
- Expected peak/RMS behavior: one active channel at a time with deterministic seeded pink-ish noise at -18 dBFS RMS; inactive channels remain below -96 dBFS.
- Expected channel identity behavior: active channel walks from 1 through 30 with no bleed into adjacent source or output channels.
- Expected PTS behavior: each active window starts and ends at exact frame boundaries, for example 0.5 seconds per channel.
- Expected result through current Orbisonic path: local decode preserves all 30 windows; Direct 30 renderer preserves the walk order.
- Expected result through VLC standalone: listening can reveal obvious channel truncation on a configured device, but capture is required for objective channel identity.
- Expected result through libVLC callback bridge: callback output must preserve active-window order and RMS within tolerance across all 30 channels.
- Expected result through Orbisonic renderer: Direct 30 output channel walk must match the manifest and existing channel-walk semantics.

### 7. 52-Channel Pink-Noise Sweep

- Container: CAF primary.
- Codec: Float32 PCM.
- Sample rate: 48 kHz.
- Sample format: Float32 canonical.
- Channel count: 52.
- Layout metadata: Direct/discrete 52-channel manifest.
- Expected peak/RMS behavior: one active channel at a time at -18 dBFS RMS, inactive channels below -96 dBFS.
- Expected channel identity behavior: active channel index must survive decode and source conversion; renderer support is not assumed.
- Expected PTS behavior: active windows remain exact and monotonic from channel 1 through 52.
- Expected result through current Orbisonic path: source preservation should be tested independently from renderer policy; current renderer policy is expected to block or require explicit handling.
- Expected result through VLC standalone: proof requires file capture or callback capture, not OS playback alone.
- Expected result through libVLC callback bridge: must prove or disprove 52-channel callback support.
- Expected result through Orbisonic renderer: should record the current 52-channel render-policy blocker rather than downmixing silently.

### 8. Representative Real Orbisonic Media That Currently Sounds Bad

- Container: use the actual problematic container, or a short private-local excerpt kept outside tracked source.
- Codec: use the actual problematic codec.
- Sample rate: record with `AudioFileProbe`, ffprobe, and Orbisonic diagnostics.
- Sample format: record with ffprobe when available and with post-decode format capture once instrumentation exists.
- Channel count: actual source count.
- Layout metadata: actual container layout plus any Orbisonic detected layout and confidence.
- Expected peak/RMS behavior: no clipping, no NaN/Inf, and comparable peak/RMS to a trusted decode of the same excerpt.
- Expected channel identity behavior: if the source is multichannel, identify known audible markers or create a synthetic reduced excerpt with the same channel count/layout.
- Expected PTS behavior: no repeated audio after seek, no drift, and no missing chunk around the subjective bad-audio location.
- Expected result through current Orbisonic path: reproduce the subjective problem while capturing the objective boundary records from Task 4.
- Expected result through VLC standalone: compare whether VLC standalone sounds correct with the same media, while recording that device output may differ from Orbisonic's output route.
- Expected result through libVLC callback bridge: after Task 7, run the same media through callback PCM capture and compare against trusted decode.
- Expected result through Orbisonic renderer: renderer input/output captures identify whether the corruption appears before or after Sonic Sphere rendering.

This asset must not be committed if it is private music or carries personal/local path metadata. Store only a sanitized manifest, source facts, hashes, and objective measurements in tracked docs.

### 9. Plex URL Playback With The Same Media

- Container: same as representative media, delivered by Plex if available.
- Codec: same as representative media.
- Sample rate: same as representative media unless Plex transcodes; any transcode must be recorded as a different source.
- Sample format: source or transcoded format as observed through headers, Plex metadata, ffprobe, VLC, or future callback capture.
- Channel count: source or transcoded count.
- Layout metadata: source layout, Plex-reported layout, and decoded layout if available.
- Expected peak/RMS behavior: same as local reference when Plex delivers original bytes; different if Plex transcodes, and the transcode must be identified.
- Expected channel identity behavior: same as local reference only when byte-identical or lossless-equivalent delivery is proven.
- Expected PTS behavior: range requests, redirects, and seek should not repeat stale audio or skip impulse windows.
- Expected result through current Orbisonic path: blocked by Task 3 evidence because no active Plex URL or `Part.key` owner was found in current source.
- Expected result through VLC standalone: useful future comparison for URL handling, redirects, headers, and range requests.
- Expected result through libVLC callback bridge: future bridge must prove URL/header/range behavior and PCM preservation.
- Expected result through Orbisonic renderer: only meaningful after URL decode enters the same canonical PCM/router boundary as local files.

## Proposed Generator Shape

The proposed non-invasive future location is `tools/audio-test-assets/`. The generator should write to a caller-specified temporary or ignored output directory and should never commit generated media by default.

Recommended files:

- `tools/audio-test-assets/generate-reference-impulses.swift`
- `tools/audio-test-assets/generate-reference-noise-sweeps.swift`
- `tools/audio-test-assets/reference-media-manifest.json`

Generator behavior:

1. Accept `--channels`, `--sample-rate`, `--frames`, `--container`, `--sample-format`, `--spacing`, `--amplitude`, and `--output`.
2. Build deterministic Float32 non-interleaved buffers first.
3. For impulse files, write channel N's impulse at `baseFrame + N * spacing`.
4. For pink-noise sweeps, generate deterministic filtered noise with a fixed seed and one active channel window at a time.
5. Write a sidecar manifest containing channel count, sample rate, sample format, frame count, layout intent, impulse frames, expected peak, expected RMS, expected first non-zero frame, and source hash.
6. Prefer CAF for 30/52-channel Core Audio preservation; attempt WAV/WAVEEX only when the writer and reader prove channel-count preservation. If 30/52-channel WAV cannot be written or read back with the same channel count, record that as a WAV-container blocker, not an asset-generation blocker.
7. For Matroska/FLAC variants, use ffmpeg/ffprobe when available and skip explicitly when unavailable, matching existing generated-fixture test behavior.

Minimal pseudocode:

```swift
guard let format = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: sampleRate,
    channels: AVAudioChannelCount(channelCount),
    interleaved: false
) else {
    throw GeneratorError.unsupportedFormat(channelCount: channelCount, sampleRate: sampleRate)
}
guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
    throw GeneratorError.bufferAllocationFailed(channelCount: channelCount, frameCount: frameCount)
}
buffer.frameLength = AVAudioFrameCount(frameCount)
for channel in 0..<channelCount {
    let frame = baseFrame + channel * spacing
    buffer.floatChannelData![channel][frame] = amplitude
}
let file = try AVAudioFile(forWriting: outputURL, settings: format.settings)
try file.write(from: buffer)
```

This pseudocode attempts 30 and 52 channels at the buffer level by requesting an explicit channel count. If `AVAudioFormat`, buffer allocation, or file writing fails for 30/52 channels, the generator must record that as a local tooling blocker. The separate open question is container writer/reader preservation for WAV/WAVEEX at high channel counts; CAF should be the primary high-channel Core Audio fixture until that is tested.

## Objective Test Harness

### Reference Decode

Every file asset should have a trusted reference decode generated outside Orbisonic's playback path:

- For PCM WAV/CAF, parse through `AVAudioFile` and also through ffmpeg when available.
- For Matroska/FLAC, use ffmpeg to decode into raw Float32 or CAF/WAV plus ffprobe JSON for metadata.
- For libVLC callback bridge experiments, save callback PCM into the same canonical representation before comparing.

The canonical comparison shape is Float32 non-interleaved PCM with explicit sample rate, channel count, frame count, layout intent, and one-based channel labels in reports.

### Capture Points

Each harness run should capture:

- source descriptor before decode,
- trusted reference decode descriptor and hash,
- Orbisonic post-decode/post-conversion/post-channel-split descriptor and per-channel hash,
- streaming/gapless chunk source-frame ranges,
- renderer-input channel order,
- post-render/pre-device hash and peak/RMS,
- underflow and dropped-frame counters,
- selected output route channel count and sample rate,
- seek/pause/resume/flush/drain generation or frame-position facts where available.

These are the same boundaries defined in Task 4, but Task 5 supplies deterministic media to exercise them.

## Acceptance Tolerances

- Decoded Float32 PCM must match the trusted reference within absolute error `0.000001` for Float32 assets.
- Integer PCM converted to Float32 must match within one normalized least-significant bit for the source bit depth, plus `0.000001` rounding slack.
- FLAC and Matroska/FLAC decoded PCM must match the trusted lossless decode within the same PCM tolerance after any documented container trim or padding is accounted for.
- No sample may become NaN or Inf.
- No decoded sample may clip unless the reference source itself clips.
- No hidden downmix is allowed: decoded channel count must equal source channel count unless an explicit, documented conversion says otherwise.
- No unexpected sample-rate conversion is allowed. Source rate, decoded rate, renderer/session rate, and output route rate must be recorded separately.
- Channel N impulse must appear at renderer input N for unmapped direct/discrete layouts.
- Direct 30 output must preserve channel N to output N.
- Any Ambisonic convention must be preserved as raw channel order or explicitly mapped by a documented convention; silent reinterpretation as generic surround is a failure.
- Seek to before an impulse must produce the impulse once; seek away and back must not replay stale pre-seek buffers.
- Pause/resume must not duplicate or skip an impulse window.
- Flush/drain/stop must clear queued audio; the next source must not contain stale samples from the previous source.
- Long pink-noise sweep playback should complete without underflows, dropped frames, or queue starvation in software-only tests; hardware-only checks must record the actual route and remain manual.
- Peak/RMS must match expected values within `0.1 dB` for pink-noise windows and within exact sample tolerance for impulse assets.
- Inactive channels in impulse/noise-walk assets must remain below -96 dBFS.

## Why These Tests Diagnose Architecture Differences

The stereo impulse asset isolates basic decode, Float32 conversion, left/right identity, normal monitor identity, and stale-audio behavior after seek. If this fails, the problem is not a high-channel Sonic Sphere edge case.

The 5.1 asset exposes layout-role interpretation, normal-monitor downmix coefficients, LFE policy, and whether Orbisonic or VLC silently folds multichannel content into stereo.

The 7.1 Matroska/FLAC asset exercises demux and codec compatibility. It separates "can open the container" from "can preserve eight decoded channels" and directly challenges the current ffmpeg fallback path.

The 30-channel impulse asset exercises Orbisonic's production Direct 30 contract. It reveals truncation, high-channel channel swaps, hidden gain, unexpected sample-rate conversion, and renderer bypass mistakes.

The 52-channel impulse asset intentionally exceeds current automatic renderer policy while staying inside Orbisonic's source-channel cap. It diagnoses whether decode/source preservation and render support are being conflated.

The 30-channel and 52-channel pink-noise sweeps expose timing and long-running channel isolation problems that single-frame impulses can miss: queue starvation, per-window bleed, RMS drift, and high-channel performance pressure.

Representative real media diagnoses whether synthetic fixtures are too clean. It should be used only after privacy-safe handling is defined, and only objective facts should be tracked.

The Plex URL case diagnoses a different architecture boundary: authenticated/redirected/ranged network media ingestion. Because current Orbisonic source has no active Plex URL owner, this case is a future bridge/VLC comparison, not a current app regression test.

Together, these tests expose the major architecture choices in this investigation:

- AVFoundation/ffmpeg demux-decode versus VLC demux-decode,
- local file path versus remote URL ingestion,
- whole-file prepared loading versus bounded streaming/gapless chunks,
- source channel preservation versus renderer policy,
- layout metadata interpretation versus raw direct-channel order,
- normal monitor output versus Sonic Sphere production output,
- software PCM correctness versus platform device backend behavior,
- callback PCM capture versus standalone OS playback.

## Task 05 Conclusion

The repo already has the right fixture discipline: generate deterministic audio in temporary directories, keep expected values small and reviewable, and skip ffmpeg-dependent tests explicitly when tools are unavailable. The missing piece is a reusable reference-media generator and harness that captures canonical PCM and boundary metadata for stereo, 5.1, 7.1, 30-channel, 52-channel, real-media, and future Plex/libVLC cases. Until that exists, VLC standalone playback can be a comparison point but not an objective replacement decision.
