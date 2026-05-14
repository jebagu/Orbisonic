import AudioContracts
import AudioCore
import XCTest

final class StereoMonitorOutputSessionTests: XCTestCase {
    func testConfigureLogsRequestedAndActualMonitorRouteFacts() throws {
        let session = StereoMonitorOutputSession()
        let route = monitorRoute(sampleRate: .rate48000)

        let negotiation = try session.configure(
            route: route,
            format: StereoMonitorFormat(sampleRate: .rate48000)
        )

        XCTAssertEqual(negotiation.requestedRoute, route)
        XCTAssertEqual(negotiation.actualRoute, route)
        XCTAssertEqual(negotiation.requestedFormat.sampleRate, .rate48000)
        XCTAssertEqual(negotiation.actualFormat.sampleRate, .rate48000)
        XCTAssertEqual(negotiation.actualFormat.channelCount, 2)
        XCTAssertTrue(negotiation.validationMessages.contains { $0.contains("monitor") || $0.contains("Monitor") })
        XCTAssertEqual(session.status().state, .configured)
        XCTAssertEqual(session.status().negotiation, negotiation)
    }

    func testSubmitAcceptsOnlyFinishedStereoMonitorBlockAndEmitsDiagnostics() throws {
        let session = StereoMonitorOutputSession()
        try session.configure(route: monitorRoute(), format: StereoMonitorFormat(sampleRate: .rate48000))
        try session.start()

        let block = try stereoMonitorBlock(sourceID: "vlc-track", frameStart: 128, frameCount: 256)
        try session.submit(block: block)
        let status = session.status()

        XCTAssertEqual(status.state, .active)
        XCTAssertEqual(status.submittedBlockCount, 1)
        XCTAssertEqual(status.consumedFramePosition, 256)
        XCTAssertEqual(status.diagnostics?.sourceID, "vlc-track")
        XCTAssertEqual(status.diagnostics?.sourceSampleRate, .rate48000)
        XCTAssertEqual(status.diagnostics?.sourceChannelCount, 2)
        XCTAssertEqual(status.diagnostics?.requestedOutputFormat?.channelCount, 2)
        XCTAssertEqual(status.diagnostics?.actualOutputFormat?.channelCount, 2)
        XCTAssertEqual(status.diagnostics?.routeChannelCount, 2)
        XCTAssertTrue(status.diagnostics?.conversionLedger.contains(stage: .routeValidation, owner: .orbisonic) == true)
        XCTAssertTrue(status.diagnostics?.conversionLedger.contains(stage: .format, owner: .orbisonic) == true)
    }

