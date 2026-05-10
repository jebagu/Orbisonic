# Task 11 - Path A libVLC Decode Bridge Design

## Scope

Task 11 designs the safest VLC-based architecture if VLC is useful primarily for media opening, demuxing, decoding, buffering, and callback delivery.

This is a design-only task. It does not implement libVLC, add dependencies, change source code, or change tests.

## Path A Shape

```text
MediaSource/PlexUrl/LocalPath
    -> LibVlcAudioSource
    -> DecodedPcmRingBuffer
    -> OrbisonicChannelRouter
    -> OrbisonicSpatialRenderer
    -> OrbisonicDeviceOutput
```

Chosen names:

- `LibVlcAudioSource`: concrete source that owns libVLC media opening, media-player lifecycle, decoded-audio callbacks, and bridge-specific diagnostics.
- `DecodedAudioSource`: Swift-style protocol for a source that emits decoded PCM blocks into Orbisonic.
- `DecodedPcmRingBuffer`: lock-bounded bridge between libVLC callback timing and Orbisonic read/render timing.

These names fit the existing repo style better than C++ `IAudioDecodeSource`: the current code uses Swift protocols such as `AudioSourceAdapter` and concrete source names such as `LocalAudioFileSource`, `StreamingAudioFileSource`, and `LiveLoopbackSourceAdapter`.

## Proposed Module Boundary

Future file ownership, if implemented later:

- `Sources/AudioContracts/`: shared contract types only, if new generic decoded-source descriptors are needed.
- `Sources/AudioImport/`: protocol-level decode/import abstractions that do not directly bind libVLC.
- `Sources/Orbisonic/LibVlcAudioSource.swift`: concrete libVLC binding and callback owner, because it would be app/runtime integration code with C library linkage and source-mode behavior.
- `Sources/Orbisonic/DecodedPcmRingBuffer.swift`: bridge buffer if it is only used by libVLC runtime integration; move lower only if shared by other sources.

The bridge replaces only media opening/demux/decode for local/network media. It must not own:

- Sonic Sphere renderer modes.
- Direct 30 or Direct 30.1 semantics.
- 52-channel render policy.
- Normal Monitor downmix policy.
- Output device selection.
- Roon, Spotify, Aux live loopback capture.
- Metering truth.

## Interface Sketch

Pseudocode in Swift style:

```swift
public enum MediaLocation: Equatable, Sendable {
    case localFile(path: String)
    case mountedPath(path: String)
    case networkURL(URL, headers: [String: String])
    case appOwnedByteStream(id: String, expectedLength: Int64?)
}

public struct DecodeOptions: Equatable, Sendable {
    public var preferredSampleRate: AudioSampleRate?
    public var requestedFormat: ProcessingFormat
    public var expectedLayout: AudioChannelLayoutDescriptor?
    public var allowVlcResampling: Bool
    public var allowVlcDownmix: Bool
    public var maximumBufferedFrames: Int
}

public struct DecodeOpenResult: Equatable, Sendable {
    public var streamInfo: AudioStreamInfo
    public var warnings: [String]
}

public struct AudioStreamInfo: Equatable, Sendable {
    public var sourceID: String
    public var sampleRate: AudioSampleRate
    public var channelCount: Int
    public var processingFormat: ProcessingFormat
    public var layout: AudioChannelLayoutDescriptor
    public var durationFrames: Int64?
    public var codecDescription: String?
    public var containerDescription: String?
    public var vlcObservedFormat: String
    public var vlcObservedChannelCount: Int
}

public struct DecodedAudioBlock: Sendable {
    public var sourceID: String
    public var generation: UInt64
    public var pts: AudioFramePosition?
    public var frameCount: Int
    public var sampleRate: AudioSampleRate
    public var channelCount: Int
    public var layout: AudioChannelLayoutDescriptor
    public var channels: [[Float]]
    public var discontinuity: Bool
    public var isEndOfStream: Bool
}

public protocol DecodedAudioSource: AnyObject, Sendable {
    var streamInfo: AudioStreamInfo? { get }

    func open(location: MediaLocation, options: DecodeOptions) throws -> DecodeOpenResult
    func start() throws
    func pause()
    func seek(to frame: AudioFramePosition) throws
    func stop()
    func read(into block: inout DecodedAudioBlock) -> DecodeReadResult
}

public enum DecodeReadResult: Equatable, Sendable {
    case blockReady
    case wouldBlock
    case endOfStream
    case failed(String)
}
```

