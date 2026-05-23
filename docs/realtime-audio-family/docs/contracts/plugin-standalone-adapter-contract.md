# Plugin and Standalone Adapter Contract

Status: reusable baseline contract
Revision: 2026-05-23-family-standard

## Purpose

Many family apps may ship as standalone apps, plugins, embedded engines, or multiple targets. This contract keeps the realtime core target-neutral.

## Plugin adapter

A plugin adapter may handle:

- host buffer layout;
- host MIDI or event delivery;
- automation mapping;
- bypass, suspend, latency, and tail reporting;
- state save/load outside realtime;
- parameter normalization.

The plugin process callback follows the same doctrine as every other audio callback.

## Standalone adapter

A standalone adapter may handle:

- device discovery;
- device selection;
- sample-rate and block-size configuration;
- MIDI and hardware input enumeration;
- route validation;
- UI device panels.

Standalone device callbacks follow the same doctrine as every other audio callback.

## Shared core

The same realtime core should be usable behind both adapters. Adapter code may differ. Core doctrine does not.
