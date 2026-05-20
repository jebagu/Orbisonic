# Orbisonic System Flows

## Purpose

This document describes the current Orbisonic runtime and verification flows without requiring source-code inspection. It is descriptive and should stay aligned with `docs/contracts.md`, `docs/architecture.md`, and the current source.

## How To Read These Diagrams

- These flows describe the canonical repository root. Imported implementation work, release evidence, and task material now live directly under `Sources/`, `Tests/`, `scripts/`, `docs/`, and `.tasks/`.
- The root `Open Orbisonic.command` is the single daily opener for the canonical build. Named root aliases, when present, delegate to the same LaunchServices reopen flow. Build or refresh flows stay in explicit scripts and are not hidden behind launchers.
- Orbisonic is selected-source oriented. Local Files, Atmos DRP, Roon, Spotify, Aux Cable, and Test Tone are not automatically mixed.
- Sonic Sphere output is the production path.
- Headphone or normal monitor output is a monitor path and must not redefine production topology.
- Live player metadata is useful context, but captured loopback audio and route facts remain authoritative for live audio health.
- Switching to Off or Test Tone clears stale local playback snapshots before those sources publish their selected-source state.
- Hardware-only steps are marked as manual verification.

## 1. System Context

Orbisonic is a native macOS app with shared package modules for contracts, import policy, and pure audio planning, plus an executable app target that owns SwiftUI, AVAudioEngine, platform routes, integrations, diagnostics, and packaging-facing runtime behavior.

```mermaid
flowchart LR
    Operator["Operator"]
    App["Orbisonic Executable App Shell"]
    Contracts["AudioContracts"]
    Import["AudioImport"]
    Core["AudioCore"]
    Engine["OrbisonicEngine"]
    LiveBridge["LiveAudioBridge"]
    LocalFiles["Local File Source And Local Library Path"]
    Roon["Roon Integration Boundary"]
    Spotify["Spotify Integration Boundary"]
    Atmos["Atmos DRP Boundary"]
    Aux["Aux Source Boundary"]
    Renderer["Renderer And Sonic Sphere Output Boundary"]
    Monitor["Headphone Or Normal Monitor Boundary"]
    Diagnostics["Diagnostics And Logging Boundary"]
    Hardware["macOS Core Audio, loopback devices, Sonic Sphere, Dante, headphones"]
    BundleScripts["Canonical Launcher, Installer, And App Bundle Scripts Boundary"]

    Operator --> App
    App --> Contracts
    App --> Import
    App --> Core
    App --> Engine
    App --> LiveBridge
    App --> LocalFiles
    App --> Roon
    App --> Spotify
    App --> Atmos
    App --> Aux
    App --> Renderer
    App --> Monitor
    App --> Diagnostics
    Engine --> Hardware
    LiveBridge --> Hardware
    Renderer --> Hardware
    Monitor --> Hardware
    BundleScripts --> App
```

## 2. Local File Playback Flow

Local file playback reads user-selected files or library tracks, probes real source facts, loads or streams PCM, and then schedules playback through the app-owned engine. This path is separate from live loopback capture.

```mermaid
sequenceDiagram
    actor Operator
    participant UI as ContentView / Local Music UI
    participant VM as OrbisonicViewModel
    participant Probe as AudioFileProbe
    participant Import as AudioImport
    participant Loader as AudioFileLoader or StreamingAudioFileSource
    participant Engine as OrbisonicEngine
    participant Renderer as Renderer And Sonic Sphere Output Boundary
    participant Monitor as Headphone Or Normal Monitor Boundary
    participant Diagnostics as Diagnostics And Logging Boundary

    Operator->>UI: Select or play local file
    UI->>VM: Local file command
    VM->>VM: selectSourceMode(Local Files)
    VM->>Probe: Probe container, codec, sample rate, channel count, layout
    Probe-->>VM: AudioAssetDescriptor
    VM->>Import: Check production readiness when policy applies
    Import-->>VM: AssetReadiness or explicit error
    VM->>Loader: Load prepared PCM or open streaming source
    Loader-->>VM: LoadedAudioFile or streaming source
    VM->>Engine: loadPreparedFile or start streaming playback
    Engine->>Renderer: Build or refresh renderer scene from source layout
    Engine->>Monitor: Configure normal monitor path for preview
    Engine-->>Diagnostics: Playback, meter, and error status
```

