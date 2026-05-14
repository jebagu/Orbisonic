# Release Gate And Default Switch Review

## Purpose

Task 019 reviews whether any implemented or prototyped Orbisonic path has enough evidence to become a default path.

The answer for this review is conservative:

```text
No new default switches are approved.
Rollback remains available.
The project is ready for implementation milestone review, not release-ready hardware signoff.
```

## Evidence Reviewed

Reviewed evidence:

```text
UI freeze contract and focused UI-freeze tests
audio-path invariants
module contracts
system flows
test strategy
status ledger
manual verification gates
release verification checklist
VLC licensing and packaging investigation notes
Task 000 through Task 018 completion records
```

Current automated evidence:

```text
focused UI-freeze tests pass
focused VLC live PCM prototype tests passed in Task 017
focused SourceAdapter and OrbisonicVLCReference tests passed in Task 017
full swift test was re-run on 2026-05-10 after the CoreAudio test isolation fix and passed with 648 tests, 0 failures
```

Current manual evidence:

```text
Dante Virtual Soundcard app is present
DVS HAL driver is present
DVS launch daemon is running
Dante Controller is not installed in /Applications
imported app and suite package artifacts were rebuilt and inspected before the canonical merge
imported package app payloads were stamped a81af94-dirty before the canonical merge
all three Orbisonic inputs can be opened for bounded capture, but measured silence
physical SonicSphere/Dante channel walk was not run
positive Roon, Spotify, and Aux source-audio captures were not proven
installer execution is blocked until administrator authentication is available
current release signing/notarization is blocked by missing signing identity and notarytool credentials
```

## Default Switch Decisions

| Area | Decision | Reason |
| --- | --- | --- |
| Existing UI | Keep frozen UI. | UI-freeze tests pass and no Task 019 evidence requires a UI change. |
| Local-file VLC monitor | Do not make real libVLC runtime integration a release default yet. | Guard/probe and callback contracts exist, but native libVLC bridge packaging, plugin discovery, signing/notarization, and license inventory are not release-proven. |
| Roon 5.1 VLC live PCM bridge | Keep proof-only and explicitly selected. | Task 017 proved deterministic harness behavior, but runtime latency, drift, clocking, and hardware/service behavior are not verified. |
| Roon stereo monitor | Keep stereo pass-through only when captured source is stereo. | This is already the safe contract and does not require a new downmix owner. |
| Spotify | Keep stereo boundary. | No accepted contract proves Spotify multichannel support. |
| SourceRateConverter | Keep deterministic reference converter as contract/test coverage, not final production SRC. | A production high-quality SRC dependency is still future work. |
| SonicSphere production | Keep strict route validation and fake/simulated evidence as implementation evidence, not hardware-ready proof. | Dante Controller and physical channel-walk gates are blocked or not run. |
| CoreAudio/DVS Dante path | Do not claim production hardware default readiness. | DVS is installed and running, but Dante Controller route, encoding, clock, latency, and physical output identity are unverified. |
| Pure Spherical Lossless | Keep direct playback limited to validated metadata and route-ready state. | It is not a default for generic high-channel files or filename-only candidates. |
| Installer/release artifacts | Do not call current artifacts release-ready. | Imported app and suite packages were rebuilt from a dirty tested tree and inspected before the canonical merge, but the merged repo still needs fresh package rebuild; installer execution is blocked by admin auth, package signing/notarization are blocked by missing credentials, and live hardware/service evidence is not proven. |

## Rollback Position

Rollback remains available because Task 019 made no source-code default changes.

Current rollback levers:

```text
default build remains safe when VLC is unavailable
VLC live PCM bridge remains explicitly selected, not default
Roon 5.1 monitor remains blocked unless an explicit owner is supplied
Pure Spherical Lossless remains metadata-gated
production route validation refuses unsafe routes before playback
manual gates remain required before hardware-ready claims
existing UI workflows remain unchanged
```

## Release Readiness Decision

Current decision:

```text
Not release-ready.
Not hardware-ready.
No new default switches.
Implementation milestone review is complete; next evidence must come from manual release gates.
```

Release readiness remains blocked by:

```text
Dante Controller not installed, so network route evidence is unavailable
no physical SonicSphere/Dante channel walk
no positive real Roon, Spotify, or Aux source-audio capture verification
no microphone permission verification
installer execution blocked until administrator authentication is available
current release signing/notarization blocked by missing signing identity and notarytool credentials
unresolved libVLC packaging, plugin discovery, and license inventory for any distributed VLC integration
production high-quality SRC dependency not selected or integrated
```

## Conditions Before Any Future Default Switch

Before any new path becomes default, require:

```text
focused tests for that path pass
full relevant suite passes or unrelated blockers are fixed/documented with a narrow exception
UI-freeze tests pass
audio-path invariants remain unchanged
manual hardware or service gate passes when the path depends on real devices/services
packaging, signing, notarization, and license obligations are documented
rollback path is still explicit
docs/status.md records the exact evidence
```
