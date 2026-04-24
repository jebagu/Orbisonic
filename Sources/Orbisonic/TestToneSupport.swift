import AVFoundation
import Foundation

enum TestTonePipelinePoint: String, CaseIterable, Identifiable {
    case directOutput = "Output Route: Both Ears"
    case rendererCenter = "Renderer: Center"
    case rendererFrontLeft = "Renderer: Front Left"
    case rendererFrontRight = "Renderer: Front Right"
    case rendererSideLeft = "Renderer: Side Left"
    case rendererSideRight = "Renderer: Side Right"
    case rendererRearLeft = "Renderer: Rear Left"
    case rendererRearRight = "Renderer: Rear Right"
    case rendererLFE = "Renderer: LFE"

    var id: String { rawValue }

    static let channelWalkPoints: [TestTonePipelinePoint] = [
        .directOutput,
        .rendererFrontLeft,
        .rendererFrontRight,
        .rendererCenter,
        .rendererSideLeft,
        .rendererSideRight,
        .rendererRearLeft,
        .rendererRearRight,
        .rendererLFE
    ]

    var detail: String {
        switch self {
        case .directOutput:
            "Sends a stereo tone straight to the macOS output route, bypassing spatial rendering."
        case .rendererCenter:
            "Sends a mono tone through the spatial renderer at the center position."
        case .rendererFrontLeft:
            "Sends a mono tone through the spatial renderer at front left."
        case .rendererFrontRight:
            "Sends a mono tone through the spatial renderer at front right."
        case .rendererSideLeft:
            "Sends a mono tone through the spatial renderer at side left."
        case .rendererSideRight:
            "Sends a mono tone through the spatial renderer at side right."
        case .rendererRearLeft:
            "Sends a mono tone through the spatial renderer behind you on the left."
        case .rendererRearRight:
            "Sends a mono tone through the spatial renderer behind you on the right."
        case .rendererLFE:
            "Sends a low tone through the renderer's LFE path."
        }
    }

    var frequency: Double {
        switch self {
        case .rendererLFE:
            90
        case .rendererCenter:
            660
        case .rendererFrontLeft, .rendererFrontRight:
            520
        case .rendererSideLeft, .rendererSideRight:
            740
        case .rendererRearLeft, .rendererRearRight:
            880
        case .directOutput:
            440
        }
    }

    var gain: Float {
        switch self {
        case .rendererLFE:
            0.22
        default:
            0.16
        }
    }

    var spatialChannel: SurroundChannel? {
        switch self {
        case .directOutput:
            nil
        case .rendererCenter:
            SurroundChannel(index: 0, role: .center)
        case .rendererFrontLeft:
            SurroundChannel(index: 0, role: .frontLeft)
        case .rendererFrontRight:
            SurroundChannel(index: 0, role: .frontRight)
        case .rendererSideLeft:
            SurroundChannel(index: 0, role: .sideLeft)
        case .rendererSideRight:
            SurroundChannel(index: 0, role: .sideRight)
        case .rendererRearLeft:
            SurroundChannel(index: 0, role: .rearLeft)
        case .rendererRearRight:
            SurroundChannel(index: 0, role: .rearRight)
        case .rendererLFE:
            SurroundChannel(index: 0, role: .lfe)
        }
    }

    var meterChannels: [SurroundChannel] {
        if let spatialChannel {
            return [spatialChannel]
        }

        return [
            SurroundChannel(index: 0, role: .frontLeft),
            SurroundChannel(index: 1, role: .frontRight)
        ]
    }

    var pipelineDescription: String {
        switch self {
        case .directOutput:
            "Synth tone -> main mixer -> macOS output"
        default:
            "Synth tone -> AVAudioEnvironmentNode -> main mixer -> macOS output"
        }
    }
}

final class SineToneState {
    private var phase = 0.0
    private let phaseIncrement: Double
    private let gain: Float

    init(frequency: Double, sampleRate: Double, gain: Float) {
        phaseIncrement = (2.0 * .pi * frequency) / sampleRate
        self.gain = gain
    }

    func nextSample() -> Float {
        let sample = sin(phase) * Double(gain)
        phase += phaseIncrement

        if phase >= 2.0 * .pi {
            phase -= 2.0 * .pi
        }

        return Float(sample)
    }
}
