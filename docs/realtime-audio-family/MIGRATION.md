# Brownfield Migration Guide

Status: reusable guide
Revision: 2026-05-23-family-standard

Use this when merging the family standard into an existing realtime audio repository.

## 1. Establish inheritance

Add a project ADR stating:

```text
This project inherits the Realtime Audio Family Standards Package. The project may add stricter product-specific constraints, but it may not weaken the callback doctrine, three-plane architecture, or performance gates.
```

## 2. Identify callback entry points

List every callback entry point:

- standalone device callback;
- plugin process callback;
- offline render callback;
- engine render function;
- audio server process callback;
- adapter callback from a framework.

For each entry point, map the functions it calls synchronously.

## 3. Classify unsafe work

Search callback-reachable code for:

- allocation and deallocation;
- container growth;
- locks, waits, sleeps, joins, condition variables, and unbounded CAS retry loops;
- logging, formatting, console output, and diagnostics;
- file, disk, network, database, plugin scan, and device discovery calls;
- JSON, OSC, MIDI file, preset, and sample parsing;
- UI and message-thread posting;
- dynamic graph mutation;
- framework calls that are not audited.

## 4. Move unsafe work

Move unsafe work to the preparation plane or control plane. The callback should receive only:

- immutable prepared snapshots;
- preallocated buffer views;
- fixed-capacity queues;
- atomic/latest-value control slots;
- precomputed routing and render tables;
- fixed-capacity audio state.

## 5. Add overload policy

Every queue and event path must define what happens when full. Examples:

- note-off and panic events get priority;
- metering and UI updates drop stale frames;
- coalescible controls use latest-value wins;
- noncritical diagnostic events are discarded;
- critical scheduling overload is reported outside realtime after audio continues.

## 6. Install gates

Add tests for:

- zero callback allocations;
- zero callback blocking locks;
- bounded event burst handling;
- variable block sizes up to configured maximum;
- route mismatch before arming playback;
- p95 and p99 callback duration under stress;
- telemetry overload without audio backpressure.

## 7. Do not claim compliance early

A brownfield project is not compliant until callback reachability, unsafe work removal, overload policy, and performance gates are all documented.
