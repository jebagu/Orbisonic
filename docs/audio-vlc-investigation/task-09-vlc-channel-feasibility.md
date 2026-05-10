# Task 09 - VLC Channel Feasibility

## Scope

Task 9 determines whether VLC's channel model can preserve Orbisonic's custom high-channel layouts, with specific attention to 30-channel and 52-channel cases.

This is a docs-only task. No Orbisonic app code, tests, scripts, resources, installer files, vendor files, calibration files, or binary media assets were changed.

## Source Inventory

The Task 6 source map cloned the ignored current VLC research checkout under `_external/vlc`.

- Current VLC checkout: `_external/vlc`, commit `b91572e7424a472bbf80d3ad5025fc20ca3fbd1d`.

Current VLC files inspected:

- `include/vlc_es.h`
- `include/vlc_aout.h`
- `src/audio_output/aout_internal.h`
- `src/audio_output/common.c`
- `src/audio_output/dec.c`
- `src/audio_output/filters.c`
- `src/audio_output/output.c`
- `modules/audio_output/amem.c`
- `modules/audio_filter/channel_mixer/remap.c`
- `modules/audio_filter/channel_mixer/simple.c`
- `modules/audio_filter/channel_mixer/trivial.c`
- `modules/audio_filter/channel_mixer/spatialaudio.cpp`
- `modules/audio_filter/resampler/src.c`
- `modules/audio_filter/resampler/soxr.c`
- `modules/audio_filter/resampler/speex.c`
- `modules/audio_filter/resampler/ugly.c`
- `modules/codec/araw.c`
- `modules/codec/avcodec/audio.c`
- `modules/codec/faad.c`
- `modules/codec/flac.c`
- `modules/codec/opus.c`
- `modules/codec/vorbis.c`
- `modules/demux/mp4/coreaudio.h`
- `modules/demux/mp4/essetup.c`
- `modules/demux/mkv/matroska_segment_parse.cpp`
- `modules/demux/ogg.c`
- `modules/demux/voc.c`
- `modules/demux/wav.c`

## Evidence Commands

