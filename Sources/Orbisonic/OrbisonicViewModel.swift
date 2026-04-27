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

private struct LocalFileQueueCommit {
    let index: Int
    let trackID: String
    let isNaturalAdvance: Bool
}

private enum LocalFileLoadStartPolicy {
    case immediate
    case debounced
}

private enum LocalFileLoadKind {
    case startingPlayback
    case selectedTrack
    case nextTrack
    case previousTrack
    case naturalAdvance

    func immediateStatus(trackTitle: String?, fileName: String) -> String {
        switch self {
        case .startingPlayback:
            return "Starting playback..."
        case .selectedTrack:
            return "Loading selected track: \(trackTitle ?? fileName)..."
        case .nextTrack:
            return "Loading next track: \(trackTitle ?? fileName)..."
        case .previousTrack:
            return "Loading previous track: \(trackTitle ?? fileName)..."
        case .naturalAdvance:
            return "Loading next track: \(trackTitle ?? fileName)..."
        }
    }

    func subtleStatus(trackTitle: String?, fileName: String) -> String {
        switch self {
        case .startingPlayback:
            return "Preparing local playback..."
        case .selectedTrack:
            return "Loading selected track..."
        case .nextTrack:
            return "Loading next track..."
        case .previousTrack:
            return "Loading previous track..."
        case .naturalAdvance:
            return "Loading next track..."
        }
    }

    func clearStatus(trackTitle: String?, fileName: String) -> String {
        "Loading large audio file: \(trackTitle ?? fileName)..."
    }

    var stillLoadingStatus: String {
        "Still loading. You can press Stop to cancel."
    }
}

