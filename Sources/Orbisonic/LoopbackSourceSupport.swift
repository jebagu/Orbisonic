import Foundation

enum OrbisonicLoopbackDevice: String, CaseIterable {
    case roonInput = "audio.orbisonic.rooninput.device"
    case spotifyInput = "audio.orbisonic.spotifyinput.device"
    case auxCable = "audio.orbisonic.auxcable.device"

    var deviceUID: String { rawValue }

    var displayName: String {
        switch self {
        case .roonInput:
            "Orbisonic Roon Input"
        case .spotifyInput:
            "Orbisonic Spotify Input"
        case .auxCable:
            "Orbisonic Aux Cable"
        }
    }

    var inputRole: InputDeviceRole {
        switch self {
        case .roonInput:
            .roonLoopback
        case .spotifyInput:
            .spotifyLoopback
        case .auxCable:
            .auxLoopback
        }
    }
}

enum InputDeviceRole: Equatable {
    case roonLoopback
    case spotifyLoopback
    case auxLoopback
    case legacyBlackHole
    case physicalInput
    case otherVirtualInput
    case unavailable
}

enum OutputRouteRisk: Equatable {
    case safe
    case feedbackLoop(String)
    case virtualOutput(String)
    case unavailable

    var blocksLiveMonitoring: Bool {
        if case .feedbackLoop = self {
            return true
        }
        return false
    }
}

enum OutputSelectionMode: Equatable {
    case none
    case systemDefault
    case device(String)

    init(storedValue: String?, defaultMode: OutputSelectionMode) {
        guard let storedValue, !storedValue.isEmpty else {
            self = defaultMode
            return
        }

        switch storedValue {
        case "none":
            self = .none
        case "system":
            self = .systemDefault
        case "automatic":
            self = defaultMode
        default:
            if storedValue.hasPrefix("device:") {
                self = .device(String(storedValue.dropFirst("device:".count)))
            } else {
                self = .device(storedValue)
            }
        }
    }

    var storedValue: String {
        switch self {
        case .none:
            "none"
        case .systemDefault:
            "system"
        case .device(let uid):
            "device:\(uid)"
        }
    }
}

enum OutputRouteSelectionPolicy {
    static func startupMonitorSelection(
        from routes: [OutputRouteInfo],
        storedSelection: OutputSelectionMode,
        systemOutput: OutputRouteInfo
    ) -> OutputSelectionMode {
        switch storedSelection {
        case .none:
            return .systemDefault
        case .systemDefault:
            return .systemDefault
        case .device(let uid):
            return routes.contains { $0.uid == uid && $0.isSelectableOutputTarget }
                ? storedSelection
                : .systemDefault
        }
    }

    static func monitorRoute(
        from routes: [OutputRouteInfo],
        selection: OutputSelectionMode,
        systemOutput: OutputRouteInfo
    ) -> OutputRouteInfo {
        switch selection {
        case .none:
            return .unavailable
        case .systemDefault:
            return systemOutput.isSelectableOutputTarget ? systemOutput : .unavailable
        case .device(let uid):
            return routes.first { $0.uid == uid && $0.isSelectableOutputTarget } ?? .unavailable
        }
    }

    static func rendererRoute(
        from routes: [OutputRouteInfo],
        selection: OutputSelectionMode,
        systemOutput: OutputRouteInfo
    ) -> OutputRouteInfo {
        switch selection {
        case .none:
            return .unavailable
        case .device(let uid):
            return routes.first { $0.uid == uid && $0.isSelectableOutputTarget } ?? .unavailable
        case .systemDefault:
            return systemOutput.isSelectableOutputTarget ? systemOutput : .unavailable
        }
    }

    static func sortedOutputRoutes(_ routes: [OutputRouteInfo]) -> [OutputRouteInfo] {
        routes.sorted { lhs, rhs in
            let lhsRank = routeSortRank(lhs)
            let rhsRank = routeSortRank(rhs)

            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }

            return lhs.deviceName.localizedStandardCompare(rhs.deviceName) == .orderedAscending
        }
    }

    private static func routeSortRank(_ route: OutputRouteInfo) -> Int {
        if !route.isAvailable {
            return 5
        }

        if route.routeRisk.blocksLiveMonitoring {
            return 4
        }

        if route.isPreferredRendererOutput {
            return 0
        }

        if route.isRendererCapableOutput {
            return route.routeRisk == .safe ? 1 : 2
        }

        return 3
    }
}

