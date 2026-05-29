# Orbisonic Real-Time Transport Responsiveness Tweak

## Purpose

This note captures the old Orbisonic local-player responsiveness work so it can be reimplemented in a fork whose code shape no longer matches this repository. The goal is not to copy files verbatim. The goal is to preserve the model:

- do not make local transport wait for a whole track to decode before playback can start;
- keep skip/next/previous actions responsive while decoding is still expensive;
- bound PCM memory instead of preloading entire adjacent tracks;
- reject stale decode, seek, skip, and completion callbacks by generation/token;
- preserve Orbisonic's monitor/renderer/source contracts rather than becoming a generic media player.

The original user-facing symptom was slow local-track transitions. Hitting Forward during local playback could feel delayed. Repeated taps then appeared to land in a burst because each tap started or queued expensive whole-file work.

## Commits To Study

The responsiveness work was spread across several commits:

| Commit | Date | Subject | Why it matters |
| --- | --- | --- | --- |
| `49cbf6c` | 2026-04-27 | `Stabilize local player transport` | Added the first strong local-transport state contract: pending queue index, cancellation on pause/stop, visible pending target, and tests for rapid forward coalescing. |
| `7573c05` | 2026-04-28 | `Stabilize playback routing and simplify output UI` | Added `LocalFileLoadStartPolicy`, `localFileLoadDebounceTask`, `DebugTimingLog`, and the more explicit delayed-start/coalescing path. The important tests include `testRapidForwardStartsOnlyFinalDebouncedDecode`. |
| `134a045` | 2026-04-29 | `Preload first local music track paused` | Supporting quality-of-life commit: preloads the first local track when paused so the first play can feel less cold. This is not the main streaming fix. |
| `0b758bb` | 2026-04-29 | `v 1.1` | Introduced the bounded streaming local source model: `StreamingAudioFileSource`, `PCMChunk`, `BoundedPCMQueue`, `PCMBufferPool`, `AVFoundationPCMFrameDecoder`, and engine-side chunk scheduling. |
| `8f2532b` | 2026-05-03 | `Add feature-gated local gapless playback` | Added the later gapless/look-ahead layer: `LocalAudioFileSource`, `LocalGaplessScheduler`, `LocalGaplessTypes`, scheduler tests, and `docs/LocalGaplessPlaybackPlan.md`. This is the most complete expression of the desired model, but it remained feature-gated. |

Useful source/doc anchors:

- `Sources/Orbisonic/AudioFileLoader.swift`
- `Sources/Orbisonic/StreamingAudioFileSource.swift`
- `Sources/Orbisonic/LocalAudioFileSource.swift`
- `Sources/Orbisonic/LocalGaplessScheduler.swift`
- `Sources/Orbisonic/LocalGaplessTypes.swift`
- `Sources/Orbisonic/OrbisonicEngine.swift`
- `Sources/Orbisonic/OrbisonicViewModel.swift`
- `Tests/OrbisonicTests/LocalPlayerStabilizationTests.swift`
- `Tests/OrbisonicTests/StreamingAudioFileSourceTests.swift`
- `Tests/OrbisonicTests/LocalGaplessSchedulerTests.swift`
- `docs/LocalGaplessPlaybackPlan.md`
- `docs/audio-vlc-investigation/final-report-orbisonic-vlc-audio.md`

## What Was Slow

The old local playback path was a prepared-buffer path:

```text
local UI intent
-> OrbisonicViewModel.loadFile(...)
-> AudioFileLoader.load(...)
-> AVAudioFile open
-> allocate full source buffer
-> file.read(into: sourceBuffer)
-> convert entire file to non-interleaved Float32
-> split entire file into one mono AVAudioPCMBuffer per source channel
-> OrbisonicEngine.loadPreparedFile(...)
-> rebuild graph
-> schedule one full-track buffer per channel
-> start players
```

