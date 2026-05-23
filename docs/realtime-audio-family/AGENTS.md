# Agent and Developer Rules for Realtime Audio Projects

Status: mandatory
Revision: 2026-05-23-family-standard

This file is for coding agents, reviewers, contributors, and future maintainers. Read it before editing anything that could touch audio timing.

## First principle

Do not optimize your way out of a bad realtime boundary. Move unsafe work out of callback-reachable code.

## Always check callback reachability

Before editing code, decide whether the edit is callback-adjacent. It is callback-adjacent if it touches any of these:

- audio device callback or host processing callback;
- realtime core process function;
- event dequeue, event scheduling, sequencer drain, or transport tick;
- source, voice, synth, sampler, effect, spatial, mixing, output, or channel write code;
- control parameter reads used by audio;
- immutable render-plan swaps;
- routing tables used by audio;
- panic/all-notes-off/recovery path;
- meter extraction or realtime snapshot publication;
- adapter code between a framework and the realtime core.

If callback-adjacent, apply the doctrine below.

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


## Required response when changing callback-adjacent code

Any implementation note, pull request summary, or coding-agent final answer MUST include:

```text
Callback impact:
New callback-reachable functions:
Allocation risk:
Lock/wait risk:
I/O/logging/UI risk:
Worst-case loop bounds:
Queue-full or overload policy:
Tests or instrumentation run:
```

## Banned shortcuts

Do not use any of these arguments to justify unsafe callback code:

- "It is only a tiny allocation."
- "The lock is almost never contended."
- "The file is already cached."
- "The network send is UDP."
- "The logger is fast."
- "The UI post is async."
- "The vector usually has enough capacity."
- "The framework probably handles it."
- "The host will not call us with that block size."
- "The event burst is unlikely."

## Safe default design

Use this default unless a project spec says otherwise:

```text
UI / Control / Telemetry Plane
  can allocate, log, render UI, parse files, parse network messages, inspect devices, and recover from failures

Preparation Plane
  validates inputs, computes render plans, allocates memory, loads presets, opens files, builds tables, and creates immutable snapshots

Realtime Plane
  receives preallocated buffer views, bounded event queues, atomic/latest-value controls, immutable prepared snapshots, and writes audio before deadline
```

## When unsure

Do not ask whether a callback violation is acceptable. Treat it as unacceptable and move the work out of realtime.
