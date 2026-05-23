# Brownfield Adoption Contract

Status: reusable baseline contract
Revision: 2026-05-23-family-standard

## Purpose

Existing projects can adopt this package without rewriting everything at once. They cannot claim realtime compliance until the gates pass.

## Required inventory

A brownfield project must inventory:

- callback entry points;
- callback-reachable functions;
- allocation sites;
- locking and wait sites;
- logging and UI posting;
- file/network/device calls;
- parser calls;
- dynamic graph or route mutation;
- queue capacities and overload policies.

## Required remediation

Unsafe work must be moved to preparation or control planes. Callback-facing data must be converted to fixed-capacity events, latest-value slots, or immutable snapshots.

## Compliance claim

A project may claim adoption when:

- inherited standard is documented;
- callback reachability is mapped;
- unsafe work has a remediation plan;
- gates are implemented;
- first compliant stress scene passes;
- exceptions, if any, have ADRs.
