# Decision 0008: UI Freeze

## Status

Accepted.

## Context

The current Orbisonic interface is the accepted baseline and should not change how the app is used during the audio-chain retrofit.

## Decision

Orbisonic preserves the existing UI.

The only visible addition is the Pure Spherical Lossless badge.

## Rationale

The problem is the audio chain, not the interface. UI redesign would add product risk and make it harder to tell whether the rewrite fixed audio.

## Consequences

Positive:

- User does not relearn the app.
- Codex cannot drift into UI redesign.
- Audio changes are isolated.

Negative:

- Existing UI facade may require adapter work.
- Diagnostics must fit existing surfaces.

## Follow-Up

- Create UI baseline tests before audio implementation.
