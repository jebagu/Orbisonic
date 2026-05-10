# Final Report - Orbisonic VLC Audio Investigation

## 1. Executive Recommendation

Direct recommendation: **Do not use VLC yet.**

The next implementation step should be to fix the current Orbisonic playback bug by adding native diagnostics and objective reference comparisons before introducing any VLC dependency.

This recommendation is based on the evidence gathered across the investigation:

- The bad-audio failure has not been isolated to media opening, demux, decode, PCM conversion, channel mapping, renderer input, monitor mix, scheduling, resampling, or output-device negotiation.
- The current investigation found no tracked reproducible bad-audio report with objective boundary captures from the failing media.
- VLC is a strong reference architecture and a useful diagnostic baseline, but the inspected libVLC callback path is not proven for Orbisonic's 30-channel or 52-channel needs.
- Full VLC playback would bypass Orbisonic's Sonic Sphere routing, monitor/production separation, diagnostics, source-state model, and renderer contracts.
- A custom VLC output module or copied VLC internals would add licensing, packaging, and maintenance risk before the fault layer is known.

The go-forward decision is:

1. **Go** for a native Orbisonic playback diagnostics and reference-comparison PR.
2. **No-go** for adding VLC or libVLC as an implementation dependency right now.
3. **Conditional go** for a guarded libVLC decode bridge only if the native comparison work proves that Orbisonic's current open/demux/decode path is the failing layer and the targeted channel counts are supported without hidden downmix, truncation, or layout loss.
4. **Conditional go** for native output-session hardening if decoded PCM is correct and the fault is downstream in scheduling, timing, mix, route negotiation, or output.

## 2. Current Orbisonic Playback Architecture

Orbisonic currently has several selected-source paths. They meet at shared app state, renderer, monitor, diagnostics, and output surfaces, but they should not be treated as one implicit mixer.

### Local File Playback

Current local playback follows this practical pipeline:

```text
media location
-> opener/fetcher
-> demuxer
-> decoder
-> PCM converter
-> channel/layout classification
-> renderer or monitor path
-> AVAudioEngine/Core Audio device output
-> OS/hardware route
```

Current ownership:

- Media selection and playback intent live primarily in `Sources/Orbisonic/OrbisonicViewModel.swift`.
- Local file metadata and open behavior use `Sources/Orbisonic/AudioFileProbe.swift`, `Sources/Orbisonic/AudioFileLoader.swift`, `Sources/Orbisonic/LocalAudioFileSource.swift`, and `Sources/Orbisonic/StreamingAudioFileSource.swift`.
- Matroska/FLAC support uses `Sources/Orbisonic/MatroskaFLACSupport.swift` and an FFmpeg fallback boundary where available.
- PCM conversion uses AVFoundation and `AVAudioConverter` toward Float32 non-interleaved processing formats.
- Surround layout detection and channel-role mapping use the existing layout detectors and renderer matrix code.
- The audible engine path is owned by `Sources/Orbisonic/OrbisonicEngine.swift` using `AVAudioEngine`, player/source nodes, mixer nodes, and Core Audio route selection.

### Streaming And Gapless Local Playback

Orbisonic also has streaming/gapless local playback components:

- `StreamingAudioFileSource` and `LocalAudioFileSource` prepare chunks.
- `LocalGaplessScheduler` owns scheduled playback state and generation-sensitive scheduling.
- `OrbisonicEngine` rebuilds the streaming playback graph and schedules chunks.

This path adds timing and stale-buffer risk because chunks, player-node scheduling, seek generation, and stream teardown must all agree.

### Live Loopback Sources

Roon and Aux live paths are not decode paths inside Orbisonic. They capture already-decoded audio from selected Core Audio loopback inputs:

- Roon is expected to capture the app-selected Roon loopback input.
- Aux is expected to capture the dedicated Aux loopback input.
- `LiveInputCapture` and `LiveAudioPipe` own capture and buffering.
- Live capture problems must be diagnosed as route, permission, sample-rate, channel-count, all-zero input, buffer, or source-device problems, not hidden behind synthetic audio.

