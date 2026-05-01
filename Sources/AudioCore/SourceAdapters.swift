import AudioContracts
import AudioImport
import Foundation

public enum PureAudioLoopbackUID {
    public static let roon = "audio.orbisonic.rooninput.device"
    public static let spotify = "audio.orbisonic.spotifyinput.device"
    public static let aux = "audio.orbisonic.auxcable.device"
}

public struct LiveInputRouteDescriptor: Equatable, Hashable, Sendable {
    public let id: String
    public let uid: String?
    public let name: String
    public let manufacturer: String?
    public let transportName: String?
    public let inputChannelCount: Int
    public let nominalSampleRate: AudioSampleRate?
    public let isAvailable: Bool

    public init(
        id: String,
        uid: String? = nil,
        name: String,
        manufacturer: String? = nil,
        transportName: String? = nil,
        inputChannelCount: Int,
        nominalSampleRate: AudioSampleRate?,
        isAvailable: Bool = true
    ) {
        self.id = id
        self.uid = uid
        self.name = name
        self.manufacturer = manufacturer
        self.transportName = transportName
        self.inputChannelCount = inputChannelCount
        self.nominalSampleRate = nominalSampleRate
        self.isAvailable = isAvailable
    }
}

public struct LiveCaptureFormatDescriptor: Equatable, Hashable, Sendable {
    public let sampleRate: AudioSampleRate
    public let channelCount: Int
    public let processingFormat: ProcessingFormat
    public let layout: AudioChannelLayoutDescriptor

    public init(
        sampleRate: AudioSampleRate,
        channelCount: Int,
        processingFormat: ProcessingFormat = .float32NonInterleavedPCM,
        layout: AudioChannelLayoutDescriptor
    ) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.processingFormat = processingFormat
        self.layout = layout
    }
}

public struct AudioSourceAdapterStatusSnapshot: Equatable, Hashable, Sendable {
    public let sourceID: String
    public let kind: SourceKind
    public let isPrepared: Bool
    public let isRunning: Bool
    public let framePosition: Int64
    public let validationMessages: [String]
    public let diagnosticMessages: [String]

    public init(
        sourceID: String,
        kind: SourceKind,
        isPrepared: Bool,
        isRunning: Bool,
        framePosition: Int64,
        validationMessages: [String] = [],
        diagnosticMessages: [String] = []
    ) {
        self.sourceID = sourceID
        self.kind = kind
        self.isPrepared = isPrepared
        self.isRunning = isRunning
        self.framePosition = framePosition
        self.validationMessages = validationMessages
        self.diagnosticMessages = diagnosticMessages
    }
}

public protocol AudioSourceAdapter: AnyObject, Sendable {
    var descriptor: SourceDescriptor { get }

    func prepare(sessionFormat: AudioSessionFormat) throws
    func start() throws
    func stop()
    func renderIntoCanonicalBus(_ bus: CanonicalSourceBus, frameCount: Int) throws
    func latestStatusSnapshot() -> AudioSourceAdapterStatusSnapshot
}

public enum LiveSourceChannelPolicy: Equatable, Hashable, Sendable {
    case fixed(Int)
    case routeChannelCount
}

public class LiveLoopbackSourceAdapter: AudioSourceAdapter, @unchecked Sendable {
    public let descriptor: SourceDescriptor
    public let route: LiveInputRouteDescriptor
    public let captureFormat: LiveCaptureFormatDescriptor
    public let expectedUID: String?

    private var isPrepared = false
    private var isRunning = false
    private var preparedSessionFormat: AudioSessionFormat?
    private var framePosition: Int64 = 0
    private var validationMessages: [String]
    private var diagnosticMessages: [String]
    private var queuedBlocks: [CanonicalAudioBlock]

