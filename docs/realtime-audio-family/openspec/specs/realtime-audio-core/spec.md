# Spec: realtime-audio-core

Status: family baseline
Revision: 2026-05-23-family-standard

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



## Purpose

The realtime audio core renders audible audio before deadline and is isolated from framework, UI, logging, parsing, and device discovery behavior.

## Requirements

### Requirement: Prepare/process split

The system SHALL expose a preparation lifecycle that may allocate and a realtime process lifecycle that SHALL NOT allocate, lock, wait, log, parse, perform I/O, call UI, or call unaudited framework/OS functions.

#### Scenario: Core prepared before audio starts

- Given the project has a selected sample rate, max block size, channel count, and event capacity
- When the engine is prepared
- Then all buffers, queues, tables, route maps, source state, meter snapshots, and panic state needed by the callback are allocated or initialized before audio starts

### Requirement: Variable callback frame count

The realtime core SHALL process any frame count from zero through the configured maximum without allocation or route mutation.

### Requirement: Bounded event drain

The realtime core SHALL drain no more than a configured maximum number of events per block and SHALL apply explicit overload policy when more events are available.

### Requirement: Framework-neutral API

The realtime core SHOULD use project-owned C++ views or POD-like types rather than backend framework types.

### Requirement: Panic path

The realtime core SHALL provide a bounded panic or silence path that can execute from the callback without allocation, locks, waits, logging, I/O, UI, or parsing.