That model is simple and deterministic, but it front-loads all decode/convert/split work. A three-minute stereo file is already wasteful. A long multichannel file is much worse because decoded Float32 PCM expands quickly. For Sonic Sphere-style layouts, the prepared path also allocates and schedules many channel buffers before the first audible frame.

Natural advance was also late:

```text
current track fully drains
-> engine stop / playback-ended callback
-> view model decides next queue item
-> next track starts full decode/prepare/commit/play cycle
```

That guarantees a gap for expensive files because the next track is not even prepared until after the current one is finished.

## What VLC Contributed

VLC was the reference model, not the dependency we copied. The investigation in `docs/audio-vlc-investigation/final-report-orbisonic-vlc-audio.md` explicitly recommended **not** adding VLC/libVLC yet.

What we copied conceptually:

- Split media access, demux/decode, buffering, clock/output scheduling, flush/drain, and device negotiation into separate responsibilities.
- Start playback after a small preroll/cache rather than waiting for the entire asset.
- Continue decoding ahead while playback is running.
- Keep buffers bounded and make buffer ownership explicit.
- Treat seek/skip/stop as lifecycle events that flush stale queued audio.
- Report format, timing, queue, and output-state failures instead of hiding them.

What we did not copy:

- We did not let VLC own playback.
- We did not route audio through VLC's normal platform output.
- We did not adopt VLC's speaker/downmix policy.
- We did not use libVLC callbacks as the default decode bridge.
- We did not loosen Orbisonic's strict channel-count, layout, monitor, renderer, or Sonic Sphere failure policy.

The reason is Orbisonic is not an ordinary stereo player. It has separate selected sources, a normal monitor path, a Sonic Sphere 30.1 production topology, high-channel source preservation, strict no-hidden-downmix rules, and diagnostic states for silent live input, route mismatch, sample-rate mismatch, and stale playback. VLC is useful as a mental model and reference player, but full VLC playback would bypass too much of Orbisonic's product contract.

## The Orbisonic Strategy

The strategy had two layers.

### Layer 1: Make Transport Intent Responsive

This is the `49cbf6c` / `7573c05` part.

Keep the UI and queue state responsive even if the decode path is still heavy:

1. Represent the requested queue target separately from the audible/committed queue target.
2. Publish pending metadata/status quickly so the user sees the newest requested track.
3. Coalesce rapid skip/forward requests before decode starts.
4. Cancel pending load intent when Pause, Stop, source switch, or a newer track request invalidates it.
5. Prevent older decode completions from committing after a newer request wins.
6. Keep tests around pending state, stale decode, pause/stop cancellation, and rapid-forward coalescing.

Important names from the old implementation:

- `pendingSessionQueueIndex`
- `LocalFileQueueCommit`
- `LocalFileLoadRequest`
- `currentLocalFileLoadGeneration`
- `activeLocalFileLoadRequest`
- `queuedLocalFileLoadRequest`
- `readyQueuedLocalFileLoadGeneration`
- `LocalFileLoadStartPolicy`
- `localFileLoadDebounceTask`
- `DebugTimingContext`

This layer made the UI less chaotic, but it did not remove the architectural cost of whole-file preparation.

### Layer 2: Replace Full-Track Preparation With Bounded Chunks

This is the `0b758bb` / `8f2532b` part.

Add a local source abstraction that can open a file and repeatedly produce bounded PCM chunks:

```text
AVAudioFile / decoder
-> readNextChunk(maxFrames:)
-> optional AVAudioConverter
-> non-interleaved Float32 PCM chunk
-> bounded queue
-> engine schedules a little audio ahead
-> completion recycles buffers and schedules more
```

The first version was `StreamingAudioFileSource`:

- `StreamingLocalPlaybackPolicy.enableStreamingLocalPlayback = false`
- `initialPrerollFrames = 8_192`
- `steadyChunkFrames = 16_384`
- `targetBufferAheadSeconds = 2`
- `hardPCMByteCap = 128 MiB`
- engine scheduled-ahead cap: 2 seconds or 64 MiB

The later gapless version was `LocalAudioFileSource` plus `LocalGaplessScheduler`:

- `LocalGaplessPlaybackPolicy.defaultEnableLocalGaplessScheduler = false`
- `localGaplessTargetAheadSeconds = 4`
- `localGaplessChunkFrames = 16_384`
- `localGaplessMaxRetainedPCMBytes = 32 MiB`
- optional compressed trim metadata remained off by default

The important part is not the exact constants. The important part is that playback starts after enough frames are queued to be safe, not after the whole track is decoded.

## How The Bounded Source Worked

The old `StreamingAudioFileSource` shape is the clearest implementation recipe:

1. `AVFoundationPCMFrameDecoder` opens the file with `AVAudioFile(forReading:)`.
2. It probes a descriptor up front for sample rate, channel count, layout, duration, and estimated decoded size.
3. It creates an output format: Float32, non-interleaved, same sample rate and channel count/layout where possible.
4. `readNextChunk(maxFrames:)` reads only `maxFrames`, not the whole file.
5. If the source format does not match the output format, it converts that chunk with `AVAudioConverter`.
6. Each chunk records `startFrame`, `frameCount`, `byteCount`, descriptor, and a recycle callback.
7. `BoundedPCMQueue` accepts chunks until the byte cap is reached, then applies backpressure.
8. A background utility task keeps the queue filled up to the target-ahead horizon.
9. EOF marks the queue finished instead of blocking playback.
10. Cancellation finishes/fails the queue so playback does not wait on a dead decoder.

The engine-side streaming model:

1. Build a `StreamingPlaybackContext` with a unique token.
2. Stop live input/test tone and detach old local nodes.
3. Rebuild the local playback graph with one `AVAudioPlayerNode` per source channel/layout channel.
4. Start the streaming source.
5. Schedule an initial preroll.
6. Start `AVAudioEngine` and the player nodes.
7. Continue scheduling chunks until the scheduled-ahead frame/byte cap is reached.
8. On chunk completion, decrement scheduled frame/byte counters and recycle mono buffers.
9. On EOF plus no scheduled frames remaining, finish naturally and call the normal playback-ended path.
10. On stop/seek/source switch/new load, cancel the context token and discard stale completions.

## How Gapless Look-Ahead Extended It

The gapless work did not just "preload the next whole file." That would re-create the original memory problem.

The intended model was:

```text
current source chunks
-> scheduler keeps enough current audio ahead
-> scheduler opens next compatible source before current drains
-> next source chunks are scheduled before the boundary
-> no engine stop/rebuild at a compatible natural boundary
-> view model receives logical track-start/track-end callbacks
```

`LocalGaplessScheduler` added:

- queue snapshot ownership;
- source look-ahead;
- scheduled buffer retention and release accounting;
- scheduler generation invalidation;
- gapless miss events;
- source failure events;
- logical track started/ended events distinct from final queue ended;
- stale callback rejection.

The first safe compatibility envelope was intentionally narrow:

- local file playback only;
- autoplay or natural adjacent queue advance;
- same sample rate;
- same source channel count;
- compatible channel roles/layout;
- unchanged output route, monitor route, renderer mode, and graph assumptions;
- no active diagnostics, test tone, live input, manual pending load, source switch, seek, or output-device change.

Anything outside that envelope should fall back to the old prepared path, with a visible/logged reason.

## Why This Is Unique For Orbisonic

Orbisonic cannot use the normal media-player shortcut of "just let the backend play it."

The fork needs to preserve these Orbisonic-specific rules:

- Local Files, Roon, Spotify, Aux, and Test Tone are selected-source paths, not one mixer.
- Local file playback is separate from live loopback capture.
- Sonic Sphere 30.1 is the primary production topology.
- Normal monitor playback is setup/preview and must not redefine production routing.
- Direct 30 and Direct 30.1 are bypass modes only when source width matches.
- Unsupported channel counts, route mismatch, sample-rate mismatch, all-zero input, stale buffers, and hidden downmix risk must remain visible.
- Metering must not consume or mutate audible playback buffers.
- The scheduler must preserve channel identity, not just produce "some stereo output."

That is why the right implementation is an Orbisonic-owned bounded local source and scheduler, not full VLC playback.

## Porting Recipe For A Fork

Use this as the implementation order in the fork.

### 1. Find The Whole-File Boundary

Search for the equivalent of:

```swift
let file = try AVAudioFile(forReading: url)
let sourceBuffer = AVAudioPCMBuffer(...)
try file.read(into: sourceBuffer)
```

Then trace where that prepared object is committed to the engine. The line that blocks first audible playback is usually the first full read/conversion/split before engine commit.

### 2. Split Metadata Probe From PCM Decode

Add a cheap descriptor path that can publish:

- URL or track ID;
- duration;
- sample rate;
- channel count;
- layout;
- codec/container display text;
- estimated decoded PCM bytes if available.

The UI can update to "pending next track" from this descriptor without waiting for full PCM.

### 3. Add Generation And Pending Intent

Before changing decode, fix stale state:

- every load request gets a generation/token;
- every queue commit carries target index and stable track ID;
- visible pending target is separate from audible committed target;
- active decode completion checks the current generation before commit;
- pause/stop/seek/source switch/new skip cancel pending intent and active decode.

Port or recreate the old tests:

- pending queue load does not commit selection until decode wins;
- pause cancels pending queue load without advancing;
- stop cancels pending queue load without advancing;
- rapid forward coalesces to latest pending target;
- only final debounced decode starts;
- stale foreground decode cannot commit after newer target selection.

### 4. Implement A Chunk Decoder

Define a small protocol similar to:

```swift
protocol LocalFrameDecoder {
    var descriptor: AudioAssetDescriptor { get }
    func seek(to frame: AVAudioFramePosition) throws
    func readNextChunk(maxFrames: AVAudioFrameCount) throws -> PCMChunk?
    func close()
}
```

Rules:

- `readNextChunk` must never read the entire file unless the file itself is smaller than the requested chunk.
- Preserve sample rate and channel count unless an explicit converter is part of the contract.
- Convert to the app's internal PCM format per chunk.
- Return `nil` on EOF.
- Throw on unsupported channel count/layout instead of downmixing silently.

### 5. Add A Bounded Queue

Use a queue with:

- max retained byte count;
- enqueue backpressure;
- dequeue waiting;
- `finish()`;
- `fail(message)`;
- `removeAll()`;
- snapshot counters for diagnostics.

Do not use an unbounded array of chunks. Do not reintroduce "preload all adjacent PCM" as the default.

### 6. Add Buffer Pooling

Chunked playback can create churn if each chunk allocates fresh buffers. Add a small pool keyed by format and capacity:

- checkout buffer with at least requested frame capacity;
- reset `frameLength` on reuse;
- cap retained buffer count;
- recycle after schedule completion.

This is not full realtime callback compliance by itself, but it prevents obvious decode/scheduler allocation spikes.

### 7. Add Engine Streaming Context

The engine needs a tokenized context:

- source object;
- descriptor;
- layout;
- metadata;
- output format;
- scheduled chunks by ID;
- scheduled frames/bytes;
- EOF flag;
- schedule task.

Startup:

1. cancel old streaming/prepared/live/test-tone state;
2. build player/source graph for this descriptor;
3. start the decoder/source;
4. schedule initial preroll;
5. start engine and players;
6. start the scheduler task.

Completion:

- each scheduled chunk completion must check token;
- stale completion must be ignored;
- scheduled bytes/frames must decrement;
- buffers must recycle;
- EOF plus zero scheduled frames means natural end.

### 8. Keep A Fallback Path

Do not delete the old prepared-buffer path at first. Gate streaming/gapless behind a feature flag or compatibility check.

Fallback reasons should be explicit:

- unsupported channel count;
- unsupported layout;
- mixed sample rates between adjacent tracks;
- graph-changing route change;
- source open failure;
- decode failure;
- output preparation failure;
- generation invalidated.

### 9. Add Gapless Only After Streaming Works

Once one-track chunked playback works, add look-ahead:

- scheduler owns queue snapshot;
- scheduler opens next compatible source before current drains;
- scheduler schedules next chunks before boundary;
- view model receives logical track start/end events;
- final queue end remains separate from track boundary;
- manual skip/seek/stop/source switch/output route change invalidates look-ahead.

Do not use "full next-track PCM preload" as the primary gapless strategy.

### 10. Preserve Diagnostics

Add timing logs for:

- user intent received;
- pending state published;
- descriptor probe started/finished;
- decode started;
- first chunk decoded;
- first chunk queued;
- first chunk scheduled;
- playback started;
- scheduler buffer usage;
- chunk consumed;
- EOF;
- stale completion discarded;
- fallback reason.

The old `DebugTimingLog`/`DebugTimingContext` shape was valuable because it made "UI intent" and "first audible schedule" measurable separately.

## Acceptance Tests

Minimum tests for the fork:

1. Decoder reads bounded chunks and reports increasing `startFrame`.
2. Queue rejects a chunk larger than the byte cap.
3. Streaming source produces first chunk without full-file preparation.
4. Engine starts streaming source through the existing local playback graph.
5. Rapid forward coalesces to latest pending target.
6. Rapid forward starts only the final debounced decode.
7. Stale foreground decode cannot commit after newer target selection.
8. Pause cancels pending queue load without advancing.
9. Stop cancels pending queue load without advancing.
10. Natural end does not double-advance when gapless scheduler owns the next boundary.
11. Scheduler refuses incompatible sample rate/channel count/layout.
12. Scheduler cancels on skip, seek, stop, source switch, diagnostics, and output route change.
13. Chunk/scheduler memory caps are enforced.
14. Feature flag off preserves old prepared-buffer behavior.

Manual checks:

1. Long stereo file starts after preroll, not after full decode.
2. Long multichannel file does not allocate decoded PCM for the whole asset before first sound.
3. Repeated Forward taps land on the latest intended target, not every intermediate tap.
4. Skip during active decode does not let the older decode commit later.
5. Compatible adjacent WAV/AIFF files transition without an audible gap when gapless flag is on.
6. Incompatible adjacent files fall back cleanly and log the reason.
7. Monitor and Sonic Sphere routing semantics remain unchanged.

## Common Failure Modes

- **Async but still slow:** moving full-track decode to a task avoids blocking the main actor, but first sound still waits for all PCM.
- **Preload makes memory worse:** full adjacent PCM preload can hide one transition while making memory and cancellation behavior worse.
- **Stale completion commits:** older decode, seek, or scheduled-buffer callbacks can overwrite newer user intent unless every path checks generation/token.
- **Gapless lies:** scheduling the next file late, after engine stop, is not gapless. It is only automatic advance.
- **Wrong boundary callback:** final queue end and logical next-track start are different events.
- **Hidden downmix:** ordinary players may succeed by downmixing. Orbisonic should fail or explicitly label fallback when channel identity cannot be preserved.
- **Meters become truth:** meter activity must not prove playback correctness or mutate playback buffers.

## Short Version

The fix was not "use VLC." The fix was "use the media-player architecture lesson from VLC while keeping Orbisonic's audio contract."

For a fork, reimplement this shape:

```text
intent coalescing + generation tokens
-> cheap descriptor probe
-> bounded chunk decoder
-> bounded PCM queue
-> engine schedules small preroll
-> background decode keeps 2-4 seconds ahead
-> chunk completions recycle buffers
-> stale tokens are ignored
-> gapless scheduler opens/schedules the next compatible source before boundary
-> fallback to prepared path when unsafe
```

That is the Orbisonic Real-Time Transport Responsiveness Tweak.
