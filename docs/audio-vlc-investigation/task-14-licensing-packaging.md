# Task 14 - Licensing, Dependency, And Packaging Risk Analysis

## Scope

Task 14 documents licensing and packaging risks for the VLC integration paths under consideration.

This is engineering risk analysis, not legal advice. A lawyer or qualified open-source compliance reviewer must review any final decision before shipping libVLC, VLC plugins, modified VLC code, copied VLC source, bundled codec libraries, or a commercial/public distribution that depends on them.

No Orbisonic app code, tests, scripts, installer files, vendor files, resources, calibration files, or binary assets were changed for this task.

## Evidence Commands

- `git status --short`
- `sed -n '1053,1120p' orbisonic_vlc_codex_prompt_sequence.md`
- `find . -maxdepth 2 -iname 'LICENSE*' -o -iname 'COPYING*' -o -iname 'NOTICE*' | sort`
- `rg -n "license|copyright|proprietary|MIT|Apache|GPL|LGPL|distribution|distribute" README.md Package.swift AGENTS.md docs installer scripts Sources Tests`
- `find _external/vlc _external/vlc-3.0 -maxdepth 2 \( -iname 'COPYING*' -o -iname 'LICENSE*' -o -iname 'README*' \) | sort`
- `sed -n '1,70p' _external/vlc/README.md`
- `sed -n '1,40p' _external/vlc/COPYING`
- `sed -n '1,45p' _external/vlc/COPYING.LIB`
- `sed -n '1,40p' _external/vlc/include/vlc/libvlc_media_player.h`
- `sed -n '1,40p' _external/vlc/lib/media_player.c`
- `sed -n '1,40p' _external/vlc/src/audio_output/dec.c`
- `sed -n '1,40p' _external/vlc/modules/audio_output/amem.c`
- `sed -n '1,40p' _external/vlc/modules/audio_output/apple/auhal.c`
- `sed -n '1,40p' _external/vlc/modules/audio_output/jack.c`
- `sed -n '1,40p' _external/vlc/modules/audio_output/pipewire.c`
- `sed -n '1,40p' _external/vlc/modules/audio_filter/channel_mixer/remap.c`
- `sed -n '1,40p' _external/vlc/modules/audio_filter/channel_mixer/spatialaudio.cpp`
- `rg -l "under the terms of the GNU Lesser General Public License" _external/vlc/include _external/vlc/lib _external/vlc/src _external/vlc/modules/audio_output _external/vlc/modules/audio_filter | sort`
- `rg -l "under the terms of the GNU General Public License" _external/vlc/include _external/vlc/lib _external/vlc/src _external/vlc/modules/audio_output _external/vlc/modules/audio_filter | sort`
- `sed -n '1,55p' _external/vlc-3.0/README`
- `sed -n '1,35p' _external/vlc-3.0/modules/audio_output/directsound.c`
- `rg -l "under the terms of the GNU General Public License" _external/vlc-3.0/include _external/vlc-3.0/lib _external/vlc-3.0/src _external/vlc-3.0/modules/audio_output _external/vlc-3.0/modules/audio_filter | sort`
- `sed -n '1,35p' _external/vlc-3.0/modules/audio_filter/channel_mixer/dolby.c`
- `sed -n '1,35p' _external/vlc-3.0/modules/audio_filter/channel_mixer/headphone.c`
- `sed -n '1,35p' _external/vlc-3.0/modules/audio_filter/channel_mixer/mono.c`
- `sed -n '1,220p' Package.swift`
- `find Vendor -maxdepth 3 -type f | sort | head -n 80`
- `sed -n '1,80p' Vendor/librespot/LICENSE`
- `sed -n '1,160p' Vendor/librespot/ORBISONIC_VENDOR.md`
- `sed -n '1,80p' Vendor/orbisonic-librespot-ffi/Cargo.toml`
- `sed -n '1,80p' Sources/Orbisonic/Resources/RoonBridge/package.json`
- `find Orbisonic.app -maxdepth 5 -type f | sort | rg "(ffmpeg|ffprobe|dylib|framework|lib|Info.plist|PkgInfo|Resources|MacOS)"`
- `sed -n '1,220p' scripts/build-installer.sh`
- `sed -n '1,220p' scripts/refresh-orbisonic-app.sh`

