import AudioContracts
import OrbisonicVLCReference
import XCTest

final class VlcLocalStereoMonitorSourceTests: XCTestCase {
    func testDefaultBuildCannotOpenMonitorAndReportsVlcUnavailable() {
        let source = VlcLocalStereoMonitorSource(
            capabilityReport: VlcCapabilityReport(
                buildFlagEnabled: false,
                status: .disabledAtBuild,
                runtimeAvailable: false,
                libraryPath: nil,
                pluginDirectoryPath: nil,
                diagnostics: [
                    VlcCapabilityDiagnostic(
                        severity: .info,
                        code: .buildFlagDisabled,
                        message: "disabled"
                    )
                ]
            )
        )

        XCTAssertThrowsError(
            try source.openLocalStereoMonitor(
                url: fixtureURL(),
                request: request()
            )
        ) { error in
            XCTAssertEqual(error as? VlcStereoMonitorError, .vlcUnavailable)
        }
    }

    func testStereoCallbackEmitsStereoMonitorBlockWithVlcDownmixOwner() throws {
        let session = try availableSession(
            request: request(
                sourceFormat: AudioFormatSummary(
                    sampleRate: .rate48000,
                    channelCount: 2,
                    sampleFormat: "Float32",
                    layoutName: "Stereo"
                )
            )
        )

        try session.acceptCallback(
            callback(
                frameStart: 256,
                frameCount: 2,
                samples: [0.1, -0.1, 0.2, -0.2]
            )
        )
        let output = try session.readBlock()
        let diagnostics = session.currentDiagnostics()

        XCTAssertEqual(output.monitorBlock.sourceID, "local-track")
        XCTAssertEqual(output.monitorBlock.generation, 42)
        XCTAssertEqual(output.monitorBlock.sampleRate, .rate48000)
        XCTAssertEqual(output.monitorBlock.contract.frameStart, 256)
        XCTAssertEqual(output.monitorBlock.frameCount, 2)
        XCTAssertEqual(output.monitorBlock.contract.channelCount, 2)
        XCTAssertEqual(output.monitorBlock.contract.processingFormat, .float32InterleavedPCM)
        XCTAssertEqual(output.interleavedSamples, [0.1, -0.1, 0.2, -0.2])
        XCTAssertEqual(diagnostics.downmixOwner, .vlc)
        XCTAssertEqual(diagnostics.nativeLocalDownmixCallCount, 0)
        XCTAssertEqual(diagnostics.acceptedCallbackBlockCount, 1)
        XCTAssertTrue(diagnostics.lastLedger?.contains(stage: .downmix, owner: .vlc) == true)
    }

    func testFiveOneLocalFixtureCallbackIsAcceptedOnlyAfterVlcReturnsStereo() throws {
        let session = try availableSession(
            request: request(
                sourceFormat: AudioFormatSummary(
                    sampleRate: .rate48000,
                    channelCount: 6,
                    sampleFormat: "Float32",
                    layoutName: "5.1 Surround"
                )
            )
        )

        try session.acceptCallback(
            callback(
                frameCount: 3,
                samples: [1, -1, 0.5, -0.5, 0.25, -0.25]
            )
        )
        let output = try session.readBlock()
        let diagnostics = session.currentDiagnostics()

        XCTAssertEqual(output.monitorBlock.contract.channelCount, 2)
        XCTAssertEqual(output.monitorBlock.contract.layout.descriptor, .stereo)
        XCTAssertEqual(diagnostics.downmixOwner, .vlc)
        XCTAssertEqual(diagnostics.nativeLocalDownmixCallCount, 0)
        XCTAssertEqual(diagnostics.lastLedger?.entries.first?.input?.channelCount, 6)
        XCTAssertEqual(diagnostics.lastLedger?.entries.first?.output?.channelCount, 2)
        XCTAssertTrue(diagnostics.lastLedger?.contains(stage: .decode, owner: .vlc) == true)
        XCTAssertTrue(diagnostics.lastLedger?.contains(stage: .downmix, owner: .vlc) == true)
    }

    func testNonStereoCallbackIsRejectedBeforeRingWrite() throws {
        let session = try availableSession()

        XCTAssertThrowsError(
            try session.acceptCallback(
                VlcStereoMonitorCallbackBuffer(
                    generation: 42,
                    frameStart: 0,
                    frameCount: 1,
                    format: VlcStereoMonitorCallbackFormat(
                        formatFourCC: "FL32",
                        sampleRate: .rate48000,
                        channelCount: 6
                    ),
                    interleavedSamples: [0, 0, 0, 0, 0, 0]
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? VlcStereoMonitorError,
                .callbackDidNotReturnStereo(actualChannelCount: 6)
            )
        }

        XCTAssertThrowsError(try session.readBlock()) { error in
            XCTAssertEqual(error as? VlcStereoMonitorError, .ringUnderflow)
        }
        XCTAssertEqual(session.currentDiagnostics().callbackFormatViolationCount, 1)
    }

    func testStaleGenerationCallbackIsRejectedBeforeRingWrite() throws {
        let session = try availableSession()

        XCTAssertThrowsError(
            try session.acceptCallback(
                callback(generation: 41, samples: [0, 0])
            )
        ) { error in
            XCTAssertEqual(
                error as? VlcStereoMonitorError,
                .staleGenerationRejected(expected: 42, actual: 41)
            )
        }

        let diagnostics = session.currentDiagnostics()
        XCTAssertEqual(diagnostics.staleGenerationRejectedCount, 1)
        XCTAssertEqual(diagnostics.acceptedCallbackBlockCount, 0)
        XCTAssertThrowsError(try session.readBlock()) { error in
            XCTAssertEqual(error as? VlcStereoMonitorError, .ringUnderflow)
        }
    }

    func testRingOverflowIsDiagnosticAndPreservesExistingBlock() throws {
        let session = try availableSession(request: request(ringCapacityBlocks: 1))

        try session.acceptCallback(callback(frameStart: 0, samples: [0.1, -0.1]))
        XCTAssertThrowsError(
            try session.acceptCallback(callback(frameStart: 1, samples: [0.2, -0.2]))
        ) { error in
            XCTAssertEqual(error as? VlcStereoMonitorError, .ringOverflow)
        }

        let first = try session.readBlock()
        XCTAssertEqual(first.interleavedSamples, [0.1, -0.1])
        XCTAssertEqual(session.currentDiagnostics().ringOverflowCount, 1)
    }

    func testCallbackAfterCloseCannotWriteIntoReleasedSessionState() throws {
        let session = try availableSession()
        session.close()

        XCTAssertThrowsError(
            try session.acceptCallback(callback(samples: [0, 0]))
        ) { error in
            XCTAssertEqual(error as? VlcStereoMonitorError, .sessionClosed)
        }
        XCTAssertThrowsError(try session.readBlock()) { error in
            XCTAssertEqual(error as? VlcStereoMonitorError, .ringUnderflow)
        }
    }

    private func availableSession(
        request: VlcStereoMonitorRequest? = nil
    ) throws -> VlcStereoMonitorSession {
        try VlcLocalStereoMonitorSource(capabilityReport: availableReport())
            .openLocalStereoMonitor(url: fixtureURL(), request: request ?? self.request())
    }

    private func request(
        sourceFormat: AudioFormatSummary? = nil,
        ringCapacityBlocks: Int = 8
    ) -> VlcStereoMonitorRequest {
        VlcStereoMonitorRequest(
            sourceID: "local-track",
            generation: 42,
            requestedSampleRate: .rate48000,
            sourceFormat: sourceFormat,
            ringCapacityBlocks: ringCapacityBlocks
        )
    }

    private func callback(
        generation: UInt64 = 42,
        frameStart: Int64 = 0,
        frameCount: Int = 1,
        samples: [Float],
        isDiscontinuity: Bool = false
    ) -> VlcStereoMonitorCallbackBuffer {
        VlcStereoMonitorCallbackBuffer(
            generation: generation,
            frameStart: frameStart,
            frameCount: frameCount,
            format: VlcStereoMonitorCallbackFormat(
                formatFourCC: "FL32",
                sampleRate: .rate48000,
                channelCount: 2
            ),
            interleavedSamples: samples,
            isDiscontinuity: isDiscontinuity
        )
    }

    private func availableReport() -> VlcCapabilityReport {
        VlcCapabilityReport(
            buildFlagEnabled: true,
            status: .available,
            runtimeAvailable: true,
            libraryPath: "/vlc/libvlc.dylib",
            pluginDirectoryPath: "/vlc/plugins",
            diagnostics: [
                VlcCapabilityDiagnostic(
                    severity: .info,
                    code: .runtimeAvailable,
                    message: "available"
                )
            ]
        )
    }

    private func fixtureURL() -> URL {
        URL(fileURLWithPath: "/tmp/orbisonic-vlc-fixture.wav")
    }
}
