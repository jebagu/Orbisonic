import AVFoundation
import XCTest
@testable import Orbisonic

final class AudioFileProbeTests: XCTestCase {
    func testProbeReadsWAVDescriptorWithoutPreparedBuffers() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let audioURL = directory.appendingPathComponent("stereo.wav")
        try Self.writeSilentAudioFile(to: audioURL, frames: 48_000)

        let descriptor = try await AudioFileProbe().probe(url: audioURL)

        XCTAssertEqual(descriptor.url, audioURL)
        XCTAssertEqual(descriptor.durationFrames, 48_000)
        XCTAssertEqual(descriptor.durationSeconds ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(descriptor.sourceSampleRate, 48_000, accuracy: 0.5)
        XCTAssertEqual(descriptor.channelCount, 2)
        XCTAssertEqual(descriptor.channelLayout.name, "Stereo")
        XCTAssertEqual(descriptor.estimatedDecodedBytes, Int64(48_000 * 2 * MemoryLayout<Float>.size))
        XCTAssertEqual(descriptor.codecDescription, "PCM")
    }

    func testProbeReadsMatroskaDescriptorWithoutDemuxing() async throws {
        guard let ffmpegURL = FFmpegToolLocator.ffmpegURL(),
              FFmpegToolLocator.ffprobeURL() != nil
        else {
            throw XCTSkip("ffmpeg/ffprobe unavailable")
        }

        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let fixtureURL = directory.appendingPathComponent("surround.mka")
        let result = try MatroskaAudioProbe.runProcess(
            executableURL: ffmpegURL,
            arguments: [
                "-v", "error",
                "-y",
                "-f", "lavfi",
                "-i", "anullsrc=channel_layout=7.1:sample_rate=96000",
                "-t", "0.1",
                "-c:a", "flac",
                fixtureURL.path
            ]
        )

        guard result.terminationStatus == 0 else {
            throw XCTSkip("ffmpeg Matroska fixture generation failed: \(result.errorText)")
        }

        let descriptor = try await AudioFileProbe().probe(url: fixtureURL)

        XCTAssertEqual(descriptor.url, fixtureURL)
        XCTAssertEqual(descriptor.sourceSampleRate, 96_000, accuracy: 0.5)
        XCTAssertEqual(descriptor.channelCount, 8)
        XCTAssertEqual(descriptor.channelLayout.name, "7.1 Surround")
        XCTAssertEqual(descriptor.codecDescription, "FLAC")
        XCTAssertEqual(descriptor.containerDescription, "Matroska")
        XCTAssertGreaterThan(descriptor.estimatedDecodedBytes ?? 0, 0)
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("orbisonic-audio-probe-tests-\(UUID().uuidString)", isDirectory: true)
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
