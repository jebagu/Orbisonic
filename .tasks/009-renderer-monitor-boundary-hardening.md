# 009: Renderer Monitor Boundary Hardening

Status: Complete

## Goal

Harden the boundary between the Sonic Sphere production renderer and the headphone or normal monitor path.

## Background

Sonic Sphere 30.1 is the production output topology. The headphone or normal monitor path is for setup, checking, and preview. Monitor choices, metering, and desktop output behavior must not redefine the production renderer, mutate Sonic Sphere topology, or create duplicate audible routes.

## Relevant Docs To Read

- `AGENTS.md`
- `docs/status.md`
- `docs/contracts.md`
- `docs/system-flows.md`
- `docs/implementation-map.md`
- `docs/test-strategy.md`
- `docs/audits/0002-contract-test-gap-audit.md`
- `docs/readiness-summary.md`
- `docs/decisions/0005-sonic-sphere-30-1-primary-output.md`
- `Sources/Orbisonic/RendererModule.swift`
- `Sources/Orbisonic/RendererMatrixSampleRenderer.swift`
- `Sources/Orbisonic/NormalMonitorStereoDownmixer.swift`
- `Sources/Orbisonic/NormalMonitorGraphTopology.swift`
- `Sources/Orbisonic/NormalMonitorRouteDescriptor.swift`
- `Sources/Orbisonic/NormalMonitorConversionLedger.swift`
- `Sources/Orbisonic/MeteringService.swift`
- Relevant renderer, monitor, and metering tests.

## Scope

- Add or strengthen tests for renderer topology, Direct 30/31 behavior, monitor isolation, LFE policy, duplicate route prevention, and metering non-interference.
- Harden code only where tests identify a boundary weakness.
- Update docs and flows if renderer or monitor behavior changes.
- Preserve Sonic Sphere 30.1 as production output.

## Out Of Scope

- Making monitor output the production topology.
- Changing Sonic Sphere speaker layout without accepted contract change.
- Replacing renderer architecture.
- Adding Atmos object decoding.
- Hardware channel-order verification unless explicitly performed and documented.

## Contract References

- `docs/contracts.md` sections `Renderer And Sonic Sphere Output Boundary`, `Headphone Or Normal Monitor Boundary`, `Diagnostics And Logging Boundary`, and `Cross-Cutting Audio Invariants`.
- `docs/system-flows.md` sections `Renderer And Sonic Sphere Output Flow`, `Headphone Or Normal Monitor Flow`, and `Test Tone Flow`.
- `docs/test-strategy.md` invariants `Renderer topology does not drift silently`, `Monitor path does not mutate production Sonic Sphere path`, and `Metering cannot affect playback`.
- `docs/decisions/0005-sonic-sphere-30-1-primary-output.md`.

## Expected Files

- `Sources/Orbisonic/RendererModule.swift`
- `Sources/Orbisonic/RendererMatrixSampleRenderer.swift`
- `Sources/Orbisonic/NormalMonitorStereoDownmixer.swift`
- `Sources/Orbisonic/NormalMonitorGraphTopology.swift`
- `Sources/Orbisonic/NormalMonitorRouteDescriptor.swift`
- `Sources/Orbisonic/NormalMonitorConversionLedger.swift`
- `Sources/Orbisonic/MeteringService.swift`
- `Tests/OrbisonicTests/RendererModuleTests.swift`
- `Tests/OrbisonicTests/RendererMatrixSampleRendererTests.swift`
- `Tests/OrbisonicTests/SonicSphereMeteringTests.swift`
- `Tests/OrbisonicTests/NormalMonitorGraphTopologyTests.swift`
- `Tests/OrbisonicTests/NormalMonitorRouteBranchRemovalTests.swift`
- `Tests/OrbisonicTests/NormalMonitorGoldenAudioTests.swift`
- `Tests/OrbisonicTests/MeteringIsolationTests.swift`
- `Tests/AudioCoreTests/RenderGraphPlanTests.swift`
- `Tests/AudioCoreTests/RenderKernelTests.swift`
- `docs/status.md`
- `docs/system-flows.md` if flows change
- `docs/test-strategy.md` if coverage changes

## Acceptance Criteria

- Renderer and monitor responsibilities remain separate in code and tests.
- Monitor changes cannot mutate Sonic Sphere 30.1 production topology.
- Metering remains non-consuming and non-audible.
- Direct 30/31 behavior remains protected.
- Full SwiftPM tests pass or blockers are documented.
- Physical Sonic Sphere / Dante verification remains manual unless actually performed.

## Verification Commands

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
./scripts/refresh-orbisonic-app.sh
./scripts/reopen-orbisonic-app.sh
git diff --check
```

Run the app refresh and reopen only when app code or GUI/audio behavior changes. Document any skipped manual hardware checks.

## Stopping Conditions

- A fix would change Sonic Sphere topology or public renderer contracts.
- A monitor path change requires hardware verification that is unavailable.
- The task starts drifting into live source, installer, or unrelated UI work.
- A failing test indicates deeper renderer architecture work beyond this task.

## Required Final Summary

Use the standard summary format from `AGENTS.md` and include renderer/monitor boundaries hardened, tests run, and remaining manual Sonic Sphere checks.

## Completion Notes

- Added a source-level clarification that `NormalMonitorAudibleRouteSelector` is a stereo preview branch and intentionally ignores production renderer mode, output route capability, and Sonic Sphere channel count.
- Added deterministic coverage that every renderer mode, including Direct 30 and Direct 30.1, resolves to the same normal-monitor route.
- Added deterministic coverage that normal-monitor planning leaves the Sonic Sphere 30.1 scene, speaker list, output topology, and renderer matrix unchanged.
- Updated `docs/status.md`, `docs/implementation-map.md`, and `docs/test-strategy.md` for the new boundary coverage.
- Physical Sonic Sphere / Dante output, route switching, and headphone/normal monitor runtime behavior remain manual verification items.
