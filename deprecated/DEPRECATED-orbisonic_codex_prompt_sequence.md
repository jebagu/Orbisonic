# DEPRECATED

Deprecated historical Orbisonic prompt material from the former split workspace. Retained for reference only; do not treat it as active instructions.

# Orbisonic Codex Sequential Retrofit Prompt Pack

Generated: 2026-05-04

Repository: `https://github.com/jebagu/Orbisonic`

Purpose: retrofit Orbisonic with the project control practices from the new project launch workflow, without rewriting the app or destabilizing the audio path.

This file is designed to be handed to Codex as a sequential prompt pack. Codex should execute the prompts in order. Each prompt is deliberately bounded. Documentation and tests come before production-code hardening.

---

# 0. How Codex Should Use This File

## 0.1 Execution Mode

Codex must process this file in order.

If the user provides the entire file to Codex, Codex should do the following:

1. Read this entire file once.
2. Start with Prompt 01.
3. Complete only the current prompt.
4. Run the verification steps required by that prompt.
5. Update `docs/status.md` when the prompt requires it.
6. Return the required final summary.
7. Continue to the next prompt only if the user explicitly asks to continue or if the user has explicitly instructed Codex to run the whole sequence.

If the user explicitly says to run the whole sequence, Codex may continue prompt by prompt, but it must still stop immediately if any stopping condition is hit.

## 0.2 Hard Gate Before Production Code

Prompts 01 through 12 are planning, documentation, audit, and test-gap discovery prompts. They must not change production app behavior.

Prompt 13 may add or update tests.

Prompts 15 through 17 may change production code, but only after the planning docs, audit fixes, and test strategy are complete.

Codex must not jump directly to production-code hardening.

## 0.3 Global Rules For Every Prompt

For every prompt in this file, Codex must obey these rules:

- Work only in the active Orbisonic repository root.
- Do not use old `etheric` workspaces, archived `OrbisonicBridge` folders, or stale prototype workspaces unless the user explicitly asks for old context.
- Treat Orbisonic as a native Swift/macOS app.
- Treat the audio path as higher priority than UI polish.
- Preserve existing repo-specific instructions in `AGENTS.md`.
- Preserve existing user-facing behavior unless the current prompt explicitly allows behavior changes.
- Prefer small, verifiable changes.
- Do not add major dependencies unless the current prompt explicitly allows it.
- Do not silently change public contracts.
- Do not touch unrelated subsystems.
- Do not commit secrets, real personal paths, machine-specific usernames, local absolute paths, or private data.
- Use repo-relative paths in docs.
- Update human-readable docs as part of the work.
- If verification is impossible because hardware is unavailable, document the manual verification gap explicitly.
- Stop if the prompt conflicts with existing docs, tests, or repo state.

## 0.4 Standard Verification Commands

Use only commands that exist in the repository. For this repo, the expected baseline test command is:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

When app code changes, also use the existing app refresh path when relevant:

```sh
./scripts/refresh-orbisonic-app.sh
```

When judging GUI or audio behavior, do not launch the raw executable directly. Use LaunchServices through the existing reopen script when relevant:

```sh
./scripts/reopen-orbisonic-app.sh
```

If a command cannot run in the current environment, document the exact reason instead of pretending it passed.

## 0.5 Required Final Summary Format

Every prompt response from Codex must include:

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

---

# Prompt 01: Baseline Repo Inventory, No File Changes

## Goal

Build a current factual inventory of the Orbisonic repository before changing anything.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 01 only.

Goal:
Create a factual baseline inventory of the current repo state. Do not change files.

Read:
- AGENTS.md
- README.md
- Package.swift
- docs/
- Sources/
- Tests/
- scripts/
- installer/
- Vendor/

Do not modify source code.
Do not modify docs.
Do not create files.
Do not run broad refactors.

Return a repo inventory with:

1. Current top-level folders and their apparent purposes
2. SwiftPM products and targets from Package.swift
3. Existing docs and what each appears to cover
4. Existing test targets and their apparent coverage
5. App-level feature areas visible from source filenames
6. Existing build and verification commands
7. Existing repo-specific constraints from AGENTS.md
8. Missing project control files compared with the retrofit plan
9. Risks or ambiguities that should shape the next docs-only prompts

Important assumptions:
- Orbisonic is already implemented.
- This is a retrofit, not a rewrite.
- Current source, README, Package.swift, existing docs, and tests are the source of truth.

Stopping conditions:
Stop and report if:
- You are not in the Orbisonic repo root
- AGENTS.md is missing
- Package.swift is missing
- The repo appears to be a stale prototype rather than the active native Swift/macOS app

Verification:
No build or test run is required for this prompt unless the inventory itself is ambiguous.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 02.
```

---

# Prompt 02: Create Baseline Status And Product Brief

## Goal

Create the first two control-panel docs: `docs/status.md` and `docs/product-brief.md`.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 02 only.

Prerequisite:
Prompt 01 must be complete, or you must independently inspect the current repo inventory before editing.

Goal:
Create baseline project control documentation for the existing Orbisonic app.

Read first:
- AGENTS.md
- README.md
- Package.swift
- docs/
- Sources/
- Tests/

Create or update:
- docs/status.md
- docs/product-brief.md

Do not change source code.
Do not refactor.
Do not rename files.
Do not alter app behavior.

`docs/status.md` must include:

- Current phase: retrofit / hardening
- Current milestone: project control retrofit
- Plain-English project summary
- Completed items already visible in the repo
- In-progress items
- Pending retrofit docs
- Blocked items, if any
- Current risks
- Recent change entry for this prompt
- Commands run
- Assumptions
- Next recommended prompt
- Open questions
- Decision log placeholder

Use this risk list as a starting point, and revise based on current repo evidence:

- live loopback routing failures
- sample-rate mismatch
- channel-count mismatch
- renderer topology regressions
- monitor path accidentally mutating production output behavior
- Roon, Spotify, Aux, and local source isolation bugs
- stale docs versus current source
- hardware-only verification gaps

`docs/product-brief.md` must explain Orbisonic in plain English:

- Project name
- One-sentence description
- Problem solved
- Target users
- Primary use cases
- Must-have features already represented by the app
- Nice-to-have features
- Explicit out-of-scope items
- Success criteria for a stable retrofit version
- Constraints
- Assumptions
- Open questions

Important product facts to preserve if supported by the repo:

- Orbisonic is a native macOS app.
- Orbisonic routes, monitors, and renders multichannel spatial audio for Sonic Sphere.
- Local files, live loopback sources, Roon, Spotify, and Aux inputs are separate source concerns.
- Sonic Sphere 30.1 is the primary production output target.
- Headphone or binaural output is a monitor path, not the primary production topology.
- The prototype supports arbitrary discrete layouts up to the repo's documented source-channel cap.
- Orbisonic does not decode Dolby Atmos object metadata unless the current repo proves otherwise.

Out of scope for this prompt:

- No production code changes
- No tests added
- No new architecture invented beyond current repo evidence
- No UI redesign
- No installer changes
- No dependency changes

Acceptance criteria:

- `docs/status.md` exists and reads like the project control panel.
- `docs/product-brief.md` exists and explains the product without requiring source-code inspection.
- Both docs are grounded in the current repo.
- Any uncertainty is called out as an assumption or open question.
- `docs/status.md` records this prompt as a recent change.

Verification:

Run no build unless you changed something that requires it. For docs-only work, inspect the files manually and report that no build was required.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 03.
```

