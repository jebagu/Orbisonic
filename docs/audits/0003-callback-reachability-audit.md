# 0003: Callback Reachability Audit

Status: Updated through Task 020 Slice 8

Date: 2026-05-23

## Scope

This audit maps the current callback, render-block, tap, and future callback-intended process paths before runtime remediation. It is a brownfield inventory, not a compliance claim.

The governing standard is `docs/realtime-audio-family/docs/standards/realtime-callback-safety-doctrine.md`. The callback impact report template is already present at `docs/realtime-audio-family/examples/callback-impact-report.template.md`; this slice does not need a duplicate template.

## Summary

Current live callback paths are not compliant yet. Slice 3 removed the direct HAL callback-local buffer allocation/deallocation. Slice 4 removed `NSLock` from the live channel transfer path and live meter-level snapshots. Slice 5 removed legacy `MeteringService` callback/tap locks and dynamic measurement arrays by publishing bounded raw RMS/peak values into fixed per-signal realtime state. Slice 8 installed callback safety instrumentation and a performance gate report. Live matrix scratch allocation, missing host-level allocation/lock/wait interposition, and unverified denormal handling remain callback-reachable risks.

Blocking findings:

- `LiveAudioPipe.render(matrix:)` allocates temporary arrays from callback-reachable paths.
- `MeterCopyBus.submit` uses `NSLock.try`, appends to an array, and creates copied sample arrays; it is not ready for realtime callback use even though it is closer to a lossy copy bus.
- Future `AudioCore` process paths are structurally useful, but source adapters and meter publication still contain allocation, throwing, array removal, locking, and snapshot publication that must stay outside realtime until remediated.

Non-blocking findings:

- Diagnostic tone and voice source-node render closures are mostly bounded sample writers, with speech file rendering and file reads performed before node creation.
- The monitor meter tap is observational and now enters fixed-size meter publication, but it still lacks runtime callback duration/allocation instrumentation.
- `AVAudioPlayerNode` completion callbacks are transport/lifecycle callbacks, not render callbacks. They currently schedule main-actor work and log, so they must remain outside the realtime safety claim.

Resolved or narrowed in Slice 3:

- `LiveInputCapture.renderInput` now uses `LiveInputCaptureBufferStorage.prepare(frameCount:)` instead of allocating and releasing a new `AudioBufferList` per callback.
- `LiveInputCaptureBufferStorage` allocates the maximum configured channel count and an 8,192-frame callback capacity before `AudioOutputUnitStart`.
- If Core Audio supplies more than 8,192 frames, `prepare(frameCount:)` increments bounded oversized counters and `renderInput` returns `kAudioUnitErr_TooManyFramesToProcess` without allocating.

Resolved or narrowed in Slice 4:

- `LiveChannelRingBuffer.write`, `read`, `peek`, `status`, and `reset` no longer use `NSLock`.
- `LiveChannelRingBuffer` now owns fixed-capacity raw Float storage, atomic read/write cursors, atomic underflow/drop/priming counters, and a nonblocking atomic gate used only to coordinate read/peek with producer-side oldest-frame trimming.
- `LiveAudioPipe.latestMeterLevels` now reads fixed atomic meter slots instead of taking `meterLock`.
- Full buffers trim/drop oldest buffered or incoming frames to stay bounded; if the transfer gate is already active, writers drop incoming frames rather than waiting. Empty reads output silence, increment underflow counters, and re-prime.

Resolved or narrowed in Slice 5:

- `MeteringService.ingest` no longer creates measurement arrays, mutates dictionaries or sets, or takes `NSLock` from callback/tap ingress.
- Meter ingress now publishes raw RMS and peak dBFS into fixed per-signal, fixed-channel realtime state using project-local atomic helpers.
- Meter channel overflow is capped at `OrbisonicAudioLimits.maxSourceChannelCount` and increments a dropped-channel counter instead of growing containers.
- Smoothing, calibration trims, VU display levels, and label semantics are applied on UI/value reads, not during callback/tap ingress.

