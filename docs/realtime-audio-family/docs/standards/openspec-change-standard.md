# OpenSpec Change Standard

Status: mandatory for project specs
Revision: 2026-05-23-family-standard

## Purpose

Every realtime audio family project uses OpenSpec or an equivalent spec/change process for audio-facing changes.

## Required questions for audio changes

Each proposal, design, task list, or spec delta must answer:

```text
Does this touch callback-reachable code?
What functions become newly reachable from the callback?
What data crosses into the realtime plane?
What work is done in preparation?
What work is done in realtime?
What work is done in telemetry/UI?
What is the maximum block size and event burst?
What is the queue-full policy?
What output routing invariant must hold?
What meter or telemetry source-of-truth changes?
What performance gates prove safety?
```

## Required spec sections

Every project-specific realtime spec should include:

- inherited family doctrine;
- scope;
- requirements;
- realtime boundary;
- forbidden callback behavior;
- event and control transfer;
- overload behavior;
- performance gates;
- acceptance tests.

## Forbidden spec behavior

A project spec must not:

- allow callback allocation, locks, waits, logging, UI, I/O, parsing, route discovery, or device enumeration;
- make telemetry required for audio to proceed;
- hide output route mismatch;
- omit full behavior for a bounded queue;
- claim average-case timing is sufficient;
- depend on one fixed block size unless the backend and tests prove it.
