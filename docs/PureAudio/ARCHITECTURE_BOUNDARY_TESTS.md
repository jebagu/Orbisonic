# Architecture Boundary Tests

The Pure Audio rewrite is governed by one rule:

```text
Only AudioCore mutates audio.
Everything else requests changes or observes snapshots.
```

The architecture boundary tests make that rule executable during migration. They run in the normal Swift test workflow and scan Swift source files only. Markdown docs, resources, generated assets, and test fixtures are not scanned as production source.

## What The Tests Scan

The tests in `Tests/OrbisonicTests/PureAudioArchitectureBoundaryTests.swift` scan:

- `Sources/AudioContracts`
- `Sources/Orbisonic`
- Future `Sources/AudioCore`
- Future `Sources/Orbisonic/AudioCore`

They look for forbidden implementation imports and live-audio symbols such as:

- `AVAudioEngine`
- `AVAudioNode`
- `AVAudioMixerNode`
- `AVAudioPlayerNode`
- `AVAudioSourceNode`
- `AVAudioEnvironmentNode`
- `AVAudioPCMBuffer`
- `AVAudioFile`
- `AVAudioConverter`
- `AudioUnit`
- `AudioDeviceID`
- `AudioBufferList`
- Float pointer types
- `RendererMatrix`
- ring buffer and `LiveAudioPipe` types
- graph mutation calls such as `installTap`, `connect`, and `disconnect`
- `mainMixerNode` and `outputNode`

The tests also check that future `AudioCore` code does not import UI frameworks.

## Boundary Tests

The current boundary test suite includes:

- `testAudioContractsHasNoAudioImplementationImports`
- `testUIAndViewModelsDoNotOwnAudioGraph`
- `testVUDisplayDoesNotOwnAudioGraph`
- `testAudioImportDoesNotOwnLiveOutput`
- `testAudioCoreDoesNotImportUI`
- `testForbiddenAudioSymbolsAreNotUsedOutsideAllowlist`

These tests are intentionally source scanners. They are not audio behavior tests. Their job is to stop future code from adding the wrong dependency in the wrong layer.

## Migration Allowlist

The single source of truth for migration exceptions is:

```text
Tests/OrbisonicTests/ArchitectureBoundaryAllowlist.swift
```

Allowlist entries are explicit by file and forbidden pattern ID. Avoid adding a whole folder when one file or one symbol is enough.

Current migration exceptions include:

- `OrbisonicEngine.swift`: legacy graph owner until `AudioCore` replaces direct `AVAudioEngine` mutation.
- `LiveAudioBridge.swift`: legacy live capture, ring buffer, and pipe implementation until live adapters move into `AudioCore`.
- `OutputRouteMonitor.swift`: legacy Core Audio route discovery until route descriptors move behind `AudioCore`.
- `BlackHoleRouteRepair.swift`: legacy device repair until route mutation moves behind `AudioCore`.
- `MeteringService.swift`: legacy meter ingestion still accepts PCM buffers; final VU code must consume `MeterSnapshot` only.
- `RendererModule.swift` and `RendererMatrixSampleRenderer.swift`: legacy Sonic Sphere matrix/meter projection code. This is analysis/metering support, not connected Dante output.
- `AudioFileLoader.swift`, `AudioFileProbe.swift`, `StreamingAudioFileSource.swift`, `MatroskaFLACSupport.swift`, `LocalMusicLibrary.swift`, `SurroundSupport.swift`, and `TestToneSupport.swift`: current file probing, decoding, layout, and diagnostic asset support. These are treated as `AudioImport` compatibility files.
- `OrbisonicViewModel.swift`: legacy view model still imports `AVFoundation` for audio permission status and observes legacy pipe status. This must be removed in a later migration.

Prompt 12 tightened the allowlist:

- The `OrbisonicViewModel.swift` `AVAudioEngine` symbol exception was removed.
- The view model still has a temporary `AVFoundation` import exception.
- The view model still has a temporary legacy live pipe status exception.
- New local-file production gating lives in `LegacyLocalFileProductionGate.swift`, which does not require graph-handle allowlist entries.

## How To Add A Legitimate Allowlist Entry

Only add an allowlist entry when all of these are true:

1. The file is part of legacy audio implementation, future `AudioCore`, or future `AudioImport`.
2. The file cannot be moved behind a contract in the same prompt without destabilizing behavior.
3. The entry is file-specific and pattern-specific.
4. The reason is documented in `migrationExceptionNotes` or belongs to one of the named compatibility groups.
5. The entry does not allow UI or VU display code to mutate audio.

When adding a new exception, prefer moving the code into `AudioCore` or `AudioImport` first.

## What Must Never Be Allowlisted

Never allowlist:

- `AudioContracts` importing audio implementation frameworks.
- UI or VU display code owning `AVAudioEngine`.
- UI or VU display code installing taps.
- UI or VU display code receiving PCM pointers.
- UI or VU display code owning render buffers.
- Metadata parsers mutating routes, graph nodes, output devices, or session state.
- Desktop monitor failure paths that can perturb Dante production output.
- Hidden production sample-rate conversion.

If one of these appears, treat it as an architecture violation, not a migration exception.

Prompt 12 adds one more hard rule: feedback-loop risk routes must never be allowlisted as valid production routes. They must be blocked by planning or route validation.

## AudioImport Rule

AudioImport compatibility files may probe, decode, and prepare offline assets. They may use `AVAudioFile`, `AVAudioConverter`, file I/O, `ffmpeg`, or `ffprobe`.

They must not own live output. The boundary tests reject live-output symbols in import files, including `AVAudioEngine`, mixer nodes, `AudioUnit`, `AudioDeviceID`, output nodes, graph connections, and taps.

## AudioCore Rule

Future `AudioCore` may own live audio implementation details, but it must not import UI.

`AudioCore` must expose typed commands and read-only snapshots. It must not depend on SwiftUI views, AppKit windows, view models, web state, or UI binding types.

The current `OrbisonicEngine.swift` `AppKit` import is a migration exception only. Future AudioCore files should not copy that dependency.

## Metering Rule

Final VU code consumes `MeterSnapshot` values only.

The meter display must never receive:

- `AVAudioPCMBuffer`
- `AudioBufferList`
- ring buffers
- `UnsafeMutablePointer<Float>`
- `UnsafeBufferPointer<Float>`
- graph nodes
- tap handles

The final meter copy happens inside `AudioCore` and publishes lossy snapshots. VU display updates may be dropped. They must never block, mutate, or back-pressure audio rendering.

## Why This Protects Dante

Dante is the production path. The desktop monitor and VU displays are confidence surfaces.

These tests protect Dante by preventing UI, VU, metadata, and view-model code from gaining live graph handles. If a future VU rewrite breaks, it can break only the display. It cannot install taps, mutate buffers, change output routes, rewire the graph, or alter the Dante render callback.