    public init(
        kind: SourceKind,
        sourceID: String,
        route: LiveInputRouteDescriptor,
        expectedUID: String? = nil,
        channelPolicy: LiveSourceChannelPolicy,
        layout: AudioChannelLayoutDescriptor? = nil,
        diagnosticSampleRate: AudioSampleRate? = nil,
        queuedBlocks: [CanonicalAudioBlock] = []
    ) throws {
        guard kind == .roon || kind == .spotify || kind == .aux else {
            throw AudioError.invalidRenderGraphPlan("Live source adapters only support Roon, Spotify, and Aux sources.")
        }
        guard let nominalSampleRate = route.nominalSampleRate else {
            throw AudioError.invalidRenderGraphPlan("Live source route sample rate is unknown.")
        }

        let channelCount: Int
        switch channelPolicy {
        case .fixed(let fixedCount):
            channelCount = fixedCount
        case .routeChannelCount:
            channelCount = route.inputChannelCount
        }

        let resolvedLayout = layout ?? AudioChannelLayoutDescriptor.fallbackLayout(channelCount: channelCount)
        self.route = route
        self.expectedUID = expectedUID
        self.captureFormat = LiveCaptureFormatDescriptor(
            sampleRate: nominalSampleRate,
            channelCount: channelCount,
            layout: resolvedLayout
        )
        self.descriptor = SourceDescriptor(
            id: sourceID,
            kind: kind,
            sampleRate: nominalSampleRate,
            channelCount: channelCount,
            layout: resolvedLayout,
            isLive: true,
            codecDescription: "Float32 non-interleaved PCM live capture"
        )
        self.validationMessages = []
        self.diagnosticMessages = Self.diagnosticMessages(
            sourceKind: kind,
            routeSampleRate: nominalSampleRate,
            diagnosticSampleRate: diagnosticSampleRate
        )
        self.queuedBlocks = queuedBlocks
    }

    public func prepare(sessionFormat: AudioSessionFormat) throws {
        try sessionFormat.validate()
        guard route.isAvailable else {
            throw AudioError.routeUnavailable(route.id)
        }
        if let expectedUID, !Self.route(route, matchesExpectedUID: expectedUID) {
            throw AudioError.routeUnavailable(expectedUID)
        }
        guard captureFormat.processingFormat.isProductionInternalFormat else {
            throw AudioError.productionSampleRateConversionForbidden
        }
        guard SourceDescriptor.sourceChannelLimit.contains(captureFormat.channelCount) else {
            throw AudioError.sourceChannelCountOutOfRange(count: captureFormat.channelCount, minimum: 1, maximum: 64)
        }
        guard captureFormat.channelCount <= sessionFormat.sourceChannelLimit else {
            throw AudioError.sourceChannelCountOutOfRange(
                count: captureFormat.channelCount,
                minimum: 1,
                maximum: sessionFormat.sourceChannelLimit
            )
        }
        guard route.inputChannelCount >= captureFormat.channelCount else {
            throw AudioError.sourceChannelCountOutOfRange(
                count: route.inputChannelCount,
                minimum: captureFormat.channelCount,
                maximum: 64
            )
        }
        try descriptor.validate(sessionFormat: sessionFormat)
        if let layoutError = captureFormat.layout.validationErrors(expectedChannelCount: captureFormat.channelCount).first {
            throw layoutError
        }

        preparedSessionFormat = sessionFormat
        isPrepared = true
        validationMessages = ["Live source route matches the session sample rate and channel contract."]
    }

    public func start() throws {
        guard isPrepared else {
            throw AudioError.invalidRenderGraphPlan("Live source must be prepared before start.")
        }
        isRunning = true
    }

    public func stop() {
        isRunning = false
    }

    public func enqueueBlock(_ block: CanonicalAudioBlock) throws {
        guard block.sampleRate.matches(captureFormat.sampleRate) else {
            throw AudioError.sampleRateMismatch(
                expected: captureFormat.sampleRate,
                actual: block.sampleRate,
                context: "live source block"
            )
        }
        guard block.channelCount == captureFormat.channelCount else {
            throw AudioError.layoutChannelCountMismatch(expected: captureFormat.channelCount, actual: block.channelCount)
        }
        queuedBlocks.append(block)
    }

    public func renderIntoCanonicalBus(_ bus: CanonicalSourceBus, frameCount: Int) throws {
        guard isRunning else {
            throw AudioError.invalidRenderGraphPlan("Live source must be running before rendering.")
        }
        guard bus.source == descriptor else {
            throw AudioError.invalidRenderGraphPlan("Canonical source bus descriptor does not match adapter descriptor.")
        }
        guard let preparedSessionFormat else {
            throw AudioError.invalidRenderGraphPlan("Live source has not been prepared.")
        }
        guard bus.sessionFormat == preparedSessionFormat else {
            throw AudioError.invalidRenderGraphPlan("Canonical source bus session does not match prepared session.")
        }

        let block = try nextBlock(frameCount: frameCount)
        try bus.injectFixtureBlock(block)
        framePosition += Int64(block.frameCount)
    }

