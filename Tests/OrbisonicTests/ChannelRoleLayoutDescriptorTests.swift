import XCTest
@testable import Orbisonic

final class ChannelRoleLayoutDescriptorTests: XCTestCase {
    private let tolerance: Float = 1e-6

    func testUntaggedFiveOneUsesLegacyOrder() {
        let descriptor = SurroundLayoutDetector.fallbackDescriptor(for: 6)

        XCTAssertEqual(descriptor.layoutName, "5.1 Surround")
        XCTAssertEqual(descriptor.source, .fallbackChannelCount)
        XCTAssertEqual(descriptor.confidence, .low)
        XCTAssertEqual(descriptor.roles, [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight])
        XCTAssertEqual(descriptor.roleSummary, "FL, FR, C, LFE1, SL, SR")
    }

    func testUnknownFiveOneDoesNotApplyMPEGRemapSilently() {
        let descriptor = ChannelRoleLayoutDescriptor.unknown(
            channelCount: 6,
            sourceDescription: "untagged source buffer"
        )

        XCTAssertEqual(descriptor.roles, [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight])
        XCTAssertFalse(descriptor.appliesMPEGFiveOneCRemap)
        XCTAssertEqual(descriptor.source, .unknown)
        XCTAssertEqual(descriptor.confidence, .low)
        XCTAssertTrue(descriptor.warningDescriptions.contains { $0.contains("legacy order L R C LFE Ls Rs") })
    }

    func testMPEGFiveOneCMappingRequiresHighConfidence() {
        let lowConfidence = ChannelRoleLayoutDescriptor.mpegFiveOneC(
            confidence: .low,
            sourceDescription: "ambiguous tag-only metadata"
        )
        XCTAssertEqual(lowConfidence.roles, [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight])
        XCTAssertFalse(lowConfidence.appliesMPEGFiveOneCRemap)
        XCTAssertFalse(lowConfidence.warningDescriptions.isEmpty)

        let highConfidence = ChannelRoleLayoutDescriptor.mpegFiveOneC(
            confidence: .high,
            sourceDescription: "explicit Core Audio MPEG 5.1 C layout tag"
        )
        XCTAssertEqual(highConfidence.roles, [.frontLeft, .center, .frontRight, .sideLeft, .sideRight, .lfe])
        XCTAssertTrue(highConfidence.appliesMPEGFiveOneCRemap)
        XCTAssertEqual(highConfidence.source, .explicitCoreAudioLayoutTag("MPEG 5.1 C"))
        XCTAssertEqual(highConfidence.confidence, .high)
        XCTAssertTrue(highConfidence.warningDescriptions.isEmpty)
    }

    func testFiveOneDownmixUsesResolvedRolesNotRawIndexGuessing() throws {
        let descriptor = ChannelRoleLayoutDescriptor.mpegFiveOneC(
            confidence: .high,
            sourceDescription: "explicit Core Audio MPEG 5.1 C layout tag"
        )
        let downmixer = NormalMonitorStereoDownmixer(
            layout: descriptor.layout,
            appliesHeadroom: false
        )

        let output = try downmixer.render(inputs: [
            [10], // FL
            [20], // C
            [30], // FR
            [40], // SL
            [50], // SR
            [60]  // LFE
        ])

        assertStereoFrame(
            output,
            left: 10 + (20 + 40) * NormalMonitorDownmixMatrix.equalPowerCenter,
            right: 30 + (20 + 50) * NormalMonitorDownmixMatrix.equalPowerCenter
        )
    }

    func testFiveOneLFEDoesNotFoldIntoNormalMonitorByDefault() throws {
        let descriptor = SurroundLayoutDetector.fallbackDescriptor(for: 6)
        let downmixer = NormalMonitorStereoDownmixer(
            layout: descriptor.layout,
            appliesHeadroom: false
        )

        let output = try downmixer.render(inputs: [
            [0],
            [0],
            [0],
            [40],
            [0],
            [0]
        ])

        assertStereoFrame(output, left: 0, right: 0)
    }