Current local playback surfaces include probing, loading, streaming, local music library state, optional gapless scheduling, metering, renderer scene refresh, and normal monitor setup. Unsupported formats, source-channel overflow, sample-rate policy failures, and decode failures stay visible as errors instead of being hidden. When the selected source changes away from Local Files to Off or Test Tone, stale local playback metadata is cleared so the idle or diagnostic source cannot present the previous track as active.

## 3. Live Roon Loopback Flow

Roon is a selected live source. Roon metadata and transport control are separate from the Core Audio loopback capture path, and a Roon playback line is not proof that Orbisonic is receiving audio.

```mermaid
sequenceDiagram
    actor Operator
    participant UI as Input UI
    participant VM as OrbisonicViewModel
    participant RoonLog as RoonNowPlayingMonitor
    participant RoonBridge as RoonBridgeClient
    participant Routes as OutputRouteMonitor and LoopbackSourceSupport
    participant Engine as OrbisonicEngine
    participant Live as LiveAudioBridge
    participant Diagnostics as Diagnostics And Logging Boundary

    Operator->>UI: Select Roon
    UI->>VM: selectSourceMode(Roon)
    VM->>Routes: Select expected Orbisonic Roon Input
    VM->>RoonBridge: Refresh optional bridge snapshot
    VM->>RoonLog: Read fallback now-playing and signal path
    VM->>Engine: startLiveInput with selected input route
    Engine->>Live: Start HAL capture and LiveAudioPipe
    Live-->>Engine: Buffered PCM, underflows, drops, signal state
    Engine-->>VM: Live input source metadata and meters
    VM-->>Diagnostics: Compare Roon metadata, route sample rate, channel count, live meter, and pipe status
```

Roon transport controls may go through the local Roon bridge helper, but live admission still depends on the selected loopback input, channel count, sample rate, and captured signal. If Roon reports playback while live meters stay silent, the flow is a route or capture diagnostic case.

## 4. Aux Loopback Flow

Aux is a selected live source for general system or app audio routed into the dedicated Aux loopback input.

```mermaid
flowchart LR
    ExternalApp["External app or system audio"]
    AuxDevice["Orbisonic Aux Cable"]
    RouteSupport["LoopbackSourceSupport"]
    VM["OrbisonicViewModel"]
    Engine["OrbisonicEngine"]
    Live["LiveAudioBridge"]
    Monitor["Headphone Or Normal Monitor Boundary"]
    Renderer["Renderer And Sonic Sphere Output Boundary"]
    Diagnostics["Diagnostics And Logging Boundary"]

    ExternalApp --> AuxDevice
    AuxDevice --> RouteSupport
    RouteSupport --> VM
    VM --> Engine
    Engine --> Live
    Live --> Engine
    Engine --> Monitor
    Engine --> Renderer
    VM --> Diagnostics
    Live --> Diagnostics
```

Aux does not parse Roon or Spotify metadata. Its health depends on the expected Aux route, live capture status, active channels, sample rate, channel count, and whether real signal is arriving.

## 5. Atmos DRP Flow

Atmos is a selected live source with Orbisonic-owned Dolby Reference Player transport. V1 intentionally routes DRP output to `Orbisonic Aux Cable` through `AtmosDRPRoutingPolicy`, and Orbisonic captures that same loopback. That temporary route does not make Atmos the same selected source as Aux Cable.

```mermaid
sequenceDiagram
    actor Operator
    participant UI as Source Button / Local Music UI
    participant VM as OrbisonicViewModel
    participant DRP as DolbyReferencePlayerController
    participant Routes as AtmosDRPRoutingPolicy / LoopbackSourceSupport
    participant Engine as OrbisonicEngine
    participant Live as LiveAudioBridge
    participant Diagnostics as Diagnostics And Web State

    Operator->>UI: Select Atmos and play DRP-compatible track
    UI->>VM: playAtmosDRPTransport
    VM->>Routes: Resolve temporary capture/output loopback
    VM->>Engine: startLiveInput for temporary Atmos route
    VM->>DRP: launch drp with device, layout, volume, print-info, metadata directory
    DRP-->>VM: Process state, stdout metadata, audio.csv metadata
    Engine->>Live: Capture live PCM from loopback
    Live-->>VM: Signal, underflow, drop, and meter facts
    VM-->>Diagnostics: Report route, process, signal, and bitstream metadata
```

