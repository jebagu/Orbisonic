# Session and Preset Package Contract

Status: reusable baseline contract
Revision: 2026-05-23-family-standard

## Purpose

Session and preset data often contains complex structured state. This contract keeps that complexity out of realtime.

## Rules

- Files are parsed outside realtime.
- Presets are validated outside realtime.
- Samples, impulse responses, tables, plugin state, and routing data are loaded outside realtime.
- A session or preset produces an immutable prepared snapshot before the callback can use it.
- The callback never receives raw file data, JSON, XML, YAML, binary archive readers, or parser objects.

## Hot changes

A hot preset/session change while audio is active must use one of:

- prepare new snapshot, swap at block boundary;
- prepare new snapshot, crossfade with bounded preallocated state;
- stop, rearm, restart;
- reject until safe.

The product spec must define which behavior applies.
