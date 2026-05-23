# Callback Safety Test Plan

Status: reusable test plan
Revision: 2026-05-23-family-standard

## Test categories

1. Allocation detection inside callback.
2. Blocking lock and wait detection inside callback.
3. I/O, logging, UI, and parser call detection inside callback.
4. Variable block-size handling.
5. Event burst handling.
6. Queue-full behavior.
7. Panic behavior.
8. Snapshot swap behavior.
9. Telemetry overload behavior.
10. Route mismatch before arming.

## Instrumentation ideas

Projects may use platform-specific hooks, malloc wrappers, sanitizers, realtime-safety analyzers, custom counters, or code review plus stress tests. The exact tool is project-specific. The required outcome is not.

## Required failure tests

Each project should add tests that intentionally violate the rules and verify that instrumentation catches them, such as callback allocation, callback logging, and callback lock attempts.
