# 0005: Realtime Family Compliance Final Audit

Status: Task 020 Slice 10 complete; compliance not yet achieved

Date: 2026-05-23

## Scope

This audit is the final Task 020 Slice 10 review of Orbisonic against the adopted Realtime Audio Family Standards Package after the realtime safety and orbital VU work package.

It reviews the local standards adoption, callback reachability and performance evidence, orbital VU data source, source-label truth, and remaining manual/hardware gates. It is not a release-ready claim and it is not a Sonic Sphere / Dante hardware-verification record.

Governing standards and evidence:

- `docs/realtime-audio-family/`
- `docs/decisions/0013-realtime-audio-family-standards-inheritance.md`
- `docs/project/orbisonic-realtime-audio-profile.md`
- `docs/audits/0003-callback-reachability-audit.md`
- `docs/audits/0004-callback-safety-performance-gates.md`
- `docs/system-flows.md`
- `docs/test-strategy.md`
- `docs/release-verification.md`

## Final Verdict

Orbisonic is brownfield-in-progress against the Realtime Audio Family Standards. It is not yet compliant.

Orbisonic can honestly claim:

- The Realtime Audio Family Standards Package is adopted locally.
- Project inheritance is documented.
- Callback entry points and callback-intended paths are mapped.
- The most direct HAL callback buffer allocation/deallocation has been removed.
- The live ring-buffer transfer path no longer uses callback-facing `NSLock`.
- Legacy meter ingress now publishes bounded raw meter values into fixed realtime state.
- Callback safety instrumentation and a project-specific stress scene exist.
- The active Renderer tab orbital VU is fed by value snapshots and uses truthful analysis/output labels in automated coverage.

Orbisonic cannot honestly claim:

- Full realtime callback compliance.
- Zero callback allocations across every callback-intended path.
- Whole-process or host-level proof of zero malloc/free, blocking locks, waits, or sleeps.
- Denormal handling compliance.
- A real 60-second standard stress run with active app GUI, live callback timing, telemetry, meters, and route events.
- Physical Sonic Sphere / Dante output verification.
- `Dante Output Meter` coverage for the active UI unless actual post-render Dante/output bus metering is implemented and manually verified.
- Release readiness.

## Audit Question Results

| Question | Result | Evidence |
| --- | --- | --- |
| Are standards adopted locally? | Pass | `docs/realtime-audio-family/` is present and mapped in project control docs. |
| Is inheritance documented? | Pass | `docs/decisions/0013-realtime-audio-family-standards-inheritance.md` and `docs/project/orbisonic-realtime-audio-profile.md` define Orbisonic inheritance and brownfield exceptions. |
| Are callback entry points mapped? | Pass | `docs/audits/0003-callback-reachability-audit.md` maps HAL input, AVAudioSourceNode, live matrix render, monitor tap, diagnostic tone nodes, transport callbacks, MeterCopyBus, future AudioCore callback-intended paths, and orbital VU non-reachability. |
| Are callback allocations zero? | Blocked | `docs/audits/0004-callback-safety-performance-gates.md` records explicit live matrix scratch allocation in `LiveAudioPipe.render(matrix:audioBufferList:frameCount:)`. Host-level malloc/free interposition is also missing. |
| Are callback blocking locks zero? | Not proven | Explicit hook counts and static guards exist, but host-level lock interposition is missing. `docs/audits/0003-callback-reachability-audit.md` also keeps `MeterCopyBus.submit` out of any realtime claim because it uses `NSLock.try` and appends/copies data. |
| Are callback waits/sleeps zero? | Not proven | Explicit hook counts exist, but host-level wait/sleep interposition is missing. |
| Are p95/p99/max durations inside budget? | Not qualified | The synthetic harness reports within budget, but the real 60-second standard scene has not been run against live app callback timing and active GUI/meter/telemetry load. |
| Are deadline misses zero in the standard stress scene? | Not qualified | Synthetic report shows zero deadline misses; the real 60-second standard scene has not been run. |
| Do meter/telemetry overloads drop or coalesce without blocking audio? | Partial | Report-layer counters and focused tests exist for drop/coalesce behavior, but real stress evidence under app load is still missing. |
| Are route mismatches visible before arming? | Pass for deterministic evidence | Deterministic tests and callback report counters cover route mismatch blocks. Hardware route behavior still belongs in release verification. |
| Is the orbital VU view fed by real snapshots only? | Pass | `OrbitalVUMeterModel` consumes value snapshots only, and UI/source tests cover the active Renderer tab wiring. |
| Are labels truthful about analysis versus actual output? | Pass for automated source coverage, manual visual check still required | Automated tests cover `Sonic Sphere Analysis Meter` and restrict `Dante Output Meter` to explicit actual-output state. Operator visual verification remains manual. |

## Remaining Exceptions And Blockers

These exceptions must stay visible until fixed or superseded by a later ADR/audit:

- `LiveAudioPipe.render(matrix:audioBufferList:frameCount:)` still records callback scratch allocation.
- Host-level or whole-path allocation/deallocation evidence is missing.
- Host-level blocking lock and wait/sleep evidence is missing.
- Denormal handling policy is not verified.
- The real 60-second standard stress scene has not been run.
- `MeterCopyBus.submit` is not realtime-safe and must stay outside realtime callback claims unless refactored or proven safe.
- The live source-node closure still has mutable engine-state reachability called out in the reachability audit and needs stricter callback-safe state proof before final compliance.
- The active Renderer tab orbital VU still needs manual visual confirmation before it is treated as operator-verified UI behavior.
- Sonic Sphere / Dante output, Roon, Aux, Spotify, microphone permission, signing, notarization, and installer behavior remain release/manual gates.

## Required Next Work

1. Remove or preallocate live matrix render scratch storage.
2. Add host-level allocation/deallocation instrumentation or stricter source-level proof for every callback-reachable path.
3. Add blocking-lock and wait/sleep instrumentation beyond explicit hooks where practical.
4. Verify or set denormal handling policy.
5. Run the 60-second standard stress scene in the real app environment and record p50, p95, p99, max duration, deadline misses, allocations, locks, waits, telemetry drops, meter drops, and route mismatch behavior.
6. Keep `MeterCopyBus` out of realtime use or refactor it into a bounded nonblocking publication path.
7. Manually verify active Renderer tab orbital VU visuals through LaunchServices.
8. Complete release verification for live loopback sources, Sonic Sphere / Dante, installer execution, signing/notarization, microphone permission, and monitor listening.

## Verification

Slice 10 verification:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: passed, 676 tests, 0 failures.
- `git diff --check`: passed.

Hardware/service checks were not run as part of this audit. They remain blockers, not passing evidence.
