import XCTest
@testable import Orbisonic

final class TestToneSupportTests: XCTestCase {
    func testDiagnosticSpeechPlayheadPreservesDurationWhenOutputRateIsHigher() {
        let sourceSamples = Array(repeating: Float(1), count: 2_205)
        let playhead = DiagnosticSpeechPlayhead(
            samples: sourceSamples,
            sourceSampleRate: 22_050,
            targetSampleRate: 48_000
        )

        var audibleFrameCount = 0
        for _ in 0..<5_000 {
            if playhead.nextSample() != 0 {
                audibleFrameCount += 1
            }
        }

        XCTAssertEqual(audibleFrameCount, 4_800)
        XCTAssertEqual(playhead.nextSample(), 0)
    }

    func testDiagnosticSpeechPlayheadInterpolatesBetweenSourceFrames() {
        let playhead = DiagnosticSpeechPlayhead(
            samples: [0, 1, 0],
            sourceSampleRate: 22_050,
            targetSampleRate: 44_100
        )

        XCTAssertEqual(playhead.nextSample(), 0, accuracy: 0.0001)
        XCTAssertEqual(playhead.nextSample(), 0.5, accuracy: 0.0001)
        XCTAssertEqual(playhead.nextSample(), 1, accuracy: 0.0001)
        XCTAssertEqual(playhead.nextSample(), 0.5, accuracy: 0.0001)
        XCTAssertEqual(playhead.nextSample(), 0, accuracy: 0.0001)
    }
}
