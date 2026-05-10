import AudioContracts
import Foundation

public enum DanteOutputPayload: Equatable, Sendable {
    case int24LittleEndianInterleaved([UInt8])
    case float32Interleaved([Float])

    public var int24LittleEndianBytes: [UInt8]? {
        guard case .int24LittleEndianInterleaved(let bytes) = self else { return nil }
        return bytes
    }

    public var float32Samples: [Float]? {
        guard case .float32Interleaved(let samples) = self else { return nil }
        return samples
    }
}

public struct DanteOutputMeasurements: Equatable, Sendable {
    public let samplePeak: Float
    public let samplePeakDBFS: Double
    public let truePeak: Float
    public let truePeakDBTP: Double
    public let truePeakMethod: String
    public let clipCount: Int
    public let nanCount: Int
    public let infinityCount: Int
    public let perChannelMax: [Float]

    public init(
        samplePeak: Float,
        samplePeakDBFS: Double,
        truePeak: Float,
        truePeakDBTP: Double,
        truePeakMethod: String,
        clipCount: Int,
        nanCount: Int,
        infinityCount: Int,
        perChannelMax: [Float]
    ) {
        self.samplePeak = samplePeak
        self.samplePeakDBFS = samplePeakDBFS
        self.truePeak = truePeak
        self.truePeakDBTP = truePeakDBTP
        self.truePeakMethod = truePeakMethod
        self.clipCount = clipCount
        self.nanCount = nanCount
        self.infinityCount = infinityCount
        self.perChannelMax = perChannelMax
    }

    public static func measure(_ block: CanonicalAudioBlock) -> DanteOutputMeasurements {
        var samplePeak: Float = 0
        var clipCount = 0
        var nanCount = 0
        var infinityCount = 0
        var perChannelMax = Array(repeating: Float(0), count: block.channelCount)

        for channel in 0..<block.channelCount {
            var channelMax: Float = 0
            for frame in 0..<block.frameCount {
                let sample = block.sample(channel: channel, frame: frame)
                if sample.isNaN {
                    nanCount += 1
                    continue
                }
                if !sample.isFinite {
                    infinityCount += 1
                    continue
                }
                let magnitude = abs(sample)
                if magnitude > 1 {
                    clipCount += 1
                }
                channelMax = max(channelMax, magnitude)
                samplePeak = max(samplePeak, magnitude)
            }
            perChannelMax[channel] = channelMax
        }

        let peakDB = db(fromLinear: Double(samplePeak))
        return DanteOutputMeasurements(
            samplePeak: samplePeak,
            samplePeakDBFS: peakDB,
            truePeak: samplePeak,
            truePeakDBTP: peakDB,
            truePeakMethod: "sample-peak approximation",
            clipCount: clipCount,
            nanCount: nanCount,
            infinityCount: infinityCount,
            perChannelMax: perChannelMax
        )
    }

    private static func db(fromLinear value: Double) -> Double {
        value > 0 ? 20.0 * log10(value) : -.infinity
    }
}

public struct DanteOutputDiagnostics: Equatable, Sendable {
    public let measurements: DanteOutputMeasurements
    public let ditherKind: DanteDitherKind
    public let ditherApplied: Bool
    public let truePeakLimitDBTP: Double
    public let truePeakWithinLimit: Bool
    public let reservedPhysicalChannels: [Int]

    public init(
        measurements: DanteOutputMeasurements,
        ditherKind: DanteDitherKind,
        ditherApplied: Bool,
        truePeakLimitDBTP: Double,
        truePeakWithinLimit: Bool,
        reservedPhysicalChannels: [Int]
    ) {
        self.measurements = measurements
        self.ditherKind = ditherKind
        self.ditherApplied = ditherApplied
        self.truePeakLimitDBTP = truePeakLimitDBTP
        self.truePeakWithinLimit = truePeakWithinLimit
        self.reservedPhysicalChannels = reservedPhysicalChannels
    }
}

public struct DanteOutputPacket: Equatable, Sendable {
    public let profile: DanteTargetProfile
    public let generation: UInt64
    public let frameCount: Int
    public let sampleRate: AudioSampleRate
    public let logicalChannelCount: Int
    public let physicalChannelCount: Int
    public let payload: DanteOutputPayload
    public let diagnostics: DanteOutputDiagnostics
    public let ledger: AudioConversionLedger

    public init(
        profile: DanteTargetProfile,
        frameCount: Int,
        sampleRate: AudioSampleRate,
        logicalChannelCount: Int,
        physicalChannelCount: Int,
        payload: DanteOutputPayload,
        diagnostics: DanteOutputDiagnostics,
        ledger: AudioConversionLedger,
        generation: UInt64 = 0
    ) {
        self.profile = profile
        self.generation = generation
        self.frameCount = frameCount
        self.sampleRate = sampleRate
        self.logicalChannelCount = logicalChannelCount
        self.physicalChannelCount = physicalChannelCount
        self.payload = payload
        self.diagnostics = diagnostics
        self.ledger = ledger
    }
}

