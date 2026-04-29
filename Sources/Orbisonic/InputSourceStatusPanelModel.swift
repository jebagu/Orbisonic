import Foundation

struct InputSourceStatusRow: Identifiable, Equatable {
    let title: String
    let value: String

    var id: String { title }
}

struct InputSourceStatusSection: Identifiable, Equatable {
    let title: String
    let rows: [InputSourceStatusRow]

    var id: String { title }
}

struct InputSourceStatusPanel: Equatable {
    let status: String
    let headline: String
    let body: String
    let rows: [InputSourceStatusRow]
    let sections: [InputSourceStatusSection]

    init(
        status: String,
        headline: String,
        body: String,
        rows: [InputSourceStatusRow] = [],
        sections: [InputSourceStatusSection] = []
    ) {
        self.status = status
        self.headline = headline
        self.body = body
        self.sections = sections
        self.rows = rows.isEmpty ? sections.flatMap(\.rows) : rows
    }
}

enum InputSourceStatusText {
    static let roonInstruction = "Open Roon and make sure Orbisonic is authorized, then start playback."
    static let spotifyInstruction = "Open Spotify, use Spotify Connect to select Orbisonic, then control playback from Spotify."
    static let auxInstruction = "Select Orbisonic Aux Cable as the output device in Ableton Live, QLab, SPAT Revolution, GarageBand, or another app."
}

private struct InputSourceStatusLogSnapshot {
    let prefix: String
    let fields: [(name: String, value: String)]

    var message: String {
        let fieldText = fields
            .map { "\($0.name)=\(Self.quote($0.value))" }
            .joined(separator: " ")
        return "\(prefix) \(fieldText)"
    }

    var signature: String {
        let signatureFields = fields
            .filter { $0.name != "reasonForUpdate" && $0.name != "silenceDuration" }
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "|")
        return "\(prefix)|\(signatureFields)"
    }

    private static func quote(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "'").replacingOccurrences(of: "\n", with: " "))\""
    }
}

extension OrbisonicViewModel {
    var inputSourceStatusPanel: InputSourceStatusPanel {
        if let sourceSwitchStatusText {
            return InputSourceStatusPanel(
                status: sourceSwitchStatusText,
                headline: sourceSwitchStatusText,
                body: sourceSwitchStatusText == "Stopping audio..."
                    ? "Orbisonic is ramping down before stopping the active audio path."
                    : "Orbisonic is ramping down before changing the active audio path.",
                rows: rowsForSelectedInputSource()
            )
        }

        switch sourceMode {
        case .off:
            return InputSourceStatusPanel(
                status: "Orbisonic is idle",
                headline: "Orbisonic is idle",
                body: "Select a source to begin listening or playback."
            )
        case .roon:
            return roonInputSourceStatusPanel()
        case .spotify:
            return spotifyInputSourceStatusPanel()
        case .aux:
            return auxInputSourceStatusPanel()
        case .filePlayback:
            return InputSourceStatusPanel(
                status: "Local Music",
                headline: "Use the Local Music tab to play music.",
                body: ""
            )
        case .testTone:
            return InputSourceStatusPanel(
                status: isTestTonePlaying ? "Playing through Orbisonic" : "Ready",
                headline: "Diagnostics source is selected.",
                body: "Test tones remain available for diagnostics.",
                rows: [
                    InputSourceStatusRow(title: "Diagnostics", value: testToneStatus.isEmpty ? "Ready" : testToneStatus)
                ]
            )
        }
    }

    func logInputSourceStatusIfNeeded(reason: String, force: Bool = false) {
        guard let snapshot = inputSourceStatusLogSnapshot(reasonForUpdate: reason) else { return }
        guard force || snapshot.signature != lastLoggedInputSourceStatusSignature else { return }

        lastLoggedInputSourceStatusSignature = snapshot.signature
        AppLogger.shared.debug(category: "input-status", snapshot.message)
    }

