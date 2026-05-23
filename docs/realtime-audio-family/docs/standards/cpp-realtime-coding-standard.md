# C++ Realtime Coding Standard

Status: mandatory for callback-reachable C++
Revision: 2026-05-23-family-standard

## Scope

This standard applies to C++ code that is called by, called from, or reachable through a realtime audio callback.

## Allowed default types

Callback-reachable code should prefer:

- trivially copyable structs;
- fixed-size arrays;
- preallocated spans or pointer plus length views;
- enum-backed event types;
- plain old data command packets;
- atomics for simple latest-value state;
- generation-indexed immutable snapshots;
- fixed-capacity containers whose worst-case operations are known.

## Banned default types and patterns

The following are banned in callback-reachable code unless an ADR proves the exact usage safe:

- allocator-backed growth from `std::vector`, `std::string`, `std::map`, `std::unordered_map`, `std::function`, `std::any`, `std::variant` with allocating alternatives, streams, formatters, exceptions, and RTTI-heavy dispatch;
- `new`, `delete`, `malloc`, `free`, `realloc`, shared pointer control block creation, and weak pointer locking;
- `std::mutex`, `std::recursive_mutex`, `std::shared_mutex`, condition variables, futures, promises, semaphores, latches, barriers, joins, sleeps, and waits;
- unbounded retry loops around compare-exchange;
- filesystem, networking, logging, console output, environment queries, plugin scanning, device enumeration, and UI calls.

## Prepare/process split

Every realtime component MUST have a prepare/process split.

```cpp
struct PreparedConfig final {
    int sampleRate;
    int maxBlockFrames;
    int maxInputChannels;
    int maxOutputChannels;
    int maxEventsPerBlock;
};

class RealtimeProcessor {
public:
    void prepare(const PreparedConfig& config); // may allocate, not realtime
    void reset() noexcept;                      // no allocation after prepare
    void process(AudioBlockView in,
                 AudioBlockView out,
                 EventBlockView events,
                 int numFrames) noexcept;       // realtime
};
```

The `process` function MUST NOT allocate, lock, wait, log, parse, validate routes, create graphs, discover devices, load presets, or call UI.

## Variable block size

The callback must handle variable block sizes up to the configured maximum. A backend may request a preferred block size, but the core must not rely on the host or device always honoring it.

Internal fixed-chunk processing is allowed only when the chunk buffer is preallocated and the remainder path is bounded.

## Denormals

Every project must define its denormal policy. Acceptable patterns include platform denormal flush modes, scoped no-denormal guards proven callback-safe, or DSP algorithms designed to avoid denormal generation.

## Error handling

Callback-reachable code MUST NOT throw exceptions.

Use bounded status flags, counters, atomics, or preallocated diagnostic snapshots. Report outside realtime.

## Debug builds

Debug-only checks may exist only if they preserve callback safety or are compiled out of callback-reachable code. A debug log in the callback is still forbidden.

## Required code review evidence

For every callback-adjacent C++ change, reviewers must see:

- the new callback-reachability map;
- allocation analysis;
- lock/wait analysis;
- worst-case loop bounds;
- queue-full behavior;
- performance gate result.
