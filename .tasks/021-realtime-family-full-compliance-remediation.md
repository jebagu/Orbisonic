# Task 021: Full Realtime Audio Family Compliance Remediation

## Status

Queued. Do not start until the user completes a manual quality check on the last pushed work and confirms whether bug fixes should be handled before or alongside this compliance package.

Total slices: 5.

## Slice Progress

- Slice 1 queued: remove remaining callback allocation from live matrix render.
- Slice 2 queued: close callback reachability gaps around mutable state and unsafe metering paths.
- Slice 3 queued: add and verify the denormal handling policy.
- Slice 4 queued: run the standard 60-second qualification scene and record evidence.
- Slice 5 queued: publish the final compliance audit and manual verification record.

## Purpose

Bring Orbisonic from brownfield-in-progress / noncompliant to a defensible Realtime Audio Family compliance verdict for mapped callback-intended audio paths.

This package is intentionally queued behind manual QA of the last push. If that QA finds bugs, triage those bugs before starting this task unless the user explicitly says a bug fix belongs inside one of these slices.

## Compliance Target

Compliance means Orbisonic can truthfully claim the Realtime Audio Family standard for mapped callback-intended audio paths.

This task does not automatically claim full product release readiness. Sonic Sphere, Dante, Roon, Aux, Spotify, microphone permission, signing, notarization, and installer behavior remain manual release gates unless they are actually run and recorded during Slice 5.

## Current Blockers

- `LiveAudioPipe.render(matrix:audioBufferList:frameCount:)` still records callback scratch allocation.
- Host-level or strict source-level allocation/deallocation evidence is incomplete.
- Host-level or strict source-level blocking lock and wait/sleep evidence is incomplete.
- Denormal handling policy is not verified.
- The real 60-second standard stress scene has not been run.
- `MeterCopyBus.submit` is not realtime-safe and must remain outside callback claims unless refactored/proven.
- The live source-node closure still has mutable engine-state reachability that needs callback-safe state proof.
- The active Renderer tab orbital VU needs manual visual confirmation.
- Sonic Sphere / Dante output, Roon, Aux, Spotify, microphone permission, signing, notarization, and installer behavior remain manual release gates.

## Bug-Fix Coordination

Before starting Slice 1, ask the user whether the manual quality check produced bugs that should be handled first.

Use this rule:

- If a bug affects live callback safety, live metering, orbital VU truth, routing diagnostics, or compliance evidence, fold it into the relevant slice and update this task file before implementation.
- If a bug is unrelated to realtime compliance, create or update a separate task and keep this package blocked until the user prioritizes it again.
- If bug fixes touch app source, rerun the relevant focused tests plus the full SwiftPM suite before claiming any compliance progress.

## Slice 1: Remove Remaining Callback Allocation

Goal:
Eliminate the known allocation blocker in `LiveAudioPipe.render(matrix:audioBufferList:frameCount:)`.

Implementation scope:

- Add a preallocated realtime scratch store owned by the live audio pipe, prepared before arming live render.
- Capacity target: 64 input channels, 31 Sonic Sphere logical outputs, and 8,192 frames per block, matching the documented standard stress scene.
- If runtime channel/frame counts exceed prepared capacity, block arming or return bounded silence/status before the callback path instead of allocating in the callback.
- Remove the current scratch `Array` allocation from matrix render.
- Remove the normal-path `recordCallbackAllocation` call from matrix render after allocation is gone.
- Add a capacity-overflow diagnostic counter for attempted out-of-contract live render sizes.

Acceptance criteria:

- No callback scratch allocation remains in `LiveAudioPipe.render`.
- Existing live pipe tests still pass.
- New or updated tests prove matrix render uses preallocated storage and reports overflow instead of allocating.
- Project control docs are updated with the new callback allocation state.

Verification:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter LiveAudioBridgeTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter RealtimeCallbackSafetyInstrumentationTests
git diff --check
```

End of slice 1 of 5. I'm ready to do the next slice.

## Slice 2: Close Callback Reachability Gaps

Goal:
Make callback-facing state and metering reachability provably safe.

Implementation scope:

- Replace callback reads of mutable engine state such as `liveInputMuted` with a realtime-safe atomic or prepared snapshot value.
- Keep `MeterCopyBus` outside realtime callback claims for this compliance pass.
- Add static/source guard tests proving callback-marked paths do not call `MeterCopyBus.submit`.
- Add static/source guard tests forbidding callback-marked paths from using known unsafe APIs unless explicitly allowlisted:
  - heap-growing collection creation or mutation such as callback scratch `Array(...)` and `append`
  - `NSLock`, blocking locks, waits, and sleeps
  - `DispatchQueue`, `Task`, file, network, UI, and logging APIs
- Keep telemetry and meter transfer as bounded value snapshots or drop/coalesce behavior outside the audio callback.

Acceptance criteria:

- Callback-marked paths have explicit source-level proof against allocation, blocking locks, waits, sleeps, unsafe dispatch, and unsafe metering calls.
- `MeterCopyBus` is either proven unreachable from callbacks or the build/test gate fails.
- No user-facing audio behavior changes.

Verification:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter RealtimeCallbackSafetyInstrumentationTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter PureAudioArchitectureBoundaryTests
git diff --check
```

