# Design: Start Realtime Audio Project with Family Standards

Status: reusable design template
Revision: 2026-05-23-family-standard

## Architecture

```text
UI / Control / Telemetry Plane
  any suitable framework, may allocate and log, never required by callback

Preparation Plane
  parses, validates, allocates, builds render plans, route maps, tables, and snapshots

Realtime Plane
  callback, bounded event drain, DSP, mixing, output writes, panic, tiny meter snapshot
```

## Backend boundary

A backend adapter delivers buffer views and timing metadata to a framework-neutral realtime core.

## Data transfer

Use fixed-capacity event queues, latest-value controls, and immutable prepared snapshots.

## Compliance proof

The project must add instrumentation or tests for zero callback allocation, zero blocking waits, p95/p99 callback duration, event overload, telemetry overload, panic, and route mismatch.
