import AudioContracts
import AudioCore
import XCTest
@testable import Orbisonic

@MainActor
final class PureSphericalLosslessBadgeTests: XCTestCase {
    func testPresenterShowsOnlyApprovedBadgeStates() {
        XCTAssertNil(PureSphericalLosslessBadgePresenter.presentation(for: .none))
        XCTAssertNil(PureSphericalLosslessBadgePresenter.presentation(for: .candidate))
        XCTAssertNil(PureSphericalLosslessBadgePresenter.presentation(for: .invalid(reason: "metadata missing")))

        XCTAssertEqual(
            PureSphericalLosslessBadgePresenter.presentation(for: .validForCurrentSphere)?.text,
            "Pure Spherical Lossless"
        )
        XCTAssertEqual(
            PureSphericalLosslessBadgePresenter.presentation(for: .validForDifferentSphere)?.text,
            "Pure Spherical Lossless, different sphere"
        )
        XCTAssertEqual(
            PureSphericalLosslessBadgePresenter.presentation(for: .routeNotReady)?.text,
            "Pure Spherical Lossless, route not ready"
        )
    }

    func testValidFileStateProducesPlayerBadgePresentation() throws {
        let url = try writeCandidateAudioFile(name: "current-sphere.bw64", header: "BW64----WAVE")
        try writeSidecar(for: url, manifest: manifest())

        let validation = try PureSphericalLosslessValidator().validate(
            url: url,
            currentSphere: .directThirtyOne(),
            route: danteRoute(channels: 32)
        )

        XCTAssertEqual(validation.state, .validForCurrentSphere)
        XCTAssertEqual(
            PureSphericalLosslessBadgePresenter.presentation(for: validation.state)?.text,
            "Pure Spherical Lossless"
        )
    }

    func testInvalidFileStateDoesNotProducePlayerBadgePresentation() throws {
        let url = try writeCandidateAudioFile(name: "Pure Spherical Lossless.bw64", header: "BW64----WAVE")

        let validation = try PureSphericalLosslessValidator().validate(
            url: url,
            currentSphere: .directThirtyOne(),
            route: danteRoute(channels: 32)
        )

        XCTAssertNil(PureSphericalLosslessBadgePresenter.presentation(for: validation.state))
    }

    func testBadgeIsPlacedInExistingNowPlayingMediaBlockOnly() throws {
        let source = try String(
            contentsOf: packageRoot().appendingPathComponent("Sources/Orbisonic/ContentView.swift"),
            encoding: .utf8
        )
        let mediaBlock = try block(named: "private var nowPlayingMediaBlock", endingBefore: "private func pureSphericalLosslessBadge", in: source)
        let badgeBlock = try block(named: "private func pureSphericalLosslessBadge", endingBefore: "private var playerTransportControls", in: source)

        XCTAssertTrue(mediaBlock.contains("model.pureSphericalLosslessBadgePresentation"))
        XCTAssertTrue(badgeBlock.contains("Text(presentation.text)"))
        XCTAssertFalse(source.contains("Pure Spherical Inspector"))
        XCTAssertFalse(source.contains("Pure Spherical Export"))
    }

    private func manifest(
        channelCount: Int = 31
    ) -> PureSphericalLosslessManifest {
        PureSphericalLosslessManifest(
            sampleRate: .rate48000,
            channelCount: channelCount,
            sampleFormat: "float32",
            sphereProfileID: "sonic-sphere-31-reference",
            calibrationID: "test-calibration",
            outputMapID: "direct-30.1-logical",
            channels: (0..<channelCount).map { index in
                PureSphericalLosslessChannelManifest(
                    index: index,
                    channelID: "ch-\(index + 1)",
                    speakerID: index == 30 ? "lfe" : "speaker-\(index + 1)",
                    logicalOutputChannel: index + 1,
                    physicalOutputChannel: index + 1,
                    danteTransmitChannel: index + 1,
                    role: index == 30 ? "lfe" : "speaker"
                )
            }
        )
    }

    private func danteRoute(
        channels: Int,
        sampleRate: AudioSampleRate = .rate48000
    ) -> OutputRouteDescriptor {
        OutputRouteDescriptor(
            id: "dante",
            uid: "dante",
            name: "Dante Virtual Soundcard",
            manufacturer: "Audinate",
            transportName: "Dante",
            outputChannelCount: channels,
            nominalSampleRate: sampleRate,
            isAvailable: true,
            risk: .preferredDante
        )
    }

    private func writeCandidateAudioFile(
        name: String,
        header: String
    ) throws -> URL {
        let directory = temporaryDirectory().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try Data(header.utf8).write(to: url)
        return url
    }

    private func writeSidecar(
        for url: URL,
        manifest: PureSphericalLosslessManifest
    ) throws {
        try JSONEncoder().encode(manifest).write(to: url.appendingPathExtension("orbi.json"))
    }

    private func block(named startMarker: String, endingBefore endMarker: String, in source: String) throws -> String {
        let start = try XCTUnwrap(source.range(of: startMarker))
        let end = try XCTUnwrap(source.range(of: endMarker, range: start.upperBound..<source.endIndex))
        return String(source[start.lowerBound..<end.lowerBound])
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func temporaryDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("PureSphericalLosslessBadgeTests", isDirectory: true)
    }
}
