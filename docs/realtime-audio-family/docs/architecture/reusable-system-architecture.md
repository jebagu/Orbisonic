# Reusable System Architecture

Status: family baseline
Revision: 2026-05-23-family-standard

## Layers

```text
Product Layer
  product-specific UI, workflows, session model, hardware profiles, plugin format, routing layout

Family Standards Layer
  doctrine, architecture, contracts, performance gates, OpenSpec requirements

Backend Adapter Layer
  JUCE, Core Audio, ASIO, JACK, WASAPI, ALSA, PortAudio, plugin wrappers, host APIs

Realtime Core Layer
  DSP, source/voice/effect processing, sample scheduling, mixing, meter extraction

Infrastructure Layer
  build, tests, instrumentation, logging outside realtime, telemetry outside realtime
```

## Reuse model

A new app should inherit the family layer unchanged, then add product-specific specs and contracts. The product layer should define what the app does. The family layer defines what the app must never do to realtime audio.

## Project profile

Every project should create `docs/project/profile.md` containing:

- product name;
- app type;
- backend choice;
- plugin/standalone target;
- supported sample rates;
- block-size assumptions;
- channel and routing model;
- event sources;
- control sources;
- telemetry outputs;
- stress scenes;
- inherited standard revision.

## Golden path

The default implementation path is:

1. Define project profile.
2. Define realtime core contract specialization.
3. Choose adapter.
4. Build prepare/process split.
5. Add event queues and snapshots.
6. Add performance instrumentation.
7. Add stress scene.
8. Only then add product-specific UI and telemetry.
