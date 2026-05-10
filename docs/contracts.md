# Orbisonic Contracts

## Contract Rules

- Contracts are binding unless explicitly revised.
- Codex must not silently change public interfaces.
- If implementation requires a contract change, stop and document the proposed change.
- Every module should have tests matching its contract.
- Modules should avoid reaching across boundaries.
- Audio-path correctness outranks UI convenience.
- Current source, tests, README, AGENTS.md, Package.swift, and project-control docs are the source of truth for this baseline.
- Hardware-only behavior must be documented as manual verification when it cannot run in automated tests.
- Silent live input must remain diagnosable. Do not hide it with synthetic signal, gain, buffering tricks, fake channels, or fallback routing.
- Local file playback and live loopback capture are separate paths.
- Roon, Spotify, Atmos DRP, Aux, local file playback, and test tones remain selected-source paths, not an implicit mixer.
- Sonic Sphere 30.1 is the primary production output topology unless a future accepted contract changes it.
- Headphone or normal monitor output is a monitor path and must not mutate Sonic Sphere production topology.
- Orbisonic renders channel beds or discrete channels exposed by Core Audio or upstream tools. It does not decode Dolby Atmos object metadata unless a future implementation explicitly adds and documents that capability.

## 1. AudioContracts

Responsibility:
Define shared audio vocabulary and validation value types for the rest of the package.

Non-responsibilities:
It must not own Core Audio device behavior, AVAudioEngine graph behavior, SwiftUI state, Roon behavior, Spotify behavior, filesystem implementation details, live capture, app logging, app resources, or installer behavior.

Public interface or public-facing concepts:
`AudioSampleRate`, `ProcessingFormat`, `AudioChannelRole`, `AudioChannelLayoutDescriptor`, `SourceKind`, `SourceDescriptor`, `DanteOutputFormat`, `DesktopOutputFormat`, `AudioSessionFormat`, `OutputRouteRisk`, `OutputRouteDescriptor`, `DanteRouteCapability`, `RenderMode`, `DesktopMonitorMode`, Apple spatial headphone value types, `ChannelMeter`, `MeterSnapshot`, `ConversionLedger`, `ManagedAssetDescriptor`, `AssetReadiness`, and `AudioError`.

Inputs:
Primitive values and value objects such as sample rates, channel counts, channel roles, source descriptors, route descriptors, conversion facts, and monitor capability facts.

Outputs:
Validated value objects, typed errors, status values, and immutable descriptors consumed by `AudioImport`, `AudioCore`, and `Orbisonic`.

Data models:
Pure Swift value types that are `Equatable`, `Hashable`, `Sendable`, or `Codable` where the current source requires it.

Errors:
`AudioError` and validation failures for invalid sample rates, invalid source descriptors, sample-rate mismatch, insufficient output channels, invalid render graph plans, route failures, and related shared conditions.

Side effects allowed:
None beyond deterministic value construction and validation.

Side effects forbidden:
Filesystem reads or writes, logging, network calls, Core Audio device calls, AVAudioEngine graph mutation, UI mutation, process launches, and installer/script actions.

Allowed dependencies:
Swift standard library and Foundation-level value support already present in the source.

Forbidden dependencies:
SwiftUI, AppKit, AVFoundation, AVFAudio, CoreAudio device management, Roon, Spotify, app target types, file loaders, live capture bridges, renderer runtime classes, and installer scripts.

Security or privacy constraints:
Must not store personal paths, device-specific secrets, tokens, logs, or machine-specific runtime details.

Performance or audio-stability constraints:
Validation must be deterministic and cheap enough for planning and tests. It must not allocate or touch realtime audio buffers.

Tests required:
`Tests/AudioContractsTests/AudioContractsTests.swift` must cover sample-rate validation, 31-channel Dante eligibility, session format validation, layout fallback, source-channel ceiling, meter snapshot value semantics, conversion-ledger invalidation, and forbidden imports.

Acceptance criteria:
The target remains a shared vocabulary layer. It compiles without app/UI/audio-device implementation imports, preserves the 64-channel source cap and production sample-rate rules, and exposes typed failures rather than hidden policy decisions.

## 2. AudioImport

Responsibility:
Classify and prepare local audio assets for production use, including readiness decisions and managed import/conversion ledger facts.

Non-responsibilities:
It must not mutate live render graphs, start or stop audio sessions, own live loopback capture, control Roon or Spotify, select Core Audio devices, manage SwiftUI state, or silently perform production realtime conversion policy.

Public interface or public-facing concepts:
`LocalAssetProbeResult`, `ProductionLocalAssetGate`, and `ManagedAssetImporter`.

Inputs:
Local asset probe facts, declared sample rate, channel layout and count, estimated decoded size, target `AudioSessionFormat`, route capabilities, and import requests.

Outputs:
Production readiness, managed asset descriptors, conversion ledgers, and errors describing why an asset is not production-ready.

Data models:
Local asset probe result, managed asset descriptor, asset readiness, conversion ledger, and audio contract descriptors.

Errors:
Invalid local asset facts, sample-rate mismatch, unsupported production conversion, managed import failure, and filesystem or AVFoundation errors surfaced rather than hidden.

Side effects allowed:
Read local source assets and write managed imported assets only when an explicit import path is used.

Side effects forbidden:
Live graph mutation, route mutation, live input capture, online lookup, metadata scraping outside the requested local asset operation, Roon/Spotify/Aux control, and UI mutation.