public struct DanteOutputFormatterConfiguration: Equatable, Hashable, Sendable {
    public let profile: DanteTargetProfile

    public init(profile: DanteTargetProfile) throws {
        try profile.validate()
        self.profile = profile
    }
}

public struct DanteOutputFormatContext: Equatable, Hashable, Sendable {
    public let sessionID: String
    public let sourceKind: SourceKind

    public init(sessionID: String, sourceKind: SourceKind) {
        self.sessionID = sessionID
        self.sourceKind = sourceKind
    }
}

public struct DanteOutputFormatter: Sendable {
    public init() {}

    public func configure(profile: DanteTargetProfile) throws -> DanteOutputFormatterConfiguration {
        try DanteOutputFormatterConfiguration(profile: profile)
    }

    public func format(
        samples: CanonicalAudioBlock,
        renderedBlock: RenderedSphereBlock,
        profile: DanteTargetProfile,
        context: DanteOutputFormatContext
    ) throws -> DanteOutputPacket {
        _ = try configure(profile: profile)
        try validate(samples: samples, renderedBlock: renderedBlock, profile: profile)

        let measurements = DanteOutputMeasurements.measure(samples)
        try validateHeadroom(measurements, profile: profile)

        let ditherKind = profile.ditherKindForOutput
        let ditherApplied = ditherKind != .none
        let reservedPhysicalChannels = profile.physicalChannelMap.enumerated().compactMap { index, mapped in
            mapped == nil ? index : nil
        }
        let payload: DanteOutputPayload
        switch profile.encodingKind {
        case .pcmInteger:
            guard profile.encodingBitDepth == 24 else {
                throw AudioError.invalidRenderGraphPlan("DanteOutputFormatter currently supports 24-bit integer PCM packing.")
            }
            payload = .int24LittleEndianInterleaved(
                Self.packInt24LittleEndian(
                    samples: samples,
                    profile: profile,
                    ditherKind: ditherKind
                )
            )
        case .float32:
            payload = .float32Interleaved(Self.packFloat32(samples: samples, profile: profile))
        }

        let diagnostics = DanteOutputDiagnostics(
            measurements: measurements,
            ditherKind: ditherKind,
            ditherApplied: ditherApplied,
            truePeakLimitDBTP: profile.maxTruePeakDBTP,
            truePeakWithinLimit: true,
            reservedPhysicalChannels: reservedPhysicalChannels
        )
        let ledger = AudioConversionLedger(
            sessionID: context.sessionID,
            sourceID: renderedBlock.sourceID,
            sourceKind: context.sourceKind,
            entries: [
                AudioConversionLedgerEntry(
                    stage: .format,
                    owner: .danteOutputFormatter,
                    input: Self.formatSummary(for: samples),
                    output: AudioFormatSummary(
                        sampleRate: profile.sampleRate,
                        channelCount: profile.physicalChannelCount,
                        sampleFormat: Self.sampleFormatDescription(profile),
                        layoutName: "Dante physical map"
                    ),
                    isExplicit: true,
                    note: [
                        "encodingKind=\(profile.encodingKind.rawValue)",
                        "encodingBitDepth=\(profile.encodingBitDepth)",
                        "dither=\(ditherKind.rawValue)",
                        "truePeakDBTP=\(measurements.truePeakDBTP)",
                        "physicalChannels=\(profile.physicalChannelCount)"
                    ].joined(separator: "; ")
                )
            ]
        )

        return DanteOutputPacket(
            profile: profile,
            frameCount: samples.frameCount,
            sampleRate: profile.sampleRate,
            logicalChannelCount: profile.logicalChannelCount,
            physicalChannelCount: profile.physicalChannelCount,
            payload: payload,
            diagnostics: diagnostics,
            ledger: ledger,
            generation: renderedBlock.generation
        )
    }

    private func validate(
        samples: CanonicalAudioBlock,
        renderedBlock: RenderedSphereBlock,
        profile: DanteTargetProfile
    ) throws {
        guard samples.processingFormat.isProductionInternalFormat else {
            throw AudioError.invalidRenderGraphPlan("DanteOutputFormatter requires Float32 non-interleaved rendered samples.")
        }
        guard samples.frameCount > 0 else {
            throw AudioError.invalidRenderGraphPlan("DanteOutputFormatter requires a non-empty rendered block.")
        }
        guard samples.sampleRate.matches(renderedBlock.sampleRate) else {
            throw AudioError.sampleRateMismatch(
                expected: renderedBlock.sampleRate,
                actual: samples.sampleRate,
                context: "DanteOutputFormatter rendered samples"
            )
        }
        guard renderedBlock.sampleRate.matches(profile.sampleRate) else {
            throw AudioError.sampleRateMismatch(
                expected: profile.sampleRate,
                actual: renderedBlock.sampleRate,
                context: "DanteOutputFormatter target profile"
            )
        }
        guard samples.channelCount == renderedBlock.channelCount else {
            throw AudioError.layoutChannelCountMismatch(expected: renderedBlock.channelCount, actual: samples.channelCount)
        }
        guard renderedBlock.channelCount == profile.logicalChannelCount else {
            throw AudioError.layoutChannelCountMismatch(expected: profile.logicalChannelCount, actual: renderedBlock.channelCount)
        }
        guard renderedBlock.contract.frameCount == samples.frameCount else {
            throw AudioError.invalidRenderGraphPlan("DanteOutputFormatter sample frame count must match rendered block contract.")
        }
        guard renderedBlock.outputMapID == profile.outputMapID else {
            throw AudioError.invalidRenderGraphPlan("DanteOutputFormatter output map must match target profile.")
        }
        guard renderedBlock.contract.layout.authority == .rendererOutputMap ||
              renderedBlock.contract.layout.authority == .pureSphericalManifest
        else {
            throw AudioError.invalidRenderGraphPlan("DanteOutputFormatter requires rendered output-map authority.")
        }
    }

