import AudioContracts
import AudioCore
import Foundation

enum OrbisonicPlaybackProduct: Equatable, Hashable, Sendable {
    case monitor
    case production
}

struct SourcePosition: Equatable, Hashable, Sendable {
    let frame: Int64?
    let seconds: Double?

    init(frame: Int64? = nil, seconds: Double? = nil) {
        self.frame = frame
        self.seconds = seconds
    }
}

struct SphereProfile: Equatable, Hashable, Sendable {
    let id: String
    let outputChannelCount: Int
    let outputMapID: String

    init(
        id: String = "sonic-sphere-31",
        outputChannelCount: Int = 31,
        outputMapID: String = "dante-31"
    ) {
        self.id = id
        self.outputChannelCount = outputChannelCount
        self.outputMapID = outputMapID
    }
}

struct OutputRouteSelection: Equatable, Hashable, Sendable {
    let routeID: String
    let displayName: String
    let sampleRate: AudioSampleRate
    let channelCount: Int

    init(
        routeID: String,
        displayName: String,
        sampleRate: AudioSampleRate = .rate48000,
        channelCount: Int = 31
    ) {
        self.routeID = routeID
        self.displayName = displayName
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }
}

enum OrbisonicAudioPath: Equatable, Hashable, Sendable {
    case off
    case localVLCStereoMonitor
    case localSourcePreservingProduction
    case roonLivePcmCapture
    case spotifyStereoSource
    case auxLivePcmCapture
    case testTone
    case pureSphericalLosslessValidator
}

struct OrbisonicSourcePreparationRequest: Equatable, Hashable, Sendable {
    let selection: SourceSelection
    let product: OrbisonicPlaybackProduct
    let sphereProfile: SphereProfile
    let outputRoute: OutputRouteSelection
    let pureSphericalLosslessState: PureSphericalLosslessState

    init(
        selection: SourceSelection,
        product: OrbisonicPlaybackProduct,
        sphereProfile: SphereProfile = SphereProfile(),
        outputRoute: OutputRouteSelection = OutputRouteSelection(routeID: "dante-31", displayName: "Dante 31"),
        pureSphericalLosslessState: PureSphericalLosslessState = .none
    ) {
        self.selection = selection
        self.product = product
        self.sphereProfile = sphereProfile
        self.outputRoute = outputRoute
        self.pureSphericalLosslessState = pureSphericalLosslessState
    }
}

struct PreparedSource: Equatable, Hashable, Sendable {
    let selection: SourceSelection
    let product: OrbisonicPlaybackProduct
    let path: OrbisonicAudioPath
    let diagnostics: PlaybackDiagnosticSnapshot

    var sourceKind: SourceKind {
        selection.kind
    }
}

enum OrbisonicAudioCoordinator2Error: Error, Equatable, Sendable {
    case sourceUnavailable
    case unsupportedSourceForMonitor(SourceKind)
    case unsupportedSourceForProduction(SourceKind)
    case seekUnsupported(SourceKind)
    case sourceNotPrepared
}

struct OrbisonicAudioCoordinator2: Sendable {
    private(set) var preparedSource: PreparedSource?
    private(set) var isPlaying = false

    init() {}

    mutating func prepareSource(selection: SourceSelection) throws -> PreparedSource {
        try prepareSource(
            OrbisonicSourcePreparationRequest(
                selection: selection,
                product: .monitor
            )
        )
    }

    mutating func prepareSource(_ request: OrbisonicSourcePreparationRequest) throws -> PreparedSource {
        let path = try path(for: request)
        let diagnostics = diagnostics(for: request, path: path)
        let prepared = PreparedSource(
            selection: request.selection,
            product: request.product,
            path: path,
            diagnostics: diagnostics
        )
        preparedSource = prepared
        return prepared
    }

