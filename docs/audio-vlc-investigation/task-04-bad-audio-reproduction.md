# Task 04 - Bad Audio Reproduction And Instrumentation

## Scope

Task 4 turns the subjective report that playback sounds bad into reproducible failure classes, test media requirements, and instrumentation requirements.

This is a docs-only task. No app code, tests, scripts, resources, installer files, vendor files, or calibration files were changed.

## Evidence Commands

- `git status --short`
- `sed -n '251,368p' orbisonic_vlc_codex_prompt_sequence.md`
- `sed -n '1,220p' docs/audio-vlc-investigation/task-03-playback-module-boundaries.md`
- `rg -n "distort|distortion|clip|clipping|crackle|crackling|pop|popping|glitch|underrun|overrun|dropout|drop out|latency|drift|bad audio|sounds|noise|artifact|stutter|resample|downmix|channel" Sources Tests docs README.md Package.swift AGENTS.md`
- `rg -n "harsh|metallic|right-heavy|shit|bad|artifact|click|ticks|drop|silent|zero|all-zero|underflow|overflow|dropped" Sources Tests docs README.md Package.swift AGENTS.md`
- `rg -n "AppLogger|category: \"audio|category: \"engine|category: \"streaming|category: \"route|category: \"input|category: \"meter|log\\(|timing\\.log|installTap|meter|peak|RMS|rms|underflow|overflow|sampleRate|channelCount|device|format" Sources/Orbisonic Sources/AudioCore Tests/OrbisonicTests Tests/AudioCoreTests`
- `rg -n "fixture|golden|impulse|pink|noise|sine|tone|wav|flac|ffmpeg|reference|expected peak|RMS|channel identity|one channel|one-channel" Tests Sources docs README.md scripts`
- `rg -n "struct OrbisonicAudioLimits|enum OrbisonicAudioLimits|maxSourceChannelCount|supportsSourceChannelCount" Sources Tests docs README.md`
- Targeted source and test reads listed in the sections below.

The broad symptom search was intentionally scoped to source, tests, docs, README, package, and AGENTS files rather than generated build/app bundles.

## Existing Evidence Found

No dedicated tracked issue report, sample name, or log excerpt was found that literally says "bad audio" or records a reproducible user-facing failure. The repo does contain adjacent diagnostic and test evidence that should shape the reproduction plan.

Existing audio-safety rules:

- `AGENTS.md:96` says not to mask live audio failures with buffering tricks, synthetic signal, fake channels, hidden gain, fallback routing, or fake activity.
- `AGENTS.md:102` says sample-rate mismatch, channel-count mismatch, route mismatch, underflow, dropped frames, and all-zero live input must remain visible as validation or diagnostic states.
- `AGENTS.md:112` says Roon log playback activity is not proof that audio reached a loopback input.

Existing logging and diagnostics:

- `Sources/Orbisonic/AppLogger.swift:31` through `:39` define the app-managed log location and `Sources/Orbisonic/AppLogger.swift:62` through `:66` writes categorized log lines.
- `Sources/Orbisonic/AudioFileLoader.swift:199` through `:223` logs Matroska probe/demux timing and stream facts.
- `Sources/Orbisonic/AudioFileLoader.swift:226` through `:243` logs forced FLAC ffmpeg fallback.
- `Sources/Orbisonic/AudioFileLoader.swift:431` through `:464` logs local file format conversion start/end.
- `Sources/Orbisonic/AudioFileLoader.swift:480` through `:516` logs channel split start/end.
- `Sources/Orbisonic/DiagnosticsView.swift:386` through `:414` surfaces live route, sample-rate, channel, signal, buffer, underflow, dropped-frame, and permission diagnostics.
- `Sources/Orbisonic/OrbisonicViewModel.swift:9270` through `:9292` logs live buffer fill, underflow, underflow-frame, and dropped-frame counts.
- `Sources/Orbisonic/OrbisonicViewModel.swift:9362` through `:9369` logs silent selected input with peak, input route, input sample rate, Roon sample rate, output route, and diagnosis.
- `Sources/Orbisonic/RoonNowPlayingMonitor.swift:121` through `:132` detects Roon channel mapping to stereo before Orbisonic.
- `Sources/Orbisonic/DiagnosticsView.swift:493` through `:507` surfaces Roon downmix, Roon playback-with-no-signal, and sample-rate mismatch warnings.

Existing objective audio helpers and tests:

- `Sources/Orbisonic/MeteringService.swift:329` through `:347` computes per-buffer RMS and peak dBFS from Float samples.
- `Tests/OrbisonicTests/LiveAudioBridgeTests.swift:58` through `:91` cover live ring-buffer underflow, reprime, and overflow/drop behavior.
- `Tests/OrbisonicTests/SonicSphereMeteringTests.swift:72` through `:97` proves live Sonic Sphere meter snapshots do not consume ring-buffer data.
- `Tests/OrbisonicTests/NormalMonitorGoldenAudioTests.swift:116` through `:134` assert normal-monitor golden PCM, no HRTF, no AVAudioEnvironmentNode, and identical PCM with meters enabled/disabled.
- `Tests/OrbisonicTests/NormalMonitorGoldenAudioTests.swift:136` through `:160` assert local/live route switching has no stale audible path.
- `Tests/AudioCoreTests/RenderKernelTests.swift:172` through `:192` assert render kernels reject sample-rate mismatch before processing.
- `Tests/AudioCoreTests/RenderKernelTests.swift:232` through `:255` assert direct30 render hash stability and that render-kernel audit reports no sample-rate conversion.
- `Tests/AudioCoreTests/OutputAdapterTests.swift:172` through `:193` assert dual-output coordinator rejects route sample-rate mismatch.
- `Tests/AudioCoreTests/OutputAdapterTests.swift:316` through `:334` assert a diagnostic tone can target one Dante/Sonic Sphere channel without bleeding into the previous channel.
- `Tests/OrbisonicTests/AudioFileProbeTests.swift:7` through `:20` cover 48 kHz stereo WAV probing without prepared buffers.
- `Tests/OrbisonicTests/AudioFileProbeTests.swift:24` through `:59` generate a 96 kHz 7.1 Matroska/FLAC fixture with ffmpeg and verify channel count/layout metadata.

Current channel-count support boundaries:

- `Sources/Orbisonic/OrbisonicAudioLimits.swift:1` through `:5` cap source file/live input requests at 64 channels.
- `Sources/Orbisonic/RendererModule.swift:205` through `:232` list automatic renderer input counts: 1, 2, 4, 6, 8, 10, 11, 12, 13, 14, 30, and 31.
- `Sources/Orbisonic/RendererModule.swift:245` through `:246` allow `.mono` renderer mode for any source count inside the source-channel cap.
- `Tests/OrbisonicTests/RendererModuleTests.swift:7` through `:11` assert 64 channels are accepted and 65 are rejected.

Current Plex/NAS boundary from Task 3:

- `docs/audio-vlc-investigation/task-03-playback-module-boundaries.md:56` records that `rg -n "Plex|Part\\.key|part key|partKey|plex|NAS|smb" Sources Tests README.md Package.swift AGENTS.md` returned no active owner.
- `docs/audio-vlc-investigation/task-03-playback-module-boundaries.md:66` records that a mounted NAS file path would currently enter as a normal local file URL if selected by the app or library.

## Reproduction Matrix

### Stereo

Use a two-channel local file at 44.1 kHz, 48 kHz, and 96 kHz. Generate variants for int16, int24, int32, and float32. Run the same material through prepared local loading and streaming/gapless loading where enabled. The objective checks are decoded PCM equality against a known-good `ffmpeg` decode, left/right impulse identity, peak/RMS preservation, no unexpected channel swap, no hidden mono sum, no clipping, and no sample-rate conversion unless explicitly recorded. Existing evidence for stereo probing starts at `Tests/OrbisonicTests/AudioFileProbeTests.swift:7`, and current normal-monitor golden output is covered by `Tests/OrbisonicTests/NormalMonitorGoldenAudioTests.swift:116`.

### 5.1

Use a six-channel file with isolated impulses in FL, FR, FC, LFE, SL, and SR. Run 48 kHz and 96 kHz first, then 44.1 kHz to expose route/sample-rate mismatch. Use int24 and float32 as primary variants because surround music masters often use those formats. Detect channel routing errors by checking that each channel's impulse appears at the expected renderer input and expected normal-monitor downmix coefficient, and that LFE follows the documented monitor policy instead of leaking into normal monitor unexpectedly. Existing renderer and monitor tests cover 5.1-style layouts in `Tests/OrbisonicTests/RendererModuleTests.swift:21` through `:70` and `Tests/OrbisonicTests/NormalMonitorGoldenAudioTests.swift:122` through `:134`.