## Callback Entry Point Map

### 1. HAL Input Callback: `LiveInputCapture.inputCallback`

Entry point:

- Installed through `AURenderCallbackStruct(inputProc: Self.inputCallback)` in `Sources/Orbisonic/LiveAudioBridge.swift:201`.
- Callback body at `Sources/Orbisonic/LiveAudioBridge.swift:258`.

Synchronous reachability:

```text
LiveInputCapture.inputCallback
-> LiveInputCapture.renderInput
-> LiveInputCaptureBufferStorage.prepare
-> AudioUnitRender
-> LiveAudioPipe.write(bufferList:frameCount:)
-> LiveChannelRingBuffer.write
-> LiveAudioPipe.meterLevel
-> MeteringService.ingest(signal:bufferList:frameCount:)
```

Current unsafe operations:

- Uses `LiveChannelRingBuffer.write`, which writes into preallocated storage and publishes cursor/counter state through project-local atomic helpers.
- Updates latest input meter levels through fixed atomic slots.
- Calls `MeteringService.ingest`, which now publishes bounded raw RMS/peak measurements into fixed per-signal realtime state without `NSLock`, dynamic measurement arrays, dictionary mutation, or set mutation.
- Meter smoothing and display-level mapping have moved to non-callback `MeteringService.levels(...)` reads.
- An explicit 8,192-frame prepared callback capacity now exists. Oversized callbacks return `kAudioUnitErr_TooManyFramesToProcess` and increment `LiveInputCaptureBufferStorage` counters without allocation.

Current tests:

- `Tests/OrbisonicTests/LiveAudioBridgeTests.swift` covers capture buffer reuse, oversized-frame rejection, ring-buffer write/read, overflow, priming, underflow, non-consuming peek behavior, and the no-`NSLock` transfer-path guard.
- `Tests/OrbisonicTests/LiveNormalMonitorRouteTests.swift` covers live normal-monitor routing behavior through `LiveAudioPipe`.
- `Tests/OrbisonicTests/MeteringServiceTests.swift` covers legacy meter math.
- `Tests/OrbisonicTests/MeteringIsolationTests.swift` covers meter isolation expectations.
- No test currently proves zero HAL callback allocations, zero blocking locks, max callback time, deadline misses, or telemetry drops.
- Slice 3 tests prove storage pointer reuse and oversized-frame rejection, but not runtime allocation counters.

Intended remediation:

- Slice 4: complete. The new bounded transfer is now covered by Slice 8 report-layer instrumentation hooks, but full realtime qualification remains blocked by the current performance report.
- Slice 5: complete. Fixed-size meter publication is now represented in Slice 8 report-layer drop/coalesce counters, but host-level allocation/lock/wait evidence remains incomplete.
- Slice 8: complete. Callback allocation, lock/wait, duration, deadline, telemetry-drop, meter-drop, and route-mismatch report fields now exist; the current gate report is `docs/audits/0004-callback-safety-performance-gates.md`.

### 2. HAL Render Helper: `LiveInputCapture.renderInput`

Entry point:

- Direct helper called synchronously by `LiveInputCapture.inputCallback` at `Sources/Orbisonic/LiveAudioBridge.swift:260`.
- Implementation starts at `Sources/Orbisonic/LiveAudioBridge.swift:267`.

Synchronous reachability:

```text
LiveInputCapture.renderInput
-> LiveInputCaptureBufferStorage.prepare
-> AudioUnitRender
-> LiveAudioPipe.write(bufferList:frameCount:)
```

Current unsafe operations:

- Callback-local buffer allocation/deallocation has been removed from this helper.
- Downstream `LiveAudioPipe.write(bufferList:frameCount:)` reaches fixed-size `MeteringService.ingest`; live matrix rendering remains separately callback-risky.
- Calls `AudioUnitRender`, which is expected in the HAL input callback design but still sits inside the framework-call audit boundary required by the family standard.
- Oversized callbacks return `kAudioUnitErr_TooManyFramesToProcess` before `AudioUnitRender`.