    public func latestStatusSnapshot() -> AudioSourceAdapterStatusSnapshot {
        AudioSourceAdapterStatusSnapshot(
            sourceID: descriptor.id,
            kind: descriptor.kind,
            isPrepared: isPrepared,
            isRunning: isRunning,
            framePosition: framePosition,
            validationMessages: validationMessages,
            diagnosticMessages: diagnosticMessages
        )
    }

    private func nextBlock(frameCount: Int) throws -> CanonicalAudioBlock {
        guard frameCount >= 0 else {
            throw AudioError.invalidRenderGraphPlan("Source render frame count must not be negative.")
        }

        if !queuedBlocks.isEmpty {
            let block = queuedBlocks.removeFirst()
            guard block.frameCount >= frameCount else {
                return block
            }
            return block
        }

        let block = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: captureFormat.sampleRate,
                channelCount: captureFormat.channelCount,
                frameCount: max(frameCount, 1),
                layout: captureFormat.layout
            )
        )
        try block.setFrameCount(frameCount)
        return block
    }

    private static func route(_ route: LiveInputRouteDescriptor, matchesExpectedUID expectedUID: String) -> Bool {
        if route.uid == expectedUID {
            return true
        }
        let text = [route.name, route.manufacturer ?? "", route.transportName ?? ""]
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        switch expectedUID {
        case PureAudioLoopbackUID.roon:
            return text.contains("orbisonic roon input")
        case PureAudioLoopbackUID.spotify:
            return text.contains("orbisonic spotify input")
        case PureAudioLoopbackUID.aux:
            return text.contains("orbisonic aux cable")
        default:
            return false
        }
    }

    private static func diagnosticMessages(
        sourceKind: SourceKind,
        routeSampleRate: AudioSampleRate,
        diagnosticSampleRate: AudioSampleRate?
    ) -> [String] {
        guard sourceKind == .roon,
              let diagnosticSampleRate,
              !diagnosticSampleRate.matches(routeSampleRate)
        else { return [] }
        return [
            "Roon metadata sample rate \(diagnosticSampleRate.hertz) Hz differs from live capture route \(routeSampleRate.hertz) Hz; live capture controls production admission."
        ]
    }
}

public final class RoonSourceAdapter: LiveLoopbackSourceAdapter, @unchecked Sendable {
    public init(
        route: LiveInputRouteDescriptor,
        metadataSampleRate: AudioSampleRate? = nil,
        queuedBlocks: [CanonicalAudioBlock] = []
    ) throws {
        try super.init(
            kind: .roon,
            sourceID: "roon-live",
            route: route,
            expectedUID: PureAudioLoopbackUID.roon,
            channelPolicy: .routeChannelCount,
            diagnosticSampleRate: metadataSampleRate,
            queuedBlocks: queuedBlocks
        )
    }
}

public final class SpotifySourceAdapter: LiveLoopbackSourceAdapter, @unchecked Sendable {
    public init(
        route: LiveInputRouteDescriptor,
        queuedBlocks: [CanonicalAudioBlock] = []
    ) throws {
        try super.init(
            kind: .spotify,
            sourceID: "spotify-live",
            route: route,
            expectedUID: PureAudioLoopbackUID.spotify,
            channelPolicy: .fixed(2),
            layout: .stereo,
            queuedBlocks: queuedBlocks
        )
    }
}

public final class AuxSourceAdapter: LiveLoopbackSourceAdapter, @unchecked Sendable {
    public init(
        route: LiveInputRouteDescriptor,
        queuedBlocks: [CanonicalAudioBlock] = []
    ) throws {
        try super.init(
            kind: .aux,
            sourceID: "aux-live",
            route: route,
            expectedUID: PureAudioLoopbackUID.aux,
            channelPolicy: .routeChannelCount,
            queuedBlocks: queuedBlocks
        )
    }
}

public final class ManagedLocalAssetSourceAdapter: AudioSourceAdapter, @unchecked Sendable {
    public let descriptor: SourceDescriptor
    public let asset: ManagedAssetDescriptor

    private var isPrepared = false
    private var isRunning = false
    private var framePosition: Int64 = 0
    private var queuedBlocks: [CanonicalAudioBlock]

