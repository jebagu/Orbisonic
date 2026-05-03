# Local Gapless Playback Plan

Discovery and implementation map for the feature-gated local `LocalGaplessScheduler`. The scheduler exists now, but production use remains behind `LocalGaplessPlaybackPolicy.enableLocalGaplessScheduler`. The call-flow sections below describe the default feature-off prepared-buffer path unless they explicitly mention the scheduler.

## Current Local Playback Call Flow

1. Local UI actions enter `OrbisonicViewModel` through methods such as `playLocalMusicTrackNow(_:)`, `toggleLocalMusicPlayback()`, `playLocalTransport()`, `playSessionQueueIndex(_:)`, `playAllLocalMusic(shuffle:)`, or `skipLocalTransport(offset:)`.
2. Queue-based play calls converge on `startSessionQueue(...)` or `playQueueIndex(...)`.
   - `startSessionQueue(...)` replaces `sessionQueue`, finds the starting track, clears local preload caches, and calls `loadFile(...)`.
   - `playQueueIndex(...)` validates the target index and calls `loadFile(...)` with a `LocalFileQueueCommit`.
3. `loadFile(...)` creates a `LocalFileLoadRequest`, marks `pendingSessionQueueIndex`, publishes pending player metadata, sets `isLocalFileLoading`, cancels adjacent prepared-file preload work, checks `LocalPreparedFileCache`, and queues or starts the load.
4. `startLocalFileLoad(_:)` probes an `AudioAssetDescriptor`, logs the streaming-local decision, optionally attempts the disabled streaming path, then runs the full `localAudioLoader` in a detached utility task.
5. The default `localAudioLoader` is `AudioFileLoader().load(url:debugTiming:)`.
   - It opens the file through `AVAudioFile`, optionally uses ffmpeg fallback for supported containers, allocates a full source buffer, performs a blocking full read, converts to non-interleaved Float32, then splits the whole file into one mono `AVAudioPCMBuffer` per source channel.
6. `completeLocalFileLoad(...)` calls `finishLoadedFile(...)` on success.
7. `finishLoadedFile(...)` enforces the local production gate, switches `sourceMode` to `.filePlayback`, commits the file into `OrbisonicEngine` with `engine.loadPreparedFile(...)`, updates visible player and meter state, and, if `autoplay` is true, prepares output and calls `engine.play(...)`.
8. `OrbisonicEngine.loadPreparedFile(...)` cancels streaming playback, stops live input, detaches source nodes, stores one `loadedFile`, resets `currentStartFrame`, sets state to `.ready`, and calls `rebuildPlaybackGraph(for:)`.
9. `rebuildPlaybackGraph(for:)` creates one `AVAudioPlayerNode` per layout channel, connects each player to `preVolumeMixer` with the loaded mono format, and applies the normal monitor pan/gain policy.
10. `OrbisonicEngine.play(...)` starts `AVAudioEngine` if needed, calls `scheduleFromCurrentPosition(...)`, starts all players at a shared host time, and sets state to `.playing`.
11. `scheduleFromCurrentPosition(...)` stops each player, slices each full-track mono buffer from `currentStartFrame`, and schedules one buffer per channel with `scheduleBuffer(...)`. Only channel 0 receives a completion callback.

## Current Natural-End Path

Prepared playback ends in `scheduleFromCurrentPosition(...)` when channel 0's scheduled full-track buffer finishes:

1. The channel 0 `scheduleBuffer(...)` completion enters the main actor with a `completionToken`.
2. The engine ignores stale completions or non-playing state.
3. The engine logs natural completion, calls `stop()`, and then invokes `onPlaybackEnded?()`.
4. `OrbisonicViewModel.finishInitialization()` wires `engine.onPlaybackEnded` to `handlePlaybackEnded()`.
5. `handlePlaybackEnded()` ignores the callback unless `isPlaying` is still true.
6. `playNextLocalMusicTrackAfterNaturalEnd()` tries `sessionQueueIndex + 1` first. If valid, it calls `playQueueIndex(..., isNaturalAdvance: true)`, which starts a normal load/decode/commit/play cycle for the next track.
7. If there is no session queue next item, it tries the next item in `visibleLocalMusicTracks` by creating a new session queue at that item.
8. If no next track exists, it clears `isPlaying`, resets meters, reevaluates renderer mode, and sets `statusMessage` to `Playback finished.`

