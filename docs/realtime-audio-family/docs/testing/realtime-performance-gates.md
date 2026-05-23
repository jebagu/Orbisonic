# Realtime Performance Gates

Status: mandatory baseline gates
Revision: 2026-05-23-family-standard

## Required before merge

For callback-adjacent changes, record:

- hardware or host configuration;
- backend adapter;
- sample rate;
- block size or range;
- maximum channel count tested;
- maximum active source/voice/effect count tested;
- event burst scenario;
- telemetry/UI scenario;
- p50, p95, p99, and max callback duration;
- deadline miss count;
- callback allocation/deallocation count;
- callback blocking-lock and wait count;
- event drop/coalesce counters;
- telemetry drop counters.

## Pass/fail

A release candidate fails if:

- any callback allocation is detected;
- any callback blocking lock or wait is detected;
- any callback I/O/logging/UI call is detected;
- any deadline miss occurs during the release stress scene;
- p99 exceeds the project-defined budget;
- event overload policy is undefined;
- telemetry overload delays audio;
- route mismatch is silently accepted.

## Standard stress scene

Every project must define at least one stress scene that exercises the product's realistic worst case. It must run with UI, meters, telemetry, event input, and routing diagnostics active.
