# Decision 0005: Roon Live PCM Boundary

## Status

Accepted.

## Context

Roon opens and decodes its own files before Orbisonic sees audio. Orbisonic captures PCM from a loopback route.

## Decision

Roon remains a live PCM capture source. VLC is not inserted into Roon by default.

## Rationale

VLC naturally owns file access, demux, and decode. Roon has already performed those steps. Inserting VLC after CoreAudio capture would add latency and clock complexity.

## Consequences

Positive:

- Roon source boundary remains honest.
- Capture diagnostics can focus on route, sample rate, channel count, and all-zero input.

Negative:

- Roon multichannel-to-stereo monitor downmix needs an explicit owner.

## Follow-Up

- Detect stereo versus multichannel Roon capture.
- Block hidden Roon multichannel monitor downmix.
- Consider future VLC live PCM downmix bridge only after proof harness.
