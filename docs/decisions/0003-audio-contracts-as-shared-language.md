# 0003: AudioContracts As Shared Language

Status: Accepted

## Context

The current repo has an `AudioContracts` library target that defines shared audio vocabulary and validation concepts used by import, core audio, and app-facing behavior. The contracts include sample rates, processing formats, channel roles, source descriptors, route descriptors, output formats, render modes, monitor modes, meter snapshots, conversion ledgers, managed assets, readiness states, and audio errors.

`docs/contracts.md` makes `AudioContracts` the first binding module contract.

## Decision

Use `AudioContracts` as the common type and vocabulary layer for audio policy. Shared rules such as source-channel limits, sample-rate validation, session format validation, conversion ledger validity, meter value semantics, and typed audio errors belong there when they are cross-module concepts.

## Rationale

Orbisonic has several paths that need the same language: local file import, live source adapters, render planning, monitor behavior, route diagnostics, and app status. A shared vocabulary keeps those paths from inventing incompatible local meanings for sample rate, channel count, source kind, output capability, or conversion state.

## Alternatives Considered

- Let each subsystem define its own audio model: rejected because it increases drift and makes source/render/monitor bugs harder to diagnose.
- Put shared audio policy in the app target: rejected because lower-level package tests would have to depend on executable runtime code.
- Move platform-specific route and graph ownership into `AudioContracts`: rejected because `AudioContracts` must stay a value layer, not a Core Audio or AVAudioEngine owner.

## Consequences

- Changes to shared audio vocabulary require `AudioContractsTests`.
- `AudioContracts` must stay free of SwiftUI, AppKit, AVFoundation graph ownership, Roon, Spotify, app runtime, and installer behavior.
- Contract changes should be explicit and should not be slipped into feature implementation.

## Follow-up

- Keep `docs/contracts.md` and `docs/test-strategy.md` aligned with `AudioContracts`.
- Add tests before accepting new shared audio vocabulary.
- If a lower-level contract needs runtime facts, pass them in as values rather than reaching across module boundaries.