    private func validateHeadroom(
        _ measurements: DanteOutputMeasurements,
        profile: DanteTargetProfile
    ) throws {
        guard measurements.nanCount == 0 else {
            throw AudioError.invalidRenderGraphPlan("DanteOutputFormatter rejects NaN samples.")
        }
        guard measurements.infinityCount == 0 else {
            throw AudioError.invalidRenderGraphPlan("DanteOutputFormatter rejects infinite samples.")
        }
        guard measurements.clipCount == 0 else {
            throw AudioError.invalidRenderGraphPlan("DanteOutputFormatter rejects clipped samples.")
        }
        guard measurements.truePeakDBTP <= profile.maxTruePeakDBTP else {
            throw AudioError.invalidRenderGraphPlan(
                "DanteOutputFormatter true peak \(measurements.truePeakDBTP) dBTP exceeds limit \(profile.maxTruePeakDBTP) dBTP."
            )
        }
    }

    private static func packFloat32(
        samples: CanonicalAudioBlock,
        profile: DanteTargetProfile
    ) -> [Float] {
        var output: [Float] = []
        output.reserveCapacity(samples.frameCount * profile.physicalChannelCount)
        for frame in 0..<samples.frameCount {
            for physicalChannel in 0..<profile.physicalChannelCount {
                guard let logicalChannel = profile.physicalChannelMap[physicalChannel] else {
                    output.append(0)
                    continue
                }
                output.append(samples.sample(channel: logicalChannel, frame: frame))
            }
        }
        return output
    }

    private static func packInt24LittleEndian(
        samples: CanonicalAudioBlock,
        profile: DanteTargetProfile,
        ditherKind: DanteDitherKind
    ) -> [UInt8] {
        var generator = DeterministicTPDFGenerator(seed: profile.ditherSeed)
        var output: [UInt8] = []
        output.reserveCapacity(samples.frameCount * profile.physicalChannelCount * 3)
        for frame in 0..<samples.frameCount {
            for physicalChannel in 0..<profile.physicalChannelCount {
                guard let logicalChannel = profile.physicalChannelMap[physicalChannel] else {
                    output.append(contentsOf: [0, 0, 0])
                    continue
                }
                var sample = Double(samples.sample(channel: logicalChannel, frame: frame))
                if ditherKind == .tpdf {
                    sample += generator.nextTPDF() / Double(Int24.positiveMax)
                }
                let quantized = Int24.quantize(sample)
                output.append(UInt8(truncatingIfNeeded: quantized))
                output.append(UInt8(truncatingIfNeeded: quantized >> 8))
                output.append(UInt8(truncatingIfNeeded: quantized >> 16))
            }
        }
        return output
    }

    private static func formatSummary(for block: CanonicalAudioBlock) -> AudioFormatSummary {
        AudioFormatSummary(
            sampleRate: block.sampleRate,
            channelCount: block.channelCount,
            sampleFormat: block.processingFormat.sampleFormat,
            layoutName: block.layout.name
        )
    }

    private static func sampleFormatDescription(_ profile: DanteTargetProfile) -> String {
        switch profile.encodingKind {
        case .pcmInteger:
            "PCM \(profile.encodingBitDepth)-bit"
        case .float32:
            "Float32"
        }
    }
}

private enum Int24 {
    static let positiveMax: Int32 = 8_388_607
    static let negativeMin: Int32 = -8_388_608

    static func quantize(_ sample: Double) -> Int32 {
        let clamped = min(max(sample, -1.0), 1.0)
        if clamped <= -1 {
            return negativeMin
        }
        return Int32((clamped * Double(positiveMax)).rounded(.toNearestOrAwayFromZero))
    }
}

private struct DeterministicTPDFGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9e37_79b9_7f4a_7c15 : seed
    }

    mutating func nextTPDF() -> Double {
        nextUnit() - nextUnit()
    }

    private mutating func nextUnit() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let mantissa = state >> 11
        return Double(mantissa) / Double(1 << 53)
    }
}