    mutating func startMonitorPlayback() throws {
        guard let preparedSource else { throw OrbisonicAudioCoordinator2Error.sourceNotPrepared }
        guard preparedSource.product == .monitor else {
            throw OrbisonicAudioCoordinator2Error.unsupportedSourceForMonitor(preparedSource.sourceKind)
        }
        isPlaying = true
    }

    mutating func startProductionPlayback() throws {
        guard let preparedSource else { throw OrbisonicAudioCoordinator2Error.sourceNotPrepared }
        guard preparedSource.product == .production else {
            throw OrbisonicAudioCoordinator2Error.unsupportedSourceForProduction(preparedSource.sourceKind)
        }
        isPlaying = true
    }

    mutating func stopPlayback() {
        isPlaying = false
    }

    func seekIfSupported(position: SourcePosition) throws {
        _ = position
        switch preparedSource?.sourceKind {
        case .localFile:
            return
        case .off, .roon, .spotify, .aux, .testTone, nil:
            throw OrbisonicAudioCoordinator2Error.seekUnsupported(preparedSource?.sourceKind ?? .off)
        }
    }

    func currentDiagnostics() -> PlaybackDiagnosticSnapshot? {
        preparedSource?.diagnostics
    }

    private func path(for request: OrbisonicSourcePreparationRequest) throws -> OrbisonicAudioPath {
        switch request.selection.kind {
        case .off:
            return .off
        case .localFile:
            if request.product == .production,
               request.pureSphericalLosslessState != .none {
                return .pureSphericalLosslessValidator
            }
            return request.product == .monitor
                ? .localVLCStereoMonitor
                : .localSourcePreservingProduction
        case .roon:
            return .roonLivePcmCapture
        case .spotify:
            return .spotifyStereoSource
        case .aux:
            return .auxLivePcmCapture
        case .testTone:
            return .testTone
        }
    }

