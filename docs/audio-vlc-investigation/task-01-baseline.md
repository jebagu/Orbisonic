# Task 01 Baseline: Orbisonic Audio Playback And VLC Investigation

## Scope

This task establishes the investigation workspace and records the current repo baseline before deeper playback analysis. It does not change app code.

The prompt requested the repository root. The active root was verified with `pwd`, but this tracked note uses `<repo-root>` instead of the local absolute path because `AGENTS.md:148-151` forbids committing local usernames, machine-specific absolute paths, and personal folders to tracked files.

## Command Evidence

- `pwd`
- `git branch --show-current`
- `git rev-parse HEAD`
- `git status --short`
- `git log --oneline --decorate --extended-regexp --regexp-ignore-case --grep='modular|module|split|refactor|extract|engine|audio' -n 30`
- `find . -maxdepth 2 -type d -not -path './.git*' -not -path './.build*' -not -path './Orbisonic.app*' -print`
- `rg --files -g 'Package.swift' -g 'Package.resolved' -g 'package.json' -g 'package-lock.json' -g 'pnpm-lock.yaml' -g 'yarn.lock' -g 'requirements*.txt' -g 'pyproject.toml' -g 'Gemfile' -g 'Podfile' -g '*.xcodeproj' -g '*.xcworkspace'`
- `find Tests -maxdepth 3 -type f -print`
- `find Sources -maxdepth 2 -type f -print`
- `find Sources/Orbisonic/Resources -maxdepth 4 -type f -print`
- `find scripts -maxdepth 2 -type f -print`
- `find Vendor -maxdepth 3 -type f -print`
- `find calibration -maxdepth 2 -type f -print`
- `find installer -maxdepth 2 -type f -print`
- `rg -n "audio|playback|player|decoder|decode|renderer|render|route|router|channel|ambisonic|ambisonics|sphere|Sonic|Plex|Part.key|ffmpeg|libav|gstreamer|juce|libsndfile|resample|interleave|deinterleave|buffer|ring|callback|device|wasapi|alsa|coreaudio|asio|pulse|jack" . --glob '!/.git/**' --glob '!/.build/**' --glob '!Orbisonic.app/**' --glob '!archive/**' --glob '!deprecated/**' --glob '!.local/**'`
- `rg -n "audio|playback|player|decoder|decode|renderer|render|route|router|channel|ambisonic|ambisonics|sphere|Sonic|Plex|Part.key|ffmpeg|libav|gstreamer|juce|libsndfile|resample|interleave|deinterleave|buffer|ring|callback|device|wasapi|alsa|coreaudio|asio|pulse|jack" Sources Tests docs README.md Package.swift AGENTS.md`
- `rg -l "audio|playback|player|decoder|decode|renderer|render|route|router|channel|ambisonic|ambisonics|sphere|Sonic|Plex|Part.key|ffmpeg|libav|gstreamer|juce|libsndfile|resample|interleave|deinterleave|buffer|ring|callback|device|wasapi|alsa|coreaudio|asio|pulse|jack" Sources Tests docs README.md Package.swift AGENTS.md`

One exploratory command was mistyped before the quoted Git regex was rerun:

```sh
git log --oneline --decorate --extended-regexp --regexp-ignore-case --grep=modular|module|split|refactor|extract|engine|audio -n 30
```

The shell treated the unquoted `|` characters as command separators and returned `zsh:1: command not found` for the later terms. The corrected quoted command above produced the commit evidence below.

## Repository State

- Repository root: `<repo-root>`; verified by `pwd`.
- Branch: `main`; verified by `git branch --show-current`.
- Commit hash: `a81af94927857569d39e4e8a24abec391206abf1`; verified by `git rev-parse HEAD`.
- Pre-task dirty state: `git status --short` reported one untracked file, `orbisonic_vlc_codex_prompt_sequence.md`.
- Task-created dirty state: this investigation file and the parent directory are new after task execution.

## Recent Modularization And Audio-Related Commits

The corrected Git log query returned these recent matching commits:

- `a81af94 (HEAD -> main) 1.2 - orbisonic refactored`
- `8f2532b Add feature-gated local gapless playback`
- `8619203 pure audio stable`
- `9e5b647 pure audio branch 2 v 1`
- `cd15daa Integrate and harden Pure Audio architecture`
- `b267e44 Add Pure Audio copy-only metering telemetry`
- `58cdaae Add Pure Audio dual output adapter architecture`
- `0c954dc Add Pure Audio source adapters`
- `15df898 Add Pure Audio canonical bus and render kernels`
- `b9af469 Add immutable Pure Audio render graph plan`
- `a968df1 Add Pure Audio session and route validation`
- `e8754a9 Add AudioControl facade and AudioCore shell`
- `6fed762 Add Pure Audio architecture boundary tests`
- `728a95f Add Pure Audio contract types`
- `eb5b950 Pure Audio Branch 2 baseline architecture docs`
- `4063298 (codex/pure-audio-branch) End of current branch: codex/pure-audio-branch`
- `609b211 Enforce pure normal monitor audio path`

Initial implication: the relevant modularization history is not a single VLC/player replacement history. It is a PureAudio boundary and app-refactor history involving contracts, source adapters, render graph plans, output adapters, metering, and monitor separation.

## Top-Level Directory Map

The top-level map from `find . -maxdepth 2 ...` is:

- `.`
- `archive/`
- `archive/web-cruft/`
- `archive/bridge/`
- `calibration/`
- `.local/`
- `.local/orbisonic-launch-worktrees/`
- `Tests/`
- `Tests/AudioCoreTests/`
- `Tests/AudioImportTests/`
- `Tests/OrbisonicTests/`
- `Tests/AudioContractsTests/`
- `docs/`
- `docs/audits/`
- `docs/PureAudio/`
- `docs/decisions/`
- `scripts/`
- `Sources/`
- `Sources/Orbisonic/`
- `Sources/AudioContracts/`
- `Sources/AudioImport/`
- `Sources/AudioCore/`
- `.tasks/`
- `installer/`
- `Vendor/`
- `Vendor/librespot/`
- `Vendor/orbisonic-librespot-ffi/`
- `deprecated/`

`archive/`, `.local/`, `deprecated/`, `.build/`, `.git/`, and `Orbisonic.app/` were excluded from the main source-oriented baseline search where practical because they are historical, local, generated, or app-bundle outputs.

## Build System

- Primary build system: Swift Package Manager, from `Package.swift:1`.
- Package products: executable `Orbisonic` and libraries `AudioContracts`, `AudioImport`, and `AudioCore` from `Package.swift:10-26`.
- Main app target: executable target `Orbisonic` depends on `AudioContracts`, `AudioImport`, and `AudioCore`, processes resources, defines `ORBISONIC_ENABLE_EMBEDDED_LIBRESPOT`, and links Apple audio/system frameworks plus local `orbisonic_librespot_ffi` from `.build/orbisonic-librespot`; see `Package.swift:39-66`.
- Test targets: `OrbisonicTests`, `AudioContractsTests`, `AudioImportTests`, and `AudioCoreTests`; see `Package.swift:68-81`.

## Detected Languages And Artifact Types

- Swift: app, shared contracts, import policy, audio core, and XCTest files under `Sources/` and `Tests/`; confirmed by `find Sources ...` and `find Tests ...`.
- JavaScript: Roon bridge helper at `Sources/Orbisonic/Resources/RoonBridge/bridge.js`; confirmed by `find Sources/Orbisonic/Resources ...`.
- Shell: app refresh, reopen, Roon bridge install, ref launchers, installer build, and embedded librespot build scripts under `scripts/`.
- Rust and Cargo/TOML: vendored Spotify/librespot boundary under `Vendor/librespot/` and `Vendor/orbisonic-librespot-ffi/`; confirmed by `find Vendor ...`.
- Markdown: project docs, PureAudio docs, investigation prompt file, and resource notes.
- JSON: app-logo manifest, layout-icon manifest, calibration layouts, and Roon bridge package metadata.
- SVG/PNG/ICNS: app logos, layout icons, and app icon resources.
- PKG: installer artifacts under `installer/`.

## Package And Dependency Files

Detected package/dependency files from `rg --files`:

- `Package.swift`
- `archive/web-cruft/package.json`
- `archive/web-cruft/package-lock.json`
- `Sources/Orbisonic/Resources/RoonBridge/package.json`

Additional dependency manifests found in the vendor scan:

- `Vendor/librespot/Cargo.toml`
- `Vendor/librespot/Cargo.lock`
- `Vendor/librespot/rust-toolchain.toml`
- `Vendor/orbisonic-librespot-ffi/Cargo.toml`
- `Vendor/orbisonic-librespot-ffi/Cargo.lock`

`archive/web-cruft/` is historical archive material, not an active product dependency boundary according to `docs/implementation-map.md:21`.

## Test Directories

- `Tests/AudioContractsTests/`: shared audio vocabulary and contract-value tests.
- `Tests/AudioImportTests/`: local asset readiness/import tests.
- `Tests/AudioCoreTests/`: PureAudio planning, render, output, metering, and monitor tests.
- `Tests/OrbisonicTests/`: app runtime, source, renderer, monitor, route, diagnostics, local playback, and integration-boundary tests.

The test-strategy snapshot describes these same four test targets and approximate scopes in `docs/test-strategy.md:24-35`.

## Likely Native-Service Directories

- `Sources/Orbisonic/`: executable app, SwiftUI shell, AVAudioEngine owner, live loopback capture, Core Audio routes, local playback, source integrations, renderer, monitor, diagnostics, and web state. This responsibility is summarized in `docs/architecture.md:42-56`.
- `Sources/AudioContracts/`: shared audio vocabulary, validation, source/layout/session descriptors, meters, conversion ledgers, and audio errors; see `docs/architecture.md:21-25`.
- `Sources/AudioImport/`: local asset readiness and managed import policy; see `docs/architecture.md:27-32`.
- `Sources/AudioCore/`: deterministic audio planning, source adapters, render graph plans, render kernels, output adapters, metering telemetry, and Apple spatial monitor logic; see `docs/architecture.md:34-40`.
- `Sources/Orbisonic/Resources/RoonBridge/`: local Node helper for Roon transport control; see `docs/architecture.md:152-154`.
- `Vendor/librespot/` and `Vendor/orbisonic-librespot-ffi/`: embedded Spotify receiver boundary; see `docs/architecture.md:155-156`.
- `scripts/`: app bundle refresh, LaunchServices reopen, installer, Roon bridge dependency install, branch launcher, and embedded librespot build scripts; see `docs/architecture.md:201-209`.

## Likely Frontend And Control-Plane Directories

- `Sources/Orbisonic/ContentView.swift`: SwiftUI shell and current tabs; `AGENTS.md:173` and `docs/architecture.md:136-147`.
- `Sources/Orbisonic/DiagnosticsView.swift`: native diagnostics surface; `docs/architecture.md:145`.
- `Sources/Orbisonic/OrbisonicWebServer.swift`: local public/control web state; `AGENTS.md:181` and `docs/architecture.md:157`.
- `Sources/Orbisonic/Resources/RoonBridge/bridge.js`: Roon control helper; `docs/architecture.md:152-154`.
- `archive/web-cruft/`: archived web material, not active product source; `docs/implementation-map.md:21`.

## Obvious Audio-Related Modules From Filenames

Shared and PureAudio:

- `Sources/AudioContracts/AudioContracts.swift`
- `Sources/AudioImport/LocalAssetImport.swift`
- `Sources/AudioCore/AudioControl.swift`
- `Sources/AudioCore/AudioSessionPlanning.swift`
- `Sources/AudioCore/SourceAdapters.swift`
- `Sources/AudioCore/RenderGraphPlan.swift`
- `Sources/AudioCore/RenderKernels.swift`
- `Sources/AudioCore/OutputAdapters.swift`
- `Sources/AudioCore/MeteringTelemetry.swift`
- `Sources/AudioCore/Monitors/AppleSpatialHeadphoneMonitor.swift`

Executable app audio path and integrations:

- `Sources/Orbisonic/OrbisonicEngine.swift`
- `Sources/Orbisonic/AudioFileLoader.swift`
- `Sources/Orbisonic/AudioFileProbe.swift`
- `Sources/Orbisonic/LocalAudioFileSource.swift`
- `Sources/Orbisonic/StreamingAudioFileSource.swift`
- `Sources/Orbisonic/LocalGaplessScheduler.swift`
- `Sources/Orbisonic/LocalGaplessTypes.swift`
- `Sources/Orbisonic/MatroskaFLACSupport.swift`
- `Sources/Orbisonic/LiveAudioBridge.swift`
- `Sources/Orbisonic/LoopbackSourceSupport.swift`
- `Sources/Orbisonic/RendererModule.swift`
- `Sources/Orbisonic/RendererMatrixSampleRenderer.swift`
- `Sources/Orbisonic/NormalMonitorStereoDownmixer.swift`
- `Sources/Orbisonic/NormalMonitorGraphTopology.swift`
- `Sources/Orbisonic/NormalMonitorRouteDescriptor.swift`
- `Sources/Orbisonic/NormalMonitorConversionLedger.swift`
- `Sources/Orbisonic/OutputRouteMonitor.swift`
- `Sources/Orbisonic/BlackHoleRouteRepair.swift`
- `Sources/Orbisonic/MeteringService.swift`
- `Sources/Orbisonic/SpotifyReceiverClient.swift`
- `Sources/Orbisonic/RoonNowPlayingMonitor.swift`
- `Sources/Orbisonic/RoonBridgeClient.swift`
- `Sources/Orbisonic/TestToneSupport.swift`

Resources and external support:

- `Sources/Orbisonic/Resources/Tools/FFmpegTools.md`
- `Sources/Orbisonic/Resources/RoonBridge/bridge.js`
- `Vendor/librespot/`
- `Vendor/orbisonic-librespot-ffi/`
- `calibration/burning-man-sphere-speaker-layout.json`
- `calibration/chateau-du-fey-sphere-speaker-layout.json`

## Targeted Search Results

The full prompt search against `.` returned 9,595 lines even after excluding `.git`, `.build`, `Orbisonic.app`, `archive`, `deprecated`, and `.local`. It still included heavy `Vendor/librespot/` matches.

The scoped search against `Sources Tests docs README.md Package.swift AGENTS.md` returned 8,589 lines. The file-list form identified active matches across:

- app source: `Sources/Orbisonic/OrbisonicEngine.swift`, `AudioFileLoader.swift`, `LiveAudioBridge.swift`, `LoopbackSourceSupport.swift`, `RendererModule.swift`, `OutputRouteMonitor.swift`, `OrbisonicViewModel.swift`, `OrbisonicWebServer.swift`, `SpotifyReceiverClient.swift`, `RoonNowPlayingMonitor.swift`, and related monitor/metering files.
- PureAudio source: `Sources/AudioCore/SourceAdapters.swift`, `AudioSessionPlanning.swift`, `RenderGraphPlan.swift`, `RenderKernels.swift`, `OutputAdapters.swift`, `MeteringTelemetry.swift`, and `Monitors/AppleSpatialHeadphoneMonitor.swift`.
- shared/import source: `Sources/AudioContracts/AudioContracts.swift` and `Sources/AudioImport/LocalAssetImport.swift`.
- tests: all four test targets, with especially dense hits in `RendererModuleTests.swift`, `LiveAudioBridgeTests.swift`, `LoopbackSourceSupportTests.swift`, `NormalMonitor*Tests.swift`, `SonicSphereMeteringTests.swift`, `AudioCoreTests/*`, and local playback tests.
- docs: `docs/architecture.md`, `docs/contracts.md`, `docs/system-flows.md`, `docs/test-strategy.md`, `docs/orbisonic-loopback-input-support-spec.md`, `docs/PureAudio/*`, and ADRs.

No active-source `Plex` or `Part.key` owner was obvious from the scoped file-list search. Those terms need a narrower follow-up in Task 2 or Task 3 before concluding the Plex path is absent.

## Initial Hypotheses

### Where Playback Probably Starts

Playback likely starts in `Sources/Orbisonic/OrbisonicViewModel.swift`, which owns source selection and local transport commands. Evidence:

- `Sources/Orbisonic/OrbisonicViewModel.swift:583` defines `final class OrbisonicViewModel`.
- `Sources/Orbisonic/OrbisonicViewModel.swift:1693` defines `selectSourceMode(...)`.
- `Sources/Orbisonic/OrbisonicViewModel.swift:2435` defines `playLocalTransport()`.
- `Sources/Orbisonic/OrbisonicViewModel.swift:2505` defines `pauseLocalTransport()`.
- `Sources/Orbisonic/OrbisonicViewModel.swift:2575` defines `playLocalMusicTrackNow(...)`.
- `Sources/Orbisonic/OrbisonicViewModel.swift:3186` defines `playLocalMusicPlaylist(...)`.
- `Sources/Orbisonic/OrbisonicViewModel.swift:6349` defines `stop()`.

### Where Decode Probably Happens

Local-file decode probably happens through AVFoundation/Core Audio by default, with ffmpeg-assisted Matroska/FLAC fallback paths. Evidence:

- `Sources/Orbisonic/AudioFileLoader.swift:252-257` opens audio through `AVAudioFile`.
- `Sources/Orbisonic/AudioFileLoader.swift:199-207` probes and demuxes Matroska input before reading decoded CAF.
- `Sources/Orbisonic/AudioFileLoader.swift:226-243` has a forced FLAC ffmpeg fallback.
- `Sources/Orbisonic/AudioFileLoader.swift:279-302` falls back to ffmpeg when native FLAC open fails.
- `Sources/Orbisonic/MatroskaFLACSupport.swift:315-329` demuxes Matroska FLAC through ffmpeg into a temporary CAF.
- `Sources/Orbisonic/StreamingAudioFileSource.swift:314-327` opens streaming local sources through `AVAudioFile`.

Spotify decode is a separate embedded librespot boundary rather than the local-file loader path. Evidence: `docs/architecture.md:155-156` names `SpotifyReceiverClient.swift`, `Vendor/librespot/`, `Vendor/orbisonic-librespot-ffi/`, and `scripts/build-embedded-librespot.sh` as the embedded librespot boundary.

Live Roon and Aux capture probably do not decode inside Orbisonic; they capture already-produced PCM from Core Audio loopback devices. Evidence: `docs/system-flows.md:56-88` describes Roon metadata/transport as separate from `LiveAudioBridge` HAL capture, and `Sources/Orbisonic/LiveAudioBridge.swift:251-291` installs an input callback and writes captured audio into the live pipe.

### Where Channel Routing Probably Happens

Channel extraction and routing are split across loaders, live pipe, renderer, and monitor code:

- Local file full reads split multichannel buffers into mono buffers at `Sources/Orbisonic/AudioFileLoader.swift:476-514`.
- Streaming chunks track buffers and channel counts in `Sources/Orbisonic/StreamingAudioFileSource.swift:405-493`.
- Live input writes per-channel float data into rings at `Sources/Orbisonic/LiveAudioBridge.swift:598-623`.
- Live renderer reads ring channels and renders through a matrix at `Sources/Orbisonic/LiveAudioBridge.swift:655-684`.
- `Sources/Orbisonic/RendererModule.swift:631` defines `RendererMatrix`.
- `Sources/Orbisonic/RendererModule.swift:710-711` defines `SonicSphereAudioRenderer.render(inputChannels:matrix:)`.
- `Sources/Orbisonic/RendererModule.swift:987-991` identifies `FeyStaticBedRenderer` as a static channel-bed renderer for already-decoded PCM beds into the FEY 30.1 sphere.

### Where Device Output Probably Happens

Device output likely happens through `OrbisonicEngine` and Core Audio/HAL support:

- `Sources/Orbisonic/OrbisonicEngine.swift:232` defines `final class OrbisonicEngine`.
- `Sources/Orbisonic/OrbisonicEngine.swift:241` owns an `AVAudioEngine`.
- `Sources/Orbisonic/OrbisonicEngine.swift:301` defines `loadPreparedFile(...)`.
- `Sources/Orbisonic/OrbisonicEngine.swift:515` defines `startLiveInput(...)`.
- `Sources/Orbisonic/OrbisonicEngine.swift:740-765` selects an output device through the engine output node's audio unit.
- `Sources/Orbisonic/LiveAudioBridge.swift:105-220` creates and configures a HAL input unit for live capture, not output.
- `Sources/Orbisonic/OutputRouteMonitor.swift` is the obvious Core Audio route discovery module from filename and `AGENTS.md:179`.

### Where Modularization May Have Changed Ownership Boundaries

The PureAudio commits and current package target map suggest modularization moved shared vocabulary, import policy, planning, render kernels, output adapters, and metering into package targets while leaving the concrete app engine and platform integrations in the executable:

- `Package.swift:10-26` defines libraries for `AudioContracts`, `AudioImport`, and `AudioCore`.
- `docs/architecture.md:13-18` describes those modules plus the executable `Orbisonic` target.
- Recent commits include `e8754a9 Add AudioControl facade and AudioCore shell`, `728a95f Add Pure Audio contract types`, `15df898 Add Pure Audio canonical bus and render kernels`, `58cdaae Add Pure Audio dual output adapter architecture`, and `b267e44 Add Pure Audio copy-only metering telemetry`.

Initial high-risk boundary candidates:

- local decode and full-buffer loading in `AudioFileLoader.swift`;
- streaming scheduler ownership in `OrbisonicEngine.swift`;
- live callback-to-ring-buffer transfer in `LiveAudioBridge.swift`;
- matrix rendering and direct 30/30.1 bypass ownership in `RendererModule.swift`;
- normal monitor downmix and production topology separation across `NormalMonitor*` and renderer files;
- metering copies, because `AGENTS.md:103` requires metering to avoid consuming live playback buffers.

## Architecture Decision Notes

### Visible Boundaries

- `AudioContracts` is a shared vocabulary layer, not an app or device owner; `docs/contracts.md:14-52`.
- `AudioImport` owns local asset readiness/import policy and must not mutate live render graphs; `docs/contracts.md:54-91`.
- `AudioCore` owns deterministic planning, adapters, render graph plans, render kernels, output adapters, and metering telemetry; `docs/contracts.md:93-132`.
- `Orbisonic` executable owns SwiftUI state, app orchestration, AVAudioEngine, live capture, route discovery, integrations, diagnostics, web state, resources, and packaging runtime code; `docs/contracts.md:134-173`.
- Local file playback and live loopback capture are separate paths; `AGENTS.md:97` and `docs/contracts.md:11`.
- Roon, Spotify, Aux, local files, and test tones are selected-source paths, not a mixer; `docs/contracts.md:12`.
- Sonic Sphere 30.1 is production output; monitor/headphone output is preview/setup and must not redefine production topology; `AGENTS.md:99` and `docs/contracts.md:13-14`.

### Boundaries That Look Intentional

- SwiftPM target direction is intentional: package products and target dependencies are explicit in `Package.swift:10-81`.
- PureAudio docs and tests intentionally protect lower-level target independence and boundary ownership; `docs/test-strategy.md:24-35` and `docs/test-strategy.md:37-83`.
- Selected-source behavior is an accepted decision, not incidental UI state; `docs/decisions/0004-selected-source-only-rule.md` was found in the ADR list.
- Sonic Sphere 30.1 production output is an accepted decision; `docs/decisions/0005-sonic-sphere-30-1-primary-output.md` was found in the ADR list.
- Roon loopback capture is intentionally separate from Roon metadata and transport control; `docs/system-flows.md:56-88`.

### Boundaries That Look Risky For Audio Quality

- The local full-read path still has a logged migration target: `Sources/Orbisonic/AudioFileLoader.swift:390` records "blocking AVAudioFile full read remains streaming migration target."
- Local decode can pass through multiple fallback paths: native AVAudioFile, Matroska ffmpeg demux, and FLAC ffmpeg decode. Those transitions may affect sample format, channel order, metadata, or temp-file behavior; see `Sources/Orbisonic/AudioFileLoader.swift:199-243` and `Sources/Orbisonic/AudioFileLoader.swift:279-302`.
- Live capture crosses a realtime HAL callback boundary into ring buffers at `Sources/Orbisonic/LiveAudioBridge.swift:251-291` and `Sources/Orbisonic/LiveAudioBridge.swift:598-623`. That boundary is sensitive to sample format, ring sizing, underflow, and dropped-frame accounting.
- `OrbisonicEngine` owns scheduling, retained buffers, player nodes, and renderer scene state in one concrete runtime owner; see `Sources/Orbisonic/OrbisonicEngine.swift:121-127`, `Sources/Orbisonic/OrbisonicEngine.swift:232-267`, and `Sources/Orbisonic/OrbisonicEngine.swift:1667-1742`.
- The normal monitor path is separate by contract, but any accidental route or graph coupling could make bad audio appear only on monitor output or only on production output; `docs/test-strategy.md:73-83` lists monitor and renderer protections and remaining manual route verification.

### Boundaries That Look Risky For 30 Or 52 Channels

- The app documents a 64-source-channel cap in `README.md:42-44`, which should admit a 52-channel source in principle, but that does not prove the entire decode, scheduler, renderer, and output path preserves 52 independent channels.
- Direct renderer modes are only named for Direct 30 and Direct 30.1; `Sources/Orbisonic/RendererModule.swift:119-121`. A 52-channel input likely cannot use the direct 30/31 bypass without an explicit future contract.
- The Sonic Sphere production topology is currently 30.1 by default; `README.md:46-50` and `Sources/Orbisonic/RendererModule.swift:543-544`.
- `FeyStaticBedRenderer` explicitly says it is for already-decoded PCM beds into the FEY 30.1 sphere and does not decode object metadata or add adaptive DSP; `Sources/Orbisonic/RendererModule.swift:987-988`.
- Live capture uses a channel-count cap and per-channel rings; `Sources/Orbisonic/LiveAudioBridge.swift:33-38` and `Sources/Orbisonic/LiveAudioBridge.swift:540-560`. It needs follow-up validation for requested 30, 31, and 52 channel shapes.

## Next Task Focus

Task 2 should produce the full current pipeline map:

`media location -> opener/fetcher -> demuxer -> decoder -> PCM converter -> resampler -> channel mapper -> spatial renderer -> device backend -> OS/hardware`

The immediate files to inspect first are:

- `Sources/Orbisonic/OrbisonicViewModel.swift`
- `Sources/Orbisonic/OrbisonicEngine.swift`
- `Sources/Orbisonic/AudioFileLoader.swift`
- `Sources/Orbisonic/StreamingAudioFileSource.swift`
- `Sources/Orbisonic/LocalAudioFileSource.swift`
- `Sources/Orbisonic/AudioFileProbe.swift`
- `Sources/Orbisonic/MatroskaFLACSupport.swift`
- `Sources/Orbisonic/LiveAudioBridge.swift`
- `Sources/Orbisonic/LoopbackSourceSupport.swift`
- `Sources/Orbisonic/RendererModule.swift`
- `Sources/Orbisonic/NormalMonitorStereoDownmixer.swift`
- `Sources/Orbisonic/OutputRouteMonitor.swift`
- `Sources/AudioCore/SourceAdapters.swift`
- `Sources/AudioCore/RenderGraphPlan.swift`
- `Sources/AudioCore/RenderKernels.swift`
- `Sources/AudioCore/OutputAdapters.swift`