## Source Summary

Current VLC README says VLC is GPLv2-or-later and that libVLC is LGPLv2-or-later so the engine can be embedded in third-party applications. The current VLC tree includes `COPYING` for GPLv2 and `COPYING.LIB` for LGPL 2.1.

The inspected current libVLC headers, current `lib/` files, current `src/audio_output/` files, and the relevant current `modules/audio_output/` and `modules/audio_filter/` files used in the audio investigation are overwhelmingly LGPL 2.1-or-later by header. The current search for GPL-only headers in the inspected current paths found only files outside the useful audio integration set: `src/test/diffutil.c` and `src/win32/mta_holder.h`.

The inspected VLC 3.0 tree has the same high-level `COPYING` and `COPYING.LIB` split, but some older audio filter/channel-mixer modules are GPLv2-or-later by header, including `modules/audio_filter/channel_mixer/dolby.c`, `headphone.c`, and `mono.c`. The same current files are LGPL in the inspected current VLC checkout. That version difference matters if Orbisonic ever copies or depends on old module source.

## Direct Answers

### 1. What is Orbisonic's license or likely distribution model?

No top-level `LICENSE`, `COPYING`, or `NOTICE` file was found in the active Orbisonic repo root. The safest engineering assumption is that Orbisonic is currently unlicensed/proprietary from an outside-user perspective until the project owner declares a license.

The current distribution model is a macOS app bundle plus installer packages. The repo has `Orbisonic.app`, app-only packages, suite packages, HAL loopback input drivers, ad hoc codesigning scripts, release verification docs, and a packaged Roon bridge resource.

Because no outbound license is declared, any public or commercial distribution needs legal review before adding LGPL/GPL components.

### 2. Does Orbisonic currently statically link, dynamically link, or bundle third-party native libraries?

Current native/dependency shape:

- Static link: `Package.swift` links `liborbisonic_librespot_ffi.a` from `.build/orbisonic-librespot` through unsafe linker flags.
- Native system frameworks: `Package.swift` links Apple frameworks including AudioToolbox, CoreAudio, CoreFoundation, Foundation, Security, and SystemConfiguration.
- Bundled native executables: the current app bundle contains `Resources/Tools/ffmpeg` and `Resources/Tools/ffprobe`.
- Vendored source: `Vendor/librespot` is pinned upstream librespot source; `Vendor/orbisonic-librespot-ffi` is the Rust FFI static-library boundary.
- Bundled non-native helper resource: `Sources/Orbisonic/Resources/RoonBridge` includes a Node package with `license: "UNLICENSED"` and Roon API dependencies.
- Installer payloads: current release docs record app-only and suite package behavior, including suite-installed HAL loopback input drivers.

No libVLC dynamic or static dependency is present in the current Swift package.

### 3. Would dynamic linking to libVLC be acceptable under LGPL obligations?

Possibly, but only with compliance work and legal review.

Engineering interpretation: dynamic linking to public libVLC is the lowest-risk VLC integration shape because libVLC is documented as LGPLv2-or-later and intended for embedding. That does not mean "no obligations." If Orbisonic distributes libVLC binaries, the package must preserve notices, include license texts, keep the libVLC boundary replaceable to the extent LGPL requires, avoid copying GPL-only VLC application/source code into Orbisonic, and document how users can obtain or replace the LGPL-covered library.

Legal review must confirm whether Orbisonic's chosen packaging, signing, notarization, update path, and any static-vs-dynamic details satisfy the applicable LGPL version and dependency licenses.

### 4. What obligations appear if Orbisonic distributes libVLC binaries?

Likely obligations and engineering tasks:

- Ship or reference the relevant GPL/LGPL license texts and notices.
- Preserve copyright notices.
- Provide or point to corresponding source for LGPL-covered libVLC and any distributed modified LGPL components.
- Track the exact libVLC version, build configuration, plugin set, and dependency list.
- Keep third-party license inventory for codec, demux, access, output, and plugin dependencies bundled with libVLC.
- Ensure users are not blocked from replacing or relinking the LGPL-covered library where the license requires that.
- Validate code signing and notarization without turning the libVLC/plugin set into an unreplaceable black box.

This is not hard in principle, but it becomes real release engineering work.

### 5. What obligations appear if Orbisonic modifies libVLC?

Modifying libVLC increases obligations and maintenance cost.

Likely requirements include publishing or offering source for the modified LGPL-covered libVLC files, clearly marking modifications, preserving notices, making the modified library buildable or replaceable as required, and carrying a long-term fork against upstream VLC.

For Orbisonic, this would also mean a regression matrix for each macOS build and any future Windows/Linux target. A modified libVLC is not a casual dependency.

### 6. What obligations appear if Orbisonic copies VLC source files?

Copying VLC source into Orbisonic is the highest-risk option.

Engineering consequences:

- The copied files bring their file-level licenses with them.
- LGPL files create compliance obligations for those files and any derivative work boundary.
- GPL files can force GPL obligations on the combined work depending on how they are used.
- Version-specific license differences matter; some VLC 3.0 audio channel-mixer modules are GPL-only even though the corresponding current files inspected here are LGPL.
- Future source-level updates become manual merges, with attribution and change tracking.

The safe engineering rule is: do not copy VLC source into Orbisonic for this investigation.

### 7. Which inspected VLC files are LGPL?

Current VLC files directly relevant to the investigation and inspected as LGPL 2.1-or-later include:

- `include/vlc/libvlc_media_player.h`
- `include/vlc/libvlc_media.h`
- `include/vlc/libvlc.h`
- `include/vlc_aout.h`
- `include/vlc_es.h`
- `lib/media_player.c`
- `lib/media.c`
- `lib/audio.c`
- `src/audio_output/dec.c`
- `src/audio_output/output.c`
- `src/audio_output/filters.c`
- `src/audio_output/common.c`
- `src/audio_output/meter.c`
- `modules/audio_output/amem.c`
- `modules/audio_output/apple/auhal.c`
- `modules/audio_output/apple/coreaudio_common.c`
- `modules/audio_output/jack.c`
- `modules/audio_output/pipewire.c`
- `modules/audio_output/alsa.c`
- `modules/audio_output/pulse.c`
- `modules/audio_output/wasapi.c`
- `modules/audio_filter/channel_mixer/remap.c`
- `modules/audio_filter/channel_mixer/simple.c`
- `modules/audio_filter/channel_mixer/trivial.c`
- `modules/audio_filter/channel_mixer/spatialaudio.cpp`
- `modules/audio_filter/resampler/soxr.c`
- `modules/audio_filter/resampler/speex.c`
- `modules/audio_filter/resampler/src.c`
- `modules/audio_filter/resampler/ugly.c`

VLC 3.0's `modules/audio_output/directsound.c` was also inspected and is LGPL 2.1-or-later by header.

### 8. Which inspected VLC files are GPL?

Current VLC GPL-only search hits in the inspected current paths:

- `src/test/diffutil.c`
- `src/win32/mta_holder.h`

These are not useful audio integration targets for Orbisonic.

VLC 3.0 GPL-only search hits in the inspected paths include:

- `modules/audio_filter/channel_mixer/dolby.c`
- `modules/audio_filter/channel_mixer/headphone.c`
- `modules/audio_filter/channel_mixer/mono.c`
- `src/win32/mta_holder.h`

The three VLC 3.0 channel-mixer modules are relevant only as a warning against copying older VLC audio filter source. They are not needed for the recommended Orbisonic path.

### 9. Are any useful VLC modules GPL-only?