    public init(asset: ManagedAssetDescriptor, queuedBlocks: [CanonicalAudioBlock] = []) {
        self.asset = asset
        self.descriptor = SourceDescriptor(
            id: asset.id,
            kind: .localFile,
            sampleRate: asset.managedSampleRate,
            channelCount: asset.channelCount,
            layout: asset.layout,
            durationFrames: asset.durationFrames,
            isLive: false,
            codecDescription: asset.codecDescription,
            originalPath: asset.managedPath
        )
        self.queuedBlocks = queuedBlocks
    }

    public func prepare(sessionFormat: AudioSessionFormat) throws {
        try sessionFormat.validate()
        guard asset.managedSampleRate.matches(sessionFormat.sampleRate) else {
            throw AudioError.localAssetRequiresManagedImport(sourceID: asset.id)
        }
        try descriptor.validate(sessionFormat: sessionFormat)
        isPrepared = true
    }

    public func start() throws {
        guard isPrepared else {
            throw AudioError.invalidRenderGraphPlan("Managed local asset source must be prepared before start.")
        }
        isRunning = true
    }

    public func stop() {
        isRunning = false
    }

    public func enqueueBlock(_ block: CanonicalAudioBlock) throws {
        guard block.sampleRate.matches(asset.managedSampleRate) else {
            throw AudioError.productionSampleRateConversionForbidden
        }
        guard block.channelCount == asset.channelCount else {
            throw AudioError.layoutChannelCountMismatch(expected: asset.channelCount, actual: block.channelCount)
        }
        queuedBlocks.append(block)
    }

    public func renderIntoCanonicalBus(_ bus: CanonicalSourceBus, frameCount: Int) throws {
        guard isRunning else {
            throw AudioError.invalidRenderGraphPlan("Managed local asset source must be running before rendering.")
        }
        guard bus.source == descriptor else {
            throw AudioError.invalidRenderGraphPlan("Canonical source bus descriptor does not match adapter descriptor.")
        }

        let block = try nextBlock(frameCount: frameCount)
        try bus.injectFixtureBlock(block)
        framePosition += Int64(block.frameCount)
    }

    public func latestStatusSnapshot() -> AudioSourceAdapterStatusSnapshot {
        AudioSourceAdapterStatusSnapshot(
            sourceID: descriptor.id,
            kind: descriptor.kind,
            isPrepared: isPrepared,
            isRunning: isRunning,
            framePosition: framePosition,
            validationMessages: ["Managed local asset source uses session-rate Float32 PCM blocks."]
        )
    }

    private func nextBlock(frameCount: Int) throws -> CanonicalAudioBlock {
        if !queuedBlocks.isEmpty {
            return queuedBlocks.removeFirst()
        }

        let block = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: asset.managedSampleRate,
                channelCount: asset.channelCount,
                frameCount: max(frameCount, 1),
                layout: asset.layout
            )
        )
        try block.setFrameCount(frameCount)
        return block
    }
}

public enum TestToneSourceMode: Equatable, Hashable, Sendable {
    case desktopStereoID
    case danteChannelID(channelIndex: Int)

    public var sourceChannelCount: Int {
        switch self {
        case .desktopStereoID:
            2
        case .danteChannelID:
            31
        }
    }

    public var layout: AudioChannelLayoutDescriptor {
        switch self {
        case .desktopStereoID:
            .stereo
        case .danteChannelID:
            .direct31
        }
    }
}

public final class TestToneSourceAdapter: AudioSourceAdapter, @unchecked Sendable {
    public let descriptor: SourceDescriptor
    public let mode: TestToneSourceMode

    private var isPrepared = false
    private var isRunning = false
    private var framePosition: Int64 = 0
    private var phase = 0.0

    public init(
        id: String = "test-tone",
        sessionSampleRate: AudioSampleRate,
        mode: TestToneSourceMode = .desktopStereoID
    ) {
        self.mode = mode
        self.descriptor = SourceDescriptor(
            id: id,
            kind: .testTone,
            sampleRate: sessionSampleRate,
            channelCount: mode.sourceChannelCount,
            layout: mode.layout,
            isLive: false,
            codecDescription: "Generated test tone at session sample rate"
        )
    }

