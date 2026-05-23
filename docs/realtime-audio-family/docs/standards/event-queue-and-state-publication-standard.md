# Event Queue and State Publication Standard

Status: mandatory for cross-plane transfer
Revision: 2026-05-23-family-standard

## Purpose

This standard defines how events, controls, render plans, meters, and diagnostic state cross between preparation, realtime, and telemetry planes.

## Default transfer patterns

Use one of these patterns:

1. Fixed-capacity SPSC queue for ordered event streams.
2. Latest-value atomic slot for coalescible controls.
3. Immutable prepared snapshot swapped by atomic pointer or generation index.
4. Preallocated ring of snapshots with explicit ownership state.
5. Lossy telemetry queue where stale data is dropped.

## Queue requirements

Every queue must define:

- producer and consumer count;
- capacity;
- maximum events drained per callback;
- event priority policy;
- full behavior;
- empty behavior;
- ordering guarantee;
- memory ordering or synchronization model;
- instrumentation counters.

A queue is not compliant merely because it is lock-free. The callback-side operation must be bounded and wait-free for the exact use.

## Full policies

Allowed full policies include:

- drop newest noncritical telemetry;
- drop oldest telemetry;
- coalesce by key and keep latest;
- preserve note-off, panic, transport-stop, and safety-critical events ahead of note-on or cosmetic events;
- set an overload flag and continue audio;
- reject arming before playback starts.

Forbidden full policies:

- wait for space;
- allocate more space;
- lock and retry;
- call the UI;
- log synchronously;
- parse or rebuild state;
- block the callback until another thread catches up.

## Snapshot requirements

Immutable snapshots must be fully prepared before publication. The callback may read a snapshot by pointer, index, or generation, but must not trigger construction, validation, deallocation, or reclamation.

Reclamation must be deferred until no realtime reader can hold the old snapshot. Acceptable patterns include epoch reclamation outside realtime, fixed snapshot rings, or zombie lists drained outside realtime.

## Meter publication

Meter snapshots must be tiny, fixed-size, and nonblocking. Telemetry publication outside realtime may convert snapshots to larger frames, JSON, UI models, logs, or network packets.

Audio never waits for telemetry.
