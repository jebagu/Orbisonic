# Task 06 - VLC Source Architecture Map

## Scope

Task 6 inspects VLC source architecture as an external reference. It does not integrate VLC, libVLC, or VLC modules into Orbisonic and does not recommend an implementation.

This is a docs-only task. No Orbisonic app code, tests, scripts, resources, installer files, vendor files, calibration files, or binary media assets were changed. VLC source was cloned under `_external/`, which is a local ignored research directory and not part of Orbisonic source.

## Source Acquisition

Current VLC checkout:

- Repo URL: `https://github.com/videolan/vlc.git`
- Local path: `_external/vlc`
- Clone command: `git clone --depth 1 https://github.com/videolan/vlc.git _external/vlc`
- Branch: `master`
- Commit: `b91572e7424a472bbf80d3ad5025fc20ca3fbd1d`

VLC 3.0 checkout:

- Repo URL: `https://github.com/videolan/vlc-3.0.git`
- Local path: `_external/vlc-3.0`
- Clone command: `git clone --depth 1 https://github.com/videolan/vlc-3.0.git _external/vlc-3.0`
- Branch: `master`
- Commit: `e30973a45e8c4f075cf5a6094f500cd3100665f5`

Local source-directory note:

- `_external/` was added to `.git/info/exclude`, not to tracked `.gitignore`.
- Current VLC has `README.md`, but no `modules/MODULES_LIST`.
- VLC 3.0 has `README` and `modules/MODULES_LIST`, but no root `README.md`.

## Evidence Commands

- `git status --short`
- `sed -n '369,455p' orbisonic_vlc_codex_prompt_sequence.md`
- `mkdir -p _external`
- `git clone --depth 1 https://github.com/videolan/vlc.git _external/vlc`
- `git clone --depth 1 https://github.com/videolan/vlc-3.0.git _external/vlc-3.0`
- `git -C _external/vlc rev-parse --abbrev-ref HEAD`
- `git -C _external/vlc rev-parse HEAD`
- `git -C _external/vlc remote -v`
- `git -C _external/vlc-3.0 rev-parse --abbrev-ref HEAD`
- `git -C _external/vlc-3.0 rev-parse HEAD`
- `git -C _external/vlc-3.0 remote -v`
- `ls README.md COPYING COPYING.LIB include/vlc/libvlc_media_player.h include/vlc_aout.h include/vlc_es.h lib/audio.c src/audio_output modules/audio_output modules/audio_filter modules/MODULES_LIST`
- `find _external/vlc/src/audio_output -maxdepth 2 -type f | sort`
- `find _external/vlc/modules/audio_output -maxdepth 2 -type f | sort`
- `find _external/vlc/modules/audio_filter -maxdepth 2 -type f | sort`
- `rg -n "libvlc_audio_set_callbacks|libvlc_audio_set_format|libvlc_audio_set_format_callbacks|audio_set_callbacks|audio_set_format" _external/vlc _external/vlc-3.0`
- `rg -n "audio_output_t|aout_|AOUT_CHAN_MAX|INPUT_CHAN_MAX|audio_format_t|channel_type|AMBISONICS|i_physical_channels|i_channels|i_chan_mode" _external/vlc/include _external/vlc/src _external/vlc/modules`
- `rg -n "ChannelReorder|ChannelExtract|Interleave|Deinterleave|channel.*reorder|channel.*map|remap|spatialaudio|spatializer|channel_mixer|simple_channel_mixer|trivial_channel_mixer" _external/vlc/include _external/vlc/src _external/vlc/modules`
- `rg -n "WASAPI|IAudioClient|IAudioRenderClient|AUDCLNT|exclusive|shared|CoreAudio|AUHAL|AudioUnit|snd_pcm|PulseAudio|PipeWire|JACK|DirectSound|MMDevice|amem" _external/vlc/modules/audio_output _external/vlc/src`
- Targeted reads of the files and line ranges cited below.

The broad searches were run over the cloned source trees. Some outputs were large; this document records the source paths and exact lines that matter for the architecture map.

## File Paths Inspected

