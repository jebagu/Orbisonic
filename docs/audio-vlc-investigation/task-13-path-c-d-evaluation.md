# Task 13 - Path C and Path D Evaluation

## Scope

Task 13 evaluates two less-preferred VLC strategies so the final recommendation is not blind:

- Path C: `MediaSource -> FullLibVlcPlayer -> VLC-selected OS audio output`
- Path D: `MediaSource -> VLC demux/decode -> VLC memory/custom audio output module -> Orbisonic PCM ingest -> Orbisonic renderer`

This is a design and investigation task only. It does not implement libVLC, change playback behavior, add dependencies, add media fixtures, or run hardware/audio verification.

## Source Basis

This evaluation uses the prior VLC investigation documents and the ignored VLC source checkouts inspected for Tasks 6 through 12:

- Task 7 found that public libVLC audio callbacks suppress normal OS output and route decoded PCM through VLC's `amem` output path, but stock current `amem` rejects callback output above 8 channels.
- Task 8 found useful output-backend lifecycle concepts in VLC, especially explicit `start`, `play`, `pause`, `flush`, `drain`, timing reports, and device selection.
- Task 9 found that VLC's mapped speaker model is capped at 9 channels and that stock end-to-end preservation of Orbisonic 30-channel or 52-channel custom layouts is not proven.
- Task 11 defined the safer Path A decode bridge, where VLC owns only media opening, demux, decode, callbacks, and callback diagnostics.
- Task 12 defined the safer Path B output repair path, where Orbisonic keeps decode, routing, rendering, and output ownership while imitating useful VLC output-session contracts.

No standalone VLC playback test was run in this task because no bad sample, target route, or capture fixture was supplied for runtime verification.

## Path C - Full libVLC Playback

Path C uses VLC as the complete player:

```text
MediaSource
    -> FullLibVlcPlayer
    -> VLC-selected OS audio output
```

In this shape, VLC owns media opening, demux, decode, channel conversion, filters, timing, and platform output. Orbisonic would become a controller around an external player rather than the owner of Sonic Sphere routing.

## Path C As A Diagnostic Baseline

Full VLC playback is useful as a baseline when the exact same bad sample is played through standalone VLC or full libVLC and compared with Orbisonic playback.

The baseline is useful only if it records:

- the same source file or URL,
- the same sample rate,
- the selected VLC output backend and device,
- the observed channel count before output,
- any VLC logs about conversion, downmix, remap, or unsupported layouts,
- an objective output capture or per-channel identity check when multichannel behavior matters.

If VLC sounds clean while Orbisonic sounds distorted, that points suspicion toward Orbisonic's decode conversion, buffer scheduling, renderer, or device-output backend. If VLC is also distorted, that points suspicion toward the media, container, codec, route, sample-rate setup, or shared lower-level output conditions.

This task does not claim that VLC sounds clean with the bad sample because that playback was not run here.

## Path C As A Quick Workaround

Full libVLC playback could be a quick workaround for ordinary listening if the goal is "play this media cleanly on the current system output." It is less useful for Orbisonic's production purpose.

As a workaround it has hard limits:

- VLC chooses and negotiates the output route through its own backend.
- Orbisonic cannot treat VLC's output as proof that Sonic Sphere routing is correct.
- VLC can convert, downmix, reorder, or reject layouts according to its own mapped speaker model and backend constraints.
- Orbisonic's existing renderer modes, Direct 30/30.1 semantics, diagnostics, and monitor/production split are bypassed.

That makes Path C acceptable only as a debug or preview escape hatch, not as a production Sonic Sphere architecture.

## Path C As A Final Architecture

Path C is not a good final architecture unless a targeted harness proves all of the following for the intended platform, device, and media set:

- high-channel files open and decode correctly,
- 30 discrete channels can reach the intended device without downmix, channel dropping, or remapping,
- 52 discrete channels can be preserved when preservation is required,
- VLC's selected output backend can target the exact Sonic Sphere route,
- channel identity is externally verified at the destination,
- Orbisonic can either control the mapping explicitly or has an accepted contract to trust VLC's mapping.

The inspected source does not provide that proof. Current evidence instead says full VLC playback is useful as a baseline, but not as Orbisonic's final output architecture.

## Path C Direct Answers

### 1. Does standalone VLC or full libVLC playback sound clean with the same bad sample?

Not verified in this task. No bad sample was played through standalone VLC or full libVLC here.

Path C should be used as a future diagnostic baseline with the exact same sample, route, sample rate, and an objective capture. A clean VLC result would narrow the suspected fault to Orbisonic-specific decode, conversion, scheduling, rendering, or output. A bad VLC result would keep the source, codec, route, and device conditions under suspicion.

### 2. Does it preserve all channels?

Not proven.

