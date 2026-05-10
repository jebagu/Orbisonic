# Task 12 - Path B Native Output Backend Design

## Scope

Task 12 designs a path where Orbisonic keeps its current decoder and channel router, but repairs or replaces its device-output backend using VLC's output architecture as a conceptual model.

This is a design-only task. It does not implement a backend, add dependencies, change source code, or change tests.

Path B is appropriate if later objective tests prove decoded PCM is already correct and distortion is introduced by rendering, buffering, timing, or OS/device output.

## Path B Shape

```text
OrbisonicMediaSource
    -> OrbisonicDecoder
    -> OrbisonicChannelRouter
    -> OrbisonicSpatialRenderer
    -> NewOrRepairedOrbisonicDeviceOutput
```

The key idea is to keep Orbisonic-owned decode, layout, Sonic Sphere rendering, and normal-monitor policy, while replacing the weak parts of the output side with a clear output-session lifecycle modeled after VLC's `audio_output_t` contract.

## Existing Files In Scope

Current files likely modified or wrapped by a future implementation:

- `Sources/Orbisonic/OrbisonicEngine.swift`: current AVAudioEngine owner, output device selection, player/source nodes, monitor graph, timing, stop/seek behavior.
- `Sources/Orbisonic/OutputRouteMonitor.swift`: current Core Audio output route discovery, channel count, nominal sample rate, route risk, route labels.
- `Sources/Orbisonic/NormalMonitorRouteDescriptor.swift`: normal-monitor route policy and downmix intent.
- `Sources/Orbisonic/NormalMonitorStereoDownmixer.swift`: deterministic monitor downmix logic and golden-test reference.
- `Sources/AudioCore/OutputAdapters.swift`: existing offline/validation-oriented desktop and Dante adapter contracts.
- `Sources/AudioCore/RenderGraphPlan.swift`: immutable render graph plan and output route contracts.
- `Sources/AudioCore/RenderKernels.swift`: render validation and channel/sample-rate exactness.
- `Sources/AudioContracts/AudioContracts.swift`: shared sample-rate, layout, source, session, and route types.

Likely new files if implemented later:

- `Sources/AudioCore/OutputSession.swift`: pure lifecycle protocol and status types.
- `Sources/AudioCore/OutputTimingReport.swift`: timing, latency, drift, underrun, and route-format records.
- `Sources/Orbisonic/CoreAudioOutputSession.swift`: macOS live backend around AVAudioEngine/Core Audio/HAL.
- `Sources/Orbisonic/OutputSessionDiagnostics.swift`: structured diagnostic summaries for UI/logging.

## Backend Lifecycle

Swift-style protocol sketch:

```swift
public protocol OrbisonicDeviceOutputSession: AnyObject, Sendable {
    var route: OutputRouteDescriptor { get }
    var requestedFormat: AudioOutputBlockFormat { get }
    var actualFormat: AudioOutputBlockFormat? { get }
    var state: OutputSessionState { get }

    func open(route: OutputRouteDescriptor) throws
    func configure(_ request: OutputSessionRequest) throws -> OutputSessionNegotiation
    func start(at hostTime: UInt64?) throws
    func submit(_ block: CanonicalAudioBlock, sourceFrameIndex: Int64) throws
    func pause(at hostTime: UInt64?)
    func resume(at hostTime: UInt64?) throws
    func flush(reason: OutputFlushReason)
    func drain() throws
    func stop()
    func close()
    func selectDevice(_ route: OutputRouteDescriptor) throws
    func timingReport() -> OutputTimingReport
    func latestStatusSnapshot() -> AudioOutputStatusSnapshot
}
```

Lifecycle semantics:

- `open/configure`: choose route, request exact sample rate, channel count, format, and layout.
- `start`: start the backend clock and device stream.
- `submit/play`: enqueue rendered blocks with source-frame index and generation.
- `pause`: stop producing sound quickly while preserving state where the backend supports it.
- `resume`: continue from paused output state.
- `flush`: discard queued output immediately.
- `drain`: let already queued audio finish, then report drained.
- `stop`: halt playback and clear running state.
- `close`: release backend resources.
- `report timing`: expose device clock, queued latency, consumed frames, and drift.
- `report underrun`: surface empty queue or missed deadline.
- `report actual device format`: record actual sample rate, channel count, layout, and processing format.
- `select device`: switch route through a controlled open/configure/restart path.

## 1. Current Backend Files To Replace Or Modify

Near-term repair path:

- Wrap the existing `OrbisonicEngine` AVAudioEngine output graph with an `OutputSession` facade.
- Add a negotiated-output report after `configureGraph`, output-device selection, graph rebuild, and engine start.
- Preserve existing `OutputRouteMonitor` discovery but extend it with actual device format and latency queries.
- Keep current normal-monitor code intact while adding an explicit output lifecycle and diagnostics around it.

Longer-term replacement path:

- Move live output responsibilities out of monolithic `OrbisonicEngine` into a `CoreAudioOutputSession`.
- Make `OrbisonicEngine` submit canonical rendered monitor/production blocks rather than owning output details directly.
- Promote `AudioCore/OutputAdapters.swift` from offline validation shape into a real runtime output contract only after tests prove the lifecycle.

## 2. Relevant Device APIs

Target OS priority:

- CoreAudio/AUHAL: primary because Orbisonic is a native macOS app. Relevant for selected output device, stream format, channel layout, nominal sample rate, latency, safety offset, and buffer size.

Conceptual cross-platform references:

- WASAPI shared: useful model for detecting OS shared-mode conversion risk.
- WASAPI exclusive: useful model for fail-loud exact format opening.
- ALSA: useful model for setting exact format, exact channel count, exact sample rate, and failing when hardware cannot satisfy them.
- PulseAudio/PipeWire: useful model for server-graph streams, node targeting, negotiated formats, and shared/server conversion risk.
- JACK: useful model for pro-audio graph timing, one port per output channel, graph latency, and fail-loud connection behavior.
- ASIO if needed: relevant only for future Windows pro-audio builds, not current macOS Orbisonic.

Path B should not import VLC backends. It should imitate the contract: small lifecycle, explicit negotiation, timing reports, flush/drain separation, and loud unsupported-format failure.

## 3. Device Format Negotiation

`OutputSessionRequest` should include:

- requested route ID and UID,
- requested sample rate,
- requested logical channel count,
- requested physical channel count,
- requested layout,
- processing format,
- block size or preferred frames per buffer,
- strictness: `failIfConverted` or `allowExplicitConversion`.

`OutputSessionNegotiation` should record:

- requested format,
- actual device stream format,
- actual engine connection format,
- actual hardware nominal sample rate,
- actual hardware output channel count,
- actual channel layout if available,
- selected route ID/UID,
- buffer size,
- safety offset,
- hardware/device latency,
- whether shared-mode or server-mode conversion risk exists,
- whether any explicit Orbisonic conversion is active.

Default policy:

- Production Sonic Sphere output is strict: if sample rate or channel count cannot be opened as requested, fail loudly.
- Normal Monitor stereo can be more tolerant, but still logs every conversion risk.
- No hidden resampling or downmix is allowed in production mode.

## 4. Refusing Unsupported Channel Counts

Refusal is based on the target output role:

- Desktop monitor requires at least 2 output channels and produces stereo.
- Dante/Sonic Sphere production requires 31 logical channels and either 31 or 32 physical channels depending on route plan.
- Direct 30 production source requires a render plan that produces the expected production topology, not just a 30-channel input.
- 52-channel source preservation does not imply 52-channel output unless a future 52-output route contract exists.

The backend should fail before playback starts when:

- actual device output channels are fewer than requested,
- the route reports unknown or unstable channel count,
- actual route sample rate cannot match the requested strict session rate,
- the channel layout cannot be proven or represented,
- route is a loopback/feedback target,
- route is shared/server output when production mode requires strict output.

## 5. Opening 30 And 52 Channel Devices

30-channel devices:

- Treat 30-channel device output as a pro-audio route class, not a consumer surround route.
- Require route discovery to prove at least 30 physical output channels.
- Require channel identity fixture playback before marking the route proven.
- Require an explicit output map from Orbisonic output channel index to hardware/device channel index.

31/32-channel Dante/Sonic Sphere devices:

- Existing Orbisonic production plans should remain centered on 31 logical channels: 30 full-range plus LFE/sub.
- A 32nd physical channel may remain reserved/silent when the route exposes 32.
- Backend must verify that channel 32 remains silent when reserved.

52-channel devices:

- Do not assume a 52-channel source requires a 52-channel device.
- If future 52-output hardware is introduced, require a separate route contract: 52 physical outputs, explicit map, exact sample rate, latency, and identity fixture.
- Until then, 52-channel handling is source preservation plus explicit renderer-policy blocker or future renderer design.

## 6. Detecting Shared-Mode Downmixing