Current VLC:

- `_external/vlc/README.md`
- `_external/vlc/COPYING`
- `_external/vlc/COPYING.LIB`
- `_external/vlc/include/vlc/libvlc_media.h`
- `_external/vlc/include/vlc/libvlc_media_player.h`
- `_external/vlc/include/vlc_aout.h`
- `_external/vlc/include/vlc_es.h`
- `_external/vlc/lib/audio.c`
- `_external/vlc/lib/media.c`
- `_external/vlc/lib/media_player.c`
- `_external/vlc/lib/libvlc.sym`
- `_external/vlc/src/libvlccore.sym`
- `_external/vlc/src/audio_output/aout_internal.h`
- `_external/vlc/src/audio_output/common.c`
- `_external/vlc/src/audio_output/dec.c`
- `_external/vlc/src/audio_output/filters.c`
- `_external/vlc/src/audio_output/meter.c`
- `_external/vlc/src/audio_output/output.c`
- `_external/vlc/src/audio_output/volume.c`
- `_external/vlc/src/input/input.c`
- `_external/vlc/src/input/decoder.c`
- `_external/vlc/modules/audio_output/`
- `_external/vlc/modules/audio_filter/`

VLC 3.0:

- `_external/vlc-3.0/README`
- `_external/vlc-3.0/COPYING`
- `_external/vlc-3.0/COPYING.LIB`
- `_external/vlc-3.0/include/vlc/libvlc_media_player.h`
- `_external/vlc-3.0/include/vlc_aout.h`
- `_external/vlc-3.0/include/vlc_es.h`
- `_external/vlc-3.0/lib/audio.c`
- `_external/vlc-3.0/lib/media_player.c`
- `_external/vlc-3.0/modules/audio_output/`
- `_external/vlc-3.0/modules/audio_filter/`
- `_external/vlc-3.0/modules/MODULES_LIST`

## High-Level Source Layout

Current `README.md` describes VLC as both media player and multimedia engine, and says the engine can be embedded into third-party applications as libVLC at `_external/vlc/README.md:1` through `:13`.

The same README records the source directory split:

- `lib/` is libVLC source code at `_external/vlc/README.md:134`.
- `modules/` contains VLC plugins and modules at `_external/vlc/README.md:136`.
- `src/` is libvlccore source code at `_external/vlc/README.md:138`.

The current public libVLC export list exposes audio control and callback symbols in `_external/vlc/lib/libvlc.sym:14` through `:35`, while libvlccore exports internal audio-output symbols in `_external/vlc/src/libvlccore.sym:3` through `:30`. That supports the split visible in the tree: embedding API in `lib/`, shared engine/core in `src/`, and platform or feature modules in `modules/`.

## Public libVLC Embedding API

The public embedding layer is under `include/vlc/` and `lib/`.

Media creation paths:

- `libvlc_media_new_location` is declared at `_external/vlc/include/vlc/libvlc_media.h:288` and implemented at `_external/vlc/lib/media.c:388`.
- `libvlc_media_new_path` is declared at `_external/vlc/include/vlc/libvlc_media.h:298` and implemented at `_external/vlc/lib/media.c:410`.
- `libvlc_media_new_callbacks` is declared at `_external/vlc/include/vlc/libvlc_media.h:350` and implemented at `_external/vlc/lib/media.c:434`.
- `libvlc_media_add_option` and option flags are declared at `_external/vlc/include/vlc/libvlc_media.h:385` and `:406`, then implemented at `_external/vlc/lib/media.c:474` and `:482`.

Media-player transport paths:

- `libvlc_media_player_play`, `set_pause`, `pause`, and `stop_async` are declared at `_external/vlc/include/vlc/libvlc_media_player.h:286` through `:316` and implemented at `_external/vlc/lib/media_player.c:996`, `:1012`, `:1035`, and `:1062`.
- Seek/rate controls are declared at `_external/vlc/include/vlc/libvlc_media_player.h:1328`, `:1364`, and `:1521`, and implemented at `_external/vlc/lib/media_player.c:1459`, `:1471`, and `:1833`.