enum RendererAudioRoutingPolicy {
    static func usesDirectRendererAudio(
        renderMode: RendererRenderMode,
        activeOutputRoute: OutputRouteInfo,
        rendererOutputRoute: OutputRouteInfo,
        requiredOutputChannelCount: Int
    ) -> Bool {
        _ = renderMode
        _ = activeOutputRoute
        _ = rendererOutputRoute
        _ = requiredOutputChannelCount
        return false
    }
}

enum SourceMode: String, CaseIterable, Identifiable {
    case off = "Off"
    case roon = "Roon"
    case spotify = "Spotify"
    case aux = "Aux Cable"
    case atmosDRP = "Atmos DRP"
    case filePlayback = "Local Files"
    case testTone = "Test Tone"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .atmosDRP:
            "Atmos"
        case .filePlayback:
            "Local Music"
        case .off, .roon, .spotify, .aux, .testTone:
            rawValue
        }
    }

    var isLiveInput: Bool {
        self == .roon || self == .spotify || self == .aux || self == .atmosDRP
    }

    var startsLiveListeningOnSelection: Bool {
        isLiveInput && self != .atmosDRP
    }

    var isUserFacingMusicInput: Bool {
        self != .testTone
    }

    var ownsTransport: Bool {
        self == .filePlayback || self == .testTone || self == .atmosDRP
    }

    var expectedLoopback: OrbisonicLoopbackDevice? {
        switch self {
        case .roon:
            .roonInput
        case .spotify:
            .spotifyInput
        case .aux:
            .auxCable
        case .atmosDRP:
            AtmosDRPRoutingPolicy.captureLoopback
        case .off, .filePlayback, .testTone:
            nil
        }
    }

    var fixedLiveChannelCount: Int? {
        switch self {
        case .spotify:
            2
        case .off, .roon, .aux, .atmosDRP, .filePlayback, .testTone:
            nil
        }
    }

    var exposesRoonMetadataAndTransport: Bool {
        self == .roon
    }

    func stopsLiveCaptureWhenSwitching(to mode: SourceMode) -> Bool {
        self != mode && isLiveInput
    }

    func acceptsInputRoute(_ route: InputRouteInfo) -> Bool {
        guard let expectedLoopback else {
            return route.isAvailable
        }

        return route.uid == expectedLoopback.deviceUID
    }

    func missingLoopbackMessage() -> String {
        guard let expectedLoopback else {
            return "No live input route is required for \(displayName)."
        }

        switch self {
        case .spotify:
            return "\(expectedLoopback.displayName) is not available. Install Orbisonic Inputs with Spotify support, then restart Core Audio or reboot."
        case .atmosDRP:
            return "\(expectedLoopback.displayName) is not available. Atmos DRP uses this temporary loopback until the dedicated Atmos input exists."
        case .roon, .aux:
            return "\(expectedLoopback.displayName) is not available. Install Orbisonic Inputs, then restart Core Audio or reboot."
        case .off, .filePlayback, .testTone:
            return "No live input route is required for \(displayName)."
        }
    }

    var monitorActionLabel: String {
        switch self {
        case .off:
            "Off"
        case .roon:
            "Listen to Roon"
        case .spotify:
            "Listen to Spotify"
        case .aux:
            "Listen to Aux Cable"
        case .atmosDRP:
            "Play Atmos"
        case .filePlayback:
            "Play"
        case .testTone:
            "Play Tone"
        }
    }

    var mutedActionLabel: String {
        switch self {
        case .off:
            "Off"
        case .roon:
            "Resume Roon"
        case .spotify:
            "Resume Spotify"
        case .aux:
            "Resume Aux Cable"
        case .atmosDRP:
            "Resume Atmos"
        case .filePlayback:
            "Play"
        case .testTone:
            "Play Tone"
        }
    }

    var muteActionLabel: String {
        switch self {
        case .off:
            "Off"
        case .roon:
            "Mute Roon"
        case .spotify:
            "Mute Spotify"
        case .aux:
            "Mute Aux Cable"
        case .atmosDRP:
            "Pause Atmos"
        case .filePlayback:
            "Pause"
        case .testTone:
            "Stop Tone"
        }
    }

    var stopMonitorLabel: String {
        switch self {
        case .off:
            "Stop"
        case .roon, .spotify:
            "Stop"
        case .aux, .atmosDRP:
            "Stop"
        case .filePlayback, .testTone:
            "Stop"
        }
    }

    static var musicInputs: [SourceMode] {
        [.filePlayback, .atmosDRP, .spotify, .roon, .aux, .off]
    }
}

