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

        XCTAssertEqual(state.player.controls, ["previous", "play", "pause", "next", "stop", "playAll", "shuffle"])
        XCTAssertTrue(state.player.enabledControls.contains("pause"))
        XCTAssertTrue(state.player.enabledControls.contains("stop"))
        XCTAssertTrue(state.player.enabledControls.contains("next"))
        XCTAssertFalse(state.player.enabledControls.contains("play"))
    }

    private static func writeSilentAudioFile(to url: URL) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480)
        else {
            XCTFail("Could not create test audio format")
            return
        }
        buffer.frameLength = 480
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