    func testSevenOneFallbackOrderIsStable() {
        let descriptor = SurroundLayoutDetector.fallbackDescriptor(for: 8)

        XCTAssertEqual(descriptor.layoutName, "7.1 Surround")
        XCTAssertEqual(
            descriptor.roles,
            [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight, .rearLeft, .rearRight]
        )
        XCTAssertEqual(descriptor.roleSummary, "FL, FR, C, LFE1, SL, SR, RL, RR")
    }

    func testUnknownSevenOneDoesNotApplyUnverifiedRemap() {
        let descriptor = ChannelRoleLayoutDescriptor.unknown(
            channelCount: 8,
            sourceDescription: "unverified 7.1 layout"
        )

        XCTAssertEqual(
            descriptor.roles,
            [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight, .rearLeft, .rearRight]
        )
        XCTAssertEqual(descriptor.source, .unknown)
        XCTAssertEqual(descriptor.confidence, .low)
        XCTAssertTrue(descriptor.warningDescriptions.contains { $0.contains("legacy order L R C LFE Ls Rs Lrs Rrs") })
    }

    func testChannelIdentificationImpulsesRevealExpectedRoles() throws {
        let descriptor = SurroundLayoutDetector.fallbackDescriptor(for: 6)
        let downmixer = NormalMonitorStereoDownmixer(
            layout: descriptor.layout,
            appliesHeadroom: false
        )
        let expectedByIndex: [(left: Float, right: Float)] = [
            (1, 0),
            (0, 1),
            (NormalMonitorDownmixMatrix.equalPowerCenter, NormalMonitorDownmixMatrix.equalPowerCenter),
            (0, 0),
            (NormalMonitorDownmixMatrix.equalPowerCenter, 0),
            (0, NormalMonitorDownmixMatrix.equalPowerCenter)
        ]

        for channelIndex in 0..<6 {
            var inputs = Array(repeating: [Float(0)], count: 6)
            inputs[channelIndex][0] = 1

            let output = try downmixer.render(inputs: inputs)

            assertStereoFrame(
                output,
                left: expectedByIndex[channelIndex].left,
                right: expectedByIndex[channelIndex].right
            )
        }
    }

    func testLayoutDescriptorIncludesConfidenceAndSource() {
        let descriptor = ChannelRoleLayoutDescriptor.mpegFiveOneC(
            confidence: .high,
            sourceDescription: "explicit Core Audio MPEG 5.1 C layout tag"
        )

        XCTAssertEqual(descriptor.source, .explicitCoreAudioLayoutTag("MPEG 5.1 C"))
        XCTAssertEqual(descriptor.confidence, .high)
        XCTAssertEqual(descriptor.sourceDescription, "explicit Core Audio MPEG 5.1 C layout tag")
        XCTAssertEqual(descriptor.channelCount, 6)
        XCTAssertEqual(descriptor.layout.channelSummary, "FL, C, FR, SL, SR, LFE1")
    }

    func testLowConfidenceLayoutProducesWarningButStillUsesNormalMonitor() {
        let descriptor = ChannelRoleLayoutDescriptor.unknown(
            channelCount: 6,
            sourceDescription: "untagged source buffer"
        )
        let route = NormalMonitorRoutePlanner.audibleRoute(
            sourceFamily: .localFile,
            sourceLayoutDescription: descriptor.layout.channelSummary,
            warningDescriptions: descriptor.warningDescriptions
        )

        XCTAssertFalse(route.warningDescriptions.isEmpty)
        XCTAssertTrue(route.usesNormalMonitor)
        XCTAssertTrue(route.usesStereoDownmix)
        XCTAssertEqual(route.outputChannelCount, 2)
        XCTAssertFalse(route.usesAVAudioEnvironmentNode)
        XCTAssertFalse(route.usesHRTF)
        XCTAssertFalse(route.usesHRTFHQ)
        XCTAssertFalse(route.usesAudibleDirectSonicSphereMatrix)
    }

    private func assertStereoFrame(
        _ output: [[Float]],
        left: Float,
        right: Float,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(output.count, 2, file: file, line: line)
        XCTAssertEqual(output[0].count, 1, file: file, line: line)
        XCTAssertEqual(output[1].count, 1, file: file, line: line)
        XCTAssertEqual(output[0][0], left, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(output[1][0], right, accuracy: tolerance, file: file, line: line)
    }
}
