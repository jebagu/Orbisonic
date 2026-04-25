import Foundation

enum OrbisonicLoopbackDevice: String, CaseIterable {
    case roonInput = "audio.orbisonic.rooninput.device"
    case auxCable = "audio.orbisonic.auxcable.device"

    var deviceUID: String { rawValue }

    var displayName: String {
        switch self {
        case .roonInput:
            "Orbisonic Roon Input"
        case .auxCable:
            "Orbisonic Aux Cable"
        }
    }
}

enum InputDeviceRole: Equatable {
    case roonLoopback
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

enum SourceMode: String, CaseIterable, Identifiable {
    case roon = "Roon"
    case aux = "Aux"
    case filePlayback = "Local Files"
    case testTone = "Test Tone"

    var id: String { rawValue }

    var isLiveInput: Bool {
        self == .roon || self == .aux
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
        case .aux:
            .auxCable
        case .filePlayback, .testTone:
            nil
        }
    }

    var monitorActionLabel: String {
        switch self {
        case .roon:
            "Monitor Roon"
        case .aux:
            "Monitor Aux"
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
        case .aux:
            "Resume Aux"
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
        case .aux:
            "Mute Aux"
        case .filePlayback:
            "Pause"
        case .testTone:
            "Stop Tone"
        }
    }

    var stopMonitorLabel: String {
        switch self {
        case .roon:
            "Stop Monitor"
        case .aux:
            "Stop Monitor"
        case .filePlayback, .testTone:
            "Stop"
        }
    }

    static var musicInputs: [SourceMode] {
        [.roon, .aux, .filePlayback]
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
            "READY"
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