Pause/resume uses process suspension and is reported as experimental. Stop interrupts DRP, then escalates to termination and kill if needed. Previous and next stop the current DRP process and launch an adjacent queue/library track. Seek stays disabled because the DRP CLI does not expose seek.

## 6. Spotify Receiver Flow

Spotify is a selected live source with a dedicated receiver boundary and a dedicated loopback input. Current product policy treats Spotify as stereo unless a future accepted contract changes that.

```mermaid
sequenceDiagram
    actor Operator
    participant SpotifyApp as Spotify App
    participant Receiver as SpotifyReceiverClient
    participant VM as OrbisonicViewModel
    participant Routes as LoopbackSourceSupport
    participant Engine as OrbisonicEngine
    participant Live as LiveAudioBridge
    participant Diagnostics as Diagnostics And Logging Boundary

    Operator->>SpotifyApp: Choose Orbisonic in Spotify Connect
    VM->>Receiver: Start or refresh receiver status
    Receiver-->>VM: Receiver status and now-playing facts
    Operator->>VM: Select Spotify source
    VM->>Routes: Expect Orbisonic Spotify Input
    VM->>VM: Use fixed stereo live channel policy
    VM->>Engine: startLiveInput for Spotify route
    Engine->>Live: Capture stereo live PCM from loopback
    Live-->>VM: Signal, underflow, drop, and meter facts
    VM-->>Diagnostics: Report receiver, loopback, signal, and metadata status
```

Receiver startup, session metadata, and controls are diagnostic/control surfaces. They do not replace the selected loopback route or live capture facts. Spotify health reporting stays inside the current fixed stereo source policy and must not promote stale local multichannel metadata into a Spotify stream format.

## 7. Renderer And Sonic Sphere Output Flow

The Sonic Sphere output path is the production path. The current app has a legacy app-target renderer model and an in-progress AudioCore planning/kernel layer; both preserve explicit source layout, render mode, and 30.1 production topology semantics.

```mermaid
flowchart TD
    Source["Selected source PCM and source layout"]
    Scene["RendererMatrixBuilder scene model"]
    Mode["RendererRenderMode: automatic, bed modes, Direct 30, Direct 30.1"]
    Matrix["RendererMatrix or AudioCore RenderGraphPlan"]
    Render["FeyStaticBedRenderer or DanteSonicSphereRenderer"]
    MeterCopy["Meter-only renderer data"]
    Production["Sonic Sphere 30.1 production output"]
    Diagnostics["Renderer diagnostics and validation messages"]

    Source --> Scene
    Scene --> Mode
    Mode --> Matrix
    Matrix --> Render
    Render --> Production
    Matrix --> MeterCopy
    MeterCopy --> Diagnostics
    Matrix --> Diagnostics
```

Direct 30 and Direct 30.1 are bypass modes only when source width matches. Renderer output must not be derived from monitor output, and monitor choices must not mutate the Sonic Sphere topology.

## 8. Headphone Or Normal Monitor Flow

The monitor path is for setup, checking, preview, and desktop listening. It is separate from Sonic Sphere production output.

```mermaid
flowchart LR
    SourcePCM["Source PCM"]
    Downmixer["NormalMonitorStereoDownmixer"]
    OutputGain["Output gain mixer"]
    MainMixer["AVAudioEngine main mixer"]
    SystemOutput["Headphone or normal system output"]
    Ledger["NormalMonitorConversionLedger"]
    SpatialStatus["AppleSpatialHeadphoneMonitor status"]
    Production["Sonic Sphere production output"]

    SourcePCM --> Downmixer
    Downmixer --> OutputGain
    OutputGain --> MainMixer
    MainMixer --> SystemOutput
    SourcePCM --> Ledger
    SystemOutput --> SpatialStatus
    SourcePCM -.-> Production
```

Normal monitor topology is source PCM to stereo downmixer to monitor output. It should not contain an audible Sonic Sphere matrix node, duplicate direct and staged routes, or monitor-volume behavior that changes production output.

