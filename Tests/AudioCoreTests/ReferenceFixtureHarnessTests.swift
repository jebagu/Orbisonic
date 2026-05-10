import AudioContracts
import AudioCore
import Foundation
import XCTest

final class ReferenceFixtureHarnessTests: XCTestCase {
    func testGeneratedFixturesAreDeterministicAcrossRuns() throws {
        let first = try ReferenceFixtureHarness.requiredFixtures().map(\.metrics)
        let second = try ReferenceFixtureHarness.requiredFixtures().map(\.metrics)

        XCTAssertEqual(first.map(\.stableHash), second.map(\.stableHash))
        XCTAssertEqual(first.map(\.summary), second.map(\.summary))
    }

    func testGeneratedFixturesCoverRequiredChannelShapesAndIdentityFacts() throws {
        let fixtures = try ReferenceFixtureHarness.requiredFixtures()

        XCTAssertEqual(fixtures.map(\.kind.name), ["stereo", "surround51", "surround71", "direct30", "high52"])
        XCTAssertEqual(fixtures.map(\.block.channelCount), [2, 6, 8, 30, 52])

        for fixture in fixtures {
            let metrics = fixture.metrics
            XCTAssertEqual(metrics.activeChannelCount, fixture.block.channelCount, fixture.kind.name)
            XCTAssertEqual(metrics.firstNonZeroFrameByChannel.first ?? nil, 1, fixture.kind.name)
            XCTAssertEqual(metrics.firstNonZeroFrameByChannel.last ?? nil, fixture.block.channelCount, fixture.kind.name)
            XCTAssertEqual(try XCTUnwrap(metrics.peakByChannel.first), 1.0 / 128.0, accuracy: 0.000_001)
        }
    }

    func testChannelIdentityComparisonCatchesDownmixTruncationAndSwap() throws {
        let fixture = try ReferenceFixtureHarness.fixture(kind: .surround51)
        let expected = fixture.metrics

        let downmixed = try ReferenceFixtureHarness.stereoDownmixLikeMutation(fixture)
        XCTAssertTrue(
            ReferenceFixtureHarness
                .identityMismatches(expected: expected, actual: downmixed.metrics)
                .contains { $0.contains("channel count") }
        )

        let truncated = try ReferenceFixtureHarness.truncatedMutation(fixture, channelCount: 2)
        XCTAssertTrue(
            ReferenceFixtureHarness
                .identityMismatches(expected: expected, actual: truncated.metrics)
                .contains { $0.contains("channel count") }
        )

        let swapped = try ReferenceFixtureHarness.swappedMutation(fixture, firstChannel: 0, secondChannel: 1)
        XCTAssertTrue(
            ReferenceFixtureHarness
                .identityMismatches(expected: expected, actual: swapped.metrics)
                .contains { $0.contains("first non-zero") }
        )
    }

    func testDirect30IdentityRendererPreservesReferenceFixtureChannelIdentity() throws {
        let fixture = try ReferenceFixtureHarness.fixture(kind: .direct30)
        let sourceBlock = try CanonicalSourceBlock(
            contract: AudioBlockContract(
                sourceID: fixture.sourceID,
                generation: 16,
                sampleRate: fixture.block.sampleRate,
                frameStart: 0,
                frameCount: fixture.block.frameCount,
                channelCount: fixture.block.channelCount,
                processingFormat: .float32NonInterleavedPCM,
                layout: SourceLayout(descriptor: .direct30, authority: .containerMetadata)
            )
        )

        let rendered = try MatrixSonicSphereRenderer().render(
            source: fixture.block,
            sourceBlock: sourceBlock,
            profile: .directThirtyOne(),
            policy: .direct30Identity,
            context: SonicSphereRenderContext(sessionID: "reference-fixture-harness", sourceKind: .localFile)
        )

        let expected = try ReferenceFixtureHarness.directThirtyOneExpectation(from: fixture)
        let mismatches = ReferenceFixtureHarness.identityMismatches(
            expected: expected.metrics,
            actual: ReferenceFixtureHarness.metrics(for: rendered.samples, fixtureName: "rendered-direct31")
        )

        XCTAssertTrue(mismatches.isEmpty, mismatches.joined(separator: "\n"))
    }

