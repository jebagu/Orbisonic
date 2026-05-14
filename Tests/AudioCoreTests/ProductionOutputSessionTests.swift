import AudioContracts
import AudioCore
import XCTest

final class ProductionOutputSessionTests: XCTestCase {
    func testRouteMismatchFailsBeforePlayback() throws {
        let session = FakeProductionOutputSession()
        try session.open(route: productionRoute(channels: 2))

        XCTAssertThrowsError(try session.configure(profile: .defaultPCM24())) { error in
            XCTAssertEqual(
                error as? ProductionOutputSessionError,
                .routeChannelCountMismatch(expected: 32, actual: 2)
            )
        }

        let report = session.timingReport()
        XCTAssertEqual(report.state, .failed)
        XCTAssertEqual(report.submittedPacketCount, 0)
        XCTAssertEqual(session.backend.capturedPackets().count, 0)
    }

    func testSampleRateMismatchFailsBeforePlayback() throws {
        let session = FakeProductionOutputSession()
        try session.open(route: productionRoute(sampleRate: .rate44100))

        XCTAssertThrowsError(try session.configure(profile: .defaultPCM24())) { error in
            XCTAssertEqual(
                error as? ProductionOutputSessionError,
                .routeSampleRateMismatch(expected: .rate48000, actual: .rate44100)
            )
        }

        XCTAssertEqual(session.timingReport().state, .failed)
        XCTAssertEqual(session.backend.capturedPackets().count, 0)
    }

    func testConfigureLogsRequestedAndActualRouteFacts() throws {
        let route = productionRoute()
        let profile = DanteTargetProfile.defaultPCM24()
        let session = FakeProductionOutputSession()

        try session.open(route: route)
        let negotiation = try session.configure(profile: profile)

        XCTAssertEqual(negotiation.requestedRoute, route)
        XCTAssertEqual(negotiation.actualRoute, route)
        XCTAssertEqual(negotiation.requestedProfile, profile)
        XCTAssertEqual(negotiation.actualProfile, profile)
        XCTAssertEqual(negotiation.requestedOutputFormat.sampleRate, .rate48000)
        XCTAssertEqual(negotiation.actualOutputFormat.channelCount, 32)
        XCTAssertTrue(negotiation.validationMessages.contains { $0.contains("strict output") })
        XCTAssertEqual(session.timingReport().state, .configured)
    }

    func testFlushDiscardsQueuedAudioAndRejectsStaleGeneration() throws {
        let session = try configuredSession()
        let stale = try outputPacket(generation: 1, impulses: [(0, 0, 0.5)])

        try session.submit(packet: stale)
        XCTAssertEqual(session.timingReport().queuedPacketCount, 1)

        session.flush(reason: .sourceChanged)
        var report = session.timingReport()
        XCTAssertEqual(report.state, .flushed)
        XCTAssertEqual(report.queuedPacketCount, 0)
        XCTAssertEqual(report.flushedPacketCount, 1)
        XCTAssertEqual(report.flushedFrameCount, 1)
        XCTAssertEqual(report.lastFlushReason, .sourceChanged)
        XCTAssertEqual(session.backend.capturedPackets().count, 0)

        try session.start()
        XCTAssertThrowsError(try session.submit(packet: stale)) { error in
            XCTAssertEqual(error as? ProductionOutputSessionError, .staleGeneration(1))
        }
        report = session.timingReport()
        XCTAssertEqual(report.state, .active)
        XCTAssertEqual(report.staleGenerationRejectedCount, 1)

        try session.submit(packet: outputPacket(generation: 2, impulses: [(1, 0, 0.5)]))
        XCTAssertEqual(session.timingReport().queuedPacketCount, 1)
        XCTAssertEqual(session.timingReport().activeGeneration, 2)
    }

