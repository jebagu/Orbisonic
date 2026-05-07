# Orbisonic Product Brief

## Project Name

Orbisonic.

## One-Sentence Description

Orbisonic is a native macOS control and rendering app for routing local and live multichannel audio into Sonic Sphere while keeping a separate monitor path for setup and preview.

## Problem Solved

Sonic Sphere needs a practical operator-facing tool that can accept local files and live player audio, inspect source and route health, render channel-bed or discrete multichannel material into the sphere's production topology, and provide enough monitoring feedback to diagnose routing problems without turning the app into a mixer or hiding audio failures.

## Target Users

- Sonic Sphere operators setting up and running multichannel playback.
- Audio engineers validating source layout, routing, monitor behavior, and production output readiness.
- Developers maintaining Orbisonic's native macOS audio path, renderer, and source integrations.
- Testers verifying local playback, Roon, Aux, Spotify, monitor, and installer behavior.

## Primary Use Cases

- Open and play local audio files and playlists.
- Inspect channel layout, format, metadata, artwork, and local queue state.
- Capture Roon live audio through the dedicated Roon loopback input.
- Capture general system or app audio through the Aux loopback input.
- Receive Spotify audio through the dedicated Spotify input and embedded librespot boundary.
- Route source channels into a Sonic Sphere renderer scene.
- Produce a Sonic Sphere 30.1 production output topology by default.
- Monitor audio through a headphone or normal stereo monitor path without changing the production topology.
- Display input, monitor, and renderer metering.
- Run channel-walk and diagnostic test tones.
- Diagnose route availability, sample-rate mismatch, channel-count mismatch, missing loopback devices, and silent live input.
- Package and reopen the app bundle through the repo scripts.

## Must-Have Features Already Represented By The App

- Native Swift/macOS app shell and SwiftUI interface.
- SwiftPM module split for shared contracts, import policy, pure audio logic, and the executable app.
- Local file loading, probing, streaming, gapless scheduling, and local music library support.
- Supported source-channel cap of 64 channels for local files and live input requests.
- Named surround and arbitrary discrete layout handling.
- Roon log parsing and optional local Roon Bridge transport control.
- Dedicated loopback source handling for Roon and Aux.
- Spotify receiver client and vendored librespot FFI integration.
- Sonic Sphere renderer model with 30.1 default topology.
- Direct 30/31-channel bypass behavior represented in renderer tests.
- Headphone or normal monitor path with downmix and Apple spatial-headphone hooks where supported.
- VU/metering surfaces for source, monitor, renderer, and diagnostics.
- Route monitoring, route repair support, diagnostic logs, web/public state, and app build metadata.
- App bundle refresh and LaunchServices reopen scripts.
- Installer packages for app-only and suite installs.
- Automated tests across contracts, import, core render planning, app integration, UI model behavior, and diagnostics.

## Post-Retrofit Follow-Up

- Roon API as the authoritative metadata and transport source, with log parsing retained only as fallback for signal-path data.
- Manual release verification for app-only installer, suite installer, LaunchServices, loopback devices, Roon, Spotify, Aux, monitor output, Sonic Sphere / Dante, microphone permission, signing, and entitlements.
- A recorded reference Sonic Sphere / Dante hardware setup for release verification.
- A product decision on whether release readiness requires the suite installer or whether the app-only installer can define a narrower milestone.
- A product decision on which Spotify receiver and transport behaviors count as stable.
- Future CI policy if the project moves beyond local SwiftPM verification.
- Continued revalidation of historical `docs/PureAudio/` claims before elevating them into current contracts.

## Explicit Out Of Scope

- Rewriting Orbisonic from scratch.
- Treating old prototype workspaces as the active product.
- Turning Orbisonic into a general-purpose DAW or arbitrary audio mixer.
- Adding simultaneous source mixing without an accepted mixer contract.
- Masking all-zero live input with synthetic signal, gain, buffering tricks, or fake channels.
- Silently changing public contracts or module boundaries.
- Decoding Dolby Atmos object metadata unless a future implementation explicitly adds and documents that capability.
- Making the headphone or monitor path the production output topology.
- Adding major dependencies during the control-doc retrofit.
- Requiring real Sonic Sphere, Dante, Roon, Spotify, or Aux hardware in automated tests.

## Stable Retrofit Success Criteria

- Project-control docs describe the current app without requiring source-code inspection.
- Module contracts and audio invariants are explicit and testable where possible.
- Existing and new tests protect the highest-risk source, renderer, monitor, sample-rate, channel-count, and diagnostic boundaries.
- Hardware-only checks are documented as manual verification rather than faked.
- Sonic Sphere 30.1 remains the primary production output target.
- Headphone or normal monitor behavior remains isolated from production topology.
- Roon, Aux, Spotify, and local file paths remain distinct unless a future contract changes that.
- Silent live input remains visible as a diagnosable failure state.
- App refresh, LaunchServices reopen, installer, and release verification steps are documented.
- `docs/status.md` remains the reliable project control panel.

## Constraints

- Work stays in the active Orbisonic repository unless explicitly directed otherwise.
- The app is native Swift/macOS and uses Swift Package Manager.
- The repo currently targets macOS 14 and Swift tools 5.10.
- The active package links embedded librespot FFI through a local static library artifact.
- Runtime loopback devices, Sonic Sphere / Dante output, Roon, Spotify, microphone permission, app signing, and installer behavior require environment-specific verification.
- Privacy hygiene requires repo-relative paths and no personal names, local usernames, secrets, or machine-specific absolute paths in tracked docs.
- Audio correctness and stability outrank UI polish.

## Assumptions

- Current source and tests represent the baseline product.
- Current README statements about supported formats, channel layouts, 64-channel cap, Sonic Sphere 30.1 output, and Atmos object metadata are accurate.
- Current AGENTS.md rules are binding for future Codex work.
- Current PureAudio docs are useful evidence but need revalidation before being elevated into global contracts.
- The retrofit docs, audits, focused tests, hardening passes, release-verification checklist, and readiness summary now describe the current baseline.
- The next release step is manual release verification in the target macOS, loopback, Roon, Spotify, monitor, Sonic Sphere, and Dante environment.

## Open Questions

- Which hardware configuration should define the reference Sonic Sphere / Dante manual verification checklist?
- Which current docs should be treated as accepted architecture versus historical migration context?
- What exact release-readiness standard should apply to the suite installer versus the app-only installer?
- How much Roon API work belongs in this retrofit versus a later integration milestone?
- What level of Spotify transport control should be considered stable for the retrofit milestone?