With the feature flag off, this path is not gapless because the next track is not committed or scheduled until after the current track has already played out and the engine has stopped. With the feature flag on and the compatibility checks passing, the engine uses `LocalGaplessScheduler` instead of this view-model natural-advance handoff for adjacent local queue items.

## Reusable Engine Callbacks And Machinery

- `OrbisonicEngine.onPlaybackEnded` is the existing final-end callback into the view model.
- `completionToken` already protects prepared playback from stale scheduled-buffer completions.
- Streaming playback has a reusable model for chunk lifecycle: `StreamingPlaybackContext`, `scheduledChunks`, `scheduledFrames`, `scheduledBytes`, `scheduleStreamingChunk(...)`, `streamingChunkDidFinish(...)`, and `finishStreamingPlaybackNaturally(...)`.
- `startPlayers()` already starts multiple `AVAudioPlayerNode`s at one shared host time.
- `currentTime()`, `duration()`, `playbackFrame()`, `inputMeterLevels()`, and Sonic Sphere meter ingestion are already centralized in the engine.
- `DebugTimingContext` and `logLocalTransportTiming(...)` already provide useful timing hooks for future scheduler visibility.

## Queue And Index State In The View Model

- `localMusicTracks` and `visibleLocalMusicTracks` are the library/view source.
- `sessionQueue` is the active local playback queue.
- `sessionQueueIndex` is the committed/audible queue index.
- `selectedSessionQueueIndex` is selection only; it must not imply audible playback.
- `pendingSessionQueueIndex` represents a requested track while loading.
- `LocalFileQueueCommit` carries target `index`, `trackID`, and `isNaturalAdvance`.
- `currentLocalFileLoadGeneration`, `activeLocalFileLoadRequest`, `queuedLocalFileLoadRequest`, and `readyQueuedLocalFileLoadGeneration` prevent stale loads from committing.
- `currentFileURL`, `sourceMetadata`, `loadedFileName`, `loadedChannels`, `duration`, `currentTime`, and `scrubProgress` are single-current-track presentation state.
- `localAudioDescriptorCache` can cache adjacent descriptors; `localPreparedFileCache` can cache prepared PCM but full adjacent PCM preload is disabled by `enableAdjacentLocalPCMPreload = false`.

## One-Track-At-A-Time Assumptions

- `OrbisonicEngine` has one `loadedFile` and one `streamingPlayback`; loading either one cancels or replaces the other.
- `playerNodes` are rebuilt per current track layout and format.
- Prepared playback schedules exactly one sliced buffer per channel for the current file.
- Natural advance is a view-model decision after engine stop, not an engine-level look-ahead decision.
- UI presentation assumes one `currentFileURL`, one `sourceMetadata`, one `duration`, and one `sessionQueueIndex`.
- Adjacent metadata preload can prepare descriptors, but production playback still foreground-decodes the next track unless the disabled streaming path is enabled.
- The existing streaming path is also one source at a time: one `StreamingPlaybackContext`, one source, and one callback path.

## Existing Relevant Tests

- `Tests/OrbisonicTests/LocalPlayerStabilizationTests.swift`
  - Queue/load state: `testFailedQueueLoadDoesNotCommitSelection`, `testQueueSelectionDoesNotChangeWebNowPlaying`, `testFirstPendingQueueLoadUsesPendingPlayerBeforeDecodeFinishes`, `testPendingQueueLoadKeepsVisiblePlayerOnAudibleTrackBeforeDecodeFinishes`.
  - Natural/end safety: `testStalePlaybackEndedAfterPauseDoesNotAdvanceQueueOrResetPosition`.
  - Manual transport/load cancellation: `testPauseCancelsPendingQueueLoadWithoutAdvancing`, `testStopCancelsPendingQueueLoadWithoutAdvancing`.
  - Skip coalescing and stale loads: `testRapidForwardCoalescesToLatestPendingTarget`, `testRapidForwardStartsOnlyFinalDebouncedDecode`, `testStaleForegroundDecodeDoesNotCommitAfterNewerTrackSelected`.
  - Adjacent preload state: `testAdjacentFullPCMPreloadIsDisabledByDefault`, `testNextTrackUsesAdjacentMetadataDescriptorButStillForegroundDecodes`, `testAdjacentFullPreloadSkipsWhenCapIsZero`, `testAdjacentMetadataPreloadDoesNotStorePreparedPCMAfterNewerTrackSelected`, `testAdjacentMetadataDescriptorInvalidatesWhenFileChanges`.
  - Engine reschedule behavior: `testPausedEngineDefersRendererGraphRebuildAndReschedulesAfterPausedSeek`.
- `Tests/OrbisonicTests/StreamingAudioFileSourceTests.swift`
  - Chunk decode/queue: `testAVFoundationDecoderReadsBoundedChunks`, `testBoundedPCMQueueRejectsChunksLargerThanMemoryCap`, `testStreamingSourceProducesChunksWithoutFullFilePreparation`.
  - Engine streaming path: `testEngineStartsStreamingSourceThroughExistingPlayerGraph`.
- Related audio route invariants are covered in `NormalMonitorGraphTopologyTests`, `NormalMonitorGoldenAudioTests`, `NormalMonitorConversionLedgerTests`, `AudioSpatialUsageAuditTests`, `AudioCoreTests/SourceAdapterTests.swift`, and `AudioCoreTests/OutputAdapterTests.swift`.

## Smallest Safe Integration Points For `LocalGaplessScheduler`

1. Keep queue ownership in `OrbisonicViewModel`; do not move library, shuffle, selection, or source-switch policy into the engine.
2. Introduce the scheduler inside `OrbisonicEngine`, initially behind a local-only feature flag, because only the engine owns `AVAudioEngine`, `AVAudioPlayerNode`, graph rebuilds, sample positions, and buffer completions.
3. Start with a narrow compatible-track path:
   - `sourceMode == .filePlayback`
   - autoplay/natural sequential advance only
   - no active diagnostics, test tone, live input, pending manual load, source switch, seek, or output-device change
   - same sample rate, source channel count, and compatible channel roles between current and next track
   - unchanged renderer mode, monitor route, output route, and output graph
4. Reuse adjacent metadata preload to identify the next queue item early. Do not re-enable full adjacent PCM preload as the primary strategy.
5. Add a view-model-to-engine handoff that gives the engine the next local track descriptor/source before the current track reaches the end. The handoff should be invalidated by the existing local playback generation and queue commit identity.
6. Have `LocalGaplessScheduler` schedule the next track before the current buffer drains, without calling `stop()` at the boundary. For compatible prepared-buffer experiments this can be same-node consecutive scheduling; for scalable production it should use bounded chunk decode like `StreamingAudioFileSource`.
7. Add a new engine callback for track-boundary commit, separate from `onPlaybackEnded`, so the view model can update `sessionQueueIndex`, `currentFileURL`, metadata, duration, and artwork when the next track becomes audible. Keep `onPlaybackEnded` for final queue end.
8. Fall back to the current natural-end path whenever compatibility or state invalidation fails. The fallback must be explicit in logs.
9. Add tests before enabling by default:
   - scheduler refuses incompatible sample rates/layouts and uses current fallback
   - current-to-next transition does not call `stop()` or rebuild graph for compatible files
   - natural boundary commits `sessionQueueIndex` and now-playing exactly once
   - pause, stop, seek, manual skip, source switch, output route change, diagnostics, and stale completion all cancel scheduled look-ahead
   - streaming/local chunk memory caps are respected

## Risks To Guard

- Streaming path: `StreamingLocalPlaybackPolicy.enableStreamingLocalPlayback` is currently false, and `finishStreamingLocalFileLoad(...)` is only a fallback-capable skeleton. A scheduler must not silently enable or regress that path.
- Remote/live playback: Roon, Spotify, and Aux live inputs rely on source switching, live capture, and source-node cleanup. Scheduler state must be canceled whenever `sourceMode` leaves `.filePlayback`.
- AirPlay/output route changes: `setOutputDevicePreservingPlayback(...)` currently restores prepared playback by rescheduling the current loaded file. Gapless look-ahead must be dropped on output changes unless it can be restored with exact sample-position correctness.
- Renderer/effects/EQ state: current audible local playback flows through `preVolumeMixer` and `outputGainMixer`; future EQ/effects should remain after the scheduler's source nodes so a boundary does not bypass or double-apply processing.
- UI state: progress, now playing, queue index, artwork, web state, meters, and status messages are single-current-track today. Boundary callbacks must update them without using selection or pending-load state as audible truth.
- Mixed formats: different sample rates, channel counts, channel roles, container decode paths, or converter requirements may require graph rebuild or SRC. The first scheduler version should reject these for gapless mode.
- Completion timing: `scheduleBuffer(..., completionCallbackType: .dataPlayedBack)` is appropriate for cleanup/final end, but track-boundary UI updates may need a render-time or scheduled-time signal so the UI changes at the audible boundary, not late.
- Memory and CPU: whole-file prepared PCM is already expensive. The production scheduler should prefer bounded decode and limited schedule-ahead instead of reviving full adjacent PCM preload.
- Manual transport: skip, previous, pause, stop, seek, diagnostics, and source switch already rely on generation cancellation. Scheduler tokens must participate in the same invalidation model.

## Compressed Trim Handling

- `LocalAudioFileSource` only applies compressed gapless trim when `localGaplessEnableCompressedTrim` is enabled and trim data is trustworthy.
- The production metadata path uses Core Audio packet table information (`kAudioFilePropertyPacketTableInfo`) for compressed files. `mPrimingFrames` becomes `GaplessTrimInfo.leadingPrimingFrames`, `mRemainderFrames` becomes `trailingPaddingFrames`, and `mNumberValidFrames` becomes `validFrameCount`.
- PCM/WAV/AIFF files are not artificially trimmed. They remain untrusted/full-window sources even when the trim flag is enabled.
- Silence detection is intentionally not used. If packet table metadata is absent or invalid, the source plays the decoded file as-is and marks `GaplessTrimInfo.isTrustworthy` false.
- The source exposes a small injected `GaplessTrimInfo` path for unit tests and future platform-specific metadata readers. That path still requires `localGaplessEnableCompressedTrim` and ignores untrusted trim values.
- Current guardrail: packet table trim is rejected if the declared trim window does not fit inside the decoded `AVAudioFile.length`, favoring untrimmed playback over damaging intentional musical silence.

## Implementation Status

Implemented:

1. `LocalGaplessPlaybackPolicy` and `LocalGaplessSchedulerConfig` define the feature gate, schedule-ahead horizon, chunk size, retained PCM cap, and compressed trim gate.
2. `LocalAudioFileSource` opens local file URLs, decodes bounded chunks through `AVAudioFile`, converts with `AVAudioConverter` when needed, supports seek, preserves track identity, and never reads a whole track into memory.
3. `LocalGaplessScheduler` owns scheduling state, generation invalidation, queue snapshots, source look-ahead, retained buffer accounting, event callbacks, queue-end handling, and stale callback rejection.
4. `OrbisonicEngine` can start the scheduler for compatible local queues, reusing the existing normal monitor graph. Mono, stereo, and surround local sources are scheduled through the existing per-channel `AVAudioPlayerNode`s. Natural adjacent-track boundaries stay inside the scheduler and do not call `stop()` or rebuild the graph.
5. `OrbisonicViewModel` consumes logical track start/end/queue-end callbacks so it can update the queue index, current file, metadata, progress finalization, and end-of-queue UI without starting the next file after a gapless natural boundary.
6. Queue rebuild, skip, seek, stop, output-device changes, live input, diagnostics, and test tones intentionally invalidate scheduled audio through scheduler generation changes or scheduler cancellation.
7. Tests cover scheduler state transitions, retained buffer release, memory cap rejection, stale callback invalidation, file-backed split-sine handoff continuity, source chunking/seek/EOF, format normalization, compressed trim plumbing, and view-model natural-end bypass.

Still feature-gated:

1. `LocalGaplessPlaybackPolicy.enableLocalGaplessScheduler` defaults to `false`.
2. `LocalGaplessPlaybackPolicy.localGaplessEnableCompressedTrim` defaults to `false`.
3. The old prepared-buffer local path remains the default and is still used whenever the flag is off or compatibility checks reject the scheduler path.

## Known Limitations

1. The engine integration accepts compatible local queues whose adjacent tracks share the current source sample rate and channel count. Mixed stereo-to-5.1, 44.1-to-48 kHz, or otherwise graph-changing transitions still fall back to the old prepared-buffer path.
2. Queue-end does not wrap for repeat-all. This matches the current local natural-end behavior; manual next/previous can wrap, but automatic repeat-one/repeat-all local modes are not implemented.
3. Shuffle is supported as a prebuilt session queue. Reordering while gapless playback is active triggers a bounded scheduler rebuild from the current logical item.
4. AAC/M4A and MP3 trim uses Core Audio packet table data only when compressed trim is enabled. If trustworthy metadata is missing, playback is untrimmed and no silence detection is applied.
5. Output route changes, diagnostics, live input, source switches, manual skip, and seek intentionally discard scheduled look-ahead. These are not natural boundaries.
6. Input and Sonic Sphere metering for the gapless scheduler is conservative and currently marked inactive instead of sampling scheduled chunks.

## Enable The Feature Flag

For manual testing, open Orbisonic, go to `Settings`, then use the `Local Playback QA` panel:

1. Turn on `Gapless local playback` to route compatible local queues through `LocalGaplessScheduler`.
2. Keep `Compressed trim metadata` off for first-pass WAV/AIFF/PCM testing.
3. Turn on `Compressed trim metadata` only when specifically validating AAC/M4A or MP3 trim behavior.

The switches persist through `UserDefaults` using `Orbisonic.localGapless.enableScheduler` and `Orbisonic.localGapless.enableCompressedTrim`. The compiled defaults remain off.

## Gapless Miss Logs

Gapless miss and source-open failures use the `gapless` log category:

```text
event="gapless miss" file="Next Track.m4a" reason="..."
event="source open failed" file="Track.m4a" reason="..."
```

A gapless miss means the scheduler could not prepare or continue into a future source in time or the source failed compatibility/open checks. With the feature flag enabled, the engine either ends the scheduler queue cleanly or falls back before starting the scheduler if compatibility fails.

## Manual QA Checklist

1. Feature flag off regression check: play a local file and a local queue; verify the old prepared-buffer path still plays and natural advance still loads the next file through the view model.
2. Two adjacent WAV files split from one continuous source: enable the flag, play from the first file, and listen at the split boundary for no click, pause, inserted silence, or duplicate transient. Confirm no `gapless miss` appears.
3. Two normal album tracks intended to be gapless: enable the flag and confirm whether the scheduler accepts the pair. Stereo and 5.1 files should use the scheduler when adjacent tracks share sample rate and channel count.
4. AAC/M4A album tracks: test first with compressed trim off, then with `localGaplessEnableCompressedTrim = true`; check for `compressed trim applied`, `compressed trim unavailable`, `gapless miss`, and audible boundary behavior.
5. MP3 album tracks: repeat the AAC/M4A check. Unknown trim metadata must play as-is rather than stripping intentional silence.
6. Skip during current track: verify playback jumps intentionally, scheduled look-ahead is discarded, and stale callbacks do not advance UI.
7. Seek near the end of the current track: verify seek restarts scheduled audio for the current logical item and either continues gaplessly or logs/falls back cleanly.
8. Pause near boundary, then resume: verify the scheduler resumes without double-starting the next file.
9. Queue reorder while playing: verify the current logical item remains the source of truth, future scheduled audio is rebuilt or playback stops cleanly if the current item was removed.
10. Repeat one: document as unsupported for automatic local gapless queueing unless a repeat-one local transport mode is added.
11. Repeat all: document as unsupported for automatic local queue-end wrap; queue end should finish once.
12. Shuffle: start playback from a shuffled local queue and verify logical track start events follow the shuffled `sessionQueue` order.
