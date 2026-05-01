# Sample Rate And Local File Policy

This document defines the production sample-rate rules for the Pure Audio rewrite.

## Default Session Rate

The default session sample rate is `48 kHz`.

Every production session has exactly one session sample rate. Desktop monitor and Dante renderer output use the same session rate.

As of Prompt 5, the default is centralized in `ProductionSampleRatePolicy.defaultProductionSampleRate` and enforced by `AudioSessionPlanner`.

## Allowed 31-Channel Dante Production Rates

Allowed production rates for 31-channel Dante are:

- `44.1 kHz`
- `48 kHz`
- `88.2 kHz`
- `96 kHz`

These rates are allowed only subject to runtime route validation. The active Dante route must prove that it supports at least 31 output channels at the requested rate.

`96 kHz` is the validated high-quality mode target.

`176.4 kHz` and `192 kHz` are rejected for 31-channel Dante production unless the exact hardware route proves at runtime that it supports at least 31 output channels at that rate.

For Dante Virtual Soundcard, treat `176.4 kHz` and `192 kHz` as not valid for 31-channel production.

Prompt 5 names this policy as `ProductionSampleRatePolicy.allowedThirtyOneChannelDanteRates`. The policy accepts only `44.1`, `48`, `88.2`, and `96 kHz` for 31-channel Dante production. `DanteRouteCapability` and `AudioSessionPlanner` then apply runtime route checks for channel count and supported or nominal sample rate.

## Local File Mismatch Policy

When a local file is requested for production playback:

1. If the file sample rate equals the session sample rate, allow production playback.
2. Else, if the session is stopped and the Dante route supports the file sample rate with the required channel count, allow a new session at that rate.
3. Else, block production playback and offer explicit offline import conversion into a managed asset at the session rate.

The app must not silently convert the file on the production render path.

`AudioSessionPlanner` enforces this at the planning layer:

- Live sources must match the session sample rate.
- Local files may enter production only when their descriptor matches the session sample rate.
- Mismatched local files are rejected with `localAssetRequiresManagedImport` unless they are represented as a managed imported asset already at the session rate.
- A managed imported asset still must declare the session sample rate. A stale or mismatched managed descriptor is rejected.

## No On-The-Fly Production SRC

No on-the-fly sample-rate conversion is allowed in the production engine.

Hidden conversion at source adaptation, render graph planning, desktop output, Dante output, or final hardware boundary is forbidden for production playback.

If conversion is needed for a production source, it must be performed offline by `AudioImport` before the source enters production playback.

The planner records any required production sample-rate conversion as `ForbiddenAudioConversion.productionSampleRateConversion` in its conversion ledger draft and rejects the plan.

## Prompt 6 Local Asset Gate

Prompt 6 adds the first concrete local-file admission layer:

- `LocalAssetProbeResult`
- `AssetReadiness`
- `ManagedAssetDescriptor`
- `ManagedAssetImporter`
- `ProductionLocalAssetGate`

`ProductionLocalAssetGate` is the production source gate for local files. It returns:

- `productionReady` when the file sample rate matches `AudioSessionFormat.sampleRate`.
- `requiresOfflineImport(reason:targetSampleRate:)` when the file cannot enter the running production session without sample-rate conversion.
- `canRestartStoppedSessionAtFileRate(reason:fileSampleRate:)` only when the current session is stopped and the selected Dante route supports 31-channel production at the file rate.
- `unsupported(reason:)` for invalid shape, channel count, or descriptor data.
- `desktopPreviewOnly(reason:)` is reserved for explicitly labeled non-production preview paths and is not currently wired to production playback.

The user-facing mismatch message must make the production rule clear. For example:

`This file is 44.1 kHz. Current Orbisonic Dante session is 48 kHz. Production playback requires matching sample rates. Convert a managed copy to 48 kHz, or restart the session at 44.1 kHz if the Dante route supports it.`

`ManagedAssetImporter` writes managed assets as CAF Float32 PCM at the target session rate. CAF was chosen because Core Audio can write it directly for explicit offline import and it is less disruptive than introducing a new external container dependency at this stage. Managed assets preserve source channel count; layout conversion is not added in Prompt 6.

The managed file is an import artifact, not the real-time production buffer. When the production render path later consumes managed assets, `AudioCore` still owns conversion into canonical non-interleaved Float32 buffers at the session sample rate.

## Optional Desktop-Only Preview

Desktop-only preview may use non-production conversion only if:

- It is clearly labeled as preview.
- It is kept out of Dante.
- It does not share render buffers, route state, or graph state with the production Dante output.
- It records in telemetry that it is non-production preview.

Desktop preview must not weaken production validation.

## Route Validation

Before any production session starts, route validation must prove:

- Session sample rate.
- Desktop output availability, if desktop monitor is enabled.
- Dante output availability.
- Dante output channel count is at least 31.
- Dante physical channel 32, if present, is reserved/silent unless explicitly assigned later.

If validation fails, production playback does not start.

## Prompt 5 Planning Types

Prompt 5 adds these contract-level planning types:

- `AudioSessionPlanner`
- `AudioSessionPlanRequest`
- `AudioSessionPlan`
- `RouteCapabilityValidator`
- `RouteCapabilityInput`
- `ProductionSampleRatePolicy`
- `StopRebuildPolicy`
- `StopRebuildDecision`

`RouteCapabilityValidator` maps route metadata into `OutputRouteDescriptor` and `DanteRouteCapability`. It preserves Pure Audio route risk:

- Orbisonic loopback outputs and BlackHole are `feedbackLoopRisk`.
- Dante or Audinate routes are `preferredDante`.
- Other virtual outputs are `virtualOutputRisk`.
- Ordinary available hardware routes are `safe`.
- Unavailable routes are `unavailable`.

`AudioSessionPlanner` produces the planned `AudioSessionFormat`, selected desktop and Dante output formats, validation messages, stop/rebuild decision, route validation status, conversion policy status, and conversion ledger draft.

## Stop And Rebuild Contract

`StopRebuildPolicy` treats these changes as stop/rebuild events:

- Session sample-rate changes.
- Dante output route changes.
- Desktop output route changes until live swaps are proven safe.

These changes do not require rebuild:

- Desktop monitor gain.
- Dante output gain.
- VU display changes.
- Source changes when the source is already at the session sample rate and source switching is supported.

A mismatched source is blocked or sent to offline import. It is never handled by hidden production SRC.

## Current Migration TODO

The current `OrbisonicViewModel` and `OrbisonicEngine` path still bypasses `AudioSessionPlanner` and `ProductionLocalAssetGate` for the legacy Normal Monitor flow. That is a migration exception. Later prompts must route session start, source selection, local file admission, and output route selection through `AudioControl`, `AudioSessionPlanner`, and `ProductionLocalAssetGate` before they can affect production audio.