### 7.1

Use an eight-channel file and a Matroska/FLAC variant because the repo already generates a 7.1 Matroska fixture with ffmpeg in `Tests/OrbisonicTests/AudioFileProbeTests.swift:24` through `:59`. Exercise local prepared and streaming paths. The detection target is whether probing, demuxing, AVAudioFile read, ffmpeg fallback, conversion, and channel split preserve eight discrete channels and 96 kHz sample rate. Also check that any 7.1 material not supported by automatic renderer policy does not silently become a wrong 5.1 or stereo interpretation.

### Ambisonics

Use a known Ambisonics test file only if its channel convention is known and explicitly documented, for example FuMa or ACN/SN3D. Current Task 3 evidence did not identify an active Ambisonics decoder or convention mapper. Therefore this reproduction case should be treated as "channel preservation and metadata honesty" rather than "correct Ambisonics rendering" until an Ambisonics contract exists. Objective detection should verify that Orbisonic does not silently reinterpret Ambisonic channels as standard surround, does not downmix without warning, and logs/probes container metadata honestly.

### Custom Sonic Sphere Layout

Use a custom discrete channel-bed file whose source channels are intended to map into the Sonic Sphere renderer, not a conventional surround layout. A one-channel-at-a-time impulse is required. Detect whether source channel N reaches renderer input N, whether the resulting `RendererMatrixBuilder.sceneModel` matrix is the requested custom/static-bed mapping, and whether normal-monitor playback remains separate from production renderer behavior. Existing Sonic Sphere output topology evidence is in `Tests/OrbisonicTests/RendererModuleTests.swift:13` through `:20`, and current normal-monitor non-mutation evidence is in `Tests/OrbisonicTests/RendererModuleTests.swift:21` through `:70`.

### 30-Channel

Use a 30-channel direct source with one impulse per channel at unique frame offsets. Current automatic renderer mode resolves 30 channels to `.direct30` at `Sources/Orbisonic/RendererModule.swift:228` through `:231`. Objective detection should assert no hidden downmix, no channel swap, no missing high-numbered channel, no gain normalization, and no unexpected sample-rate conversion. Direct30 render hash stability is already covered at `Tests/AudioCoreTests/RenderKernelTests.swift:232` through `:239`.

### 52-Channel

A 52-channel source is inside the 64-channel source cap in `Sources/Orbisonic/OrbisonicAudioLimits.swift:1` through `:5`, so loader/live source admission should be possible in principle if AVAudioFile/Core Audio and memory limits allow the asset. However, automatic renderer modes do not include 52 in `Sources/Orbisonic/RendererModule.swift:205` through `:232`, and there is no direct52 bypass mode in current source. The reproduction must therefore separate "can decode and preserve 52 input channels" from "can render 52 channels to Sonic Sphere." Objective checks should verify loader/probe/source-channel preservation and then record the renderer-policy blocker instead of forcing a misleading downmix.

### Plex Remote URL

Task 3 found no active Plex or `Part.key` opener in source. Reproduction for a Plex remote URL is therefore blocked until a current URL ingestion path exists or a future test harness feeds the same bytes through a local file and a remote URL path. The correct Task 4 result is to record the absence of an active Plex owner and avoid guessing that remote URL playback is currently responsible.

### Local File

Local file playback is the primary current reproduction path. Run every media shape and sample format through local prepared loading, and through streaming/gapless loading where enabled. Capture descriptor metadata, loader timing, conversion status, channel split facts, engine graph route, output device format, and resulting PCM snapshots at the diagnostic points listed below.

### NAS Path

No separate NAS protocol reader was found. Reproduce NAS behavior only as a mounted local file path. Compare the same file copied to local storage and accessed through the mounted path. If decoded PCM differs, inspect file access/caching/partial-read behavior; if decoded PCM matches but playback differs, inspect scheduling, buffering, or output routing.

### Sample Rates

Use 44.1 kHz, 48 kHz, and 96 kHz for every file type that can be generated. The objective checks are source rate, decoded PCM rate, renderer/session rate, output device nominal rate, and whether Core Audio or a future bridge resamples again. Existing sample-rate mismatch protections are represented by `Tests/AudioCoreTests/RenderKernelTests.swift:172` through `:192` and `Tests/AudioCoreTests/OutputAdapterTests.swift:172` through `:193`.

### Sample Formats

