# Orbisonic Release Notes

## 1.3.1

Orbisonic 1.3.1 is a packaging hotfix for the 1.3 installer lane.

### Installation

Install the app only with:

```sh
installer/Orbisonic-1.3.1.pkg
```

Install the app plus Orbisonic virtual input drivers with:

```sh
installer/OrbisonicSuite-1.3.1.pkg
```

### Packaging Notes

- Rebuilds the app package with `pkgbuild --component`.
- Rebuilds the suite with `productbuild` from valid component packages.
- Adds package payload checks so malformed loose-file `Payload` archives fail before publishing.
- Adds packaged-resource lookup that does not depend on SwiftPM `Bundle.module` during app launch.
- Deprecates the previous 1.3 installer assets.

## 1.3

Orbisonic 1.3 is deprecated. The published suite installer had a malformed payload layout and should not be used.

## 1.1

Orbisonic 1.1 packages the current app build from commit `8ffa977` and adds a suite installer that bundles the app with Orbisonic Inputs 0.2.0.

### Installation

Install the app only with:

```sh
installer/Orbisonic-1.1.pkg
```

Install the app plus Orbisonic virtual input drivers with:

```sh
installer/OrbisonicSuite-1.1.pkg
```

The suite installer includes:

- `Orbisonic Roon Input`
- `Orbisonic Aux Cable`
- `Orbisonic Spotify Input`

## 1.0

Orbisonic 1.0 is the first packaged app build for the native macOS Sonic Sphere routing, monitoring, and rendering workflow.

### Highlights

- Adds the compact `Player` pane with centralized transport and live-source controls.
- Splits the main workspace into `Input`, `Routing`, `Output`, `Renderer`, `Local Music`, `Diagnostics`, and `Settings`.
- Adds compact adaptive square and hex VU meters on the `Routing` and `Diagnostics` tabs for input, monitor, and renderer activity.
- Adds monitor output selection from existing Core Audio outputs without adding another virtual soundcard.
- Makes live monitor stops explicit and stops the active Roon or Aux Cable monitor when switching sources.
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

The app package does not install or replace those loopback drivers. Without Orbisonic Inputs, local file playback still works, but Roon and Aux Cable live capture will report the missing input devices.

### Notes

- macOS may label Orbisonic live-capture access as microphone access because Core Audio input-device capture uses the same privacy permission.
- Roon transport control requires the optional local Orbisonic Roon Bridge helper and Roon extension authorization.
- The renderer/source path remains capped at 64 source channels for this build.
