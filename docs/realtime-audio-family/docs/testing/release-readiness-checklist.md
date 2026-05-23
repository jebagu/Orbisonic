# Release Readiness Checklist

Status: reusable checklist
Revision: 2026-05-23-family-standard

Before release, verify:

- the project profile names the inherited family standard revision;
- callback entry points are documented;
- callback-reachable functions are mapped;
- no callback allocation is detected;
- no callback blocking lock or wait is detected;
- no callback logging, file I/O, network I/O, UI call, parser call, or device discovery is detected;
- event queues have explicit capacities and full policies;
- control state uses latest-value slots or immutable snapshots;
- route mismatch fails before arming;
- meters and telemetry are lossy under overload;
- panic path is bounded;
- p95, p99, and maximum callback duration pass the project budget;
- stress scene includes UI and telemetry;
- product-specific specs do not weaken the family standard.
