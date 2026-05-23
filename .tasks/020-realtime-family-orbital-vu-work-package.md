# Task 020: Realtime Family Compliance And Orbital Multichannel VU

## Status

planned

## Purpose

Bring Orbisonic into alignment with the shared Realtime Audio Family Standards while adding a real multichannel VU output path into the orbital Sonic Sphere view.

This is a work package for sequential Codex implementation. Do not implement all slices at once. Each slice is intended to be a bounded prompt-sized change with its own verification, documentation update, and final summary.

## Product Goal

The operator should be able to see real multichannel output energy in the orbital Sonic Sphere view without compromising realtime audio safety. The orbital view should show channel activity, hot channels, and clipping using the same source-of-truth rules as the VU tab:

- Input meter means captured input signal.
- Monitor meter means desktop/normal monitor signal.
- Sonic Sphere Analysis Meter means synthetic or analysis projection.
- Dante Output Meter means actual post-render Dante/output bus only after live Dante output exists and is verified.

The implementation must not fake signal, hide silence, create synthetic activity, silently change routing, or label analysis meters as physical output.

## Standards Baseline

Read before starting any slice:

```text
AGENTS.md
README.md
Package.swift
docs/status.md
docs/architecture.md
docs/contracts.md
docs/system-flows.md
docs/test-strategy.md
docs/implementation-map.md
docs/PureAudio/AUDIO_BOUNDARY_RULES.md
docs/PureAudio/SYSTEM_AUDIO_FLOW.md
docs/PureAudio/PURE_AUDIO_BRANCH_2_STATUS.md
../All projects assets/realtime-audio-family-standards/README.md
../All projects assets/realtime-audio-family-standards/PACKAGE-RULES.md
../All projects assets/realtime-audio-family-standards/MIGRATION.md
../All projects assets/realtime-audio-family-standards/docs/standards/realtime-callback-safety-doctrine.md
../All projects assets/realtime-audio-family-standards/docs/standards/realtime-audio-architecture-standard.md
../All projects assets/realtime-audio-family-standards/docs/standards/event-queue-and-state-publication-standard.md
../All projects assets/realtime-audio-family-standards/docs/standards/performance-gate-standard.md
```

## Current Audit Summary

Orbisonic already has useful architecture pieces:

- `AudioContracts`, `AudioImport`, and `AudioCore` are separated targets.
- `AudioCore` has session planning, source adapters, immutable render plans, offline render kernels, output adapters, and copy-only metering concepts.
- Existing docs are honest that live playback still runs through `OrbisonicEngine` and that live Dante output is not complete.
- Route, sample-rate, channel-count, source-isolation, and all-zero live input failures are already treated as visible diagnostics.

Orbisonic is not yet compliant with the shared family standard because:

- The family standards package is not adopted into the repo as a first-class standard layer.
- There is no project ADR declaring inheritance of the Realtime Audio Family Standards.
- There is no Orbisonic OpenSpec tree or equivalent callback-adjacent change process.
- The HAL input callback currently allocates/deallocates callback-local buffer lists.
- The live ring buffer uses `NSLock` in callback-reachable write/read paths.
- Legacy metering can allocate and lock from callback-adjacent tap/capture paths.
- There is no callback safety instrumentation for allocation count, blocking-lock count, callback duration p50/p95/p99/max, deadline misses, or telemetry drops.

## Non-Negotiable Constraints

- No callback allocation, deallocation, blocking lock, wait, sleep, logging, UI call, file I/O, network I/O, JSON parsing, route discovery, graph rebuild, or dynamic container growth.
- No new audio graph mutation from SwiftUI, VU display, metadata parsers, route pickers, or web state.
- No fake audio, fake channels, fake meters, hidden gain, hidden sample-rate conversion, silent route fallback, or route mismatch masking.
- No claim that Dante output is active until a real `AudioCore`-owned live Dante adapter is implemented and manually verified.
- Metering is observational. It must not block, mutate, own, or consume audible output.
- The orbital view must render immutable meter snapshots only. It must not reach into audio buffers, graph nodes, route handles, taps, or live renderer state.
- Hardware-only behavior must remain manual verification unless the test actually exercises that hardware.

## Total Plan

1. Adopt the shared family standards into Orbisonic docs and change process without weakening existing Orbisonic contracts.
2. Map and document all current callback entry points and callback-reachable functions.
3. Remove the most direct callback doctrine violations from live capture: callback allocation/deallocation and callback-facing locks.
4. Route meters through bounded, nonblocking, copy-only snapshots with explicit overload/drop counters.
5. Expose a value-only multichannel VU model suitable for the orbital Sonic Sphere view.
6. Render multichannel VU activity in the orbital view from real meter snapshots while preserving the existing Orbisonic visual language.
7. Add focused tests for callback safety boundaries, meter source labels, orbital view model mapping, and no monitor-to-production mutation.
8. Add callback performance gates and manual verification steps before calling the feature compliant.

## Slice 1: Adopt Family Standards As Project Governance

Goal:
Make the Realtime Audio Family Standards visible and binding in Orbisonic without changing runtime behavior.

Implementation scope:

- Add a standards layer under `docs/realtime-audio-family/` or another repo-local path that preserves the shared standards package contents or a project-specific copy of the mandatory files.
- Add an ADR under `docs/decisions/` declaring that Orbisonic inherits the Realtime Audio Family Standards Package.
- Add the required inheritance statement near the top of `docs/architecture.md` or a new project architecture profile.
- Add an Orbisonic project profile describing backend choice, source modes, Sonic Sphere 30.1, current legacy exceptions, and stricter product-specific rules.
- Update `docs/status.md`, `docs/implementation-map.md`, and `docs/test-strategy.md` to point at the adopted standards layer.
- Do not edit the shared source package in `../All projects assets/`.

Acceptance criteria:

- The repo has a clear local standards path.
- The inheritance ADR exists.
- Current docs say Orbisonic can add stricter requirements but cannot weaken the family doctrine.
- No app source behavior changes.

Verification:

```sh
git diff --name-only -- AGENTS.md README.md Package.swift Sources Tests scripts installer Vendor calibration
git diff --check
```

Slice 1. I'm ready to do the next slice.

## Slice 2: Callback Reachability And Impact Map

Goal:
Create the callback reachability map required by the family standards before touching callback-adjacent implementation.

Implementation scope:

- Add an audit doc under `docs/audits/` or `docs/PureAudio/` listing each callback or render-block entry point.
- Include at least:
  - `LiveInputCapture.inputCallback`
  - `LiveInputCapture.renderInput`
  - `AVAudioSourceNode` closures in `OrbisonicEngine`
  - monitor meter tap closure in `OrbisonicEngine`
  - diagnostic tone and voice source-node closures
  - any AudioCore process path intended to become callback-reachable
- For each entry point, list synchronously reachable helpers, current unsafe operations, current tests, and intended remediation.
- Add a callback impact report template to the repo if the adopted standards package does not already provide one locally.
- Update `docs/test-strategy.md` with the requirement that callback-adjacent changes include callback impact evidence.

Acceptance criteria:

- Every known live callback/tap/source-node path has a documented reachability chain.
- Unsafe operations are named precisely, not summarized vaguely.
- The report distinguishes current legacy paths from future `AudioCore` callback paths.
- No runtime source behavior changes.

Verification:

```sh
git diff --name-only -- AGENTS.md README.md Package.swift Sources Tests scripts installer Vendor calibration
git diff --check
```

Slice 2. I'm ready to do the next slice.

## Slice 3: Preallocate Live HAL Capture Buffers

Goal:
Remove callback allocation/deallocation from the live HAL input capture path.

Implementation scope:

- Replace per-callback `AudioBufferList` and per-channel `UnsafeMutableRawPointer.allocate` calls with preallocated capture storage owned by `LiveInputCapture` or a new capture buffer owner.
- Allocate the maximum configured channel count and maximum supported callback frame capacity before `AudioOutputUnitStart`.
- In the callback, pass only prepared buffer views to `AudioUnitRender`.
- Define what happens if Core Audio supplies a frame count above the prepared max:
  - fail visibly outside realtime if possible before arming; or
  - return silence/status and set a bounded overload flag without allocating.
- Add tests for allocation ownership and oversized frame-count policy where practical.
- Update callback impact report with the removed allocation path.

Acceptance criteria:

- No allocation or deallocation remains in `LiveInputCapture.renderInput` or helpers it calls from the HAL callback.
- The prepared buffer capacity is explicit and documented.
- Oversized callback blocks have explicit behavior.
- Existing live input tests still pass or are updated to the new buffer owner.

Verification:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter LiveAudioBridgeTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter PureAudioArchitectureBoundaryTests
git diff --check
```

Final response for this slice must include:

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

Slice 3. I'm ready to do the next slice.

## Slice 4: Replace Callback-Facing Locks With Bounded Transfer

Goal:
Replace `NSLock` use in live capture/playback transfer paths with a bounded realtime-safe exchange pattern.

Implementation scope:

- Replace `LiveChannelRingBuffer` callback-facing locking with a fixed-capacity SPSC ring or another project-owned bounded wait-free transfer.
- Define producer and consumer ownership:
  - HAL capture writes.
  - AVAudioSourceNode render reads.
  - UI/status reads use snapshots or counters, not the same blocking path.
- Define exact full/empty behavior:
  - full: drop oldest or trim to target latency and increment counters.
  - empty: output silence, increment underflow counters, re-prime.
- Keep buffer capacity bounded and derived from session sample rate, target latency, high water, and max block.
- Move status reads to non-realtime snapshots or atomics so UI polling cannot block audio.
- Add tests for underflow, overflow/drop, priming, non-consuming meter peeks, and no unbounded growth.

Acceptance criteria:

- Callback-reachable write/read paths do not call `NSLock.lock`.
- Overflow and underflow behavior is deterministic and counted.
- Meter peeks do not consume playback data.
- Status snapshots cannot backpressure the audio path.

Verification:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter LiveAudioBridgeTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter LiveNormalMonitorRouteTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MeteringIsolationTests
git diff --check
```

Final response for this slice must include the callback impact block.

Slice 4. I'm ready to do the next slice.

## Slice 5: Nonblocking Meter Snapshot Path

Goal:
Move legacy VU metering toward nonblocking, copy-only snapshots that the UI and orbital view can consume safely.

Implementation scope:

- Define a value-only meter snapshot model for app UI consumption if existing `MeterSnapshot` and `ChannelMeterStore` need a bridge.
- Use source labels that preserve truth:
  - `Input Meter`
  - `Desktop Output Meter`
  - `Sonic Sphere Analysis Meter`
  - `Dante Output Meter` only for actual post-render Dante output.
- Ensure callback/tap paths publish only tiny fixed-size values or bounded copies with drop counters.
- Move smoothing, color mapping, labels, and UI-specific normalized levels outside callback-reachable code.
- Preserve current quiet-signal behavior: quiet measured signal may show a visual tail, but silence must remain silence.
- Add tests that meter calibration does not mutate audible output hashes or renderer coefficients.

Acceptance criteria:

- UI-facing meters read immutable values or snapshots.
- Telemetry overload drops/coalesces instead of blocking audio.
- Meter labels cannot misrepresent analysis projection as real Dante output.
- Existing VU tab behavior remains visually and semantically compatible.

Verification:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MeteringTelemetryTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MeteringIsolationTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter SonicSphereMeteringTests
git diff --check
```

Final response for this slice must include the callback impact block.

Slice 5. I'm ready to do the next slice.

## Slice 6: Orbital View Multichannel VU Data Model

Goal:
Add a value-only model that maps multichannel meter snapshots onto the orbital Sonic Sphere view.

Implementation scope:

- Identify the orbital view implementation, currently `SonicSphereRendererSceneView` in `ContentView.swift`.
- Create a small model layer that maps channels or speakers to orbital meter state:
  - channel ID
  - label
  - role
  - normalized level
  - peak/clipping flag
  - hot flag
  - meter source label
  - whether the source is actual audible output or analysis only
- Keep this model free of `AVAudioEngine`, `AVAudioPCMBuffer`, `AudioBufferList`, route handles, taps, and graph objects.
- Preserve Sonic Sphere topology: the orbital VU mapping must not change renderer matrices, monitor topology, route selection, gain, or output channel count.
- Add deterministic tests for mapping:
  - 2-channel monitor data maps only to monitor markers or is omitted from Sonic Sphere output markers.
  - 30.1 analysis data maps to 30 full-range markers plus LFE/sub.
  - 32-channel physical plans keep channel 32 reserved/silent unless a future contract changes it.
  - inactive or all-zero meters render as inactive, not fake activity.

Acceptance criteria:

- Orbital VU state is derived from meter snapshots only.
- The model can be tested without SceneKit or live Core Audio.
- Source labels survive into the orbital view model.
- No UI code gets direct audio internals.

Verification:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter SonicSphereMeteringTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter RendererModuleTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter PureAudioArchitectureBoundaryTests
git diff --check
```

Slice 6. I'm ready to do the next slice.

## Slice 7: Render Multichannel VU In The Orbital View

Goal:
Display real multichannel VU activity inside the orbital Sonic Sphere view without changing the app shell structure.

Implementation scope:

- Extend `SonicSphereRendererSceneView` or its coordinator to accept the orbital VU model from Slice 6.
- Render level using restrained Orbisonic visual language:
  - normal active: cyan/blue glow or size change
  - hot: amber accent
  - clipping: red/pink ring or pulse
  - inactive: quiet outline
  - LFE/sub: visually distinct but not oversized
- Use stable dimensions and avoid layout changes when levels update.
- Keep the orbital view readable at 30.1 and 32-channel plan sizes.
- Add a visible or accessible source label so the operator can tell whether the orbital activity is `Sonic Sphere Analysis Meter` or actual `Dante Output Meter`.
- Do not add explanatory clutter inside the app. Keep labels compact and operator-facing.
- Do not make the whole page scroll; preserve the current workbench layout and VU/Renderer tabs.

Acceptance criteria:

- Orbital view shows multichannel activity from real meter state.
- It does not animate or glow when the source meter is inactive/all-zero.
- Hot/clipping states are visually distinct.
- The feature does not introduce UI overlap or text overflow in current minimum window dimensions.
- SceneKit rendering remains optional enough for tests to validate model behavior without a live renderer.

Verification:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter OrbisonicUITweakTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter SonicSphereMeteringTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter PureAudioArchitectureBoundaryTests
git diff --check
```

After code changes, refresh the app bundle:

```sh
./scripts/refresh-orbisonic-app.sh
```

If the app is already running, reopen through LaunchServices:

```sh
./scripts/reopen-orbisonic-app.sh
```

Manual visual check:

- Open the VU and Renderer/Output areas.
- Confirm the orbital view shows multichannel activity only when the matching meter source is active.
- Confirm labels do not say `Dante Output Meter` unless the source is actual Dante output.
- Confirm no text overlaps at the minimum supported window size.

Slice 7. I'm ready to do the next slice.

## Slice 8: Callback Safety Instrumentation And Performance Gates

Goal:
Install the minimum evidence needed before claiming callback-adjacent compliance.

Implementation scope:

- Add or document a callback stress harness that can report:
  - sample rate
  - block size or range
  - callback duration p50, p95, p99, and max
  - deadline miss count
  - callback allocation/deallocation count
  - blocking-lock count
  - wait/sleep count
  - telemetry drops
  - event or meter copy drops/coalesces
  - CPU load under stress where practical
  - denormal handling status
  - route mismatch behavior
- If runtime allocation/lock instrumentation is too large for one slice, add the static and dynamic hooks needed for the next slice and clearly mark the gap.
- Add a standard stress scene for maximum configured channel count, active UI/meters, route validation before arming, telemetry active, and panic/stop behavior.
- Record performance budgets in `docs/test-strategy.md` using the family starting guidance unless a stricter Orbisonic budget is chosen.

Acceptance criteria:

- Callback-adjacent changes have measurable safety evidence or explicitly documented gaps.
- The project has named performance budgets.
- Tests or scripts fail, warn, or block clearly when callback safety evidence is missing.
- No release doc implies compliance before the gates are passing.

Verification:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```

Manual or local stress command:

```text
Run the project-specific stress harness added by this slice and record p50/p95/p99/max, deadline misses, allocations, locks, waits, and telemetry drops.
```

Final response for this slice must include the callback impact block and performance report location.

Slice 8. I'm ready to do the next slice.

## Slice 9: Full Documentation And Release-Gate Alignment

Goal:
Make project control docs reflect the actual implementation state after the realtime safety and orbital VU work.

Implementation scope:

- Update `docs/status.md` with completed slices, remaining manual gates, and current risks.
- Update `docs/implementation-map.md` for any new source, tests, scripts, docs, or standards files.
- Update `docs/system-flows.md` if the meter path, callback path, or orbital VU data flow changed.
- Update `docs/contracts.md` only if a public contract changed and the change was explicitly accepted.
- Update `docs/test-strategy.md` with new tests, performance gates, manual verification, and known gaps.
- Update `.tasks/020...` completion notes as slices finish, if this file remains the active work package.
- Keep hardware-only claims manual unless actually tested.

Acceptance criteria:

- Docs match source and tests.
- Manual verification gaps are explicit.
- There is no claim that live Dante output is active unless it is implemented and verified.
- There is no claim that callback compliance is complete unless all mandatory gates pass.

Verification:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
./scripts/refresh-orbisonic-app.sh
git diff --check
```

Manual checks:

- Launch through `./scripts/reopen-orbisonic-app.sh`.
- Confirm orbital VU behavior visually.
- Confirm live/hardware paths that require Sonic Sphere, Dante, Roon, Spotify, Aux, microphone permission, signing, or installer behavior are recorded as manual unless tested.

Slice 9. I'm ready to do the next slice.

## Slice 10: Final Compliance Review

Goal:
Decide whether Orbisonic can honestly be called compliant with the Realtime Audio Family Standards, partially compliant, or still brownfield-in-progress.

Implementation scope:

- Re-run the original audit questions:
  - Are standards adopted locally?
  - Is inheritance documented?
  - Are callback entry points mapped?
  - Are callback allocations zero?
  - Are callback blocking locks zero?
  - Are callback waits/sleeps zero?
  - Are p95/p99/max durations inside budget?
  - Are deadline misses zero in the standard stress scene?
  - Do meter/telemetry overloads drop or coalesce without blocking audio?
  - Are route mismatches visible before arming?
  - Is the orbital VU view fed by real snapshots only?
  - Are labels truthful about analysis versus actual output?
- Produce a final audit under `docs/audits/`.
- Update status/readiness docs with the final result.

Acceptance criteria:

- The final audit has a clear compliance verdict.
- Remaining exceptions have ADRs or are listed as blockers.
- No hidden hardware claim, Dante claim, or callback-safety claim remains.

Verification:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```

Manual verification:

- Run any hardware/service checks needed to support the final verdict.
- If they cannot be run, record them as blockers rather than passing criteria.

Slice 10. I'm ready to do the next slice.

## Global Stopping Conditions

Stop and report before continuing if:

- A public contract must change and the user has not accepted it.
- A major dependency is required.
- A change would mask live audio failures.
- A change would add fake signal, fake meters, hidden gain, hidden SRC, or silent fallback.
- A callback-adjacent change still allocates, locks, waits, logs, calls UI, parses, does I/O, or discovers routes from callback-reachable code.
- The implementation would touch unrelated subsystems.
- Tests fail for reasons outside the slice.
- Hardware-only verification is required but cannot be run.

## Required Final Summary For Every Slice

Use the repo standard:

```text
Summary:
Files changed:
Tests added or updated:
Commands run:
Results:
Documentation updated:
Assumptions:
Risks or blockers:
Recommended next prompt:
```

For callback-adjacent slices, also include:

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
