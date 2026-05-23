# 0004: Callback Safety Performance Gates

Status: Slice 8 installed; compliance blocked by documented gaps

Date: 2026-05-23

## Scope

This report records the project-specific callback stress scene, starting performance budgets, installed instrumentation hooks, and current gate result for Task 020 Slice 8. It is evidence plumbing and a current-state report, not a final realtime compliance verdict.

The governing standard is `docs/realtime-audio-family/docs/standards/performance-gate-standard.md`.

## Standard Stress Scene

- Name: Orbisonic maximum configured realtime callback stress
- Sample rate: 48000 Hz
- Block size range: 128-8192 frames
- Input channels: 64 maximum configured source channels
- Output channels: 31 Sonic Sphere logical outputs
- Active sources/effects: maximum configured live source channels with Sonic Sphere analysis meters active
- Event burst: route, meter, telemetry, and stop/panic events must be coalesced or dropped outside audio
- UI active: yes
- Meters active: yes
- Telemetry active: yes
- Route validation before arming: yes
- Panic/stop behavior: stop transport, publish failure state, and keep callbacks bounded without retrying inside audio
- Duration target: 60 seconds for a real qualification run

## Budgets

Orbisonic uses the family starting budget until a stricter project-specific budget is accepted:

- p95 callback duration <= 50 percent of minimum observed block duration
- p99 callback duration <= 70 percent of minimum observed block duration
- max observed duration <= 90 percent of minimum observed block duration during qualification
- missed deadlines = 0
- callback allocations = 0
- callback deallocations = 0
- callback blocking locks = 0
- callback waits/sleeps = 0
- route mismatch must be blocked before arming or converted to bounded silence/status without graph mutation inside the callback
- telemetry and meter overload must drop or coalesce without blocking audio

## Installed Harness

- Source hook: `Sources/Orbisonic/RealtimeCallbackSafetyInstrumentation.swift`
- Realtime atomic max helper: `Sources/Orbisonic/RealtimeAtomicPrimitives.swift`
- Live pipe hooks: `Sources/Orbisonic/LiveAudioBridge.swift`
- Focused tests: `Tests/OrbisonicTests/RealtimeCallbackSafetyInstrumentationTests.swift`

Local stress command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter RealtimeCallbackSafetyInstrumentationTests
```

The installed probe records callback duration samples into preallocated atomic slots, computes p50/p95/p99/max off the callback path, and exposes explicit counters for deadline misses, allocations, deallocations, blocking locks, waits/sleeps, max events drained, event drops/coalesces, telemetry drops, meter drops/coalesces, and route mismatch blocks.

The current hook counters are not malloc/free or OS lock interposition. They are explicit callback hooks plus static source guards. That gap must remain visible until a later slice adds host-level allocation and lock/wait instrumentation or replaces the remaining callback allocation sites.

## Synthetic Harness Report

The deterministic synthetic stress report exercises the standard scene shape and verifies the reporting surface:

- p50 callback duration: 48000 ns
- p95 callback duration: 56000 ns
- p99 callback duration: 56000 ns
- max callback duration: 56000 ns
- deadline misses: 0
- callback allocations: 0
- callback deallocations: 0
- callback blocking locks: 0
- callback waits/sleeps: 0
- max events drained per block: 16
- event drops/coalesces: 2
- telemetry drops: 1
- meter drops/coalesces: 3
- p95 CPU load against 128-frame block at 48 kHz: about 2.10 percent
- denormal handling: not verified
- route mismatch behavior: blocked before arming
- gate result: warning

Warning reasons:

- malloc/free interposition is not installed; allocation counts cover explicit callback hooks only.
- blocking lock and wait/sleep counts cover explicit hooks plus static source guards only.
- denormal handling is not verified.

## Live Pipe Hook Report

The focused live matrix render instrumentation test records the current known allocation gap:

- Path: `LiveAudioPipe.render(matrix:audioBufferList:frameCount:)`
- Callback samples: 1
- Callback allocation count: 3 explicit current scratch-array allocations for a 2-input matrix render
- Gate result: blocked
- Blocking reason: callback allocations are nonzero

This is not a new allocation introduced by Slice 8. Slice 8 only makes the existing documented live matrix scratch allocation measurable through a gate. The app cannot claim callback compliance while this report remains blocked.

## Current Verdict

Callback-adjacent evidence is improved but compliance remains blocked.

## Verification Run

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter RealtimeCallbackSafetyInstrumentationTests`: passed, 4 tests.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter LiveAudioBridgeTests`: passed, 8 tests.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter PureAudioArchitectureBoundaryTests`: passed, 13 tests.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: passed, 676 tests.
- `git diff --check`: passed.
- `./scripts/refresh-orbisonic-app.sh`: passed; repo-root `Orbisonic.app` refreshed.

Passing evidence:

- Named stress scene exists.
- Named budgets exist.
- Metrics surface exists for all family-required metric names.
- Route mismatch can be counted as blocked rather than accepted.
- Telemetry and meter drop/coalesce counters exist at the report layer.
- Focused tests prove the report can warn or block clearly.

Blocking or open evidence:

- `LiveAudioPipe.render(matrix:audioBufferList:frameCount:)` still allocates scratch arrays in a callback-intended path.
- malloc/free interposition is not installed.
- blocking-lock and wait/sleep counters are explicit hooks plus static source guards, not whole-process instrumentation.
- denormal handling is not verified.
- The standard scene has not been run for 60 seconds against real Core Audio callback timing, Sonic Sphere / Dante hardware, live loopback devices, or active GUI rendering.

## Required Follow-Up

- Remove or preallocate live matrix scratch storage before direct matrix render can pass allocation gates.
- Add host-level allocation/deallocation evidence or a stricter source-level proof for every callback-reachable path.
- Add lock/wait/sleep instrumentation beyond explicit hooks where practical.
- Verify or set denormal handling policy.
- Run the 60-second stress scene in the real app environment and record p50/p95/p99/max, deadline misses, allocations, locks, waits, telemetry drops, and route mismatch behavior.
