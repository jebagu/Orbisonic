# Orbisonic Release Notes

## 1.0

Orbisonic 1.0 is the first packaged app build for the native macOS Sonic Sphere routing, monitoring, and rendering workflow.

### Highlights

- Adds the compact `Player` pane with centralized transport and live-source controls.
- Splits the main workspace into `Input`, `Routing`, `Output`, `Renderer`, `Scene Tuning`, `Local Playlist`, `Diagnostics`, and `Settings`.
- Adds compact pulsing square VU meters on the `Routing` tab for input, monitor, and renderer activity.
- Adds monitor output selection from existing Core Audio outputs without adding another virtual soundcard.
- Keeps the Sonic Sphere renderer on the default 30.1 topology.
- Adds compact monitor and renderer channel-walk diagnostics.
- Adds the optional Orbisonic Roon Bridge helper for Roon transport control.

### Installation

Install the app with:

```sh
installer/Orbisonic-1.0.pkg
```

The app installer places `Orbisonic.app` in `/Applications`.

Orbisonic live capture also expects the Orbisonic virtual loopback inputs, which are distributed as a separate package. Install Orbisonic Inputs separately to provide:

- `Orbisonic Roon Input`
- `Orbisonic Aux Cable`

The app package does not install or replace those loopback drivers. Without Orbisonic Inputs, local file playback still works, but Roon and Aux live capture will report the missing input devices.

### Notes

- macOS may label Orbisonic live-capture access as microphone access because Core Audio input-device capture uses the same privacy permission.
- Roon transport control requires the optional local Orbisonic Roon Bridge helper and Roon extension authorization.
- The renderer/source path remains capped at 64 source channels for this build.