- `git status --short`
- `sed -n '593,680p' orbisonic_vlc_codex_prompt_sequence.md`
- `rg -n "AOUT_CHAN_MAX|INPUT_CHAN_MAX|i_channels|i_physical_channels|channel_type|AMBISONIC|AMBISONICS|Ambisonic|ambisonic|WG4|aout_CheckChannelReorder|aout_ChannelReorder|aout_CheckChannelExtraction|aout_ChannelExtract|remap|channel_mixer|downmix|binaural|spatial" _external/vlc`
- `awk 'NR>=48&&NR<=80 {printf "%5d %s\n", NR, $0}' _external/vlc/include/vlc_es.h`
- `awk 'NR>=86&&NR<=102 {printf "%5d %s\n", NR, $0}' _external/vlc/include/vlc_es.h`
- `awk 'NR>=128&&NR<=152 {printf "%5d %s\n", NR, $0}' _external/vlc/include/vlc_es.h`
- `awk 'NR>=405&&NR<=425 {printf "%5d %s\n", NR, $0}' _external/vlc/include/vlc_aout.h`
- `awk 'NR>=185&&NR<=205 {printf "%5d %s\n", NR, $0}' _external/vlc/src/audio_output/aout_internal.h`
- `awk 'NR>=86&&NR<=106 {printf "%5d %s\n", NR, $0}' _external/vlc/src/audio_output/common.c`
- `awk 'NR>=245&&NR<=330 {printf "%5d %s\n", NR, $0}' _external/vlc/src/audio_output/common.c`
- `awk 'NR>=415&&NR<=506 {printf "%5d %s\n", NR, $0}' _external/vlc/src/audio_output/common.c`
- `awk 'NR>=340&&NR<=364 {printf "%5d %s\n", NR, $0}' _external/vlc/src/audio_output/dec.c`
- `awk 'NR>=493&&NR<=543 {printf "%5d %s\n", NR, $0}' _external/vlc/src/audio_output/filters.c`
- `awk 'NR>=545&&NR<=688 {printf "%5d %s\n", NR, $0}' _external/vlc/src/audio_output/filters.c`
- `awk 'NR>=594&&NR<=731 {printf "%5d %s\n", NR, $0}' _external/vlc/src/audio_output/output.c`
- `awk 'NR>=28&&NR<=72 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/audio_output/amem.c`
- `awk 'NR>=278&&NR<=330 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/audio_output/amem.c`
- `awk 'NR>=36&&NR<=154 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/audio_filter/channel_mixer/remap.c`
- `awk 'NR>=275&&NR<=364 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/audio_filter/channel_mixer/remap.c`
- `awk 'NR>=47&&NR<=123 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/audio_filter/channel_mixer/simple.c`
- `awk 'NR>=274&&NR<=345 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/audio_filter/channel_mixer/simple.c`
- `awk 'NR>=180&&NR<=270 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/audio_filter/channel_mixer/trivial.c`
- `awk 'NR>=88&&NR<=555 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/audio_filter/channel_mixer/spatialaudio.cpp`
- `awk 'NR>=74&&NR<=102 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/audio_filter/resampler/src.c`
- `awk 'NR>=121&&NR<=178 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/audio_filter/resampler/soxr.c`
- `awk 'NR>=102&&NR<=146 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/audio_filter/resampler/speex.c`
- `awk 'NR>=74&&NR<=116 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/audio_filter/resampler/ugly.c`
- `awk 'NR>=232&&NR<=286 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/codec/araw.c`
- `awk 'NR>=420&&NR<=715 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/codec/avcodec/audio.c`
- `awk 'NR>=412&&NR<=575 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/codec/faad.c`
- `awk 'NR>=74&&NR<=102 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/codec/flac.c`
- `awk 'NR>=180&&NR<=220 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/codec/flac.c`
- `awk 'NR>=320&&NR<=380 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/codec/flac.c`
- `awk 'NR>=228&&NR<=255 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/codec/opus.c`
- `awk 'NR>=466&&NR<=482 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/codec/opus.c`
- `awk 'NR>=96&&NR<=116 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/codec/vorbis.c`
- `awk 'NR>=360&&NR<=386 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/codec/vorbis.c`
- `awk 'NR>=285&&NR<=306 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/demux/mp4/coreaudio.h`
- `awk 'NR>=488&&NR<=506 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/demux/mp4/coreaudio.h`
- `awk 'NR>=1258&&NR<=1301 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/demux/mp4/essetup.c`
- `awk 'NR>=1360&&NR<=1378 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/demux/mp4/essetup.c`
- `awk 'NR>=1968&&NR<=2002 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/demux/mkv/matroska_segment_parse.cpp`
- `awk 'NR>=190&&NR<=224 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/demux/ogg.c`
- `awk 'NR>=2930&&NR<=2950 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/demux/ogg.c`
- `awk 'NR>=306&&NR<=315 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/demux/voc.c`
- `awk 'NR>=401&&NR<=410 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/demux/voc.c`
- `awk 'NR>=38&&NR<=46 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/demux/wav.c`
- `awk 'NR>=230&&NR<=245 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/demux/wav.c`
- `awk 'NR>=380&&NR<=508 {printf "%5d %s\n", NR, $0}' _external/vlc/modules/demux/wav.c`

## Direct Answers

### 1. What is VLC's maximum number of mapped speaker channels?

VLC's mapped speaker model is capped at 9 channels. `AOUT_CHAN_MAX` is documented as the maximum number of mapped channels, or maximum number of set bits in `i_physical_channels`, and is defined as 9 at `_external/vlc/include/vlc_es.h:132` through `:136`.

The built-in `vlc_chan_maps` table maps channel counts 0 through 9 and stops at `AOUT_CHANS_8_1` at `_external/vlc/include/vlc_es.h:138` through `:149`. The named mapped channels are the standard VLC bitmap positions, not Orbisonic custom speaker ports.

### 2. What is VLC's maximum number of unmapped input channels?

VLC's generic unmapped input ceiling is 64 channels. `INPUT_CHAN_MAX` is defined as 64 at `_external/vlc/include/vlc_es.h:132` through `:136`.