struct SourceSwitchRequestState {
    private(set) var isProcessing = false
    private(set) var pendingMode: SourceMode?

    mutating func request(_ mode: SourceMode) -> Bool {
        pendingMode = mode
        guard !isProcessing else { return false }
        isProcessing = true
        return true
    }

    mutating func takeNext() -> SourceMode? {
        guard let mode = pendingMode else {
            isProcessing = false
            return nil
        }

        pendingMode = nil
        return mode
    }

    mutating func coalescePending(over mode: SourceMode) -> SourceMode {
        guard let pendingMode else { return mode }
        self.pendingMode = nil
        return pendingMode
    }

    mutating func reset() {
        isProcessing = false
        pendingMode = nil
    }
}

enum LiveMonitorState: Equatable {
    case stopped
    case monitoring
    case muted
    case silent
    case unavailable(String)
    case error(String)

    var isCapturing: Bool {
        switch self {
        case .monitoring, .muted, .silent:
            true
        case .stopped, .unavailable, .error:
            false
        }
    }

    var isMuted: Bool {
        if case .muted = self {
            return true
        }
        return false
    }

    var statusLabel: String {
        switch self {
        case .stopped:
            "Stopped"
        case .monitoring:
            "Playing"
        case .muted:
            "Muted"
        case .silent:
            "No audio"
        case .unavailable:
            "Unavailable"
        case .error:
            "Error"
        }
    }
}

enum LiveAudioSignalState: String, Equatable {
    case unknown
    case receiving
    case briefSilence
    case silentPassage
    case noSignal

    var isRecentlyReceiving: Bool {
        switch self {
        case .receiving, .briefSilence, .silentPassage:
            true
        case .unknown, .noSignal:
            false
        }
    }
}

enum LiveLoopbackDiagnosticSeverity: String, Equatable {
    case idle
    case healthy
    case waiting
    case warning
    case error
}

struct LiveLoopbackDiagnosticSnapshot: Equatable {
    let severity: LiveLoopbackDiagnosticSeverity
    let expectedDeviceName: String
    let selectedDeviceName: String
    let routeStatus: String
    let sampleRateStatus: String
    let channelStatus: String
    let signalStatus: String
    let bufferStatus: String
    let permissionStatus: String
    let playerActivityStatus: String
    let summary: String

    var logSummary: String {
        [
            "summary=\(summary)",
            "route=\(routeStatus)",
            "sampleRate=\(sampleRateStatus)",
            "channels=\(channelStatus)",
            "signal=\(signalStatus)",
            "buffer=\(bufferStatus)",
            "permission=\(permissionStatus)",
            "player=\(playerActivityStatus)"
        ].joined(separator: "; ")
    }
}

struct LiveLoopbackBufferDiagnostic: Equatable {
    let minimumBufferedFrames: Int
    let maximumBufferedFrames: Int
    let targetLatencyFrames: Int
    let isPriming: Bool
    let underflowCount: Int
    let underflowFrames: Int
    let overflowDropFrames: Int
}