`AudioFramePosition` can be an alias or small value type around source frames. The important contract is that the bridge does not expose raw libVLC timestamps as UI truth until they are converted into Orbisonic's source-frame domain.

## 1. Module Boundary

`LibVlcAudioSource` is a source adapter for local/network media decode only. It feeds decoded PCM to Orbisonic's existing channel router and renderer.

Boundary rules:

- Input: `MediaLocation`, `DecodeOptions`, optional externally supplied layout manifest.
- Output: `DecodedAudioBlock` with Float32 non-interleaved channel arrays and Orbisonic-owned layout.
- Side outputs: structured logs, warnings, stream metadata, callback stats, ring-buffer stats.
- Not allowed: direct OS audio output, VLC spatialaudio rendering as production renderer, VLC device selection, hidden downmix, hidden resampling, or silent fallback to stereo.

## 2. Ownership Of libVLC Instance, Media, Media Player, And Callbacks

`LibVlcAudioSource` owns:

- One libVLC instance or a shared app-level `LibVlcRuntime` if startup cost requires pooling.
- One media object per opened `MediaLocation`.
- One media player per source instance.
- All audio callback registration.
- The callback opaque pointer lifetime.
- The source generation counter.
- The `DecodedPcmRingBuffer`.

Ownership rules:

- The callback opaque pointer points to a stable bridge object that outlives all callbacks.
- `stop()` must unregister/stop playback, mark the generation closed, flush the ring, then release player/media objects after callbacks are quiesced.
- `deinit` must be equivalent to `stop()` plus libVLC release.
- The libVLC instance must never be globally mutated from UI code.

## 3. Plex URLs And Headers

Preferred decision tree:

1. If the Plex URL carries all authorization in the URL or cookies/referrer/user-agent supported by the intended libVLC build, pass it as `.networkURL` through `libvlc_media_new_location`.
2. If Plex requires arbitrary headers, signed requests, custom range behavior, or exact app-owned authentication, use `.appOwnedByteStream` and `libvlc_media_new_callbacks` so Orbisonic owns HTTP and supplies bytes to libVLC.
3. Always log which path is used: `vlc_url_access` or `orbisonic_byte_stream_access`.

Header handling:

- User-agent, referrer, and cookies may be passed as libVLC media options only after the exact option support is verified for the target VLC build.
- Arbitrary headers are not assumed available in stock VLC URL access.
- Credential values must never be logged; logs should record only header names and redacted value presence.

Range handling:

- Stock VLC HTTP access can support byte ranges, but Plex-specific requirements must be proven.
- App-owned byte streams must implement read and seek callbacks and record whether seek is supported.

## 4. Local And NAS Paths

Local file paths:

- Use `libvlc_media_new_path` for normal local files.
- Preserve the original path only as a source ID or sanitized display name in tracked diagnostics.

NAS paths:

- Treat mounted NAS paths as local file paths only after the file exists through the mounted filesystem.
- Do not add a separate SMB/NAS protocol stack in this path.
- If mounted-path playback differs from copied-local playback, diagnose file I/O latency, partial reads, and OS caching separately from decode.

## 5. Requested Callback Sample Format

Default request:

- Format: `FL32`.
- Sample layout: libVLC callback side is expected to deliver interleaved Float32 for multichannel content.
- Orbisonic bridge output: deinterleaved Float32 channel arrays.

Rate/channel request:

- Use setup callbacks where possible to observe VLC's incoming decoded format.
- Request the source sample rate unless the user explicitly selects a tested conversion path.
- Request the observed source channel count only when it is within the proven callback limit.

Critical stock VLC blocker:

- Current stock `amem` rejects callback output above 8 channels. Therefore 30-channel and 52-channel Path A are expected to fail until a target VLC build or custom callback backend proves otherwise.

## 6. Actual Sample Format Validation

At callback setup:

- Verify VLC returned `FL32`.
- Verify native-endian Float32 interpretation by running a known fixture.
- Verify callback bytes match `sampleCount * channelCount * MemoryLayout<Float>.size`.
- Reject `S16N`, `S32N`, or any other format unless a separate converter is explicitly designed and tested.

At block ingestion:

- Reject NaN and Inf samples.
- Track per-block peak and clipping count.
- Track whether deinterleaving changed expected channel count.
- Record a conversion ledger entry: `VLC FL32 interleaved -> Orbisonic Float32 non-interleaved`.

## 7. Actual Channel Count Validation

Validation sequence:

1. Read the observed `channels` from libVLC setup callback.
2. Compare against `DecodeOptions.expectedLayout?.channelCount` when supplied.
3. Compare against Orbisonic's source-channel limit of 1...64.
4. Fail loudly if the requested callback channel count is lower than the expected source count and `allowVlcDownmix == false`.
5. Fail loudly if libVLC reports a supported ordinary count but the fixture manifest says the source should be 30 or 52.

Policy:

- Stereo, 5.1, and 7.1 may proceed when callback channel count and identity tests pass.
- 30 and 52 may proceed only if the target VLC callback path proves those counts. Stock current `amem` should record an exact blocker instead.

## 8. Source Channel Layout Metadata Capture

libVLC's public audio callback does not expose full `audio_format_t` layout metadata. Orbisonic must capture layout from outside the callback:

- Existing local probe metadata before handing the file to libVLC.
- Plex/library metadata when available.
- Sidecar fixture manifests for Direct 30 and Direct 52 tests.
- Container metadata from a separate probe command or future VLC event/track API only if it exposes enough information in the target build.
- User-selected layout override only through an explicit UI/control surface, never silent inference.

The bridge should emit `AudioStreamInfo.layout` from Orbisonic authority, not from VLC's mapped speaker bitmap.

## 9. Sonic Sphere Metadata Preservation Outside VLC

Sonic Sphere metadata must remain outside VLC:

- Direct 30 means source channel 1 maps to Sonic Sphere input 1, continuing ordinally through channel 30.
- Direct 30.1 means 30 full-range channels plus LFE/sub.
- 52-channel content is a source-preservation case until a render policy exists.
- Renderer mode, speaker map, calibration, and Sonic Sphere topology remain Orbisonic-owned.

`LibVlcAudioSource` may include a `sourceID` that lets the router look up an Orbisonic layout manifest. It must not translate source channels into VLC standard speaker positions as the authoritative production layout.

## 10. Ambisonic Metadata

Ambisonics must be handled as metadata, not silently decoded by VLC into ordinary speaker output for production use.

Policy:

- If the source is tagged Ambisonic and Orbisonic has no accepted Ambisonic renderer contract for that content, mark the layout as Ambisonic source preservation with a warning.
- Do not let VLC `spatialaudio` become Orbisonic's production renderer.
- If VLC decodes Ambisonic PCM channel order but does not expose convention/order in the callback, require external metadata or block production admission.
- If a future Ambisonic path is accepted, Orbisonic must define convention, order, normalization, channel ordering, and render target.

## 11. Ring Buffer Design

`DecodedPcmRingBuffer` should be bounded, nonblocking on the callback side, and generation-aware.

Stored per block:

- `generation`
- source frame start or converted PTS
- callback PTS in microseconds or VLC time units for diagnostics
- frame count
- channel count
- sample rate
- deinterleaved Float32 samples
- discontinuity flag
- end-of-stream/drain marker

Behavior:

- Single producer from libVLC audio callback.
- Single consumer from Orbisonic scheduling/render side.
- Fixed maximum buffered frames from `DecodeOptions`.
- Overflow policy is fail-loud for production: mark overflow, drop the new block or stop the source according to a strict policy, and log it. Do not silently discard old audio during production.
- Underflow is reported to diagnostics and acceptance tests.

## 12. Callback Threading

libVLC callbacks may arrive on internal VLC threads. The callback must only:

- Read the stable bridge state.
- Copy/deinterleave the samples into preallocated or quickly allocated bridge storage.
- Push the block into `DecodedPcmRingBuffer`.
- Record simple atomic counters.

The callback must not:

- Call SwiftUI/MainActor.
- Open files.
- Perform network I/O.
- Allocate unbounded memory.
- Call into renderer/device output.
- Block waiting for Orbisonic to consume buffers.
- Log synchronously if logging can block.

## 13. Avoiding Blocking Inside Callbacks

Design requirements:

- Preallocate ring capacity at open/start based on callback format and maximum buffered frames.
- Use a small lock or lock-free ring only if tests prove it is safe; prefer a simple bounded structure first and measure.
- If allocation is unavoidable, cap allocation size and record it as a risk.
- Use atomic counters for dropped callback blocks, overflow, last PTS, and generation.
- Dispatch expensive logging to a background logger with redacted metadata.