    private func diagnostics(
        for request: OrbisonicSourcePreparationRequest,
        path: OrbisonicAudioPath
    ) -> PlaybackDiagnosticSnapshot {
        let descriptor = request.selection.descriptor
        let sourceSummary = AudioFormatSummary(
            sampleRate: descriptor?.sampleRate,
            channelCount: descriptor?.channelCount,
            sampleFormat: descriptor?.codecDescription ?? "Float32",
            layoutName: descriptor?.layout.name
        )
        let stereoSummary = AudioFormatSummary(
            sampleRate: descriptor?.sampleRate ?? .rate48000,
            channelCount: 2,
            sampleFormat: "Float32",
            layoutName: "Stereo"
        )
        let renderedSummary = AudioFormatSummary(
            sampleRate: request.outputRoute.sampleRate,
            channelCount: request.sphereProfile.outputChannelCount,
            sampleFormat: "Float32",
            layoutName: request.sphereProfile.outputMapID
        )
        let outputSummary = AudioFormatSummary(
            sampleRate: request.outputRoute.sampleRate,
            channelCount: request.outputRoute.channelCount,
            sampleFormat: "PCM 24-bit",
            layoutName: request.outputRoute.displayName
        )
        let sourceID = descriptor?.id ?? "off"
        let sessionID = "coordinator2-\(sourceID)"

        let ledger: AudioConversionLedger
        let decodeOwner: AudioConversionOwner
        let downmixOwner: AudioConversionOwner
        let srcOwner: AudioConversionOwner
        let rendererOwner: AudioConversionOwner
        let formatterOwner: AudioConversionOwner

        switch path {
        case .localVLCStereoMonitor:
            ledger = .localVLCMonitor(
                sessionID: sessionID,
                sourceID: sourceID,
                source: sourceSummary,
                monitor: stereoSummary
            )
            decodeOwner = .vlc
            downmixOwner = .vlc
            srcOwner = .none
            rendererOwner = .none
            formatterOwner = .orbisonic
        case .localSourcePreservingProduction:
            ledger = .danteProduction(
                sessionID: sessionID,
                sourceID: sourceID,
                source: sourceSummary,
                rendered: renderedSummary,
                output: outputSummary,
                srcOccurred: descriptor?.sampleRate.matches(request.outputRoute.sampleRate) == false
            )
            decodeOwner = .orbisonic
            downmixOwner = .none
            srcOwner = ledger.contains(stage: .sampleRateConversion, owner: .sourceRateConverter) ? .sourceRateConverter : .none
            rendererOwner = .sonicSphereRenderer
            formatterOwner = .danteOutputFormatter
        case .roonLivePcmCapture:
            ledger = request.product == .production
                ? liveProductionLedger(
                    sessionID: sessionID,
                    sourceID: sourceID,
                    sourceKind: .roon,
                    captureOwner: .roon,
                    captured: sourceSummary,
                    rendered: renderedSummary,
                    output: outputSummary,
                    srcOccurred: descriptor?.sampleRate.matches(request.outputRoute.sampleRate) == false
                )
                : liveMonitorLedger(
                    sessionID: sessionID,
                    sourceID: sourceID,
                    sourceKind: .roon,
                    captureOwner: .roon,
                    captured: sourceSummary,
                    monitor: stereoSummary
                )
            decodeOwner = .roon
            downmixOwner = .none
            srcOwner = ledger.contains(stage: .sampleRateConversion, owner: .sourceRateConverter) ? .sourceRateConverter : .none
            rendererOwner = request.product == .production ? .sonicSphereRenderer : .none
            formatterOwner = request.product == .production ? .danteOutputFormatter : .orbisonic
        case .spotifyStereoSource:
            ledger = request.product == .production
                ? liveProductionLedger(
                    sessionID: sessionID,
                    sourceID: sourceID,
                    sourceKind: .spotify,
                    captureOwner: .spotify,
                    captured: sourceSummary,
                    rendered: renderedSummary,
                    output: outputSummary,
                    srcOccurred: descriptor?.sampleRate.matches(request.outputRoute.sampleRate) == false
                )
                : liveMonitorLedger(
                    sessionID: sessionID,
                    sourceID: sourceID,
                    sourceKind: .spotify,
                    captureOwner: .spotify,
                    captured: sourceSummary,
                    monitor: stereoSummary
                )
            decodeOwner = .spotify
            downmixOwner = .none
            srcOwner = ledger.contains(stage: .sampleRateConversion, owner: .sourceRateConverter) ? .sourceRateConverter : .none
            rendererOwner = request.product == .production ? .sonicSphereRenderer : .none
            formatterOwner = request.product == .production ? .danteOutputFormatter : .orbisonic
        case .auxLivePcmCapture:
            ledger = request.product == .production
                ? liveProductionLedger(
                    sessionID: sessionID,
                    sourceID: sourceID,
                    sourceKind: .aux,
                    captureOwner: .orbisonic,
                    captured: sourceSummary,
                    rendered: renderedSummary,
                    output: outputSummary,
                    srcOccurred: descriptor?.sampleRate.matches(request.outputRoute.sampleRate) == false
                )
                : liveMonitorLedger(
                    sessionID: sessionID,
                    sourceID: sourceID,
                    sourceKind: .aux,
                    captureOwner: .orbisonic,
                    captured: sourceSummary,
                    monitor: stereoSummary
                )
            decodeOwner = .orbisonic
            downmixOwner = .none
            srcOwner = ledger.contains(stage: .sampleRateConversion, owner: .sourceRateConverter) ? .sourceRateConverter : .none
            rendererOwner = request.product == .production ? .sonicSphereRenderer : .none
            formatterOwner = request.product == .production ? .danteOutputFormatter : .orbisonic
        case .pureSphericalLosslessValidator:
            if request.pureSphericalLosslessState == .validForCurrentSphere {
                ledger = .pureSphericalDirect(
                    sessionID: sessionID,
                    sourceID: sourceID,
                    source: sourceSummary,
                    output: outputSummary
                )
            } else {
                ledger = AudioConversionLedger(
                    sessionID: sessionID,
                    sourceID: sourceID,
                    sourceKind: .localFile,
                    entries: [
                        AudioConversionLedgerEntry(
                            stage: .validation,
                            owner: .pureSphericalLosslessValidator,
                            input: sourceSummary,
                            output: renderedSummary,
                            isExplicit: true,
                            note: "Pure Spherical Lossless validation path"
                        )
                    ]
                )
            }
            decodeOwner = .none
            downmixOwner = .none
            srcOwner = .none
            rendererOwner = .none
            formatterOwner = ledger.contains(stage: .format, owner: .danteOutputFormatter) ? .danteOutputFormatter : .none
        case .off, .testTone:
            ledger = AudioConversionLedger(sessionID: sessionID, sourceID: sourceID, sourceKind: request.selection.kind, entries: [])
            decodeOwner = .none
            downmixOwner = .none
            srcOwner = .none
            rendererOwner = .none
            formatterOwner = .none
        }

        return PlaybackDiagnosticSnapshot(
            sessionID: sessionID,
            sourceID: sourceID,
            sourceKind: request.selection.kind,
            sourceSampleRate: descriptor?.sampleRate,
            sourceChannelCount: descriptor?.channelCount,
            decodeOwner: decodeOwner,
            downmixOwner: downmixOwner,
            sampleRateConversionOwner: srcOwner,
            rendererOwner: rendererOwner,
            outputFormatterOwner: formatterOwner,
            requestedOutputFormat: request.product == .production ? outputSummary : stereoSummary,
            actualOutputFormat: request.product == .production ? outputSummary : stereoSummary,
            routeChannelCount: request.product == .production ? request.outputRoute.channelCount : 2,
            pureSphericalLosslessState: request.pureSphericalLosslessState,
            conversionLedger: ledger
        )
    }