VLC can preserve ordinary mapped layouts in some cases, but prior inspection found path-specific limits and conversion points. VLC's mapped speaker layout is capped at 9 standard channels, stock callback output is capped at 8 in current `amem`, unknown maps can be converted into a limited WAVE-style physical layout, and backend output may further negotiate or downmix.

### 3. Does it output 30 discrete channels?

Not proven.

Some VLC backend shapes are high-channel-friendly in concept, such as JACK creating one port per output channel or PipeWire using auxiliary positions, but the inspected stock VLC path does not prove end-to-end 30-channel Orbisonic custom routing. A 30-channel claim needs a targeted channel-identity harness and a proven 30-channel route.

### 4. Does it output 52 discrete channels?

Not proven.

The 52-channel case has more blockers than the 30-channel case. Prior inspection found a generic 64-channel unmapped input ceiling in some paths, but format-specific demuxers and normal output/filter stages can reject, reinterpret, or drop channels. WAV PCM above 32 channels is specifically blocked in the inspected VLC demux path.

### 5. Does it preserve Sonic Sphere routing?

No, not by default.

VLC does not know Orbisonic's Sonic Sphere topology, calibration, Direct 30 semantics, Direct 30.1 semantics, reserved channel policy, normal-monitor boundary, or production route contract. Full VLC output cannot be treated as preserving Sonic Sphere routing unless an explicit output map and external channel-identity test prove it.

### 6. Can Orbisonic control channel mapping?

Only in a limited and indirect way.

Orbisonic could select VLC options, choose a device, or possibly provide a layout-related media option if a target build supports it. That is not the same as owning the channel router. Full-player output leaves actual mapping, conversion, and backend negotiation inside VLC and the OS output path.

### 7. Can Orbisonic integrate spatial rendering?

Not in the full-output shape.

Once VLC owns the player output, decoded PCM does not return to Orbisonic's router and renderer. Orbisonic could build controls around VLC playback, but it could not apply its own Sonic Sphere renderer or normal-monitor policy to VLC's already-rendered output.

### 8. Does it bypass Orbisonic's value proposition?

Yes, for production use.

Orbisonic's value proposition is not merely opening media. It is selected-source routing, reliable multichannel diagnostics, Sonic Sphere production rendering, direct-channel semantics, and a controlled normal-monitor preview path. Full VLC output bypasses those boundaries.

## Path C Verdict

Path C should remain a diagnostic baseline and possible temporary ordinary-playback workaround. It should not be the final Orbisonic architecture unless future tests prove high-channel routing, custom channel layouts, and Sonic Sphere destination identity end to end.

## Path D - VLC Memory Or Custom Audio Output

Path D uses VLC as a decode engine plus memory/custom output mechanism, then feeds Orbisonic:

```text
MediaSource
    -> VLC demux/decode
    -> VLC memory/custom audio output module
    -> Orbisonic PCM ingest
    -> OrbisonicChannelRouter
    -> OrbisonicSpatialRenderer
    -> OrbisonicDeviceOutput
```

There are two different meanings hidden in Path D:

- Use stock libVLC audio callbacks, which are the public facade around the `amem` memory audio output.
- Write or ship a custom VLC audio output module, which would bind Orbisonic to VLC internal module APIs and packaging behavior.

The first meaning is essentially Path A. The second meaning is a custom VLC integration project with higher maintenance, licensing, and packaging risk.

## Path D Direct Answers

### 1. Is a memory audio output module present in inspected VLC versions?

Yes.

The inspected current VLC checkout has `modules/audio_output/amem.c`. The inspected VLC 3.0 checkout also has `modules/audio_output/amem.c`. Current `amem` is identified as an audio output module named "Audio memory" and exposes private options such as `amem-format`, `amem-rate`, and `amem-channels`.

### 2. Is it public and stable enough?

The public and stable-enough surface is the libVLC audio callback API, not direct ownership of `amem` internals.

The public callback API is documented in libVLC headers and is appropriate for a bounded decode bridge experiment. Directly configuring `amem` module variables, depending on its private option names, or modifying the module itself is a weaker contract. It is source-compatible only to the extent VLC keeps those internals stable.

### 3. Is it better than libVLC callbacks?

Not in stock form.

Stock libVLC callbacks already select the `amem,none` output path, suppress normal OS audio output, and deliver decoded PCM to application callbacks. Direct `amem` use does not provide a better public contract than the callback API.

A custom audio output module could expose more metadata or higher channel counts, but that would no longer be a simple libVLC integration. It would be a custom VLC module that Orbisonic must build, package, and maintain.

### 4. Does it preserve high channel counts?

No, not in the inspected stock `amem` path.

Current `amem` defines `AMEM_CHAN_MAX 8` and rejects channels above that. VLC 3.0's inspected `amem` path is also ordinary-surround-scale and was not proven for high-channel Float32 callback output. Therefore stock memory output does not preserve 30-channel or 52-channel Orbisonic layouts.