Current tests:

- Covered indirectly by live bridge unit tests for downstream pipe/ring behavior.
- `LiveAudioBridgeTests` directly cover `LiveInputCaptureBufferStorage` reuse and oversized-frame behavior.
- No direct instrumentation test currently invokes the HAL callback with allocation/lock counters.

Intended remediation:

- Treat `renderInput` as narrowed but not fully compliant until downstream live pipe transfer and meter publication are callback-safe.

### 3. Live AVAudioSourceNode Closures In `OrbisonicEngine`

Entry point:

- Live source nodes are created in `Sources/Orbisonic/OrbisonicEngine.swift:640`.
- The render closure starts at `Sources/Orbisonic/OrbisonicEngine.swift:641`.

Synchronous reachability:

```text
AVAudioSourceNode live closure
-> LiveAudioPipe.render(channelIndex:audioBufferList:frameCount:)
-> LiveChannelRingBuffer.read
-> optional OrbisonicEngine.clear(audioBufferList:frameCount:)
```

Current unsafe operations:

- `LiveChannelRingBuffer.read` uses a nonblocking atomic gate and outputs silence if coordination is unavailable.
- The closure reads `self?.liveInputMuted` from the engine object. That is mutable app state, not an explicit realtime-safe snapshot.
- Empty-buffer fallback and underflow counters update atomic ring state.
- `LiveAudioPipe.render(channelIndex:)` avoids heap allocation in the visible loop and now reads from the bounded atomic ring transfer.

Current tests:

- `Tests/OrbisonicTests/LiveAudioBridgeTests.swift` covers ring read semantics.
- `Tests/OrbisonicTests/LiveNormalMonitorRouteTests.swift` covers live monitor route behavior.
- `Tests/OrbisonicTests/PureAudioArchitectureBoundaryTests.swift` and `Tests/OrbisonicTests/ArchitectureBoundaryAllowlist.swift` keep the legacy AVFoundation/Core Audio boundary visible.
- No test currently proves the source-node closure has zero lock/wait or stable worst-case time.

Intended remediation:

- Slice 4: complete. Add callback duration and contention/drop instrumentation before claiming realtime compliance.
- Move live mute to a callback-safe immutable or atomic value read.
- Keep graph mutation, route selection, diagnostics, and UI state outside the closure.

### 4. Live Matrix Render Path In `LiveAudioPipe.render(matrix:)`

Entry point:

- `LiveAudioPipe.render(matrix:audioBufferList:frameCount:)` starts at `Sources/Orbisonic/LiveAudioBridge.swift:684`.
- Current source inspection did not find a live `AVAudioSourceNode` closure calling this method directly. It is still callback-intended because it renders live pipe data into an output `AudioBufferList`.

Synchronous reachability:

```text
LiveAudioPipe.render(matrix:audioBufferList:frameCount:)
-> LiveChannelRingBuffer.read for each input
-> RendererMatrixSampleRenderer.render
-> MeteringService.ingest(signal:.sonicSphere,...)
```

Current unsafe operations:

- Allocates nested `inputScratch` arrays sized by `matrix.inputCount * frameCount`.
- Calls `LiveChannelRingBuffer.read`, which uses the same bounded transfer path as live source-node rendering.
- Calls fixed-size `MeteringService.ingest`; the remaining allocation risk in this path is the matrix scratch allocation before meter publication.
- Worst-case loop bounds depend on `matrix.inputCount`, `matrix.outputCount`, and `frameCount`; they are not currently enforced as a callback performance gate.

Current tests:

- `Tests/OrbisonicTests/SonicSphereMeteringTests.swift` covers the live pipe path for Sonic Sphere analysis metering.
- `Tests/OrbisonicTests/MeteringIsolationTests.swift` covers isolation expectations.
- No test proves this path is callback-safe.

Intended remediation:

- If this path becomes a live render closure, preallocate scratch storage or replace it with an `AudioCore` render block that receives prepared blocks.
- Move Sonic Sphere meter publication to nonblocking value snapshots.
- Add explicit max input count, output count, and frame count gates.

### 5. Monitor Meter Tap Closure In `OrbisonicEngine`

Entry point:

- `preVolumeMixer.installTap` is installed at `Sources/Orbisonic/OrbisonicEngine.swift:2573`.
- The closure calls `captureMonitorMeters(from:)` at `Sources/Orbisonic/OrbisonicEngine.swift:2574`.

Synchronous reachability:

```text
monitor meter tap closure
-> OrbisonicEngine.captureMonitorMeters
-> MeteringService.ingest(signal:.monitor,bufferList:frameCount:)
```

Current unsafe operations:

- The tap closure enters fixed-size `MeteringService.ingest`, which publishes raw RMS/peak values and drop counters without locks or dynamic measurement arrays.
- Empty or invalid buffers call `resetMonitorMeterLevels`, which now stores fixed inactive meter state without `NSLock`, dictionary mutation, set mutation, or dynamic channel-state arrays.
- This tap is observational and does not consume output. Slice 8 installed report-layer callback duration/allocation fields, but full compliance still needs host-level allocation evidence and real stress timing.

Current tests:

- `Tests/OrbisonicTests/MeteringServiceTests.swift`
- `Tests/OrbisonicTests/MeteringIsolationTests.swift`
- `Tests/OrbisonicTests/NormalMonitorGoldenAudioTests.swift`
- No tap-specific test proves nonblocking behavior.

Intended remediation:

- Slice 5: complete. Keep smoothing, labels, UI display levels, and quiet-signal visual-tail mapping outside callback/tap ingress.
- Slice 8: complete. Runtime report hooks exist for allocation count, lock/wait count, callback duration, and drop counters; host-level interposition and real stress timing remain follow-up.

### 6. Diagnostic Tone Source-Node Closures

Entry points:

- `makeToneNode` closure starts at `Sources/Orbisonic/OrbisonicEngine.swift:2335`.
- `makeChannelToneNode` closure starts at `Sources/Orbisonic/OrbisonicEngine.swift:2409`.
- `SineToneState.nextSample` starts at `Sources/Orbisonic/TestToneSupport.swift:112`.

Synchronous reachability:

```text
AVAudioSourceNode diagnostic tone closure
-> SineToneState.nextSample
-> write sample into each output buffer
```

Current unsafe operations:

- The closure mutates `SineToneState` state captured by the closure.
- It performs bounded loops over `frameCount * bufferCount`.
- It calls `sin` for each frame through `SineToneState.nextSample`.
- No heap allocation, locks, logging, file I/O, UI, parser work, or route discovery are visible in the closure body.
- `makeChannelToneNode` appears present but not currently selected by the active `playDiagnosticChannelTone` path; the active path uses `makeToneNode` or `makeMonitorVoiceNode`.

Current tests:

- Diagnostic channel behavior is covered indirectly by VU routing and local monitor route tests.
- No callback instrumentation currently covers tone source-node duration or max frame bounds.

Intended remediation:

- Keep diagnostic synthesis preconfigured before node start.
- Add callback duration gates before calling diagnostic source nodes compliant.
- Consider replacing per-frame `sin` with a cheaper oscillator or table only if performance evidence requires it.

### 7. Diagnostic Voice Source-Node Closures

Entry points:

- `makeMonitorVoiceNode` closure starts at `Sources/Orbisonic/OrbisonicEngine.swift:2436`.
- `makeChannelVoiceNode` closure starts at `Sources/Orbisonic/OrbisonicEngine.swift:2464`.
- `DiagnosticSpeechPlayhead.nextSample` starts at `Sources/Orbisonic/TestToneSupport.swift:166`.

Synchronous reachability:

```text
AVAudioSourceNode diagnostic voice closure
-> DiagnosticSpeechPlayhead.nextSample
-> write sample into each output buffer
```