    var inputSourceDiagnosticsRows: [InputSourceStatusRow] {
        switch sourceMode {
        case .roon:
            return [
                InputSourceStatusRow(title: "Roon endpoint raw state", value: roonEndpointStatusValue),
                InputSourceStatusRow(title: "Roon connection raw state", value: roonConnectionStatusValue),
                InputSourceStatusRow(title: "Roon zone", value: roonZoneStatusValue),
                InputSourceStatusRow(title: "Roon playback raw state", value: roonStreamStatusValue),
                InputSourceStatusRow(title: "Roon signal raw state", value: roonAudioSignalStatusValue),
                InputSourceStatusRow(title: "Roon metadata", value: roonNowPlayingStatusValue)
            ]
        case .spotify:
            return [
                InputSourceStatusRow(title: "Spotify receiver raw state", value: spotifyReceiverStatusValue),
                InputSourceStatusRow(title: "Spotify discovery raw state", value: spotifyConnectDiscoveryStatusValue),
                InputSourceStatusRow(title: "Spotify session raw state", value: spotifyConnectSessionStatusValue),
                InputSourceStatusRow(title: "Spotify signal raw state", value: spotifyAudioSignalStatusValue),
                InputSourceStatusRow(title: "Spotify metadata", value: spotifyNowPlayingStatusValue)
            ]
        case .aux:
            return [
                InputSourceStatusRow(title: "Aux virtual sound card", value: auxVirtualSoundCardStatusValue),
                InputSourceStatusRow(title: "Aux raw input format", value: auxInputFormatStatusValue),
                InputSourceStatusRow(title: "Aux raw signal", value: auxAudioSignalStatusValue),
                InputSourceStatusRow(title: "Aux active channels", value: auxActiveChannelsStatusValue ?? "Unknown")
            ]
        case .off, .filePlayback, .testTone:
            return []
        }
    }

    private func inputSourceStatusLogSnapshot(reasonForUpdate: String) -> InputSourceStatusLogSnapshot? {
        switch sourceMode {
        case .roon:
            return InputSourceStatusLogSnapshot(
                prefix: "[input-status:roon]",
                fields: [
                    ("endpointRunning", runningLogValue(for: roonEndpointStatusValue)),
                    ("discoveryState", roonDiscoveryStatusValue),
                    ("streamState", roonStreamStatusValue),
                    ("audioSignalState", roonAudioSignalStatusValue),
                    ("playbackState", roonPlaybackStateLogValue),
                    ("nowPlaying", roonNowPlayingStatusValue),
                    ("silenceDuration", liveAudioSignalSilenceDurationLogValue),
                    ("activeSource", sourceMode.rawValue),
                    ("uiLabelShown", inputSourceStatusPanel.status),
                    ("reasonForUpdate", reasonForUpdate),
                    ("error", roonInputStatusErrorValue)
                ]
            )
        case .spotify:
            return InputSourceStatusLogSnapshot(
                prefix: "[input-status:spotify]",
                fields: [
                    ("receiverRunning", runningLogValue(for: spotifyReceiverStatusValue)),
                    ("discoveryState", spotifyConnectDiscoveryStatusValue),
                    ("connectSessionState", spotifyConnectSessionStatusValue),
                    ("audioSignalState", spotifyAudioSignalStatusValue),
                    ("playbackState", spotifyPlaybackStatusValue),
                    ("nowPlaying", spotifyNowPlayingStatusValue),
                    ("silenceDuration", liveAudioSignalSilenceDurationLogValue),
                    ("activeSource", sourceMode.rawValue),
                    ("uiLabelShown", inputSourceStatusPanel.status),
                    ("reasonForUpdate", reasonForUpdate),
                    ("error", spotifyInputStatusErrorValue)
                ]
            )
        case .aux:
            return InputSourceStatusLogSnapshot(
                prefix: "[input-status:aux]",
                fields: [
                    ("virtualDeviceAvailable", availabilityLogValue(for: auxVirtualSoundCardStatusValue)),
                    ("channelCount", auxChannelCountLogValue),
                    ("audioSignalState", auxAudioSignalStatusValue),
                    ("activeChannels", auxActiveChannelsStatusValue ?? "Unknown"),
                    ("playbackState", "Not applicable"),
                    ("silenceDuration", liveAudioSignalSilenceDurationLogValue),
                    ("activeSource", sourceMode.rawValue),
                    ("uiLabelShown", inputSourceStatusPanel.status),
                    ("reasonForUpdate", reasonForUpdate),
                    ("error", liveMonitorStatusErrorValue)
                ]
            )
        case .off, .filePlayback, .testTone:
            return nil
        }
    }

