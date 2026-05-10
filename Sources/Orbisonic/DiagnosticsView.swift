import AppKit
import SwiftUI

private enum DiagnosticsSectionID: Hashable {
    case inputHealth
    case roon
    case spotify
    case aux
    case localFiles
    case outputRouting
    case renderer
    case webControl
    case logsSupport
    case rendererAdvanced
}

private enum DiagnosticsRowTone {
    case normal
    case warning
    case error
    case secondary
}

private enum DiagnosticsSummaryGroup: String, CaseIterable, Hashable {
    case orbisonic = "Orbisonic"
    case source = "Source"
    case audio = "Audio"
}

private enum DiagnosticsSummaryState: Equatable {
    case ok
    case fault
    case status

    var label: String {
        switch self {
        case .ok:
            return "OK"
        case .fault:
            return "Fault"
        case .status:
            return "Status"
        }
    }

    var tone: DiagnosticsRowTone {
        switch self {
        case .ok:
            return .normal
        case .fault:
            return .error
        case .status:
            return .secondary
        }
    }
}

private struct DiagnosticsSummaryRow: Identifiable {
    let group: DiagnosticsSummaryGroup
    let name: String
    let state: DiagnosticsSummaryState
    let status: String
    var monospace = false
    var copyValue: String?

    var id: String { "\(group.rawValue):\(name):\(state.label):\(status)" }
}

private struct DiagnosticsRow: Identifiable {
    let label: String
    let value: String
    var tone: DiagnosticsRowTone = .normal
    var monospace = false

    var id: String { "\(label):\(value):\(tone)" }

    var isWarning: Bool {
        tone == .warning || tone == .error
    }
}

struct DiagnosticsView: View {
    @ObservedObject var model: OrbisonicViewModel
    @State private var expansionOverrides: [DiagnosticsSectionID: Bool] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            topStatusPanel
            channelWalkPanel

            diagnosticsDisclosure(
                id: .inputHealth,
                title: "Input / Source Health",
                defaultExpanded: false,
                rows: inputHealthRows,
                warnings: inputHealthWarnings
            )

            diagnosticsDisclosure(
                id: .roon,
                title: "Roon",
                defaultExpanded: false,
                rows: roonRows,
                warnings: roonWarnings
            )

            diagnosticsDisclosure(
                id: .spotify,
                title: "Spotify",
                defaultExpanded: false,
                rows: spotifyRows,
                warnings: spotifyWarnings
            )

            diagnosticsDisclosure(
                id: .aux,
                title: "Aux Cable",
                defaultExpanded: false,
                rows: auxRows,
                warnings: auxWarnings
            )

            diagnosticsDisclosure(
                id: .localFiles,
                title: "Local Files",
                defaultExpanded: false,
                rows: localFileRows,
                warnings: localFileWarnings
            )

            diagnosticsDisclosure(
                id: .outputRouting,
                title: "Output / Routing",
                defaultExpanded: false,
                warnings: outputWarnings
            ) {
                diagnosticsRows(outputWarnings)
                diagnosticSubsection("Output 1 / Monitor", rows: outputRows(model.monitorOutputDiagnosticsRows))
                diagnosticSubsection("Output 2 / Main Renderer", rows: outputRows(model.rendererOutputDiagnosticsRows))
                diagnosticsRows(otherRoutingRows)
            }

            diagnosticsDisclosure(
                id: .renderer,
                title: "Renderer",
                defaultExpanded: false,
                warnings: rendererWarnings
            ) {
                diagnosticsRows(rendererWarnings)
                diagnosticsRows(rendererRows)
                diagnosticsInlineDisclosure(
                    id: .rendererAdvanced,
                    title: "Advanced renderer details",
                    defaultExpanded: false
                ) {
                    diagnosticsRows(rendererAdvancedRows)
                        .padding(.top, 8)
                }
                .padding(.top, 4)
            }

            diagnosticsDisclosure(
                id: .webControl,
                title: "Web / Control",
                defaultExpanded: false,
                rows: webRows,
                warnings: webWarnings
            )

