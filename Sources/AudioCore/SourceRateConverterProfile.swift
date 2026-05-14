import AudioContracts
import Foundation

public enum SourceRateConverterAlgorithm: Equatable, Hashable, Sendable {
    case deterministicLinearReference
    case externalHighQuality(String)

    public var stableName: String {
        switch self {
        case .deterministicLinearReference:
            "deterministic-linear-reference"
        case .externalHighQuality(let name):
            name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

public enum SourceRateConverterPhaseMode: String, CaseIterable, Equatable, Hashable, Sendable {
    case linearPhaseReference
    case minimumPhase
    case apodizingPhase

    public var stableName: String {
        rawValue
    }
}

public enum SourceRateConverterQuality: String, CaseIterable, Equatable, Hashable, Sendable {
    case deterministicReference
    case productionHighQuality
}

public struct SourceRateConverterProfile: Equatable, Hashable, Sendable {
    public let inputSampleRate: AudioSampleRate
    public let outputSampleRate: AudioSampleRate
    public let algorithm: SourceRateConverterAlgorithm
    public let phaseMode: SourceRateConverterPhaseMode
    public let quality: SourceRateConverterQuality
    public let declaredLatencyFrames: Int
    public let passbandDescription: String
    public let stopbandDescription: String

    public init(
        inputSampleRate: AudioSampleRate,
        outputSampleRate: AudioSampleRate,
        algorithm: SourceRateConverterAlgorithm,
        phaseMode: SourceRateConverterPhaseMode,
        quality: SourceRateConverterQuality,
        declaredLatencyFrames: Int,
        passbandDescription: String,
        stopbandDescription: String
    ) {
        self.inputSampleRate = inputSampleRate
        self.outputSampleRate = outputSampleRate
        self.algorithm = algorithm
        self.phaseMode = phaseMode
        self.quality = quality
        self.declaredLatencyFrames = declaredLatencyFrames
        self.passbandDescription = passbandDescription
        self.stopbandDescription = stopbandDescription
    }

    public static func deterministicReference(
        inputSampleRate: AudioSampleRate,
        outputSampleRate: AudioSampleRate
    ) -> SourceRateConverterProfile {
        SourceRateConverterProfile(
            inputSampleRate: inputSampleRate,
            outputSampleRate: outputSampleRate,
            algorithm: .deterministicLinearReference,
            phaseMode: .linearPhaseReference,
            quality: .deterministicReference,
            declaredLatencyFrames: 0,
            passbandDescription: "deterministic test profile; no production passband guarantee",
            stopbandDescription: "deterministic test profile; no production stopband guarantee"
        )
    }

    public func validationErrors() -> [AudioError] {
        var errors: [AudioError] = []
        if inputSampleRate.matches(outputSampleRate) {
            errors.append(.invalidRenderGraphPlan("SourceRateConverter requires distinct input and output rates."))
        }
        if declaredLatencyFrames < 0 {
            errors.append(.invalidRenderGraphPlan("SourceRateConverter latency must not be negative."))
        }
        if algorithm.stableName.isEmpty {
            errors.append(.invalidRenderGraphPlan("SourceRateConverter algorithm name must not be empty."))
        }
        if passbandDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.invalidRenderGraphPlan("SourceRateConverter passband description must not be empty."))
        }
        if stopbandDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.invalidRenderGraphPlan("SourceRateConverter stopband description must not be empty."))
        }
        return errors
    }

    public func validate() throws {
        if let error = validationErrors().first {
            throw error
        }
    }

    public func ledgerNote(channelCount: Int) -> String {
        [
            "srcOccurred=true",
            "srcAlgorithm=\(algorithm.stableName)",
            "srcPhaseMode=\(phaseMode.stableName)",
            "srcInputRate=\(inputSampleRate.hertz)",
            "srcOutputRate=\(outputSampleRate.hertz)",
            "srcLatencyFrames=\(declaredLatencyFrames)",
            "srcChannels=\(channelCount)",
            "srcQuality=\(quality.rawValue)"
        ].joined(separator: "; ")
    }
}

public struct SourceRateConverterConfiguration: Equatable, Hashable, Sendable {
    public let profile: SourceRateConverterProfile
    public let inputToOutputRatio: Double

    public var outputToInputRatio: Double {
        1.0 / inputToOutputRatio
    }

    public init(profile: SourceRateConverterProfile) throws {
        try profile.validate()
        self.profile = profile
        self.inputToOutputRatio = profile.outputSampleRate.hertz / profile.inputSampleRate.hertz
    }

    public func latency() -> Int {
        profile.declaredLatencyFrames
    }
}
