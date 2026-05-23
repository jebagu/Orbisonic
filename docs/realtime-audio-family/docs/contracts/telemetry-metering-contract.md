# Telemetry and Metering Contract

Status: mandatory baseline contract
Revision: 2026-05-23-family-standard

## Purpose

Meters and telemetry help humans and tools observe audio. They do not own audio timing.

## Realtime extraction

The callback may compute tiny fixed-size meter snapshots from explicit tap points. Meter extraction must be bounded and allocation-free.

## Telemetry publication

Telemetry formatting, UI model construction, logging, network sending, JSON serialization, database writes, and file writes happen outside realtime.

## Backpressure rule

Audio never waits for telemetry.

Allowed overload behavior:

- drop stale frames;
- keep latest complete snapshot;
- decimate update rate;
- set a telemetry-overload flag;
- report later outside realtime.

Forbidden overload behavior:

- block the callback;
- allocate more queue space in callback;
- synchronously log from callback;
- post UI messages from callback;
- send network packets from callback.

## Source labels

Every meter stream must label its source of truth, such as input, pre-fader, post-fader, post-effect, bus, final output, or hardware tap.
