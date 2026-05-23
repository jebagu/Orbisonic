# ADR-RT-0001: Callback Owns Sound

Status: accepted
Revision: 2026-05-23-family-standard

## Context

Realtime audio fails when callback work exceeds its deadline or is delayed by allocation, locks, I/O, scheduling, UI, or unbounded algorithms.

## Decision

Audible sound is owned by the realtime callback path. UI, telemetry, logging, file operations, network operations, and diagnostics may observe or prepare state but may not be required for the callback to finish.

## Consequences

The callback has priority over convenience. Any subsystem that cannot meet the doctrine must live outside realtime and communicate through bounded transfer patterns.
