# Package Rules

Status: mandatory when this package is present
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


## Family-level rules

1. The realtime audio plane is sacred. No feature, deadline, demo, UI request, convenience abstraction, or product-specific contract may weaken it.
2. Every project that adopts this package inherits the doctrine and architecture standard by default.
3. Product-specific specs may be stricter. They may not be looser.
4. Any code change that touches audio callback entry points, callback-reachable functions, event queues, control snapshots, routing, scheduling, meters, panic, device I/O, or adapter boundaries is callback-adjacent.
5. Callback-adjacent changes require a callback impact report, a reachability review, and performance gate evidence.
6. A framework wrapper is not a realtime guarantee. JUCE, Core Audio, ASIO, JACK, WASAPI, ALSA, PortAudio, iPlug2, CLAP, AU, VST3, or any other backend must still prove callback safety.
7. A lock-free data structure is not automatically safe. The callback operation must be bounded and wait-free for the actual use.
8. Telemetry, logging, meters, diagnostics, UI, route panels, and developer tooling must never backpressure audio.
9. An exception requires an ADR before implementation, not after a glitch is discovered.
10. When a rule conflicts with convenience, the rule wins.

## Merge behavior

When this package is merged into a project:

- keep this file at repo root when possible;
- keep `AGENTS.md` at repo root when possible;
- keep `docs/standards/realtime-callback-safety-doctrine.md` unchanged except for revision metadata;
- add project-specific documents under `docs/project/` or `openspec/specs/<project-feature>/`;
- do not edit the family standard to encode one product's hardware, channel count, preset type, network protocol, or UI.

## Required language in project docs

Every project architecture doc that touches audio MUST include this statement near the top:

```text
This project inherits the Realtime Audio Family Standards Package. The Bencina Realtime Callback Doctrine is mandatory for every callback and every callback-reachable function. Project-specific requirements may add stricter rules but may not weaken the family standard.
```
