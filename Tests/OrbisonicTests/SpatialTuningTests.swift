import AVFoundation
import XCTest
@testable import Orbisonic

final class SpatialTuningTests: XCTestCase {
    func testFrontLeftPositionLivesOnTheLeftAndInFront() {
        let point = SpatialTuning.default.position(for: SurroundChannel(index: 0, role: .frontLeft))
        XCTAssertLessThan(point.x, 0)
        XCTAssertLessThan(point.z, 0)
    }

    func testRearRightPositionLivesOnTheRightAndBehind() {
        let point = SpatialTuning.default.position(for: SurroundChannel(index: 0, role: .rearRight))
        XCTAssertGreaterThan(point.x, 0)
        XCTAssertGreaterThan(point.z, 0)
    }

    func testLFEPositionLivesOnTheRightAndBehind() {
        let point = SpatialTuning.default.position(for: SurroundChannel(index: 0, role: .lfe))
        XCTAssertGreaterThan(point.x, 0)
        XCTAssertGreaterThan(point.z, 0)
    }

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

    func testSpatialToneTargetsRendererChannel() {
        XCTAssertEqual(TestTonePipelinePoint.rendererRearRight.spatialChannel?.role, .rearRight)
        XCTAssertTrue(TestTonePipelinePoint.rendererRearRight.pipelineDescription.contains("AVAudioEnvironmentNode"))
    }
}