enum LiveLoopbackDiagnostics {
    static func snapshot(
        sourceMode: SourceMode,
        inputRoute: InputRouteInfo,
        availableInputRoutes: [InputRouteInfo],
        activeChannelCount: Int,
        signalState: LiveAudioSignalState,
        silenceDuration: Int?,
        bufferDiagnostic: LiveLoopbackBufferDiagnostic?,
        sampleRateMismatchText: String?,
        permissionStatusText: String,
        playerActivityText: String
    ) -> LiveLoopbackDiagnosticSnapshot {
        guard sourceMode.isLiveInput, let expectedLoopback = sourceMode.expectedLoopback else {
            return LiveLoopbackDiagnosticSnapshot(
                severity: .idle,
                expectedDeviceName: "None",
                selectedDeviceName: inputRoute.isAvailable ? inputRoute.displayName : "Unavailable",
                routeStatus: "No live input route required.",
                sampleRateStatus: "No live sample-rate check required.",
                channelStatus: "No live channel check required.",
                signalStatus: "No live loopback capture selected.",
                bufferStatus: bufferDiagnostic.map(bufferStatusText) ?? "No live buffer status available.",
                permissionStatus: permissionStatusText,
                playerActivityStatus: playerActivityText,
                summary: "No live loopback capture selected."
            )
        }

        let expectedDeviceName = expectedLoopback.displayName
        let selectedDeviceName = inputRoute.isAvailable ? inputRoute.displayName : "Unavailable"
        let routeStatus = routeStatusText(
            sourceMode: sourceMode,
            expectedLoopback: expectedLoopback,
            inputRoute: inputRoute,
            availableInputRoutes: availableInputRoutes
        )
        let sampleRateStatus = trimmed(sampleRateMismatchText) ?? "Sample rates aligned or not applicable."
        let channelStatus = channelStatusText(
            expectedDeviceName: expectedDeviceName,
            inputRoute: inputRoute,
            activeChannelCount: activeChannelCount
        )
        let signalStatus = signalStatusText(
            expectedDeviceName: expectedDeviceName,
            signalState: signalState,
            silenceDuration: silenceDuration
        )
        let bufferStatus = bufferDiagnostic.map(bufferStatusText) ?? "No live buffer status available."
        let permissionStatus = permissionStatusText
        let playerActivityStatus = playerActivityText

        let routeProblem = routeProblemSeverity(
            sourceMode: sourceMode,
            expectedLoopback: expectedLoopback,
            inputRoute: inputRoute,
            availableInputRoutes: availableInputRoutes
        )
        let channelProblem = channelProblemSeverity(inputRoute: inputRoute, activeChannelCount: activeChannelCount)
        let permissionProblem = permissionProblemSeverity(permissionStatusText)
        let hasSampleRateMismatch = trimmed(sampleRateMismatchText) != nil
        let hasBufferCounters = (bufferDiagnostic?.underflowCount ?? 0) > 0 || (bufferDiagnostic?.overflowDropFrames ?? 0) > 0

        let severity: LiveLoopbackDiagnosticSeverity
        let summary: String
        if let routeProblem {
            severity = routeProblem
            summary = routeStatus
        } else if let channelProblem {
            severity = channelProblem
            summary = channelStatus
        } else if let permissionProblem {
            severity = permissionProblem
            summary = "macOS input permission is \(permissionStatusText). Loopback capture may be blocked."
        } else if hasSampleRateMismatch {
            severity = .warning
            summary = sampleRateStatus
        } else {
            switch signalState {
            case .receiving:
                severity = hasBufferCounters ? .warning : .healthy
                summary = hasBufferCounters ? "Live buffer underflow/drop counters are non-zero." : "Capturing \(expectedDeviceName)."
            case .briefSilence:
                severity = hasBufferCounters ? .warning : .healthy
                summary = hasBufferCounters ? "Live buffer underflow/drop counters are non-zero." : "\(expectedDeviceName) is briefly silent after recent audio."
            case .silentPassage:
                severity = hasBufferCounters ? .warning : .waiting
                summary = hasBufferCounters ? "Live buffer underflow/drop counters are non-zero." : "\(expectedDeviceName) is in a silent passage."
            case .noSignal:
                severity = .warning
                summary = "\(signalStatus) \(playerActivityStatus)"
            case .unknown:
                severity = hasBufferCounters ? .warning : .waiting
                summary = hasBufferCounters ? "Live buffer underflow/drop counters are non-zero." : signalStatus
            }
        }

        return LiveLoopbackDiagnosticSnapshot(
            severity: severity,
            expectedDeviceName: expectedDeviceName,
            selectedDeviceName: selectedDeviceName,
            routeStatus: routeStatus,
            sampleRateStatus: sampleRateStatus,
            channelStatus: channelStatus,
            signalStatus: signalStatus,
            bufferStatus: bufferStatus,
            permissionStatus: permissionStatus,
            playerActivityStatus: playerActivityStatus,
            summary: summary
        )
    }

    private static func routeStatusText(
        sourceMode: SourceMode,
        expectedLoopback: OrbisonicLoopbackDevice,
        inputRoute: InputRouteInfo,
        availableInputRoutes: [InputRouteInfo]
    ) -> String {
        if sourceMode.acceptsInputRoute(inputRoute) {
            return "Selected input matches \(expectedLoopback.displayName)."
        }

        if !expectedLoopbackIsAvailable(expectedLoopback, inputRoute: inputRoute, availableInputRoutes: availableInputRoutes) {
            return "Missing expected input: \(expectedLoopback.displayName)."
        }

        guard inputRoute.isAvailable else {
            return "Selected input unavailable: expected \(expectedLoopback.displayName)."
        }

        return "Wrong input selected: expected \(expectedLoopback.displayName) but selected \(inputRoute.displayName)."
    }