Use int16, int24, int32, and float32. The objective checks are decoded value scale, sign, endian, clipping, peak/RMS, and whether conversion to Float32 non-interleaved preserves channel identity. Existing conversion code is in `Sources/Orbisonic/AudioFileLoader.swift:431` through `:464`; existing peak/RMS measurement code is in `Sources/Orbisonic/MeteringService.swift:329` through `:347`.

## Failure Classes And Objective Detection

### 1. Decode Corruption

Definition: decoded PCM differs from a trusted decode before Orbisonic applies channel mapping, renderer logic, or output routing.

Detection:

- Decode the same source with `ffmpeg` into a known format such as Float32 planar WAV/CAF or raw f32le with explicit channel count.
- Capture Orbisonic's decoded PCM immediately after `AudioFileLoader` conversion/channel split and after `StreamingAudioFileSource`/`LocalAudioFileSource` chunk decode.
- Compare channel count, frame count, sample rate, per-channel hash, max absolute sample difference, and first non-zero sample frame per channel.
- Run the check for local WAV/AIFF/CAF, native FLAC, forced ffmpeg FLAC fallback, and Matroska FLAC fallback.

Likely hook points for a later task:

- `Sources/Orbisonic/AudioFileLoader.swift:199` through `:223` for Matroska demux facts.
- `Sources/Orbisonic/AudioFileLoader.swift:226` through `:243` for FLAC fallback facts.
- `Sources/Orbisonic/AudioFileLoader.swift:431` through `:464` for post-conversion facts.
- `Sources/Orbisonic/AudioFileLoader.swift:480` through `:516` for post-split per-channel hash/peak facts.
- `Sources/Orbisonic/StreamingAudioFileSource.swift:386` for streaming chunk decode facts.
- `Sources/Orbisonic/LocalAudioFileSource.swift:153` through `:166` for gapless chunk source-frame facts.

### 2. Format Conversion Error

Definition: PCM is decoded correctly but conversion into Orbisonic's internal Float32 non-interleaved shape changes scale, sign, endian, planar/interleaved layout, or clips values.

Detection:

- Use deterministic int16, int24, int32, and float32 fixtures with known sample values near -1.0, 0.0, +1.0, and below full scale.
- Check that int full-scale values normalize to expected Float values and that no sample exceeds the expected range unless the source itself does.
- Verify channel 0 and channel 1 remain distinct after conversion from interleaved sources.
- Compare per-channel peak/RMS using `MeteringService` and direct sample inspection.

Likely hook points for a later task:

- `Sources/Orbisonic/AudioFileLoader.swift:431` through `:464` after `AVAudioConverter`.
- `Sources/Orbisonic/AudioFileLoader.swift:470` through `:516` after mono-buffer creation/split.
- `Sources/Orbisonic/StreamingAudioFileSource.swift:350` and `:481` for converter/output format.
- `Sources/Orbisonic/LocalAudioFileSource.swift:92` for gapless converter creation.
- `Sources/Orbisonic/MeteringService.swift:329` through `:347` for peak/RMS verification.

### 3. Resampling Error

Definition: source, renderer/session, and device sample rates are not what the user thinks they are, or the signal is resampled twice or poorly.

Detection:

- For 44.1, 48, and 96 kHz fixtures, log source file sample rate, decoded PCM sample rate, local engine format, renderer/session rate, output route nominal rate, and any explicit conversion ledger.
- Compare a high-frequency sine sweep or impulse timing before and after playback/export capture if a capture path exists.
- Verify that `RenderKernelAudit.sampleRateConversionOccurred` remains false in AudioCore paths unless a future explicit SRC stage is added.
- For live loopback, compare player output rate, loopback input nominal rate, selected input route rate, and selected output device rate.

Likely hook points for a later task:

- `Sources/Orbisonic/AudioFileLoader.swift:539` for final prepared sample rate.
- `Sources/Orbisonic/StreamingAudioFileSource.swift:485` and `:493` for streaming output sample rate.
- `Sources/Orbisonic/OutputRouteMonitor.swift:4` through `:10` for output route channel count and nominal sample rate.
- `Sources/Orbisonic/DiagnosticsView.swift:386` through `:414` for live sample-rate diagnostics.
- `Sources/Orbisonic/OrbisonicViewModel.swift:9362` through `:9369` for silent-input sample-rate warning logs.

### 4. Buffering / Timing Error

