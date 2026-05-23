# Orbisonic Realtime Audio Project Profile

## Status

Accepted project profile for the adopted Realtime Audio Family Standards Package.

## Inheritance

This project inherits the Realtime Audio Family Standards Package. The Bencina Realtime Callback Doctrine is mandatory for every callback and every callback-reachable function. Project-specific requirements may add stricter rules but may not weaken the family standard.

The adopted family package is stored under `docs/realtime-audio-family/`. Binding Orbisonic-specific contracts remain in `docs/contracts.md`, accepted ADRs, and current source/tests.

## Product Shape

Orbisonic is a native Swift/macOS app for routing, monitoring, and rendering multichannel spatial audio for Sonic Sphere. Sonic Sphere is the physical 30.1 spatial audio system. Orbisonic is the software tool for interfacing with it.

The current repository is a Swift Package Manager project with:

- `AudioContracts`: value vocabulary and validation.
- `AudioImport`: local asset readiness and explicit managed import.
- `AudioCore`: deterministic planning, render kernels, source adapters, output adapters, and metering telemetry.
- `Orbisonic`: SwiftUI app shell plus current concrete AVAudioEngine, Core Audio, live loopback, source integration, diagnostics, and web-surface code.

## Backend Profile

Current live runtime backend:

- SwiftUI/AppKit for UI.
- AVAudioEngine for current local playback and monitor output.
- Core Audio HAL input callback for live loopback capture.
- Current live playback is still a brownfield compatibility path through `OrbisonicEngine`.

Target realtime backend direction:

- Thin Core Audio/AVAudioEngine adapters deliver prepared buffer views and timing to `AudioCore`.
- `AudioCore` owns source admission, render planning, production render kernels, output adapters, and value-only telemetry.
- UI, diagnostics, web, metadata, route discovery, and file parsing remain outside realtime.

## Three-Plane Specialization

Preparation plane:

- Local file probing, managed import, offline conversion, source validation, route validation, render graph planning, channel maps, session ledgers, and immutable snapshot creation.

Realtime plane:

- Device callbacks, AVAudioSourceNode render closures, live capture write/read, output buffer writes, panic/silence, bounded event or snapshot reads, and tiny meter publication.

UI / diagnostic / telemetry plane:

- SwiftUI views, SceneKit orbital view, diagnostics rows, local web state, Roon/Spotify metadata, local library metadata, logging, JSON, file I/O, network I/O, route discovery, and formatted meter display.

## Source Profile

Orbisonic uses selected-source behavior, not an implicit mixer.

Current source modes:

- `Off`
- `Roon`
- `Spotify`
- `Atmos DRP`
- `Aux Cable`
- `Local Files`
- `Test Tone`

Roon, Spotify, Atmos DRP, and Aux are live loopback capture paths. Local files and test tones have separate transport paths. Metadata is diagnostic and must not override live PCM route facts.

## Output Profile

Production output target:

- Sonic Sphere 30.1, meaning 30 full-range spatial outputs plus one LFE/sub output.

Monitor output target:

- Desktop/headphone/normal monitor output for setup and confidence listening.

Rules:

- Sonic Sphere production output is primary.
- Monitor output must not redefine Sonic Sphere topology.
- Route mismatch fails visibly before arming.
- Silent downmix, channel truncation, hidden sample-rate conversion, fake channel expansion, and fallback routing are forbidden unless a future accepted contract explicitly defines the behavior and tells the user before arming.
- Live Dante output is not complete until a real `AudioCore`-owned live output adapter is implemented and manually verified.

## Metering And Orbital VU Profile

Metering is observational and must not affect audio.

Orbisonic meter labels preserve source truth:

- `Input Meter` means captured input signal.
- `Desktop Output Meter` means desktop/normal monitor signal.
- `Sonic Sphere Analysis Meter` means synthetic, legacy, or analysis projection and is not proof of audible Dante output.
- `Dante Output Meter` is reserved for actual post-render Dante/output bus data after live Dante output exists.

The orbital Sonic Sphere view may show multichannel VU activity only from immutable meter snapshots or value-only orbital meter models. It must not read graph nodes, buffers, route handles, taps, or mutable renderer state.

## Brownfield Exceptions

Current known exceptions:

- `OrbisonicEngine` still owns the current audible AVAudioEngine compatibility graph.
- `LiveAudioBridge` still owns Core Audio HAL capture and live pipe buffering.
- Legacy metering still supports Normal Monitor and Sonic Sphere analysis surfaces.
- `OutputRouteMonitor` and `BlackHoleRouteRepair` still own legacy Core Audio route discovery and repair.
- `OrbisonicViewModel` still calls legacy engine paths for play, pause, route selection, local file commit, live loopback start, and test tones.

These exceptions are not compliance claims. They are migration inventory until remediated.

## Callback-Adjacent Completion Rule

Any callback-adjacent change must answer:

```text
Callback impact:
New callback-reachable functions:
Allocation risk:
Lock/wait risk:
I/O/logging/UI risk:
Worst-case loop bounds:
Queue-full or overload policy:
Tests or instrumentation run:
```

The project is not fully compliant until callback reachability, unsafe work removal, overload policy, and performance gates are documented and passing.
