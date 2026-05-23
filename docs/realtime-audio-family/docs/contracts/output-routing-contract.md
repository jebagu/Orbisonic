# Output Routing Contract

Status: mandatory baseline contract
Revision: 2026-05-23-family-standard

## Purpose

Output routing maps logical audio buses, sources, objects, tracks, channels, or stems to physical, host, plugin, file, or network outputs.

## Rules

- Routing must be explicit before arming production playback or capture.
- A route mismatch must fail visibly outside realtime.
- The callback must not discover, validate, or repair routes.
- Silent downmix, truncation, duplication, reordering, or fallback is forbidden unless the project spec explicitly defines it and the user is told before arming.
- Channel and bus maps used by the callback must be precomputed.

## Realtime route data

Callback-facing route data must be one of:

- fixed-size mapping table;
- immutable prepared route snapshot;
- generation-indexed route plan;
- compile-time route layout.

## Route changes

Route changes while audio is active must be prepared off-thread and swapped safely at a block boundary, or require stopping and rearming. The product spec must define which behavior applies.
