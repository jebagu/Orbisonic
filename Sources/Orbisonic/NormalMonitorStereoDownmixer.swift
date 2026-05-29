import Foundation

enum NormalMonitorLFEMonitorPolicy: Equatable, Sendable {
    case muted
    case auditionMinus10
    case auditionMinus6
}

struct NormalMonitorDownmixCoefficient: Equatable, Sendable {
    let inputIndex: Int
    let role: SurroundChannelRole
    let left: Float
    let right: Float
}

struct NormalMonitorDownmixMatrix: Equatable, Sendable {
    static let equalPowerCenter: Float = 0.70710678
    static let heightSide: Float = 0.5
    static let topCenter: Float = 0.5 * equalPowerCenter
    static let lfeAuditionMinus10: Float = 0.31622777
    static let lfeAuditionMinus6: Float = 0.5
    static let multichannelHeadroom: Float = 0.50118723

    let sourceChannelCount: Int
    let outputChannelCount: Int
    let lfePolicy: NormalMonitorLFEMonitorPolicy
    let appliesHeadroom: Bool
    let coefficients: [NormalMonitorDownmixCoefficient]

    init(
        layout: SurroundLayout,
        lfePolicy: NormalMonitorLFEMonitorPolicy = .muted,
        appliesHeadroom: Bool = true
    ) {
        let headroom = Self.headroomGain(channelCount: layout.channelCount, appliesHeadroom: appliesHeadroom)
        self.sourceChannelCount = layout.channelCount
        self.outputChannelCount = 2
        self.lfePolicy = lfePolicy
        self.appliesHeadroom = appliesHeadroom
        self.coefficients = layout.channels.map { channel in
            let base = Self.baseCoefficients(for: channel.role, lfePolicy: lfePolicy)
            return NormalMonitorDownmixCoefficient(
                inputIndex: channel.index,
                role: channel.role,
                left: base.left * headroom,
                right: base.right * headroom
            )
        }
    }

    func coefficient(for role: SurroundChannelRole) -> NormalMonitorDownmixCoefficient? {
        coefficients.first { $0.role == role }
    }

    static func coefficients(
        for role: SurroundChannelRole,
        sourceChannelCount: Int,
        lfePolicy: NormalMonitorLFEMonitorPolicy = .muted,
        appliesHeadroom: Bool = true
    ) -> (left: Float, right: Float) {
        let base = baseCoefficients(for: role, lfePolicy: lfePolicy)
        let headroom = headroomGain(channelCount: sourceChannelCount, appliesHeadroom: appliesHeadroom)
        return (base.left * headroom, base.right * headroom)
    }

    private static func headroomGain(channelCount: Int, appliesHeadroom: Bool) -> Float {
        appliesHeadroom && channelCount > 2 ? multichannelHeadroom : 1
    }

    private static func baseCoefficients(
        for role: SurroundChannelRole,
        lfePolicy: NormalMonitorLFEMonitorPolicy
    ) -> (left: Float, right: Float) {
        switch role {
        case .frontLeft:
            return (1, 0)
        case .frontRight:
            return (0, 1)
        case .center, .rearCenter:
            return (equalPowerCenter, equalPowerCenter)
        case .lfe, .lfe2:
            return lfeCoefficients(for: lfePolicy)
        case .sideLeft, .rearLeft, .wideLeft, .frontLeftCenter:
            return (equalPowerCenter, 0)
        case .sideRight, .rearRight, .wideRight, .frontRightCenter:
            return (0, equalPowerCenter)
        case .topFrontLeft, .topMiddleLeft, .topRearLeft:
            return (heightSide, 0)
        case .topFrontRight, .topMiddleRight, .topRearRight:
            return (0, heightSide)
        case .topFrontCenter, .topMiddleCenter, .topRearCenter:
            return (topCenter, topCenter)
        case .discrete(let index):
            return index.isMultiple(of: 2) ? (1, 0) : (0, 1)
        }
    }

    private static func lfeCoefficients(
        for policy: NormalMonitorLFEMonitorPolicy
    ) -> (left: Float, right: Float) {
        switch policy {
        case .muted:
            return (0, 0)
        case .auditionMinus10:
            return (lfeAuditionMinus10, lfeAuditionMinus10)
        case .auditionMinus6:
            return (lfeAuditionMinus6, lfeAuditionMinus6)
        }
    }
}

enum NormalMonitorStereoDownmixerError: Error, Equatable {
    case inputChannelCountMismatch(expected: Int, actual: Int)
    case outputChannelCountMismatch(expected: Int, actual: Int)
    case inputFrameCountMismatch(channelIndex: Int, expected: Int, actual: Int)
    case outputFrameCountMismatch(channelIndex: Int, expected: Int, actual: Int)
}

struct NormalMonitorStereoDownmixer: Equatable, Sendable {
    let matrix: NormalMonitorDownmixMatrix

    init(
        layout: SurroundLayout,
        lfePolicy: NormalMonitorLFEMonitorPolicy = .muted,
        appliesHeadroom: Bool = true
    ) {
        self.matrix = NormalMonitorDownmixMatrix(
            layout: layout,
            lfePolicy: lfePolicy,
            appliesHeadroom: appliesHeadroom
        )
    }

    func render(inputs: [[Float]]) throws -> [[Float]] {
        let frameCount = inputs.first?.count ?? 0
        var output = Array(repeating: Array(repeating: Float(0), count: frameCount), count: 2)
        try render(inputs: inputs, output: &output)
        return output
    }

    func render(inputs: [[Float]], output: inout [[Float]]) throws {
        guard inputs.count == matrix.sourceChannelCount else {
            throw NormalMonitorStereoDownmixerError.inputChannelCountMismatch(
                expected: matrix.sourceChannelCount,
                actual: inputs.count
            )
        }
        guard output.count == matrix.outputChannelCount else {
            throw NormalMonitorStereoDownmixerError.outputChannelCountMismatch(
                expected: matrix.outputChannelCount,
                actual: output.count
            )
        }

        let frameCount = inputs.first?.count ?? 0
        for (index, input) in inputs.enumerated() where input.count != frameCount {
            throw NormalMonitorStereoDownmixerError.inputFrameCountMismatch(
                channelIndex: index,
                expected: frameCount,
                actual: input.count
            )
        }
        for (index, channelOutput) in output.enumerated() where channelOutput.count != frameCount {
            throw NormalMonitorStereoDownmixerError.outputFrameCountMismatch(
                channelIndex: index,
                expected: frameCount,
                actual: channelOutput.count
            )
        }

        for channelIndex in output.indices {
            output[channelIndex].replaceSubrange(output[channelIndex].indices, with: repeatElement(Float(0), count: frameCount))
        }

        for coefficient in matrix.coefficients {
            let input = inputs[coefficient.inputIndex]
            for frameIndex in 0..<frameCount {
                output[0][frameIndex] += input[frameIndex] * coefficient.left
                output[1][frameIndex] += input[frameIndex] * coefficient.right
            }
        }
    }

}
