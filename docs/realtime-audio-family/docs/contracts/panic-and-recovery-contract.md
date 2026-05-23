# Panic and Recovery Contract

Status: mandatory baseline contract
Revision: 2026-05-23-family-standard

## Purpose

Panic and recovery behavior must be bounded, predictable, and available even under event overload.

## Panic triggers

A project may define panic triggers such as:

- user panic command;
- transport stop;
- route invalidation before arming;
- unrecoverable event overload;
- detected invalid realtime state;
- host reset;
- device loss notification handled outside realtime.

## Realtime panic behavior

The callback panic path may:

- silence outputs;
- mark all active voices or sources inactive;
- flush bounded event queues by generation;
- reset envelopes or gains using bounded loops;
- publish a tiny status flag.

It must not allocate, log, wait, call UI, close devices, parse state, reload presets, or validate routes.

## Recovery

Recovery happens outside realtime. It may rebuild render plans, reload session state, reopen devices, and republish snapshots. Re-entering playback requires the same arming checks as first start.