Current unsafe operations:

- The closure mutates `DiagnosticSpeechPlayhead` state captured by the closure.
- It performs bounded loops over `frameCount * bufferCount`.
- It reads from the preloaded `DiagnosticSpeechClip.samples` array.
- No file I/O or speech synthesis is visible in the closure; `DiagnosticSpeechRenderer.clip(for:)` performs temp-file creation, `NSSpeechSynthesizer`, run-loop waiting, `AVAudioFile` reads, and array creation before node creation.
- The callback safety of captured Swift array reads and class mutation has not been instrumented.

Current tests:

- No focused callback safety test exists for diagnostic voice source nodes.

Intended remediation:

- Keep speech rendering and `AVAudioFile` reads outside realtime.
- Preserve voice playhead as a prepared immutable sample source plus minimal realtime cursor.
- Add callback duration and allocation instrumentation if these nodes remain part of supported diagnostics.

### 8. AudioCore Process Path Intended To Become Callback-Reachable

Entry point:

- `DualOutputRenderCoordinator.renderOneBlock(frameCount:)` starts at `Sources/AudioCore/OutputAdapters.swift:590`.
- `MatrixRenderKernel.process` starts at `Sources/AudioCore/RenderKernels.swift:282`.
- `LiveCaptureSourceAdapter.renderIntoCanonicalBus` starts at `Sources/AudioCore/SourceAdapters.swift:269`.
- `ManagedLocalAssetSourceAdapter.renderIntoCanonicalBus` starts at `Sources/AudioCore/SourceAdapters.swift:512`.

Synchronous reachability:

```text
DualOutputRenderCoordinator.renderOneBlock
-> sourceAdapter.renderIntoCanonicalBus
-> CanonicalSourceBus.copyCurrentBlock
-> MeterCopyBus.submit(input)
-> renderMeterBlocks
-> DesktopMonitorRenderer.process
-> DanteSonicSphereRenderer.process
-> MeterCopyBus.submit(desktop)
-> MeterCopyBus.submit(dante)
-> DesktopMonitorRenderer.process
-> DanteSonicSphereRenderer.process
-> desktopAdapter.consume
-> danteAdapter.consume
-> PureAudioMeteringService.publishLatestSnapshot
```

Current unsafe operations if promoted directly into a realtime callback:

- `LiveCaptureSourceAdapter.nextBlock` and `ManagedLocalAssetSourceAdapter.nextBlock` allocate `CanonicalAudioBlock` when queues are empty.
- Source adapters use `queuedBlocks.removeFirst`, which is not a bounded callback-safe queue operation.
- `MeterCopyBus.submit` uses `NSLock.try`; lock contention drops are intended but not counted on the current `guard lock.try() else { return false }` path.
- `MeterCopyBus.submit` appends to an array and constructs `MeterCopiedBlock`, which copies channel sample arrays.
- `PureAudioMeteringService.publishLatestSnapshot` drains with a blocking lock and builds a `MeterSnapshot`; it must not run in a realtime callback.
- The process methods throw errors; an actual callback wrapper must convert prepared validation failures to bounded status or silence behavior without throwing through the callback.

Current safe or useful properties:

- `MatrixRenderKernel.process` writes into caller-owned destination blocks.
- Render loops are explicit and bounded by `matrix.inputCount`, `matrix.outputCount`, and `frameCount`.
- `DualOutputRenderCoordinator.prepare` owns several block allocations before `renderOneBlock`.
- Meter copy points already preserve source truth: input source bus, desktop post-render pre-output gain, and Dante post-render pre-output gain.

Current tests:

- `Tests/AudioCoreTests/RenderKernelTests.swift`
- `Tests/AudioCoreTests/OutputAdapterTests.swift`
- `Tests/AudioCoreTests/MeteringTelemetryTests.swift`
- `Tests/AudioCoreTests/SourceAdapterTests.swift`
- `Tests/OrbisonicTests/PureAudioArchitectureBoundaryTests.swift`
- No current test proves `renderOneBlock` is callback-safe or deadline-safe.