The stream constructor accepts either a valid mapped channel layout or a valid unmapped channel count, and rejects `i_channels > INPUT_CHAN_MAX` at `_external/vlc/src/audio_output/dec.c:350` through `:360`. This means 30 and 52 unmapped channels can pass that specific validation, but that is not proof that the full playback, callback, filter, or OS-output path preserves them.

### 3. Is there any separate limit on `i_channels`, decoded channels, or output channels?

Yes. `audio_format_t.i_channels` is a `uint8_t` with a comment saying it "must be <=32" at `_external/vlc/include/vlc_es.h:91` through `:95`, while the current generic runtime constant says `INPUT_CHAN_MAX` is 64. Current code uses the 64-channel constant in multiple runtime checks, so the comment is a warning about legacy expectations rather than sufficient proof of the current effective limit.

Decoded-channel and demuxer limits are format-specific:

- Raw audio accepts input channel counts from 1 through `INPUT_CHAN_MAX` at `_external/vlc/modules/codec/araw.c:239` through `:245`, then leaves channel maps unknown for counts outside `vlc_chan_maps` at `_external/vlc/modules/codec/araw.c:267` through `:282`.
- FFmpeg audio decode rejects decoded frames with `channels > INPUT_CHAN_MAX` at `_external/vlc/modules/codec/avcodec/audio.c:420` through `:432`.
- AAC/FAAD rejects frames with 0 channels or `frame.channels >= 64` at `_external/vlc/modules/codec/faad.c:418` through `:424`.
- WAV PCM has a stricter `WAV_CHAN_MAX 32` and rejects PCM frame info above that at `_external/vlc/modules/demux/wav.c:42` through `:43` and `_external/vlc/modules/demux/wav.c:235` through `:243`.
- FLAC uses `FLAC__MAX_CHANNELS`, maps only the FLAC-supported channel table, and rejects counts above that at `_external/vlc/modules/codec/flac.c:79` through `:100` and `_external/vlc/modules/codec/flac.c:200` through `:214`.
- Vorbis has a `pi_channels_maps[9]` table and rejects decoded counts at or above that array size at `_external/vlc/modules/codec/vorbis.c:96` through `:116` and `_external/vlc/modules/codec/vorbis.c:377` through `:386`.
- Ogg Opus maps RFC stereo only through 2 channels, Vorbis mapping through 8, and marks mapping families 2 and 3 as Ambisonics at `_external/vlc/modules/demux/ogg.c:2930` through `:2948`.

Output-channel limits are path-specific:

- Mapped VLC audio output is 9 channels.
- LibVLC `amem` callback output is capped at 8 channels by `AMEM_CHAN_MAX` at `_external/vlc/modules/audio_output/amem.c:33` through `:68`, and rejects higher counts at `_external/vlc/modules/audio_output/amem.c:284` through `:292`.
- The audio output setup converts unknown channel maps to WAVE physical channels, which are capped at the first 9 mapped positions, at `_external/vlc/src/audio_output/output.c:717` through `:723` and `_external/vlc/src/audio_output/aout_internal.h:190` through `:200`.

### 4. What does VLC mean by `i_physical_channels`?

`i_physical_channels` is VLC's bitmap channel configuration for samples. The struct comment says it describes "the channels configuration of the samples," including the number of channels available in the buffer and their positions, at `_external/vlc/include/vlc_es.h:67` through `:69`.

When the bitmap is nonzero, `aout_FormatPrepare` derives `i_channels` from `aout_FormatNbChannels` at `_external/vlc/src/audio_output/common.c:87` through `:100`. In other words, `i_physical_channels` is not an arbitrary channel count; it is a standard-speaker bitmap whose bit count becomes the effective channel count for mapped formats.

### 5. What does VLC mean by `channel_type`?

`channel_type` distinguishes bitmap speaker-channel audio from Ambisonics. The enum has exactly `AUDIO_CHANNEL_TYPE_BITMAP` and `AUDIO_CHANNEL_TYPE_AMBISONICS` at `_external/vlc/include/vlc_es.h:50` through `:57`, and `audio_format_t` stores that type at `_external/vlc/include/vlc_es.h:76` through `:77`.

