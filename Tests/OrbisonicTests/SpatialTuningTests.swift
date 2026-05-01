import AVFoundation
import CoreAudioTypes
import XCTest
@testable import Orbisonic

final class SpatialTuningTests: XCTestCase {
    func testDisplayOrderingKeepsLfeLast() {
        let channels = [
            SurroundChannel(index: 0, role: .lfe),
            SurroundChannel(index: 1, role: .frontLeft),
            SurroundChannel(index: 2, role: .frontRight),
            SurroundChannel(index: 3, role: .rearLeft)
        ]

        XCTAssertEqual(
            channels.displayOrdered().map(\.role),
            [.frontLeft, .frontRight, .rearLeft, .lfe]
        )
    }

    func testFallbackFivePointOneLayoutIncludesCenterAndLFE() {
        let layout = SurroundLayoutDetector.fallbackLayout(for: 6)
        XCTAssertEqual(layout.name, "5.1 Surround")
        XCTAssertEqual(layout.channels.map(\.role), [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight])
    }

    func testTagOnlyMPEGFivePointOneCLayoutKeepsTaggedChannelOrder() {
        let channelLayout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_MPEG_5_1_C)!
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            interleaved: false,
            channelLayout: channelLayout
        )

        let layout = SurroundLayoutDetector.detect(for: format)

        XCTAssertEqual(layout.name, "5.1 Surround")
        XCTAssertEqual(layout.channels.map(\.role), [.frontLeft, .center, .frontRight, .sideLeft, .sideRight, .lfe])
        XCTAssertEqual(layout.channelSummary, "FL, C, FR, SL, SR, LFE1")
    }

    func testFallbackSevenPointOnePointFourLayoutIncludesTopRearChannels() {
        let layout = SurroundLayoutDetector.fallbackLayout(for: 12)
        XCTAssertEqual(layout.name, "7.1.4")
        XCTAssertTrue(layout.channels.map(\.role).contains(.topRearLeft))
        XCTAssertTrue(layout.channels.map(\.role).contains(.topRearRight))
    }

    func testFallbackNinePointTwoLayoutUsesDualLFE() {
        let layout = SurroundLayoutDetector.fallbackLayout(for: 11)
        XCTAssertEqual(layout.name, "9.2 Surround")
        XCTAssertEqual(layout.channels.filter { $0.role.isLFE }.count, 2)
    }

    func testDirectOutputToneBypassesSpatialChannel() {
        XCTAssertNil(TestTonePipelinePoint.directOutput.spatialChannel)
        XCTAssertEqual(TestTonePipelinePoint.directOutput.meterChannels.map(\.role), [.frontLeft, .frontRight])
    }

    func testDiagnosticTonesDoNotUseSpatialRendererChannels() {
        XCTAssertNil(TestTonePipelinePoint.rendererRearRight.spatialChannel)
        XCTAssertFalse(TestTonePipelinePoint.rendererRearRight.pipelineDescription.contains("AVAudioEnvironmentNode"))
        XCTAssertTrue(TestTonePipelinePoint.rendererRearRight.pipelineDescription.contains("Normal Monitor"))
    }
}
