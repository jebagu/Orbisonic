import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

struct ChannelMeter: Identifiable {
    let channel: SurroundChannel
    var level: Float

    var id: String { channel.id }
}

enum SourceMode: String, CaseIterable, Identifiable {
    case roonBlackHole = "Roon"
    case testTone = "Test Tone"
    case filePlayback = "Local Player"
    case blackHoleOtherInput = "BlackHole / Other Input"

    var id: String { rawValue }

    var isLiveInput: Bool {
        self == .roonBlackHole || self == .blackHoleOtherInput
    }
}

enum PlaylistSortMode: String, CaseIterable, Identifiable {
    case name = "Name"
    case artist = "Artist"
    case album = "Album"

    var id: String { rawValue }
}

private struct DiagnosticReturnContext {
    let sourceMode: SourceMode
    let wasPlaying: Bool
    let progress: Double
    let hadSource: Bool
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

@MainActor
final class OrbisonicViewModel: ObservableObject {
    private static let selectedInputDeviceUIDKey = "Orbisonic.selectedInputDeviceUID"

    @Published var preset: SpatialPreset = .defaultPreset {
        didSet {
            applyPreset(preset)
        }
    }

    @Published private(set) var rendererPresets: [RendererPreset] = [.sonicSphere30Point1]
    @Published private(set) var rendererPreset: RendererPreset = .sonicSphere30Point1
    @Published var rendererBedRadius: Double = RendererPreset.sonicSphere30Point1.inputGeometry.bedRadius {
        didSet {
            guard !suppressRendererPublish else { return }
            updateRendererBedRadius(rendererBedRadius)
        }
    }
    @Published private(set) var rendererScene: RendererSceneModel = .empty
    @Published private(set) var rendererPresetStatus = "Renderer presets have not loaded yet."
    @Published private(set) var rendererPresetDirectoryText = ""
    @Published private(set) var rendererPresetIsDirty = false

    @Published var frontAngle: Double = SpatialTuning.default.frontAngle {
        didSet { if !suppressTuningPublish { publishTuning() } }
    }

    @Published var rearAngle: Double = SpatialTuning.default.rearAngle {
        didSet { if !suppressTuningPublish { publishTuning() } }
    }

    @Published var headTrackingEnabled: Bool = SpatialTuning.default.headTrackingEnabled {
        didSet { if !suppressTuningPublish { publishTuning() } }
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
    @Published var lastError: String?
    @Published private(set) var outputRoute: OutputRouteInfo = .unavailable
    @Published private(set) var inputRoute: InputRouteInfo = .unavailable
    @Published private(set) var systemInputRoute: InputRouteInfo = .unavailable
    @Published private(set) var availableInputRoutes: [InputRouteInfo] = []
    @Published var sourceMode: SourceMode = .filePlayback
    @Published var activeLiveChannelCount = 8
    @Published var liveSignalStatus = "No live input."
    @Published var liveBufferStatus = "No live buffer."
    @Published var selectedTestTonePoint: TestTonePipelinePoint = .directOutput
    @Published var isTestTonePlaying = false
    @Published var testToneStatus = "No diagnostic tone playing."
    @Published var activeDiagnosticPoint: TestTonePipelinePoint?
    @Published var diagnosticSequencePosition = 0
    @Published var isDiagnosticSequencePlaying = false
    @Published private(set) var roonNowPlaying: RoonNowPlaying?
    @Published private(set) var roonNowPlayingStatus = "Roon metadata not requested yet."
    @Published private(set) var roonSignalPath: RoonSignalPath?
    @Published private(set) var localMusicSettings = LocalMusicSettings()
    @Published private(set) var localMusicTracks: [LocalMusicTrack] = []
    @Published private(set) var localMusicPlaylists: [LocalMusicPlaylist] = []
    @Published var selectedLocalMusicTrackID: String?
    @Published var selectedLocalMusicPlaylistID: String?
    @Published var localMusicSearchText = ""
    @Published var localMusicSortMode: PlaylistSortMode = .name
    @Published private(set) var sessionQueue: [LocalMusicTrack] = []
    @Published private(set) var sessionQueueIndex: Int?
    @Published var isShuffleEnabled = false

    let meterStore = ChannelMeterStore()
    let monitorMeterStore = ChannelMeterStore()
    let rendererMeterStore = ChannelMeterStore()

    private let engine = OrbisonicEngine()
    private let localMusicLibrary = LocalMusicLibrary()
    private let rendererPresetStore = RendererPresetStore()
    private let roonNowPlayingReader = RoonNowPlayingReader()
    private var refreshTimer: Timer?
    private var lastHeartbeatSecond: Int = -1
    private var lastLiveMeterLogSecond: Int = -1
    private var lastLiveBufferLogSecond: Int = -1
    private var lastLiveSilenceWarningSecond: Int = -1
    private var lastLiveSignalPresent: Bool?
    private var testToneStopTask: Task<Void, Never>?
    private var diagnosticSequenceTask: Task<Void, Never>?
    private var diagnosticReturnContext: DiagnosticReturnContext?
    private var localMusicScanTask: Task<Void, Never>?
    private var lastRouteRefreshTime = Date.distantPast
    private var lastRoonNowPlayingRefreshTime = Date.distantPast
    private var lastBlackHoleSampleRateRepairTime = Date.distantPast
    private var selectedInputDeviceUID = UserDefaults.standard.string(forKey: OrbisonicViewModel.selectedInputDeviceUIDKey)
    private var suppressTuningPublish = false
    private var suppressRendererPublish = false

    init() {
        AppLogger.shared.notice(category: "view-model", "View model initialized.")

        engine.onPlaybackEnded = { [weak self] in
            self?.handlePlaybackEnded()
        }

        applyPreset(.defaultPreset, pushToEngine: false)
        loadRendererPresets()
        loadLocalMusicDatabase()
        refreshRoutesIfNeeded(force: true)
        configureMonitorMeters()
        configureRendererMeters()

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.refreshTransport()
            }
        }
        timer.tolerance = 1.0 / 120.0
        refreshTimer = timer
    }

