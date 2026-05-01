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
-> AudioControl API
-> CommandQueue
-> GraphPlanner
-> ContractValidator
-> immutable RenderGraphPlan
-> atomic plan swap at block boundary
-> real-time render callback
```

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

The render graph plan is immutable once validated. It describes:

- Session sample rate.
- Source layout.
- Desktop render path.
- Dante render path.
- Output route IDs.
- Output channel counts.
- Dante logical channel map.
- Meter copy points.
- Conversion ledger reference.

The real-time callback receives a complete plan. It must not ask UI, route monitors, import services, metadata parsers, or view models for more information.

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
