# Backend Adapter Standard

Status: mandatory for audio backends and plugin wrappers
Revision: 2026-05-23-family-standard

## Purpose

The project may use any suitable audio backend. The backend adapter exists to deliver buffers and timing to the realtime core without leaking framework assumptions into the core.

## Required separation

The realtime core MUST be framework-neutral unless a project ADR explicitly accepts otherwise.

The adapter may depend on JUCE, Core Audio, ASIO, JACK, WASAPI, ALSA, PortAudio, iPlug2, CLAP, AU, VST3, or host APIs. The core should depend on plain C++ types and project-owned views.

```text
Framework / Host / Device API
  -> thin callback adapter
  -> framework-neutral realtime core
```

## Adapter responsibilities

The adapter is responsible for:

- device or host callback registration;
- buffer view conversion;
- sample rate, block size, channel count, and transport metadata delivery;
- mapping host events into prepared compact event blocks;
- calling the realtime core process function;
- publishing tiny meter snapshots;
- calling prepare/reset outside realtime.

## Adapter prohibitions

The adapter callback MUST NOT:

- allocate;
- lock or wait;
- post UI messages;
- log;
- parse raw network/file data;
- perform device discovery;
- mutate graph topology;
- resize buffers;
- call framework helpers that are not audited as callback-safe.

## Framework-specific note

Using JUCE or any other framework is allowed. Treat the framework as plumbing. Do not treat it as proof of realtime safety.

Good pattern:

```text
JUCE AudioIODeviceCallback or AudioProcessor::processBlock
  converts to project AudioBlockView
  drains bounded event queue
  calls RealtimeAudioCore::process
```

Bad pattern:

```text
processBlock
  parses project files
  resizes containers
  posts AsyncUpdater
  mutates AudioProcessorGraph
  logs diagnostics
  calls UI or route discovery
```

## Native backend note

Native Core Audio, ASIO, JACK, WASAPI, or ALSA can provide maximum control. Native code is still subject to the same doctrine. Direct driver access does not excuse allocation, locks, I/O, logging, route discovery, or unbounded work in the callback.
