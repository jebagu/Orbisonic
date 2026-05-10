import AudioContracts
import AudioCore
import XCTest

final class SourceRateConverterTests: XCTestCase {
    private let tolerance: Float = 0.000_001

    func testConverts44100ImpulseTo48000AndLogsExplicitLedger() throws {
        let block = try makeBlock(sampleRate: .rate44100, channelCount: 2, frameCapacity: 441, layout: .stereo)
        try block.setSample(1, channel: 0, frame: 0)
        try block.setFrameCount(441)

        let profile = SourceRateConverterProfile.deterministicReference(
            inputSampleRate: .rate44100,
            outputSampleRate: .rate48000
        )
        let result = try DeterministicSourceRateConverter().convert(
            block: block,
            profile: profile,
            context: context(sourceID: "impulse-441")
        )

        XCTAssertEqual(result.inputFrameCount, 441)
        XCTAssertEqual(result.outputFrameCount, 480)
        XCTAssertEqual(result.block.sampleRate, .rate48000)
        XCTAssertEqual(result.block.channelCount, 2)
        XCTAssertEqual(result.block.frameCount, 480)
        XCTAssertEqual(result.block.sample(channel: 0, frame: 0), 1, accuracy: tolerance)
        XCTAssertEqual(result.block.sample(channel: 1, frame: 0), 0, accuracy: tolerance)
        XCTAssertEqual(result.canonicalBlock.sourceID, "impulse-441")
        XCTAssertEqual(result.canonicalBlock.generation, 2)
        XCTAssertEqual(result.canonicalBlock.sampleRate, .rate48000)
        XCTAssertEqual(result.canonicalBlock.layout.authority, .containerMetadata)
        XCTAssertTrue(result.ledger.contains(stage: .sampleRateConversion, owner: .sourceRateConverter))
        XCTAssertFalse(result.ledger.hasHiddenConversionRisk)

        let note = try XCTUnwrap(result.ledger.entries.first?.note)
        XCTAssertTrue(note.contains("srcOccurred=true"))
        XCTAssertTrue(note.contains("srcAlgorithm=deterministic-linear-reference"))
        XCTAssertTrue(note.contains("srcPhaseMode=linearPhaseReference"))
        XCTAssertTrue(note.contains("srcInputRate=44100.0"))
        XCTAssertTrue(note.contains("srcOutputRate=48000.0"))
        XCTAssertTrue(note.contains("srcLatencyFrames=0"))
        XCTAssertTrue(note.contains("srcChannels=2"))
    }

    func testConverts96000SweepTo48000WithDeclaredLatencyAndAlgorithm() throws {
        let block = try makeBlock(sampleRate: .rate96000, channelCount: 2, frameCapacity: 16, layout: .stereo)
        try block.setChannelSamples((0..<16).map { Float($0) }, channel: 0)
        try block.setChannelSamples((0..<16).map { -Float($0) }, channel: 1)

        let profile = SourceRateConverterProfile.deterministicReference(
            inputSampleRate: .rate96000,
            outputSampleRate: .rate48000
        )
        let converter = DeterministicSourceRateConverter()
        let result = try converter.convert(
            block: block,
            profile: profile,
            context: context(sourceID: "sweep-960")
        )

        XCTAssertEqual(result.outputFrameCount, 8)
        XCTAssertEqual(try converter.latency(profile: profile), 0)
        XCTAssertEqual(result.profile.algorithm.stableName, "deterministic-linear-reference")

        for frame in 0..<8 {
            XCTAssertEqual(result.block.sample(channel: 0, frame: frame), Float(frame * 2), accuracy: tolerance)
            XCTAssertEqual(result.block.sample(channel: 1, frame: frame), -Float(frame * 2), accuracy: tolerance)
        }
    }

