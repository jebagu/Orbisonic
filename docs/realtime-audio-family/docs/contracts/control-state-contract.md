# Control State Contract

Status: mandatory baseline contract
Revision: 2026-05-23-family-standard

## Purpose

Control state represents parameters, automation, hardware controls, UI controls, and product-specific state read by the realtime core.

## Default pattern

Use latest-value atomic slots or immutable prepared snapshots.

Coalescible controls should not use ordered queues unless ordering is musically required. Latest value wins for controls such as gain, enable flags, smoothing targets, display state, and noncritical UI-controlled parameters.

## Requirements

Control state consumed by the callback must be:

- bounded to read;
- free of dynamic allocation on read;
- free of locks and waits on read;
- valid for every possible value or guarded by preparation-side validation;
- explicitly smoothed if abrupt change would cause audible artifacts.

## Smoothing

Smoothing may happen in realtime only if bounded and preconfigured. Smoothing table construction, curve parsing, and automation-lane preprocessing happen outside realtime.

## Snapshot state

Complex controls should be published as immutable snapshots. The callback may switch snapshots at a block boundary by generation or pointer. Old snapshots must be reclaimed outside realtime.