    deinit {
        testToneStopTask?.cancel()
        diagnosticSequenceTask?.cancel()
        localMusicScanTask?.cancel()
        refreshTimer?.invalidate()
    }

    func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.audio]

        guard panel.runModal() == .OK, let url = panel.url else {
            AppLogger.shared.debug(category: "ui", "Open file panel dismissed.")
            return
        }

        AppLogger.shared.info(category: "ui", "Selected file: \(url.path)")

        loadFile(url: url, autoplay: false)
    }

    func selectSourceMode(_ mode: SourceMode) {
        guard mode != sourceMode else { return }

        if isPlaying || isTestTonePlaying || isDiagnosticSequencePlaying {
            stop()
        }

        sourceMode = mode

        switch mode {
        case .filePlayback:
            liveSignalStatus = "No live input."
            liveBufferStatus = "No live buffer."
            roonNowPlayingStatus = "Roon metadata is only shown for live Roon input."
            roonSignalPath = nil
            statusMessage = sourceMetadata == nil
                ? "Open a local multichannel file or scan watch folders in Settings."
                : "Local player source is ready."
        case .roonBlackHole:
            currentFileURL = nil
            selectPreferredBlackHoleInputIfAvailable()
            statusMessage = "Roon is selected. Start Roon when the source is playing."
        case .testTone:
            liveSignalStatus = "No live input."
            liveBufferStatus = "No live buffer."
            roonNowPlayingStatus = "Roon metadata is only shown for live Roon input."
            roonSignalPath = nil
            statusMessage = "Test tone source is ready. Use the Routing tab to play the selected tone."
        case .blackHoleOtherInput:
            currentFileURL = nil
            roonNowPlayingStatus = "Roon metadata is only shown for live Roon input."
            roonSignalPath = nil
            statusMessage = "Using \(inputRoute.displayName) as Orbisonic's live source. macOS system input remains separate."
        }
    }

    func selectInputRoute(_ route: InputRouteInfo) {
        guard route.isAvailable else { return }

        if sourceMode == .roonBlackHole, !route.isBlackHole {
            if isPlaying {
                stop()
            }
            statusMessage = "Roon mode captures BlackHole only. Switch to BlackHole / Other Input to capture \(route.deviceName)."
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
        guard let track = selectedLocalMusicTrack ?? currentLocalMusicTrack ?? visibleLocalMusicTracks.first else {
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

    func playNextLocalMusicTrack() {
        playQueueOffset(1, wrap: true)
    }

    func playPreviousLocalMusicTrack() {
        playQueueOffset(-1, wrap: true)
    }

    func selectSessionQueueIndex(_ index: Int) {
        guard sessionQueue.indices.contains(index) else { return }
        sessionQueueIndex = index
        selectedLocalMusicTrackID = sessionQueue[index].id
    }

    func playSelectedSessionQueueTrack() {
        if let sessionQueueIndex, sessionQueue.indices.contains(sessionQueueIndex) {
            if currentFileURL?.path == sessionQueue[sessionQueueIndex].id, sourceMode == .filePlayback {
                togglePlayback()
                return
            }
            playQueueIndex(sessionQueueIndex)
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
            selectedLocalMusicTrackID = tracks[0].id
        }

        statusMessage = "Added \(tracks.count) track\(tracks.count == 1 ? "" : "s") from \(playlist.name) to the session queue."
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
        } else if let currentIndex = sessionQueueIndex {
            if currentIndex == index {
                sessionQueueIndex = min(index, sessionQueue.count - 1)
            } else if index < currentIndex {
                sessionQueueIndex = currentIndex - 1
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

    var localMusicArtworkStatusText: String {
        let count = localMusicTracks.filter { $0.artworkPath != nil }.count
        return "\(count) tracks with cached artwork."
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

        do {
            let loaded = try engine.loadFile(url: url)
            loadedFileName = loaded.url.lastPathComponent
            currentFileURL = loaded.url
            if localMusicTracks.contains(where: { $0.id == loaded.url.path }) {
                selectedLocalMusicTrackID = loaded.url.path
            }
            sourceMetadata = loaded.metadata
            loadedChannels = loaded.layout.channels
            refreshRendererScene()
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
                try engine.play()
                isPlaying = true
                statusMessage = "Playing \(loaded.metadata.fileName) through \(routeDisplayName)."
            } else if outputRoute.isAvailable {
                statusMessage = "Loaded \(loaded.metadata.fileName). Ready to render through \(outputRoute.deviceName)."
            } else {
                statusMessage = "Loaded \(loaded.metadata.fileName). Verify the macOS output route before playback."
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
    }

    func startRoonPipe() {
        cancelDiagnosticsForMusicAction()
        sourceMode = .roonBlackHole
        currentFileURL = nil
        refreshRoutesIfNeeded(force: true)
        refreshRoonNowPlayingIfNeeded(force: true)
        selectPreferredBlackHoleInputIfAvailable()

        guard inputRoute.isBlackHole else {
            let message = "Choose BlackHole 64ch as Orbisonic's input before starting the Roon pipe. macOS system input can stay on \(systemInputRoute.displayName)."
            AppLogger.shared.error(category: "ui", message)
            statusMessage = message
            lastError = message
            return
        }

        guard !outputRoute.isBlackHole else {
            let message = "Set macOS Sound Output to your headphones before starting. Output is currently \(outputRoute.deviceName), which would route the render back into BlackHole."
            AppLogger.shared.error(category: "ui", message)
            statusMessage = message
            lastError = message
            return
        }

        repairBlackHoleSampleRateIfNeeded(force: true)
        BlackHoleRouteRepair.prepareInputDeviceForCapture(inputRoute, preferredSampleRate: roonNowPlaying?.outputSampleRate)
        refreshRoutesIfNeeded(force: true)
        startLiveInputForCurrentRoute(reason: "manual")
        refreshRoonNowPlayingIfNeeded(force: true)
    }

    func startOtherInputPipe() {
        cancelDiagnosticsForMusicAction()
        sourceMode = .blackHoleOtherInput
        currentFileURL = nil
        roonNowPlaying = nil
        roonSignalPath = nil
        refreshRoutesIfNeeded(force: true)

        guard inputRoute.isAvailable else {
            let message = "No Orbisonic live input route is available. Choose BlackHole, a mic, or another input in the app."
            AppLogger.shared.error(category: "ui", message)
            statusMessage = message
            lastError = message
            return
        }

        guard !outputRoute.isBlackHole else {
            let message = "Set macOS Sound Output to a monitor or renderer target before starting. Output is currently BlackHole."
            AppLogger.shared.error(category: "ui", message)
            statusMessage = message
            lastError = message
            return
        }

        startLiveInputForCurrentRoute(reason: "manual other input")
    }

    private func startLiveInputForCurrentRoute(reason: String) {
        let requestedChannelCount = preferredLiveChannelCount()

        do {
            let liveSource = try engine.startLiveInput(
                activeChannelCount: requestedChannelCount,
                inputRoute: inputRoute,
                sourceName: liveInputSourceName
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
            lastHeartbeatSecond = -1
            lastLiveMeterLogSecond = -1
            lastLiveBufferLogSecond = -1
            lastLiveSilenceWarningSecond = -1
            lastLiveSignalPresent = nil
            liveSignalStatus = "Waiting for signal from \(liveInputSignalName)."
            liveBufferStatus = "Priming live buffer."
            refreshRoonNowPlayingIfNeeded(force: true)

            if sourceMode == .roonBlackHole, inputRoute.isBlackHole {
                statusMessage = "Capturing Roon and rendering to \(routeDisplayName)."
            } else {
                statusMessage = "Capturing \(inputRoute.deviceName) and rendering to \(routeDisplayName). System input remains \(systemInputRoute.displayName)."
            }

            AppLogger.shared.notice(
                category: "live-input",
                "Live input active reason=\(reason) input=\(inputRoute.deviceName) activeChannels=\(requestedChannelCount)"
            )
        } catch {
            AppLogger.shared.error(category: "ui", "Roon pipe failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    func togglePlayback() {
        cancelDiagnosticsForMusicAction()

        if sourceMode == .roonBlackHole {
            if isPlaying {
                stop()
            } else {
                startRoonPipe()
            }
            return
        }

        if sourceMode == .blackHoleOtherInput {
            if isPlaying {
                stop()
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
                statusMessage = "Paused."
            } else {
                try engine.play()
                isPlaying = true
                if headTrackingEnabled {
                    statusMessage = "Playing through \(routeDisplayName) with head tracking requested."
                } else {
                    statusMessage = "Playing through \(routeDisplayName) with fixed spatial rendering."
                }
            }
        } catch {
            AppLogger.shared.error(category: "ui", "Playback toggle failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    func stop() {
        testToneStopTask?.cancel()
        testToneStopTask = nil
        diagnosticSequenceTask?.cancel()
        diagnosticSequenceTask = nil
        diagnosticReturnContext = nil
        engine.stop()
        isPlaying = false
        isTestTonePlaying = false
        isDiagnosticSequencePlaying = false
        activeDiagnosticPoint = nil
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
        testToneStatus = "No diagnostic tone playing."
        roonNowPlayingStatus = "Roon metadata stopped."
        roonSignalPath = nil
        currentFileURL = sourceMode == .filePlayback ? currentFileURL : nil
        statusMessage = "Stopped."
    }

    var diagnosticToneSequence: [TestTonePipelinePoint] {
        TestTonePipelinePoint.channelWalkPoints
    }

    var activeDiagnosticText: String {
        if let activeDiagnosticPoint {
            return "\(diagnosticSequencePosition) / \(diagnosticToneSequence.count): \(activeDiagnosticPoint.rawValue)"
        }

        return isDiagnosticSequencePlaying ? "Starting diagnostics..." : "Ready."
    }

    func startDiagnosticChannelWalk() {
        refreshRoutesIfNeeded(force: true)

        guard !outputRoute.isBlackHole else {
            let message = "Set macOS Sound Output to your headphones before running diagnostics. Output is currently BlackHole."
            AppLogger.shared.error(category: "diagnostics", message)
            statusMessage = message
            lastError = message
            return
        }

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
        activeDiagnosticPoint = nil
        diagnosticSequencePosition = 0
        testToneStatus = "Starting channel walk."
        statusMessage = "Running diagnostic channel walk through \(routeDisplayName)."

        AppLogger.shared.notice(
            category: "diagnostics",
            "Started diagnostic channel walk output=\(outputRoute.deviceName) returnSource=\(diagnosticReturnContext?.sourceMode.rawValue ?? "none") wasPlaying=\(diagnosticReturnContext?.wasPlaying ?? false)"
        )

        diagnosticSequenceTask = Task { [weak self] in
            let points = TestTonePipelinePoint.channelWalkPoints

            for (index, point) in points.enumerated() {
                let shouldContinue = await MainActor.run {
                    self?.playDiagnosticPoint(point, index: index, total: points.count) ?? false
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

    func stopDiagnosticsAndReturnToMusic() {
        finishDiagnosticChannelWalk(restoreMusic: true, automatic: false)
    }

    private func playDiagnosticPoint(
        _ point: TestTonePipelinePoint,
        index: Int,
        total: Int
    ) -> Bool {
        guard isDiagnosticSequencePlaying else { return false }

        do {
            try engine.playTestTone(point)
            activeDiagnosticPoint = point
            diagnosticSequencePosition = index + 1
            testToneStatus = "Playing \(point.rawValue) for 1.5 seconds."
            statusMessage = "\(point.pipelineDescription). Listen on \(routeDisplayName)."

            let channels = point.meterChannels
            meterStore.configure(channels: channels)
            meterStore.update(with: Array(repeating: 0.82, count: channels.count))
            updateMonitorMeters()
            updateRendererMeters(from: Array(repeating: 0.82, count: rendererScene.matrix.inputCount))

            AppLogger.shared.notice(
                category: "diagnostics",
                "Diagnostic point \(index + 1)/\(total) point=\(point.rawValue) route=\(point.pipelineDescription)"
            )
            return true
        } catch {
            AppLogger.shared.error(category: "diagnostics", "Diagnostic point failed: \(error.localizedDescription)")
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
        diagnosticSequencePosition = 0
        meterStore.reset()
        monitorMeterStore.reset()
        rendererMeterStore.reset()
        testToneStatus = automatic ? "Diagnostic channel walk finished." : "Diagnostic channel walk stopped."

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

        case .roonBlackHole:
            guard context.wasPlaying else {
                statusMessage = "Diagnostics stopped. Roon route is ready."
                return
            }

            startRoonPipe()

        case .testTone:
            statusMessage = "Diagnostics stopped. Test tone source is ready."

        case .blackHoleOtherInput:
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

        guard !outputRoute.isBlackHole else {
            let message = "Set macOS Sound Output to your headphones before running a test tone. Output is currently BlackHole."
            AppLogger.shared.error(category: "diagnostics", message)
            statusMessage = message
            lastError = message
            return
        }

        if isPlaying {
            stop()
        } else {
            stopTestTone()
        }

        do {
            try engine.playTestTone(selectedTestTonePoint)
            isTestTonePlaying = true
            testToneStatus = "Playing \(selectedTestTonePoint.rawValue) for 3 seconds."
            statusMessage = "\(selectedTestTonePoint.pipelineDescription). Listen on \(routeDisplayName)."

            let channels = selectedTestTonePoint.meterChannels
            meterStore.configure(channels: channels)
            meterStore.update(with: Array(repeating: 0.82, count: channels.count))
            updateMonitorMeters()
            updateRendererMeters(from: Array(repeating: 0.82, count: rendererScene.matrix.inputCount))

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

    func stopTestTone(automatic: Bool = false) {
        testToneStopTask?.cancel()
        testToneStopTask = nil
        engine.stopTestTone()

        guard isTestTonePlaying else { return }

        isTestTonePlaying = false
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
            rearAngle: rearAngle,
            headTrackingEnabled: headTrackingEnabled
        )
    }

    func selectRendererPreset(_ preset: RendererPreset) {
        applyRendererPreset(preset, markDirty: false)
        statusMessage = "Selected renderer preset \(preset.name)."
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
        case .roonBlackHole:
            return "Roon"
        case .testTone:
            return "Test Tone"
        case .filePlayback:
            return sourceMetadata?.fileName ?? "Local Player"
        case .blackHoleOtherInput:
            return inputRoute.isBlackHole ? "BlackHole Input" : "Other Input"
        }
    }

    var sourceFlowDetail: String {
        if sourceMode == .roonBlackHole {
            if let roonNowPlaying {
                return "\(roonNowPlaying.titleLine) • \(liveSignalStatus) • \(liveBufferStatus)"
            }
            return "\(liveSignalStatus) • \(liveBufferStatus)"
        }

        if sourceMode == .blackHoleOtherInput {
            let routeText = inputRoute.isAvailable ? inputRoute.detail : "No selected input."
            return "\(routeText) • \(liveSignalStatus) • \(liveBufferStatus)"
        }

        if sourceMode == .testTone {
            return "\(selectedTestTonePoint.rawValue) • \(testToneStatus)"
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

        if sourceMode == .roonBlackHole {
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
            return sourceMode.isLiveInput ? inputRoute.roonReadiness : "No source loaded."
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

    var inputNowText: String {
        inputRoute.isAvailable ? "\(inputRoute.displayName) • \(inputRoute.detail)" : inputRoute.roonReadiness
    }

    var systemInputNowText: String {
        systemInputRoute.isAvailable ? "\(systemInputRoute.displayName) • \(systemInputRoute.detail)" : "No verified macOS system input"
    }

    var roonZoneText: String {
        "Roon"
    }

    var availableLiveChannelCounts: [Int] {
        let available = min(inputRoute.inputChannelCount, OrbisonicAudioLimits.maxSourceChannelCount)
        guard available > 0 else {
            return [2, 4, 6, 8]
        }

        let common = [2, 4, 6, 8, 10, 11, 12, 14, 16, 24, 30, 32, 52, 64]
        let filtered = common.filter { $0 <= available }

        if filtered.contains(available) {
            return filtered
        }

        return (filtered + [available]).sorted()
    }

    var rendererText: String {
        guard rendererScene.matrix.inputCount > 0 else {
            return "\(rendererPreset.name) • waiting for source"
        }
        return "\(rendererPreset.name) • \(rendererScene.matrix.inputCount)x\(rendererScene.matrix.outputCount) matrix"
    }

    var rendererTargetText: String {
        rendererPreset.outputTopology.kind == .sonicSphere ? "Sonic Sphere" : "Sound System"
    }

    var rendererLayoutText: String {
        "\(rendererPreset.outputTopology.fullRangeCount).\(rendererPreset.outputTopology.lfeCount) • \(rendererScene.outputSpeakers.count) outputs"
    }

    var rendererSelectionText: String {
        "\(rendererTargetText) • \(rendererLayoutText)"
    }

    private var routeDisplayName: String {
        outputRoute.isAvailable ? outputRoute.deviceName : "the current macOS output"
    }

    private var liveInputSourceName: String {
        switch sourceMode {
        case .roonBlackHole:
            return "Roon"
        case .blackHoleOtherInput:
            return inputRoute.isBlackHole ? "BlackHole Input" : "\(inputRoute.deviceName) Input"
        case .filePlayback:
            return "Local Player"
        case .testTone:
            return "Test Tone"
        }
    }

    private var liveInputSignalName: String {
        inputRoute.isBlackHole ? "BlackHole" : inputRoute.deviceName
    }

    private var roonBlackHoleSampleRateMismatchText: String? {
        guard let roonRate = roonNowPlaying?.outputSampleRate, inputRoute.nominalSampleRate > 0 else {
            return nil
        }

        guard abs(roonRate - inputRoute.nominalSampleRate) > 1 else {
            return nil
        }

        return "Roon is streaming \(formatSampleRate(roonRate)) but BlackHole input is \(formatSampleRate(inputRoute.nominalSampleRate)). Set BlackHole 64ch input and output to the same rate in Audio MIDI Setup, then restart the Roon pipe."
    }

    private var roonBlackHoleSampleRateMismatch: Double? {
        guard let roonRate = roonNowPlaying?.outputSampleRate,
              inputRoute.isBlackHole,
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
        let available = max(min(inputRoute.inputChannelCount, OrbisonicAudioLimits.maxSourceChannelCount), 1)

        if inputRoute.isBlackHole, activeLiveChannelCount <= 1, available >= 8 {
            return 8
        }

        return min(max(activeLiveChannelCount, 1), available)
    }

    @discardableResult
    private func selectPreferredBlackHoleInputIfAvailable() -> Bool {
        guard let blackHoleRoute = availableInputRoutes.first(where: \.isBlackHole) else {
            return false
        }

        if inputRoute.deviceID != blackHoleRoute.deviceID {
            selectInputRoute(blackHoleRoute)
        }

        return true
    }

    private func resolvedSelectedInputRoute(
        from routes: [InputRouteInfo],
        systemInput: InputRouteInfo
    ) -> InputRouteInfo {
        if let selectedInputDeviceUID,
           let persistedRoute = routes.first(where: { $0.uid == selectedInputDeviceUID }) {
            return persistedRoute
        }

        if inputRoute.isAvailable,
           let existingRoute = routes.first(where: { $0.uid == inputRoute.uid || $0.deviceID == inputRoute.deviceID }) {
            return existingRoute
        }

        if let blackHoleRoute = routes.first(where: \.isBlackHole) {
            return blackHoleRoute
        }

        if systemInput.isAvailable,
           let route = routes.first(where: { $0.uid == systemInput.uid || $0.deviceID == systemInput.deviceID }) {
            return route
        }

        return routes.first ?? .unavailable
    }

    private func applyLiveChannelDefaults(for route: InputRouteInfo) {
        let available = max(min(route.inputChannelCount, OrbisonicAudioLimits.maxSourceChannelCount), 1)

        if activeLiveChannelCount > available {
            activeLiveChannelCount = available
        }

        if route.isBlackHole, activeLiveChannelCount <= 1, available >= 8 {
            activeLiveChannelCount = 8
        }
    }

    private func handlePlaybackEnded() {
        if playNextLocalMusicTrackAfterNaturalEnd() {
            return
        }

        isPlaying = false
        meterStore.reset()
        monitorMeterStore.reset()
        rendererMeterStore.reset()
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
            let comparison = lhsValue.localizedStandardCompare(rhsValue)
            if comparison == .orderedAscending { return true }
            if comparison == .orderedDescending { return false }
        }

        return lhs.fileName.localizedStandardCompare(rhs.fileName) == .orderedAscending
    }

    private func refreshTransport() {
        refreshRoutesIfNeeded()

        if sourceMode == .roonBlackHole {
            refreshRoonNowPlayingIfNeeded()
            repairBlackHoleSampleRateIfNeeded()
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
            meterStore.update(with: levels)
            updateMonitorMeters()
            updateRendererMeters(from: levels)

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
        updateMonitorMeters()
        updateRendererMeters(from: levels)
    }

    private func refreshRoutesIfNeeded(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastRouteRefreshTime) >= 1.0 else { return }
        lastRouteRefreshTime = now

        let nextRoute = OutputRouteMonitor.currentRoute()
        if nextRoute != outputRoute {
            outputRoute = nextRoute
            configureMonitorMeters()
            AppLogger.shared.notice(
                category: "route",
                "Default output route changed device=\(nextRoute.deviceName) transport=\(nextRoute.transportName) channels=\(nextRoute.outputChannelCount) target=\(nextRoute.targetName)"
            )

            if isPlaying {
                statusMessage = "Playing through \(routeDisplayName)."
            } else if let metadata = sourceMetadata {
                statusMessage = "Loaded \(metadata.fileName). Current route: \(routeDisplayName)."
            } else if outputRoute.isAvailable {
                statusMessage = "Load a surround file. Current macOS output: \(routeDisplayName)."
            } else {
                statusMessage = "Load a surround file. The active macOS output route will appear below."
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

            if sourceMode.isLiveInput, isPlaying, previousInputRoute.deviceID != nextInputRoute.deviceID {
                if sourceMode == .roonBlackHole, !nextInputRoute.isBlackHole {
                    stop()
                    statusMessage = "Live input stopped because the selected BlackHole route is unavailable. The macOS system input is still \(systemInputRoute.displayName)."
                } else if nextInputRoute.isAvailable {
                    startLiveInputForCurrentRoute(reason: "selected input route changed")
                } else {
                    stop()
                    statusMessage = "Live input stopped because the selected Orbisonic input is unavailable."
                }
            }
        }

        if sourceMode.isLiveInput, isPlaying, outputRoute.isBlackHole {
            stop()
            let message = "Live input stopped because macOS output changed to BlackHole. Set output to a monitor or renderer target, then start the route again."
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

    private func applyRendererPreset(_ preset: RendererPreset, markDirty: Bool) {
        rendererPreset = preset
        rendererPresetIsDirty = markDirty
        suppressRendererPublish = true
        rendererBedRadius = preset.inputGeometry.bedRadius
        suppressRendererPublish = false
        refreshRendererScene()
    }

    private func updateRendererBedRadius(_ rawRadius: Double) {
        let radius = min(max(rawRadius, 0.25), 1.75)
        if abs(radius - rawRadius) > 0.000_1 {
            suppressRendererPublish = true
            rendererBedRadius = radius
            suppressRendererPublish = false
        }

        rendererPreset = rendererPreset.replacingBedRadius(radius)
        rendererPresetIsDirty = true
        rendererPresetStatus = "Edited \(rendererPreset.name). Save to update its JSON preset."
        refreshRendererScene()
    }

    private func refreshRendererScene() {
        rendererScene = RendererMatrixBuilder.sceneModel(
            for: currentRendererLayout,
            preset: rendererPreset
        )
        configureRendererMeters()
    }

    private func configureMonitorMeters() {
        let detectedCount = max(engine.monitorMeterChannelCount(), outputRoute.outputChannelCount, 2)
        monitorMeterStore.configureIfNeeded(channels: SurroundLayoutDetector.fallbackLayout(for: detectedCount).channels)
    }

    private func updateMonitorMeters() {
        let levels = engine.monitorMeterLevels()
        let channelCount = max(levels.count, outputRoute.outputChannelCount, 2)
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

        rendererMeterStore.configureIfNeeded(channels: channels)

        guard rendererScene.matrix.inputCount > 0,
              rendererScene.matrix.outputCount == channels.count,
              sourceLevels.count == rendererScene.matrix.inputCount
        else {
            rendererMeterStore.update(with: Array(repeating: 0, count: channels.count))
            return
        }

        var nextLevels = Array(repeating: Float(0), count: rendererScene.matrix.outputCount)

        for inputIndex in 0..<rendererScene.matrix.inputCount {
            let inputLevel = sourceLevels[inputIndex]
            guard inputLevel > 0 else { continue }

            for outputIndex in 0..<rendererScene.matrix.outputCount {
                let gain = Float(abs(rendererScene.matrix.gains[inputIndex][outputIndex]))
                let weightedLevel = inputLevel * gain
                nextLevels[outputIndex] += weightedLevel * weightedLevel
            }
        }

        rendererMeterStore.update(with: nextLevels.map { min(sqrtf($0), 1) })
    }

    private func rendererMeterChannels() -> [SurroundChannel] {
        var lfeCount = 0

        return rendererScene.outputSpeakers.enumerated().map { offset, speaker in
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

    private func padded(_ levels: [Float], count: Int) -> [Float] {
        guard count > 0 else { return [] }
        if levels.count == count { return levels }
        if levels.count > count { return Array(levels.prefix(count)) }
        return levels + Array(repeating: 0, count: count - levels.count)
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
            if lastLiveSignalPresent != true {
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

        if sourceMode == .roonBlackHole, let mismatchText = roonBlackHoleSampleRateMismatchText {
            liveSignalStatus = "BlackHole is silent. \(mismatchText)"
        } else if sourceMode == .roonBlackHole, roonNowPlaying?.state.caseInsensitiveCompare("PAUSED") == .orderedSame {
            liveSignalStatus = "BlackHole is silent because Roon is paused."
        } else if sourceMode == .roonBlackHole {
            liveSignalStatus = "BlackHole is silent. Select the BlackHole 64ch zone in Roon and start playback."
        } else {
            liveSignalStatus = "\(liveInputSignalName) is silent. Start the source or choose another Orbisonic input."
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
        guard sourceMode == .roonBlackHole,
              let targetSampleRate = roonBlackHoleSampleRateMismatch
        else { return }

        let now = Date()
        guard force || now.timeIntervalSince(lastBlackHoleSampleRateRepairTime) >= 8 else {
            return
        }

        lastBlackHoleSampleRateRepairTime = now
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
            statusMessage = "BlackHole is \(formatSampleRate(inputRoute.nominalSampleRate)) while Roon is \(formatSampleRate(targetSampleRate)). Set BlackHole 64ch to \(formatSampleRate(targetSampleRate)) in Audio MIDI Setup if capture stays silent."
        }

        if wasPlaying {
            startLiveInputForCurrentRoute(reason: "BlackHole sample-rate alignment")
        }
    }

    private func refreshRoonNowPlayingIfNeeded(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastRoonNowPlayingRefreshTime) >= 1.0 else { return }
        lastRoonNowPlayingRefreshTime = now

        guard sourceMode == .roonBlackHole else { return }

        guard let next = roonNowPlayingReader.readLatest() else {
            roonNowPlayingStatus = "No Roon playback line found in RoonServer log yet."
            return
        }

        if next != roonNowPlaying {
            roonNowPlaying = next
            AppLogger.shared.notice(
                category: "roon-metadata",
                "Now playing zone=\(next.zoneName) state=\(next.state) title=\(next.titleLine) format=\(next.qualityFormat) progress=\(next.positionText)/\(next.durationText)"
            )
        }

        if let signalPath = roonNowPlayingReader.readLatestSignalPath(), signalPath != roonSignalPath {
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

        roonNowPlayingStatus = "\(next.updatedText) • \(roonZoneText)"
    }

    private func applyPreset(_ preset: SpatialPreset, pushToEngine: Bool = true) {
        let defaults = preset.defaults
        suppressTuningPublish = true
        frontAngle = defaults.frontAngle
        rearAngle = defaults.rearAngle
        headTrackingEnabled = defaults.headTrackingEnabled
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