    func testMultichannelChannelWalkDoesNotBleedAcrossChannels() throws {
        let block = try makeBlock(
            sampleRate: .rate44100,
            channelCount: 4,
            frameCapacity: 32,
            layout: .quad
        )
        for channel in 0..<4 {
            try block.setChannelSamples(Array(repeating: Float(channel + 1), count: 32), channel: channel)
        }

        let result = try DeterministicSourceRateConverter().convert(
            block: block,
            profile: .deterministicReference(inputSampleRate: .rate44100, outputSampleRate: .rate48000),
            context: context(sourceID: "quad-walk")
        )

        XCTAssertEqual(result.block.channelCount, 4)
        for channel in 0..<4 {
            for frame in 0..<result.block.frameCount {
                XCTAssertEqual(
                    result.block.sample(channel: channel, frame: frame),
                    Float(channel + 1),
                    accuracy: tolerance,
                    "channel \(channel), frame \(frame)"
                )
            }
        }
    }

    func testRejectsNoOpProfileBeforeHiddenSRC() throws {
        let profile = SourceRateConverterProfile.deterministicReference(
            inputSampleRate: .rate48000,
            outputSampleRate: .rate48000
        )

        XCTAssertThrowsError(try DeterministicSourceRateConverter().configure(profile: profile)) { error in
            XCTAssertEqual(
                error as? AudioError,
                .invalidRenderGraphPlan("SourceRateConverter requires distinct input and output rates.")
            )
        }
    }

    func testRejectsDoubleSRCWhenLedgerAlreadyContainsSampleRateConversion() throws {
        let block = try makeBlock(sampleRate: .rate44100, channelCount: 2, frameCapacity: 8, layout: .stereo)
        try block.setChannelSamples(Array(repeating: 0.25, count: 8), channel: 0)
        try block.setChannelSamples(Array(repeating: -0.25, count: 8), channel: 1)
        let existingLedger = AudioConversionLedger(
            sessionID: "existing-session",
            sourceID: "double-src",
            sourceKind: .localFile,
            entries: [
                AudioConversionLedgerEntry(
                    stage: .sampleRateConversion,
                    owner: .sourceRateConverter,
                    isExplicit: true,
                    note: "previous explicit SRC"
                )
            ]
        )

        XCTAssertThrowsError(
            try DeterministicSourceRateConverter().convert(
                block: block,
                profile: .deterministicReference(inputSampleRate: .rate44100, outputSampleRate: .rate48000),
                context: context(sourceID: "double-src", existingConversionLedger: existingLedger)
            )
        ) { error in
            XCTAssertEqual(error as? AudioError, .invalidRenderGraphPlan("SourceRateConverter refuses double SRC."))
        }
    }

    func testRejectsAlreadyConvertedBlockForProfileInputRate() throws {
        let block = try makeBlock(sampleRate: .rate48000, channelCount: 2, frameCapacity: 8, layout: .stereo)
        try block.setChannelSamples(Array(repeating: 0.25, count: 8), channel: 0)
        try block.setChannelSamples(Array(repeating: -0.25, count: 8), channel: 1)

        XCTAssertThrowsError(
            try DeterministicSourceRateConverter().convert(
                block: block,
                profile: .deterministicReference(inputSampleRate: .rate44100, outputSampleRate: .rate48000),
                context: context(sourceID: "already-48")
            )
        ) { error in
            guard case AudioError.sampleRateMismatch(let expected, let actual, let context) = error else {
                return XCTFail("Expected sample-rate mismatch, got \(error).")
            }
            XCTAssertEqual(expected, .rate44100)
            XCTAssertEqual(actual, .rate48000)
            XCTAssertEqual(context, "SourceRateConverter input")
        }
    }

    private func makeBlock(
        sampleRate: AudioSampleRate,
        channelCount: Int,
        frameCapacity: Int,
        layout: AudioChannelLayoutDescriptor
    ) throws -> CanonicalAudioBlock {
        try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: sampleRate,
                channelCount: channelCount,
                frameCount: frameCapacity,
                layout: layout
            )
        )
    }

    private func context(
        sourceID: String,
        existingConversionLedger: AudioConversionLedger? = nil
    ) -> SourceRateConversionContext {
        SourceRateConversionContext(
            sessionID: "src-test-session",
            sourceID: sourceID,
            sourceKind: .localFile,
            generation: 2,
            frameStart: 0,
            layoutAuthority: .containerMetadata,
            existingConversionLedger: existingConversionLedger
        )
    }
}
