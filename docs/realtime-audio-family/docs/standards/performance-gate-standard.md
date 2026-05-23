# Performance Gate Standard

Status: mandatory
Revision: 2026-05-23-family-standard

## Purpose

Realtime safety requires proof. This standard defines the minimum evidence required before merging callback-adjacent work.

## Required metrics

Each project must report:

- sample rate;
- block size or block-size range;
- callback duration p50, p95, p99, and maximum observed;
- deadline miss count;
- callback allocation count;
- callback deallocation count;
- callback blocking-lock count;
- callback wait/sleep count;
- max events drained per block;
- event drops/coalesces by class;
- telemetry drops;
- CPU load under stress;
- denormal handling status;
- route mismatch behavior.

## Minimum gates

A callback-adjacent change fails if:

- callback allocations are nonzero;
- callback blocking locks are nonzero;
- callback waits or sleeps are nonzero;
- p99 callback duration violates the project budget;
- any deadline miss occurs in the standard stress scene;
- event overload lacks explicit policy;
- route mismatch is silently accepted;
- telemetry overload blocks audio;
- UI activity increases callback risk.

## Budget guidance

Each project must define its own budget. A reasonable starting budget is:

```text
p95 callback duration <= 50 percent of block duration
p99 callback duration <= 70 percent of block duration
max observed duration <= 90 percent of block duration during qualification
missed deadlines = 0 during release stress scenes
```

These are starting gates, not guarantees. More demanding apps should set stricter budgets.

## Stress scene requirements

Stress scenes must include:

- maximum configured channel count;
- maximum or representative active voices/sources/effects;
- bursty event input;
- active UI and meters;
- active telemetry output;
- route validation before arming;
- device or host block-size changes if supported;
- panic path activation;
- long enough duration to catch p99 and worst-observed behavior.
