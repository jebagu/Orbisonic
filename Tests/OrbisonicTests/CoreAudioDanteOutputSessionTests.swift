import AudioContracts
import AudioCore
import XCTest
@testable import Orbisonic

final class CoreAudioDanteOutputSessionTests: XCTestCase {
    func testConfigureQueriesCoreAudioFactsAndLogsHostVersusTargetProfile() throws {
        let route = danteRoute()
        let facts = routeFacts(requestedRoute: route, hostFormat: hostFloat32Format())
        let provider = FakeCoreAudioDanteRouteFactProvider(facts: facts)
        let session = CoreAudioDanteOutputSession(factProvider: provider)

        try session.open(route: route)
        let negotiation = try session.configure(profile: .defaultPCM24())

        XCTAssertEqual(provider.requestedRouteIDs, ["dante"])
        XCTAssertEqual(negotiation.requestedRoute, route)
        XCTAssertEqual(negotiation.actualRoute, facts.actualRoute)
        XCTAssertEqual(negotiation.requestedOutputFormat.sampleFormat, "PCM 24-bit")
        XCTAssertEqual(negotiation.actualOutputFormat.sampleFormat, "CoreAudio host Float32")
        XCTAssertTrue(negotiation.validationMessages.contains { $0.contains("Target Dante profile PCM 24-bit") })
        XCTAssertTrue(negotiation.validationMessages.contains { $0.contains("CoreAudio host format is not treated as Dante network encoding") })
        XCTAssertTrue(negotiation.validationMessages.contains { $0.contains("host-vs-network format separation") })
        XCTAssertEqual(session.timingReport().diagnostics?.actualOutputFormat?.sampleFormat, "CoreAudio host Float32")
        XCTAssertTrue(session.timingReport().diagnostics?.conversionLedger.contains(stage: .routeValidation, owner: .productionOutputSession) == true)
    }

    func testCoreAudioFloatHostDoesNotForceDanteNetworkFloat() throws {
        let route = danteRoute()
        let session = CoreAudioDanteOutputSession(
            factProvider: FakeCoreAudioDanteRouteFactProvider(
                facts: routeFacts(requestedRoute: route, hostFormat: hostFloat32Format())
            )
        )

        try session.open(route: route)
        let negotiation = try session.configure(profile: .defaultPCM24())

        XCTAssertEqual(negotiation.actualProfile.encodingKind, .pcmInteger)
        XCTAssertEqual(negotiation.actualProfile.encodingBitDepth, 24)
        XCTAssertEqual(negotiation.actualOutputFormat.sampleFormat, "CoreAudio host Float32")
    }

    func testProductionRefusesNonDanteAndStereoRoutesBeforePlayback() throws {
        let nonDanteRoute = danteRoute(
            name: "MacBook Pro Speakers",
            manufacturer: "Apple",
            transportName: "Built-In",
            channels: 2,
            risk: .safe
        )
        let nonDanteSession = CoreAudioDanteOutputSession(
            factProvider: FakeCoreAudioDanteRouteFactProvider(
                facts: routeFacts(
                    requestedRoute: nonDanteRoute,
                    actualRoute: nonDanteRoute,
                    hostFormat: hostFloat32Format(channels: 2)
                )
            )
        )

        try nonDanteSession.open(route: nonDanteRoute)
        XCTAssertThrowsError(try nonDanteSession.configure(profile: .defaultPCM24())) { error in
            XCTAssertEqual(
                error as? CoreAudioDanteSessionError,
                .routeIsNotDante(routeName: "MacBook Pro Speakers", risk: .safe)
            )
        }
        XCTAssertEqual(nonDanteSession.timingReport().submittedPacketCount, 0)

        let stereoDante = danteRoute(channels: 2)
        let stereoSession = CoreAudioDanteOutputSession(
            factProvider: FakeCoreAudioDanteRouteFactProvider(
                facts: routeFacts(
                    requestedRoute: stereoDante,
                    actualRoute: stereoDante,
                    hostFormat: hostFloat32Format(channels: 2)
                )
            )
        )

        try stereoSession.open(route: stereoDante)
        XCTAssertThrowsError(try stereoSession.configure(profile: .defaultPCM24())) { error in
            XCTAssertEqual(
                error as? CoreAudioDanteSessionError,
                .actualRouteChannelCountMismatch(expected: 32, actual: 2)
            )
        }
        XCTAssertEqual(stereoSession.timingReport().submittedPacketCount, 0)
    }

    func testProductionRefusesRouteAndHostSampleRateMismatchBeforePlayback() throws {
        let routeMismatch = danteRoute(sampleRate: .rate44100)
        let routeSession = CoreAudioDanteOutputSession(
            factProvider: FakeCoreAudioDanteRouteFactProvider(
                facts: routeFacts(
                    requestedRoute: routeMismatch,
                    actualRoute: routeMismatch,
                    hostFormat: hostFloat32Format(sampleRate: .rate44100)
                )
            )
        )

        try routeSession.open(route: routeMismatch)
        XCTAssertThrowsError(try routeSession.configure(profile: .defaultPCM24())) { error in
            XCTAssertEqual(
                error as? CoreAudioDanteSessionError,
                .actualRouteSampleRateMismatch(expected: .rate48000, actual: .rate44100)
            )
        }

        let hostMismatchRoute = danteRoute()
        let hostSession = CoreAudioDanteOutputSession(
            factProvider: FakeCoreAudioDanteRouteFactProvider(
                facts: routeFacts(
                    requestedRoute: hostMismatchRoute,
                    hostFormat: hostFloat32Format(sampleRate: .rate44100)
                )
            )
        )

        try hostSession.open(route: hostMismatchRoute)
        XCTAssertThrowsError(try hostSession.configure(profile: .defaultPCM24())) { error in
            XCTAssertEqual(
                error as? CoreAudioDanteSessionError,
                .hostOutputSampleRateMismatch(expected: .rate48000, actual: .rate44100)
            )
        }
    }

