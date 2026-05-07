# Orbisonic Agent Instructions

## Purpose

This file is the repo-level operating constitution for Codex work in Orbisonic. It describes how to read the project, where to work, what must be preserved, when to stop, how to verify changes, and how to report results.

Orbisonic is a native Swift/macOS app for routing, monitoring, and rendering multichannel spatial audio for Sonic Sphere. Sonic Sphere is the physical spatial audio system. Orbisonic is the software tool for interfacing with it.

## Scope And Product Identity

- The canonical project root is this repository root.
- Work only in this repository unless the user explicitly says otherwise.
- If a Codex thread or inherited environment starts in an older Orbisonic prototype workspace, treat that as stale launch context. Switch all active Orbisonic work to this repository.
- Do not use, inspect, or ask about the old `etheric` workspace or archived `OrbisonicBridge` folders for active Orbisonic work unless the user explicitly asks for old context.
- Orbisonic is a native Swift/macOS app. Do not treat the old `etheric` web app or the earlier `OrbisonicBridge` prototype as the active product.
- `Orbisonic.app` is the user-facing double-clickable app bundle in the project root.
- The current app is the baseline. Retrofit work should add contracts, docs, tests, audits, and bounded hardening around the existing implementation rather than rewriting it.

## Read First

For active work, read the smallest relevant set from this list before editing:

- `AGENTS.md`
- `README.md`
- `Package.swift`
- `docs/status.md`
- `docs/product-brief.md`
- `docs/architecture.md`
- `docs/contracts.md`
- `docs/system-flows.md`
- `docs/implementation-map.md`
- `docs/test-strategy.md`
- Relevant files in `docs/decisions/`
- Relevant `.tasks` file once `.tasks/` exists
- Relevant source and test files for the subsystem being changed

When docs and source disagree, inspect the current source and tests before changing behavior. If a public contract would need to change, stop and document the proposed contract change instead of silently editing around it.

## Task Discipline

- Run only the task or prompt the user asked for.
- Start by checking the current worktree when code or docs may change.
- Keep changes narrowly scoped to the requested behavior or document.
- Preserve current behavior unless the task explicitly authorizes behavior changes.
- Prefer existing project patterns, helpers, scripts, and tests.
- Do not introduce broad rewrites, major dependencies, or unrelated cleanup during bounded tasks.
- Do not touch unrelated subsystems just because they are nearby.
- Update project-control docs in the same change when behavior, flows, contracts, or file ownership maps change.
- Treat hardware-only behavior honestly: document required manual verification instead of implying automated tests proved it.

## Documentation Requirements

- Keep `docs/status.md` current as the project control panel.
- Update `docs/implementation-map.md` when source, test, script, resource, installer, vendor, or calibration file ownership changes.
- Update `docs/system-flows.md` when a user-visible or audio-relevant flow changes.
- Update `docs/test-strategy.md` when test coverage expectations, target maps, or verification rules change.
- Update `docs/contracts.md` only when the task explicitly allows contract changes.
- Add or update `docs/decisions/` entries when a durable architecture choice is made or revised.
- Use repo-relative paths in tracked docs.
- Do not add personal names, local usernames, machine-specific absolute paths, secrets, tokens, private logs, runtime caches, or private media to tracked files.

## Testing Requirements

Use Xcode's developer dir for tests:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Run the full SwiftPM test suite before accepting source or test changes unless a blocker is documented.

For docs-only tasks, no build is required unless source, tests, scripts, installer files, vendor files, resources, or calibration files changed by mistake. Minimum docs-only checks:

```sh
git diff --name-only -- AGENTS.md README.md Package.swift Sources Tests scripts installer Vendor calibration
git diff --check
```

After changing app code, refresh and verify the bundle:

```sh
./scripts/refresh-orbisonic-app.sh
```

If the app is already running, quit and reopen it through LaunchServices before judging UI/audio behavior:

```sh
./scripts/reopen-orbisonic-app.sh
```