Audio-control paths:

- `lib/audio.c` includes libVLC public headers and internal VLC audio headers at `_external/vlc/lib/audio.c:31` through `:39`.
- The public audio-output setter writes the `aout` variable and resets the player audio output at `_external/vlc/lib/audio.c:123` through `:133`.
- Device enumeration and device selection pass through `audio_output_t` and `aout_DevicesList` / `aout_DeviceSet` at `_external/vlc/lib/audio.c:137` through `:202`.
- Volume, stereo mode, mix mode, and delay functions similarly hold the current `audio_output_t` and call internal aout functions at `_external/vlc/lib/audio.c:249` through `:363`.

Architecture meaning: public libVLC is a stable embedding/control facade. It owns media-player-facing C API shape, but delegates audio device, filter, and playback behavior to libvlccore and modules.

## Decoded Audio Callback API

The decoded audio callback API is declared in the public media-player header and implemented by selecting the `amem` audio-output module.

Public callback contract:

- `libvlc_audio_play_cb` is documented as receiving decoded and post-processed samples asynchronously from an internal thread at `_external/vlc/include/vlc/libvlc_media_player.h:1117` through `:1130`.
- The header says sample format and channel layout are determined by `libvlc_audio_set_format()` or `libvlc_audio_set_format_callbacks()` at `_external/vlc/include/vlc/libvlc_media_player.h:1127` through `:1128`.
- The callback API explicitly overrides other audio output mechanisms and says LibVLC will not output audio in any way when callbacks are set at `_external/vlc/include/vlc/libvlc_media_player.h:1202` through `:1204`.
- Setup and cleanup callback types are declared at `_external/vlc/include/vlc/libvlc_media_player.h:1249` and `:1253`.
- Fixed-format callback output supports `S16N`, `S32N`, and `FL32`; samples are native endian and interleaved if channel count is greater than one at `_external/vlc/include/vlc/libvlc_media_player.h:1281` through `:1287`.

Implementation:

- `libvlc_audio_set_callbacks` stores `amem-play`, `amem-pause`, `amem-resume`, `amem-flush`, `amem-drain`, and `amem-data`, then sets `aout` to `amem,none` at `_external/vlc/lib/media_player.c:1364` through `:1380`.
- `libvlc_audio_set_format_callbacks` stores `amem-setup` and `amem-cleanup` at `_external/vlc/lib/media_player.c:1391` through `:1398`.
- `libvlc_audio_set_format` stores `amem-format`, `amem-rate`, and `amem-channels` at `_external/vlc/lib/media_player.c:1401` through `:1408`.

Memory output module:

- `amem.c` identifies itself as a virtual LibVLC audio output plugin at `_external/vlc/modules/audio_output/amem.c:1` through `:2`.
- Current `amem` declares allowed sample format strings and fourcc mappings for `S16N`, `S32N`, and `FL32` at `_external/vlc/modules/audio_output/amem.c:34` through `:45`.
- Current `amem` caps callback channels at `AMEM_CHAN_MAX 8` at `_external/vlc/modules/audio_output/amem.c:34`, applies the range at `_external/vlc/modules/audio_output/amem.c:67`, and rejects formats whose channel count is above that cap at `_external/vlc/modules/audio_output/amem.c:286` through `:289`.
- Current `amem` maps channel counts 1 through 8 to standard VLC physical channel layouts at `_external/vlc/modules/audio_output/amem.c:295` through `:323`.
- Current `amem` reads callback pointers from inherited variables at `_external/vlc/modules/audio_output/amem.c:340` through `:360`.

VLC 3.0 comparison:

- VLC 3.0 exposes the same callback API names in `_external/vlc-3.0/include/vlc/libvlc_media_player.h:603` through `:775`.
- VLC 3.0 sets `aout` to `amem,none` from `libvlc_audio_set_callbacks` at `_external/vlc-3.0/lib/media_player.c:1294` through `:1300`.
- VLC 3.0 `amem` ranges callback channel count from 1 through `AOUT_CHAN_MAX` at `_external/vlc-3.0/modules/audio_output/amem.c:50` through `:52`, and rejects counts above `AOUT_CHAN_MAX` at `_external/vlc-3.0/modules/audio_output/amem.c:195`.
- VLC 3.0 `amem` only accepts `S16N` in the inspected source path at `_external/vlc-3.0/modules/audio_output/amem.c:192` through `:195`; current VLC expands this to `S16N`, `S32N`, and `FL32`.

