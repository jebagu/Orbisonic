# ADR-RT-0003: Preparation Plane Owns Unsafe Work

Status: accepted
Revision: 2026-05-23-family-standard

## Context

Realtime audio fails when callback work exceeds its deadline or is delayed by allocation, locks, I/O, scheduling, UI, or unbounded algorithms.

## Decision

Parsing, allocation, validation, route discovery, device enumeration, graph construction, preset loading, sample loading, and table construction belong to the preparation or control plane.

## Consequences

The realtime plane receives only prepared snapshots, fixed-capacity queues, latest-value controls, and preallocated state.
