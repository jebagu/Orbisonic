# 0001: Retrofit, Not Rewrite

Status: Accepted

## Context

The current Orbisonic repository already contains a native Swift/macOS app, SwiftPM package targets, tests, app-bundle scripts, installer artifacts, local file playback, live loopback capture, Roon support, Spotify support, renderer code, monitor code, diagnostics, and project docs.

The project control prompt sequence is being run against this existing app. The purpose is to make the current architecture safer to change, not to replace it with a new product.

## Decision

Current Orbisonic is the baseline. The retrofit adds control documents, architecture maps, module contracts, system flows, test strategy, decision records, audits, task files, and hardening work around the existing implementation.

The retrofit must not rewrite Orbisonic from scratch, treat old prototype workspaces as active product source, or replace current runtime behavior unless a later prompt explicitly authorizes behavior changes.

## Rationale

The app already has substantial working surface area and test coverage. Rewriting would increase risk in the highest-value part of the product: audio routing, monitoring, rendering, and diagnostics.

The safer path is to document the current boundaries, protect them with tests, and then make targeted changes from a known baseline.

## Alternatives Considered

- Rewrite as a new app: rejected because it would discard current source, tests, app-bundle workflow, and accumulated audio-path behavior.
- Freeze the app and only write docs: rejected because the retrofit is intended to enable later hardening work.
- Treat old prototype workspaces as reusable baselines: rejected because the active repo is the native Swift/macOS Orbisonic product.

## Consequences

- Existing source, tests, README, AGENTS.md, Package.swift, and accepted control docs remain the source of truth.
- Future work should be incremental and contract-aware.
- Historical docs may remain useful, but they must be checked against current source before becoming binding.
- Docs-only prompts do not require builds unless source, tests, scripts, installer files, vendor files, or calibration files changed by mistake.

## Follow-up

- Keep `docs/status.md` as the project control panel.
- Use audits and task files before source hardening.
- Update contracts, flows, test strategy, and ADRs when accepted architecture decisions change.
