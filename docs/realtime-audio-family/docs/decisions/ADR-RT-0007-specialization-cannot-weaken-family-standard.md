# ADR-RT-0007: Specialization Cannot Weaken Family Standard

Status: accepted
Revision: 2026-05-23-family-standard

## Context

Realtime audio fails when callback work exceeds its deadline or is delayed by allocation, locks, I/O, scheduling, UI, or unbounded algorithms.

## Decision

Product-specific specs may add requirements but may not weaken the family doctrine, architecture boundary, or performance gates.

## Consequences

This package can be reused across products without losing its safety value. Project documents inherit the family standard unless they explicitly add stricter constraints.