The backend should flag shared-mode or server-mode risk when:

- actual device channel count differs from requested channel count,
- actual engine output format differs from requested format,
- route is AirPlay, Bluetooth, aggregate, virtual, or system-default without strict channel proof,
- Core Audio reports a stereo stream for a multichannel request,
- external capture or loopback meter shows folded channels,
- output channel identity fixture fails.

Detection layers:

1. Before start: route/device properties and requested-vs-actual stream format.
2. During start: engine connection format and output unit format.
3. During playback: per-channel impulse/noise identity capture when possible.
4. Diagnostics: visible `sharedModeConversionRisk` and `downmixSuspected` flags.

## 7. Avoiding Or Making Resampling Explicit

Production policy:

- Requested source/session sample rate must match route nominal sample rate.
- Backend refuses strict production if actual route sample rate differs.
- No implicit production resampler is inserted.

Normal monitor policy:

- Normal monitor can tolerate Core Audio conversion for preview only if diagnostics record it.
- If Orbisonic adds a native resampler later, it must be a named stage with input rate, output rate, quality, channel count, and measured latency.

Logging:

- `sampleRateConversionOccurred=false` for strict production.
- `sampleRateConversionRisk=true` when AVAudioEngine/Core Audio may convert.
- `explicitResampler=name` only if a future approved resampler is active.

## 8. Measuring Latency

CoreAudio/macOS output session should measure and log:

- device latency,
- safety offset,
- stream latency,
- buffer frame size,
- engine/render callback block size,
- queued frames in Orbisonic buffer,
- estimated total output latency,
- timestamp of last submitted frame,
- timestamp of last timing report.

VLC's useful model is that output latency is not guessed from UI time. It is a backend report that maps queued audio to system time.

Acceptance target:

- Normal Monitor diagnostics show estimated output latency.
- Production route diagnostics show exact route latency where Core Audio exposes it.
- Hardware-only gaps are marked manual, not implied.

## 9. Drift Handling

Path B should define one output clock owner:

- Source frame clock: source/decoder frame positions.
- Render graph clock: frame blocks submitted to renderer.
- Device clock: actual output session timing.
- UI clock: display/progress only.

Drift policy:

- Track expected consumed frame position versus backend reported consumed position.
- If drift grows above threshold, log it.
- For strict production, fail or pause with a visible diagnostic rather than silently time-stretching.
- For normal monitor preview, small drift correction may be allowed only if explicit and logged.

No hidden drift correction should be added until objective tests prove the current failure is clock drift.

## 10. Buffer Queue Design

The output backend should own a bounded queue of rendered blocks:

- Producer: Orbisonic renderer/scheduler.
- Consumer: output backend/device callback.
- Unit: `CanonicalAudioBlock` or a backend-specific deinterleaved/interleaved copy with explicit format.
- Metadata: source frame index, render plan version, generation, PTS/host-time estimate, layout, sample rate, channel count.
- Queue limit: frames and bytes, not unbounded block count.

Queue policy:

- Underrun: report immediately and increment counter.
- Overflow: fail loudly in production; normal monitor may drop according to an explicit policy.
- No allocation in realtime output callback if a lower-level callback is used.
- Metering copies must not consume output queue buffers.

## 11. Flush Versus Drain

Flush:

- Discard queued output immediately.
- Used for seek, stop, source switch, route change, renderer-mode generation change, and fatal mismatch.
- Increments generation so stale callbacks/blocks are rejected.

Drain:

- Let already queued output play to completion.
- Used for natural track end and safe gapless boundaries.
- Reports drained when queue reaches zero and backend confirms no pending device frames beyond measured latency.

This distinction is the main VLC concept to adopt. Stop/seek should not be conflated with natural end.

## 12. Seek Clears Stale Buffers

Seek sequence:

1. Increment output generation.
2. Stop or pause producer scheduling.
3. Flush backend queue.
4. Reset timing report baseline.
5. Seek source/decoder.
6. Rebuild or validate render plan if needed.
7. Resume submit/play with new generation.

Every queued block must carry the generation. Backend rejects stale blocks and records stale rejection count.

## 13. Preserving Channel Identity

Channel identity rules:

- Orbisonic channel layout remains authoritative.
- Device backend receives already-rendered output channels, not source channels requiring reinterpretation.
- Output map must be explicit: Orbisonic output channel index to device channel index.
- Standard surround names are useful for Normal Monitor only; Sonic Sphere uses Orbisonic's production map.
- Reserved physical channels must be checked for silence.
- A route is not marked production-proven until deterministic channel-walk capture passes.