    private func rowsForSelectedInputSource() -> [InputSourceStatusRow] {
        switch sourceMode {
        case .off:
            return []
        case .roon:
            return roonInputStatusSections().flatMap(\.rows)
        case .spotify:
            return spotifyInputStatusSections().flatMap(\.rows)
        case .aux:
            return auxInputStatusSections().flatMap(\.rows)
        case .filePlayback:
            return []
        case .testTone:
            return [
                InputSourceStatusRow(title: "Diagnostics", value: testToneStatus.isEmpty ? "Ready" : testToneStatus)
            ]
        }
    }

    private func roonInputSourceStatusPanel() -> InputSourceStatusPanel {
        let headline: String
        if roonInputIsUnavailable {
            headline = "Roon input is unavailable"
        } else if roonNeedsServerOrAuthorization {
            headline = "Waiting for Roon"
        } else if roonHasReceivingAudio {
            headline = "Receiving Roon audio"
        } else if roonPlaybackIsPaused {
            headline = "Roon is paused"
        } else if roonPlaybackIsActive {
            headline = "Waiting for Roon audio"
        } else {
            headline = "Waiting for Roon"
        }

        let body: String
        if roonInputIsUnavailable {
            body = "Open Diagnostics for setup details."
        } else if roonNeedsServerOrAuthorization {
            body = "Open Roon and make sure Orbisonic is authorized."
        } else if roonHasReceivingAudio {
            body = ""
        } else if roonPlaybackIsPaused {
            body = "Use Roon's player controls to resume."
        } else if roonPlaybackIsActive {
            body = "Make sure Roon is playing to Orbisonic."
        } else {
            body = InputSourceStatusText.roonInstruction
        }

        return InputSourceStatusPanel(
            status: headline,
            headline: headline,
            body: body,
            sections: roonInputStatusSections()
        )
    }

    private func spotifyInputSourceStatusPanel() -> InputSourceStatusPanel {
        let headline: String
        if spotifyHasReceivingAudio {
            headline = "Receiving Spotify audio"
        } else if spotifySetupIsUnavailable {
            headline = "Spotify Connect is unavailable"
        } else if spotifyReceiverStatusValue == "Starting" {
            headline = "Spotify Connect is starting"
        } else if !spotifyIsSelectedInApp {
            headline = "Open Spotify and choose Orbisonic"
        } else if spotifyPlaybackStatusValue == "Paused" {
            headline = "Spotify is paused"
        } else if spotifyNowPlayingForStatus != nil {
            headline = "Spotify is connected - waiting for audio"
        } else {
            headline = "Open Spotify and choose Orbisonic"
        }

        let body: String
        if spotifyHasReceivingAudio {
            body = ""
        } else if spotifySetupIsUnavailable {
            body = "Open Diagnostics for setup details."
        } else if spotifyReceiverStatusValue == "Starting" {
            body = "Spotify Connect is starting. Try Spotify again in a moment."
        } else if !spotifyIsSelectedInApp {
            body = "In Spotify, select Orbisonic from the devices menu."
        } else if spotifyPlaybackStatusValue == "Paused" {
            body = "Resume playback in Spotify."
        } else {
            body = "Start playback in Spotify."
        }

        return InputSourceStatusPanel(
            status: headline,
            headline: headline,
            body: body,
            sections: spotifyInputStatusSections()
        )
    }

    private func auxInputSourceStatusPanel() -> InputSourceStatusPanel {
        let headline: String
        if inputStatusSelectedLiveSourceUnavailable || liveInputReadyValue(expected: .auxCable) == "Missing" {
            headline = "Aux input unavailable"
        } else {
            headline = liveAudioSignalState.isRecentlyReceiving || liveMonitorState == .monitoring
                ? "Receiving Aux audio"
                : "Waiting for Aux audio"
        }

        let body: String
        if inputStatusSelectedLiveSourceUnavailable || liveInputReadyValue(expected: .auxCable) == "Missing" {
            body = "Open Diagnostics for setup details."
        } else {
            body = liveAudioSignalState.isRecentlyReceiving || liveMonitorState == .monitoring
                ? ""
                : InputSourceStatusText.auxInstruction
        }

        return InputSourceStatusPanel(
            status: headline,
            headline: headline,
            body: body,
            sections: auxInputStatusSections()
        )
    }