Allowed dependencies:
`AudioContracts`, AVFoundation, and Foundation.

Forbidden dependencies:
SwiftUI, app view model types, `OrbisonicEngine`, `LiveAudioBridge`, Roon bridge/client types, Spotify receiver types, Core Audio output route repair, installer scripts, and web server state.

Security or privacy constraints:
Docs and tests must avoid personal absolute paths. Runtime imports should use app-managed or user-selected paths without committing them to tracked files.

Performance or audio-stability constraints:
Managed import may be offline work. It must not introduce hidden realtime sample-rate conversion into production rendering.

Tests required:
`Tests/AudioImportTests/LocalAssetImportTests.swift` must cover production-ready 48 kHz assets, mismatched sample-rate policy, stopped-session restart decisions, unsupported high-rate DVS production sessions, hidden production SRC rejection, managed CAF import, conversion ledger records, and layout preservation.

Acceptance criteria:
Local assets are admitted, rejected, or prepared explicitly. Any conversion is documented in a ledger. Realtime production conversion policy is not hidden inside import.

## 3. AudioCore

Responsibility:
Own deterministic audio planning, source adapters, render graph plans, render kernels, output adapters, metering telemetry, command/telemetry shell behavior, and Apple spatial headphone monitor value/status logic.

Non-responsibilities:
It must not own SwiftUI state, app window state, local playlist UI, Roon log parsing, Node helper lifecycle, Spotify FFI process control, concrete Core Audio route discovery in the app target, installer behavior, or app bundle refresh behavior.

Public interface or public-facing concepts:
`AudioControl`, `AudioCoreShell`, `AudioCommandQueue`, `AudioTelemetry`, `AudioSessionPlanner`, `SourceAdapterFactory`, `RenderGraphPlanner`, `PlanValidator`, `MatrixRenderKernel`, `DesktopMonitorRenderer`, `DanteSonicSphereRenderer`, `DualOutputRenderCoordinator`, `PureAudioMeteringService`, and `AppleSpatialHeadphoneMonitor`.

Inputs:
Source descriptors, route descriptors, live input route descriptors, session formats, render-mode choices, gain changes, route capability data, canonical audio blocks, and command values.

Outputs:
Session plans, source adapter statuses, immutable render graph plans, deterministic rendered blocks, output status snapshots, meter snapshots, stop/rebuild decisions, and typed errors.

Data models:
Audio contracts, source selections, linear gain, route snapshots, graph audit snapshots, session plans, source adapter statuses, render graph plans, canonical audio blocks, meter copied blocks, and Apple spatial headphone status values.

Errors:
`AudioError`, invalid gain, invalid source/session/route/render graph, source sample-rate mismatch, route sample-rate mismatch, insufficient channels, route unavailable, underrun, and typed graph validation failures.

Side effects allowed:
Deterministic in-memory planning, offline rendering, queue serialization, status publication, and testable buffer operations.

Side effects forbidden:
SwiftUI mutation, app UI mutation, direct user file selection, Roon/Spotify service control, installer actions, writing app logs from core planning, hidden live capture, and direct ownership of app-level Core Audio route discovery.

Allowed dependencies:
`AudioContracts`, `AudioImport`, Foundation, and AVFAudio only inside the current Apple spatial headphone monitor boundary.

Forbidden dependencies:
SwiftUI, AppKit, app executable types, `OrbisonicViewModel`, `OrbisonicEngine`, `LiveAudioBridge`, Roon/Spotify concrete clients, `OutputRouteMonitor`, app web server, and installer scripts.

Security or privacy constraints:
Core state must be value-oriented and must not expose private buffers, personal paths, tokens, or local log content.

Performance or audio-stability constraints:
Planning and render kernels must be deterministic. Metering must not mutate audible output. Sample-rate and channel-count mismatch must be surfaced before processing where possible. Realtime-adjacent paths must avoid blocking or unbounded allocation.

Tests required:
`Tests/AudioCoreTests/` must cover command API boundaries, session planning, route validation, source adapters, render graph immutability, render kernels, output adapters, metering telemetry, Apple spatial headphone monitor boundaries, and forbidden UI/import leakage.

Acceptance criteria:
`AudioCore` remains independent of SwiftUI/app UI state, exposes typed value and status surfaces, rejects unsafe plans, and keeps monitor, meter, desktop, and Dante/Sonic Sphere production paths separable.

## 4. Orbisonic Executable App Shell

Responsibility:
Own the native macOS app entrypoint, SwiftUI shell, user-facing state, app resources, app-level orchestration, diagnostics UI, web surface, and concrete platform integrations.

Non-responsibilities:
It must not redefine shared contracts that belong in `AudioContracts`, silently override `AudioImport` production policy, hide `AudioCore` validation failures, or treat archived/prototype workspaces as active product source.

Public interface or public-facing concepts:
`OrbisonicApp`, `ContentView`, `DiagnosticsView`, `OrbisonicViewModel`, `StageTab`, player/status panels, source controls, renderer controls, VU meters, local music UI, diagnostics UI, settings, and local web state.

Inputs:
User commands, local file selections, source selections, route selections, renderer settings, playlist mutations, Roon/Spotify status, live input route facts, output route facts, and diagnostic requests.

Outputs:
Native UI state, audio engine commands, route selections, rendered/monitor playback behavior, logs, diagnostics, web state, and user-facing status text.