    func testMetricsSummaryDoesNotExposePrivatePaths() throws {
        let summary = try ReferenceFixtureHarness.fixture(kind: .surround71).metrics.summary

        XCTAssertFalse(summary.contains("/Users/"))
        XCTAssertFalse(summary.contains("/private/"))
        XCTAssertFalse(summary.contains(FileManager.default.temporaryDirectory.path))
    }

    func testExternalToolFixtureGenerationSkipsExplicitlyWhenUnavailable() throws {
        guard let ffmpegURL = ReferenceFixtureHarness.executableURL(named: "ffmpeg") else {
            throw XCTSkip("ffmpeg unavailable for external reference fixture generation")
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("orbisonic-reference-fixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let outputURL = directory.appendingPathComponent("external-surround51.wav")
        let result = try ReferenceFixtureHarness.runProcess(
            executableURL: ffmpegURL,
            arguments: [
                "-v", "error",
                "-y",
                "-f", "lavfi",
                "-i", "anullsrc=channel_layout=5.1:sample_rate=48000",
                "-t", "0.01",
                "-c:a", "pcm_f32le",
                outputURL.path
            ]
        )

        guard result.terminationStatus == 0 else {
            throw XCTSkip("ffmpeg external reference fixture generation failed with status \(result.terminationStatus)")
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }
}

private enum ReferenceFixtureKind: Equatable, Hashable {
    case stereo
    case surround51
    case surround71
    case direct30
    case high52

    static let required: [ReferenceFixtureKind] = [.stereo, .surround51, .surround71, .direct30, .high52]

    var name: String {
        switch self {
        case .stereo: "stereo"
        case .surround51: "surround51"
        case .surround71: "surround71"
        case .direct30: "direct30"
        case .high52: "high52"
        }
    }

    var channelCount: Int {
        switch self {
        case .stereo: 2
        case .surround51: 6
        case .surround71: 8
        case .direct30: 30
        case .high52: 52
        }
    }

    var layout: AudioChannelLayoutDescriptor {
        switch self {
        case .stereo: .stereo
        case .surround51: .surround51
        case .surround71: .surround71
        case .direct30: .direct30
        case .high52: .discrete(count: 52)
        }
    }
}

private struct ReferenceAudioFixture {
    let kind: ReferenceFixtureKind
    let sourceID: String
    let block: CanonicalAudioBlock

    var metrics: ReferenceFixtureMetrics {
        ReferenceFixtureHarness.metrics(for: block, fixtureName: kind.name)
    }
}

private struct ReferenceFixtureMetrics: Equatable {
    let fixtureName: String
    let channelCount: Int
    let frameCount: Int
    let stableHash: String
    let peakByChannel: [Float]
    let rmsByChannel: [Double]
    let firstNonZeroFrameByChannel: [Int?]

    var activeChannelCount: Int {
        firstNonZeroFrameByChannel.filter { $0 != nil }.count
    }

    var summary: String {
        [
            "fixture=\(fixtureName)",
            "channels=\(channelCount)",
            "frames=\(frameCount)",
            "hash=\(stableHash)",
            "active=\(activeChannelCount)"
        ].joined(separator: ";")
    }
}

private struct ReferenceFixtureHarness {
    private static let epsilon: Float = 0.000_000_1
    private static let hashOffset: UInt64 = 14_695_981_039_346_656_037
    private static let hashPrime: UInt64 = 1_099_511_628_211

    static func requiredFixtures() throws -> [ReferenceAudioFixture] {
        try ReferenceFixtureKind.required.map(fixture(kind:))
    }

    static func fixture(kind: ReferenceFixtureKind) throws -> ReferenceAudioFixture {
        let frameCount = max(64, kind.channelCount + 4)
        let block = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: .rate48000,
                channelCount: kind.channelCount,
                frameCount: frameCount,
                layout: kind.layout
            )
        )

        try block.setFrameCount(frameCount)
        for channel in 0..<kind.channelCount {
            let frame = channel + 1
            let value = Float(channel + 1) / 128.0
            try block.setSample(value, channel: channel, frame: frame)
        }

        return ReferenceAudioFixture(
            kind: kind,
            sourceID: "reference-\(kind.name)",
            block: block
        )
    }

    static func metrics(for block: CanonicalAudioBlock, fixtureName: String) -> ReferenceFixtureMetrics {
        var peakByChannel: [Float] = []
        var rmsByChannel: [Double] = []
        var firstNonZeroFrameByChannel: [Int?] = []

        for channel in 0..<block.channelCount {
            var peak: Float = 0
            var sumSquares = 0.0
            var firstNonZeroFrame: Int?

            for frame in 0..<block.frameCount {
                let sample = block.sample(channel: channel, frame: frame)
                let magnitude = abs(sample)
                peak = max(peak, magnitude)
                sumSquares += Double(sample * sample)
                if firstNonZeroFrame == nil, magnitude > epsilon {
                    firstNonZeroFrame = frame
                }
            }

            peakByChannel.append(peak)
            rmsByChannel.append(sqrt(sumSquares / Double(max(block.frameCount, 1))))
            firstNonZeroFrameByChannel.append(firstNonZeroFrame)
        }

        return ReferenceFixtureMetrics(
            fixtureName: fixtureName,
            channelCount: block.channelCount,
            frameCount: block.frameCount,
            stableHash: stableHash(for: block),
            peakByChannel: peakByChannel,
            rmsByChannel: rmsByChannel,
            firstNonZeroFrameByChannel: firstNonZeroFrameByChannel
        )
    }

    static func identityMismatches(
        expected: ReferenceFixtureMetrics,
        actual: ReferenceFixtureMetrics,
        peakTolerance: Float = 0.000_001,
        rmsTolerance: Double = 0.000_001
    ) -> [String] {
        var mismatches: [String] = []
        if expected.channelCount != actual.channelCount {
            mismatches.append("channel count mismatch expected=\(expected.channelCount) actual=\(actual.channelCount)")
        }
        if expected.frameCount != actual.frameCount {
            mismatches.append("frame count mismatch expected=\(expected.frameCount) actual=\(actual.frameCount)")
        }

        let comparableChannels = min(expected.channelCount, actual.channelCount)
        for channel in 0..<comparableChannels {
            if expected.firstNonZeroFrameByChannel[channel] != actual.firstNonZeroFrameByChannel[channel] {
                mismatches.append(
                    "first non-zero frame mismatch channel=\(channel) expected=\(String(describing: expected.firstNonZeroFrameByChannel[channel])) actual=\(String(describing: actual.firstNonZeroFrameByChannel[channel]))"
                )
            }
            if abs(expected.peakByChannel[channel] - actual.peakByChannel[channel]) > peakTolerance {
                mismatches.append(
                    "peak mismatch channel=\(channel) expected=\(expected.peakByChannel[channel]) actual=\(actual.peakByChannel[channel])"
                )
            }
            if abs(expected.rmsByChannel[channel] - actual.rmsByChannel[channel]) > rmsTolerance {
                mismatches.append(
                    "rms mismatch channel=\(channel) expected=\(expected.rmsByChannel[channel]) actual=\(actual.rmsByChannel[channel])"
                )
            }
        }

        if mismatches.isEmpty, expected.stableHash != actual.stableHash {
            mismatches.append("hash mismatch expected=\(expected.stableHash) actual=\(actual.stableHash)")
        }
        return mismatches
    }

    static func stereoDownmixLikeMutation(_ fixture: ReferenceAudioFixture) throws -> ReferenceAudioFixture {
        let block = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: fixture.block.sampleRate,
                channelCount: 2,
                frameCount: fixture.block.frameCount,
                layout: .stereo
            )
        )
        try block.setFrameCount(fixture.block.frameCount)
        for frame in 0..<fixture.block.frameCount {
            var left: Float = 0
            var right: Float = 0
            for channel in 0..<fixture.block.channelCount {
                if channel.isMultiple(of: 2) {
                    left += fixture.block.sample(channel: channel, frame: frame)
                } else {
                    right += fixture.block.sample(channel: channel, frame: frame)
                }
            }
            try block.setSample(left, channel: 0, frame: frame)
            try block.setSample(right, channel: 1, frame: frame)
        }
        return ReferenceAudioFixture(kind: .stereo, sourceID: "mutated-downmix", block: block)
    }

    static func truncatedMutation(_ fixture: ReferenceAudioFixture, channelCount: Int) throws -> ReferenceAudioFixture {
        let block = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: fixture.block.sampleRate,
                channelCount: channelCount,
                frameCount: fixture.block.frameCount,
                layout: .discrete(count: channelCount)
            )
        )
        try block.setFrameCount(fixture.block.frameCount)
        for channel in 0..<channelCount {
            for frame in 0..<fixture.block.frameCount {
                try block.setSample(fixture.block.sample(channel: channel, frame: frame), channel: channel, frame: frame)
            }
        }
        return ReferenceAudioFixture(kind: .stereo, sourceID: "mutated-truncated", block: block)
    }

    static func swappedMutation(
        _ fixture: ReferenceAudioFixture,
        firstChannel: Int,
        secondChannel: Int
    ) throws -> ReferenceAudioFixture {
        let block = try copyBlock(from: fixture.block, layout: fixture.kind.layout)
        for frame in 0..<fixture.block.frameCount {
            try block.setSample(fixture.block.sample(channel: secondChannel, frame: frame), channel: firstChannel, frame: frame)
            try block.setSample(fixture.block.sample(channel: firstChannel, frame: frame), channel: secondChannel, frame: frame)
        }
        return ReferenceAudioFixture(kind: fixture.kind, sourceID: "mutated-swapped", block: block)
    }

    static func directThirtyOneExpectation(from fixture: ReferenceAudioFixture) throws -> ReferenceAudioFixture {
        let block = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: fixture.block.sampleRate,
                channelCount: 31,
                frameCount: fixture.block.frameCount,
                layout: .direct31
            )
        )
        try block.setFrameCount(fixture.block.frameCount)
        for channel in 0..<fixture.block.channelCount {
            for frame in 0..<fixture.block.frameCount {
                try block.setSample(fixture.block.sample(channel: channel, frame: frame), channel: channel, frame: frame)
            }
        }
        return ReferenceAudioFixture(kind: .direct30, sourceID: "expected-direct31", block: block)
    }

    static func executableURL(named toolName: String) -> URL? {
        let candidates = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
            .map { URL(fileURLWithPath: $0).appendingPathComponent(toolName) }
            + [
                URL(fileURLWithPath: "/opt/homebrew/bin").appendingPathComponent(toolName),
                URL(fileURLWithPath: "/usr/local/bin").appendingPathComponent(toolName),
                URL(fileURLWithPath: "/usr/bin").appendingPathComponent(toolName)
            ]

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static func runProcess(executableURL: URL, arguments: [String]) throws -> ProcessResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        return ProcessResult(terminationStatus: process.terminationStatus)
    }

    private static func copyBlock(from source: CanonicalAudioBlock, layout: AudioChannelLayoutDescriptor) throws -> CanonicalAudioBlock {
        let copy = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: source.sampleRate,
                channelCount: source.channelCount,
                frameCount: source.frameCount,
                layout: layout
            )
        )
        try copy.setFrameCount(source.frameCount)
        for channel in 0..<source.channelCount {
            for frame in 0..<source.frameCount {
                try copy.setSample(source.sample(channel: channel, frame: frame), channel: channel, frame: frame)
            }
        }
        return copy
    }

    private static func stableHash(for block: CanonicalAudioBlock) -> String {
        var hash = hashOffset
        combine(UInt64(block.channelCount), into: &hash)
        combine(UInt64(block.frameCount), into: &hash)
        combine(block.sampleRate.hertz.bitPattern, into: &hash)

        for channel in 0..<block.channelCount {
            for frame in 0..<block.frameCount {
                combine(UInt64(block.sample(channel: channel, frame: frame).bitPattern), into: &hash)
            }
        }

        return String(format: "%016llx", hash)
    }

    private static func combine(_ value: UInt64, into hash: inout UInt64) {
        var remaining = value
        for _ in 0..<8 {
            hash ^= remaining & 0xff
            hash = hash &* hashPrime
            remaining >>= 8
        }
    }
}

private struct ProcessResult {
    let terminationStatus: Int32
}