## 9. Route Diagnostics Flow

Route diagnostics compare expected source/output identities against Core Audio route facts and live status. They are especially important when a player reports activity but loopback capture is silent.

```mermaid
flowchart TD
    Refresh["Refresh route inventory"]
    Inputs["Available input routes"]
    Outputs["Available output routes"]
    SourcePolicy["SourceMode expected loopback policy"]
    MonitorPolicy["Output 1 Monitor selection policy"]
    RendererPolicy["Output 2 Main Renderer selection policy"]
    LiveStatus["Live pipe status: signal, underflow, dropped frames"]
    DiagnosticPolicy["LiveLoopbackDiagnostics snapshot"]
    RoonFacts["Roon bridge and log facts"]
    SpotifyFacts["Spotify receiver facts"]
    AtmosFacts["DRP process and bitstream facts"]
    Diagnostics["DiagnosticsView and InputSourceStatusPanelModel"]

    Refresh --> Inputs
    Refresh --> Outputs
    Inputs --> SourcePolicy
    Outputs --> MonitorPolicy
    Outputs --> RendererPolicy
    SourcePolicy --> LiveStatus
    SourcePolicy --> DiagnosticPolicy
    LiveStatus --> DiagnosticPolicy
    RoonFacts --> DiagnosticPolicy
    SpotifyFacts --> DiagnosticPolicy
    AtmosFacts --> DiagnosticPolicy
    RoonFacts --> Diagnostics
    SpotifyFacts --> Diagnostics
    AtmosFacts --> Diagnostics
    LiveStatus --> Diagnostics
    DiagnosticPolicy --> Diagnostics
    MonitorPolicy --> Diagnostics
    RendererPolicy --> Diagnostics
```

Diagnostics should distinguish missing loopback devices, wrong selected routes, sample-rate mismatch, channel-count mismatch, microphone permission issues, all-zero input, underflows, dropped frames, and feedback-loop risk. For live sources, `LiveLoopbackDiagnostics` produces separate route, sample-rate, channel, signal, buffer, permission, and player/source activity summaries so Roon, Spotify, or DRP activity never counts as proof of captured loopback audio.

## 10. Test Tone Flow

Test tones are diagnostic sources. They can target monitor checks, renderer output channel walks, or multichannel VU activity without implying that external player audio or hardware has been verified.

```mermaid
sequenceDiagram
    actor Operator
    participant DiagnosticsUI as DiagnosticsView
    participant VM as OrbisonicViewModel
    participant Engine as OrbisonicEngine
    participant Tone as TestToneSupport
    participant Monitor as Headphone Or Normal Monitor Boundary
    participant Renderer as Renderer And Sonic Sphere Output Boundary
    participant Logs as Diagnostics And Logging Boundary

    Operator->>DiagnosticsUI: Start test tone or channel walk
    DiagnosticsUI->>VM: Diagnostic command
    VM->>VM: Save return context and stop conflicting music action
    VM->>Engine: playTestTone or playDiagnosticChannelTone
    Engine->>Tone: Generate tone frames
    alt Monitor test
        Engine->>Monitor: Send tone through normal monitor path
    else Renderer test
        Engine->>Renderer: Send channel tone to renderer output path
        Engine->>Monitor: Optional monitor downmix for checking
    end
    VM-->>Logs: Record status, meters, and failures
```

Test tone success proves the commanded diagnostic path ran. Sonic Sphere, Dante, headphones, and loopback hardware still need manual listening or route verification when those physical paths are the question.

## 11. Error And Logging Flow

Orbisonic uses typed errors, user-facing status, bounded diagnostics, and app-managed runtime logs. Logging should aid diagnosis without mutating audio behavior or committing private runtime data.

```mermaid
flowchart TD
    ErrorSource["Engine, live bridge, imports, routes, Roon, Spotify, Atmos DRP, local files, renderer"]
    TypedError["Typed error or localized failure"]
    VMStatus["OrbisonicViewModel status and lastError"]
    Logger["AppLogger"]
    LogStore["DiagnosticsLogStore bounded tail"]
    DebugTiming["DebugTimingLog"]
    NativeDiagnostics["DiagnosticsView"]
    WebState["OrbisonicWebServer public and control state"]

    ErrorSource --> TypedError
    TypedError --> VMStatus
    VMStatus --> NativeDiagnostics
    TypedError --> Logger
    Logger --> LogStore
    DebugTiming --> Logger
    LogStore --> NativeDiagnostics
    VMStatus --> WebState
```