    private func liveMonitorLedger(
        sessionID: String,
        sourceID: String,
        sourceKind: SourceKind,
        captureOwner: AudioConversionOwner,
        captured: AudioFormatSummary,
        monitor: AudioFormatSummary
    ) -> AudioConversionLedger {
        AudioConversionLedger(
            sessionID: sessionID,
            sourceID: sourceID,
            sourceKind: sourceKind,
            entries: [
                AudioConversionLedgerEntry(
                    stage: .capture,
                    owner: captureOwner,
                    output: captured,
                    isExplicit: true,
                    note: "live PCM capture contract"
                ),
                AudioConversionLedgerEntry(
                    stage: .format,
                    owner: .orbisonic,
                    input: captured,
                    output: monitor,
                    isExplicit: true,
                    note: "local monitor output formatting"
                ),
                AudioConversionLedgerEntry(
                    stage: .routeValidation,
                    owner: .orbisonic,
                    input: monitor,
                    output: monitor,
                    isExplicit: true,
                    note: "local monitor route validation"
                )
            ]
        )
    }

    private func liveProductionLedger(
        sessionID: String,
        sourceID: String,
        sourceKind: SourceKind,
        captureOwner: AudioConversionOwner,
        captured: AudioFormatSummary,
        rendered: AudioFormatSummary,
        output: AudioFormatSummary,
        srcOccurred: Bool
    ) -> AudioConversionLedger {
        var entries: [AudioConversionLedgerEntry] = [
            AudioConversionLedgerEntry(
                stage: .capture,
                owner: captureOwner,
                output: captured,
                isExplicit: true,
                note: "live PCM capture contract"
            )
        ]

        if srcOccurred {
            entries.append(
                AudioConversionLedgerEntry(
                    stage: .sampleRateConversion,
                    owner: .sourceRateConverter,
                    input: captured,
                    output: rendered,
                    isExplicit: true,
                    note: "explicit production SRC"
                )
            )
        }

        entries.append(
            AudioConversionLedgerEntry(
                stage: .render,
                owner: .sonicSphereRenderer,
                input: captured,
                output: rendered,
                isExplicit: true,
                note: "source to SonicSphere render"
            )
        )
        entries.append(
            AudioConversionLedgerEntry(
                stage: .format,
                owner: .danteOutputFormatter,
                input: rendered,
                output: output,
                isExplicit: true,
                note: "strict Dante/output formatting"
            )
        )
        entries.append(
            AudioConversionLedgerEntry(
                stage: .routeValidation,
                owner: .productionOutputSession,
                input: output,
                output: output,
                isExplicit: true,
                note: "strict production route validation"
            )
        )

        return AudioConversionLedger(
            sessionID: sessionID,
            sourceID: sourceID,
            sourceKind: sourceKind,
            entries: entries
        )
    }
}

