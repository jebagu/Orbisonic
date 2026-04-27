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
}
