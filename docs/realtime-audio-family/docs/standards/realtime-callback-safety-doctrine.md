# Realtime Callback Safety Doctrine

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


## Scope boundary

The doctrine applies to:

- audio device callbacks and render blocks;
- plugin host callbacks such as process callbacks;
- standalone engine render functions;
- Core Audio, ASIO, JACK, WASAPI, ALSA, PortAudio, JUCE, iPlug2, CLAP, AU, VST3, or any future backend adapter while it is on the audio thread;
- event dequeue, sample-time scheduling, source rendering, DSP processing, spatial or channel mixing, output buffer writes, meter extraction, panic, and recovery;
- every helper called synchronously by those paths.

The doctrine does not forbid expensive work. It moves expensive work to the preparation or control plane, where it can be allocated, parsed, logged, validated, retried, and measured without risking the audio deadline.

## Banned by default

The following are banned in callback-reachable code unless a later ADR proves the exact usage safe:

- `new`, `delete`, `malloc`, `free`, `realloc`, allocator-backed container growth, hidden allocation through strings, vectors, maps, function wrappers, exceptions, or formatting;
- mutexes, critical sections, semaphores, condition variables, blocking atomics, thread joins, sleeps, waits, polling loops that wait for another thread, and unbounded compare-exchange retry loops;
- file reads or writes, network sends or receives, route or device discovery, plugin scanning, sample loading, database access, console output, logging, telemetry emission, JSON parsing, OSC parsing, MIDI-file parsing, and GUI or message-thread posting;
- framework calls that are convenient but not proven bounded, nonblocking, and allocation-free;
- dynamic graph mutation, dynamic channel-map mutation, sampler construction, route validation, or preset loading.

## Required transfer patterns

Cross-plane transfer MUST use one of these patterns:

- immutable prepared snapshot swapped between blocks;
- fixed-capacity SPSC queue with bounded push/pop and explicit overflow behavior;
- latest-value atomic slot for coalescible controls and meter snapshots;
- preallocated array or table selected by index or generation counter;
- lossy telemetry queue where dropping stale data is valid and audio never waits.

Every queue MUST define what happens when full. It is not enough to say "lock-free." The callback operation must have a bounded number of instructions for the worst case it can encounter.

## Review checklist

Every callback-adjacent change MUST answer:

1. What code is newly reachable from the callback?
2. Can any reachable function allocate, lock, wait, log, parse, call UI, call the OS, or call unaudited framework code?
3. What is the worst-case event count and loop bound for a block?
4. What is the queue-full policy?
5. What work was moved to preparation?
6. What instrumentation proves callback allocations, blocking locks, and missed deadlines are zero under the standard stress scene?
7. What test would fail if this rule is violated later?

## Enforcement

A change is not complete until:

- code review signs off on callback reachability;
- tests or instrumentation prove zero callback allocations and zero callback blocking locks;
- p95 and p99 callback duration are reported against the block duration;
- UI, telemetry, diagnostics, and routing views are active during the stress test;
- failures are recorded as release blockers, not warnings.
