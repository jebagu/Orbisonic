# Package Manifest

Package: Realtime Audio Family Standards
Revision: 2026-05-23-family-standard

## Root files

- `README.md`: package purpose and adoption flow.
- `PACKAGE-RULES.md`: family-level mandatory rules.
- `AGENTS.md`: coding-agent and contributor guardrails.
- `MIGRATION.md`: how to apply the package to brownfield projects.
- `generation-summary.json`: package generation metadata.

## Standards

- `docs/standards/realtime-callback-safety-doctrine.md`
- `docs/standards/realtime-audio-architecture-standard.md`
- `docs/standards/cpp-realtime-coding-standard.md`
- `docs/standards/backend-adapter-standard.md`
- `docs/standards/event-queue-and-state-publication-standard.md`
- `docs/standards/openspec-change-standard.md`
- `docs/standards/performance-gate-standard.md`

## Architecture

- `docs/architecture/three-plane-realtime-audio-architecture.md`
- `docs/architecture/framework-neutral-runtime-boundary.md`
- `docs/architecture/reusable-system-architecture.md`

## Contracts

- `docs/contracts/realtime-audio-core-contract.md`
- `docs/contracts/audio-device-io-contract.md`
- `docs/contracts/event-ingress-contract.md`
- `docs/contracts/control-state-contract.md`
- `docs/contracts/output-routing-contract.md`
- `docs/contracts/telemetry-metering-contract.md`
- `docs/contracts/panic-and-recovery-contract.md`
- `docs/contracts/plugin-standalone-adapter-contract.md`
- `docs/contracts/session-preset-package-contract.md`
- `docs/contracts/brownfield-adoption-contract.md`

## Decisions

- `docs/decisions/ADR-RT-0001-callback-owns-sound.md`
- `docs/decisions/ADR-RT-0002-framework-neutral-engine-boundary.md`
- `docs/decisions/ADR-RT-0003-preparation-plane-owns-unsafe-work.md`
- `docs/decisions/ADR-RT-0004-telemetry-never-backpressures-audio.md`
- `docs/decisions/ADR-RT-0005-bencina-callback-rules-are-mandatory.md`
- `docs/decisions/ADR-RT-0006-bounded-queues-require-overload-policy.md`
- `docs/decisions/ADR-RT-0007-specialization-cannot-weaken-family-standard.md`

## Testing

- `docs/testing/realtime-performance-gates.md`
- `docs/testing/callback-safety-test-plan.md`
- `docs/testing/release-readiness-checklist.md`
- `docs/testing/stress-scene-template.md`

## OpenSpec

- `openspec/project.md`
- `openspec/config.yaml`
- `openspec/specs/*/spec.md`
- `openspec/changes/start-realtime-audio-project/*`

## Examples and templates

- `examples/callback-impact-report.template.md`
- `examples/adr-exception-template.md`
- `examples/event-queue-overflow-policy.example.yaml`
- `examples/project-specialization.example.yaml`
- `examples/realtime-core-interface.example.hpp`
- `examples/performance-report.template.md`
- `examples/adapter-juce-boundary.example.md`
- `examples/adapter-native-boundary.example.md`
- `examples/realtime-safe-code-review-checklist.md`