### Spotify Source Boundary

The Spotify source uses the existing embedded receiver boundary represented in source and docs. Its current fixed stereo boundary must remain explicit. Spotify state must not inherit stale local multichannel metadata.

### Renderer, Monitor, Metering, And Output

The renderer and monitor paths are intentionally separate:

- Sonic Sphere 30.1 is the production topology.
- Direct 30 and Direct 30.1 modes are bypass modes only when source width matches.
- The normal monitor/headphone path is for setup and preview and must not mutate Sonic Sphere production routing.
- Metering must not consume playback buffers or alter output.

## 3. What Changed During Modularization

The retrofit/modularization work added clearer package and ownership boundaries around an existing native app rather than replacing the playback system.

Relevant shifts:

- `AudioContracts`, `AudioImport`, and `AudioCore` provide stronger vocabulary and lower-level boundaries.
- The app target remains responsible for AVFoundation, Core Audio, live capture, Roon, Spotify, local playback state, UI, and runtime integration.
- Tests now protect dependency direction, lower-target runtime leakage, source integration boundaries, selected-source no-signal behavior, and monitor/production separation.
- PureAudio and architecture docs make renderer and monitor roles more explicit.

These changes improve contracts, but they also make some legacy assumptions more visible:

- Local playback still has multiple owners across view model, file source, loader, scheduler, and engine.
- Source sample rate is often preserved or validated rather than globally normalized by one resampler owner.
- Layout metadata can be inferred or mapped at several stages.
- The normal monitor path can sound wrong even if production-renderer data structures look correct.
- The system now has stricter contract language than the older runtime path may have been written for.

The investigation did not prove that modularization itself broke audio. It identified the places where modularization could expose or fail to carry older assumptions: format handoff, layout identity, stale scheduled buffers, route negotiation, and monitor/output conversion.

## 4. Reproduction Of Bad Audio

The investigation did not find a tracked, objective reproduction of the bad-audio issue.

Missing evidence:

- The exact failing media class has not been recorded as a safe fixture.
- There is no boundary-capture set showing source metadata, decoded PCM, converted PCM, renderer input, monitor mix, pre-device output, and actual output-route format for the same failing playback.
- There is no objective comparison between Orbisonic output and a trusted reference decode for the failing media.
- There is no current matrix proving whether the failure reproduces for local file, streaming/gapless, Roon loopback, Aux loopback, Spotify, Plex-style URL, NAS-mounted file, stereo, 5.1, 7.1, 30-channel, or 52-channel sources.

The reproduction plan created earlier remains the correct prerequisite:

1. Use generated fixtures for stereo, 5.1, 7.1, 30-channel impulse/sweep, and 52-channel source-preservation tests.
2. Use private bad media only outside tracked source.
3. Capture diagnostics at each boundary before changing playback ownership.
4. Classify the fault as decode corruption, format conversion error, resampling error, buffering/timing error, channel routing error, gain/mixing error, or device backend error.

Until that evidence exists, any VLC implementation would be a speculative replacement rather than a targeted fix.

## 5. Failure-Mode Analysis

Most likely root causes, ranked by current evidence and blast radius:

1. **Decode or PCM conversion corruption before routing.** Orbisonic's local path uses AVFoundation, custom Matroska/FLAC support, optional FFmpeg fallback, and conversion into processing formats. If PCM is already wrong here, output-backend work will not fix it.
2. **Output device negotiation or hidden output conversion.** The AVAudioEngine/Core Audio route can differ from the requested route format. Shared-mode conversion, route sample-rate mismatch, or unexpected engine connection format could make clean internal PCM sound bad.
3. **Channel layout/order mismatch.** Orbisonic has to preserve channel identity across source channel count, layout roles, renderer input, monitor downmix, and production output. Wrong channel order can sound like distortion or incoherent imaging.
4. **Buffer scheduling, stale buffers, seek/flush, or drain error.** Streaming/gapless scheduling and live ring buffers need generation control. Stale buffers after seek or route rebuild can produce wrong audio without a decode bug.
5. **Gain, duplicate-channel, downmix, or clipping error.** The normal monitor path can fold or duplicate channels. If gain staging or downmix coefficients are wrong, the monitor may sound bad while production topology remains unchanged.
6. **Resampling or clock-drift error.** No single local resampler owner was identified as the universal point of control. Sample-rate mismatch can show up at decode, live capture, engine connection, or device route.
7. **Live loopback capture/routing error.** Roon and Aux can show source activity while capture receives silence or a mismatched route. That is a live-source issue, not proof that local decode is broken.
8. **Meter/diagnostic misinterpretation.** Meter correctness does not prove audible output correctness, and audible output correctness does not prove production renderer correctness.

