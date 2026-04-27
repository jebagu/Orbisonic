import Foundation
import Darwin
import XCTest
@testable import Orbisonic

final class SpotifyReceiverClientTests: XCTestCase {
    func testDefaultConfigurationTargetsDedicatedSpotifyLoopback() {
        let configuration = SpotifyReceiverConfiguration.default()

        XCTAssertEqual(configuration.receiverName, "Orbisonic Spotify")
        XCTAssertEqual(configuration.loopbackDeviceName, "Orbisonic Spotify Input")
        XCTAssertEqual(configuration.loopbackDeviceUID, "audio.orbisonic.spotifyinput.device")
        XCTAssertFalse(configuration.loopbackDeviceName.contains("Aux Cable"))
        XCTAssertFalse(configuration.loopbackDeviceName.contains("Roon Input"))
    }

    func testStartReportsEmbeddedModuleUnavailableWhenModuleIsDisabled() {
        setenv("ORBISONIC_DISABLE_EMBEDDED_LIBRESPOT", "1", 1)
        defer {
            unsetenv("ORBISONIC_DISABLE_EMBEDDED_LIBRESPOT")
        }

        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("orbisonic-spotify-receiver-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let configuration = SpotifyReceiverConfiguration(
            receiverName: "Orbisonic Spotify",
            loopbackDeviceName: OrbisonicLoopbackDevice.spotifyInput.displayName,
            loopbackDeviceUID: OrbisonicLoopbackDevice.spotifyInput.deviceUID,
            supportDirectoryURL: rootURL.appendingPathComponent("Support", isDirectory: true),
            cacheDirectoryURL: rootURL.appendingPathComponent("Support/Cache", isDirectory: true),
            logDirectoryURL: rootURL.appendingPathComponent("Logs", isDirectory: true)
        )
        let client = SpotifyReceiverClient(configuration: configuration)

        let status = client.start()

        XCTAssertEqual(status.state, .embeddedModuleUnavailable)
        XCTAssertFalse(status.message.localizedCaseInsensitiveContains("librespot"))
        XCTAssertFalse(status.isRunning)
        XCTAssertTrue(FileManager.default.fileExists(atPath: configuration.cacheDirectoryURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: configuration.logDirectoryURL.path))
    }

    func testDefaultStatusIsStopped() {
        let status = SpotifyReceiverStatus.notStarted

        XCTAssertEqual(status.state, .notStarted)
        XCTAssertFalse(status.isRunning)
    }

    func testRestartingStatusIsUserFacingSpotifyConnectCopy() {
        let status = SpotifyReceiverStatus(
            state: .restarting,
            message: "Spotify Connect server is restarting."
        )

        XCTAssertEqual(status.state, .restarting)
        XCTAssertFalse(status.message.localizedCaseInsensitiveContains("librespot"))
    }
}
