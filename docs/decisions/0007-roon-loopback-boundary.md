# 0007: Roon Loopback Boundary

Status: Accepted

## Context

Roon is a selected live source that expects `Orbisonic Roon Input`. Current code parses Roon server logs for now-playing and signal-path details, and `RoonBridgeClient` can use an optional local Roon bridge helper for transport control and artwork. The repo rules state that a Roon log line is not proof that audio reached loopback capture.

Live audio capture is owned by the selected Core Audio loopback route and `LiveAudioBridge`, not by Roon metadata.

## Decision

Roon responsibilities are split:

- Roon metadata and signal-path facts may come from log parsing.
- Roon transport and artwork may come from the optional local Roon bridge helper.
- Actual audio admission depends on `Orbisonic Roon Input`, route facts, live capture status, meters, sample rate, channel count, underflows, drops, and no-signal diagnostics.

Roon must not override live HAL validation, prove captured audio from metadata alone, mix with other sources, or hide silence.

## Rationale

Roon can report playback while Orbisonic receives no loopback signal. Treating metadata as audio truth would mask the exact failures Orbisonic needs to diagnose: wrong output route, sample-rate mismatch, channel mismatch, permission failure, silent input, underflow, or dropped frames.

## Alternatives Considered

- Trust latest Roon log playback as proof of audio: rejected because logs and loopback capture can diverge.
- Require Roon as the only metadata/control source for all playback: rejected because Local Files, Spotify, Aux, and Test Tone have separate ownership.
- Make the Roon bridge own live capture: rejected because live capture belongs to Core Audio route handling and `LiveAudioBridge`.

## Consequences

- Diagnostics must compare Roon playback state with live capture state.
- Roon bridge failures should not block local playback or Aux/Spotify behavior.
- Roon sample-rate mismatch is diagnostic and must not override live route validation.
- Manual Roon loopback verification remains required for end-to-end confidence.

## Follow-up

- Keep `RoonNowPlayingMonitorTests`, `RoonBridgeClientTests`, `OrbisonicWebStateTests`, `LoopbackSourceSupportTests`, and source-adapter tests current.
- Future Roon API work should make API metadata authoritative for Roon state, but not for captured audio unless paired with live capture facts.
- Record manual Roon loopback checks in release verification docs.
