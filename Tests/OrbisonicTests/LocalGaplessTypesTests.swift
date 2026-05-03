import AVFoundation
import XCTest
@testable import Orbisonic

final class LocalGaplessTypesTests: XCTestCase {
    func testSchedulerConfigDefaultsComeFromFeatureFlags() {
        let config = LocalGaplessSchedulerConfig()

        XCTAssertEqual(config.isEnabled, LocalGaplessPlaybackPolicy.enableLocalGaplessScheduler)
        XCTAssertEqual(config.targetAheadSeconds, LocalGaplessPlaybackPolicy.localGaplessTargetAheadSeconds, accuracy: 0.001)
        XCTAssertEqual(config.chunkFrames, LocalGaplessPlaybackPolicy.localGaplessChunkFrames)
        XCTAssertEqual(config.maxRetainedPCMBytes, LocalGaplessPlaybackPolicy.localGaplessMaxRetainedPCMBytes)
        XCTAssertEqual(config.enableCompressedTrim, LocalGaplessPlaybackPolicy.localGaplessEnableCompressedTrim)
    }

    func testTrimInfoClampsInvalidFrameCounts() {
        let trim = GaplessTrimInfo(
            leadingPrimingFrames: -12,
            trailingPaddingFrames: -4,
            validFrameCount: -100,
            isTrustworthy: true
        )

        XCTAssertEqual(trim.leadingPrimingFrames, 0)
        XCTAssertEqual(trim.trailingPaddingFrames, 0)
        XCTAssertEqual(trim.validFrameCount, 0)
        XCTAssertTrue(trim.isTrustworthy)
    }

    func testDecodedChunkCarriesTrackFrameRangeAndBoundaryFlags() throws {
        let track = LocalGaplessTrackDescriptor(
            id: "track-1",
            url: URL(fileURLWithPath: "/tmp/track-1.wav"),
            queueIndex: 3,
            displayName: "Track 1"
        )
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1_024))
        buffer.frameLength = 768

        let chunk = LocalDecodedChunk(
            buffer: buffer,
            track: track,
            sourceFrameRange: 2_048..<2_816,
            startsLogicalTrack: true,
            endsLogicalTrack: false
        )

        XCTAssertEqual(chunk.track, track)
        XCTAssertEqual(chunk.frameCount, 768)
        XCTAssertEqual(chunk.sourceFrameRange, 2_048..<2_816)
        XCTAssertTrue(chunk.startsLogicalTrack)
        XCTAssertFalse(chunk.endsLogicalTrack)
    }

    func testSchedulerEventsUseLightweightTrackDescriptors() {
        let track = LocalGaplessTrackDescriptor(
            id: "queue-item-2",
            url: URL(fileURLWithPath: "/tmp/next.flac"),
            queueIndex: 2,
            displayName: "Next"
        )

        XCTAssertEqual(
            LocalGaplessSchedulerEvent.logicalTrackStarted(track),
            .logicalTrackStarted(track)
        )
        XCTAssertEqual(
            LocalGaplessSchedulerEvent.gaplessMiss(track: track, reason: "incompatible format"),
            .gaplessMiss(track: track, reason: "incompatible format")
        )
        XCTAssertEqual(
            LocalGaplessSchedulerEvent.schedulerStopped(reason: "generation invalidated"),
            .schedulerStopped(reason: "generation invalidated")
        )
    }
}