For the current VLC checkout inspected here, no useful Path A/B/C/D module in the examined audio-output or audio-filter set was found to be GPL-only. The useful current modules checked for Orbisonic, such as `amem`, AUHAL/CoreAudio, JACK, PipeWire, ALSA, PulseAudio, WASAPI, remap, simple/trivial mixers, and spatialaudio, are LGPL by header.

For VLC 3.0, some channel-mixer modules are GPL-only. They are not needed for Orbisonic's recommended path, but they prove that "a VLC module" cannot be assumed LGPL without checking the exact file and exact VLC version.

### 10. Are platform codecs or VLC plugin dependencies a packaging risk?

Yes.

libVLC is not just one dynamic library in practice. Useful playback usually depends on plugin discovery, codec/demux/access modules, and platform-specific libraries. The current VLC README also warns that some platforms are effectively GPLv3 because of dependency licenses.

Packaging risks:

- Codec and demux plugin selection can alter license obligations.
- Missing plugins can make media open but not decode.
- Plugin paths can break inside a signed app bundle.
- The exact plugin set must be reproducible for test, release, and support.
- Dependencies such as FFmpeg/libavcodec-family components, TLS, network access, audio output backends, JACK/PipeWire/ALSA/PulseAudio support, and platform codecs can have their own licenses and runtime assumptions.

Orbisonic already has some of this class of risk through bundled `ffmpeg`/`ffprobe`, embedded librespot, Roon bridge resources, and suite-installed HAL drivers. libVLC would add a second plugin-based native media stack.

### 11. How difficult is Windows packaging?

Medium to high.

Windows would need libVLC DLLs, plugins, dependency DLLs, a known plugin search path, architecture matching, installer integration, update behavior, code-signing, and runtime diagnostics for missing DLLs or plugins. WASAPI/MMDevice device selection may be useful, but it introduces a Windows-specific route matrix that Orbisonic does not currently ship.

Path C full playback is easiest to get audible on Windows. Path A callback bridge is more controlled but still requires libVLC and plugin packaging. Path D custom modules are the hardest.

### 12. How difficult is macOS packaging?

Medium.

Orbisonic is already a macOS app bundle with ad hoc signing, installer packages, bundled tools, resources, and HAL driver release checks. Adding libVLC means deciding whether libVLC lives in the app bundle, where plugins live, how plugin discovery is configured, how the app is signed and notarized with those binaries, and how LGPL replacement expectations interact with signed bundle integrity.

macOS also has route-specific risk: Core Audio device selection, microphone permission for loopback capture, LaunchServices launch behavior, and suite-installed HAL input drivers already require manual verification. libVLC would need its own runtime-unavailable and plugin-unavailable diagnostics.

### 13. How difficult is Linux packaging?

Medium.

Linux can often use distro libVLC packages, which reduces bundled-binary obligations but increases version variance. If Orbisonic bundles libVLC, it must manage shared libraries, plugins, distro ABI differences, codecs, JACK/PipeWire/PulseAudio/ALSA availability, sandbox packaging rules, and license inventory.

Linux is probably easier than macOS for dynamic library replacement, but harder for consistent audio-route behavior across distributions.

### 14. Does adding libVLC increase app size or plugin management complexity?

Yes.

libVLC adds library binaries, plugin modules, codec/access/demux/output dependencies, version pinning, plugin search configuration, diagnostics for missing modules, package signing/notarization work, and release inventory. A minimal callback bridge still needs enough plugins to open the target media.

This is materially more complex than Path B, which copies no VLC code and adds no libVLC runtime dependency.

### 15. Is code signing, notarization, or plugin discovery relevant?

Yes.

On macOS, bundled dynamic libraries and plugins must be signed in a way compatible with the app bundle and installer. Notarization for public distribution would need to cover the full embedded binary set. Plugin discovery must be deterministic after signing and installation, not dependent on a developer machine's VLC install.

The runtime should surface:

- libVLC library not found,
- libVLC version unsupported,
- plugin directory missing,
- required decoder/access/output module missing,
- callback audio memory output unavailable,
- media opened but no decoded callback blocks arrived.

