import CoreAudio
import XCTest
@testable import Orbisonic

final class LoopbackSourceSupportTests: XCTestCase {
    func testMusicInputsExposeExactlyRoonAuxCableAndLocalFiles() {
        XCTAssertEqual(SourceMode.musicInputs, [.roon, .aux, .filePlayback])
        XCTAssertEqual(SourceMode.musicInputs.map(\.rawValue), ["Roon", "Aux Cable", "Local Files"])
        XCTAssertTrue(SourceMode.musicInputs.allSatisfy(\.isUserFacingMusicInput))
        XCTAssertFalse(SourceMode.musicInputs.contains(.testTone))
    }

    func testAuxCableLabelsUseFullName() {
        XCTAssertEqual(SourceMode.aux.monitorActionLabel, "Monitor Aux Cable")
        XCTAssertEqual(SourceMode.aux.muteActionLabel, "Mute Aux Cable")
        XCTAssertEqual(SourceMode.aux.mutedActionLabel, "Resume Aux Cable")
    }

    func testLiveSourcesMapToStableOrbisonicLoopbackUIDs() {
        XCTAssertEqual(SourceMode.roon.expectedLoopback?.deviceUID, "audio.orbisonic.rooninput.device")
        XCTAssertEqual(SourceMode.aux.expectedLoopback?.deviceUID, "audio.orbisonic.auxcable.device")
        XCTAssertNil(SourceMode.filePlayback.expectedLoopback)
        XCTAssertNil(SourceMode.testTone.expectedLoopback)
    }

    func testRoonAndAuxDoNotOwnPlaybackTransport() {
        XCTAssertFalse(SourceMode.roon.ownsTransport)
        XCTAssertFalse(SourceMode.aux.ownsTransport)
        XCTAssertTrue(SourceMode.filePlayback.ownsTransport)
    }

    func testInputRouteClassifiesOrbisonicLoopbacksByUID() {
        let roon = inputRoute(
            uid: OrbisonicLoopbackDevice.roonInput.deviceUID,
            name: "User Renamed Device",
            manufacturer: "Orbisonic"
        )
        let aux = inputRoute(
            uid: OrbisonicLoopbackDevice.auxCable.deviceUID,
            name: "Another User Name",
            manufacturer: "Orbisonic"
        )

        XCTAssertEqual(roon.role, .roonLoopback)
        XCTAssertTrue(roon.isRoonLoopback)
        XCTAssertEqual(aux.role, .auxLoopback)
        XCTAssertTrue(aux.isAuxLoopback)
    }

    func testInputRouteClassifiesLegacyBlackHoleSeparately() {
        let route = inputRoute(
            uid: "blackhole-64ch",
            name: "BlackHole 64ch",
            manufacturer: "Existential Audio"
        )

        XCTAssertEqual(route.role, .legacyBlackHole)
        XCTAssertTrue(route.isBlackHole)
        XCTAssertFalse(route.isOrbisonicLoopback)
    }

    func testOutputRouteBlocksOrbisonicLoopbackFeedback() {
        let route = OutputRouteInfo(
            deviceID: 42,
            uid: OrbisonicLoopbackDevice.auxCable.deviceUID,
            deviceName: "Orbisonic Aux Cable",
            manufacturer: "Orbisonic",
            transportName: "Virtual",
            outputChannelCount: 64,
            nominalSampleRate: 48_000
        )

        XCTAssertTrue(route.routeRisk.blocksLiveMonitoring)
    }

    func testDanteHighRatePolicyOnlyWarnsAboveSixteenChannels() {
        XCTAssertFalse(DanteSafetyPolicy.requiresHighRateChannelWarning(outputChannelCount: 16, sampleRate: 192_000))
        XCTAssertTrue(DanteSafetyPolicy.requiresHighRateChannelWarning(outputChannelCount: 30, sampleRate: 192_000))
        XCTAssertFalse(DanteSafetyPolicy.requiresHighRateChannelWarning(outputChannelCount: 30, sampleRate: 96_000))
    }

    private func inputRoute(uid: String, name: String, manufacturer: String) -> InputRouteInfo {
        InputRouteInfo(
            deviceID: AudioDeviceID(1),
            uid: uid,
            deviceName: name,
            manufacturer: manufacturer,
            transportName: "Virtual",
            inputChannelCount: 64,
            nominalSampleRate: 48_000
        )
    }
}
