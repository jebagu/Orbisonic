# Task 15 - Prototype Plan

## Current Evidence Ranking

The currently most supported path is: **No VLC integration yet, fix current Orbisonic bug first.**

That does not mean VLC is ruled out. It means the next implementation work should isolate the failing stage before adding libVLC or changing playback ownership.

Evidence basis:

- Task 4 and Task 5 define the missing reproduction matrix, diagnostic capture points, reference media, and objective comparison harness.
- Task 10 ranks likely root causes but does not prove whether the fault is decode, PCM conversion, routing, buffering, renderer, monitor downmix, resampling, or output negotiation.
- Path A is architecturally safe only as a bounded decode bridge, but Tasks 7, 9, and 11 show stock libVLC callbacks are not proven for 30-channel or 52-channel PCM.
- Path B is the lowest legal/packaging risk and the right direction if decoded PCM is already correct, but it repairs the wrong layer if decode is the fault.
- Path C is useful as a diagnostic baseline, not as final Sonic Sphere architecture.
- Path D collapses to Path A when using public callbacks, or becomes the highest-risk option if it means custom VLC modules or copied internal VLC source.

Current working recommendation:

1. Add diagnostics and objective current-path tests first.
2. Choose Path B if Orbisonic PCM is good and the problem is downstream.
3. Choose Path A only if Orbisonic decode/opening is proven faulty and libVLC callback output is sufficient for the targeted channel counts.
4. Keep Path C as a baseline/debug escape hatch only.
5. Avoid Path D custom module/copying unless later evidence justifies legal, packaging, and maintenance risk.

## Minimal Code Spike Decision

No code spike is created in Task 15.

Reason:

- The evidence does not yet prove that VLC belongs in the implementation.
- The repo has no libVLC dependency, build flag, package inventory, or legal review outcome.
- Stock `amem` callback output is blocked for 30/52-channel proof in the inspected current VLC source.
- Full VLC playback bypasses Orbisonic's Sonic Sphere routing and monitor/production boundaries.
- A skeleton VLC module would create dependency and architecture churn before the first diagnostic PR has identified the actual fault.

Exact next implementation step:

Add a native playback diagnostic snapshot and reference comparison pass with no VLC dependency. The first PR should add a small Orbisonic-owned diagnostic record for local playback that captures source URL class, source sample rate, source channel count, decoded buffer format, layout descriptor, conversion ledger, output route, engine connection format where available, queue/seek/flush counters, and visible failure state. It should write to the existing diagnostics/logging surfaces and include deterministic tests for the new record formatting and failure classification.

## Prototype Plan

### PR 1 - Current Playback Diagnostics And Logging

Goal: make the current failing layer visible before changing architecture.

Likely files:

- `Sources/Orbisonic/AppLogger.swift`
- `Sources/Orbisonic/DiagnosticsLogStore.swift`
- `Sources/Orbisonic/AudioFileLoader.swift`
- `Sources/Orbisonic/LocalAudioFileSource.swift`
- `Sources/Orbisonic/StreamingAudioFileSource.swift`
- `Sources/Orbisonic/OrbisonicEngine.swift`
- `Sources/Orbisonic/OrbisonicViewModel.swift`
- `Tests/OrbisonicTests/DiagnosticsLogStoreTests.swift`
- new focused tests in `Tests/OrbisonicTests/`

Scope:

- Add a native `PlaybackDiagnosticSnapshot` or repo-appropriate equivalent.
- Record source path class without storing private absolute paths.
- Record source sample rate, source channel count, decoded format, layout source, renderer mode, monitor/output role, route name, route channel count, route nominal sample rate, conversion ledger summary, queue depth, underrun/drop counters, seek generation, flush count, and latest error.
- Surface warnings for hidden downmix risk, sample-rate mismatch, channel-count mismatch, stale buffers, unsupported 52-channel renderer policy, and route mismatch.
- Do not change playback behavior.

Acceptance:

- Existing default playback path is unchanged.
- Diagnostics are deterministic in tests.
- No private file paths or media metadata are written to tracked fixtures.
- Full SwiftPM suite passes if source/tests change.

### PR 2 - Reference Decode Comparison

Goal: determine whether Orbisonic's decoded PCM is already corrupt before routing/rendering/output.

Likely files:

- `Sources/Orbisonic/AudioFileLoader.swift`
- `Sources/Orbisonic/MatroskaFLACSupport.swift`
- `Tests/OrbisonicTests/AudioFileProbeTests.swift`
- `Tests/OrbisonicTests/MatroskaFLACSupportTests.swift`
- new test helper under `Tests/OrbisonicTests/`

Scope:

- Add generated test fixtures where possible, not private media.
- Compare Orbisonic decode output against a trusted reference decode when `ffmpeg`/`ffprobe` are available.
- Make skip behavior explicit when external tools are absent.
- Capture differences as decode corruption, channel swap, channel drop, gain change, clipping, silence, sample-rate conversion, or format mismatch.

Acceptance:

- Stereo, 5.1, and 7.1 reference comparisons have deterministic assertions.
- 30-channel and 52-channel fixture attempts either pass identity preservation before rendering or record exact local tooling/container blockers.
- No renderer or output changes are included.

### PR 3 - Impulse And Channel Identity Tests

Goal: prove channel identity across source, router, renderer, and monitor boundaries.

Likely files:

- `Tests/AudioCoreTests/RenderKernelTests.swift`
- `Tests/OrbisonicTests/RendererModuleTests.swift`
- `Tests/OrbisonicTests/NormalMonitorGoldenAudioTests.swift`
- new generated local-file fixture tests under `Tests/OrbisonicTests/`

Scope:

- Add deterministic impulse fixtures for stereo, 5.1, 7.1, Direct 30, and 52-channel source-preservation cases.
- Verify source channel index, layout role, renderer input index, production output index, and monitor downmix contribution separately.
- Confirm Direct 30/31 bypass semantics remain direct only when source width matches.
- Confirm 52-channel source is preserved or blocked explicitly before renderer policy, not silently downmixed.

Acceptance:

- Any channel swap, channel drop, duplicate channel, hidden downmix, or unexpected LFE fold is test-visible.
- Monitor tests prove the normal monitor path does not mutate Sonic Sphere production output.

### PR 4 - Optional libVLC Build Guard Only If Path A Or C Remains Viable

Goal: make a future VLC experiment buildable without making VLC part of the default app.

Precondition:

- PRs 1 through 3 show that VLC is likely useful for the failing stage.
- Legal/packaging review accepts a public libVLC callback or full-player experiment.

Scope:

- Add a build guard such as `ORBISONIC_ENABLE_LIBVLC`.
- Keep default builds without VLC.
- Keep VLC-specific imports and C bridge declarations out of `AudioContracts`, `AudioImport`, and `AudioCore`.
- Add runtime availability checks for library missing, plugin directory missing, unsupported libVLC version, callback output unavailable, and required decoder/plugin unavailable.

Acceptance:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` passes without VLC.
- A guarded VLC build either compiles on a configured machine or fails with a clear setup error.
- No default playback behavior changes.

### PR 5 - Guarded Path A VLC Decode Bridge If Viable

Goal: prototype libVLC only as a decode/callback source.

Likely files:

- `Sources/Orbisonic/LibVlcAudioSource.swift`
- `Sources/Orbisonic/DecodedPcmRingBuffer.swift`
- `Sources/Orbisonic/OrbisonicViewModel.swift`
- `Sources/Orbisonic/OrbisonicEngine.swift`
- guarded tests under `Tests/OrbisonicTests/`

Scope:

- Use public libVLC callbacks only.
- Request `FL32` where supported.
- Capture negotiated sample rate, format, channel count, callback byte count, PTS, flush/drain events, and callback generation.
- Use Orbisonic-owned layout metadata.
- Fail loudly when callback output channel count is below expected source channel count.
- Keep old backend available and default.

Acceptance:

- Stereo/5.1/7.1 callback identity passes before any default switch.
- 30/52 tests either pass on the target libVLC build or record the exact `amem`/callback blocker.
- No VLC source is copied.

### PR 6 - Seek, Pause, Flush, Drain, And Teardown Handling

Goal: make the prototype lifecycle safe under real user transport commands.

Scope:

- Map Orbisonic play/pause/resume/seek/stop to the bridge.
- Clear stale callback blocks on seek and stop.
- Keep a generation counter across open/seek/stop.
- Separate flush from drain.
- Ensure callbacks cannot outlive their bridge owner.

Acceptance:

- Tests prove stale buffers from a prior generation are rejected.
- Stop/teardown cannot leave a callback writing into released state.
- End-of-stream drain does not truncate queued PCM.

### PR 7 - Validate Stereo, 5.1, And 7.1

Goal: prove ordinary-channel value before high-channel work.

Scope:

- Run current native path and guarded VLC bridge path against the same generated fixtures.
- Compare peaks, RMS, impulse identity, sample count, channel order, PTS continuity, and route diagnostics.
- Include local file and streaming/gapless variants where practical.

Acceptance:

- VLC path is at least as correct as native path for ordinary channels before it remains in the candidate set.
- If native path is already correct, prefer Path B downstream repair over Path A.

### PR 8 - Validate 30 Channels

Goal: prove or reject Direct 30 viability for any VLC path.

Scope:

- Use Direct 30 impulse and sweep fixtures.
- Validate source preservation before renderer.
- Validate renderer/direct routing separately from decode.
- Validate output route identity only with a real 30-channel-capable route or marked manual/hardware-only.

Acceptance:

- All 30 source channels are preserved into Orbisonic with correct identity, or the exact blocker is recorded.
- Stock current `amem` rejection above 8 channels is treated as expected failure, not worked around with hidden downmix.

### PR 9 - Validate 52 Channels Or Document Exact Blocker

Goal: decide whether 52-channel source preservation is possible in the selected path.

Scope:

- Use a 52-channel source-preservation fixture.
- Separate container/tooling limitations from decoder limitations and renderer policy.
- Do not invent a Direct 52 renderer.

Acceptance:

- 52-channel source identity passes before renderer policy, or the exact container, decoder, callback, memory, or renderer-policy blocker is documented.
- No silent downmix or truncation is accepted.

### PR 10 - Validate Plex, Local, And NAS Paths

Goal: validate media access differences after local fixture behavior is known.

Scope:

- Local path: direct open and streaming/gapless behavior.
- NAS path: mounted filesystem behavior, latency, partial read, cancellation, and seek.
- Plex path: URL access, redirects, range behavior, user-agent/referrer/cookie support if used, and app-owned byte-stream fallback if arbitrary headers are required.

Acceptance:

- Plex credentials or private URLs are never logged.
- Access failures are classified separately from decode failures.
- Seek and range behavior is visible.

### PR 11 - Validate Long Playback

Goal: catch drift, buffer growth, leak, and late-session distortion.

Scope:

- Run long local playback and long streaming/gapless playback.
- Record PTS continuity, queue depth, underrun/drop counters, memory growth, route changes, sample-rate changes, and end-of-stream drain.
- Include pause/resume/seek during long playback.

Acceptance:

- No unbounded queue or memory growth.
- No stale buffers after seek.
- Diagnostics remain bounded and useful.

### PR 12 - Validate Packaging

Goal: prove release behavior for any selected path.

Scope:

- For Path B, run normal app bundle refresh and installer verification.
- For Path A/C, add libVLC binary/plugin inventory, license notices, plugin discovery, runtime unavailable state, code signing, notarization review, and installer payload checks.
- Confirm the app still builds and runs without VLC.

Acceptance:

- App refresh passes.
- Installer behavior is recorded.
- libVLC/plugin missing states are visible and nonfatal.
- Legal/open-source compliance items are reviewed before distribution.

### PR 13 - Switch Default Only After Acceptance Criteria Pass

Goal: make any new path the default only after objective evidence supports it.

Preconditions:

- Diagnostics identify the original failure layer.
- The candidate path passes ordinary-channel tests.
- The candidate path passes Direct 30 tests or documents an accepted non-support decision.
- 52-channel source behavior is preserved or blocked explicitly.
- Plex/local/NAS and long-playback tests pass for the target use cases.
- Packaging and runtime unavailable behavior are verified.
- Hardware-only gaps are recorded honestly.

Acceptance:

- Default switch is small and reversible.
- Old backend remains available for rollback during at least one release cycle.
- Release verification docs are updated with exact manual checks.

## Rollback And Safety

- Feature flag: all VLC work must start behind a build-time guard and a runtime setting. Default builds must continue without VLC.
- Fallback backend: the current native playback path remains available until the new path passes all acceptance criteria.
- Build without VLC: CI/local default must compile and test without libVLC headers, libraries, or plugins.
- Runtime unavailable VLC behavior: missing library, missing plugins, unsupported version, unsupported callback output, or missing decoder must become visible diagnostics, not crashes.
- Unsupported channel counts: 30/52 failures must fail loudly with exact blockers. No hidden downmix, truncation, synthetic channels, or fake activity.
- Old path preservation: do not switch defaults until tests prove the candidate path and release verification covers packaging/runtime behavior.
- Source privacy: do not log private media paths, Plex URLs, credentials, local absolute paths, or runtime logs into tracked files.
- Hardware honesty: Sonic Sphere, Dante, loopback, Roon, Spotify Connect, microphone permission, code signing, notarization, and installer behavior remain manual unless actually tested.

## Immediate Next Implementation Step

Implement PR 1 only:

```text
Add Orbisonic-owned playback diagnostics for the current native path.
Do not add libVLC.
Do not change default playback.
Do not alter renderer or output semantics.
```

The first concrete patch should add a small diagnostic record and focused tests around source/decode/output facts that already exist in Orbisonic. That will tell the next prompt whether the bug points toward Path A, Path B, or no VLC work at all.
