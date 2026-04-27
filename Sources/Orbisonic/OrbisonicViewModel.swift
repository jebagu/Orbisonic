import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

struct ChannelMeter: Identifiable {
    let channel: SurroundChannel
    var level: Float

    var id: String { channel.id }
}

enum PlaylistSortMode: String, CaseIterable, Identifiable {
    case name = "Name"
    case artist = "Artist"
    case album = "Album"

    var id: String { rawValue }
}

enum RendererMeterDisplayModel {
    static func channels(for scene: RendererSceneModel) -> [SurroundChannel] {
        var lfeCount = 0

        return SonicSphereTopology.outputSpeakers(for: scene.preset, includeLFE: true).enumerated().map { offset, speaker in
            let role: SurroundChannelRole
            if speaker.isLFE {
                role = lfeCount == 0 ? .lfe : .lfe2
                lfeCount += 1
            } else {
                role = .discrete(offset)
            }

            return SurroundChannel(index: offset, role: role)
        }
    }

    static func levels(for scene: RendererSceneModel, sourceLevels: [Float]) -> [Float] {
        let channels = channels(for: scene)
        guard !channels.isEmpty else {
            return Array(repeating: 0, count: channels.count)
        }

        let levels = RendererMeterLevelModel.outputLevels(
            sourceLevels: sourceLevels,
            matrix: scene.matrix
        )
        return padded(levels, count: channels.count)
    }

    private static func padded(_ levels: [Float], count: Int) -> [Float] {
        guard count > 0 else { return [] }
        if levels.count == count { return levels }
        if levels.count > count { return Array(levels.prefix(count)) }
        return levels + Array(repeating: 0, count: count - levels.count)
    }
}

enum LiveChannelCountPolicy {
    static let roonSupportedCounts = [2, 4, 6, 8]

    static func availableCounts(sourceMode: SourceMode, availableInputChannels: Int) -> [Int] {
        if let fixedCount = sourceMode.fixedLiveChannelCount {
            return [fixedCount]
        }

        if sourceMode == .roon {
            let available = min(max(availableInputChannels, 0), roonSupportedCounts.last ?? 8)
            let supported = roonSupportedCounts.filter { $0 <= available }
            return supported.isEmpty ? [2] : supported
        }

        let available = min(max(availableInputChannels, 0), OrbisonicAudioLimits.maxSourceChannelCount)
        guard available > 0 else {
            return [2, 4, 6, 8]
        }

        let supported = RendererRenderMode.supportedInputCounts.filter { $0 <= available }
        if supported.contains(available) {
            return supported
        }

        return supported.isEmpty ? [min(available, 2)] : supported
    }

    static func preferredCount(sourceMode: SourceMode, availableInputChannels: Int, activeCount: Int) -> Int {
        if let fixedCount = sourceMode.fixedLiveChannelCount {
            return fixedCount
        }

        let available = availableCounts(sourceMode: sourceMode, availableInputChannels: availableInputChannels)
        if available.contains(activeCount) {
            return activeCount
        }

        return available.contains(2) ? 2 : (available.first ?? 2)
    }
}

struct SpotifySourceHealthLine: Identifiable, Equatable {
    let title: String
    let value: String

    var id: String { title }
}

private struct DiagnosticReturnContext {
    let sourceMode: SourceMode
    let wasPlaying: Bool
    let progress: Double
    let hadSource: Bool
}

private enum DiagnosticChannelWalkKind {
    case monitor
    case renderer

    var title: String {
        switch self {
        case .monitor:
            "Monitor Channel Walk"
        case .renderer:
            "Renderer Channel Walk"
        }
    }

    var shortTitle: String {
        switch self {
        case .monitor:
            "Monitor"
        case .renderer:
            "Renderer"
        }
    }
}

@MainActor
final class ChannelMeterStore: ObservableObject {
    @Published private(set) var channelMeters: [ChannelMeter] = []

    func configure(channels: [SurroundChannel]) {
        channelMeters = channels.map { ChannelMeter(channel: $0, level: 0) }
    }

    func configureIfNeeded(channels: [SurroundChannel]) {
        let currentIDs = channelMeters.map(\.id)
        let nextIDs = channels.map(\.id)
        guard currentIDs != nextIDs else { return }

        configure(channels: channels)
    }

    func reset() {
        channelMeters = channelMeters.map { ChannelMeter(channel: $0.channel, level: 0) }
    }

    func update(with nextLevels: [Float]) {
        guard nextLevels.count == channelMeters.count else { return }

        let updated = zip(channelMeters, nextLevels).map { current, next in
            ChannelMeter(channel: current.channel, level: next)
        }

        let shouldPublish = zip(channelMeters, updated).contains {
            abs($0.level - $1.level) >= 0.003
        }

        if shouldPublish {
            channelMeters = updated
        }
    }
}

private enum OutputPurpose: Equatable {
    case monitor
    case renderer

    var title: String {
        switch self {
        case .monitor:
            "Monitor"
        case .renderer:
            "Renderer"
        }
    }

    var lowerTitle: String {
        title.lowercased()
    }
}

@MainActor
final class OrbisonicViewModel: ObservableObject {
    private static let selectedInputDeviceUIDKey = "Orbisonic.selectedInputDeviceUID"
    private static let selectedMonitorOutputModeKey = "Orbisonic.selectedMonitorOutputMode"
    private static let selectedRendererOutputModeKey = "Orbisonic.selectedRendererOutputMode"
    private static let rendererRenderModeKey = "Orbisonic.rendererRenderMode"
    private static let rendererAlwaysMonoKey = "Orbisonic.rendererAlwaysMono"
    private static let rendererTwoChannelPreferenceKey = "Orbisonic.rendererTwoChannelPreference"
    private static let legacySelectedOutputDeviceUIDKey = "Orbisonic.selectedOutputDeviceUID"
    private static let roonLogRefreshInterval: TimeInterval = 5.0
    private static let roonBridgeRefreshInterval: TimeInterval = 2.0
    private static let spotifyNowPlayingRefreshInterval: TimeInterval = 0.5
    private static let spotifyConnectRestartDebounce: TimeInterval = 8.0
    private static let webControlTokenKey = "Orbisonic.webControlToken"
    private static let localMusicSortModeKey = "Orbisonic.localMusicSortMode"
    private static let rendererOptionsKey = "Orbisonic.rendererOptions"
    private static let frontAngleKey = "Orbisonic.frontAngle"
    private static let rearAngleKey = "Orbisonic.rearAngle"
    private static let sphereOutputVolumeKey = "Orbisonic.sphereOutputVolumePercent"
    private static let sphereOutputSafetyLimitKey = "Orbisonic.sphereOutputSafetyLimitPercent"
    private static let diagnosticSpeakerChannelCount = 31

    @Published var preset: SpatialPreset = .defaultPreset {
        didSet {
            applyPreset(preset)
        }
    }

    @Published private(set) var rendererPresets: [RendererPreset] = [.sonicSphere30Point1]
    @Published private(set) var rendererPreset: RendererPreset = .sonicSphere30Point1
    @Published private(set) var rendererRenderMode: RendererRenderMode = OrbisonicViewModel.loadRendererRenderMode()
    @Published var rendererAlwaysMono: Bool = OrbisonicViewModel.loadBool(
        key: OrbisonicViewModel.rendererAlwaysMonoKey,
        defaultValue: false
    ) {
        didSet {
            UserDefaults.standard.set(rendererAlwaysMono, forKey: Self.rendererAlwaysMonoKey)
            applyRendererModePolicyChange(reason: "always mono changed")
        }
    }
    @Published var rendererTwoChannelPreference: RendererTwoChannelPreference = OrbisonicViewModel.loadRendererTwoChannelPreference() {
        didSet {
            UserDefaults.standard.set(rendererTwoChannelPreference.rawValue, forKey: Self.rendererTwoChannelPreferenceKey)
            applyRendererModePolicyChange(reason: "two-channel preference changed")
        }
    }
    @Published var rendererSeamSupportGain = RendererPreset.sonicSphere30Point1.options.seamSupportGain { didSet { publishRendererOptions() } }
    @Published var rendererUpperBiasDbPerUnitZ = RendererPreset.sonicSphere30Point1.options.upperBiasDbPerUnitZ { didSet { publishRendererOptions() } }
    @Published var rendererStereoRearFill = RendererPreset.sonicSphere30Point1.options.stereoRearFill { didSet { publishRendererOptions() } }
    @Published var rendererCenterSideSupportGain = RendererPreset.sonicSphere30Point1.options.centerSideSupportGain { didSet { publishRendererOptions() } }
    @Published var rendererAdjacentBleed = RendererPreset.sonicSphere30Point1.options.adjacentBleed { didSet { publishRendererOptions() } }
    @Published var rendererMaxSingleSpeakerPowerShare = RendererPreset.sonicSphere30Point1.options.maxSingleSpeakerPowerShare { didSet { publishRendererOptions() } }
    @Published var rendererRenderedOutputTrimDb = RendererPreset.sonicSphere30Point1.options.renderedOutputTrimDb { didSet { publishRendererOptions() } }
    @Published var rendererLfeTrimDb = RendererPreset.sonicSphere30Point1.options.lfeTrimDb { didSet { publishRendererOptions() } }
    @Published var rendererAuroLowerUpperBiasDbPerUnitZ = RendererPreset.sonicSphere30Point1.options.defaultUpperBiasDbPerUnitZ { didSet { publishRendererOptions() } }
    @Published var rendererAuroHeightUpperBiasDbPerUnitZ = RendererPreset.sonicSphere30Point1.options.heightUpperBiasDbPerUnitZ { didSet { publishRendererOptions() } }
    @Published var rendererAuroHeightMaxSingleSpeakerPowerShare = RendererPreset.sonicSphere30Point1.options.heightMaxSingleSpeakerPowerShare { didSet { publishRendererOptions() } }
    @Published var rendererAuroTopMaxSingleSpeakerPowerShare = RendererPreset.sonicSphere30Point1.options.topMaxSingleSpeakerPowerShare { didSet { publishRendererOptions() } }
    @Published var rendererFiveOneChannelOrder = RendererPreset.sonicSphere30Point1.options.fiveOneChannelOrder { didSet { publishRendererOptions() } }
    @Published private(set) var rendererScene: RendererSceneModel = .empty
    @Published private(set) var rendererPresetStatus = "Renderer presets have not loaded yet."
    @Published private(set) var rendererPresetDirectoryText = ""
    @Published private(set) var rendererPresetIsDirty = false

    @Published var frontAngle: Double = OrbisonicViewModel.loadDouble(
        key: OrbisonicViewModel.frontAngleKey,
        defaultValue: SpatialTuning.default.frontAngle
    ) {
        didSet {
            guard !suppressTuningPublish else { return }
            persistDouble(frontAngle, key: Self.frontAngleKey, category: "tuning", name: "Front Angle")
            publishTuning()
        }
    }

    @Published var rearAngle: Double = OrbisonicViewModel.loadDouble(
        key: OrbisonicViewModel.rearAngleKey,
        defaultValue: SpatialTuning.default.rearAngle
    ) {
        didSet {
            guard !suppressTuningPublish else { return }
            persistDouble(rearAngle, key: Self.rearAngleKey, category: "tuning", name: "Rear Angle")
            publishTuning()
        }
    }

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var scrubProgress: Double = 0
    @Published var isScrubbing = false
    @Published var sourceMetadata: AudioSourceMetadata?
    @Published var loadedChannels: [SurroundChannel] = []
    @Published var statusMessage = "Load a surround file. The active macOS output route will appear below."
    @Published var loadedFileName = "No file loaded"
    @Published private(set) var currentFileURL: URL?
    @Published var lastError: String? {
        didSet {
            if let lastError {
                controlLastError = lastError
            }
        }
    }
    @Published private(set) var controlLastError: String?
    @Published private(set) var outputRoute: OutputRouteInfo = .unavailable
    @Published private(set) var monitorOutputRoute: OutputRouteInfo = .unavailable
    @Published private(set) var rendererOutputRoute: OutputRouteInfo = .unavailable
    @Published private(set) var systemOutputRoute: OutputRouteInfo = .unavailable
    @Published private(set) var availableOutputRoutes: [OutputRouteInfo] = []
    @Published private(set) var inputRoute: InputRouteInfo = .unavailable
    @Published private(set) var systemInputRoute: InputRouteInfo = .unavailable
    @Published private(set) var availableInputRoutes: [InputRouteInfo] = []
    @Published var sourceMode: SourceMode = .filePlayback
    @Published private(set) var liveMonitorState: LiveMonitorState = .stopped
    @Published var activeLiveChannelCount = 2
    @Published var liveSignalStatus = "No live input."
    @Published var liveBufferStatus = "No live buffer."
    @Published var selectedTestTonePoint: TestTonePipelinePoint = .directOutput
    @Published var isTestTonePlaying = false
    @Published var testToneStatus = ""
    @Published private(set) var isDiagnosticTransitioning = false
    @Published private(set) var selectedDiagnosticSpeakerChannel = 1
    @Published var diagnosticWalkStatus = "Ready."
    @Published var activeDiagnosticPoint: TestTonePipelinePoint?
    @Published var activeDiagnosticChannelIndex: Int?
    @Published var activeDiagnosticChannelCount = 0
    @Published var activeDiagnosticWalkTitle = ""
    @Published var diagnosticSequencePosition = 0
    @Published var isDiagnosticSequencePlaying = false
    @Published private(set) var roonNowPlaying: RoonNowPlaying?
    @Published private(set) var roonNowPlayingStatus = "Roon metadata not requested yet."
    @Published private(set) var roonSignalPath: RoonSignalPath?
    @Published private(set) var roonBridgeSnapshot: RoonBridgeSnapshot = .unavailable
    @Published private(set) var spotifyReceiverStatus: SpotifyReceiverStatus = .notStarted
    @Published private(set) var spotifyNowPlaying: SpotifyNowPlaying?
    @Published private(set) var localMusicSettings = LocalMusicSettings()
    @Published private(set) var localMusicTracks: [LocalMusicTrack] = []
    @Published private(set) var localMusicPlaylists: [LocalMusicPlaylist] = []
    @Published var selectedLocalMusicTrackID: String?
    @Published var selectedLocalMusicPlaylistID: String?
    @Published var localMusicSearchText = ""
    @Published var localMusicSortMode: PlaylistSortMode = OrbisonicViewModel.loadLocalMusicSortMode() {
        didSet {
            UserDefaults.standard.set(localMusicSortMode.rawValue, forKey: Self.localMusicSortModeKey)
            AppLogger.shared.notice(category: "local-music", "Sort mode set to \(localMusicSortMode.rawValue)")
        }
    }
    @Published private(set) var sessionQueue: [LocalMusicTrack] = []
    @Published private(set) var sessionQueueIndex: Int?
    @Published private(set) var selectedSessionQueueIndex: Int?
    @Published var isShuffleEnabled = false
    @Published private(set) var webServerStatus = "Web server starting."
    @Published private(set) var webPublicPageURL = ""
    @Published private(set) var webControlPageURL = ""
    @Published var sphereOutputVolumePercent: Double = OrbisonicViewModel.loadDouble(
        key: OrbisonicViewModel.sphereOutputVolumeKey,
        defaultValue: 100
    ) {
        didSet { updateSphereOutputVolume(settingName: "Sphere Volume", key: Self.sphereOutputVolumeKey) }
    }
    @Published var sphereOutputSafetyLimitPercent: Double = OrbisonicViewModel.loadDouble(
        key: OrbisonicViewModel.sphereOutputSafetyLimitKey,
        defaultValue: 100
    ) {
        didSet { updateSphereOutputVolume(settingName: "Max Output Safety Limit", key: Self.sphereOutputSafetyLimitKey) }
    }
    @Published private(set) var isRoonTransportCommandInFlight = false
    @Published private(set) var isLiveMonitorTransitioning = false
    @Published private(set) var isLocalFileLoading = false

    let meterStore = ChannelMeterStore()
    let monitorMeterStore = ChannelMeterStore()
    let rendererMeterStore = ChannelMeterStore()

    private let engine = OrbisonicEngine()
    private let localMusicLibrary = LocalMusicLibrary()
    private let rendererPresetStore = RendererPresetStore()
    private let roonNowPlayingReader = RoonNowPlayingReader()
    private let roonBridgeClient = RoonBridgeClient()
    private let spotifyReceiverClient = SpotifyReceiverClient()
    private var webServer: OrbisonicWebServer?
    private var webControlToken = OrbisonicViewModel.loadOrCreateWebControlToken()
    private var refreshTimer: Timer?
    private var lastHeartbeatSecond: Int = -1
    private var lastLiveMeterLogSecond: Int = -1
    private var lastLiveBufferLogSecond: Int = -1
    private var lastLiveSilenceWarningSecond: Int = -1
    private var lastLiveSignalPresent: Bool?
    private var testToneStopTask: Task<Void, Never>?
    private var diagnosticSequenceTask: Task<Void, Never>?
    private var diagnosticReturnContext: DiagnosticReturnContext?
    private var rendererDiagnosticsUsingMonitorPreview = false
    private var rendererDiagnosticsMonitorDownmixAvailable = false
    private var localMusicScanTask: Task<Void, Never>?
    private var lastRouteRefreshTime = Date.distantPast
    private var lastRoonNowPlayingRefreshTime = Date.distantPast
    private var lastRoonBridgeRefreshTime = Date.distantPast
    private var lastSpotifyNowPlayingRefreshTime = Date.distantPast
    private var lastSpotifyConnectRefreshTime = Date.distantPast
    private var lastLegacyLoopbackSampleRateRepairTime = Date.distantPast
    private var isRoonLogRefreshInFlight = false
    private var isRoonBridgeRefreshInFlight = false
    private var lastLoggedRoonBridgeStatus: String?
    private var selectedInputDeviceUID = UserDefaults.standard.string(forKey: OrbisonicViewModel.selectedInputDeviceUIDKey)
    private var monitorOutputSelection = OrbisonicViewModel.loadMonitorOutputSelection()
    private var rendererOutputSelection = OrbisonicViewModel.loadRendererOutputSelection()
    private var suppressTuningPublish = false
    private var suppressRendererPublish = false

