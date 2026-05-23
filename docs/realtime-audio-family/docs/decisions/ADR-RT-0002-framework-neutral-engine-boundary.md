# ADR-RT-0002: Framework Neutral Engine Boundary

Status: accepted
Revision: 2026-05-23-family-standard

## Context

Realtime audio fails when callback work exceeds its deadline or is delayed by allocation, locks, I/O, scheduling, UI, or unbounded algorithms.

## Decision

The realtime core should be framework-neutral. Backends and plugin wrappers adapt host or device APIs into project-owned buffer, event, control, and routing views.

## Consequences

Projects can use JUCE, native APIs, plugin wrappers, or custom backends without rewriting the core doctrine. Framework convenience functions remain suspect until audited.