Data models:
View model state, `SourceMode`, `LiveMonitorState`, `LiveAudioSignalState`, local music models, player row models, meter display models, route info, renderer presets, web state, and diagnostics rows.

Errors:
User-facing errors from engine, file, route, live capture, Roon, Spotify, Atmos DRP, local library, diagnostics, and web command paths.

Side effects allowed:
Start/stop playback, read selected files, manage app state, write app-managed runtime logs/cache/preferences, start local helpers, expose local web state, and interact with Core Audio via app integration code.

Side effects forbidden:
Committing private runtime data, using old prototype workspaces for active product changes, silently changing shared module contracts, masking live silence, or using raw executable launches for GUI/audio verification.

Allowed dependencies:
`AudioContracts`, `AudioImport`, `AudioCore`, SwiftUI, AppKit, SceneKit, AVFoundation, Core Audio, Network, Darwin, Foundation, app resources, and vendored FFI boundary where already configured.

Forbidden dependencies:
Archived workspaces, unrelated local projects, secrets in tracked files, and major new dependencies unless a future prompt explicitly allows them.

Security or privacy constraints:
Docs and tracked files must use repo-relative paths. Runtime storage belongs in app-managed user locations and must not be committed. Local web controls must not leak private diagnostics into public state.

Performance or audio-stability constraints:
UI responsiveness must not come at the expense of audio correctness. Diagnostics should be bounded. Large local file operations should not destabilize live audio.

Tests required:
`Tests/OrbisonicTests/` must cover UI model behavior, app build info, web state, local playback, source switching, diagnostics, route policies, metering, renderer behavior, Roon, Spotify, Atmos DRP, loopback, monitor boundaries, and architecture boundary rules.

Acceptance criteria:
The executable app presents current source and route state honestly, keeps source paths distinct, delegates shared policy to package modules, and remains verifiable through SwiftPM tests plus LaunchServices runtime checks when app behavior changes.

## 5. OrbisonicEngine

Responsibility:
Own the concrete AVAudioEngine graph for local playback and live input playback/monitoring inside the executable app.

Non-responsibilities:
It must not parse Roon logs, own Spotify receiver state, own local library metadata enrichment, own SwiftUI layout, replace renderer contracts, or hide source/route failures.

Public interface or public-facing concepts:
Transport state, output device selection, local queue snapshots, playback/load controls, live input capture wiring, monitor playback behavior, and engine callbacks used by the view model.

Inputs:
Loaded audio files, streaming/local sources, live input sources, output device selections, render/monitor choices, local queue commands, and transport commands.

Outputs:
Audible local or live monitor playback, current transport state, callbacks for playback progress/end, metering taps/snapshots, and engine errors.

Data models:
`TransportState`, `OutputDeviceSelectionError`, local gapless queue snapshots, loaded audio files, live input sources, PCM buffers, and engine-owned playback context.

Errors:
Output device selection failure, unsupported file or format, graph build failure, live input capture failure, playback scheduling failure, and route/sample-rate/channel-count mismatch surfaced through app diagnostics.

Side effects allowed:
Build and mutate the app-owned AVAudioEngine graph, schedule buffers, start and stop playback, select output devices, and install/remove app-owned taps.

Side effects forbidden:
Masking all-zero live input, faking extra source channels, mutating Sonic Sphere topology from monitor changes, writing package contracts, or starting unrelated services.

Allowed dependencies:
AVFoundation, AudioToolbox, AppKit where current app code requires it, local source/renderer/monitor helpers, and app state callbacks.

Forbidden dependencies:
Swift package modules reaching back into engine internals, Roon log parsing as proof of live audio, installer scripts, and hidden network access.

Security or privacy constraints:
Do not persist user-selected paths or route/device facts into tracked files. Runtime logs must be app-managed.

Performance or audio-stability constraints:
Audio graph work must avoid unnecessary rebuilds during playback. Live silence, underruns, drops, and mismatches must stay visible. Metering must not consume ring buffers or alter audible output.

Tests required:
Engine-adjacent behavior must be covered through local playback, live route, monitor, metering, source switching, and gapless tests in `Tests/OrbisonicTests/`.

Acceptance criteria:
Local and live paths remain separate, source switches do not leave stale graph connections, monitor playback remains two-channel where specified, and runtime failures surface as errors or diagnostics rather than hidden fallbacks.

## 6. LiveAudioBridge

Responsibility:
Capture live audio from selected loopback input devices, buffer it safely, report live pipe status, and expose signal/underflow/drop information to the app.

Non-responsibilities:
It must not choose the active music source, parse Roon or Spotify metadata, synthesize missing signal, perform production rendering, own monitor topology, or decide UI copy.

Public interface or public-facing concepts:
`LiveInputSource`, `LiveInputCapture`, `LiveChannelRingBuffer`, `LiveChannelRingBufferStatus`, `LiveAudioPipeStatus`, and `LiveAudioPipe`.

Inputs:
Selected live input device identity, channel count requests, sample rate, input buffers, and read requests from playback/metering consumers.

Outputs:
Buffered live PCM, ring-buffer status, pipe status, underflow/drop counters, priming state, and capture errors.

Data models:
Live input source, channel ring buffers, live audio pipe status, channel buffer status, live input errors, and AVAudioPCMBuffer data.

Errors:
Too many requested source channels, unavailable input, invalid format, input install/start failure, underflow, and capture errors.

Side effects allowed:
Open selected input capture, allocate bounded ring buffers, write captured frames into buffers, and report status.