Definition: audio data is correct but playback callback cadence, queue depth, retained buffers, seek state, or ring-buffer state causes gaps, stale audio, repeated audio, underflow, overflow, or drift.

Detection:

- Log scheduled frames, retained PCM bytes, current source frame, player render time, and queue generation for local prepared/streaming/gapless playback.
- For live input, log callback frame counts, ring available frames, target latency frames, underflow count, underflow frames, overflow/drop frames, and elapsed time between callbacks.
- Use fixtures with impulses at known frame offsets before and after seek/pause/resume to detect stale or duplicated audio.
- Compare local file playback and mounted NAS playback of the same file to detect read/scheduling differences.

Likely hook points for a later task:

- `Sources/Orbisonic/OrbisonicEngine.swift:2395` through `:2400` for playback frame calculation.
- `Sources/Orbisonic/LocalGaplessScheduler.swift:44` through `:45` for queue-depth snapshot fields.
- `Sources/Orbisonic/LocalGaplessScheduler.swift:516` through `:520` and `:816` through `:817` for retained/scheduled accounting.
- `Sources/Orbisonic/LiveAudioBridge.swift:355` through `:476` for ring-buffer latency, underflow, and overflow counters.
- `Sources/Orbisonic/OrbisonicViewModel.swift:9270` through `:9292` for live buffer logging.
- `Tests/OrbisonicTests/LiveAudioBridgeTests.swift:58` through `:91` for expected underflow/drop behavior.

### 5. Channel Routing Error

Definition: decoded channels are preserved but routed to the wrong renderer input, wrong monitor side, wrong Sonic Sphere output, or wrong physical device channel.

Detection:

- Use one-channel-at-a-time impulses for stereo, 5.1, 7.1, custom layout, 30-channel, and 52-channel cases.
- For every channel N, assert that the first non-zero sample appears only in expected renderer input N before matrix rendering.
- For Direct 30, assert channel N maps to output N with no crossfeed.
- For 31-channel physical/Dante plans, assert LFE/sub behavior and reserved physical channel 32 silence where applicable.
- For Roon/live cases, check `RoonSignalPath.isDownmixingToStereo` and diagnostics warnings before blaming Orbisonic routing.

Likely hook points for a later task:

- `Sources/Orbisonic/AudioFileLoader.swift:480` through `:516` after channel split.
- `Sources/Orbisonic/OrbisonicEngine.swift:2155` through `:2161` where normal-monitor gain/pan is applied.
- `Sources/Orbisonic/RendererModule.swift:927` through `:931` where renderer scene/model is built.
- `Sources/Orbisonic/RendererMatrixSampleRenderer.swift:3` for sample matrix rendering.
- `Sources/Orbisonic/RoonNowPlayingMonitor.swift:121` through `:132` for upstream Roon downmix detection.
- `Tests/AudioCoreTests/OutputAdapterTests.swift:316` through `:334` for single-channel Dante diagnostic behavior.

### 6. Gain / Mixing Error

Definition: routing is correct but gain, summing, headroom, duplicate paths, meter side effects, or hidden normalization changes the audible output.

Detection:

- Use fixtures with predictable peaks such as one channel at -18 dBFS, two channels summed at known values, and high but unclipped values near full scale.
- Compare pre-render peaks, post-normal-monitor peaks, post-Sonic-Sphere matrix peaks, desktop monitor peaks, and Dante/Sonic Sphere peaks.
- Assert no duplicate audible route by confirming expected output energy does not double.
- Toggle meters on/off and volume changes while asserting render/meter taps do not mutate PCM.

Likely hook points for a later task:

- `Sources/Orbisonic/MeteringService.swift:329` through `:347` for peak/RMS measurement.
- `Sources/Orbisonic/OrbisonicEngine.swift:2155` through `:2161` for normal monitor gain/pan.
- `Tests/OrbisonicTests/NormalMonitorGoldenAudioTests.swift:122` through `:134` for meter side-effect checks.
- `Tests/OrbisonicTests/SonicSphereMeteringTests.swift:7` through `:34` for Sonic Sphere meter independence from output volume.
- `Tests/AudioCoreTests/RenderKernelTests.swift:148` through `:167` for desktop and Dante gain isolation.

### 7. Device Backend Error

Definition: PCM and renderer output are correct before the OS output boundary, but actual Core Audio device negotiation, channel count, sample rate, latency, or shared-mode conversion alters playback.

