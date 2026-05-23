# Realtime Audio Core Contract

Status: mandatory baseline contract
Revision: 2026-05-23-family-standard

## Purpose

The realtime audio core owns audible timing. It is a framework-neutral component called by a backend adapter.

## Lifecycle

```text
construct          no heavy work required
prepare(config)   allocate, validate, precompute, warm caches, create fixed-capacity state
reset()           clear realtime state without allocation
process(ctx)      render audio before deadline
release()         deallocate outside realtime
```

## Inputs to process

The process function may receive:

- audio input buffer views;
- audio output buffer views;
- sample rate and frame count;
- stream time or host time;
- fixed-capacity event block;
- latest-value controls;
- immutable prepared render plan;
- precomputed route map;
- panic flag or command.

## Outputs from process

The process function may produce:

- audio output buffers;
- fixed-size meter snapshot;
- bounded overload counters;
- status flags for non-realtime reporting.

## Prohibitions

The process function and every function reachable from it must follow the Bencina Realtime Callback Doctrine.

## Acceptance criteria

- No framework types are required by the core public API unless a project ADR accepts that dependency.
- The core can be unit-tested without opening an audio device.
- The core handles variable frame counts up to the prepared maximum.
- The core has explicit behavior for event overload.
- The core publishes meters without blocking.
- The core can panic or silence output with bounded work.
