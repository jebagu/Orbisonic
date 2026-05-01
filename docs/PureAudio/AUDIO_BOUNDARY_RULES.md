# Audio Boundary Rules

These rules define the target Pure Audio architecture. Existing code may violate them until migrated, but new rewrite work must move toward these constraints rather than widening current coupling.

## Core Rule

Only `AudioCore` mutates live audio. Everything else sends typed commands or reads immutable snapshots.

No UI, VU, metadata parser, renderer display, route picker, web server, or view model may hold mutable references to live audio objects or mutate audio graph state directly.

## Forbidden Dependencies Outside AudioCore

Code outside `AudioCore` must not create, own, mutate, expose, or cache:

- `AVAudioEngine`
- `AVAudioNode`
- `AVAudioMixerNode`
- `AVAudioPlayerNode`
- `AVAudioSourceNode`
- `AudioUnit`
- `AudioComponent`
- `AudioDeviceID`
- `AudioBufferList`
- `UnsafeMutableAudioBufferListPointer`
- Ring buffers used for real-time audio
- `UnsafeMutablePointer<Float>` or other mutable audio sample pointers
- Mutable `RendererMatrix` references used by production render state
- Output handles, output callbacks, HAL units, or graph taps

Outside `AudioCore`, Core Audio and AVFoundation objects may appear only as inert import-time descriptors or adapter-private implementation details explicitly owned by `AudioImport`.

## Forbidden Dependencies Outside AudioImport

`AudioImport` is the only subsystem allowed to perform local-file probing, decoding, external tool invocation, or offline managed-asset conversion.

Code outside `AudioImport` must not:

- Run `ffmpeg` or `ffprobe`.
- Open files with `AVAudioFile` for production decode.
- Decide whether a local file requires offline conversion.
- Convert sample rates for production playback.
- Cache decoded production assets.
- Expose temporary decode paths to UI as playback sources.

`AudioImport` may depend on AVFoundation and external tools for probing, decoding, and offline conversion. It must return typed descriptors, managed asset references, and conversion ledger entries, not live audio objects.

## Forbidden Dependencies Inside UI And VU Modules

UI and VU modules must not import or use live-audio mutation APIs. Target UI and VU code must avoid direct dependencies on:

- `AVFoundation`
- `AudioToolbox`
- `CoreAudio`
- `AudioUnit`
- `AudioBufferList`
- `AVAudioPCMBuffer`
- `AVAudioEngine`
- `RendererMatrix` mutable state
- Ring buffers or render buffers

UI and VU modules may read:

- `AudioSnapshot`
- `RouteSnapshot`
- `MeterSnapshot`
- `ImportSnapshot`
- Immutable display models derived from those snapshots

UI and VU modules may send:

- Typed `AudioCommand` values
- Typed `ImportCommand` values

## No Public Exposure Of Live Audio Internals

Public APIs outside `AudioCore` must not expose:

- `AVAudioEngine`
- `AVAudioNode`
- `AudioUnit`
- `AudioDeviceID`
- `AudioBufferList`
- Ring buffers
- `UnsafeMutablePointer<Float>`
- Mutable `RendererMatrix` references
- Output handles
- HAL callbacks
- Graph tap handles

If a subsystem needs to identify a route, source, layout, or output, it must use stable value types such as route IDs, channel counts, sample rates, channel layouts, and validation summaries.

## Command-Only Mutation

All audio mutations must be expressed as typed commands:

- Start session.
- Stop session.
- Select source.
- Select desktop monitor route.
- Select Dante renderer route.
- Load managed asset.
- Start live capture.
- Change session sample rate while stopped.
- Set output gain.
- Set renderer mode.
- Start or stop diagnostic tone.

Commands enter `AudioCore` through the `AudioControl` facade and are serialized through `AudioCommandQueue`. They are validated before changing real-time state.

As of Prompt 4, `AudioControl` is the only app-facing command surface for new Pure Audio work. It exposes typed value commands for:

- `startSession(_:)`
- `stopSession()`
- `selectSource(_:)`
- `setDesktopMonitorGain(_:)`
- `setDanteOutputGain(_:)`
- `setDanteOutputEnabled(_:)`
- `setDesktopOutputEnabled(_:)`
- `setRenderMode(_:)`
- `prepareLocalAsset(_:)`
- `importLocalAssetToSessionRate(_:)`
- `requestRouteRefresh()`
- `requestGraphAuditSnapshot()`

The facade returns value results and snapshots only. It must never expose graph handles, output handles, mutable render state, or raw audio storage.