    private func roonInputStatusSections() -> [InputSourceStatusSection] {
        [
            InputSourceStatusSection(
                title: "Orbisonic setup",
                rows: [
                    InputSourceStatusRow(title: "Roon input", value: roonInputUserStatusValue),
                    InputSourceStatusRow(title: "Roon server", value: roonServerUserStatusValue)
                ]
            ),
            InputSourceStatusSection(
                title: "Roon app",
                rows: [
                    InputSourceStatusRow(title: "Playback", value: roonPlaybackUserStatusValue),
                    InputSourceStatusRow(title: "Audio", value: roonAudioUserStatusValue),
                    InputSourceStatusRow(title: "Now playing", value: roonNowPlayingUserStatusValue)
                ]
            )
        ]
    }

    private func spotifyInputStatusSections() -> [InputSourceStatusSection] {
        [
            InputSourceStatusSection(
                title: "Orbisonic setup",
                rows: [
                    InputSourceStatusRow(title: "Spotify Connect", value: spotifySetupUserStatusValue)
                ]
            ),
            InputSourceStatusSection(
                title: "Spotify app",
                rows: [
                    InputSourceStatusRow(title: "Connection", value: spotifyConnectionUserStatusValue),
                    InputSourceStatusRow(title: "Audio", value: spotifyAudioUserStatusValue),
                    InputSourceStatusRow(title: "Now playing", value: spotifyNowPlayingUserStatusValue)
                ]
            )
        ]
    }

    private func auxInputStatusSections() -> [InputSourceStatusSection] {
        var rows = [
            InputSourceStatusRow(title: "Aux Cable", value: auxCableUserStatusValue),
            InputSourceStatusRow(title: "Input", value: auxInputFormatStatusValue),
            InputSourceStatusRow(title: "Audio", value: auxAudioUserStatusValue)
        ]
        if let activeChannels = auxActiveChannelsStatusValue {
            rows.append(InputSourceStatusRow(title: "Active channels", value: activeChannels))
        }
        return [InputSourceStatusSection(title: "Aux source", rows: rows)]
    }

    private var roonEndpointStatusValue: String {
        if case .error = liveMonitorState {
            return "Error"
        }
        if sourceSwitchStatusText != nil || isLiveMonitorTransitioning {
            return "Starting"
        }
        if liveInputReadyValue(expected: .roonInput) == "Missing" {
            return "Stopped"
        }
        return "Running"
    }

    private var roonDiscoveryStatusValue: String {
        roonConnectionStatusValue
    }

    private var roonConnectionStatusValue: String {
        if roonBridgeSnapshot.ok, roonBridgeSnapshot.core != nil {
            return "Connected to Roon Server"
        }

        switch roonBridgeSnapshot.bridge.state {
        case "waiting_for_authorization":
            return "Waiting for Roon authorization"
        case "waiting_for_zone":
            return roonBridgeSnapshot.ok ? "Connected, waiting for Orbisonic Zone" : "Waiting for Roon Server"
        case "starting":
            return "Starting"
        case "offline", "unpaired":
            return "Waiting for Roon Server"
        case "missing_dependencies", "missing_node", "error":
            return "Unknown"
        default:
            return roonBridgeSnapshot.ok ? "Connected to Roon Server" : "Waiting for Roon Server"
        }
    }

    private var roonZoneStatusValue: String {
        if let selectedZone = roonBridgeSnapshot.selectedZone {
            return selectedZone.displayName.trimmedNilIfBlank ?? "Orbisonic audio Zone"
        }
        if roonBridgeSnapshot.ok {
            return "Waiting for Orbisonic audio Zone"
        }
        return "Unknown"
    }

