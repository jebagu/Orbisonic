# Orbisonic

`Orbisonic` is a package-backed macOS app prototype that routes multichannel audio through Apple's spatial audio pipeline and sweetens the result for headphones.

## What It Does

- Opens multichannel audio files (`.wav`, `.aif`, `.aiff`, `.caf`, `.flac`, `.m4a`)
- Splits source channels into mono point sources
- Places those sources in a 3D scene with `AVAudioEnvironmentNode`
- Renders a binaural headphone mix aimed at AirPods and other headphones
- Adds a light mastering chain so the result feels bigger and less flat
- Exposes tuning controls for front width, rear wrap, height lift, room blend, rear energy, bass, and presence

## Run It

```bash
cd "this repository"
swift build
swift run
```

Switch macOS audio output to AirPods or another headphone device before playback. The app follows the current system default output.

For Roon capture, select `BlackHole 64ch` inside Orbisonic's App Input menu. macOS Sound Input can stay on the built-in mic or another microphone for normal apps.

macOS will still show this as a microphone permission prompt because every app-level input device, including BlackHole, is covered by the same privacy gate. Granting that permission lets Orbisonic capture the selected App Input; it does not force the app to use the MacBook microphone.

## Head Tracking Note

The app enables Apple listener head tracking in code through `AVAudioEnvironmentNode`. Sensor-driven head tracking and personalized spatial audio profile access still require the matching entitlements in a properly signed Xcode target.

Use the included entitlement template if you open the package in Xcode:

- [Orbisonic.entitlements](./Orbisonic.entitlements)

Without those entitlements, the app still produces a fixed binaural spatial render.
