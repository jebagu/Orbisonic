# Decision 0002: VLC Reference Monitor

## Status

Accepted.

## Context

The current native local monitor downmix is a suspected source of bad audio. VLC is a mature ordinary media-player reference for local-file decode and stereo downmix.

## Decision

Use VLC as the protected local-file stereo monitor authority.

## Rationale

Local monitor playback asks for ordinary stereo output. VLC is better suited than a custom Orbisonic downmixer for that path.

## Consequences

Positive:

- Local-file stereo monitor downmix becomes reference-standard.
- Native Orbisonic downmix is bypassed for local monitor playback.
- Monitor path becomes simpler and easier to test.

Negative:

- libVLC packaging and plugin discovery must be solved.
- VLC is not a solution for Roon live PCM by default.
- VLC callback path is not a 30 or 52 channel production bridge.

## Follow-Up

- Build VLC capability probe.
- Build local stereo monitor source.
- Prove no double downmix.
