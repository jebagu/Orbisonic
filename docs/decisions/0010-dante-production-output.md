# Decision 0003: Dante Production Output

## Status

Accepted.

## Context

SonicSphere production output requires strict multichannel delivery. Dante expects configured PCM transport, not an arbitrary internal float bus.

## Decision

Default production output profile is 48 kHz / 24-bit PCM with explicit channel map and strict route validation.

## Rationale

This profile is common for Dante, preserves channel capacity, and reduces route instability.

## Consequences

Positive:

- Production output has a clear contract.
- SRC is explicit and testable.
- Dither and quantization are localized.

Negative:

- 96 kHz sessions require separate route proof.
- Host API float formats must be carefully distinguished from Dante network encoding.

## Follow-Up

- Implement fake backend first.
- Validate DVS/CoreAudio route facts.
- Add hardware manual gate.
