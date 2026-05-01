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
-> MeteringService
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

## Meter Copy Contract

Metering receives copies from defined copy points:

- Source input after adaptation.
- Desktop render output.
- Dante render output.

Metering is lossy. It may drop updates. It must not block or mutate render state.
