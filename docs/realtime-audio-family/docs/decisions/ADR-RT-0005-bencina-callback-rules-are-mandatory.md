# ADR-RT-0005: Bencina Callback Rules Are Mandatory

Status: accepted
Revision: 2026-05-23-family-standard

## Context

Realtime audio fails when callback work exceeds its deadline or is delayed by allocation, locks, I/O, scheduling, UI, or unbounded algorithms.

## Decision

The package adopts a project paraphrase of Ross Bencina's realtime audio callback rules as mandatory family doctrine. The rules apply to every callback and every callback-reachable function.

## Consequences

No project may opt out for convenience. Exceptions require a project ADR with bounded worst-case proof and regression gates before implementation.
