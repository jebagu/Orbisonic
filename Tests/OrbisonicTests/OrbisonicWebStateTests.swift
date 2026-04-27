import XCTest
@testable import Orbisonic

final class OrbisonicWebStateTests: XCTestCase {
    @MainActor
    func testControlStateIncludesDiagnosticsAndErrorsWhilePublicStateDoesNot() {
        let model = OrbisonicViewModel()

        model.lastError = "Desktop route error"
        model.selectDiagnosticSpeakerChannel(12)

        let controlState = model.webStateForTesting(controlEnabled: true)
        let publicState = model.webStateForTesting(controlEnabled: false)

        XCTAssertTrue(controlState.controlEnabled)
        XCTAssertNil(controlState.urls.controlPage)
        XCTAssertEqual(controlState.diagnostics.availableTests, ["monitorWalk", "rendererWalk", "testTone"])
        XCTAssertEqual(controlState.diagnostics.selectedChannel, 12)
        XCTAssertEqual(controlState.build.lastError, "Desktop route error")

        XCTAssertFalse(publicState.controlEnabled)
        XCTAssertEqual(publicState.diagnostics.availableTests, [])
        XCTAssertNil(publicState.build.lastError)
        XCTAssertNil(publicState.player.artworkURL)
    }

    @MainActor
    func testVolumeStateUsesPlainZeroToOneHundredValues() {
        let model = OrbisonicViewModel()

        model.setSphereOutputVolume(88.4)
        model.sphereOutputSafetyLimitPercent = 40.2

        let state = model.webStateForTesting(controlEnabled: true)

        XCTAssertEqual(state.player.volume, 88)
        XCTAssertEqual(model.sphereOutputVolumeText, "88")
        XCTAssertEqual(model.sphereMaxOutputVolumeText, "40")
        XCTAssertEqual(model.sphereEffectiveOutputVolumeText, "40")
        XCTAssertFalse(model.sphereOutputVolumeText.contains("%"))
        XCTAssertFalse(model.sphereMaxOutputVolumeText.contains("%"))
        XCTAssertFalse(model.sphereEffectiveOutputVolumeText.contains("%"))
    }

    @MainActor
    func testControlStateUsesPrimarySourcePanelModel() {
        let model = OrbisonicViewModel()

        let state = model.webStateForTesting(controlEnabled: true)

        XCTAssertEqual(state.input.sourceButtons.map(\.title), ["Off", "Roon", "Spotify", "Aux Cable", "Local Files"])
        XCTAssertEqual(state.input.sourceButtons.map(\.value), ["Off", "Roon", "Spotify", "Aux Cable", "Local Files"])
        XCTAssertEqual(state.input.sourceButtons.map(\.subtitle), ["", "", "", "", ""])
        XCTAssertFalse(state.input.sourceButtons.map(\.title).contains("Test Tone"))
        XCTAssertEqual(state.input.sourcePanel.title, "Local Files")
        XCTAssertEqual(state.input.sourcePanel.headline, "Ready")
        XCTAssertEqual(state.input.sourcePanel.rows.map(\.title), ["Library", "Playback"])
    }

    @MainActor
    func testControlStateUsesSourceSpecificInstructions() {
        let model = OrbisonicViewModel()

        model.sourceMode = .spotify
        let spotifyState = model.webStateForTesting(controlEnabled: true)

        XCTAssertEqual(spotifyState.input.sourcePanel.title, "Spotify")
        XCTAssertEqual(spotifyState.input.sourcePanel.headline, "Waiting for Spotify")
        XCTAssertTrue(spotifyState.input.sourcePanel.body.contains("Use the Spotify app to connect"))
        XCTAssertEqual(spotifyState.input.sourcePanel.rows.map(\.title), ["Receiver", "Input", "Signal"])
        XCTAssertEqual(spotifyState.player.controls, ["previous", "play", "pause", "stop", "next"])
        XCTAssertTrue(spotifyState.player.enabledControls.isEmpty)

        model.sourceMode = .roon
        let roonState = model.webStateForTesting(controlEnabled: true)

        XCTAssertEqual(roonState.input.sourcePanel.title, "Roon")
        XCTAssertEqual(roonState.input.sourcePanel.headline, "Roon unavailable")
        XCTAssertEqual(roonState.input.sourcePanel.body, "Orbisonic could not connect to the Roon service.")
        XCTAssertEqual(roonState.input.sourcePanel.rows.map(\.title), ["Roon", "Input", "Signal"])
    }

    @MainActor
    func testWebPlayerControlsStayStable() {
        let model = OrbisonicViewModel()

        let state = model.webStateForTesting(controlEnabled: true)

        XCTAssertEqual(state.player.controls, ["previous", "play", "pause", "stop", "next"])
        XCTAssertFalse(state.player.controls.contains("playAll"))
        XCTAssertFalse(state.player.controls.contains("shuffle"))
        XCTAssertFalse(state.player.controls.contains("seekBackward"))
        XCTAssertFalse(state.player.controls.contains("seekForward"))
        XCTAssertFalse(state.player.controls.contains("playPause"))
    }

    @MainActor
    func testSpotifyStatusUsesDebouncedBackendStateWithDisabledControls() async throws {
        let model = OrbisonicViewModel()
        model.setSourceModeForTesting(.spotify)
        model.setSpotifyNowPlayingForTesting(Self.spotifyNowPlaying(title: "Stable Track", isPlaying: true))

        var state = model.webStateForTesting(controlEnabled: true)
        XCTAssertEqual(state.player.status, "Spotify playing")
        XCTAssertTrue(state.player.isPlaying)
        XCTAssertTrue(state.player.enabledControls.isEmpty)

        model.applySpotifyNowPlayingForTesting(Self.spotifyNowPlaying(title: "Stable Track", isPlaying: false))

        state = model.webStateForTesting(controlEnabled: true)
        XCTAssertEqual(state.player.status, "Spotify playing")
        XCTAssertTrue(state.player.isPlaying)
        XCTAssertTrue(state.player.enabledControls.isEmpty)

        try await Task.sleep(nanoseconds: 350_000_000)

        state = model.webStateForTesting(controlEnabled: true)
        XCTAssertEqual(state.player.status, "Spotify playback paused")
        XCTAssertFalse(state.player.isPlaying)
        XCTAssertTrue(state.player.enabledControls.isEmpty)
    }

