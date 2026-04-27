# Embedded Librespot Integration

Orbisonic vendors librespot as the source for its Spotify Connect receiver:

- `Vendor/librespot`: pinned upstream librespot source.
- `Vendor/orbisonic-librespot-ffi`: Rust static-library boundary and in-process receiver runner for the Swift app.
- `scripts/build-embedded-librespot.sh`: builds the Rust static library into `.build/orbisonic-librespot`.

The intended runtime shape is one Orbisonic process:

```text
Spotify app -> Spotify Connect -> embedded librespot receiver
embedded librespot receiver -> Orbisonic Spotify Input
Orbisonic Spotify source -> Orbisonic renderer -> Sonic Sphere / Dante
```

The Spotify source remains isolated from Roon and Aux:

- Roon resolves only `audio.orbisonic.rooninput.device`.
- Spotify resolves only `audio.orbisonic.spotifyinput.device`.
- Aux resolves only `audio.orbisonic.auxcable.device`.

Spotify is stereo-only. Do not fake multichannel input from Spotify; any expansion belongs in Orbisonic's renderer, not in the source capture model.

Runtime files:

- librespot cache/support files belong under Orbisonic-managed Application Support.
- receiver logs belong under Orbisonic's app-managed log directory.
- credentials, OAuth tokens, local machine paths, and generated build artifacts must not be tracked.

Current implementation state:

The Swift app uses `SpotifyReceiverClient` and no longer starts an external `librespot` process. The Rust FFI crate owns the single embedded librespot runtime and targets `Orbisonic Spotify Input`. Build `scripts/build-embedded-librespot.sh` before SwiftPM so `.build/orbisonic-librespot/liborbisonic_librespot_ffi.a` is available for the Swift target.