Do not launch `Orbisonic.app/Contents/MacOS/Orbisonic` directly for GUI/audio verification. AppKit needs LaunchServices registration, and raw executable launches can abort before Orbisonic code runs.

## Audio-Specific Operating Rules

- The audio path is the most important part of this app. Prefer correctness, stability, and low-risk architecture over quick UI-visible fixes.
- Do not mask live audio failures with buffering tricks, synthetic signal, fake channels, hidden gain, fallback routing, or fake activity. If the input is all zeros, diagnose routing, sample-rate, source-device, permission, or capture problems.
- Local file playback and live loopback capture are separate paths. Do not assume a fix in one path fixes the other.
- Roon, Spotify, Aux Cable, Local Files, and Test Tone are selected-source paths, not an implicit mixer. Do not mix them without an accepted contract change.
- Sonic Sphere 30.1 is the primary production output topology. The headphone or normal monitor path is for setup, checking, and preview, and must not redefine or mutate the production topology.
- Direct 30 and Direct 30.1 renderer modes are bypass modes only when source width matches.
- Orbisonic renders channel beds or discrete channels exposed by Core Audio or upstream tools. It does not decode Dolby Atmos object metadata unless a future implementation explicitly adds and documents that capability.
- Sample-rate mismatch, channel-count mismatch, route mismatch, underflow, dropped frames, and all-zero live input must remain visible as validation or diagnostic states.
- Metering must not consume live playback buffers or mutate audible output.
- Hardware-only behavior involving Sonic Sphere, Dante, loopback devices, Roon, Spotify, microphone permission, signing entitlements, or installers requires manual verification.

## Live Source Rules

- The Roon live path captures the app-selected input device, expected to be `Orbisonic Roon Input`, without requiring macOS Sound Input to switch away from the user's mic.
- The Aux live path captures `Orbisonic Aux Cable` for general system/app audio.
- The Spotify live path uses the embedded librespot boundary and the dedicated Spotify input policy already represented in source and docs.
- macOS presents all input-device capture as "Microphone" permission, including Orbisonic loopback devices. That prompt is expected and does not by itself mean the physical mic is selected.
- Roon logs may show playback while loopback capture is silent. Treat this as a routing or device-rate problem, not automatically as an engine/render problem.

For Roon/live-loopback problems, inspect the app-managed Orbisonic log and compare:

- Roon output sample rate
- Orbisonic Roon Input nominal sample rate
- Input route name/channel count
- Live meter peak
- Buffer underflow/drop counters

## Roon Data

Current code reads Roon metadata from:

```text
~/Library/RoonServer/Logs/RoonServer_log.txt
```

Parser:

```text
Sources/Orbisonic/RoonNowPlayingMonitor.swift
```

The log parser extracts now-playing lines and signal-path details such as `Source Format=`, `ChannelMapping`, `Raat Device=`, and `Output`.

Future direction:

- Use the official Roon API for production metadata and transport control.
- Add a small `orbisonic-roon-bridge` helper if needed, likely Node-based, because Roon's public API tooling is Node-oriented.
- Use Roon API as the authoritative source for zones, zone IDs, state, seek position, duration, now playing, queue info, and transport commands.
- Keep Roon log parsing only as a fallback for signal-path data that the public API does not expose.
- Do not use latest Roon log line as proof that audio is reaching a loopback input.

## Privacy And Secret Handling

- Do not add real names, local usernames, machine-specific absolute paths, or personal folders such as Desktop, Downloads, or Documents to repo-tracked files.
- Use repo-relative paths, app-managed runtime paths, or generic placeholders for source provenance and setup notes.
- Do not commit private music files, Roon logs, Spotify credentials, Roon bridge tokens, local web tokens, local runtime caches, generated private diagnostics, or captured audio.
- Before committing, search for accidental personal identifiers, local absolute paths, secrets, tokens, runtime logs, and private media references.
- Runtime storage belongs in app-managed user locations and must remain outside tracked source unless explicitly represented by safe fixtures.

## Design Reference And UI Direction

