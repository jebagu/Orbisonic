import AVFoundation
import SwiftUI

private enum StageTab: String, CaseIterable, Identifiable {
    case routing = "Routing"
    case outputVU = "Output"
    case renderer = "Renderer"
    case sceneTuning = "Scene Tuning"
    case localMusic = "Local Music"
    case settings = "Settings"
    case diagnostics = "Diagnostics"

    var id: String { rawValue }
}

private enum LocalMusicPanel: String, CaseIterable, Identifiable {
    case player = "Player"
    case allMusic = "All Music"
    case playlists = "Playlists"
    case queue = "Session Queue"

    var id: String { rawValue }
}

private enum LabTheme {
    static let bg = Color(red: 7.0 / 255.0, green: 16.0 / 255.0, blue: 20.0 / 255.0)
    static let bgBottom = Color(red: 2.0 / 255.0, green: 7.0 / 255.0, blue: 10.0 / 255.0)
    static let panel = Color(red: 13.0 / 255.0, green: 24.0 / 255.0, blue: 29.0 / 255.0).opacity(0.88)
    static let panelSoft = Color.white.opacity(0.045)
    static let toolbar = Color(red: 5.0 / 255.0, green: 12.0 / 255.0, blue: 15.0 / 255.0).opacity(0.68)
    static let line = Color(red: 217.0 / 255.0, green: 251.0 / 255.0, blue: 255.0 / 255.0).opacity(0.14)
    static let text = Color(red: 239.0 / 255.0, green: 252.0 / 255.0, blue: 255.0 / 255.0)
    static let textSoft = Color(red: 159.0 / 255.0, green: 185.0 / 255.0, blue: 189.0 / 255.0)
    static let cyan = Color(red: 94.0 / 255.0, green: 234.0 / 255.0, blue: 212.0 / 255.0)
    static let blue = Color(red: 96.0 / 255.0, green: 165.0 / 255.0, blue: 250.0 / 255.0)
    static let amber = Color(red: 250.0 / 255.0, green: 204.0 / 255.0, blue: 21.0 / 255.0)
    static let red = Color(red: 251.0 / 255.0, green: 113.0 / 255.0, blue: 133.0 / 255.0)

    static let panelRadius: CGFloat = 8
    static let controlRadius: CGFloat = 7
}

private struct LabButtonStyle: ButtonStyle {
    var isActive = false
    var accent = LabTheme.cyan

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(isActive ? LabTheme.text : LabTheme.textSoft)
            .frame(minHeight: 34)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                    .fill(isActive ? accent.opacity(configuration.isPressed ? 0.22 : 0.14) : Color.white.opacity(configuration.isPressed ? 0.075 : 0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                    .stroke(isActive ? accent.opacity(0.55) : LabTheme.line, lineWidth: 1)
            )
    }
}

struct ContentView: View {
    @StateObject private var model = OrbisonicViewModel()
    @State private var selectedStageTab: StageTab = .routing
    @State private var selectedLocalMusicPanel: LocalMusicPanel = .player

    var body: some View {
        HStack(spacing: 24) {
            sidebar
                .frame(width: 360)
            stage
        }
        .padding(24)
        .frame(minWidth: 1_220, minHeight: 780)
        .background(
            ZStack {
                LinearGradient(
                    colors: [LabTheme.bg, LabTheme.bgBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    colors: [LabTheme.cyan.opacity(0.17), Color.clear],
                    center: .topTrailing,
                    startRadius: 40,
                    endRadius: 760
                )
            }
        )
        .alert("Audio Error", isPresented: Binding(
            get: { model.lastError != nil },
            set: { if !$0 { model.lastError = nil } }
        )) {
            Button("OK") {
                model.lastError = nil
            }
        } message: {
            Text(model.lastError ?? "Unknown error")
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerCard
                nowPlayingSessionCard
            }
        }
    }