    init() {
        AppLogger.shared.notice(category: "view-model", "View model initialized.")

        engine.onPlaybackEnded = { [weak self] in
            self?.handlePlaybackEnded()
        }
        applyEffectiveOutputVolume(log: false)

        applyPreset(.defaultPreset, pushToEngine: false)
        loadRendererPresets()
        restorePersistedRendererOptions()
        loadLocalMusicDatabase()
        refreshRoutesIfNeeded(force: true)
        configureMonitorMeters()
        configureRendererMeters()
        refreshWebPageURLs()
        webServer = OrbisonicWebServer(model: self, controlToken: webControlToken) { [weak self] status in
            self?.webServerStatus = status
        }
        webServer?.start()

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.refreshTransport()
            }
        }
        timer.tolerance = 1.0 / 120.0
        refreshTimer = timer
    }

    private static func loadMonitorOutputSelection() -> OutputSelectionMode {
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: selectedMonitorOutputModeKey) {
            return OutputSelectionMode(storedValue: stored, defaultMode: .systemDefault)
        }

        if let legacyUID = defaults.string(forKey: legacySelectedOutputDeviceUIDKey), !legacyUID.isEmpty {
            return .device(legacyUID)
        }

        return .systemDefault
    }

    private static func loadRendererOutputSelection() -> OutputSelectionMode {
        let storedSelection = OutputSelectionMode(
            storedValue: UserDefaults.standard.string(forKey: selectedRendererOutputModeKey),
            defaultMode: .none
        )

        if case .device = storedSelection {
            return storedSelection
        }

        return .none
    }

    private static func loadRendererRenderMode() -> RendererRenderMode {
        guard let storedValue = UserDefaults.standard.string(forKey: rendererRenderModeKey),
              let mode = RendererRenderMode(rawValue: storedValue)
        else {
            return .automatic
        }

        return mode
    }

    private static func loadRendererTwoChannelPreference() -> RendererTwoChannelPreference {
        guard let storedValue = UserDefaults.standard.string(forKey: rendererTwoChannelPreferenceKey),
              let preference = RendererTwoChannelPreference(rawValue: storedValue)
        else {
            return .automatic
        }

        return preference
    }

    private static func loadLocalMusicSortMode() -> PlaylistSortMode {
        guard let storedValue = UserDefaults.standard.string(forKey: localMusicSortModeKey),
              let mode = PlaylistSortMode(rawValue: storedValue)
        else {
            return .album
        }

        return mode
    }

    private static func loadDouble(key: String, defaultValue: Double) -> Double {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }

        return UserDefaults.standard.double(forKey: key)
    }

    private static func loadBool(key: String, defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }

        return UserDefaults.standard.bool(forKey: key)
    }

    private static func loadOrCreateWebControlToken() -> String {
        if let existing = UserDefaults.standard.string(forKey: webControlTokenKey),
           existing.count >= 32 {
            return existing
        }

        let token = generateWebControlToken()
        UserDefaults.standard.set(token, forKey: webControlTokenKey)
        return token
    }

    private static func generateWebControlToken() -> String {
        (0..<3).map { _ in UUID().uuidString.replacingOccurrences(of: "-", with: "") }.joined()
    }

    private func persistMonitorOutputSelection() {
        UserDefaults.standard.set(monitorOutputSelection.storedValue, forKey: Self.selectedMonitorOutputModeKey)
        UserDefaults.standard.removeObject(forKey: Self.legacySelectedOutputDeviceUIDKey)
    }

    private func persistRendererOutputSelection() {
        UserDefaults.standard.set(rendererOutputSelection.storedValue, forKey: Self.selectedRendererOutputModeKey)
    }

    private func persistRendererRenderMode() {
        UserDefaults.standard.set(rendererRenderMode.rawValue, forKey: Self.rendererRenderModeKey)
    }

    private func persistDouble(_ value: Double, key: String, category: String, name: String) {
        UserDefaults.standard.set(value, forKey: key)
        AppLogger.shared.info(category: category, "\(name) set to \(String(format: "%.3f", value))")
    }

    deinit {
        testToneStopTask?.cancel()
        diagnosticSequenceTask?.cancel()
        localMusicScanTask?.cancel()
        webServer?.stop()
        refreshTimer?.invalidate()
    }

    func refreshWebPageURLs() {
        let urls = OrbisonicWebServer.urlSet(controlToken: webControlToken)
        webPublicPageURL = urls.publicURL
        webControlPageURL = urls.controlURL
    }

    var webControlTokenForLocalServer: String {
        webControlToken
    }

    func copyWebURLToPasteboard(_ url: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        statusMessage = "Copied web URL to clipboard."
    }

    var effectiveSphereOutputVolumePercent: Double {
        min(Self.clampedPercent(sphereOutputVolumePercent), Self.clampedPercent(sphereOutputSafetyLimitPercent))
    }

    var sphereOutputVolumeText: String {
        sphereRequestedOutputVolumeText
    }

    var sphereRequestedOutputVolumeText: String {
        "\(Int(Self.clampedPercent(sphereOutputVolumePercent).rounded()))"
    }

    var sphereMaxOutputVolumeText: String {
        "\(Int(Self.clampedPercent(sphereOutputSafetyLimitPercent).rounded()))"
    }

    var sphereEffectiveOutputVolumeText: String {
        "\(Int(effectiveSphereOutputVolumePercent.rounded()))"
    }

    var sphereOutputVolumeValue: Int { Int(Self.clampedPercent(sphereOutputVolumePercent).rounded()) }
    var sphereMaxOutputVolumeValue: Int { Int(Self.clampedPercent(sphereOutputSafetyLimitPercent).rounded()) }
    var sphereEffectiveOutputVolumeValue: Int { Int(effectiveSphereOutputVolumePercent.rounded()) }

    private static func clampedPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }

    private func updateSphereOutputVolume(settingName: String, key: String) {
        let currentValue = key == Self.sphereOutputVolumeKey ? sphereOutputVolumePercent : sphereOutputSafetyLimitPercent
        let clamped = Self.clampedPercent(currentValue)
        if currentValue != clamped {
            if key == Self.sphereOutputVolumeKey {
                sphereOutputVolumePercent = clamped
            } else {
                sphereOutputSafetyLimitPercent = clamped
            }
            return
        }

        persistDouble(clamped, key: key, category: "renderer", name: settingName)
        applyEffectiveOutputVolume(log: true)
    }

    func setSphereOutputVolume(_ value: Double) {
        sphereOutputVolumePercent = Self.clampedPercent(value)
    }

    private func applyEffectiveOutputVolume(log: Bool) {
        let effective = Float(effectiveSphereOutputVolumePercent / 100.0)
        engine.setOutputVolume(effective)
        if log {
            AppLogger.shared.notice(
                category: "renderer",
                "Effective sphere output volume=\(Int(effectiveSphereOutputVolumePercent.rounded()))% requested=\(Int(sphereOutputVolumePercent.rounded()))% safetyLimit=\(Int(sphereOutputSafetyLimitPercent.rounded()))%"
            )
        }
    }

    func resetWebControlToken() {
        let token = Self.generateWebControlToken()
        webControlToken = token
        UserDefaults.standard.set(token, forKey: Self.webControlTokenKey)
        refreshWebPageURLs()
        webServer?.updateControlToken(token)
        statusMessage = "Reset control token. Old control URLs no longer work."
    }

    func saveDiagnosticBundle() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let filename = "Orbisonic-Log-\(formatter.string(from: Date())).txt"

        let panel = NSSavePanel()
        panel.title = "Export Orbisonic Log"
        panel.nameFieldStringValue = filename
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            panel.directoryURL = desktopURL
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            statusMessage = "Diagnostic export canceled."
            return
        }

        do {
            try diagnosticReportText().write(to: url, atomically: true, encoding: .utf8)
            statusMessage = "Exported log to \(url.lastPathComponent)."
            AppLogger.shared.notice(category: "diagnostics", "Exported diagnostic bundle path=\(redactedPath(url.path))")
        } catch {
            let message = "Could not save diagnostics: \(error.localizedDescription)"
            statusMessage = message
            lastError = message
            AppLogger.shared.error(category: "diagnostics", message)
        }
    }

    func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.audio] + ["mkv", "mka"].compactMap { UTType(filenameExtension: $0) }

        guard panel.runModal() == .OK, let url = panel.url else {
            AppLogger.shared.debug(category: "ui", "Open file panel dismissed.")
            return
        }

        AppLogger.shared.info(category: "ui", "Selected file: \(url.path)")

        loadFile(url: url, autoplay: false)
    }

    private func diagnosticReportText() -> String {
        let logText = (try? String(contentsOf: AppLogger.logFileURL, encoding: .utf8)) ?? "Log file unavailable."
        let redactedControlURL = redactSensitiveText(webControlPageURL)
        let redactedLog = redactSensitiveText(logText)

        let rows: [String] = [
            "Orbisonic Diagnostics",
            "Generated: \(ISO8601DateFormatter().string(from: Date()))",
            "",
            "Build",
            "Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")",
            "Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "dev")",
            "Executable: \(redactedPath(Bundle.main.executableURL?.path ?? "unknown"))",
            "",
            "Machine And Web",
            "Host: \(Host.current().localizedName ?? "unknown")",
            "Web Host: \(webHostText)",
            "Public URL: \(redactedPath(webPublicPageURL))",
            "Control URL: \(redactedPath(redactedControlURL))",
            "Web Status: \(webServerStatus)",
            "",
            "Player",
            "Source: \(sourceMode.rawValue)",
            "Status: \(statusMessage)",
            "Loaded: \(redactedPath(loadedFileName))",
            "Playing: \(isPlaying)",
            "Time: \(formattedCurrentTime()) / \(formattedDuration())",
            "",
            "Routes",
            "Input: \(inputNowText)",
            "System Input: \(systemInputNowText)",
            "Monitor Output: \(monitorOutputSelectionText) | \(monitorOutputNowText) | \(monitorOutputStatusText)",
            "Renderer Output: \(rendererOutputSelectionText) | \(rendererOutputNowText) | \(rendererOutputStatusText)",
            "System Output: \(systemOutputNowText)",
            "",
            "Renderer",
            "Mode: \(rendererRenderMode.displayName)",
            "Scene: \(rendererSceneOutputText)",
            "Sphere Volume: \(sphereRequestedOutputVolumeText)",
            "Safety Limit: \(sphereMaxOutputVolumeText)",
            "Effective Volume: \(sphereEffectiveOutputVolumeText)",
            "Tuning: seam=\(rendererSeamSupportGain), upperBias=\(rendererUpperBiasDbPerUnitZ), rearFill=\(rendererStereoRearFill), centerSide=\(rendererCenterSideSupportGain), adjacentBleed=\(rendererAdjacentBleed), maxShare=\(rendererMaxSingleSpeakerPowerShare), trim=\(rendererRenderedOutputTrimDb), lfe=\(rendererLfeTrimDb)",
            "",
            "Local Music",
            "Sort: \(localMusicSortMode.rawValue)",
            "Tracks: \(localMusicTracks.count)",
            "Playlists: \(localMusicPlaylists.count)",
            "Watch Folders: \(localMusicSettings.watchFolderPaths.map(redactedPath).joined(separator: ", "))",
            "M3U Playlists: \(localMusicSettings.m3uPlaylistPaths.map(redactedPath).joined(separator: ", "))",
            "",
            "Diagnostics",
            "Tone: \(testToneStatus.isEmpty ? "None" : testToneStatus)",
            "Walk: \(diagnosticWalkStatus)",
            "Active: \(activeDiagnosticText)",
            "Selected Speaker Channel: \(selectedDiagnosticSpeakerChannel)",
            "",
            "Log",
            redactedLog
        ]

        return rows.joined(separator: "\n")
    }

    private var webHostText: String {
        if let host = URLComponents(string: webPublicPageURL).flatMap(\.host), !host.isEmpty {
            return host
        }
        return "unknown"
    }

    private func redactSensitiveText(_ value: String) -> String {
        let tokenPattern = #"(#token=)[A-Za-z0-9_-]+"#
        let tokenRedacted = value.replacingOccurrences(
            of: tokenPattern,
            with: "$1REDACTED",
            options: .regularExpression
        )
        return redactedPath(tokenRedacted)
    }

    private func redactedPath(_ value: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard !home.isEmpty else { return value }
        return value.replacingOccurrences(of: home, with: "~")
    }

    func selectSourceMode(_ mode: SourceMode) {
        guard mode != sourceMode else { return }

        if sourceMode.stopsLiveCaptureWhenSwitching(to: mode) {
            stopLiveMonitorForSourceSwitch(to: mode)
        } else if isPlaying || isTestTonePlaying || isDiagnosticSequencePlaying {
            stop()
        }

        sourceMode = mode

        switch mode {
        case .filePlayback:
            spotifyNowPlaying = nil
            liveSignalStatus = "No live input."
            liveBufferStatus = "No live buffer."
            liveMonitorState = .stopped
            roonNowPlayingStatus = "Roon metadata is only shown for live Roon input."
            roonSignalPath = nil
            statusMessage = sourceMetadata == nil
                ? "Open a local multichannel file or scan watch folders in Settings."
                : "Local player source is ready."
        case .roon:
            spotifyNowPlaying = nil
            currentFileURL = nil
            clearLoadedSourceSnapshot()
            roonNowPlayingStatus = "Roon metadata not requested yet."
            roonSignalPath = nil
            refreshRoonBridgeIfNeeded(force: true)
            if selectExpectedLoopbackInputIfAvailable(for: .roon) {
                liveMonitorState = .stopped
                statusMessage = "Roon is selected. Monitor Roon when the source is playing."
            } else {
                let message = missingLoopbackMessage(for: .roon)
                liveMonitorState = .unavailable(message)
                statusMessage = message
            }
        case .spotify:
            currentFileURL = nil
            clearLoadedSourceSnapshot()
            roonNowPlayingStatus = "Roon metadata is only shown for live Roon input."
            roonSignalPath = nil
            roonNowPlaying = nil
            activeLiveChannelCount = SourceMode.spotify.fixedLiveChannelCount ?? 2
            refreshSpotifyConnectServerIfNeeded(reason: "source selected", force: true)
            refreshSpotifyNowPlayingIfNeeded(force: true)
            if selectExpectedLoopbackInputIfAvailable(for: .spotify) {
                liveMonitorState = .stopped
                statusMessage = "Spotify is selected. Monitor Spotify when the source is playing through Orbisonic Spotify Input."
            } else {
                let message = missingLoopbackMessage(for: .spotify)
                liveMonitorState = .unavailable(message)
                statusMessage = message
            }
        case .testTone:
            spotifyNowPlaying = nil
            liveSignalStatus = "No live input."
            liveBufferStatus = "No live buffer."
            liveMonitorState = .stopped
            roonNowPlayingStatus = "Roon metadata is only shown for live Roon input."
            roonSignalPath = nil
            statusMessage = "Test tone source is ready. Use Diagnostics to play the selected tone."
        case .aux:
            spotifyNowPlaying = nil
            currentFileURL = nil
            clearLoadedSourceSnapshot()
            roonNowPlayingStatus = "Roon metadata is only shown for live Roon input."
            roonSignalPath = nil
            roonNowPlaying = nil
            if selectExpectedLoopbackInputIfAvailable(for: .aux) {
                liveMonitorState = .stopped
                statusMessage = "Aux Cable is selected. Monitor Aux Cable when the source app is playing."
            } else {
                let message = missingLoopbackMessage(for: .aux)
                liveMonitorState = .unavailable(message)
                statusMessage = message
            }
        }

        resetRendererRequestToAutomatic(reason: "source changed to \(mode.rawValue)")
    }

    func selectInputRoute(_ route: InputRouteInfo) {
        guard route.isAvailable else { return }

        if sourceMode.isLiveInput, !sourceMode.acceptsInputRoute(route) {
            if isPlaying {
                stop()
            }
            statusMessage = inputSelectionBlockedMessage(for: route)
            return
        }

        let previousRoute = inputRoute
        selectedInputDeviceUID = route.uid
        if route.uid.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.selectedInputDeviceUIDKey)
        } else {
            UserDefaults.standard.set(route.uid, forKey: Self.selectedInputDeviceUIDKey)
        }

        inputRoute = route
        applyLiveChannelDefaults(for: route)

        AppLogger.shared.notice(
            category: "route",
            "Selected Orbisonic input device=\(route.deviceName) uid=\(route.uid) transport=\(route.transportName) channels=\(route.inputChannelCount) sampleRate=\(formatSampleRate(route.nominalSampleRate)) blackHole=\(route.isBlackHole)"
        )

        if sourceMode.isLiveInput, isPlaying, previousRoute.deviceID != route.deviceID {
            startLiveInputForCurrentRoute(reason: "selected input changed")
        } else if sourceMode.isLiveInput {
            statusMessage = "Orbisonic input set to \(route.deviceName). macOS system input is still \(systemInputRoute.displayName)."
        }
    }

    func selectNoMonitorOutput() {
        monitorOutputSelection = .none
        persistMonitorOutputSelection()
        refreshRoutesIfNeeded(force: true)
        if isDiagnosticSequencePlaying {
            stop()
        }
        statusMessage = "Monitor output not set."
    }

    func selectSystemMonitorOutput() {
        monitorOutputSelection = .systemDefault
        persistMonitorOutputSelection()
        refreshRoutesIfNeeded(force: true)
        applyOutputRouteIfAvailable(monitorOutputRoute, purpose: .monitor, label: "System Default")
    }

    func selectMonitorOutputRoute(_ route: OutputRouteInfo) {
        guard route.isAvailable else { return }
        guard route.isSelectableOutputTarget else {
            let message = outputFeedbackMessage(for: route, purpose: .monitor)
            AppLogger.shared.error(category: "route", message)
            statusMessage = message
            lastError = message
            return
        }

        monitorOutputSelection = .device(route.uid)
        persistMonitorOutputSelection()
        refreshRoutesIfNeeded(force: true)
        applyOutputRouteIfAvailable(route, purpose: .monitor, label: route.deviceName)
    }

    func selectNoRendererOutput() {
        rendererOutputSelection = .none
        persistRendererOutputSelection()
        refreshRoutesIfNeeded(force: true)
        configureMonitorMeters()
        configureRendererMeters()
        syncRendererAudioRouting()
        if isDiagnosticSequencePlaying {
            stop()
        }
        statusMessage = "Renderer output not set."
    }

    func selectRendererOutputRoute(_ route: OutputRouteInfo) {
        guard route.isAvailable else { return }
        guard route.isSelectableOutputTarget else {
            let message = outputFeedbackMessage(for: route, purpose: .renderer)
            AppLogger.shared.error(category: "route", message)
            statusMessage = message
            lastError = message
            return
        }

        rendererOutputSelection = .device(route.uid)
        persistRendererOutputSelection()
        refreshRoutesIfNeeded(force: true)
        applyOutputRouteIfAvailable(route, purpose: .renderer, label: route.deviceName)
    }

    func chooseWatchFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK else {
            AppLogger.shared.debug(category: "ui", "Watch folder panel dismissed.")
            return
        }

        var nextSettings = localMusicSettings
        for url in panel.urls where !nextSettings.watchFolderPaths.contains(url.path) {
            nextSettings.watchFolderPaths.append(url.path)
        }
        nextSettings.watchFolderPaths.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        updateLocalMusicSettings(nextSettings, rescan: true)
    }

    func removeWatchFolder(path: String) {
        var nextSettings = localMusicSettings
        nextSettings.watchFolderPaths.removeAll { $0 == path }
        updateLocalMusicSettings(nextSettings, rescan: true)
    }

    func chooseM3UPlaylist() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "m3u"),
            UTType(filenameExtension: "m3u8")
        ].compactMap { $0 }

        guard panel.runModal() == .OK else {
            AppLogger.shared.debug(category: "ui", "M3U playlist panel dismissed.")
            return
        }

        var nextSettings = localMusicSettings
        for url in panel.urls where !nextSettings.m3uPlaylistPaths.contains(url.path) {
            nextSettings.m3uPlaylistPaths.append(url.path)
        }
        nextSettings.m3uPlaylistPaths.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        updateLocalMusicSettings(nextSettings, rescan: true)
    }

    func removeM3UPlaylist(path: String) {
        var nextSettings = localMusicSettings
        nextSettings.m3uPlaylistPaths.removeAll { $0 == path }
        updateLocalMusicSettings(nextSettings, rescan: true)
    }

    func setLocalMusicScansSubfolders(_ scansSubfolders: Bool) {
        var nextSettings = localMusicSettings
        nextSettings.scansSubfolders = scansSubfolders
        updateLocalMusicSettings(nextSettings, rescan: true)
    }

    func setLocalMusicImportsM3UPlaylists(_ importsM3UPlaylists: Bool) {
        var nextSettings = localMusicSettings
        nextSettings.importsM3UPlaylists = importsM3UPlaylists
        updateLocalMusicSettings(nextSettings, rescan: true)
    }

    func setLocalMusicExtractsAlbumArt(_ extractsAlbumArt: Bool) {
        var nextSettings = localMusicSettings
        nextSettings.extractsAlbumArt = extractsAlbumArt
        updateLocalMusicSettings(nextSettings, rescan: true)
    }

    func rescanLocalMusicLibrary() {
        localMusicScanTask?.cancel()
        let settings = localMusicSettings
        statusMessage = "Scanning local music library..."

        localMusicScanTask = Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                LocalMusicLibrary().scan(settings: settings)
            }.value

            guard let self, !Task.isCancelled else { return }
            self.applyLocalMusicScanResult(result)
        }
    }

    private func applyLocalMusicScanResult(_ result: LocalMusicScanResult) {
        localMusicTracks = result.tracks
        localMusicPlaylists = result.playlists

        if let selectedLocalMusicTrackID,
           !localMusicTracks.contains(where: { $0.id == selectedLocalMusicTrackID }) {
            self.selectedLocalMusicTrackID = nil
        }
        if let selectedLocalMusicPlaylistID,
           !localMusicPlaylists.contains(where: { $0.id == selectedLocalMusicPlaylistID }) {
            self.selectedLocalMusicPlaylistID = nil
        }
        sessionQueue = sessionQueue.filter { track in localMusicTracks.contains(where: { $0.id == track.id }) }
        if let sessionQueueIndex, sessionQueue.indices.contains(sessionQueueIndex) == false {
            self.sessionQueueIndex = sessionQueue.isEmpty ? nil : 0
        }
        if let selectedSessionQueueIndex, sessionQueue.indices.contains(selectedSessionQueueIndex) == false {
            self.selectedSessionQueueIndex = self.sessionQueueIndex
        }

        persistLocalMusicDatabase()
        statusMessage = "Local music library scanned: \(localMusicTracks.count) tracks, \(localMusicPlaylists.count) playlists."
        AppLogger.shared.notice(
            category: "local-music",
            "Scanned watchFolders=\(localMusicSettings.watchFolderPaths.count) explicitPlaylists=\(localMusicSettings.m3uPlaylistPaths.count) tracks=\(localMusicTracks.count) playlists=\(localMusicPlaylists.count)"
        )
    }

    func loadSelectedLocalMusicTrack() {
        guard let track = selectedLocalMusicTrack ?? visibleLocalMusicTracks.first else {
            statusMessage = "Add a watch folder in Settings, then scan local music."
            return
        }

        startSessionQueue(from: visibleLocalMusicTracks, startTrackID: track.id, shuffle: false, autoplay: false)
    }

    func toggleLocalMusicPlayback() {
        let selectedQueueTrack = selectedSessionQueueIndex.flatMap { index in
            sessionQueue.indices.contains(index) ? sessionQueue[index] : nil
        }
        guard let track = selectedQueueTrack ?? selectedLocalMusicTrack ?? currentLocalMusicTrack ?? visibleLocalMusicTracks.first else {
            statusMessage = "Add a watch folder in Settings, then scan local music."
            return
        }

        selectedLocalMusicTrackID = track.id

        guard currentFileURL?.path == track.id, sourceMode == .filePlayback else {
            if let queueIndex = sessionQueue.firstIndex(where: { $0.id == track.id }) {
                playQueueIndex(queueIndex)
                return
            }
            startSessionQueue(from: visibleLocalMusicTracks, startTrackID: track.id, shuffle: isShuffleEnabled, autoplay: true)
            return
        }

        togglePlayback()
    }

    func playLocalMusicTrackNow(_ track: LocalMusicTrack) {
        selectedLocalMusicTrackID = track.id
        selectedSessionQueueIndex = nil
        let tracks = visibleLocalMusicTracks.contains(where: { $0.id == track.id })
            ? visibleLocalMusicTracks
            : [track]
        startSessionQueue(from: tracks, startTrackID: track.id, shuffle: false, autoplay: true)
    }

    func selectLocalMusicTrack(_ track: LocalMusicTrack) {
        selectedLocalMusicTrackID = track.id
        selectedSessionQueueIndex = nil
    }

    func playNextLocalMusicTrack() {
        playQueueOffset(1, wrap: true)
    }

    func playPreviousLocalMusicTrack() {
        playQueueOffset(-1, wrap: true)
    }

    func selectSessionQueueIndex(_ index: Int) {
        guard sessionQueue.indices.contains(index) else { return }
        selectedSessionQueueIndex = index
        selectedLocalMusicTrackID = sessionQueue[index].id
    }

    func playSessionQueueIndex(_ index: Int) {
        guard sessionQueue.indices.contains(index) else { return }
        selectedSessionQueueIndex = index
        _ = playQueueIndex(index)
    }

    func playSelectedSessionQueueTrack() {
        if let selectedSessionQueueIndex, sessionQueue.indices.contains(selectedSessionQueueIndex) {
            if currentFileURL?.path == sessionQueue[selectedSessionQueueIndex].id, sourceMode == .filePlayback {
                togglePlayback()
                return
            }
            playQueueIndex(selectedSessionQueueIndex)
            return
        }

        toggleLocalMusicPlayback()
    }

    func playAllLocalMusic(shuffle: Bool = false) {
        startSessionQueue(from: visibleLocalMusicTracks, startTrackID: visibleLocalMusicTracks.first?.id, shuffle: shuffle, autoplay: true)
    }

    func playSelectedLocalMusicPlaylist(shuffle: Bool = false) {
        guard let playlist = selectedLocalMusicPlaylist ?? localMusicPlaylists.first else {
            statusMessage = "No M3U playlists are available. Add one in Settings or scan a folder that contains playlists."
            return
        }

        playLocalMusicPlaylist(playlist, shuffle: shuffle)
    }

    func addLocalMusicTrackToQueue(_ track: LocalMusicTrack) {
        let wasEmpty = sessionQueue.isEmpty
        sessionQueue.append(track)
        selectedLocalMusicTrackID = track.id

        if wasEmpty {
            sessionQueueIndex = 0
            selectedSessionQueueIndex = 0
        }

        statusMessage = "Added \(track.displayTitle) to the session queue."
    }

    func addSelectedLocalMusicPlaylistToQueue(shuffle: Bool = false) {
        guard let playlist = selectedLocalMusicPlaylist ?? localMusicPlaylists.first else {
            statusMessage = "No M3U playlists are available. Add one in Settings or scan a folder that contains playlists."
            return
        }

        addLocalMusicPlaylistToQueue(playlist, shuffle: shuffle)
    }

    func addLocalMusicPlaylistToQueue(_ playlist: LocalMusicPlaylist, shuffle: Bool = false) {
        var tracks = tracks(for: playlist)
        guard !tracks.isEmpty else {
            statusMessage = "\(playlist.name) has no playable tracks in the current library."
            return
        }

        if shuffle {
            tracks.shuffle()
        }

        let wasEmpty = sessionQueue.isEmpty
        sessionQueue.append(contentsOf: tracks)
        selectedLocalMusicPlaylistID = playlist.id

        if wasEmpty {
            sessionQueueIndex = 0
            selectedSessionQueueIndex = 0
            selectedLocalMusicTrackID = tracks[0].id
        }

        statusMessage = "Added \(tracks.count) track\(tracks.count == 1 ? "" : "s") from \(playlist.name) to the session queue."
    }

    func saveSessionQueueAsPlaylist(named rawName: String) {
        guard !sessionQueue.isEmpty else {
            statusMessage = "Session queue is empty."
            return
        }

        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            let message = "Playlist name is required."
            statusMessage = message
            lastError = message
            return
        }

        do {
            let playlist = try localMusicLibrary.saveSessionPlaylist(
                name: name,
                tracks: sessionQueue
            )
            if !localMusicSettings.m3uPlaylistPaths.contains(playlist.path) {
                localMusicSettings.m3uPlaylistPaths.append(playlist.path)
            }
            localMusicPlaylists.removeAll { $0.id == playlist.id }
            localMusicPlaylists.append(playlist)
            localMusicPlaylists.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            selectedLocalMusicPlaylistID = playlist.id
            persistLocalMusicDatabase()
            statusMessage = "Saved session queue as \(playlist.name)."
            AppLogger.shared.notice(category: "local-music", "Saved session queue playlist tracks=\(sessionQueue.count) path=\(playlist.path)")
        } catch {
            let message = "Could not save session queue playlist: \(error.localizedDescription)"
            statusMessage = message
            lastError = message
            AppLogger.shared.error(category: "local-music", message)
        }
    }

    func clearSessionQueue() {
        sessionQueue = []
        sessionQueueIndex = nil
        selectedSessionQueueIndex = nil
        statusMessage = "Session queue cleared."
    }

    func moveSessionQueueItemUp(_ index: Int) {
        moveSessionQueueItem(from: index, to: index - 1)
    }

    func moveSessionQueueItemDown(_ index: Int) {
        moveSessionQueueItem(from: index, to: index + 1)
    }

    func removeSessionQueueItem(_ index: Int) {
        guard sessionQueue.indices.contains(index) else { return }

        let removed = sessionQueue.remove(at: index)

        if sessionQueue.isEmpty {
            sessionQueueIndex = nil
            selectedSessionQueueIndex = nil
        } else if let currentIndex = sessionQueueIndex {
            if currentIndex == index {
                sessionQueueIndex = min(index, sessionQueue.count - 1)
            } else if index < currentIndex {
                sessionQueueIndex = currentIndex - 1
            }
        }

        if let selectedIndex = selectedSessionQueueIndex {
            if selectedIndex == index {
                selectedSessionQueueIndex = sessionQueue.isEmpty ? nil : min(index, sessionQueue.count - 1)
            } else if index < selectedIndex {
                selectedSessionQueueIndex = selectedIndex - 1
            }
        }

        if let sessionQueueIndex, sessionQueue.indices.contains(sessionQueueIndex) {
            selectedLocalMusicTrackID = sessionQueue[sessionQueueIndex].id
        } else if selectedLocalMusicTrackID == removed.id {
            selectedLocalMusicTrackID = nil
        }

        statusMessage = "Removed \(removed.displayTitle) from the session queue."
    }

    func playLocalMusicPlaylist(_ playlist: LocalMusicPlaylist, shuffle: Bool = false) {
        let tracks = tracks(for: playlist)
        guard !tracks.isEmpty else {
            statusMessage = "\(playlist.name) has no playable tracks in the current library."
            return
        }

        selectedLocalMusicPlaylistID = playlist.id
        startSessionQueue(from: tracks, startTrackID: tracks.first?.id, shuffle: shuffle, autoplay: true)
    }

    var localMusicCountText: String {
        let total = localMusicTracks.count
        let visible = visibleLocalMusicTracks.count

        if localMusicSettings.watchFolderPaths.isEmpty && localMusicSettings.m3uPlaylistPaths.isEmpty {
            return "Add watch folders or M3U playlists in Settings."
        }

        if total == 0 {
            return "No audio files scanned yet."
        }

        if localMusicSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(total) tracks."
        }

        return "\(visible) of \(total) shown."
    }

    var localMusicWatchFolderText: String {
        let count = localMusicSettings.watchFolderPaths.count
        return count == 1 ? "1 watch folder." : "\(count) watch folders."
    }

    var localMusicPlaylistCountText: String {
        let count = localMusicPlaylists.count
        return count == 1 ? "1 playlist." : "\(count) playlists."
    }

    var localMusicQueueText: String {
        guard !sessionQueue.isEmpty else { return "Queue is empty." }
        let current = sessionQueueIndex.map { $0 + 1 } ?? 0
        return current > 0 ? "\(current) of \(sessionQueue.count)" : "\(sessionQueue.count) queued."
    }

    var localMusicDatabasePath: String {
        localMusicLibrary.databasePath
    }

    var localMusicArtworkDirectoryPath: String {
        localMusicLibrary.artworkDirectoryPath
    }

    var localMusicSavedPlaylistDirectoryPath: String {
        localMusicLibrary.playlistDirectoryPath
    }

    var localMusicArtworkStatusText: String {
        let count = localMusicTracks.filter { $0.artworkPath != nil }.count
        return "\(count) tracks with cached artwork."
    }

    var currentLocalArtworkURL: URL? {
        guard let path = (currentQueueTrack ?? currentLocalMusicTrack ?? selectedLocalMusicTrack)?.artworkPath else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }

    var roonArtworkURL: URL? {
        guard let imageKey = roonBridgeSnapshot.selectedZone?.nowPlaying?.imageKey else {
            return nil
        }

        return roonBridgeClient.imageURL(for: imageKey)
    }

    var spotifyArtworkURL: URL? {
        guard let coverURL = spotifyNowPlaying?.coverURL else { return nil }
        return URL(string: coverURL)
    }

    var visibleLocalMusicTracks: [LocalMusicTrack] {
        let query = localMusicSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sortedTracks = sortedLocalMusicTracks
        guard !query.isEmpty else { return sortedTracks }

        return sortedTracks.filter { track in track.matches(query) }
    }

    var selectedLocalMusicTrack: LocalMusicTrack? {
        guard let selectedLocalMusicTrackID else { return nil }
        return localMusicTracks.first { $0.id == selectedLocalMusicTrackID }
    }

    var currentLocalMusicTrack: LocalMusicTrack? {
        guard let currentFileURL else { return nil }
        return localMusicTracks.first { $0.id == currentFileURL.path }
    }

    var selectedLocalMusicPlaylist: LocalMusicPlaylist? {
        guard let selectedLocalMusicPlaylistID else { return nil }
        return localMusicPlaylists.first { $0.id == selectedLocalMusicPlaylistID }
    }

    var currentQueueTrack: LocalMusicTrack? {
        guard let sessionQueueIndex, sessionQueue.indices.contains(sessionQueueIndex) else { return nil }
        return sessionQueue[sessionQueueIndex]
    }

    func tracks(for playlist: LocalMusicPlaylist) -> [LocalMusicTrack] {
        let tracksByPath = Dictionary(uniqueKeysWithValues: localMusicTracks.map { ($0.path, $0) })
        return playlist.trackPaths.compactMap { tracksByPath[$0] }
    }

    private var sortedLocalMusicTracks: [LocalMusicTrack] {
        localMusicTracks.sorted(by: localMusicComparator)
    }

    @discardableResult
    private func loadFile(url: URL, autoplay: Bool) -> Bool {
        cancelDiagnosticsForMusicAction()
        sourceMode = .filePlayback
        isLocalFileLoading = true
        statusMessage = "Loading \(url.lastPathComponent)..."
        defer { isLocalFileLoading = false }

        do {
            let loaded = try engine.loadFile(url: url)
            loadedFileName = loaded.url.lastPathComponent
            currentFileURL = loaded.url
            if localMusicTracks.contains(where: { $0.id == loaded.url.path }) {
                selectedLocalMusicTrackID = loaded.url.path
            }
            sourceMetadata = loaded.metadata
            loadedChannels = loaded.layout.channels
            resetRendererRequestToAutomatic(reason: "new track")
            duration = loaded.duration
            currentTime = 0
            scrubProgress = 0
            meterStore.configure(channels: loaded.layout.channels)
            meterStore.reset()
            monitorMeterStore.reset()
            updateRendererMeters(from: Array(repeating: 0, count: loaded.layout.channelCount))
            isPlaying = false
            lastHeartbeatSecond = -1
            lastLiveMeterLogSecond = -1
            lastLiveBufferLogSecond = -1
            lastLiveSilenceWarningSecond = -1
            lastLiveSignalPresent = nil
            liveSignalStatus = "File playback source loaded."
            liveBufferStatus = "No live buffer."
            roonNowPlayingStatus = "Roon metadata is only shown for live Roon input."
            roonSignalPath = nil

            if autoplay {
                guard prepareOutputForMusicPlayback() else { return false }
                try engine.play()
                isPlaying = true
                statusMessage = "Playing \(loaded.metadata.fileName) through \(routeDisplayName) with \(rendererScene.renderMode.displayName)."
            } else if rendererOutputRoute.isAvailable {
                statusMessage = "Loaded \(loaded.metadata.fileName). Ready to render through \(rendererOutputRoute.deviceName)."
            } else {
                statusMessage = "Loaded \(loaded.metadata.fileName). Playback can use the monitor or current macOS output."
            }

            return true
        } catch {
            AppLogger.shared.error(category: "ui", "Load failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return false
        }
    }

    private func loadLocalMusicDatabase() {
        let database = localMusicLibrary.load()
        localMusicSettings = database.settings
        localMusicTracks = database.tracks
        localMusicPlaylists = database.playlists
        sessionQueue = []
        sessionQueueIndex = nil
        selectedSessionQueueIndex = nil
        AppLogger.shared.notice(
            category: "local-music",
            "Loaded local music database tracks=\(localMusicTracks.count) playlists=\(localMusicPlaylists.count) watchFolders=\(localMusicSettings.watchFolderPaths.count)"
        )
    }

    private func persistLocalMusicDatabase() {
        localMusicLibrary.save(LocalMusicDatabase(
            settings: localMusicSettings,
            tracks: localMusicTracks,
            playlists: localMusicPlaylists
        ))
    }

    private func updateLocalMusicSettings(_ settings: LocalMusicSettings, rescan: Bool) {
        localMusicSettings = settings
        persistLocalMusicDatabase()
        if rescan {
            rescanLocalMusicLibrary()
        }
    }

    private func startSessionQueue(
        from tracks: [LocalMusicTrack],
        startTrackID: String?,
        shuffle: Bool,
        autoplay: Bool
    ) {
        guard !tracks.isEmpty else {
            statusMessage = "No local music matches the current view."
            return
        }

        isShuffleEnabled = shuffle

        let startTrack = startTrackID.flatMap { id in tracks.first { $0.id == id } } ?? tracks[0]
        let queue: [LocalMusicTrack]
        if shuffle {
            let rest = tracks.filter { $0.id != startTrack.id }.shuffled()
            queue = [startTrack] + rest
        } else {
            queue = tracks
        }

        sessionQueue = queue
        sessionQueueIndex = queue.firstIndex { $0.id == startTrack.id } ?? 0
        selectedSessionQueueIndex = sessionQueueIndex
        selectedLocalMusicTrackID = startTrack.id
        _ = loadFile(url: startTrack.url, autoplay: autoplay)
    }

    private func playQueueOffset(_ offset: Int, wrap: Bool) {
        if sessionQueue.isEmpty {
            let tracks = visibleLocalMusicTracks
            guard !tracks.isEmpty else {
                statusMessage = "Add a watch folder in Settings, then scan local music."
                return
            }
            startSessionQueue(from: tracks, startTrackID: tracks.first?.id, shuffle: isShuffleEnabled, autoplay: true)
            return
        }

        let currentIndex: Int
        if let sessionQueueIndex, sessionQueue.indices.contains(sessionQueueIndex) {
            currentIndex = sessionQueueIndex
        } else if let currentFileURL,
                  let loadedIndex = sessionQueue.firstIndex(where: { $0.id == currentFileURL.path }) {
            currentIndex = loadedIndex
        } else {
            currentIndex = offset < 0 ? 0 : -1
        }

        var nextIndex = currentIndex + offset
        if wrap {
            nextIndex = (nextIndex + sessionQueue.count) % sessionQueue.count
        }

        guard sessionQueue.indices.contains(nextIndex) else {
            statusMessage = "End of session queue."
            return
        }

        playQueueIndex(nextIndex)
    }

    @discardableResult
    private func playQueueIndex(_ index: Int) -> Bool {
        guard sessionQueue.indices.contains(index) else { return false }
        sessionQueueIndex = index
        selectedSessionQueueIndex = index
        let track = sessionQueue[index]
        selectedLocalMusicTrackID = track.id
        return loadFile(url: track.url, autoplay: true)
    }

    private func moveSessionQueueItem(from sourceIndex: Int, to destinationIndex: Int) {
        guard sessionQueue.indices.contains(sourceIndex),
              sessionQueue.indices.contains(destinationIndex),
              sourceIndex != destinationIndex
        else { return }

        sessionQueue.swapAt(sourceIndex, destinationIndex)

        if let currentIndex = sessionQueueIndex {
            if currentIndex == sourceIndex {
                sessionQueueIndex = destinationIndex
            } else if currentIndex == destinationIndex {
                sessionQueueIndex = sourceIndex
            }
        }

        if let selectedIndex = selectedSessionQueueIndex {
            if selectedIndex == sourceIndex {
                selectedSessionQueueIndex = destinationIndex
            } else if selectedIndex == destinationIndex {
                selectedSessionQueueIndex = sourceIndex
            }
        }
    }

    func startRoonPipe() {
        cancelDiagnosticsForMusicAction()
        sourceMode = .roon
        currentFileURL = nil
        refreshRoutesIfNeeded(force: true)
        refreshRoonNowPlayingIfNeeded(force: true)
        refreshRoonBridgeIfNeeded(force: true)
        selectExpectedLoopbackInputIfAvailable(for: .roon)

        guard inputRoute.isRoonLoopback else {
            let message = missingLoopbackMessage(for: .roon)
            AppLogger.shared.error(category: "ui", message)
            statusMessage = message
            lastError = message
            liveMonitorState = .unavailable(message)
            return
        }

        guard prepareOutputForMusicPlayback() else { return }

        repairBlackHoleSampleRateIfNeeded(force: true)
        BlackHoleRouteRepair.prepareInputDeviceForCapture(inputRoute, preferredSampleRate: roonNowPlaying?.outputSampleRate)
        refreshRoutesIfNeeded(force: true)
        startLiveInputForCurrentRoute(reason: "manual")
        refreshRoonNowPlayingIfNeeded(force: true)
    }

    func startSpotifyPipe() {
        cancelDiagnosticsForMusicAction()
        sourceMode = .spotify
        currentFileURL = nil
        roonNowPlaying = nil
        roonSignalPath = nil
        activeLiveChannelCount = SourceMode.spotify.fixedLiveChannelCount ?? 2
        refreshRoutesIfNeeded(force: true)
        selectExpectedLoopbackInputIfAvailable(for: .spotify)

        guard inputRoute.isSpotifyLoopback else {
            let message = missingLoopbackMessage(for: .spotify)
            AppLogger.shared.error(category: "ui", message)
            statusMessage = message
            lastError = message
            liveMonitorState = .unavailable(message)
            return
        }

        guard prepareOutputForMusicPlayback() else { return }

        refreshSpotifyConnectServerIfNeeded(reason: "manual spotify input", force: true)
        refreshSpotifyNowPlayingIfNeeded(force: true)
        startLiveInputForCurrentRoute(reason: "manual spotify input")
    }

    func startOtherInputPipe() {
        cancelDiagnosticsForMusicAction()
        sourceMode = .aux
        currentFileURL = nil
        roonNowPlaying = nil
        roonSignalPath = nil
        refreshRoutesIfNeeded(force: true)
        selectExpectedLoopbackInputIfAvailable(for: .aux)

        guard inputRoute.isAuxLoopback else {
            let message = missingLoopbackMessage(for: .aux)
            AppLogger.shared.error(category: "ui", message)
            statusMessage = message
            lastError = message
            liveMonitorState = .unavailable(message)
            return
        }

        guard prepareOutputForMusicPlayback() else { return }

        startLiveInputForCurrentRoute(reason: "manual other input")
    }

    private func startLiveInputForCurrentRoute(reason: String, resetRendererMode: Bool = true) {
        guard recoverRoonMonoRouteIfNeeded(reason: reason) else { return }

        let requestedChannelCount = preferredLiveChannelCount()
        if resetRendererMode {
            resetRendererRequestToAutomatic(reason: "\(sourceMode.rawValue) input changed")
        } else {
            refreshRendererScene()
        }
        let liveLayout = SurroundLayoutDetector.fallbackLayout(for: requestedChannelCount)
        let liveRendererMode = RendererModePolicy.effectiveRequestedMode(
            requestedMode: rendererRenderMode,
            inputChannelCount: requestedChannelCount,
            alwaysMono: rendererAlwaysMono,
            twoChannelPreference: rendererTwoChannelPreference
        )
        rendererScene = RendererMatrixBuilder.sceneModel(
            for: liveLayout,
            preset: rendererPreset,
            renderMode: liveRendererMode
        )
        syncRendererAudioRouting()

        do {
            let liveSource = try engine.startLiveInput(
                activeChannelCount: requestedChannelCount,
                inputRoute: inputRoute,
                sourceName: liveInputSourceName,
                rendererMode: liveRendererMode,
                rendererPreset: rendererPreset,
                directRendererAudioEnabled: shouldUseDirectRendererAudio(scene: rendererScene)
            )
            loadedFileName = liveSource.metadata.fileName
            sourceMetadata = liveSource.metadata
            loadedChannels = liveSource.layout.channels
            refreshRendererScene()
            duration = 0
            currentTime = 0
            scrubProgress = 0
            activeLiveChannelCount = requestedChannelCount
            meterStore.configure(channels: liveSource.layout.channels)
            meterStore.reset()
            monitorMeterStore.reset()
            updateRendererMeters(from: Array(repeating: 0, count: liveSource.layout.channelCount))
            isPlaying = true
            liveMonitorState = .monitoring
            lastHeartbeatSecond = -1
            lastLiveMeterLogSecond = -1
            lastLiveBufferLogSecond = -1
            lastLiveSilenceWarningSecond = -1
            lastLiveSignalPresent = nil
            liveSignalStatus = "Waiting for signal from \(liveInputSignalName)."
            liveBufferStatus = "Priming live buffer."
            if sourceMode == .roon {
                refreshRoonNowPlayingIfNeeded(force: true)
            }
            if sourceMode == .spotify {
                refreshSpotifyNowPlayingIfNeeded(force: true)
                refreshSpotifyConnectServerIfNeeded(reason: "monitor started")
            }

            if sourceMode == .roon, inputRoute.isRoonLoopback {
                statusMessage = "Capturing Roon and rendering to \(routeDisplayName)."
            } else if sourceMode == .spotify, inputRoute.isSpotifyLoopback {
                statusMessage = "Capturing Spotify from Orbisonic Spotify Input and rendering to \(routeDisplayName)."
            } else {
                statusMessage = "Capturing Aux Cable and rendering to \(routeDisplayName). Source playback stays in the source app."
            }

            AppLogger.shared.notice(
                category: "live-input",
                "Live input active source=\(sourceMode.rawValue) reason=\(reason) input=\(inputRoute.deviceName) uid=\(inputRoute.uid) activeChannels=\(requestedChannelCount)"
            )
        } catch {
            liveMonitorState = .error(error.localizedDescription)
            AppLogger.shared.error(category: "ui", "Live monitor failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    private func recoverRoonMonoRouteIfNeeded(reason: String) -> Bool {
        guard sourceMode == .roon else { return true }

        let isStaleMono = inputRoute.inputChannelCount == 1 || activeLiveChannelCount == 1
        guard isStaleMono else { return true }

        AppLogger.shared.warning(
            category: "route",
            "Recovering stale Roon mono route reason=\(reason) route=\(inputRoute.deviceName) channels=\(inputRoute.inputChannelCount) active=\(activeLiveChannelCount)"
        )

        refreshRoutesIfNeeded(force: true)
        selectExpectedLoopbackInputIfAvailable(for: .roon)
        activeLiveChannelCount = 2

        guard inputRoute.isRoonLoopback, inputRoute.inputChannelCount >= 2 else {
            let message = "Roon route recovery could not find a valid stereo-or-better Orbisonic Roon Input."
            statusMessage = message
            lastError = message
            liveMonitorState = .unavailable(message)
            AppLogger.shared.error(category: "route", message)
            return false
        }

        AppLogger.shared.notice(
            category: "route",
            "Recovered Roon route input=\(inputRoute.deviceName) channels=\(inputRoute.inputChannelCount) active=2"
        )
        return true
    }

    func togglePlayback() {
        cancelDiagnosticsForMusicAction()

        if sourceMode == .roon {
            if liveMonitorState.isMuted {
                resumeLiveMonitor()
            } else if isPlaying {
                muteLiveMonitor()
            } else {
                startRoonPipe()
            }
            return
        }

        if sourceMode == .spotify {
            if liveMonitorState.isMuted {
                resumeLiveMonitor()
            } else if isPlaying {
                muteLiveMonitor()
            } else {
                startSpotifyPipe()
            }
            return
        }

        if sourceMode == .aux {
            if liveMonitorState.isMuted {
                resumeLiveMonitor()
            } else if isPlaying {
                muteLiveMonitor()
            } else {
                startOtherInputPipe()
            }
            return
        }

        if sourceMode == .testTone {
            if isTestTonePlaying {
                stopTestTone()
            } else {
                playSelectedTestTone()
            }
            return
        }

        guard duration > 0 else {
            statusMessage = "Open a surround file first."
            AppLogger.shared.debug(category: "ui", "Play requested before a file was loaded.")
            return
        }

        do {
            if isPlaying {
                engine.pause()
                isPlaying = false
                reevaluateAutomaticRendererMode(reason: "pause")
                statusMessage = "Paused."
            } else {
                guard prepareOutputForMusicPlayback() else { return }
                reevaluateAutomaticRendererMode(reason: "play")
                try engine.play()
                isPlaying = true
                statusMessage = "Playing through \(routeDisplayName) with \(rendererRenderMode.displayName)."
            }
        } catch {
            AppLogger.shared.error(category: "ui", "Playback toggle failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    var roonTransportStatusText: String {
        roonBridgeSnapshot.statusText
    }

    var roonAudioPathText: String {
        roonBridgeSnapshot.audioPathText
    }

    var roonTransportCompactStatusText: String {
        roonBridgeSnapshot.compactStatusText
    }

    var roonTransportTitleText: String? {
        roonBridgeSnapshot.selectedZone?.titleText
    }

    var roonTransportSubtitleText: String? {
        roonBridgeSnapshot.selectedZone?.subtitleText
    }

    var isRoonTransportPlaying: Bool {
        roonBridgeSnapshot.selectedZone?.isPlaying == true
    }

    func canSendRoonTransport(_ control: RoonBridgeControl) -> Bool {
        guard sourceMode == .roon,
              roonBridgeSnapshot.isReadyForTransport,
              let selectedZone = roonBridgeSnapshot.selectedZone
        else {
            return false
        }

        return selectedZone.allows(control)
    }

    func openRoon() {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.roon.Roon") else {
            statusMessage = "Open Roon and enable Orbisonic in Settings > Extensions."
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { [weak self] _, error in
            Task { @MainActor [weak self] in
                if let error {
                    self?.statusMessage = "Could not open Roon: \(error.localizedDescription)"
                    self?.lastError = error.localizedDescription
                } else {
                    self?.statusMessage = "Opening Roon."
                }
            }
        }
    }

    func toggleRoonTransport() {
        let control: RoonBridgeControl = isRoonTransportPlaying ? .pause : .play
        sendRoonTransport(control)
    }

    func stopRoonTransport() {
        sendRoonTransport(.stop)
    }

    func playPreviousRoonTrack() {
        sendRoonTransport(.previous)
    }

    func playNextRoonTrack() {
        sendRoonTransport(.next)
    }

    func startSelectedLiveMonitor() {
        guard !isLiveMonitorTransitioning else { return }
        isLiveMonitorTransitioning = true
        defer { isLiveMonitorTransitioning = false }
        statusMessage = "Starting \(sourceMode.rawValue) monitor..."
        switch sourceMode {
        case .roon:
            startRoonPipe()
        case .spotify:
            startSpotifyPipe()
        case .aux:
            startOtherInputPipe()
        case .filePlayback, .testTone:
            togglePlayback()
        }
    }

    func muteLiveMonitor() {
        guard sourceMode.isLiveInput, isPlaying else { return }
        guard !isLiveMonitorTransitioning else { return }

        engine.setLiveInputMuted(true)
        liveMonitorState = .muted
        monitorMeterStore.reset()
        rendererMeterStore.reset()
        statusMessage = "\(sourceMode.rawValue) monitor muted. Input metering remains active."
        AppLogger.shared.notice(category: "live-input", "Muted live monitor source=\(sourceMode.rawValue)")
    }

    func resumeLiveMonitor() {
        guard sourceMode.isLiveInput else { return }
        guard !isLiveMonitorTransitioning else { return }

        if !isPlaying {
            startSelectedLiveMonitor()
            return
        }

        engine.setLiveInputMuted(false)
        liveMonitorState = .monitoring
        statusMessage = "\(sourceMode.rawValue) monitor resumed."
        AppLogger.shared.notice(category: "live-input", "Resumed live monitor source=\(sourceMode.rawValue)")
    }

    func stopSelectedLiveMonitor() {
        guard !isLiveMonitorTransitioning else { return }
        isLiveMonitorTransitioning = true
        defer { isLiveMonitorTransitioning = false }
        guard sourceMode.isLiveInput else {
            stop()
            return
        }

        let sourceName = sourceMode.rawValue
        stopSpotifyReceiverIfNeeded()
        markLiveMonitorStopped(sourceName: sourceName)
        engine.stop()
        markLiveMonitorStopped(sourceName: sourceName)
        AppLogger.shared.notice(category: "live-input", "Stopped live monitor source=\(sourceName)")
    }

    private func stopLiveMonitorForSourceSwitch(to mode: SourceMode) {
        guard sourceMode.isLiveInput else { return }

        let sourceName = sourceMode.rawValue
        stopSpotifyReceiverIfNeeded()
        markLiveMonitorStopped(sourceName: sourceName)
        engine.stop()
        markLiveMonitorStopped(sourceName: sourceName)
        AppLogger.shared.notice(
            category: "live-input",
            "Stopped live monitor source=\(sourceName) before selecting source=\(mode.rawValue)"
        )
    }

    private func stopSpotifyReceiverIfNeeded() {
        guard sourceMode == .spotify else { return }
        spotifyReceiverClient.stop()
        spotifyReceiverStatus = .notStarted
        spotifyNowPlaying = nil
    }

    private func markLiveMonitorStopped(sourceName: String) {
        isPlaying = false
        liveMonitorState = .stopped
        clearLoadedSourceSnapshot()
        duration = 0
        currentTime = 0
        scrubProgress = 0
        monitorMeterStore.reset()
        rendererMeterStore.reset()
        lastHeartbeatSecond = -1
        lastLiveMeterLogSecond = -1
        lastLiveBufferLogSecond = -1
        lastLiveSilenceWarningSecond = -1
        lastLiveSignalPresent = nil
        liveSignalStatus = "\(sourceName) monitoring stopped."
        liveBufferStatus = "No live buffer."
        statusMessage = "\(sourceName) monitoring stopped."
    }

    private func clearLoadedSourceSnapshot() {
        sourceMetadata = nil
        loadedChannels = []
        loadedFileName = "No file loaded"
        meterStore.configure(channels: [])
        refreshRendererScene()
    }

    func stop() {
        testToneStopTask?.cancel()
        testToneStopTask = nil
        diagnosticSequenceTask?.cancel()
        diagnosticSequenceTask = nil
        diagnosticReturnContext = nil
        stopSpotifyReceiverIfNeeded()
        engine.stop()
        isPlaying = false
        liveMonitorState = .stopped
        isTestTonePlaying = false
        isDiagnosticSequencePlaying = false
        isDiagnosticTransitioning = false
        activeDiagnosticPoint = nil
        activeDiagnosticChannelIndex = nil
        activeDiagnosticChannelCount = 0
        activeDiagnosticWalkTitle = ""
        rendererDiagnosticsUsingMonitorPreview = false
        rendererDiagnosticsMonitorDownmixAvailable = false
        diagnosticSequencePosition = 0
        currentTime = 0
        scrubProgress = 0
        meterStore.reset()
        monitorMeterStore.reset()
        rendererMeterStore.reset()
        lastHeartbeatSecond = -1
        lastLiveMeterLogSecond = -1
        lastLiveBufferLogSecond = -1
        lastLiveSilenceWarningSecond = -1
        lastLiveSignalPresent = nil
        liveSignalStatus = "No live input."
        liveBufferStatus = "No live buffer."
        testToneStatus = ""
        diagnosticWalkStatus = "Ready."
        roonNowPlayingStatus = "Roon metadata stopped."
        roonSignalPath = nil
        currentFileURL = sourceMode == .filePlayback ? currentFileURL : nil
        reevaluateAutomaticRendererMode(reason: "stop")
        statusMessage = "Stopped."
    }

    var diagnosticToneSequence: [TestTonePipelinePoint] {
        TestTonePipelinePoint.channelWalkPoints
    }

    var activeDiagnosticText: String {
        if let activeDiagnosticChannelIndex {
            return "\(activeDiagnosticWalkTitle) \(activeDiagnosticChannelIndex + 1) / \(activeDiagnosticChannelCount)"
        }

        if let activeDiagnosticPoint {
            return "\(diagnosticSequencePosition) / \(diagnosticToneSequence.count): \(activeDiagnosticPoint.rawValue)"
        }

        return isDiagnosticSequencePlaying ? "Starting diagnostics..." : "Ready."
    }

    var monitorChannelWalkCount: Int {
        2
    }

    var rendererOutputChannelWalkCount: Int {
        max(rendererScene.outputSpeakers.count, rendererPreset.outputTopology.fullRangeCount + rendererPreset.outputTopology.lfeCount)
    }

    var diagnosticSpeakerChannelCount: Int {
        Self.diagnosticSpeakerChannelCount
    }

    private func clampedDiagnosticSpeakerChannel(_ channel: Int) -> Int {
        min(max(channel, 1), Self.diagnosticSpeakerChannelCount)
    }

    func selectDiagnosticSpeakerChannel(_ channel: Int) {
        let clamped = clampedDiagnosticSpeakerChannel(channel)
        guard selectedDiagnosticSpeakerChannel != clamped else { return }
        selectedDiagnosticSpeakerChannel = clamped
    }

    func startMonitorChannelWalk() {
        startDiagnosticChannelWalk(kind: .monitor)
    }

    func startRendererOutputChannelWalk() {
        startDiagnosticChannelWalk(kind: .renderer)
    }

    func startDiagnosticChannelWalk() {
        startMonitorChannelWalk()
    }

    private func startDiagnosticChannelWalk(kind: DiagnosticChannelWalkKind) {
        refreshRoutesIfNeeded(force: true)

        guard prepareDiagnosticOutput(for: kind) else { return }

        testToneStopTask?.cancel()
        testToneStopTask = nil
        diagnosticSequenceTask?.cancel()

        diagnosticReturnContext = DiagnosticReturnContext(
            sourceMode: sourceMode,
            wasPlaying: isPlaying,
            progress: min(max(scrubProgress, 0), 1),
            hadSource: sourceMetadata != nil
        )

        engine.stop()
        isPlaying = false
        isTestTonePlaying = true
        isDiagnosticSequencePlaying = true
        isDiagnosticTransitioning = true
        activeDiagnosticPoint = nil
        activeDiagnosticChannelIndex = nil
        activeDiagnosticWalkTitle = kind.title
        activeDiagnosticChannelCount = kind == .monitor ? monitorChannelWalkCount : rendererOutputChannelWalkCount
        diagnosticSequencePosition = 0
        testToneStatus = ""
        if rendererDiagnosticsUsingMonitorPreview, kind == .renderer {
            diagnosticWalkStatus = "Starting renderer channel walk as monitor preview."
            statusMessage = "Renderer output is not set. Previewing renderer channel walk through \(routeDisplayName)."
        } else {
            diagnosticWalkStatus = "Starting \(kind.shortTitle.lowercased()) channel walk."
            statusMessage = "Running \(kind.shortTitle.lowercased()) channel walk through \(routeDisplayName)."
        }

        AppLogger.shared.notice(
            category: "diagnostics",
            "Started \(kind.title) output=\(outputRoute.deviceName) channels=\(activeDiagnosticChannelCount) monitorPreview=\(rendererDiagnosticsUsingMonitorPreview) returnSource=\(diagnosticReturnContext?.sourceMode.rawValue ?? "none") wasPlaying=\(diagnosticReturnContext?.wasPlaying ?? false)"
        )

        diagnosticSequenceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 140_000_000)
            } catch {
                await MainActor.run {
                    self?.isDiagnosticTransitioning = false
                }
                return
            }

            await MainActor.run {
                self?.isDiagnosticTransitioning = false
            }

            let total = await MainActor.run {
                self?.activeDiagnosticChannelCount ?? 0
            }

            for index in 0..<total {
                let shouldContinue = await MainActor.run {
                    self?.playDiagnosticChannel(kind: kind, index: index, total: total) ?? false
                }

                guard shouldContinue else { return }

                do {
                    try await Task.sleep(nanoseconds: 1_500_000_000)
                } catch {
                    return
                }
            }

            await MainActor.run {
                self?.finishDiagnosticChannelWalk(restoreMusic: true, automatic: true)
            }
        }
    }

    private func prepareDiagnosticOutput(for kind: DiagnosticChannelWalkKind) -> Bool {
        rendererDiagnosticsUsingMonitorPreview = false
        rendererDiagnosticsMonitorDownmixAvailable = false
        try? engine.setDiagnosticMonitorOutputDevice(nil)

        switch kind {
        case .monitor:
            return ensureOutputForAction(.monitor)
        case .renderer:
            if rendererOutputSelection != .none {
                guard ensureOutputForAction(.renderer) else { return false }
                rendererDiagnosticsMonitorDownmixAvailable = configureDiagnosticMonitorDownmix()
                return true
            }

            rendererDiagnosticsUsingMonitorPreview = true
            if monitorOutputRoute.isAvailable {
                return applyOutputRouteIfAvailable(monitorOutputRoute, purpose: .monitor, label: monitorOutputRoute.deviceName)
            }

            let fallbackRoute = outputRoute.isAvailable ? outputRoute : systemOutputRoute
            if fallbackRoute.isAvailable, fallbackRoute.isSelectableOutputTarget {
                outputRoute = fallbackRoute
                syncRendererAudioRouting()
                statusMessage = "Renderer output is not set; using \(fallbackRoute.deviceName) for monitor preview."
                AppLogger.shared.notice(category: "diagnostics", "Renderer diagnostic preview using fallback output=\(fallbackRoute.deviceName)")
                return true
            }

            AppLogger.shared.notice(category: "diagnostics", "Renderer diagnostic preview starting without explicit output route.")
            return true
        }
    }

    private func configureDiagnosticMonitorDownmix() -> Bool {
        guard monitorOutputRoute.isAvailable,
              monitorOutputRoute.isSelectableOutputTarget
        else {
            AppLogger.shared.warning(category: "diagnostics", "Monitor downmix unavailable for renderer diagnostic; no monitor output route.")
            return false
        }

        do {
            try engine.setDiagnosticMonitorOutputDevice(monitorOutputRoute.deviceID)
            return true
        } catch {
            AppLogger.shared.warning(category: "diagnostics", "Monitor downmix unavailable: \(error.localizedDescription)")
            return false
        }
    }

    func stopDiagnosticsAndReturnToMusic() {
        finishDiagnosticChannelWalk(restoreMusic: true, automatic: false)
    }

    private func playDiagnosticChannel(
        kind: DiagnosticChannelWalkKind,
        index: Int,
        total: Int
    ) -> Bool {
        guard isDiagnosticSequencePlaying else { return false }

        do {
            let usesMonitorDownmix = kind == .renderer
                && !rendererDiagnosticsUsingMonitorPreview
                && rendererDiagnosticsMonitorDownmixAvailable
            try engine.playDiagnosticChannelTone(
                channelIndex: index,
                channelCount: total,
                monitorDownmix: usesMonitorDownmix
            )
            activeDiagnosticPoint = nil
            activeDiagnosticChannelIndex = index
            activeDiagnosticChannelCount = total
            activeDiagnosticWalkTitle = kind.title
            diagnosticSequencePosition = index + 1
            if rendererDiagnosticsUsingMonitorPreview, kind == .renderer {
                diagnosticWalkStatus = "Playing renderer channel \(index + 1) of \(total) as monitor downmix."
                statusMessage = "Renderer channel \(index + 1) preview is active on \(routeDisplayName)."
            } else if usesMonitorDownmix {
                diagnosticWalkStatus = "Playing renderer channel \(index + 1) of \(total) with monitor downmix."
                statusMessage = "Renderer channel \(index + 1) is active on \(routeDisplayName); monitor downmix is on \(monitorOutputRoute.deviceName)."
            } else {
                diagnosticWalkStatus = "Playing \(kind.shortTitle.lowercased()) channel \(index + 1) of \(total)."
                statusMessage = "\(kind.shortTitle) channel \(index + 1) is active on \(routeDisplayName)."
            }

            meterStore.reset()
            switch kind {
            case .monitor:
                let channels = SurroundLayoutDetector.fallbackLayout(for: total).channels
                monitorMeterStore.configureIfNeeded(channels: channels)
                monitorMeterStore.update(with: activeLevel(index: index, count: total))
                rendererMeterStore.reset()
            case .renderer:
                let channels = rendererMeterChannels()
                rendererMeterStore.configureIfNeeded(channels: channels)
                rendererMeterStore.update(with: activeLevel(index: index, count: channels.count))
                if rendererDiagnosticsUsingMonitorPreview || usesMonitorDownmix {
                    monitorMeterStore.configureIfNeeded(channels: SurroundLayoutDetector.fallbackLayout(for: monitorChannelWalkCount).channels)
                    monitorMeterStore.update(with: Array(repeating: Float(0.72), count: monitorChannelWalkCount))
                } else {
                    monitorMeterStore.reset()
                }
            }

            AppLogger.shared.notice(
                category: "diagnostics",
                "\(kind.title) channel \(index + 1)/\(total) output=\(outputRoute.deviceName)"
            )
            return true
        } catch {
            AppLogger.shared.error(category: "diagnostics", "\(kind.title) failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
            finishDiagnosticChannelWalk(restoreMusic: true, automatic: false)
            return false
        }
    }

    private func finishDiagnosticChannelWalk(restoreMusic: Bool, automatic: Bool) {
        diagnosticSequenceTask?.cancel()
        diagnosticSequenceTask = nil
        testToneStopTask?.cancel()
        testToneStopTask = nil
        engine.stopTestTone()

        isTestTonePlaying = false
        isDiagnosticSequencePlaying = false
        activeDiagnosticPoint = nil
        activeDiagnosticChannelIndex = nil
        activeDiagnosticChannelCount = 0
        activeDiagnosticWalkTitle = ""
        rendererDiagnosticsUsingMonitorPreview = false
        diagnosticSequencePosition = 0
        meterStore.reset()
        monitorMeterStore.reset()
        rendererMeterStore.reset()
        diagnosticWalkStatus = automatic ? "Diagnostic channel walk finished." : "Diagnostic channel walk stopped."

        AppLogger.shared.notice(
            category: "diagnostics",
            "Finished diagnostic channel walk automatic=\(automatic) restoreMusic=\(restoreMusic)"
        )

        if restoreMusic {
            restoreMusicAfterDiagnostics()
        } else {
            diagnosticReturnContext = nil
        }
    }

    private func restoreMusicAfterDiagnostics() {
        guard let context = diagnosticReturnContext else {
            statusMessage = "Diagnostics stopped. No previous music source to restore."
            return
        }

        diagnosticReturnContext = nil
        sourceMode = context.sourceMode

        switch context.sourceMode {
        case .filePlayback:
            guard context.hadSource else {
                statusMessage = "Diagnostics stopped. Open a file or pipe in Roon to continue."
                return
            }

            guard context.wasPlaying, duration > 0 else {
                statusMessage = "Diagnostics stopped. File source is ready."
                return
            }

            do {
                engine.stop()
                scrubProgress = context.progress
                currentTime = duration * scrubProgress
                engine.seek(toProgress: scrubProgress)
                try engine.play()
                isPlaying = true
                statusMessage = "Returned to music at \(formattedCurrentTime())."
            } catch {
                AppLogger.shared.error(category: "diagnostics", "Failed to return to file playback: \(error.localizedDescription)")
                lastError = error.localizedDescription
                statusMessage = "Diagnostics stopped, but music could not resume."
            }

        case .roon:
            guard context.wasPlaying else {
                statusMessage = "Diagnostics stopped. Roon route is ready."
                return
            }

            startRoonPipe()

        case .spotify:
            guard context.wasPlaying else {
                statusMessage = "Diagnostics stopped. Spotify route is ready."
                return
            }

            startSpotifyPipe()

        case .testTone:
            statusMessage = "Diagnostics stopped. Test tone source is ready."

        case .aux:
            guard context.wasPlaying else {
                statusMessage = "Diagnostics stopped. Live input route is ready."
                return
            }

            startOtherInputPipe()
        }
    }

    private func cancelDiagnosticsForMusicAction() {
        if isDiagnosticSequencePlaying {
            finishDiagnosticChannelWalk(restoreMusic: false, automatic: false)
        } else {
            stopTestTone()
        }
    }

    func playSelectedTestTone() {
        refreshRoutesIfNeeded(force: true)
        rendererDiagnosticsMonitorDownmixAvailable = false
        try? engine.setDiagnosticMonitorOutputDevice(nil)

        let purpose: OutputPurpose = selectedTestTonePoint.spatialChannel == nil ? .monitor : .renderer
        guard ensureOutputForAction(purpose) else { return }
        let monitorDownmix = purpose == .renderer && configureDiagnosticMonitorDownmix()

        if isPlaying {
            stop()
        } else {
            stopTestTone()
        }

        do {
            try engine.playTestTone(selectedTestTonePoint, monitorDownmix: monitorDownmix)
            isTestTonePlaying = true
            testToneStatus = "Playing \(selectedTestTonePoint.rawValue) for 3 seconds."
            statusMessage = monitorDownmix
                ? "\(selectedTestTonePoint.pipelineDescription). Renderer output is \(routeDisplayName); monitor downmix is on \(monitorOutputRoute.deviceName)."
                : "\(selectedTestTonePoint.pipelineDescription). Listen on \(routeDisplayName)."

            let channels = selectedTestTonePoint.meterChannels
            meterStore.configure(channels: channels)
            meterStore.update(with: Array(repeating: 0.82, count: channels.count))
            let rendererTestLevels = Array(repeating: Float(0.82), count: rendererScene.matrix.inputCount)
            if monitorDownmix {
                monitorMeterStore.configureIfNeeded(channels: SurroundLayoutDetector.fallbackLayout(for: monitorChannelWalkCount).channels)
                monitorMeterStore.update(with: Array(repeating: Float(0.72), count: monitorChannelWalkCount))
            } else {
                updateMonitorMeters(from: rendererTestLevels.isEmpty ? [Float(0.82)] : rendererTestLevels)
            }
            updateRendererMeters(from: rendererTestLevels)

            AppLogger.shared.notice(
                category: "diagnostics",
                "UI requested test tone point=\(selectedTestTonePoint.rawValue) output=\(outputRoute.deviceName)"
            )

            testToneStopTask?.cancel()
            testToneStopTask = Task { [weak self] in
                do {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                } catch {
                    return
                }

                await MainActor.run {
                    self?.stopTestTone(automatic: true)
                }
            }
        } catch {
            AppLogger.shared.error(category: "diagnostics", "Test tone failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
            testToneStatus = "Test tone failed."
        }
    }

    func playSelectedDiagnosticSpeakerTone() {
        refreshRoutesIfNeeded(force: true)
        rendererDiagnosticsUsingMonitorPreview = false
        rendererDiagnosticsMonitorDownmixAvailable = false
        try? engine.setDiagnosticMonitorOutputDevice(nil)

        if rendererOutputSelection != .none {
            guard ensureOutputForAction(.renderer) else { return }
            rendererDiagnosticsMonitorDownmixAvailable = configureDiagnosticMonitorDownmix()
        } else {
            rendererDiagnosticsUsingMonitorPreview = true
            if monitorOutputRoute.isAvailable {
                guard applyOutputRouteIfAvailable(monitorOutputRoute, purpose: .monitor, label: monitorOutputRoute.deviceName) else { return }
            } else if outputRoute.isAvailable || systemOutputRoute.isAvailable {
                let fallbackRoute = outputRoute.isAvailable ? outputRoute : systemOutputRoute
                guard fallbackRoute.isSelectableOutputTarget else {
                    let message = outputFeedbackMessage(for: fallbackRoute, purpose: .monitor)
                    statusMessage = message
                    lastError = message
                    return
                }
                outputRoute = fallbackRoute
                syncRendererAudioRouting()
            }
        }

        if isPlaying {
            stop()
        } else {
            stopTestTone()
        }

        let channel = clampedDiagnosticSpeakerChannel(selectedDiagnosticSpeakerChannel)
        selectDiagnosticSpeakerChannel(channel)
        let monitorDownmix = !rendererDiagnosticsUsingMonitorPreview && rendererDiagnosticsMonitorDownmixAvailable

        do {
            try engine.playDiagnosticChannelTone(
                channelIndex: channel - 1,
                channelCount: Self.diagnosticSpeakerChannelCount,
                monitorDownmix: monitorDownmix
            )
            isTestTonePlaying = true
            activeDiagnosticPoint = nil
            activeDiagnosticChannelIndex = channel - 1
            activeDiagnosticChannelCount = Self.diagnosticSpeakerChannelCount
            activeDiagnosticWalkTitle = "Test Tone"
            testToneStatus = rendererDiagnosticsUsingMonitorPreview
                ? "Playing channel \(channel) as monitor downmix preview."
                : (monitorDownmix ? "Playing channel \(channel) on renderer output with monitor downmix." : "Playing channel \(channel) on renderer output.")
            statusMessage = rendererDiagnosticsUsingMonitorPreview
                ? "Renderer output is not set. Channel \(channel) is previewing through \(routeDisplayName)."
                : (monitorDownmix ? "Channel \(channel) tone is active on \(routeDisplayName); monitor downmix is on \(monitorOutputRoute.deviceName)." : "Channel \(channel) tone is active on \(routeDisplayName).")

            let channels = rendererMeterChannels()
            rendererMeterStore.configureIfNeeded(channels: channels)
            rendererMeterStore.update(with: activeLevel(index: channel - 1, count: channels.count))
            if rendererDiagnosticsUsingMonitorPreview || monitorDownmix {
                monitorMeterStore.configureIfNeeded(channels: SurroundLayoutDetector.fallbackLayout(for: monitorChannelWalkCount).channels)
                monitorMeterStore.update(with: Array(repeating: Float(0.72), count: monitorChannelWalkCount))
            } else {
                monitorMeterStore.reset()
            }

            AppLogger.shared.notice(
                category: "diagnostics",
                "Started speaker test tone channel=\(channel)/\(Self.diagnosticSpeakerChannelCount) monitorPreview=\(rendererDiagnosticsUsingMonitorPreview) output=\(outputRoute.deviceName)"
            )
        } catch {
            AppLogger.shared.error(category: "diagnostics", "Speaker test tone failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
            testToneStatus = "Speaker test tone failed."
        }
    }

    func stopTestTone(automatic: Bool = false) {
        testToneStopTask?.cancel()
        testToneStopTask = nil
        engine.stopTestTone()

        guard isTestTonePlaying else { return }

        isTestTonePlaying = false
        rendererDiagnosticsUsingMonitorPreview = false
        rendererDiagnosticsMonitorDownmixAvailable = false
        activeDiagnosticChannelIndex = nil
        activeDiagnosticChannelCount = 0
        activeDiagnosticWalkTitle = ""
        meterStore.reset()
        monitorMeterStore.reset()
        rendererMeterStore.reset()
        testToneStatus = automatic ? "Diagnostic tone finished." : "Diagnostic tone stopped."

        if automatic {
            statusMessage = "Diagnostic tone finished. If you heard it, \(routeDisplayName) is receiving app audio."
        }
    }

    func scrubEditingChanged(_ editing: Bool) {
        guard sourceMode == .filePlayback else {
            scrubProgress = 0
            return
        }

        isScrubbing = editing
        if !editing {
            engine.seek(toProgress: scrubProgress)
            currentTime = duration * scrubProgress
        }
    }

    func formattedCurrentTime() -> String {
        Self.timestamp(currentTime)
    }

    func formattedDuration() -> String {
        if sourceMode.isLiveInput, sourceMetadata != nil {
            return "LIVE"
        }
        return Self.timestamp(duration)
    }

    func currentTuning() -> SpatialTuning {
        SpatialTuning(
            preset: preset,
            frontAngle: frontAngle,
            rearAngle: rearAngle
        )
    }

    func selectRendererPreset(_ preset: RendererPreset) {
        applyRendererPreset(preset, markDirty: false)
        statusMessage = "Selected renderer preset \(preset.name)."
    }

    func setRendererRenderMode(_ nextMode: RendererRenderMode) {
        applyRendererModeRequest(nextMode, reason: "manual mode changed")
    }

    private func applyRendererModePolicyChange(reason: String) {
        applyRendererModeRequest(rendererRenderMode, reason: reason, persistRequestedMode: false)
    }

    private func applyRendererModeRequest(
        _ nextMode: RendererRenderMode,
        reason: String,
        persistRequestedMode: Bool = true
    ) {
        let nextScene = rendererScene(forRequestedMode: nextMode)
        guard rendererRenderMode != nextMode || rendererScene != nextScene else { return }

        let wasUsingDirectRendererAudio = shouldUseDirectRendererAudio(scene: rendererScene)
        let willUseDirectRendererAudio = shouldUseDirectRendererAudio(scene: nextScene)
        let changesActiveAudioGraph = wasUsingDirectRendererAudio || willUseDirectRendererAudio
        let shouldResumeFilePlayback = sourceMode == .filePlayback && isPlaying && changesActiveAudioGraph
        let shouldRestartLiveInput = sourceMode.isLiveInput && isPlaying && changesActiveAudioGraph
        let wasLiveMuted = liveMonitorState.isMuted
        let playbackProgress = duration > 0 ? currentTime / duration : scrubProgress

        if shouldResumeFilePlayback || shouldRestartLiveInput {
            engine.stop()
            isPlaying = false
            if shouldRestartLiveInput {
                liveMonitorState = .stopped
            }
        }

        rendererRenderMode = nextMode
        if persistRequestedMode {
            persistRendererRenderMode()
        }
        rendererScene = nextScene
        syncRendererAudioRouting()
        configureRendererMeters()
        statusMessage = rendererModeStatusMessage(requestedMode: nextMode)
        AppLogger.shared.notice(
            category: "renderer",
            "Renderer mode changed reason=\(reason) requested=\(nextMode.rawValue) effective=\(nextScene.requestedRenderMode.rawValue) resolved=\(nextScene.renderMode.rawValue)"
        )

        if shouldRestartLiveInput {
            startLiveInputForCurrentRoute(reason: "renderer mode changed", resetRendererMode: false)
            if wasLiveMuted {
                muteLiveMonitor()
            }
            return
        }

        if shouldResumeFilePlayback {
            do {
                engine.seek(toProgress: playbackProgress)
                guard prepareOutputForMusicPlayback() else { return }
                try engine.play()
                isPlaying = true
                statusMessage = "Playing through \(routeDisplayName) with \(rendererScene.renderMode.displayName)."
            } catch {
                AppLogger.shared.error(category: "ui", "Renderer mode resume failed: \(error.localizedDescription)")
                lastError = error.localizedDescription
            }
        }
    }

    func resetRendererTuning() {
        rendererPreset = rendererPreset.replacingOptions(.default)
        rendererPresetIsDirty = false
        UserDefaults.standard.removeObject(forKey: Self.rendererOptionsKey)
        syncRendererControlsFromPreset(rendererPreset)
        rendererPresetStatus = "FEY renderer tuning reset to defaults."
        refreshRendererScene()
        AppLogger.shared.notice(category: "renderer", "Renderer tuning reset to defaults.")
    }

    func saveRendererPreset() {
        do {
            _ = try rendererPresetStore.save(rendererPreset)
            rendererPresetIsDirty = false
            reloadRendererPresets(selectCurrent: true)
            rendererPresetStatus = "Saved \(rendererPreset.name) to JSON."
            AppLogger.shared.notice(
                category: "renderer",
                "Saved renderer preset id=\(rendererPreset.id) name=\(rendererPreset.name) path=\(rendererPresetStore.directoryURL.path)"
            )
        } catch {
            let message = "Renderer preset save failed: \(error.localizedDescription)"
            rendererPresetStatus = message
            lastError = message
            AppLogger.shared.error(category: "renderer", message)
        }
    }

    func reloadRendererPresets(selectCurrent: Bool = true) {
        do {
            let currentID = rendererPreset.id
            let presets = try rendererPresetStore.loadPresets()
            rendererPresets = presets
            rendererPresetDirectoryText = rendererPresetStore.directoryURL.path

            if selectCurrent, let match = presets.first(where: { $0.id == currentID }) {
                applyRendererPreset(match, markDirty: false)
            } else if !presets.contains(where: { $0.id == rendererPreset.id }), let first = presets.first {
                applyRendererPreset(first, markDirty: false)
            } else {
                refreshRendererScene()
            }

            rendererPresetStatus = "Loaded \(presets.count) renderer preset\(presets.count == 1 ? "" : "s")."
        } catch {
            rendererPresets = [.sonicSphere30Point1]
            applyRendererPreset(.sonicSphere30Point1, markDirty: false)
            rendererPresetStatus = "Using built-in preset because JSON presets could not load."
            AppLogger.shared.error(category: "renderer", "Renderer preset reload failed: \(error.localizedDescription)")
        }
    }

    func revealRendererPresetFolder() {
        do {
            try rendererPresetStore.ensureDirectoryAndDefaultPreset()
            NSWorkspace.shared.activateFileViewerSelecting([rendererPresetStore.directoryURL])
        } catch {
            let message = "Could not open renderer preset folder: \(error.localizedDescription)"
            rendererPresetStatus = message
            lastError = message
            AppLogger.shared.error(category: "renderer", message)
        }
    }

    var sourceFlowTitle: String {
        switch sourceMode {
        case .roon:
            return "Roon"
        case .spotify:
            return "Spotify"
        case .testTone:
            return "Test Tone"
        case .filePlayback:
            return sourceMetadata?.fileName ?? "Local Files"
        case .aux:
            return "Aux Cable"
        }
    }

    var sourceFlowDetail: String {
        if sourceMode == .roon {
            if let roonNowPlaying {
                return "\(roonNowPlaying.titleLine) • \(liveSignalStatus) • \(liveBufferStatus)"
            }
            return "\(liveSignalStatus) • \(liveBufferStatus)"
        }

        if sourceMode == .spotify {
            let routeText = inputRoute.isAvailable ? inputRoute.detail : missingLoopbackMessage(for: .spotify)
            let serverText = spotifySourceHealthLines.first(where: { $0.title == "Spotify Connect Server" })?.value ?? spotifyReceiverStatus.message
            return "\(routeText) • \(serverText) • \(liveSignalStatus)"
        }

        if sourceMode == .aux {
            let routeText = inputRoute.isAvailable ? inputRoute.detail : missingLoopbackMessage(for: .aux)
            return "\(routeText) • \(liveSignalStatus) • \(liveBufferStatus)"
        }

        if sourceMode == .testTone {
            return testToneStatus.isEmpty ? selectedTestTonePoint.rawValue : "\(selectedTestTonePoint.rawValue) • \(testToneStatus)"
        }

        guard let metadata = sourceMetadata else {
            return "Open a local surround file to inspect the source format."
        }

        return "\(metadata.layoutName) • \(metadata.codecName) • \(metadata.channelCount) ch • \(metadata.sampleRateText)"
    }

    var renderFlowTitle: String {
        if sourceMode == .testTone {
            return "Test tone -> selected renderer path"
        }

        guard let metadata = sourceMetadata else {
            return "Waiting For Render Input"
        }

        if sourceMode == .roon {
            return "\(metadata.layoutName) live -> binaural spatial render"
        }

        switch metadata.channelCount {
        case 1:
            return "Mono -> centered object render"
        case 2:
            return "Stereo -> widened headphone field"
        default:
            return "\(metadata.layoutName) -> binaural spatial fold-down"
        }
    }

    var renderFlowDetail: String {
        guard let metadata = sourceMetadata else {
            if sourceMode == .testTone {
                return "Synthetic source for monitor and renderer checks."
            }
            return sourceMode.isLiveInput ? liveInputReadinessText : "No source loaded."
        }

        let objectText = metadata.channelCount == 1
            ? "1 placed source"
            : "\(metadata.channelCount) placed sources"
        return sourceMode.isLiveInput ? "\(objectText) • live capture" : "\(objectText) • local player"
    }

    var routeFlowTitle: String {
        outputRoute.deviceName
    }

    var routeFlowDetail: String {
        outputRoute.routeDetail
    }

    var targetFlowTitle: String {
        outputRoute.targetName
    }

    var targetFlowDetail: String {
        outputRoute.targetDetail
    }

    var outputNowText: String {
        outputRoute.isAvailable ? "\(outputRoute.deviceName) • \(outputRoute.routeDetail)" : "No verified macOS output"
    }

    var monitorOutputNowText: String {
        outputText(for: monitorOutputRoute, noneText: "not set")
    }

    var rendererOutputNowText: String {
        outputText(for: rendererOutputRoute, noneText: "not set")
    }

    var monitorOutputSelectionText: String {
        outputSelectionText(
            selection: monitorOutputSelection,
            route: monitorOutputRoute,
            systemLabel: "System Default"
        )
    }

    var rendererOutputSelectionText: String {
        outputSelectionText(
            selection: rendererOutputSelection,
            route: rendererOutputRoute,
            systemLabel: "System Default"
        )
    }

    var systemOutputNowText: String {
        systemOutputRoute.isAvailable ? "\(systemOutputRoute.deviceName) • \(systemOutputRoute.routeDetail)" : "No verified system output"
    }

    var inputNowText: String {
        inputRoute.isAvailable ? "\(inputRoute.displayName) • \(inputRoute.detail)" : liveInputReadinessText
    }

    var systemInputNowText: String {
        systemInputRoute.isAvailable ? "\(systemInputRoute.displayName) • \(systemInputRoute.detail)" : "No verified macOS system input"
    }

    var roonZoneText: String {
        "Roon"
    }

    var liveInputReadinessText: String {
        if let expectedLoopback = sourceMode.expectedLoopback {
            return inputRoute.isAvailable
                ? "\(expectedLoopback.displayName) ready."
                : missingLoopbackMessage(for: sourceMode)
        }

        return inputRoute.roonReadiness
    }

    var selectedSourceDeviceStatusText: String {
        guard let expectedLoopback = sourceMode.expectedLoopback else {
            return sourceMetadata?.fileName ?? "No local file loaded."
        }

        if inputRoute.uid == expectedLoopback.deviceUID {
            return "\(expectedLoopback.displayName) • \(inputRoute.detail)"
        }

        return missingLoopbackMessage(for: sourceMode)
    }

    var spotifySourceHealthLines: [SpotifySourceHealthLine] {
        guard sourceMode == .spotify else { return [] }

        let deviceStatus: String
        if inputRoute.isSpotifyLoopback {
            deviceStatus = "Selected: \(inputRoute.deviceName)"
        } else if let route = availableInputRoutes.first(where: \.isSpotifyLoopback) {
            deviceStatus = "Available: \(route.deviceName)"
        } else {
            deviceStatus = "Orbisonic Spotify Input unavailable"
        }

        let serverStatus: String
        switch spotifyReceiverStatus.state {
        case .notStarted:
            serverStatus = "Unavailable"
        case .embeddedModuleUnavailable:
            serverStatus = "Unavailable"
        case .waitingForConnection:
            if let clientName = spotifyNowPlaying?.clientName?.trimmedNilIfBlank {
                serverStatus = "Connected to \(clientName)"
            } else {
                serverStatus = "Advertising as \(spotifyReceiverClient.configuration.receiverName)"
            }
        case .running:
            serverStatus = "Connected"
        case .restarting:
            serverStatus = "Restarting"
        case .failed:
            serverStatus = "Failed"
        }

        let streamRead: String
        if let metadata = sourceMetadata, inputRoute.isSpotifyLoopback {
            streamRead = "Connected: \(metadata.channelCount) channels, \(metadata.sampleRateText) \(metadata.layoutName.lowercased())"
        } else if inputRoute.isSpotifyLoopback, liveMonitorState.isCapturing || liveMonitorState.isMuted {
            streamRead = "Connected: \(activeLiveChannelCount) channels, \(formatSampleRate(inputRoute.nominalSampleRate)) stereo"
        } else {
            streamRead = "Waiting for stream"
        }

        let signal = lastLiveSignalPresent == true ? "Music detected" : "Silent"

        return [
            SpotifySourceHealthLine(title: "Device Status", value: deviceStatus),
            SpotifySourceHealthLine(title: "Spotify Connect Server", value: serverStatus),
            SpotifySourceHealthLine(title: "Stream Read", value: streamRead),
            SpotifySourceHealthLine(title: "Signal", value: signal)
        ]
    }

    var outputSafetyText: String {
        if rendererOutputSelection == .none {
            return "Renderer output is not set. Renderer VU remains active."
        }

        if DanteSafetyPolicy.requiresHighRateChannelWarning(
            outputChannelCount: rendererScene.outputSpeakers.count,
            sampleRate: rendererOutputRoute.nominalSampleRate
        ) {
            return "Dante Virtual Soundcard Pro supports only 16x16 channels at 176.4/192 kHz."
        }

        switch rendererOutputRoute.routeRisk {
        case .safe:
            if rendererOutputRoute.isRendererCapableOutput {
                return "Renderer output selected."
            }
            return "Renderer output selected."
        case .feedbackLoop(let name):
            return "Blocked: \(name) would feed Orbisonic back into an input loopback."
        case .virtualOutput(let name):
            return "Virtual output: verify \(name) is the intended renderer target."
        case .unavailable:
            return "No verified renderer output route."
        }
    }

    var availableLiveChannelCounts: [Int] {
        LiveChannelCountPolicy.availableCounts(
            sourceMode: sourceMode,
            availableInputChannels: inputRoute.inputChannelCount
        )
    }

    var rendererText: String {
        if rendererScene.isBypass {
            return "\(rendererScene.renderMode.statusName) • direct speaker playback"
        }

        guard rendererScene.matrix.inputCount > 0 else {
            if let message = rendererScene.validationMessages.last {
                return "\(rendererRenderMode.displayName) • \(message)"
            }
            return "\(rendererRenderMode.displayName) • waiting for source"
        }
        return "\(rendererScene.renderMode.statusName) • \(rendererScene.matrix.inputCount)x\(rendererScene.matrix.outputCount) matrix"
    }

    var rendererTargetText: String {
        rendererPreset.outputTopology.kind == .sonicSphere ? "Sonic Sphere" : "Sound System"
    }

    var rendererLayoutText: String {
        "\(rendererPreset.outputTopology.fullRangeCount).\(rendererPreset.outputTopology.lfeCount) Spatial"
    }

    var rendererSelectionText: String {
        "\(rendererTargetText) \(rendererLayoutText)"
    }

    var rendererLobeInspectionText: String {
        if rendererScene.isBypass {
            return "Direct speaker playback, renderer bypassed."
        }

        if rendererScene.renderMode.isAuroBed {
            return "Auro lower uses lower/mid FEY lobes • height uses upper lobes • T uses crown"
        }

        return "FL 5/6/11/17/22/28 • FR 2/7/13/18/24/29 • rear supports 9/20/26"
    }

    var rendererChannelOrderText: String {
        if rendererScene.isBypass {
            return rendererScene.renderMode == .direct31
                ? "0...30 direct to outputs 0...30"
                : "0...29 direct to outputs 0...29"
        }

        let renderer = FeyStaticBedRenderer(options: rendererPreset.options)
        let mode = rendererScene.renderMode == .automatic ? rendererRenderMode : rendererScene.renderMode
        return renderer.getInputLayout(layoutId: mode)?.summary ?? "Waiting for supported source"
    }

    var rendererMatrixInspectionText: String {
        if rendererScene.isBypass {
            return rendererScene.renderMode == .direct31 ? "31 direct channels" : "30 direct speaker channels"
        }

        guard rendererScene.matrix.inputCount > 0 else {
            return rendererScene.validationMessages.last ?? "Waiting for supported source"
        }

        let summary = (0..<min(rendererScene.matrix.inputCount, 4)).map { inputIndex in
            let labels = rendererScene.matrix
                .strongestOutputs(forInputAt: inputIndex, limit: 2)
                .map { "\($0.index + 1)" }
                .joined(separator: "/")
            return "In \(inputIndex + 1): \(labels)"
        }
        .joined(separator: " • ")

        return summary.isEmpty ? "No active matrix" : summary
    }

    var monitorOutputStatusText: String {
        return outputStatusText(
            for: monitorOutputRoute,
            selection: monitorOutputSelection,
            noneDetail: "local monitor disabled",
            safeDetail: monitorOutputRoute.isRendererCapableOutput ? "multichannel output" : "local monitor"
        )
    }

    var rendererOutputStatusText: String {
        if rendererOutputSelection == .none {
            return "not set • explicit renderer not selected"
        }

        if DanteSafetyPolicy.requiresHighRateChannelWarning(
            outputChannelCount: rendererScene.outputSpeakers.count,
            sampleRate: rendererOutputRoute.nominalSampleRate
        ) {
            return "Warning • 176.4/192 kHz limits high channel counts"
        }

        return outputStatusText(
            for: rendererOutputRoute,
            selection: rendererOutputSelection,
            noneDetail: "explicit renderer not selected",
            safeDetail: "renderer output selected"
        )
    }

    var rendererSceneOutputText: String {
        let target = "\(rendererTargetText) \(rendererPreset.outputTopology.fullRangeCount).\(rendererPreset.outputTopology.lfeCount)"
        if rendererScene.isBypass {
            return "\(target) • Direct speaker playback, renderer bypassed"
        }

        guard rendererScene.matrix.inputCount > 0 else {
            if let message = rendererScene.validationMessages.last {
                return "\(target) • \(message)"
            }
            return "\(target) • waiting for source"
        }

        return "\(target) • \(rendererScene.matrix.inputCount) -> \(rendererScene.matrix.outputCount) matrix"
    }

    private func outputText(for route: OutputRouteInfo, noneText: String) -> String {
        route.isAvailable ? "\(route.deviceName) • \(route.routeDetail)" : noneText
    }

    private func outputSelectionText(
        selection: OutputSelectionMode,
        route: OutputRouteInfo,
        systemLabel: String
    ) -> String {
        switch selection {
        case .none:
            return "not set"
        case .systemDefault:
            return route.isAvailable ? "\(systemLabel): \(route.deviceName)" : systemLabel
        case .device:
            return route.isAvailable ? route.deviceName : "Unavailable Device"
        }
    }

    private func outputStatusText(
        for route: OutputRouteInfo,
        selection: OutputSelectionMode,
        noneDetail: String,
        safeDetail: String
    ) -> String {
        if selection == .none {
            return "not set • \(noneDetail)"
        }

        guard route.isAvailable else {
            return "Unavailable • no verified route"
        }

        switch route.routeRisk {
        case .safe:
            return "Safe • \(safeDetail)"
        case .feedbackLoop(let name):
            return "Blocked • \(name) would feed back into Orbisonic"
        case .virtualOutput(let name):
            return "Warning • verify \(name) is the intended target"
        case .unavailable:
            return "Unavailable • no verified route"
        }
    }

    private var routeDisplayName: String {
        outputRoute.isAvailable ? outputRoute.deviceName : "the current macOS output"
    }

    private var liveInputSourceName: String {
        switch sourceMode {
        case .roon:
            return "Roon"
        case .spotify:
            return "Spotify"
        case .aux:
            return "Aux Cable"
        case .filePlayback:
            return "Local Files"
        case .testTone:
            return "Test Tone"
        }
    }

    private var liveInputSignalName: String {
        if sourceMode == .roon {
            return OrbisonicLoopbackDevice.roonInput.displayName
        }
        if sourceMode == .spotify {
            return OrbisonicLoopbackDevice.spotifyInput.displayName
        }
        if sourceMode == .aux {
            return OrbisonicLoopbackDevice.auxCable.displayName
        }
        return inputRoute.deviceName
    }

    private var roonLoopbackSampleRateMismatchText: String? {
        guard let roonRate = roonNowPlaying?.outputSampleRate, inputRoute.nominalSampleRate > 0 else {
            return nil
        }

        guard abs(roonRate - inputRoute.nominalSampleRate) > 1 else {
            return nil
        }

        return "Roon is streaming \(formatSampleRate(roonRate)) but \(liveInputSignalName) is \(formatSampleRate(inputRoute.nominalSampleRate)). Set the Roon output and Orbisonic loopback to the same rate, then restart monitoring."
    }

    private var roonLoopbackSampleRateMismatch: Double? {
        guard let roonRate = roonNowPlaying?.outputSampleRate,
              inputRoute.isRoonLoopback || inputRoute.isBlackHole,
              inputRoute.nominalSampleRate > 0,
              abs(roonRate - inputRoute.nominalSampleRate) > 1
        else { return nil }

        return roonRate
    }

    private func formatSampleRate(_ sampleRate: Double) -> String {
        let kilohertz = sampleRate / 1_000
        if abs(kilohertz.rounded() - kilohertz) < 0.01 {
            return "\(Int(kilohertz.rounded())) kHz"
        }

        return String(format: "%.1f kHz", kilohertz)
    }

    private func preferredLiveChannelCount() -> Int {
        LiveChannelCountPolicy.preferredCount(
            sourceMode: sourceMode,
            availableInputChannels: inputRoute.inputChannelCount,
            activeCount: activeLiveChannelCount
        )
    }

    @discardableResult
    private func selectExpectedLoopbackInputIfAvailable(for mode: SourceMode) -> Bool {
        guard let route = expectedLoopbackRoute(for: mode) else {
            return false
        }

        if inputRoute.deviceID != route.deviceID {
            inputRoute = route
            AppLogger.shared.notice(
                category: "route",
                "Selected expected source input source=\(mode.rawValue) device=\(route.deviceName) uid=\(route.uid)"
            )
        }

        applyLiveChannelDefaults(for: route)

        return true
    }

    private func expectedLoopbackRoute(for mode: SourceMode) -> InputRouteInfo? {
        guard let expectedLoopback = mode.expectedLoopback else { return nil }
        return availableInputRoutes.first { $0.uid == expectedLoopback.deviceUID }
    }

    private func missingLoopbackMessage(for mode: SourceMode) -> String {
        mode.missingLoopbackMessage()
    }

    private func inputSelectionBlockedMessage(for route: InputRouteInfo) -> String {
        guard let expectedLoopback = sourceMode.expectedLoopback else {
            return "\(sourceMode.rawValue) does not use \(route.deviceName) as a live input."
        }

        switch sourceMode {
        case .roon:
            return "Roon mode captures \(expectedLoopback.displayName) only."
        case .spotify:
            return "Spotify mode captures \(expectedLoopback.displayName) only. Aux Cable and Roon Input stay separate."
        case .aux:
            return "Aux Cable mode captures \(expectedLoopback.displayName) only."
        case .filePlayback, .testTone:
            return "\(sourceMode.rawValue) does not use a live input route."
        }
    }

    private var outputFeedbackMessage: String {
        outputFeedbackMessage(for: outputRoute, purpose: .renderer)
    }

    private func outputFeedbackMessage(for route: OutputRouteInfo, purpose: OutputPurpose) -> String {
        switch route.routeRisk {
        case .feedbackLoop(let name):
            return "Blocked: \(name) would feed Orbisonic output back into an input loopback. Choose a safe \(purpose.lowerTitle) output or leave it not set."
        case .virtualOutput(let name):
            return "Output is currently the virtual device \(name). Verify it is the intended \(purpose.lowerTitle) target."
        case .safe:
            return "Output route is safe."
        case .unavailable:
            return "No \(purpose.lowerTitle) output route is available."
        }
    }

    @discardableResult
    private func applyOutputRouteIfAvailable(
        _ route: OutputRouteInfo,
        purpose: OutputPurpose,
        label: String
    ) -> Bool {
        guard route.isAvailable else {
            statusMessage = "\(purpose.title) output not set."
            return false
        }

        guard route.isSelectableOutputTarget else {
            let message = outputFeedbackMessage(for: route, purpose: purpose)
            statusMessage = message
            lastError = message
            return false
        }

        if isPlaying || isTestTonePlaying || isDiagnosticSequencePlaying {
            stop()
        }

        do {
            try engine.setOutputDevice(route.deviceID)
            outputRoute = route
            configureMonitorMeters()
            syncRendererAudioRouting()
            statusMessage = "\(purpose.title) output set to \(label)."
            AppLogger.shared.notice(
                category: "route",
                "Selected \(purpose.lowerTitle) output label=\(label) device=\(route.deviceName) uid=\(route.uid) channels=\(route.outputChannelCount) sampleRate=\(formatSampleRate(route.nominalSampleRate))"
            )
            return true
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Could not select \(label) for \(purpose.lowerTitle)."
            AppLogger.shared.error(category: "route", "\(purpose.title) output selection failed: \(error.localizedDescription)")
            return false
        }
    }

    private func resolvedMonitorOutputRoute(
        from routes: [OutputRouteInfo],
        systemOutput: OutputRouteInfo
    ) -> OutputRouteInfo {
        OutputRouteSelectionPolicy.monitorRoute(
            from: routes,
            selection: monitorOutputSelection,
            systemOutput: systemOutput
        )
    }

    private func resolvedRendererOutputRoute(
        from routes: [OutputRouteInfo],
        systemOutput: OutputRouteInfo
    ) -> OutputRouteInfo {
        OutputRouteSelectionPolicy.rendererRoute(
            from: routes,
            selection: rendererOutputSelection,
            systemOutput: systemOutput
        )
    }

    private func refreshedActiveOutputRoute(from routes: [OutputRouteInfo]) -> OutputRouteInfo {
        if outputRoute.isAvailable,
           let refreshedRoute = routes.first(where: { $0.uid == outputRoute.uid || $0.deviceID == outputRoute.deviceID }) {
            return refreshedRoute
        }

        if rendererOutputRoute.isAvailable {
            return rendererOutputRoute
        }

        if monitorOutputRoute.isAvailable {
            return monitorOutputRoute
        }

        return .unavailable
    }

    @discardableResult
    private func prepareOutputForMusicPlayback() -> Bool {
        refreshRoutesIfNeeded(force: true)

        if rendererOutputSelection != .none {
            return ensureOutputForAction(.renderer)
        }

        if monitorOutputRoute.isAvailable {
            return applyOutputRouteIfAvailable(monitorOutputRoute, purpose: .monitor, label: monitorOutputRoute.deviceName)
        }

        let fallbackRoute = outputRoute.isAvailable ? outputRoute : systemOutputRoute
        if fallbackRoute.isAvailable {
            guard fallbackRoute.isSelectableOutputTarget else {
                let message = outputFeedbackMessage(for: fallbackRoute, purpose: .renderer)
                statusMessage = message
                lastError = message
                AppLogger.shared.error(category: "route", message)
                return false
            }

            outputRoute = fallbackRoute
            syncRendererAudioRouting()
            return true
        }

        AppLogger.shared.notice(
            category: "route",
            "Music playback starting without an explicit renderer output; using the current AVAudioEngine output route."
        )
        return true
    }

    @discardableResult
    private func ensureOutputForAction(_ purpose: OutputPurpose) -> Bool {
        refreshRoutesIfNeeded(force: true)

        let selection = purpose == .monitor ? monitorOutputSelection : rendererOutputSelection
        if selection == .none {
            let message = "Select a \(purpose.lowerTitle) output before starting this action."
            statusMessage = message
            lastError = message
            AppLogger.shared.error(category: "route", message)
            return false
        }

        let route = purpose == .monitor ? monitorOutputRoute : rendererOutputRoute
        guard route.isAvailable else {
            let message = "No \(purpose.lowerTitle) output route is available."
            statusMessage = message
            lastError = message
            AppLogger.shared.error(category: "route", message)
            return false
        }

        return applyOutputRouteIfAvailable(route, purpose: purpose, label: route.deviceName)
    }

    private func resolvedSelectedInputRoute(
        from routes: [InputRouteInfo],
        systemInput: InputRouteInfo
    ) -> InputRouteInfo {
        if let expectedLoopback = sourceMode.expectedLoopback,
           let sourceRoute = routes.first(where: { $0.uid == expectedLoopback.deviceUID }) {
            return sourceRoute
        }

        if let selectedInputDeviceUID,
           let persistedRoute = routes.first(where: { $0.uid == selectedInputDeviceUID }) {
            return persistedRoute
        }

        if inputRoute.isAvailable,
           let existingRoute = routes.first(where: { $0.uid == inputRoute.uid || $0.deviceID == inputRoute.deviceID }) {
            return existingRoute
        }

        if systemInput.isAvailable,
           let route = routes.first(where: { $0.uid == systemInput.uid || $0.deviceID == systemInput.deviceID }) {
            return route
        }

        return routes.first ?? .unavailable
    }

    private func applyLiveChannelDefaults(for route: InputRouteInfo) {
        activeLiveChannelCount = LiveChannelCountPolicy.preferredCount(
            sourceMode: sourceMode,
            availableInputChannels: route.inputChannelCount,
            activeCount: activeLiveChannelCount
        )
    }

    private func handlePlaybackEnded() {
        if playNextLocalMusicTrackAfterNaturalEnd() {
            return
        }

        isPlaying = false
        meterStore.reset()
        monitorMeterStore.reset()
        rendererMeterStore.reset()
        reevaluateAutomaticRendererMode(reason: "playback ended")
        statusMessage = "Playback finished."
    }

    private func playNextLocalMusicTrackAfterNaturalEnd() -> Bool {
        guard sourceMode == .filePlayback else { return false }

        if let sessionQueueIndex, sessionQueue.indices.contains(sessionQueueIndex + 1) {
            return playQueueIndex(sessionQueueIndex + 1)
        }

        guard let currentID = currentFileURL?.path else { return false }
        let tracks = visibleLocalMusicTracks
        guard let currentIndex = tracks.firstIndex(where: { $0.id == currentID }),
              tracks.indices.contains(currentIndex + 1)
        else {
            return false
        }

        startSessionQueue(from: tracks, startTrackID: tracks[currentIndex + 1].id, shuffle: false, autoplay: true)
        return true
    }

    private func localMusicComparator(lhs: LocalMusicTrack, rhs: LocalMusicTrack) -> Bool {
        switch localMusicSortMode {
        case .name:
            return compareLocalMusic(lhs, rhs, primary: \.sortName, secondary: \.sortArtist, tertiary: \.sortAlbum)
        case .artist:
            return compareLocalMusic(lhs, rhs, primary: \.sortArtist, secondary: \.sortAlbum, tertiary: \.sortName)
        case .album:
            return compareLocalMusic(lhs, rhs, primary: \.sortAlbum, secondary: \.sortArtist, tertiary: \.sortName)
        }
    }

    private func compareLocalMusic(
        _ lhs: LocalMusicTrack,
        _ rhs: LocalMusicTrack,
        primary: KeyPath<LocalMusicTrack, String>,
        secondary: KeyPath<LocalMusicTrack, String>,
        tertiary: KeyPath<LocalMusicTrack, String>
    ) -> Bool {
        for keyPath in [primary, secondary, tertiary] {
            let lhsValue = lhs[keyPath: keyPath]
            let rhsValue = rhs[keyPath: keyPath]
            let lhsBlank = lhsValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let rhsBlank = rhsValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if lhsBlank != rhsBlank {
                return !lhsBlank
            }
            let comparison = lhsValue.localizedStandardCompare(rhsValue)
            if comparison == .orderedAscending { return true }
            if comparison == .orderedDescending { return false }
        }

        return lhs.fileName.localizedStandardCompare(rhs.fileName) == .orderedAscending
    }

    private func refreshTransport() {
        refreshRoutesIfNeeded()

        if sourceMode == .roon {
            refreshRoonNowPlayingIfNeeded()
            refreshRoonBridgeIfNeeded()
            repairBlackHoleSampleRateIfNeeded()
        }

        if sourceMode == .spotify {
            refreshSpotifyNowPlayingIfNeeded()
        }

        let engineDuration = engine.duration()
        if abs(engineDuration - duration) >= 0.001 {
            duration = engineDuration
        }

        if sourceMode.isLiveInput, isPlaying {
            let nextTime = engine.currentTime()
            if abs(nextTime - currentTime) >= (1.0 / 30.0) {
                currentTime = nextTime
            }

            let levels = engine.channelMeterLevels()
            let audibleLevels = liveMonitorState.isMuted ? [] : levels
            meterStore.update(with: levels)
            updateMonitorMeters(from: audibleLevels)
            updateRendererMeters(from: audibleLevels)

            let wholeSecond = Int(nextTime.rounded(.down))
            updateLiveBufferStatus(elapsedSecond: wholeSecond)

            let peak = levels.max() ?? 0
            updateLiveSignalStatus(peak: peak, elapsedSecond: wholeSecond)

            if wholeSecond >= 0, wholeSecond != lastLiveMeterLogSecond, wholeSecond % 2 == 0 {
                lastLiveMeterLogSecond = wholeSecond
                let levelText = levels
                    .prefix(8)
                    .map { String(format: "%.2f", $0) }
                    .joined(separator: ",")
                AppLogger.shared.debug(
                    category: "live-input",
                    "Live meter time=\(formattedCurrentTime()) peak=\(String(format: "%.2f", peak)) levels=[\(levelText)] output=\(outputRoute.deviceName)"
                )
            }
            return
        }

        guard engineDuration > 0, isPlaying else { return }

        if !isScrubbing {
            let nextTime = engine.currentTime()
            let nextProgress = engineDuration > 0 ? nextTime / engineDuration : 0

            if abs(nextTime - currentTime) >= (1.0 / 30.0) {
                currentTime = nextTime
            }

            if abs(nextProgress - scrubProgress) >= 0.003 {
                scrubProgress = nextProgress
            }

            let wholeSecond = Int(nextTime.rounded(.down))
            if wholeSecond >= 0, wholeSecond != lastHeartbeatSecond, wholeSecond % 2 == 0 {
                lastHeartbeatSecond = wholeSecond
                AppLogger.shared.debug(
                    category: "transport",
                    "Heartbeat time=\(formattedCurrentTime()) / \(formattedDuration()) progress=\(String(format: "%.3f", nextProgress)) playing=\(isPlaying)"
                )
            }
        }

        let levels = engine.channelMeterLevels()
        meterStore.update(with: levels)
        updateMonitorMeters(from: levels)
        updateRendererMeters(from: levels)
    }

    private func refreshRoutesIfNeeded(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastRouteRefreshTime) >= 1.0 else { return }
        lastRouteRefreshTime = now

        let nextSystemOutputRoute = OutputRouteMonitor.currentRoute()
        if nextSystemOutputRoute != systemOutputRoute {
            systemOutputRoute = nextSystemOutputRoute
            AppLogger.shared.notice(
                category: "route",
                "System output route changed device=\(nextSystemOutputRoute.deviceName) transport=\(nextSystemOutputRoute.transportName) channels=\(nextSystemOutputRoute.outputChannelCount) target=\(nextSystemOutputRoute.targetName)"
            )
        }

        let nextAvailableOutputRoutes = OutputRouteMonitor.availableOutputRoutes()
        if nextAvailableOutputRoutes != availableOutputRoutes {
            availableOutputRoutes = nextAvailableOutputRoutes
            let outputNames = nextAvailableOutputRoutes.map(\.deviceName).joined(separator: ", ")
            AppLogger.shared.notice(
                category: "route",
                "Available output routes changed count=\(nextAvailableOutputRoutes.count) devices=[\(outputNames)]"
            )
        }

        let nextMonitorOutputRoute = resolvedMonitorOutputRoute(
            from: nextAvailableOutputRoutes,
            systemOutput: nextSystemOutputRoute
        )
        if nextMonitorOutputRoute != monitorOutputRoute {
            monitorOutputRoute = nextMonitorOutputRoute
            configureMonitorMeters()
            AppLogger.shared.notice(
                category: "route",
                "Monitor output route changed device=\(nextMonitorOutputRoute.deviceName) transport=\(nextMonitorOutputRoute.transportName) channels=\(nextMonitorOutputRoute.outputChannelCount) target=\(nextMonitorOutputRoute.targetName)"
            )
        }

        let nextRendererOutputRoute = resolvedRendererOutputRoute(
            from: nextAvailableOutputRoutes,
            systemOutput: nextSystemOutputRoute
        )
        if nextRendererOutputRoute != rendererOutputRoute {
            rendererOutputRoute = nextRendererOutputRoute
            configureMonitorMeters()
            configureRendererMeters()
            syncRendererAudioRouting()
            AppLogger.shared.notice(
                category: "route",
                "Renderer output route changed device=\(nextRendererOutputRoute.deviceName) transport=\(nextRendererOutputRoute.transportName) channels=\(nextRendererOutputRoute.outputChannelCount) target=\(nextRendererOutputRoute.targetName)"
            )
        }

        let refreshedActiveRoute = refreshedActiveOutputRoute(from: nextAvailableOutputRoutes)
        if refreshedActiveRoute != outputRoute {
            outputRoute = refreshedActiveRoute
            configureMonitorMeters()

            if refreshedActiveRoute.isAvailable, !isPlaying, !isTestTonePlaying, !isDiagnosticSequencePlaying {
                do {
                    try engine.setOutputDevice(refreshedActiveRoute.deviceID)
                } catch {
                    AppLogger.shared.warning(category: "route", "Could not apply refreshed output device: \(error.localizedDescription)")
                }
            }

            AppLogger.shared.notice(
                category: "route",
                "Active output route changed device=\(refreshedActiveRoute.deviceName) transport=\(refreshedActiveRoute.transportName) channels=\(refreshedActiveRoute.outputChannelCount) target=\(refreshedActiveRoute.targetName)"
            )

            if isPlaying {
                statusMessage = "Playing through \(routeDisplayName)."
            } else if let metadata = sourceMetadata {
                statusMessage = "Loaded \(metadata.fileName). Current route: \(routeDisplayName)."
            } else if rendererOutputRoute.isAvailable {
                statusMessage = "Load a surround file. Current renderer output: \(rendererOutputRoute.deviceName)."
            } else if monitorOutputRoute.isAvailable {
                statusMessage = "Load a surround file. Current monitor output: \(monitorOutputRoute.deviceName)."
            } else {
                statusMessage = "Load a surround file. Monitor and renderer outputs are not set."
            }
        }

        let nextAvailableInputRoutes = OutputRouteMonitor.availableInputRoutes()
        if nextAvailableInputRoutes != availableInputRoutes {
            availableInputRoutes = nextAvailableInputRoutes
            let inputNames = nextAvailableInputRoutes.map(\.deviceName).joined(separator: ", ")
            AppLogger.shared.notice(
                category: "route",
                "Available Orbisonic input routes changed count=\(nextAvailableInputRoutes.count) devices=[\(inputNames)]"
            )
        }

        let nextSystemInputRoute = OutputRouteMonitor.currentInputRoute()
        if nextSystemInputRoute != systemInputRoute {
            systemInputRoute = nextSystemInputRoute
            AppLogger.shared.notice(
                category: "route",
                "System input route changed device=\(nextSystemInputRoute.deviceName) transport=\(nextSystemInputRoute.transportName) channels=\(nextSystemInputRoute.inputChannelCount) sampleRate=\(formatSampleRate(nextSystemInputRoute.nominalSampleRate)) blackHole=\(nextSystemInputRoute.isBlackHole)"
            )
        }

        let nextInputRoute = resolvedSelectedInputRoute(
            from: nextAvailableInputRoutes,
            systemInput: nextSystemInputRoute
        )
        if nextInputRoute != inputRoute {
            let previousInputRoute = inputRoute
            inputRoute = nextInputRoute
            applyLiveChannelDefaults(for: nextInputRoute)
            AppLogger.shared.notice(
                category: "route",
                "Orbisonic input route changed device=\(nextInputRoute.deviceName) transport=\(nextInputRoute.transportName) channels=\(nextInputRoute.inputChannelCount) sampleRate=\(formatSampleRate(nextInputRoute.nominalSampleRate)) blackHole=\(nextInputRoute.isBlackHole)"
            )

            if sourceMode == .spotify, nextInputRoute.isSpotifyLoopback {
                refreshSpotifyConnectServerIfNeeded(reason: "spotify input route changed")
            }

            if sourceMode.isLiveInput, isPlaying, previousInputRoute.deviceID != nextInputRoute.deviceID {
                if !sourceMode.acceptsInputRoute(nextInputRoute) {
                    stop()
                    statusMessage = "Live input stopped because \(sourceMode.expectedLoopback?.displayName ?? "the selected Orbisonic input") is unavailable."
                } else if nextInputRoute.isAvailable {
                    startLiveInputForCurrentRoute(reason: "selected input route changed")
                } else {
                    stop()
                    statusMessage = "Live input stopped because the selected Orbisonic input is unavailable."
                }
            }
        }

        if sourceMode.isLiveInput, isPlaying, outputRoute.routeRisk.blocksLiveMonitoring {
            stop()
            let message = "Live input stopped because macOS output changed to a loopback input. Set output to a monitor or renderer target, then start the route again."
            AppLogger.shared.error(category: "route", message)
            statusMessage = message
            lastError = message
        }
    }

    private func publishTuning() {
        engine.updateTuning(currentTuning())
    }

    private func loadRendererPresets() {
        reloadRendererPresets(selectCurrent: false)
    }

    private func restorePersistedRendererOptions() {
        guard let data = UserDefaults.standard.data(forKey: Self.rendererOptionsKey),
              let options = try? JSONDecoder().decode(FeyRendererOptions.self, from: data)
        else { return }

        rendererPreset = rendererPreset.replacingOptions(options.clamped)
        syncRendererControlsFromPreset(rendererPreset)
        refreshRendererScene()
        rendererPresetIsDirty = true
        rendererPresetStatus = "Loaded persisted FEY renderer tuning."
        AppLogger.shared.notice(category: "renderer", "Loaded persisted renderer tuning from UserDefaults.")
    }

    private func applyRendererPreset(_ preset: RendererPreset, markDirty: Bool) {
        rendererPreset = preset.normalizedForCurrentSchema
        rendererPresetIsDirty = markDirty
        syncRendererControlsFromPreset(rendererPreset)
        refreshRendererScene()
    }

    private func syncRendererControlsFromPreset(_ preset: RendererPreset) {
        suppressRendererPublish = true
        rendererSeamSupportGain = preset.options.seamSupportGain
        rendererUpperBiasDbPerUnitZ = preset.options.upperBiasDbPerUnitZ
        rendererStereoRearFill = preset.options.stereoRearFill
        rendererCenterSideSupportGain = preset.options.centerSideSupportGain
        rendererAdjacentBleed = preset.options.adjacentBleed
        rendererMaxSingleSpeakerPowerShare = preset.options.maxSingleSpeakerPowerShare
        rendererRenderedOutputTrimDb = preset.options.renderedMainTrimDb
        rendererLfeTrimDb = preset.options.lfeTrimDb
        rendererAuroLowerUpperBiasDbPerUnitZ = preset.options.defaultUpperBiasDbPerUnitZ
        rendererAuroHeightUpperBiasDbPerUnitZ = preset.options.heightUpperBiasDbPerUnitZ
        rendererAuroHeightMaxSingleSpeakerPowerShare = preset.options.heightMaxSingleSpeakerPowerShare
        rendererAuroTopMaxSingleSpeakerPowerShare = preset.options.topMaxSingleSpeakerPowerShare
        rendererFiveOneChannelOrder = preset.options.fiveOneChannelOrder
        suppressRendererPublish = false
    }

    private func publishRendererOptions() {
        guard !suppressRendererPublish else { return }

        let options = FeyRendererOptions(
            coreGain: rendererPreset.options.coreGain,
            seamSupportGain: rendererSeamSupportGain,
            upperBiasDbPerUnitZ: rendererUpperBiasDbPerUnitZ,
            stereoRearFill: rendererStereoRearFill,
            centerSideSupportGain: rendererCenterSideSupportGain,
            adjacentBleed: rendererAdjacentBleed,
            maxSingleSpeakerPowerShare: rendererMaxSingleSpeakerPowerShare,
            renderedOutputTrimDb: rendererRenderedOutputTrimDb,
            directOutputTrimDb: rendererPreset.options.directOutputTrimDb,
            fiveOneChannelOrder: rendererFiveOneChannelOrder,
            renderedMainTrimDb: rendererRenderedOutputTrimDb,
            lfeTrimDb: rendererLfeTrimDb,
            defaultMaxSingleSpeakerPowerShare: rendererMaxSingleSpeakerPowerShare,
            heightMaxSingleSpeakerPowerShare: rendererAuroHeightMaxSingleSpeakerPowerShare,
            topMaxSingleSpeakerPowerShare: rendererAuroTopMaxSingleSpeakerPowerShare,
            defaultUpperBiasDbPerUnitZ: rendererAuroLowerUpperBiasDbPerUnitZ,
            heightUpperBiasDbPerUnitZ: rendererAuroHeightUpperBiasDbPerUnitZ
        ).clamped

        rendererPreset = rendererPreset.replacingOptions(options)
        rendererPresetIsDirty = true
        rendererPresetStatus = "FEY renderer tuning changed."
        persistRendererOptions(options)
        syncRendererControlsFromPreset(rendererPreset)
        refreshRendererScene()
    }

    private func persistRendererOptions(_ options: FeyRendererOptions) {
        if let data = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(data, forKey: Self.rendererOptionsKey)
        }
        AppLogger.shared.info(
            category: "renderer",
            "Renderer tuning persisted seam=\(String(format: "%.3f", options.seamSupportGain)) upperBias=\(String(format: "%.3f", options.upperBiasDbPerUnitZ)) rearFill=\(String(format: "%.3f", options.stereoRearFill)) trim=\(String(format: "%.3f", options.renderedOutputTrimDb))"
        )
    }

    private func refreshRendererScene() {
        rendererScene = rendererScene(forRequestedMode: rendererRenderMode)
        syncRendererAudioRouting()
        configureMonitorMeters()
        configureRendererMeters()
    }

    private func rendererScene(forRequestedMode requestedMode: RendererRenderMode) -> RendererSceneModel {
        RendererMatrixBuilder.sceneModel(
            for: currentRendererLayout,
            preset: rendererPreset,
            renderMode: effectiveRendererRenderMode(forRequestedMode: requestedMode)
        )
    }

    private func effectiveRendererRenderMode(forRequestedMode requestedMode: RendererRenderMode) -> RendererRenderMode {
        RendererModePolicy.effectiveRequestedMode(
            requestedMode: requestedMode,
            inputChannelCount: currentRendererLayout?.channelCount,
            alwaysMono: rendererAlwaysMono,
            twoChannelPreference: rendererTwoChannelPreference
        )
    }

    private func rendererModeStatusMessage(requestedMode: RendererRenderMode) -> String {
        if let message = rendererScene.validationMessages.last,
           rendererScene.renderMode != rendererScene.requestedRenderMode {
            return message
        }

        if rendererAlwaysMono {
            return "Renderer mode set to Always Mono. Using \(rendererScene.renderMode.displayName)."
        }

        if requestedMode == .automatic,
           currentRendererLayout?.channelCount == 2,
           rendererTwoChannelPreference != .automatic {
            return "Renderer Auto uses \(rendererTwoChannelPreference.displayName) for two-channel sources."
        }

        return "Renderer mode set to \(requestedMode.displayName)."
    }

    private func resetRendererRequestToAutomatic(reason: String) {
        guard rendererRenderMode != .automatic else {
            refreshRendererScene()
            return
        }

        rendererRenderMode = .automatic
        persistRendererRenderMode()
        refreshRendererScene()
        AppLogger.shared.info(category: "renderer", "Renderer request reset to Auto reason=\(reason)")
    }

    private func reevaluateAutomaticRendererMode(reason: String) {
        refreshRendererScene()
        if rendererRenderMode == .automatic {
            AppLogger.shared.info(
                category: "renderer",
                "Re-evaluated automatic renderer mode reason=\(reason) resolved=\(rendererScene.renderMode.rawValue) inputChannels=\(rendererScene.matrix.inputCount)"
            )
        }
    }

    private var shouldUseDirectRendererAudio: Bool {
        shouldUseDirectRendererAudio(scene: rendererScene)
    }

    private func shouldUseDirectRendererAudio(scene: RendererSceneModel) -> Bool {
        RendererAudioRoutingPolicy.usesDirectRendererAudio(
            renderMode: scene.renderMode,
            activeOutputRoute: outputRoute,
            rendererOutputRoute: rendererOutputRoute,
            requiredOutputChannelCount: rendererOutputChannelRequirement(for: scene)
        )
    }

    private var rendererOutputChannelRequirement: Int {
        rendererOutputChannelRequirement(for: rendererScene)
    }

    private func rendererOutputChannelRequirement(for scene: RendererSceneModel) -> Int {
        if scene.renderMode == .direct30 {
            return FeyStaticBedRenderer.fullRangeOutputs
        }

        if scene.matrix.outputCount > 0 {
            return scene.matrix.outputCount
        }

        return rendererPreset.outputTopology.fullRangeCount + rendererPreset.outputTopology.lfeCount
    }

    private func syncRendererAudioRouting() {
        engine.updateRenderer(
            mode: rendererScene.renderMode,
            scene: rendererScene,
            directRendererAudioEnabled: shouldUseDirectRendererAudio
        )
    }

    private func configureMonitorMeters() {
        monitorMeterStore.configureIfNeeded(channels: SurroundLayoutDetector.fallbackLayout(for: monitorChannelWalkCount).channels)
    }

    private func updateMonitorMeters(from _: [Float]) {
        let levels = engine.monitorMeterLevels()
        let channelCount = monitorChannelWalkCount
        let paddedLevels = padded(levels, count: channelCount)
        monitorMeterStore.configureIfNeeded(channels: SurroundLayoutDetector.fallbackLayout(for: channelCount).channels)
        monitorMeterStore.update(with: paddedLevels)
    }

    private func configureRendererMeters() {
        rendererMeterStore.configureIfNeeded(channels: rendererMeterChannels())
    }

    private func updateRendererMeters(from sourceLevels: [Float]) {
        let channels = rendererMeterChannels()
        guard !channels.isEmpty else { return }

        updateRenderedMeterStore(
            rendererMeterStore,
            channels: channels,
            scene: rendererScene,
            sourceLevels: sourceLevels
        )
    }

    private func updateRenderedMeterStore(
        _ store: ChannelMeterStore,
        channels: [SurroundChannel],
        scene: RendererSceneModel,
        sourceLevels: [Float]
    ) {
        store.configureIfNeeded(channels: channels)

        store.update(with: RendererMeterDisplayModel.levels(for: scene, sourceLevels: sourceLevels))
    }

    private func rendererMeterChannels() -> [SurroundChannel] {
        rendererMeterChannels(for: rendererScene)
    }

    private func rendererMeterChannels(for scene: RendererSceneModel) -> [SurroundChannel] {
        RendererMeterDisplayModel.channels(for: scene)
    }

    private func padded(_ levels: [Float], count: Int) -> [Float] {
        guard count > 0 else { return [] }
        if levels.count == count { return levels }
        if levels.count > count { return Array(levels.prefix(count)) }
        return levels + Array(repeating: 0, count: count - levels.count)
    }

    private func activeLevel(index: Int, count: Int) -> [Float] {
        guard count > 0 else { return [] }
        return (0..<count).map { $0 == index ? 0.86 : 0 }
    }

    private var currentRendererLayout: SurroundLayout? {
        guard !loadedChannels.isEmpty else { return nil }
        return SurroundLayout(
            name: sourceMetadata?.layoutName ?? "\(loadedChannels.count)-Channel Input",
            channels: loadedChannels
        )
    }

    private func updateLiveBufferStatus(elapsedSecond: Int) {
        guard let bufferStatus = engine.liveInputStatus() else {
            liveBufferStatus = "No live buffer."
            return
        }

        liveBufferStatus = bufferStatus.displayText(sampleRate: sourceMetadata?.sampleRate ?? inputRoute.nominalSampleRate)

        guard elapsedSecond >= 0,
              elapsedSecond != lastLiveBufferLogSecond,
              elapsedSecond % 2 == 0
        else { return }

        lastLiveBufferLogSecond = elapsedSecond
        AppLogger.shared.debug(
            category: "live-input",
            "Live buffer \(liveBufferStatus) underflows=\(bufferStatus.underflowCount) underflowFrames=\(bufferStatus.underflowFrames) droppedFrames=\(bufferStatus.overflowDropFrames)"
        )
    }

    private func updateLiveSignalStatus(peak: Float, elapsedSecond: Int) {
        let signalPresent = peak >= 0.005

        if signalPresent {
            liveSignalStatus = "Signal present from \(liveInputSignalName)."
            if !liveMonitorState.isMuted {
                liveMonitorState = .monitoring
            }
            if lastLiveSignalPresent != true && !liveMonitorState.isMuted {
                statusMessage = "Live signal detected from \(liveInputSignalName); rendering to \(routeDisplayName)."
                AppLogger.shared.notice(
                    category: "live-input",
                    "Live signal detected peak=\(String(format: "%.2f", peak)) input=\(inputRoute.deviceName) output=\(outputRoute.deviceName)"
                )
            }
            lastLiveSignalPresent = true
            return
        }

        if elapsedSecond < 3 {
            liveSignalStatus = "Waiting for signal from \(liveInputSignalName)."
            return
        }

        if sourceMode == .roon, let mismatchText = roonLoopbackSampleRateMismatchText {
            liveSignalStatus = "\(liveInputSignalName) is silent. \(mismatchText)"
        } else if sourceMode == .roon, roonNowPlaying?.state.caseInsensitiveCompare("PAUSED") == .orderedSame {
            liveSignalStatus = "\(liveInputSignalName) is silent because Roon is paused."
        } else if sourceMode == .roon {
            liveSignalStatus = "\(liveInputSignalName) is silent. Select Orbisonic Roon Input in Roon and start playback."
        } else if sourceMode == .spotify {
            liveSignalStatus = "\(liveInputSignalName) is silent. Start Spotify playback and select Orbisonic Spotify in Spotify Connect."
        } else {
            liveSignalStatus = "\(liveInputSignalName) is silent. Start the source or route it to Orbisonic Aux Cable."
        }

        if !liveMonitorState.isMuted {
            liveMonitorState = .silent
        }

        if lastLiveSignalPresent != false {
            statusMessage = liveSignalStatus
            lastLiveSignalPresent = false
        }

        if elapsedSecond != lastLiveSilenceWarningSecond, elapsedSecond % 5 == 0 {
            lastLiveSilenceWarningSecond = elapsedSecond
            AppLogger.shared.warning(
                category: "live-input",
                "Selected input is silent elapsed=\(elapsedSecond)s peak=\(String(format: "%.2f", peak)) input=\(inputRoute.deviceName) inputRate=\(formatSampleRate(inputRoute.nominalSampleRate)) roonRate=\(roonNowPlaying?.outputSampleRate.map(formatSampleRate) ?? "unknown") output=\(outputRoute.deviceName)"
            )
        }
    }

    private func repairBlackHoleSampleRateIfNeeded(force: Bool = false) {
        guard sourceMode == .roon,
              inputRoute.isBlackHole,
              let targetSampleRate = roonLoopbackSampleRateMismatch
        else { return }

        let now = Date()
        guard force || now.timeIntervalSince(lastLegacyLoopbackSampleRateRepairTime) >= 8 else {
            return
        }

        lastLegacyLoopbackSampleRateRepairTime = now
        let wasPlaying = isPlaying
        if wasPlaying {
            engine.stop()
            isPlaying = false
        }

        let changed = BlackHoleRouteRepair.prepareInputDeviceForCapture(
            inputRoute,
            preferredSampleRate: targetSampleRate
        )
        refreshRoutesIfNeeded(force: true)

        if changed {
            statusMessage = "Aligned BlackHole to \(formatSampleRate(targetSampleRate)); restarting the Roon pipe."
        } else {
            statusMessage = "Legacy loopback is \(formatSampleRate(inputRoute.nominalSampleRate)) while Roon is \(formatSampleRate(targetSampleRate)). Set the loopback to \(formatSampleRate(targetSampleRate)) in Audio MIDI Setup if capture stays silent."
        }

        if wasPlaying {
            startLiveInputForCurrentRoute(reason: "BlackHole sample-rate alignment")
        }
    }

    private func refreshRoonNowPlayingIfNeeded(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastRoonNowPlayingRefreshTime) >= Self.roonLogRefreshInterval else { return }
        guard !isRoonLogRefreshInFlight else { return }
        lastRoonNowPlayingRefreshTime = now

        guard sourceMode == .roon else { return }
        isRoonLogRefreshInFlight = true
        let reader = roonNowPlayingReader

        Task { @MainActor [weak self] in
            let snapshot = await Task.detached(priority: .utility) {
                reader.readLatestSnapshot()
            }.value

            guard let self else { return }
            defer { isRoonLogRefreshInFlight = false }
            guard sourceMode == .roon else { return }

            applyRoonLogSnapshot(snapshot)
        }
    }

    private func applyRoonLogSnapshot(_ snapshot: RoonLogSnapshot?) {
        guard let snapshot else {
            roonNowPlayingStatus = roonBridgeSnapshot.isReadyForTransport
                ? "Roon connected. Signal-path log has not updated yet."
                : "No Roon playback line found in RoonServer log yet."
            return
        }

        if let next = snapshot.nowPlaying {
            if next != roonNowPlaying {
                roonNowPlaying = next
                AppLogger.shared.notice(
                    category: "roon-metadata",
                    "Now playing zone=\(next.zoneName) state=\(next.state) title=\(next.titleLine) format=\(next.qualityFormat) progress=\(next.positionText)/\(next.durationText)"
                )
            }

            roonNowPlayingStatus = next.updatedText
        } else if roonBridgeSnapshot.isReadyForTransport {
            roonNowPlayingStatus = "Roon connected. Waiting for signal-path log details."
        } else {
            roonNowPlayingStatus = "No Roon playback line found in RoonServer log yet."
        }

        guard let signalPath = snapshot.signalPath, signalPath != roonSignalPath else {
            return
        }

        roonSignalPath = signalPath
        let level: AppLogLevel = signalPath.isDownmixingToStereo ? .warning : .notice
        AppLogger.shared.log(
            level,
            category: "roon-metadata",
            "Signal path sourceChannels=\(signalPath.sourceChannelText) sourceFormat=\(signalPath.sourceFormat) channelMapping=\(signalPath.channelMapping) device=\(signalPath.device) output=\(signalPath.output)"
        )

        if signalPath.isDownmixingToStereo {
            statusMessage = "Roon is downmixing quad to stereo before BlackHole. Change the BlackHole zone channel layout in Roon."
        }
    }

    private func refreshRoonBridgeIfNeeded(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastRoonBridgeRefreshTime) >= Self.roonBridgeRefreshInterval else { return }
        guard !isRoonBridgeRefreshInFlight else { return }
        lastRoonBridgeRefreshTime = now
        isRoonBridgeRefreshInFlight = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isRoonBridgeRefreshInFlight = false }

            do {
                let snapshot = try await roonBridgeClient.refreshStartingIfNeeded()
                applyRoonBridgeSnapshot(snapshot)
            } catch {
                applyRoonBridgeError(error)
            }
        }
    }

    private func refreshSpotifyNowPlayingIfNeeded(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastSpotifyNowPlayingRefreshTime) >= Self.spotifyNowPlayingRefreshInterval else { return }
        lastSpotifyNowPlayingRefreshTime = now

        let next = spotifyReceiverClient.readNowPlaying()
        if next != spotifyNowPlaying {
            spotifyNowPlaying = next
        }

        if sourceMode == .spotify, next == nil, spotifyReceiverStatus.isRunning {
            refreshSpotifyConnectServerIfNeeded(reason: "stale now playing")
        }
    }

    private func refreshSpotifyConnectServerIfNeeded(reason: String, force: Bool = false) {
        guard sourceMode == .spotify else { return }

        let now = Date()
        guard force || now.timeIntervalSince(lastSpotifyConnectRefreshTime) >= Self.spotifyConnectRestartDebounce else { return }
        lastSpotifyConnectRefreshTime = now

        if spotifyReceiverStatus.isRunning || force {
            spotifyReceiverStatus = SpotifyReceiverStatus(
                state: .restarting,
                message: "Spotify Connect server is restarting."
            )
            spotifyReceiverClient.stop()
        }

        spotifyReceiverStatus = spotifyReceiverClient.start()
        AppLogger.shared.notice(
            category: "spotify-receiver",
            "Refreshed Spotify Connect server reason=\(reason) state=\(spotifyReceiverStatus.state.rawValue)"
        )
    }

    func toggleSpotifyTransport() {
        sendSpotifyControl(.playPause)
    }

    func playPreviousSpotifyTrack() {
        sendSpotifyControl(.previous)
    }

    func playNextSpotifyTrack() {
        sendSpotifyControl(.next)
    }

    func seekSpotifyBy(seconds delta: Int) {
        guard let nowPlaying = spotifyNowPlaying,
              let current = nowPlaying.positionMs
        else { return }

        let duration = nowPlaying.durationMs ?? current
        let next = UInt32(min(max(Int(current) + delta * 1_000, 0), Int(duration)))
        sendSpotifyControl(.seek(positionMs: next))
    }

    private func sendSpotifyControl(_ control: SpotifyReceiverControl) {
        guard sourceMode == .spotify else { return }
        if spotifyReceiverClient.send(control) {
            refreshSpotifyNowPlayingIfNeeded(force: true)
            statusMessage = "Sent Spotify Connect control."
        } else {
            statusMessage = "Spotify Connect control is not available in this build or the receiver is not active."
            refreshSpotifyConnectServerIfNeeded(reason: "control failed", force: true)
        }
    }

    private func sendRoonTransport(_ control: RoonBridgeControl) {
        guard sourceMode == .roon else { return }
        guard !isRoonTransportCommandInFlight else { return }
        isRoonTransportCommandInFlight = true
        statusMessage = "Sending \(control.rawValue) to Roon..."

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isRoonTransportCommandInFlight = false }

            do {
                let response = try await roonBridgeClient.sendStartingIfNeeded(control)
                if let snapshot = response.state {
                    applyRoonBridgeSnapshot(snapshot)
                } else {
                    refreshRoonBridgeIfNeeded(force: true)
                }
                statusMessage = response.message ?? "Sent \(control.rawValue) to Roon."
                AppLogger.shared.notice(category: "roon-bridge", "Sent transport control=\(control.rawValue)")
            } catch {
                applyRoonBridgeError(error)
                statusMessage = error.localizedDescription
                lastError = error.localizedDescription
                AppLogger.shared.error(category: "roon-bridge", "Transport control failed control=\(control.rawValue) error=\(error.localizedDescription)")
            }
        }
    }

    private func applyRoonBridgeSnapshot(_ snapshot: RoonBridgeSnapshot) {
        if snapshot != roonBridgeSnapshot {
            roonBridgeSnapshot = snapshot
            let logStatus = [
                snapshot.bridge.state,
                snapshot.selectedZoneId ?? "no-zone",
                snapshot.statusText,
                snapshot.selectedZone?.titleText ?? ""
            ].joined(separator: "|")

            if logStatus != lastLoggedRoonBridgeStatus {
                lastLoggedRoonBridgeStatus = logStatus
                AppLogger.shared.notice(
                    category: "roon-bridge",
                    "State=\(snapshot.bridge.state) status=\(snapshot.statusText)"
                )
            }
        }
    }

    private func applyRoonBridgeError(_ error: Error) {
        let bridgeState: String
        if case RoonBridgeClientError.missingDependencies = error {
            bridgeState = "missing_dependencies"
        } else if case RoonBridgeClientError.missingNodeRuntime = error {
            bridgeState = "missing_node"
        } else {
            bridgeState = "offline"
        }

        let snapshot = RoonBridgeSnapshot(
            ok: false,
            updatedAt: nil,
            bridge: RoonBridgeInfo(
                state: bridgeState,
                message: error.localizedDescription,
                zoneHint: "Orbisonic Roon Input"
            ),
            core: nil,
            selectedZoneId: nil,
            selectedZone: nil,
            zones: []
        )

        if snapshot != roonBridgeSnapshot {
            roonBridgeSnapshot = snapshot
            AppLogger.shared.warning(category: "roon-bridge", error.localizedDescription)
        }
    }

    private func applyPreset(_ preset: SpatialPreset, pushToEngine: Bool = true) {
        let defaults = preset.defaults
        suppressTuningPublish = true
        frontAngle = defaults.frontAngle
        rearAngle = defaults.rearAngle
        suppressTuningPublish = false

        if pushToEngine {
            publishTuning()
        }
    }

    private static func timestamp(_ value: TimeInterval) -> String {
        let totalSeconds = max(Int(value.rounded(.down)), 0)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

}

private extension SpatialPreset {
    static let defaultPreset: SpatialPreset = .immersiveWrap
}