    public func prepare(sessionFormat: AudioSessionFormat) throws {
        try sessionFormat.validate()
        try descriptor.validate(sessionFormat: sessionFormat)
        switch mode {
        case .desktopStereoID:
            break
        case .danteChannelID(let channelIndex):
            guard channelIndex >= 0, channelIndex < 31 else {
                throw AudioError.sourceChannelCountOutOfRange(count: channelIndex + 1, minimum: 1, maximum: 31)
            }
        }
        isPrepared = true
    }

    public func start() throws {
        guard isPrepared else {
            throw AudioError.invalidRenderGraphPlan("Test tone source must be prepared before start.")
        }
        isRunning = true
    }

    public func stop() {
        isRunning = false
    }

    public func renderIntoCanonicalBus(_ bus: CanonicalSourceBus, frameCount: Int) throws {
        guard isRunning else {
            throw AudioError.invalidRenderGraphPlan("Test tone source must be running before rendering.")
        }
        guard bus.source == descriptor else {
            throw AudioError.invalidRenderGraphPlan("Canonical source bus descriptor does not match adapter descriptor.")
        }

        let block = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: descriptor.sampleRate,
                channelCount: descriptor.channelCount,
                frameCount: max(frameCount, 1),
                layout: descriptor.layout
            )
        )
        try fill(block: block, frameCount: frameCount)
        try bus.injectFixtureBlock(block)
        framePosition += Int64(frameCount)
    }

    public func latestStatusSnapshot() -> AudioSourceAdapterStatusSnapshot {
        AudioSourceAdapterStatusSnapshot(
            sourceID: descriptor.id,
            kind: descriptor.kind,
            isPrepared: isPrepared,
            isRunning: isRunning,
            framePosition: framePosition,
            validationMessages: ["Test tone is generated directly at the session sample rate."]
        )
    }

    private func fill(block: CanonicalAudioBlock, frameCount: Int) throws {
        try block.setFrameCount(frameCount)
        guard frameCount > 0 else { return }

        let phaseIncrement = (2.0 * Double.pi * 440.0) / descriptor.sampleRate.hertz
        for frame in 0..<frameCount {
            let value = Float(sin(phase) * 0.25)
            phase += phaseIncrement
            if phase >= 2.0 * Double.pi {
                phase -= 2.0 * Double.pi
            }

            switch mode {
            case .desktopStereoID:
                try block.setSample(value, channel: 0, frame: frame)
                try block.setSample(-value, channel: 1, frame: frame)
            case .danteChannelID(let channelIndex):
                try block.setSample(value, channel: channelIndex, frame: frame)
            }
        }
    }
}

public final class OffSourceAdapter: AudioSourceAdapter, @unchecked Sendable {
    public let descriptor: SourceDescriptor

    private var isPrepared = false
    private var isRunning = false

    public init(sessionSampleRate: AudioSampleRate) {
        self.descriptor = SourceDescriptor(
            id: "off",
            kind: .off,
            sampleRate: sessionSampleRate,
            channelCount: 1,
            layout: .mono,
            isLive: false,
            codecDescription: "Silent source"
        )
    }

    public func prepare(sessionFormat: AudioSessionFormat) throws {
        try descriptor.validate(sessionFormat: sessionFormat)
        isPrepared = true
    }

    public func start() throws {
        guard isPrepared else {
            throw AudioError.invalidRenderGraphPlan("Off source must be prepared before start.")
        }
        isRunning = true
    }

    public func stop() {
        isRunning = false
    }

    public func renderIntoCanonicalBus(_ bus: CanonicalSourceBus, frameCount: Int) throws {
        guard bus.source == descriptor else {
            throw AudioError.invalidRenderGraphPlan("Canonical source bus descriptor does not match adapter descriptor.")
        }
        let block = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: descriptor.sampleRate,
                channelCount: 1,
                frameCount: max(frameCount, 1),
                layout: .mono
            )
        )
        try block.setFrameCount(frameCount)
        try bus.injectFixtureBlock(block)
    }

    public func latestStatusSnapshot() -> AudioSourceAdapterStatusSnapshot {
        AudioSourceAdapterStatusSnapshot(
            sourceID: descriptor.id,
            kind: descriptor.kind,
            isPrepared: isPrepared,
            isRunning: isRunning,
            framePosition: 0,
            validationMessages: ["Off source emits silence."]
        )
    }
}