Architecture meaning: libVLC callbacks are not a separate decoder API. They are a public way to force VLC's audio-output selection to the `amem` module, causing decoded/post-processed PCM to be delivered to application callbacks instead of an OS audio device.

## Internal Audio Output Abstraction

The internal abstraction is `audio_output_t`, declared in `include/vlc_aout.h` and implemented through `src/audio_output/`.

Core shape:

- `vlc_aout.h` describes the file as the audio output modules interface at `_external/vlc/include/vlc_aout.h:39`.
- `audio_output_t` is documented as the abstraction for rendering decoded or pass-through samples, plus pause/resume, flush/drain, volume, mute, device listing, and device selection at `_external/vlc/include/vlc_aout.h:139` through `:151`.
- Mandatory or optional callbacks include `start`, `stop`, `time_get`, `play`, `pause`, `flush`, `drain`, `volume_set`, `mute_set`, and `device_select` at `_external/vlc/include/vlc_aout.h:155` through `:285`.
- `timing_report` and `drained_report` are separate event callbacks at `_external/vlc/include/vlc_aout.h:128` through `:130`.
- The comments explicitly separate `time_get` latency estimation from `play` buffer submission at `_external/vlc/include/vlc_aout.h:185` through `:213`.

Decoder-to-aout path:

- `src/audio_output/dec.c` is labeled "audio output API towards decoders" at `_external/vlc/src/audio_output/dec.c:2`.
- It creates `vlc_aout_stream` instances from decoder format and checks mapped-channel and input-channel limits at `_external/vlc/src/audio_output/dec.c:342` through `:358`.
- It builds filters through `aout_FiltersNewWithClock` during stream creation at `_external/vlc/src/audio_output/dec.c:416` through `:428`.
- It applies filters, software volume, clock delay, then calls `aout->play` at `_external/vlc/src/audio_output/dec.c:868` through `:958`.
- It handles pause, flush, and drain by calling the audio-output callbacks and filter drain paths at `_external/vlc/src/audio_output/dec.c:978` through `:1110`.

Architecture meaning: decoders do not talk directly to CoreAudio, WASAPI, ALSA, or other device APIs. Decoded audio becomes blocks sent into `vlc_aout_stream`, which applies filters/timing/volume and then hands blocks to the selected `audio_output_t` implementation.

## Platform-Specific Output Modules

Platform output modules live under `modules/audio_output/`. Current VLC includes modules for memory/file output and major platform/device APIs:

- `amem.c` is the LibVLC audio memory output and advertises audio-output capability at `_external/vlc/modules/audio_output/amem.c:53`.
- `file.c` advertises file audio output at `_external/vlc/modules/audio_output/file.c:112` through `:125`.
- macOS AUHAL output is in `_external/vlc/modules/audio_output/apple/auhal.c`; it includes CoreAudio headers at line `:35` and advertises HAL AudioUnit output at `_external/vlc/modules/audio_output/apple/auhal.c:51` through `:53`.
- Shared macOS/iOS AudioUnit logic is in `_external/vlc/modules/audio_output/apple/coreaudio_common.c`; it creates AudioUnits at `_external/vlc/modules/audio_output/apple/coreaudio_common.c:434` through `:453`, defines an AudioUnit render callback at `:464` through `:470`, sets stream format and render callback properties at `:748` through `:777`, and applies channel layout where available at `:790`.
- WASAPI output is in `_external/vlc/modules/audio_output/wasapi.c`; it uses `IAudioClient` at line `:112`, `IAudioRenderClient` at `:243`, format support checks at `:625` through `:854`, initialization at `:900`, and advertises WASAPI output at `:964` through `:968`.
- ALSA output is in `_external/vlc/modules/audio_output/alsa.c`; it opens `snd_pcm` at `:785`, negotiates formats/channels/rates around `:827` through `:886`, and advertises ALSA output at `:1197` through `:1209`.
- PulseAudio output is in `_external/vlc/modules/audio_output/pulse.c`; it advertises PulseAudio output at `:45` through `:47`, warns about PulseAudio callback locking at `:54` through `:57`, and creates playback streams around `:885`.
- PipeWire output is in `_external/vlc/modules/audio_output/pipewire.c`; it advertises PipeWire output at `:934` through `:936`.
- JACK output is in `_external/vlc/modules/audio_output/jack.c`; it advertises JACK output at `:101` through `:103`, notes JACK only supports `fl32` at `:156`, and initializes output channels and rate around `:279`.

