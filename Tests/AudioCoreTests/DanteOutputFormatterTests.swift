import AudioContracts
import AudioCore
import XCTest

final class DanteOutputFormatterTests: XCTestCase {
    func testDefaultProfileIsFortyEightKilohertzTwentyFourBitPCM() throws {
        let profile = DanteTargetProfile.defaultPCM24()

        XCTAssertEqual(profile.sampleRate, .rate48000)
        XCTAssertEqual(profile.encodingKind, .pcmInteger)
        XCTAssertEqual(profile.encodingBitDepth, 24)
        XCTAssertEqual(profile.logicalChannelCount, 31)
        XCTAssertEqual(profile.physicalChannelCount, 32)
        XCTAssertEqual(profile.physicalChannelMap[0], 0)
        XCTAssertEqual(profile.physicalChannelMap[30], 30)
        XCTAssertNil(profile.physicalChannelMap[31])
        XCTAssertTrue(profile.allowSampleRateConversion)
        XCTAssertTrue(profile.requireStrictRoute)
        XCTAssertTrue(profile.requireDitherForIntegerOutput)
        XCTAssertEqual(profile.maxTruePeakDBTP, -1)
        XCTAssertNoThrow(try profile.validate())
    }

    func testFloatToTwentyFourBitPCMUsesFinalTPDFDitherAndLedger() throws {
        let samples = try renderedSamples(frameCount: 2)
        try samples.setSample(0.25, channel: 0, frame: 0)
        try samples.setSample(-0.25, channel: 1, frame: 0)
        let rendered = try renderedBlock(frameCount: 2)

        let packet = try DanteOutputFormatter().format(
            samples: samples,
            renderedBlock: rendered,
            profile: .defaultPCM24(),
            context: context()
        )

        let bytes = try XCTUnwrap(packet.payload.int24LittleEndianBytes)
        XCTAssertEqual(bytes.count, 2 * 32 * 3)
        XCTAssertEqual(packet.diagnostics.ditherKind, .tpdf)
        XCTAssertTrue(packet.diagnostics.ditherApplied)
        XCTAssertEqual(packet.diagnostics.measurements.truePeak, 0.25)
        XCTAssertTrue(packet.ledger.contains(stage: .format, owner: .danteOutputFormatter))
        XCTAssertTrue(packet.ledger.entries.first?.note?.contains("dither=tpdf") == true)
    }

    func testFloatHostOutputDoesNotDither() throws {
        let samples = try renderedSamples()
        try samples.setSample(0.25, channel: 0, frame: 0)
        try samples.setSample(0.5, channel: 1, frame: 0)
        try samples.setSample(0.75, channel: 30, frame: 0)

        let packet = try DanteOutputFormatter().format(
            samples: samples,
            renderedBlock: try renderedBlock(),
            profile: .hostFloat32(),
            context: context()
        )

        let output = try XCTUnwrap(packet.payload.float32Samples)
        XCTAssertEqual(output.count, 32)
        XCTAssertEqual(output[0], 0.25, accuracy: 0.000_001)
        XCTAssertEqual(output[1], 0.5, accuracy: 0.000_001)
        XCTAssertEqual(output[30], 0.75, accuracy: 0.000_001)
        XCTAssertEqual(output[31], 0, accuracy: 0.000_001)
        XCTAssertEqual(packet.diagnostics.ditherKind, .none)
        XCTAssertFalse(packet.diagnostics.ditherApplied)
    }

    func testTruePeakIsMeasuredAndHeadroomGuardRejectsHotOutput() throws {
        let samples = try renderedSamples()
        try samples.setSample(0.5, channel: 4, frame: 0)
        let rendered = try renderedBlock()

        let safePacket = try DanteOutputFormatter().format(
            samples: samples,
            renderedBlock: rendered,
            profile: .hostFloat32(),
            context: context()
        )

        XCTAssertEqual(safePacket.diagnostics.measurements.samplePeak, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(safePacket.diagnostics.measurements.truePeak, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(safePacket.diagnostics.measurements.truePeakDBTP, -6.020_599_913, accuracy: 0.000_001)
        XCTAssertEqual(safePacket.diagnostics.measurements.truePeakMethod, "sample-peak approximation")
        XCTAssertTrue(safePacket.diagnostics.truePeakWithinLimit)

        let hot = try renderedSamples()
        try hot.setSample(0.95, channel: 4, frame: 0)
        XCTAssertThrowsError(
            try DanteOutputFormatter().format(
                samples: hot,
                renderedBlock: rendered,
                profile: .hostFloat32(),
                context: context()
            )
        ) { error in
            guard case AudioError.invalidRenderGraphPlan(let message) = error else {
                return XCTFail("Expected headroom guard error, got \(error).")
            }
            XCTAssertTrue(message.contains("true peak"))
            XCTAssertTrue(message.contains("exceeds limit"))
        }
    }

    func testChannelMapControlsPhysicalOrderForFloatHostPacket() throws {
        let samples = try renderedSamples()
        try samples.setSample(0.1, channel: 0, frame: 0)
        try samples.setSample(0.2, channel: 1, frame: 0)
        try samples.setSample(0.3, channel: 2, frame: 0)
        var map = DanteTargetProfile.defaultPhysicalChannelMap(physicalChannelCount: 32)
        map[0] = 2
        map[1] = 0
        map[2] = 1
        let profile = DanteTargetProfile.hostFloat32(physicalChannelCount: 32)
        let reorderedProfile = DanteTargetProfile(
            backend: profile.backend,
            sampleRate: profile.sampleRate,
            encodingBitDepth: profile.encodingBitDepth,
            encodingKind: profile.encodingKind,
            physicalChannelCount: profile.physicalChannelCount,
            outputMapID: profile.outputMapID,
            physicalChannelMap: map,
            requireDitherForIntegerOutput: profile.requireDitherForIntegerOutput
        )

        let packet = try DanteOutputFormatter().format(
            samples: samples,
            renderedBlock: try renderedBlock(),
            profile: reorderedProfile,
            context: context()
        )

        let output = try XCTUnwrap(packet.payload.float32Samples)
        XCTAssertEqual(output[0], 0.3, accuracy: 0.000_001)
        XCTAssertEqual(output[1], 0.1, accuracy: 0.000_001)
        XCTAssertEqual(output[2], 0.2, accuracy: 0.000_001)
    }

    func testReservedPhysicalChannelStaysSilentInPackedPCM() throws {
        let samples = try renderedSamples()
        for channel in 0..<31 {
            try samples.setSample(0.125, channel: channel, frame: 0)
        }

        let packet = try DanteOutputFormatter().format(
            samples: samples,
            renderedBlock: try renderedBlock(),
            profile: .defaultPCM24(),
            context: context()
        )

        let bytes = try XCTUnwrap(packet.payload.int24LittleEndianBytes)
        let reservedOffset = 31 * 3
        XCTAssertEqual(Array(bytes[reservedOffset..<(reservedOffset + 3)]), [0, 0, 0])
        XCTAssertEqual(packet.diagnostics.reservedPhysicalChannels, [31])
    }

    func testFormatterRejectsOutputMapMismatchBeforePacking() throws {
        let profile = DanteTargetProfile.defaultPCM24(outputMapID: "different-map")

        XCTAssertThrowsError(
            try DanteOutputFormatter().format(
                samples: renderedSamples(),
                renderedBlock: try renderedBlock(),
                profile: profile,
                context: context()
            )
        ) { error in
            XCTAssertEqual(
                error as? AudioError,
                .invalidRenderGraphPlan("DanteOutputFormatter output map must match target profile.")
            )
        }
    }

    private func renderedSamples(frameCount: Int = 1) throws -> CanonicalAudioBlock {
        let block = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: .rate48000,
                channelCount: 31,
                frameCount: frameCount,
                layout: .direct31
            )
        )
        try block.setFrameCount(frameCount)
        return block
    }

    private func renderedBlock(frameCount: Int = 1) throws -> RenderedSphereBlock {
        try RenderedSphereBlock(
            contract: AudioBlockContract(
                sourceID: "rendered-source",
                generation: 11,
                sampleRate: .rate48000,
                frameStart: 0,
                frameCount: frameCount,
                channelCount: 31,
                processingFormat: .float32NonInterleavedPCM,
                layout: SourceLayout(
                    descriptor: .direct31,
                    authority: .rendererOutputMap,
                    authorityID: "direct-30.1-logical"
                )
            ),
            outputMapID: "direct-30.1-logical",
            sphereProfileID: "sonic-sphere-31-reference"
        )
    }

    private func context() -> DanteOutputFormatContext {
        DanteOutputFormatContext(sessionID: "formatter-tests", sourceKind: .localFile)
    }
}
