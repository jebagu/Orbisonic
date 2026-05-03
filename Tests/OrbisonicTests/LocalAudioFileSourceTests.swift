import AVFoundation
import XCTest
@testable import Orbisonic

final class LocalAudioFileSourceTests: XCTestCase {
    func testReadsLocalWAVInBoundedChunksUntilEOF() throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let audioURL = directory.appendingPathComponent("bounded.wav")
        let format = try Self.makeFormat(sampleRate: 48_000, channels: 2)
        try Self.writeAudioFile(to: audioURL, format: format, frames: 10_000)
        let config = LocalGaplessSchedulerConfig(chunkFrames: 2_048)
        let track = LocalGaplessTrackDescriptor(id: "bounded-track", url: audioURL, queueIndex: 4, displayName: "Bounded")
        let source = try LocalAudioFileSource(track: track, outputFormat: format, config: config)
        defer { source.close() }

        var chunks: [LocalDecodedChunk] = []
        while let chunk = try source.readNextChunk(maxFrames: 8_192) {
            XCTAssertGreaterThan(chunk.frameCount, 0)
            XCTAssertLessThanOrEqual(chunk.frameCount, config.chunkFrames)
            XCTAssertEqual(chunk.track, track)
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks.count, 5)
        XCTAssertEqual(chunks.first?.sourceFrameRange, 0..<2_048)
        XCTAssertEqual(chunks.first?.startsLogicalTrack, true)
        XCTAssertEqual(chunks.first?.endsLogicalTrack, false)
        XCTAssertEqual(chunks.last?.sourceFrameRange, 8_192..<10_000)
        XCTAssertEqual(chunks.last?.endsLogicalTrack, true)
        XCTAssertEqual(totalFrames(in: chunks), 10_000)
        XCTAssertEqual(source.readPosition, 10_000)
        XCTAssertNil(try source.readNextChunk(maxFrames: 2_048))
    }

    func testSeekByFrameResetsReadPositionAndNextChunkRange() throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let audioURL = directory.appendingPathComponent("seek-frame.wav")
        let format = try Self.makeFormat(sampleRate: 48_000, channels: 2)
        try Self.writeAudioFile(to: audioURL, format: format, frames: 6_000)
        let source = try LocalAudioFileSource(url: audioURL, outputFormat: format, config: LocalGaplessSchedulerConfig(chunkFrames: 1_024))
        defer { source.close() }

        _ = try XCTUnwrap(source.readNextChunk(maxFrames: 1_024))
        try source.seek(to: 2_500)
        let chunk = try XCTUnwrap(source.readNextChunk(maxFrames: 1_000))

        XCTAssertEqual(source.readPosition, 3_500)
        XCTAssertEqual(chunk.sourceFrameRange, 2_500..<3_500)
        XCTAssertFalse(chunk.startsLogicalTrack)
        XCTAssertFalse(chunk.endsLogicalTrack)
    }

    func testSeekBySecondsUsesSourceSampleRate() throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let audioURL = directory.appendingPathComponent("seek-seconds.wav")
        let format = try Self.makeFormat(sampleRate: 48_000, channels: 2)
        try Self.writeAudioFile(to: audioURL, format: format, frames: 8_000)
        let source = try LocalAudioFileSource(url: audioURL, outputFormat: format, config: LocalGaplessSchedulerConfig(chunkFrames: 512))
        defer { source.close() }

        try source.seek(toSeconds: 0.05)
        let chunk = try XCTUnwrap(source.readNextChunk(maxFrames: 512))

        XCTAssertEqual(chunk.sourceFrameRange, 2_400..<2_912)
        XCTAssertEqual(source.readPosition, 2_912)
    }

    func testOutputBufferUsesRequestedCanonicalFormat() throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let audioURL = directory.appendingPathComponent("canonical.wav")
        let sourceFormat = try Self.makeFormat(sampleRate: 44_100, channels: 2)
        let outputFormat = try Self.makeFormat(sampleRate: 48_000, channels: 2)
        try Self.writeAudioFile(to: audioURL, format: sourceFormat, frames: 4_410)
        let source = try LocalAudioFileSource(url: audioURL, outputFormat: outputFormat, config: LocalGaplessSchedulerConfig(chunkFrames: 1_024))
        defer { source.close() }

        let chunk = try XCTUnwrap(source.readNextChunk(maxFrames: 1_024))

        XCTAssertGreaterThan(chunk.frameCount, 0)
        XCTAssertEqual(chunk.sourceFrameRange, 0..<1_024)
        XCTAssertEqual(chunk.buffer.format.commonFormat, outputFormat.commonFormat)
        XCTAssertEqual(chunk.buffer.format.sampleRate, outputFormat.sampleRate, accuracy: 0.001)
        XCTAssertEqual(chunk.buffer.format.channelCount, outputFormat.channelCount)
        XCTAssertEqual(chunk.buffer.format.isInterleaved, outputFormat.isInterleaved)
    }

    func testFormatNormalizationCoversCommonLocalSourceShapes() throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let cases: [(name: String, sourceSampleRate: Double, outputSampleRate: Double, channels: AVAudioChannelCount)] = [
            ("stereo-44k-to-48k", 44_100, 48_000, 2),
            ("stereo-48k-to-48k", 48_000, 48_000, 2),
            ("mono-44k-to-48k", 44_100, 48_000, 1),
            ("mono-48k-to-48k", 48_000, 48_000, 1)
        ]

        for testCase in cases {
            let audioURL = directory.appendingPathComponent("\(testCase.name).wav")
            let sourceFormat = try Self.makeFormat(sampleRate: testCase.sourceSampleRate, channels: testCase.channels)
            let outputFormat = try Self.makeFormat(sampleRate: testCase.outputSampleRate, channels: testCase.channels)
            try Self.writeAudioFile(to: audioURL, format: sourceFormat, frames: 2_048)

            let source = try LocalAudioFileSource(
                url: audioURL,
                outputFormat: outputFormat,
                config: LocalGaplessSchedulerConfig(chunkFrames: 512)
            )
            defer { source.close() }

            let chunk = try XCTUnwrap(source.readNextChunk(maxFrames: 512), testCase.name)
            let expectedMaxOutputFrames = Int(
                ceil(512.0 * testCase.outputSampleRate / testCase.sourceSampleRate)
            ) + 2

            XCTAssertGreaterThan(chunk.frameCount, 0, testCase.name)
            XCTAssertLessThanOrEqual(Int(chunk.frameCount), expectedMaxOutputFrames, testCase.name)
            XCTAssertEqual(chunk.buffer.format.commonFormat, outputFormat.commonFormat, testCase.name)
            XCTAssertEqual(chunk.buffer.format.sampleRate, outputFormat.sampleRate, accuracy: 0.001, testCase.name)
            XCTAssertEqual(chunk.buffer.format.channelCount, outputFormat.channelCount, testCase.name)
            XCTAssertEqual(chunk.buffer.format.isInterleaved, outputFormat.isInterleaved, testCase.name)
        }
    }

    func testPCMFileDoesNotReceiveArtificialTrimWhenCompressedTrimEnabled() throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let audioURL = directory.appendingPathComponent("pcm-intentional-silence.wav")
        let format = try Self.makeFormat(sampleRate: 48_000, channels: 2)
        try Self.writeAudioFile(
            to: audioURL,
            format: format,
            frames: 1_000,
            leadingSilentFrames: 128,
            trailingSilentFrames: 192
        )
        let source = try LocalAudioFileSource(
            url: audioURL,
            outputFormat: format,
            config: LocalGaplessSchedulerConfig(
                chunkFrames: 256,
                enableCompressedTrim: true
            )
        )
        defer { source.close() }

        var chunks: [LocalDecodedChunk] = []
        while let chunk = try source.readNextChunk(maxFrames: 512) {
            chunks.append(chunk)
        }

        XCTAssertFalse(source.trimInfo.isTrustworthy)
        XCTAssertEqual(source.trimInfo.validFrameCount, 1_000)
        XCTAssertEqual(chunks.first?.sourceFrameRange, 0..<256)
        XCTAssertEqual(chunks.last?.sourceFrameRange, 768..<1_000)
        XCTAssertEqual(totalFrames(in: chunks), 1_000)
    }

    func testTrustedTrimMetadataSkipsPrimingAndStopsBeforePadding() throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let audioURL = directory.appendingPathComponent("trusted-trim.wav")
        let format = try Self.makeFormat(sampleRate: 48_000, channels: 2)
        try Self.writeAudioFile(to: audioURL, format: format, frames: 1_000)
        let source = try LocalAudioFileSource(
            url: audioURL,
            outputFormat: format,
            config: LocalGaplessSchedulerConfig(
                chunkFrames: 300,
                enableCompressedTrim: true
            ),
            trimInfoOverride: GaplessTrimInfo(
                leadingPrimingFrames: 100,
                trailingPaddingFrames: 100,
                validFrameCount: 800,
                isTrustworthy: true
            )
        )
        defer { source.close() }

        let first = try XCTUnwrap(source.readNextChunk(maxFrames: 1_000))
        XCTAssertEqual(first.sourceFrameRange, 100..<400)
        XCTAssertTrue(first.startsLogicalTrack)
        XCTAssertFalse(first.endsLogicalTrack)

        let second = try XCTUnwrap(source.readNextChunk(maxFrames: 1_000))
        let third = try XCTUnwrap(source.readNextChunk(maxFrames: 1_000))

        XCTAssertEqual(second.sourceFrameRange, 400..<700)
        XCTAssertEqual(third.sourceFrameRange, 700..<900)
        XCTAssertEqual(third.frameCount, 200)
        XCTAssertFalse(third.startsLogicalTrack)
        XCTAssertTrue(third.endsLogicalTrack)
        XCTAssertNil(try source.readNextChunk(maxFrames: 1_000))
        XCTAssertEqual(source.readPosition, 800)
        XCTAssertEqual(source.trimInfo.leadingPrimingFrames, 100)
        XCTAssertEqual(source.trimInfo.trailingPaddingFrames, 100)
        XCTAssertEqual(source.trimInfo.validFrameCount, 800)
        XCTAssertTrue(source.trimInfo.isTrustworthy)
    }

    func testSeekUsesLogicalFrameInsideTrustedTrimWindow() throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let audioURL = directory.appendingPathComponent("trimmed-seek.wav")
        let format = try Self.makeFormat(sampleRate: 48_000, channels: 2)
        try Self.writeAudioFile(to: audioURL, format: format, frames: 1_000)
        let source = try LocalAudioFileSource(
            url: audioURL,
            outputFormat: format,
            config: LocalGaplessSchedulerConfig(
                chunkFrames: 100,
                enableCompressedTrim: true
            ),
            trimInfoOverride: GaplessTrimInfo(
                leadingPrimingFrames: 100,
                trailingPaddingFrames: 200,
                validFrameCount: 700,
                isTrustworthy: true
            )
        )
        defer { source.close() }

        try source.seek(to: 50)
        let chunk = try XCTUnwrap(source.readNextChunk(maxFrames: 100))

        XCTAssertEqual(chunk.sourceFrameRange, 150..<250)
        XCTAssertFalse(chunk.startsLogicalTrack)
        XCTAssertFalse(chunk.endsLogicalTrack)
        XCTAssertEqual(source.readPosition, 150)
    }

    func testUntrustedTrimMetadataDoesNotStripIntentionalSilence() throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let audioURL = directory.appendingPathComponent("untrusted-trim-silence.wav")
        let format = try Self.makeFormat(sampleRate: 48_000, channels: 2)
        try Self.writeAudioFile(
            to: audioURL,
            format: format,
            frames: 1_000,
            leadingSilentFrames: 200,
            trailingSilentFrames: 200
        )
        let source = try LocalAudioFileSource(
            url: audioURL,
            outputFormat: format,
            config: LocalGaplessSchedulerConfig(
                chunkFrames: 400,
                enableCompressedTrim: true
            ),
            trimInfoOverride: GaplessTrimInfo(
                leadingPrimingFrames: 200,
                trailingPaddingFrames: 200,
                validFrameCount: 600,
                isTrustworthy: false
            )
        )
        defer { source.close() }

        let first = try XCTUnwrap(source.readNextChunk(maxFrames: 400))
        let second = try XCTUnwrap(source.readNextChunk(maxFrames: 400))
        let third = try XCTUnwrap(source.readNextChunk(maxFrames: 400))

        XCTAssertFalse(source.trimInfo.isTrustworthy)
        XCTAssertEqual(first.sourceFrameRange, 0..<400)
        XCTAssertEqual(second.sourceFrameRange, 400..<800)
        XCTAssertEqual(third.sourceFrameRange, 800..<1_000)
        XCTAssertEqual(first.frameCount + second.frameCount + third.frameCount, 1_000)
        XCTAssertTrue(third.endsLogicalTrack)
    }

    private func totalFrames(in chunks: [LocalDecodedChunk]) -> AVAudioFramePosition {
        chunks.reduce(0) { partial, chunk in
            partial + AVAudioFramePosition(chunk.frameCount)
        }
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("orbisonic-local-audio-source-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func makeFormat(sampleRate: Double, channels: AVAudioChannelCount) throws -> AVAudioFormat {
        try XCTUnwrap(
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: channels,
                interleaved: false
            )
        )
    }

    private static func writeAudioFile(
        to url: URL,
        format: AVAudioFormat,
        frames: AVAudioFrameCount,
        leadingSilentFrames: AVAudioFrameCount = 0,
        trailingSilentFrames: AVAudioFrameCount = 0
    ) throws {
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        if let channelData = buffer.floatChannelData {
            for channel in 0..<Int(format.channelCount) {
                for frame in 0..<Int(frames) {
                    let frameIndex = AVAudioFrameCount(frame)
                    let isIntentionalSilence = frameIndex < leadingSilentFrames ||
                        frameIndex >= frames - trailingSilentFrames
                    channelData[channel][frame] = isIntentionalSilence ? 0 : (channel == 0 ? 0.125 : -0.125)
                }
            }
        }

        let file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
        try file.write(from: buffer)
    }
}