The current most important gap is not a missing library. It is missing measurement at the boundary where clean PCM becomes bad audio.

## 6. VLC Architecture Relevant To Orbisonic

VLC is valuable to this investigation because its architecture cleanly separates responsibilities that Orbisonic should also keep explicit.

Relevant VLC pieces:

- Media access can be path, URL, or callback/stream driven.
- Demux and decode are separate from audio output.
- libVLC exposes a stable public facade for embedding.
- Audio callbacks can suppress normal OS output and deliver decoded PCM to an application-owned sink.
- Internal VLC output modules use lifecycle responsibilities similar to what Orbisonic needs: start/stop, play, pause, flush, drain, timing, volume/mute, and device selection.
- VLC has filter, resampler, channel reorder, and platform-output layers that make conversion points visible.

Important constraints:

- The inspected public callback path is useful for ordinary-channel decode experiments, but it is not proven for 30-channel or 52-channel callback output.
- Stock callback output has an inspected high-channel blocker in the current `amem` path.
- VLC's mapped speaker model is oriented around conventional speaker layouts, not Orbisonic's Sonic Sphere layout.
- VLC can be a trusted playback baseline for ordinary media, but full VLC playback does not preserve Orbisonic's renderer, monitor/production split, source-state model, or diagnostics.
- Custom VLC output modules or copied internals raise licensing, packaging, and maintenance concerns.

The main architectural lesson is to imitate VLC's separation of decode, buffer ownership, clock, output lifecycle, and failure reporting. It does not follow that VLC should become Orbisonic's playback owner.

## 7. Architecture Decision Comparison

### Media Opening And Access

Orbisonic currently owns local paths, local library state, live loopback selection, and source-specific UI state. VLC can open many local and network media forms and can act as a useful comparison opener for Plex-style URLs and mounted files.

Decision: keep Orbisonic as the media/source owner. Use VLC only as a later guarded decode source if the native opener/decode layer is proven faulty.

Improves:

- Source-state consistency.
- Privacy control over logged media identifiers.
- Separation of local, live, Spotify, Roon, Aux, Plex, and NAS access failures.

Risks:

- Native open/decode bugs remain until measured.
- VLC network access may still be useful later for specific URL behavior.

### Demux And Decode

Orbisonic currently uses AVFoundation, Matroska/FLAC support, and fallback tooling boundaries. VLC is strongest as an alternate demux/decode engine for ordinary channel counts.

Decision: do not replace decode yet. First compare native decoded PCM against a trusted reference. If native decoded PCM is corrupt, revisit Path A as a bounded libVLC decode bridge.

Improves:

- Avoids adding a dependency before proving the failing layer.
- Keeps high-channel source-preservation tests first-class.

Risks:

- If native decode is the fault, the first PR will diagnose rather than directly solve it.

### PCM Format Conversion

Orbisonic expects Float32 non-interleaved processing in important local paths. VLC callback output can deliver PCM, but inspected callback surfaces do not prove arbitrary high-channel planar layout preservation for Orbisonic.

Decision: Orbisonic should remain authoritative for its internal PCM contract. Any future libVLC bridge must explicitly convert into Orbisonic's processing format and fail when channel count, sample rate, or layout assumptions are unsupported.

### Resampling And Clocking

Orbisonic currently exposes sample-rate mismatch as a diagnostic state in some paths, but no single universal resampler owner was identified for all playback paths. VLC has explicit resampler/filter and clock/output concepts.

