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
        guard renderMode.usesDirectRendererAudio,
              requiredOutputChannelCount > 0,
              activeOutputRoute.isAvailable,
              rendererOutputRoute.isAvailable,
              rendererOutputRoute.isRendererCapableOutput,
              rendererOutputRoute.outputChannelCount >= requiredOutputChannelCount
        else {
            return false
        }

        return activeOutputRoute.uid == rendererOutputRoute.uid
            || activeOutputRoute.deviceID == rendererOutputRoute.deviceID
    }
}

enum SourceMode: String, CaseIterable, Identifiable {
    case roon = "Roon"
    case spotify = "Spotify"
    case aux = "Aux Cable"
    case filePlayback = "Local Files"
    case testTone = "Test Tone"

    var id: String { rawValue }

    var isLiveInput: Bool {
        self == .roon || self == .spotify || self == .aux
    }

    var isUserFacingMusicInput: Bool {
        self != .testTone
    }

    var ownsTransport: Bool {
        self == .filePlayback || self == .testTone
    }

    var expectedLoopback: OrbisonicLoopbackDevice? {
        switch self {
        case .roon:
            .roonInput
        case .spotify:
            .spotifyInput
        case .aux:
            .auxCable
        case .filePlayback, .testTone:
            nil
        }
    }

    var fixedLiveChannelCount: Int? {
        switch self {
        case .spotify:
            2
        case .roon, .aux, .filePlayback, .testTone:
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
            return "No live input route is required for \(rawValue)."
        }

        switch self {
        case .spotify:
            return "\(expectedLoopback.displayName) is not available. Install Orbisonic Inputs with Spotify support, then restart Core Audio or reboot."
        case .roon, .aux:
            return "\(expectedLoopback.displayName) is not available. Install Orbisonic Inputs, then restart Core Audio or reboot."
        case .filePlayback, .testTone:
            return "No live input route is required for \(rawValue)."
        }
    }

    var monitorActionLabel: String {
        switch self {
        case .roon:
            "Monitor Roon"
        case .spotify:
            "Monitor Spotify"
        case .aux:
            "Monitor Aux Cable"
        case .filePlayback:
            "Play"
        case .testTone:
            "Play Tone"
        }
    }

    var mutedActionLabel: String {
        switch self {
        case .roon:
            "Resume Roon"
        case .spotify:
            "Resume Spotify"
        case .aux:
            "Resume Aux Cable"
        case .filePlayback:
            "Play"
        case .testTone:
            "Play Tone"
        }
    }

    var muteActionLabel: String {
        switch self {
        case .roon:
            "Mute Roon"
        case .spotify:
            "Mute Spotify"
        case .aux:
            "Mute Aux Cable"
        case .filePlayback:
            "Pause"
        case .testTone:
            "Stop Tone"
        }
    }

    var stopMonitorLabel: String {
        switch self {
        case .roon, .spotify:
            "Stop Monitor"
        case .aux:
            "Stop Monitor"
        case .filePlayback, .testTone:
            "Stop"
        }
    }

    static var musicInputs: [SourceMode] {
        [.roon, .spotify, .aux, .filePlayback]
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
            "STOPPED"
        case .monitoring:
            "MONITORING"
        case .muted:
            "MUTED"
        case .silent:
            "SILENT"
        case .unavailable:
            "MISSING"
        case .error:
            "ERROR"
        }
    }
}

enum DanteSafetyPolicy {
    static func requiresHighRateChannelWarning(outputChannelCount: Int, sampleRate: Double) -> Bool {
        guard outputChannelCount > 16 else { return false }
        return sampleRate >= 176_400
    }
}