    func testNonStereoContractCannotEnterSessionAsMonitorBlock() {
        XCTAssertThrowsError(
            try StereoMonitorBlock(
                contract: AudioBlockContract(
                    sourceID: "bad",
                    generation: 1,
                    sampleRate: .rate48000,
                    frameStart: 0,
                    frameCount: 128,
                    channelCount: 6,
                    processingFormat: .float32InterleavedPCM,
                    layout: SourceLayout(descriptor: .surround51, authority: .containerMetadata)
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? AudioError,
                .sourceChannelCountOutOfRange(count: 6, minimum: 1, maximum: 2)
            )
        }
    }

    func testSubmitRejectsSampleRateMismatch() throws {
        let session = StereoMonitorOutputSession()
        try session.configure(route: monitorRoute(sampleRate: .rate48000), format: StereoMonitorFormat(sampleRate: .rate48000))
        try session.start()

        XCTAssertThrowsError(
            try session.submit(block: stereoMonitorBlock(sampleRate: .rate44100))
        ) { error in
            XCTAssertEqual(
                error as? StereoMonitorOutputSessionError,
                .blockSampleRateMismatch(expected: .rate48000, actual: .rate44100)
            )
        }
        XCTAssertEqual(session.status().state, .failed)
    }

    func testConfigureRejectsUnavailableInsufficientAndMismatchedRoutes() throws {
        XCTAssertThrowsError(
            try StereoMonitorOutputSession().configure(
                route: monitorRoute(isAvailable: false),
                format: StereoMonitorFormat(sampleRate: .rate48000)
            )
        ) { error in
            XCTAssertEqual(error as? StereoMonitorOutputSessionError, .routeUnavailable("monitor"))
        }

        XCTAssertThrowsError(
            try StereoMonitorOutputSession().configure(
                route: monitorRoute(channels: 1),
                format: StereoMonitorFormat(sampleRate: .rate48000)
            )
        ) { error in
            XCTAssertEqual(
                error as? StereoMonitorOutputSessionError,
                .routeInsufficientChannels(required: 2, actual: 1)
            )
        }

        XCTAssertThrowsError(
            try StereoMonitorOutputSession().configure(
                route: monitorRoute(sampleRate: .rate44100),
                format: StereoMonitorFormat(sampleRate: .rate48000)
            )
        ) { error in
            XCTAssertEqual(
                error as? StereoMonitorOutputSessionError,
                .routeSampleRateMismatch(expected: .rate48000, actual: .rate44100)
            )
        }
    }

    func testFlushAndStopPreserveTransportLevelLifecycle() throws {
        let session = StereoMonitorOutputSession()
        try session.configure(route: monitorRoute(), format: StereoMonitorFormat(sampleRate: .rate48000))
        try session.start()
        try session.submit(block: stereoMonitorBlock(frameCount: 64))

        session.flush(reason: .userStop)
        var status = session.status()
        XCTAssertEqual(status.state, .flushed)
        XCTAssertEqual(status.flushCount, 1)
        XCTAssertEqual(status.lastFlushReason, .userStop)
        XCTAssertEqual(status.submittedBlockCount, 1)
        XCTAssertEqual(status.consumedFramePosition, 64)

        session.stop()
        status = session.status()
        XCTAssertEqual(status.state, .stopped)
        XCTAssertEqual(status.flushCount, 1)
    }

    func testStereoMonitorOutputSessionDoesNotOwnProductionRoute() throws {
        let danteBefore = productionRoute()
        let session = StereoMonitorOutputSession()
        try session.configure(route: monitorRoute(), format: StereoMonitorFormat(sampleRate: .rate48000))
        try session.start()
        try session.submit(block: stereoMonitorBlock())
        session.stop()
        let danteAfter = danteBefore

        XCTAssertEqual(danteAfter, danteBefore)
        XCTAssertEqual(session.status().negotiation?.actualRoute.id, "monitor")
        XCTAssertNotEqual(session.status().negotiation?.actualRoute.id, danteBefore.route.id)
    }

    private func stereoMonitorBlock(
        sourceID: String = "source",
        sampleRate: AudioSampleRate = .rate48000,
        frameStart: Int64 = 0,
        frameCount: Int = 128
    ) throws -> StereoMonitorBlock {
        try StereoMonitorBlock(
            contract: AudioBlockContract(
                sourceID: sourceID,
                generation: 7,
                sampleRate: sampleRate,
                frameStart: frameStart,
                frameCount: frameCount,
                channelCount: 2,
                processingFormat: .float32InterleavedPCM,
                layout: SourceLayout(
                    descriptor: .stereo,
                    authority: .fallback,
                    authorityID: "test-stereo-monitor"
                )
            )
        )
    }

    private func monitorRoute(
        sampleRate: AudioSampleRate = .rate48000,
        channels: Int = 2,
        isAvailable: Bool = true
    ) -> MonitorRoute {
        MonitorRoute(
            id: "monitor",
            uid: "monitor",
            name: "Desktop Monitor",
            manufacturer: "Orbisonic",
            transportName: "Built-In",
            outputChannelCount: channels,
            nominalSampleRate: sampleRate,
            isAvailable: isAvailable,
            risk: .safe
        )
    }

    private func productionRoute() -> DanteRouteCapability {
        DanteRouteCapability(
            route: OutputRouteDescriptor(
                id: "dante",
                uid: "dante",
                name: "Dante Virtual Soundcard",
                manufacturer: "Audinate",
                transportName: "Dante",
                outputChannelCount: 32,
                nominalSampleRate: .rate48000,
                isAvailable: true,
                risk: .preferredDante
            ),
            supportedSampleRates: [.rate48000],
            currentNominalSampleRate: .rate48000,
            outputChannelCount: 32
        )
    }
}
