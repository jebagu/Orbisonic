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

The current `OrbisonicViewModel` and `OrbisonicEngine` path still bypasses `AudioSessionPlanner` for the legacy Normal Monitor flow. That is a migration exception. Later prompts must route session start, source selection, and output route selection through `AudioControl` and `AudioSessionPlanner` before they can affect production audio.