Migration exception: `OrbisonicViewModel` still calls `OrbisonicEngine` directly for the existing Normal Monitor path. That direct path is legacy compatibility only and must shrink in later prompts as call sites move to `AudioControl`. New UI, VU, metadata, and route-picker work must not add new direct engine mutation calls.

## Read-Only Telemetry

All telemetry leaving `AudioCore` must be immutable:

- Session state.
- Source state.
- Route state.
- Render graph plan summary.
- Desktop output health.
- Dante output health.
- Conversion ledger.
- Meter levels.
- Underrun/drop counters.
- Last validation error.

Telemetry must be copy-only. Observers must not receive references that can affect rendering.

As of Prompt 4, the initial read-only telemetry surface is `AudioTelemetry`. It provides:

- `latestMeterSnapshot()`
- `latestRouteSnapshot()`
- `latestGraphAudit()`
- `latestConversionLedger()`
- `latestSessionFormat()`

These methods return `AudioContracts` values or `AudioCore` snapshot values. They are polling-friendly and do not require UI framework imports.

As of Prompt 11, new Pure Audio metering is owned by `Sources/AudioCore/MeteringTelemetry.swift`:

- `MeterCopyBus` accepts copied source, desktop, and Dante render blocks only.
- `MeterAccumulator` computes `ChannelMeter` values from those copies.
- `PureAudioMeteringService` publishes value-only `MeterSnapshot` telemetry.
- If the copy queue is full, meter data is dropped. Audio must never wait for meters.
- Meter calibration may affect VU display values only. It must not affect desktop or Dante audible output hashes.

`Sources/Orbisonic/MeteringService.swift` remains a legacy compatibility path for the existing Normal Monitor and analysis meters. It is not the Pure Audio authority and must not be expanded into new live graph ownership.

Meter names must preserve source truth:

- `Dante Output Meter` means the meter is based on the actual Dante render bus.
- `Sonic Sphere Analysis Meter` means the meter is synthetic, legacy, or otherwise not proof of audible Dante output.

## Real-Time Callback Forbidden Operations

Real-time render and capture callbacks must not perform operations that can block, allocate unpredictably, or call back into UI/application state. Forbidden operations include:

- File I/O.
- Network I/O.
- Process launch.
- `ffmpeg` or `ffprobe`.
- Logging from the callback.
- Locks, semaphores, waits, or dispatch sync.
- MainActor work or AppKit/SwiftUI calls.
- UserDefaults access.
- Codable/JSON work.
- Route discovery.
- Sample-rate negotiation.
- Graph rebuilds.
- Heap-growing arrays, dictionaries, or strings.
- Installing or removing taps.
- Mutating UI/view-model state.

The callback may read the current immutable render plan, read source buffers owned by `AudioCore`, write output buffers, update lock-free or bounded telemetry counters, and publish lossy meter copies through a non-blocking path.

## Immutable Render Graph Plans

As of Prompt 7, the production graph intent is represented by `RenderGraphPlan` in `AudioCore`.

Rules for the plan layer:

- `RenderGraphPlanner` creates plans off the real-time thread.
- `PlanValidator` must validate a complete plan before publication.
- `PlanPublicationStore` refuses invalid plans and stale versions.
- Published plans are immutable values. Callers may inspect read-only fields and copy coefficient data for tests, but cannot mutate live render state.
- `ImmutableMatrix` must not expose mutable storage, unsafe buffers, graph nodes, or output handles.
- Desktop and Dante outputs are sibling plan sections. Desktop gain and desktop downmix coefficients cannot mutate Dante render coefficients or Dante gain.
- Meter calibration lives in `GainPlan` but is not an audible gain. It must not alter desktop or Dante output coefficients.
- `MeterPlan` may define copy points only. It must not contain graph node references, tap handles, callbacks, raw buffer pointers, or route handles.
- `MeterCopyBus` may receive only copied block data. It must not expose live source, desktop, or Dante render storage to UI.
- Physical Dante channel 32, when present, is reserved and must be silent unless a future explicit assignment policy changes that rule.

Current migration note: `PlanPublicationStore` is lock-protected because it is not yet read by the real-time callback. Before the live render path consumes it, the store must be replaced or wrapped by a real-time-safe atomic pointer/value swap at a render block boundary.

## No Hidden Production Sample-Rate Conversion

There is one session sample rate.

Production playback and production live capture must not insert hidden sample-rate conversion. If an input file or route does not match the session rate, the session must stop for an explicit rate switch or the file must be converted offline into a managed asset before production playback.

Desktop-only preview may use non-production conversion only when clearly labeled and kept out of Dante.
