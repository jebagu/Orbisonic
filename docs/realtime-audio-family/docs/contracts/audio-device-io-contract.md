# Audio Device I/O Contract

Status: mandatory baseline contract
Revision: 2026-05-23-family-standard

## Purpose

The audio device or host adapter connects an external callback source to the realtime core.

## Responsibilities

The adapter must:

- configure sample rate, block size, and channel count outside realtime;
- call core prepare before audio starts;
- convert backend buffer types to project buffer views without allocation;
- normalize host/device timing metadata;
- deliver bounded event blocks to the core;
- handle backend lifecycle changes outside realtime when possible;
- report failures outside realtime.

## Callback rules

Inside the device or host callback, the adapter may only:

- create stack-local lightweight views;
- read already-published snapshots;
- drain bounded queues;
- call the realtime core;
- clear or fill output buffers;
- publish tiny fixed-size meter snapshots.

## Route validation

Route validation, device enumeration, channel-name discovery, and layout negotiation happen before arming playback or capture. A mismatch must fail visibly outside realtime.

## Variable blocks

The adapter must pass actual frame count to the core. The project may process in fixed internal chunks only with preallocated storage and bounded remainder handling.