### 16. Does the feature flag need to support "VLC unavailable" at runtime?

Yes.

The build flag and runtime flag should be separate:

- Build-time flag: compile VLC bridge code only when libVLC headers and link settings are intentionally enabled.
- Runtime availability: detect whether the library, plugin directory, required modules, and target callback path are present.
- User-visible state: show VLC unavailable as a diagnostic state, not a crash or silent fallback.
- Existing path preservation: Orbisonic must continue to run without VLC so the current native path, live loopback sources, test tone, Roon/Aux/Spotify source boundaries, and normal-monitor behavior remain available.

## Licensing Impact By Architecture

### Path A - libVLC Callback Bridge

Risk: medium.

This is the lowest-risk VLC dependency if VLC is used at all. It links to public libVLC, uses public callback APIs, avoids normal VLC OS output, and keeps Orbisonic's renderer, route selection, and Sonic Sphere semantics in Orbisonic.

Licensing impact:

- LGPL libVLC compliance is required if libVLC is distributed.
- Plugin and dependency license inventory is required.
- No VLC source should be copied into Orbisonic.
- No custom VLC module should be shipped for the first spike.

Packaging impact:

- Add libVLC discovery, version checks, plugin path setup, code signing/notarization handling, and runtime unavailable diagnostics.
- Keep the native app usable when VLC is absent.

### Path B - VLC-Inspired Native Backend With No Copied Code

Risk: low.

Path B copies concepts, not code. It imitates lifecycle and diagnostics patterns such as configure/start/play/flush/drain/timing reports while keeping implementation native to Orbisonic.

Licensing impact:

- No new VLC license obligations if no VLC source, headers, binaries, or generated code are copied or distributed.
- Normal Orbisonic dependency review still applies for any future native libraries added independently.

Packaging impact:

- No libVLC plugin management.
- No added VLC signing/notarization path.
- The risk stays in engineering correctness rather than open-source compliance.

### Path C - Full libVLC Playback

Risk: medium to high.

Path C uses public libVLC, so it can stay in the LGPL dynamic-linking lane if implemented carefully. But it depends on a broader libVLC plugin/output stack and bypasses Orbisonic's core value proposition.

Licensing impact:

- Same LGPL and plugin-dependency compliance as Path A.
- Potentially broader dependency set because full playback may use more output, filter, and platform modules.

Packaging impact:

- Higher plugin management complexity than Path A.
- More output-backend testing.
- Still needs runtime unavailable behavior.
- Does not solve Sonic Sphere routing unless high-channel output and destination identity are independently proven.

### Path D - Custom VLC Module Or Copied Internal Module Code

Risk: high.

Path D is only low risk if it means public libVLC callbacks, in which case it collapses back into Path A. If it means a custom VLC module or copied `amem`/audio-output internals, it becomes the highest-risk option.

Licensing impact:

- Modifying LGPL VLC files likely requires source publication/offer and clear modification tracking.
- Copying source files imports file-level licenses into Orbisonic.
- Copying GPL-only modules can create GPL obligations for the combined work.
- Legal review is mandatory before distributing anything in this shape.

Packaging impact:

- Custom module build, install, signing, discovery, version matching, and crash diagnostics.
- Harder cross-platform support.
- Higher long-term maintenance cost against upstream VLC.

## Recommended Low-Risk Path

Lowest legal/packaging risk: Path B, the VLC-inspired native backend with no copied VLC code and no libVLC binary dependency.

Lowest-risk VLC integration if VLC is still needed after objective tests: Path A, a public libVLC callback bridge behind build-time and runtime feature flags, dynamically linked where practical, with no copied VLC source and no custom VLC module. It should be packaged only after legal review confirms LGPL compliance, plugin/dependency notices, user replacement expectations, code signing/notarization implications, and exact distribution obligations.

Avoid Path D custom module or copied internal code unless Path A and Path B both fail objective tests and the project explicitly accepts legal, packaging, and maintenance risk.
