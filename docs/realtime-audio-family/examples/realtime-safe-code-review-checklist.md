# Realtime-Safe Code Review Checklist

Use this for every callback-adjacent change.

## Reachability

- [ ] Callback entry points identified.
- [ ] New callback-reachable functions listed.
- [ ] No unaudited framework calls reachable.

## Bencina doctrine

- [ ] No allocation or deallocation.
- [ ] No locks, waits, sleeps, joins, condition variables, or unbounded CAS retry loops.
- [ ] No file, disk, network, console, logging, UI, route discovery, device discovery, or parser calls.
- [ ] No unbounded or poor worst-case algorithms.
- [ ] No untrusted code reachable.

## Boundaries

- [ ] Unsafe work moved to preparation or control plane.
- [ ] Callback receives only buffer views, fixed-capacity queues, latest-value controls, immutable snapshots, and precomputed tables.
- [ ] Queue-full behavior documented.
- [ ] Panic path bounded.
- [ ] Telemetry lossy and nonblocking.

## Gates

- [ ] Callback allocation count: 0.
- [ ] Callback blocking lock/wait count: 0.
- [ ] Deadline misses: 0.
- [ ] p95 and p99 reported.
- [ ] Stress scene includes UI and telemetry.
