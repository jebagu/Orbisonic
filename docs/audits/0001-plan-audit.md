# 0001: Plan Audit

Status: Complete

Date: 2026-05-05

## Executive Summary

The project control package is usable and the task order is broadly safe: docs and audits come before tests, tests come before production hardening, and hardware-only checks are repeatedly marked manual. No blocker prevents Prompt 11 from running.

The audit found three high-severity issues to fix before contract-test work starts:

- `AGENTS.md` has a Definition of Done rule that conflicts with prompt-scoped audit tasks.
- README live-input setup lags current Spotify loopback support.
- Task 010 allows low-risk script edits but its default verification command does not protect scripts.

The remaining findings are medium or low. They mostly involve stale project control wording, historical PureAudio docs that are not clearly labeled, readiness artifacts missing from status, and inconsistent `Local Files` versus `Local Music` naming context.

## Issues Found

### Blocker

No blocker was found.

### High

#### H1. `AGENTS.md` Definition of Done conflicts with prompt-scoped audit tasks

Evidence:

- `AGENTS.md:220-228` says a task is done only when `docs/implementation-map.md` is updated when files change.
- Prompt 10 explicitly allows only `docs/audits/0001-plan-audit.md` and `docs/status.md`, and says not to fix other docs yet (`orbisonic_codex_prompt_sequence.md:1127-1134`).
- `.tasks/001-plan-audit.md:52-63` also lists only the audit file and status as expected outputs.

Impact:

Future Codex sessions can be forced into a conflict: obey the specific prompt and leave `docs/implementation-map.md` alone, or obey the global Definition of Done and edit an out-of-scope file.

Recommended fix:

In Prompt 11, clarify `AGENTS.md` so `docs/implementation-map.md` is required when source, test, script, resource, installer, vendor, calibration, or durable ownership maps change, but not for prompt-scoped audit/status-only artifacts unless the prompt explicitly allows it. Alternatively, update each audit task's expected files to include `docs/implementation-map.md`, but that is less compatible with the prompt sequence.

#### H2. README live-input requirements omit Spotify loopback setup

Evidence:

- `README.md:56` says Orbisonic Inputs provide `Orbisonic Roon Input` and `Orbisonic Aux Cable`.
- `README.md:79-81` says the suite installer installs Spotify live capture, but the capture setup text only mentions Roon and Aux.
- Current source defines `Orbisonic Spotify Input` as a first-class loopback device in `Sources/Orbisonic/LoopbackSourceSupport.swift:3-17`.
- Tests assert Spotify loopback identity and setup text in `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift:24-30` and `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift:100-104`.

Impact:

Release verification and operator setup can under-specify the Spotify path even though the app, docs, and tests treat it as a supported selected source.

Recommended fix:

In Prompt 11, update README requirements and live capture setup language to include `Orbisonic Spotify Input`, while preserving that Roon and Spotify are optional source helpers.

#### H3. Task 010 permits script edits but its baseline verification does not protect scripts

Evidence:

- `.tasks/010-installer-and-release-verification-docs.md:40` permits script edits when necessary and low risk.
- `.tasks/010-installer-and-release-verification-docs.md:58-62` lists possible script files as expected files.
- `.tasks/010-installer-and-release-verification-docs.md:74-79` verifies only `Sources`, `Tests`, `Vendor`, and `calibration` by default, then adds a conditional note if scripts change.

Impact:

A future release-doc task could change scripts while still passing its default verification command. Scripts can affect app refresh, installer, and LaunchServices behavior, so they need explicit protection.

Recommended fix:

In Prompt 11, either make Task 010 docs-only and move script work into a separate explicit task, or strengthen the verification command to include `scripts`, `installer`, `Package.swift`, `README.md`, and `RELEASE_NOTES.md` plus explicit script checks when scripts are changed.

### Medium

#### M1. `docs/implementation-map.md` does not include the new project control surfaces

Evidence:

- `docs/status.md:32` records the sequential retrofit and hardening task graph under `.tasks/`.
- `docs/implementation-map.md:7-20` lists top-level structure but does not include `.tasks/` or `docs/audits/`.
- `docs/implementation-map.md:5` still says contracts belong in `docs/contracts.md` after Prompt 04 creates it, even though Prompt 04 is complete.

Impact:

Future sessions may use `docs/implementation-map.md` and miss the current task graph and audit trail. This also compounds H1 because the implementation map is the file meant to help future agents find project surfaces.

Recommended fix:

In Prompt 11, add `.tasks/` and `docs/audits/` to the top-level structure and refresh the stale purpose sentence.

#### M2. `docs/architecture.md` contains a stale post-Prompt-08 note

Evidence:

- `docs/architecture.md:137-143` correctly lists the current `StageTab` set.
- `docs/architecture.md:147` still says AGENTS mentions older tabs until Prompt 08 updates it.
- Prompt 08 updated `AGENTS.md` and it now lists the current tab names.

Impact:

The note is now stale and can make future sessions re-audit a resolved issue.

Recommended fix:

In Prompt 11, remove or replace the stale note with a statement that `AGENTS.md`, `docs/architecture.md`, and current `StageTab` source are aligned as of Prompt 08.

#### M3. Historical PureAudio docs are linked but not clearly classified

Evidence:

- `docs/implementation-map.md:14-15` treats `docs/` and `docs/PureAudio/` as related project docs.
- `docs/status.md:217` keeps an open question asking which PureAudio docs are current versus historical.
- `docs/PureAudio/SYSTEM_AUDIO_FLOW.md:232-241` contains prior prompt-numbered implementation status about output adapters and live dual-device binding.
- `docs/PureAudio/AUDIO_BOUNDARY_RULES.md:156-183` also contains prior prompt-numbered hardening rules.

