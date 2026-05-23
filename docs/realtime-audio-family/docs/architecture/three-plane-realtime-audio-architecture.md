# Three-Plane Realtime Audio Architecture

## Bencina Realtime Callback Doctrine

Status: mandatory family standard
Revision: 2026-05-23-family-standard
Source: Ross Bencina, "Real-time audio programming 101: time waits for nothing"
Use in this package: project paraphrase, elevated to engineering law

This doctrine applies to every audio callback, render block, host `processBlock`, device callback, scheduler drain, panic path, meter extraction path, and every function reachable from those paths.

**Rule zero:** if the bounded worst-case execution time is not known, the operation is not allowed in the realtime callback.

Forbidden inside the callback or callback-reachable code:

1. No heap allocation, deallocation, resizing, or hidden allocator use.
2. No mutex, blocking lock, semaphore wait, condition variable wait, thread join, sleep, spin-until-ready loop, or scheduler-dependent wait.
3. No file, disk, network, console, logging, printf-style output, GUI, runtime dispatch, JSON parsing, OSC parsing, MIDI-file parsing, preset loading, sample loading, route discovery, or device enumeration.
4. No OS or framework call unless the exact call path has been audited as bounded, nonblocking, allocation-free, and callback-safe.
5. No algorithm with unbounded or poor worst-case timing. Average-case speed is not a defense.
6. No call into code that may break any rule above.
7. No call into code that the project cannot audit or does not trust to follow these rules.

Required inside or feeding the callback:

1. Use bounded worst-case algorithms, preferably O(1) for callback work.
2. Amortize bursty computation outside realtime or across many samples so no single callback takes a surprise hit.
3. Preallocate and precompute in the preparation plane.
4. Use fixed-capacity, wait-free, callback-facing queues or latest-value snapshots with explicit overflow policy.
5. Prefer audio-callback-only state. When crossing planes, use immutable prepared snapshots, atomics, or bounded SPSC exchange patterns.
6. Treat "lock-free" as insufficient unless the callback operation is also bounded and wait-free for the actual use.
7. Prove compliance with code review, instrumentation, and performance gates before merging any callback-adjacent change.

No exception is allowed unless a project ADR names the exact operation, proves bounded worst-case behavior, adds a regression gate, and is accepted before implementation.


## Overview

Every family app is organized into three planes:

```text
Control / UI / Telemetry Plane
  user interaction, logs, diagnostics, network emission, displays, developer tools

Preparation Plane
  parsing, validation, allocation, file loading, preset/session loading, graph construction, route validation, table building

Realtime Plane
  audio callback, sample scheduling, DSP, mixing, buffer writes, panic, tiny meter snapshot
```

## Control / UI / Telemetry Plane

This plane may allocate, log, render UI, parse display models, write files, send network telemetry, inspect devices, and present diagnostics. It must not be required for the callback to complete.

It consumes lossy snapshots and may lag behind audio.

## Preparation Plane

This plane converts arbitrary inputs into realtime-safe state. It owns:

- file parsing;
- network message parsing;
- preset/session validation;
- device discovery;
- route validation;
- render-plan construction;
- graph construction outside realtime;
- sample and table loading;
- memory allocation;
- queue setup;
- immutable snapshot publication.

## Realtime Plane

This plane owns audible timing. It accepts only prepared, bounded, fixed-capacity, callback-safe data.

Allowed callback work:

- read preallocated buffer views;
- drain bounded event queues up to a fixed limit;
- read atomic/latest-value controls;
- read immutable prepared snapshots;
- render sources, effects, and channels;
- write output buffers;
- update tiny fixed-size meter snapshots;
- handle panic with bounded work.

Forbidden callback work is defined by the doctrine and cannot be overridden by project convenience.

## Plane-crossing rule

Crossing from preparation/control into realtime requires one of:

- immutable prepared snapshot;
- fixed-capacity event queue;
- latest-value atomic slot;
- preallocated table selected by generation;
- bounded command packet.

No raw file, raw network packet, UI message, route query, or parser object crosses into realtime.
