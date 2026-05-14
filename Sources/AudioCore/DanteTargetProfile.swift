import AudioContracts
import Foundation

public enum DanteBackend: String, CaseIterable, Equatable, Hashable, Sendable {
    case validationOnly
    case coreAudioHostFloat32
    case dantePCMNetwork
}

public enum DanteEncodingKind: String, CaseIterable, Equatable, Hashable, Sendable {
    case pcmInteger
    case float32
}

public enum DanteDitherKind: String, CaseIterable, Equatable, Hashable, Sendable {
    case none
    case tpdf
}

public struct DanteTargetProfile: Equatable, Hashable, Sendable {
    public let backend: DanteBackend
    public let sampleRate: AudioSampleRate
    public let encodingBitDepth: Int
    public let encodingKind: DanteEncodingKind
    public let logicalChannelCount: Int
    public let physicalChannelCount: Int
    public let outputMapID: String
    public let physicalChannelMap: [Int?]
    public let allowSampleRateConversion: Bool
    public let requireStrictRoute: Bool
    public let requireDitherForIntegerOutput: Bool
    public let maxTruePeakDBTP: Double
    public let ditherSeed: UInt64

    public init(
        backend: DanteBackend,
        sampleRate: AudioSampleRate,
        encodingBitDepth: Int,
        encodingKind: DanteEncodingKind,
        logicalChannelCount: Int = DanteRenderPlan.logicalOutputCount,
        physicalChannelCount: Int,
        outputMapID: String,
        physicalChannelMap: [Int?]? = nil,
        allowSampleRateConversion: Bool = true,
        requireStrictRoute: Bool = true,
        requireDitherForIntegerOutput: Bool = true,
        maxTruePeakDBTP: Double = -1.0,
        ditherSeed: UInt64 = 0x0d4a_7e10_d17e_0123
    ) {
        self.backend = backend
        self.sampleRate = sampleRate
        self.encodingBitDepth = encodingBitDepth
        self.encodingKind = encodingKind
        self.logicalChannelCount = logicalChannelCount
        self.physicalChannelCount = physicalChannelCount
        self.outputMapID = outputMapID
        self.physicalChannelMap = physicalChannelMap ?? Self.defaultPhysicalChannelMap(
            logicalChannelCount: logicalChannelCount,
            physicalChannelCount: physicalChannelCount
        )
        self.allowSampleRateConversion = allowSampleRateConversion
        self.requireStrictRoute = requireStrictRoute
        self.requireDitherForIntegerOutput = requireDitherForIntegerOutput
        self.maxTruePeakDBTP = maxTruePeakDBTP
        self.ditherSeed = ditherSeed
    }

    public static func defaultPCM24(
        sampleRate: AudioSampleRate = .defaultProduction,
        physicalChannelCount: Int = 32,
        outputMapID: String = "direct-30.1-logical"
    ) -> DanteTargetProfile {
        DanteTargetProfile(
            backend: .dantePCMNetwork,
            sampleRate: sampleRate,
            encodingBitDepth: 24,
            encodingKind: .pcmInteger,
            physicalChannelCount: physicalChannelCount,
            outputMapID: outputMapID
        )
    }

    public static func hostFloat32(
        sampleRate: AudioSampleRate = .defaultProduction,
        physicalChannelCount: Int = 32,
        outputMapID: String = "direct-30.1-logical"
    ) -> DanteTargetProfile {
        DanteTargetProfile(
            backend: .coreAudioHostFloat32,
            sampleRate: sampleRate,
            encodingBitDepth: 32,
            encodingKind: .float32,
            physicalChannelCount: physicalChannelCount,
            outputMapID: outputMapID,
            requireDitherForIntegerOutput: false
        )
    }

    public var ditherKindForOutput: DanteDitherKind {
        encodingKind == .pcmInteger && requireDitherForIntegerOutput ? .tpdf : .none
    }

    public func validationErrors() -> [AudioError] {
        var errors: [AudioError] = []
        if logicalChannelCount != DanteRenderPlan.logicalOutputCount {
            errors.append(.invalidRenderGraphPlan("Dante target logical channel count must be 31."))
        }
        if physicalChannelCount < 31 {
            errors.append(.danteRouteInsufficientChannels(required: 31, actual: physicalChannelCount))
        } else if physicalChannelCount > 32 {
            errors.append(.invalidRenderGraphPlan("Dante target physical channel count must be 31 or 32."))
        }
        if physicalChannelMap.count != physicalChannelCount {
            errors.append(.invalidRenderGraphPlan("Dante physical channel map must match physical channel count."))
        }
        for mappedChannel in physicalChannelMap.compactMap({ $0 }) {
            if mappedChannel < 0 || mappedChannel >= logicalChannelCount {
                errors.append(.invalidRenderGraphPlan("Dante physical channel map references an invalid logical channel."))
                break
            }
        }
        if outputMapID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.invalidRenderGraphPlan("Dante target output map id must not be empty."))
        }
        if encodingKind == .pcmInteger, ![16, 24, 32].contains(encodingBitDepth) {
            errors.append(.invalidRenderGraphPlan("Dante integer PCM bit depth must be 16, 24, or 32."))
        }
        if encodingKind == .float32, encodingBitDepth != 32 {
            errors.append(.invalidRenderGraphPlan("Dante float output must be 32-bit."))
        }
        if encodingKind == .pcmInteger, backend == .coreAudioHostFloat32 {
            errors.append(.invalidRenderGraphPlan("CoreAudio host Float32 profile cannot use integer PCM encoding."))
        }
        if encodingKind == .float32, backend == .dantePCMNetwork {
            errors.append(.invalidRenderGraphPlan("Dante PCM network profile cannot use Float32 host encoding."))
        }
        if !sampleRate.isDanteThirtyOneChannelProductionEligible {
            errors.append(.danteUnsupportedSampleRate(sampleRate))
        }
        if !maxTruePeakDBTP.isFinite {
            errors.append(.invalidRenderGraphPlan("Dante true-peak limit must be finite."))
        }
        return errors
    }

    public func validate() throws {
        if let error = validationErrors().first {
            throw error
        }
    }

    public static func defaultPhysicalChannelMap(
        logicalChannelCount: Int = DanteRenderPlan.logicalOutputCount,
        physicalChannelCount: Int
    ) -> [Int?] {
        (0..<physicalChannelCount).map { physicalIndex in
            physicalIndex < logicalChannelCount ? physicalIndex : nil
        }
    }
}
