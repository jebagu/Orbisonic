import AudioContracts
import Foundation

public struct SourceRateConversionContext: Equatable, Hashable, Sendable {
    public let sessionID: String
    public let sourceID: String
    public let sourceKind: SourceKind
    public let generation: UInt64
    public let frameStart: Int64
    public let layoutAuthority: SourceLayoutAuthority
    public let layoutAuthorityID: String?
    public let isDiscontinuity: Bool
    public let existingConversionLedger: AudioConversionLedger?

    public init(
        sessionID: String,
        sourceID: String,
        sourceKind: SourceKind,
        generation: UInt64,
        frameStart: Int64,
        layoutAuthority: SourceLayoutAuthority,
        layoutAuthorityID: String? = nil,
        isDiscontinuity: Bool = false,
        existingConversionLedger: AudioConversionLedger? = nil
    ) {
        self.sessionID = sessionID
        self.sourceID = sourceID
        self.sourceKind = sourceKind
        self.generation = generation
        self.frameStart = frameStart
        self.layoutAuthority = layoutAuthority
        self.layoutAuthorityID = layoutAuthorityID
        self.isDiscontinuity = isDiscontinuity
        self.existingConversionLedger = existingConversionLedger
    }
}

public struct SourceRateConversionResult: Sendable {
    public let block: CanonicalAudioBlock
    public let canonicalBlock: CanonicalSourceBlock
    public let ledger: AudioConversionLedger
    public let profile: SourceRateConverterProfile
    public let inputFrameCount: Int
    public let outputFrameCount: Int
    public let outputFrameStart: Int64

    public init(
        block: CanonicalAudioBlock,
        canonicalBlock: CanonicalSourceBlock,
        ledger: AudioConversionLedger,
        profile: SourceRateConverterProfile,
        inputFrameCount: Int,
        outputFrameCount: Int,
        outputFrameStart: Int64
    ) {
        self.block = block
        self.canonicalBlock = canonicalBlock
        self.ledger = ledger
        self.profile = profile
        self.inputFrameCount = inputFrameCount
        self.outputFrameCount = outputFrameCount
        self.outputFrameStart = outputFrameStart
    }
}

public protocol SourceRateConverter: Sendable {
    func configure(profile: SourceRateConverterProfile) throws -> SourceRateConverterConfiguration
    func convert(
        block: CanonicalAudioBlock,
        profile: SourceRateConverterProfile,
        context: SourceRateConversionContext
    ) throws -> SourceRateConversionResult
    func latency(profile: SourceRateConverterProfile) throws -> Int
}

public struct DeterministicSourceRateConverter: SourceRateConverter {
    public init() {}

    public func configure(profile: SourceRateConverterProfile) throws -> SourceRateConverterConfiguration {
        try SourceRateConverterConfiguration(profile: profile)
    }

    public func latency(profile: SourceRateConverterProfile) throws -> Int {
        try configure(profile: profile).latency()
    }