If callback push cannot complete immediately, mark an overflow and fail loudly. Do not block the VLC callback until Orbisonic catches up.

## 14. PTS Capture Or Generation

PTS policy:

- Preserve VLC callback PTS for diagnostics.
- Convert PTS to source-frame position when sample rate is known.
- If PTS is missing or invalid, generate a monotonic source-frame position from accumulated accepted callback frames.
- On discontinuity, seek, flush, or source generation change, reset generated PTS continuity and mark the first block discontinuous.

Orbisonic progress should use a single chosen time base per source:

- Prefer source-frame position for local files.
- Keep VLC PTS as secondary evidence.
- Never mix stale pre-seek PTS into a new generation.

## 15. Seek, Pause, Flush, Drain, Stop, And Teardown

Seek:

- Increment source generation.
- Flush `DecodedPcmRingBuffer`.
- Call libVLC seek.
- Reject callback blocks from older generations.
- Mark first accepted post-seek block as discontinuous.

Pause:

- Call libVLC pause.
- Record pause event.
- Consumer may stop reading or hold output according to existing Orbisonic transport behavior.

Flush:

- Clear pending decoded PCM immediately.
- Increment flush counter.
- Keep source open.
- Reject in-flight older-generation callback blocks.

Drain:

- Mark end-of-stream after libVLC drain callback.
- Let Orbisonic consume queued blocks before natural-end completion.
- Do not accept new PCM after drained unless generation changes through seek/restart.

Stop:

- Increment generation.
- Stop libVLC media player.
- Flush ring.
- Stop consumer scheduling.
- Release media/player after callbacks are quiesced.

Teardown:

- Unregister callbacks if the libVLC API/build supports explicit release ordering.
- Release player, media, and runtime references.
- Emit final stats: frames accepted, callbacks received, overflows, underflows, flushes, drains, seek count, last error.

## 16. Stale Buffer Rejection

Every decoded block carries a generation. The source increments generation on:

- open
- seek
- flush
- stop
- source location change
- format renegotiation
- fatal error

Consumer side rejects blocks whose generation does not equal the current source generation. Rejection is counted and logged. This mirrors the existing Orbisonic scheduler emphasis on avoiding stale scheduled work after seek/source switches.

## 17. Error Surfacing

Errors should surface through:

- `DecodeReadResult.failed`
- source status snapshot
- `AppLogger` decode category
- Diagnostics row for libVLC bridge state
- user-visible local playback status when the source cannot start

Error classes:

- media open failed
- unsupported callback format
- callback channel count lower than expected
- callback channel count above stock VLC limit
- source layout missing for production admission
- byte-stream read/seek failed
- ring overflow
- ring underflow
- stale block rejected
- callback PTS discontinuity
- libVLC stop/teardown timeout

The bridge should never silently fall back to stereo. If fallback is allowed, it must be explicit and visible.

## 18. Fallback To Existing Path

Default behavior:

- Existing AVFoundation/ffmpeg local path remains the default.
- Path A is opt-in behind a feature flag.
- If Path A fails before playback starts, Orbisonic can fall back to the existing path only when the user or debug setting allows fallback.
- If Path A fails after playback starts, stop and report the failure before fallback to avoid mixing two decoded sources in one timeline.

Fallback log must include:

- source ID
- Path A failure code
- whether audio had started
- whether fallback was allowed
- selected fallback path
- whether metadata/layout changed between paths

## 19. Feature Flag

Suggested controls:

- Build flag: `ORBISONIC_ENABLE_LIBVLC_DECODE_BRIDGE`
- Runtime setting: `experimentalLibVlcDecodeBridgeEnabled`
- Per-source debug override: `decodeEngine = existing | libvlc`

Defaults:

- Build flag off until dependency and signing implications are accepted.
- Runtime setting off.
- Production high-channel sources require test-proven callback support before enabling.

## 20. Required Logs

Open/start logs:

- bridge enabled/disabled
- libVLC version/build identifier
- media location kind
- access mode: local path, network URL, app-owned byte stream
- redacted header names only
- requested callback format/rate/channels
- setup callback observed format/rate/channels
- Orbisonic authoritative layout
- source duration if known