            diagnosticsDisclosure(
                id: .logsSupport,
                title: "Logs / Support",
                defaultExpanded: false,
                warnings: supportWarnings
            ) {
                diagnosticsRows(supportWarnings)
                supportActions
                diagnosticsRows(supportRows)
                logSnippetView
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var topStatusPanel: some View {
        diagnosticsPanel(title: "At A Glance") {
            diagnosticsSummaryHeader
            ForEach(DiagnosticsSummaryGroup.allCases, id: \.self) { group in
                diagnosticsSummarySection(
                    group,
                    rows: atAGlanceRows.filter { $0.group == group }
                )
            }
        }
    }

    private var channelWalkPanel: some View {
        diagnosticsPanel(title: "Speaker Tests") {
            speakerTestControlRow
            diagnosticToneActivityPanel
        }
    }

    private var atAGlanceRows: [DiagnosticsSummaryRow] {
        [
            DiagnosticsSummaryRow(
                group: .orbisonic,
                name: "App",
                state: model.appLaunchContextText == "Raw executable" ? .fault : .ok,
                status: AppBuildInfo.buildStatusText,
                monospace: true
            ),
            DiagnosticsSummaryRow(
                group: .orbisonic,
                name: "Machine Address",
                state: machineAddressCopyValue == nil ? .status : .ok,
                status: machineAddressText,
                monospace: true,
                copyValue: machineAddressCopyValue
            ),
            DiagnosticsSummaryRow(
                group: .orbisonic,
                name: "Web Interface",
                state: webInterfaceCopyValue == nil ? .status : .ok,
                status: webInterfaceText,
                monospace: true,
                copyValue: webInterfaceCopyValue
            ),
            DiagnosticsSummaryRow(
                group: .orbisonic,
                name: "Last Error",
                state: model.lastErrorEvent == nil ? .ok : .fault,
                status: model.lastErrorEvent == nil ? "None" : "See below"
            ),
            DiagnosticsSummaryRow(
                group: .source,
                name: "Active Source",
                state: .status,
                status: model.sourceMode.displayName
            ),
            inputRouteSummaryRow,
            signalSummaryRow,
            sourceServiceSummaryRow,
            outputSummaryRow(name: "Output 1", isMonitor: true),
            outputSummaryRow(name: "Output 2", isMonitor: false)
        ]
    }

    private var inputRouteSummaryRow: DiagnosticsSummaryRow {
        if model.sourceMode.isLiveInput {
            let isFault = !model.inputRoute.isAvailable || !model.sourceMode.acceptsInputRoute(model.inputRoute)
            return DiagnosticsSummaryRow(
                group: .source,
                name: "Input Route",
                state: isFault ? .fault : .ok,
                status: isFault ? "See below" : "OK"
            )
        }

        return DiagnosticsSummaryRow(
            group: .source,
            name: "Input Route",
            state: .status,
            status: "Idle"
        )
    }

    private var signalSummaryRow: DiagnosticsSummaryRow {
        if model.sourceMode.isLiveInput {
            switch model.liveAudioSignalState {
            case .receiving:
                return DiagnosticsSummaryRow(group: .source, name: "Signal", state: .ok, status: "Running")
            case .briefSilence, .silentPassage:
                return DiagnosticsSummaryRow(group: .source, name: "Signal", state: .status, status: "Idle")
            case .noSignal:
                return DiagnosticsSummaryRow(group: .source, name: "Signal", state: .fault, status: "No Signal")
            case .unknown:
                return DiagnosticsSummaryRow(group: .source, name: "Signal", state: .status, status: "Idle")
            }
        }

        if model.isLocalFileLoading {
            return DiagnosticsSummaryRow(group: .source, name: "Signal", state: .status, status: "Loading")
        }
        if model.isPlaying || model.isTestTonePlaying || model.isDiagnosticSequencePlaying {
            return DiagnosticsSummaryRow(group: .source, name: "Signal", state: .ok, status: "Running")
        }
        return DiagnosticsSummaryRow(group: .source, name: "Signal", state: .status, status: "Idle")
    }

    private var sourceServiceSummaryRow: DiagnosticsSummaryRow {
        let hasFault: Bool
        let status: String

        switch model.sourceMode {
        case .roon:
            hasFault = !roonWarnings.isEmpty
            status = "Roon"
        case .spotify:
            hasFault = !spotifyWarnings.isEmpty
            status = "Spotify"
        case .aux:
            hasFault = !auxWarnings.isEmpty
            status = "Aux"
        case .atmosDRP:
            hasFault = model.dolbyReferencePlayerSnapshot.state == .failed || !auxWarnings.isEmpty
            status = "Atmos"
        case .filePlayback:
            hasFault = !localFileWarnings.isEmpty
            status = "Local"
        case .testTone:
            hasFault = model.lastDiagnosticFailure != nil
            status = "Diagnostics"
        case .off:
            hasFault = false
            status = "Idle"
        }

        return DiagnosticsSummaryRow(
            group: .source,
            name: "Source Service",
            state: hasFault ? .fault : (model.sourceMode == .off ? .status : .ok),
            status: hasFault ? "See below" : status
        )
    }

    private func outputSummaryRow(name: String, isMonitor: Bool) -> DiagnosticsSummaryRow {
        let route = isMonitor ? model.monitorOutputRoute : model.rendererOutputRoute
        let selectionText = isMonitor ? model.monitorOutputSelectionText : model.rendererOutputSelectionText
        let hasFault = isMonitor ? model.monitorOutputWarningText != nil : rendererOutputHasFault
        let isNotSet = selectionText.localizedCaseInsensitiveContains("not set")

        let state: DiagnosticsSummaryState
        let status: String
        if hasFault {
            state = .fault
            status = "See below"
        } else if isNotSet {
            state = .status
            status = "Not Set"
        } else if route.isAvailable {
            state = .ok
            status = "OK"
        } else {
            state = .status
            status = "Not Set"
        }

        return DiagnosticsSummaryRow(group: .audio, name: name, state: state, status: status)
    }

    private var rendererOutputHasFault: Bool {
        model.rendererOutputWarningText != nil ||
            (
                model.rendererOutputRoute.isAvailable &&
                    model.rendererScene.outputSpeakers.count > model.rendererOutputRoute.outputChannelCount
            )
    }

    private var machineAddressText: String {
        machineAddressCopyValue ?? "Starting"
    }

    private var machineAddressCopyValue: String? {
        guard let host = URLComponents(string: model.webPublicPageURL).flatMap(\.host),
              isIPv4Address(host) else {
            return nil
        }
        return host
    }

    private var webInterfaceText: String {
        model.webPublicPageURL.trimmedNilIfBlank ?? "Starting"
    }

    private var webInterfaceCopyValue: String? {
        copyableDiagnosticValue(in: webInterfaceText)
    }

    private var inputHealthRows: [DiagnosticsRow] {
        var rows: [DiagnosticsRow] = [
            DiagnosticsRow(label: "Expected input device", value: expectedInputDeviceText),
            DiagnosticsRow(label: "Actual selected input device", value: model.inputRoute.isAvailable ? model.inputRoute.displayName : "Unavailable"),
            DiagnosticsRow(label: "Input UID", value: model.inputRoute.uid.trimmedNilIfBlank ?? "none", monospace: true),
            DiagnosticsRow(label: "Transport", value: model.inputRoute.transportName),
            DiagnosticsRow(label: "Channel count", value: model.inputRoute.isAvailable ? "\(model.inputRoute.inputChannelCount)" : "none"),
            DiagnosticsRow(label: "Nominal sample rate", value: formatSampleRate(model.inputRoute.nominalSampleRate)),
            DiagnosticsRow(label: "Microphone/input permission", value: model.inputPermissionStatusText)
        ]

        if model.sourceMode.isLiveInput {
            let diagnosis = model.liveLoopbackDiagnostics
            rows.append(contentsOf: [
                DiagnosticsRow(label: "Capture diagnosis", value: diagnosis.summary, tone: diagnosticsTone(for: diagnosis.severity)),
                DiagnosticsRow(label: "Route diagnosis", value: diagnosis.routeStatus),
                DiagnosticsRow(label: "Sample-rate diagnosis", value: diagnosis.sampleRateStatus),
                DiagnosticsRow(label: "Channel diagnosis", value: diagnosis.channelStatus),
                DiagnosticsRow(label: "Signal diagnosis", value: diagnosis.signalStatus),
                DiagnosticsRow(label: "Buffer diagnosis", value: diagnosis.bufferStatus, monospace: true),
                DiagnosticsRow(label: "Player/source activity", value: diagnosis.playerActivityStatus),
                DiagnosticsRow(label: "Capture format", value: liveCaptureFormatText),
                DiagnosticsRow(label: "Active input channels", value: "\(model.activeLiveChannelCount) active of \(model.inputRoute.inputChannelCount) available"),
                DiagnosticsRow(label: "Signal state", value: signalStateText),
                DiagnosticsRow(label: "Buffer fill level", value: model.liveBufferStatus),
                DiagnosticsRow(label: "Underflow count", value: model.livePipeStatus.map { "\($0.underflowCount)" } ?? "not available"),
                DiagnosticsRow(label: "Dropped frame count", value: model.livePipeStatus.map { "\($0.overflowDropFrames)" } ?? "not available")
            ])
            if let seconds = model.liveAudioSignalSilenceDuration {
                rows.append(DiagnosticsRow(label: "Time since last real signal", value: "\(seconds)s"))
            }
            if let underflowAt = model.lastLiveUnderflowAt {
                rows.append(DiagnosticsRow(label: "Last underflow time", value: dateText(underflowAt)))
            }
        }

        if let mismatch = model.liveSourceSampleRateMismatchText?.trimmedNilIfBlank {
            rows.append(DiagnosticsRow(label: "Sample-rate mismatch", value: mismatch, tone: .warning))
        }

        return rows
    }

    private var inputHealthWarnings: [DiagnosticsRow] {
        var rows: [DiagnosticsRow] = []
        if model.sourceMode.isLiveInput {
            let diagnosis = model.liveLoopbackDiagnostics
            if diagnosis.severity == .warning || diagnosis.severity == .error {
                rows.append(DiagnosticsRow(
                    label: "Capture diagnosis",
                    value: diagnosis.summary,
                    tone: diagnosticsTone(for: diagnosis.severity)
                ))
            }
        }
        if model.sourceMode.isLiveInput, !model.sourceMode.acceptsInputRoute(model.inputRoute) {
            rows.append(DiagnosticsRow(
                label: "Warning",
                value: "Expected \(expectedInputDeviceText), but Orbisonic is seeing \(model.inputRoute.displayName).",
                tone: .warning
            ))
        }
        if model.sourceMode.isLiveInput, model.liveAudioSignalState == .noSignal {
            rows.append(DiagnosticsRow(label: "Warning", value: model.liveSignalStatus, tone: .warning))
        }
        if model.inputPermissionStatusText == "Denied" || model.inputPermissionStatusText == "Restricted" {
            rows.append(DiagnosticsRow(label: "Warning", value: "macOS input permission may block loopback capture.", tone: .warning))
        }
        return rows
    }

    private func diagnosticsTone(for severity: LiveLoopbackDiagnosticSeverity) -> DiagnosticsRowTone {
        switch severity {
        case .error:
            return .error
        case .warning:
            return .warning
        case .idle, .waiting:
            return .secondary
        case .healthy:
            return .normal
        }
    }

    private var roonRows: [DiagnosticsRow] {
        var rows = [
            DiagnosticsRow(label: "Roon bridge status", value: model.roonBridgeSnapshot.statusText),
            DiagnosticsRow(label: "Selected zone", value: model.roonBridgeSnapshot.selectedZone?.displayName ?? "Not selected"),
            DiagnosticsRow(label: "Transport state", value: model.roonBridgeSnapshot.selectedZone?.state ?? model.roonNowPlaying?.state ?? "Unknown"),
            DiagnosticsRow(label: "Roon endpoint", value: model.roonBridgeSnapshot.audioPathText),
            DiagnosticsRow(label: "Roon audio path", value: model.roonSignalPath?.statusText ?? model.roonBridgeSnapshot.audioPathText)
        ]

        if let signalPath = model.roonSignalPath {
            rows.append(contentsOf: [
                DiagnosticsRow(label: "Source format from Roon", value: signalPath.sourceFormat, monospace: true),
                DiagnosticsRow(label: "ChannelMapping line", value: signalPath.channelMapping, monospace: true),
                DiagnosticsRow(label: "RAAT device", value: signalPath.device, monospace: true),
                DiagnosticsRow(label: "Roon Output line", value: signalPath.output, monospace: true)
            ])
        }

        if let outputSampleRate = model.roonNowPlaying?.outputSampleRate {
            rows.append(DiagnosticsRow(label: "Roon output sample rate", value: formatSampleRate(outputSampleRate)))
        }
        if let roonInput = model.availableInputRoutes.first(where: \.isRoonLoopback) {
            rows.append(DiagnosticsRow(label: "Orbisonic Roon input sample rate", value: formatSampleRate(roonInput.nominalSampleRate)))
        }

        rows.append(contentsOf: [
            DiagnosticsRow(label: "Receiving while Roon reports playback", value: roonPlaybackReceivingText),
            DiagnosticsRow(label: "Metadata/log freshness", value: model.roonNowPlayingStatus)
        ])

        return rows
    }

    private var roonWarnings: [DiagnosticsRow] {
        var rows: [DiagnosticsRow] = []
        if model.roonSignalPath?.isDownmixingToStereo == true,
           let channelMapping = model.roonSignalPath?.channelMapping {
            rows.append(DiagnosticsRow(label: "Warning", value: "Roon is downmixing before Orbisonic: \(channelMapping).", tone: .warning, monospace: true))
        }
        if model.sourceMode == .roon,
           roonBridgePlaybackIsActive,
           model.liveAudioSignalState == .noSignal {
            rows.append(DiagnosticsRow(label: "Warning", value: signalPlaybackMismatchWarning(sourceName: "Roon"), tone: .warning))
        }
        if model.sourceMode == .roon,
           let mismatch = model.liveSourceSampleRateMismatchText?.trimmedNilIfBlank {
            rows.append(DiagnosticsRow(label: "Warning", value: mismatch, tone: .warning))
        }
        return rows
    }

    private var spotifyRows: [DiagnosticsRow] {
        var rows = [
            DiagnosticsRow(label: "Spotify Connect receiver status", value: model.spotifyReceiverStatus.message),
            DiagnosticsRow(label: "Advertised device name", value: model.spotifyAdvertisedDeviceName),
            DiagnosticsRow(label: "Active Spotify client/session", value: model.spotifyNowPlayingForActiveStatus?.clientName ?? "None"),
            DiagnosticsRow(label: "Orbisonic active Spotify target", value: spotifyIsActiveTargetText),
            DiagnosticsRow(label: "Spotify loopback availability", value: spotifyLoopbackAvailabilityText),
            DiagnosticsRow(label: "Signal state", value: model.sourceMode == .spotify ? signalStateText : "not active"),
            DiagnosticsRow(label: "Remote-control readiness", value: model.spotifyReceiverStatus.isRunning ? "Ready" : "Not available")
        ]

        if model.sourceMode == .spotify, let metadata = model.sourceMetadata {
            rows.append(DiagnosticsRow(label: "Stream format", value: "\(metadata.channelCount) ch • \(metadata.sampleRateText) • \(metadata.layoutName)"))
        }
        if let updatedAt = model.spotifyVisibleNowPlaying?.updatedAt ?? model.spotifyNowPlaying?.updatedAt {
            rows.append(DiagnosticsRow(label: "Last stream read time", value: updatedAt, monospace: true))
        }
        if spotifyReceiverHasFailure {
            rows.append(DiagnosticsRow(label: "Last failure reason", value: model.spotifyReceiverStatus.message, tone: .error))
        }

        return rows
    }

    private var spotifyWarnings: [DiagnosticsRow] {
        var rows: [DiagnosticsRow] = []
        if spotifyReceiverHasFailure {
            rows.append(DiagnosticsRow(label: "Warning", value: model.spotifyReceiverStatus.message, tone: .warning))
        }
        if model.sourceMode == .spotify,
           model.spotifyReceiverStatus.isRunning,
           model.liveAudioSignalState == .noSignal {
            rows.append(DiagnosticsRow(label: "Warning", value: signalPlaybackMismatchWarning(sourceName: "Spotify"), tone: .warning))
        }
        return rows
    }

    private var auxRows: [DiagnosticsRow] {
        let auxRoute = model.inputRoute.isAuxLoopback ? model.inputRoute : model.availableInputRoutes.first(where: \.isAuxLoopback)
        return [
            DiagnosticsRow(label: "Expected Aux loopback/input device", value: OrbisonicLoopbackDevice.auxCable.displayName),
            DiagnosticsRow(label: "Actual input device", value: model.inputRoute.displayName),
            DiagnosticsRow(label: "Signal state", value: model.sourceMode == .aux ? signalStateText : "not active"),
            DiagnosticsRow(label: "Sample rate", value: auxRoute.map { formatSampleRate($0.nominalSampleRate) } ?? "not available"),
            DiagnosticsRow(label: "Channel count", value: auxRoute.map { "\($0.inputChannelCount)" } ?? "not available")
        ]
    }

    private var auxWarnings: [DiagnosticsRow] {
        var rows: [DiagnosticsRow] = []
        if model.sourceMode == .aux, !model.inputRoute.isAuxLoopback {
            rows.append(DiagnosticsRow(label: "Warning", value: "Aux source expects Orbisonic Aux Cable.", tone: .warning))
        }
        if outputPointsToOrbisonicLoopback {
            rows.append(DiagnosticsRow(label: "Warning", value: "Possible feedback loop: output points to an Orbisonic loopback device.", tone: .warning))
        }
        return rows
    }

    private var localFileRows: [DiagnosticsRow] {
        var rows: [DiagnosticsRow] = []
        if let metadata = model.sourceMode == .filePlayback ? model.sourceMetadata : nil {
            rows.append(contentsOf: [
                DiagnosticsRow(label: "Loaded file name", value: metadata.fileName),
                DiagnosticsRow(label: "Container", value: metadata.containerName),
                DiagnosticsRow(label: "Codec", value: metadata.codecName),
                DiagnosticsRow(label: "Sample rate", value: metadata.sampleRateText),
                DiagnosticsRow(label: "Channel count", value: "\(metadata.channelCount)"),
                DiagnosticsRow(label: "Channel layout", value: metadata.layoutName),
                DiagnosticsRow(label: "Duration", value: metadata.durationText),
                DiagnosticsRow(label: "Decode state", value: model.isLocalFileLoading ? "Loading" : "Ready"),
                DiagnosticsRow(label: "Loading state", value: model.isLocalFileLoading ? "Loading" : "Idle")
            ])
            if let note = metadata.formatNote?.trimmedNilIfBlank {
                rows.append(DiagnosticsRow(label: "Probe warnings", value: note, tone: note.localizedCaseInsensitiveContains("not rendered") ? .warning : .normal))
            }
        } else {
            rows.append(DiagnosticsRow(label: "Loaded file name", value: "None"))
            rows.append(DiagnosticsRow(label: "Loading state", value: model.isLocalFileLoading ? "Loading" : "Idle"))
        }

        rows.append(contentsOf: [
            DiagnosticsRow(label: "Local gapless scheduler", value: model.isLocalGaplessSchedulerEnabled ? "Enabled" : "Off"),
            DiagnosticsRow(label: "Compressed trim metadata", value: model.isLocalGaplessCompressedTrimEnabled ? "Enabled" : "Off"),
            DiagnosticsRow(label: "Local library database health", value: model.localMusicSettings.watchFolderPaths.isEmpty && model.localMusicSettings.m3uPlaylistPaths.isEmpty ? "No library sources configured" : "Configured"),
            DiagnosticsRow(label: "Track count", value: "\(model.localMusicTracks.count)"),
            DiagnosticsRow(label: "Playlist count", value: "\(model.localMusicPlaylists.count)"),
            DiagnosticsRow(label: "Watch-folder status", value: model.localMusicWatchFolderText)
        ])
        return rows
    }

    private var localFileWarnings: [DiagnosticsRow] {
        guard model.sourceMode == .filePlayback, let error = model.lastError?.trimmedNilIfBlank else {
            return []
        }
        return [DiagnosticsRow(label: "Warning", value: error, tone: .warning)]
    }

    private var outputWarnings: [DiagnosticsRow] {
        var rows: [DiagnosticsRow] = []
        if let warning = model.monitorOutputWarningText {
            rows.append(DiagnosticsRow(label: "Output 1 warning", value: warning, tone: .warning))
        }
        if let warning = model.rendererOutputWarningText {
            rows.append(DiagnosticsRow(label: "Output 2 warning", value: warning, tone: .warning))
        }
        if model.rendererOutputRoute.isAvailable,
           model.rendererScene.outputSpeakers.count > model.rendererOutputRoute.outputChannelCount {
            rows.append(DiagnosticsRow(
                label: "Renderer capacity",
                value: "Renderer requires \(model.rendererScene.outputSpeakers.count) output channels, but selected device reports \(model.rendererOutputRoute.outputChannelCount).",
                tone: .warning
            ))
        }
        return rows
    }

    private var otherRoutingRows: [DiagnosticsRow] {
        [
            DiagnosticsRow(label: "Active engine output route", value: model.outputNowText),
            DiagnosticsRow(label: "Renderer channel requirement", value: "\(model.rendererScene.outputSpeakers.count) required / \(model.rendererOutputRoute.outputChannelCount) available"),
            DiagnosticsRow(label: "Requested output volume", value: "\(model.sphereRequestedOutputVolumeText)%"),
            DiagnosticsRow(label: "Effective output volume", value: "\(model.sphereEffectiveOutputVolumeText)%"),
            DiagnosticsRow(label: "Max safety limit", value: "\(model.sphereMaxOutputVolumeText)%")
        ]
    }

    private var rendererRows: [DiagnosticsRow] {
        let scene = model.rendererScene
        return [
            DiagnosticsRow(label: "Render mode", value: model.rendererRenderMode.displayName),
            DiagnosticsRow(label: "Resolved automatic render mode", value: scene.renderMode.displayName),
            DiagnosticsRow(label: "Bypass/direct renderer", value: scene.isBypass ? "Direct speaker playback" : "Matrix-rendered"),
            DiagnosticsRow(label: "Input layout", value: model.sourceMetadata?.layoutName ?? scene.renderMode.displayName),
            DiagnosticsRow(label: "Output topology", value: model.rendererSelectionText),
            DiagnosticsRow(label: "Matrix size", value: "\(scene.matrix.inputCount)x\(scene.matrix.outputCount)"),
            DiagnosticsRow(label: "Validation messages", value: scene.validationMessages.isEmpty ? "None" : scene.validationMessages.joined(separator: " • ")),
            DiagnosticsRow(label: "Direct channel mapping summary", value: model.rendererChannelOrderText),
            DiagnosticsRow(label: "Current renderer preset", value: model.rendererPreset.name)
        ]
    }

    private var rendererWarnings: [DiagnosticsRow] {
        model.rendererScene.validationMessages.map {
            DiagnosticsRow(label: "Renderer warning", value: $0, tone: .warning)
        }
    }

    private var rendererAdvancedRows: [DiagnosticsRow] {
        [
            DiagnosticsRow(label: "Always Mono", value: model.rendererAlwaysMono ? "On" : "Off"),
            DiagnosticsRow(label: "2-channel preference", value: model.rendererTwoChannelPreference.displayName),
            DiagnosticsRow(label: "Seam Support", value: String(format: "%.2f", model.rendererSeamSupportGain)),
            DiagnosticsRow(label: "Upper Bias dB/Z", value: String(format: "%.1f", model.rendererUpperBiasDbPerUnitZ)),
            DiagnosticsRow(label: "Stereo Rear Fill", value: String(format: "%.2f", model.rendererStereoRearFill)),
            DiagnosticsRow(label: "Center Side Support", value: String(format: "%.2f", model.rendererCenterSideSupportGain)),
            DiagnosticsRow(label: "Adjacent Bleed", value: String(format: "%.2f", model.rendererAdjacentBleed)),
            DiagnosticsRow(label: "Max Speaker Share", value: String(format: "%.2f", model.rendererMaxSingleSpeakerPowerShare)),
            DiagnosticsRow(label: "Rendered Trim", value: String(format: "%.1f dB", model.rendererRenderedOutputTrimDb)),
            DiagnosticsRow(label: "LFE Trim", value: String(format: "%.1f dB", model.rendererLfeTrimDb))
        ]
    }

    private var webRows: [DiagnosticsRow] {
        [
            DiagnosticsRow(label: "Machine address", value: machineAddressText, monospace: true),
            DiagnosticsRow(label: "Web interface", value: webInterfaceText, monospace: true),
            DiagnosticsRow(label: "Public page status", value: model.webServerStatus),
            DiagnosticsRow(label: "Control server status", value: model.webServerStatus),
            DiagnosticsRow(label: "Permanent local URL", value: "http://127.0.0.1:37943/Orbisonic/", monospace: true),
            DiagnosticsRow(label: "Public route health", value: model.webPublicPageURL.isEmpty ? "Starting" : model.webPublicPageURL, monospace: !model.webPublicPageURL.isEmpty),
            DiagnosticsRow(label: "Control route health", value: model.webControlPageURL.isEmpty ? "Starting" : redactedControlURL(model.webControlPageURL), monospace: !model.webControlPageURL.isEmpty)
        ]
    }

    private var webWarnings: [DiagnosticsRow] {
        model.webServerStatus.localizedCaseInsensitiveContains("unavailable")
            ? [DiagnosticsRow(label: "Web warning", value: model.webServerStatus, tone: .warning)]
            : []
    }

    private var supportRows: [DiagnosticsRow] {
        [
            DiagnosticsRow(label: "Last export result", value: model.lastDiagnosticExportResult ?? "None"),
            DiagnosticsRow(label: "App launch context", value: model.appLaunchContextText),
            DiagnosticsRow(label: "Log file", value: redactedPath(AppLogger.logFilePath), monospace: true),
            DiagnosticsRow(label: "ffmpeg", value: FFmpegToolLocator.ffmpegURL() == nil ? "Unavailable" : "Available"),
            DiagnosticsRow(label: "ffprobe", value: FFmpegToolLocator.ffprobeURL() == nil ? "Unavailable" : "Available"),
            DiagnosticsRow(label: "Roon bridge", value: model.roonBridgeSnapshot.compactStatusText),
            DiagnosticsRow(label: "Spotify receiver", value: model.spotifyReceiverStatus.state.rawValue)
        ]
    }

    private var supportWarnings: [DiagnosticsRow] {
        var rows: [DiagnosticsRow] = []
        if model.appLaunchContextText == "Raw executable" {
            rows.append(DiagnosticsRow(label: "Launch warning", value: "Orbisonic was launched as a raw executable. Reopen Orbisonic.app through LaunchServices before judging GUI/audio behavior.", tone: .warning))
        }
        return rows
    }

    private var speakerTestControlRow: some View {
        HStack(spacing: 10) {
            Button(action: model.startMonitorChannelWalk) {
                Label {
                    Text("Local Monitor Channel Walk")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                } icon: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(LabButtonStyle(isActive: true, accent: LabTheme.amber))
            .disabled(model.isDiagnosticSequencePlaying)

            Button(action: model.startRendererOutputChannelWalk) {
                Label {
                    Text("Sonic Sphere Channel Walk")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                } icon: {
                    Image(systemName: "speaker.wave.3.fill")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(LabButtonStyle(isActive: true, accent: LabTheme.amber))
            .disabled(model.isDiagnosticSequencePlaying)

            Button(action: model.stopDiagnosticsAndReturnToMusic) {
                Image(systemName: "stop.fill")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(LabButtonStyle())
            .disabled(!model.isDiagnosticSequencePlaying)
            .help("Stop channel walk")

            Menu {
                ForEach(1...model.diagnosticSpeakerChannelCount, id: \.self) { channel in
                    Button("Channel \(channel)") {
                        model.selectDiagnosticSpeakerChannel(channel)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Speaker")
                    Spacer(minLength: 6)
                    Text("\(model.selectedDiagnosticSpeakerChannel)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(LabTheme.text)
                .frame(minWidth: 118)
            }
            .buttonStyle(LabButtonStyle())
            .help("Sonic Sphere single speaker test channel")

            Button(action: model.playSelectedDiagnosticSpeakerTone) {
                Label {
                    Text("Play Speaker")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } icon: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(LabButtonStyle(isActive: true, accent: LabTheme.amber))
            .help("Play Sonic Sphere single speaker test")

            Button(action: { model.stopTestTone() }) {
                Image(systemName: "stop.fill")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(LabButtonStyle())
            .disabled(!model.isTestTonePlaying)
            .help("Stop single speaker test")
        }
    }

    private var diagnosticToneActivityPanel: some View {
        let summary = model.diagnosticToneActivitySummary

        return diagnosticControlGroup(title: "Multichannel VU") {
            VStack(alignment: .leading, spacing: 12) {
                if summary.isActive {
                    DiagnosticToneMeterStrip(
                        title: "Tone Source",
                        meterStore: model.meterStore,
                        isActive: true,
                        accent: LabTheme.cyan,
                        hidesWhenSilent: true
                    )
                }

                DiagnosticToneMeterStrip(
                    title: "Output 1: Local speakers",
                    meterStore: model.monitorMeterStore,
                    isActive: summary.isActive,
                    accent: LabTheme.green
                )

                DiagnosticToneMeterStrip(
                    title: "Output 2: Sonic Sphere",
                    meterStore: model.rendererMeterStore,
                    isActive: summary.isActive,
                    accent: LabTheme.amber
                )
            }
        }
    }

    private var supportActions: some View {
        HStack(spacing: 10) {
            Button(action: model.saveDiagnosticBundle) {
                Label("Export Redacted Diagnostic Bundle", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LabButtonStyle(isActive: true))

            Button(action: model.refreshRecentLogSnippets) {
                Label("Refresh Logs", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LabButtonStyle())
            .disabled(model.isLoadingRecentLogSnippets)
        }
    }

    @ViewBuilder
    private var logSnippetView: some View {
        HStack(spacing: 8) {
            Text("RECENT WARNINGS/ERRORS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(LabTheme.cyan)
            if model.isLoadingRecentLogSnippets {
                ProgressView()
                    .controlSize(.small)
                    .tint(LabTheme.cyan)
            }
        }
        .padding(.top, 4)

        if model.recentWarningAndErrorLogSnippets.isEmpty {
            Text(model.recentLogSnippetStatus)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LabTheme.textSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(model.recentWarningAndErrorLogSnippets.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(LabTheme.text)
                        .textSelection(.enabled)
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                                .fill(Color.black.opacity(0.18))
                        )
                }
            }
        }
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                model.refreshRecentLogSnippetsIfNeeded()
            }
    }

    private func diagnosticsDisclosure(
        id: DiagnosticsSectionID,
        title: String,
        defaultExpanded: Bool,
        rows: [DiagnosticsRow],
        warnings: [DiagnosticsRow]
    ) -> some View {
        diagnosticsDisclosure(id: id, title: title, defaultExpanded: defaultExpanded, warnings: warnings) {
            diagnosticsRows(warnings)
            diagnosticsRows(rows)
        }
    }

    private func diagnosticsDisclosure<Content: View>(
        id: DiagnosticsSectionID,
        title: String,
        defaultExpanded: Bool,
        warnings: [DiagnosticsRow],
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let expansion = expansionBinding(for: id, defaultExpanded: defaultExpanded)

        return OrbisonicDisclosureTray(
            isExpanded: expansion,
            title: title,
            showsWarning: !warnings.isEmpty,
            titleFontSize: 16,
            contentTopPadding: 8,
            contentSpacing: 10,
            style: .diagnostics
        ) {
            content()
        }
    }

    private func diagnosticsInlineDisclosure<Content: View>(
        id: DiagnosticsSectionID,
        title: String,
        defaultExpanded: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let expansion = expansionBinding(for: id, defaultExpanded: defaultExpanded)

        return OrbisonicDisclosureTray(
            isExpanded: expansion,
            title: title,
            titleFontSize: 12,
            headerMinHeight: 30,
            contentTopPadding: 8,
            contentSpacing: 8,
            style: .inline
        ) {
            content()
        }
    }

    private func diagnosticsPanel<Content: View>(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LabTheme.text)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                .fill(LabTheme.panelSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                        .stroke(LabTheme.line, lineWidth: 1)
                )
        )
    }

    private var diagnosticsSummaryHeader: some View {
        HStack(spacing: 12) {
            Text("NAME")
                .frame(width: 150, alignment: .leading)
            Text("STATE")
                .frame(width: 70, alignment: .leading)
            Text("STATUS")
                .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear
                .frame(width: 28, height: 1)
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(LabTheme.textSoft)
    }

    private func diagnosticsSummarySection(
        _ group: DiagnosticsSummaryGroup,
        rows: [DiagnosticsSummaryRow]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.rawValue.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(LabTheme.cyan)
                .padding(.top, group == .orbisonic ? 0 : 4)

            ForEach(rows) { row in
                diagnosticsSummaryRow(row)
            }
        }
    }

    private func diagnosticsSummaryRow(_ row: DiagnosticsSummaryRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(row.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(LabTheme.textSoft)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 150, alignment: .leading)

            Text(row.state.label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(valueColor(for: row.state.tone))
                .lineLimit(1)
                .frame(width: 70, alignment: .leading)

            Text(row.status)
                .font(.system(size: 12, weight: .semibold, design: row.monospace ? .monospaced : .default))
                .foregroundStyle(valueColor(for: row.state.tone))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .topLeading)

            if let copyValue = row.copyValue ?? copyableDiagnosticValue(in: row.status) {
                diagnosticCopyButton(value: copyValue, label: row.name)
            } else {
                Color.clear
                    .frame(width: 28, height: 24)
            }
        }
        .padding(row.state == .fault ? 8 : 0)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                .fill(row.state == .fault ? LabTheme.red.opacity(0.08) : Color.clear)
        )
    }

    private func diagnosticsRows(_ rows: [DiagnosticsRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { row in
                diagnosticsRow(row)
            }
        }
    }

    private func diagnosticsRow(_ row: DiagnosticsRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(row.label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(labelColor(for: row))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 188, alignment: .leading)

            Text(row.value)
                .font(.system(size: 12, weight: .semibold, design: row.monospace ? .monospaced : .default))
                .foregroundStyle(valueColor(for: row))
                .textSelection(.enabled)
                .lineLimit(row.monospace ? 3 : 2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .topLeading)

            if let copyValue = copyableDiagnosticValue(in: row.value) {
                diagnosticCopyButton(value: copyValue, label: row.label)
            }
        }
        .padding(row.isWarning ? 8 : 0)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                .fill(row.isWarning ? valueColor(for: row).opacity(0.08) : Color.clear)
        )
    }

    private func diagnosticSubsection(_ title: String, rows: [DiagnosticsRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(LabTheme.cyan)
            diagnosticsRows(rows)
        }
        .padding(.top, 4)
    }

    private func diagnosticControlGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(LabTheme.cyan)
            content()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                .fill(Color.black.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                        .stroke(LabTheme.line, lineWidth: 1)
                )
        )
    }

    private func diagnosticCopyButton(value: String, label: String) -> some View {
        Button {
            copyDiagnosticValue(value)
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LabTheme.cyan)
                .frame(width: 28, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                        .fill(Color.black.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                                .stroke(LabTheme.line, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .help("Copy \(label)")
        .accessibilityLabel("Copy \(label)")
    }

    private func copyDiagnosticValue(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func copyableDiagnosticValue(in value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = firstRegexMatch(
            pattern: #"https?://(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?[^\s,)]*"#,
            in: trimmed
        ) {
            return url
        }

        if let ip = firstRegexMatch(pattern: #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#, in: trimmed),
           isIPv4Address(ip) {
            return ip
        }

        return nil
    }

    private func firstRegexMatch(pattern: String, in value: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range),
              let matchRange = Range(match.range, in: value) else {
            return nil
        }
        return String(value[matchRange])
    }

    private func isIPv4Address(_ value: String) -> Bool {
        let parts = value.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let octet = Int(part) else { return false }
            return (0...255).contains(octet)
        }
    }

    private func expansionBinding(for id: DiagnosticsSectionID, defaultExpanded: Bool) -> Binding<Bool> {
        Binding(
            get: { expansionOverrides[id] ?? defaultExpanded },
            set: { isExpanded in
                expansionOverrides[id] = isExpanded
                if id == .logsSupport, isExpanded {
                    model.refreshRecentLogSnippetsIfNeeded()
                }
            }
        )
    }

    private func outputRows(_ rows: [InputSourceStatusRow]) -> [DiagnosticsRow] {
        rows.map {
            let lowerTitle = $0.title.lowercased()
            return DiagnosticsRow(
                label: outputLabel($0.title),
                value: $0.value,
                tone: lowerTitle.contains("warning") || $0.value.localizedCaseInsensitiveContains("blocked") ? .warning : .normal,
                monospace: lowerTitle.contains("uid")
            )
        }
    }

    private func outputLabel(_ title: String) -> String {
        switch title {
        case "selected device":
            return "Selected device"
        case "resolved device":
            return "Resolved device"
        case "device UID", "resolved device UID":
            return "Device UID"
        case "transport":
            return "Transport"
        case "channels":
            return "Channels"
        case "sample rate":
            return "Sample rate"
        case "safety":
            return "Safety"
        case "feedback loop":
            return "Feedback loop"
        default:
            return title
        }
    }

    private var expectedInputDeviceText: String {
        model.sourceMode.expectedLoopback?.displayName ?? "No live input route"
    }

    private var liveCaptureFormatText: String {
        guard model.sourceMode.isLiveInput else { return "No live capture" }
        return "\(model.inputRoute.displayName) • \(model.activeLiveChannelCount) active of \(model.inputRoute.inputChannelCount) ch • \(formatSampleRate(model.inputRoute.nominalSampleRate))"
    }

    private var signalStateText: String {
        switch model.liveAudioSignalState {
        case .receiving:
            return "signal present"
        case .briefSilence:
            return "brief silence"
        case .silentPassage:
            return "silent passage"
        case .noSignal:
            return "no signal"
        case .unknown:
            return "unknown"
        }
    }

    private var roonBridgePlaybackIsActive: Bool {
        if let state = model.roonBridgeSnapshot.selectedZone?.state.lowercased() {
            return state == "playing" || state == "loading"
        }
        if let state = model.roonNowPlaying?.state.lowercased() {
            return state == "playing" || state == "loading"
        }
        return false
    }

    private var roonPlaybackReceivingText: String {
        guard roonBridgePlaybackIsActive else { return "Roon is not reporting playback" }
        return model.liveAudioSignalState.isRecentlyReceiving ? "Yes" : "No"
    }

    private var spotifyReceiverHasFailure: Bool {
        switch model.spotifyReceiverStatus.state {
        case .failed, .embeddedModuleUnavailable:
            return true
        case .notStarted, .waitingForConnection, .restarting, .running:
            return false
        }
    }

    private var spotifyIsActiveTargetText: String {
        guard model.sourceMode == .spotify else { return "No" }
        if model.spotifyHasActiveSessionForStatus {
            return "Yes"
        }
        return "No"
    }

    private var spotifyLoopbackAvailabilityText: String {
        if model.inputRoute.isSpotifyLoopback {
            return "Selected: \(model.inputRoute.deviceName)"
        }
        if let route = model.availableInputRoutes.first(where: \.isSpotifyLoopback) {
            return "Available: \(route.deviceName)"
        }
        return "Unavailable"
    }

    private var outputPointsToOrbisonicLoopback: Bool {
        model.monitorOutputRoute.isOrbisonicLoopback || model.rendererOutputRoute.isOrbisonicLoopback || model.outputRoute.isOrbisonicLoopback
    }

    private func signalPlaybackMismatchWarning(sourceName: String) -> String {
        let seconds = model.liveAudioSignalSilenceDuration.map { " for \($0)s" } ?? ""
        return "\(sourceName) reports playback, but Orbisonic has not received signal\(seconds)."
    }

    private func dateText(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatSampleRate(_ sampleRate: Double) -> String {
        guard sampleRate > 0 else { return "unknown" }
        let kilohertz = sampleRate / 1_000
        if abs(kilohertz.rounded() - kilohertz) < 0.01 {
            return "\(Int(kilohertz.rounded())) kHz"
        }
        return String(format: "%.1f kHz", kilohertz)
    }

    private func redactedPath(_ value: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard !home.isEmpty else { return value }
        return value.replacingOccurrences(of: home, with: "~")
    }

    private func redactedControlURL(_ value: String) -> String {
        value.replacingOccurrences(
            of: #"(#token=)[A-Za-z0-9_-]+"#,
            with: "$1REDACTED",
            options: .regularExpression
        )
    }

    private func labelColor(for row: DiagnosticsRow) -> Color {
        switch row.tone {
        case .warning:
            return LabTheme.amber
        case .error:
            return LabTheme.red
        case .normal, .secondary:
            return LabTheme.textSoft
        }
    }

    private func valueColor(for row: DiagnosticsRow) -> Color {
        valueColor(for: row.tone)
    }

    private func valueColor(for tone: DiagnosticsRowTone) -> Color {
        switch tone {
        case .warning:
            return LabTheme.amber
        case .error:
            return LabTheme.red
        case .secondary:
            return LabTheme.textSoft
        case .normal:
            return LabTheme.text
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

private struct DiagnosticToneMeterStrip: View {
    let title: String
    @ObservedObject var meterStore: ChannelMeterStore
    let isActive: Bool
    let accent: Color
    var hidesWhenSilent = false

    private var sortedMeters: [ChannelMeter] {
        meterStore.channelMeters.sorted { lhs, rhs in
            if lhs.channel.role.displayOrder == rhs.channel.role.displayOrder {
                return lhs.channel.index < rhs.channel.index
            }
            return lhs.channel.role.displayOrder < rhs.channel.role.displayOrder
        }
    }

    private var activeCount: Int {
        guard isActive else { return 0 }
        return sortedMeters.filter { $0.level >= 0.005 }.count
    }

    @ViewBuilder
    var body: some View {
        if hidesWhenSilent && activeCount == 0 {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accent)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }

                if !sortedMeters.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 32, maximum: 46), spacing: 6)],
                        alignment: .leading,
                        spacing: 6
                    ) {
                        ForEach(sortedMeters, id: \.id) { meter in
                            DiagnosticToneMeterCell(
                                meter: meter,
                                isActive: isActive,
                                accent: accent
                            )
                        }
                    }
                }
            }
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                    .fill(Color.black.opacity(0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                            .stroke(accent.opacity(isActive ? 0.34 : 0.16), lineWidth: 1)
                    )
            )
        }
    }
}

private struct DiagnosticToneMeterCell: View {
    let meter: ChannelMeter
    let isActive: Bool
    let accent: Color

    private var level: Float {
        guard isActive else { return 0 }
        return min(max(meter.level, 0), 1)
    }

    private var fillColor: Color {
        level >= 0.72 ? LabTheme.amber : accent
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.black.opacity(0.26))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(fillColor.opacity(level > 0 ? 0.92 : 0.16))
                    .frame(height: max(2, CGFloat(level) * 28))
            }
            .frame(height: 28)

            Text(VUMeterChannelLabel.text(for: meter.channel))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(level > 0 ? LabTheme.text : LabTheme.textSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 32, minHeight: 45)
        .opacity(isActive ? 1 : 0.46)
        .accessibilityLabel("\(VUMeterChannelLabel.text(for: meter.channel)) \(Int((level * 100).rounded())) percent")
    }
}