struct ExistingNowPlayingState: Equatable, Sendable {
    let sourceMode: SourceMode
    let preparedPath: OrbisonicAudioPath?
}

struct ExistingDiagnosticsStatusRow: Equatable, Sendable {
    let label: String
    let value: String
    let isFailure: Bool
}

struct ExistingDiagnosticsState: Equatable, Sendable {
    let snapshot: PlaybackDiagnosticSnapshot?
    let statusRows: [ExistingDiagnosticsStatusRow]
    let failureMessages: [String]

    init(snapshot: PlaybackDiagnosticSnapshot?) {
        self.snapshot = snapshot
        guard let snapshot else {
            statusRows = [
                ExistingDiagnosticsStatusRow(label: "Playback diagnostics", value: "No active source", isFailure: false)
            ]
            failureMessages = []
            return
        }

        var rows = [
            ExistingDiagnosticsStatusRow(label: "Source", value: snapshot.sourceKind.rawValue, isFailure: false),
            ExistingDiagnosticsStatusRow(
                label: "Source format",
                value: "\(snapshot.sourceChannelCount.map(String.init) ?? "unknown") ch @ \(snapshot.sourceSampleRate?.hertz.description ?? "unknown") Hz",
                isFailure: snapshot.sourceChannelCount == nil || snapshot.sourceSampleRate == nil
            ),
            ExistingDiagnosticsStatusRow(
                label: "Output format",
                value: Self.formatDescription(snapshot.actualOutputFormat),
                isFailure: snapshot.actualOutputFormat == nil
            ),
            ExistingDiagnosticsStatusRow(
                label: "Route channels",
                value: snapshot.routeChannelCount.map(String.init) ?? "unknown",
                isFailure: snapshot.routeChannelCount == nil
            ),
            ExistingDiagnosticsStatusRow(
                label: "Ledger entries",
                value: "\(snapshot.conversionLedger.entries.count)",
                isFailure: snapshot.conversionLedger.entries.isEmpty
            )
        ]

        let messages = snapshot.diagnosticMessages()
        rows.append(contentsOf: messages.map {
            ExistingDiagnosticsStatusRow(label: "Diagnostic failure", value: $0, isFailure: true)
        })

        if let pureStateMessage = Self.failureMessage(for: snapshot.pureSphericalLosslessState) {
            rows.append(ExistingDiagnosticsStatusRow(label: "Pure Spherical Lossless", value: pureStateMessage, isFailure: true))
        }

        statusRows = rows
        failureMessages = rows.filter(\.isFailure).map(\.value)
    }

    private static func formatDescription(_ format: AudioFormatSummary?) -> String {
        guard let format else { return "unknown" }
        let channelCount = format.channelCount.map(String.init) ?? "unknown"
        let sampleRate = format.sampleRate?.hertz.description ?? "unknown"
        let layout = format.layoutName ?? "unknown layout"
        return "\(channelCount) ch @ \(sampleRate) Hz, \(format.sampleFormat), \(layout)"
    }

