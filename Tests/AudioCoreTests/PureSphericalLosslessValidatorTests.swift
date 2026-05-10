import AudioContracts
import AudioCore
import XCTest

final class PureSphericalLosslessValidatorTests: XCTestCase {
    func testValidBW64SidecarShowsCurrentSphereBadge() throws {
        let url = try writeCandidateAudioFile(name: "current-sphere.bw64", header: "BW64----WAVE")
        try writeSidecar(for: url, manifest: manifest())

        let validation = try PureSphericalLosslessValidator().validate(
            url: url,
            currentSphere: .directThirtyOne(),
            route: danteRoute(channels: 32)
        )

        XCTAssertEqual(validation.containerKind, .bw64)
        XCTAssertEqual(validation.state, .validForCurrentSphere)
        XCTAssertEqual(validation.badgeText, "Pure Spherical Lossless")
        XCTAssertTrue(validation.validationMessages.contains("valid for current sphere"))
    }

    func testValidCAFSidecarUsesSameManifestRules() throws {
        let url = try writeCandidateAudioFile(name: "current-sphere.caf", header: "caff----")
        try writeSidecar(for: url, manifest: manifest())

        let validation = try PureSphericalLosslessValidator().validate(
            url: url,
            currentSphere: .directThirtyOne(),
            route: danteRoute(channels: 32)
        )

        XCTAssertEqual(validation.containerKind, .caf)
        XCTAssertEqual(validation.state, .validForCurrentSphere)
    }

    func testEmbeddedORBIManifestStubCanValidateWithoutSidecar() throws {
        let url = try writeCandidateAudioFile(
            name: "embedded.bw64",
            header: "BW64----WAVEORBI\n",
            embeddedManifest: manifest()
        )

        let validation = try PureSphericalLosslessValidator().validate(
            url: url,
            currentSphere: .directThirtyOne(),
            route: danteRoute(channels: 32)
        )

        XCTAssertEqual(validation.metadataSource, .embeddedORBI)
        XCTAssertEqual(validation.state, .validForCurrentSphere)
    }

    func testFilenameOnlyCandidateDoesNotShowBadge() throws {
        let url = try writeCandidateAudioFile(name: "Pure Spherical Lossless.bw64", header: "BW64----WAVE")

        let validation = try PureSphericalLosslessValidator().validate(
            url: url,
            currentSphere: .directThirtyOne(),
            route: danteRoute(channels: 32)
        )

        XCTAssertEqual(validation.state, .invalid(reason: "Pure Spherical Lossless metadata missing"))
        XCTAssertNil(validation.badgeText)
    }

    func testInvalidMetadataIsRejected() throws {
        let url = try writeCandidateAudioFile(name: "needs-renderer.bw64", header: "BW64----WAVE")
        try writeSidecar(
            for: url,
            manifest: manifest(alreadyRendered: false, requiresRendererAtPlayback: true)
        )

        let validation = try PureSphericalLosslessValidator().validate(
            url: url,
            currentSphere: .directThirtyOne(),
            route: danteRoute(channels: 32)
        )

        XCTAssertEqual(validation.state, .invalid(reason: "file is not already rendered"))
        XCTAssertNil(validation.badgeText)
    }

    func testDifferentSphereAndRouteNotReadyBadgeStates() throws {
        let differentSphereURL = try writeCandidateAudioFile(name: "different-sphere.bw64", header: "BW64----WAVE")
        try writeSidecar(
            for: differentSphereURL,
            manifest: manifest(sphereProfileID: "different-sphere-31")
        )

        let differentSphere = try PureSphericalLosslessValidator().validate(
            url: differentSphereURL,
            currentSphere: .directThirtyOne(),
            route: danteRoute(channels: 32)
        )

        XCTAssertEqual(differentSphere.state, .validForDifferentSphere)
        XCTAssertEqual(differentSphere.badgeText, "Pure Spherical Lossless, different sphere")

        let routeNotReadyURL = try writeCandidateAudioFile(name: "route-not-ready.bw64", header: "BW64----WAVE")
        try writeSidecar(for: routeNotReadyURL, manifest: manifest())

        let routeNotReady = try PureSphericalLosslessValidator().validate(
            url: routeNotReadyURL,
            currentSphere: .directThirtyOne(),
            route: danteRoute(channels: 2)
        )

        XCTAssertEqual(routeNotReady.state, .routeNotReady)
        XCTAssertEqual(routeNotReady.badgeText, "Pure Spherical Lossless, route not ready")
    }

    private func manifest(
        alreadyRendered: Bool = true,
        requiresRendererAtPlayback: Bool = false,
        sphereProfileID: String = "sonic-sphere-31-reference",
        outputMapID: String = "direct-30.1-logical",
        channelCount: Int = 31
    ) -> PureSphericalLosslessManifest {
        PureSphericalLosslessManifest(
            alreadyRendered: alreadyRendered,
            requiresRendererAtPlayback: requiresRendererAtPlayback,
            sampleRate: .rate48000,
            channelCount: channelCount,
            sampleFormat: "float32",
            sphereProfileID: sphereProfileID,
            calibrationID: "test-calibration",
            outputMapID: outputMapID,
            rendererVersion: "orbisonic-renderer-v2-test",
            rendererMatrixHash: "sha256:test",
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
        header: String,
        embeddedManifest: PureSphericalLosslessManifest? = nil
    ) throws -> URL {
        let directory = temporaryDirectory().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        var data = Data(header.utf8)
        if let embeddedManifest {
            data.append(try JSONEncoder().encode(embeddedManifest))
        }
        try data.write(to: url)
        return url
    }

    private func writeSidecar(
        for url: URL,
        manifest: PureSphericalLosslessManifest
    ) throws {
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: url.appendingPathExtension("orbi.json"))
    }

    private func temporaryDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("PureSphericalLosslessValidatorTests", isDirectory: true)
    }
}
