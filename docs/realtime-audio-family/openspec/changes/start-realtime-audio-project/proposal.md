# Proposal: Start Realtime Audio Project with Family Standards

Status: reusable proposal template
Revision: 2026-05-23-family-standard

## Summary

Adopt the Realtime Audio Family Standards Package as the baseline for a new or existing realtime audio project.

## Motivation

Realtime audio failures are usually caused by unsafe callback work, unbounded event paths, weak routing validation, or telemetry/UI backpressure. This change installs shared guardrails before project-specific features are built.

## Scope

- Inherit callback doctrine.
- Define three-plane architecture.
- Define realtime core, device I/O, event ingress, controls, routing, telemetry, panic, and performance gates.
- Add project profile and stress scene.

## Non-goals

- Selecting a mandatory backend.
- Implementing product-specific DSP.
- Defining a product-specific UI.
- Weakening the family standard.