For 30/31-channel output, the backend must prove no truncation, no downmix, no reordering, and no duplicate channels.

For 52-channel source, the backend must not imply output support unless a 52-output render plan exists.

## 14. Output Format Logging

Emit one structured log on every output start/restart:

- source ID,
- route ID/UID/name,
- backend type,
- requested sample rate,
- requested logical channel count,
- requested physical channel count,
- requested layout,
- requested processing format,
- actual route nominal sample rate,
- actual hardware channel count,
- actual engine/device stream format,
- buffer size,
- latency fields,
- strictness policy,
- shared-mode conversion risk,
- explicit resampler status,
- output map identifier,
- render plan version,
- generation.

Do not rely on prose logs alone; diagnostics should consume the same structured record.

## 15. Feature Flag And Rollback

Suggested controls:

- Build flag: `ORBISONIC_ENABLE_NATIVE_OUTPUT_SESSION_V2`
- Runtime setting: `nativeOutputSessionV2Enabled`
- Per-route override: `outputBackend = currentAVAudioEngine | outputSessionV2`

Defaults:

- Feature off.
- Current AVAudioEngine path remains fallback.
- Production routes require manual proof before defaulting to V2.

Rollback policy:

- If V2 fails before playback starts, fallback to current path only when explicit fallback is enabled.
- If V2 fails after playback starts, stop and report instead of switching mid-stream.
- Logs must record backend choice, failure code, fallback decision, and whether audio had started.

## Why This Path May Be Better Than libVLC

It avoids libVLC channel-count uncertainty. Path A is blocked for 30/52 in stock current `amem`; Path B never asks VLC to carry high-channel PCM.

It preserves Orbisonic's existing decoder if decode is proven good. If objective PCM captures show that AVFoundation/ffmpeg/local sources are correct, replacing decode adds unnecessary risk.

It directly attacks timing, buffer, and device problems. Task 10 ranked output negotiation, clocking, flush/drain, scheduling, and gain/mix as plausible downstream root causes.

It can target pro-audio hardware more explicitly than VLC. Orbisonic can model Dante/Sonic Sphere routes, reserved physical channels, route risk, and exact channel maps as product contracts rather than standard speaker layouts.

It avoids full player black-box behavior. Orbisonic keeps selected-source isolation, renderer mode, normal-monitor policy, metering truth, diagnostics, and LaunchServices-tested native app behavior.

## Why This Path May Be Worse Than libVLC

It requires more platform-specific engineering. Core Audio can be done first, but WASAPI, ALSA, PipeWire, PulseAudio, JACK, and ASIO-style backends each require real implementation and tests.

It risks repeating bugs VLC already solved. VLC has mature lifecycle, timing, device, resampling, and backend handling; a native backend must earn that reliability through focused scope and tests.

It has a larger testing burden. Every route class needs negotiated-format checks, latency checks, channel identity, underrun behavior, flush/drain semantics, and long-run playback tests.

Codec and demux issues remain unresolved if decode is the problem. If Task 5/Task 10 tests show Orbisonic's decoded PCM is already corrupt, Path B repairs the wrong layer.

## Path B Acceptance Criteria

Before replacing any current output behavior:

- Existing local decode reference tests show decoded PCM is correct.
- Normal Monitor stereo output passes existing golden tests.
- Output start emits a structured requested-vs-actual format report.
- Unsupported production channel counts fail before playback starts.
- Shared-mode downmix risk is visible in diagnostics.
- No hidden production resampling occurs.
- Output latency is reported when Core Audio exposes it.
- Flush after seek prevents stale buffers.
- Drain at natural end plays queued audio once and then reports drained.
- 30/31-channel production route identity passes with channel-walk fixtures.
- 52-channel source handling remains a renderer-policy decision, not an output-backend promise.
- 20 minute target-hardware playback has no underruns on the intended route.

## Path B Diagnostic Verdict

Path B is the right design direction only if decoded PCM is proven good and the fault moves downstream into output negotiation, buffering, timing, monitor mix, or device behavior. It is not a codec fix. Its value is that it strengthens Orbisonic's native product architecture instead of moving responsibility to VLC or libVLC.

The safest first design slice is not a rewrite. It is an output-session audit layer around the existing AVAudioEngine path that records requested format, actual route/device format, latency, queue state, generation, and conversion risk. Once those facts are visible, a replacement backend can be scoped to the specific failure instead of rebuilding the whole audio stack.