Side effects forbidden:
Generating fake signal, increasing gain to hide silence, unlimited buffering, fake multichannel expansion, route selection policy, source mixing, production renderer mutation, and UI mutation.

Allowed dependencies:
AVFoundation, AudioToolbox, Foundation, and app-owned source/route values.

Forbidden dependencies:
SwiftUI, Roon bridge client, Spotify receiver client, local library metadata, renderer topology owner, installer scripts, and public web controls.

Security or privacy constraints:
Treat macOS microphone permission as the OS gate for loopback input capture. Do not record or persist captured audio in tracked files.

Performance or audio-stability constraints:
Buffers must remain bounded. Underflow and dropped frames must be counted rather than hidden. Reads for metering must not consume playback data.

Tests required:
`Tests/OrbisonicTests/LiveAudioBridgeTests.swift` and metering tests must cover source-channel ceiling, priming, underflow recovery, drop behavior, and non-consuming meter peeks.

Acceptance criteria:
Live capture exposes silence and buffer failures clearly, respects the 64-channel source cap, and never masks all-zero input or grows latency without bound.

## 7. Local File Source And Local Library Path

Responsibility:
Probe, load, decode, stream, schedule, display, and organize user-selected local audio files and playlists.

Non-responsibilities:
It must not own live loopback capture, Roon transport, Spotify receiver control, Aux routing, Sonic Sphere production topology, or hidden realtime conversion policy.

Public interface or public-facing concepts:
Local file playback, local library, playlists, queue, metadata/artwork, gapless playback policy, local file probe/load status, and local player rows.

Inputs:
User-selected audio files or folders, M3U playlists, sidecar metadata/artwork, local file formats, local queue commands, and playback controls.

Outputs:
Loaded or streaming PCM chunks, local track descriptors, library database state, playlist state, metadata overlays, artwork, player rows, and local playback status.

Data models:
`AudioAssetDescriptor`, `LoadedAudioFile`, `LocalAudioFileSource`, `StreamingAudioFileSource`, `LocalGaplessTrackDescriptor`, `LocalGaplessScheduler`, `LocalMusicTrack`, `LocalMusicPlaylist`, metadata overlay/resolver types, and Matroska/FFmpeg probe types.

Errors:
Unsupported format, missing file, decode failure, probe failure, sample-rate mismatch, oversized prepared PCM, invalid playlist mutation, metadata lookup failure, and queue scheduling failure.

Side effects allowed:
Read user-selected files, write app-managed local library/cache/playlist metadata, perform offline demux/probe/import work, and schedule local playback.

Side effects forbidden:
Mutating live capture graphs, treating Roon/Spotify/Aux as local file sources, deleting external user playlist files unless explicitly designed, committing personal paths, hidden production SRC, and fake metadata that obscures actual source facts.

Allowed dependencies:
AVFoundation, Foundation, CoreAudioTypes where current file support needs it, `AudioImport`, `AudioContracts`, `AudioCore` adapters, and FFmpeg helper discovery where current code supports it.

Forbidden dependencies:
Roon transport control, Spotify receiver lifecycle, Aux loopback capture ownership, installer scripts, and direct production route repair unless mediated through app orchestration.

Security or privacy constraints:
User file paths and metadata are runtime data and must not be added to tracked docs/tests. Tests must use generated fixtures or repo-safe fixture data.

Performance or audio-stability constraints:
Large file preparation must respect memory caps and avoid playback stalls where current streaming/gapless paths support that. Local decode must not destabilize live loopback paths.

Tests required:
Local file, streaming, gapless, local library, metadata enrichment, Matroska/FLAC, probe, and local player stabilization tests must cover deterministic behavior without private media.

Acceptance criteria:
Local playback works as a separate source path, preserves real source format/layout facts, respects sample-rate/channel-count policy, and does not leak stale local state into live source state.

## 8. Roon Integration Boundary

Responsibility:
Represent Roon as a selected live source, parse fallback signal-path/now-playing data from Roon logs, and optionally control Roon transport through the local Roon bridge helper.

Non-responsibilities:
It must not treat a Roon log line as proof that audio reached loopback capture, own live capture buffers, bypass source selection, own Sonic Sphere topology, or require Roon for local playback.

Public interface or public-facing concepts:
Roon source mode, `Orbisonic Roon Input`, Roon now-playing, Roon signal path, Roon bridge snapshot, Roon transport commands, Roon artwork cache, and Roon diagnostics.

Inputs:
Selected source mode, Roon log content, bridge HTTP/JSON responses, transport command requests, expected loopback route facts, live signal state, and artwork requests.

Outputs:
Roon now-playing metadata, signal-path facts, transport command results, artwork cache results, input status rows, diagnostics, and web player state.

Data models:
`RoonNowPlaying`, `RoonSignalPath`, `RoonLogSnapshot`, `RoonNowPlayingReader`, `RoonBridgeSnapshot`, `RoonBridgeZone`, `RoonBridgeOutput`, `RoonBridgeNowPlaying`, `RoonBridgeControl`, `RoonArtworkRequest`, and Roon-specific source adapter status.

Errors:
Missing log, unparsable log, bridge unavailable, bridge unauthorized, no zone/output, command failure, artwork failure, missing loopback input, sample-rate mismatch, and no live signal while Roon reports playback.

Side effects allowed:
Read Roon logs, call the local Roon bridge helper, send explicit Roon transport commands, read/write app-managed artwork cache, and expose diagnostics.

