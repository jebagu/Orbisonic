# 0004: Selected Source Only Rule

Status: Accepted

## Context

Current source modes are `Off`, `Roon`, `Spotify`, `Aux Cable`, `Local Files`, and `Test Tone`. Live source modes map to dedicated loopback expectations: `Orbisonic Roon Input`, `Orbisonic Spotify Input`, and `Orbisonic Aux Cable`. Local Files owns app playback and does not require a live input route.

Current contracts, flows, tests, and source support describe Orbisonic as selected-source oriented rather than as a mixer.

## Decision

Orbisonic has one selected active source path at a time. Roon, Spotify, Atmos DRP, Aux, Local Files, and Test Tone must not be automatically summed or mixed. Switching sources must stop or isolate the previous path so stale local, Roon, Spotify, Atmos DRP, Aux, or diagnostic state cannot drive audible output for the newly selected source.

## Rationale

The product is an operator-facing routing, rendering, and monitoring tool for Sonic Sphere, not a DAW or arbitrary mixer. Selected-source semantics keep diagnostics readable, make live silence easier to trace, and reduce feedback-loop and stale-state risks.

## Alternatives Considered

- Add implicit mixing between live sources: rejected because it would require a separate mixer contract, UI model, diagnostics model, metering model, and safety policy.
- Let live sources keep background capture while another source plays: rejected because mute is not a multi-source feature and stale capture can confuse diagnostics.
- Treat Aux as a catch-all that includes Roon and Spotify: rejected because current source modes and loopback identities distinguish those paths.

## Consequences

- Source switching is high-risk and needs tests.
- Roon, Spotify, Atmos DRP, Aux, and Local Files must keep separate metadata, transport, route, and signal states.
- Future simultaneous playback requires a new accepted contract.
- Web/public/control state must show the selected source without letting stale inactive state win.

## Follow-up

- Keep source-isolation tests current in `LoopbackSourceSupportTests`, `OrbisonicWebStateTests`, `LocalPlayerStabilizationTests`, and `AudioCoreTests/SourceAdapterTests.swift`.
- Add explicit no-stale-state tests when changing source selection, transport, or diagnostics.
- If a future mixer is desired, write a new ADR and contract before implementation.