    private static func failureMessage(for state: PureSphericalLosslessState) -> String? {
        switch state {
        case .none, .candidate, .validForCurrentSphere:
            nil
        case .validForDifferentSphere:
            "Source is valid, but not for the active sphere."
        case .routeNotReady:
            "Production output route is not ready for direct-read playback."
        case let .invalid(reason):
            reason
        }
    }
}

struct ExistingOrbisonicUIFacade: Sendable {
    private(set) var coordinator = OrbisonicAudioCoordinator2()
    private(set) var sourceMode: SourceMode = .filePlayback
    private(set) var selectedLocalFile: URL?
    private(set) var outputRouteID: String?
    private(set) var pureSphericalLosslessState: PureSphericalLosslessState = .none

    mutating func selectSource(_ sourceMode: SourceMode) throws -> PreparedSource {
        self.sourceMode = sourceMode
        return try coordinator.prepareSource(
            OrbisonicSourcePreparationRequest(
                selection: sourceSelection(for: sourceMode),
                product: .monitor,
                pureSphericalLosslessState: pureSphericalLosslessState
            )
        )
    }

    mutating func selectLocalFile(
        _ url: URL,
        product: OrbisonicPlaybackProduct = .monitor,
        pureSphericalLosslessState: PureSphericalLosslessState = .none
    ) throws -> PreparedSource {
        selectedLocalFile = url
        sourceMode = .filePlayback
        self.pureSphericalLosslessState = pureSphericalLosslessState
        return try coordinator.prepareSource(
            OrbisonicSourcePreparationRequest(
                selection: localFileSelection(url: url),
                product: product,
                pureSphericalLosslessState: pureSphericalLosslessState
            )
        )
    }

    mutating func playStopToggle() throws {
        if coordinator.isPlaying {
            coordinator.stopPlayback()
        } else {
            try coordinator.startMonitorPlayback()
        }
    }

    mutating func selectOutputRoute(_ routeID: String) {
        outputRouteID = routeID
    }

    func observeNowPlayingState() -> ExistingNowPlayingState {
        ExistingNowPlayingState(
            sourceMode: sourceMode,
            preparedPath: coordinator.preparedSource?.path
        )
    }

    func observeDiagnosticsState() -> ExistingDiagnosticsState {
        ExistingDiagnosticsState(snapshot: coordinator.currentDiagnostics())
    }

    func observePureSphericalBadge() -> PureSphericalLosslessState {
        pureSphericalLosslessState
    }

    private func sourceSelection(for sourceMode: SourceMode) -> SourceSelection {
        switch sourceMode {
        case .off:
            .off
        case .filePlayback:
            selectedLocalFile.map(localFileSelection(url:)) ?? .source(descriptor(kind: .localFile, channelCount: 2, layout: .stereo))
        case .roon:
            .source(descriptor(kind: .roon, channelCount: 2, layout: .stereo, isLive: true))
        case .spotify:
            .source(descriptor(kind: .spotify, channelCount: 2, layout: .stereo, isLive: true))
        case .aux:
            .source(descriptor(kind: .aux, channelCount: 2, layout: .stereo, isLive: true))
        case .testTone:
            .source(descriptor(kind: .testTone, channelCount: 2, layout: .stereo))
        }
    }

    private func localFileSelection(url: URL) -> SourceSelection {
        .source(
            descriptor(
                id: url.path,
                kind: .localFile,
                channelCount: 2,
                layout: .stereo,
                originalPath: url.path
            )
        )
    }

    private func descriptor(
        id: String = "ui-facade-source",
        kind: SourceKind,
        channelCount: Int,
        layout: AudioChannelLayoutDescriptor,
        isLive: Bool? = nil,
        originalPath: String? = nil
    ) -> SourceDescriptor {
        SourceDescriptor(
            id: id,
            kind: kind,
            sampleRate: .rate48000,
            channelCount: channelCount,
            layout: layout,
            isLive: isLive,
            codecDescription: kind == .localFile ? "unknown local file" : nil,
            originalPath: originalPath
        )
    }
}
