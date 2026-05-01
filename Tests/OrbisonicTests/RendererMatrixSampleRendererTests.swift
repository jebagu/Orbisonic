import XCTest
@testable import Orbisonic

final class RendererMatrixSampleRendererTests: XCTestCase {
    private let tolerance: Float = 1e-6

    func testMatrixRendererStereoIdentity() {
        let input = [
            [Float(1), 2, -3, 4],
            [Float(-5), 6, 7, -8]
        ]
        let output = render(matrix: RendererMatrix(gains: [
            [1, 0],
            [0, 1]
        ]), input: input)

        assertSamples(output, equals: input)
    }

    func testMatrixRendererMonoToStereoEqualPower() {
        let input = [[Float(1), -2, 3, -4, 0.5]]
        let gain = Double(NormalMonitorDownmixMatrix.equalPowerCenter)
        let output = render(matrix: RendererMatrix(gains: [
            [gain, gain]
        ]), input: input)
        let expected = input[0].map { $0 * NormalMonitorDownmixMatrix.equalPowerCenter }

        assertSamples(output, equals: [expected, expected])
    }

    func testMatrixRendererFiveOneToStereoGolden() {
        let input: [[Float]] = [
            [10, 11, 12],
            [20, 21, 22],
            [30, 31, 32],
            [40, 41, 42],
            [50, 51, 52],
            [60, 61, 62]
        ]
        let output = render(matrix: normalMonitorMatrix(roles: [
            .frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight
        ]), input: input)

        assertSamples(output, equals: expectedOutput(matrix: normalMonitorMatrix(roles: [
            .frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight
        ]), input: input))
    }

    func testMatrixRendererSevenOneToStereoGolden() {
        let input: [[Float]] = [
            [10, 11, 12, 13],
            [20, 21, 22, 23],
            [30, 31, 32, 33],
            [40, 41, 42, 43],
            [50, 51, 52, 53],
            [60, 61, 62, 63],
            [70, 71, 72, 73],
            [80, 81, 82, 83]
        ]
        let matrix = normalMonitorMatrix(roles: [
            .frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight, .rearLeft, .rearRight
        ])
        let output = render(matrix: matrix, input: input)

        assertSamples(output, equals: expectedOutput(matrix: matrix, input: input))
    }

    func testMatrixRendererHeightToStereoGolden() {
        let input: [[Float]] = [
            [1, 2, 3],
            [4, 5, 6],
            [7, 8, 9],
            [10, 11, 12],
            [13, 14, 15]
        ]
        let matrix = normalMonitorMatrix(roles: [
            .topFrontLeft, .topMiddleLeft, .topMiddleCenter, .topMiddleRight, .topRearRight
        ])
        let output = render(matrix: matrix, input: input)

        assertSamples(output, equals: expectedOutput(matrix: matrix, input: input))
    }

    func testMatrixRendererClearsOutputBeforeRendering() {
        let matrix = RendererMatrix(gains: [
            [1, 0],
            [0, 1]
        ])
        let input = [
            [Float(1), 2, 3],
            [Float(4), 5, 6]
        ]
        var output = [
            [Float(99), 99, 99, 99],
            [Float(88), 88, 88, 88]
        ]

        let frames = RendererMatrixSampleRenderer.render(
            matrix: matrix,
            inputSamples: input,
            frameCount: 3,
            outputBuffers: &output
        )

        XCTAssertEqual(frames, 3)
        assertSamples(output, equals: input)
    }

    func testMatrixRendererDoesNotAccumulateResidueAcrossCalls() {
        let matrix = RendererMatrix(gains: [
            [1, 0],
            [0, 1]
        ])
        let firstInput = [
            [Float(1), 1, 1],
            [Float(2), 2, 2]
        ]
        let secondInput = [
            [Float(3), 4, 5],
            [Float(6), 7, 8]
        ]
        var output = [[Float]]()

        RendererMatrixSampleRenderer.render(
            matrix: matrix,
            inputSamples: firstInput,
            frameCount: 3,
            outputBuffers: &output
        )
        RendererMatrixSampleRenderer.render(
            matrix: matrix,
            inputSamples: secondInput,
            frameCount: 3,
            outputBuffers: &output
        )

        assertSamples(output, equals: secondInput)
    }