Detection:

- Log selected output device ID, UID, name, manufacturer, transport, channel count, nominal sample rate, and route risk before playback starts and after output changes.
- Log AVAudioEngine output format, main mixer format, and output unit current device after graph start.
- For monitor output, verify it is two-channel normal monitor by contract.
- For Sonic Sphere/Dante output, verify the physical/logical channel count and sample rate match the production plan before playback.
- If external capture is available, capture the physical output and compare per-channel impulse positions and peak/RMS to pre-device PCM.

Likely hook points for a later task:

- `Sources/Orbisonic/OutputRouteMonitor.swift:4` through `:10` for output route facts.
- `Sources/Orbisonic/OrbisonicEngine.swift:500` and `:754` where the Core Audio current output device property is set.
- `Sources/Orbisonic/OrbisonicEngine.swift:1202` through `:1203` where the current normal monitor graph connects to the main mixer.
- `Sources/Orbisonic/OrbisonicEngine.swift:1226` through `:1255` where output device changes restart the engine.
- `Sources/AudioCore/OutputAdapters.swift:187` through `:204` for desktop route validation.
- `Sources/AudioCore/OutputAdapters.swift:319` through `:350` for Dante route validation.

## Required Diagnostic Capture Points

For later implementation or manual instrumentation, each reproduction run should capture these points:

1. Source descriptor:
   - path or source ID, container, codec, sample rate, sample format when known, channel count, layout, duration, estimated decoded bytes.
   - Current owners: `AudioFileProbe`, `AudioFileLoader`, `StreamingAudioFileSource`.

2. Post-decode PCM:
   - frame count, sample rate, sample format, planar/interleaved status, channel count, per-channel hash, peak, RMS, first non-zero frame.
   - Current owners: `AudioFileLoader`, `StreamingAudioFileSource`, `LocalAudioFileSource`.

3. Post-format-conversion PCM:
   - Float scale, clipping count, NaN/Inf count, per-channel hash, planar/interleaved status.
   - Current owners: local source classes and AudioCore block validators.

4. Post-channel-map / renderer input:
   - source channel index to renderer input index, layout confidence, direct mode resolution, warning text.
   - Current owners: `SurroundLayoutDetector`, `RendererMatrixBuilder`, `OrbisonicEngine`.

5. Post-render / pre-device output:
   - output channel count, output channel hash, peak/RMS, clipping count, direct-mode identity check.
   - Current owners: `RendererMatrixSampleRenderer`, AudioCore render kernels, normal monitor golden harness.

6. Runtime timing:
   - scheduled frames, source frame range, current playback frame, queue generation, retained PCM bytes, callback cadence, underruns, dropped frames, ring fill.
   - Current owners: `OrbisonicEngine`, `LocalGaplessScheduler`, `LiveAudioPipe`.

7. Device backend:
   - output route name/UID/device ID, nominal sample rate, channel count, AVAudioEngine output format, selected Core Audio output unit device, route risk, hardware path used.
   - Current owners: `OutputRouteMonitor`, `OrbisonicEngine`, AudioCore output adapters.

## Minimum Reproduction Run Record

Every bad-audio reproduction should record:

- Orbisonic commit hash and dirty state.
- App launch method, because `DiagnosticsView` warns raw executable launches should not be used for GUI/audio judgment at `Sources/Orbisonic/DiagnosticsView.swift:709`.
- Source file/source URL/source route.
- Local, mounted NAS, live Roon, live Spotify, live Aux, or Plex remote source category.
- Container and codec.
- Source sample rate and output device nominal sample rate.
- Source sample format if known.
- Source channel count and detected layout.
- Renderer mode and whether automatic mode resolved.
- Normal monitor output route and renderer/production output route.
- Underflow and dropped-frame counters before and after playback.
- Whether Roon or upstream source was already downmixing, using `RoonSignalPath.isDownmixingToStereo`.
- Objective result: hashes, peak/RMS, first non-zero frame, channel impulse positions, and whether any sample clipped or became NaN/Inf.
- Subjective note only after objective facts are recorded.

## Task 04 Conclusion

The repo does not currently contain a tracked, reproducible bad-audio report. It does contain enough diagnostic surfaces and tests to define objective failure classes. The next useful work is not to choose VLC yet; it is to generate deterministic source media and capture PCM/metadata at decode, conversion, channel-map, render, timing, and device-output boundaries so the corrupting stage can be identified.