The filter chain asserts the output channel type is bitmap, and if input and output channel types differ it tries an audio-renderer pipeline before normal filters because standard converters and filters handle only bitmap channel types. That behavior is at `_external/vlc/src/audio_output/filters.c:589` through `:607`.

### 6. What does VLC do with Ambisonics?

VLC can label Ambisonics at demux or codec boundaries, then render it into a conventional bitmap speaker layout or binaural stereo.

Evidence:

- Ogg Opus mapping families 2 and 3 set `AUDIO_CHANNEL_TYPE_AMBISONICS` at `_external/vlc/modules/demux/ogg.c:2934` through `:2948`.
- MP4 samples with `SA3D` set `AUDIO_CHANNEL_TYPE_AMBISONICS` at `_external/vlc/modules/demux/mp4/essetup.c:1369` through `:1372`.
- The Opus decoder marks channel mappings greater than or equal to 2 as Ambisonics at `_external/vlc/modules/codec/opus.c:466` through `:478`.
- Audio output sets Ambisonics content to a maximum 7.1 render target before backend negotiation at `_external/vlc/src/audio_output/output.c:725` through `:731`.
- The `spatialaudio` renderer supports Ambisonics order 1 through 3 only, rejecting input channel counts below 4 or above `(AMB_MAX_ORDER + 1)^2 + 2`, which is 18, at `_external/vlc/modules/audio_filter/channel_mixer/spatialaudio.cpp:94` and `_external/vlc/modules/audio_filter/channel_mixer/spatialaudio.cpp:427` through `:446`.
- `spatialaudio` derives order and optional nondiegetic channels, permits only 0 or 2 nondiegetic channels, and renders either binaural stereo or a bitmap speaker set at `_external/vlc/modules/audio_filter/channel_mixer/spatialaudio.cpp:471` through `:555`.

Ambisonics is therefore not a general custom 30-channel or 52-channel speaker bus in VLC.

### 7. What channel order does VLC consider canonical?

VLC's internal canonical order is WG4. `pi_vlc_chan_order_wg4` is left, right, middle-left, middle-right, rear-left, rear-right, rear-center, center, LFE, then zero terminator at `_external/vlc/include/vlc_aout.h:405` through `:414`.

The reorder API says that if either input or output order is `NULL`, VLC assumes the internal WG4 order at `_external/vlc/include/vlc_aout.h:416` through `:423`.

### 8. Where does VLC reorder channels?

The generic reorder functions are `aout_CheckChannelReorder` and `aout_ChannelReorder` in `src/audio_output/common.c`. `aout_CheckChannelReorder` computes a table against input and output channel orders, defaulting to WG4 when either side is null, at `_external/vlc/src/audio_output/common.c:250` through `:284`. `aout_ChannelReorder` applies that table at `_external/vlc/src/audio_output/common.c:286` through `:330`.

Demuxers and codecs call those helpers when they understand a mapped layout:

- WAV extensible computes reorder tables for recognized masks at `_external/vlc/modules/demux/wav.c:494` through `:507`.
- Matroska/WAVEFORMATEXTENSIBLE computes reorder tables at `_external/vlc/modules/demux/mkv/matroska_segment_parse.cpp:1970` through `:1997`.
- MP4 `chan` boxes use CoreAudio-to-VLC mapping and call `aout_CheckChannelReorder` for uncompressed audio at `_external/vlc/modules/demux/mp4/essetup.c:1266` through `:1296`.
- Opus mappings through 8 channels reorder against standard maps at `_external/vlc/modules/codec/opus.c:228` through `:255`.
- FLAC WAVEFORMATEXTENSIBLE comments can compute a new mapped order when the channel count is within `AOUT_CHAN_MAX` at `_external/vlc/modules/codec/flac.c:336` through `:375`.

### 9. Where does VLC extract channels?

The generic extraction helpers are `aout_CheckChannelExtraction` and `aout_ChannelExtract`. `aout_ChannelExtract` copies selected channels into a separate destination buffer at `_external/vlc/src/audio_output/common.c:415` through `:447`. `aout_CheckChannelExtraction` ignores unknown, duplicated, or unsupported channels, limits selection to the mapped WG4 destination order, and returns true when extraction or dropping is needed at `_external/vlc/src/audio_output/common.c:449` through `:506`.