VLC 3.0 `modules/MODULES_LIST` records the equivalent module families: `alsa` at `_external/vlc-3.0/modules/MODULES_LIST:36`, `amem` at `:37`, `auhal` at `:58`, `directsound` at `:119`, `jack` at `:213`, `mmdevice` at `:248`, `pulse` at `:319`, `wasapi` at `:464`, and `waveout` at `:467`.

Architecture meaning: device-specific negotiation is delegated to modules. The common engine and libVLC APIs can stay mostly stable while each platform output module handles its own API, latency, channel map, and buffer behavior.

## Audio Filters And Resamplers

Audio filters live under `modules/audio_filter/`, and filter pipeline construction lives under `src/audio_output/filters.c`.

Module families:

- Channel mixers are listed in current `modules/audio_filter/Makefile.am`: headphone, mono, remap, trivial, simple, and spatialaudio around `_external/vlc/modules/audio_filter/Makefile.am:87` through `:129`.
- Meson build definitions mirror this structure with remap, trivial, simple, spatialaudio, converters, and resamplers at `_external/vlc/modules/audio_filter/meson.build:161` through `:263`.
- The remap filter advertises itself as an audio channel remapper at `_external/vlc/modules/audio_filter/channel_mixer/remap.c:2`, `:76`, and `:77`.
- The trivial mixer describes itself as a channel mixer that drops unwanted channels at `_external/vlc/modules/audio_filter/channel_mixer/trivial.c:2`, advertises converter capability at `:41` through `:42`, and comments that it is the lowest-priority converter at `:212`.
- The simple mixer advertises audio converter capability at `_external/vlc/modules/audio_filter/channel_mixer/simple.c:42` through `:44`.
- The spatialaudio filter is an Ambisonics renderer/binauralizer at `_external/vlc/modules/audio_filter/channel_mixer/spatialaudio.cpp:2`, advertises audio renderer and converter capabilities at `:77` through `:87`, and includes Ambisonics and binauralizer headers at `:44` through `:48`.

Resamplers and converters:

- PCM format conversion is in `_external/vlc/modules/audio_filter/converter/format.c:2`, with audio converter capability at `:48` through `:50`.
- The "ugly" nearest-neighbor resampler advertises converter and resampler capability at `_external/vlc/modules/audio_filter/resampler/ugly.c:48` through `:54`.
- Speex resampler uses libspeexdsp and advertises converter/resampler capability at `_external/vlc/modules/audio_filter/resampler/speex.c:42` through `:52`.
- Secret Rabbit Code/libsamplerate advertises converter/resampler capability at `_external/vlc/modules/audio_filter/resampler/src.c:58` through `:68`.
- SoXR advertises quality options and converter/resampler capability at `_external/vlc/modules/audio_filter/resampler/soxr.c:70` through `:78`.

Pipeline behavior:

- `aout_FiltersNewWithClock` prepares input/output formats, creates channel type conversion if needed, handles unknown channel maps, appends remap filters from config, then adds user audio filters at `_external/vlc/src/audio_output/filters.c:545` through `:650`.
- `aout_FiltersPlay` runs the filter pipeline and resampler before output playback at `_external/vlc/src/audio_output/filters.c:787` through `:824`.
- `aout_FiltersDrain` drains filters and the resampler at `_external/vlc/src/audio_output/filters.c:824` onward.

