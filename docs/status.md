# Orbisonic Status

## Current Phase

Post-retrofit readiness / manual release verification.

## Current Milestone

Partial manual release verification complete; next milestone is clean signed installer rebuild plus hardware/service verification.

## Project Summary

Orbisonic is a native macOS app for routing, monitoring, and rendering multichannel spatial audio for Sonic Sphere. The current app opens local audio files and playlists, captures live audio from dedicated loopback inputs, presents Roon, Spotify, Atmos DRP, Aux, and local source workflows separately, renders channel-bed or discrete multichannel sources toward a Sonic Sphere 30.1 production topology, and provides a headphone or normal monitor path for setup and preview.

This retrofit does not rewrite the app. It adds control documents, contracts, audits, tasks, and tests around the current implementation so future changes stay bounded and audio-safe.

## Completed Items Visible In The Repo

- Native Swift Package Manager app with an `Orbisonic` executable target.
- Library targets for `AudioContracts`, `AudioImport`, and `AudioCore`.
- Test targets for `OrbisonicTests`, `AudioContractsTests`, `AudioImportTests`, and `AudioCoreTests`.
- Existing app bundle at `Orbisonic.app`.
- App refresh, reopen, installer, Roon bridge, and embedded librespot scripts under `scripts/`.
- Packaged app and suite installers under `installer/`.
- Local file playback and local library support in `Sources/Orbisonic/`.
- Live loopback capture and source support in `Sources/Orbisonic/LiveAudioBridge.swift` and `Sources/Orbisonic/LoopbackSourceSupport.swift`.
- Roon metadata and transport bridge support in `Sources/Orbisonic/RoonNowPlayingMonitor.swift`, `Sources/Orbisonic/RoonBridgeClient.swift`, and `Sources/Orbisonic/Resources/RoonBridge/`.
- Spotify receiver support in `Sources/Orbisonic/SpotifyReceiverClient.swift` with vendored librespot sources under `Vendor/`.
- Atmos DRP source support in `Sources/Orbisonic/DolbyReferencePlayerController.swift`, with `SourceMode.atmosDRP` displayed as `Atmos`, temporary Aux loopback routing through `AtmosDRPRoutingPolicy`, and DRP bitstream metadata in app/web state.
- Pinned Atmos first-pass launcher at `Open Orbisonic - Atmos First Pass.command`, using the existing isolated launcher helper against commit `76ca882`.
- Renderer, monitor, metering, diagnostics, route monitoring, and test tone support in current source and tests.
- PureAudio boundary, sample-rate, conversion-ledger, Apple spatial monitor, and system-flow docs under `docs/PureAudio/`.
- Loopback input support spec, embedded librespot integration notes, local gapless playback plan, release notes, calibration layouts, and VU design-lab spec.
- Sequential retrofit and hardening task graph under `.tasks/`.
- Plan audit report under `docs/audits/0001-plan-audit.md`.
- Contract-test gap audit report under `docs/audits/0002-contract-test-gap-audit.md`.
- Release verification checklist under `docs/release-verification.md`.
- First contract-test gap pass under `Tests/OrbisonicTests/OrbisonicWebStateTests.swift`, covering selected Roon, Spotify, and Aux no-signal web/control status.
- Architecture boundary test pass under `Tests/OrbisonicTests/PureAudioArchitectureBoundaryTests.swift`, covering SwiftPM dependency direction, lower-target runtime leakage, source-integration renderer ownership, and monitor/production topology separation.
- Live loopback diagnostic snapshot coverage under `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift`, covering route mismatch, sample-rate mismatch, channel-count mismatch, permission denial, buffer counters, and Roon playback activity separate from captured audio.
- Source isolation hardening under `Tests/OrbisonicTests/OrbisonicWebStateTests.swift`, covering stale local snapshot cleanup when switching to Off or Test Tone and Spotify's fixed stereo boundary when stale local multichannel metadata exists.

## In Progress Items

- `.tasks/012-manual-release-verification.md` is partially complete and blocked on clean signed installer artifacts plus hardware and external-service checks.
- The current repo-root app bundle has been refreshed, and the installed `/Applications/Orbisonic.app` launches through LaunchServices.

## Pending Follow-Up Tasks

- Rebuild signed installer artifacts from a clean tested commit, then finish `.tasks/012-manual-release-verification.md` before calling a release candidate ready.
- Revalidate historical `docs/PureAudio/` claims before elevating any historical migration note into a binding contract.

## Blocked Items

- No documentation-refresh blocker is known.
- Release readiness is blocked until package artifacts match the tested code, packages are signed if public distribution requires it, and hardware/service verification is run and recorded.
- Hardware-only verification is not available from docs inspection alone and must remain manual until tested with the relevant devices.

## Current Risks

- Live loopback routing failures can make Roon, Aux, or Spotify appear active while captured audio is silent.
- Roon logs can show playback even when Orbisonic loopback capture is not receiving audio.
- Sample-rate mismatch between a source, loopback input, monitor route, or Sonic Sphere output can break live capture or production rendering.
- Channel-count mismatch can cause source admission, renderer, or output-route failures.
- Renderer topology regressions could alter Sonic Sphere 30.1 behavior.
- Monitor path changes could accidentally mutate production output behavior.
- Roon, Spotify, Atmos DRP, Aux, and local source states could leak into one another if source isolation is not protected.
- Existing docs are feature-specific and may be stale relative to current source.
- Future Codex sessions must follow the upgraded `AGENTS.md` discipline to avoid broad rewrites, stale workspace drift, or unverified audio changes.
- Embedded librespot linking depends on the local Rust-built static library being present in `.build/orbisonic-librespot`.
- Sonic Sphere, Dante, loopback devices, Spotify receiver, Roon bridge, app signing, and installer behavior all require manual runtime verification beyond unit tests.
- Real Dolby Reference Player/iLok behavior, Atmos playback, and loopback capture for the Atmos source require manual runtime verification beyond unit tests.
- Current package files are unsigned.
- The refreshed repo-root app bundle is stamped from a dirty working tree.
- The installed package app is stamped `8ffa977`, while the tested working tree is `64f7fea` with uncommitted changes.

## Recent Changes

- 2026-05-10: Added a separate `Atmos` source for Dolby Reference Player playback with modular DRP process ownership, temporary Aux loopback routing policy, output-layout setting, DRP metadata parsing, native/web state exposure, and focused tests. Real DRP/iLok and Atmos playback verification remain manual.
- 2026-05-07: Added Task 16 final VLC/Orbisonic technical report under `docs/audio-vlc-investigation/`, recommending no VLC integration yet, defining native playback diagnostics and reference comparison as the next engineering step, and preserving VLC only as a conditional later decode bridge or diagnostic baseline; no app code changed.
- 2026-05-07: Added Task 15 prototype plan under `docs/audio-vlc-investigation/`, recommending no VLC integration yet until the current Orbisonic playback fault is isolated, defining PR-sized diagnostics/reference/channel-identity steps before any guarded libVLC work, and documenting rollback/safety requirements; no app code changed.
- 2026-05-07: Added Task 14 licensing/dependency/packaging risk analysis under `docs/audio-vlc-investigation/`, finding Path B has the lowest legal/packaging risk, Path A is the lowest-risk VLC dependency if VLC is still needed, and custom VLC module or copied-source work requires explicit legal review; no app code changed.
- 2026-05-07: Added Task 13 Path C/D evaluation under `docs/audio-vlc-investigation/`, concluding full VLC playback is useful as a diagnostic baseline while stock VLC memory/custom-output paths do not improve on the public callback bridge and do not prove 30/52-channel Orbisonic routing; no app code changed.
- 2026-05-07: Added Task 12 Path B native output-backend design under `docs/audio-vlc-investigation/`, defining an Orbisonic-owned output-session lifecycle inspired by VLC's `audio_output_t` for format negotiation, timing, queueing, flush/drain, channel identity, and rollback; no app code changed.
- 2026-05-07: Added Task 11 Path A libVLC decode-bridge design under `docs/audio-vlc-investigation/`, defining a bounded `LibVlcAudioSource`/`DecodedPcmRingBuffer` architecture where VLC can replace media opening/demux/decode without owning Orbisonic layout, renderer, or output; no app code changed.
- 2026-05-07: Added Task 10 Orbisonic/VLC architecture decision comparison under `docs/audio-vlc-investigation/`, ranking decode/conversion, output negotiation, channel layout, buffer scheduling, gain/mix, and resampling/clocking as diagnostic root-cause hypotheses; no app code changed.
- 2026-05-07: Added Task 09 VLC channel feasibility analysis under `docs/audio-vlc-investigation/`, finding VLC's mapped speaker model is capped at 9 channels, stock `amem` callbacks are capped at 8 output channels, and 30/52-channel Orbisonic custom layouts are not proven preserved end to end; no app code changed.
- 2026-05-07: Added Task 08 VLC `audio_output_t` and backend analysis under `docs/audio-vlc-investigation/`, identifying lifecycle, timing, device-selection, shared-mode, high-channel, and pro-audio concepts Orbisonic can imitate without reusing VLC output backends; no app code changed.
- 2026-05-07: Added Task 07 libVLC callback decode-bridge analysis under `docs/audio-vlc-investigation/`, concluding stock `amem` callbacks can suppress OS output and deliver PCM but do not support 30-channel or 52-channel callback output as inspected; no Orbisonic app code changed.
- 2026-05-07: Added Task 06 VLC source architecture map under `docs/audio-vlc-investigation/`, based on external current VLC and VLC 3.0 shallow checkouts; no Orbisonic app code changed.
- 2026-05-07: Added Task 05 reference-media and objective test-harness design under `docs/audio-vlc-investigation/`, defining deterministic fixture assets, generator pseudocode, acceptance tolerances, and architecture-diagnosis coverage; no app code changed.
- 2026-05-07: Added Task 04 bad-audio reproduction plan under `docs/audio-vlc-investigation/`, defining objective failure classes, reproduction matrix coverage, existing diagnostics, and later instrumentation hook points; no app code changed.
- 2026-05-07: Added Task 03 playback module boundary analysis under `docs/audio-vlc-investigation/`, separating Orbisonic transport, media opening, decode, PCM conversion, resampling, channel mapping, spatial renderer, device output, timing, and flush/drain ownership; no app code changed.
- 2026-05-07: Added Task 02 Orbisonic playback architecture map under `docs/audio-vlc-investigation/`, covering local prepared playback, streaming/gapless playback, live loopback capture, renderer/metering, device backend, and PureAudio boundary evidence; no app code changed.
- 2026-05-07: Started `docs/audio-vlc-investigation/` with Task 01 baseline for the Orbisonic playback and VLC/libVLC replacement investigation; no app code changed.
- 2026-05-04: Prompt 02 created baseline project-control docs: `docs/status.md` and `docs/product-brief.md`.
- 2026-05-04: Prompt 03 created `docs/architecture.md` and `docs/implementation-map.md`, and updated this status file.
- 2026-05-04: Prompt 04 created `docs/contracts.md`, including module and feature-boundary contracts for audio contracts, import, core audio, app shell, engine, live loopback, local files, Roon, Spotify, Aux, renderer, monitor, diagnostics, and installer scripts.
- 2026-05-04: Prompt 05 created `docs/system-flows.md` with Mermaid diagrams for system context, local files, Roon, Spotify, Aux, renderer, monitor, diagnostics, test tones, logging, and manual hardware verification.
- 2026-05-04: Prompt 06 created `docs/test-strategy.md` with the test target map, contract-to-test map, critical audio invariants, required commands, manual verification requirements, fixture rules, coverage expectations, and known test gaps.
- 2026-05-04: Prompt 07 created retrospective ADRs under `docs/decisions/` covering retrofit-not-rewrite, SwiftPM target boundaries, AudioContracts as shared language, selected-source-only behavior, Sonic Sphere 30.1 production output, embedded librespot, and Roon loopback boundaries.
- 2026-05-05: Prompt 08 upgraded `AGENTS.md` into the repo-level operating constitution while preserving Orbisonic scope, privacy, LaunchServices, live audio, Roon, Aux, Sonic Sphere, and design rules.
- 2026-05-05: Prompt 09 created the `.tasks/` control graph for audit, accepted doc fixes, contract-test gap work, boundary tests, audio hardening, installer/release verification docs, and final readiness refresh.
- 2026-05-05: Prompt 10 created `docs/audits/0001-plan-audit.md` with prioritized findings comparing project-control docs, tasks, source evidence, and tests.
- 2026-05-05: Prompt 11 applied accepted plan-audit fixes to docs and tasks, clarified project-control completion rules, updated task verification, refreshed stale project-control wording, and documented the carried-forward README setup issue.
- 2026-05-05: Prompt 12 created `docs/audits/0002-contract-test-gap-audit.md`, identified selected live-source no-signal diagnostics as the first useful test gap, and updated `docs/test-strategy.md`.
- 2026-05-05: Prompt 13 updated `Tests/OrbisonicTests/OrbisonicWebStateTests.swift` with deterministic selected live-source no-signal coverage for Roon, Spotify, and Aux, and updated project-control docs for the new coverage.
- 2026-05-05: Prompt 14 strengthened `Tests/OrbisonicTests/PureAudioArchitectureBoundaryTests.swift` and `ArchitectureBoundaryAllowlist.swift` to protect SwiftPM dependency direction, lower-target runtime leakage, source-integration renderer ownership, and monitor/production topology separation.
- 2026-05-05: Prompt 15 added `LiveLoopbackDiagnostics`, surfaced capture diagnosis rows in Diagnostics, enriched silent-input warning logs, and added deterministic tests for route, sample-rate, channel-count, permission, buffer-counter, and player-activity separation cases.
- 2026-05-05: Prompt 16 hardened source transitions so Off and Test Tone clear stale local playback snapshots, kept Spotify health reporting inside the fixed stereo boundary, and added deterministic web-state tests for those source-isolation cases.
- 2026-05-05: Prompt 17 hardened the renderer/monitor boundary so normal-monitor route selection is explicitly independent from production renderer modes, including Direct 30/31, and added deterministic tests that monitor planning leaves the Sonic Sphere 30.1 scene topology unchanged.
- 2026-05-05: Prompt 18 created `docs/release-verification.md`, updated release/setup documentation for `Orbisonic Spotify Input`, and connected release verification to the implementation map, test strategy, and task graph.
- 2026-05-05: Prompt 19 created `docs/readiness-summary.md`, refreshed stale project-control claims, marked task status drift, added `.tasks/012-manual-release-verification.md`, and set manual release verification as the next action.
- 2026-05-07: Task 012 partially verified the current release candidate: full SwiftPM suite passed, repo-root app bundle refresh passed, app-only and suite installers passed from `/private/tmp`, installed app verification passed, all three HAL drivers installed as `0.2.0`, Roon bridge dependency install passed, Core Audio sees all three Orbisonic inputs, and remaining clean-package / hardware / service checks were recorded as blockers.
- 2026-05-07: Added `Open Orbisonic - Release - v1.1.command`, a root double-click launcher for the `v1.1` tag using the existing isolated per-ref launcher helper.

## Commands Run

- `sed -n '1,140p' AGENTS.md`
- `sed -n '1,140p' README.md`
- `sed -n '1,120p' Package.swift`
- `find docs Sources Tests -maxdepth 2 -type f | sort`
- `find Sources Tests docs scripts installer Vendor calibration -maxdepth 3 -type f | sort`
- `rg -n "^(public |private |fileprivate |internal )?(final class|class|struct|enum|protocol|actor)|^@main" Sources/AudioContracts Sources/AudioImport Sources/AudioCore`
- `rg -n "^(public |private |fileprivate |internal )?(final class|class|struct|enum|protocol|actor)|^@main" Sources/Orbisonic`
- `rg -n "^#|^##|^###" docs/*.md docs/PureAudio/*.md README.md RELEASE_NOTES.md`
- `rg -n "^import " Sources Tests | sort`
- `git status --short`
- `git diff --name-only -- AGENTS.md README.md Package.swift Sources Tests scripts installer Vendor calibration`
- Privacy-sensitive path/name scan across new project-control docs.
- `rg -n "[ \t]+$" docs/status.md docs/product-brief.md docs/architecture.md docs/implementation-map.md`
- `git diff --check`
- `sed -n '1,180p' AGENTS.md`
- `sed -n '1,180p' README.md`
- `sed -n '1,140p' Package.swift`
- `sed -n '1,220p' docs/status.md`
- `sed -n '1,320p' docs/architecture.md`
- `sed -n '1,380p' docs/implementation-map.md`
- `find Sources/AudioContracts Sources/AudioImport Sources/AudioCore Sources/Orbisonic Tests -maxdepth 3 -type f | sort`
- `rg -n "SourceMode|OrbisonicLoopbackDevice|RendererAudioRoutingPolicy|RendererRenderMode|NormalMonitor|Roon|Spotify|Aux|source-channel|64|Direct 30|direct30|direct31|AudioError|ConversionLedger|LiveAudioSignalState|SampleRate|sample rate|channel count" Sources/AudioContracts Sources/AudioImport Sources/AudioCore Sources/Orbisonic Tests`
- Contract field scan for required per-contract headings in `docs/contracts.md`.
- Source/test/script/vendor/installer change check after Prompt 04.
- Privacy-sensitive path/name scan across current project-control docs.
- Trailing-whitespace scan across current project-control docs.
- `sed -n '523,618p' orbisonic_codex_prompt_sequence.md`
- `sed -n '1,260p' docs/contracts.md`
- `sed -n '261,620p' docs/contracts.md`
- `sed -n '620,980p' docs/contracts.md`
- `sed -n '1,260p' docs/architecture.md`
- `sed -n '1,260p' docs/implementation-map.md`
- `sed -n '261,620p' docs/implementation-map.md`
- `sed -n '1,260p' docs/status.md`
- `sed -n '1,260p' docs/product-brief.md`
- `sed -n '1,220p' AGENTS.md`
- `sed -n '1,240p' README.md`
- `sed -n '1,180p' Package.swift`
- `find docs -maxdepth 2 -type f | sort`
- `find Sources -maxdepth 3 -type f | sort`
- `find Tests -maxdepth 3 -type f | sort`
- Source searches and targeted reads for local file, live loopback, Roon, Spotify, Aux, renderer, monitor, diagnostics, logging, and test-tone flows.
- Prompt 05 docs/source/test/script/vendor/installer change check.
- Prompt 05 privacy-sensitive path/name scan across current project-control docs.
- Prompt 05 trailing-whitespace scan across current project-control docs.
- Prompt 05 `git diff --check`.
- `sed -n '619,744p' orbisonic_codex_prompt_sequence.md`
- `find Tests -maxdepth 2 -type f | sort`
- `rg -n "func test" Tests/AudioContractsTests Tests/AudioImportTests Tests/AudioCoreTests Tests/OrbisonicTests`
- `rg -c "func test" Tests/AudioContractsTests Tests/AudioImportTests Tests/AudioCoreTests Tests/OrbisonicTests`
- `sed -n '1,220p' AGENTS.md`
- `sed -n '1,220p' README.md`
- `sed -n '1,180p' Package.swift`
- `sed -n '1,220p' docs/product-brief.md`
- `sed -n '1,260p' docs/architecture.md`
- `sed -n '261,760p' docs/contracts.md`
- `sed -n '760,980p' docs/contracts.md`
- `sed -n '1,220p' docs/system-flows.md`
- `sed -n '220,460p' docs/system-flows.md`
- `sed -n '260,620p' docs/implementation-map.md`
- Prompt 06 docs/source/test/script/vendor/installer change check.
- Prompt 06 privacy-sensitive path/name scan across current project-control docs.
- Prompt 06 trailing-whitespace scan across current project-control docs.
- Prompt 06 `git diff --check`.
- `sed -n '746,860p' orbisonic_codex_prompt_sequence.md`
- `find docs -maxdepth 2 -type f | sort`
- `sed -n '1,220p' docs/status.md`
- `sed -n '1,220p' docs/embedded-librespot-integration.md`
- `sed -n '1,220p' docs/orbisonic-loopback-input-support-spec.md`
- `sed -n '1,140p' Sources/Orbisonic/LoopbackSourceSupport.swift`
- `sed -n '193,290p' Sources/Orbisonic/LoopbackSourceSupport.swift`
- `sed -n '1,120p' Sources/Orbisonic/RendererModule.swift`
- `sed -n '1,120p' Sources/Orbisonic/SpotifyReceiverClient.swift`
- Prompt 07 docs/source/test/script/vendor/installer change check.
- Prompt 07 ADR field check.
- Prompt 07 privacy-sensitive path/name scan across current project-control docs.
- Prompt 07 trailing-whitespace scan across current project-control docs.
- Prompt 07 `git diff --check`.
- `sed -n '835,978p' orbisonic_codex_prompt_sequence.md`
- `sed -n '1,260p' AGENTS.md`
- `sed -n '1,240p' docs/status.md`
- `sed -n '1,220p' README.md`
- `sed -n '1,180p' Package.swift`
- `sed -n '1,240p' docs/product-brief.md`
- `sed -n '1,260p' docs/architecture.md`
- `sed -n '1,260p' docs/test-strategy.md`
- `sed -n '1,320p' docs/contracts.md`
- `sed -n '1,320p' docs/system-flows.md`
- `sed -n '1,360p' docs/implementation-map.md`
- `find docs/decisions -maxdepth 1 -type f | sort`
- `rg -n "^#|^Status:|^## Context|^## Decision|^## Follow-up" docs/decisions/*.md`
- `rg -n "enum StageTab|StageTab|Local Music|Settings|VU" Sources/Orbisonic/ContentView.swift`
- `git status --short`
- `git diff -- AGENTS.md docs/status.md`
- Prompt 08 required-section and preserved-rule scan across `AGENTS.md` and `docs/status.md`.
- Prompt 08 source/test/script/vendor/installer/calibration change check.
- Prompt 08 personal path/name scan across current project-control docs.
- Prompt 08 trailing-whitespace scan across current project-control docs.
- Prompt 08 `git diff --check`.
- `sed -n '978,1135p' orbisonic_codex_prompt_sequence.md`
- `sed -n '1,260p' AGENTS.md`
- `sed -n '1,230p' docs/status.md`
- `sed -n '1,240p' README.md`
- `sed -n '1,180p' Package.swift`
- `sed -n '1,240p' docs/product-brief.md`
- `sed -n '1,280p' docs/architecture.md`
- `find Sources Tests -maxdepth 2 -type f | sort`
- `rg -n "^## |^Responsibility:|^Tests required:|^Acceptance criteria:" docs/contracts.md`
- `sed -n '1,240p' docs/system-flows.md`
- `sed -n '1,260p' docs/test-strategy.md`
- `sed -n '1,420p' docs/implementation-map.md`
- `rg -n "^# |^Status:|^## Decision|^## Follow-up" docs/decisions/*.md`
- `mkdir -p .tasks`
- `find .tasks -maxdepth 1 -type f | sort`
- Prompt 09 required task-section scans across `.tasks/*.md`.
- Prompt 09 source/test/script/vendor/installer/calibration change check.
- Prompt 09 personal path/name scan across `.tasks/` and current project-control docs.
- Prompt 09 trailing-whitespace scan across `.tasks/` and current project-control docs.
- Prompt 09 `git diff --check`.
- Prompt 09 `git status --short`.
- `sed -n '1095,1215p' orbisonic_codex_prompt_sequence.md`
- `sed -n '1,260p' AGENTS.md`
- `sed -n '1,260p' docs/status.md`
- `find .tasks docs -maxdepth 2 -type f | sort`
- `find Sources Tests -maxdepth 2 -type f | sort`
- `git status --short`
- `rg -n "enum SourceMode|Local Files|Local Music|Orbisonic Spotify Input|Orbisonic Roon Input|Orbisonic Aux Cable" Sources Tests docs README.md AGENTS.md .tasks`
- `rg -n "AGENTS notes mention older|Prompt 08|docs/readiness-summary|release verification|docs/audits/0003|Prompt 10|Prompt 11|Prompt 12" docs .tasks AGENTS.md README.md`
- `sed -n '1,220p' Sources/Orbisonic/LoopbackSourceSupport.swift`
- `sed -n '1,160p' Sources/AudioCore/SourceAdapters.swift`
- `nl -ba README.md`
- `nl -ba Sources/Orbisonic/LoopbackSourceSupport.swift`
- `nl -ba docs/architecture.md`
- `nl -ba docs/implementation-map.md`
- `nl -ba docs/status.md`
- `nl -ba .tasks/010-installer-and-release-verification-docs.md`
- `nl -ba .tasks/011-documentation-refresh-and-readiness.md`
- `nl -ba AGENTS.md`
- `nl -ba .tasks/001-plan-audit.md`
- `nl -ba orbisonic_codex_prompt_sequence.md`
- `rg -c "func test" Tests/AudioContractsTests Tests/AudioImportTests Tests/AudioCoreTests Tests/OrbisonicTests`
- `mkdir -p docs/audits`
- Prompt 10 required audit-section scan.
- Prompt 10 source/test/script/vendor/installer/calibration change check.
- Prompt 10 personal path/name scan across audit, status, tasks, and current project-control docs.
- Prompt 10 trailing-whitespace scan across audit, status, tasks, and current project-control docs.
- Prompt 10 `git diff --check`.
- Prompt 10 `git status --short`.
- `sed -n '1215,1375p' orbisonic_codex_prompt_sequence.md`
- `sed -n '1,260p' docs/audits/0001-plan-audit.md`
- `git status --short`
- `sed -n '218,232p' AGENTS.md`
- `sed -n '1,28p' docs/implementation-map.md`
- `sed -n '136,149p' docs/architecture.md`
- `sed -n '68,82p' .tasks/010-installer-and-release-verification-docs.md`
- `sed -n '1,85p' .tasks/003-contract-test-gap-audit.md`
- `sed -n '124,156p' docs/test-strategy.md`
- `sed -n '1,90p' docs/status.md`
- `sed -n '205,245p' docs/status.md`
- Prompt 11 source/test/script/vendor/installer/calibration change check.
- Prompt 11 required status/task/content scan.
- Prompt 11 personal path/name scan across current project-control docs, audit docs, and task files.
- Prompt 11 trailing-whitespace scan across current project-control docs, audit docs, and task files.
- Prompt 11 `git diff --check`.
- Prompt 11 `git status --short`.
- `sed -n '1340,1515p' orbisonic_codex_prompt_sequence.md`
- `sed -n '1,260p' docs/contracts.md`
- `sed -n '261,560p' docs/contracts.md`
- `sed -n '561,900p' docs/contracts.md`
- `sed -n '1,220p' docs/test-strategy.md`
- `sed -n '1,520p' docs/implementation-map.md`
- `sed -n '1,520p' docs/system-flows.md`
- `sed -n '1,220p' docs/audits/0001-plan-audit.md`
- `sed -n '1,220p' .tasks/003-contract-test-gap-audit.md`
- `sed -n '1,220p' Package.swift`
- `rg --files Tests`
- `rg -n "func test" Tests/AudioContractsTests Tests/AudioImportTests Tests/AudioCoreTests Tests/OrbisonicTests`
- `rg -c "func test" Tests/AudioContractsTests Tests/AudioImportTests Tests/AudioCoreTests Tests/OrbisonicTests`
- `sed -n '1,180p' README.md`
- `sed -n '1,180p' docs/product-brief.md`
- Prompt 12 targeted reads for loopback, live bridge, web state, source adapters, input status panel, monitor routing, architecture boundary, and selected-source ADRs.
- `sed -n '1370,1535p' orbisonic_codex_prompt_sequence.md`
- `sed -n '1,220p' docs/audits/0002-contract-test-gap-audit.md`
- `sed -n '1,180p' .tasks/004-contract-test-gap-pass.md`
- `rg -n "setLiveAudioSignalStateForTesting|setLiveMonitorStateForTesting|setInputRouteForTesting|setSourceModeForTesting|setRoonBridgeSnapshotForTesting|setSpotifyNowPlayingForTesting" Sources/Orbisonic Tests/OrbisonicTests`
- Prompt 13 targeted reads for `OrbisonicWebStateTests`, `InputSourceStatusPanelModel`, `OrbisonicWebServer`, and `OrbisonicViewModel` test setters.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter OrbisonicWebStateTests`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `git diff --name-only -- Sources Package.swift README.md scripts installer Vendor calibration`
- `git diff --check`
- Prompt 13 privacy and trailing-whitespace scans over changed test, task, and docs files.
- `sed -n '1484,1558p' orbisonic_codex_prompt_sequence.md`
- `sed -n '1,120p' .tasks/005-architecture-boundary-test-pass.md`
- `rg --files Tests Sources docs/decisions docs/PureAudio | rg "Architecture|Boundary|AudioCore|Contracts|PureAudio|SourceAdapter|Import|Renderer|Monitor"`
- Prompt 14 targeted reads for `PureAudioArchitectureBoundaryTests`, `ArchitectureBoundaryAllowlist`, `Package.swift`, SwiftPM target ADRs, architecture/contracts docs, source imports, source integration files, and monitor topology files.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter PureAudioArchitectureBoundaryTests`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `rg -c "func test" Tests/AudioContractsTests Tests/AudioImportTests Tests/AudioCoreTests Tests/OrbisonicTests`
- `git diff --name-only -- Sources Package.swift README.md scripts installer Vendor calibration`
- `git diff --check`
- Prompt 14 privacy and trailing-whitespace scans over changed architecture test, allowlist, task, and docs files.
- Prompt 15 targeted source/test/doc reads for live loopback diagnostic snapshots, Diagnostics UI rows, and selected-source status.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter LoopbackSourceSupportTests`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `./scripts/refresh-orbisonic-app.sh`
- `git diff --check`
- Prompt 16 targeted source/test/doc reads for selected-source transitions, local snapshot state, Spotify health rows, and web-state source isolation.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter OrbisonicWebStateTests`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `./scripts/refresh-orbisonic-app.sh`
- `pgrep -fl Orbisonic`
- `./scripts/reopen-orbisonic-app.sh`
- `git diff --name-only -- Sources Package.swift README.md scripts installer Vendor calibration`
- `git diff --check`
- Prompt 16 privacy-sensitive scan over changed source-isolation docs and web-state tests; hits were expected test-token/artwork assertions, generated `.flac` fixture naming, and existing privacy-rule wording.
- Prompt 17 targeted source/test/doc reads for renderer topology, Direct 30/31, normal-monitor routing, monitor graph topology, metering isolation, and project-control docs.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter RendererModuleTests/testNormalMonitorPlanningLeavesProductionSonicSphereSceneUnchanged`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter NormalMonitorRouteBranchRemovalTests/testNormalMonitorDoesNotDependOnAnyRendererModeIncludingDirectBypass`
- Test-count refresh for `AudioContractsTests`, `AudioImportTests`, `AudioCoreTests`, and `OrbisonicTests`.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `./scripts/refresh-orbisonic-app.sh`
- `git diff --check`
- `git diff --name-only -- AGENTS.md README.md Package.swift Sources Tests scripts installer Vendor calibration docs .tasks`
- Prompt 17 privacy-sensitive scan over changed renderer/monitor docs, source, and tests; hits were expected privacy-rule wording in `docs/test-strategy.md` and prior Prompt 16 status wording.
- Prompt 18 targeted reads for README, release notes, project-control docs, installer package inventory, scripts, Roon bridge resources, entitlements, and package payload metadata.
- `find installer scripts -maxdepth 2 -type f | sort`
- `pkgutil --payload-files installer/Orbisonic-1.1.pkg`
- `pkgutil --payload-files installer/OrbisonicSuite-1.1.pkg`
- Prompt 18 suite-package expansion into a temporary directory to inspect nested `PackageInfo` metadata.
- `git diff --name-only -- AGENTS.md README.md Package.swift Sources Tests scripts installer Vendor calibration`
- `git diff --name-only -- scripts installer Package.swift README.md RELEASE_NOTES.md`
- `git diff --check`
- Prompt 18 privacy-sensitive and trailing-whitespace scans over release-verification docs, status docs, test strategy, implementation map, README, and task file.
- Prompt 19 targeted reads for status, product brief, architecture, contracts, system flows, implementation map, test strategy, release verification, audits, decisions, task statuses, Sources, and Tests.
- `rg -c "func test" Tests/AudioContractsTests Tests/AudioImportTests Tests/AudioCoreTests Tests/OrbisonicTests`
- `git diff --name-only -- AGENTS.md README.md Package.swift Sources Tests scripts installer Vendor calibration`
- `git diff --name-only -- Sources Tests Vendor calibration`
- `git diff --check`
- Prompt 19 privacy-sensitive and trailing-whitespace scans over readiness docs, project-control docs, and task files.

No build or test command was required for the docs-only prompts. Prompts 13 and 14 are tests-only prompts and passed focused plus full SwiftPM verification.

## Plan Audit Follow-Up

### Audit Issues Fixed

- H1: Clarified `AGENTS.md` Definition of Done so prompt-scoped audit/status-only artifacts do not force unrelated `docs/implementation-map.md` edits.
- H3: Strengthened `.tasks/010-installer-and-release-verification-docs.md` verification so future script, installer, package, README, and release-note changes are visible.
- Task graph: Marked `.tasks/001-plan-audit.md` and `.tasks/002-fix-plan-audit-findings.md` complete.
- M1: Updated `docs/implementation-map.md` to include `.tasks/`, `docs/audits/`, and current contract-map wording.
- M2: Removed stale Prompt 08 tab-note wording from `docs/architecture.md`.
- M3: Classified `docs/PureAudio/` as historical migration evidence unless elevated by current contracts, system flows, or accepted ADRs.
- M4: Created `docs/readiness-summary.md` during Prompt 19.
- L1: Added a naming note for `Local Files` as raw/source-mode value and `Local Music` as operator-facing label.
- H2: Updated README live-input setup so it includes `Orbisonic Spotify Input`.

### Audit Issues Left Open

- No Prompt 10 audit issues remain open after Prompt 19. Release/setup readiness still depends on the manual verification documented in `docs/release-verification.md` and `.tasks/012-manual-release-verification.md`.

### Questions Requiring User Decision

- Which existing PureAudio docs are fully current versus historical migration notes?
- Which hardware setup is the reference manual verification environment for Sonic Sphere / Dante output?
- Should release-readiness require the suite installer with loopback drivers, or is the app-only installer enough for a stable retrofit milestone?
- What level of Spotify receiver functionality should count as supported if Spotify controls remain session-dependent?

### Contract-Test Gap Audit Status

Prompt 13 is complete. Selected live-source no-signal status is now covered for Roon, Spotify, and Aux in deterministic web/control-state tests. Real loopback capture remains manual-only.

### Architecture Boundary Test Status

Prompt 14 is complete. Static architecture boundary tests now cover SwiftPM dependency direction, lower-target app/runtime leakage, AudioContracts filesystem implementation leakage, source-integration renderer topology ownership, monitor production-topology ownership, and documented migration exceptions.

### Source Isolation Hardening Status

Prompt 16 is complete. Off and Test Tone source transitions now clear stale local source snapshots, and Spotify source health stays inside the fixed stereo boundary even if stale local multichannel metadata is still present before a transition settles. Real Roon, Aux, Spotify Connect, loopback permission, and hardware routing checks remain manual.

### Renderer Monitor Boundary Hardening Status

Prompt 17 is complete. Normal monitor route selection is explicitly documented in source as a stereo preview branch that ignores production renderer mode, output route capability, and Sonic Sphere channel count. New deterministic tests cover every renderer mode, including Direct 30/31, and confirm normal-monitor planning does not mutate the Sonic Sphere 30.1 scene topology. Physical Sonic Sphere / Dante verification remains manual.

### Installer And Release Verification Status

Prompt 18 is complete. `docs/release-verification.md` now separates automated repository checks from manual installer, LaunchServices, Roon bridge, Roon loopback, Aux loopback, Spotify receiver, Sonic Sphere / Dante, monitor, microphone permission, and signing/entitlement checks. README setup docs now include `Orbisonic Spotify Input`. No scripts, installer packages, source, or tests changed in Prompt 18.

### Readiness Review Status

Prompt 19 is complete. `docs/readiness-summary.md` records that documentation and automated hardening are ready for a manual release-verification pass, but Orbisonic is not release-verified until `.tasks/012-manual-release-verification.md` is run in the real macOS, loopback, Roon, Spotify, monitor, Sonic Sphere, and Dante environment. `.tasks/006-audio-boundary-hardening-plan.md` is marked skipped / superseded because the prompt sequence moved directly from the test-gap passes into Prompts 15 through 17 hardening.

### Manual Release Verification Status

Task 012 is partially complete. Full SwiftPM tests passed with 544 tests and 0 failures, the repo-root app bundle refreshed, app-only and suite installers passed from `/private/tmp`, installed app verification passed, all three HAL drivers installed as version `0.2.0`, Roon bridge dependencies installed, the embedded librespot static library is present, AVFoundation sees all three Orbisonic inputs, and Dante Virtual Soundcard is running. Release readiness is still blocked because packages are unsigned, the installed package app is stamped `8ffa977` while the tested working tree is `64f7fea` with uncommitted changes, and real Roon / Aux / Spotify / monitor / Sonic Sphere / Dante / microphone-permission / entitlement checks were not run.

## Assumptions

- The current repo root is the canonical Orbisonic product root.
- Current source, tests, README, AGENTS.md, Package.swift, and existing docs are the source of truth.
- Orbisonic is already implemented; this retrofit should stabilize control surfaces around the existing implementation.
- Sonic Sphere 30.1 remains the primary production output target.
- The headphone or normal monitor path is a monitoring surface, not the production topology.
- Orbisonic does not decode Dolby Atmos object metadata; it renders channel beds or discrete channels exposed by Core Audio or an upstream decoder.
- Hardware-only behavior should be documented honestly rather than simulated in tests.
- The Prompt 19 refresh made no production source or test changes.
- Task 012 did not modify production source or tests.

## Next Recommended Prompt

Clean signed installer rebuild plus hardware/service verification from `.tasks/012-manual-release-verification.md`.

## Open Questions

- Which existing PureAudio docs are fully current versus historical migration notes?
- Which hardware setup is the reference manual verification environment for Sonic Sphere / Dante output?
- Should release-readiness require the suite installer with loopback drivers, or is the app-only installer enough for a stable retrofit milestone?
- What level of Spotify receiver functionality should count as supported if Spotify controls remain session-dependent?

## Decision Log

- `docs/decisions/0001-retrofit-not-rewrite.md`: current Orbisonic is the baseline; the retrofit adds control docs, contracts, tests, audits, tasks, and hardening rather than rewriting the app.
- `docs/decisions/0002-swiftpm-target-boundaries.md`: the current SwiftPM target split is the starting architecture.
- `docs/decisions/0003-audio-contracts-as-shared-language.md`: `AudioContracts` is the common type and vocabulary layer for shared audio policy.
- `docs/decisions/0004-selected-source-only-rule.md`: Roon, Spotify, Atmos DRP, Aux, Local Files, and Test Tone are selected-source paths, not an implicit mixer.
- `docs/decisions/0005-sonic-sphere-30-1-primary-output.md`: Sonic Sphere 30.1 is the primary production output; headphone or normal monitor output is a separate monitor path.
- `docs/decisions/0006-embedded-librespot-boundary.md`: Spotify Connect support is the embedded librespot FFI boundary targeting `Orbisonic Spotify Input`.
- `docs/decisions/0007-roon-loopback-boundary.md`: Roon metadata/transport are separate from live loopback capture truth.

## Current State Snapshot

- Current phase: post-retrofit readiness / manual release verification.
- Current milestone: Task 012 is partially complete; clean signed installer rebuild plus hardware/service verification are next.
- Completed retrofit work: project-control docs, contracts, system flows, implementation map, test strategy, ADRs, audits, task graph, release verification docs, readiness summary, and repo-level operating rules.
- Completed hardening work: selected live-source no-signal tests, architecture boundary tests, live loopback diagnostic snapshots, Off/Test Tone stale-local cleanup, Spotify fixed-stereo health boundary, and renderer/monitor route-isolation tests.
- Remaining risks: real loopback capture, Roon, Spotify Connect, Atmos DRP capture/playback, Aux capture, Sonic Sphere / Dante, monitor listening, microphone permission, signing, entitlements, unsigned packages, and package/tested-code mismatch remain.
- Blockers: release readiness is blocked until clean signed package artifacts exist and live hardware/service checks are run and recorded.
- Manual verification still needed: Roon authorization/transport/capture, Atmos DRP/iLok/playback/capture, Aux capture, Spotify Connect/capture, monitor listening, Sonic Sphere / Dante channel walk, microphone permission prompt, and entitlement-gated Apple spatial behavior.
- Commands most recently run: full SwiftPM test suite, app refresh, app-only installer, suite installer, installed app LaunchServices open, package payload/signature inspection, suite package expansion, app plist/codesign checks, HAL driver version/signature checks, AVFoundation device listing, Roon bridge install, prerequisite process checks, v1.1 launcher syntax/existence checks, `git diff --check`, and privacy/trailing-whitespace scans.
- Test status: current full SwiftPM suite passed with 552 tests and 0 failures.
- Recommended next concrete task: rebuild signed installer artifacts from a clean tested commit, then finish hardware/service verification from `.tasks/012-manual-release-verification.md`.