    private var roonInputIsUnavailable: Bool {
        inputStatusSelectedLiveSourceUnavailable || liveInputReadyValue(expected: .roonInput) == "Missing"
    }

    private var roonHasReceivingAudio: Bool {
        liveAudioSignalState.isRecentlyReceiving || liveMonitorState == .monitoring
    }

    private var roonNeedsServerOrAuthorization: Bool {
        switch roonBridgeSnapshot.bridge.state {
        case "waiting_for_authorization", "waiting_for_zone", "offline", "unpaired", "starting":
            return !roonBridgeSnapshot.isReadyForTransport
        default:
            return !roonBridgeSnapshot.ok && !roonBridgeSnapshot.isReadyForTransport
        }
    }

    private var roonInputUserStatusValue: String {
        switch roonEndpointStatusValue {
        case "Running":
            return "Ready"
        case "Starting":
            return "Starting"
        case "Stopped":
            return "Unavailable"
        case "Error":
            return "Error"
        default:
            return "Unavailable"
        }
    }

    private var roonServerUserStatusValue: String {
        if roonBridgeSnapshot.ok, roonBridgeSnapshot.core != nil {
            return "Connected"
        }

        switch roonBridgeSnapshot.bridge.state {
        case "waiting_for_authorization":
            return "Waiting for authorization"
        case "starting":
            return "Starting"
        default:
            return "Waiting for Roon Server"
        }
    }

    private var roonPlaybackUserStatusValue: String {
        if roonPlaybackIsActive {
            return "Playing"
        }
        if roonPlaybackIsPaused {
            return "Paused"
        }
        return "Waiting"
    }

    private var roonAudioUserStatusValue: String {
        switch liveAudioSignalState {
        case .receiving, .briefSilence, .silentPassage:
            return roonPlaybackIsPaused ? "Waiting for audio" : "Receiving"
        case .noSignal:
            return roonPlaybackIsActive ? "No signal" : "Waiting for audio"
        case .unknown:
            break
        }

        switch liveMonitorState {
        case .monitoring:
            return "Receiving"
        case .silent:
            return roonPlaybackIsActive ? "No signal" : "Waiting for audio"
        case .muted:
            return "Waiting for audio"
        case .stopped, .unavailable, .error:
            return "Waiting for audio"
        }
    }

    private var roonNowPlayingUserStatusValue: String {
        let value = roonNowPlayingStatusValue
        return value == "No metadata" ? "No metadata yet" : value
    }

    private var roonStreamStatusValue: String {
        if roonPlaybackIsActive {
            return "Active"
        }
        if roonPlaybackIsPaused {
            return "Paused"
        }
        if roonBridgeSnapshot.selectedZone != nil || roonNowPlaying != nil || roonBridgeSnapshot.ok {
            return "Waiting"
        }
        return "Unknown"
    }

    private var roonAudioSignalStatusValue: String {
        switch liveAudioSignalState {
        case .receiving:
            return "Receiving"
        case .briefSilence:
            return "Brief silence"
        case .silentPassage:
            return roonPlaybackIsPaused ? "Silent" : "Silent passage"
        case .noSignal:
            return roonPlaybackIsActive ? "No signal while Roon is playing" : "No signal"
        case .unknown:
            break
        }

        switch liveMonitorState {
        case .silent:
            return "No signal"
        case .muted:
            return "Silent"
        case .monitoring:
            return "Receiving"
        case .stopped, .unavailable, .error:
            return "Unknown"
        }
    }

    private var roonNowPlayingStatusValue: String {
        if let title = roonTransportTitleText?.trimmedNilIfBlank {
            if let subtitle = roonTransportSubtitleText?.trimmedNilIfBlank {
                return "\(title) - \(subtitle)"
            }
            return title
        }
        if let nowPlaying = roonNowPlaying {
            return nowPlaying.titleLine
        }
        return roonBridgeSnapshot.isReadyForTransport ? "Waiting for Roon" : "No metadata"
    }

    private var roonPlaybackIsPaused: Bool {
        if roonBridgeSnapshot.selectedZone?.state.caseInsensitiveCompare("paused") == .orderedSame {
            return true
        }
        return roonNowPlaying?.state.caseInsensitiveCompare("PAUSED") == .orderedSame
    }