    @MainActor
    func testInactiveSpotifyStateDoesNotOverwriteLocalPlayerStatus() {
        let model = OrbisonicViewModel()
        model.setSourceModeForTesting(.spotify)
        model.setSpotifyNowPlayingForTesting(Self.spotifyNowPlaying(title: "Spotify Track", isPlaying: true))
        XCTAssertEqual(model.webStateForTesting(controlEnabled: true).player.status, "Spotify playing")

        model.setSourceModeForTesting(.filePlayback)
        model.sourceMetadata = Self.localMetadata(title: "Local Track")
        model.statusMessage = "Local playback paused"
        model.applySpotifyNowPlayingForTesting(Self.spotifyNowPlaying(title: "Spotify Track", isPlaying: false))

        let state = model.webStateForTesting(controlEnabled: true)
        XCTAssertEqual(state.player.source, SourceMode.filePlayback.rawValue)
        XCTAssertEqual(state.player.title, "Local Track")
        XCTAssertEqual(state.player.status, "Local playback paused")
        XCTAssertFalse(state.player.isPlaying)
    }

    @MainActor
    func testActiveSpotifyPlayerIgnoresStaleLocalPlaybackState() {
        let model = OrbisonicViewModel()
        model.setSourceModeForTesting(.filePlayback)
        model.sourceMetadata = Self.localMetadata(title: "Local Track")
        model.statusMessage = "Local playback playing"
        model.isPlaying = true

        model.setSourceModeForTesting(.spotify)
        model.setSpotifyNowPlayingForTesting(Self.spotifyNowPlaying(title: "Spotify Track", isPlaying: false))

        let state = model.webStateForTesting(controlEnabled: true)
        XCTAssertEqual(state.player.source, SourceMode.spotify.rawValue)
        XCTAssertEqual(state.player.title, "Spotify Track")
        XCTAssertEqual(state.player.status, "Spotify playback paused")
        XCTAssertFalse(state.player.isPlaying)
        XCTAssertTrue(state.player.enabledControls.isEmpty)
    }

    @MainActor
    func testActiveLocalPlayerIgnoresStaleRoonNowPlayingState() {
        let model = OrbisonicViewModel()
        model.setSourceModeForTesting(.roon)
        model.setRoonNowPlayingForTesting(Self.roonNowPlaying(title: "Roon Track"))
        XCTAssertEqual(model.webStateForTesting(controlEnabled: true).player.title, "Roon Track")

        model.setSourceModeForTesting(.filePlayback)
        model.sourceMetadata = Self.localMetadata(title: "Local Track")
        model.statusMessage = "Local playback paused"
        model.isPlaying = false

        let state = model.webStateForTesting(controlEnabled: true)
        XCTAssertEqual(state.player.source, SourceMode.filePlayback.rawValue)
        XCTAssertEqual(state.player.title, "Local Track")
        XCTAssertEqual(state.player.status, "Local playback paused")
        XCTAssertFalse(state.player.isPlaying)
    }

    @MainActor
    func testActiveRoonPlayerIgnoresStaleLocalPlaybackState() {
        let model = OrbisonicViewModel()
        model.setSourceModeForTesting(.filePlayback)
        model.sourceMetadata = Self.localMetadata(title: "Local Track")
        model.statusMessage = "Local playback playing"
        model.isPlaying = true

        model.setSourceModeForTesting(.roon)

        let state = model.webStateForTesting(controlEnabled: true)
        XCTAssertEqual(state.player.source, SourceMode.roon.rawValue)
        XCTAssertEqual(state.player.title, "Roon")
        XCTAssertEqual(state.player.status, "Roon playback stopped")
        XCTAssertFalse(state.player.isPlaying)
    }

    private static func localMetadata(title: String) -> AudioSourceMetadata {
        AudioSourceMetadata(
            fileName: "\(title).wav",
            containerName: "WAV",
            codecName: "PCM",
            layoutName: "Stereo",
            channelSummary: "FL, FR",
            channelCount: 2,
            sampleRate: 48_000,
            bitDepth: 24,
            duration: 180,
            title: title,
            album: "Local Album",
            artist: "Local Artist"
        )
    }

    private static func roonNowPlaying(title: String) -> RoonNowPlaying {
        RoonNowPlaying(
            zoneName: "Orbisonic",
            qualityFormat: "HighQuality, 24/96 FLAC => 24/96",
            bufferStatus: "100%",
            state: "PLAYING",
            positionText: "1:23",
            durationText: "4:56",
            title: title,
            artist: "Roon Artist",
            updatedText: "test",
            rawLine: "test"
        )
    }

    private static func spotifyNowPlaying(title: String, isPlaying: Bool) -> SpotifyNowPlaying {
        SpotifyNowPlaying(
            title: title,
            album: "Album",
            artists: ["Artist"],
            albumArtists: ["Artist"],
            uri: "spotify:track:\(title.replacingOccurrences(of: " ", with: "-"))",
            durationMs: 180_000,
            positionMs: isPlaying ? 42_000 : 43_000,
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
            updatedAt: isPlaying ? "playing" : "paused"
        )
    }
}