private struct LocalFileLoadRequest {
    let id: UInt64
    let generation: UInt64
    let url: URL
    let autoplay: Bool
    let queueCommit: LocalFileQueueCommit?
    let kind: LocalFileLoadKind
    let startPolicy: LocalFileLoadStartPolicy
    let debugTiming: DebugTimingContext?
    let requestedFromSource: SourceMode
    let isLocalPlayNow: Bool
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
            "Output 1 Monitor Channel Walk"
        case .renderer:
            "Output 2 Renderer Channel Walk"
        }
    }

    var shortTitle: String {
        switch self {
        case .monitor:
            "Output 1 Monitor"
        case .renderer:
            "Output 2 Renderer"
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
            "Output 1 Monitor"
        case .renderer:
            "Output 2 Renderer"
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
    private static let spotifyPlaybackStatusDebounceNanoseconds: UInt64 = 300_000_000
    private static let spotifyConnectRestartDebounce: TimeInterval = 8.0
    private static let localTransportDebounceNanoseconds: UInt64 = 120_000_000
    private static let localLoadSubtleStatusNanoseconds: UInt64 = 150_000_000
    private static let localLoadClearStatusNanoseconds: UInt64 = 700_000_000
    private static let localLoadStillLoadingNanoseconds: UInt64 = 5_000_000_000
    private static let webControlTokenKey = "Orbisonic.webControlToken"
    private static let localMusicSortModeKey = "Orbisonic.localMusicSortMode"
    private static let rendererOptionsKey = "Orbisonic.rendererOptions"
    private static let frontAngleKey = "Orbisonic.frontAngle"
    private static let rearAngleKey = "Orbisonic.rearAngle"
    private static let sphereOutputVolumeKey = "Orbisonic.sphereOutputVolumePercent"
    private static let sphereOutputSafetyLimitKey = "Orbisonic.sphereOutputSafetyLimitPercent"
    private static let diagnosticSpeakerChannelCount = 31
    private static let sourceRampDownDuration: TimeInterval = 0.04
    private static let sourcePrimeDuration: TimeInterval = 0.08
    private static let sourceRampUpDuration: TimeInterval = 0.08
    private static let localPlayNowSourceSwitchTimeout: TimeInterval = 2.0
    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            NSClassFromString("XCTest.XCTestCase") != nil
    }

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
    @Published private(set) var roonArtworkURL: URL?
    @Published private(set) var spotifyReceiverStatus: SpotifyReceiverStatus = .notStarted
    @Published private(set) var spotifyNowPlaying: SpotifyNowPlaying?
    @Published private(set) var spotifyVisibleNowPlaying: SpotifyNowPlaying?
    @Published private(set) var localMusicSettings = LocalMusicSettings()
    @Published private(set) var localMusicTracks: [LocalMusicTrack] = []
    @Published private(set) var localMusicPlaylists: [LocalMusicPlaylist] = []
    @Published var selectedLibraryTrackID: String?
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
    @Published private(set) var pendingSessionQueueIndex: Int?
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
    @Published private(set) var sourceSwitchTargetMode: SourceMode?
    @Published private(set) var isLocalFileLoading = false

    let meterStore = ChannelMeterStore()
    let monitorMeterStore = ChannelMeterStore()
    let rendererMeterStore = ChannelMeterStore()

    private let engine = OrbisonicEngine()
    private let localAudioLoader: @Sendable (URL, DebugTimingContext?) throws -> LoadedAudioFile
    private let localMusicLibrary = LocalMusicLibrary()
    private let rendererPresetStore = RendererPresetStore()
    private let roonNowPlayingReader = RoonNowPlayingReader()
    private let roonBridgeClient = RoonBridgeClient()
    private let roonArtworkCache = RoonArtworkCache()
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
    private var sourceSwitchTask: Task<Void, Never>?
    private var sourceSwitchRequests = SourceSwitchRequestState()
    private var transitionOutputGain: Float = 1
    private var diagnosticReturnContext: DiagnosticReturnContext?
    private var rendererDiagnosticsUsingMonitorPreview = false
    private var rendererDiagnosticsMonitorDownmixAvailable = false
    private var localMusicScanTask: Task<Void, Never>?
    private var localPlayNowTask: Task<Void, Never>?
    private var localPlayNowSequence: UInt64 = 0
    private var localFileLoadTask: Task<Void, Never>?
    private var localFileLoadDebounceTask: Task<Void, Never>?
    private var localFileLoadStatusTask: Task<Void, Never>?
    private var spotifyPlaybackStatusDebounceTask: Task<Void, Never>?
    private var localFileLoadSequence: UInt64 = 0
    private var currentLocalFileLoadGeneration: UInt64 = 0
    private var activeLocalFileLoadRequest: LocalFileLoadRequest?
    private var queuedLocalFileLoadRequest: LocalFileLoadRequest?
    private var readyQueuedLocalFileLoadGeneration: UInt64?
    private var pendingSourceSwitchTiming: DebugTimingContext?
    private var pendingSourceSwitchReason: String?
    private var pendingSourceSwitchRequestedBy: String?
    private var mainActorHeartbeatTask: Task<Void, Never>?
    private var lastRouteRefreshTime = Date.distantPast
    private var lastRoonNowPlayingRefreshTime = Date.distantPast
    private var lastRoonBridgeRefreshTime = Date.distantPast
    private var lastSpotifyNowPlayingRefreshTime = Date.distantPast
    private var lastSpotifyConnectRefreshTime = Date.distantPast
    private var lastLegacyLoopbackSampleRateRepairTime = Date.distantPast
    private var isRoonLogRefreshInFlight = false
    private var isRoonBridgeRefreshInFlight = false
    private var lastLoggedRoonBridgeStatus: String?
    private var roonArtworkFetchTask: Task<Void, Never>?
    private var roonArtworkRequestedKey: String?
    private var roonArtworkFailedKeys: Set<String> = []
    private var lastLoggedRoonArtworkMissingSignature: String?
    private var lastLoggedSpotifyStatusSignature: String?
    private var selectedInputDeviceUID = UserDefaults.standard.string(forKey: OrbisonicViewModel.selectedInputDeviceUIDKey)
    private var monitorOutputSelection = OrbisonicViewModel.loadMonitorOutputSelection()
    private var rendererOutputSelection = OrbisonicViewModel.loadRendererOutputSelection()
    private var suppressTuningPublish = false
    private var suppressRendererPublish = false

    init() {
        self.localAudioLoader = { url, debugTiming in
            try AudioFileLoader().load(url: url, debugTiming: debugTiming)
        }
        finishInitialization()
    }

    init(localAudioLoader: @escaping @Sendable (URL) throws -> LoadedAudioFile) {
        self.localAudioLoader = { url, _ in
            try localAudioLoader(url)
        }
        finishInitialization()
    }

    private func finishInitialization() {
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
        startPersistentHelperServices(reason: "app launch", force: true)

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.refreshTransport()
            }
        }
        timer.tolerance = 1.0 / 120.0
        refreshTimer = timer
        startMainActorResponsivenessHeartbeat()
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
        localPlayNowTask?.cancel()
        localFileLoadTask?.cancel()
        localFileLoadDebounceTask?.cancel()
        localFileLoadStatusTask?.cancel()
        roonArtworkFetchTask?.cancel()
        spotifyPlaybackStatusDebounceTask?.cancel()
        sourceSwitchTask?.cancel()
        mainActorHeartbeatTask?.cancel()
        webServer?.stop()
        roonBridgeClient.stop()
        spotifyReceiverClient.stop()
        refreshTimer?.invalidate()
    }

    private func startMainActorResponsivenessHeartbeat() {
        #if DEBUG
        mainActorHeartbeatTask?.cancel()
        mainActorHeartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 50_000_000)
                } catch {
                    return
                }

                guard self != nil else { return }
                let scheduled = DispatchTime.now().uptimeNanoseconds
                await MainActor.run { [weak self] in
                    guard self != nil else { return }
                    let delayMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - scheduled) / 1_000_000.0
                    if delayMilliseconds > 100 {
                        let context = DebugTimingLog.makeCommand(prefix: "main-actor", sourceMode: self?.sourceMode)
                        context.log(
                            "Main actor delayed by \(String(format: "%.1f", delayMilliseconds)) ms",
                            sourceMode: self?.sourceMode,
                            sessionQueueIndex: self?.sessionQueueIndex,
                            selectedSessionQueueIndex: self?.selectedSessionQueueIndex,
                            pendingSessionQueueIndex: self?.pendingSessionQueueIndex,
                            extra: ["delayMs=\(String(format: "%.1f", delayMilliseconds))"]
                        )
                    }
                }
            }
        }
        #endif
    }

    func refreshWebPageURLs() {
        let urls = OrbisonicWebServer.urlSet(controlToken: webControlToken)
        webPublicPageURL = urls.publicURL
        webControlPageURL = ""
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
        let effective = Float(effectiveSphereOutputVolumePercent / 100.0) * transitionOutputGain
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
        statusMessage = "Updated local web access."
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
            "Output 1 Monitor: \(monitorOutputSelectionText) | \(monitorOutputNowText) | \(monitorOutputStatusText)",
            "Output 2 Renderer: \(rendererOutputSelectionText) | \(rendererOutputNowText) | \(rendererOutputStatusText)",
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

    private func debugTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    private func debugQuote(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "'").replacingOccurrences(of: "\n", with: " "))\""
    }

    private func liveMonitorDebugState() -> String {
        switch liveMonitorState {
        case .stopped:
            return "stopped"
        case .monitoring:
            return "monitoring"
        case .muted:
            return "muted"
        case .silent:
            return "silent"
        case .unavailable(let message):
            return "unavailable:\(message)"
        case .error(let message):
            return "error:\(message)"
        }
    }

    func debugPlaybackStateSnapshot() -> String {
        [
            "source=\(sourceMode.rawValue)",
            "playing=\(isPlaying)",
            "localLoading=\(isLocalFileLoading)",
            "liveMonitor=\(liveMonitorDebugState())",
            "file=\(currentFileURL.map { redactedPath($0.path) } ?? "-")",
            "queueIndex=\(sessionQueueIndex.map(String.init) ?? "-")",
            "pendingQueueIndex=\(pendingSessionQueueIndex.map(String.init) ?? "-")",
            "roonPlaying=\(isRoonTransportPlaying)",
            "spotifyPlaying=\(spotifyNowPlaying?.isPlaying.description ?? "-")",
            "spotifyVisiblePlaying=\(spotifyVisibleNowPlaying?.isPlaying.description ?? "-")"
        ].joined(separator: ",")
    }

    func logTransportDebug(
        source: SourceMode? = nil,
        command: String,
        allowed: Bool,
        handler: String,
        stateBefore: String,
        stateAfter: String? = nil,
        error: String? = nil
    ) {
        let activeSource = source ?? sourceMode
        let fields = [
            "source=\(debugQuote(activeSource.rawValue))",
            "command=\(debugQuote(command))",
            "allowed=\(allowed)",
            "handler=\(debugQuote(handler))",
            "stateBefore=\(debugQuote(stateBefore))",
            "stateAfter=\(debugQuote(stateAfter ?? debugPlaybackStateSnapshot()))",
            "error=\(debugQuote(error ?? ""))"
        ]
        AppLogger.shared.debug(category: "transport", "[transport] \(fields.joined(separator: " "))")
    }

    private func logSourceSwitchDebug(
        _ event: String,
        context: DebugTimingContext?,
        from previousSource: SourceMode,
        to nextSource: SourceMode,
        reason: String,
        requestedBy: String,
        completedAt: Date? = nil,
        success: Bool? = nil,
        error: String? = nil
    ) {
        let startedAt = context?.enabled == true ? context?.startedAt ?? Date() : Date()
        let fields = [
            "event=\(debugQuote(event))",
            "id=\(debugQuote(context?.enabled == true ? context?.id ?? "" : ""))",
            "from=\(debugQuote(previousSource.rawValue))",
            "to=\(debugQuote(nextSource.rawValue))",
            "reason=\(debugQuote(reason))",
            "requestedBy=\(debugQuote(requestedBy))",
            "startedAt=\(debugQuote(debugTimestamp(startedAt)))",
            "completedAt=\(debugQuote(completedAt.map(debugTimestamp) ?? ""))",
            "success=\(success.map { $0 ? "true" : "false" } ?? "pending")",
            "error=\(debugQuote(error ?? ""))"
        ]
        AppLogger.shared.debug(category: "source", "[source-switch] \(fields.joined(separator: " "))")
    }

    private func logLocalPlayNowDebug(
        _ event: String,
        selectedTrack: LocalMusicTrack?,
        previousSource: SourceMode,
        sourceSwitchRequired: Bool,
        sourceSwitchStarted: Bool = false,
        sourceSwitchSuccess: Bool = false,
        loadStarted: Bool = false,
        loadCompleted: Bool = false,
        playStarted: Bool = false,
        finalState: String? = nil,
        error: String? = nil
    ) {
        let fields = [
            "event=\(debugQuote(event))",
            "selectedTrack=\(debugQuote(selectedTrack?.displayTitle ?? ""))",
            "previousSource=\(debugQuote(previousSource.rawValue))",
            "sourceSwitchRequired=\(sourceSwitchRequired)",
            "sourceSwitchStarted=\(sourceSwitchStarted)",
            "sourceSwitchSuccess=\(sourceSwitchSuccess)",
            "loadStarted=\(loadStarted)",
            "loadCompleted=\(loadCompleted)",
            "playStarted=\(playStarted)",
            "finalState=\(debugQuote(finalState ?? debugPlaybackStateSnapshot()))",
            "error=\(debugQuote(error ?? ""))"
        ]
        AppLogger.shared.debug(category: "local-music", "[local-play-now] \(fields.joined(separator: " "))")
    }

    private func logLocalPlayNowDebug(
        _ event: String,
        request: LocalFileLoadRequest,
        loadStarted: Bool = false,
        loadCompleted: Bool = false,
        playStarted: Bool = false,
        finalState: String? = nil,
        error: String? = nil
    ) {
        guard request.isLocalPlayNow else { return }
        logLocalPlayNowDebug(
            event,
            selectedTrack: request.queueCommit.flatMap { queueTrack(for: $0.index) },
            previousSource: request.requestedFromSource,
            sourceSwitchRequired: request.requestedFromSource != .filePlayback,
            loadStarted: loadStarted,
            loadCompleted: loadCompleted,
            playStarted: playStarted,
            finalState: finalState,
            error: error
        )
    }

    private func spotifyDebugStateText(_ state: SpotifyNowPlaying?) -> String {
        guard let state else { return "nil" }
        return [
            "playing=\(state.isPlaying)",
            "position=\(state.positionMs.map(String.init) ?? "-")",
            "duration=\(state.durationMs.map(String.init) ?? "-")",
            "updatedAt=\(state.updatedAt ?? "-")"
        ].joined(separator: ",")
    }

    private func logSpotifyStatusDebug(
        rawState: SpotifyNowPlaying?,
        debouncedState: SpotifyNowPlaying?,
        reasonForUpdate: String
    ) {
        let rawStateText = spotifyDebugStateText(rawState)
        let debouncedStateText = spotifyDebugStateText(debouncedState)

        let trackText = rawState.map { "\($0.displayTitle) - \($0.artistText)" } ?? ""
        let signature = [
            rawStateText,
            debouncedStateText,
            trackText,
            sourceMode.rawValue,
            reasonForUpdate
        ].joined(separator: "|")
        guard signature != lastLoggedSpotifyStatusSignature else { return }
        lastLoggedSpotifyStatusSignature = signature

        let fields = [
            "rawState=\(debugQuote(rawStateText))",
            "debouncedState=\(debugQuote(debouncedStateText))",
            "track=\(debugQuote(trackText))",
            "timestamp=\(debugQuote(debugTimestamp(Date())))",
            "activeSource=\(debugQuote(sourceMode.rawValue))",
            "reasonForUpdate=\(debugQuote(reasonForUpdate))"
        ]
        AppLogger.shared.debug(category: "spotify-status", "[spotify-status] \(fields.joined(separator: " "))")
    }

    private func logOutputRoutingDebug(
        output: String,
        previousDevice: String,
        newDevice: String,
        playbackStateBefore: String,
        graphRebuild: Bool,
        playbackStateAfter: String? = nil,
        error: String? = nil
    ) {
        let fields = [
            "output=\(debugQuote(output))",
            "previousDevice=\(debugQuote(previousDevice))",
            "newDevice=\(debugQuote(newDevice))",
            "activeSource=\(debugQuote(sourceMode.rawValue))",
            "playbackStateBefore=\(debugQuote(playbackStateBefore))",
            "graphRebuild=\(graphRebuild)",
            "playbackStateAfter=\(debugQuote(playbackStateAfter ?? debugPlaybackStateSnapshot()))",
            "error=\(debugQuote(error ?? ""))"
        ]
        AppLogger.shared.debug(category: "route", "[output-routing] \(fields.joined(separator: " "))")
    }

    private func logLocalTransportTiming(
        _ context: DebugTimingContext?,
        _ event: String,
        targetQueueIndex: Int? = nil,
        track: LocalMusicTrack? = nil,
        fileURL: URL? = nil,
        extra: [String] = []
    ) {
        context?.log(
            event,
            sourceMode: sourceMode,
            sessionQueueIndex: sessionQueueIndex,
            selectedSessionQueueIndex: selectedSessionQueueIndex,
            pendingSessionQueueIndex: pendingSessionQueueIndex,
            targetQueueIndex: targetQueueIndex,
            trackTitle: track?.displayTitle,
            fileURL: fileURL ?? track?.url,
            extra: extra
        )
    }

    private func logSourceSwitchTiming(
        _ context: DebugTimingContext?,
        _ event: String,
        previousSource: SourceMode? = nil,
        nextSource: SourceMode? = nil,
        extra: [String] = []
    ) {
        var fields = extra
        if let previousSource {
            fields.append("previousSource=\"\(previousSource.rawValue)\"")
        }
        if let nextSource {
            fields.append("nextSource=\"\(nextSource.rawValue)\"")
        }
        context?.log(
            event,
            sourceMode: sourceMode,
            sessionQueueIndex: sessionQueueIndex,
            selectedSessionQueueIndex: selectedSessionQueueIndex,
            pendingSessionQueueIndex: pendingSessionQueueIndex,
            extra: fields
        )
    }

    var sourceSwitchStatusText: String? {
        sourceSwitchTargetMode.map(sourceSwitchDisplayText(for:))
    }

    private func sourceSwitchDisplayText(for mode: SourceMode) -> String {
        mode == .off ? "Stopping audio..." : "Switching to \(mode.rawValue)..."
    }

    func selectSourceMode(
        _ mode: SourceMode,
        reason: String = "source selected",
        requestedBy: String = "desktop"
    ) {
        let debugTiming = DebugTimingLog.makeCommand(prefix: "source-switch", sourceMode: sourceMode)
        let previousSource = sourceMode
        logSourceSwitchDebug(
            "requested",
            context: debugTiming,
            from: previousSource,
            to: mode,
            reason: reason,
            requestedBy: requestedBy
        )
        logSourceSwitchTiming(
            debugTiming,
            "source switch command received",
            previousSource: previousSource,
            nextSource: mode
        )

        if mode == sourceMode,
           !isLiveMonitorTransitioning,
           !sourceSwitchRequests.isProcessing {
            if mode.startsLiveListeningOnSelection, !isPlaying {
                requestSourceTransition(to: mode, debugTiming: debugTiming, reason: reason, requestedBy: requestedBy)
                return
            }
            logSourceSwitchDebug(
                "completed",
                context: debugTiming,
                from: previousSource,
                to: mode,
                reason: reason,
                requestedBy: requestedBy,
                completedAt: Date(),
                success: true,
                error: "already selected"
            )
            return
        }

        requestSourceTransition(to: mode, debugTiming: debugTiming, reason: reason, requestedBy: requestedBy)
    }

    private func requestSourceTransition(
        to mode: SourceMode,
        debugTiming: DebugTimingContext?,
        reason: String,
        requestedBy: String
    ) {
        let shouldStart = sourceSwitchRequests.request(mode)
        pendingSourceSwitchTiming = debugTiming
        pendingSourceSwitchReason = reason
        pendingSourceSwitchRequestedBy = requestedBy
        sourceSwitchTargetMode = mode
        isLiveMonitorTransitioning = true
        statusMessage = sourceSwitchDisplayText(for: mode)
        logSourceSwitchTiming(
            debugTiming,
            "pending target set",
            previousSource: sourceMode,
            nextSource: mode,
            extra: ["shouldStart=\(shouldStart)"]
        )
        logSourceSwitchTiming(
            debugTiming,
            "UI switching state published",
            previousSource: sourceMode,
            nextSource: mode,
            extra: ["status=\"\(statusMessage)\""]
        )
        guard shouldStart else { return }

        sourceSwitchTask = Task { @MainActor [weak self] in
            await self?.processPendingSourceTransitions()
        }
    }

    private func processPendingSourceTransitions() async {
        isLiveMonitorTransitioning = true
        logSourceSwitchTiming(
            pendingSourceSwitchTiming,
            "UI switching state published",
            nextSource: sourceSwitchRequests.pendingMode
        )
        await Task.yield()
        defer {
            sourceSwitchRequests.reset()
            sourceSwitchTask = nil
            isLiveMonitorTransitioning = false
            sourceSwitchTargetMode = nil
            transitionOutputGain = 1
            applyEffectiveOutputVolume(log: false)
        }

        while !Task.isCancelled, let requestedMode = sourceSwitchRequests.takeNext() {
            let debugTiming = pendingSourceSwitchTiming
            let reason = pendingSourceSwitchReason ?? "source selected"
            let requestedBy = pendingSourceSwitchRequestedBy ?? "unknown"
            pendingSourceSwitchTiming = nil
            pendingSourceSwitchReason = nil
            pendingSourceSwitchRequestedBy = nil
            await performSourceTransition(
                to: requestedMode,
                debugTiming: debugTiming,
                reason: reason,
                requestedBy: requestedBy
            )
        }
    }

    private func performSourceTransition(
        to requestedMode: SourceMode,
        debugTiming: DebugTimingContext?,
        reason: String,
        requestedBy: String
    ) async {
        var mode = requestedMode
        sourceSwitchTargetMode = mode
        statusMessage = sourceSwitchDisplayText(for: mode)
        let originalSource = sourceMode
        logSourceSwitchDebug(
            "started",
            context: debugTiming,
            from: originalSource,
            to: mode,
            reason: reason,
            requestedBy: requestedBy
        )
        logSourceSwitchTiming(
            debugTiming,
            "source switch command type",
            previousSource: originalSource,
            nextSource: mode,
            extra: ["command=\"source-switch\""]
        )
        AppLogger.shared.notice(category: "source", "Switching source from \(sourceMode.rawValue) to \(mode.rawValue)")

        logSourceSwitchTiming(debugTiming, "output ramp down start", previousSource: sourceMode, nextSource: mode)
        await rampTransitionOutput(to: 0, duration: Self.sourceRampDownDuration)
        logSourceSwitchTiming(debugTiming, "output ramp down end", previousSource: sourceMode, nextSource: mode)
        guard !Task.isCancelled else {
            logSourceSwitchDebug(
                "completed",
                context: debugTiming,
                from: originalSource,
                to: mode,
                reason: reason,
                requestedBy: requestedBy,
                completedAt: Date(),
                success: false,
                error: "task canceled"
            )
            return
        }

        mode = sourceSwitchRequests.coalescePending(over: mode)
        if let nextDebugTiming = pendingSourceSwitchTiming {
            logSourceSwitchTiming(
                debugTiming,
                "stale source switch discarded",
                previousSource: sourceMode,
                nextSource: mode,
                extra: ["reason=\"coalesced source switch superseded by \(nextDebugTiming.id)\""]
            )
        }
        let activeDebugTiming = pendingSourceSwitchTiming ?? debugTiming
        pendingSourceSwitchTiming = nil
        sourceSwitchTargetMode = mode
        statusMessage = sourceSwitchDisplayText(for: mode)

        if mode == sourceMode, !(mode.startsLiveListeningOnSelection && !isPlaying) {
            logSourceSwitchTiming(activeDebugTiming, "output ramp up start", previousSource: sourceMode, nextSource: mode)
            let didRampUp = await rampTransitionOutput(to: 1, duration: Self.sourceRampUpDuration, abortIfNewSourceSwitchPending: true)
            guard didRampUp else {
                logSourceSwitchTiming(
                    activeDebugTiming,
                    "stale source switch discarded",
                    previousSource: sourceMode,
                    nextSource: mode,
                    extra: ["reason=\"newer source requested during ramp up\""]
                )
                logSourceSwitchDebug(
                    "completed",
                    context: activeDebugTiming,
                    from: originalSource,
                    to: mode,
                    reason: reason,
                    requestedBy: requestedBy,
                    completedAt: Date(),
                    success: false,
                    error: "newer source requested during ramp up"
                )
                return
            }
            logSourceSwitchTiming(activeDebugTiming, "output ramp up end", previousSource: sourceMode, nextSource: mode)
            logSourceSwitchTiming(activeDebugTiming, "source switch complete", previousSource: sourceMode, nextSource: mode)
            logSourceSwitchDebug(
                "completed",
                context: activeDebugTiming,
                from: originalSource,
                to: mode,
                reason: reason,
                requestedBy: requestedBy,
                completedAt: Date(),
                success: true
            )
            return
        }

        logSourceSwitchTiming(activeDebugTiming, "old source detach/stop start", previousSource: sourceMode, nextSource: mode)
        if sourceMode.stopsLiveCaptureWhenSwitching(to: mode) {
            stopLiveMonitorForSourceSwitch(to: mode)
        } else if isPlaying || isTestTonePlaying || isDiagnosticSequencePlaying {
            stop()
        }
        if mode != .filePlayback {
            cancelPendingLocalFileLoad()
        }
        logSourceSwitchTiming(activeDebugTiming, "old source detach/stop end", previousSource: sourceMode, nextSource: mode)

        logSourceSwitchTiming(activeDebugTiming, "new source prepare/select start", previousSource: sourceMode, nextSource: mode)
        applySourceModeState(mode)
        logSourceSwitchTiming(activeDebugTiming, "new source prepare/select end", previousSource: originalSource, nextSource: mode)

        if mode.startsLiveListeningOnSelection {
            logSourceSwitchTiming(activeDebugTiming, "new source start/listen/render start", previousSource: originalSource, nextSource: mode)
            startSelectedLiveMonitorNow()
            await sleepForSourceTransition(Self.sourcePrimeDuration)
            logSourceSwitchTiming(activeDebugTiming, "new source start/listen/render end", previousSource: originalSource, nextSource: mode)
        }

        if let pendingMode = sourceSwitchRequests.pendingMode {
            logSourceSwitchTiming(
                activeDebugTiming,
                "stale source switch discarded",
                previousSource: originalSource,
                nextSource: mode,
                extra: ["pendingSource=\"\(pendingMode.rawValue)\""]
            )
            logSourceSwitchDebug(
                "completed",
                context: activeDebugTiming,
                from: originalSource,
                to: mode,
                reason: reason,
                requestedBy: requestedBy,
                completedAt: Date(),
                success: false,
                error: "pending source \(pendingMode.rawValue)"
            )
            return
        }

        logSourceSwitchTiming(activeDebugTiming, "output ramp up start", previousSource: originalSource, nextSource: mode)
        let didRampUp = await rampTransitionOutput(to: 1, duration: Self.sourceRampUpDuration, abortIfNewSourceSwitchPending: true)
        guard didRampUp else {
            logSourceSwitchTiming(
                activeDebugTiming,
                "stale source switch discarded",
                previousSource: originalSource,
                nextSource: mode,
                extra: ["reason=\"newer source requested during ramp up\""]
            )
            logSourceSwitchDebug(
                "completed",
                context: activeDebugTiming,
                from: originalSource,
                to: mode,
                reason: reason,
                requestedBy: requestedBy,
                completedAt: Date(),
                success: false,
                error: "newer source requested during ramp up"
            )
            return
        }
        logSourceSwitchTiming(activeDebugTiming, "output ramp up end", previousSource: originalSource, nextSource: mode)
        if case .error = liveMonitorState {
            logSourceSwitchTiming(activeDebugTiming, "source switch failed", previousSource: originalSource, nextSource: mode)
            logSourceSwitchDebug(
                "completed",
                context: activeDebugTiming,
                from: originalSource,
                to: mode,
                reason: reason,
                requestedBy: requestedBy,
                completedAt: Date(),
                success: false,
                error: liveMonitorDebugState()
            )
        } else if case .unavailable = liveMonitorState, mode.isLiveInput {
            logSourceSwitchTiming(activeDebugTiming, "source switch failed", previousSource: originalSource, nextSource: mode)
            logSourceSwitchDebug(
                "completed",
                context: activeDebugTiming,
                from: originalSource,
                to: mode,
                reason: reason,
                requestedBy: requestedBy,
                completedAt: Date(),
                success: false,
                error: liveMonitorDebugState()
            )
        } else {
            logSourceSwitchTiming(activeDebugTiming, "source switch complete", previousSource: originalSource, nextSource: mode)
            logSourceSwitchDebug(
                "completed",
                context: activeDebugTiming,
                from: originalSource,
                to: mode,
                reason: reason,
                requestedBy: requestedBy,
                completedAt: Date(),
                success: true
            )
        }
        AppLogger.shared.notice(category: "source", "Finished source switch to \(mode.rawValue)")
    }

    private func applySourceModeState(_ mode: SourceMode) {
        sourceMode = mode

        switch mode {
        case .off:
            updateSpotifyNowPlaying(nil, reason: "source changed", forceVisible: true)
            liveSignalStatus = "No audio yet."
            liveBufferStatus = "No live buffer."
            liveMonitorState = .stopped
            roonNowPlayingStatus = "Roon metadata is only shown for live Roon input."
            roonSignalPath = nil
            statusMessage = "Orbisonic is idle. Select a source to begin listening or playback."
        case .filePlayback:
            updateSpotifyNowPlaying(nil, reason: "source changed", forceVisible: true)
            liveSignalStatus = "No live input."
            liveBufferStatus = "No live buffer."
            liveMonitorState = .stopped
            roonNowPlayingStatus = "Roon metadata is only shown for live Roon input."
            roonSignalPath = nil
            statusMessage = "Use the Player below to choose files and control playback."
        case .roon:
            updateSpotifyNowPlaying(nil, reason: "source changed", forceVisible: true)
            currentFileURL = nil
            clearLoadedSourceSnapshot()
            roonNowPlayingStatus = "Roon metadata not requested yet."
            roonSignalPath = nil
            refreshRoonBridgeIfNeeded(force: true)
            if selectExpectedLoopbackInputIfAvailable(for: .roon) {
                liveMonitorState = .stopped
                statusMessage = "Roon is selected. Use Roon to send audio to Orbisonic."
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
            refreshSpotifyNowPlayingIfNeeded(force: true, reason: "source selected")
            if selectExpectedLoopbackInputIfAvailable(for: .spotify) {
                liveMonitorState = .stopped
                statusMessage = "Spotify is selected. Use the Spotify app to connect to Orbisonic Spotify."
            } else {
                let message = missingLoopbackMessage(for: .spotify)
                liveMonitorState = .unavailable(message)
                statusMessage = message
            }
        case .testTone:
            updateSpotifyNowPlaying(nil, reason: "source changed", forceVisible: true)
            liveSignalStatus = "No live input."
            liveBufferStatus = "No live buffer."
            liveMonitorState = .stopped
            roonNowPlayingStatus = "Roon metadata is only shown for live Roon input."
            roonSignalPath = nil
            statusMessage = "Test tone source is ready. Use Diagnostics to play the selected tone."
        case .aux:
            updateSpotifyNowPlaying(nil, reason: "source changed", forceVisible: true)
            currentFileURL = nil
            clearLoadedSourceSnapshot()
            roonNowPlayingStatus = "Roon metadata is only shown for live Roon input."
            roonSignalPath = nil
            roonNowPlaying = nil
            if selectExpectedLoopbackInputIfAvailable(for: .aux) {
                liveMonitorState = .stopped
                statusMessage = "Aux Cable is selected. Connect an audio source to the selected input."
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
        let stateBefore = debugPlaybackStateSnapshot()
        let previousDevice = monitorOutputRoute.deviceName
        let previousRoute = monitorOutputRoute
        monitorOutputSelection = .none
        persistMonitorOutputSelection()
        refreshRoutesIfNeeded(force: true)
        let graphRebuild = activateRendererOutputIfMonitorWasActive(previousMonitorRoute: previousRoute)
        statusMessage = "Output 1 Monitor not set."
        logOutputRoutingDebug(
            output: "Output 1 Monitor",
            previousDevice: previousDevice,
            newDevice: "not set",
            playbackStateBefore: stateBefore,
            graphRebuild: graphRebuild
        )
    }

    func selectSystemMonitorOutput() {
        let previousDevice = monitorOutputRoute.deviceName
        monitorOutputSelection = .systemDefault
        persistMonitorOutputSelection()
        refreshRoutesIfNeeded(force: true)
        applyMonitorOutputRouteIfAvailable(monitorOutputRoute, previousDevice: previousDevice, label: "System Default")
    }

    func selectMonitorOutputRoute(_ route: OutputRouteInfo) {
        let stateBefore = debugPlaybackStateSnapshot()
        let previousDevice = monitorOutputRoute.deviceName
        guard route.isAvailable else {
            logOutputRoutingDebug(
                output: "Output 1 Monitor",
                previousDevice: previousDevice,
                newDevice: route.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: false,
                error: "route unavailable"
            )
            return
        }
        guard route.isSelectableOutputTarget else {
            let message = outputFeedbackMessage(for: route, purpose: .monitor)
            AppLogger.shared.error(category: "route", message)
            statusMessage = message
            lastError = message
            logOutputRoutingDebug(
                output: "Output 1 Monitor",
                previousDevice: previousDevice,
                newDevice: route.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: false,
                error: message
            )
            return
        }

        monitorOutputSelection = .device(route.uid)
        persistMonitorOutputSelection()
        refreshRoutesIfNeeded(force: true)
        applyMonitorOutputRouteIfAvailable(route, previousDevice: previousDevice, label: route.deviceName)
    }

    func selectNoRendererOutput() {
        let stateBefore = debugPlaybackStateSnapshot()
        let previousDevice = rendererOutputRoute.deviceName
        rendererOutputSelection = .none
        persistRendererOutputSelection()
        refreshRoutesIfNeeded(force: true)
        configureMonitorMeters()
        configureRendererMeters()
        syncRendererAudioRouting()
        if isDiagnosticSequencePlaying {
            stop()
        }
        statusMessage = "Output 2 Renderer not set."
        logOutputRoutingDebug(
            output: "Output 2 Renderer",
            previousDevice: previousDevice,
            newDevice: "not set",
            playbackStateBefore: stateBefore,
            graphRebuild: true
        )
    }

    func selectRendererOutputRoute(_ route: OutputRouteInfo) {
        let stateBefore = debugPlaybackStateSnapshot()
        let previousDevice = rendererOutputRoute.deviceName
        guard route.isAvailable else {
            logOutputRoutingDebug(
                output: "Output 2 Renderer",
                previousDevice: previousDevice,
                newDevice: route.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: false,
                error: "route unavailable"
            )
            return
        }
        guard route.isSelectableOutputTarget else {
            let message = outputFeedbackMessage(for: route, purpose: .renderer)
            AppLogger.shared.error(category: "route", message)
            statusMessage = message
            lastError = message
            logOutputRoutingDebug(
                output: "Output 2 Renderer",
                previousDevice: previousDevice,
                newDevice: route.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: false,
                error: message
            )
            return
        }

        rendererOutputSelection = .device(route.uid)
        persistRendererOutputSelection()
        refreshRoutesIfNeeded(force: true)
        applyOutputRouteIfAvailable(route, purpose: .renderer, label: route.deviceName)
        logOutputRoutingDebug(
            output: "Output 2 Renderer",
            previousDevice: previousDevice,
            newDevice: route.deviceName,
            playbackStateBefore: stateBefore,
            graphRebuild: true
        )
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

        if let selectedLibraryTrackID,
           !localMusicTracks.contains(where: { $0.id == selectedLibraryTrackID }) {
            self.selectedLibraryTrackID = nil
        }
        if let selectedLocalMusicPlaylistID,
           !localMusicPlaylists.contains(where: { $0.id == selectedLocalMusicPlaylistID }) {
            self.selectedLocalMusicPlaylistID = nil
        }
        sessionQueue = sessionQueue.filter { track in localMusicTracks.contains(where: { $0.id == track.id }) }
        if let sessionQueueIndex, sessionQueue.indices.contains(sessionQueueIndex) == false {
            refreshSessionQueueIndexForCurrentFile()
        }
        if let selectedSessionQueueIndex, sessionQueue.indices.contains(selectedSessionQueueIndex) == false {
            self.selectedSessionQueueIndex = nil
        }
        if let pendingSessionQueueIndex, sessionQueue.indices.contains(pendingSessionQueueIndex) == false {
            self.pendingSessionQueueIndex = nil
        }

        persistLocalMusicDatabase()
        if result.skippedMissingFiles > 0 {
            statusMessage = "Scanned \(localMusicTracks.count) playable tracks; skipped \(result.skippedMissingFiles) missing files."
        } else {
            statusMessage = "Local music library scanned: \(localMusicTracks.count) tracks, \(localMusicPlaylists.count) playlists."
        }
        AppLogger.shared.notice(
            category: "local-music",
            "Scanned watchFolders=\(localMusicSettings.watchFolderPaths.count) explicitPlaylists=\(localMusicSettings.m3uPlaylistPaths.count) tracks=\(localMusicTracks.count) playlists=\(localMusicPlaylists.count) skippedMissing=\(result.skippedMissingFiles)"
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
        if isPlaying {
            pauseLocalTransport()
            return
        }

        playLocalTransport()
    }

    func playLocalTransport() {
        let stateBefore = debugPlaybackStateSnapshot()
        var commandAllowed = true
        var commandError: String?
        defer {
            logTransportDebug(
                command: "play",
                allowed: commandAllowed,
                handler: "playLocalTransport",
                stateBefore: stateBefore,
                stateAfter: debugPlaybackStateSnapshot(),
                error: commandError
            )
        }
        let debugTiming = DebugTimingLog.makeCommand(prefix: "local-play", sourceMode: sourceMode)
        logLocalTransportTiming(
            debugTiming,
            "command received",
            extra: ["command=\"play\""]
        )
        if isLocalFileLoading {
            statusMessage = "Loading local track..."
            commandAllowed = false
            commandError = "local file load already in progress"
            logLocalTransportTiming(
                debugTiming,
                "UI state updated",
                extra: ["status=\"Loading local track...\""]
            )
            return
        }

        if sourceMode == .filePlayback, currentFileURL != nil, duration > 0 {
            guard !isPlaying else {
                commandAllowed = false
                commandError = "local playback already playing"
                return
            }
            togglePlayback()
            return
        }

        let selectedQueueTrack = selectedSessionQueueIndex.flatMap { index in
            sessionQueue.indices.contains(index) ? sessionQueue[index] : nil
        }
        guard let track = selectedQueueTrack ?? selectedLocalMusicTrack ?? currentLocalMusicTrack ?? visibleLocalMusicTracks.first else {
            statusMessage = "Add a watch folder in Settings, then scan local music."
            commandAllowed = false
            commandError = statusMessage
            return
        }

        guard currentFileURL?.path == track.id, sourceMode == .filePlayback else {
            if let queueIndex = sessionQueue.firstIndex(where: { $0.id == track.id }) {
                playQueueIndex(queueIndex, debugTiming: debugTiming)
                return
            }
            startSessionQueue(
                from: visibleLocalMusicTracks,
                startTrackID: track.id,
                shuffle: isShuffleEnabled,
                autoplay: true,
                debugTiming: debugTiming
            )
            return
        }

        togglePlayback()
    }

    func pauseLocalTransport() {
        let stateBefore = debugPlaybackStateSnapshot()
        var commandAllowed = sourceMode == .filePlayback || isLocalFileLoading
        var commandError: String?
        defer {
            logTransportDebug(
                command: "pause",
                allowed: commandAllowed,
                handler: "pauseLocalTransport",
                stateBefore: stateBefore,
                stateAfter: debugPlaybackStateSnapshot(),
                error: commandError
            )
        }
        let debugTiming = DebugTimingLog.makeCommand(prefix: "local-pause", sourceMode: sourceMode)
        logLocalTransportTiming(
            debugTiming,
            "command received",
            extra: ["command=\"pause\""]
        )
        logLocalTransportTiming(debugTiming, "pause cancellation started")
        cancelPendingLocalFileLoad(debugTiming: debugTiming)
        logLocalTransportTiming(debugTiming, "pause cancellation finished")
        guard sourceMode == .filePlayback else {
            commandAllowed = false
            commandError = "source is \(sourceMode.rawValue)"
            return
        }

        if isPlaying {
            engine.pause()
            isPlaying = false
            reevaluateAutomaticRendererMode(reason: "pause")
            statusMessage = "Local playback paused"
        } else {
            statusMessage = "Local playback paused"
        }
    }

    func stopLocalTransport() {
        let stateBefore = debugPlaybackStateSnapshot()
        let commandAllowed = sourceMode == .filePlayback || isLocalFileLoading
        var commandError: String?
        defer {
            logTransportDebug(
                command: "stop",
                allowed: commandAllowed,
                handler: "stopLocalTransport",
                stateBefore: stateBefore,
                stateAfter: debugPlaybackStateSnapshot(),
                error: commandError
            )
        }
        let debugTiming = DebugTimingLog.makeCommand(prefix: "local-stop", sourceMode: sourceMode)
        logLocalTransportTiming(
            debugTiming,
            "command received",
            extra: ["command=\"stop\""]
        )
        logLocalTransportTiming(debugTiming, "stop cancellation started")
        cancelPendingLocalFileLoad(debugTiming: debugTiming)
        logLocalTransportTiming(debugTiming, "stop cancellation finished")
        stop()
        if sourceMode == .filePlayback {
            statusMessage = "Local playback stopped"
        } else if !commandAllowed {
            commandError = "source is \(sourceMode.rawValue)"
        }
    }

    func playLocalMusicTrackNow(_ track: LocalMusicTrack) {
        let previousSource = sourceMode
        let debugTiming = DebugTimingLog.makeCommand(prefix: "local-play-now", sourceMode: sourceMode)
        let sourceSwitchRequired = previousSource != .filePlayback ||
            isLiveMonitorTransitioning ||
            sourceSwitchRequests.isProcessing ||
            sourceSwitchTargetMode != nil
        logLocalPlayNowDebug(
            "requested",
            selectedTrack: track,
            previousSource: previousSource,
            sourceSwitchRequired: sourceSwitchRequired,
            finalState: debugPlaybackStateSnapshot()
        )
        logLocalTransportTiming(
            debugTiming,
            "command received",
            track: track,
            extra: ["command=\"row-play\""]
        )
        selectedSessionQueueIndex = nil
        let tracks = visibleLocalMusicTracks.contains(where: { $0.id == track.id })
            ? visibleLocalMusicTracks
            : [track]
        localPlayNowTask?.cancel()
        localPlayNowSequence &+= 1
        let sequence = localPlayNowSequence

        guard sourceSwitchRequired else {
            startSessionQueue(from: tracks, startTrackID: track.id, shuffle: false, autoplay: true, debugTiming: debugTiming)
            return
        }

        statusMessage = "Switching to Local Files..."
        logLocalPlayNowDebug(
            "source switch started",
            selectedTrack: track,
            previousSource: previousSource,
            sourceSwitchRequired: true,
            sourceSwitchStarted: true,
            finalState: debugPlaybackStateSnapshot()
        )

        localPlayNowTask = Task { @MainActor [weak self] in
            await self?.continueLocalPlayNowAfterSourceSwitch(
                sequence: sequence,
                track: track,
                tracks: tracks,
                previousSource: previousSource,
                debugTiming: debugTiming
            )
        }
    }

    private func continueLocalPlayNowAfterSourceSwitch(
        sequence: UInt64,
        track: LocalMusicTrack,
        tracks: [LocalMusicTrack],
        previousSource: SourceMode,
        debugTiming: DebugTimingContext?
    ) async {
        defer {
            if sequence == localPlayNowSequence {
                localPlayNowTask = nil
            }
        }
        selectSourceMode(.filePlayback, reason: "local Play Now", requestedBy: "local-play-now")

        let didSwitch = await waitForLocalPlayNowSourceActivation(sequence: sequence)
        guard !Task.isCancelled, sequence == localPlayNowSequence else { return }

        guard didSwitch else {
            let message = sourceMode == .filePlayback
                ? "Local Files did not finish activating for Play Now."
                : "Could not switch to Local Files for Play Now. Current source is \(sourceMode.rawValue)."
            statusMessage = message
            lastError = message
            isLocalFileLoading = false
            pendingSessionQueueIndex = nil
            logLocalPlayNowDebug(
                "completed",
                selectedTrack: track,
                previousSource: previousSource,
                sourceSwitchRequired: true,
                sourceSwitchStarted: true,
                sourceSwitchSuccess: false,
                finalState: debugPlaybackStateSnapshot(),
                error: message
            )
            return
        }

        logLocalPlayNowDebug(
            "source switch completed",
            selectedTrack: track,
            previousSource: previousSource,
            sourceSwitchRequired: true,
            sourceSwitchStarted: true,
            sourceSwitchSuccess: true,
            finalState: debugPlaybackStateSnapshot()
        )
        startSessionQueue(from: tracks, startTrackID: track.id, shuffle: false, autoplay: true, debugTiming: debugTiming)
    }

    private func waitForLocalPlayNowSourceActivation(sequence: UInt64) async -> Bool {
        let deadline = Date().addingTimeInterval(Self.localPlayNowSourceSwitchTimeout)
        while Date() < deadline {
            guard !Task.isCancelled, sequence == localPlayNowSequence else { return false }
            if sourceMode == .filePlayback,
               sourceSwitchTargetMode == nil,
               !isLiveMonitorTransitioning,
               !sourceSwitchRequests.isProcessing {
                return true
            }

            do {
                try await Task.sleep(nanoseconds: 20_000_000)
            } catch {
                return false
            }
        }

        return sourceMode == .filePlayback &&
            sourceSwitchTargetMode == nil &&
            !isLiveMonitorTransitioning &&
            !sourceSwitchRequests.isProcessing
    }

    func selectLocalMusicTrack(_ track: LocalMusicTrack) {
        selectedLibraryTrackID = track.id
        selectedSessionQueueIndex = nil
    }

    func playNextLocalMusicTrack() {
        skipLocalTransport(offset: 1)
    }

    func playPreviousLocalMusicTrack() {
        skipLocalTransport(offset: -1)
    }

    func selectSessionQueueIndex(_ index: Int) {
        guard sessionQueue.indices.contains(index) else { return }
        selectedSessionQueueIndex = index
    }

    func playSessionQueueIndex(_ index: Int) {
        guard sessionQueue.indices.contains(index) else { return }
        let debugTiming = DebugTimingLog.makeCommand(prefix: "local-row-play", sourceMode: sourceMode)
        logLocalTransportTiming(
            debugTiming,
            "command received",
            targetQueueIndex: index,
            track: queueTrack(for: index),
            extra: ["command=\"row-play\""]
        )
        selectedSessionQueueIndex = index
        logLocalTransportTiming(
            debugTiming,
            "UI state updated",
            targetQueueIndex: index,
            track: queueTrack(for: index),
            extra: ["selectedSessionQueueIndex=\(index)"]
        )
        _ = playQueueIndex(index, debugTiming: debugTiming)
    }

    func playSelectedSessionQueueTrack() {
        let debugTiming = DebugTimingLog.makeCommand(prefix: "local-row-play", sourceMode: sourceMode)
        logLocalTransportTiming(
            debugTiming,
            "command received",
            targetQueueIndex: selectedSessionQueueIndex,
            track: selectedSessionQueueIndex.flatMap { queueTrack(for: $0) },
            extra: ["command=\"selected-row-play\""]
        )
        if let selectedSessionQueueIndex, sessionQueue.indices.contains(selectedSessionQueueIndex) {
            if currentFileURL?.path == sessionQueue[selectedSessionQueueIndex].id, sourceMode == .filePlayback {
                toggleLocalMusicPlayback()
                return
            }
            playQueueIndex(selectedSessionQueueIndex, debugTiming: debugTiming)
            return
        }

        toggleLocalMusicPlayback()
    }

    func playAllLocalMusic(shuffle: Bool = false) {
        let debugTiming = DebugTimingLog.makeCommand(prefix: shuffle ? "local-shuffle" : "local-play-all", sourceMode: sourceMode)
        logLocalTransportTiming(
            debugTiming,
            "command received",
            extra: ["command=\"\(shuffle ? "shuffle" : "playAll")\""]
        )
        startSessionQueue(
            from: visibleLocalMusicTracks,
            startTrackID: visibleLocalMusicTracks.first?.id,
            shuffle: shuffle,
            autoplay: true,
            debugTiming: debugTiming
        )
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
        selectedLibraryTrackID = track.id

        if wasEmpty {
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
            selectedSessionQueueIndex = 0
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
        cancelPendingLocalFileLoad()
        sessionQueue = []
        sessionQueueIndex = nil
        selectedSessionQueueIndex = nil
        pendingSessionQueueIndex = nil
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
            pendingSessionQueueIndex = nil
        } else if let currentIndex = sessionQueueIndex {
            if currentIndex == index {
                refreshSessionQueueIndexForCurrentFile()
            } else if index < currentIndex {
                sessionQueueIndex = currentIndex - 1
            }
        }

        if let selectedIndex = selectedSessionQueueIndex {
            if selectedIndex == index {
                selectedSessionQueueIndex = nil
            } else if index < selectedIndex {
                selectedSessionQueueIndex = selectedIndex - 1
            }
        }

        if let pendingIndex = pendingSessionQueueIndex {
            if pendingIndex == index {
                cancelPendingLocalFileLoad()
            } else if index < pendingIndex {
                pendingSessionQueueIndex = pendingIndex - 1
            }
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
        guard let path = (currentQueueTrack ?? currentLocalMusicTrack)?.artworkPath else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }

    var spotifyArtworkURL: URL? {
        guard let coverURL = spotifyVisibleNowPlaying?.coverURL else { return nil }
        return URL(string: coverURL)
    }

    var visibleLocalMusicTracks: [LocalMusicTrack] {
        let query = localMusicSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sortedTracks = sortedLocalMusicTracks
        guard !query.isEmpty else { return sortedTracks }

        return sortedTracks.filter { track in track.matches(query) }
    }

    var selectedLocalMusicTrack: LocalMusicTrack? {
        guard let selectedLibraryTrackID else { return nil }
        return localMusicTracks.first { $0.id == selectedLibraryTrackID }
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

    private func queueTrack(for index: Int) -> LocalMusicTrack? {
        sessionQueue.indices.contains(index) ? sessionQueue[index] : nil
    }

    func tracks(for playlist: LocalMusicPlaylist) -> [LocalMusicTrack] {
        let tracksByPath = Dictionary(uniqueKeysWithValues: localMusicTracks.map { ($0.path, $0) })
        return playlist.trackPaths.compactMap { tracksByPath[$0] }
    }

#if DEBUG
    func replaceLocalMusicQueueForTesting(
        tracks: [LocalMusicTrack],
        currentIndex: Int?,
        selectedIndex: Int?
    ) {
        localMusicTracks = tracks
        sessionQueue = tracks
        sessionQueueIndex = currentIndex
        selectedSessionQueueIndex = selectedIndex
        selectedLibraryTrackID = nil
        pendingSessionQueueIndex = nil
    }

    func setSourceModeForTesting(_ mode: SourceMode) {
        sourceMode = mode
        if mode != .spotify {
            clearSpotifyVisibleState(reason: "test source changed")
        }
    }

    func setSpotifyNowPlayingForTesting(_ nowPlaying: SpotifyNowPlaying?) {
        updateSpotifyNowPlaying(nowPlaying, reason: "test", forceVisible: true)
    }

    func applySpotifyNowPlayingForTesting(_ nowPlaying: SpotifyNowPlaying?) {
        updateSpotifyNowPlaying(nowPlaying, reason: "test")
    }

    func setRoonNowPlayingForTesting(_ nowPlaying: RoonNowPlaying?) {
        roonNowPlaying = nowPlaying
        roonNowPlayingStatus = nowPlaying?.updatedText ?? "No Roon playback line found in RoonServer log yet."
    }

    @discardableResult
    func playQueueIndexForTesting(_ index: Int) -> Bool {
        playQueueIndex(index)
    }

    func loadQueueIndexForTesting(_ index: Int, autoplay: Bool = false, isPlaying: Bool = false) async throws {
        guard sessionQueue.indices.contains(index) else { return }
        let track = sessionQueue[index]
        _ = loadFile(
            url: track.url,
            autoplay: autoplay,
            queueCommit: LocalFileQueueCommit(index: index, trackID: track.id, isNaturalAdvance: false)
        )
        while isLocalFileLoading {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        self.isPlaying = isPlaying
    }

    func triggerPlaybackEndedForTesting() {
        handlePlaybackEnded()
    }
#endif

    private var sortedLocalMusicTracks: [LocalMusicTrack] {
        localMusicTracks.sorted(by: localMusicComparator)
    }

    @discardableResult
    private func loadFile(
        url: URL,
        autoplay: Bool,
        queueCommit: LocalFileQueueCommit? = nil,
        kind: LocalFileLoadKind = .selectedTrack,
        startPolicy: LocalFileLoadStartPolicy = .immediate,
        debugTiming: DebugTimingContext? = nil
    ) -> Bool {
        let request = nextLocalFileLoadRequest(
            url: url,
            autoplay: autoplay,
            queueCommit: queueCommit,
            kind: kind,
            startPolicy: startPolicy,
            debugTiming: debugTiming
        )
        currentLocalFileLoadGeneration = request.generation
        pendingSessionQueueIndex = queueCommit?.index
        logLocalTransportTiming(
            debugTiming,
            "pending target set",
            targetQueueIndex: queueCommit?.index,
            track: queueCommit.flatMap { queueTrack(for: $0.index) },
            fileURL: url
        )
        logLocalPlayNowDebug(
            "load requested",
            request: request,
            loadStarted: false
        )
        statusMessage = requestImmediateStatus(request)
        logLocalTransportTiming(
            debugTiming,
            "UI state updated",
            targetQueueIndex: queueCommit?.index,
            track: queueCommit.flatMap { queueTrack(for: $0.index) },
            fileURL: url,
            extra: ["status=\"\(statusMessage)\""]
        )
        lastError = nil
        isLocalFileLoading = true
        startLocalFileLoadStatusTask(for: request)

        queueLocalFileLoadForStart(request)
        return true
    }

    private func nextLocalFileLoadRequest(
        url: URL,
        autoplay: Bool,
        queueCommit: LocalFileQueueCommit?,
        kind: LocalFileLoadKind,
        startPolicy: LocalFileLoadStartPolicy,
        debugTiming: DebugTimingContext?
    ) -> LocalFileLoadRequest {
        localFileLoadSequence &+= 1
        return LocalFileLoadRequest(
            id: localFileLoadSequence,
            generation: localFileLoadSequence,
            url: url,
            autoplay: autoplay,
            queueCommit: queueCommit,
            kind: kind,
            startPolicy: startPolicy,
            debugTiming: debugTiming,
            requestedFromSource: sourceMode,
            isLocalPlayNow: debugTiming?.id.hasPrefix("local-play-now-") == true
        )
    }

    private func requestTrackTitle(_ request: LocalFileLoadRequest) -> String? {
        request.queueCommit.flatMap { queueTrack(for: $0.index)?.displayTitle }
    }

    private func requestImmediateStatus(_ request: LocalFileLoadRequest) -> String {
        request.kind.immediateStatus(
            trackTitle: requestTrackTitle(request),
            fileName: request.url.lastPathComponent
        )
    }

    private func startLocalFileLoadStatusTask(for request: LocalFileLoadRequest) {
        localFileLoadStatusTask?.cancel()
        localFileLoadStatusTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.localLoadSubtleStatusNanoseconds)
                guard let self, self.isLocalFileLoadRequestCurrent(request) else { return }
                self.statusMessage = request.kind.subtleStatus(
                    trackTitle: self.requestTrackTitle(request),
                    fileName: request.url.lastPathComponent
                )
                self.logLocalTransportTiming(
                    request.debugTiming,
                    "UI state updated",
                    targetQueueIndex: request.queueCommit?.index,
                    track: request.queueCommit.flatMap { self.queueTrack(for: $0.index) },
                    fileURL: request.url,
                    extra: ["status=\"\(self.statusMessage)\""]
                )

                try await Task.sleep(nanoseconds: Self.localLoadClearStatusNanoseconds - Self.localLoadSubtleStatusNanoseconds)
                guard self.isLocalFileLoadRequestCurrent(request) else { return }
                self.statusMessage = request.kind.clearStatus(
                    trackTitle: self.requestTrackTitle(request),
                    fileName: request.url.lastPathComponent
                )
                self.logLocalTransportTiming(
                    request.debugTiming,
                    "UI state updated",
                    targetQueueIndex: request.queueCommit?.index,
                    track: request.queueCommit.flatMap { self.queueTrack(for: $0.index) },
                    fileURL: request.url,
                    extra: ["status=\"\(self.statusMessage)\""]
                )

                try await Task.sleep(nanoseconds: Self.localLoadStillLoadingNanoseconds - Self.localLoadClearStatusNanoseconds)
                guard self.isLocalFileLoadRequestCurrent(request) else { return }
                self.statusMessage = request.kind.stillLoadingStatus
                self.logLocalTransportTiming(
                    request.debugTiming,
                    "UI state updated",
                    targetQueueIndex: request.queueCommit?.index,
                    track: request.queueCommit.flatMap { self.queueTrack(for: $0.index) },
                    fileURL: request.url,
                    extra: ["status=\"\(self.statusMessage)\""]
                )
            } catch {
                return
            }
        }
    }

    private func stopLocalFileLoadStatusTask() {
        localFileLoadStatusTask?.cancel()
        localFileLoadStatusTask = nil
    }

    private func isLocalFileLoadRequestCurrent(_ request: LocalFileLoadRequest) -> Bool {
        currentLocalFileLoadGeneration == request.generation &&
            (activeLocalFileLoadRequest?.generation == request.generation ||
             queuedLocalFileLoadRequest?.generation == request.generation)
    }

    private func localFileLoadValidationFailure(for request: LocalFileLoadRequest) -> String? {
        guard currentLocalFileLoadGeneration == request.generation else {
            return "generation \(request.generation) invalidated by \(currentLocalFileLoadGeneration)"
        }
        guard sourceMode == .filePlayback else {
            return "source mode changed to \(sourceMode.rawValue)"
        }
        if let queueCommit = request.queueCommit {
            guard sessionQueue.indices.contains(queueCommit.index) else {
                return "target queue index \(queueCommit.index) is no longer valid"
            }
            guard sessionQueue[queueCommit.index].id == queueCommit.trackID else {
                return "target queue index \(queueCommit.index) now points at a different track"
            }
            guard pendingSessionQueueIndex == queueCommit.index else {
                return "pending target no longer matches \(queueCommit.index)"
            }
        }
        return nil
    }

    private func cancelLocalFileLoadDebounce(reason: String) {
        guard let request = queuedLocalFileLoadRequest ?? activeLocalFileLoadRequest,
              localFileLoadDebounceTask != nil
        else {
            localFileLoadDebounceTask?.cancel()
            localFileLoadDebounceTask = nil
            readyQueuedLocalFileLoadGeneration = nil
            return
        }

        localFileLoadDebounceTask?.cancel()
        localFileLoadDebounceTask = nil
        readyQueuedLocalFileLoadGeneration = nil
        logLocalTransportTiming(
            request.debugTiming,
            "debounce canceled",
            targetQueueIndex: request.queueCommit?.index,
            track: request.queueCommit.flatMap { queueTrack(for: $0.index) },
            fileURL: request.url,
            extra: ["reason=\"\(reason)\""]
        )
        logLocalTransportTiming(
            request.debugTiming,
            "generation invalidated",
            targetQueueIndex: request.queueCommit?.index,
            track: request.queueCommit.flatMap { queueTrack(for: $0.index) },
            fileURL: request.url,
            extra: ["reason=\"\(reason)\""]
        )
    }

    private func queueLocalFileLoadForStart(_ request: LocalFileLoadRequest) {
        if let activeRequest = activeLocalFileLoadRequest,
           activeRequest.generation != request.generation {
            logLocalTransportTiming(
                activeRequest.debugTiming,
                "generation invalidated",
                targetQueueIndex: activeRequest.queueCommit?.index,
                track: activeRequest.queueCommit.flatMap { queueTrack(for: $0.index) },
                fileURL: activeRequest.url,
                extra: ["reason=\"superseded by local load \(request.generation)\""]
            )
        }
        if let queuedRequest = queuedLocalFileLoadRequest,
           queuedRequest.generation != request.generation {
            logLocalTransportTiming(
                queuedRequest.debugTiming,
                "stale completion discarded",
                targetQueueIndex: queuedRequest.queueCommit?.index,
                track: queuedRequest.queueCommit.flatMap { queueTrack(for: $0.index) },
                fileURL: queuedRequest.url,
                extra: ["reason=\"queued load superseded by \(request.generation)\""]
            )
        }

        switch request.startPolicy {
        case .immediate:
            cancelLocalFileLoadDebounce(reason: "immediate local load replacing debounce")
            queuedLocalFileLoadRequest = nil
            readyQueuedLocalFileLoadGeneration = nil
            if activeLocalFileLoadRequest == nil {
                startLocalFileLoad(request)
            } else {
                queuedLocalFileLoadRequest = request
                AppLogger.shared.info(
                    category: "ui",
                    "Queued local load request id=\(request.id) file=\(request.url.lastPathComponent)"
                )
            }
        case .debounced:
            if localFileLoadDebounceTask != nil {
                cancelLocalFileLoadDebounce(reason: "debounce reset")
            }
            queuedLocalFileLoadRequest = request
            readyQueuedLocalFileLoadGeneration = nil
            logLocalTransportTiming(
                request.debugTiming,
                "debounce started",
                targetQueueIndex: request.queueCommit?.index,
                track: request.queueCommit.flatMap { queueTrack(for: $0.index) },
                fileURL: request.url,
                extra: ["debounceMs=120"]
            )
            localFileLoadDebounceTask = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(nanoseconds: Self.localTransportDebounceNanoseconds)
                } catch {
                    return
                }
                guard let self else { return }
                guard self.currentLocalFileLoadGeneration == request.generation,
                      self.queuedLocalFileLoadRequest?.generation == request.generation
                else {
                    self.logLocalTransportTiming(
                        request.debugTiming,
                        "stale completion discarded",
                        targetQueueIndex: request.queueCommit?.index,
                        track: request.queueCommit.flatMap { self.queueTrack(for: $0.index) },
                        fileURL: request.url,
                        extra: ["reason=\"debounce fired for stale generation \(request.generation)\""]
                    )
                    return
                }
                self.localFileLoadDebounceTask = nil
                self.readyQueuedLocalFileLoadGeneration = request.generation
                self.logLocalTransportTiming(
                    request.debugTiming,
                    "debounce fired",
                    targetQueueIndex: request.queueCommit?.index,
                    track: request.queueCommit.flatMap { self.queueTrack(for: $0.index) },
                    fileURL: request.url
                )
                guard self.activeLocalFileLoadRequest == nil else { return }
                self.queuedLocalFileLoadRequest = nil
                self.readyQueuedLocalFileLoadGeneration = nil
                self.startLocalFileLoad(request)
            }
        }
    }

    private func startLocalFileLoad(_ request: LocalFileLoadRequest) {
        activeLocalFileLoadRequest = request
        if readyQueuedLocalFileLoadGeneration == request.generation {
            readyQueuedLocalFileLoadGeneration = nil
        }
        pendingSessionQueueIndex = request.queueCommit?.index
        isLocalFileLoading = true
        statusMessage = requestImmediateStatus(request)
        let audioLoader = localAudioLoader
        logLocalTransportTiming(
            request.debugTiming,
            "decode scheduled",
            targetQueueIndex: request.queueCommit?.index,
            track: request.queueCommit.flatMap { queueTrack(for: $0.index) },
            fileURL: request.url
        )
        logLocalPlayNowDebug(
            "load started",
            request: request,
            loadStarted: true
        )

        localFileLoadTask = Task { @MainActor [weak self] in
            do {
                let decodeStart = DispatchTime.now().uptimeNanoseconds
                request.debugTiming?.log(
                    "decode started",
                    sourceMode: self?.sourceMode,
                    targetQueueIndex: request.queueCommit?.index,
                    trackTitle: request.queueCommit.flatMap { self?.queueTrack(for: $0.index)?.displayTitle },
                    fileURL: request.url
                )
                let loaded = try await Task.detached(priority: .utility) {
                    try audioLoader(request.url, request.debugTiming)
                }.value
                let decodeMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - decodeStart) / 1_000_000.0
                request.debugTiming?.log(
                    "decode finished",
                    sourceMode: self?.sourceMode,
                    targetQueueIndex: request.queueCommit?.index,
                    trackTitle: request.queueCommit.flatMap { self?.queueTrack(for: $0.index)?.displayTitle },
                    fileURL: request.url,
                    extra: ["decodeMs=\(String(format: "%.1f", decodeMilliseconds))"]
                )
                guard let self else { return }
                guard !Task.isCancelled else {
                    self.logLocalTransportTiming(
                        request.debugTiming,
                        "decode canceled",
                        targetQueueIndex: request.queueCommit?.index,
                        track: request.queueCommit.flatMap { self.queueTrack(for: $0.index) },
                        fileURL: request.url
                    )
                    return
                }
                guard self.activeLocalFileLoadRequest?.id == request.id else {
                    self.logLocalTransportTiming(
                        request.debugTiming,
                        "stale completion discarded",
                        targetQueueIndex: request.queueCommit?.index,
                        track: request.queueCommit.flatMap { self.queueTrack(for: $0.index) },
                        fileURL: request.url
                    )
                    return
                }
                self.completeLocalFileLoad(request: request, result: .success(loaded))
            } catch {
                guard let self else { return }
                guard !Task.isCancelled else {
                    self.logLocalTransportTiming(
                        request.debugTiming,
                        "decode canceled",
                        targetQueueIndex: request.queueCommit?.index,
                        track: request.queueCommit.flatMap { self.queueTrack(for: $0.index) },
                        fileURL: request.url,
                        extra: ["error=\"\(error.localizedDescription)\""]
                    )
                    return
                }
                guard self.activeLocalFileLoadRequest?.id == request.id else {
                    self.logLocalTransportTiming(
                        request.debugTiming,
                        "stale completion discarded",
                        targetQueueIndex: request.queueCommit?.index,
                        track: request.queueCommit.flatMap { self.queueTrack(for: $0.index) },
                        fileURL: request.url,
                        extra: ["error=\"\(error.localizedDescription)\""]
                    )
                    return
                }
                self.completeLocalFileLoad(request: request, result: .failure(error))
            }
        }
    }

    private func completeLocalFileLoad(request: LocalFileLoadRequest, result: Result<LoadedAudioFile, Error>) {
        localFileLoadTask = nil
        if activeLocalFileLoadRequest?.generation == request.generation {
            activeLocalFileLoadRequest = nil
        }

        if let queuedRequest = queuedLocalFileLoadRequest {
            logLocalTransportTiming(
                request.debugTiming,
                "stale completion discarded",
                targetQueueIndex: request.queueCommit?.index,
                track: request.queueCommit.flatMap { queueTrack(for: $0.index) },
                fileURL: request.url,
                extra: ["reason=\"superseded by queued local load \(queuedRequest.id)\""]
            )
            if queuedRequest.startPolicy == .debounced,
               readyQueuedLocalFileLoadGeneration != queuedRequest.generation {
                if localFileLoadDebounceTask == nil {
                    queueLocalFileLoadForStart(queuedRequest)
                }
                return
            }
            queuedLocalFileLoadRequest = nil
            readyQueuedLocalFileLoadGeneration = nil
            startLocalFileLoad(queuedRequest)
            return
        }

        if let validationFailure = localFileLoadValidationFailure(for: request) {
            stopLocalFileLoadStatusTask()
            logLocalTransportTiming(
                request.debugTiming,
                "stale completion discarded",
                targetQueueIndex: request.queueCommit?.index,
                track: request.queueCommit.flatMap { queueTrack(for: $0.index) },
                fileURL: request.url,
                extra: ["reason=\"\(validationFailure)\""]
            )
            if pendingSessionQueueIndex == request.queueCommit?.index {
                pendingSessionQueueIndex = nil
            }
            if activeLocalFileLoadRequest == nil && queuedLocalFileLoadRequest == nil {
                isLocalFileLoading = false
            }
            logLocalPlayNowDebug(
                "completed",
                request: request,
                loadStarted: true,
                loadCompleted: false,
                error: validationFailure
            )
            return
        }

        isLocalFileLoading = false
        pendingSessionQueueIndex = nil
        stopLocalFileLoadStatusTask()

        switch result {
        case .success(let loaded):
            logLocalPlayNowDebug(
                "load completed",
                request: request,
                loadStarted: true,
                loadCompleted: true
            )
            finishLoadedFile(
                loaded,
                autoplay: request.autoplay,
                queueCommit: request.queueCommit,
                localPlayNowRequest: request,
                debugTiming: request.debugTiming
            )
        case .failure(let error):
            logLocalPlayNowDebug(
                "completed",
                request: request,
                loadStarted: true,
                loadCompleted: false,
                error: error.localizedDescription
            )
            handleLocalFileLoadFailure(
                url: request.url,
                error: error,
                queueCommit: request.queueCommit,
                debugTiming: request.debugTiming
            )
        }
    }

    private func finishLoadedFile(
        _ loaded: LoadedAudioFile,
        autoplay: Bool,
        queueCommit: LocalFileQueueCommit?,
        localPlayNowRequest: LocalFileLoadRequest?,
        debugTiming: DebugTimingContext?
    ) {
        cancelDiagnosticsForMusicAction()
        sourceMode = .filePlayback

        let commitStart = DispatchTime.now().uptimeNanoseconds
        logLocalTransportTiming(
            debugTiming,
            "engine commit started",
            targetQueueIndex: queueCommit?.index,
            track: queueCommit.flatMap { queueTrack(for: $0.index) },
            fileURL: loaded.url
        )
        _ = engine.loadPreparedFile(loaded, debugTiming: debugTiming)
        logLocalTransportTiming(
            debugTiming,
            "engine commit finished",
            targetQueueIndex: queueCommit?.index,
            track: queueCommit.flatMap { queueTrack(for: $0.index) },
            fileURL: loaded.url,
            extra: ["commitMs=\(String(format: "%.1f", Double(DispatchTime.now().uptimeNanoseconds - commitStart) / 1_000_000.0))"]
        )
        logLocalTransportTiming(
            debugTiming,
            "publish player state start",
            targetQueueIndex: queueCommit?.index,
            track: queueCommit.flatMap { queueTrack(for: $0.index) },
            fileURL: loaded.url
        )
        loadedFileName = loaded.url.lastPathComponent
        currentFileURL = loaded.url
        if let queueCommit {
            sessionQueueIndex = queueCommit.index
            if !sessionQueue.indices.contains(queueCommit.index) ||
                sessionQueue[queueCommit.index].id != queueCommit.trackID {
                refreshSessionQueueIndexForCurrentFile()
            }
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
        logLocalTransportTiming(
            debugTiming,
            "now-playing committed",
            targetQueueIndex: queueCommit?.index,
            track: queueCommit.flatMap { queueTrack(for: $0.index) },
            fileURL: loaded.url
        )
        logLocalTransportTiming(
            debugTiming,
            "publish player state end",
            targetQueueIndex: queueCommit?.index,
            track: queueCommit.flatMap { queueTrack(for: $0.index) },
            fileURL: loaded.url
        )

        if autoplay {
            guard prepareOutputForMusicPlayback() else {
                if let localPlayNowRequest {
                    logLocalPlayNowDebug(
                        "completed",
                        request: localPlayNowRequest,
                        loadStarted: true,
                        loadCompleted: true,
                        playStarted: false,
                        error: "output preparation failed"
                    )
                }
                return
            }
            do {
                try engine.play(debugTiming: debugTiming)
                isPlaying = true
                statusMessage = "Playing \(loaded.metadata.fileName) through \(routeDisplayName) with \(rendererScene.renderMode.displayName)."
                if let localPlayNowRequest {
                    logLocalPlayNowDebug(
                        "completed",
                        request: localPlayNowRequest,
                        loadStarted: true,
                        loadCompleted: true,
                        playStarted: true
                    )
                }
            } catch {
                AppLogger.shared.error(category: "ui", "Playback start failed: \(error.localizedDescription)")
                lastError = error.localizedDescription
                logLocalTransportTiming(
                    debugTiming,
                    "error shown",
                    targetQueueIndex: queueCommit?.index,
                    track: queueCommit.flatMap { queueTrack(for: $0.index) },
                    fileURL: loaded.url,
                    extra: ["error=\"\(error.localizedDescription)\""]
                )
                if let localPlayNowRequest {
                    logLocalPlayNowDebug(
                        "completed",
                        request: localPlayNowRequest,
                        loadStarted: true,
                        loadCompleted: true,
                        playStarted: false,
                        error: error.localizedDescription
                    )
                }
            }
        } else if rendererOutputRoute.isAvailable {
            statusMessage = "Loaded \(loaded.metadata.fileName). Ready to render through \(rendererOutputRoute.deviceName)."
            if let localPlayNowRequest {
                logLocalPlayNowDebug(
                    "completed",
                    request: localPlayNowRequest,
                    loadStarted: true,
                    loadCompleted: true,
                    playStarted: false
                )
            }
        } else {
            statusMessage = "Loaded \(loaded.metadata.fileName). Playback can use Output 1 Monitor or current macOS output."
            if let localPlayNowRequest {
                logLocalPlayNowDebug(
                    "completed",
                    request: localPlayNowRequest,
                    loadStarted: true,
                    loadCompleted: true,
                    playStarted: false
                )
            }
        }
    }

    private func handleLocalFileLoadFailure(
        url: URL,
        error: Error,
        queueCommit: LocalFileQueueCommit?,
        debugTiming: DebugTimingContext?
    ) {
        let message = "Could not load \(url.lastPathComponent): \(error.localizedDescription)"
        AppLogger.shared.error(category: "ui", "Load failed: \(error.localizedDescription)")
        lastError = message
        statusMessage = message
        logLocalTransportTiming(
            debugTiming,
            "error shown",
            targetQueueIndex: queueCommit?.index,
            track: queueCommit.flatMap { queueTrack(for: $0.index) },
            fileURL: url,
            extra: ["error=\"\(error.localizedDescription)\""]
        )
        if queueCommit?.isNaturalAdvance == true {
            isPlaying = false
            meterStore.reset()
            monitorMeterStore.reset()
            rendererMeterStore.reset()
            reevaluateAutomaticRendererMode(reason: "load failed")
        }
    }

    private func cancelPendingLocalFileLoad(debugTiming: DebugTimingContext? = nil) {
        let activeTiming = debugTiming ?? activeLocalFileLoadRequest?.debugTiming ?? queuedLocalFileLoadRequest?.debugTiming
        let canceledRequest = queuedLocalFileLoadRequest ?? activeLocalFileLoadRequest
        if localFileLoadDebounceTask != nil {
            cancelLocalFileLoadDebounce(reason: "local load canceled")
        }
        let invalidatedGeneration = currentLocalFileLoadGeneration
        currentLocalFileLoadGeneration &+= 1
        if localFileLoadTask != nil || activeLocalFileLoadRequest != nil || queuedLocalFileLoadRequest != nil {
            logLocalTransportTiming(
                activeTiming,
                "decode canceled",
                targetQueueIndex: canceledRequest?.queueCommit?.index,
                track: canceledRequest?.queueCommit.flatMap { queueTrack(for: $0.index) },
                fileURL: canceledRequest?.url
            )
            logLocalTransportTiming(
                activeTiming,
                "generation invalidated",
                targetQueueIndex: canceledRequest?.queueCommit?.index,
                track: canceledRequest?.queueCommit.flatMap { queueTrack(for: $0.index) },
                fileURL: canceledRequest?.url,
                extra: [
                    "invalidatedGeneration=\(invalidatedGeneration)",
                    "currentGeneration=\(currentLocalFileLoadGeneration)"
                ]
            )
        }
        queuedLocalFileLoadRequest = nil
        readyQueuedLocalFileLoadGeneration = nil
        pendingSessionQueueIndex = nil
        isLocalFileLoading = false
        stopLocalFileLoadStatusTask()
    }

    private func loadLocalMusicDatabase() {
        let database = localMusicLibrary.load()
        localMusicSettings = database.settings
        localMusicTracks = database.tracks
        localMusicPlaylists = database.playlists
        sessionQueue = []
        sessionQueueIndex = nil
        selectedSessionQueueIndex = nil
        pendingSessionQueueIndex = nil
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
        autoplay: Bool,
        isNaturalAdvance: Bool = false,
        debugTiming: DebugTimingContext? = nil
    ) {
        guard !tracks.isEmpty else {
            statusMessage = "No local music matches the current view."
            logLocalTransportTiming(debugTiming, "error shown", extra: ["error=\"No local music matches the current view.\""])
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
        let startIndex = queue.firstIndex { $0.id == startTrack.id } ?? 0
        logLocalTransportTiming(
            debugTiming,
            "UI state updated",
            targetQueueIndex: startIndex,
            track: startTrack,
            extra: ["sessionQueueCount=\(queue.count)", "shuffle=\(shuffle)"]
        )
        _ = loadFile(
            url: startTrack.url,
            autoplay: autoplay,
            queueCommit: LocalFileQueueCommit(index: startIndex, trackID: startTrack.id, isNaturalAdvance: isNaturalAdvance),
            kind: isNaturalAdvance ? .naturalAdvance : (autoplay ? .startingPlayback : .selectedTrack),
            debugTiming: debugTiming
        )
    }

    func skipLocalTransport(offset: Int) {
        let stateBefore = debugPlaybackStateSnapshot()
        defer {
            logTransportDebug(
                command: offset < 0 ? "back" : "forward",
                allowed: !sessionQueue.isEmpty || !localMusicTracks.isEmpty,
                handler: "skipLocalTransport",
                stateBefore: stateBefore,
                stateAfter: debugPlaybackStateSnapshot()
            )
        }
        let prefix = offset < 0 ? "local-back" : "local-forward"
        let debugTiming = DebugTimingLog.makeCommand(prefix: prefix, sourceMode: sourceMode)
        logLocalTransportTiming(
            debugTiming,
            "command received",
            extra: ["command=\"\(offset < 0 ? "back" : "forward")\"", "offset=\(offset)"]
        )
        playQueueOffset(offset, wrap: true, debugTiming: debugTiming)
    }

    private func playQueueOffset(_ offset: Int, wrap: Bool, debugTiming: DebugTimingContext? = nil) {
        if sessionQueue.isEmpty {
            let tracks = visibleLocalMusicTracks
            guard !tracks.isEmpty else {
                statusMessage = "Add a watch folder in Settings, then scan local music."
                logLocalTransportTiming(debugTiming, "error shown", extra: ["error=\"Add a watch folder in Settings, then scan local music.\""])
                return
            }
            startSessionQueue(
                from: tracks,
                startTrackID: tracks.first?.id,
                shuffle: isShuffleEnabled,
                autoplay: true,
                debugTiming: debugTiming
            )
            return
        }

        let currentIndex: Int
        if let pendingSessionQueueIndex, sessionQueue.indices.contains(pendingSessionQueueIndex) {
            currentIndex = pendingSessionQueueIndex
        } else if let sessionQueueIndex, sessionQueue.indices.contains(sessionQueueIndex) {
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
            logLocalTransportTiming(debugTiming, "error shown", targetQueueIndex: nextIndex, extra: ["error=\"End of session queue.\""])
            return
        }

        logLocalTransportTiming(
            debugTiming,
            "target queue index resolved",
            targetQueueIndex: nextIndex,
            track: queueTrack(for: nextIndex)
        )
        playQueueIndex(
            nextIndex,
            kind: offset < 0 ? .previousTrack : .nextTrack,
            startPolicy: .debounced,
            debugTiming: debugTiming
        )
    }

    @discardableResult
    private func playQueueIndex(
        _ index: Int,
        isNaturalAdvance: Bool = false,
        kind: LocalFileLoadKind? = nil,
        startPolicy: LocalFileLoadStartPolicy = .immediate,
        debugTiming: DebugTimingContext? = nil
    ) -> Bool {
        guard sessionQueue.indices.contains(index) else { return false }
        let track = sessionQueue[index]
        let loadKind = kind ?? (isNaturalAdvance ? .naturalAdvance : .selectedTrack)
        logLocalTransportTiming(
            debugTiming,
            "target queue index resolved",
            targetQueueIndex: index,
            track: track,
            extra: ["naturalAdvance=\(isNaturalAdvance)"]
        )
        return loadFile(
            url: track.url,
            autoplay: true,
            queueCommit: LocalFileQueueCommit(index: index, trackID: track.id, isNaturalAdvance: isNaturalAdvance),
            kind: loadKind,
            startPolicy: startPolicy,
            debugTiming: debugTiming
        )
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

        if let pendingIndex = pendingSessionQueueIndex {
            if pendingIndex == sourceIndex {
                pendingSessionQueueIndex = destinationIndex
            } else if pendingIndex == destinationIndex {
                pendingSessionQueueIndex = sourceIndex
            }
        }
    }

    private func refreshSessionQueueIndexForCurrentFile() {
        guard let currentPath = currentFileURL?.path,
              let index = sessionQueue.firstIndex(where: { $0.id == currentPath })
        else {
            sessionQueueIndex = nil
            return
        }

        sessionQueueIndex = index
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
        refreshSpotifyNowPlayingIfNeeded(force: true, reason: "manual spotify input")
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
            liveMonitorState = .silent
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
                refreshSpotifyNowPlayingIfNeeded(force: true, reason: "monitor started")
                refreshSpotifyConnectServerIfNeeded(reason: "monitor started")
            }

            if sourceMode == .roon, inputRoute.isRoonLoopback {
                statusMessage = "Use Roon to send audio to Orbisonic."
            } else if sourceMode == .spotify, inputRoute.isSpotifyLoopback {
                statusMessage = spotifyVisibleNowPlaying == nil
                    ? "Use the Spotify app to connect to \"Orbisonic Spotify\" and press play there."
                    : "Spotify is connected. Press play in Spotify to hear it through Orbisonic."
            } else {
                statusMessage = "Connect an audio source to the selected input."
            }

            AppLogger.shared.notice(
                category: "live-input",
                "Live input active source=\(sourceMode.rawValue) reason=\(reason) input=\(inputRoute.deviceName) uid=\(inputRoute.uid) activeChannels=\(requestedChannelCount)"
            )
        } catch {
            liveMonitorState = .error(error.localizedDescription)
            AppLogger.shared.error(category: "ui", "Live input failed: \(error.localizedDescription)")
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
        let stateBefore = debugPlaybackStateSnapshot()
        var commandAllowed = true
        var commandError: String?
        defer {
            logTransportDebug(
                command: "toggle",
                allowed: commandAllowed,
                handler: "togglePlayback",
                stateBefore: stateBefore,
                stateAfter: debugPlaybackStateSnapshot(),
                error: commandError
            )
        }
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
            commandAllowed = false
            commandError = statusMessage
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
            commandError = error.localizedDescription
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

    func playRoonTransport() {
        sendRoonTransport(.play)
    }

    func pauseRoonTransport() {
        sendRoonTransport(.pause)
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
        startSelectedLiveMonitorNow()
    }

    private func startSelectedLiveMonitorNow() {
        if !isLiveMonitorTransitioning {
            statusMessage = "Preparing \(sourceMode.rawValue) input..."
        }
        switch sourceMode {
        case .off:
            stop()
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

    @discardableResult
    private func rampTransitionOutput(
        to target: Float,
        duration: TimeInterval,
        abortIfNewSourceSwitchPending: Bool = false
    ) async -> Bool {
        let clampedTarget = min(max(target, 0), 1)
        let start = transitionOutputGain
        let steps = max(Int((duration / 0.01).rounded(.up)), 1)

        for step in 1...steps {
            guard !Task.isCancelled else { return false }
            if abortIfNewSourceSwitchPending, sourceSwitchRequests.pendingMode != nil {
                return false
            }
            let progress = Float(step) / Float(steps)
            transitionOutputGain = start + (clampedTarget - start) * progress
            applyEffectiveOutputVolume(log: false)

            if step < steps {
                await sleepForSourceTransition(duration / Double(steps))
            }
        }
        return true
    }

    private func sleepForSourceTransition(_ duration: TimeInterval) async {
        guard duration > 0 else { return }
        do {
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        } catch {
            return
        }
    }

    func muteLiveMonitor() {
        guard sourceMode.isLiveInput, isPlaying else { return }
        guard !isLiveMonitorTransitioning else { return }

        engine.setLiveInputMuted(true)
        liveMonitorState = .muted
        monitorMeterStore.reset()
        rendererMeterStore.reset()
        statusMessage = "\(sourceMode.rawValue) audio muted. Input metering remains active."
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
        statusMessage = "\(sourceMode.rawValue) audio resumed."
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
        markLiveMonitorStopped(sourceName: sourceName)
        engine.stop()
        markLiveMonitorStopped(sourceName: sourceName)
        AppLogger.shared.notice(category: "live-input", "Stopped live monitor source=\(sourceName)")
    }

    private func stopLiveMonitorForSourceSwitch(to mode: SourceMode) {
        guard sourceMode.isLiveInput else { return }

        let sourceName = sourceMode.rawValue
        markLiveMonitorStopped(sourceName: sourceName)
        engine.stop()
        markLiveMonitorStopped(sourceName: sourceName)
        AppLogger.shared.notice(
            category: "live-input",
            "Stopped live monitor source=\(sourceName) before selecting source=\(mode.rawValue)"
        )
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
        liveSignalStatus = "\(sourceName) input stopped."
        liveBufferStatus = "No live buffer."
        statusMessage = "\(sourceName) input stopped."
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
        cancelPendingLocalFileLoad()
        diagnosticReturnContext = nil
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
        switch sourceMode {
        case .off:
            statusMessage = "Orbisonic is idle"
        case .filePlayback:
            statusMessage = "Local playback stopped"
        case .spotify:
            statusMessage = "Spotify playback stopped"
        case .roon:
            statusMessage = "Roon playback stopped"
        case .aux:
            statusMessage = "Aux has no transport"
        case .testTone:
            statusMessage = "Diagnostics stopped."
        }
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
            diagnosticWalkStatus = "Starting Output 2 Renderer channel walk as preview."
            statusMessage = "Output 2 Renderer is not set. Previewing Output 2 Renderer channel walk through \(routeDisplayName)."
        } else {
            diagnosticWalkStatus = "Starting \(kind.shortTitle.lowercased()) channel walk."
            statusMessage = "Running \(kind.shortTitle.lowercased()) channel walk through \(routeDisplayName)."
        }

        AppLogger.shared.notice(
            category: "diagnostics",
            "Started \(kind.title) output=\(outputRoute.deviceName) channels=\(activeDiagnosticChannelCount) localPreview=\(rendererDiagnosticsUsingMonitorPreview) returnSource=\(diagnosticReturnContext?.sourceMode.rawValue ?? "none") wasPlaying=\(diagnosticReturnContext?.wasPlaying ?? false)"
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
            statusMessage = "Output 2 Renderer is not set; using \(fallbackRoute.deviceName) for Output 1 Monitor."
                AppLogger.shared.notice(category: "diagnostics", "Output 2 Renderer diagnostic preview using fallback output=\(fallbackRoute.deviceName)")
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
            AppLogger.shared.warning(category: "diagnostics", "Output 1 Monitor downmix unavailable for Output 2 Renderer diagnostic; no Output 1 Monitor route.")
            return false
        }

        do {
            try engine.setDiagnosticMonitorOutputDevice(monitorOutputRoute.deviceID)
            return true
        } catch {
            AppLogger.shared.warning(category: "diagnostics", "Output 1 Monitor downmix unavailable: \(error.localizedDescription)")
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
                diagnosticWalkStatus = "Playing Output 2 Renderer channel \(index + 1) of \(total) as Output 1 Monitor downmix."
                statusMessage = "Output 2 Renderer channel \(index + 1) preview is active on \(routeDisplayName)."
            } else if usesMonitorDownmix {
                diagnosticWalkStatus = "Playing Output 2 Renderer channel \(index + 1) of \(total) with Output 1 Monitor downmix."
                statusMessage = "Output 2 Renderer channel \(index + 1) is active on \(routeDisplayName); Output 1 Monitor downmix is on \(monitorOutputRoute.deviceName)."
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
        case .off:
            statusMessage = "Diagnostics stopped. Orbisonic is idle."

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
                ? "\(selectedTestTonePoint.pipelineDescription). Output 2 Renderer is \(routeDisplayName); Output 1 Monitor downmix is on \(monitorOutputRoute.deviceName)."
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
                ? "Playing channel \(channel) as Output 1 Monitor downmix."
                : (monitorDownmix ? "Playing channel \(channel) on Output 2 Renderer with Output 1 Monitor downmix." : "Playing channel \(channel) on Output 2 Renderer.")
            statusMessage = rendererDiagnosticsUsingMonitorPreview
                ? "Output 2 Renderer is not set. Channel \(channel) is previewing through \(routeDisplayName)."
                : (monitorDownmix ? "Channel \(channel) tone is active on \(routeDisplayName); Output 1 Monitor downmix is on \(monitorOutputRoute.deviceName)." : "Channel \(channel) tone is active on \(routeDisplayName).")

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
                "Started speaker test tone channel=\(channel)/\(Self.diagnosticSpeakerChannelCount) localPreview=\(rendererDiagnosticsUsingMonitorPreview) output=\(outputRoute.deviceName)"
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
        case .off:
            return "Off"
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
        if sourceMode == .off {
            return "Orbisonic is idle."
        }

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
                return "Synthetic source for Output 1 Monitor and Output 2 Renderer checks."
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
            if let clientName = (spotifyVisibleNowPlaying ?? spotifyNowPlaying)?.clientName?.trimmedNilIfBlank {
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
            return "Output 2 Renderer is not set. Output 2 Renderer VU remains active."
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
                return "Output 2 Renderer selected."
            }
            return "Output 2 Renderer selected."
        case .feedbackLoop(let name):
            return "Blocked: \(name) would feed Orbisonic back into an input loopback."
        case .virtualOutput(let name):
            return "Virtual output: verify \(name) is the intended Output 2 Renderer target."
        case .unavailable:
            return "No verified Output 2 Renderer route."
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
            noneDetail: "Output 1 Monitor disabled",
            safeDetail: monitorOutputRoute.isRendererCapableOutput ? "multichannel output" : "Output 1 Monitor"
        )
    }

    var rendererOutputStatusText: String {
        if rendererOutputSelection == .none {
            return "not set • Output 2 Renderer not selected"
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
            noneDetail: "Output 2 Renderer not selected",
            safeDetail: "Output 2 Renderer selected"
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
        case .off:
            return "Off"
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

        return "Roon is streaming \(formatSampleRate(roonRate)) but \(liveInputSignalName) is \(formatSampleRate(inputRoute.nominalSampleRate)). Set the Roon output and Orbisonic loopback to the same rate, then restart listening."
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
        case .off, .filePlayback, .testTone:
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
        let stateBefore = debugPlaybackStateSnapshot()
        let previousDevice = outputRoute.deviceName
        guard route.isAvailable else {
            statusMessage = "\(purpose.title) output not set."
            logOutputRoutingDebug(
                output: purpose.title,
                previousDevice: previousDevice,
                newDevice: route.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: false,
                error: statusMessage
            )
            return false
        }

        guard route.isSelectableOutputTarget else {
            let message = outputFeedbackMessage(for: route, purpose: purpose)
            statusMessage = message
            lastError = message
            logOutputRoutingDebug(
                output: purpose.title,
                previousDevice: previousDevice,
                newDevice: route.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: false,
                error: message
            )
            return false
        }

        if routesMatch(outputRoute, route) {
            outputRoute = route
            configureMonitorMeters()
            syncRendererAudioRouting()
            statusMessage = "\(purpose.title) output set to \(label)."
            AppLogger.shared.notice(
                category: "route",
                "\(purpose.title) output label=\(label) already active; keeping current audio graph."
            )
            logOutputRoutingDebug(
                output: purpose.title,
                previousDevice: previousDevice,
                newDevice: route.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: false
            )
            return true
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
            logOutputRoutingDebug(
                output: purpose.title,
                previousDevice: previousDevice,
                newDevice: route.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: true
            )
            return true
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Could not select \(label) for \(purpose.lowerTitle)."
            AppLogger.shared.error(category: "route", "\(purpose.title) output selection failed: \(error.localizedDescription)")
            logOutputRoutingDebug(
                output: purpose.title,
                previousDevice: previousDevice,
                newDevice: route.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: true,
                error: error.localizedDescription
            )
            return false
        }
    }

    @discardableResult
    private func applyMonitorOutputRouteIfAvailable(
        _ route: OutputRouteInfo,
        previousDevice: String,
        label: String
    ) -> Bool {
        let stateBefore = debugPlaybackStateSnapshot()
        guard route.isAvailable else {
            statusMessage = "Output 1 Monitor output not set."
            logOutputRoutingDebug(
                output: "Output 1 Monitor",
                previousDevice: previousDevice,
                newDevice: route.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: false,
                error: statusMessage
            )
            return false
        }

        guard route.isSelectableOutputTarget else {
            let message = outputFeedbackMessage(for: route, purpose: .monitor)
            statusMessage = message
            lastError = message
            logOutputRoutingDebug(
                output: "Output 1 Monitor",
                previousDevice: previousDevice,
                newDevice: route.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: false,
                error: message
            )
            return false
        }

        if !shouldPreserveRendererOutputDuringMonitorChange, routesMatch(outputRoute, route) {
            outputRoute = route
            configureMonitorMeters()
            syncRendererAudioRouting()
            statusMessage = "Output 1 Monitor output set to \(label)."
            AppLogger.shared.notice(
                category: "route",
                "Output 1 Monitor output label=\(label) already active; keeping current audio graph."
            )
            logOutputRoutingDebug(
                output: "Output 1 Monitor",
                previousDevice: previousDevice,
                newDevice: route.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: false
            )
            return true
        }

        if shouldPreserveRendererOutputDuringMonitorChange {
            var graphRebuild = false
            var routeApplyError: String?
            if !routesMatch(outputRoute, rendererOutputRoute) {
                do {
                    graphRebuild = try engine.setOutputDevicePreservingPlayback(rendererOutputRoute.deviceID)
                    outputRoute = rendererOutputRoute
                    configureMonitorMeters()
                    syncRendererAudioRouting()
                } catch {
                    routeApplyError = error.localizedDescription
                    lastError = error.localizedDescription
                    statusMessage = "Could not preserve Output 2 Renderer while selecting \(label) for Output 1 Monitor."
                    AppLogger.shared.error(category: "route", statusMessage)
                }
            }

            if routeApplyError == nil {
                statusMessage = "Output 1 Monitor set to \(label). Output 2 Renderer remains \(rendererOutputRoute.deviceName)."
                AppLogger.shared.notice(
                    category: "route",
                    "Selected monitor output label=\(label) device=\(route.deviceName) uid=\(route.uid) while preserving renderer output=\(rendererOutputRoute.deviceName)"
                )
            }

            logOutputRoutingDebug(
                output: "Output 1 Monitor",
                previousDevice: previousDevice,
                newDevice: route.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: graphRebuild,
                error: routeApplyError
            )
            return routeApplyError == nil
        }

        do {
            let graphRebuild = try engine.setOutputDevicePreservingPlayback(route.deviceID)
            outputRoute = route
            configureMonitorMeters()
            syncRendererAudioRouting()
            statusMessage = "Output 1 Monitor output set to \(label)."
            AppLogger.shared.notice(
                category: "route",
                "Selected monitor output label=\(label) device=\(route.deviceName) uid=\(route.uid) channels=\(route.outputChannelCount) sampleRate=\(formatSampleRate(route.nominalSampleRate))"
            )
            logOutputRoutingDebug(
                output: "Output 1 Monitor",
                previousDevice: previousDevice,
                newDevice: route.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: graphRebuild
            )
            return true
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Could not select \(label) for Output 1 Monitor."
            AppLogger.shared.error(category: "route", "Output 1 Monitor selection failed: \(error.localizedDescription)")
            logOutputRoutingDebug(
                output: "Output 1 Monitor",
                previousDevice: previousDevice,
                newDevice: route.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: true,
                error: error.localizedDescription
            )
            return false
        }
    }

    @discardableResult
    private func activateRendererOutputIfMonitorWasActive(previousMonitorRoute: OutputRouteInfo) -> Bool {
        guard rendererOutputRoute.isAvailable,
              routesMatch(outputRoute, previousMonitorRoute)
        else {
            return false
        }

        do {
            let graphRebuild = try engine.setOutputDevicePreservingPlayback(rendererOutputRoute.deviceID)
            outputRoute = rendererOutputRoute
            configureMonitorMeters()
            syncRendererAudioRouting()
            return graphRebuild
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Could not preserve Output 2 Renderer after disabling Output 1 Monitor."
            AppLogger.shared.error(category: "route", statusMessage)
            return true
        }
    }

    private var shouldPreserveRendererOutputDuringMonitorChange: Bool {
        rendererOutputSelection != .none && rendererOutputRoute.isAvailable
    }

    private func routesMatch(_ lhs: OutputRouteInfo, _ rhs: OutputRouteInfo) -> Bool {
        lhs.matchesAudioDevice(rhs)
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
        let stateBefore = debugPlaybackStateSnapshot()
        guard isPlaying else {
            logTransportDebug(
                command: "playback-ended",
                allowed: false,
                handler: "handlePlaybackEnded:ignoredWhenNotPlaying",
                stateBefore: stateBefore,
                stateAfter: debugPlaybackStateSnapshot(),
                error: "ignored because local playback is not playing"
            )
            return
        }

        if playNextLocalMusicTrackAfterNaturalEnd() {
            logTransportDebug(
                command: "playback-ended",
                allowed: true,
                handler: "handlePlaybackEnded:naturalAdvance",
                stateBefore: stateBefore,
                stateAfter: debugPlaybackStateSnapshot()
            )
            return
        }

        isPlaying = false
        meterStore.reset()
        monitorMeterStore.reset()
        rendererMeterStore.reset()
        reevaluateAutomaticRendererMode(reason: "playback ended")
        statusMessage = "Playback finished."
        logTransportDebug(
            command: "playback-ended",
            allowed: true,
            handler: "handlePlaybackEnded:finish",
            stateBefore: stateBefore,
            stateAfter: debugPlaybackStateSnapshot()
        )
    }

    private func playNextLocalMusicTrackAfterNaturalEnd() -> Bool {
        guard sourceMode == .filePlayback else { return false }

        if let sessionQueueIndex, sessionQueue.indices.contains(sessionQueueIndex + 1) {
            return playQueueIndex(sessionQueueIndex + 1, isNaturalAdvance: true)
        }

        guard let currentID = currentFileURL?.path else { return false }
        let tracks = visibleLocalMusicTracks
        guard let currentIndex = tracks.firstIndex(where: { $0.id == currentID }),
              tracks.indices.contains(currentIndex + 1)
        else {
            return false
        }

        startSessionQueue(
            from: tracks,
            startTrackID: tracks[currentIndex + 1].id,
            shuffle: false,
            autoplay: true,
            isNaturalAdvance: true
        )
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
        maintainPersistentHelperServices()

        if sourceMode == .roon {
            refreshRoonNowPlayingIfNeeded()
            repairBlackHoleSampleRateIfNeeded()
        }

        refreshSpotifyNowPlayingIfNeeded(reason: "transport refresh")

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
            let stateBefore = debugPlaybackStateSnapshot()
            let previousDevice = systemOutputRoute.deviceName
            systemOutputRoute = nextSystemOutputRoute
            AppLogger.shared.notice(
                category: "route",
                "System output route changed device=\(nextSystemOutputRoute.deviceName) transport=\(nextSystemOutputRoute.transportName) channels=\(nextSystemOutputRoute.outputChannelCount) target=\(nextSystemOutputRoute.targetName)"
            )
            logOutputRoutingDebug(
                output: "System Output",
                previousDevice: previousDevice,
                newDevice: nextSystemOutputRoute.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: false
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
            let stateBefore = debugPlaybackStateSnapshot()
            let previousDevice = monitorOutputRoute.deviceName
            monitorOutputRoute = nextMonitorOutputRoute
            configureMonitorMeters()
            AppLogger.shared.notice(
                category: "route",
                "Output 1 Monitor route changed device=\(nextMonitorOutputRoute.deviceName) transport=\(nextMonitorOutputRoute.transportName) channels=\(nextMonitorOutputRoute.outputChannelCount) target=\(nextMonitorOutputRoute.targetName)"
            )
            logOutputRoutingDebug(
                output: "Output 1 Monitor",
                previousDevice: previousDevice,
                newDevice: nextMonitorOutputRoute.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: false
            )
        }

        let nextRendererOutputRoute = resolvedRendererOutputRoute(
            from: nextAvailableOutputRoutes,
            systemOutput: nextSystemOutputRoute
        )
        if nextRendererOutputRoute != rendererOutputRoute {
            let stateBefore = debugPlaybackStateSnapshot()
            let previousDevice = rendererOutputRoute.deviceName
            rendererOutputRoute = nextRendererOutputRoute
            configureMonitorMeters()
            configureRendererMeters()
            syncRendererAudioRouting()
            AppLogger.shared.notice(
                category: "route",
                "Output 2 Renderer route changed device=\(nextRendererOutputRoute.deviceName) transport=\(nextRendererOutputRoute.transportName) channels=\(nextRendererOutputRoute.outputChannelCount) target=\(nextRendererOutputRoute.targetName)"
            )
            logOutputRoutingDebug(
                output: "Output 2 Renderer",
                previousDevice: previousDevice,
                newDevice: nextRendererOutputRoute.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: true
            )
        }

        let refreshedActiveRoute = refreshedActiveOutputRoute(from: nextAvailableOutputRoutes)
        if refreshedActiveRoute != outputRoute {
            let stateBefore = debugPlaybackStateSnapshot()
            let previousDevice = outputRoute.deviceName
            outputRoute = refreshedActiveRoute
            configureMonitorMeters()

            var routeApplyError: String?
            var didApplyOutputDevice = false
            if refreshedActiveRoute.isAvailable, !isPlaying, !isTestTonePlaying, !isDiagnosticSequencePlaying {
                do {
                    try engine.setOutputDevice(refreshedActiveRoute.deviceID)
                    didApplyOutputDevice = true
                } catch {
                    routeApplyError = error.localizedDescription
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
                statusMessage = "Load a surround file. Current Output 2 Renderer: \(rendererOutputRoute.deviceName)."
            } else if monitorOutputRoute.isAvailable {
                statusMessage = "Load a surround file. Current Output 1 Monitor: \(monitorOutputRoute.deviceName)."
            } else {
                statusMessage = "Load a surround file. Output 1 Monitor and Output 2 Renderer are not set."
            }
            logOutputRoutingDebug(
                output: "Active Output",
                previousDevice: previousDevice,
                newDevice: refreshedActiveRoute.deviceName,
                playbackStateBefore: stateBefore,
                graphRebuild: didApplyOutputDevice,
                error: routeApplyError
            )
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
            let message = "Live input stopped because macOS output changed to a loopback input. Set output to Output 1 Monitor or Output 2 Renderer, then start the route again."
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
                statusMessage = "Playing through Orbisonic."
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
            statusMessage = "Roon is downmixing quad to stereo before Orbisonic. Change the selected Roon output channel layout to multichannel."
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

    private func startPersistentHelperServices(reason: String, force: Bool = false) {
        guard !Self.isRunningUnitTests else { return }
        refreshRoonBridgeIfNeeded(force: force)
        refreshSpotifyConnectServerIfNeeded(reason: reason, force: force)
    }

    private func maintainPersistentHelperServices() {
        startPersistentHelperServices(reason: "periodic service check")
    }

    private func spotifyTrackIdentity(_ state: SpotifyNowPlaying?) -> String? {
        guard let state else { return nil }
        if let uri = state.uri?.trimmedNilIfBlank {
            return uri
        }

        return [
            state.displayTitle,
            state.artistText,
            state.durationMs.map(String.init) ?? "-"
        ].joined(separator: "|")
    }

    private func clearSpotifyVisibleState(reason: String) {
        spotifyPlaybackStatusDebounceTask?.cancel()
        spotifyPlaybackStatusDebounceTask = nil
        if spotifyVisibleNowPlaying != nil {
            spotifyVisibleNowPlaying = nil
            logSpotifyStatusDebug(
                rawState: spotifyNowPlaying,
                debouncedState: spotifyVisibleNowPlaying,
                reasonForUpdate: reason
            )
        }
    }

    private func updateSpotifyVisibleState(
        from rawState: SpotifyNowPlaying?,
        reason: String,
        forceImmediate: Bool = false
    ) {
        guard sourceMode == .spotify else {
            clearSpotifyVisibleState(reason: "\(reason):inactive source")
            return
        }

        let currentVisible = spotifyVisibleNowPlaying
        let trackChanged = spotifyTrackIdentity(currentVisible) != spotifyTrackIdentity(rawState)
        let playbackChanged = currentVisible?.isPlaying != rawState?.isPlaying
        let shouldDebounce = currentVisible != nil && !trackChanged && playbackChanged && !forceImmediate

        spotifyPlaybackStatusDebounceTask?.cancel()
        spotifyPlaybackStatusDebounceTask = nil

        guard shouldDebounce else {
            if spotifyVisibleNowPlaying != rawState {
                spotifyVisibleNowPlaying = rawState
            }
            logSpotifyStatusDebug(
                rawState: rawState,
                debouncedState: spotifyVisibleNowPlaying,
                reasonForUpdate: forceImmediate ? "\(reason):immediate" : reason
            )
            return
        }

        logSpotifyStatusDebug(
            rawState: rawState,
            debouncedState: currentVisible,
            reasonForUpdate: "\(reason):debounce pending"
        )
        spotifyPlaybackStatusDebounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.spotifyPlaybackStatusDebounceNanoseconds)
            } catch {
                return
            }

            await MainActor.run { [weak self] in
                guard let self, self.sourceMode == .spotify else { return }
                self.spotifyVisibleNowPlaying = rawState
                self.logSpotifyStatusDebug(
                    rawState: self.spotifyNowPlaying,
                    debouncedState: self.spotifyVisibleNowPlaying,
                    reasonForUpdate: "\(reason):debounced"
                )
            }
        }
    }

    private func updateSpotifyNowPlaying(
        _ next: SpotifyNowPlaying?,
        reason: String,
        forceVisible: Bool = false
    ) {
        spotifyNowPlaying = next
        guard sourceMode == .spotify else {
            clearSpotifyVisibleState(reason: "\(reason):inactive source")
            logSpotifyStatusDebug(
                rawState: next,
                debouncedState: spotifyVisibleNowPlaying,
                reasonForUpdate: "\(reason):inactive source"
            )
            return
        }
        updateSpotifyVisibleState(from: next, reason: reason, forceImmediate: forceVisible)
    }

    private func refreshSpotifyNowPlayingIfNeeded(force: Bool = false, reason: String = "periodic refresh") {
        let now = Date()
        guard force || now.timeIntervalSince(lastSpotifyNowPlayingRefreshTime) >= Self.spotifyNowPlayingRefreshInterval else { return }
        lastSpotifyNowPlayingRefreshTime = now

        let next = spotifyReceiverClient.readNowPlaying()
        if next != spotifyNowPlaying {
            updateSpotifyNowPlaying(next, reason: reason, forceVisible: force && sourceMode == .spotify)
        } else if force {
            updateSpotifyVisibleState(from: next, reason: reason, forceImmediate: sourceMode == .spotify)
        }

        if next == nil, spotifyReceiverStatus.isRunning {
            refreshSpotifyConnectServerIfNeeded(reason: "stale now playing")
        }
    }

    private func refreshSpotifyConnectServerIfNeeded(reason: String, force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastSpotifyConnectRefreshTime) >= Self.spotifyConnectRestartDebounce else { return }
        lastSpotifyConnectRefreshTime = now

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

    private func spotifyControlDebugName(_ control: SpotifyReceiverControl) -> String {
        switch control {
        case .playPause:
            return "playPause"
        case .previous:
            return "previous"
        case .next:
            return "next"
        case .seek(let positionMs):
            return "seek:\(positionMs)"
        case .setVolume(let percent):
            return "setVolume:\(percent)"
        }
    }

    private func sendSpotifyControl(_ control: SpotifyReceiverControl) {
        let stateBefore = debugPlaybackStateSnapshot()
        guard sourceMode == .spotify else {
            logTransportDebug(
                command: spotifyControlDebugName(control),
                allowed: false,
                handler: "sendSpotifyControl",
                stateBefore: stateBefore,
                stateAfter: debugPlaybackStateSnapshot(),
                error: "source is \(sourceMode.rawValue)"
            )
            return
        }
        if spotifyReceiverClient.send(control) {
            refreshSpotifyNowPlayingIfNeeded(force: true, reason: "spotify control sent")
            statusMessage = "Sent Spotify Connect control."
            logTransportDebug(
                command: spotifyControlDebugName(control),
                allowed: true,
                handler: "sendSpotifyControl",
                stateBefore: stateBefore,
                stateAfter: debugPlaybackStateSnapshot()
            )
        } else {
            statusMessage = "Spotify Connect control is not available in this build or the receiver is not active."
            refreshSpotifyConnectServerIfNeeded(reason: "control failed", force: true)
            logTransportDebug(
                command: spotifyControlDebugName(control),
                allowed: true,
                handler: "sendSpotifyControl",
                stateBefore: stateBefore,
                stateAfter: debugPlaybackStateSnapshot(),
                error: "spotify receiver control unavailable"
            )
        }
    }

    private func sendRoonTransport(_ control: RoonBridgeControl) {
        let stateBefore = debugPlaybackStateSnapshot()
        guard sourceMode == .roon else {
            logTransportDebug(
                command: control.rawValue,
                allowed: false,
                handler: "sendRoonTransport",
                stateBefore: stateBefore,
                stateAfter: debugPlaybackStateSnapshot(),
                error: "source is \(sourceMode.rawValue)"
            )
            return
        }
        guard !isRoonTransportCommandInFlight else {
            logTransportDebug(
                command: control.rawValue,
                allowed: false,
                handler: "sendRoonTransport",
                stateBefore: stateBefore,
                stateAfter: debugPlaybackStateSnapshot(),
                error: "roon command already in flight"
            )
            return
        }
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
                logTransportDebug(
                    command: control.rawValue,
                    allowed: true,
                    handler: "sendRoonTransport",
                    stateBefore: stateBefore,
                    stateAfter: debugPlaybackStateSnapshot()
                )
            } catch {
                applyRoonBridgeError(error)
                statusMessage = error.localizedDescription
                lastError = error.localizedDescription
                AppLogger.shared.error(category: "roon-bridge", "Transport control failed control=\(control.rawValue) error=\(error.localizedDescription)")
                logTransportDebug(
                    command: control.rawValue,
                    allowed: true,
                    handler: "sendRoonTransport",
                    stateBefore: stateBefore,
                    stateAfter: debugPlaybackStateSnapshot(),
                    error: error.localizedDescription
                )
            }
        }
    }

    private func applyRoonBridgeSnapshot(_ snapshot: RoonBridgeSnapshot) {
        if snapshot != roonBridgeSnapshot {
            roonBridgeSnapshot = snapshot
            updateRoonArtwork(for: snapshot, reason: "bridge snapshot")
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
        } else {
            updateRoonArtwork(for: snapshot, reason: "bridge snapshot unchanged")
        }
    }

    private func updateRoonArtwork(for snapshot: RoonBridgeSnapshot, reason: String) {
        guard let request = snapshot.selectedZone?.nowPlaying?.artworkRequest else {
            roonArtworkFetchTask?.cancel()
            roonArtworkFetchTask = nil
            roonArtworkRequestedKey = nil
            let signature = [
                snapshot.selectedZoneId ?? "no-zone",
                snapshot.selectedZone?.titleText ?? "no-title",
                snapshot.selectedZone?.subtitleText ?? "no-subtitle"
            ].joined(separator: "|")
            if signature != lastLoggedRoonArtworkMissingSignature {
                lastLoggedRoonArtworkMissingSignature = signature
                AppLogger.shared.debug(category: "roon-artwork", "No Roon artwork key available reason=\(reason)")
            }
            return
        }

        lastLoggedRoonArtworkMissingSignature = nil

        if let cachedURL = roonArtworkCache.cachedURL(for: request.stableKey) {
            roonArtworkFetchTask?.cancel()
            roonArtworkFetchTask = nil
            roonArtworkRequestedKey = request.stableKey
            if roonArtworkURL != cachedURL {
                roonArtworkURL = cachedURL
                AppLogger.shared.notice(
                    category: "roon-artwork",
                    "Loaded cached Roon artwork title=\(request.title) key=\(request.stableKey)"
                )
            }
            return
        }

        if roonArtworkRequestedKey == request.stableKey, roonArtworkFetchTask != nil {
            return
        }

        if roonArtworkFailedKeys.contains(request.stableKey) {
            AppLogger.shared.debug(category: "roon-artwork", "Skipping previously failed Roon artwork key=\(request.stableKey)")
            return
        }

        roonArtworkFetchTask?.cancel()
        roonArtworkRequestedKey = request.stableKey
        roonArtworkFetchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let data = try await roonBridgeClient.fetchImageDataStartingIfNeeded(for: request.imageKey)
                guard !Task.isCancelled else { return }
                let cachedURL = try roonArtworkCache.store(data, for: request.stableKey)
                guard roonArtworkRequestedKey == request.stableKey else { return }
                roonArtworkURL = cachedURL
                roonArtworkFetchTask = nil
                roonArtworkFailedKeys.remove(request.stableKey)
                AppLogger.shared.notice(
                    category: "roon-artwork",
                    "Fetched Roon artwork title=\(request.title) key=\(request.stableKey) bytes=\(data.count)"
                )
            } catch {
                guard !Task.isCancelled else { return }
                if roonArtworkRequestedKey == request.stableKey {
                    roonArtworkFetchTask = nil
                    roonArtworkFailedKeys.insert(request.stableKey)
                }
                AppLogger.shared.warning(
                    category: "roon-artwork",
                    "Roon artwork fetch failed title=\(request.title) key=\(request.stableKey) error=\(error.localizedDescription)"
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