Architecture meaning: filters are modular conversions/effects between decode and output. Output modules do not need to own remap, format conversion, time stretch, resampling, Ambisonic rendering, or user effects as one monolith.

## Channel Mapping And Reordering

VLC represents known channel layouts as physical-channel bitmaps and has a separate unmapped-channel limit.

Format facts:

- `audio_channel_type_t` has bitmap and Ambisonics variants at `_external/vlc/include/vlc_es.h:53` through `:57`.
- `audio_format_t` stores `i_physical_channels`, `i_chan_mode`, `channel_type`, and `i_channels` at `_external/vlc/include/vlc_es.h:62` through `:94`.
- `AOUT_CHAN_MAX` is 9 mapped channels; `INPUT_CHAN_MAX` is 64 unmapped channels at `_external/vlc/include/vlc_es.h:133` through `:136`.
- Standard maps include stereo, 5.1, 7.1, and 8.1 around `_external/vlc/include/vlc_es.h:112` through `:149`.

Reorder/extraction helpers:

- VLC's expected internal WG4 channel order is declared at `_external/vlc/include/vlc_aout.h:408` through `:417`.
- `aout_CheckChannelReorder` and `aout_ChannelReorder` are declared at `_external/vlc/include/vlc_aout.h:422` through `:440` and implemented at `_external/vlc/src/audio_output/common.c:251` and `:286`.
- `aout_CheckChannelExtraction` and `aout_ChannelExtract` are declared at `_external/vlc/include/vlc_aout.h:450` through `:465` and implemented at `_external/vlc/src/audio_output/common.c:415` through `:431`.
- `aout_Interleave` and `aout_Deinterleave` are declared at `_external/vlc/include/vlc_aout.h:467` through `:470` and implemented at `_external/vlc/src/audio_output/common.c:352` and `:388`.

Filter remapping:

- If the remap order differs from VLC's WG4 order, a remap audio filter is inserted according to `aout_filters_cfg_t.remap` at `_external/vlc/include/vlc_aout.h:602` through `:614`.
- `AppendRemapFilter` converts WG4 remap indexes into the remap module's order and appends the remap filter if needed at `_external/vlc/src/audio_output/filters.c:502` through `:543`.
- When an input channel map is unknown, filters use WAVE channel layout and can drop extra channels not handled by VLC at `_external/vlc/src/audio_output/filters.c:611` through `:624`.
- `aout_SetWavePhysicalChannels` maps unknown channel counts into WAVE order, but only up to `AOUT_CHAN_MAX` at `_external/vlc/src/audio_output/aout_internal.h:190` through `:202`.

Output-module reordering:

- macOS AudioUnit common output calls `aout_ChannelReorder` at `_external/vlc/modules/audio_output/apple/coreaudio_common.c:336` and `aout_CheckChannelReorder` at `:665`.
- WASAPI output calls `aout_ChannelReorder` at `_external/vlc/modules/audio_output/wasapi.c:240` and `aout_CheckChannelReorder` at `:604`.
- ALSA output calls `aout_ChannelReorder` at `_external/vlc/modules/audio_output/alsa.c:399` and negotiates channel maps around `:589` through `:868`.

Architecture meaning: channel identity is not owned by a single device backend. VLC separates source format metadata, internal channel order, filter-level remapping, and device-specific channel-order negotiation.

## Memory And Custom Output Paths

VLC has several non-device or custom boundaries:

- `amem` is the LibVLC decoded-audio memory output. It receives application callback pointers through `amem-*` variables and calls the application `play`, `pause`, `resume`, `flush`, `drain`, and volume callbacks from the audio-output abstraction.
- `file.c` is a file audio-output module, advertising "File audio output" at `_external/vlc/modules/audio_output/file.c:112` through `:125`.
- `libvlc_media_new_callbacks` is a public custom input-media boundary at `_external/vlc/include/vlc/libvlc_media.h:350` and `_external/vlc/lib/media.c:434`.