    private var roonPlaybackIsActive: Bool {
        if let state = roonBridgeSnapshot.selectedZone?.state.lowercased() {
            return state == "playing" || state == "loading"
        }
        if let state = roonNowPlaying?.state.lowercased() {
            return state == "playing" || state == "loading"
        }
        return false
    }

    private var roonPlaybackStateLogValue: String {
        if let state = roonBridgeSnapshot.selectedZone?.state.trimmedNilIfBlank {
            return normalizedPlaybackStateLogValue(state)
        }
        if let state = roonNowPlaying?.state.trimmedNilIfBlank {
            return normalizedPlaybackStateLogValue(state)
        }
        return "Unknown"
    }

    private var roonInputStatusErrorValue: String {
        if let liveMonitorError = liveMonitorStatusErrorValue.trimmedNilIfBlank {
            return liveMonitorError
        }

        switch roonBridgeSnapshot.bridge.state {
        case "missing_dependencies", "missing_node", "error":
            return roonBridgeSnapshot.bridge.message
        default:
            return ""
        }
    }

    private var spotifyReceiverStatusValue: String {
        switch spotifyReceiverStatus.state {
        case .waitingForConnection, .running:
            return "Running"
        case .restarting:
            return "Starting"
        case .failed, .embeddedModuleUnavailable:
            return "Error"
        case .notStarted:
            return "Stopped"
        }
    }

    private var spotifyConnectDiscoveryStatusValue: String {
        switch spotifyReceiverStatus.state {
        case .waitingForConnection, .running:
            return "Available as Orbisonic"
        case .restarting:
            return "Waiting for Spotify"
        case .notStarted:
            return "Not discoverable"
        case .failed, .embeddedModuleUnavailable:
            return "Unknown"
        }
    }

    private var spotifyConnectSessionStatusValue: String {
        if spotifyNowPlayingForStatus != nil || spotifyHasReceivingAudio {
            return "Selected in Spotify"
        }

        switch spotifyReceiverStatus.state {
        case .waitingForConnection, .running, .restarting:
            return "Waiting for Spotify app"
        case .notStarted:
            return "Disconnected"
        case .failed, .embeddedModuleUnavailable:
            return "Unknown"
        }
    }

    private var spotifySetupIsUnavailable: Bool {
        inputStatusSpotifyReceiverUnavailable ||
            spotifyReceiverStatus.state == .notStarted ||
            liveInputReadyValue(expected: .spotifyInput) == "Missing"
    }

    private var spotifyIsSelectedInApp: Bool {
        spotifyNowPlayingForStatus != nil || spotifyHasReceivingAudio
    }

    private var spotifySetupUserStatusValue: String {
        switch spotifyReceiverStatus.state {
        case .waitingForConnection, .running:
            return liveInputReadyValue(expected: .spotifyInput) == "Missing" ? "Unavailable" : "Available as Orbisonic"
        case .restarting:
            return "Starting"
        case .notStarted:
            return "Unavailable"
        case .failed, .embeddedModuleUnavailable:
            return "Error"
        }
    }

    private var spotifyConnectionUserStatusValue: String {
        if spotifyIsSelectedInApp {
            return "Connected to Orbisonic"
        }
        switch spotifyReceiverStatus.state {
        case .waitingForConnection, .running:
            return "Choose Orbisonic in Spotify"
        case .restarting:
            return "Waiting for Spotify"
        case .notStarted, .failed, .embeddedModuleUnavailable:
            return "Waiting for Spotify"
        }
    }

    private var spotifyAudioUserStatusValue: String {
        if spotifyHasReceivingAudio {
            return "Receiving"
        }
        if spotifyPlaybackStatusValue == "Paused" {
            return "Paused or silent"
        }
        switch liveAudioSignalState {
        case .noSignal:
            return spotifyIsSelectedInApp ? "No signal" : "Waiting for audio"
        case .silentPassage:
            return "Paused or silent"
        case .receiving, .briefSilence:
            return "Receiving"
        case .unknown:
            return spotifyIsSelectedInApp ? "Waiting for audio" : "Waiting for audio"
        }
    }

