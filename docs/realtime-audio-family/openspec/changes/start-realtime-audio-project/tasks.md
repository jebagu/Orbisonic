# Tasks: Start Realtime Audio Project with Family Standards

Status: reusable task template
Revision: 2026-05-23-family-standard

## 1. Inherit standards

- [ ] Copy `PACKAGE-RULES.md`, `AGENTS.md`, `docs/standards`, `docs/contracts`, `docs/decisions`, `docs/testing`, and `openspec`.
- [ ] Add a project ADR accepting the family standard.
- [ ] Add project profile under `docs/project/profile.md`.

## 2. Define architecture

- [ ] Identify backend adapter.
- [ ] Identify realtime core boundary.
- [ ] Identify preparation plane responsibilities.
- [ ] Identify UI/telemetry plane responsibilities.

## 3. Define callback transfer

- [ ] Define event queues and capacities.
- [ ] Define queue-full policies.
- [ ] Define control state pattern.
- [ ] Define snapshot publication and reclamation.
- [ ] Define route map and arming validation.

## 4. Install gates

- [ ] Add callback allocation detection.
- [ ] Add blocking lock/wait detection or review gate.
- [ ] Add p95/p99 duration metrics.
- [ ] Add deadline miss counter.
- [ ] Add stress scene.
- [ ] Add telemetry overload test.
- [ ] Add panic test.

## 5. Product-specific specs

- [ ] Add product event spec.
- [ ] Add product routing spec.
- [ ] Add product session/preset spec.
- [ ] Add product telemetry spec.
- [ ] Add product performance budget.
