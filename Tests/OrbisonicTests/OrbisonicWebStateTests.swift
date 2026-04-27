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

        model.sourceMode = .roon
        let roonState = model.webStateForTesting(controlEnabled: true)

        XCTAssertEqual(roonState.input.sourcePanel.title, "Roon")
        XCTAssertEqual(roonState.input.sourcePanel.headline, "Waiting for Roon audio")
        XCTAssertEqual(roonState.input.sourcePanel.body, "Use Roon to send audio to Orbisonic.")
        XCTAssertEqual(roonState.input.sourcePanel.rows.map(\.title), ["Roon", "Input", "Signal"])
    }

    @MainActor
    func testWebPlayerControlsStayStable() {
        let model = OrbisonicViewModel()

        let state = model.webStateForTesting(controlEnabled: true)

        XCTAssertEqual(state.player.controls, ["previous", "play", "pause", "next", "stop", "playAll", "shuffle"])
        XCTAssertFalse(state.player.controls.contains("seekBackward"))
        XCTAssertFalse(state.player.controls.contains("seekForward"))
        XCTAssertFalse(state.player.controls.contains("playPause"))
    }
}
