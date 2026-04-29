import AVFoundation
import Foundation
import XCTest
@testable import Orbisonic

final class LocalPlayerStabilizationTests: XCTestCase {
    func testScanExcludesMissingM3UEntries() throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let audioURL = fixture.directory.appendingPathComponent("playable.wav")
        try Self.writeSilentAudioFile(to: audioURL)
        let missingURL = fixture.directory.appendingPathComponent("missing.flac")
        let playlistURL = fixture.directory.appendingPathComponent("session.m3u")
        try [
            "#EXTM3U",
            audioURL.path,
            missingURL.path
        ].joined(separator: "\n").write(to: playlistURL, atomically: true, encoding: .utf8)

        let library = LocalMusicLibrary(supportURL: fixture.supportDirectory)
        let result = library.scan(settings: LocalMusicSettings(
            watchFolderPaths: [],
            m3uPlaylistPaths: [playlistURL.path],
            scansSubfolders: true,
            importsM3UPlaylists: true,
            extractsAlbumArt: false
        ))

        XCTAssertEqual(result.tracks.map(\.path), [audioURL.path])
        XCTAssertEqual(result.playlists.count, 1)
        XCTAssertEqual(result.playlists[0].trackPaths, [audioURL.path])
        XCTAssertEqual(result.skippedMissingFiles, 1)
    }

    func testLoadPrunesPersistedMissingTracksAndPlaylistEntries() throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let existingURL = fixture.directory.appendingPathComponent("existing.wav")
        try Data().write(to: existingURL)
        let missingURL = fixture.directory.appendingPathComponent("missing.wav")

        let library = LocalMusicLibrary(supportURL: fixture.supportDirectory)
        library.save(LocalMusicDatabase(
            settings: LocalMusicSettings(),
            tracks: [
                Self.track(url: existingURL),
                Self.track(url: missingURL)
            ],
            playlists: [
                LocalMusicPlaylist(
                    name: "Mixed",
                    path: fixture.directory.appendingPathComponent("mixed.m3u").path,
                    trackPaths: [existingURL.path, missingURL.path]
                ),
                LocalMusicPlaylist(
                    name: "Missing",
                    path: fixture.directory.appendingPathComponent("missing.m3u").path,
                    trackPaths: [missingURL.path]
                )
            ]
        ))

        let loaded = library.load()

        XCTAssertEqual(loaded.tracks.map(\.path), [existingURL.path])
        XCTAssertEqual(loaded.playlists.map(\.name), ["Mixed"])
        XCTAssertEqual(loaded.playlists[0].trackPaths, [existingURL.path])
    }

    @MainActor
    func testStartupPreloadsFirstLibraryTrackPaused() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let firstURL = fixture.directory.appendingPathComponent("01-first.wav")
        let secondURL = fixture.directory.appendingPathComponent("02-second.wav")
        try Self.writeSilentAudioFile(to: firstURL)
        try Self.writeSilentAudioFile(to: secondURL)

        let first = Self.track(url: firstURL)
        let second = Self.track(url: secondURL)
        let library = LocalMusicLibrary(supportURL: fixture.supportDirectory)
        library.save(LocalMusicDatabase(
            settings: LocalMusicSettings(),
            tracks: [second, first],
            playlists: []
        ))

        let model = OrbisonicViewModel(
            localAudioLoader: Self.delayedLoader(delays: [:]),
            localMusicLibrary: library,
            preloadFirstLocalMusicTrack: true
        )
        try await Self.waitForCurrentFile(model, path: first.path)

        XCTAssertEqual(model.sessionQueue.map(\.id), [first.id, second.id])
        XCTAssertEqual(model.sessionQueueIndex, 0)
        XCTAssertEqual(model.currentQueueTrack?.id, first.id)
        XCTAssertFalse(model.isPlaying)
    }

    func testGeneratedFLACCanUseFFmpegFallbackDecodePath() throws {
        guard let ffmpegURL = FFmpegToolLocator.ffmpegURL() else {
            throw XCTSkip("ffmpeg unavailable")
        }

        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let flacURL = fixture.directory.appendingPathComponent("surround.flac")
        let result = try MatroskaAudioProbe.runProcess(
            executableURL: ffmpegURL,
            arguments: [
                "-v", "error",
                "-y",
                "-f", "lavfi",
                "-i", "anullsrc=channel_layout=5.1:sample_rate=96000",
                "-t", "0.1",
                "-c:a", "flac",
                flacURL.path
            ]
        )

        guard result.terminationStatus == 0 else {
            throw XCTSkip("ffmpeg FLAC fixture generation failed: \(result.errorText)")
        }

        let loaded = try AudioFileLoader().load(url: flacURL, forceFFmpegFLACFallback: true)

        XCTAssertEqual(loaded.metadata.codecName, "FLAC")
        XCTAssertEqual(loaded.metadata.channelCount, 6)
        XCTAssertEqual(loaded.metadata.sampleRate, 96_000, accuracy: 0.5)
        XCTAssertEqual(loaded.monoBuffers.count, 6)
    }

    func testPreparedPCMEstimateUsesFloat32Samples() {
        XCTAssertEqual(
            PreparedPCMPolicy.estimatedDecodedPCMBytes(
                durationSeconds: 2,
                sampleRate: 48_000,
                channelCount: 6
            ),
            2 * 48_000 * 6 * MemoryLayout<Float>.size
        )
        XCTAssertEqual(
            PreparedPCMPolicy.estimatedDecodedPCMBytes(
                frameCount: 96_000,
                channelCount: 2
            ),
            96_000 * 2 * MemoryLayout<Float>.size
        )
    }

    @MainActor
    func testAdjacentFullPCMPreloadIsDisabledByDefault() {
        let model = OrbisonicViewModel(localAudioLoader: Self.delayedLoader(delays: [:]))

        XCTAssertFalse(OrbisonicViewModel.adjacentFullLocalPCMPreloadEnabledByDefaultForTesting)
        XCTAssertFalse(model.adjacentFullLocalPCMPreloadEnabledForTesting)
    }

    @MainActor
    func testPreparedCacheRejectsEntriesAboveByteCap() throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let audioURL = fixture.directory.appendingPathComponent("cache-budget.wav")
        try Self.writeSilentAudioFile(to: audioURL, frames: 48_000)
        let loaded = try AudioFileLoader().load(url: audioURL)
        let model = OrbisonicViewModel(
            localAudioLoader: Self.delayedLoader(delays: [:]),
            preparedCacheByteLimit: max(loaded.preparedPCMByteCount - 1, 1)
        )

        let reason = model.cachePreparedLocalFileForTesting(loaded)

        XCTAssertEqual(reason, "prepared PCM exceeds cache budget")
        XCTAssertFalse(model.hasPreparedLocalFileForTesting(path: audioURL.path))
    }

    @MainActor
    func testFailedQueueLoadDoesNotCommitSelection() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let currentURL = fixture.directory.appendingPathComponent("current.wav")
        let missingURL = fixture.directory.appendingPathComponent("missing.wav")
        try Self.writeSilentAudioFile(to: currentURL)

        let model = OrbisonicViewModel()
        let current = Self.track(url: currentURL)
        let missing = Self.track(url: missingURL)
        model.replaceLocalMusicQueueForTesting(
            tracks: [current, missing],
            currentIndex: 0,
            selectedIndex: 0
        )

        XCTAssertTrue(model.playQueueIndexForTesting(1))
        XCTAssertEqual(model.sessionQueueIndex, 0)
        XCTAssertEqual(model.selectedSessionQueueIndex, 0)
        XCTAssertEqual(model.currentQueueTrack?.id, current.id)
        XCTAssertEqual(model.pendingSessionQueueIndex, 1)

        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(model.sessionQueueIndex, 0)
        XCTAssertEqual(model.selectedSessionQueueIndex, 0)
        XCTAssertEqual(model.currentQueueTrack?.id, current.id)
        XCTAssertNil(model.pendingSessionQueueIndex)
        XCTAssertFalse(model.isLocalFileLoading)
        XCTAssertTrue(model.lastError?.contains("Could not load missing.wav") == true)
    }

    @MainActor
    func testQueueSelectionDoesNotChangeWebNowPlaying() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let currentURL = fixture.directory.appendingPathComponent("current.wav")
        let selectedURL = fixture.directory.appendingPathComponent("selected.wav")
        try Self.writeSilentAudioFile(to: currentURL)
        try Self.writeSilentAudioFile(to: selectedURL)

        let model = OrbisonicViewModel()
        let current = Self.track(url: currentURL)
        let selected = Self.track(url: selectedURL)
        model.replaceLocalMusicQueueForTesting(
            tracks: [current, selected],
            currentIndex: nil,
            selectedIndex: nil
        )
        try await model.loadQueueIndexForTesting(0, isPlaying: true)

        model.selectSessionQueueIndex(1)

        let state = model.webStateForTesting(controlEnabled: true)
        XCTAssertEqual(model.sessionQueueIndex, 0)
        XCTAssertEqual(model.selectedSessionQueueIndex, 1)
        XCTAssertEqual(state.player.title, current.displayTitle)
        XCTAssertEqual(state.player.subtitle, current.displaySubtitle)
    }

    @MainActor
    func testFirstPendingQueueLoadUsesPendingPlayerBeforeDecodeFinishes() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let firstURL = fixture.directory.appendingPathComponent("first.wav")
        try Self.writeSilentAudioFile(to: firstURL)

        let model = OrbisonicViewModel(localAudioLoader: Self.delayedLoader(delays: ["first.wav": 0.3]))
        let first = Self.track(url: firstURL)
        model.replaceLocalMusicQueueForTesting(
            tracks: [first],
            currentIndex: nil,
            selectedIndex: nil
        )

        XCTAssertTrue(model.playQueueIndexForTesting(0))
        let state = model.webStateForTesting(controlEnabled: true)

        XCTAssertNil(model.sessionQueueIndex)
        XCTAssertNil(model.currentFileURL)
        XCTAssertEqual(model.pendingSessionQueueIndex, 0)
        XCTAssertTrue(model.isLocalFileLoading)
        XCTAssertEqual(model.visibleLocalPlaybackTrack?.id, first.id)
        XCTAssertEqual(model.visibleLocalSourceMetadata?.fileName, first.fileName)
        XCTAssertEqual(state.player.title, first.displayTitle)
        XCTAssertEqual(state.player.subtitle, first.displaySubtitle)
        XCTAssertEqual(state.player.status, "Loading")

        try await Self.waitForCurrentFile(model, path: first.path)
        XCTAssertEqual(model.visibleLocalPlaybackTrack?.id, first.id)
    }

    @MainActor
    func testPendingQueueLoadKeepsVisiblePlayerOnAudibleTrackBeforeDecodeFinishes() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let currentURL = fixture.directory.appendingPathComponent("current.wav")
        let nextURL = fixture.directory.appendingPathComponent("next.wav")
        try Self.writeSilentAudioFile(to: currentURL)
        try Self.writeSilentAudioFile(to: nextURL)

        let model = OrbisonicViewModel(localAudioLoader: Self.delayedLoader(delays: ["next.wav": 0.3]))
        let current = Self.track(url: currentURL)
        let next = Self.track(url: nextURL)
        model.replaceLocalMusicQueueForTesting(
            tracks: [current, next],
            currentIndex: nil,
            selectedIndex: nil
        )
        try await model.loadQueueIndexForTesting(0, isPlaying: true)

        model.skipLocalTransport(offset: 1)
        let state = model.webStateForTesting(controlEnabled: true)

        XCTAssertEqual(model.sessionQueueIndex, 0)
        XCTAssertEqual(model.currentFileURL?.path, current.path)
        XCTAssertEqual(model.pendingSessionQueueIndex, 1)
        XCTAssertTrue(model.isLocalFileLoading)
        XCTAssertEqual(model.visibleLocalPlaybackTrack?.id, current.id)
        XCTAssertEqual(model.visibleLocalSourceMetadata?.fileName, current.fileName)
        XCTAssertEqual(state.player.title, current.displayTitle)
        XCTAssertEqual(state.player.subtitle, current.displaySubtitle)
        XCTAssertEqual(state.player.status, "Loading")
        XCTAssertFalse(state.player.status.contains(next.displayTitle))
        XCTAssertFalse(state.player.details.contains { $0.title == "Pending" })

        try await Self.waitForCurrentFile(model, path: next.path)
        XCTAssertEqual(model.visibleLocalPlaybackTrack?.id, next.id)
        XCTAssertEqual(model.visibleLocalSourceMetadata?.fileName, next.fileName)
    }

    @MainActor
    func testPlayNowSwitchesFromSpotifyBeforeLoadingLocalTrack() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let localURL = fixture.directory.appendingPathComponent("local.wav")
        try Self.writeSilentAudioFile(to: localURL)

        let model = OrbisonicViewModel()
        let localTrack = Self.track(url: localURL)
        model.replaceLocalMusicQueueForTesting(
            tracks: [localTrack],
            currentIndex: nil,
            selectedIndex: nil
        )
        model.setSourceModeForTesting(.spotify)
        model.setSpotifyNowPlayingForTesting(Self.spotifyNowPlaying(title: "Paused Spotify Track", isPlaying: false))

        model.playLocalMusicTrackNow(localTrack)
        try await Self.waitForCurrentFile(model, path: localTrack.path)

        XCTAssertEqual(model.sourceMode, .filePlayback)
        XCTAssertEqual(model.currentFileURL?.path, localTrack.path)
        XCTAssertEqual(model.currentQueueTrack?.id, localTrack.id)
        XCTAssertTrue(model.isPlaying)
        XCTAssertEqual(model.webStateForTesting(controlEnabled: true).player.title, localTrack.displayTitle)
        XCTAssertFalse(model.statusMessage.localizedCaseInsensitiveContains("Spotify"))
        XCTAssertFalse(model.lastError?.contains("source mode changed") == true)
    }

    @MainActor
    func testPlayNowSwitchesFromRoonBeforeLoadingLocalTrack() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let localURL = fixture.directory.appendingPathComponent("local.wav")
        try Self.writeSilentAudioFile(to: localURL)

        let model = OrbisonicViewModel()
        let localTrack = Self.track(url: localURL)
        model.replaceLocalMusicQueueForTesting(
            tracks: [localTrack],
            currentIndex: nil,
            selectedIndex: nil
        )
        model.setSourceModeForTesting(.roon)

        model.playLocalMusicTrackNow(localTrack)
        try await Self.waitForCurrentFile(model, path: localTrack.path)

        XCTAssertEqual(model.sourceMode, .filePlayback)
        XCTAssertEqual(model.currentFileURL?.path, localTrack.path)
        XCTAssertEqual(model.currentQueueTrack?.id, localTrack.id)
        XCTAssertTrue(model.isPlaying)
        XCTAssertFalse(model.lastError?.contains("source mode changed") == true)
    }

    @MainActor
    func testPauseCancelsPendingQueueLoadWithoutAdvancing() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let currentURL = fixture.directory.appendingPathComponent("current.wav")
        let nextURL = fixture.directory.appendingPathComponent("next.wav")
        try Self.writeSilentAudioFile(to: currentURL)
        try Self.writeSilentAudioFile(to: nextURL)

        let model = OrbisonicViewModel(localAudioLoader: Self.delayedLoader(delays: ["next.wav": 0.25]))
        let current = Self.track(url: currentURL)
        let next = Self.track(url: nextURL)
        model.replaceLocalMusicQueueForTesting(
            tracks: [current, next],
            currentIndex: nil,
            selectedIndex: nil
        )
        try await model.loadQueueIndexForTesting(0, isPlaying: true)

        model.skipLocalTransport(offset: 1)
        XCTAssertEqual(model.pendingSessionQueueIndex, 1)
        XCTAssertTrue(model.isLocalFileLoading)

        model.pauseLocalTransport()
        try await Task.sleep(nanoseconds: 350_000_000)

        XCTAssertEqual(model.sessionQueueIndex, 0)
        XCTAssertEqual(model.currentFileURL?.path, current.path)
        XCTAssertNil(model.pendingSessionQueueIndex)
        XCTAssertFalse(model.isLocalFileLoading)
        XCTAssertFalse(model.isPlaying)
    }

    @MainActor
    func testStalePlaybackEndedAfterPauseDoesNotAdvanceQueueOrResetPosition() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let currentURL = fixture.directory.appendingPathComponent("current.wav")
        let nextURL = fixture.directory.appendingPathComponent("next.wav")
        try Self.writeSilentAudioFile(to: currentURL)
        try Self.writeSilentAudioFile(to: nextURL)

        let model = OrbisonicViewModel()
        let current = Self.track(url: currentURL)
        let next = Self.track(url: nextURL)
        model.replaceLocalMusicQueueForTesting(
            tracks: [current, next],
            currentIndex: nil,
            selectedIndex: nil
        )
        try await model.loadQueueIndexForTesting(0, isPlaying: true)

        for _ in 0..<3 {
            model.currentTime = max(model.duration - 0.01, 0)
            let pausedTime = model.currentTime
            model.pauseLocalTransport()
            model.triggerPlaybackEndedForTesting()

            XCTAssertEqual(model.sessionQueueIndex, 0)
            XCTAssertEqual(model.currentFileURL?.path, current.path)
            XCTAssertEqual(model.currentQueueTrack?.id, current.id)
            XCTAssertEqual(model.currentTime, pausedTime)
            XCTAssertFalse(model.isPlaying)

            model.playLocalTransport()

            XCTAssertEqual(model.sessionQueueIndex, 0)
            XCTAssertEqual(model.currentFileURL?.path, current.path)
            XCTAssertEqual(model.currentQueueTrack?.id, current.id)
            XCTAssertTrue(model.isPlaying)
        }
    }

    func testPausedEngineDefersRendererGraphRebuildAndReschedulesAfterPausedSeek() throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let audioURL = fixture.directory.appendingPathComponent("paused-resume.wav")
        try Self.writeSilentAudioFile(to: audioURL, frames: 48_000)

        let engine = OrbisonicEngine()
        defer { engine.stop() }

        let loaded = try engine.loadFile(url: audioURL)
        let scene = RendererMatrixBuilder.sceneModel(
            for: loaded.layout,
            preset: .sonicSphere30Point1,
            renderMode: .stereo
        )

        try engine.play()
        engine.pause()

        XCTAssertEqual(engine.state, .paused)
        let graphBuildCountAfterPause = engine.debugPlaybackGraphBuildCount

        engine.updateRenderer(mode: scene.renderMode, scene: scene, directRendererAudioEnabled: false)
        XCTAssertEqual(engine.debugPlaybackGraphBuildCount, graphBuildCountAfterPause)

        engine.seek(toProgress: 0.5)
        XCTAssertTrue(engine.debugPausedPlaybackNeedsReschedule)
        let scheduleCountBeforeResume = engine.debugScheduleFromCurrentPositionCount

        try engine.play()

        XCTAssertEqual(engine.state, .playing)
        XCTAssertFalse(engine.debugPausedPlaybackNeedsReschedule)
        XCTAssertGreaterThan(engine.debugScheduleFromCurrentPositionCount, scheduleCountBeforeResume)
        XCTAssertGreaterThanOrEqual(engine.currentTime(), 0.5)
    }

    @MainActor
    func testStopCancelsPendingQueueLoadWithoutAdvancing() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let currentURL = fixture.directory.appendingPathComponent("current.wav")
        let nextURL = fixture.directory.appendingPathComponent("next.wav")
        try Self.writeSilentAudioFile(to: currentURL)
        try Self.writeSilentAudioFile(to: nextURL)

        let model = OrbisonicViewModel(localAudioLoader: Self.delayedLoader(delays: ["next.wav": 0.25]))
        let current = Self.track(url: currentURL)
        let next = Self.track(url: nextURL)
        model.replaceLocalMusicQueueForTesting(
            tracks: [current, next],
            currentIndex: nil,
            selectedIndex: nil
        )
        try await model.loadQueueIndexForTesting(0, isPlaying: true)

        model.skipLocalTransport(offset: 1)
        XCTAssertEqual(model.pendingSessionQueueIndex, 1)
        XCTAssertTrue(model.isLocalFileLoading)

        model.stopLocalTransport()
        try await Task.sleep(nanoseconds: 350_000_000)

        XCTAssertEqual(model.sessionQueueIndex, 0)
        XCTAssertEqual(model.currentFileURL?.path, current.path)
        XCTAssertNil(model.pendingSessionQueueIndex)
        XCTAssertFalse(model.isLocalFileLoading)
        XCTAssertFalse(model.isPlaying)
    }

    @MainActor
    func testRapidForwardCoalescesToLatestPendingTarget() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let urls = (0..<4).map { fixture.directory.appendingPathComponent("track-\($0).wav") }
        try urls.forEach { try Self.writeSilentAudioFile(to: $0) }

        let model = OrbisonicViewModel(localAudioLoader: Self.delayedLoader(delays: ["track-1.wav": 0.25]))
        let tracks = urls.map { Self.track(url: $0) }
        model.replaceLocalMusicQueueForTesting(
            tracks: tracks,
            currentIndex: nil,
            selectedIndex: 0
        )
        try await model.loadQueueIndexForTesting(0, isPlaying: true)

        model.skipLocalTransport(offset: 1)
        model.skipLocalTransport(offset: 1)
        model.skipLocalTransport(offset: 1)

        XCTAssertEqual(model.sessionQueueIndex, 0)
        XCTAssertEqual(model.pendingSessionQueueIndex, 3)

        try await Self.waitForLocalLoadToFinish(model)

        XCTAssertEqual(model.sessionQueueIndex, 3)
        XCTAssertEqual(model.currentFileURL?.path, tracks[3].path)
        XCTAssertEqual(model.selectedSessionQueueIndex, 0)
        XCTAssertNil(model.pendingSessionQueueIndex)
        XCTAssertFalse(model.isLocalFileLoading)
    }

    @MainActor
    func testRapidForwardStartsOnlyFinalDebouncedDecode() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let urls = (0..<4).map { fixture.directory.appendingPathComponent("track-\($0).wav") }
        try urls.forEach { try Self.writeSilentAudioFile(to: $0) }

        let recorder = LocalLoadRecorder()
        let loader: @Sendable (URL) throws -> LoadedAudioFile = { url in
            try recorder.load(url: url)
        }
        let model = OrbisonicViewModel(localAudioLoader: loader)
        let tracks = urls.map { Self.track(url: $0) }
        model.replaceLocalMusicQueueForTesting(
            tracks: tracks,
            currentIndex: nil,
            selectedIndex: 0
        )
        try await model.loadQueueIndexForTesting(0, isPlaying: true)
        recorder.reset()

        model.skipLocalTransport(offset: 1)
        model.skipLocalTransport(offset: 1)
        model.skipLocalTransport(offset: 1)

        XCTAssertEqual(model.sessionQueueIndex, 0)
        XCTAssertEqual(model.pendingSessionQueueIndex, 3)

        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(recorder.fileNames, [])

        try await Self.waitForLocalLoadToFinish(model)

        XCTAssertEqual(recorder.fileNames, ["track-3.wav"])
        XCTAssertEqual(model.sessionQueueIndex, 3)
        XCTAssertEqual(model.currentFileURL?.path, tracks[3].path)
    }

    @MainActor
    func testStaleForegroundDecodeDoesNotCommitAfterNewerTrackSelected() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let urls = (0..<2).map { fixture.directory.appendingPathComponent("track-\($0).wav") }
        try urls.forEach { try Self.writeSilentAudioFile(to: $0) }

        let recorder = LocalLoadRecorder(delays: ["track-0.wav": 0.25])
        let loader: @Sendable (URL) throws -> LoadedAudioFile = { url in
            try recorder.load(url: url)
        }
        let model = OrbisonicViewModel(localAudioLoader: loader)
        let tracks = urls.map { Self.track(url: $0) }
        model.replaceLocalMusicQueueForTesting(
            tracks: tracks,
            currentIndex: nil,
            selectedIndex: nil
        )

        XCTAssertTrue(model.playQueueIndexForTesting(0))
        try await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertTrue(model.playQueueIndexForTesting(1))

        let deadline = Date().addingTimeInterval(3)
        var observedStaleCommit = false
        while model.currentFileURL?.path != tracks[1].path, Date() < deadline {
            if model.currentFileURL?.path == tracks[0].path {
                observedStaleCommit = true
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertFalse(observedStaleCommit)
        try await Self.waitForCurrentFile(model, path: tracks[1].path)
        XCTAssertEqual(model.sessionQueueIndex, 1)
    }

    @MainActor
    func testNextTrackUsesAdjacentMetadataDescriptorButStillForegroundDecodes() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let currentURL = fixture.directory.appendingPathComponent("current.wav")
        let nextURL = fixture.directory.appendingPathComponent("next.wav")
        try Self.writeSilentAudioFile(to: currentURL)
        try Self.writeSilentAudioFile(to: nextURL)

        let recorder = LocalLoadRecorder()
        let loader: @Sendable (URL) throws -> LoadedAudioFile = { url in
            try recorder.load(url: url)
        }
        let model = OrbisonicViewModel(
            localAudioLoader: loader,
            preloadAdjacentLocalMusicTracks: true,
            adjacentFullPreloadPCMByteLimit: PreparedPCMPolicy.maxFullPreparedPCMBytes
        )
        let current = Self.track(url: currentURL)
        let next = Self.track(url: nextURL)
        model.replaceLocalMusicQueueForTesting(
            tracks: [current, next],
            currentIndex: nil,
            selectedIndex: 0
        )
        try await model.loadQueueIndexForTesting(0, isPlaying: true)
        try await Self.waitForCachedLocalDescriptor(model, path: next.path)

        recorder.reset()
        XCTAssertFalse(model.hasPreparedLocalFileForTesting(path: next.path))
        XCTAssertFalse(recorder.fileNames.contains("next.wav"))

        model.skipLocalTransport(offset: 1)
        try await Self.waitForCurrentFile(model, path: next.path)

        XCTAssertEqual(recorder.fileNames, ["next.wav"])
        XCTAssertEqual(model.sessionQueueIndex, 1)
        XCTAssertTrue(model.isPlaying)
    }

    @MainActor
    func testAdjacentFullPreloadSkipsWhenCapIsZero() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let currentURL = fixture.directory.appendingPathComponent("current.wav")
        let nextURL = fixture.directory.appendingPathComponent("next.wav")
        try Self.writeSilentAudioFile(to: currentURL)
        try Self.writeSilentAudioFile(to: nextURL)

        let recorder = LocalLoadRecorder()
        let loader: @Sendable (URL) throws -> LoadedAudioFile = { url in
            try recorder.load(url: url)
        }
        let model = OrbisonicViewModel(
            localAudioLoader: loader,
            preloadAdjacentLocalMusicTracks: true
        )
        let current = Self.track(url: currentURL)
        let next = Self.track(url: nextURL)
        model.replaceLocalMusicQueueForTesting(
            tracks: [current, next],
            currentIndex: nil,
            selectedIndex: 0
        )
        try await model.loadQueueIndexForTesting(0, isPlaying: true)
        try await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertFalse(recorder.fileNames.contains("next.wav"))
        XCTAssertFalse(model.hasPreparedLocalFileForTesting(path: next.path))
        XCTAssertTrue(model.hasCachedLocalDescriptorForTesting(path: next.path))
    }

    @MainActor
    func testAdjacentMetadataPreloadDoesNotStorePreparedPCMAfterNewerTrackSelected() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let urls = (0..<5).map { fixture.directory.appendingPathComponent("track-\($0).wav") }
        try urls.forEach { try Self.writeSilentAudioFile(to: $0) }

        let recorder = LocalLoadRecorder(delays: ["track-1.wav": 0.35])
        let loader: @Sendable (URL) throws -> LoadedAudioFile = { url in
            try recorder.load(url: url)
        }
        let model = OrbisonicViewModel(
            localAudioLoader: loader,
            preloadAdjacentLocalMusicTracks: true,
            adjacentFullPreloadPCMByteLimit: PreparedPCMPolicy.maxFullPreparedPCMBytes
        )
        let tracks = urls.map { Self.track(url: $0) }
        model.replaceLocalMusicQueueForTesting(
            tracks: tracks,
            currentIndex: nil,
            selectedIndex: 0
        )
        try await model.loadQueueIndexForTesting(0, isPlaying: true)

        try await Self.waitForCachedLocalDescriptor(model, path: tracks[1].path)
        XCTAssertFalse(recorder.fileNames.contains("track-1.wav"))

        model.playQueueIndexForTesting(3)
        try await Self.waitForCurrentFile(model, path: tracks[3].path)
        try await Task.sleep(nanoseconds: 450_000_000)

        XCTAssertFalse(model.hasPreparedLocalFileForTesting(path: tracks[1].path))
    }

    @MainActor
    func testAdjacentMetadataDescriptorInvalidatesWhenFileChanges() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let currentURL = fixture.directory.appendingPathComponent("current.wav")
        let nextURL = fixture.directory.appendingPathComponent("next.wav")
        try Self.writeSilentAudioFile(to: currentURL)
        try Self.writeSilentAudioFile(to: nextURL)

        let recorder = LocalLoadRecorder()
        let loader: @Sendable (URL) throws -> LoadedAudioFile = { url in
            try recorder.load(url: url)
        }
        let model = OrbisonicViewModel(
            localAudioLoader: loader,
            preloadAdjacentLocalMusicTracks: true,
            adjacentFullPreloadPCMByteLimit: PreparedPCMPolicy.maxFullPreparedPCMBytes
        )
        let current = Self.track(url: currentURL)
        let next = Self.track(url: nextURL)
        model.replaceLocalMusicQueueForTesting(
            tracks: [current, next],
            currentIndex: nil,
            selectedIndex: 0
        )
        try await model.loadQueueIndexForTesting(0, isPlaying: true)
        try await Self.waitForCachedLocalDescriptor(model, path: next.path)

        try Self.writeSilentAudioFile(to: nextURL, frames: 960)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(60)],
            ofItemAtPath: nextURL.path
        )
        XCTAssertFalse(model.hasPreparedLocalFileForTesting(path: next.path))
        XCTAssertFalse(model.hasCachedLocalDescriptorForTesting(path: next.path))

        recorder.reset()
        model.skipLocalTransport(offset: 1)
        try await Self.waitForCurrentFile(model, path: next.path)

        XCTAssertEqual(recorder.fileNames.first, "next.wav")
        XCTAssertEqual(model.sessionQueueIndex, 1)
        XCTAssertTrue(model.isPlaying)
    }

    @MainActor
    func testWebPlayerControlsRemainUsableDuringPendingLocalLoad() async throws {
        let fixture = try TemporaryLocalMusicFixture()
        defer { fixture.remove() }

        let currentURL = fixture.directory.appendingPathComponent("current.wav")
        let nextURL = fixture.directory.appendingPathComponent("next.wav")
        try Self.writeSilentAudioFile(to: currentURL)
        try Self.writeSilentAudioFile(to: nextURL)

        let model = OrbisonicViewModel(localAudioLoader: Self.delayedLoader(delays: ["next.wav": 0.25]))
        let current = Self.track(url: currentURL)
        let next = Self.track(url: nextURL)
        model.replaceLocalMusicQueueForTesting(
            tracks: [current, next],
            currentIndex: nil,
            selectedIndex: nil
        )
        try await model.loadQueueIndexForTesting(0, isPlaying: true)
        model.skipLocalTransport(offset: 1)

        let state = model.webStateForTesting(controlEnabled: true)

        XCTAssertEqual(state.player.controls, ["previous", "play", "pause", "next"])
        XCTAssertTrue(state.player.enabledControls.contains("pause"))
        XCTAssertTrue(state.player.enabledControls.contains("next"))
        XCTAssertFalse(state.player.enabledControls.contains("play"))
    }

    private static func writeSilentAudioFile(to url: URL, frames: AVAudioFrameCount = 480) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)
        else {
            XCTFail("Could not create test audio format")
            return
        }
        buffer.frameLength = frames
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    private static func track(url: URL) -> LocalMusicTrack {
        LocalMusicTrack(
            path: url.path,
            rootPath: url.deletingLastPathComponent().path,
            fileName: url.lastPathComponent,
            title: url.deletingPathExtension().lastPathComponent,
            artist: nil,
            album: nil,
            channelCount: 2,
            channelSummary: "FL, FR",
            layoutName: "Stereo",
            sampleRate: 48_000,
            duration: 1,
            artworkPath: nil
        )
    }

    private static func spotifyNowPlaying(title: String, isPlaying: Bool) -> SpotifyNowPlaying {
        SpotifyNowPlaying(
            title: title,
            album: "Album",
            artists: ["Artist"],
            albumArtists: ["Artist"],
            uri: "spotify:track:test",
            durationMs: 180_000,
            positionMs: 42_000,
            isPlaying: isPlaying,
            isExplicit: false,
            popularity: nil,
            trackNumber: nil,
            discNumber: nil,
            coverURL: nil,
            volume: nil,
            shuffle: nil,
            repeatContext: nil,
            repeatTrack: nil,
            autoPlay: nil,
            clientName: "Spotify",
            updatedAt: "test"
        )
    }

    private static func delayedLoader(delays: [String: TimeInterval]) -> @Sendable (URL) throws -> LoadedAudioFile {
        { url in
            if let delay = delays[url.lastPathComponent] {
                Thread.sleep(forTimeInterval: delay)
            }
            return try AudioFileLoader().load(url: url)
        }
    }

    @MainActor
    private static func waitForLocalLoadToFinish(
        _ model: OrbisonicViewModel,
        timeout: TimeInterval = 2
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while model.isLocalFileLoading, Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertFalse(model.isLocalFileLoading)
    }

    @MainActor
    private static func waitForPreparedLocalFile(
        _ model: OrbisonicViewModel,
        path: String,
        timeout: TimeInterval = 3
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !model.hasPreparedLocalFileForTesting(path: path), Date() < deadline {
            if let lastError = model.lastError, !lastError.isEmpty {
                XCTFail("Unexpected local preload error: \(lastError)")
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertTrue(model.hasPreparedLocalFileForTesting(path: path))
    }

    @MainActor
    private static func waitForCachedLocalDescriptor(
        _ model: OrbisonicViewModel,
        path: String,
        timeout: TimeInterval = 3
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !model.hasCachedLocalDescriptorForTesting(path: path), Date() < deadline {
            if let lastError = model.lastError, !lastError.isEmpty {
                XCTFail("Unexpected local metadata preload error: \(lastError)")
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertTrue(model.hasCachedLocalDescriptorForTesting(path: path))
    }

    @MainActor
    private static func waitForCurrentFile(
        _ model: OrbisonicViewModel,
        path: String,
        timeout: TimeInterval = 3
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while model.currentFileURL?.path != path, Date() < deadline {
            if let lastError = model.lastError, !lastError.isEmpty {
                XCTFail("Unexpected local Play Now error: \(lastError)")
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(model.currentFileURL?.path, path)
        XCTAssertFalse(model.isLocalFileLoading)
        XCTAssertNil(model.pendingSessionQueueIndex)
    }
}

private final class LocalLoadRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let delays: [String: TimeInterval]
    private var loadedFileNames: [String] = []

    init(delays: [String: TimeInterval] = [:]) {
        self.delays = delays
    }

    var fileNames: [String] {
        lock.lock()
        defer { lock.unlock() }
        return loadedFileNames
    }

    func reset() {
        lock.lock()
        loadedFileNames.removeAll()
        lock.unlock()
    }

    func load(url: URL) throws -> LoadedAudioFile {
        lock.lock()
        loadedFileNames.append(url.lastPathComponent)
        lock.unlock()
        if let delay = delays[url.lastPathComponent] {
            Thread.sleep(forTimeInterval: delay)
        }
        return try AudioFileLoader().load(url: url)
    }
}

private final class TemporaryLocalMusicFixture {
    let directory: URL
    let supportDirectory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("orbisonic-local-player-tests-\(UUID().uuidString)", isDirectory: true)
        supportDirectory = directory.appendingPathComponent("Support", isDirectory: true)
        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