Detailed diagnostics and control state must stay separate from public-facing state. Log reads should remain bounded, and meter display must not alter playback samples.

## 12. Manual Hardware Verification Flow

Automated tests can protect contracts, source isolation, render planning, monitor topology, diagnostics, and local file behavior. They cannot prove physical Sonic Sphere, Dante, loopback, Roon, Spotify, Dolby Reference Player, app signing, microphone permission, or installer behavior unless those environments are actually exercised.

```mermaid
flowchart TD
    Build["Build or refresh app bundle"]
    Reopen["Reopen Orbisonic.app through LaunchServices"]
    Loopbacks["Manual: verify Orbisonic loopback devices"]
    Roon["Manual: route Roon to Orbisonic Roon Input"]
    Spotify["Manual: choose Orbisonic in Spotify Connect"]
    Aux["Manual: route external app audio to Orbisonic Aux Cable"]
    Atmos["Manual: play DRP-compatible Atmos file through Dolby Reference Player"]
    Monitor["Manual: listen on headphone or normal monitor output"]
    Sphere["Manual: verify Sonic Sphere or Dante production output"]
    Diagnostics["Record diagnostics: route, sample rate, channel count, meters, drops, logs"]
    Release["Release verification notes"]

    Build --> Reopen
    Reopen --> Loopbacks
    Loopbacks --> Roon
    Loopbacks --> Spotify
    Loopbacks --> Aux
    Loopbacks --> Atmos
    Reopen --> Monitor
    Reopen --> Sphere
    Roon --> Diagnostics
    Spotify --> Diagnostics
    Aux --> Diagnostics
    Atmos --> Diagnostics
    Monitor --> Diagnostics
    Sphere --> Diagnostics
    Diagnostics --> Release
```

Manual hardware verification should record what was actually tested and avoid claiming success for unexercised routes. For GUI or audio checks after app-code changes, use the app bundle through LaunchServices rather than launching the raw executable.

## Playback And Source State Model

The high-level source state is selected-source based. Source switching stops incompatible live capture and starts the selected source path when appropriate.

```mermaid
stateDiagram-v2
    [*] --> Off
    Off --> LocalFiles: select Local Files
    Off --> Roon: select Roon
    Off --> Spotify: select Spotify
    Off --> Atmos: select Atmos
    Off --> Aux: select Aux Cable
    Off --> TestTone: select Test Tone

    LocalFiles --> Off: stop
    LocalFiles --> Roon: switch source
    LocalFiles --> Spotify: switch source
    LocalFiles --> Atmos: switch source
    LocalFiles --> Aux: switch source

    Roon --> Off: stop live monitor
    Roon --> LocalFiles: switch source
    Roon --> Spotify: switch source
    Roon --> Atmos: switch source
    Roon --> Aux: switch source

    Spotify --> Off: stop live monitor
    Spotify --> LocalFiles: switch source
    Spotify --> Roon: switch source
    Spotify --> Atmos: switch source
    Spotify --> Aux: switch source

    Atmos --> Off: stop DRP and live capture
    Atmos --> LocalFiles: switch source
    Atmos --> Roon: switch source
    Atmos --> Spotify: switch source
    Atmos --> Aux: switch source

    Aux --> Off: stop live monitor
    Aux --> LocalFiles: switch source
    Aux --> Roon: switch source
    Aux --> Spotify: switch source
    Aux --> Atmos: switch source

    TestTone --> Off: stop tone
    TestTone --> LocalFiles: return to music
```

This model is intentionally not a mixer model. Simultaneous source mixing would need a future accepted contract.

## Maintenance Rules For This Document

- Update this document when a prompt changes a source flow, renderer flow, monitor flow, diagnostics flow, or hardware verification path.
- Do not update diagrams to describe planned rewrites unless the plan is explicitly labeled as future-only.
- Keep Mermaid labels plain and aligned with `docs/contracts.md`.
- If a flow cannot be verified without hardware, keep it marked manual.