Architecture meaning: VLC has both custom input and custom output boundaries, but they are different concepts. `libvlc_media_new_callbacks` feeds bytes into VLC as media input; `libvlc_audio_set_callbacks` receives decoded/post-processed PCM after demux/decode/filtering.

## VLC Design Decisions

### Demux/decode From Output

VLC's input loop fills buffers from access and demux at `_external/vlc/src/input/input.c:494` through `:520`, while audio decoding queues decoded audio into `vlc_aout_stream_Play` at `_external/vlc/src/input/decoder.c:1629` through `:1680`. The output side then filters and submits blocks through `src/audio_output/dec.c`.

This separation lets one demux/decode pipeline serve many outputs: CoreAudio, WASAPI, ALSA, PulseAudio, PipeWire, JACK, file output, or memory callback output. It also lets VLC change output device or output policy without rewriting demuxers and decoders.

### Public libVLC From Internal libvlccore

The README says `lib/` is libVLC source code and `src/` is libvlccore source code at `_external/vlc/README.md:134` and `:138`. Public exported libVLC symbols are in `_external/vlc/lib/libvlc.sym`, while internal/core audio symbols such as `aout_ChannelReorder`, `aout_FiltersPlay`, and `aout_DeviceSet` are in `_external/vlc/src/libvlccore.sym:3` through `:30`.

This separation keeps a smaller embedding ABI around media/player/control operations while allowing libvlccore internals and modules to own playback machinery, filters, input, decoders, clocks, and platform details.

### Filters From Output Modules

Filter construction and playback are centralized in `src/audio_output/filters.c`, with user filter insertion, channel remap insertion, format conversion, and resampling handled before the selected output module's `play` callback. Output modules still negotiate device format and channel order, but they do not each reimplement the full conversion/filter/effect graph.

This keeps output modules focused on platform/device APIs and lets filters be reused across outputs.

### Channel Mapping From Platform Device Output

`audio_format_t` carries channel type, physical-channel bitmap, mode, and channel count. Shared helpers compute reorder/extraction/interleave/deinterleave, while output modules call those helpers when their platform device needs a different order. This split is visible in `include/vlc_es.h`, `include/vlc_aout.h`, `src/audio_output/common.c`, `src/audio_output/filters.c`, and platform output modules.

This allows VLC to keep one internal channel model while adapting to ALSA maps, WASAPI masks, CoreAudio layouts, and filter-level remaps.

### Timing Reports From Buffer Submission

The `audio_output_t` contract separates `time_get`, `timing_report`, and `play`. `time_get` estimates playback latency, `timing_report` sends timing events, and `play` queues sample blocks for intended render dates. This is stated in the `audio_output_t` comments at `_external/vlc/include/vlc_aout.h:185` through `:213` and in the event callbacks at `:128` through `:130`.

This separation lets VLC correct drift, manage synchronization, and report timing without making every buffer submission double as a timing query.

### GPL Application Code From LGPL Embeddable Engine

Current README states VLC is GPLv2-or-later, while libVLC is LGPLv2-or-later to allow embedding in third-party applications at `_external/vlc/README.md:22` through `:26`. `COPYING` is GPLv2 at `_external/vlc/COPYING:1` through `:18`, and `COPYING.LIB` is LGPL 2.1 at `_external/vlc/COPYING.LIB:1` through `:20`.

The design consequence is a licensing and architecture split: VLC the application can remain GPL, while libVLC is intentionally packaged as an embeddable engine with a different license boundary.

## Task 06 Conclusion

VLC's audio architecture is layered: public libVLC media/player/audio APIs in `include/vlc/` and `lib/`, internal audio output and filter orchestration in `src/audio_output/`, platform/device implementations in `modules/audio_output/`, and reusable channel/filter/resampler modules in `modules/audio_filter/`. The libVLC decoded-audio callback path is implemented by selecting the `amem` audio-output module rather than by exposing a separate decoder-only API. Current `amem` supports `S16N`, `S32N`, and `FL32` fixed formats but caps callback output at 8 channels in the inspected source.