Impact:

Future implementation tasks can accidentally treat historical migration notes as current binding contracts. This is especially risky around live output, Dante, metering, and legacy bridge exceptions.

Recommended fix:

In Prompt 11, do not rewrite the PureAudio docs broadly. Add a status or index note that classifies them as historical migration evidence unless explicitly elevated by `docs/contracts.md`, `docs/system-flows.md`, or an accepted ADR.

#### M4. Release readiness artifact is missing from the status pending list

Evidence:

- `docs/status.md:41-44` lists pending docs as `docs/audits/` and `docs/release-verification.md`.
- `.tasks/011-documentation-refresh-and-readiness.md:53-55` expects `docs/readiness-summary.md`.

Impact:

The final readiness artifact can be missed because it is not visible from the main status panel.

Recommended fix:

In Prompt 11, update `docs/status.md` pending docs to include `docs/readiness-summary.md` or explicitly defer it to Task 011.

### Low

#### L1. `Local Files` and `Local Music` need a short naming note

Evidence:

- `SourceMode.filePlayback` raw value is `Local Files`, but its display name is `Local Music` in `Sources/Orbisonic/LoopbackSourceSupport.swift:193-207`.
- Tests assert both raw values and display labels in `Tests/OrbisonicTests/LoopbackSourceSupportTests.swift:6-10`.
- Web state tests also assert `Local Music` titles with `Local Files` values in `Tests/OrbisonicTests/OrbisonicWebStateTests.swift:194-199`.

Impact:

This is not a behavior bug, but future docs and tests can drift if they do not distinguish internal/raw source names from operator-facing copy.

Recommended fix:

In Prompt 11 or a later docs refresh, add a short naming note to `docs/architecture.md`, `docs/contracts.md`, or `docs/system-flows.md`: `Local Files` is the source-mode/raw value, while `Local Music` is the current operator-facing label.

## Recommended Doc Changes

- Update `AGENTS.md` Definition of Done to avoid conflict with prompt-scoped audit/status-only tasks.
- Update README requirements and live player setup for `Orbisonic Spotify Input`.
- Add `.tasks/` and `docs/audits/` to `docs/implementation-map.md`.
- Refresh stale Prompt 04/Prompt 08 wording in `docs/implementation-map.md` and `docs/architecture.md`.
- Add a status note classifying `docs/PureAudio/` as historical migration evidence unless elevated by current contracts, flows, or ADRs.
- Add `docs/readiness-summary.md` to status pending docs or mark it explicitly as Task 011 output.
- Add a naming note for `Local Files` versus `Local Music`.

## Recommended Task Changes

- In `.tasks/010-installer-and-release-verification-docs.md`, either remove script edits from scope or split them into a separate script-verification task.
- If Task 010 keeps script edits, strengthen verification to include `scripts`, `installer`, `Package.swift`, `README.md`, and `RELEASE_NOTES.md`, with explicit commands for any changed script.
- In `.tasks/011-documentation-refresh-and-readiness.md`, keep `docs/readiness-summary.md` as a first-class output and make sure status points to it.
- Keep Prompt 11 as the next task. Do not proceed to contract-test gap work before resolving or explicitly carrying forward H1-H3.

## Recommended Test Strategy Changes

- No immediate test changes are required before Prompt 11 because Prompt 11 is docs/tasks only.
- In the later contract-test gap audit, explicitly check product/setup claims from README and product docs against tests, not only `docs/contracts.md`.
- Add a test-strategy note that UI/raw naming pairs such as `Local Files` and `Local Music` should be tested together when they are part of public web/control state.
- Keep installer, loopback, Roon, Aux, Spotify Connect, microphone permission, signing, and Sonic Sphere / Dante checks as manual verification until real hardware or service checks are run.

## Questions That Block Implementation

- Which `docs/PureAudio/` files are current binding references, and which are historical migration notes?
- Which hardware setup is the reference manual verification environment for Sonic Sphere / Dante output?
- Should release readiness require the suite installer with loopback drivers, or is the app-only installer enough for the retrofit milestone?
- What level of Spotify receiver behavior counts as supported for the retrofit milestone: receiver startup only, live loopback signal, Spotify Connect session, or transport/control readiness?

## Questions That Can Be Treated As Assumptions

- Current source and tests remain authoritative over older docs.
- `Local Files` can be treated as the internal/source-mode name and `Local Music` as the operator-facing label until a naming doc says otherwise.
- Hardware-only behavior remains manual and non-blocking for docs-only and test-only tasks.
- Roon log parsing remains fallback/context, not proof of captured audio.
- Prompt-specific file scopes override generic Definition of Done requirements until `AGENTS.md` is clarified.

## Risk Of Proceeding Without Fixes

| Issue | Risk if ignored |
| --- | --- |
| H1 | Future agents may either violate prompt scope or skip the stated Definition of Done, creating inconsistent project control behavior. |
| H2 | Spotify live capture can be omitted from setup and release verification despite source and tests supporting a dedicated Spotify input. |
| H3 | Release-related scripts may change without enough verification, risking app refresh, installer, or LaunchServices behavior. |
| M1 | Future sessions may miss `.tasks/` and audit files when using the implementation map as the project index. |
| M2 | Resolved tab-name drift remains visible as an apparent unresolved issue. |
| M3 | Historical PureAudio migration notes may be mistaken for current binding implementation instructions. |
| M4 | Final readiness work may omit the readiness summary artifact. |
| L1 | Naming inconsistencies can cause low-grade doc/test drift around Local Files versus Local Music. |

## Recommended Next Prompt

Prompt 11: Apply Plan Audit Findings, Docs And Tasks Only.
