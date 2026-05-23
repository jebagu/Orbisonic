# Realtime Audio Family Standards Package

Status: reusable starter and merge package
Revision: 2026-05-23-family-standard

This package defines the baseline architecture, rules, contracts, OpenSpec specs, review gates, and templates for any serious realtime audio application in the family.

It is intentionally not tied to any one app, output system, file format, hardware target, plugin format, or UI framework. It can be copied into a new repository at project start or merged into an existing repository as a standards layer.

## What this package does

It establishes one non-negotiable rule: audible audio timing is owned by a bounded realtime callback path, and every other subsystem exists outside that path unless explicitly proven safe.

It gives each project:

- a mandatory realtime callback safety doctrine;
- a three-plane architecture standard;
- framework-neutral contracts for realtime cores, event ingress, controls, routing, telemetry, panic, and adapters;
- OpenSpec specs that can be inherited by product-specific specs;
- review templates for callback-adjacent code changes;
- performance gates for p95, p99, deadline misses, callback allocations, and blocking calls;
- ADR templates for the rare case where a project claims an exception.

## How to use it in a new project

1. Copy this package into the repository root or under `docs/realtime-audio-family`.
2. Read `AGENTS.md`, `PACKAGE-RULES.md`, and `docs/standards/realtime-callback-safety-doctrine.md` before writing audio code.
3. Create project-specific specs under `openspec/specs/<project-feature>/`.
4. Create project-specific architecture docs under `docs/project/`.
5. Do not edit the family doctrine to make a product easier. Specialize beneath it.

## How to merge it into an existing project

1. Copy `docs/standards`, `docs/contracts`, `docs/decisions`, `docs/testing`, `openspec`, `AGENTS.md`, and `PACKAGE-RULES.md`.
2. Rename nothing unless the target repo already has conflicting paths.
3. Add a project ADR that says the project inherits this family standard.
4. Run `examples/callback-impact-report.template.md` for every callback-adjacent subsystem.
5. Move parsing, allocation, logging, device discovery, and route validation out of callback-reachable code before calling the project compliant.

## Files to read first

- `PACKAGE-RULES.md`
- `AGENTS.md`
- `docs/standards/realtime-callback-safety-doctrine.md`
- `docs/standards/realtime-audio-architecture-standard.md`
- `openspec/project.md`
- `openspec/specs/realtime-audio-core/spec.md`

## Inheritance rule

Project-specific requirements may add stricter behavior. They may not weaken this package.

Examples of allowed specialization:

- choosing JUCE, Core Audio, ASIO, JACK, WASAPI, PortAudio, iPlug2, CLAP, VST3, AU, or another backend;
- defining a spatial renderer, synth, sampler, recorder, live input processor, plugin, standalone app, hardware output map, or embedded target;
- adding product-specific event types, routing layouts, preset formats, UI protocols, and telemetry channels.

Examples of forbidden specialization:

- allowing callback allocation because the app is small;
- allowing mutexes because the lock is "usually uncontended";
- letting UI, logging, route discovery, JSON parsing, network I/O, or sample loading run from the callback;
- replacing bounded overload policy with "just wait";
- treating p95 as enough when p99 misses deadlines.

## Package boundary

This is not a DSP library and not a framework recommendation. It is an architecture and safety standard.

A project can use JUCE, native platform APIs, PortAudio, JACK, iPlug2, a plugin wrapper, or a custom engine. The backend is secondary. The realtime doctrine is primary.