Side effects forbidden:
Changing macOS system input away from the selected Orbisonic loopback requirement, assuming Roon playback equals captured audio, using Roon state to override live HAL validation, mixing with other sources, or hiding silence.

Allowed dependencies:
Foundation, app bridge/resource code, `LoopbackSourceSupport`, `LiveAudioBridge` status, `AudioCore` source adapters, and app diagnostics/web state.

Forbidden dependencies:
Spotify receiver internals, local file scheduler internals, installer package mutation, renderer topology mutation, and old prototype workspaces.

Security or privacy constraints:
Roon authorization tokens and logs are runtime data and must not be committed. Docs should describe app-managed runtime paths generically.

Performance or audio-stability constraints:
Log reads should be bounded. Roon control or metadata failures must not block audio rendering. Roon sample-rate mismatch must be diagnostic and must not override live route validation.

Tests required:
Roon log parser, Roon bridge client, source adapter, web state, and source-isolation tests must cover parsing, playback/signal separation, transport status, and no-signal diagnostics.

Acceptance criteria:
Roon remains one selected live source. Metadata and transport are useful but not trusted as audio-capture proof. Live capture status remains authoritative for whether Orbisonic is receiving audio.

## 9. Spotify Integration Boundary

Responsibility:
Run and monitor the embedded Spotify Connect receiver boundary, expose Spotify status/now-playing/control affordances, and route Spotify audio through the dedicated Spotify loopback input.

Non-responsibilities:
It must not pretend Spotify is multichannel when the source provides stereo, own Roon/Aux/local behavior, bypass selected-source semantics, or store Spotify credentials in tracked files.

Public interface or public-facing concepts:
Spotify source mode, `Orbisonic Spotify Input`, `SpotifyReceiverClient`, `SpotifyReceiverConfiguration`, `SpotifyReceiverStatus`, `SpotifyNowPlaying`, `SpotifyReceiverControl`, embedded librespot FFI, and Spotify diagnostics.

Inputs:
Receiver configuration, app-managed storage location, Spotify Connect session state, now-playing JSON/status files, explicit controls, loopback route facts, and live signal status.

Outputs:
Receiver status, now-playing metadata, control result, diagnostics rows, web player state, and expected stereo live source behavior.

Data models:
Spotify receiver configuration/status/control, Spotify now-playing, source mode, loopback device identity, and AudioCore Spotify source adapter.

Errors:
Storage preparation failure, embedded module unavailable, receiver start failure, no Spotify session, no loopback input, control failure, and no live signal despite Spotify session metadata.

Side effects allowed:
Create app-managed Spotify receiver storage, start/stop the embedded receiver if linked, read receiver now-playing state, send explicit controls where available, and expose diagnostics.

Side effects forbidden:
Committing Spotify credentials/tokens/caches, declaring fake multichannel source width, mixing with Roon/Aux/local, mutating renderer topology, or hiding silence.

Allowed dependencies:
Foundation, Darwin where current FFI boundary needs it, vendored librespot FFI, app-managed storage, loopback support, AudioCore source adapters, and diagnostics/web state.

Forbidden dependencies:
Roon bridge internals, local playlist scheduler internals, installer mutation, app UI layout as receiver logic, and direct Core Audio route repair outside app orchestration.

Security or privacy constraints:
Spotify runtime files belong in app-managed storage and logs. Do not store Spotify credentials, OAuth tokens, or caches in tracked source or docs.

Performance or audio-stability constraints:
Receiver status should not block UI or audio. Spotify source adapter must keep stereo source behavior explicit.

Tests required:
`SpotifyReceiverClientTests`, `OrbisonicWebStateTests`, `LoopbackSourceSupportTests`, and `AudioCoreTests/SourceAdapterTests.swift` must cover receiver unavailable/active status, stale metadata separation, selected-source behavior, and stereo source policy.

Acceptance criteria:
Spotify remains a dedicated selected live source, stereo policy remains explicit, receiver/runtime failures are visible, and credentials/caches stay out of tracked files.

## 10. Atmos DRP Source Boundary

Responsibility:
Represent Dolby Reference Player playback as a separate selected source named `Atmos`, with Orbisonic owning the DRP CLI process and capturing its output through the current temporary loopback route.

Non-responsibilities:
It must not alter `OrbisonicEngine`, renderer matrix policy, normal monitor downmix policy, Sonic Sphere output topology, Aux source semantics, or local PCM decoding behavior.

Public interface or public-facing concepts:
Atmos source mode, `SourceMode.atmosDRP` raw value `Atmos DRP`, source button title `Atmos`, DRP output layout setting, temporary `Orbisonic Aux Cable` loopback route, DRP bitstream metadata, and disabled seek copy.

Inputs:
Selected source mode, DRP-playable local library file URLs, DRP output device list, DRP stdout, DRP metadata CSV files, selected output layout, Aux loopback route facts, live capture status, and queue previous/next commands.

Outputs:
DRP process lifecycle commands, Atmos live audio via loopback capture, approximate wall-clock progress excluding suspended time, diagnostics/status rows, web player state, and DRP codec/Atmos/data-rate/channel/sample-rate/object metadata.

Data models:
`DolbyReferencePlayerController`, `DolbyReferencePlayerDevice`, `DolbyReferencePlayerSession`, `DolbyBitstreamInfo`, `DolbyReferencePlayerOutputLayout`, `AtmosDRPRoutingPolicy`, `SourceMode.atmosDRP`, `OrbisonicLoopbackDevice.auxCable`, `InputRouteInfo`, and `LiveMonitorState`.

Errors:
Missing DRP CLI, missing selected Atmos-compatible track, missing Aux loopback route, DRP output device unavailable, DRP process exit failure, unsupported seek, no signal, and loopback route mismatch.

Side effects allowed:
Launch DRP, select the temporary Atmos loopback policy route, start/stop live capture for the selected Atmos source, suspend/resume DRP with `SIGSTOP`/`SIGCONT`, interrupt/terminate/kill stale DRP process as needed, and read app-created temporary DRP metadata files.

Side effects forbidden:
Using `--audio-out-file`, writing PCM/WAV output files, decoding Atmos in Orbisonic, changing general Aux behavior, treating Atmos as the same source as Aux Cable, silently mixing with other sources, or mutating renderer/monitor topology to support DRP.

Allowed dependencies:
Foundation/Darwin process ownership, loopback source support, local library file recognition, view-model source orchestration, diagnostics/web state, and normal monitor route descriptors.

Forbidden dependencies:
Renderer matrix ownership, Sonic Sphere output topology mutation, Aux-specific metadata ownership, Roon/Spotify controls, installer scripts, hidden route repair, and old prototype workspaces.

Security or privacy constraints:
DRP temp metadata stays in app-created temporary folders and must not be committed. Docs should name generic app concepts instead of local user media paths.

Performance or audio-stability constraints:
DRP process management must not block UI, pause/resume remains explicitly experimental, and progress is approximate because DRP CLI does not expose seek or transport position.

Tests required:
`DolbyReferencePlayerControllerTests`, `LoopbackSourceSupportTests`, `LiveNormalMonitorRouteTests`, `NormalMonitorRouteDescriptorTests`, and `OrbisonicWebStateTests` must cover device parsing, command arguments, metadata parsing, source order, temporary route policy, transport state, and web metadata exposure.

Acceptance criteria:
Atmos is a separate selected source with owned DRP transport. V1 routes through the Aux loopback by policy only, reports DRP bitstream metadata, and leaves Aux source behavior and renderer/monitor topology unchanged.

## 11. Aux Source Boundary

Responsibility:
Represent general system/app audio as a selected live source captured through the dedicated Aux loopback input.

Non-responsibilities:
It must not own Roon or Spotify metadata/transport, local file playback, source mixing, or production renderer topology.

Public interface or public-facing concepts:
Aux source mode, `Orbisonic Aux Cable`, Aux live input status, Aux signal state, active channel count, and Aux diagnostics.

Inputs:
Selected source mode, Aux loopback route facts, live capture buffers/status, sample rate, channel count, active-channel detection, and monitor commands.

Outputs:
Aux live audio, diagnostics rows, input status rows, active-channel status, web state, and errors for missing or mismatched Aux input.

Data models:
`SourceMode.aux`, `OrbisonicLoopbackDevice.auxCable`, `InputRouteInfo`, `LiveMonitorState`, `LiveAudioSignalState`, `LiveAudioPipeStatus`, and AudioCore Aux source adapter status.

Errors:
Missing Aux loopback input, unavailable route, sample-rate mismatch, channel-count mismatch, no signal, underflow/drop status, and monitor route risk.

Side effects allowed:
Start/stop capture from the selected Aux loopback, monitor Aux through the normal monitor path, and expose diagnostics.

Side effects forbidden:
Parsing Roon/Spotify metadata for Aux, treating Aux as local file playback, faking active channels, mutating renderer topology, or mixing Aux with other sources without a future mixer contract.

Allowed dependencies:
Loopback support, live capture, route monitor facts, AudioCore source adapter policy, app engine, diagnostics, and web state.

Forbidden dependencies:
Roon bridge commands, Spotify receiver internals, local library mutation, installer scripts, and hidden route repair that masks failure.

Security or privacy constraints:
Aux can carry arbitrary system/app audio; captured audio must not be persisted into tracked files.

Performance or audio-stability constraints:
Aux capture must surface silence, underflows, drops, sample-rate mismatch, and route mismatch without growing latency or hiding failure.

Tests required:
Loopback source support, live normal monitor route, source adapter, diagnostics/web state, and live bridge tests must cover Aux route identity, channel policy, selected-source behavior, and no-signal states.

Acceptance criteria:
Aux is a dedicated selected live source that captures only the expected Aux loopback and reports route/signal problems honestly.

## 12. Renderer And Sonic Sphere Output Boundary

Responsibility:
Define and preserve Sonic Sphere production rendering, including static bed modes, Direct 30, Direct 30.1, renderer matrices, speaker topology, presets, and production metering semantics.

Non-responsibilities:
It must not own source selection, live capture, Roon/Spotify/Aux transport, local file scheduling, normal monitor topology, or UI-only meter decoration.

Public interface or public-facing concepts:
Sonic Sphere 30.1 default topology, `RendererRenderMode`, `RendererOutputTopology`, `RendererPreset`, `RendererSceneModel`, `RendererMatrix`, `FeyStaticBedRenderer`, Direct 30/31 bypass, Sonic Sphere output speakers, and renderer meter levels.

Inputs:
Source channel count/layout, renderer mode selection, renderer tuning/preset settings, source frames, channel roles, and calibration/topology facts.

Outputs:
Renderer scene model, matrix gains, rendered Sonic Sphere output frame, renderer meter levels, and preset persistence.

Data models:
Renderer vectors, topology, render modes, input layouts, matrix, presets, FEY speaker/lobe data, spatial tuning, AudioCore render graph plans, and Dante/Sonic Sphere renderer kernels.

Errors:
Unsupported source width, invalid renderer matrix/plan, channel mismatch, invalid preset, insufficient production output channels, sample-rate mismatch, and route capability failure.

Side effects allowed:
Compute renderer topology and matrices, persist app-managed renderer presets, render deterministic output frames, and expose meter-only renderer data.

Side effects forbidden:
Changing active source, mutating monitor topology, treating monitor output as production truth, fake channel expansion, hidden sample-rate conversion, and direct hardware claims without runtime verification.

Allowed dependencies:
Foundation, renderer module helpers, AudioCore render graph/kernels/output adapters, calibration files, source layout descriptors, and app state that selects renderer settings.

Forbidden dependencies:
Roon/Spotify/Aux control, local library mutation, live capture buffers as ownership, SwiftUI layout code as renderer policy, and installer scripts.

Security or privacy constraints:
Renderer presets must not contain personal paths or private device identifiers unless app-managed and not tracked.

Performance or audio-stability constraints:
Matrix rendering must be deterministic, clear outputs before rendering, avoid mutating inputs, and preserve direct30/direct31 bypass semantics. Renderer topology changes are high risk.

Tests required:
Renderer module, matrix renderer, Sonic Sphere metering, AudioCore render graph, render kernel, and output adapter tests must cover topology, direct modes, channel role routing, LFE behavior, matrix stability, and no monitor-to-production mutation.

Acceptance criteria:
Sonic Sphere production rendering remains explicit, deterministic, and protected by tests. Monitor changes cannot redefine production topology.

## 13. Headphone Or Normal Monitor Boundary

Responsibility:
Provide a headphone or normal stereo monitor path for setup, checking, preview, and desktop listening without changing Sonic Sphere production output.

Non-responsibilities:
It must not own Sonic Sphere production topology, direct renderer output, source selection, live capture ownership, local file decoding, or route repair.

Public interface or public-facing concepts:
Normal monitor downmix, normal monitor route descriptor, normal monitor graph topology, monitor conversion ledger, Apple spatial headphone monitor status/options, and monitor meters.

Inputs:
Source channel roles/layout, source frames or deterministic test blocks, monitor route facts, monitor mode options, Apple spatial headphone options, and sample-rate/session facts.

Outputs:
Two-channel monitor output where current normal monitor path requires it, monitor conversion ledger, monitor route decisions, monitor meter data, and Apple spatial headphone status values.

Data models:
`NormalMonitorStereoDownmixer`, `NormalMonitorGraphTopology`, `NormalMonitorRouteDescriptor`, `NormalMonitorConversionLedger`, `DesktopMonitorModeStatus`, Apple spatial headphone option/capability/status types, and AudioCore desktop monitor renderer.

Errors:
Invalid downmix format, unsupported route, sample-rate mismatch, no route, invalid monitor conversion, and Apple spatial capability failures.

Side effects allowed:
Compute monitor downmix, classify monitor route capability, expose monitor status, apply monitor-only gain, and produce monitor-only meters.

Side effects forbidden:
Mutating Sonic Sphere/Dante output, enabling direct Sonic Sphere audible output as monitor fallback, folding LFE unless explicit policy allows it, using HRTF/environment nodes in paths where tests forbid it, and hiding production route failures.

Allowed dependencies:
Foundation, AVFoundation in current app monitor helpers, AudioContracts, AudioCore monitor/kernels, route descriptor values, and app-owned monitor route facts.

Forbidden dependencies:
Renderer topology ownership, Roon/Spotify transport control, live capture ownership, installer scripts, and SwiftUI layout as monitor policy.

Security or privacy constraints:
Monitor route names/device facts are runtime diagnostics and should not be committed as private machine-specific data.

Performance or audio-stability constraints:
Monitor processing must not mutate input buffers or audible production output. Metering must be side-effect-free relative to playback samples.

Tests required:
Normal monitor downmixer, graph topology, route descriptor, route branch removal, conversion ledger, golden audio, AudioSpatialUsageAudit, Apple spatial headphone monitor, and metering isolation tests must protect monitor-only behavior.

Acceptance criteria:
Monitor output remains a preview/checking path, normal monitor routes are deterministic, and monitor changes cannot mutate Sonic Sphere production output or route topology.

## 14. Diagnostics And Logging Boundary

Responsibility:
Expose bounded, useful, source-specific diagnostics for input, output, renderer, monitor, logs, web state, route state, and source health.

Non-responsibilities:
Diagnostics must not fix audio by hiding failure, own engine graph mutation, own route selection policy, parse private data into tracked files, or become a source of production truth when lower-level validation disagrees.

Public interface or public-facing concepts:
Diagnostics tab, input source status panel, app logger, diagnostics log store, debug timing log, web public/control state, live source status rows, Roon/Spotify/Aux diagnostics, route warnings, and meter displays.

Inputs:
Engine state, route facts, live signal state, buffer counters, Roon bridge/log facts, Spotify receiver facts, local playback state, meter snapshots, log files, and user diagnostic requests.

Outputs:
User-facing diagnostic rows, filtered log snippets, warnings/errors, public web state, control web state, source instructions, route warnings, and status summaries.