---

# Prompt 03: Create Architecture And Implementation Map

## Goal

Create the high-level architecture doc and the feature-to-file map.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 03 only.

Prerequisite:
Prompt 02 should be complete.

Goal:
Create architecture and implementation-map docs for the current Orbisonic app.

Read first:
- AGENTS.md
- README.md
- Package.swift
- docs/status.md
- docs/product-brief.md
- existing docs/
- Sources/
- Tests/

Create or update:
- docs/architecture.md
- docs/implementation-map.md
- docs/status.md

Do not change source code.
Do not refactor.
Do not rename files.
Do not alter app behavior.

`docs/architecture.md` must include:

- Overview
- Core subsystems
- Runtime architecture
- Audio architecture
- Source architecture
- Renderer architecture
- Monitor architecture
- UI architecture
- External integrations
- Error-handling model
- Logging and diagnostics model
- Security and privacy model
- Deployment and installer model
- Architecture rules
- Known risks

The architecture must be based on current repo structure, especially the SwiftPM targets:

- AudioContracts
- AudioImport
- AudioCore
- Orbisonic executable app

`docs/implementation-map.md` must include:

- Purpose of the file
- Top-level structure
- SwiftPM target map
- Feature map
- Module map
- Test map
- Related docs
- Last updated entry

Map features by behavior, not only by folder name. Include feature sections when supported by current files:

- Local file playback
- Playlist and local library support
- Live loopback capture
- Roon bridge and Roon now-playing support
- Spotify embedded receiver support
- Aux source support
- Renderer and Sonic Sphere output
- Headphone or normal monitor path
- Diagnostics and logs
- Route monitoring and repair
- Test tones
- Installer and app bundle scripts
- Vendor dependencies

For each feature, list likely implementation files and related tests. Use repo-relative paths.

Out of scope for this prompt:

- No production code changes
- No tests added
- No contract changes yet
- No task files yet unless they already exist and need status mention only

Acceptance criteria:

- A non-code-reading project owner can understand the system shape from `docs/architecture.md`.
- A future Codex session can find relevant files from `docs/implementation-map.md`.
- Existing module boundaries are described without inventing a rewrite.
- `docs/status.md` records this prompt as a recent change.

Verification:

Docs-only prompt. No build required unless you changed executable files by mistake. Confirm no source files were changed.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 04.
```

---

# Prompt 04: Create Binding Module Contracts

## Goal

Create `docs/contracts.md`, centered on audio invariants and module boundaries.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 04 only.

Prerequisite:
Prompt 03 should be complete.

Goal:
Create binding module contracts for Orbisonic's current architecture.

Read first:
- AGENTS.md
- README.md
- Package.swift
- docs/status.md
- docs/product-brief.md
- docs/architecture.md
- docs/implementation-map.md
- Sources/AudioContracts/
- Sources/AudioImport/
- Sources/AudioCore/
- Sources/Orbisonic/
- Tests/

Create or update:
- docs/contracts.md
- docs/status.md

Do not change source code.
Do not change tests.
Do not refactor.
Do not rename files.
Do not alter app behavior.

`docs/contracts.md` must start with contract rules:

- Contracts are binding unless explicitly revised.
- Codex must not silently change public interfaces.
- If implementation requires a contract change, stop and document the proposed change.
- Every module should have tests matching its contract.
- Modules should avoid reaching across boundaries.
- Audio-path correctness outranks UI convenience.

Create contracts for the major current modules and feature boundaries. At minimum include:

1. AudioContracts
2. AudioImport
3. AudioCore
4. Orbisonic executable app shell
5. OrbisonicEngine or equivalent app audio engine owner
6. LiveAudioBridge or equivalent live loopback capture owner
7. Local file source and local library path
8. Roon integration boundary
9. Spotify integration boundary
10. Aux source boundary
11. Renderer and Sonic Sphere output boundary
12. Headphone or normal monitor boundary
13. Diagnostics and logging boundary
14. Installer and app bundle scripts boundary, if applicable

Each contract must include:

- Responsibility
- Non-responsibilities
- Public interface or public-facing concepts
- Inputs
- Outputs
- Data models
- Errors
- Side effects allowed
- Side effects forbidden
- Allowed dependencies
- Forbidden dependencies
- Security or privacy constraints
- Performance or audio-stability constraints
- Tests required
- Acceptance criteria

Use these Orbisonic-specific rules where supported by current repo evidence:

- `AudioContracts` defines shared language and must not own Core Audio device behavior, UI behavior, Roon behavior, Spotify behavior, or filesystem implementation details.
- `AudioImport` may classify and prepare local assets, but must not mutate live render graphs or silently perform production real-time conversion policy.
- `AudioCore` owns render planning, kernels, adapters, metering, or equivalent pure audio logic, but must not own SwiftUI state.
- Live loopback capture must not mask all-zero input with buffering tricks.
- Local file playback and live loopback capture are separate paths.
- Roon, Aux, Spotify, and local file sources must remain isolated unless an explicit future mixer design is accepted.
- The selected-source-only rule must be documented if supported by current docs or code.
- The headphone or monitor path must not mutate Sonic Sphere production output topology.
- Hardware-only behavior must be documented as manual verification when it cannot be tested in CI.

Out of scope for this prompt:

- No production code changes
- No tests added
- No interface changes
- No new dependencies

Acceptance criteria:

- `docs/contracts.md` exists and is specific enough to constrain future Codex work.
- Each major module has responsibility and non-responsibility sections.
- Audio invariants are explicit.
- Hardware/manual verification gaps are explicit.
- `docs/status.md` records this prompt as a recent change.

Verification:

Docs-only prompt. No build required unless source files changed by mistake. Confirm no source files were changed.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 05.
```

---

# Prompt 05: Create System Flows With Mermaid Diagrams

## Goal

Create diagrams that let the user and future Codex sessions understand the system without reading source code.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 05 only.

Prerequisite:
Prompt 04 should be complete.

Goal:
Create `docs/system-flows.md` with plain-English flow descriptions and Mermaid diagrams.

Read first:
- AGENTS.md
- README.md
- Package.swift
- docs/status.md
- docs/product-brief.md
- docs/architecture.md
- docs/contracts.md
- docs/implementation-map.md
- existing docs/
- Sources/
- Tests/

