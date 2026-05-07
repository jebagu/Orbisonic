# 0005: Sonic Sphere 30.1 Primary Output

Status: Accepted

## Context

Orbisonic is the software tool for Sonic Sphere. The current renderer model defines a Sonic Sphere topology with 30 full-range outputs plus one LFE output. The README describes `Sonic Sphere 30.1 Default` as the default renderer preset. `docs/contracts.md` states that Sonic Sphere 30.1 is the primary production output topology unless a future accepted contract changes it.

The normal headphone or monitor output path exists for setup, checking, preview, and desktop listening.

## Decision

Sonic Sphere 30.1 is Orbisonic's primary production output target. Headphone, binaural, Apple spatial, or normal monitor output is a monitor path and must not redefine or mutate the Sonic Sphere production topology.

Direct 30 and Direct 30.1 are bypass modes only when source width matches their expected topology.

## Rationale

Orbisonic's main job is to interface with Sonic Sphere. Keeping production output separate from monitor output protects real speaker topology, route diagnostics, and renderer validation from preview-path convenience changes.

## Alternatives Considered

- Treat headphone or normal monitor output as the production topology: rejected because it conflicts with the Sonic Sphere goal.
- Allow monitor route changes to drive renderer topology: rejected because that would let a preview path alter production semantics.
- Use direct renderer output as a monitor fallback: rejected where tests forbid it because it can hide production/monitor boundary failures.

## Consequences

- Renderer changes require strong deterministic tests.
- Monitor changes must prove they do not mutate Sonic Sphere production behavior.
- Hardware verification is still required to prove physical Sonic Sphere / Dante behavior.
- Metering can expose renderer activity, but meter display must not become the production truth.

## Follow-up

- Keep renderer tests, monitor tests, and metering isolation tests current.
- Record manual Sonic Sphere / Dante verification in release verification docs when the physical route is tested.
- Update this ADR only if a future accepted contract changes the primary production output.