    public func convert(
        block: CanonicalAudioBlock,
        profile: SourceRateConverterProfile,
        context: SourceRateConversionContext
    ) throws -> SourceRateConversionResult {
        let configuration = try configure(profile: profile)
        try validate(block: block, profile: profile, context: context)

        let outputFrameCount = Self.outputFrameCount(
            inputFrameCount: block.frameCount,
            ratio: configuration.inputToOutputRatio
        )
        let output = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: profile.outputSampleRate,
                channelCount: block.channelCount,
                frameCount: outputFrameCount,
                processingFormat: block.processingFormat,
                layout: block.layout
            )
        )

        for channel in 0..<block.channelCount {
            let inputSamples = block.channelSamplesCopy(channel: channel)
            let outputSamples = Self.resample(
                inputSamples,
                outputFrameCount: outputFrameCount,
                inputToOutputRatio: configuration.inputToOutputRatio
            )
            try output.setChannelSamples(outputSamples, channel: channel)
        }
        try output.setFrameCount(outputFrameCount)

        let outputFrameStart = Int64(
            (Double(context.frameStart) * configuration.inputToOutputRatio).rounded(.toNearestOrAwayFromZero)
        )
        let canonical = try CanonicalSourceBlock(
            contract: AudioBlockContract(
                sourceID: context.sourceID,
                generation: context.generation,
                sampleRate: profile.outputSampleRate,
                frameStart: outputFrameStart,
                frameCount: outputFrameCount,
                channelCount: output.channelCount,
                processingFormat: output.processingFormat,
                layout: SourceLayout(
                    descriptor: output.layout,
                    authority: context.layoutAuthority,
                    authorityID: context.layoutAuthorityID
                ),
                isDiscontinuity: context.isDiscontinuity
            )
        )

        let ledger = AudioConversionLedger(
            sessionID: context.sessionID,
            sourceID: context.sourceID,
            sourceKind: context.sourceKind,
            entries: [
                AudioConversionLedgerEntry(
                    stage: .sampleRateConversion,
                    owner: .sourceRateConverter,
                    input: Self.formatSummary(for: block),
                    output: Self.formatSummary(for: output),
                    isExplicit: true,
                    note: profile.ledgerNote(channelCount: block.channelCount)
                )
            ]
        )

        return SourceRateConversionResult(
            block: output,
            canonicalBlock: canonical,
            ledger: ledger,
            profile: profile,
            inputFrameCount: block.frameCount,
            outputFrameCount: outputFrameCount,
            outputFrameStart: outputFrameStart
        )
    }

    private func validate(
        block: CanonicalAudioBlock,
        profile: SourceRateConverterProfile,
        context: SourceRateConversionContext
    ) throws {
        guard block.frameCount > 0 else {
            throw AudioError.invalidRenderGraphPlan("SourceRateConverter requires a non-empty block.")
        }
        guard block.processingFormat.isProductionInternalFormat else {
            throw AudioError.invalidRenderGraphPlan("SourceRateConverter requires Float32 non-interleaved PCM.")
        }
        guard block.sampleRate.matches(profile.inputSampleRate) else {
            throw AudioError.sampleRateMismatch(
                expected: profile.inputSampleRate,
                actual: block.sampleRate,
                context: "SourceRateConverter input"
            )
        }
        guard !block.sampleRate.matches(profile.outputSampleRate) else {
            throw AudioError.invalidRenderGraphPlan("SourceRateConverter refuses no-op SRC.")
        }
        guard !context.sourceID.isEmpty else {
            throw AudioError.invalidRenderGraphPlan("SourceRateConverter context sourceID must not be empty.")
        }
        if let existing = context.existingConversionLedger,
           existing.entries.contains(where: { $0.stage == .sampleRateConversion }) {
            throw AudioError.invalidRenderGraphPlan("SourceRateConverter refuses double SRC.")
        }
    }

    private static func outputFrameCount(inputFrameCount: Int, ratio: Double) -> Int {
        max(1, Int((Double(inputFrameCount) * ratio).rounded(.toNearestOrAwayFromZero)))
    }

    private static func resample(
        _ inputSamples: [Float],
        outputFrameCount: Int,
        inputToOutputRatio: Double
    ) -> [Float] {
        guard !inputSamples.isEmpty else { return [] }
        guard inputSamples.count > 1 else {
            return Array(repeating: inputSamples[0], count: outputFrameCount)
        }

        return (0..<outputFrameCount).map { outputFrame in
            let inputPosition = Double(outputFrame) / inputToOutputRatio
            let lower = min(max(Int(inputPosition.rounded(.down)), 0), inputSamples.count - 1)
            let upper = min(lower + 1, inputSamples.count - 1)
            let fraction = Float(inputPosition - Double(lower))
            return inputSamples[lower] * (1 - fraction) + inputSamples[upper] * fraction
        }
    }

    private static func formatSummary(for block: CanonicalAudioBlock) -> AudioFormatSummary {
        AudioFormatSummary(
            sampleRate: block.sampleRate,
            channelCount: block.channelCount,
            sampleFormat: block.processingFormat.sampleFormat,
            layoutName: block.layout.name
        )
    }
}
