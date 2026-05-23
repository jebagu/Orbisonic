# Realtime Audio Architecture Standard

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


## 1. Standing rule

Audible sound is owned by a realtime engine. Everything else observes, prepares, configures, validates, logs, visualizes, or trails behind.

The realtime plane is the only plane allowed to affect audible timing.

## 2. Backend neutrality

This standard intentionally does not select a specific audio framework. The callback-driven architecture, Bencina doctrine, and performance gates are primary.

A compliant backend MUST provide:

- a callback or render-block path for audible output;
- a preparation lifecycle before rendering;
- sample-time event scheduling;
- fixed-capacity or otherwise bounded event ingestion;
- preallocated audio buffers or caller-owned buffer views;
- explicit output channel mapping;
- meter snapshot extraction without blocking audio;
- proof that callback-reachable code follows the doctrine.

A backend may be JUCE, native Core Audio, ASIO, JACK, WASAPI, ALSA, PortAudio, iPlug2, CLAP, AU, VST3, a custom C++ engine adapter, or another callback-capable system. The backend may not weaken the rules.

## 3. Three planes

```text
Preparation Plane
  parses, validates, warms, allocates, precomputes, maps, and builds immutable snapshots

Realtime Plane
  owns callback/render block, sample-time scheduling, source rendering, DSP, channel mixing, output writes, panic, and tiny meter extraction

UI / Diagnostic / Telemetry Plane
  observes snapshots, paints UI, writes logs, emits lossy meter frames, and reports performance
```

No behavior may move into the realtime plane merely because it is convenient.

## 4. Source convergence

All sources become timestamped, bounded events before crossing into realtime:

```text
live inputs
MIDI
OSC or network control
plugin host events
automation
sequencer lanes
preset/session data
file playback
hardware controls
future project-specific sources
```

Source-specific parsing, validation, jitter policy, tempo mapping, route lookup, and logging belong before the realtime boundary.

## 5. Realtime callback contract

The callback receives only:

```text
preallocated buffer views
immutable prepared render plan pointer or generation
fixed-capacity event queues
latest-value control slots
precomputed channel maps
precomputed DSP tables
preallocated source/voice/effect state
panic flag or bounded command queue
tiny meter snapshot target
```

The callback MUST NOT receive raw UDP packets, JSON, files, UI messages, route-discovery requests, sampler-loading requests, plugin-scan requests, or log events.

## 6. Output model

Output routing MUST be explicit. A production or user-facing route MUST NOT silently downmix, truncate, duplicate, reorder, or fall back to another route unless the project spec explicitly defines that behavior and the user is told before arming playback.

Route mismatch fails visibly before playback or capture is armed.

## 7. Metering and telemetry model

Meters are extracted from explicitly labeled points, such as final output, channel bus, object/source bus, input tap, or hardware tap.

Telemetry is allowed to be lossy and approximate unless a product-specific spec says otherwise. It MUST NOT delay sound. Latest complete frame wins. Stale backlog is dropped.

## 8. OpenSpec requirement

Every audio-related change MUST be represented in OpenSpec and MUST answer:

```text
Does this touch the realtime plane?
What new code is reachable from the callback?
Does this affect audible timing?
Does this affect output routing?
Does this affect meter source-of-truth or lag?
Does this introduce allocation, locks, waits, logging, file I/O, network I/O, UI calls, JSON parsing, OSC parsing, MIDI-file parsing, route discovery, or unaudited framework/OS calls near callback code?
What is the worst-case loop/event bound per block?
What is the queue-full policy?
Which performance gate proves the change is safe?
```

## 9. Merge gate

A callback-adjacent change is not accepted until:

- callback reachability has been reviewed;
- allocation and blocking-lock instrumentation reports zero in callback paths;
- p95 and p99 callback duration are reported under stress;
- telemetry and UI are active during the stress test;
- output route integrity is preserved where relevant;
- failure of any doctrine rule blocks the change.

## 10. Project specialization

Each project should create a product profile under `docs/project/` and specs under `openspec/specs/<project-feature>/`.

Specialization may define:

- audio backend choice;
- plugin or standalone shape;
- sample rates and block sizes;
- channel layout and routing rules;
- event types;
- control schema;
- session or preset formats;
- telemetry formats;
- product-specific stress scenes.

Specialization may not weaken the callback doctrine.
