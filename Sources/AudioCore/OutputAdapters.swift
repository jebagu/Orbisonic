import AudioContracts
import Foundation

public enum AudioOutputAdapterState: String, CaseIterable, Equatable, Hashable, Sendable {
    case inactive
    case prepared
    case active
    case muted
    case routeUnavailable
    case routeSampleRateMismatch
    case insufficientChannels
    case failed
    case underrun
    case validationOnly
}

public struct AudioOutputBlockFormat: Equatable, Hashable, Sendable {
    public let sampleRate: AudioSampleRate
    public let channelCount: Int
    public let layout: AudioChannelLayoutDescriptor
    public let processingFormat: ProcessingFormat

    public init(
        sampleRate: AudioSampleRate,
        channelCount: Int,
        layout: AudioChannelLayoutDescriptor,
        processingFormat: ProcessingFormat = .float32NonInterleavedPCM
    ) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.layout = layout
        self.processingFormat = processingFormat
    }
}

public struct AudioOutputStatusSnapshot: Equatable, Hashable, Sendable {
    public let routeID: String
    public let routeName: String
    public let state: AudioOutputAdapterState
    public let outputFormat: AudioOutputBlockFormat?
    public let consumedFramePosition: Int64
    public let underrunCount: Int
    public let validationMessages: [String]
    public let failureMessage: String?
    public let sourceFrameIndex: Int64?

    public init(
        routeID: String,
        routeName: String,
        state: AudioOutputAdapterState,
        outputFormat: AudioOutputBlockFormat?,
        consumedFramePosition: Int64,
        underrunCount: Int = 0,
        validationMessages: [String] = [],
        failureMessage: String? = nil,
        sourceFrameIndex: Int64? = nil
    ) {
        self.routeID = routeID
        self.routeName = routeName
        self.state = state
        self.outputFormat = outputFormat
        self.consumedFramePosition = consumedFramePosition
        self.underrunCount = underrunCount
        self.validationMessages = validationMessages
        self.failureMessage = failureMessage
        self.sourceFrameIndex = sourceFrameIndex
    }
}

public struct DesktopOutputStatus: Equatable, Hashable, Sendable {
    public let snapshot: AudioOutputStatusSnapshot
    public let desktopOutputFailed: Bool
    public let isMuted: Bool

    public init(
        snapshot: AudioOutputStatusSnapshot,
        desktopOutputFailed: Bool,
        isMuted: Bool
    ) {
        self.snapshot = snapshot
        self.desktopOutputFailed = desktopOutputFailed
        self.isMuted = isMuted
    }
}

public struct DanteOutputStatus: Equatable, Hashable, Sendable {
    public let snapshot: AudioOutputStatusSnapshot
    public let productionOutputFailed: Bool
    public let logicalChannelCount: Int
    public let physicalChannelCount: Int
    public let isChannel32Reserved: Bool

    public init(
        snapshot: AudioOutputStatusSnapshot,
        productionOutputFailed: Bool,
        logicalChannelCount: Int,
        physicalChannelCount: Int,
        isChannel32Reserved: Bool
    ) {
        self.snapshot = snapshot
        self.productionOutputFailed = productionOutputFailed
        self.logicalChannelCount = logicalChannelCount
        self.physicalChannelCount = physicalChannelCount
        self.isChannel32Reserved = isChannel32Reserved
    }
}

public struct DualOutputStatus: Equatable, Hashable, Sendable {
    public let desktop: DesktopOutputStatus
    public let dante: DanteOutputStatus
    public let sourceFrameIndex: Int64
    public let renderPlanVersion: UInt64
    public let validationMessages: [String]

    public var productionOutputFailed: Bool {
        dante.productionOutputFailed
    }

    public init(
        desktop: DesktopOutputStatus,
        dante: DanteOutputStatus,
        sourceFrameIndex: Int64,
        renderPlanVersion: UInt64,
        validationMessages: [String] = []
    ) {
        self.desktop = desktop
        self.dante = dante
        self.sourceFrameIndex = sourceFrameIndex
        self.renderPlanVersion = renderPlanVersion
        self.validationMessages = validationMessages
    }
}

public protocol AudioOutputAdapter: AnyObject, Sendable {
    var route: OutputRouteDescriptor { get }
    var outputFormat: AudioOutputBlockFormat? { get }

    func prepare(sessionFormat: AudioSessionFormat) throws
    func start() throws
    func stop()
    func consume(_ block: CanonicalAudioBlock, sourceFrameIndex: Int64) throws
    func latestStatusSnapshot() -> AudioOutputStatusSnapshot
}

public protocol DesktopOutputAdapter: AudioOutputAdapter {
    func latestDesktopStatus() -> DesktopOutputStatus
}

public protocol DanteOutputAdapter: AudioOutputAdapter {
    func latestDanteStatus() -> DanteOutputStatus
}

public final class OfflineDesktopOutputAdapter: DesktopOutputAdapter, @unchecked Sendable {
    public let route: OutputRouteDescriptor
    public private(set) var outputFormat: AudioOutputBlockFormat?

    private let validationOnly: Bool
    private let shouldFailOnConsume: Bool
    private var state: AudioOutputAdapterState = .inactive
    private var consumedFramePosition: Int64 = 0
    private var underrunCount = 0
    private var validationMessages: [String] = []
    private var failureMessage: String?
    private var lastSourceFrameIndex: Int64?
    private var lastBlock: CanonicalAudioBlock?

    public init(
        route: OutputRouteDescriptor,
        validationOnly: Bool = true,
        shouldFailOnConsume: Bool = false
    ) {
        self.route = route
        self.validationOnly = validationOnly
        self.shouldFailOnConsume = shouldFailOnConsume
    }

    public func prepare(sessionFormat: AudioSessionFormat) throws {
        guard route.isAvailable else {
            setFailure(.routeUnavailable, message: "Desktop route is unavailable.")
            throw AudioError.routeUnavailable(route.id)
        }
        guard route.outputChannelCount >= 2 else {
            setFailure(.insufficientChannels, message: "Desktop route exposes fewer than two channels.")
            throw AudioError.desktopRouteInsufficientChannels(required: 2, actual: route.outputChannelCount)
        }
        if let nominalSampleRate = route.nominalSampleRate,
           !nominalSampleRate.matches(sessionFormat.sampleRate) {
            setFailure(.routeSampleRateMismatch, message: "Desktop route sample rate does not match the session.")
            throw AudioError.sampleRateMismatch(
                expected: sessionFormat.sampleRate,
                actual: nominalSampleRate,
                context: "desktop output route"
            )
        }

        outputFormat = AudioOutputBlockFormat(
            sampleRate: sessionFormat.sampleRate,
            channelCount: 2,
            layout: .stereo
        )
        state = validationOnly ? .validationOnly : .prepared
        failureMessage = nil
        validationMessages = validationOnly
            ? ["Desktop route validated; live desktop output adapter not yet active."]
            : ["Desktop route prepared."]
    }

    public func start() throws {
        guard outputFormat != nil else {
            throw AudioError.routeUnavailable(route.id)
        }
        state = validationOnly ? .validationOnly : .active
    }

    public func stop() {
        state = .inactive
    }

    public func mute() {
        state = .muted
    }

    public func consume(_ block: CanonicalAudioBlock, sourceFrameIndex: Int64) throws {
        guard let outputFormat else {
            throw AudioError.routeUnavailable(route.id)
        }
        guard block.channelCount == 2 else {
            setFailure(.failed, message: "Desktop block must be stereo.")
            throw AudioError.desktopRouteInsufficientChannels(required: 2, actual: block.channelCount)
        }
        guard block.sampleRate.matches(outputFormat.sampleRate) else {
            setFailure(.routeSampleRateMismatch, message: "Desktop block sample rate does not match output.")
            throw AudioError.sampleRateMismatch(
                expected: outputFormat.sampleRate,
                actual: block.sampleRate,
                context: "desktop output block"
            )
        }
        guard block.frameCount > 0 else {
            underrunCount += 1
            state = .underrun
            throw AudioError.invalidRenderGraphPlan("Desktop output underrun.")
        }
        if shouldFailOnConsume {
            setFailure(.failed, message: "Desktop output consume failed.")
            throw AudioError.invalidRenderGraphPlan("Desktop output consume failed.")
        }

        lastBlock = try copy(block)
        consumedFramePosition += Int64(block.frameCount)
        lastSourceFrameIndex = sourceFrameIndex
        if state != .muted {
            state = validationOnly ? .validationOnly : .active
        }
    }

    public func latestStatusSnapshot() -> AudioOutputStatusSnapshot {
        AudioOutputStatusSnapshot(
            routeID: route.id,
            routeName: route.name,
            state: state,
            outputFormat: outputFormat,
            consumedFramePosition: consumedFramePosition,
            underrunCount: underrunCount,
            validationMessages: validationMessages,
            failureMessage: failureMessage,
            sourceFrameIndex: lastSourceFrameIndex
        )
    }

    public func latestDesktopStatus() -> DesktopOutputStatus {
        let snapshot = latestStatusSnapshot()
        return DesktopOutputStatus(
            snapshot: snapshot,
            desktopOutputFailed: [.routeUnavailable, .routeSampleRateMismatch, .insufficientChannels, .failed, .underrun].contains(snapshot.state),
            isMuted: snapshot.state == .muted
        )
    }

    public func lastConsumedBlockForTestingCopy() throws -> CanonicalAudioBlock? {
        guard let lastBlock else { return nil }
        return try copy(lastBlock)
    }

    private func setFailure(_ state: AudioOutputAdapterState, message: String) {
        self.state = state
        self.failureMessage = message
        self.validationMessages = [message]
    }
}

public final class OfflineDanteOutputAdapter: DanteOutputAdapter, @unchecked Sendable {
    public let capability: DanteRouteCapability
    public var route: OutputRouteDescriptor { capability.route }
    public private(set) var outputFormat: AudioOutputBlockFormat?

    private let validationOnly: Bool
    private let shouldFailOnConsume: Bool
    private var state: AudioOutputAdapterState = .inactive
    private var consumedFramePosition: Int64 = 0
    private var underrunCount = 0
    private var validationMessages: [String] = []
    private var failureMessage: String?
    private var lastSourceFrameIndex: Int64?
    private var lastBlock: CanonicalAudioBlock?
    private var physicalChannelCount = 0

    public init(
        capability: DanteRouteCapability,
        validationOnly: Bool = true,
        shouldFailOnConsume: Bool = false
    ) {
        self.capability = capability
        self.validationOnly = validationOnly
        self.shouldFailOnConsume = shouldFailOnConsume
    }

    public func prepare(sessionFormat: AudioSessionFormat) throws {
        let validationErrors = capability.validationErrors(for: sessionFormat.sampleRate)
        if let error = validationErrors.first {
            setState(for: error)
            throw error
        }
        guard capability.outputChannelCount >= sessionFormat.dante.physicalChannelCount else {
            setFailure(.insufficientChannels, message: "Dante route exposes fewer channels than the session requires.")
            throw AudioError.danteRouteInsufficientChannels(
                required: sessionFormat.dante.physicalChannelCount,
                actual: capability.outputChannelCount
            )
        }
        if let nominalSampleRate = capability.currentNominalSampleRate,
           !nominalSampleRate.matches(sessionFormat.sampleRate) {
            setFailure(.routeSampleRateMismatch, message: "Dante route sample rate does not match the session.")
            throw AudioError.sampleRateMismatch(
                expected: sessionFormat.sampleRate,
                actual: nominalSampleRate,
                context: "Dante output route"
            )
        }

        physicalChannelCount = sessionFormat.dante.physicalChannelCount
        outputFormat = AudioOutputBlockFormat(
            sampleRate: sessionFormat.sampleRate,
            channelCount: physicalChannelCount,
            layout: physicalChannelCount == 32 ? .discrete(count: 32) : .direct31
        )
        state = validationOnly ? .validationOnly : .prepared
        failureMessage = nil
        validationMessages = validationOnly
            ? ["Dante renderer validated, live Dante output adapter not yet active."]
            : ["Dante output route prepared."]
    }

    public func start() throws {
        guard outputFormat != nil else {
            throw AudioError.routeUnavailable(route.id)
        }
        state = validationOnly ? .validationOnly : .active
    }

    public func stop() {
        state = .inactive
    }

    public func consume(_ block: CanonicalAudioBlock, sourceFrameIndex: Int64) throws {
        guard let outputFormat else {
            throw AudioError.routeUnavailable(route.id)
        }
        guard block.channelCount == outputFormat.channelCount else {
            setFailure(.insufficientChannels, message: "Dante block does not match physical output channel count.")
            throw AudioError.danteRouteInsufficientChannels(
                required: outputFormat.channelCount,
                actual: block.channelCount
            )
        }
        guard block.sampleRate.matches(outputFormat.sampleRate) else {
            setFailure(.routeSampleRateMismatch, message: "Dante block sample rate does not match output.")
            throw AudioError.sampleRateMismatch(
                expected: outputFormat.sampleRate,
                actual: block.sampleRate,
                context: "Dante output block"
            )
        }
        guard block.frameCount > 0 else {
            underrunCount += 1
            state = .underrun
            throw AudioError.invalidRenderGraphPlan("Dante output underrun.")
        }
        if outputFormat.channelCount == 32 {
            for frame in 0..<block.frameCount where abs(block.sample(channel: 31, frame: frame)) > 0.000_001 {
                setFailure(.failed, message: "Dante physical channel 32 must remain silent.")
                throw AudioError.invalidRenderGraphPlan("Dante physical channel 32 must remain silent.")
            }
        }
        if shouldFailOnConsume {
            setFailure(.failed, message: "Dante output consume failed.")
            throw AudioError.invalidRenderGraphPlan("Dante output consume failed.")
        }

        lastBlock = try copy(block)
        consumedFramePosition += Int64(block.frameCount)
        lastSourceFrameIndex = sourceFrameIndex
        state = validationOnly ? .validationOnly : .active
    }

    public func latestStatusSnapshot() -> AudioOutputStatusSnapshot {
        AudioOutputStatusSnapshot(
            routeID: route.id,
            routeName: route.name,
            state: state,
            outputFormat: outputFormat,
            consumedFramePosition: consumedFramePosition,
            underrunCount: underrunCount,
            validationMessages: validationMessages,
            failureMessage: failureMessage,
            sourceFrameIndex: lastSourceFrameIndex
        )
    }

    public func latestDanteStatus() -> DanteOutputStatus {
        let snapshot = latestStatusSnapshot()
        return DanteOutputStatus(
            snapshot: snapshot,
            productionOutputFailed: [.routeUnavailable, .routeSampleRateMismatch, .insufficientChannels, .failed, .underrun].contains(snapshot.state),
            logicalChannelCount: 31,
            physicalChannelCount: physicalChannelCount,
            isChannel32Reserved: physicalChannelCount == 32
        )
    }

    public func lastConsumedBlockForTestingCopy() throws -> CanonicalAudioBlock? {
        guard let lastBlock else { return nil }
        return try copy(lastBlock)
    }

    private func setState(for error: AudioError) {
        switch error {
        case .routeUnavailable:
            setFailure(.routeUnavailable, message: error.description)
        case .sampleRateMismatch:
            setFailure(.routeSampleRateMismatch, message: error.description)
        case .danteRouteInsufficientChannels:
            setFailure(.insufficientChannels, message: error.description)
        default:
            setFailure(.failed, message: error.description)
        }
    }

    private func setFailure(_ state: AudioOutputAdapterState, message: String) {
        self.state = state
        self.failureMessage = message
        self.validationMessages = [message]
    }
}

public final class DualOutputRenderCoordinator: @unchecked Sendable {
    public let plan: RenderGraphPlan
    public let sourceAdapter: any AudioSourceAdapter
    public let desktopAdapter: any DesktopOutputAdapter
    public let danteAdapter: any DanteOutputAdapter

    private let frameCapacity: Int
    private let validator: PlanValidator
    private let meteringService: PureAudioMeteringService?
    private var sourceBus: CanonicalSourceBus?
    private var sourceBlock: CanonicalAudioBlock?
    private var desktopBlock: CanonicalAudioBlock?
    private var danteBlock: CanonicalAudioBlock?
    private var desktopMeterBlock: CanonicalAudioBlock?
    private var danteMeterBlock: CanonicalAudioBlock?
    private var isPrepared = false
    private var isRunning = false
    private var latestStatusValue: DualOutputStatus?

    public init(
        plan: RenderGraphPlan,
        sourceAdapter: any AudioSourceAdapter,
        desktopAdapter: any DesktopOutputAdapter,
        danteAdapter: any DanteOutputAdapter,
        frameCapacity: Int,
        validator: PlanValidator = PlanValidator(),
        meteringService: PureAudioMeteringService? = nil
    ) {
        self.plan = plan
        self.sourceAdapter = sourceAdapter
        self.desktopAdapter = desktopAdapter
        self.danteAdapter = danteAdapter
        self.frameCapacity = frameCapacity
        self.validator = validator
        self.meteringService = meteringService
    }

    public func prepare() throws {
        try validator.validateOrThrow(plan)
        guard sourceAdapter.descriptor == plan.source else {
            throw AudioError.invalidRenderGraphPlan("Source adapter descriptor must match the render plan source.")
        }
        guard frameCapacity > 0, frameCapacity <= plan.sessionFormat.maxFramesPerBlock else {
            throw AudioError.invalidRenderGraphPlan("Coordinator frame capacity must be positive and within the session block limit.")
        }

        try sourceAdapter.prepare(sessionFormat: plan.sessionFormat)
        let bus = try CanonicalSourceBus(
            sessionFormat: plan.sessionFormat,
            source: plan.source,
            frameCapacity: frameCapacity
        )
        let source = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: plan.sessionFormat.sampleRate,
                channelCount: plan.source.channelCount,
                frameCount: frameCapacity,
                layout: plan.source.layout
            )
        )
        let desktop = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: plan.sessionFormat.sampleRate,
                channelCount: 2,
                frameCount: frameCapacity,
                layout: .stereo
            )
        )
        let dante = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: plan.sessionFormat.sampleRate,
                channelCount: plan.danteRenderer.physicalOutputCount,
                frameCount: frameCapacity,
                layout: plan.danteRenderer.physicalOutputCount == 32 ? .discrete(count: 32) : .direct31
            )
        )
        let desktopMeter = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: plan.sessionFormat.sampleRate,
                channelCount: 2,
                frameCount: frameCapacity,
                layout: .stereo
            )
        )
        let danteMeter = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: plan.sessionFormat.sampleRate,
                channelCount: plan.danteRenderer.physicalOutputCount,
                frameCount: frameCapacity,
                layout: plan.danteRenderer.physicalOutputCount == 32 ? .discrete(count: 32) : .direct31
            )
        )

        do {
            try desktopAdapter.prepare(sessionFormat: plan.sessionFormat)
        } catch {
            // Desktop is a confidence output. Keep the failure in its status, but do not block Dante preparation.
        }
        try danteAdapter.prepare(sessionFormat: plan.sessionFormat)

        sourceBus = bus
        sourceBlock = source
        desktopBlock = desktop
        danteBlock = dante
        desktopMeterBlock = desktopMeter
        danteMeterBlock = danteMeter
        isPrepared = true
        latestStatusValue = makeStatus(sourceFrameIndex: 0)
    }

    public func start() throws {
        guard isPrepared else {
            throw AudioError.invalidRenderGraphPlan("Coordinator must be prepared before start.")
        }
        try sourceAdapter.start()
        do {
            try desktopAdapter.start()
        } catch {
            // Desktop start failure is isolated from Dante.
        }
        try danteAdapter.start()
        isRunning = true
    }

    public func stop() {
        sourceAdapter.stop()
        desktopAdapter.stop()
        danteAdapter.stop()
        isRunning = false
        latestStatusValue = makeStatus(sourceFrameIndex: sourceBus?.frameIndex ?? 0)
    }

    @discardableResult
    public func render(frameCount: Int) throws -> DualOutputStatus {
        guard isRunning else {
            throw AudioError.invalidRenderGraphPlan("Coordinator must be running before render.")
        }
        guard frameCount > 0, frameCount <= frameCapacity else {
            throw AudioError.invalidRenderGraphPlan("Render frame count must be positive and within capacity.")
        }
        guard let sourceBus,
              let sourceBlock,
              let desktopBlock,
              let danteBlock,
              let desktopMeterBlock,
              let danteMeterBlock
        else {
            throw AudioError.invalidRenderGraphPlan("Coordinator is missing prepared blocks.")
        }

        try sourceAdapter.renderIntoCanonicalBus(sourceBus, frameCount: frameCount)
        try sourceBus.copyCurrentBlock(into: sourceBlock)
        let sourceFrameIndex = sourceBus.frameIndex

        meteringService?.copyBus.submit(
            copyPoint: .inputSourceBus,
            block: sourceBlock,
            sessionVersion: plan.version,
            sourceID: plan.source.id,
            framePosition: sourceFrameIndex
        )

        try renderMeterBlocks(
            sourceBlock: sourceBlock,
            desktopMeterBlock: desktopMeterBlock,
            danteMeterBlock: danteMeterBlock,
            frameCount: frameCount
        )

        meteringService?.copyBus.submit(
            copyPoint: .desktopPostRenderPreOutputGain,
            block: desktopMeterBlock,
            sessionVersion: plan.version,
            sourceID: plan.source.id,
            framePosition: sourceFrameIndex
        )
        meteringService?.copyBus.submit(
            copyPoint: .dantePostRenderPreOutputGain,
            block: danteMeterBlock,
            sessionVersion: plan.version,
            sourceID: plan.source.id,
            framePosition: sourceFrameIndex
        )

        try DesktopMonitorRenderer(plan: plan.desktopDownmix, gainPlan: plan.gainPlan)
            .process(source: sourceBlock, destination: desktopBlock, frameCount: frameCount)
        try DanteSonicSphereRenderer(plan: plan.danteRenderer, gainPlan: plan.gainPlan)
            .process(source: sourceBlock, destination: danteBlock, frameCount: frameCount)

        do {
            try desktopAdapter.consume(desktopBlock, sourceFrameIndex: sourceFrameIndex)
        } catch {
            // Desktop consume failure must not perturb Dante.
        }

        do {
            try danteAdapter.consume(danteBlock, sourceFrameIndex: sourceFrameIndex)
        } catch {
            latestStatusValue = makeStatus(sourceFrameIndex: sourceFrameIndex)
            throw error
        }

        let status = makeStatus(sourceFrameIndex: sourceFrameIndex)
        latestStatusValue = status
        meteringService?.publishLatestSnapshot(meterCalibrationGain: plan.gainPlan.meterCalibrationGain)
        return status
    }

    public func latestStatusSnapshot() -> DualOutputStatus {
        latestStatusValue ?? makeStatus(sourceFrameIndex: sourceBus?.frameIndex ?? 0)
    }

    private func makeStatus(sourceFrameIndex: Int64) -> DualOutputStatus {
        DualOutputStatus(
            desktop: desktopAdapter.latestDesktopStatus(),
            dante: danteAdapter.latestDanteStatus(),
            sourceFrameIndex: sourceFrameIndex,
            renderPlanVersion: plan.version,
            validationMessages: plan.validationMessages
        )
    }

    private func renderMeterBlocks(
        sourceBlock: CanonicalAudioBlock,
        desktopMeterBlock: CanonicalAudioBlock,
        danteMeterBlock: CanonicalAudioBlock,
        frameCount: Int
    ) throws {
        let preOutputGainPlan = GainPlan(
            sourceTrim: plan.gainPlan.sourceTrim,
            desktopMonitorGain: .unity,
            danteOutputGain: .unity,
            meterCalibrationGain: plan.gainPlan.meterCalibrationGain,
            testToneCalibrationGain: plan.gainPlan.testToneCalibrationGain
        )
        try DesktopMonitorRenderer(plan: plan.desktopDownmix, gainPlan: preOutputGainPlan)
            .process(source: sourceBlock, destination: desktopMeterBlock, frameCount: frameCount)
        try DanteSonicSphereRenderer(plan: plan.danteRenderer, gainPlan: preOutputGainPlan)
            .process(source: sourceBlock, destination: danteMeterBlock, frameCount: frameCount)
    }
}

private func copy(_ block: CanonicalAudioBlock) throws -> CanonicalAudioBlock {
    let copied = try CanonicalAudioBlock(
        format: AudioBlockFormat(
            sampleRate: block.sampleRate,
            channelCount: block.channelCount,
            frameCount: block.frameCapacity,
            layout: block.layout
        )
    )
    try copied.copyFrom(block)
    return copied
}