    private static func channelStatusText(
        expectedDeviceName: String,
        inputRoute: InputRouteInfo,
        activeChannelCount: Int
    ) -> String {
        guard inputRoute.isAvailable else {
            return "No selected input channels for \(expectedDeviceName)."
        }
        guard inputRoute.inputChannelCount > 0 else {
            return "\(inputRoute.displayName) exposes no input channels."
        }
        guard activeChannelCount <= inputRoute.inputChannelCount else {
            return "Active live channel request is \(activeChannelCount), but \(inputRoute.displayName) exposes \(inputRoute.inputChannelCount) input channels."
        }
        return "Active live channel request is \(activeChannelCount) of \(inputRoute.inputChannelCount) input channels."
    }

    private static func signalStatusText(
        expectedDeviceName: String,
        signalState: LiveAudioSignalState,
        silenceDuration: Int?
    ) -> String {
        switch signalState {
        case .receiving:
            return "Signal present from \(expectedDeviceName)."
        case .briefSilence:
            return "\(expectedDeviceName) is briefly silent after recent audio."
        case .silentPassage:
            if let silenceDuration {
                return "\(expectedDeviceName) is in a silent passage (\(silenceDuration)s)."
            }
            return "\(expectedDeviceName) is in a silent passage."
        case .noSignal:
            if let silenceDuration {
                return "No captured audio from \(expectedDeviceName) after \(silenceDuration)s."
            }
            return "No captured audio from \(expectedDeviceName)."
        case .unknown:
            return "Waiting for captured audio from \(expectedDeviceName)."
        }
    }

    private static func bufferStatusText(_ status: LiveLoopbackBufferDiagnostic) -> String {
        let mode = status.isPriming ? "priming" : "locked"
        return "mode=\(mode), bufferedFrames=\(status.minimumBufferedFrames)-\(status.maximumBufferedFrames), targetFrames=\(status.targetLatencyFrames), underflows=\(status.underflowCount), underflowFrames=\(status.underflowFrames), droppedFrames=\(status.overflowDropFrames)"
    }

    private static func routeProblemSeverity(
        sourceMode: SourceMode,
        expectedLoopback: OrbisonicLoopbackDevice,
        inputRoute: InputRouteInfo,
        availableInputRoutes: [InputRouteInfo]
    ) -> LiveLoopbackDiagnosticSeverity? {
        guard !sourceMode.acceptsInputRoute(inputRoute) else { return nil }
        if !inputRoute.isAvailable {
            return .error
        }
        if expectedLoopbackIsAvailable(expectedLoopback, inputRoute: inputRoute, availableInputRoutes: availableInputRoutes) {
            return .warning
        }
        return .error
    }

    private static func channelProblemSeverity(
        inputRoute: InputRouteInfo,
        activeChannelCount: Int
    ) -> LiveLoopbackDiagnosticSeverity? {
        guard inputRoute.isAvailable else { return .error }
        guard inputRoute.inputChannelCount > 0 else { return .error }
        guard activeChannelCount <= inputRoute.inputChannelCount else { return .error }
        return nil
    }

    private static func permissionProblemSeverity(_ permissionStatusText: String) -> LiveLoopbackDiagnosticSeverity? {
        let normalized = permissionStatusText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "denied" || normalized == "restricted" {
            return .error
        }
        return nil
    }

    private static func expectedLoopbackIsAvailable(
        _ expectedLoopback: OrbisonicLoopbackDevice,
        inputRoute: InputRouteInfo,
        availableInputRoutes: [InputRouteInfo]
    ) -> Bool {
        inputRoute.uid == expectedLoopback.deviceUID ||
            availableInputRoutes.contains { $0.uid == expectedLoopback.deviceUID }
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}

enum DanteSafetyPolicy {
    static func requiresHighRateChannelWarning(outputChannelCount: Int, sampleRate: Double) -> Bool {
        guard outputChannelCount > 16 else { return false }
        return sampleRate >= 176_400
    }
}
