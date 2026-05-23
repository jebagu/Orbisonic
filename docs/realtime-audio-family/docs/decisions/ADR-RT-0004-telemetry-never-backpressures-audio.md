# ADR-RT-0004: Telemetry Never Backpressures Audio

Status: accepted
Revision: 2026-05-23-family-standard

## Context

Realtime audio fails when callback work exceeds its deadline or is delayed by allocation, locks, I/O, scheduling, UI, or unbounded algorithms.

## Decision

Meters, UI, diagnostics, and telemetry are observers. They must be lossy or decimated under load rather than delaying audio.

## Consequences

Audio can continue when telemetry drops frames. Telemetry quality is subordinate to audible timing.
