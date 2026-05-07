# 0006: Embedded Librespot Boundary

Status: Accepted

## Context

The current package enables `ORBISONIC_ENABLE_EMBEDDED_LIBRESPOT` for the `Orbisonic` executable target and links `orbisonic_librespot_ffi` from `.build/orbisonic-librespot`. The repo vendors `Vendor/librespot` and `Vendor/orbisonic-librespot-ffi`, and `scripts/build-embedded-librespot.sh` builds the Rust static library.

`docs/embedded-librespot-integration.md` states that the Swift app uses `SpotifyReceiverClient`, the Rust FFI crate owns the single embedded librespot runtime, and Spotify targets `Orbisonic Spotify Input`.

## Decision

Spotify Connect support is an embedded receiver boundary owned by the app runtime and vendored librespot FFI. The Spotify source remains dedicated to `Orbisonic Spotify Input`, stays isolated from Roon, Aux, and Local Files, and is treated as stereo unless a future accepted contract changes that.

Spotify runtime files belong in app-managed support, cache, and log locations. Credentials, OAuth tokens, caches, generated build artifacts, and local machine paths must not be tracked.

## Rationale

Embedding the receiver keeps the user-facing app flow cohesive while still preserving a clear integration boundary. Routing Spotify through a dedicated loopback keeps source identity and diagnostics explicit.

## Alternatives Considered

- Run an external librespot process as the primary integration: superseded by the current embedded FFI boundary.
- Route Spotify through Aux only: rejected by current source support because Spotify has its own selected source and loopback identity.
- Pretend Spotify is multichannel: rejected because current policy is stereo source capture and renderer expansion belongs downstream, not in source capture.

## Consequences

- SwiftPM builds depend on the local static library artifact being available.
- Spotify receiver behavior needs tests for unavailable, waiting, running, stale metadata, and selected-source behavior.
- Real Spotify Connect playback remains manual verification.
- Spotify credentials and cache state must stay out of tracked files.

## Follow-up

- Keep `docs/embedded-librespot-integration.md`, `Package.swift`, `SpotifyReceiverClientTests`, and source-adapter tests aligned.
- Record manual Spotify Connect checks in release verification docs.
- If the receiver lifecycle changes away from embedded FFI, write a new ADR.
