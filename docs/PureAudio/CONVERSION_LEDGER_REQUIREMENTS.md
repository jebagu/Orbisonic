# Conversion Ledger Requirements

Every production session emits a conversion ledger. The ledger is a required artifact, not a diagnostic afterthought.

As of Prompt 5, `AudioSessionPlanner` creates a ledger draft during planning. The draft is not the final render-session ledger, but it is already authoritative for sample-rate policy: if planning determines that production sample-rate conversion would be required, the plan is invalid.

## Required Ledger Fields

The ledger must identify:

- Source ID or source route.
- Source type.
- Original container.
- Original codec.
- Original sample rate.
- Original bit depth when known.
- Original interleaving state when known.
- Original channel count.
- Original channel layout.
- Canonical format.
- Canonical sample rate.
- Canonical channel count.
- Canonical channel layout.
- Desktop output format.
- Dante output format.
- Whether any sample-rate conversion occurred.
- Where any sample-rate conversion occurred.
- Whether conversion was offline or production render-time.
- Validation result.
- Warnings and operator-facing explanation.

Prompt 5 planner drafts record at minimum:

- Session sample rate.
- Source sample rate, if known.
- Desktop route nominal sample rate, if known.
- Dante route nominal sample rate, if known.
- Whether production SRC would be required.
- Allowed conversion categories.
- Forbidden conversion categories observed or required.

## Allowed Conversions

The following conversions are allowed before or during production, provided they are declared in the ledger:

- Codec to PCM.
- Integer PCM to Float32.
- Interleaved to deinterleaved.
- Layout metadata normalization.
- Channel label normalization.
- Offline managed sample-rate conversion before production playback.

Allowed conversions must be explicit and attributable to a subsystem.

## Forbidden Production Render Conversion

Hidden sample-rate conversion is forbidden in the production render path.

Forbidden production render conversions include:

- Source sample rate to session sample rate conversion inside the real-time engine.
- Session sample rate to desktop output sample rate conversion hidden by graph negotiation.
- Session sample rate to Dante output sample rate conversion hidden by graph negotiation.
- Silent fallback to a different hardware sample rate.
- Temporary preview conversion routed to Dante.

If a file requires sample-rate conversion, `AudioImport` must create a managed converted asset before production playback.

`AudioSessionPlanner` encodes this as:

- `AllowedAudioConversion.offlineManagedSampleRateConversion` for managed assets converted before production.
- `ForbiddenAudioConversion.productionSampleRateConversion` when a source, desktop route, or Dante route would require hidden production SRC.

Any ledger draft containing `productionSampleRateConversion` has invalid validation status and blocks the plan.

## Prompt 8 Render Kernel Ledger Facts

Prompt 8 adds pure offline render kernels:

- `MatrixRenderKernel`
- `DesktopMonitorRenderer`
- `DanteSonicSphereRenderer`

These kernels do not perform conversion. They accept only already-canonical `CanonicalAudioBlock` input and preallocated output blocks with matching sample rates.

Kernel ledger/audit facts:

- Source sample rate is read from the canonical source block.
- Desktop output sample rate is read from the desktop block.
- Dante output sample rate is read from the Dante block.
- `sampleRateConversionOccurred` is always `false` in `RenderKernelAudit`.
- A sample-rate mismatch is rejected before processing and must not be represented as a successful render.
- Allocation measurement is currently not instrumented; `RenderKernelAudit` records that limitation explicitly.

The render kernels must never add any of these ledger conversions:

- `offlineManagedSampleRateConversion`
- `productionSampleRateConversion`
- `unknownGraphConversion`

Offline managed import remains the only approved sample-rate conversion path before production playback. The render kernel may consume the resulting managed asset only after the managed descriptor and session format agree on sample rate.

## Prompt 10 Output Adapter Ledger Facts

Prompt 10 adds validation/offline output adapters:

- `OfflineDesktopOutputAdapter`
- `OfflineDanteOutputAdapter`
- `DualOutputRenderCoordinator`

These adapters consume already-rendered blocks. They do not perform format conversion, channel remixing, sample-rate conversion, file I/O, or route negotiation inside block consumption.

Output adapter ledger/audit facts:

- Desktop output sample rate must equal the session sample rate.
- Dante output sample rate must equal the session sample rate.
- Desktop output must be stereo.
- Dante output must expose at least 31 physical channels.
- Physical Dante channel 32, when present, must remain silent and reserved.
- A route sample-rate mismatch is a validation failure, not a conversion event.
- A validation-only status is proof of route/render validation only. It is not proof that audio is leaving the Mac.

The output adapters must never add any of these ledger conversions:

- `offlineManagedSampleRateConversion`
- `productionSampleRateConversion`
- `unknownGraphConversion`

Future live output adapters must continue this rule: live device binding may accept only blocks already at the session sample rate and must fail closed rather than relying on hidden device or graph sample-rate conversion.

## Prompt 6 Managed Import Ledgers

Prompt 6 adds `ManagedAssetImporter` and `ManagedAssetDescriptor`.

Every managed import returns a descriptor with:

- Original path.
- Managed path.
- Original sample rate.
- Managed sample rate.
- Channel count.
- Channel layout.
- Codec description when known.
- Container description when known.
- Duration frames when known.
- Conversion ledger.
- Creation timestamp when produced by the importer.

The managed asset format is CAF Float32 PCM at the target session sample rate. This is an offline import artifact. It does not authorize hidden sample-rate conversion in the production render path.

When source sample rate differs from target session rate, the import ledger must include:

- `AllowedAudioConversion.offlineManagedSampleRateConversion`
- No `ForbiddenAudioConversion.productionSampleRateConversion`

When source sample rate already equals target session rate, the importer may still create a managed CAF Float32 PCM copy for canonical storage, but the ledger must not claim offline sample-rate conversion occurred.

`ProductionLocalAssetGate` blocks a mismatched local file before production playback. A running production session can admit only a file already at the session rate or a managed descriptor whose managed sample rate equals the session rate.

## Ledger Semantics

The ledger must distinguish between:

- A conversion that actually happened.
- A conversion that was explicitly not needed.
- A conversion that was blocked.
- A suspected external conversion outside Orbisonic.
- An unsupported route or hardware condition.

The ledger must be available through read-only snapshots and logs. UI may display ledger summaries, but UI must not calculate or mutate ledger truth.

## Session Boundary

A production session starts only after the ledger is valid.

If a command would change source format, sample rate, output route, or channel count, the current session must stop or atomically swap to a newly validated plan with a new ledger at a block boundary.

`StopRebuildPolicy` now models the conservative Prompt 5 contract:

- Session sample-rate changes require stop and rebuild.
- Dante output route changes require stop and rebuild until live route swapping is proven safe.
- Desktop output route changes are conservatively treated as rebuild events.
- Gain changes do not require rebuild.
- VU display changes do not require rebuild and must never change ledger truth.
- Mismatched source changes are blocked or sent to offline import, not converted inside production rendering.

## Prompt 12 Integration Status

The legacy local-file path now consults `LegacyLocalFileProductionGate` before renderer-selected playback can reach `OrbisonicEngine`.

That gate uses:

- `RouteCapabilityValidator` for route descriptors and Dante capability.
- `AudioSessionPlanner` for planned production session format and conversion policy.
- `ProductionLocalAssetGate` for local-file admission.

If a local file would require production sample-rate conversion, playback is blocked before the legacy engine commit and the user-facing message points to offline managed import or a stopped-session rate rebuild.

Remaining ledger TODOs:

- `NormalMonitorConversionLedger` still exists independently for the legacy Normal Monitor graph.
- `AudioSessionPlanner` produces a ledger draft, not a full running session ledger attached to live playback.
- The UI does not yet display or persist the Pure Audio ledger for each session.
- Managed import ledgers are produced by `AudioImport`, but the UI does not yet connect them to a complete production retry flow.
