import XCTest
@testable import Orbisonic

final class NormalMonitorStereoDownmixerTests: XCTestCase {
    private let tolerance: Float = 1e-6

    func testMonoDownmixUsesEqualPowerPhantomCenter() throws {
        let downmixer = NormalMonitorStereoDownmixer(layout: layout([.center]))
        let output = try downmixer.render(inputs: [[2, -4]])

        assertStereoFrames(
            output,
            left: [
                2 * NormalMonitorDownmixMatrix.equalPowerCenter,
                -4 * NormalMonitorDownmixMatrix.equalPowerCenter
            ],
            right: [
                2 * NormalMonitorDownmixMatrix.equalPowerCenter,
                -4 * NormalMonitorDownmixMatrix.equalPowerCenter
            ]
        )
    }

    func testStereoDownmixIsIdentity() throws {
        let downmixer = NormalMonitorStereoDownmixer(layout: layout([.frontLeft, .frontRight]))
        let output = try downmixer.render(inputs: [
            [1, -2],
            [3, -4]
        ])

        assertStereoFrames(output, left: [1, -2], right: [3, -4])
    }

    func testStereoDownmixDoesNotCreateCenterSurroundOrHeight() throws {
        let stereoLayout = layout([.frontLeft, .frontRight])
        let matrix = NormalMonitorDownmixMatrix(layout: stereoLayout)

        XCTAssertEqual(matrix.coefficients.count, 2)
        XCTAssertNil(matrix.coefficient(for: .center))
        XCTAssertNil(matrix.coefficient(for: .sideLeft))
        XCTAssertNil(matrix.coefficient(for: .sideRight))
        XCTAssertNil(matrix.coefficient(for: .topMiddleCenter))

        let downmixer = NormalMonitorStereoDownmixer(layout: stereoLayout)
        let output = try downmixer.render(inputs: [
            [7],
            [11]
        ])
        assertStereoFrame(output, left: 7, right: 11)
    }

    func testThreeChannelDownmixFoldsCenterAtMinus3dB() throws {
        let downmixer = NormalMonitorStereoDownmixer(
            layout: layout([.frontLeft, .frontRight, .center]),
            appliesHeadroom: false
        )
        let output = try downmixer.render(inputs: [
            [10],
            [20],
            [30]
        ])

        assertStereoFrame(
            output,
            left: 10 + 30 * NormalMonitorDownmixMatrix.equalPowerCenter,
            right: 20 + 30 * NormalMonitorDownmixMatrix.equalPowerCenter
        )
    }

    func testFiveOneDownmixFoldsCenterAndSurroundsButMutesLFEByDefault() throws {
        let downmixer = NormalMonitorStereoDownmixer(layout: fiveOneLayout, appliesHeadroom: false)
        let output = try downmixer.render(inputs: [
            [1],
            [2],
            [3],
            [100],
            [5],
            [7]
        ])

        assertStereoFrame(
            output,
            left: 1 + (3 + 5) * NormalMonitorDownmixMatrix.equalPowerCenter,
            right: 2 + (3 + 7) * NormalMonitorDownmixMatrix.equalPowerCenter
        )
    }

    func testFiveOneLFEAuditionMinus10IsExplicit() throws {
        let downmixer = NormalMonitorStereoDownmixer(
            layout: fiveOneLayout,
            lfePolicy: .auditionMinus10,
            appliesHeadroom: false
        )
        let output = try downmixer.render(inputs: [
            [0],
            [0],
            [0],
            [10],
            [0],
            [0]
        ])

        assertStereoFrame(
            output,
            left: 10 * NormalMonitorDownmixMatrix.lfeAuditionMinus10,
            right: 10 * NormalMonitorDownmixMatrix.lfeAuditionMinus10
        )
    }

    func testFiveOneLFEAuditionMinus6IsExplicit() throws {
        let downmixer = NormalMonitorStereoDownmixer(
            layout: fiveOneLayout,
            lfePolicy: .auditionMinus6,
            appliesHeadroom: false
        )
        let output = try downmixer.render(inputs: [
            [0],
            [0],
            [0],
            [10],
            [0],
            [0]
        ])

        assertStereoFrame(
            output,
            left: 10 * NormalMonitorDownmixMatrix.lfeAuditionMinus6,
            right: 10 * NormalMonitorDownmixMatrix.lfeAuditionMinus6
        )
    }