public struct SourceAdapterFactoryRequest: Sendable {
    public let selection: SourceSelection
    public let sessionFormat: AudioSessionFormat
    public let liveRoutes: [LiveInputRouteDescriptor]
    public let managedAsset: ManagedAssetDescriptor?
    public let localAssetProbe: LocalAssetProbeResult?
    public let testToneMode: TestToneSourceMode
    public let frameCapacity: Int

    public init(
        selection: SourceSelection,
        sessionFormat: AudioSessionFormat,
        liveRoutes: [LiveInputRouteDescriptor] = [],
        managedAsset: ManagedAssetDescriptor? = nil,
        localAssetProbe: LocalAssetProbeResult? = nil,
        testToneMode: TestToneSourceMode = .desktopStereoID,
        frameCapacity: Int = 512
    ) {
        self.selection = selection
        self.sessionFormat = sessionFormat
        self.liveRoutes = liveRoutes
        self.managedAsset = managedAsset
        self.localAssetProbe = localAssetProbe
        self.testToneMode = testToneMode
        self.frameCapacity = frameCapacity
    }
}

public struct SourceAdapterFactory: Sendable {
    public init() {}

    public func makeAdapter(_ request: SourceAdapterFactoryRequest) throws -> any AudioSourceAdapter {
        try request.sessionFormat.validate()

        switch request.selection.kind {
        case .off:
            let adapter = OffSourceAdapter(sessionSampleRate: request.sessionFormat.sampleRate)
            try adapter.prepare(sessionFormat: request.sessionFormat)
            return adapter
        case .roon:
            let adapter = try RoonSourceAdapter(route: liveRoute(expectedUID: PureAudioLoopbackUID.roon, in: request.liveRoutes))
            try adapter.prepare(sessionFormat: request.sessionFormat)
            return adapter
        case .spotify:
            let adapter = try SpotifySourceAdapter(route: liveRoute(expectedUID: PureAudioLoopbackUID.spotify, in: request.liveRoutes))
            try adapter.prepare(sessionFormat: request.sessionFormat)
            return adapter
        case .aux:
            let adapter = try AuxSourceAdapter(route: liveRoute(expectedUID: PureAudioLoopbackUID.aux, in: request.liveRoutes))
            try adapter.prepare(sessionFormat: request.sessionFormat)
            return adapter
        case .localFile:
            return try makeLocalAssetAdapter(request)
        case .testTone:
            let adapter = TestToneSourceAdapter(
                sessionSampleRate: request.sessionFormat.sampleRate,
                mode: request.testToneMode
            )
            try adapter.prepare(sessionFormat: request.sessionFormat)
            return adapter
        }
    }

    private func makeLocalAssetAdapter(_ request: SourceAdapterFactoryRequest) throws -> any AudioSourceAdapter {
        if let probe = request.localAssetProbe,
           !probe.sourceSampleRate.matches(request.sessionFormat.sampleRate) {
            throw AudioError.localAssetRequiresManagedImport(sourceID: probe.path)
        }

        guard let managedAsset = request.managedAsset else {
            let sourceID = request.selection.descriptor?.id ?? request.localAssetProbe?.path ?? "local-file"
            throw AudioError.localAssetRequiresManagedImport(sourceID: sourceID)
        }

        guard managedAsset.managedSampleRate.matches(request.sessionFormat.sampleRate) else {
            throw AudioError.localAssetRequiresManagedImport(sourceID: managedAsset.id)
        }

        let adapter = ManagedLocalAssetSourceAdapter(asset: managedAsset)
        try adapter.prepare(sessionFormat: request.sessionFormat)
        return adapter
    }

    private func liveRoute(expectedUID: String, in routes: [LiveInputRouteDescriptor]) throws -> LiveInputRouteDescriptor {
        if let route = routes.first(where: { $0.uid == expectedUID }) {
            return route
        }

        let expectedName: String
        switch expectedUID {
        case PureAudioLoopbackUID.roon:
            expectedName = "orbisonic roon input"
        case PureAudioLoopbackUID.spotify:
            expectedName = "orbisonic spotify input"
        case PureAudioLoopbackUID.aux:
            expectedName = "orbisonic aux cable"
        default:
            expectedName = expectedUID
        }

        if let route = routes.first(where: { route in
            route.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(expectedName)
        }) {
            return route
        }

        throw AudioError.routeUnavailable(expectedUID)
    }
}