Create or update:
- docs/system-flows.md
- docs/status.md

Do not change source code.
Do not change tests.
Do not refactor.
Do not alter app behavior.

`docs/system-flows.md` must include Mermaid diagrams and short explanations for the flows that the current repo supports.

Include these sections when supported by repo evidence:

1. System context
2. Local file playback flow
3. Live Roon loopback flow
4. Aux loopback flow
5. Spotify receiver flow
6. Renderer and Sonic Sphere output flow
7. Headphone or normal monitor flow
8. Route diagnostics flow
9. Test tone flow
10. Error and logging flow
11. Manual hardware verification flow

Mermaid diagram types to use:

- flowchart TD or LR for system context and data flows
- sequenceDiagram for source-to-renderer sequences
- stateDiagram-v2 if there is a useful playback or source state model

Rules:

- Use plain names that match docs/contracts.md.
- Do not invent new runtime components.
- Distinguish production Sonic Sphere output from monitor output.
- Distinguish local files from live loopback sources.
- Distinguish Roon, Spotify, and Aux sources.
- Mark hardware/manual-only checks clearly.

Out of scope for this prompt:

- No source changes
- No tests added
- No UI redesign
- No new behavior

Acceptance criteria:

- Diagrams are readable in Markdown.
- Diagrams match current architecture and contracts.
- A project owner can understand the main audio flows without source-code inspection.
- `docs/status.md` records this prompt as a recent change.

Verification:

Docs-only prompt. No build required unless source files changed by mistake. Confirm no source files were changed.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 06.
```

---

# Prompt 06: Create Test Strategy And Verification Map

## Goal

Create a test strategy that maps existing tests to contracts and identifies verification gaps.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 06 only.

Prerequisite:
Prompt 05 should be complete.

Goal:
Create `docs/test-strategy.md` for Orbisonic's current repo and audio risks.

Read first:
- AGENTS.md
- README.md
- Package.swift
- docs/status.md
- docs/product-brief.md
- docs/architecture.md
- docs/contracts.md
- docs/system-flows.md
- docs/implementation-map.md
- Tests/
- Sources/

Create or update:
- docs/test-strategy.md
- docs/status.md

Do not change source code.
Do not change tests yet.
Do not refactor.
Do not alter app behavior.

`docs/test-strategy.md` must include:

- Testing goals
- Test types
- Existing test target map
- Contract-to-test map
- Critical audio invariants
- Required checks
- Manual verification requirements
- Test data rules
- Coverage expectations
- Completion rule
- Known test gaps

Map existing test targets such as:

- AudioContractsTests
- AudioImportTests
- AudioCoreTests
- OrbisonicTests

Map tests to invariants such as:

- Source channel count cap and layout handling
- Local file path stays separate from live loopback path
- Roon, Spotify, Aux, and local sources stay isolated
- Renderer topology does not drift silently
- Monitor path does not mutate production Sonic Sphere path
- Hardware-unavailable behavior is explicit
- All-zero live input is diagnosed rather than hidden
- Sample-rate and channel-count mismatches are visible

Required verification commands section must include the repo's real commands, especially:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `./scripts/refresh-orbisonic-app.sh` when app code changes
- `./scripts/reopen-orbisonic-app.sh` when GUI/audio behavior needs LaunchServices verification

Manual verification section must call out:

- Sonic Sphere / Dante or production output hardware verification
- Roon loopback device verification
- Aux loopback device verification
- Spotify Connect receiver verification
- macOS microphone permission behavior for loopback devices
- App signing or entitlement gaps, if relevant
- Installer verification

Out of scope for this prompt:

- No source changes
- No test changes
- No new test harness
- No CI changes unless already present and docs-only

Acceptance criteria:

- Existing tests are mapped to behavior.
- Missing tests are called out honestly.
- Manual hardware verification is separated from automated testing.
- `docs/status.md` records this prompt as a recent change.

Verification:

Docs-only prompt. No build required unless source files changed by mistake. Confirm no source files were changed.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 07.
```

---

# Prompt 07: Add Retrospective Architecture Decision Records

## Goal

Capture decisions already made by the existing repo so future Codex sessions do not re-litigate them.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 07 only.

Prerequisite:
Prompt 06 should be complete.

Goal:
Create retrospective architecture decision records for the current Orbisonic architecture.

Read first:
- AGENTS.md
- README.md
- Package.swift
- docs/status.md
- docs/product-brief.md
- docs/architecture.md
- docs/contracts.md
- docs/system-flows.md
- docs/implementation-map.md
- docs/test-strategy.md
- existing docs/
- Sources/
- Tests/

Create or update:
- docs/decisions/0001-retrofit-not-rewrite.md
- docs/decisions/0002-swiftpm-target-boundaries.md
- docs/decisions/0003-audio-contracts-as-shared-language.md
- docs/decisions/0004-selected-source-only-rule.md
- docs/decisions/0005-sonic-sphere-30-1-primary-output.md
- docs/decisions/0006-embedded-librespot-boundary.md
- docs/decisions/0007-roon-loopback-boundary.md
- docs/status.md

If any decision is not supported by current repo evidence, either revise the decision title to match reality or mark it as proposed instead of accepted.

Each ADR must include:

- Status
- Context
- Decision
- Rationale
- Alternatives considered
- Consequences
- Follow-up

ADR guidance:

`0001-retrofit-not-rewrite.md`:
- Decision should state that current Orbisonic is the baseline and the retrofit adds control docs, contracts, tests, and hardening rather than rewriting the app.

`0002-swiftpm-target-boundaries.md`:
- Decision should capture the existing SwiftPM target split as the starting architecture.

`0003-audio-contracts-as-shared-language.md`:
- Decision should capture AudioContracts as the common type and vocabulary layer.

`0004-selected-source-only-rule.md`:
- Decision should capture Roon, Aux, Spotify, and local source isolation if current repo evidence supports it.

`0005-sonic-sphere-30-1-primary-output.md`:
- Decision should capture Sonic Sphere production output as primary and headphone or binaural output as monitor path if current repo evidence supports it.

`0006-embedded-librespot-boundary.md`:
- Decision should capture the Spotify receiver boundary if current repo evidence supports embedded librespot or related FFI integration.

`0007-roon-loopback-boundary.md`:
- Decision should capture Roon transport or loopback responsibilities and non-responsibilities.

Out of scope for this prompt:

- No source changes
- No tests added
- No behavior changes

Acceptance criteria:

- ADRs exist and are factual.
- Accepted decisions are supported by current repo evidence.
- Proposed or uncertain decisions are clearly marked.
- `docs/status.md` links or summarizes the decision log.
- `docs/status.md` records this prompt as a recent change.

Verification:

Docs-only prompt. No build required unless source files changed by mistake. Confirm no source files were changed.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 08.
```

---

# Prompt 08: Upgrade AGENTS.md Without Losing Existing Rules

## Goal

Make `AGENTS.md` the operating constitution for Codex in this repo.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 08 only.

Prerequisite:
Prompt 07 should be complete.

Goal:
Upgrade AGENTS.md into a full repo-level instruction file while preserving all existing Orbisonic-specific rules.

Read first:
- AGENTS.md
- README.md
- Package.swift
- docs/status.md
- docs/product-brief.md
- docs/architecture.md
- docs/contracts.md
- docs/system-flows.md
- docs/implementation-map.md
- docs/test-strategy.md
- docs/decisions/

Create or update:
- AGENTS.md
- docs/status.md

Do not change source code.
Do not change tests.
Do not alter app behavior.

AGENTS.md must preserve existing rules about:

- Canonical project root
- Stale old workspaces
- Native Swift/macOS app status
- Sonic Sphere meaning
- Privacy hygiene
- Design reference and visual language, if present
- Build and verification commands
- LaunchServices app reopening
- Audio priorities
- Live audio failure diagnosis
- Roon live path
- Aux live path
- Microphone permission behavior
- Separation of local file playback and Roon live capture
- Roon/live-loopback troubleshooting logs and metrics

Then add the project control sections:

- Purpose
- Read First
- Task discipline
- Documentation requirements
- Testing requirements
- Audio-specific operating rules
- Privacy and secret-handling rules
- Stopping conditions
- Final response format
- Definition of done

Read First must include:

- docs/status.md
- docs/product-brief.md
- docs/architecture.md
- docs/contracts.md
- docs/system-flows.md
- docs/implementation-map.md
- docs/test-strategy.md
- relevant docs/decisions files
- relevant .tasks file once .tasks exists

Stopping conditions must include:

- A public contract needs to change
- A major dependency is required
- The task conflicts with existing docs
- The task touches unrelated subsystems
- Tests fail for reasons outside the task
- Hardware-only behavior cannot be verified and the task requires verification
- The repo appears to be stale or not the active native Swift app
- The work would mask live audio failures instead of diagnosing them

Definition of done must include:

- Requested behavior or doc change complete
- Relevant tests added or updated for behavioral changes
- Relevant checks run or blockers documented
- docs/status.md updated
- docs/implementation-map.md updated when files change
- docs/system-flows.md updated when flows change
- docs/contracts.md updated only when explicitly allowed
- Assumptions and risks documented

Out of scope for this prompt:

- No source changes
- No tests added
- No behavioral changes
- Do not delete existing AGENTS content unless replacing it with equivalent or clearer language

Acceptance criteria:

- AGENTS.md is comprehensive and repo-specific.
- Existing Orbisonic-specific rules are preserved.
- Future Codex sessions have clear instructions.
- `docs/status.md` records this prompt as a recent change.

Verification:

Docs-only prompt. No build required unless source files changed by mistake. Confirm no source files were changed.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 09.
```

---

# Prompt 09: Create The .tasks Control Graph

## Goal

Create bounded Codex task files that future work can execute one at a time.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 09 only.

Prerequisite:
Prompt 08 should be complete.

Goal:
Create a .tasks directory with bounded, sequential task files for the Orbisonic retrofit and hardening program.

Read first:
- AGENTS.md
- README.md
- Package.swift
- docs/status.md
- docs/product-brief.md
- docs/architecture.md
- docs/contracts.md
- docs/system-flows.md
- docs/implementation-map.md
- docs/test-strategy.md
- docs/decisions/
- Sources/
- Tests/

Create or update:
- .tasks/000-retrofit-control-docs.md
- .tasks/001-plan-audit.md
- .tasks/002-fix-plan-audit-findings.md
- .tasks/003-contract-test-gap-audit.md
- .tasks/004-contract-test-gap-pass.md
- .tasks/005-architecture-boundary-test-pass.md
- .tasks/006-audio-boundary-hardening-plan.md
- .tasks/007-live-loopback-diagnostics-hardening.md
- .tasks/008-source-isolation-hardening.md
- .tasks/009-renderer-monitor-boundary-hardening.md
- .tasks/010-installer-and-release-verification-docs.md
- .tasks/011-documentation-refresh-and-readiness.md
- docs/status.md

Each task file must include:

- Task title and ID
- Status
- Goal
- Background
- Relevant docs to read
- Scope
- Out of scope
- Contract references
- Expected files
- Acceptance criteria
- Verification commands
- Stopping conditions
- Required final summary

Task intent:

`000-retrofit-control-docs.md`:
- Documents the docs-only retrofit already performed by Prompts 02 through 08.

`001-plan-audit.md`:
- Asks Codex to audit the docs and task graph without code changes.

`002-fix-plan-audit-findings.md`:
- Applies accepted audit fixes to docs and tasks only.

`003-contract-test-gap-audit.md`:
- Finds contract claims not covered by tests.

`004-contract-test-gap-pass.md`:
- Adds or updates tests for the most important missing contract coverage. No production behavior changes unless a test exposes a genuine bug and the task is explicitly expanded.

`005-architecture-boundary-test-pass.md`:
- Adds or strengthens tests that protect module boundaries.

`006-audio-boundary-hardening-plan.md`:
- Produces a code-hardening plan based on docs and test gaps. No production code changes.

`007-live-loopback-diagnostics-hardening.md`:
- Hardens live loopback diagnosis without masking all-zero input.

`008-source-isolation-hardening.md`:
- Hardens Roon, Aux, Spotify, and local source isolation.

`009-renderer-monitor-boundary-hardening.md`:
- Hardens boundary between Sonic Sphere production renderer and monitor path.

`010-installer-and-release-verification-docs.md`:
- Updates installer and release verification docs, scripts only if explicitly necessary and low risk.

`011-documentation-refresh-and-readiness.md`:
- Refreshes all docs after hardening and produces a release-readiness summary.

Out of scope for this prompt:

- No production code changes
- No tests added
- No behavior changes

Acceptance criteria:

- `.tasks/` exists.
- Each task is bounded and executable.
- Task ordering is dependency-aware.
- Code-affecting tasks are separated from docs-only tasks.
- Hardware verification gaps are documented in relevant tasks.
- `docs/status.md` records this prompt as a recent change.

Verification:

Docs-only prompt. No build required unless source files changed by mistake. Confirm no source files were changed.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 10.
```

---

# Prompt 10: Plan Audit, No Code Changes

## Goal

Use Codex to audit the new project control package before implementation work begins.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 10 only.

Prerequisite:
Prompt 09 should be complete.

Goal:
Audit the Orbisonic project control package for correctness, gaps, contradictions, and risky task ordering.

Read first:
- AGENTS.md
- README.md
- Package.swift
- docs/status.md
- docs/product-brief.md
- docs/architecture.md
- docs/contracts.md
- docs/system-flows.md
- docs/implementation-map.md
- docs/test-strategy.md
- docs/decisions/
- .tasks/
- Sources/
- Tests/

Create or update:
- docs/audits/0001-plan-audit.md
- docs/status.md

Do not change production code.
Do not change tests.
Do not fix the docs yet, except for updating status and writing the audit report.
Do not refactor.
Do not alter app behavior.

Audit for:

- Missing product requirements
- Stale assumptions versus current repo
- Unclear module boundaries
- Missing module contracts
- Contradictory instructions
- Untestable requirements
- Bad task ordering
- Missing stopping conditions
- Missing hardware/manual verification steps
- Areas where implementation would likely drift from docs
- Places where AGENTS.md conflicts with docs or tasks
- Places where docs imply behavior not supported by code or tests
- Places where tests imply behavior not reflected in docs

The audit report must include:

1. Executive summary
2. Issues found, grouped by severity
3. Recommended doc changes
4. Recommended task changes
5. Recommended test strategy changes
6. Questions that block implementation
7. Questions that can be treated as assumptions
8. Risk of proceeding without fixing each issue
9. Recommended next prompt

Severity categories:

- Blocker
- High
- Medium
- Low

Out of scope for this prompt:

- No production code changes
- No test changes
- No doc fixes besides the audit file and status update

Acceptance criteria:

- `docs/audits/0001-plan-audit.md` exists.
- The audit compares docs against actual repo evidence.
- Blockers are clearly separated from non-blocking assumptions.
- `docs/status.md` records this prompt as a recent change.

Verification:

Docs-only prompt. No build required unless source files changed by mistake. Confirm no source files were changed.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 11.
```

---

# Prompt 11: Apply Plan Audit Findings, Docs And Tasks Only

## Goal

Fix the issues found in the plan audit before adding tests or touching production code.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 11 only.

Prerequisite:
Prompt 10 should be complete and `docs/audits/0001-plan-audit.md` should exist.

Goal:
Apply accepted plan-audit fixes to docs and task files only.

Read first:
- AGENTS.md
- docs/audits/0001-plan-audit.md
- docs/status.md
- docs/product-brief.md
- docs/architecture.md
- docs/contracts.md
- docs/system-flows.md
- docs/implementation-map.md
- docs/test-strategy.md
- docs/decisions/
- .tasks/
- README.md
- Package.swift
- Sources/
- Tests/