    func testSevenOneDownmixFoldsRearSurroundsSameSide() throws {
        let downmixer = NormalMonitorStereoDownmixer(
            layout: layout([.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight, .rearLeft, .rearRight]),
            appliesHeadroom: false
        )
        let output = try downmixer.render(inputs: [
            [1],
            [2],
            [3],
            [100],
            [5],
            [7],
            [11],
            [13]
        ])

        assertStereoFrame(
            output,
            left: 1
                + 3 * NormalMonitorDownmixMatrix.equalPowerCenter
                + 5 * NormalMonitorDownmixMatrix.equalPowerCenter
                + 11 * NormalMonitorDownmixMatrix.equalPowerCenter,
            right: 2
                + 3 * NormalMonitorDownmixMatrix.equalPowerCenter
                + 7 * NormalMonitorDownmixMatrix.equalPowerCenter
                + 13 * NormalMonitorDownmixMatrix.equalPowerCenter
        )
    }

    func testHeightChannelsFoldToStereoWithoutSpatialization() throws {
        XCTAssertFalse(AudioSpatialUsageAudit.normalMonitorAudiblePlayback.convertsSourceToPointSource)

        let downmixer = NormalMonitorStereoDownmixer(
            layout: layout([.topFrontLeft, .topMiddleLeft, .topRearLeft, .topFrontRight, .topMiddleRight, .topRearRight]),
            appliesHeadroom: false
        )
        let output = try downmixer.render(inputs: [
            [2],
            [4],
            [6],
            [8],
            [10],
            [12]
        ])

        assertStereoFrame(
            output,
            left: (2 + 4 + 6) * NormalMonitorDownmixMatrix.heightSide,
            right: (8 + 10 + 12) * NormalMonitorDownmixMatrix.heightSide
        )
    }

    func testTopCenterFoldsEquallyToLeftAndRight() throws {
        let downmixer = NormalMonitorStereoDownmixer(
            layout: layout([.topMiddleCenter]),
            appliesHeadroom: false
        )
        let output = try downmixer.render(inputs: [
            [8]
        ])

        assertStereoFrame(
            output,
            left: 8 * NormalMonitorDownmixMatrix.topCenter,
            right: 8 * NormalMonitorDownmixMatrix.topCenter
        )
    }

    func testMultichannelDownmixAppliesHeadroom() throws {
        let downmixer = NormalMonitorStereoDownmixer(layout: layout([.frontLeft, .frontRight, .center]))
        let output = try downmixer.render(inputs: [
            [10],
            [20],
            [30]
        ])

        assertStereoFrame(
            output,
            left: 10 * NormalMonitorDownmixMatrix.multichannelHeadroom
                + 30 * (NormalMonitorDownmixMatrix.equalPowerCenter * NormalMonitorDownmixMatrix.multichannelHeadroom),
            right: 20 * NormalMonitorDownmixMatrix.multichannelHeadroom
                + 30 * (NormalMonitorDownmixMatrix.equalPowerCenter * NormalMonitorDownmixMatrix.multichannelHeadroom)
        )
    }

    func testDownmixerClearsOutputBuffersBeforeRendering() throws {
        let downmixer = NormalMonitorStereoDownmixer(layout: layout([.frontLeft]))
        var output: [[Float]] = [
            [99, 99],
            [88, 88]
        ]

        try downmixer.render(inputs: [[1, 2]], output: &output)

        assertStereoFrames(output, left: [1, 2], right: [0, 0])
    }

    func testDownmixerDoesNotMutateInputBuffers() throws {
        let downmixer = NormalMonitorStereoDownmixer(layout: fiveOneLayout)
        let inputs: [[Float]] = [
            [1, 2],
            [3, 4],
            [5, 6],
            [7, 8],
            [9, 10],
            [11, 12]
        ]
        let original = inputs
        var output = Array(repeating: Array(repeating: Float(-1), count: 2), count: 2)

        try downmixer.render(inputs: inputs, output: &output)

        XCTAssertEqual(inputs, original)
    }

    private var fiveOneLayout: SurroundLayout {
        layout([.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight])
    }

    private func layout(_ roles: [SurroundChannelRole]) -> SurroundLayout {
        SurroundLayout(
            name: "Synthetic",
            channels: roles.enumerated().map { index, role in
                SurroundChannel(index: index, role: role)
            }
        )
    }

    private func assertStereoFrame(
        _ output: [[Float]],
        left: Float,
        right: Float,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertStereoFrames(output, left: [left], right: [right], file: file, line: line)
    }

    private func assertStereoFrames(
        _ output: [[Float]],
        left: [Float],
        right: [Float],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(output.count, 2, file: file, line: line)
        XCTAssertEqual(output[0].count, left.count, file: file, line: line)
        XCTAssertEqual(output[1].count, right.count, file: file, line: line)

        for index in left.indices {
            XCTAssertEqual(output[0][index], left[index], accuracy: tolerance, file: file, line: line)
            XCTAssertEqual(output[1][index], right[index], accuracy: tolerance, file: file, line: line)
        }
    }
}