The FFmpeg decoder uses extraction with an explicit "TODO: do not drop channels... at least not here" comment at `_external/vlc/modules/codec/avcodec/audio.c:548` through `:563`. The trivial channel mixer also switches unmapped input into extraction mode and logs that channels above `AOUT_CHAN_MAX` will be dropped at `_external/vlc/modules/audio_filter/channel_mixer/trivial.c:187` through `:204`.

### 10. Where does VLC downmix?

Downmix decisions appear in both output configuration and channel-mixer modules.

- `aout_SetupMixModeChoices` only offers Original, Stereo, Binaural, 4.0, 5.1, and 7.1 choices for multichannel output at `_external/vlc/src/audio_output/output.c:594` through `:643`.
- `aout_UpdateMixMode` mutates the output physical layout to stereo, binaural, 4.0, 5.1, or 7.1 at `_external/vlc/src/audio_output/output.c:665` through `:696`.
- `channel_mixer/simple.c` contains explicit downmix workers such as 7.x to 2.0, 6.1 to 2.0, 5.x to 2.0, 4.0 to 2.0, and 3.x to 2.0 at `_external/vlc/modules/audio_filter/channel_mixer/simple.c:50` through `:123`.
- `channel_mixer/simple.c` selects those workers only for known mapped inputs and known mapped outputs, and explicitly notes unsupported 8.1, 6.x, and some 4.0 inputs at `_external/vlc/modules/audio_filter/channel_mixer/simple.c:274` through `:345`.
- `channel_mixer/trivial.c` drops or extracts channels for unmapped input when the requested output does not match the input count at `_external/vlc/modules/audio_filter/channel_mixer/trivial.c:187` through `:204`.
- `spatialaudio.cpp` renders Ambisonics to binaural stereo or a mapped speaker set at `_external/vlc/modules/audio_filter/channel_mixer/spatialaudio.cpp:483` through `:555`.

### 11. Where does VLC resample?

The audio filter chain inserts the resampler after channel conversion. `aout_FiltersNewWithClock` builds the filter pipeline, then sets `output_format.i_rate` to the final output rate, calls `FindResampler`, and errors if a resampler is required but unavailable at `_external/vlc/src/audio_output/filters.c:664` through `:687`.

The resampler modules do not perform channel remapping:

- The libsamplerate module runs only when rates differ and requires identical input/output channel counts at `_external/vlc/modules/audio_filter/resampler/src.c:74` through `:102`.
- The SoXR module says "Cannot remix" and rejects unequal channel counts at `_external/vlc/modules/audio_filter/resampler/soxr.c:121` through `:127`, then creates SoXR with the input channel count at `_external/vlc/modules/audio_filter/resampler/soxr.c:148` through `:160`.
- The Speex module runs on interleaved audio after rate changes, using the output bytes-per-frame at `_external/vlc/modules/audio_filter/resampler/speex.c:102` through `:146`.
- The ugly resampler requires identical formats and identical channel counts, then computes frame size from the channel count at `_external/vlc/modules/audio_filter/resampler/ugly.c:74` through `:116`.

### 12. Which code paths would reject, truncate, downmix, reorder, or reinterpret 30 channels?

For 30 channels, the answer depends on whether the source is mapped, unmapped, callback output, Ambisonics, or a specific codec/container.