    func testSubmitAndDrainUseStrictPacketLifecycleAfterCoreAudioNegotiation() throws {
        let backend = FakeProductionOutputBackend()
        let lifecycle = FakeProductionOutputSession(backend: backend)
        let route = danteRoute()
        let session = CoreAudioDanteOutputSession(
            factProvider: FakeCoreAudioDanteRouteFactProvider(
                facts: routeFacts(requestedRoute: route, hostFormat: hostFloat32Format())
            ),
            lifecycle: lifecycle
        )

        try session.open(route: route)
        _ = try session.configure(profile: .defaultPCM24())
        try session.start()
        try session.submit(packet: outputPacket(generation: 12, impulses: [(0, 0, 0.5)]))
        try session.drain()

        let report = session.timingReport()
        XCTAssertEqual(report.state, .drained)
        XCTAssertEqual(report.writtenPacketCount, 1)
        XCTAssertEqual(report.diagnostics?.actualOutputFormat?.sampleFormat, "CoreAudio host Float32")
        XCTAssertTrue(report.diagnostics?.conversionLedger.contains(stage: .format, owner: .danteOutputFormatter) == true)
        XCTAssertTrue(report.diagnostics?.conversionLedger.contains(stage: .routeValidation, owner: .productionOutputSession) == true)
        XCTAssertEqual(backend.capturedPackets().count, 1)
    }

    private final class FakeCoreAudioDanteRouteFactProvider: CoreAudioDanteRouteFactProviding, @unchecked Sendable {
        private let facts: CoreAudioDanteRouteFacts
        private(set) var requestedRouteIDs: [String] = []

        init(facts: CoreAudioDanteRouteFacts) {
            self.facts = facts
        }

        func routeFacts(for route: ProductionOutputRoute) throws -> CoreAudioDanteRouteFacts {
            requestedRouteIDs.append(route.id)
            return facts
        }
    }

    private func routeFacts(
        requestedRoute: ProductionOutputRoute,
        actualRoute: ProductionOutputRoute? = nil,
        hostFormat: CoreAudioDanteHostFormat?
    ) -> CoreAudioDanteRouteFacts {
        CoreAudioDanteRouteFacts(
            requestedRoute: requestedRoute,
            actualRoute: actualRoute ?? requestedRoute,
            deviceID: 42,
            hostOutputFormat: hostFormat,
            queryMessages: [
                "CoreAudio deviceID=42",
                "CoreAudio route channels=\((actualRoute ?? requestedRoute).outputChannelCount)"
            ]
        )
    }

    private func hostFloat32Format(
        sampleRate: AudioSampleRate = .rate48000,
        channels: Int = 32
    ) -> CoreAudioDanteHostFormat {
        CoreAudioDanteHostFormat(
            sampleRate: sampleRate,
            channelCount: channels,
            formatID: 0x6c70_636d,
            formatIDDescription: "lpcm",
            formatFlags: 1,
            bitsPerChannel: 32,
            bytesPerFrame: channels * 4,
            framesPerPacket: 1,
            bytesPerPacket: channels * 4,
            isFloat: true,
            isIntegerPCM: false,
            isInterleaved: true
        )
    }

    private func outputPacket(
        generation: UInt64,
        frameCount: Int = 1,
        impulses: [(channel: Int, frame: Int, value: Float)]
    ) throws -> DanteOutputPacket {
        let profile = DanteTargetProfile.defaultPCM24()
        let samples = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: profile.sampleRate,
                channelCount: profile.logicalChannelCount,
                frameCount: frameCount,
                layout: .direct31
            )
        )
        try samples.setFrameCount(frameCount)
        for impulse in impulses {
            try samples.setSample(impulse.value, channel: impulse.channel, frame: impulse.frame)
        }
        return try DanteOutputFormatter().format(
            samples: samples,
            renderedBlock: try renderedBlock(profile: profile, generation: generation, frameCount: frameCount),
            profile: profile,
            context: DanteOutputFormatContext(sessionID: "coreaudio-dante-tests", sourceKind: .localFile)
        )
    }

    private func renderedBlock(
        profile: DanteTargetProfile,
        generation: UInt64,
        frameCount: Int
    ) throws -> RenderedSphereBlock {
        try RenderedSphereBlock(
            contract: AudioBlockContract(
                sourceID: "rendered-source",
                generation: generation,
                sampleRate: profile.sampleRate,
                frameStart: 0,
                frameCount: frameCount,
                channelCount: profile.logicalChannelCount,
                processingFormat: .float32NonInterleavedPCM,
                layout: SourceLayout(
                    descriptor: .direct31,
                    authority: .rendererOutputMap,
                    authorityID: profile.outputMapID
                )
            ),
            outputMapID: profile.outputMapID,
            sphereProfileID: "sonic-sphere-31-reference"
        )
    }

    private func danteRoute(
        name: String = "Dante Virtual Soundcard",
        manufacturer: String = "Audinate",
        transportName: String = "Dante",
        sampleRate: AudioSampleRate = .rate48000,
        channels: Int = 32,
        risk: AudioContracts.OutputRouteRisk = .preferredDante
    ) -> ProductionOutputRoute {
        ProductionOutputRoute(
            id: "dante",
            uid: "dante",
            name: name,
            manufacturer: manufacturer,
            transportName: transportName,
            outputChannelCount: channels,
            nominalSampleRate: sampleRate,
            isAvailable: true,
            risk: risk
        )
    }
}
