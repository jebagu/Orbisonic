# Apple Spatial Headphone Monitor

`Apple Spatial Headphones` is a desktop monitor mode only.

It is not a production renderer, not a Dante output path, and not a replacement for the Sonic Sphere 31-channel renderer.

## Purpose

The feature gives the desktop confidence monitor an Apple-native headphone spatial option. Users can switch the desktop monitor between:

- `Reference Stereo Monitor`: the existing Normal Monitor stereo fold-down path.
- `Apple Spatial Headphones`: an Apple-native headphone spatial monitor path using virtual speaker positions and Apple's public spatial audio APIs where supported.

## Boundaries

- Dante output is unaffected.
- Dante output gain is unaffected.
- Sonic Sphere renderer matrices are unaffected.
- Session sample-rate policy is unchanged.
- Hidden production sample-rate conversion remains forbidden.
- VU and meter code still consume value snapshots only.
- UI sends a command or view-model request only. UI does not import AVFAudio or touch graph objects.

## What It Does Not Do

`Apple Spatial Headphones` does not decode Dolby Atmos or Apple Music Spatial Audio bitstreams. It spatializes Orbisonic's own monitor source layout using public Apple spatial audio APIs.

PHASE and personalized spatial audio remain future capability hooks unless the app later gains a clean entitlement-safe integration.

## Implementation

`AppleSpatialHeadphoneMonitor` is an AudioCore/audio-implementation-only module.

The module owns `AVAudioEnvironmentNode` validation and spatial-source configuration. Public status and command types are value-only:

- `DesktopMonitorMode`
- `AppleSpatialHeadphoneOptions`
- `AppleSpatialHeadphoneCapability`
- `DesktopMonitorModeStatus`

The Output Monitor page toggle controls this mode through the view model and Pure Audio command shape. It does not directly mutate the audio graph.

## Route Policy

The mode is disabled or pending when route/session constraints are not met:

- No desktop monitor route.
- Dante route selected.
- Feedback-loop route selected.
- Route exposes fewer than 2 output channels.
- Desktop route sample rate does not match the session/sample-rate context.
- Built-in speakers are selected while `requiresHeadphones` is true.
- Route is unavailable.

Head tracking is optional and capability-dependent. If unavailable on the SDK, route, or hardware, the monitor can still be supported without head tracking.

## LFE Policy

The default LFE policy is conservative: LFE and LFE2 are omitted from the reference Apple Spatial Headphones monitor. A future consumer-preview bass mode can add explicit bass behavior without changing the Sonic Sphere Dante renderer.

## Current Runtime Status

Prompt 13 adds the command/status boundary, route capability classifier, virtual speaker position map, UI toggle, and validation module.

Live desktop graph rebuilding is not claimed as complete here. When the route supports the mode, the UI saves the preference but reports that live Apple Spatial Headphones output is not wired until the desktop monitor branch is safely rebuilt by AudioCore.
