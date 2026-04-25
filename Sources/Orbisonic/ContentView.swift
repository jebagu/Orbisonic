import SceneKit
import SwiftUI

private enum StageTab: String, CaseIterable, Identifiable {
    case input = "Input"
    case routing = "Routing"
    case output = "Output"
    case renderer = "Renderer"
    case sceneTuning = "Scene Tuning"
    case localMusic = "Local Playlist"
    case diagnostics = "Diagnostics"
    case settings = "Settings"

    var id: String { rawValue }
}

private enum LocalMusicPanel: String, CaseIterable, Identifiable {
    case music = "Music"
    case playlists = "Playlists"
    case queue = "Session Queue"

    var id: String { rawValue }
}

private enum VUMeterVisualStyle: String, CaseIterable, Identifiable {
    case squarePulse = "Square Pulse"
    case squareFlicker = "Square Flicker"
    case hexPulse = "Hex Pulse"
    case hexFlicker = "Hex Flicker"

    var id: String { rawValue }

    var shapeLabel: String {
        switch self {
        case .squarePulse, .squareFlicker: "Squares"
        case .hexPulse, .hexFlicker: "Hexagons"
        }
    }

    var motionLabel: String {
        switch self {
        case .squarePulse, .hexPulse: "Pulse"
        case .squareFlicker, .hexFlicker: "Flicker"
        }
    }

    var isHex: Bool {
        switch self {
        case .hexPulse, .hexFlicker: true
        case .squarePulse, .squareFlicker: false
        }
    }

