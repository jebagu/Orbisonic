# Event Ingress Contract

Status: mandatory baseline contract
Revision: 2026-05-23-family-standard

## Purpose

Event ingress converts external, host, UI, MIDI, OSC, automation, hardware, sequencer, or project-specific events into compact callback-safe event blocks.

## Preparation-side responsibilities

Before events reach realtime, the producer must:

- parse raw input;
- validate schema and ranges;
- normalize timestamps;
- map source identifiers;
- coalesce when allowed;
- assign priority;
- encode into fixed-size event packets;
- define overload behavior.

## Realtime-side responsibilities

The callback may:

- pop or read bounded events;
- process at most a configured maximum per block;
- preserve ordering within the event policy;
- apply panic and transport-stop priority;
- set counters for dropped or late events.

## Event packet requirements

Callback-facing events should be fixed-size or read from fixed-capacity storage. They must not contain owning heap pointers, strings, JSON blobs, parser handles, or framework objects requiring lifetime management in the callback.

## Overload policy

Each event class must define one policy:

- preserve;
- drop newest;
- drop oldest;
- coalesce latest by key;
- defer outside realtime;
- reject before arming;
- panic/silence.

No event class may use wait, allocate, or block as its overload policy.
