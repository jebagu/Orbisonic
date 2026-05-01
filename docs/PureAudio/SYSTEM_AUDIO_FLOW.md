# System Audio Flow

This document defines the target flow for the Pure Audio rewrite. The diagrams are intentionally text-only so later prompts can copy them into tests and comments without introducing visual tooling.

## Production Flow

Desktop stereo monitor:

```text
Source adapters
-> canonical source bus
-> immutable render graph plan
-> desktop stereo renderer
-> desktop output adapter
```

Dante Sonic Sphere renderer:

```text
Source adapters
-> canonical source bus
-> immutable render graph plan
-> Dante Sonic Sphere renderer
-> Dante output adapter
```

Meter copies:

```text
Copies from source, desktop render, and Dante render
-> MeterCopyBus
-> PureAudioMeteringService / MeterAccumulator
-> read-only UI snapshots
```

The desktop and Dante production outputs are siblings. The desktop monitor is a confidence output and must not own or gate Dante renderer state. Dante is the production Sonic Sphere output.

## Control Flow

```text
UI/ViewModel
-> AudioControl facade
-> AudioCommandQueue
-> AudioCoreShell
-> RenderGraphPlanner
-> PlanValidator
-> immutable RenderGraphPlan
-> PlanPublicationStore
-> atomic plan swap at block boundary in the future real-time renderer
-> real-time render callback
```

Prompt 4 creates the initial command and snapshot boundary:

```text
UI/ViewModel
-> AudioControl
-> AudioCommandQueue
-> AudioCoreShell
-> AudioCoreCompatibilityAdapter where legacy engine bridging is still required
```

The current `AudioCoreShell` validates and records value state only. It does not connect Dante, replace the render kernel, or alter the existing Normal Monitor playback path.

Read-only telemetry now has a named surface:

```text
AudioCoreShell
-> AudioTelemetry
-> latest MeterSnapshot / AudioRouteSnapshot / AudioGraphAuditSnapshot / ConversionLedger / AudioSessionFormat
-> UI/VU value snapshots
```

During migration, `OrbisonicViewModel` still has direct legacy calls into `OrbisonicEngine`. Those calls are explicitly outside the target flow and must move behind `AudioControl` in later prompts.

## Source Adapter Contract

Source adapters convert approved sources into the canonical source bus. A source adapter must declare:

- Source type.
- Source route or managed asset ID.
- Source sample rate.
- Source channel count.
- Source channel layout.
- Canonical output layout.
- Whether it is live or finite.
- Whether it can run at the current session sample rate.

Source adapters do not select output devices and do not mutate render graph topology directly.

## Canonical Source Bus Contract

The canonical source bus carries only explicit production-ready audio:

- Float32 samples.
- Non-interleaved/deinterleaved buffers.
- Explicit channel count.
- Explicit channel layout.
- Session sample rate.

No source may enter the canonical source bus if its sample rate is unknown or mismatched, unless it is already an offline converted managed asset at the session sample rate.

Prompt 8 introduces the first concrete `AudioCore` source-block types:

- `AudioBlockFormat` describes Float32 non-interleaved PCM at one session sample rate, with explicit frame count, channel count, and layout.
- `CanonicalAudioBlock` owns preallocated non-interleaved Float32 channel storage for AudioCore render work. It exposes safe sample setters/getters and copies for tests, but it does not expose raw buffers to UI.
- `CanonicalSourceBus` validates source descriptors against `AudioSessionFormat`, accepts deterministic fixture injection for tests, and tracks a monotonic frame index.

Prompt 9 adds the first concrete source adapter layer around this bus:

- `AudioSourceAdapter` is the common source protocol. It exposes a `SourceDescriptor`, `prepare(sessionFormat:)`, `start()`, `stop()`, `renderIntoCanonicalBus(_:frameCount:)`, and `latestStatusSnapshot()`.
- `LiveLoopbackSourceAdapter` is the shared validation wrapper for live Roon, Spotify, and Aux capture. It validates route availability, expected loopback identity, session sample-rate match, Float32 non-interleaved PCM format, and the 1...64 source channel limit.
- `RoonSourceAdapter` treats Roon metadata as diagnostic only. The live capture route sample rate and channel count control production admission. If metadata and live route sample rate disagree, the adapter reports a diagnostic message without overriding HAL/live PCM truth.
- `SpotifySourceAdapter` fixes Spotify to stereo by product policy even if the route reports more input channels.
- `AuxSourceAdapter` uses the discovered live route input channel count and assigns a deterministic fallback layout.
- `ManagedLocalAssetSourceAdapter` admits only managed/session-rate local assets and feeds prevalidated Float32 blocks into the canonical bus. It does not perform playback-time sample-rate conversion.
- `TestToneSourceAdapter` generates deterministic source tones directly at the session sample rate for stereo ID and Dante channel ID tests.
- `OffSourceAdapter` emits silence through the same bus contract.
- `SourceAdapterFactory` maps typed `SourceSelection` values, live input route descriptors, managed asset descriptors, and test-tone modes to an adapter or a typed `AudioError`.

The Prompt 9 adapters are still not wired to the live dual-output engine. They are a validated canonical-bus entry layer for deterministic tests and later output-adapter integration.

## Render Graph Plan Contract

Prompt 7 introduces `RenderGraphPlan` in `AudioCore`. The plan is immutable once created and validated. It describes:

- Session sample rate.
- Source descriptor and layout.
- Desktop render path through `DesktopDownmixPlan`.
- Dante render path through `DanteRenderPlan`.
- Output route IDs.
- Output channel counts.
- Dante logical channel map.
- Separate gain domains through `GainPlan`.
- Meter copy points through `MeterPlan`.
- Conversion ledger reference.

`ImmutableMatrix` stores desktop and Dante coefficients in private immutable storage. It exposes gain accessors and explicit test copies, but it does not expose mutable storage or unsafe buffers.

`PlanValidator` validates the complete plan before publication:

- `AudioSessionFormat` must be valid.
- Source sample rate must match the session sample rate.
- Source channel count and layout count must match.
- Desktop matrix output count must be stereo.
- Dante output must be 31 logical channels, with 31 or 32 physical channels.
- Physical Dante channel 32 must be reserved and silent when present.
- Conversion ledger must not record production sample-rate conversion.
- Metering must be copy-only.

`PlanPublicationStore` currently uses a lock-protected validated snapshot store because it is not read by the real-time callback yet. Before live render integration, publication must become a real-time-safe atomic pointer/value swap at a block boundary.

The real-time callback receives a complete plan. It must not ask UI, route monitors, import services, metadata parsers, or view models for more information.

`AudioGraphAuditSnapshot` remains the temporary shell audit snapshot while existing app call sites still bypass the new plan layer. Later prompts will connect `RenderGraphPlan` to the actual render and output adapters.

## Prompt 7 Planning Behavior

`RenderGraphPlanner` now builds validated plans off the real-time thread. Its current policies are intentionally conservative:

- Desktop reference stereo downmix mirrors the existing Normal Monitor policy: LFE muted by default, equal-power center to left/right, surrounds folded to their side, top center folded equally, and multichannel headroom applied.
- Dante `direct30` maps source channels 1-30 directly to full-range outputs 1-30 and keeps the LFE/sub output silent.
- Dante `direct31` maps source channels 1-30 directly to full-range outputs 1-30 and maps source channel 31 to LFE/sub output 31.
- For non-direct Dante beds, Prompt 7 creates deterministic placeholder matrices inside the immutable plan layer. The current legacy Sonic Sphere renderer is not yet wired into production audio; later prompts can replace those placeholder coefficients with copied immutable renderer coefficients without changing the plan boundary.

## Prompt 8 Pure Render Kernels

Prompt 8 adds deterministic offline render kernels in `AudioCore`:

```text
CanonicalAudioBlock source
-> DesktopMonitorRenderer
-> CanonicalAudioBlock desktop stereo output
```

```text
CanonicalAudioBlock source
-> DanteSonicSphereRenderer
-> CanonicalAudioBlock Dante 31/32-channel output
```

Both renderers are backed by `MatrixRenderKernel`, which applies an immutable N-input to M-output matrix into a preallocated destination block. The process call:

- Performs no sample-rate conversion.
- Performs no file I/O.
- Uses no locks.
- Clears and writes only the preallocated destination block.
- Silences extra destination outputs not addressed by the matrix.
- Rejects channel-count, frame-count, processing-format, and sample-rate mismatches before rendering.

Allocation measurement is not yet instrumented. `RenderKernelAudit` records this explicitly as "not instrumented" while the implementation keeps allocation outside the hot process call by requiring caller-owned destination blocks.

Desktop render policy:

- Reference stereo fold-down comes from `DesktopDownmixPlan`.
- LFE is omitted by default.
- Center folds equal-power to left/right.
- Surrounds and rears fold to their side.
- Top-center channels fold equally.
- Discrete channels alternate left/right deterministically.
- Multichannel sources receive the existing Normal Monitor headroom.
- `desktopMonitorGain` applies only to desktop output.

Dante render policy:

- Dante is rendered from the same canonical source block as desktop, as a sibling output.
- Dante never consumes desktop fold-down.
- `danteOutputGain` applies only to Dante output.
- Outputs 1-30 are full-range Sonic Sphere channels.
- Output 31 is LFE/sub.
- In 32-channel physical plans, channel 32 remains silent.
- `direct30` maps source channels 1-30 bit-exactly to Dante outputs 1-30 and keeps LFE/sub silent.
- `direct31` maps source channels 1-30 to Dante outputs 1-30 and source channel 31 to output 31.

The kernels remain offline/test-only after Prompt 8. Existing live playback continues on the legacy Normal Monitor path until later prompts wire the canonical source bus and output adapters into the running engine.

## Output Adapter Contract

Desktop output adapter:

- Owns only the desktop stereo output path.
- Fails independently from Dante.
- Reports health through snapshots.

Dante output adapter:

- Owns the 31-channel Sonic Sphere production output.
- Requires 30 full-range channels plus 1 LFE/sub.
- Leaves physical channel 32 silent unless explicitly assigned later.
- Fails closed if runtime route validation cannot prove enough output channels at the session sample rate.

Prompt 10 adds the first concrete output adapter architecture in `AudioCore`:

- `AudioOutputAdapter` is the common value-boundary protocol for prepared output routes. It exposes route descriptors, output formats, lifecycle calls, block consumption, and status snapshots. It does not expose live graph or device handles.
- `DesktopOutputAdapter` represents the local stereo confidence output. Desktop failures may mute or fail desktop only.
- `DanteOutputAdapter` represents the Sonic Sphere production output. Dante failures are production-output failures.
- `OfflineDesktopOutputAdapter` validates and consumes desktop stereo render blocks for tests without claiming live device output.
- `OfflineDanteOutputAdapter` validates Dante route capability, consumes 31/32-channel Dante blocks, and enforces silent physical channel 32 when present.
- `DualOutputRenderCoordinator` pulls one source adapter into the canonical source bus, renders desktop and Dante as sibling outputs, and hands each block to its matching output adapter.

Prompt 10 remains validation/offline only. The live dual-device binding is not implemented yet. Status messages must therefore say that the desktop or Dante renderer is validated and that the live output adapter is not yet active. No UI or diagnostic surface may claim Dante audio is leaving the Mac until a real live Dante adapter has been implemented and verified.

Prompt 10 dual-output render flow:

```text
AudioSourceAdapter
-> CanonicalSourceBus
-> DesktopMonitorRenderer
-> DesktopOutputAdapter
```

```text
AudioSourceAdapter
-> CanonicalSourceBus
-> DanteSonicSphereRenderer
-> DanteOutputAdapter
```

Failure isolation rules:

- Desktop route validation or consume failure updates only desktop output status.
- Dante route validation failure blocks preparation.
- Dante consume failure sets production-output-failed status.
- Desktop gain and Dante gain are separate domains in `GainPlan`.
- Route sample-rate mismatch is a validation failure, not a hidden conversion.

## Meter Copy Contract

Metering receives copies from defined copy points:

- Source input after adaptation.
- Desktop post-render, pre-output-gain output.
- Dante post-render, pre-output-gain output.

Metering is lossy. It may drop updates. It must not block or mutate render state.

Prompt 11 adds the first Pure Audio copy-only metering path in `AudioCore`:

- `MeterCopyBus` receives copied source, desktop, and Dante blocks. It owns a bounded queue and drops meter frames when full instead of back-pressuring render.
- `MeterCopiedBlock` stores value copies only: sample arrays, sample rate, layout, copy point, source ID, frame position, and session version. It does not expose graph nodes, output handles, or mutable live buffers.
- `MeterAccumulator` consumes copied blocks off the render path and calculates RMS dBFS, peak dBFS, VU dB, normalized display level, and clipping.
- `PureAudioMeteringService` drains the copy bus, builds `MeterSnapshot` values, and publishes them through `AudioTelemetry.latestMeterSnapshot()`.
- `DualOutputRenderCoordinator` can now copy the input source bus, desktop render bus, and Dante render bus into `MeterCopyBus` during deterministic offline rendering.

Pure Audio meter naming:

- Actual post-render Dante bus meter: `Dante Output Meter`.
- Synthetic or legacy meter-only Sonic Sphere projection: `Sonic Sphere Analysis Meter`.

The current app UI still uses legacy analysis metering for the Sonic Sphere surface, so it must use `Sonic Sphere Analysis Meter`. It must not say `Dante Output Meter` until the meter source is the actual Dante render bus and a real live Dante output adapter has been implemented and verified.

Legacy migration note:

- `Sources/Orbisonic/MeteringService.swift` remains as the legacy Normal Monitor and analysis-meter compatibility service.
- `Sources/AudioCore/MeteringTelemetry.swift` is authoritative for new Pure Audio metering.
- Later prompts must move UI/VU display stores from legacy `ChannelMeterStore` updates to `MeterSnapshot`-derived view models.

## Prompt 12 Integration Gate

Prompt 12 closes the most important current production bypass in the app-facing local-file path:

```text
OrbisonicViewModel local file request
-> AudioFileProbe descriptor
-> LegacyLocalFileProductionGate
-> RouteCapabilityValidator
-> AudioSessionPlanner
-> ProductionLocalAssetGate
-> allow legacy engine commit only when production rules pass
```

When Output 2 Renderer is selected, a local file is treated as a production candidate. It must match the planned Dante session sample rate before the legacy playback engine can stream or commit it. If it does not match, the app returns the explicit managed-import/restart message from the local asset policy.

When Output 2 Renderer is not selected, the current path is labeled as legacy desktop-only Normal Monitor playback. It is not Pure Audio Dante production and must not be represented as such in UI or diagnostics.

Prompt 12 also tightens route planning:

- `AudioSessionPlanner` rejects `feedbackLoopRisk` desktop routes.
- `AudioSessionPlanner` rejects `feedbackLoopRisk` Dante routes.
- BlackHole and Orbisonic loopback outputs remain blocked from production planning.

The live signal path is still:

```text
Legacy OrbisonicEngine Normal Monitor path
```

for current audible playback. The Pure Audio source bus, render plan, render kernels, output adapters, and metering path are implemented as validation/offline architecture and tests. A later prompt must replace the live output execution path with the Pure Audio coordinator and real output adapters before Dante can be described as audible.

## Apple Spatial Headphones Desktop Monitor Branch

Prompt 13 adds `Apple Spatial Headphones` as an optional desktop confidence-monitor mode.

It adds an optional branch under the desktop monitor only:

```text
Desktop Monitor Renderer
-> Reference Stereo Monitor
-> Desktop output adapter
```

or:

```text
Desktop Monitor Renderer
-> Apple Spatial Headphones Monitor
-> Desktop output adapter
```

The Dante path remains a sibling and is unaffected:

```text
Source adapters
-> CanonicalSourceBus
-> immutable RenderGraphPlan
-> DanteSonicSphereRenderer
-> Dante output adapter
```

Control flow for the toggle is:

```text
Output Monitor UI
-> OrbisonicViewModel.setAppleSpatialHeadphonesEnabled(_:)
-> DesktopMonitorMode / DesktopMonitorModeStatus value state
-> AppleSpatialHeadphoneMonitor inside AudioCore
```

The current Prompt 13 integration publishes capability and pending/active status. It does not claim live Dante output, and it does not claim a live Apple spatial desktop graph is active until AudioCore safely rebuilds the desktop monitor branch.