Runtime logs:

- callback block count and accepted frame count
- PTS first/last/discontinuity
- ring fill level high-water mark
- underflow count
- overflow count
- stale block rejection count
- seek/flush/drain/stop generation changes
- no hidden downmix confirmation or exact blocker

Close logs:

- final frame count
- playback duration
- last error
- fallback decision
- teardown completion

## Why This Path Preserves Orbisonic's Architecture

VLC replaces decode, not Orbisonic's spatial renderer.

Orbisonic remains the channel-layout authority. The bridge may observe a channel count, but it must not treat VLC's standard speaker bitmap as the source of truth for Sonic Sphere.

Orbisonic remains the high-channel renderer. Direct 30, Direct 30.1, Sonic Sphere matrices, Normal Monitor policy, and future 52-channel routing decisions remain in Orbisonic modules.

Orbisonic remains responsible for 30 and 52 channel mapping. Path A can only feed those maps after callback PCM identity is proven. Stock current `amem` does not prove that.

VLC's standard speaker layout limits are less dangerous because OS output is bypassed: the design uses libVLC audio callbacks instead of VLC platform audio output. That prevents VLC from writing to the macOS default device or owning Sonic Sphere output. It does not remove callback channel-count limits, and it does not make VLC layout metadata sufficient.

The remaining risk is whether callbacks preserve high-channel PCM. Tasks 7 and 9 found that stock current `amem` callback output is capped at 8 channels. Therefore Path A is immediately useful only for ordinary-channel decode experiments unless a target VLC build or custom callback output proves 30 and 52 channels.

## Path A Acceptance Criteria

Required before treating Path A as useful for ordinary local playback:

- Stereo reference decode passes against the Task 5 tolerance.
- 5.1 channel identity passes: all source channels arrive with the expected order and no hidden downmix.
- 7.1 channel identity passes: all eight source channels arrive with expected role/order or a documented manifest.
- No hidden downmix is observed in callback setup or captured PCM.
- No clipping, NaN, Inf, unexpected gain, or inactive-channel leakage is observed.
- Seek does not play stale buffers.
- Pause/resume does not duplicate or skip impulse windows.
- Stop/source switch does not leak previous-source PCM.
- Fallback to the existing path is explicit and logged.

Required before treating Path A as relevant to Sonic Sphere Direct 30:

- 30 channel identity passes with a deterministic Direct 30 impulse fixture, or the exact blocker is documented.
- If using stock current VLC, the expected blocker is callback output above 8 channels being rejected.
- If using a custom/proven callback path, channel N must arrive at Orbisonic channel N before renderer input.
- Direct 30 renderer output must remain Orbisonic-owned.

Required before treating Path A as relevant to 52-channel source preservation:

- 52 channel identity passes before renderer policy, or the exact blocker is documented.
- If using stock current VLC, the expected blocker is callback output above 8 channels being rejected.
- No renderer support should be implied unless a separate 52-channel Orbisonic render contract exists.

Required before target-hardware confidence:

- 20 minute playback has no underruns on target hardware.
- Ring high-water mark stays inside configured bounds.
- Callback overflow count remains zero.
- Output-route diagnostics remain visible and separate from decode success.
- Hardware-only checks record the actual route, sample rate, channel count, and manual verification result.

## Non-Goals

- Do not replace Orbisonic's renderer.
- Do not replace Orbisonic's output backend.
- Do not use VLC OS audio output as the audible app path.
- Do not accept VLC stereo downmix as proof of Sonic Sphere correctness.
- Do not infer Ambisonics or Direct 30/52 metadata from callback channel count alone.
- Do not implement Path A until the acceptance harness and dependency/signing plan are accepted.

## Path A Diagnostic Verdict

Path A is architecturally safe only as a bounded decode bridge. It is attractive for proving whether AVFoundation/Orbisonic decode is the source of ordinary playback problems. It is not yet a high-channel solution because the inspected stock libVLC callback path does not deliver 30-channel or 52-channel PCM.

The immediate design value is that it keeps the comparison honest: if libVLC callback PCM matches trusted decode and Orbisonic still sounds bad, the root cause moves downstream into channel layout, buffering, monitor mix, timing, or output negotiation. If libVLC callback PCM sounds and measures correct before Orbisonic routing, then VLC is useful as a decode boundary, not as a replacement for Orbisonic's spatial product.