A custom output module might be able to carry higher counts, but that would need proof against VLC's upstream channel model, filters, decoder outputs, and package format.

### 5. Does it expose better timing or layout metadata?

Only slightly for timing, and not enough for layout through the public callback path.

The public play callback provides a PTS and sample count. Flush, drain, pause, and resume callbacks provide useful transport boundaries. The setup callback exposes format, sample rate, and channel count.

The public callback path does not expose full VLC `audio_sample_format_t` layout fields, physical channel bitmap, Ambisonic metadata, or Sonic Sphere mapping. A custom internal output module could access more internal structures, but then it would rely on internal VLC APIs rather than the public libVLC contract.

### 6. Does it require internal VLC APIs?

Stock libVLC callbacks do not require internal VLC APIs.

Direct `amem` module work or a custom VLC output module likely does. A custom module would depend on VLC's `audio_output_t`, `audio_sample_format_t`, module loading, block ownership, timing report, and build/package conventions. That is a materially larger integration surface than Path A.

### 7. Does it increase licensing or packaging risk?

Yes, if Orbisonic ships or modifies VLC modules.

Using public libVLC binaries and headers is the lower-risk shape for this investigation. Shipping a custom audio output module, copying VLC module code, or distributing a modified VLC build increases packaging complexity and legal-review needs. The detailed licensing decision is deferred to the licensing/package task, but Path D custom-output work is clearly higher risk than a public callback bridge.

### 8. Is it supported by libVLC distribution packages?

Public libVLC callbacks are the supported distribution-facing path when the target package includes the required audio memory output module.

A custom VLC output module is not automatically supported by distribution packages. It would require Orbisonic to build, install, locate, sign, and load that module consistently across local developer machines and shipped app bundles.

## Path D Verdict

Path D is not better than Path A in stock form. The useful public mechanism is already the libVLC callback bridge from Task 11.

A custom VLC memory/output module might remove the stock `amem` channel cap and expose richer metadata, but that turns the work into a maintained VLC module integration. That is too much risk for the current evidence and should not be selected before Path A and Path B are objectively tested.

## What These Paths Teach Us Architecturally

### Using VLC As A Whole Player

VLC as a whole player is valuable for comparison. It can answer whether VLC itself can play a problem file cleanly under roughly similar local conditions.

It is not a natural fit for Orbisonic production output because it gives VLC control over channel conversion, backend negotiation, and destination routing. That conflicts with Orbisonic's reason to exist.

### Using VLC As A Decode Engine

VLC as a decode engine is the strongest VLC-based role so far.

This is Path A: VLC opens difficult media, decodes it, and delivers PCM into Orbisonic. Orbisonic keeps layout authority, channel routing, Sonic Sphere rendering, output route selection, metering, and diagnostics. The main current blocker is that stock callbacks are not proven for 30-channel or 52-channel output.

### Using VLC As An Output Engine

VLC as an output engine is useful as an architectural reference but weak as a direct dependency.

VLC's output backends demonstrate good contracts for negotiation, timing, drain, flush, latency reporting, and fail-loud device handling. Orbisonic should imitate those contracts in a native output session rather than hand the Sonic Sphere route to VLC.

### Using VLC As An Architectural Reference

VLC's strongest lesson is separation of responsibilities:

- demux and decode are not the same as rendering,
- channel count is not the same as channel identity,
- output negotiation must report actual format and latency,
- flush and drain are different operations,
- shared-mode output is not proof of discrete-channel production routing,
- high-channel support must be proven at every layer.

Those lessons support the current ranking: Path B for native output repair if Orbisonic PCM is already correct, Path A for a bounded VLC decode bridge if current media opening/decode is the fault, Path C only as a baseline or preview, and Path D custom output only as a later fallback if a public callback bridge is insufficient and the added integration risk is accepted.

## Recommended Next Experiments

- Run the exact bad sample through standalone VLC or full libVLC and capture whether it sounds clean.
- Capture VLC verbose logs for output backend, device, sample rate, channel count, layout conversion, and filter insertion.
- Use deterministic 30-channel and 52-channel identity fixtures for any claim about high-channel preservation.
- Verify whether the intended libVLC package includes the audio memory output module.
- Do not select full VLC output or custom VLC output as final architecture before high-channel route identity is proven.

## Conclusion

Full VLC playback may be useful as a diagnostic baseline and possibly a temporary ordinary-playback workaround. It is not the right final Orbisonic architecture unless it proves high-channel custom routing and Sonic Sphere destination identity.

VLC memory/custom output is useful through the public libVLC callback API, which is already Path A. Direct or custom memory output is not better than callbacks unless Orbisonic is willing to own a custom VLC module and its associated packaging and maintenance risk.
