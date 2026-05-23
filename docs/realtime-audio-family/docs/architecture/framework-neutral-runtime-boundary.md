# Framework-Neutral Runtime Boundary

Status: reusable architecture rule
Revision: 2026-05-23-family-standard

## Principle

The realtime core should not know which framework or host delivered the audio buffer.

Use this split:

```text
Backend or host adapter
  knows JUCE, Core Audio, ASIO, JACK, WASAPI, ALSA, PortAudio, plugin APIs, device APIs

Realtime core
  knows sample rate, block frames, audio buffers, events, controls, routing, prepared snapshots
```

## Why this exists

The framework may change across products. The doctrine cannot change.

A family app might be:

- a standalone app;
- a plugin;
- a background audio engine;
- an embedded processor;
- a networked renderer;
- a recorder;
- a synth;
- a sampler;
- a spatial processor;
- a live performance tool.

The core rules remain the same.

## Adapter contract

The adapter may translate framework buffers and events into project-owned views. It must not allocate, lock, log, call UI, parse, resize, discover devices, or mutate graphs in the callback.

The adapter must own all framework-specific weirdness, including:

- variable block sizes;
- zero-length blocks;
- channel layout changes;
- host transport flags;
- sample-rate changes;
- device lifecycle events;
- plugin bypass or suspend states;
- offline rendering mode;
- host automation delivery.

The realtime core receives normalized, bounded data.

## Core contract

The core exposes a prepare/process/reset lifecycle. It is tested without the framework.

```text
prepare(config)    may allocate, not realtime
reset()            bounded, no allocation after prepare
process(context)   realtime, no allocation, no locks, no waits, no I/O
```
