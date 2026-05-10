import AudioContracts
import Foundation

public struct SonicSphereProfile: Equatable, Hashable, Sendable {
    public let id: String
    public let outputMapID: String
    public let sampleRate: AudioSampleRate
    public let outputChannelCount: Int
    public let outputLayout: AudioChannelLayoutDescriptor

    public init(
        id: String,
        outputMapID: String,
        sampleRate: AudioSampleRate,
        outputChannelCount: Int,
        outputLayout: AudioChannelLayoutDescriptor
    ) {
        self.id = id
        self.outputMapID = outputMapID
        self.sampleRate = sampleRate
        self.outputChannelCount = outputChannelCount
        self.outputLayout = outputLayout
    }

    public static func directThirtyOne(sampleRate: AudioSampleRate = .defaultProduction) -> SonicSphereProfile {
        SonicSphereProfile(
            id: "sonic-sphere-31-reference",
            outputMapID: "direct-30.1-logical",
            sampleRate: sampleRate,
            outputChannelCount: DanteRenderPlan.logicalOutputCount,
            outputLayout: .direct31
        )
    }

    public func validationErrors() -> [AudioError] {
        var errors: [AudioError] = []
        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.invalidRenderGraphPlan("SonicSphere profile id must not be empty."))
        }
        if outputMapID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.invalidRenderGraphPlan("SonicSphere output map id must not be empty."))
        }
        if outputChannelCount <= 0 {
            errors.append(.invalidRenderGraphPlan("SonicSphere output channel count must be positive."))
        }
        if outputChannelCount != outputLayout.channelCount {
            errors.append(.layoutChannelCountMismatch(expected: outputChannelCount, actual: outputLayout.channelCount))
        }
        errors.append(contentsOf: outputLayout.validationErrors(expectedChannelCount: outputChannelCount))
        return errors
    }

    public func validate() throws {
        if let error = validationErrors().first {
            throw error
        }
    }
}

public enum SonicSphereHighChannelPolicy: String, CaseIterable, Equatable, Hashable, Sendable {
    case blockAboveProfileOutputCount
}

public struct SonicSphereRenderPolicy: Equatable, Hashable, Sendable {
    public let id: String
    public let requestedRenderMode: RenderMode
    public let allowedLayoutAuthorities: Set<SourceLayoutAuthority>
    public let highChannelPolicy: SonicSphereHighChannelPolicy

    public init(
        id: String,
        requestedRenderMode: RenderMode = .automatic,
        allowedLayoutAuthorities: Set<SourceLayoutAuthority> = Self.defaultAllowedLayoutAuthorities,
        highChannelPolicy: SonicSphereHighChannelPolicy = .blockAboveProfileOutputCount
    ) {
        self.id = id
        self.requestedRenderMode = requestedRenderMode
        self.allowedLayoutAuthorities = allowedLayoutAuthorities
        self.highChannelPolicy = highChannelPolicy
    }

    public static let defaultAllowedLayoutAuthorities: Set<SourceLayoutAuthority> = [
        .containerMetadata,
        .userOverride,
        .liveCaptureContract,
        .spotifyStereoContract
    ]

    public static func production(renderMode: RenderMode = .automatic) -> SonicSphereRenderPolicy {
        SonicSphereRenderPolicy(
            id: "production-\(renderMode.rawValue)",
            requestedRenderMode: renderMode
        )
    }

    public static var direct30Identity: SonicSphereRenderPolicy {
        SonicSphereRenderPolicy(
            id: "direct30-identity",
            requestedRenderMode: .direct30,
            allowedLayoutAuthorities: [.containerMetadata, .userOverride]
        )
    }

    public func validationErrors() -> [AudioError] {
        var errors: [AudioError] = []
        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.invalidRenderGraphPlan("SonicSphere render policy id must not be empty."))
        }
        if allowedLayoutAuthorities.isEmpty {
            errors.append(.invalidRenderGraphPlan("SonicSphere render policy must declare allowed layout authorities."))
        }
        if allowedLayoutAuthorities.contains(.unknown) {
            errors.append(.invalidRenderGraphPlan("SonicSphere render policy cannot accept unknown layout authority."))
        }
        return errors
    }

    public func validate() throws {
        if let error = validationErrors().first {
            throw error
        }
    }
}