Intended remediation:

- Do not wire `renderOneBlock` directly into a live callback until source queues, meter copy, snapshot publication, error propagation, and output adapters are separated into prepared realtime and non-realtime phases.
- Keep `publishLatestSnapshot` on a non-realtime telemetry/UI plane.
- Add performance gates for frame capacity, channel count, p95, p99, max duration, deadline misses, allocations, locks/waits, and meter drops.

## Callback-Like But Not Render-Block Entry Points

`AVAudioPlayerNode.scheduleBuffer` completion callbacks exist in local gapless, streaming, and full-file playback paths. They schedule `Task { @MainActor ... }`, use retained-buffer locks in local gapless playback, call transport methods, and log. These callbacks are lifecycle/transport notifications, not audio render callbacks. They are excluded from the realtime compliance claim and must remain out of any callback-reachable audio render path.

## Current Test Coverage Matrix

| Path | Existing coverage | Missing evidence |
| --- | --- | --- |
| HAL input callback downstream pipe | `LiveAudioBridgeTests`, `LiveNormalMonitorRouteTests` | Runtime allocation counters, callback duration, live matrix scratch remediation |
| Live source-node render | `LiveAudioBridgeTests`, `LiveNormalMonitorRouteTests` | Realtime-safe mute snapshot, duration gates, atomic contention/drop stress evidence |
| Monitor tap metering | `MeteringServiceTests`, `MeteringIsolationTests`, `NormalMonitorGoldenAudioTests` | Runtime callback duration/allocation evidence |
| Diagnostic source nodes | VU/routing tests indirectly | Source-node callback duration and allocation evidence |
| AudioCore render kernels | `RenderKernelTests`, `OutputAdapterTests` | Whole callback wrapper safety, source queue safety, meter bus safety |
| Meter copy bus | `MeteringTelemetryTests` | Callback-safe allocation/lock/drop instrumentation |

## Required Follow-Up By Slice

- Slice 3: complete. HAL input callback allocation/deallocation removed; oversized-frame policy documented and tested.
- Slice 4: complete. Callback-facing `NSLock` removed from live capture/playback transfer and live meter-level snapshots.
- Slice 5: complete. Legacy meter publication now uses bounded nonblocking raw RMS/peak state with drop counters and UI-side smoothing/display mapping.
- Slice 6: complete. Orbital VU data now maps value-only snapshots to monitor or Sonic Sphere markers without graph, route, tap, buffer, or SceneKit ownership.
- Slice 7: complete. Active Renderer tab orbital VU rendering consumes value marker state only and adds no callback reachability.
- Slice 8: complete. Callback performance and safety instrumentation now exists, and the current gate report blocks compliance for live matrix scratch allocation.
- Slice 10: produce final compliance matrix only after all mandatory gates pass or remaining exceptions have accepted ADRs.

## Callback Impact

New callback-reachable functions:

- `LiveInputCaptureBufferStorage.prepare(frameCount:)` is now callback-reachable from `LiveInputCapture.renderInput`.
- `RealtimeAtomicInt.load/store/add`, `RealtimeAtomicFlag.load/store/tryEnter`, and `RealtimeAtomicFloat.load/store` are now callback-reachable through live transfer and latest-level publication.
- `MeterSignalRealtimeState.publish/reset/status`, `MeterRealtimeChannelState.publish/reset/rawLevel`, and `MeteringService.ingest` are callback/tap-reachable for bounded meter publication.
- Slice 6 added `OrbitalVUMeterModel`, which is not callback-reachable and reads only value snapshots on the non-realtime UI/model side.
- Slice 7 added `OrbitalSonicSphereMeterPanel` and SceneKit marker styling from `OrbitalVUMeterViewState`; this is UI-side rendering only and not callback-reachable.
- Slice 8 added `RealtimeCallbackSafetyProbe.begin`, `RealtimeCallbackSafetyProbe.end`, explicit counter record methods, and optional `LiveAudioPipe` probe calls around live render entry points. These are callback-adjacent evidence hooks and use preallocated atomic storage; report generation is non-callback.

