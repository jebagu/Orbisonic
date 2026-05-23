# Decision 0013: Realtime Audio Family Standards Inheritance

## Status

Accepted.

## Context

Orbisonic is a brownfield realtime audio app. It already has Pure Audio migration docs, `AudioContracts`, `AudioImport`, `AudioCore`, immutable render plans, route validation, explicit sample-rate policy, and copy-only metering concepts. The current live app still has legacy callback-adjacent paths in `OrbisonicEngine`, `LiveAudioBridge`, and legacy metering.

The shared Realtime Audio Family Standards Package defines mandatory callback safety doctrine, a three-plane architecture, callback-adjacent review requirements, event/state publication rules, and performance gates for realtime audio family apps.

## Decision

Orbisonic inherits the Realtime Audio Family Standards Package as a binding project governance layer.

Project-specific requirements may add stricter Orbisonic behavior, but they may not weaken the family callback doctrine, three-plane architecture, event/state transfer rules, telemetry backpressure rule, route-validation rule, or performance gates.

The adopted standards package is stored in:

```text
docs/realtime-audio-family/
```

Orbisonic-specific specialization lives in:

```text
docs/project/orbisonic-realtime-audio-profile.md
```

## Rationale

The family standard turns the current Pure Audio migration intent into a reusable, explicit rule set. It also creates a clear bar before any callback-adjacent work can be called compliant: callback reachability must be mapped, unsafe work must be removed from callback-reachable code, transfer paths must be bounded, and performance evidence must be recorded.

## Consequences

Positive:

- Future audio work has a shared callback-safety baseline.
- Callback-adjacent changes must include impact reports and verification evidence.
- Orbisonic's existing Pure Audio docs can remain product-specific rather than carrying all family-wide doctrine.
- Brownfield legacy exceptions stay visible until remediated.

Negative:

- Current live callback paths cannot be called compliant yet.
- Additional documentation and verification are required before callback-adjacent changes are complete.
- Performance gates and callback instrumentation remain follow-up work before a final compliance claim.

## Follow-Up

- Map callback entry points and callback-reachable functions.
- Remove callback allocation/deallocation from live HAL capture.
- Replace callback-facing locks with bounded realtime-safe transfer.
- Move legacy metering toward nonblocking snapshot publication.
- Add callback allocation, lock/wait, deadline, p95, p99, and telemetry-drop gates.