    private var spotifyNowPlayingUserStatusValue: String {
        let value = spotifyNowPlayingStatusValue
        return value == "No metadata" ? "No track yet" : value
    }

    private var spotifyAudioSignalStatusValue: String {
        switch liveAudioSignalState {
        case .receiving:
            return "Receiving"
        case .briefSilence:
            return "Brief silence"
        case .silentPassage:
            return "Paused or silent"
        case .noSignal:
            return spotifyPlaybackStatusValue == "Paused" ? "Paused or silent" : "No signal"
        case .unknown:
            break
        }
        switch liveMonitorState {
        case .monitoring:
            return "Receiving"
        case .silent:
            return "No signal"
        case .muted:
            return "Paused or silent"
        case .stopped, .unavailable, .error:
            return "Unknown"
        }
    }

    private var spotifyPlaybackStatusValue: String {
        if spotifyHasReceivingAudio {
            return "Playing"
        }
        if let nowPlaying = spotifyNowPlayingForStatus {
            return nowPlaying.isPlaying ? "Playing" : "Paused"
        }
        switch spotifyReceiverStatus.state {
        case .notStarted:
            return "Stopped"
        case .waitingForConnection, .running, .restarting, .failed, .embeddedModuleUnavailable:
            return "Unknown"
        }
    }

    private var spotifyNowPlayingStatusValue: String {
        if let nowPlaying = spotifyNowPlayingForStatus {
            return "\(nowPlaying.displayTitle) - \(nowPlaying.artistText)"
        }
        switch spotifyReceiverStatus.state {
        case .waitingForConnection, .running, .restarting:
            return "Waiting for Spotify"
        case .notStarted, .failed, .embeddedModuleUnavailable:
            return "No metadata"
        }
    }

    private var spotifyInputStatusErrorValue: String {
        if let liveMonitorError = liveMonitorStatusErrorValue.trimmedNilIfBlank {
            return liveMonitorError
        }

        switch spotifyReceiverStatus.state {
        case .failed, .embeddedModuleUnavailable:
            return spotifyReceiverStatus.message
        case .notStarted, .waitingForConnection, .running, .restarting:
            return ""
        }
    }

    private var spotifyNowPlayingForStatus: SpotifyNowPlaying? {
        spotifyVisibleNowPlaying ?? spotifyNowPlaying
    }

    private var spotifyHasReceivingAudio: Bool {
        liveAudioSignalState.isRecentlyReceiving || liveSignalStatus.localizedCaseInsensitiveContains("Signal present") || liveMonitorState == .monitoring
    }

    private var auxVirtualSoundCardStatusValue: String {
        if case .error = liveMonitorState {
            return "Error"
        }
        if sourceSwitchStatusText != nil || isLiveMonitorTransitioning {
            return "Starting"
        }
        if liveInputReadyValue(expected: .auxCable) == "Ready" {
            return "Available"
        }
        return availableInputRoutes.contains(where: \.isAuxLoopback) ? "Unknown" : "Not installed"
    }

    private var auxCableUserStatusValue: String {
        switch auxVirtualSoundCardStatusValue {
        case "Available":
            return "Ready"
        case "Starting":
            return "Starting"
        case "Error":
            return "Error"
        default:
            return "Unavailable"
        }
    }

    private var auxInputFormatStatusValue: String {
        if inputRoute.isAuxLoopback, inputRoute.inputChannelCount > 0 {
            return "\(inputRoute.inputChannelCount) channels"
        }
        if let auxRoute = availableInputRoutes.first(where: \.isAuxLoopback),
           auxRoute.inputChannelCount > 0 {
            return "\(auxRoute.inputChannelCount) channels"
        }
        return "Unknown"
    }

    private var auxAudioSignalStatusValue: String {
        switch liveAudioSignalState {
        case .receiving:
            return "Receiving"
        case .briefSilence:
            return "Brief silence"
        case .silentPassage:
            return "Silent passage"
        case .noSignal:
            return "No signal"
        case .unknown:
            break
        }

        switch liveMonitorState {
        case .monitoring:
            return "Receiving"
        case .muted:
            return "Silent"
        case .silent:
            return "No signal"
        case .stopped, .unavailable, .error:
            return "Unknown"
        }
    }