Allocation risk:

- Direct HAL callback buffer-list and per-channel sample allocation/deallocation removed.
- `LiveInputCaptureBufferStorage` allocates raw buffer-list storage and per-channel Float storage before callback start.
- `LiveAudioPipe.write(bufferList:frameCount:)` no longer allocates `nextMeters`.
- `MeteringService.ingest` no longer allocates measurement arrays or grows channel-state containers; `MeteringService.levels(...)` still allocates returned value arrays on the non-callback UI/read side.
- Existing documented allocation risks remain in live pipe matrix render, `MeterCopyBus`, and future `AudioCore` source adapters.
- Slice 8 does not introduce a new live matrix allocation; it records the existing `LiveAudioPipe.render(matrix:)` scratch-array allocation through an explicit callback allocation counter. The current performance report blocks compliance while that counter is nonzero.

Lock/wait risk:

- `LiveChannelRingBuffer` and `LiveAudioPipe.latestMeterLevels` no longer use `NSLock`.
- `MeteringService.ingest`, `reset`, and `setInactive` no longer use `NSLock`.
- Live transfer uses one nonblocking atomic gate for producer-side trimming versus reader/peek access; writers drop incoming frames and readers output silence rather than waiting when coordination is unavailable.
- Existing documented lock risks remain in `MeterCopyBus`.
- Slice 8 lock and wait/sleep counters are explicit hooks plus static source guards, not host-wide lock/wait interposition. That remains a documented evidence gap.

I/O/logging/UI risk:

- No new runtime I/O, logging, UI, or parser risk introduced.
- Slice 8 callback probes record to atomic slots only; text report generation, percentile sorting, and docs are off the callback path.
- Diagnostic speech rendering uses file I/O, `NSSpeechSynthesizer`, and run-loop waiting before source-node creation; it must stay outside callback reachability.

Worst-case loop bounds:

- `LiveInputCaptureBufferStorage.prepare(frameCount:)` loops over prepared capture channels only, capped by `OrbisonicAudioLimits.maxSourceChannelCount` and the configured capture channel count.
- `MeteringService.ingest` loops over the published channel count capped by `OrbisonicAudioLimits.maxSourceChannelCount` and over supplied frame count for RMS/peak measurement; smoothing/display mapping loops only during non-callback reads.
- Current downstream callback-reachable loop bounds remain `frameCount * channel/buffer count` for live pipe, tone, voice, and meter paths. Ring transfer loops are bounded by the supplied frame count and fixed channel count; status snapshots are bounded by channel count.

Queue-full or overload policy:

- Oversized HAL callback blocks above 8,192 frames return `kAudioUnitErr_TooManyFramesToProcess` and increment bounded counters without allocating.
- Full live channel transfer drops oldest buffered or incoming frames to stay bounded and increments overflow/drop counters. If read/peek coordination is active, writers drop incoming frames instead of waiting. Empty reads output silence, increment underflow counters, and re-prime. Meter copy bus drops on full queue, but allocation/lock behavior is not callback-safe.
- Legacy app metering caps channels at `MeteringService.maxRealtimeChannelCount`; overflow channels increment `MeteringSignalStatus.droppedChannelMeasurementCount`.
- Slice 8 report counters include max events drained, event drops/coalesces, telemetry drops, meter drops/coalesces, and route mismatch blocks.

Tests or instrumentation run:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter LiveAudioBridgeTests`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `./scripts/refresh-orbisonic-app.sh`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter LiveNormalMonitorRouteTests`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MeteringServiceTests`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MeteringIsolationTests`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MeteringTelemetryTests`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter SonicSphereMeteringTests`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter RealtimeCallbackSafetyInstrumentationTests`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter PureAudioArchitectureBoundaryTests`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter RendererModuleTests`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter OrbisonicUITweakTests`
