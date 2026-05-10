import AudioContracts
@testable import OrbisonicVLCReference
import XCTest

final class VlcLivePCMDownmixPrototypeTests: XCTestCase {
    func testPrototypeRequiresExplicitSelection() throws {
        let prototype = VlcLivePCMDownmixPrototype(selection: .disabled)

        XCTAssertThrowsError(try prototype.feedCapturedPCM(roonFiveOneBlock())) { error in
            XCTAssertEqual(error as? VlcLivePCMDownmixPrototypeError, .notSelected)
        }
    }

    func testRoonFiveOnePCMFeedsVlcReadableRawStreamAndReturnsStereoFL32() throws {
        let prototype = VlcLivePCMDownmixPrototype(
            selection: .selectedForRoonMonitor,
            simulatedProcessingLatencyFrames: 96
        )
        let input = try roonFiveOneBlock(frameStart: 1_024)

        let result = try prototype.feedCapturedPCM(input)

        XCTAssertEqual(result.rawStream.formatFourCC, "FL32")
        XCTAssertEqual(result.rawStream.sampleRate, .rate48000)
        XCTAssertEqual(result.rawStream.channelCount, 6)
        XCTAssertEqual(result.rawStream.frameStart, 1_024)
        XCTAssertEqual(result.rawStream.frameCount, 3)
        XCTAssertEqual(result.rawStream.interleavedSamples, [
            1, 10, 100, 1_000, 10_000, 100_000,
            2, 20, 200, 2_000, 20_000, 200_000,
            3, 30, 300, 3_000, 30_000, 300_000
        ])

        XCTAssertEqual(result.callback.generation, 17)
        XCTAssertEqual(result.callback.frameStart, 1_120)
        XCTAssertEqual(result.callback.frameCount, 3)
        XCTAssertEqual(result.callback.format.formatFourCC, "FL32")
        XCTAssertEqual(result.callback.format.channelCount, 2)
        XCTAssertEqual(result.callback.format.sampleRate, .rate48000)
        XCTAssertEqual(result.callback.interleavedSamples.count, 6)
        XCTAssertEqual(result.downmixOwner, VlcLivePCMDownmixPrototype.downmixOwner)
        XCTAssertTrue(result.ledger.contains(stage: .downmix, owner: VlcLivePCMDownmixPrototype.downmixOwner))
    }

    func testPrototypeMeasuresLatencyAndDrift() throws {
        let prototype = VlcLivePCMDownmixPrototype(
            selection: .selectedForRoonMonitor,
            simulatedProcessingLatencyFrames: 48
        )

        let result = try prototype.feedCapturedPCM(roonFiveOneBlock())

        XCTAssertEqual(result.measurements.inputFrameCount, 3)
        XCTAssertEqual(result.measurements.outputFrameCount, 3)
        XCTAssertEqual(result.measurements.latencyFrames, 48)
        XCTAssertEqual(result.measurements.latencyMilliseconds, 1.0, accuracy: 0.000_001)
        XCTAssertEqual(result.measurements.driftFrames, 0)
        XCTAssertEqual(result.measurements.driftPartsPerMillion, 0, accuracy: 0.000_001)
        XCTAssertTrue(result.ledger.entries.last?.note?.contains("latencyFrames=48") == true)
        XCTAssertTrue(result.ledger.entries.last?.note?.contains("driftFrames=0") == true)
    }

    func testPrototypeRejectsNonRoonOrNonFiveOneInput() throws {
        let prototype = VlcLivePCMDownmixPrototype(selection: .selectedForRoonMonitor)

        XCTAssertThrowsError(
            try prototype.feedCapturedPCM(
                inputBlock(
                    sourceKind: .spotify,
                    channelCount: 6,
                    layout: .surround51,
                    planarSamples: fiveOneSamples()
                )
            )
        ) { error in
            XCTAssertEqual(error as? VlcLivePCMDownmixPrototypeError, .unsupportedSourceKind(.spotify))
        }

        XCTAssertThrowsError(
            try prototype.feedCapturedPCM(
                inputBlock(
                    sourceKind: .roon,
                    channelCount: 2,
                    layout: .stereo,
                    planarSamples: [[1, 2, 3], [4, 5, 6]]
                )
            )
        ) { error in
            XCTAssertEqual(error as? VlcLivePCMDownmixPrototypeError, .unsupportedChannelCount(2))
        }
    }

    private func roonFiveOneBlock(frameStart: Int64 = 0) throws -> VlcLivePCMInputBlock {
        try inputBlock(
            sourceKind: .roon,
            channelCount: 6,
            frameStart: frameStart,
            layout: .surround51,
            planarSamples: fiveOneSamples()
        )
    }

    private func inputBlock(
        sourceKind: SourceKind,
        channelCount: Int,
        frameStart: Int64 = 0,
        layout: AudioChannelLayoutDescriptor,
        planarSamples: [[Float]]
    ) throws -> VlcLivePCMInputBlock {
        try VlcLivePCMInputBlock(
            sourceID: "roon-live",
            sourceKind: sourceKind,
            generation: 17,
            sampleRate: .rate48000,
            channelCount: channelCount,
            frameStart: frameStart,
            frameCount: 3,
            layout: layout,
            planarSamples: planarSamples
        )
    }

    private func fiveOneSamples() -> [[Float]] {
        [
            [1, 2, 3],
            [10, 20, 30],
            [100, 200, 300],
            [1_000, 2_000, 3_000],
            [10_000, 20_000, 30_000],
            [100_000, 200_000, 300_000]
        ]
    }
}