End of slice 2 of 5. I'm ready to do the next slice.

## Slice 3: Add Denormal Handling Policy

Goal:
Convert denormal handling from not verified to a documented and tested policy.

Implementation scope:

- Use algorithmic denormal avoidance rather than platform FP-mode mutation as the default policy.
- Add a small internal denormal helper used only inside already-bounded sample loops.
- Treat subnormal or near-subnormal samples as zero before they can propagate through realtime render or meter kernels.
- Extend realtime qualification status from `notVerified` to a verified policy state, such as `algorithmicZeroingVerified`.
- Document the policy in the realtime audit and project control docs.

Acceptance criteria:

- Tests feed subnormal sample values through relevant render/meter paths and verify bounded zeroed output.
- Realtime callback report no longer warns that denormal handling is unverified.
- No platform-specific FP control dependency is required for compliance.

Verification:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter RealtimeCallbackSafetyInstrumentationTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter Metering
git diff --check
```

End of slice 3 of 5. I'm ready to do the next slice.

## Slice 4: Run The Standard 60-Second Qualification Scene

Goal:
Add and run the actual compliance stress evidence.

Implementation scope:

- Add a gated qualification command or test so the normal suite stays fast while compliance can run the full scene intentionally.
- Match the documented standard scene:
  - 48 kHz
  - 128 to 8,192 frame blocks
  - up to 64 input channels
  - 31 Sonic Sphere logical outputs
  - active Sonic Sphere analysis meters
  - route, meter, telemetry, stop, and panic event bursts
  - 60-second duration
- Required pass budgets:
  - p95 <= 50% of minimum observed block duration
  - p99 <= 70% of minimum observed block duration
  - max <= 90% of minimum observed block duration
  - deadline misses = 0
  - callback allocations/deallocations = 0
  - callback blocking locks = 0
  - callback waits/sleeps = 0
- Record the resulting evidence in a new final qualification audit.

Acceptance criteria:

- Full SwiftPM tests pass.
- The 60-second qualification scene passes with recorded p95/p99/max timing and zero safety violations.
- The final audit records exact commands, results, and any manual-only gaps.

Verification:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```

Run the gated 60-second qualification command added in this slice and paste its exact command and result into the audit.

End of slice 4 of 5. I'm ready to do the next slice.

## Slice 5: Final Compliance Audit And Manual Verification

Goal:
Publish the final compliance verdict and separate remaining release gates from realtime-family compliance.

Implementation scope:

- Update `docs/status.md`, `docs/test-strategy.md`, and the final audit with the new compliance state.
- Update `docs/implementation-map.md` if new source/test ownership was added.
- Refresh the app bundle after source changes.
- Reopen through LaunchServices before UI verification.
- Manually verify the Renderer tab orbital VU:
  - value snapshots only
  - no simulated or fake signal
  - truthful labels for Sonic Sphere analysis versus actual Dante/output metering
- Keep Sonic Sphere, Dante, Roon, Aux, Spotify, mic permission, signing, notarization, and installer checks listed as manual release gates unless actually performed.

Acceptance criteria:

- Final audit can truthfully say Orbisonic is Realtime Audio Family compliant for mapped callback-intended paths.
- Any hardware or release claims are either verified or explicitly excluded.
- `git diff --check` passes.
- Full SwiftPM tests pass.
- App refresh command completes.

Verification:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
./scripts/refresh-orbisonic-app.sh
./scripts/reopen-orbisonic-app.sh
git diff --check
```

End of slice 5 of 5. I'm ready to do the next slice.

## Planned Internal Interfaces

No public user-facing contract should change.

Expected internal additions:

- `RealtimeMatrixScratchStorage` or equivalent preallocated scratch helper for live matrix render.
- Realtime-safe atomic/snapshot state for callback-readable flags such as live mute.
- Expanded denormal status, such as `algorithmicZeroingVerified`.
- Static callback reachability/source-guard tests for allocation, locks, waits, sleeps, dispatch, and unsafe metering paths.
- A gated 60-second realtime qualification command or XCTest path.

## Assumptions

- The user will complete manual quality check on the last pushed work before this package starts.
- Any bug fixes found during that quality check should be triaged before this package starts unless the user explicitly folds them into this task.
- Source-level proof plus explicit realtime instrumentation is the chosen compliance evidence model, instead of whole-process malloc/free interposition.
- `MeterCopyBus` remains non-realtime and guarded out of callback reachability in this pass.
- If implementation reveals a public contract change is required, stop and document the proposed contract change before proceeding.

## Recommended Start Prompt

After manual quality check and bug-fix triage are complete:

```text
Run Task 021 Slice 1 of 5.
```