    var isFlicker: Bool {
        switch self {
        case .squareFlicker, .hexFlicker: true
        case .squarePulse, .hexPulse: false
        }
    }
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
    @AppStorage("Orbisonic.hasConfirmedLoopbackSetup") private var hasConfirmedLoopbackSetup = false
    @State private var selectedStageTab: StageTab = .input
    @State private var selectedLocalMusicPanel: LocalMusicPanel = .music
    @State private var selectedVUMeterStyle: VUMeterVisualStyle = .squarePulse
    @State private var showsLoopbackSetupDialog = false

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
        .confirmationDialog(
            "Install Orbisonic Inputs",
            isPresented: $showsLoopbackSetupDialog,
            titleVisibility: .visible
        ) {
            Button("Got It") {
                hasConfirmedLoopbackSetup = true
            }
            Button("Remind Me Later", role: .cancel) {}
        } message: {
            Text("Install Orbisonic Inputs to use Roon and Aux Cable live capture. Roon itself is optional; install it only if you want Roon playback. Local Files works without Roon.")
        }
        .onAppear {
            if !hasConfirmedLoopbackSetup {
                showsLoopbackSetupDialog = true
            }
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerCard
                nowPlayingSessionCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        case .input:
            tabPage { inputTab }
        case .routing:
            tabPage { routingTab }
        case .output:
            tabPage { outputTab }
        case .renderer:
            tabPage { rendererTab }
        case .sceneTuning:
            tabPage { sceneTuningTab }
        case .localMusic:
            localMusicTab
        case .diagnostics:
            tabPage { diagnosticsTab }
        case .settings:
            tabPage { settingsTab }
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

    private var inputTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsPanel(title: "Source Selector") {
                sourceModeSelector
                routingPrimaryControls
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var routingTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            routingFlowGraphic

            routingCompactMeters
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var routingPrimaryControls: some View {
        switch model.sourceMode {
        case .roon, .aux:
            HStack(spacing: 10) {
                Button(action: livePrimaryAction) {
                    Label(livePrimaryTitle, systemImage: livePrimaryIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle(isActive: true))

                Button(action: model.stopSelectedLiveMonitor) {
                    Label("Stop Monitor", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle())
                .disabled(!model.liveMonitorState.isCapturing)
            }

            infoRow(title: "Device", value: model.selectedSourceDeviceStatusText)
            infoRow(title: "Status", value: model.liveSignalStatus)

        case .filePlayback:
            EmptyView()

        case .testTone:
            EmptyView()
        }
    }

    private var sourceModeSelector: some View {
        HStack(spacing: 6) {
            ForEach(primarySourceModes) { mode in
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

    private var primarySourceModes: [SourceMode] {
        SourceMode.musicInputs
    }

    private var inputDeviceMenu: some View {
        Menu {
            ForEach(model.availableInputRoutes) { route in
                Button(route.deviceName) {
                    model.selectInputRoute(route)
                }
                .disabled(
                    (model.sourceMode == .roon && !route.isRoonLoopback)
                    || (model.sourceMode == .aux && !route.isAuxLoopback)
                )
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
                        subtitle: "Monitor",
                        detail: model.outputRoute.targetName,
                        icon: "headphones",
                        accent: LabTheme.blue
                    )

                    routingOutputCard(
                        title: "Output 2",
                        subtitle: "Renderer",
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

    private var routingCompactMeters: some View {
        HStack(alignment: .top, spacing: 12) {
            CompactSquareVUMeterPanel(
                title: "Input",
                subtitle: inputVUMeterSubtitle,
                accent: LabTheme.cyan,
                meterStore: model.meterStore
            )

            CompactSquareVUMeterPanel(
                title: "Monitor",
                subtitle: monitorVUMeterSubtitle,
                accent: LabTheme.blue,
                meterStore: model.monitorMeterStore
            )

            CompactSquareVUMeterPanel(
                title: "Renderer",
                subtitle: rendererVUMeterSubtitle,
                accent: LabTheme.amber,
                meterStore: model.rendererMeterStore
            )
        }
    }

    private var outputTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                settingsPanel(title: "Output 1: Monitor") {
                    monitorOutputMenu
                    infoRow(title: "Output", value: model.outputNowText)
                    infoRow(title: "Selection", value: model.monitorOutputSelectionText)
                    infoRow(title: "System", value: model.systemOutputNowText)
                    infoRow(title: "Target", value: model.targetFlowTitle)
                    infoRow(title: "Detail", value: model.targetFlowDetail)
                }
                .frame(maxWidth: .infinity, minHeight: 236, alignment: .topLeading)

                settingsPanel(title: "Output 2: Renderer") {
                    infoRow(title: "Layout", value: model.sourceMetadata?.layoutName ?? "No source loaded")
                    infoRow(title: "Channels", value: outputChannelText)
                    infoRow(title: "Renderer", value: model.rendererText)
                    infoRow(title: "Safety", value: model.outputSafetyText)
                }
                .frame(maxWidth: .infinity, minHeight: 236, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var monitorOutputMenu: some View {
        Menu {
            Button("System Default") {
                model.selectSystemMonitorOutput()
            }

            Divider()

            ForEach(model.availableOutputRoutes) { route in
                Button(route.deviceName) {
                    model.selectMonitorOutputRoute(route)
                }
            }
        } label: {
            HStack {
                Text("MONITOR")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LabTheme.textSoft)
                Spacer()
                Text(model.monitorOutputSelectionText)
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
        .buttonStyle(LabButtonStyle(isActive: true))
    }

    private var vuMeterTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                DenseVUMeterPanel(
                    title: "Input",
                    subtitle: inputVUMeterSubtitle,
                    style: selectedVUMeterStyle,
                    meterStore: model.meterStore,
                    minHeight: 220
                )

                DenseVUMeterPanel(
                    title: "Monitor",
                    subtitle: monitorVUMeterSubtitle,
                    style: selectedVUMeterStyle,
                    meterStore: model.monitorMeterStore,
                    minHeight: 220
                )
            }

            DenseVUMeterPanel(
                title: "Renderer",
                subtitle: rendererVUMeterSubtitle,
                style: selectedVUMeterStyle,
                meterStore: model.rendererMeterStore,
                minHeight: 240
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var vuMeterStylePicker: some View {
        HStack(spacing: 10) {
            ForEach(VUMeterVisualStyle.allCases) { style in
                Button {
                    selectedVUMeterStyle = style
                } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        VUMeterStylePreview(style: style)
                            .frame(height: 46)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.rawValue)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LabTheme.text)
                            Text("\(style.shapeLabel) • \(style.motionLabel)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(LabTheme.textSoft)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
                .buttonStyle(LabButtonStyle(isActive: selectedVUMeterStyle == style))
            }
        }
    }

    private var inputVUMeterSubtitle: String {
        let sourceText = model.sourceMode.isLiveInput ? model.inputRoute.displayName : model.loadedFileName
        let count = model.meterStore.channelMeters.count
        return count > 0 ? "\(sourceText) • \(count) ch" : "\(sourceText) • no input channels"
    }

    private var monitorVUMeterSubtitle: String {
        let count = model.monitorMeterStore.channelMeters.count
        return "\(model.outputNowText) • \(count) ch"
    }

    private var rendererVUMeterSubtitle: String {
        let count = model.rendererMeterStore.channelMeters.count
        return "\(model.rendererText) • \(count) renderer outputs"
    }

    private var rendererTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                settingsPanel(title: "Renderer Preset") {
                    rendererPresetMenu
                    infoRow(title: "Preset", value: model.rendererPreset.name)
                    infoRow(title: "Status", value: model.rendererPresetIsDirty ? "Edited, not saved" : model.rendererPresetStatus)
                    infoRow(title: "Folder", value: model.rendererPresetDirectoryText)

                    HStack(spacing: 10) {
                        Button(action: model.saveRendererPreset) {
                            Label("Save JSON", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LabButtonStyle(isActive: model.rendererPresetIsDirty))

                        Button(action: { model.reloadRendererPresets() }) {
                            Label("Reload", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LabButtonStyle())

                        Button(action: model.revealRendererPresetFolder) {
                            Label("Folder", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LabButtonStyle())
                    }
                }

                settingsPanel(title: "Geometry") {
                    tuningSlider(title: "Input Bed Radius", value: $model.rendererBedRadius, range: 0.25...1.75, format: "%.2f")
                    infoRow(title: "Output", value: model.rendererLayoutText)
                    infoRow(title: "Layout", value: model.sourceMetadata?.layoutName ?? "No source loaded")
                    infoRow(title: "Inputs", value: "\(model.rendererScene.inputSpeakers.count) cubes")
                    infoRow(title: "Speakers", value: "\(model.rendererPreset.outputTopology.fullRangeCount) solid shell spheres")
                    infoRow(title: "Matrix", value: model.rendererText)
                }
            }

            SonicSphereRendererSceneView(
                sceneModel: model.rendererScene,
                isPlaying: model.isPlaying
            )
            .frame(minHeight: 430)
            .background(
                RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                    .fill(Color.black.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                    .stroke(LabTheme.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous))

            HStack(alignment: .top, spacing: 18) {
                settingsPanel(title: "Renderer Feed") {
                    infoRow(title: "Mode", value: model.sourceMode == .testTone ? "Test tone render" : (model.sourceMode.isLiveInput ? "Live input render" : "Local player render"))
                    infoRow(title: "Target", value: model.rendererTargetText)
                    infoRow(title: "Objects", value: model.renderFlowDetail)
                }

                settingsPanel(title: "Monitor Path") {
                    infoRow(title: "Output", value: "Two-channel downmix")
                    infoRow(title: "Device", value: model.outputNowText)
                    infoRow(title: "Scope", value: "Independent from Sonic Sphere matrix")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var rendererPresetMenu: some View {
        Menu {
            ForEach(model.rendererPresets) { preset in
                Button(preset.name) {
                    model.selectRendererPreset(preset)
                }
            }
        } label: {
            HStack {
                Text("JSON PRESET")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LabTheme.textSoft)
                Spacer()
                Text(model.rendererPreset.name)
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
        .buttonStyle(LabButtonStyle(isActive: true))
    }

    private var sceneTuningTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                settingsPanel(title: "Spatial Bed") {
                    tuningSlider(title: "Input Bed Radius", value: $model.rendererBedRadius, range: 0.25...1.75, format: "%.2f")
                    tuningSlider(title: "Front Angle", value: $model.frontAngle, range: 20...120, format: "%.0f")
                    tuningSlider(title: "Rear Angle", value: $model.rearAngle, range: 90...180, format: "%.0f")

                    Toggle("Head tracking", isOn: $model.headTrackingEnabled)
                        .toggleStyle(.switch)
                        .tint(LabTheme.cyan)
                }

                settingsPanel(title: "Active Source") {
                    infoRow(title: "Source", value: model.sourceMode.rawValue)
                    infoRow(title: "Input", value: model.selectedSourceDeviceStatusText)
                    infoRow(title: "Layout", value: model.sourceMetadata?.layoutName ?? "No source loaded")
                    infoRow(title: "Renderer", value: model.rendererText)
                }
            }

            SonicSphereRendererSceneView(
                sceneModel: model.rendererScene,
                isPlaying: model.isPlaying
            )
            .frame(minHeight: 500)
            .background(
                RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                    .fill(Color.black.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                    .stroke(LabTheme.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous))
        }
    }

    private var headerCard: some View {
        card {
            Text("Orbisonic 1.0")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(LabTheme.text)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var primaryTransportTitle: String {
        if model.sourceMode == .testTone {
            return model.isTestTonePlaying ? "Stop Tone" : "Play Tone"
        }
        if model.sourceMode.isLiveInput {
            return livePrimaryTitle
        }
        return model.isPlaying ? "Pause" : "Play"
    }

    private var primaryTransportIcon: String {
        if model.sourceMode.isLiveInput {
            return livePrimaryIcon
        }
        return model.isPlaying ? "pause.fill" : "play.fill"
    }

    private var secondaryTransportTitle: String {
        model.sourceMode.isLiveInput ? model.sourceMode.stopMonitorLabel : "Stop"
    }

    private var statusChipText: String {
        if model.sourceMode.isLiveInput {
            return model.liveMonitorState.statusLabel
        }
        if model.sourceMode == .testTone {
            return model.isTestTonePlaying ? "TONE" : "READY"
        }
        return model.isPlaying ? "PLAYING" : "READY"
    }

    private var statusChipIsActive: Bool {
        if model.sourceMode.isLiveInput {
            return model.liveMonitorState == .monitoring
        }
        return model.isPlaying || model.isTestTonePlaying
    }

    private var livePrimaryTitle: String {
        if model.liveMonitorState.isMuted {
            return "Resume Monitor"
        }
        if model.liveMonitorState.isCapturing {
            return model.sourceMode.muteActionLabel
        }
        return model.sourceMode.monitorActionLabel
    }

    private var livePrimaryIcon: String {
        if model.liveMonitorState.isMuted {
            return "speaker.wave.2.fill"
        }
        if model.liveMonitorState.isCapturing {
            return "speaker.slash.fill"
        }
        return "waveform.path.ecg"
    }

    private func livePrimaryAction() {
        if model.liveMonitorState.isMuted {
            model.resumeLiveMonitor()
        } else if model.liveMonitorState.isCapturing {
            model.muteLiveMonitor()
        } else {
            model.startSelectedLiveMonitor()
        }
    }

    private var nowPlayingTitle: String {
        if model.sourceMode == .roon, let title = model.roonTransportTitleText, !title.isEmpty {
            return title
        }

        if let nowPlaying = model.roonNowPlaying, model.sourceMode == .roon {
            return nowPlaying.title
        }

        if model.sourceMode == .testTone {
            return model.selectedTestTonePoint.rawValue
        }

        if model.sourceMode == .aux {
            return "Aux Cable"
        }

        if model.sourceMode == .filePlayback, let track = model.selectedLocalMusicTrack {
            return track.displayTitle
        }

        if let metadata = model.sourceMetadata {
            return metadata.fileName
        }

        return "No source loaded"
    }

    private var nowPlayingSubtitle: String {
        if model.sourceMode == .roon, let subtitle = model.roonTransportSubtitleText, !subtitle.isEmpty {
            return subtitle
        }

        if let nowPlaying = model.roonNowPlaying, model.sourceMode == .roon {
            return nowPlaying.artist.isEmpty ? "Roon" : nowPlaying.artist
        }

        if model.sourceMode == .testTone {
            return model.testToneStatus
        }

        if model.sourceMode == .aux {
            return model.selectedSourceDeviceStatusText
        }

        if model.sourceMode == .filePlayback, let track = model.selectedLocalMusicTrack {
            return track.displaySubtitle
        }

        if let metadata = model.sourceMetadata {
            return "\(metadata.layoutName) • \(metadata.channelCount) ch • \(metadata.sampleRateText)"
        }

        return "Choose Roon, Aux Cable, or Local Files."
    }

    private var nowPlayingSessionCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Text("Player")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LabTheme.text)
                    Spacer()
                    Text(statusChipText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(statusChipIsActive ? LabTheme.bg : LabTheme.textSoft)
                        .frame(width: 86, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                                .fill(statusChipIsActive ? LabTheme.cyan : LabTheme.panelSoft)
                                .overlay(
                                    RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                                        .stroke(statusChipIsActive ? LabTheme.cyan.opacity(0.55) : LabTheme.line, lineWidth: 1)
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
                    Button(action: primaryNowPlayingAction) {
                        Label(primaryTransportTitle, systemImage: primaryTransportIcon)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabButtonStyle(isActive: true))

                    Button(action: secondaryNowPlayingAction) {
                        Label(secondaryTransportTitle, systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LabButtonStyle())
                }

                if model.sourceMode == .roon {
                    roonTransportControls
                } else if model.sourceMode == .filePlayback {
                    localMusicNowPlayingControls
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

                if model.sourceMode == .roon {
                    if let nowPlaying = model.roonNowPlaying {
                        VStack(alignment: .leading, spacing: 8) {
                            transportRow(title: "Roon API", value: model.roonTransportStatusText)
                            transportRow(title: "Format", value: nowPlaying.tidyFormatText)
                            if let signalPath = model.roonSignalPath {
                                transportRow(title: "Source Channels", value: signalPath.sourceChannelText)
                                transportRow(title: "Roon Map", value: signalPath.statusText)
                            }
                            transportRow(title: "Zone", value: model.roonZoneText)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            transportRow(title: "Roon API", value: model.roonTransportStatusText)
                            Text(model.roonNowPlayingStatus)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(LabTheme.textSoft)
                                .lineLimit(2)
                                .frame(minHeight: 36, alignment: .topLeading)
                        }
                    }
                } else if model.sourceMode == .aux {
                    VStack(alignment: .leading, spacing: 8) {
                        transportRow(title: "Device", value: model.selectedSourceDeviceStatusText)
                        transportRow(title: "Signal", value: model.liveSignalStatus)
                        transportRow(title: "Buffer", value: model.liveBufferStatus)
                        transportRow(title: "Control", value: "Playback is controlled in the source app.")
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
                    transportRow(title: "Input", value: nowPlayingInputText)
                    transportRow(title: "System Input", value: model.systemInputNowText)
                    transportRow(title: "Output", value: model.outputRoute.deviceName)
                    transportRow(title: "Renderer", value: model.rendererText)
                }
            }
        }
    }

    private var nowPlayingInputText: String {
        if model.sourceMode.isLiveInput {
            return model.selectedSourceDeviceStatusText
        }
        if model.sourceMode == .testTone {
            return "Diagnostics"
        }
        return model.currentLocalMusicTrack?.displayTitle ?? model.loadedFileName
    }

    private func primaryNowPlayingAction() {
        if model.sourceMode.isLiveInput {
            livePrimaryAction()
        } else if model.sourceMode == .filePlayback, !model.localMusicTracks.isEmpty {
            model.toggleLocalMusicPlayback()
        } else {
            model.togglePlayback()
        }
    }

    private func secondaryNowPlayingAction() {
        if model.sourceMode.isLiveInput {
            model.stopSelectedLiveMonitor()
        } else {
            model.stop()
        }
    }

    private var localMusicNowPlayingControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: model.playPreviousLocalMusicTrack) {
                    Label("Back", systemImage: "backward.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle())

                Button(action: model.playNextLocalMusicTrack) {
                    Label("Next", systemImage: "forward.fill")
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
        }
        .disabled(model.localMusicTracks.isEmpty)
    }

    private var roonTransportControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                roonTransportButton(
                    systemImage: "backward.fill",
                    help: "Previous in Roon",
                    control: .previous,
                    action: model.playPreviousRoonTrack
                )

                roonTransportButton(
                    systemImage: model.isRoonTransportPlaying ? "pause.fill" : "play.fill",
                    help: model.isRoonTransportPlaying ? "Pause Roon" : "Play Roon",
                    control: model.isRoonTransportPlaying ? .pause : .play,
                    isActive: model.isRoonTransportPlaying,
                    action: model.toggleRoonTransport
                )

                roonTransportButton(
                    systemImage: "stop.fill",
                    help: "Stop Roon",
                    control: .stop,
                    action: model.stopRoonTransport
                )

                roonTransportButton(
                    systemImage: "forward.fill",
                    help: "Next in Roon",
                    control: .next,
                    action: model.playNextRoonTrack
                )
            }

            Text(model.roonTransportCompactStatusText)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(model.roonBridgeSnapshot.isReadyForTransport ? LabTheme.cyan : LabTheme.textSoft)
                .lineLimit(1)
                .frame(height: 14, alignment: .leading)
        }
    }

    private func roonTransportButton(
        systemImage: String,
        help: String,
        control: RoonBridgeControl,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(LabButtonStyle(isActive: isActive))
        .disabled(!model.canSendRoonTransport(control))
        .help(help)
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
        case .music:
            localMusicAllTracksPanel
        case .playlists:
            localMusicPlaylistsPanel
        case .queue:
            localMusicQueuePanel
        }
    }

    private var localMusicAllTracksPanel: some View {
        settingsPanel(title: "Music") {
            localMusicSearchSortBar
            infoRow(title: "Tracks", value: model.localMusicCountText)
            localMusicTrackList(model.visibleLocalMusicTracks)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var localMusicPlaylistsPanel: some View {
        settingsPanel(title: "Playlists") {
            HStack(spacing: 10) {
                Button(action: { model.addSelectedLocalMusicPlaylistToQueue(shuffle: false) }) {
                    Label("Add to Queue", systemImage: "text.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LabButtonStyle(isActive: true))

                Button(action: { model.addSelectedLocalMusicPlaylistToQueue(shuffle: true) }) {
                    Label("Shuffle to Queue", systemImage: "shuffle")
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
                        .contextMenu {
                            Button("Add to Queue") {
                                model.addLocalMusicPlaylistToQueue(playlist, shuffle: false)
                            }
                            Button("Shuffle to Queue") {
                                model.addLocalMusicPlaylistToQueue(playlist, shuffle: true)
                            }
                        }
                    }
                }
                .padding(8)
            }
            .frame(minHeight: 480, maxHeight: .infinity)
            .background(localMusicListBackground)
        }
    }

    private var localMusicQueuePanel: some View {
        settingsPanel(title: "Session Queue") {
            infoRow(title: "Queue", value: model.localMusicQueueText)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 6) {
                    ForEach(Array(model.sessionQueue.enumerated()), id: \.offset) { index, track in
                        queueTrackRow(track, index: index, isCurrent: model.sessionQueueIndex == index)
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
                        Button("Add to Queue") {
                            model.addLocalMusicTrackToQueue(track)
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

            HStack(spacing: 4) {
                Button {
                    model.moveSessionQueueItemUp(index)
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(LabButtonStyle())
                .disabled(index == 0)

                Button {
                    model.moveSessionQueueItemDown(index)
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(LabButtonStyle())
                .disabled(index >= model.sessionQueue.count - 1)

                Button {
                    model.removeSessionQueueItem(index)
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(LabButtonStyle())
            }
        }
        .frame(height: 46)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            model.selectSessionQueueIndex(index)
        }
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

            settingsPanel(title: "Meter Style") {
                vuMeterStylePicker
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
                diagnosticWalkPanel(
                    title: "Monitor Channel Walk",
                    channelText: "\(model.monitorChannelWalkCount) ch",
                    actionTitle: "Walk Monitor",
                    action: model.startMonitorChannelWalk
                )

                diagnosticWalkPanel(
                    title: "Output To Renderer Channel Walk",
                    channelText: "\(model.rendererOutputChannelWalkCount) ch",
                    actionTitle: "Walk Renderer",
                    action: model.startRendererOutputChannelWalk
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func diagnosticWalkPanel(
        title: String,
        channelText: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        settingsPanel(title: title) {
            HStack(spacing: 10) {
                Button(action: action) {
                    Label(actionTitle, systemImage: "speaker.wave.3.fill")
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
                .help("Stop and return to the previous source")
            }

            HStack(spacing: 12) {
                Text(channelText)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(LabTheme.cyan)
                    .frame(width: 72, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                            .fill(LabTheme.cyan.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                                    .stroke(LabTheme.cyan.opacity(0.38), lineWidth: 1)
                            )
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.activeDiagnosticText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(LabTheme.text)
                        .lineLimit(1)
                    Text(model.testToneStatus)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(LabTheme.textSoft)
                        .lineLimit(2)
                }
            }

            infoRow(title: "Output", value: model.outputNowText)
        }
    }

    private func tabPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            content()
                .padding(.trailing, 6)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var outputChannelText: String {
        guard let metadata = model.sourceMetadata else {
            return "No source loaded"
        }

        return "\(metadata.channelCount) (\(metadata.channelSummary))"
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
        .frame(maxWidth: .infinity, alignment: .leading)
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

}

private struct CompactSquareVUMeterPanel: View {
    let title: String
    let subtitle: String
    let accent: Color
    @ObservedObject var meterStore: ChannelMeterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LabTheme.text)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LabTheme.textSoft)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(height: 18, alignment: .leading)

            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(sortedMeters, id: \.id) { meter in
                            compactSquare(meter: meter, date: context.date)
                        }
                    }
                    .padding(.horizontal, 1)
                    .padding(.vertical, 2)
                }
                .frame(height: 42)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                .fill(Color.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                        .stroke(LabTheme.line, lineWidth: 1)
                )
        )
    }

    private var sortedMeters: [ChannelMeter] {
        meterStore.channelMeters.sorted { lhs, rhs in
            if lhs.channel.role.displayOrder == rhs.channel.role.displayOrder {
                return lhs.channel.index < rhs.channel.index
            }
            return lhs.channel.role.displayOrder < rhs.channel.role.displayOrder
        }
    }

    private func compactSquare(meter: ChannelMeter, date: Date) -> some View {
        let level = max(0, min(CGFloat(meter.level), 1))
        let phase = CGFloat((sin(date.timeIntervalSinceReferenceDate * 8 + Double(meter.channel.index) * 0.31) + 1) / 2)
        let pulse = 1 + level * (0.10 + phase * 0.16)

        return VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accent.opacity(0.12 + Double(level) * 0.78))
                .frame(width: 16, height: 16)
                .scaleEffect(pulse)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(level > 0.02 ? accent.opacity(0.72) : LabTheme.line, lineWidth: 1)
                )
                .shadow(color: accent.opacity(Double(level) * 0.38), radius: 4, x: 0, y: 0)

            Text(meter.channel.shortLabel)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(level > 0.02 ? LabTheme.text : LabTheme.textSoft)
                .lineLimit(1)
                .frame(width: 24)
        }
        .frame(width: 24)
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

private struct DenseVUMeterPanel: View {
    let title: String
    let subtitle: String
    let style: VUMeterVisualStyle
    @ObservedObject var meterStore: ChannelMeterStore
    var minHeight: CGFloat

    private var sortedMeters: [ChannelMeter] {
        meterStore.channelMeters.sorted { lhs, rhs in
            if lhs.channel.role.displayOrder == rhs.channel.role.displayOrder {
                return lhs.channel.index < rhs.channel.index
            }
            return lhs.channel.role.displayOrder < rhs.channel.role.displayOrder
        }
    }

    private var activeCount: Int {
        sortedMeters.filter { $0.level >= 0.005 }.count
    }

    private var hotCount: Int {
        sortedMeters.filter { $0.level >= 0.72 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LabTheme.text)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LabTheme.textSoft)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)

                meterPill("CH", sortedMeters.count)
                meterPill("A", activeCount)
                meterPill("HOT", hotCount, accent: hotCount > 0 ? LabTheme.amber : LabTheme.textSoft)
            }

            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    DenseVUMeterRenderer.draw(
                        meters: sortedMeters,
                        style: style,
                        time: timeline.date.timeIntervalSinceReferenceDate,
                        context: &context,
                        size: size
                    )
                }
            }
            .frame(minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                    .fill(Color.black.opacity(0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous)
                            .stroke(LabTheme.line, lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: LabTheme.panelRadius, style: .continuous))
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
    }

    private func meterPill(_ label: String, _ value: Int, accent: Color = LabTheme.cyan) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(LabTheme.textSoft)
            Text("\(value)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                .fill(Color.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: LabTheme.controlRadius, style: .continuous)
                        .stroke(LabTheme.line, lineWidth: 1)
                )
        )
    }
}

private struct VUMeterStylePreview: View {
    let style: VUMeterVisualStyle

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let levels: [Float] = [0.28, 0.76, 0.48, 0.12, 0.92, 0.36]
                let meters = levels.enumerated().map { index, level in
                    ChannelMeter(
                        channel: SurroundChannel(index: index, role: .discrete(index)),
                        level: level
                    )
                }

                DenseVUMeterRenderer.draw(
                    meters: meters,
                    style: style,
                    time: timeline.date.timeIntervalSinceReferenceDate,
                    context: &context,
                    size: size,
                    showLabels: false
                )
            }
        }
    }
}

private struct DenseMeterCell {
    let index: Int
    let center: CGPoint
    let rect: CGRect
    let size: CGFloat
    let radius: CGFloat
}

private enum DenseVUMeterRenderer {
    static func draw(
        meters: [ChannelMeter],
        style: VUMeterVisualStyle,
        time: TimeInterval,
        context: inout GraphicsContext,
        size: CGSize,
        showLabels: Bool = true
    ) {
        let background = Path(CGRect(origin: .zero, size: size))
        context.fill(background, with: .color(LabTheme.bg.opacity(0.22)))

        guard !meters.isEmpty else {
            context.draw(
                Text("NO CHANNELS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(LabTheme.textSoft),
                at: CGPoint(x: size.width / 2, y: size.height / 2)
            )
            return
        }

        if style.isHex {
            let cells = hexCells(count: meters.count, size: size)
            for (meter, cell) in zip(meters, cells) {
                drawHex(meter: meter, cell: cell, style: style, time: time, context: &context, showLabels: showLabels)
            }
        } else {
            let cells = squareCells(count: meters.count, size: size)
            for (meter, cell) in zip(meters, cells) {
                drawSquare(meter: meter, cell: cell, style: style, time: time, context: &context, showLabels: showLabels)
            }
        }
    }

    private static func squareCells(count: Int, size: CGSize) -> [DenseMeterCell] {
        let padding = max(CGFloat(12), min(size.width, size.height) * 0.055)
        let aspect = size.width / max(size.height, 1)
        var best: (cols: Int, rows: Int, side: CGFloat, gap: CGFloat, score: CGFloat)?

        for cols in 1...max(count, 1) {
            let rows = Int(ceil(Double(count) / Double(cols)))
            let gapRatio: CGFloat = count > 50 ? 0.11 : count > 20 ? 0.14 : 0.18
            let side = min(
                (size.width - padding * 2) / (CGFloat(cols) + gapRatio * CGFloat(max(cols - 1, 0))),
                (size.height - padding * 2) / (CGFloat(rows) + gapRatio * CGFloat(max(rows - 1, 0)))
            )
            guard side > 1 else { continue }

            let gridAspect = CGFloat(cols) / CGFloat(max(rows, 1))
            let score = side - abs(log(gridAspect / aspect)) * 5
            if best == nil || score > best!.score {
                best = (cols, rows, side, side * gapRatio, score)
            }
        }

        guard let best else { return [] }

        let gridWidth = CGFloat(best.cols) * best.side + CGFloat(max(best.cols - 1, 0)) * best.gap
        let gridHeight = CGFloat(best.rows) * best.side + CGFloat(max(best.rows - 1, 0)) * best.gap
        let startX = (size.width - gridWidth) / 2
        let startY = (size.height - gridHeight) / 2

        return (0..<count).map { index in
            let col = index % best.cols
            let row = index / best.cols
            let rect = CGRect(
                x: startX + CGFloat(col) * (best.side + best.gap),
                y: startY + CGFloat(row) * (best.side + best.gap),
                width: best.side,
                height: best.side
            )
            return DenseMeterCell(index: index, center: CGPoint(x: rect.midX, y: rect.midY), rect: rect, size: best.side, radius: best.side / 2)
        }
    }

    private static func hexCells(count: Int, size: CGSize) -> [DenseMeterCell] {
        let padding = max(CGFloat(12), min(size.width, size.height) * 0.055)
        let gapRatio: CGFloat = count > 50 ? 0.12 : count > 20 ? 0.16 : 0.2
        let sqrt3 = CGFloat(sqrt(3.0))
        var best: (cols: Int, rows: Int, radius: CGFloat, score: CGFloat)?

        for cols in 1...max(count, 1) {
            let rows = Int(ceil(Double(count) / Double(cols)))
            let widthFactor = CGFloat(cols) * sqrt3 + CGFloat(max(cols - 1, 0)) * gapRatio + (rows > 1 ? sqrt3 / 2 : 0)
            let heightFactor = CGFloat(2) + CGFloat(max(rows - 1, 0)) * (1.5 + gapRatio)
            let radius = min((size.width - padding * 2) / widthFactor, (size.height - padding * 2) / heightFactor)
            guard radius > 1 else { continue }

            let usedWidth = radius * widthFactor
            let usedHeight = radius * heightFactor
            let score = radius - abs(log((usedWidth / max(usedHeight, 1)) / (size.width / max(size.height, 1)))) * 4
            if best == nil || score > best!.score {
                best = (cols, rows, radius, score)
            }
        }

        guard let best else { return [] }

        let radius = best.radius
        let gap = radius * gapRatio
        let hexWidth = sqrt3 * radius
        let stepX = hexWidth + gap
        let stepY = radius * 1.5 + gap
        let usedWidth = CGFloat(best.cols) * hexWidth + CGFloat(max(best.cols - 1, 0)) * gap + (best.rows > 1 ? hexWidth / 2 : 0)
        let usedHeight = radius * 2 + CGFloat(max(best.rows - 1, 0)) * stepY
        let startX = (size.width - usedWidth) / 2 + hexWidth / 2
        let startY = (size.height - usedHeight) / 2 + radius

        return (0..<count).map { index in
            let col = index % best.cols
            let row = index / best.cols
            let center = CGPoint(
                x: startX + CGFloat(col) * stepX + (row.isMultiple(of: 2) ? 0 : hexWidth / 2),
                y: startY + CGFloat(row) * stepY
            )
            return DenseMeterCell(
                index: index,
                center: center,
                rect: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2),
                size: radius * 2,
                radius: radius
            )
        }
    }

    private static func drawSquare(
        meter: ChannelMeter,
        cell: DenseMeterCell,
        style: VUMeterVisualStyle,
        time: TimeInterval,
        context: inout GraphicsContext,
        showLabels: Bool
    ) {
        let level = clampedLevel(meter.level)
        let shell = Path(roundedRect: cell.rect, cornerRadius: max(2, cell.size * 0.055))
        context.fill(shell, with: .color(Color.white.opacity(0.035)))
        context.stroke(shell, with: .color(level >= 0.96 ? LabTheme.red.opacity(0.85) : LabTheme.line.opacity(0.8 + Double(level))), lineWidth: 1)

        if style.isFlicker {
            drawSquareFlicker(level: level, cell: cell, time: time, context: &context)
        } else {
            let inner = cell.size * (0.1 + CGFloat(level) * 0.72)
            let rect = CGRect(x: cell.center.x - inner / 2, y: cell.center.y - inner / 2, width: inner, height: inner)
            context.fill(Path(roundedRect: rect, cornerRadius: max(1, inner * 0.06)), with: .color(meterColor(level: level).opacity(0.24 + Double(level) * 0.68)))
        }

        drawLabelIfNeeded(meter.channel.shortLabel, level: level, cell: cell, context: &context, showLabels: showLabels)
    }

    private static func drawHex(
        meter: ChannelMeter,
        cell: DenseMeterCell,
        style: VUMeterVisualStyle,
        time: TimeInterval,
        context: inout GraphicsContext,
        showLabels: Bool
    ) {
        let level = clampedLevel(meter.level)
        let shell = hexPath(center: cell.center, radius: cell.radius)
        context.fill(shell, with: .color(Color.white.opacity(0.032)))
        context.stroke(shell, with: .color(level >= 0.96 ? LabTheme.red.opacity(0.85) : LabTheme.line.opacity(0.85 + Double(level))), lineWidth: max(1, cell.radius * 0.035))

        if style.isFlicker {
            drawHexRipple(level: level, cell: cell, time: time, context: &context)
        } else {
            let inner = cell.radius * (0.16 + CGFloat(level) * 0.7)
            context.fill(hexPath(center: cell.center, radius: inner), with: .color(meterColor(level: level).opacity(0.24 + Double(level) * 0.68)))
        }

        drawLabelIfNeeded(meter.channel.shortLabel, level: level, cell: cell, context: &context, showLabels: showLabels)
    }

    private static func drawSquareFlicker(level: Float, cell: DenseMeterCell, time: TimeInterval, context: inout GraphicsContext) {
        let energy = pow(CGFloat(level), 1.4)
        let block = max(CGFloat(2), floor(cell.size / (energy > 0.5 ? 8 : 10)))
        let inset = cell.size * 0.12
        let field = cell.size - inset * 2
        let pulse = sin(CGFloat(time) * (0.8 + energy * 4.2) * .pi * 2 + CGFloat(cell.index)) * 0.5 + 0.5
        let coreSize = max(block, floor(field * (0.12 + CGFloat(level) * 0.68) * (0.78 + pulse * 0.34) / block) * block)
        let coreRect = CGRect(
            x: floor((cell.center.x - coreSize / 2) / block) * block,
            y: floor((cell.center.y - coreSize / 2) / block) * block,
            width: coreSize,
            height: coreSize
        )
        context.fill(Path(roundedRect: coreRect, cornerRadius: max(1, block)), with: .color(meterColor(level: level).opacity(0.06 + Double(energy) * 0.32)))

        let pixels = max(1, Int(1 + energy * min(20, cell.size / 2.4)))
        let speed = 0.35 + energy * 15
        let frame = floor(CGFloat(time) * speed)

        for pixel in 0..<pixels {
            let seed = noise(CGFloat(cell.index) * 31.7 + CGFloat(pixel) * 5.1)
            let jitter = noise(CGFloat(cell.index) * 9.3 + CGFloat(pixel) * 13.9 + frame)
            let x = cell.rect.minX + inset + noise(seed * 101 + jitter * 7) * field
            let y = cell.rect.minY + inset + noise(seed * 209 + jitter * 11) * field
            let rect = CGRect(x: floor(x / block) * block, y: floor(y / block) * block, width: block, height: block)
            context.fill(Path(rect), with: .color(pixelColor(level: level, seed: seed).opacity(0.12 + Double(level) * 0.7)))
        }
    }

    private static func drawHexRipple(level: Float, cell: DenseMeterCell, time: TimeInterval, context: inout GraphicsContext) {
        let energy = pow(CGFloat(level), 1.35)
        let maxRadius = cell.radius * 0.84
        let block = max(CGFloat(2), floor(cell.radius / (energy > 0.55 ? 4.2 : 5.4)))
        let diameter = maxRadius * 2
        let columns = max(1, Int(ceil(diameter / block)))
        let startX = floor((cell.center.x - diameter / 2) / block) * block
        let startY = floor((cell.center.y - diameter / 2) / block) * block
        let speed = 0.045 + energy * 0.42
        let travel = (CGFloat(time) * speed + noise(CGFloat(cell.index) * 0.23)).truncatingRemainder(dividingBy: 1)
        let width = 9.5 - energy * 3.3
        let shimmerFrame = floor(CGFloat(time) * (0.35 + energy * 1.45))
        var clipped = context
        clipped.clip(to: hexPath(center: cell.center, radius: maxRadius))

        for row in 0...columns {
            for col in 0...columns {
                let x = startX + CGFloat(col) * block
                let y = startY + CGFloat(row) * block
                let sample = CGPoint(x: x + block / 2, y: y + block / 2)
                let distance = hypot(sample.x - cell.center.x, sample.y - cell.center.y)
                guard distance <= maxRadius else { continue }

                let normalized = distance / max(maxRadius, 1)
                let seed = noise(CGFloat(cell.index) * 53.2 + CGFloat(row) * 7.9 + CGFloat(col) * 3.1)
                let ring = rippleBand(normalized: normalized, travel: travel + seed * 0.025, width: width)
                let secondary = rippleBand(normalized: normalized, travel: travel - 0.34 + seed * 0.018, width: width * 1.18) * 0.48
                let centerBloom = pow(1 - normalized, 2.4) * (0.08 + energy * 0.34)
                let shimmer = 0.82 + noise(seed * 113 + shimmerFrame) * 0.36
                let alpha = (ring + secondary + centerBloom) * shimmer * (0.08 + pow(CGFloat(level), 0.92) * 0.8)

                guard alpha >= 0.025 else { continue }
                clipped.fill(Path(CGRect(x: x, y: y, width: block, height: block)), with: .color(pixelColor(level: level, seed: min(seed + ring * energy * 0.55, 1)).opacity(Double(alpha))))
            }
        }
    }

    private static func drawLabelIfNeeded(
        _ label: String,
        level: Float,
        cell: DenseMeterCell,
        context: inout GraphicsContext,
        showLabels: Bool
    ) {
        guard showLabels, cell.size >= 42 else { return }
        context.draw(
            Text(label)
                .font(.system(size: min(11, max(8, cell.size * 0.15)), weight: .bold, design: .monospaced))
                .foregroundColor(level >= 0.58 ? LabTheme.bg.opacity(0.84) : LabTheme.textSoft.opacity(0.78)),
            at: cell.center
        )
    }

    private static func hexPath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for index in 0..<6 {
            let angle = -.pi / 2 + CGFloat(index) * .pi / 3
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private static func clampedLevel(_ level: Float) -> Float {
        min(max(level, 0), 1)
    }

    private static func meterColor(level: Float) -> Color {
        if level > 0.9 { return LabTheme.red }
        if level > 0.72 { return LabTheme.amber }
        if level > 0.34 { return LabTheme.blue }
        return LabTheme.cyan
    }

    private static func pixelColor(level: Float, seed: CGFloat) -> Color {
        if level > 0.9, seed > 0.35 { return LabTheme.red }
        if level > 0.72, seed > 0.22 { return LabTheme.amber }
        if level > 0.5, seed > 0.82 { return Color(red: 244 / 255, green: 114 / 255, blue: 182 / 255) }
        if level > 0.34, seed > 0.18 { return LabTheme.blue }
        return LabTheme.cyan
    }

    private static func rippleBand(normalized: CGFloat, travel: CGFloat, width: CGFloat) -> CGFloat {
        let wrapped = ((travel.truncatingRemainder(dividingBy: 1)) + 1).truncatingRemainder(dividingBy: 1)
        let distance = min(abs(normalized - wrapped), abs(normalized - wrapped + 1), abs(normalized - wrapped - 1))
        return pow(max(1 - distance * width, 0), 2.2)
    }

    private static func noise(_ value: CGFloat) -> CGFloat {
        let raw = sin(value * 127.1 + 311.7) * 43_758.5453
        return raw - floor(raw)
    }
}

private struct SonicSphereRendererSceneView: NSViewRepresentable {
    let sceneModel: RendererSceneModel
    let isPlaying: Bool

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.backgroundColor = .clear
        view.rendersContinuously = true
        view.scene = makeScene()
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        nsView.scene = makeScene()
    }

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.clear

        let root = scene.rootNode
        let target = SCNNode()
        target.position = SCNVector3(0, 0, 0)
        root.addChildNode(target)

        let camera = SCNCamera()
        camera.fieldOfView = 46
        camera.zNear = 0.01
        camera.zFar = 100
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 1.45, 4.15)
        cameraNode.constraints = [SCNLookAtConstraint(target: target)]
        root.addChildNode(cameraNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 520
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        root.addChildNode(ambientNode)

        let key = SCNLight()
        key.type = .omni
        key.intensity = 680
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(-2.5, 2.5, 3.0)
        root.addChildNode(keyNode)

        root.addChildNode(makeLamellaSphere())
        root.addChildNode(makeEquator())

        for output in sceneModel.outputSpeakers {
            root.addChildNode(makeOutputSpeaker(output))
        }

        for input in sceneModel.inputSpeakers {
            root.addChildNode(makeInputSpeaker(input))
        }

        root.addChildNode(makeListener())
        return scene
    }

    private func makeLamellaSphere() -> SCNNode {
        let container = SCNNode()

        let sphere = SCNSphere(radius: 1)
        sphere.segmentCount = 64
        let sphereMaterial = material(
            color: NSColor(calibratedRed: 0.37, green: 0.92, blue: 0.83, alpha: 0.32),
            emission: NSColor(calibratedRed: 0.10, green: 0.35, blue: 0.32, alpha: 0.22),
            fillMode: .lines
        )
        sphere.firstMaterial = sphereMaterial
        container.addChildNode(SCNNode(geometry: sphere))

        let lamellaAngles = stride(from: -60.0, through: 60.0, by: 15.0)
        for angle in lamellaAngles {
            let node = torusNode(
                radius: cos(abs(angle) * .pi / 180),
                color: NSColor(calibratedRed: 0.34, green: 0.90, blue: 0.84, alpha: 0.52)
            )
            node.position.y = CGFloat(sin(angle * .pi / 180))
            container.addChildNode(node)
        }

        for angle in stride(from: 0.0, to: 180.0, by: 22.5) {
            let node = torusNode(
                radius: 1,
                color: NSColor(calibratedRed: 0.24, green: 0.54, blue: 0.95, alpha: 0.30)
            )
            node.eulerAngles.x = CGFloat.pi / 2
            node.eulerAngles.y = CGFloat(angle * .pi / 180)
            container.addChildNode(node)
        }

        return container
    }

    private func makeEquator() -> SCNNode {
        let node = torusNode(
            radius: 1.002,
            color: NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.08, alpha: 0.82),
            pipeRadius: 0.0038
        )
        return node
    }

    private func makeOutputSpeaker(_ speaker: RendererOutputSpeaker) -> SCNNode {
        let geometry = SCNSphere(radius: speaker.isLFE ? 0.048 : 0.036)
        geometry.segmentCount = speaker.isLFE ? 16 : 20
        geometry.firstMaterial = material(
            color: speaker.isLFE
                ? NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.08, alpha: 1.0)
                : NSColor(calibratedRed: 0.37, green: 0.92, blue: 0.83, alpha: 1.0),
            emission: speaker.isLFE
                ? NSColor(calibratedRed: 0.28, green: 0.20, blue: 0.02, alpha: 1.0)
                : NSColor(calibratedRed: 0.06, green: 0.34, blue: 0.31, alpha: 1.0)
        )

        let node = SCNNode(geometry: geometry)
        node.name = speaker.displayName
        node.position = speaker.position.scnVector
        return node
    }

    private func makeInputSpeaker(_ speaker: RendererInputSpeaker) -> SCNNode {
        let geometry = SCNBox(width: 0.075, height: 0.075, length: 0.075, chamferRadius: 0.008)
        geometry.firstMaterial = material(
            color: speaker.channel.role.isLFE
                ? NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.08, alpha: 0.95)
                : NSColor(calibratedRed: 0.96, green: 0.44, blue: 0.52, alpha: 0.95),
            emission: speaker.channel.role.isLFE
                ? NSColor(calibratedRed: 0.28, green: 0.20, blue: 0.02, alpha: 1.0)
                : NSColor(calibratedRed: 0.26, green: 0.08, blue: 0.12, alpha: 1.0)
        )

        let node = SCNNode(geometry: geometry)
        node.name = speaker.displayName
        node.position = speaker.position.scnVector
        return node
    }

    private func makeListener() -> SCNNode {
        let geometry = SCNSphere(radius: isPlaying ? 0.043 : 0.034)
        geometry.segmentCount = 20
        geometry.firstMaterial = material(
            color: NSColor(calibratedRed: 0.93, green: 0.99, blue: 1.0, alpha: 1.0),
            emission: NSColor(calibratedRed: 0.16, green: 0.26, blue: 0.28, alpha: 1.0)
        )
        return SCNNode(geometry: geometry)
    }

    private func torusNode(
        radius: Double,
        color: NSColor,
        pipeRadius: CGFloat = 0.0025
    ) -> SCNNode {
        let torus = SCNTorus(ringRadius: CGFloat(max(radius, 0.001)), pipeRadius: pipeRadius)
        torus.ringSegmentCount = 96
        torus.pipeSegmentCount = 6
        torus.firstMaterial = material(color: color, emission: color.withAlphaComponent(0.18))
        return SCNNode(geometry: torus)
    }

    private func material(
        color: NSColor,
        emission: NSColor,
        fillMode: SCNFillMode = .fill
    ) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = emission
        material.lightingModel = .physicallyBased
        material.transparency = CGFloat(color.alphaComponent)
        material.isDoubleSided = true
        material.fillMode = fillMode
        return material
    }
}

private extension RendererVector3 {
    var scnVector: SCNVector3 {
        SCNVector3(Float(x), Float(y), Float(z))
    }
}
