# ADR-RT-0006: Bounded Queues Require Overload Policy

Status: accepted
Revision: 2026-05-23-family-standard

## Context

Realtime audio fails when callback work exceeds its deadline or is delayed by allocation, locks, I/O, scheduling, UI, or unbounded algorithms.

## Decision

Every queue or state publication path crossing into realtime must be fixed-capacity or otherwise bounded and must define full behavior before implementation.

## Consequences

Waiting for space, allocating more space, or logging from the callback are invalid overload policies. Dropping, coalescing, rejecting before arming, or setting flags outside realtime are preferred.