    func testDrainFinishesQueuedAudio() throws {
        let session = try configuredSession()
        try session.submit(packet: outputPacket(generation: 3, frameCount: 4, impulses: [(0, 0, 0.5)]))
        try session.submit(packet: outputPacket(generation: 3, frameCount: 4, impulses: [(1, 0, 0.5)]))

        var report = session.timingReport()
        XCTAssertEqual(report.queuedPacketCount, 2)
        XCTAssertEqual(report.writtenPacketCount, 0)
        XCTAssertEqual(report.consumedFramePosition, 0)

        try session.drain()
        report = session.timingReport()
        XCTAssertEqual(report.state, .drained)
        XCTAssertEqual(report.queuedPacketCount, 0)
        XCTAssertEqual(report.writtenPacketCount, 2)
        XCTAssertEqual(report.drainedPacketCount, 2)
        XCTAssertEqual(report.drainedFrameCount, 8)
        XCTAssertEqual(report.consumedFramePosition, 8)
        XCTAssertEqual(session.backend.capturedPackets().count, 2)
        XCTAssertEqual(session.backend.lifecycleCounts().drain, 1)
    }

    func testChannelWalkPassesInFakeBackend() throws {
        let session = try configuredSession()

        for logicalChannel in 0..<31 {
            try session.submit(
                packet: outputPacket(
                    generation: 9,
                    impulses: [(logicalChannel, 0, 0.5)]
                )
            )
        }
        try session.drain()

        let report = try session.backend.channelWalkReport()
        XCTAssertTrue(report.passed)
        XCTAssertEqual(report.expectedLogicalChannelCount, 31)
        XCTAssertEqual(report.observations.count, 31)
        XCTAssertTrue(report.reservedPhysicalChannelsWithSignal.isEmpty)
        XCTAssertEqual(report.observations.first?.logicalChannel, 0)
        XCTAssertEqual(report.observations.first?.physicalChannel, 0)
        XCTAssertEqual(report.observations.last?.logicalChannel, 30)
        XCTAssertEqual(report.observations.last?.physicalChannel, 30)
    }

    func testSubmitRejectsPacketProfileMismatchBeforeQueueing() throws {
        let session = try configuredSession(profile: .defaultPCM24())
        let hostPacket = try outputPacket(profile: .hostFloat32(), generation: 4, impulses: [(0, 0, 0.5)])

        XCTAssertThrowsError(try session.submit(packet: hostPacket)) { error in
            XCTAssertEqual(error as? ProductionOutputSessionError, .packetProfileMismatch)
        }

        let report = session.timingReport()
        XCTAssertEqual(report.state, .failed)
        XCTAssertEqual(report.queuedPacketCount, 0)
        XCTAssertEqual(session.backend.capturedPackets().count, 0)
    }

    private func configuredSession(
        profile: DanteTargetProfile = .defaultPCM24()
    ) throws -> FakeProductionOutputSession {
        let session = FakeProductionOutputSession()
        try session.open(route: productionRoute(sampleRate: profile.sampleRate, channels: profile.physicalChannelCount))
        _ = try session.configure(profile: profile)
        try session.start()
        return session
    }

    private func outputPacket(
        profile: DanteTargetProfile = .defaultPCM24(),
        generation: UInt64,
        frameCount: Int = 1,
        impulses: [(channel: Int, frame: Int, value: Float)]
    ) throws -> DanteOutputPacket {
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
            renderedBlock: try renderedBlock(
                profile: profile,
                generation: generation,
                frameCount: frameCount
            ),
            profile: profile,
            context: DanteOutputFormatContext(sessionID: "production-output-tests", sourceKind: .localFile)
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

    private func productionRoute(
        sampleRate: AudioSampleRate = .rate48000,
        channels: Int = 32,
        isAvailable: Bool = true
    ) -> ProductionOutputRoute {
        ProductionOutputRoute(
            id: "dante",
            uid: "dante",
            name: "Dante Virtual Soundcard",
            manufacturer: "Audinate",
            transportName: "Dante",
            outputChannelCount: channels,
            nominalSampleRate: sampleRate,
            isAvailable: isAvailable,
            risk: .preferredDante
        )
    }
}