Decision: borrow the responsibility model, not the implementation. A native diagnostic/output-session pass should record requested rate, actual route rate, engine connection format, PTS or frame position, underrun/drop counters, and drift where available.

### Channel Layout And Mapping

Orbisonic's layout model must preserve Sonic Sphere 30.1 semantics and selected-source roles. VLC's conventional speaker masks and inspected callback limits do not prove Sonic Sphere custom layout preservation.

Decision: Orbisonic must own layout identity. VLC, if used later, can supply samples and observed count/rate, not final channel meaning.

### Buffer Ownership, Threading, And Transport

Orbisonic has scheduling and ring-buffer owners that must reject stale buffers across open, seek, stop, and route rebuilds. VLC's lifecycle model makes flush/drain/generation boundaries more explicit.

Decision: make Orbisonic's current buffer lifecycle visible first. A future bridge must use app-owned generation counters, bounded ring buffers, explicit flush, explicit drain, and callback lifetime guarantees.

### Device Negotiation

VLC output modules explicitly negotiate with platform devices and can expose requested-vs-actual format decisions. Orbisonic needs the same clarity around AVAudioEngine and Core Audio route formats.

Decision: add native requested-vs-actual output diagnostics before replacing the backend.

### Gain, Mixing, And Failure Policy

Orbisonic must never hide failures with silent downmix, truncation, synthetic channels, or implicit fallback routing. VLC can downmix or convert successfully for consumer playback, but that success may be wrong for Orbisonic.

Decision: Orbisonic failure policy stays stricter than general media-player playback. Unsupported counts, unknown layouts, all-zero input, hidden downmix risk, and route mismatch must remain visible.

## 8. 30 And 52 Channel Feasibility

### 30-Channel Sources

Orbisonic:

- Sonic Sphere 30.1 is the production topology.
- Direct 30 and Direct 30.1 are bypass modes only when source width matches.
- Current source admission is intended to support high channel counts within the documented ceiling, but objective identity tests are still needed.

VLC/libVLC:

- Stock mapped speaker paths are not proven for 30-channel custom layouts.
- The inspected public callback path is blocked for 30-channel output in stock current VLC.
- Full VLC platform output may play some high-channel forms on some systems, but that does not prove Orbisonic layout preservation or Sonic Sphere routing.

Decision: 30-channel viability must be proven in Orbisonic with generated impulse/sweep fixtures before any VLC path is considered for production.

### 52-Channel Sources

Orbisonic:

- A 52-channel source is inside the broad source-channel ceiling but no Direct 52 renderer contract exists.
- Correct behavior should be source preservation or explicit renderer-policy blocking, not silent downmix or truncation.

VLC/libVLC:

- The inspected stock callback path does not prove 52-channel output.
- Conventional mapped speaker assumptions do not represent Orbisonic's custom 52-channel source-preservation need.
- Some lower layers may be able to carry larger channel counts as unmapped audio, but the public callback/output path remains unproven for this product.

Decision: 52-channel work should be a source-preservation and explicit-blocker test, not a VLC integration requirement.

## 9. Implementation Options

### Path A - libVLC Decode Bridge

Summary: use public libVLC callbacks only for media open/demux/decode, then feed Orbisonic-owned PCM, layout, renderer, monitor, and output.

Best use:

- Ordinary-channel media where native decode is proven faulty.
- A bounded experiment after diagnostics identify decode as the problem.

Benefits:

- Keeps Orbisonic renderer/output ownership.
- Uses public libVLC embedding APIs.
- Can be feature-flagged and omitted from default builds.

Risks:

- Stock callback output is not proven for 30/52 channels.
- Layout identity must come from Orbisonic, not VLC.
- Adds packaging and runtime dependency complexity.

Current decision: not now. Revisit only after native diagnostics prove decode/opening is the failing layer.

### Path B - Native Output Backend Repair

Summary: keep native decode and renderer, then harden Orbisonic's output lifecycle, format negotiation, timing, buffer queue, flush/drain, route reporting, and failure states.

Best use:

- Native decoded PCM is correct, but audio becomes bad downstream.

Benefits:

- Lowest dependency and licensing risk.
- Preserves Sonic Sphere routing and app contracts.
- Directly addresses route, clock, monitor, scheduling, and output concerns.

Risks:

- Does not fix a decode corruption bug.
- Requires careful AVAudioEngine/Core Audio inspection.

Current decision: likely first implementation direction after diagnostics if decoded PCM is clean.

### Path C - Full libVLC Playback

Summary: embed VLC as the playback engine and let VLC own decode, timing, filters, and device output.

Best use:

- Diagnostic baseline for ordinary media.
- Temporary comparison path to answer "does VLC play this cleanly?"

Benefits:

- Fast way to compare against a mature media player for ordinary cases.
- Useful for isolating whether the user-facing symptom is specific to Orbisonic.

Risks:

- Bypasses Orbisonic renderer/output contracts.
- Does not prove Sonic Sphere 30.1 correctness.
- Can hide layout and downmix decisions that Orbisonic must expose.

Current decision: diagnostic baseline only, not product architecture.

### Path D - VLC Memory/Custom Output

Summary: use VLC memory output or create a custom VLC output path to get deeper control.

Best use:

- Only if future evidence proves a public callback bridge cannot solve a decode-specific problem and legal/packaging review explicitly accepts the cost.

Benefits:

- Theoretically more control than full-player embedding.

Risks:

- Public memory output collapses to the same callback limitations as Path A.
- Custom modules or copied internals are high legal, packaging, and maintenance risk.
- Still does not automatically solve Orbisonic layout semantics.

Current decision: do not use.

## 10. Recommended Architecture

The recommended architecture is a native-first diagnostic and repair path:

```text
Selected Orbisonic source
-> current native open/decode/capture path
-> PlaybackDiagnosticSnapshot
-> objective reference comparison where available
-> Orbisonic layout and renderer contracts
-> Orbisonic monitor/production separation
-> explicit output route negotiation diagnostics
-> current output path or later native output-session hardening
```

Recommended immediate interfaces:

- Add a `PlaybackDiagnosticSnapshot` or repo-appropriate equivalent.
- Record source class without storing private absolute paths.
- Record source sample rate, source channel count, decoded format, layout descriptor, renderer mode, monitor/output role, output route name, route channel count, route nominal sample rate, queue counters, seek generation, flush count, underrun/drop counters, and latest visible failure state.
- Add deterministic formatting and classification tests for the new diagnostic record.
- Add reference decode comparison tests for generated fixtures and skip explicitly when external tooling is unavailable.

Future conditional Path A shape, only if decode is proven faulty:

```text
MediaSource/PlexUrl/LocalPath
-> LibVlcAudioSource
-> DecodedPcmRingBuffer
-> Orbisonic channel/layout authority
-> Orbisonic spatial renderer or monitor path
-> Orbisonic device output
```

Future conditional Path B shape, only if decoded PCM is clean:

```text
Orbisonic decoded/rendered PCM
-> native output-session lifecycle
-> requested format
-> actual route/engine format
-> queue/timing/latency/underrun reporting
-> explicit flush/drain/stop
-> Core Audio route
```

Required architectural rules:

- VLC-specific code must not enter `AudioContracts`, `AudioImport`, or `AudioCore`.
- Default builds must keep working without VLC.
- The existing playback path must remain default until objective acceptance criteria pass.
- Fallback must be explicit and visible; do not switch engines mid-play after corrupted or unsupported audio is detected.
- Orbisonic remains authoritative for layout, renderer mode, monitor/production separation, failure policy, and hardware verification status.

## 11. Incremental Implementation Plan

Recommended sequence:

1. Add current playback diagnostics and logging with no behavior change.
2. Add reference decode comparison for generated fixtures.
3. Add impulse and channel-identity tests for stereo, 5.1, 7.1, Direct 30, and 52-channel source-preservation cases.
4. Decide Path B or Path A from measured evidence.
5. If Path B: add a guarded native output-session audit/hardening slice.
6. If Path A remains viable: add a build guard and runtime availability checks before any libVLC bridge code.
7. If Path A is enabled: add a guarded public-callback decode bridge.
8. Add seek, pause, flush, drain, stop, and teardown tests for whichever path changes.
9. Validate stereo, 5.1, and 7.1 before any high-channel claim.
10. Validate 30-channel source identity and Direct 30/30.1 behavior.
11. Validate 52-channel source preservation or document the exact blocker.
12. Validate Plex, local, and NAS access behavior only after fixture behavior is known.
13. Validate long playback, route changes, pause/resume, seek, queue growth, underflow, and drain.
14. Resolve dependency, packaging, signing, and installer issues only if VLC remains in the candidate set.
15. Switch defaults only after objective tests and manual hardware verification pass.

## 12. Acceptance Criteria

Before any VLC path can become a candidate for default playback:

- The current bad-audio sample has a safe reproduction record outside tracked private media.
- The same sample has boundary diagnostics showing where clean audio becomes bad audio.
- Stereo, 5.1, and 7.1 generated fixtures pass source, decode, layout, monitor, and output diagnostics.
- Direct 30 fixture identity is preserved or the exact blocker is recorded.
- 52-channel source preservation passes before renderer policy or the exact blocker is recorded.
- Any route mismatch, sample-rate mismatch, channel-count mismatch, all-zero live input, unsupported layout, hidden downmix risk, underflow, dropped frame, stale buffer, or teardown callback is visible.
- Seek, pause, resume, flush, drain, stop, and reopen behavior reject stale buffers.
- Requested output format and actual engine/route format are logged where available.
- The normal monitor path does not mutate Sonic Sphere production topology.
- The existing default playback path remains available during any guarded experiment.
- Full SwiftPM tests pass for source or test changes.
- App bundle refresh and LaunchServices reopen are run for app-code changes before UI/audio judgment.
- Sonic Sphere, Dante, loopback, Roon, Spotify, microphone permission, signing, and installer behavior remain manual verification items unless actually tested.

## 13. Risks And Unresolved Questions

### Risks

- A VLC integration could mask the real bug instead of identifying it.
- A full VLC player path could sound clean while bypassing Orbisonic's actual production routing.
- A callback bridge could work for stereo and still fail for 30/52-channel source preservation.
- Native output repair could consume time if the actual bug is decode corruption.
- Generated fixtures may not reproduce the user's bad-audio case.
- Private media cannot be committed, so reproduction handling must separate local evidence from tracked fixtures.
- Route/device behavior may differ between normal monitor, loopback, Dante, Sonic Sphere, and installed app contexts.
- Any dependency addition can complicate signing, app bundle layout, installer behavior, and release verification.

### Unresolved Questions

- Which exact source format, container, channel count, and route produces the reported bad audio?
- Does the decoded PCM differ from a trusted reference before routing?
- Does the converted Float32 non-interleaved PCM preserve sample count, channel identity, peak, RMS, and impulse positions?
- Does the bad audio occur before or after monitor downmix?
- Does the actual Core Audio route format match the expected engine format?
- Does the problem reproduce in streaming/gapless mode, direct local-file mode, live loopback, or all of them?
- Is 52-channel behavior intended to be source preservation only, or should a future renderer contract be proposed?

## 14. Final Go/No-Go

Final VLC decision: **No-go for VLC integration now.**

Final native diagnostic decision: **Go.**

The evidence does not support choosing libVLC, full VLC playback, or custom VLC output as the next product change. The best next engineering slice is the Task 15 PR 1 diagnostic work: add native playback diagnostics and reference comparison without changing playback behavior.

After that diagnostic slice:

- If decoded PCM is wrong, revisit Path A as a guarded libVLC decode bridge.
- If decoded PCM is clean and audio becomes bad downstream, proceed with Path B native output-session repair.
- If VLC plays the sample cleanly, treat it as useful evidence, not as proof that VLC should own Orbisonic's Sonic Sphere architecture.
- If 30/52-channel preservation remains blocked, do not ship a VLC path for high-channel Orbisonic playback.
