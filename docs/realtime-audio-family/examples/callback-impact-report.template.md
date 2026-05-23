# Callback Impact Report Template

Change:
Author:
Date:
Project:

## Callback impact

Does this change touch callback-reachable code? yes/no

## New callback-reachable functions

List each function and why it is safe.

## Allocation risk

- New allocation sites:
- Hidden allocation risks:
- Evidence callback allocation count is zero:

## Lock/wait risk

- New locks or waits:
- Atomics used:
- Evidence callback blocking count is zero:

## I/O/logging/UI/parser risk

- File/network/log/UI/parser calls reachable from callback:
- Evidence none are reachable:

## Worst-case loop bounds

- Max frames:
- Max channels:
- Max events per block:
- Max active voices/sources/effects:
- Other loop bounds:

## Queue-full or overload policy

Describe each queue and full behavior.

## Tests or instrumentation run

- Stress scene:
- p50:
- p95:
- p99:
- max:
- deadline misses:
- callback allocations:
- callback locks/waits:
