# 0002: SwiftPM Target Boundaries

Status: Accepted

## Context

`Package.swift` defines one executable product, `Orbisonic`, and three library products: `AudioContracts`, `AudioImport`, and `AudioCore`.

The package target split is:

- `AudioContracts`: no package-target dependencies.
- `AudioImport`: depends on `AudioContracts`.
- `AudioCore`: depends on `AudioContracts` and `AudioImport`.
- `Orbisonic`: depends on `AudioContracts`, `AudioImport`, and `AudioCore`.

The test targets mirror this split with `AudioContractsTests`, `AudioImportTests`, `AudioCoreTests`, and `OrbisonicTests`.

## Decision

The existing SwiftPM target split is the starting architecture for the retrofit. Shared value contracts belong in `AudioContracts`, local asset readiness and managed import policy belong in `AudioImport`, deterministic planning and render logic belong in `AudioCore`, and concrete app runtime behavior belongs in the `Orbisonic` executable target.

## Rationale

The target split provides useful boundaries without requiring a rewrite. It lets tests protect pure value and planning code independently from SwiftUI, AVAudioEngine runtime behavior, Roon, Spotify, Core Audio routes, diagnostics, and packaging scripts.

## Alternatives Considered

- Collapse everything into the executable target: rejected because it would make contract and pure-audio tests less meaningful.
- Move all app audio behavior into `AudioCore` immediately: rejected because the current app still owns concrete AVAudioEngine and platform integration behavior.
- Add new package targets during the retrofit: deferred until audits identify a specific need.

## Consequences

- Lower-level targets must not reach back into app UI, view model, runtime helper, or installer ownership.
- `OrbisonicTests` remains the place for app-runtime and integration behavior.
- Boundary tests should keep forbidden imports and dependencies visible.
- Some concrete audio behavior remains in the executable target during the retrofit.

## Follow-up

- Keep `docs/implementation-map.md` aligned with package target ownership.
- Add or update architecture boundary tests whenever package ownership changes.
- If future extraction moves runtime behavior into `AudioCore`, record that as a new or amended ADR.