- For UI, branding, icon, and visual-system work, use the adjacent Orbisonic app-family design language document when it is available.
- Treat that style guide as the Orbisonic app-family source of truth before making visual design decisions.
- Keep the DomeLab-inspired visual language: dark technical glass UI, compact labels, cyan accents, restrained dashboard density.
- Left rail keeps Now Playing and session status.
- Current main tabs are `Input`, `Renderer`, `Output`, `VU`, `Local Music`, `Diagnostics`, and `Settings`.
- Local music should remain a contained scrolling surface, not make the whole window scroll.
- Avoid adding nonfunctional clutter. Placeholder UI should be clearly scoped and must not interfere with the core audio workflow.

## Local Hosting

- Permanent local public page: `http://127.0.0.1:37943/Orbisonic/`
- For locally hosted web surfaces, use a stable project-name path in the URL instead of a bare host and port.
- Prefer readable IPv4 localhost links over bracketed IPv6 URLs.
- If the pinned port is occupied, stop the stale server or report the conflict; do not silently move Orbisonic to a new permanent URL unless the user approves it.

## Existing Important Files

- `Sources/Orbisonic/ContentView.swift`: SwiftUI shell and tabs.
- `Sources/Orbisonic/OrbisonicViewModel.swift`: app state, Roon status, routing, playlist behavior.
- `Sources/Orbisonic/OrbisonicEngine.swift`: AVAudioEngine graph and playback/live input.
- `Sources/Orbisonic/LiveAudioBridge.swift`: live loopback capture bridge and buffer status.
- `Sources/Orbisonic/RoonNowPlayingMonitor.swift`: current Roon log metadata parser.
- `Sources/Orbisonic/BlackHoleRouteRepair.swift`: BlackHole mute/volume/sample-rate repair.
- `Sources/Orbisonic/OutputRouteMonitor.swift`: Core Audio route discovery.
- `Sources/Orbisonic/SpotifyReceiverClient.swift`: embedded Spotify receiver boundary.
- `Sources/Orbisonic/OrbisonicWebServer.swift`: local public/control web state.
- `calibration/`: Sonic Sphere layout JSON files.
- `scripts/refresh-orbisonic-app.sh`: canonical app bundle refresh path.
- `scripts/reopen-orbisonic-app.sh`: canonical LaunchServices reopen path.

## Stopping Conditions

Stop and report the issue before continuing if:

- A public contract needs to change.
- A major dependency is required.
- The task conflicts with existing docs.
- The task touches unrelated subsystems.
- Tests fail for reasons outside the task.
- Hardware-only behavior cannot be verified and the task requires verification.
- The repo appears to be stale or not the active native Swift app.
- The work would mask live audio failures instead of diagnosing them.
- A requested change would require committing personal paths, secrets, tokens, private logs, private media, or machine-specific runtime state.

## Final Response Format

Use this standard summary format for prompt-sequence work:

```text
Summary:
Files changed:
Tests added or updated:
Commands run:
Results:
Documentation updated:
Assumptions:
Risks or blockers:
Recommended next prompt:
```

For non-sequence work, keep the final response concise but still include what changed, what was verified, and any remaining manual checks or blockers.

## Definition Of Done

A task is done only when the prompt-specific file scope has been respected and:

- The requested behavior or documentation change is complete.
- Relevant tests were added or updated for behavioral changes.
- Relevant checks were run, or blockers were documented.
- `docs/status.md` was updated.
- `docs/implementation-map.md` was updated when source, test, script, resource, installer, vendor, calibration, or durable ownership maps changed. Prompt-scoped audit/status-only artifacts do not require an implementation-map update unless the prompt explicitly allows it.
- `docs/system-flows.md` was updated when flows changed.
- `docs/contracts.md` was updated only when explicitly allowed.
- Assumptions and risks were documented.
- Source, tests, scripts, installer files, vendor files, resources, and calibration files were confirmed unchanged for docs-only prompts.
- Any hardware-only verification gap was stated plainly instead of being implied as tested.
