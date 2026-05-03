import AVFoundation
import XCTest
@testable import Orbisonic

final class LocalGaplessPlaybackPolicyTests: XCTestCase {
    func testGaplessSchedulerDefaultsAreConservative() {
        XCTAssertFalse(LocalGaplessPlaybackPolicy.defaultEnableLocalGaplessScheduler)
        XCTAssertEqual(LocalGaplessPlaybackPolicy.localGaplessTargetAheadSeconds, 4, accuracy: 0.001)
        XCTAssertEqual(LocalGaplessPlaybackPolicy.localGaplessChunkFrames, AVAudioFrameCount(16_384))
        XCTAssertEqual(LocalGaplessPlaybackPolicy.localGaplessMaxRetainedPCMBytes, 32 * 1_024 * 1_024)
        XCTAssertLessThanOrEqual(
            LocalGaplessPlaybackPolicy.localGaplessMaxRetainedPCMBytes,
            PreparedPCMPolicy.maxFullPreparedPCMBytes
        )
        XCTAssertFalse(LocalGaplessPlaybackPolicy.defaultLocalGaplessEnableCompressedTrim)
    }

    func testGaplessSchedulerPreferencesReadPersistedValues() throws {
        let suiteName = "Orbisonic.LocalGaplessPlaybackPolicyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        XCTAssertFalse(
            LocalGaplessPlaybackPolicy.bool(
                forKey: LocalGaplessPlaybackPolicy.enableLocalGaplessSchedulerKey,
                defaultValue: LocalGaplessPlaybackPolicy.defaultEnableLocalGaplessScheduler,
                defaults: defaults
            )
        )

        defaults.set(true, forKey: LocalGaplessPlaybackPolicy.enableLocalGaplessSchedulerKey)
        XCTAssertTrue(
            LocalGaplessPlaybackPolicy.bool(
                forKey: LocalGaplessPlaybackPolicy.enableLocalGaplessSchedulerKey,
                defaultValue: LocalGaplessPlaybackPolicy.defaultEnableLocalGaplessScheduler,
                defaults: defaults
            )
        )
    }

    func testGaplessSchedulerLogEventsCoverPlannedFailureModes() {
        let messages = Set(LocalGaplessSchedulerLogEvent.allCases.map(\.rawValue))

        XCTAssertEqual(
            messages,
            [
                "gapless scheduler enabled",
                "source open failed",
                "decoder underrun",
                "queue exhausted",
                "gapless miss",
                "generation invalidated",
                "compressed trim applied",
                "compressed trim unavailable"
            ]
        )
        XCTAssertEqual(LocalGaplessSchedulerLog.category, "gapless")
    }

    func testGaplessSchedulerLogMessageFormatsOptionalContext() {
        XCTAssertEqual(
            LocalGaplessSchedulerLog.message(
                .gaplessMiss,
                fileName: "next-track.flac",
                reason: "format mismatch"
            ),
            "event=\"gapless miss\" file=\"next-track.flac\" reason=\"format mismatch\""
        )
        XCTAssertEqual(
            LocalGaplessSchedulerLog.message(.queueExhausted),
            "event=\"queue exhausted\""
        )
    }
}