Create or update, only as needed:
- AGENTS.md
- docs/status.md
- docs/product-brief.md
- docs/architecture.md
- docs/contracts.md
- docs/system-flows.md
- docs/implementation-map.md
- docs/test-strategy.md
- docs/decisions/*.md
- .tasks/*.md

Do not change production code.
Do not change tests.
Do not refactor.
Do not alter app behavior.

Apply fixes for:

- Blocker audit findings
- High-severity audit findings
- Any medium-severity findings that make future tasks ambiguous or risky

Do not guess product decisions. If a finding requires the user's decision, preserve it as an open question in `docs/status.md` instead of inventing an answer.

For every audit issue addressed, either:

- update the relevant file, or
- document why it remains open

Create or update a section in `docs/status.md` that summarizes:

- Audit issues fixed
- Audit issues left open
- Questions requiring the user
- Whether the project is ready for contract-test gap audit

Out of scope for this prompt:

- No source code changes
- No test changes
- No new features
- No new dependencies

Acceptance criteria:

- Blocker and high-severity audit issues are resolved or explicitly carried forward as blockers.
- Docs and tasks no longer contradict each other on critical points.
- `docs/status.md` records this prompt as a recent change.
- The next task is safe to run.

Verification:

Docs-only prompt. No build required unless source files changed by mistake. Confirm no source files were changed.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 12.
```

---

# Prompt 12: Contract-Test Gap Audit, No Code Changes

## Goal

Find the most important contract claims that lack test coverage.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 12 only.

Prerequisite:
Prompt 11 should be complete and no plan-audit blockers should remain unresolved unless explicitly documented.

Goal:
Audit contract coverage against existing tests.

Read first:
- AGENTS.md
- docs/status.md
- docs/contracts.md
- docs/test-strategy.md
- docs/implementation-map.md
- docs/system-flows.md
- docs/audits/0001-plan-audit.md
- .tasks/003-contract-test-gap-audit.md
- Package.swift
- Sources/
- Tests/

Create or update:
- docs/audits/0002-contract-test-gap-audit.md
- docs/test-strategy.md, only to add discovered gaps if needed
- docs/status.md

Do not change production code.
Do not change tests in this prompt.
Do not refactor.
Do not alter app behavior.

Audit method:

1. Read every contract in `docs/contracts.md`.
2. Identify the behavioral claims and forbidden behaviors.
3. Search existing tests for coverage.
4. Categorize coverage as covered, partially covered, not covered, or manual-only.
5. Prioritize gaps by audio risk and regression likelihood.

Focus first on these invariants:

- `AudioContracts` remains a shared vocabulary layer.
- `AudioImport` does not mutate live render graphs.
- `AudioCore` stays independent of SwiftUI/app UI state.
- Local file playback is separate from live loopback capture.
- Roon, Aux, Spotify, and local sources remain isolated.
- Selected-source-only behavior is protected if documented.
- All-zero live loopback input is diagnosed rather than hidden.
- Sample-rate and channel-count mismatches are surfaced.
- Monitor path does not mutate production Sonic Sphere topology.
- Renderer topology does not silently drift.
- Hardware-only behavior is marked manual-only.

The audit report must include:

1. Contract coverage summary
2. Highest-risk untested claims
3. Existing tests that already cover important contracts
4. Tests to add first
5. Tests that should not be automated because they require hardware
6. Suggested scope for Prompt 13
7. Any contradictions between contracts and tests
8. Recommended next prompt

Out of scope for this prompt:

- No source changes
- No test changes
- No dependency changes

Acceptance criteria:

- `docs/audits/0002-contract-test-gap-audit.md` exists.
- Test gaps are prioritized.
- Prompt 13 has a clear smallest useful test scope.
- `docs/status.md` records this prompt as a recent change.

Verification:

Docs-only prompt. No build required unless source files changed by mistake. Confirm no source files were changed.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 13.
```

---

# Prompt 13: Add The Highest-Value Contract Tests, Tests Only

## Goal

Add or update tests for the highest-risk untested contract claims. Do not change production behavior.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 13 only.

Prerequisite:
Prompt 12 should be complete and `docs/audits/0002-contract-test-gap-audit.md` should identify prioritized test gaps.

Goal:
Add or update the smallest useful set of tests that protect the highest-risk Orbisonic contracts.

Read first:
- AGENTS.md
- docs/status.md
- docs/contracts.md
- docs/test-strategy.md
- docs/implementation-map.md
- docs/audits/0002-contract-test-gap-audit.md
- .tasks/004-contract-test-gap-pass.md
- Package.swift
- Sources/
- Tests/

Allowed changes:
- Tests only
- Test fixtures only
- Test helper code only if scoped to tests
- Docs updates required by this prompt

Create or update, as needed:
- Tests/AudioContractsTests/
- Tests/AudioImportTests/
- Tests/AudioCoreTests/
- Tests/OrbisonicTests/
- docs/test-strategy.md
- docs/implementation-map.md if test files are added or repurposed
- docs/status.md

Do not change production source code unless a test cannot compile due to an obvious test-only access issue. If production changes appear necessary, stop and report instead of making them.
Do not refactor.
Do not alter app behavior.
Do not add dependencies.

Select the smallest set of tests from the audit that covers the highest-risk contract gaps. Prefer tests around:

- Source isolation
- Selected-source-only behavior
- Renderer/monitor boundary
- AudioContracts invariants
- Live loopback diagnosis rules
- Sample-rate/channel-count mismatch surfacing
- No fake multichannel expansion at source capture
- Hardware-unavailable behavior being explicit

Rules:

- Keep tests deterministic.
- Do not require real Sonic Sphere hardware.
- Do not require live Roon, Spotify, or Aux devices.
- Do not require network access.
- Do not store personal paths or secrets.
- If a behavior requires hardware, document it as manual-only instead of writing a fake automated test.

Acceptance criteria:

- Tests cover at least the highest-priority gap from `docs/audits/0002-contract-test-gap-audit.md`.
- No production behavior changes are made.
- Relevant tests pass or blockers are documented.
- `docs/test-strategy.md` reflects the new coverage.
- `docs/implementation-map.md` is updated if test files changed materially.
- `docs/status.md` records this prompt as a recent change.

Verification:

Run:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`

If this command cannot run, document the exact environment reason.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 14.
```

---

# Prompt 14: Architecture Boundary Test Pass

## Goal

Strengthen tests that prevent accidental module-boundary drift.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 14 only.

Prerequisite:
Prompt 13 should be complete.

Goal:
Add or improve tests that protect Orbisonic's architecture boundaries.

Read first:
- AGENTS.md
- docs/status.md
- docs/architecture.md
- docs/contracts.md
- docs/implementation-map.md
- docs/test-strategy.md
- .tasks/005-architecture-boundary-test-pass.md
- Package.swift
- Sources/
- Tests/

Allowed changes:
- Tests only
- Test helpers only if scoped to tests
- Docs updates required by this prompt

Create or update, as needed:
- Existing architecture boundary tests under Tests/
- Tests that inspect module boundaries or enforce import restrictions if the repo already uses that pattern
- docs/test-strategy.md
- docs/implementation-map.md if test files are added or repurposed
- docs/status.md

Do not change production source code.
Do not refactor.
Do not alter app behavior.
Do not add dependencies.

Priority boundary checks:

- AudioContracts must not depend on app, UI, Roon, Spotify, filesystem implementation, or Core Audio device management.
- AudioCore must not depend on SwiftUI or app UI state.
- AudioImport must not depend on live loopback capture or app UI.
- Orbisonic app may depend on AudioContracts, AudioImport, and AudioCore, but shared packages should not depend back on the app.
- Source integration code should not mutate renderer topology directly unless existing contracts explicitly allow it.
- Monitor path should not own Sonic Sphere production topology.

If import-boundary tests are impractical in SwiftPM without new tooling, create a lightweight test or audit fixture only if it is maintainable. Otherwise document the manual architecture review rule in `docs/test-strategy.md` and `docs/status.md`.

Acceptance criteria:

- At least one meaningful architecture boundary is covered by tests or explicitly documented as manual-only with rationale.
- No production behavior changes are made.
- Relevant tests pass or blockers are documented.
- `docs/test-strategy.md` reflects the new boundary coverage.
- `docs/status.md` records this prompt as a recent change.

Verification:

Run:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`

If this command cannot run, document the exact environment reason.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 15.
```

---

# Prompt 15: Live Loopback Diagnostics Hardening

## Goal

Harden live loopback diagnostics without hiding routing, sample-rate, or source-device failures.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 15 only.

Prerequisite:
Prompts 01 through 14 should be complete. Tests should pass or known blockers should be documented.

Goal:
Harden live loopback diagnostics while preserving the repo's rule that all-zero live input must be diagnosed, not masked.

Read first:
- AGENTS.md
- docs/status.md
- docs/product-brief.md
- docs/architecture.md
- docs/contracts.md
- docs/system-flows.md
- docs/implementation-map.md
- docs/test-strategy.md
- docs/audits/0002-contract-test-gap-audit.md
- .tasks/007-live-loopback-diagnostics-hardening.md
- relevant docs/decisions/
- Package.swift
- relevant source files for live loopback, diagnostics, route monitoring, and logs
- relevant tests

Likely relevant production areas, verify current paths before editing:
- Sources/Orbisonic/LiveAudioBridge.swift
- Sources/Orbisonic/LoopbackSourceSupport.swift
- Sources/Orbisonic/BlackHoleRouteRepair.swift, if present
- Sources/Orbisonic/DiagnosticsLogStore.swift, if present
- Sources/Orbisonic/AppLogger.swift, if present
- related diagnostics or route-monitor files

Likely relevant tests, verify current paths before editing:
- Tests/OrbisonicTests/LiveAudioBridgeTests.swift or equivalent
- Tests/OrbisonicTests/LoopbackSourceSupportTests.swift or equivalent
- diagnostics or route-monitor tests

Scope:

- Improve diagnostics for silent live input, route mismatch, sample-rate mismatch, channel-count mismatch, unavailable input device, and buffer underrun/drop counters.
- Make failure states explicit in logs or diagnostic models.
- Preserve selected live source semantics.
- Add or update regression tests for deterministic diagnostic behavior.
- Update docs affected by the change.

Out of scope:

- Do not redesign the live audio engine.
- Do not add new external dependencies.
- Do not change local file playback behavior.
- Do not change Roon transport control behavior unless directly necessary for diagnostics.
- Do not change Spotify receiver behavior.
- Do not change renderer topology.
- Do not mask all-zero input with buffering, gain, synthetic signal, fake channels, or silent fallback routing.
- Do not require real hardware in automated tests.

Acceptance criteria:

- Silent live input is diagnosed as a route, sample-rate, channel-count, device availability, permission, or source problem where possible.
- Diagnostics make it easier to distinguish Roon playback activity from Orbisonic loopback capture activity.
- All-zero input remains visible as a failure state.
- Tests cover the new diagnostic behavior without requiring hardware.
- Relevant tests pass or blockers are documented.
- `docs/system-flows.md` is updated if diagnostic flow changed.
- `docs/implementation-map.md` is updated if files changed materially.
- `docs/test-strategy.md` is updated if tests changed coverage.
- `docs/status.md` records this prompt as a recent change.

Verification:

Run:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`

If app code changed and environment supports it, also run:

- `./scripts/refresh-orbisonic-app.sh`

If GUI/audio behavior requires runtime verification and environment supports it, use:

- `./scripts/reopen-orbisonic-app.sh`

If hardware is unavailable, document manual verification steps instead.

Stopping conditions:

Stop and report if:
- The fix requires changing a public contract.
- The fix requires a major engine rewrite.
- The fix requires real Sonic Sphere, Roon, Spotify, or Aux hardware to proceed.
- The fix would mask all-zero input rather than diagnose it.
- The work touches unrelated subsystems.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 16.
```

---

# Prompt 16: Source Isolation Hardening

## Goal

Protect Roon, Aux, Spotify, and local file source boundaries.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 16 only.

Prerequisite:
Prompt 15 should be complete.

Goal:
Harden source isolation so Roon, Aux, Spotify, and local file paths remain distinct unless an explicit mixer design is later accepted.

Read first:
- AGENTS.md
- docs/status.md
- docs/architecture.md
- docs/contracts.md
- docs/system-flows.md
- docs/implementation-map.md
- docs/test-strategy.md
- docs/decisions/0004-selected-source-only-rule.md, if present
- .tasks/008-source-isolation-hardening.md
- Package.swift
- relevant source integration files
- relevant tests

Likely relevant production areas, verify current paths before editing:
- Local file source and library files
- Live loopback bridge/support files
- Roon bridge/client/now-playing files
- Spotify receiver files
- app source-selection state or view model files
- engine source connection logic

Scope:

- Audit and harden source-selection logic.
- Ensure selected-source-only behavior is explicit where applicable.
- Prevent accidental summing or cross-wiring of Roon and Aux.
- Prevent Spotify receiver behavior from pretending to be multichannel unless the input actually provides multichannel data.
- Keep local file playback separate from live capture.
- Add or update deterministic tests for source isolation.
- Update docs affected by the change.

Out of scope:

- Do not implement a new mixer.
- Do not add simultaneous source playback unless a contract explicitly allows it.
- Do not redesign the UI.
- Do not change renderer topology.
- Do not change installer behavior.
- Do not add new dependencies.
- Do not require live Roon, Spotify, or Aux devices in automated tests.

Acceptance criteria:

- Source selection behavior is clear in code and docs.
- Roon, Aux, Spotify, and local file source states do not leak into each other.
- Tests cover at least the highest-risk source isolation path.
- Hardware-only verification is documented separately.
- Relevant tests pass or blockers are documented.
- `docs/contracts.md` is not changed unless the task explicitly requires and justifies a contract clarification.
- `docs/system-flows.md` is updated if source flow changed.
- `docs/implementation-map.md` is updated if files changed materially.
- `docs/test-strategy.md` is updated if tests changed coverage.
- `docs/status.md` records this prompt as a recent change.

Verification:

Run:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`

If app code changed and environment supports it, also run:

- `./scripts/refresh-orbisonic-app.sh`

If hardware/runtime verification is unavailable, document manual verification steps.

Stopping conditions:

Stop and report if:
- The change requires a new mixer contract.
- The change requires a major engine rewrite.
- The change requires new dependencies.
- The change requires live external services to proceed.
- The work touches unrelated renderer, installer, or UI systems.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 17.
```

---

# Prompt 17: Renderer And Monitor Boundary Hardening

## Goal

Protect Sonic Sphere production rendering from accidental monitor-path regressions.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 17 only.

Prerequisite:
Prompt 16 should be complete.

Goal:
Harden the boundary between the Sonic Sphere production renderer and the headphone or normal monitor path.

Read first:
- AGENTS.md
- docs/status.md
- docs/architecture.md
- docs/contracts.md
- docs/system-flows.md
- docs/implementation-map.md
- docs/test-strategy.md
- docs/decisions/0005-sonic-sphere-30-1-primary-output.md, if present
- .tasks/009-renderer-monitor-boundary-hardening.md
- Package.swift
- renderer-related source files
- monitor-related source files
- related tests

Likely relevant production areas, verify current paths before editing:
- RendererModule or equivalent
- RendererMatrixSampleRenderer or equivalent
- RenderGraphPlan and RenderKernels under AudioCore, if present
- NormalMonitorStereoDownmixer or equivalent
- NormalMonitorGraphTopology or equivalent
- PureAudio route capability bridge or equivalent
- output route monitor files

Scope:

- Make production renderer topology and monitor topology responsibilities explicit in code or tests.
- Ensure monitor-path changes do not mutate Sonic Sphere production output topology.
- Ensure renderer topology changes are covered by deterministic tests.
- Add or update tests for topology separation.
- Update docs affected by the change.

Out of scope:

- Do not redesign the renderer.
- Do not implement new spatial algorithms.
- Do not change source-selection behavior.
- Do not change Roon, Spotify, Aux, or local source behavior.
- Do not change installer behavior.
- Do not add dependencies.
- Do not require Sonic Sphere hardware in automated tests.

Acceptance criteria:

- Production Sonic Sphere output topology remains primary and explicit.
- Monitor path remains a monitoring/preview surface.
- Tests protect against accidental topology drift or monitor-to-production mutation.
- Hardware-only verification is documented separately.
- Relevant tests pass or blockers are documented.
- `docs/contracts.md` is not changed unless the task explicitly requires and justifies a contract clarification.
- `docs/system-flows.md` is updated if renderer or monitor flow changed.
- `docs/implementation-map.md` is updated if files changed materially.
- `docs/test-strategy.md` is updated if tests changed coverage.
- `docs/status.md` records this prompt as a recent change.

Verification:

Run:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`

If app code changed and environment supports it, also run:

- `./scripts/refresh-orbisonic-app.sh`

If hardware/runtime verification is unavailable, document manual verification steps.

Stopping conditions:

Stop and report if:
- The change requires a renderer contract change.
- The change requires a major renderer rewrite.
- The change requires live Sonic Sphere hardware to proceed.
- The work touches unrelated source integrations.
- The change would make monitor output the production source of truth.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 18.
```

---

# Prompt 18: Installer And Release Verification Docs

## Goal

Make release and installer verification explicit, especially hardware and app-bundle checks.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 18 only.

Prerequisite:
Prompt 17 should be complete, or production-code hardening should be intentionally paused.

Goal:
Document installer, app bundle, release, and manual verification procedures for Orbisonic.

Read first:
- AGENTS.md
- README.md
- RELEASE_NOTES.md, if present
- docs/status.md
- docs/product-brief.md
- docs/architecture.md
- docs/contracts.md
- docs/system-flows.md
- docs/implementation-map.md
- docs/test-strategy.md
- installer/
- scripts/
- Package.swift
- app entitlement files, if present

Create or update:
- docs/release-verification.md
- docs/implementation-map.md
- docs/test-strategy.md
- docs/status.md
- README.md only if current run instructions are stale or materially incomplete
- RELEASE_NOTES.md only if the repo already uses it and a small note is appropriate

Production source changes are out of scope.
Script changes are out of scope unless a script path in docs is clearly stale and the fix is trivial. If script behavior needs repair, stop and recommend a separate task.

`docs/release-verification.md` must include:

- Build and test commands
- App bundle refresh procedure
- LaunchServices reopen procedure
- Installer location and verification steps
- Roon bridge verification steps
- Roon loopback verification steps
- Aux loopback verification steps
- Spotify receiver verification steps
- Sonic Sphere / Dante output verification steps
- Headphone or monitor output verification steps
- macOS microphone permission note for loopback devices
- Entitlement/signing checks if relevant
- Logs to inspect
- Manual smoke-test checklist
- Known hardware requirements
- Known blockers and limitations

Out of scope:

- No production code changes
- No major script rewrites
- No installer rebuild unless explicitly required by existing repo workflow and safe
- No new dependencies

Acceptance criteria:

- Release verification is documented without requiring source-code inspection.
- Hardware-only checks are clear and separated from automated checks.
- Existing README or release notes are not contradicted.
- `docs/implementation-map.md` mentions release/installer docs and scripts.
- `docs/test-strategy.md` mentions release smoke tests and manual checks.
- `docs/status.md` records this prompt as a recent change.

Verification:

For docs-only work, no build is required. If you touch scripts, run the smallest safe verification command or explain why you did not.

Final response must use the standard summary format.
Recommended next prompt should be: Prompt 19.
```

---

# Prompt 19: Final Documentation Refresh And Readiness Review

## Goal

Refresh all project control docs after the retrofit and hardening sequence.

## Prompt To Codex

```text
You are working in the active Orbisonic repository.

Run Prompt 19 only.

Prerequisite:
Prompts 01 through 18 should be complete, or skipped prompts should be documented in `docs/status.md` with reasons.

Goal:
Refresh the project control docs so the user can understand the current system state without reading source code.

Read first:
- AGENTS.md
- README.md
- Package.swift
- docs/status.md
- docs/product-brief.md
- docs/architecture.md
- docs/contracts.md
- docs/system-flows.md
- docs/implementation-map.md
- docs/test-strategy.md
- docs/release-verification.md, if present
- docs/decisions/
- docs/audits/
- .tasks/
- Sources/
- Tests/

Create or update:
- docs/status.md
- docs/product-brief.md, only if stale
- docs/architecture.md, only if stale
- docs/contracts.md, only if stale and changes are clarifications rather than new contracts
- docs/system-flows.md, only if stale
- docs/implementation-map.md
- docs/test-strategy.md
- docs/release-verification.md, if present
- .tasks/*.md statuses, if appropriate

Do not change production code.
Do not change tests.
Do not refactor.
Do not alter app behavior.

Review and refresh for:

- Stale file paths
- Stale module names
- Stale test descriptions
- Missing risks
- Resolved risks that can be marked complete
- Open questions that remain real
- Manual verification gaps
- Contradictions across docs
- Task status accuracy
- Release-readiness state

`docs/status.md` must end with a clear current state:

- Current phase
- Current milestone
- Completed retrofit work
- Completed hardening work
- Remaining risks
- Blockers
- Manual verification still needed
- Commands most recently run
- Test status
- Recommended next concrete task

Out of scope:

- No source changes
- No test changes
- No new features
- No new dependencies

Acceptance criteria:

- Project-control docs are internally consistent.
- A non-code-reading project owner can understand the current state.
- Future Codex sessions have clear next steps.
- `docs/status.md` is the reliable control panel.

Verification:

Docs-only prompt. No build required unless source files changed by mistake. Confirm no source files were changed.

Final response must use the standard summary format.
Recommended next prompt should be one of:

- A specific remaining task from `.tasks/`
- A new task file if the refresh discovered a necessary follow-up
- `none`, if the retrofit sequence is complete and no immediate task is recommended
```

---

# Appendix A: One-Shot Codex Instruction If The User Wants Batch Execution

Use this only when the user wants Codex to process multiple prompts from this file in one session.

```text
Read `orbisonic_codex_prompt_sequence.md` completely.

Execute the prompts sequentially, starting with Prompt 01.

After each prompt:
- Apply only the scope of that prompt.
- Run that prompt's verification steps.
- Update docs/status.md if required.
- Record files changed, tests changed, commands run, results, assumptions, risks, blockers, and the next prompt.

Continue to the next prompt only if:
- The current prompt's acceptance criteria passed.
- No stopping condition was hit.
- No blocker requiring the user's decision was found.

Stop immediately if:
- A public contract needs to change unexpectedly.
- A major dependency is required.
- The task touches unrelated subsystems.
- The repo state contradicts the prompt.
- Hardware-only verification is required to proceed.
- Tests fail for reasons outside the current prompt.
- The work would mask live audio failure instead of diagnosing it.

Do not execute production-code prompts until all docs, audits, and test-gap prompts before them are complete.

Return the standard final summary after the last completed prompt.
```

---

# Appendix B: First Paste To Codex

Use this if you want Codex to start safely.

```text
You are working in the active Orbisonic repo.

I am giving you a sequential prompt pack: `orbisonic_codex_prompt_sequence.md`.

Read the whole file once.
Then execute Prompt 01 only.
Do not modify files.
Stop after Prompt 01 and return the required final summary.
```

---

# Appendix C: Continue Paste To Codex

Use this after Codex completes one prompt cleanly.

```text
Continue with the next prompt in `orbisonic_codex_prompt_sequence.md`.

Execute only that next prompt.
Follow all scope limits, verification steps, documentation requirements, and stopping conditions.
Stop after that one prompt and return the required final summary.
```

---

# Appendix D: Emergency Debug Prompt

Use this if a prompt fails or tests break.

```text
Read AGENTS.md, docs/status.md, the current prompt from `orbisonic_codex_prompt_sequence.md`, and the relevant task file under `.tasks/` if it exists.

Investigate the failure without making broad unrelated changes.

Goal:
- Identify the root cause.
- Explain why it happened.
- Fix the smallest reasonable scope only if the fix is inside the current prompt's scope.
- Add or update a regression test only if the current prompt allows tests.
- Run relevant checks.
- Update docs/status.md.

Do not refactor unrelated code.
Do not change public contracts unless the current prompt explicitly allows it.
Do not proceed to the next prompt.

Return:
1. Root cause
2. Fix made, if any
3. Files changed
4. Regression test added or updated, if any
5. Commands run and results
6. Remaining risks or blockers
7. Recommended next prompt or recovery step
```