    private var stage: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(selectedStageTab.rawValue)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LabTheme.text)
                    .frame(height: 24, alignment: .leading)

                stageTabBar
            }

            Text(model.statusMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LabTheme.textSoft)
                .lineLimit(2)
                .frame(height: 34, alignment: .topLeading)

            selectedStageContent
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                .fill(LabTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                        .stroke(LabTheme.line, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.36), radius: 28, x: 0, y: 18)
        )
    }

    @ViewBuilder
    private var selectedStageContent: some View {
        switch selectedStageTab {
        case .routing:
            tabPage { routingTab }
        case .outputVU:
            tabPage { outputVUTab }
        case .renderer:
            tabPage { rendererTab }
        case .sceneTuning:
            tabPage { sceneTuningTab }
        case .localMusic:
            localMusicTab
        case .settings:
            tabPage { settingsTab }
        case .diagnostics:
            tabPage { diagnosticsTab }
        }
    }

    private var stageTabBar: some View {
        HStack(spacing: 4) {
            ForEach(StageTab.allCases) { tab in
                Button {
                    selectedStageTab = tab
                } label: {
                    Text(tab.rawValue)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle(isActive: selectedStageTab == tab))
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                .fill(LabTheme.toolbar)
                .overlay(
                    RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                        .stroke(LabTheme.line, lineWidth: 1)
                )
        )
    }

    private var routingTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                settingsPanel(title: "Source Selector") {
                    sourceModeSelector
                    routingPrimaryControls
                    infoRow(title: "Mode", value: model.sourceMode.rawValue)
                    infoRow(title: "App Input", value: model.inputNowText)
                    infoRow(title: "System Input", value: model.systemInputNowText)
                }

                settingsPanel(title: "Incoming Stream") {
                    infoRow(title: "Detected", value: model.sourceMode.isLiveInput ? model.inputNowText : model.sourceFlowTitle)
                    infoRow(title: "Channels", value: model.sourceMode.isLiveInput ? "\(model.activeLiveChannelCount) selected • \(model.inputRoute.inputChannelCount) available" : outputChannelText)
                    infoRow(title: "Signal", value: model.sourceMode.isLiveInput ? model.liveSignalStatus : model.sourceFlowDetail)
                    if model.sourceMode == .roonBlackHole, let signalPath = model.roonSignalPath {
                        infoRow(title: "Roon Map", value: signalPath.statusText)
                    }
                }
            }

            routingFlowGraphic

            HStack(alignment: .top, spacing: 18) {
                settingsPanel(title: "Output 1: Monitor Stream") {
                    infoRow(title: "Device", value: model.outputNowText)
                    infoRow(title: "Purpose", value: "MacBook speakers, headphones, or local confidence monitoring.")
                    infoRow(title: "Mode", value: "Monitor fold-down / headphone render")
                }

                settingsPanel(title: "Output 2: Renderer Feed") {
                    infoRow(title: "Renderer", value: model.rendererTargetText)
                    infoRow(title: "Selected In", value: "Renderer tab")
                    infoRow(title: "Layouts", value: model.rendererLayoutText)
                    infoRow(title: "Current", value: model.rendererText)
                }
            }

            inputMeters
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var routingPrimaryControls: some View {
        switch model.sourceMode {
        case .roonBlackHole:
            inputDeviceMenu
            channelCountMenu

            Button(action: model.startRoonPipe) {
                Label("Start Roon Route", systemImage: "dot.radiowaves.left.and.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LabButtonStyle(isActive: true))

        case .testTone:
            testTonePointMenu

            HStack(spacing: 10) {
                Button(action: model.playSelectedTestTone) {
                    Label("Play Tone", systemImage: "waveform")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle(isActive: true, accent: LabTheme.amber))

                Button(action: { model.stopTestTone() }) {
                    Label("Stop Tone", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle())
            }

        case .filePlayback:
            HStack(spacing: 10) {
                Button(action: model.openFile) {
                    Label("Open File", systemImage: "waveform.badge.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle(isActive: true))

                Button(action: {
                    selectedStageTab = .localMusic
                }) {
                    Label("Local Music", systemImage: "music.note.list")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle())
            }

        case .blackHoleOtherInput:
            inputDeviceMenu
            channelCountMenu

            Button(action: model.startOtherInputPipe) {
                Label("Start Live Input", systemImage: "cable.connector")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LabButtonStyle(isActive: true))
        }
    }

    private var sourceModeSelector: some View {
        HStack(spacing: 6) {
            ForEach(SourceMode.allCases) { mode in
                Button {
                    model.selectSourceMode(mode)
                } label: {
                    Text(mode.rawValue)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle(isActive: model.sourceMode == mode))
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                .fill(Color.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                        .stroke(LabTheme.line, lineWidth: 1)
                )
        )
    }

    private var channelCountMenu: some View {
        Menu {
            ForEach(model.availableLiveChannelCounts, id: \.self) { count in
                Button("\(count) ch") {
                    model.activeLiveChannelCount = count
                }
            }
        } label: {
            HStack {
                Text("CHANNELS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LabTheme.textSoft)
                Spacer()
                Text("\(model.activeLiveChannelCount) ch")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(LabTheme.text)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(LabTheme.cyan)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(LabButtonStyle())
    }

    private var inputDeviceMenu: some View {
        Menu {
            ForEach(model.availableInputRoutes) { route in
                Button(route.deviceName) {
                    model.selectInputRoute(route)
                }
                .disabled(model.sourceMode == .roonBlackHole && !route.isBlackHole)
            }
        } label: {
            HStack {
                Text("APP INPUT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LabTheme.textSoft)
                Spacer()
                Text(model.inputRoute.displayName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LabTheme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(LabTheme.cyan)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(LabButtonStyle(isActive: model.inputRoute.isAvailable))
    }

    private var testTonePointMenu: some View {
        Menu {
            ForEach(TestTonePipelinePoint.allCases) { point in
                Button(point.rawValue) {
                    model.selectedTestTonePoint = point
                }
            }
        } label: {
            HStack {
                Text("TONE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LabTheme.textSoft)
                Spacer()
                Text(model.selectedTestTonePoint.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LabTheme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(LabTheme.cyan)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(LabButtonStyle())
    }

    private var routingFlowGraphic: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Signal Flow")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LabTheme.text)
                Text("input arrives automatically; routing creates monitor and renderer streams")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LabTheme.textSoft)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            HStack(alignment: .center, spacing: 12) {
                routingNodeCard(
                    step: "Source",
                    title: model.sourceMode.rawValue,
                    detail: model.sourceFlowDetail,
                    icon: "dial.medium"
                )

                flowArrow

                routingNodeCard(
                    step: "Incoming",
                    title: "Auto-detected stream",
                    detail: model.sourceMode.isLiveInput ? model.inputNowText : model.sourceFlowTitle,
                    icon: "waveform.path.ecg"
                )

                flowArrow

                routingNodeCard(
                    step: "Routing",
                    title: "Split to two outputs",
                    detail: "Monitor stream stays local; renderer feed targets the selected Sonic Sphere or sound system.",
                    icon: "arrow.triangle.branch"
                )

                flowArrow

                VStack(spacing: 10) {
                    routingOutputCard(
                        title: "Output 1",
                        subtitle: "Monitor Stream",
                        detail: model.outputRoute.targetName,
                        icon: "headphones",
                        accent: LabTheme.blue
                    )

                    routingOutputCard(
                        title: "Output 2",
                        subtitle: "Renderer Feed",
                        detail: model.rendererSelectionText,
                        icon: "dot.radiowaves.left.and.right",
                        accent: LabTheme.cyan
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                .fill(Color.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                        .stroke(LabTheme.line, lineWidth: 1)
                )
        )
    }

    private func routingNodeCard(
        step: String,
        title: String,
        detail: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LabTheme.cyan)
                    .frame(width: 22, height: 22)
                Text(step.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LabTheme.textSoft)
                Spacer(minLength: 0)
            }

            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(LabTheme.text)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(height: 34, alignment: .bottomLeading)

            Text(detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LabTheme.textSoft)
                .lineLimit(3)
                .truncationMode(.tail)
                .frame(height: 46, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                .fill(LabTheme.panelSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                        .stroke(LabTheme.line, lineWidth: 1)
                )
        )
    }

    private func routingOutputCard(
        title: String,
        subtitle: String,
        detail: String,
        icon: String,
        accent: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(LabTheme.textSoft)
                Text(subtitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LabTheme.text)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LabTheme.textSoft)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 58)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                .fill(accent.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                        .stroke(accent.opacity(0.36), lineWidth: 1)
                )
        )
    }

    private var outputVUTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                settingsPanel(title: "Output Route") {
                    infoRow(title: "Output", value: model.outputNowText)
                    infoRow(title: "Target", value: model.targetFlowTitle)
                    infoRow(title: "Detail", value: model.targetFlowDetail)
                }

                settingsPanel(title: "Rendered Layout") {
                    infoRow(title: "Layout", value: model.sourceMetadata?.layoutName ?? "No source loaded")
                    infoRow(title: "Channels", value: outputChannelText)
                    infoRow(title: "Renderer", value: model.rendererText)
                }
            }

            outputMeters
            signalFlowPanel
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var rendererTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                settingsPanel(title: "Renderer") {
                    infoRow(title: "Engine", value: model.rendererText)
                    infoRow(title: "Mode", value: model.sourceMode == .testTone ? "Test tone render" : (model.sourceMode.isLiveInput ? "Live input render" : "Local player render"))
                    infoRow(title: "Target", value: model.targetFlowTitle)
                }

                settingsPanel(title: "Source Objects") {
                    infoRow(title: "Layout", value: model.sourceMetadata?.layoutName ?? "No source loaded")
                    infoRow(title: "Objects", value: model.renderFlowDetail)
                    infoRow(title: "Channels", value: outputChannelText)
                }
            }

            settingsPanel(title: "Spatial Scene") {
                infoRow(title: "Preset", value: model.preset.rawValue)
                infoRow(title: "Front Angle", value: String(format: "%.0f deg", model.frontAngle))
                infoRow(title: "Rear Angle", value: String(format: "%.0f deg", model.rearAngle))
                infoRow(title: "Head Tracking", value: model.headTrackingEnabled ? "Requested" : "Off")
            }

            signalFlowPanel
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var headerCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    Text("Orbisonic")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(LabTheme.text)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: model.isPlaying ? "waveform.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(model.isPlaying ? LabTheme.cyan : LabTheme.textSoft.opacity(0.42))
                        .frame(width: 24, height: 24)
                }

                Text(model.sourceMode.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LabTheme.cyan)
                    .lineLimit(1)
            }
        }
    }

    private var primaryTransportTitle: String {
        if model.sourceMode == .testTone {
            return model.isTestTonePlaying ? "Stop Tone" : "Play Tone"
        }
        if model.sourceMode.isLiveInput {
            return model.isPlaying ? "Stop Live" : "Start Live"
        }
        return model.isPlaying ? "Pause" : "Play"
    }

    private var nowPlayingTitle: String {
        if let nowPlaying = model.roonNowPlaying, model.sourceMode == .roonBlackHole {
            return nowPlaying.title
        }

        if model.sourceMode == .testTone {
            return model.selectedTestTonePoint.rawValue
        }

        if model.sourceMode == .blackHoleOtherInput, model.sourceMetadata == nil {
            return model.inputRoute.displayName
        }

        if let metadata = model.sourceMetadata {
            return metadata.fileName
        }

        return "No source loaded"
    }

    private var nowPlayingSubtitle: String {
        if let nowPlaying = model.roonNowPlaying, model.sourceMode == .roonBlackHole {
            return nowPlaying.artist.isEmpty ? "Roon via BlackHole" : nowPlaying.artist
        }

        if model.sourceMode == .testTone {
            return model.testToneStatus
        }

        if let metadata = model.sourceMetadata {
            return "\(metadata.layoutName) • \(metadata.channelCount) ch • \(metadata.sampleRateText)"
        }

        return "Choose Roon, Test Tone, Local Player, or BlackHole / Other Input."
    }

    private var nowPlayingSessionCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Text("Now Playing")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LabTheme.text)
                    Spacer()
                    Text(model.isPlaying ? "ON AIR" : "READY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(model.isPlaying ? LabTheme.bg : LabTheme.textSoft)
                        .frame(width: 58, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                                .fill(model.isPlaying ? LabTheme.cyan : LabTheme.panelSoft)
                                .overlay(
                                    RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                                        .stroke(model.isPlaying ? LabTheme.cyan.opacity(0.55) : LabTheme.line, lineWidth: 1)
                                )
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(nowPlayingTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LabTheme.text)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(height: 50, alignment: .bottomLeading)

                    Text(nowPlayingSubtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LabTheme.textSoft)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(height: 18, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Button(action: model.togglePlayback) {
                        Label(primaryTransportTitle, systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabButtonStyle(isActive: true))

                    Button(action: model.stop) {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabButtonStyle())
                }

                HStack {
                    Text(model.formattedCurrentTime())
                    Spacer()
                    Text(model.formattedDuration())
                }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(LabTheme.textSoft)

                Slider(
                    value: $model.scrubProgress,
                    in: 0...1,
                    onEditingChanged: model.scrubEditingChanged
                )
                .tint(LabTheme.cyan)
                .disabled(model.sourceMode.isLiveInput || model.sourceMode == .testTone)

                Divider()
                    .overlay(Color.white.opacity(0.08))

                if model.sourceMode == .roonBlackHole {
                    if let nowPlaying = model.roonNowPlaying {
                        VStack(alignment: .leading, spacing: 8) {
                            transportRow(title: "Format", value: nowPlaying.tidyFormatText)
                            if let signalPath = model.roonSignalPath {
                                transportRow(title: "Source Channels", value: signalPath.sourceChannelText)
                                transportRow(title: "Roon Map", value: signalPath.statusText)
                            }
                            transportRow(title: "Zone", value: model.roonZoneText)
                        }
                    } else {
                        Text(model.roonNowPlayingStatus)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LabTheme.textSoft)
                            .lineLimit(2)
                            .frame(minHeight: 36, alignment: .topLeading)
                    }
                } else if let metadata = model.sourceMetadata {
                    VStack(alignment: .leading, spacing: 8) {
                        transportRow(title: "Codec", value: "\(metadata.containerName) / \(metadata.codecName)")
                        transportRow(title: "Layout", value: metadata.layoutName)
                        transportRow(title: "Channels", value: "\(metadata.channelCount) (\(metadata.channelSummary))")
                        transportRow(title: "Rate", value: metadata.sampleRateText)
                        transportRow(title: "Length", value: metadata.durationText)
                    }
                } else {
                    Text("Load a surround mix to see file metadata here.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LabTheme.textSoft)
                        .lineLimit(2)
                        .frame(minHeight: 36, alignment: .topLeading)
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                VStack(alignment: .leading, spacing: 8) {
                    transportRow(title: "App Input", value: model.inputNowText)
                    transportRow(title: "System Input", value: model.systemInputNowText)
                    transportRow(title: "Output", value: model.outputRoute.deviceName)
                    transportRow(title: "Renderer", value: model.rendererText)
                }
            }
        }
    }

    private var sceneTuningTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Preset")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LabTheme.text)

                    presetSelector
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Scene Width")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LabTheme.text)

                    tuningSlider(title: "Front Width", value: $model.frontAngle, range: 25...55, format: "%.0f°")
                    tuningSlider(title: "Rear Wrap", value: $model.rearAngle, range: 95...155, format: "%.0f°")
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            SpatialFieldView(
                tuning: model.currentTuning(),
                channels: model.loadedChannels,
                isPlaying: model.isPlaying
            )
            .frame(minHeight: 430)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var presetSelector: some View {
        HStack(spacing: 6) {
            ForEach(SpatialPreset.allCases) { preset in
                Button {
                    model.preset = preset
                } label: {
                    Text(preset.rawValue)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle(isActive: model.preset == preset))
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                .fill(Color.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                        .stroke(LabTheme.line, lineWidth: 1)
                )
        )
    }

    private var localMusicTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            localMusicPanelSelector

            localMusicPanelContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var localMusicPanelSelector: some View {
        HStack(spacing: 4) {
            ForEach(LocalMusicPanel.allCases) { panel in
                Button {
                    selectedLocalMusicPanel = panel
                } label: {
                    Text(panel.rawValue)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle(isActive: selectedLocalMusicPanel == panel))
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                .fill(Color.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                        .stroke(LabTheme.line, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var localMusicPanelContent: some View {
        switch selectedLocalMusicPanel {
        case .player:
            localMusicPlayerPanel
        case .allMusic:
            localMusicAllTracksPanel
        case .playlists:
            localMusicPlaylistsPanel
        case .queue:
            localMusicQueuePanel
        }
    }

    private var localMusicPlayerPanel: some View {
        HStack(alignment: .top, spacing: 18) {
            settingsPanel(title: "Player") {
                HStack(spacing: 10) {
                    Button(action: model.playPreviousLocalMusicTrack) {
                        Image(systemName: "backward.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabButtonStyle())

                    Button(action: model.toggleLocalMusicPlayback) {
                        Image(systemName: model.isPlaying && model.sourceMode == .filePlayback ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabButtonStyle(isActive: true))

                    Button(action: model.stop) {
                        Image(systemName: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabButtonStyle())

                    Button(action: model.playNextLocalMusicTrack) {
                        Image(systemName: "forward.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabButtonStyle())
                }

                HStack(spacing: 10) {
                    Button(action: { model.playAllLocalMusic(shuffle: false) }) {
                        Label("Play All", systemImage: "play.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabButtonStyle())

                    Button(action: { model.playAllLocalMusic(shuffle: true) }) {
                        Label("Shuffle", systemImage: "shuffle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabButtonStyle(isActive: model.isShuffleEnabled))
                }

                infoRow(title: "Loaded", value: model.currentLocalMusicTrack?.displayTitle ?? model.loadedFileName)
                infoRow(title: "Queue", value: model.localMusicQueueText)
                infoRow(title: "Library", value: model.localMusicCountText)
            }

            settingsPanel(title: "Selected Track") {
                let track = model.selectedLocalMusicTrack ?? model.currentLocalMusicTrack
                infoRow(title: "Song", value: track?.displayTitle ?? "No track selected")
                infoRow(title: "Artist", value: track?.displayArtist ?? "-")
                infoRow(title: "Album", value: track?.displayAlbum ?? "-")
                infoRow(title: "Channels", value: track?.channelDetailText ?? "-")
                infoRow(title: "Rate", value: track?.sampleRateText ?? "-")
                infoRow(title: "Length", value: track?.durationText ?? "-")
            }
        }
    }

    private var localMusicAllTracksPanel: some View {
        settingsPanel(title: "All Music") {
            localMusicSearchSortBar
            infoRow(title: "Tracks", value: model.localMusicCountText)
            localMusicTrackList(model.visibleLocalMusicTracks)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var localMusicPlaylistsPanel: some View {
        HStack(alignment: .top, spacing: 18) {
            settingsPanel(title: "Playlists") {
                HStack(spacing: 10) {
                    Button(action: { model.playSelectedLocalMusicPlaylist(shuffle: false) }) {
                        Label("Play", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabButtonStyle(isActive: true))

                    Button(action: { model.playSelectedLocalMusicPlaylist(shuffle: true) }) {
                        Label("Shuffle", systemImage: "shuffle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabButtonStyle())
                }

                infoRow(title: "Playlists", value: model.localMusicPlaylistCountText)

                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 6) {
                        ForEach(model.localMusicPlaylists) { playlist in
                            Button {
                                model.selectedLocalMusicPlaylistID = playlist.id
                            } label: {
                                playlistLibraryRow(
                                    playlist,
                                    trackCount: model.tracks(for: playlist).count,
                                    isSelected: model.selectedLocalMusicPlaylistID == playlist.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
                .frame(minHeight: 380, maxHeight: .infinity)
                .background(localMusicListBackground)
            }

            settingsPanel(title: "Playlist Tracks") {
                let playlist = model.selectedLocalMusicPlaylist ?? model.localMusicPlaylists.first
                infoRow(title: "Playlist", value: playlist?.name ?? "No playlist selected")
                localMusicTrackList(playlist.map { model.tracks(for: $0) } ?? [])
            }
        }
    }

    private var localMusicQueuePanel: some View {
        settingsPanel(title: "Session Queue") {
            HStack(spacing: 10) {
                Button(action: model.playPreviousLocalMusicTrack) {
                    Label("Back", systemImage: "backward.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle())

                Button(action: model.playSelectedSessionQueueTrack) {
                    Label(model.isPlaying && model.sourceMode == .filePlayback ? "Pause" : "Play", systemImage: model.isPlaying && model.sourceMode == .filePlayback ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle(isActive: true))

                Button(action: model.playNextLocalMusicTrack) {
                    Label("Next", systemImage: "forward.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle())
            }

            infoRow(title: "Queue", value: model.localMusicQueueText)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 6) {
                    ForEach(Array(model.sessionQueue.enumerated()), id: \.element.id) { index, track in
                        Button {
                            model.selectSessionQueueIndex(index)
                        } label: {
                            queueTrackRow(track, index: index, isCurrent: model.sessionQueueIndex == index)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
            .frame(minHeight: 450, maxHeight: .infinity)
            .background(localMusicListBackground)
        }
    }

    private var localMusicSearchSortBar: some View {
        HStack(spacing: 10) {
            TextField("Search song, artist, album, channels, or path", text: $model.localMusicSearchText)
                .textFieldStyle(.plain)
                .foregroundStyle(LabTheme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LabTheme.panelSoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(LabTheme.line, lineWidth: 1)
                        )
                )

            localMusicSortMenu
                .frame(width: 170)
        }
    }

    private var localMusicSortMenu: some View {
        Menu {
            ForEach(PlaylistSortMode.allCases) { sortMode in
                Button(sortMode.rawValue) {
                    model.localMusicSortMode = sortMode
                }
            }
        } label: {
            HStack {
                Text("SORT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LabTheme.textSoft)
                Spacer()
                Text(model.localMusicSortMode.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LabTheme.text)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(LabTheme.cyan)
            }
        }
        .buttonStyle(LabButtonStyle())
    }

    private func localMusicTrackList(_ tracks: [LocalMusicTrack]) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 6) {
                ForEach(tracks) { track in
                    Button {
                        model.selectedLocalMusicTrackID = track.id
                    } label: {
                        trackLibraryRow(track, isSelected: model.selectedLocalMusicTrackID == track.id)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Play") {
                            model.selectedLocalMusicTrackID = track.id
                            model.toggleLocalMusicPlayback()
                        }
                    }
                }
            }
            .padding(8)
        }
        .frame(minHeight: 420, maxHeight: .infinity)
        .background(localMusicListBackground)
    }

    private var localMusicListBackground: some View {
        RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
            .fill(Color.black.opacity(0.18))
            .overlay(
                RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                    .stroke(LabTheme.line, lineWidth: 1)
            )
    }

    private func trackLibraryRow(_ track: LocalMusicTrack, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: model.currentFileURL?.path == track.id ? "speaker.wave.2.fill" : "music.note")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(model.currentFileURL?.path == track.id ? LabTheme.cyan : LabTheme.textSoft.opacity(isSelected ? 0.86 : 0.56))
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LabTheme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(track.displaySubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LabTheme.textSoft)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 3) {
                Text(track.channelText)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(LabTheme.cyan)
                    .lineLimit(1)
                    .frame(width: 58, alignment: .trailing)

                Text(track.durationText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(LabTheme.textSoft)
                    .lineLimit(1)
                    .frame(width: 58, alignment: .trailing)
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? LabTheme.cyan.opacity(0.10) : Color.white.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? LabTheme.cyan.opacity(0.45) : Color.clear, lineWidth: 1)
                )
        )
    }

    private func playlistLibraryRow(_ playlist: LocalMusicPlaylist, trackCount: Int, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? LabTheme.cyan : LabTheme.textSoft.opacity(0.72))
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LabTheme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(playlist.fileName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LabTheme.textSoft)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            Text("\(trackCount)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(LabTheme.cyan)
                .frame(width: 42, alignment: .trailing)
        }
        .frame(height: 46)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? LabTheme.cyan.opacity(0.10) : Color.white.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? LabTheme.cyan.opacity(0.45) : Color.clear, lineWidth: 1)
                )
        )
    }

    private func queueTrackRow(_ track: LocalMusicTrack, index: Int, isCurrent: Bool) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(isCurrent ? LabTheme.bg : LabTheme.textSoft)
                .frame(width: 30, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isCurrent ? LabTheme.cyan : LabTheme.panelSoft)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(track.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LabTheme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(track.displaySubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LabTheme.textSoft)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            Text(track.channelText)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(isCurrent ? LabTheme.cyan : LabTheme.textSoft)
                .frame(width: 58, alignment: .trailing)
        }
        .frame(height: 46)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isCurrent ? LabTheme.cyan.opacity(0.10) : Color.white.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isCurrent ? LabTheme.cyan.opacity(0.45) : Color.clear, lineWidth: 1)
                )
        )
    }

    private var settingsTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                settingsPanel(title: "Watch Folders") {
                    HStack(spacing: 10) {
                        Button(action: model.chooseWatchFolder) {
                            Label("Add Folder", systemImage: "folder.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LabButtonStyle(isActive: true))

                        Button(action: model.rescanLocalMusicLibrary) {
                            Label("Rescan", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LabButtonStyle())
                    }

                    Toggle(
                        "Search subfolders",
                        isOn: Binding(
                            get: { model.localMusicSettings.scansSubfolders },
                            set: model.setLocalMusicScansSubfolders
                        )
                    )
                    .toggleStyle(.switch)
                    .tint(LabTheme.cyan)

                    infoRow(title: "Folders", value: model.localMusicWatchFolderText)
                    settingsPathList(
                        paths: model.localMusicSettings.watchFolderPaths,
                        emptyText: "No watch folders yet.",
                        removeAction: model.removeWatchFolder
                    )
                }

                settingsPanel(title: "M3U Playlists") {
                    HStack(spacing: 10) {
                        Button(action: model.chooseM3UPlaylist) {
                            Label("Add M3U", systemImage: "text.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LabButtonStyle(isActive: true))

                        Button(action: model.rescanLocalMusicLibrary) {
                            Label("Rescan", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LabButtonStyle())
                    }

                    Toggle(
                        "Import M3U files",
                        isOn: Binding(
                            get: { model.localMusicSettings.importsM3UPlaylists },
                            set: model.setLocalMusicImportsM3UPlaylists
                        )
                    )
                    .toggleStyle(.switch)
                    .tint(LabTheme.cyan)

                    infoRow(title: "Playlists", value: model.localMusicPlaylistCountText)
                    settingsPathList(
                        paths: model.localMusicSettings.m3uPlaylistPaths,
                        emptyText: "No explicit M3U files yet.",
                        removeAction: model.removeM3UPlaylist
                    )
                }
            }

            settingsPanel(title: "Album Art And Local Database") {
                Toggle(
                    "Extract embedded album art",
                    isOn: Binding(
                        get: { model.localMusicSettings.extractsAlbumArt },
                        set: model.setLocalMusicExtractsAlbumArt
                    )
                )
                .toggleStyle(.switch)
                .tint(LabTheme.cyan)

                infoRow(title: "Artwork", value: model.localMusicArtworkStatusText)
                infoRow(title: "Library DB", value: model.localMusicDatabasePath)
                infoRow(title: "Art Cache", value: model.localMusicArtworkDirectoryPath)
            }
        }
    }

    private func settingsPathList(
        paths: [String],
        emptyText: String,
        removeAction: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if paths.isEmpty {
                Text(emptyText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LabTheme.textSoft)
                    .frame(height: 38, alignment: .leading)
            } else {
                ForEach(paths, id: \.self) { path in
                    HStack(spacing: 10) {
                        Image(systemName: "folder")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LabTheme.textSoft)
                            .frame(width: 18)

                        Text(path)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(LabTheme.text)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer(minLength: 0)

                        Button {
                            removeAction(path)
                        } label: {
                            Image(systemName: "xmark")
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(LabButtonStyle())
                    }
                    .frame(height: 38)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.035))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(LabTheme.line, lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    private var diagnosticsTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                settingsPanel(title: "Channel Walk") {
                    Text("Plays each diagnostic point for 1.5 seconds. This bypasses Roon and BlackHole so you can verify the app-to-headphones path directly.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LabTheme.textSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button(action: model.startDiagnosticChannelWalk) {
                            Label("Play Channel Walk", systemImage: "speaker.wave.3.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LabButtonStyle(isActive: true, accent: LabTheme.amber))
                        .disabled(model.isDiagnosticSequencePlaying)

                        Button(action: model.stopDiagnosticsAndReturnToMusic) {
                            Label("Stop & Return", systemImage: "arrow.uturn.backward.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LabButtonStyle())
                        .disabled(!model.isDiagnosticSequencePlaying)
                    }

                    infoRow(title: "Now Playing", value: model.activeDiagnosticText)
                    infoRow(title: "Output", value: model.outputNowText)
                    infoRow(title: "Status", value: model.testToneStatus)
                }

                settingsPanel(title: "What This Proves") {
                    infoRow(title: "Output Route", value: "If the first tone is silent, macOS output, headphone routing, or volume is wrong.")
                    infoRow(title: "Renderer", value: "If direct output works but positioned tones fail, the spatial renderer path is wrong.")
                    infoRow(title: "Roon Pipe", value: "If all tones work but Roon is silent, Roon is not feeding BlackHole.")
                }
            }

            diagnosticChannelGrid
            stageMeters
            signalFlowPanel
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func tabPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            content()
                .padding(.trailing, 6)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var diagnosticChannelGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
            alignment: .leading,
            spacing: 12
        ) {
            ForEach(Array(model.diagnosticToneSequence.enumerated()), id: \.element.id) { index, point in
                diagnosticPointCard(index: index + 1, point: point)
            }
        }
    }

    private func diagnosticPointCard(index: Int, point: TestTonePipelinePoint) -> some View {
        let isActive = model.activeDiagnosticPoint?.id == point.id

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(index)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isActive ? LabTheme.bg : LabTheme.textSoft)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                            .fill(isActive ? LabTheme.amber : LabTheme.panelSoft)
                    )

                Spacer()

                Circle()
                    .fill(isActive ? LabTheme.amber : LabTheme.line)
                    .frame(width: 10, height: 10)
            }

            Text(point.rawValue)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(LabTheme.text)

            Text(point.pipelineDescription)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LabTheme.textSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                .fill(isActive ? LabTheme.amber.opacity(0.12) : LabTheme.panelSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                        .stroke(isActive ? LabTheme.amber.opacity(0.65) : LabTheme.line, lineWidth: 1)
                )
        )
    }

    private var outputChannelText: String {
        guard let metadata = model.sourceMetadata else {
            return "No source loaded"
        }

        return "\(metadata.channelCount) (\(metadata.channelSummary))"
    }

    private var inputMeters: some View {
        LiveSurroundVUView(
            title: "Input VU",
            subtitle: model.sourceMode.isLiveInput ? model.inputRoute.displayName : model.loadedFileName,
            meterStore: model.meterStore
        )
    }

    private var outputMeters: some View {
        LiveSurroundVUView(
            title: "Output VU",
            subtitle: outputChannelText,
            meterStore: model.meterStore
        )
    }

    private var stageMeters: some View {
        LiveSurroundVUView(
            title: "Diagnostic VU",
            subtitle: model.activeDiagnosticText,
            meterStore: model.meterStore
        )
    }

    private var signalFlowPanel: some View {
        HStack(alignment: .center, spacing: 12) {
            flowCard(
                step: "Source",
                title: model.sourceFlowTitle,
                detail: model.sourceFlowDetail
            )

            flowArrow

            flowCard(
                step: "Render",
                title: model.renderFlowTitle,
                detail: model.renderFlowDetail
            )

            flowArrow

            flowCard(
                step: "Route",
                title: model.routeFlowTitle,
                detail: model.routeFlowDetail
            )

            flowArrow

            flowCard(
                step: "Target",
                title: model.targetFlowTitle,
                detail: model.targetFlowDetail
            )
        }
    }

    private var flowArrow: some View {
        VStack {
            Spacer()
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(LabTheme.cyan.opacity(0.52))
            Spacer()
        }
        .frame(width: 18)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                .fill(LabTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                        .stroke(LabTheme.line, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.36), radius: 18, x: 0, y: 10)
        )
    }

    private func transportRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LabTheme.textSoft)
                .lineLimit(1)
                .frame(width: 112, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LabTheme.text)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(minHeight: 32, alignment: .topLeading)
        }
    }

    private func tuningSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LabTheme.text)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .foregroundStyle(LabTheme.cyan)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
            Slider(value: value, in: range)
                .tint(LabTheme.cyan)
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LabTheme.textSoft)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LabTheme.text)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(minHeight: 32, alignment: .topLeading)
        }
    }

    private func settingsPanel<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LabTheme.text)
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

    private func flowCard(
        step: String,
        title: String,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text(step.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LabTheme.textSoft)
                Spacer(minLength: 0)
            }
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(LabTheme.text)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(height: 36, alignment: .bottomLeading)
            Text(detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LabTheme.textSoft)
                .lineLimit(3)
                .truncationMode(.tail)
                .frame(height: 42, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
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
}

private struct LiveSurroundVUView: View {
    let title: String
    let subtitle: String
    @ObservedObject var meterStore: ChannelMeterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LabTheme.text)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LabTheme.textSoft)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 0)
            }
            .frame(height: 22, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(meterStore.channelMeters.sorted(by: meterSort), id: \.id) { meter in
                        VStack(spacing: 8) {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                                            .stroke(LabTheme.line, lineWidth: 1)
                                    )
                                    .frame(width: 54, height: 144)
                                RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                                    .fill(meterGradient(for: meter.channel.role))
                                    .frame(width: 54, height: max(12, 144 * CGFloat(meter.level)))
                            }
                            VStack(spacing: 2) {
                                Text(meter.channel.shortLabel)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(LabTheme.text)
                                    .lineLimit(1)
                                    .frame(width: 54)
                                Text("\(Int(meter.level * 100))%")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(LabTheme.textSoft)
                                    .lineLimit(1)
                                    .frame(width: 54)
                            }
                        }
                        .frame(width: 64)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 178)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                .fill(LabTheme.panelSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                        .stroke(LabTheme.line, lineWidth: 1)
                )
        )
        .frame(minHeight: 238, alignment: .topLeading)
    }

    private func meterSort(lhs: ChannelMeter, rhs: ChannelMeter) -> Bool {
        if lhs.channel.role.displayOrder == rhs.channel.role.displayOrder {
            return lhs.channel.index < rhs.channel.index
        }
        return lhs.channel.role.displayOrder < rhs.channel.role.displayOrder
    }

    private func meterGradient(for role: SurroundChannelRole) -> LinearGradient {
        if role.isLFE {
            LinearGradient(
                colors: [LabTheme.amber, LabTheme.amber.opacity(0.55)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if role.isRear {
            LinearGradient(
                colors: [LabTheme.blue, LabTheme.cyan.opacity(0.55)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            LinearGradient(
                colors: [LabTheme.cyan, LabTheme.blue],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

private struct SpatialFieldView: View {
    let tuning: SpatialTuning
    let channels: [SurroundChannel]
    let isPlaying: Bool

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * 0.34

                var grid = Path()
                grid.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                grid.addEllipse(in: CGRect(x: center.x - radius * 0.7, y: center.y - radius * 0.7, width: radius * 1.4, height: radius * 1.4))
                grid.move(to: CGPoint(x: center.x - radius, y: center.y))
                grid.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                grid.move(to: CGPoint(x: center.x, y: center.y - radius))
                grid.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                context.stroke(grid, with: .color(LabTheme.line), lineWidth: 1)

                let listenerRect = CGRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24)
                context.fill(Path(ellipseIn: listenerRect), with: .color(LabTheme.cyan))

                for channel in channels.displayOrdered() {
                    let position = tuning.position(for: channel)
                    let point = projectedPoint(for: position, center: center, radius: radius)
                    let color = color(for: channel.role)
                    let sizeBoost: CGFloat = isPlaying ? 6 : 0
                    let orbRect = CGRect(x: point.x - 13 - sizeBoost / 2, y: point.y - 13 - sizeBoost / 2, width: 26 + sizeBoost, height: 26 + sizeBoost)
                    context.fill(Path(ellipseIn: orbRect), with: .color(color.opacity(0.95)))
                    context.draw(
                        Text(channel.shortLabel)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(LabTheme.text),
                        at: CGPoint(x: point.x, y: point.y + 28)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            LabTheme.cyan.opacity(0.12),
                            LabTheme.bg
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 420
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                .stroke(LabTheme.line, lineWidth: 1)
        )
    }

    private func projectedPoint(for position: AVAudio3DPoint, center: CGPoint, radius: CGFloat) -> CGPoint {
        let x = center.x + CGFloat(position.x) * radius
        let y = center.y + CGFloat(position.z) * radius
        return CGPoint(x: x, y: y)
    }

    private func color(for role: SurroundChannelRole) -> Color {
        if role.isLFE {
            return LabTheme.amber
        }
        if role.isRear {
            return LabTheme.blue
        }
        return LabTheme.cyan
    }
}
