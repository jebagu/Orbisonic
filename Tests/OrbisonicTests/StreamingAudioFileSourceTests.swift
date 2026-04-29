import AVFoundation
import XCTest
@testable import Orbisonic

final class StreamingAudioFileSourceTests: XCTestCase {
    func testAVFoundationDecoderReadsBoundedChunks() throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let audioURL = directory.appendingPathComponent("chunked.wav")
        try Self.writeSilentAudioFile(to: audioURL, frames: 20_000)

        let decoder = try AVFoundationPCMFrameDecoder(url: audioURL)
        defer { decoder.close() }

        XCTAssertEqual(decoder.descriptor.durationFrames, 20_000)
        XCTAssertEqual(decoder.descriptor.channelCount, 2)

        let first = try XCTUnwrap(decoder.readNextChunk(maxFrames: 4_096))
        XCTAssertEqual(first.startFrame, 0)
        XCTAssertEqual(first.frameCount, 4_096)
        XCTAssertLessThanOrEqual(first.byteCount, 4_096 * 2 * MemoryLayout<Float>.size)

        let second = try XCTUnwrap(decoder.readNextChunk(maxFrames: 4_096))
        XCTAssertEqual(second.startFrame, 4_096)
        XCTAssertEqual(second.frameCount, 4_096)
    }

    func testBoundedPCMQueueRejectsChunksLargerThanMemoryCap() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let audioURL = directory.appendingPathComponent("queue.wav")
        try Self.writeSilentAudioFile(to: audioURL, frames: 1_024)

        let decoder = try AVFoundationPCMFrameDecoder(url: audioURL)
        defer { decoder.close() }
        let chunk = try XCTUnwrap(decoder.readNextChunk(maxFrames: 1_024))
        let queue = BoundedPCMQueue(maxBytes: max(chunk.byteCount - 1, 1))

        do {
            try await queue.enqueue(chunk)
            XCTFail("Expected queue cap to reject oversized chunk")
        } catch StreamingAudioFileSourceError.chunkExceedsQueueLimit(let chunkBytes, let maxBytes) {
            XCTAssertEqual(chunkBytes, chunk.byteCount)
            XCTAssertLessThan(maxBytes, chunk.byteCount)
        } catch {
            XCTFail("Unexpected queue error: \(error)")
        }
    }

    func testStreamingSourceProducesChunksWithoutFullFilePreparation() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let audioURL = directory.appendingPathComponent("source.wav")
        try Self.writeSilentAudioFile(to: audioURL, frames: 12_000)

        let configuration = StreamingAudioFileSource.Configuration(
            initialPrerollFrames: 1_024,
            steadyChunkFrames: 1_024,
            targetBufferAheadSeconds: 0.025,
            maxBufferedPCMBytes: 1_024 * 2 * MemoryLayout<Float>.size * 4
        )
        let source = StreamingAudioFileSource(url: audioURL, configuration: configuration)
        defer { source.cancel() }

        source.start()
        let maybeFirst = try await source.nextChunk()
        let first = try XCTUnwrap(maybeFirst)
        XCTAssertEqual(first.startFrame, 0)
        XCTAssertEqual(first.frameCount, 1_024)

        let snapshot = await source.bufferSnapshot()
        XCTAssertLessThanOrEqual(snapshot.queuedBytes, configuration.maxBufferedPCMBytes)
    }

    @MainActor
    func testEngineStartsStreamingSourceThroughExistingPlayerGraph() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let audioURL = directory.appendingPathComponent("engine-stream.wav")
        try Self.writeSilentAudioFile(to: audioURL, frames: 96_000)

        let descriptor = try await AudioFileProbe().probe(url: audioURL)
        let configuration = StreamingAudioFileSource.Configuration(
            initialPrerollFrames: 1_024,
            steadyChunkFrames: 1_024,
            targetBufferAheadSeconds: 0.05,
            maxBufferedPCMBytes: 1_024 * 2 * MemoryLayout<Float>.size * 6
        )
        let source = StreamingAudioFileSource(url: audioURL, configuration: configuration)
        let engine = OrbisonicEngine()
        defer { engine.stop() }

        try await engine.startStreaming(source: source, descriptor: descriptor)

        XCTAssertEqual(engine.state, .playing)
        XCTAssertEqual(engine.duration(), descriptor.durationSeconds ?? 0, accuracy: 0.001)
        XCTAssertEqual(engine.channelMeterLevels().count, descriptor.channelCount)
        XCTAssertGreaterThanOrEqual(engine.currentTime(), 0)
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("orbisonic-streaming-source-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func writeSilentAudioFile(to url: URL, frames: AVAudioFrameCount) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)
        else {
            XCTFail("Could not create test audio format")
            return
        }

        buffer.frameLength = frames
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
}
