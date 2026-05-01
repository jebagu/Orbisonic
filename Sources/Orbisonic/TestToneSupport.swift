import AVFoundation
import AppKit
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
            "Sends a stereo tone to the Normal Monitor path."
        case .rendererCenter:
            "Sends a diagnostic tone through the Normal Monitor path."
        case .rendererFrontLeft:
            "Sends a diagnostic tone through the Normal Monitor path."
        case .rendererFrontRight:
            "Sends a diagnostic tone through the Normal Monitor path."
        case .rendererSideLeft:
            "Sends a diagnostic tone through the Normal Monitor path."
        case .rendererSideRight:
            "Sends a diagnostic tone through the Normal Monitor path."
        case .rendererRearLeft:
            "Sends a diagnostic tone through the Normal Monitor path."
        case .rendererRearRight:
            "Sends a diagnostic tone through the Normal Monitor path."
        case .rendererLFE:
            "Sends a low diagnostic tone through the Normal Monitor path."
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
        nil
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
        "Synth tone -> Normal Monitor stereo downmix -> macOS output"
    }
}

final class SineToneState {
    private var phase = 0.0
    private let phaseIncrement: Double
    private let gain: Float
    private let attackFrameCount: Int
    private var frameIndex = 0

    init(frequency: Double, sampleRate: Double, gain: Float) {
        phaseIncrement = (2.0 * .pi * frequency) / sampleRate
        self.gain = gain
        attackFrameCount = max(Int(sampleRate * 0.018), 1)
    }

    func nextSample() -> Float {
        let attack = min(Float(frameIndex) / Float(attackFrameCount), 1)
        let sample = sin(phase) * Double(gain * attack)
        phase += phaseIncrement
        frameIndex += 1

        if phase >= 2.0 * .pi {
            phase -= 2.0 * .pi
        }

        return Float(sample)
    }
}

struct DiagnosticSpeechClip {
    let samples: [Float]
    let sampleRate: Double
}

final class DiagnosticSpeechPlayhead {
    private let samples: [Float]
    private let step: Double
    private let gain: Float
    private let outputFrameLimit: Int
    private var position = 0.0
    private var outputFrameIndex = 0

    init(
        samples: [Float],
        sourceSampleRate: Double,
        targetSampleRate: Double,
        gain: Float = 1
    ) {
        self.samples = samples
        self.gain = gain

        if sourceSampleRate > 0, targetSampleRate > 0 {
            step = sourceSampleRate / targetSampleRate
            outputFrameLimit = Int((Double(samples.count) * targetSampleRate / sourceSampleRate).rounded(.up))
        } else {
            step = 1
            outputFrameLimit = samples.count
        }
    }

    convenience init(clip: DiagnosticSpeechClip, targetSampleRate: Double, gain: Float = 1) {
        self.init(
            samples: clip.samples,
            sourceSampleRate: clip.sampleRate,
            targetSampleRate: targetSampleRate,
            gain: gain
        )
    }

    func nextSample() -> Float {
        guard !samples.isEmpty, outputFrameIndex < outputFrameLimit else {
            return 0
        }

        let lowerIndex = min(Int(position), samples.count - 1)
        let upperIndex = lowerIndex + 1
        let lowerSample = samples[lowerIndex]
        let interpolated: Float

        if upperIndex < samples.count {
            let fraction = Float(position - Double(lowerIndex))
            interpolated = lowerSample + ((samples[upperIndex] - lowerSample) * fraction)
        } else {
            interpolated = lowerSample
        }

        position += step
        outputFrameIndex += 1
        return interpolated * gain
    }
}

enum DiagnosticSpeechRenderer {
    private static var cache: [Int: DiagnosticSpeechClip] = [:]

    static func clip(for channelNumber: Int) -> DiagnosticSpeechClip? {
        if let cached = cache[channelNumber] {
            return cached
        }

        guard let url = renderSpeechFile(for: channelNumber),
              let clip = readMonoClip(from: url),
              !clip.samples.isEmpty
        else {
            return nil
        }

        cache[channelNumber] = clip
        return clip
    }

    private static func renderSpeechFile(for channelNumber: Int) -> URL? {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OrbisonicDiagnosticSpeech", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent("channel-\(channelNumber).aiff")
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        let synthesizer = NSSpeechSynthesizer()
        let phrase = "\(channelNumber), \(channelNumber), \(channelNumber)"
        guard synthesizer.startSpeaking(phrase, to: url) else {
            return nil
        }

        let deadline = Date().addingTimeInterval(4)
        while synthesizer.isSpeaking, Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }

        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static func readMonoClip(from url: URL) -> DiagnosticSpeechClip? {
        do {
            let file = try AVAudioFile(forReading: url)
            let frameCount = AVAudioFrameCount(file.length)
            let sampleRate = file.processingFormat.sampleRate
            guard frameCount > 0,
                  sampleRate > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount)
            else {
                return nil
            }

            try file.read(into: buffer)
            guard let channels = buffer.floatChannelData else {
                return nil
            }

            let channelCount = max(Int(buffer.format.channelCount), 1)
            let sampleCount = Int(buffer.frameLength)
            let samples = (0..<sampleCount).map { frame in
                var sum: Float = 0
                for channel in 0..<channelCount {
                    sum += channels[channel][frame]
                }
                return sum / Float(channelCount)
            }

            return DiagnosticSpeechClip(samples: samples, sampleRate: sampleRate)
        } catch {
            return nil
        }
    }
}