    func testMatrixRendererDoesNotMutateInputs() {
        let matrix = RendererMatrix(gains: [
            [0.25, 0.75],
            [1.25, -0.5]
        ])
        let input = [
            [Float(1), 2, 3, 4],
            [Float(5), 6, 7, 8]
        ]
        let original = input

        _ = render(matrix: matrix, input: input)

        XCTAssertEqual(input, original)
    }

    func testMatrixRendererHandlesZeroGainMatrix() {
        let input = [
            [Float(1), -2, 3],
            [Float(4), 5, -6]
        ]
        let output = render(matrix: RendererMatrix(gains: [
            [0, 0],
            [0, 0]
        ]), input: input)

        assertSamples(output, equals: [
            [0, 0, 0],
            [0, 0, 0]
        ])
    }

    func testMatrixRendererRejectsOrSafelyHandlesChannelMismatch() {
        let matrix = RendererMatrix(gains: [
            [1, 0],
            [0, 1]
        ])
        var output = [
            [Float(9), 9, 9],
            [Float(8), 8, 8]
        ]

        let frames = RendererMatrixSampleRenderer.render(
            matrix: matrix,
            inputSamples: [[1, 2, 3]],
            frameCount: 3,
            outputBuffers: &output
        )

        XCTAssertEqual(frames, 0)
        XCTAssertTrue(output.isEmpty)
    }

    func testMatrixRendererGoldenKnownValues() {
        let matrix = RendererMatrix(gains: [
            [0.5, -1.0],
            [2.0, 0.25],
            [-0.75, 1.5]
        ])
        let input = [
            [Float(1), 2, 3, 4],
            [Float(5), 6, 7, 8],
            [Float(9), 10, 11, 12]
        ]
        let output = render(matrix: matrix, input: input)

        assertSamples(output, equals: [
            [
                1 * 0.5 + 5 * 2.0 + 9 * -0.75,
                2 * 0.5 + 6 * 2.0 + 10 * -0.75,
                3 * 0.5 + 7 * 2.0 + 11 * -0.75,
                4 * 0.5 + 8 * 2.0 + 12 * -0.75
            ],
            [
                1 * -1.0 + 5 * 0.25 + 9 * 1.5,
                2 * -1.0 + 6 * 0.25 + 10 * 1.5,
                3 * -1.0 + 7 * 0.25 + 11 * 1.5,
                4 * -1.0 + 8 * 0.25 + 12 * 1.5
            ]
        ])
    }

    private func render(matrix: RendererMatrix, input: [[Float]]) -> [[Float]] {
        var output = [[Float]]()
        let frames = RendererMatrixSampleRenderer.render(
            matrix: matrix,
            inputSamples: input,
            frameCount: input.first?.count ?? 0,
            outputBuffers: &output
        )
        XCTAssertEqual(frames, input.first?.count ?? 0)
        return output
    }

    private func normalMonitorMatrix(roles: [SurroundChannelRole]) -> RendererMatrix {
        RendererMatrix(gains: roles.map { role in
            let coefficients = NormalMonitorDownmixMatrix.coefficients(
                for: role,
                sourceChannelCount: roles.count,
                appliesHeadroom: false
            )
            return [Double(coefficients.left), Double(coefficients.right)]
        })
    }

    private func expectedOutput(matrix: RendererMatrix, input: [[Float]]) -> [[Float]] {
        guard matrix.inputCount == input.count,
              let frameCount = input.first?.count
        else {
            return []
        }

        var output = Array(
            repeating: Array(repeating: Float(0), count: frameCount),
            count: matrix.outputCount
        )
        for inputIndex in 0..<matrix.inputCount {
            for outputIndex in 0..<matrix.outputCount {
                let gain = Float(matrix.gains[inputIndex][outputIndex])
                for frame in 0..<frameCount {
                    output[outputIndex][frame] += input[inputIndex][frame] * gain
                }
            }
        }
        return output
    }

    private func assertSamples(
        _ actual: [[Float]],
        equals expected: [[Float]],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for channelIndex in expected.indices {
            XCTAssertEqual(actual[channelIndex].count, expected[channelIndex].count, file: file, line: line)
            for frameIndex in expected[channelIndex].indices {
                XCTAssertEqual(
                    actual[channelIndex][frameIndex],
                    expected[channelIndex][frameIndex],
                    accuracy: tolerance,
                    "channel \(channelIndex) frame \(frameIndex)",
                    file: file,
                    line: line
                )
            }
        }
    }
}