public struct SonicSphereRenderContext: Equatable, Hashable, Sendable {
    public let sessionID: String
    public let sourceKind: SourceKind

    public init(sessionID: String, sourceKind: SourceKind) {
        self.sessionID = sessionID
        self.sourceKind = sourceKind
    }
}

public struct SonicSphereRenderConfiguration: Equatable, Hashable, Sendable {
    public let profile: SonicSphereProfile
    public let policy: SonicSphereRenderPolicy

    public init(profile: SonicSphereProfile, policy: SonicSphereRenderPolicy) throws {
        try profile.validate()
        try policy.validate()
        self.profile = profile
        self.policy = policy
    }
}

public struct SonicSphereRenderResult: Sendable {
    public let samples: CanonicalAudioBlock
    public let renderedBlock: RenderedSphereBlock
    public let ledger: AudioConversionLedger
    public let resolvedRenderMode: RenderMode
    public let profile: SonicSphereProfile
    public let policy: SonicSphereRenderPolicy

    public init(
        samples: CanonicalAudioBlock,
        renderedBlock: RenderedSphereBlock,
        ledger: AudioConversionLedger,
        resolvedRenderMode: RenderMode,
        profile: SonicSphereProfile,
        policy: SonicSphereRenderPolicy
    ) {
        self.samples = samples
        self.renderedBlock = renderedBlock
        self.ledger = ledger
        self.resolvedRenderMode = resolvedRenderMode
        self.profile = profile
        self.policy = policy
    }
}

public protocol SonicSphereRenderer: Sendable {
    func prepare(
        profile: SonicSphereProfile,
        policy: SonicSphereRenderPolicy
    ) throws -> SonicSphereRenderConfiguration

    func render(
        source: CanonicalAudioBlock,
        sourceBlock: CanonicalSourceBlock,
        profile: SonicSphereProfile,
        policy: SonicSphereRenderPolicy,
        context: SonicSphereRenderContext
    ) throws -> SonicSphereRenderResult
}

public struct MatrixSonicSphereRenderer: SonicSphereRenderer {
    public init() {}

    public func prepare(
        profile: SonicSphereProfile,
        policy: SonicSphereRenderPolicy
    ) throws -> SonicSphereRenderConfiguration {
        try SonicSphereRenderConfiguration(profile: profile, policy: policy)
    }

    public func render(
        source: CanonicalAudioBlock,
        sourceBlock: CanonicalSourceBlock,
        profile: SonicSphereProfile,
        policy: SonicSphereRenderPolicy,
        context: SonicSphereRenderContext
    ) throws -> SonicSphereRenderResult {
        let configuration = try prepare(profile: profile, policy: policy)
        try validate(source: source, sourceBlock: sourceBlock, configuration: configuration)

        let resolvedMode = SonicSphereMatrixPolicy.resolvedMode(
            policy.requestedRenderMode,
            sourceChannelCount: sourceBlock.channelCount
        )
        let matrix = try SonicSphereMatrixPolicy.matrix(
            sourceLayout: sourceBlock.layout.descriptor,
            renderMode: resolvedMode,
            physicalOutputCount: profile.outputChannelCount
        )
        let output = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: profile.sampleRate,
                channelCount: profile.outputChannelCount,
                frameCount: source.frameCount,
                layout: profile.outputLayout
            )
        )
        try MatrixRenderKernel(matrix: matrix).process(
            source: source,
            destination: output,
            frameCount: source.frameCount
        )
        let renderedBlock = try RenderedSphereBlock(
            contract: AudioBlockContract(
                sourceID: sourceBlock.sourceID,
                generation: sourceBlock.generation,
                sampleRate: profile.sampleRate,
                frameStart: sourceBlock.contract.frameStart,
                frameCount: output.frameCount,
                channelCount: output.channelCount,
                processingFormat: output.processingFormat,
                layout: SourceLayout(
                    descriptor: profile.outputLayout,
                    authority: .rendererOutputMap,
                    authorityID: profile.outputMapID
                ),
                isDiscontinuity: sourceBlock.contract.isDiscontinuity
            ),
            outputMapID: profile.outputMapID,
            sphereProfileID: profile.id
        )
        let ledger = AudioConversionLedger(
            sessionID: context.sessionID,
            sourceID: sourceBlock.sourceID,
            sourceKind: context.sourceKind,
            entries: [
                AudioConversionLedgerEntry(
                    stage: .render,
                    owner: .sonicSphereRenderer,
                    input: Self.formatSummary(
                        sampleRate: sourceBlock.sampleRate,
                        channelCount: sourceBlock.channelCount,
                        layoutName: sourceBlock.layout.descriptor.name
                    ),
                    output: Self.formatSummary(for: output),
                    isExplicit: true,
                    note: [
                        "renderPolicy=\(policy.id)",
                        "renderMode=\(resolvedMode.rawValue)",
                        "sphereProfileID=\(profile.id)",
                        "outputMapID=\(profile.outputMapID)",
                        "sourceLayoutAuthority=\(sourceBlock.layout.authority.rawValue)"
                    ].joined(separator: "; ")
                )
            ]
        )

        return SonicSphereRenderResult(
            samples: output,
            renderedBlock: renderedBlock,
            ledger: ledger,
            resolvedRenderMode: resolvedMode,
            profile: profile,
            policy: policy
        )
    }

    private func validate(
        source: CanonicalAudioBlock,
        sourceBlock: CanonicalSourceBlock,
        configuration: SonicSphereRenderConfiguration
    ) throws {
        guard source.processingFormat.isProductionInternalFormat else {
            throw AudioError.invalidRenderGraphPlan("SonicSphereRenderer requires Float32 non-interleaved PCM.")
        }
        guard source.frameCount > 0 else {
            throw AudioError.invalidRenderGraphPlan("SonicSphereRenderer requires a non-empty source block.")
        }
        guard source.sampleRate.matches(sourceBlock.sampleRate) else {
            throw AudioError.sampleRateMismatch(
                expected: sourceBlock.sampleRate,
                actual: source.sampleRate,
                context: "SonicSphereRenderer source samples"
            )
        }
        guard source.sampleRate.matches(configuration.profile.sampleRate) else {
            throw AudioError.sampleRateMismatch(
                expected: configuration.profile.sampleRate,
                actual: source.sampleRate,
                context: "SonicSphereRenderer profile"
            )
        }
        guard source.channelCount == sourceBlock.channelCount else {
            throw AudioError.layoutChannelCountMismatch(expected: sourceBlock.channelCount, actual: source.channelCount)
        }
        guard source.layout == sourceBlock.layout.descriptor else {
            throw AudioError.invalidRenderGraphPlan("SonicSphereRenderer source sample layout must match source contract.")
        }
        guard configuration.policy.allowedLayoutAuthorities.contains(sourceBlock.layout.authority) else {
            throw AudioError.invalidRenderGraphPlan(
                "SonicSphereRenderer rejects source layout authority \(sourceBlock.layout.authority.rawValue)."
            )
        }
        if let expectedInputCount = configuration.policy.requestedRenderMode.expectedInputCount,
           expectedInputCount != sourceBlock.channelCount {
            throw AudioError.invalidRenderGraphPlan(
                "SonicSphere render policy \(configuration.policy.id) requires \(expectedInputCount) source channels."
            )
        }
        switch configuration.policy.highChannelPolicy {
        case .blockAboveProfileOutputCount:
            if sourceBlock.channelCount > configuration.profile.outputChannelCount {
                throw AudioError.invalidRenderGraphPlan(
                    "SonicSphereRenderer blocks \(sourceBlock.channelCount)-channel sources above profile output count \(configuration.profile.outputChannelCount)."
                )
            }
        }
    }

    private static func formatSummary(for block: CanonicalAudioBlock) -> AudioFormatSummary {
        formatSummary(
            sampleRate: block.sampleRate,
            channelCount: block.channelCount,
            layoutName: block.layout.name
        )
    }

    private static func formatSummary(
        sampleRate: AudioSampleRate,
        channelCount: Int,
        layoutName: String
    ) -> AudioFormatSummary {
        AudioFormatSummary(
            sampleRate: sampleRate,
            channelCount: channelCount,
            sampleFormat: ProcessingFormat.float32NonInterleavedPCM.sampleFormat,
            layoutName: layoutName
        )
    }
}