    private var auxAudioUserStatusValue: String {
        switch liveAudioSignalState {
        case .receiving, .briefSilence:
            return "Receiving"
        case .silentPassage:
            return "Paused or silent"
        case .noSignal:
            return "No signal"
        case .unknown:
            break
        }

        switch liveMonitorState {
        case .monitoring:
            return "Receiving"
        case .muted:
            return "Paused or silent"
        case .silent:
            return "No signal"
        case .stopped, .unavailable, .error:
            return "Waiting for audio"
        }
    }

    private var auxChannelCountLogValue: String {
        if inputRoute.isAuxLoopback, inputRoute.inputChannelCount > 0 {
            return "\(inputRoute.inputChannelCount)"
        }
        if let auxRoute = availableInputRoutes.first(where: \.isAuxLoopback),
           auxRoute.inputChannelCount > 0 {
            return "\(auxRoute.inputChannelCount)"
        }
        return "Unknown"
    }

    private var auxActiveChannelsStatusValue: String? {
        let meters = meterStore.channelMeters
        guard !meters.isEmpty else { return nil }

        let activeChannels = meters
            .filter { $0.level >= 0.005 }
            .map { $0.channel.index + 1 }
            .sorted()

        return activeChannels.isEmpty ? "None" : compactInputChannelRanges(activeChannels)
    }

    private var liveAudioSignalSilenceDurationLogValue: String {
        liveAudioSignalSilenceDuration.map { "\($0)s" } ?? "Unknown"
    }

    private func liveInputReadyValue(expected: OrbisonicLoopbackDevice) -> String {
        inputRoute.uid == expected.deviceUID ? "Ready" : "Missing"
    }

    private var inputStatusSelectedLiveSourceUnavailable: Bool {
        guard sourceMode.isLiveInput else { return false }
        switch liveMonitorState {
        case .unavailable, .error:
            return true
        case .stopped, .monitoring, .muted, .silent:
            return false
        }
    }

    private var inputStatusSpotifyReceiverUnavailable: Bool {
        switch spotifyReceiverStatus.state {
        case .failed, .embeddedModuleUnavailable:
            return true
        case .notStarted, .waitingForConnection, .running, .restarting:
            return false
        }
    }

    private var liveMonitorStatusErrorValue: String {
        switch liveMonitorState {
        case .unavailable(let message), .error(let message):
            return message
        case .stopped, .monitoring, .muted, .silent:
            return ""
        }
    }

    private func runningLogValue(for statusValue: String) -> String {
        switch statusValue {
        case "Running":
            return "true"
        case "Starting":
            return "starting"
        case "Stopped", "Error":
            return "false"
        default:
            return "unknown"
        }
    }

    private func availabilityLogValue(for statusValue: String) -> String {
        switch statusValue {
        case "Available":
            return "true"
        case "Starting":
            return "starting"
        case "Not installed":
            return "false"
        case "Error", "Unknown":
            return "unknown"
        default:
            return "unknown"
        }
    }

    private func normalizedPlaybackStateLogValue(_ rawValue: String) -> String {
        switch rawValue.lowercased() {
        case "playing", "play":
            return "Playing"
        case "loading":
            return "Loading"
        case "paused", "pause":
            return "Paused"
        case "stopped", "stop":
            return "Stopped"
        default:
            return rawValue
        }
    }

    private func compactInputChannelRanges(_ channels: [Int]) -> String {
        var ranges: [String] = []
        var rangeStart: Int?
        var previous: Int?

        for channel in channels {
            guard let start = rangeStart, let prior = previous else {
                rangeStart = channel
                previous = channel
                continue
            }

            if channel == prior + 1 {
                previous = channel
                continue
            }

            ranges.append(start == prior ? "\(start)" : "\(start)-\(prior)")
            rangeStart = channel
            previous = channel
        }

        if let start = rangeStart, let prior = previous {
            ranges.append(start == prior ? "\(start)" : "\(start)-\(prior)")
        }

        return ranges.joined(separator: ", ")
    }
}