- Mapped 30-channel VLC speaker layouts are rejected by the generic audio-output stream validation because mapped channels above `AOUT_CHAN_MAX` are invalid at `_external/vlc/src/audio_output/dec.c:350` through `:360`.
- Unmapped 30-channel raw or FFmpeg-decoded audio can pass the generic `INPUT_CHAN_MAX` validation, as shown by raw audio at `_external/vlc/modules/codec/araw.c:239` through `:245` and FFmpeg decode at `_external/vlc/modules/codec/avcodec/audio.c:420` through `:432`.
- Unmapped 30-channel audio is not preserved by the normal output filter setup when VLC needs a bitmap layout. Unknown channel maps are converted to WAVE physical channels and the comment says the converter will "drop extra channels that are not handled by VLC" at `_external/vlc/src/audio_output/filters.c:609` through `:629`; the WAVE physical-channel helper keeps only the first 9 positions at `_external/vlc/src/audio_output/aout_internal.h:190` through `:200`; the trivial channel mixer logs and drops channels above `AOUT_CHAN_MAX` at `_external/vlc/modules/audio_filter/channel_mixer/trivial.c:187` through `:204`.
- WAV PCM can describe 30 channels because it is below `WAV_CHAN_MAX 32`, but a WAVE_EXTENSIBLE or default physical channel mask cannot represent 30 VLC mapped positions. WAV fills a default mask only when channels are `<= AOUT_CHAN_MAX` at `_external/vlc/modules/demux/wav.c:473` through `:491`.
- LibVLC callback output through `amem` rejects 30 channels because `AMEM_CHAN_MAX` is 8 and the open path rejects higher counts at `_external/vlc/modules/audio_output/amem.c:33` through `:68` and `_external/vlc/modules/audio_output/amem.c:284` through `:292`.
- Ambisonic 30-channel content is rejected by the `spatialaudio` renderer because its Ambisonics input cap is 18 channels at `_external/vlc/modules/audio_filter/channel_mixer/spatialaudio.cpp:427` through `:446`.
- Format-specific demuxers/codecs can reject 30 channels earlier. Vorbis and FLAC are below this range; WAV permits 30 PCM frames but not 52; Ogg Opus marks Ambisonic mapping families instead of exposing a 30-channel custom bitmap at `_external/vlc/modules/demux/ogg.c:2930` through `:2948`.

### 13. Which code paths would reject, truncate, downmix, reorder, or reinterpret 52 channels?

For 52 channels, generic unmapped raw or FFmpeg decode can pass some initial limits, but the inspected end-to-end paths still do not prove preservation.

- Mapped 52-channel VLC speaker layouts are rejected by the same `AOUT_CHAN_MAX` validation at `_external/vlc/src/audio_output/dec.c:350` through `:360`.
- Unmapped 52-channel raw or FFmpeg-decoded audio can pass the `INPUT_CHAN_MAX` limit because 52 is below 64, based on `_external/vlc/modules/codec/araw.c:239` through `:245` and `_external/vlc/modules/codec/avcodec/audio.c:420` through `:432`.
- WAV PCM rejects 52 channels because `WAV_CHAN_MAX` is 32 at `_external/vlc/modules/demux/wav.c:42` through `:43`, and PCM frame info rejects `i_channels > WAV_CHAN_MAX` at `_external/vlc/modules/demux/wav.c:235` through `:243`.
- Unmapped 52-channel audio falls into the same unknown-map conversion and drop path as 30 channels when VLC needs bitmap output: `_external/vlc/src/audio_output/filters.c:609` through `:629`, `_external/vlc/src/audio_output/aout_internal.h:190` through `:200`, and `_external/vlc/modules/audio_filter/channel_mixer/trivial.c:187` through `:204`.
- LibVLC callback output through `amem` rejects 52 channels because the callback output cap is 8 at `_external/vlc/modules/audio_output/amem.c:33` through `:68` and `_external/vlc/modules/audio_output/amem.c:284` through `:292`.
- Ambisonic 52-channel content is rejected by `spatialaudio` because the Ambisonics input cap is 18 channels at `_external/vlc/modules/audio_filter/channel_mixer/spatialaudio.cpp:427` through `:446`.
- MP4 CoreAudio channel bitmap mapping rejects unsupported numbers of mapped channels once the mapping reaches `AOUT_CHAN_MAX` at `_external/vlc/modules/demux/mp4/coreaudio.h:285` through `:306`, and MP4 `chan` handling only sets VLC physical channels for VLC-mapped or remapped PCM audio at `_external/vlc/modules/demux/mp4/essetup.c:1266` through `:1296`.

## Layer Separation

The inspected VLC code separates these layers:

- A source stream can contain N channels if its container and codec permit that N.
- A demuxer can describe N channels, but may also cap or reinterpret them based on container-specific maps.
- A decoder can produce N channels, but may cap them by codec-specific constraints or `INPUT_CHAN_MAX`.
- A libVLC callback output path can deliver only up to the callback backend's configured output cap; stock `amem` is 8 channels.
- VLC filters can process known mapped layouts and some unmapped counts, but unknown maps are forced into a 9-channel WAVE-style bitmap when a mapped output is needed.
- VLC's mapped speaker layout can represent at most 9 standard bitmap speaker positions.
- An OS audio backend can render only what the selected VLC backend, format negotiation, and device expose; this task did not prove 30 or 52 physical output ports through a VLC backend.
- Target hardware can expose N physical outputs independently of VLC's internal speaker bitmap, but VLC's inspected mapped channel model does not represent Orbisonic's 30 or 52 custom speaker identities.

## Preliminary 30/52 Go/No-Go

- 30 channels are not proven yet because no inspected VLC path preserves a 30-channel Orbisonic custom layout from source stream through demux, decode, callback or output filtering, mapped speaker layout, OS backend, and target hardware without falling into unmapped-layout or backend-specific proof gaps.
- 30 channels are blocked by exact code path `_external/vlc/src/audio_output/dec.c:350` through `:360` because mapped speaker layouts above `AOUT_CHAN_MAX` are invalid.
- 30 channels are blocked by exact code path `_external/vlc/modules/audio_output/amem.c:33` through `:68` and `_external/vlc/modules/audio_output/amem.c:284` through `:292` because stock libVLC callback output above 8 channels is rejected.
- 30 channels are blocked by exact code path `_external/vlc/src/audio_output/filters.c:609` through `:629`, `_external/vlc/src/audio_output/aout_internal.h:190` through `:200`, and `_external/vlc/modules/audio_filter/channel_mixer/trivial.c:187` through `:204` because unknown maps are converted to a WAVE physical layout capped at the first 9 channels and extra channels are dropped.
- 30 channels are blocked by exact code path `_external/vlc/modules/audio_filter/channel_mixer/spatialaudio.cpp:427` through `:446` because Ambisonics input above 18 channels is rejected.
- 52 channels are not proven yet because no inspected VLC path preserves a 52-channel Orbisonic custom layout from source stream through demux, decode, callback or output filtering, mapped speaker layout, OS backend, and target hardware without falling into unmapped-layout or backend-specific proof gaps.
- 52 channels are blocked by exact code path `_external/vlc/src/audio_output/dec.c:350` through `:360` because mapped speaker layouts above `AOUT_CHAN_MAX` are invalid.
- 52 channels are blocked by exact code path `_external/vlc/modules/demux/wav.c:42` through `:43` and `_external/vlc/modules/demux/wav.c:235` through `:243` because WAV PCM channel counts above 32 are rejected.
- 52 channels are blocked by exact code path `_external/vlc/modules/audio_output/amem.c:33` through `:68` and `_external/vlc/modules/audio_output/amem.c:284` through `:292` because stock libVLC callback output above 8 channels is rejected.
- 52 channels are blocked by exact code path `_external/vlc/src/audio_output/filters.c:609` through `:629`, `_external/vlc/src/audio_output/aout_internal.h:190` through `:200`, and `_external/vlc/modules/audio_filter/channel_mixer/trivial.c:187` through `:204` because unknown maps are converted to a WAVE physical layout capped at the first 9 channels and extra channels are dropped.
- 52 channels are blocked by exact code path `_external/vlc/modules/audio_filter/channel_mixer/spatialaudio.cpp:427` through `:446` because Ambisonics input above 18 channels is rejected.

## Conclusion

VLC's channel model is useful as evidence for a disciplined separation between decoded channel count, channel-map metadata, filter conversion, resampling, and device output negotiation. It is not evidence that stock VLC or stock libVLC can preserve Orbisonic's custom 30-channel or 52-channel layouts end to end.

For Orbisonic, the practical lesson is to avoid treating VLC's 9-channel bitmap layout as a Sonic Sphere layout. Any VLC-inspired decode bridge would need an explicit high-channel PCM contract outside VLC's normal mapped-speaker model, and the inspected stock `amem` callback path does not provide that contract.