Data models:
`DiagnosticEvent`, `DiagnosticToneActivitySummary`, `DiagnosticsLogReadResult`, `InputSourceStatusPanel`, `OrbisonicWebState`, meter models, route info, and source-specific status values.

Errors:
Log read failure, unavailable route/source, bridge/receiver failure, malformed command, missing hardware, sample-rate mismatch, channel-count mismatch, no live signal, underflow/drop diagnostics, and permission/signing limitations.

Side effects allowed:
Read bounded log tails, write app logs, expose local web state/commands, present diagnostic UI, and report warnings.

Side effects forbidden:
Unbounded synchronous log scans, committing private logs, masking silence, changing renderer topology, starting unrelated services, or using public state to expose private diagnostics.

Allowed dependencies:
Foundation, OSLog, Network/Darwin for current local web server, app state, route monitor facts, Roon/Spotify status, meter services, and diagnostic views.

Forbidden dependencies:
Installer mutation, hidden source mixing, direct buffer mutation for metering display, and old prototype workspaces.

Security or privacy constraints:
Public web state should stay visitor-facing. Detailed diagnostics and control state must remain separated. Logs and private runtime state must not be tracked.

Performance or audio-stability constraints:
Diagnostics must be bounded and should not block realtime audio or heavy UI refresh. Metering display must not mutate audio samples.

Tests required:
Diagnostics log store, web state, VU routing, metering service, metering telemetry, input source status, and source-specific diagnostics tests must cover bounded reads, public/control separation, and no side effects on playback.

Acceptance criteria:
Diagnostics make failures easier to distinguish, especially player activity versus captured audio, while keeping audio failures visible and privacy boundaries intact.

## 15. Installer And App Bundle Scripts Boundary

Responsibility:
Build, refresh, sign, verify, open, package, and install helper assets for the Orbisonic app and its optional runtime helpers.

Non-responsibilities:
Scripts must not change source behavior outside their documented build/package purpose, rewrite audio policy, edit contracts without a docs task, or verify hardware behavior they do not actually exercise.

Public interface or public-facing concepts:
`scripts/refresh-orbisonic-app.sh`, `scripts/reopen-orbisonic-app.sh`, `scripts/build-installer.sh`, `scripts/install-roon-bridge.sh`, `scripts/build-embedded-librespot.sh`, branch/release launchers, `Orbisonic.app`, installer packages, and release notes.

Inputs:
Swift package source, app bundle skeleton, built executable/resource bundle, git metadata, vendored Rust source, Roon bridge resource files, package version argument, and installer root.

Outputs:
Refreshed app bundle, ad hoc signed bundle, app package, suite package artifacts where already present, Roon bridge install, embedded librespot static library, and launcher worktrees.

Data models:
Shell script arguments, Info.plist keys, app bundle contents, package identifiers, static library artifact path, Roon bridge package files, and release notes.

Errors:
Missing app bundle, failed Swift build, missing built executable, failed codesign/plutil/pkgbuild, missing cargo/rustc for librespot build, npm install failure, and LaunchServices/open failure.

Side effects allowed:
Write `.build` artifacts, copy executable/resources into `Orbisonic.app`, sign ad hoc, create installer roots/packages, install Roon bridge dependencies into app-managed user support locations, create launcher worktrees, and open the app through LaunchServices.

Side effects forbidden:
Launching the raw GUI executable for verification, silently changing permanent local URLs, committing personal runtime paths, deleting unrelated files, changing source/audio policy, or claiming hardware verification without running it.

Allowed dependencies:
SwiftPM, Xcode developer dir, codesign, PlistBuddy, plutil, pkgbuild, open/LaunchServices, npm for Roon bridge helper install, cargo/rustc for embedded librespot build, and git for metadata/worktrees.

Forbidden dependencies:
Undocumented destructive commands, hidden network installs outside documented helper setup, old prototype workspaces, and manual hardware assumptions presented as passed checks.

Security or privacy constraints:
Installer and build docs must avoid personal absolute paths and secrets. Runtime helper installs may use app-managed user support paths but should not be written into tracked docs with local usernames.

Performance or audio-stability constraints:
Build scripts do not validate live audio correctness by themselves. After app-code changes, bundle refresh is required; after GUI/audio behavior changes, LaunchServices reopen is required.

Tests required:
App build metadata tests plus future release verification docs. Script behavior should be manually verified by running the smallest safe command when scripts are changed.

Acceptance criteria:
The app bundle and installers are reproducible through documented scripts, GUI verification uses LaunchServices, and release docs distinguish automated checks from manual hardware verification.

## Cross-Cutting Audio Invariants

- Source channel count must not exceed 64 unless a future accepted contract changes `OrbisonicAudioLimits` and related shared descriptors.
- Local file playback and live capture are separate paths.
- Roon, Spotify, Atmos DRP, Aux, local file playback, and test tones are selected source modes, not automatically mixed.
- Atmos DRP temporarily uses the Aux loopback through `AtmosDRPRoutingPolicy`; it is not the same selected source as Aux Cable.
- Roon log playback does not prove loopback capture.
- Spotify must not be represented as multichannel unless the input actually provides multichannel data and a future contract allows it.
- Sample-rate mismatch and channel-count mismatch must be surfaced as validation or diagnostics.
- Monitor meters and VU displays must not change audible output.
- Monitor output must not mutate Sonic Sphere production output.
- Direct 30 and Direct 30.1 remain bypass modes only when source width matches their expected topology.
- Hardware-only behavior must stay manual-only until a real environment verifies it.
