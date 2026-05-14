# Decision 0004: Pure Spherical Lossless

## Status

Accepted.

## Context

Orbisonic needs a way to identify already-rendered SonicSphere speaker-bed files.

## Decision

Use `Pure Spherical Lossless` as the user-facing badge for validated rendered SonicSphere LPCM files.

## Rationale

The label communicates that the file is already rendered for the sphere, lossless, and not a normal source file.

## Consequences

Positive:

- User can see when a file is direct sphere material.
- Playback can bypass VLC and renderer.
- Metadata validation prevents filename-only guessing.

Negative:

- Metadata writer/reader must be reliable.
- Files for a different sphere need careful status.

## Follow-Up

- Build validator.
- Build badge presenter.
- Build direct reader.
