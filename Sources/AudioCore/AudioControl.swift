import AudioContracts
import AudioImport
import Foundation

public enum SourceSelection: Equatable, Hashable, Sendable {
    case off
    case source(SourceDescriptor)

    public var descriptor: SourceDescriptor? {
        switch self {
        case .off:
            nil
        case .source(let descriptor):
            descriptor
        }
    }

    public var kind: SourceKind {
        descriptor?.kind ?? .off
    }

    public func validate(sessionFormat: AudioSessionFormat) throws {
        try descriptor?.validate(sessionFormat: sessionFormat)
    }
}

public struct LinearGain: Equatable, Hashable, Sendable, Comparable {
    public static let maximum = 2.0
    public static let silence = try! LinearGain(0)
    public static let unity = try! LinearGain(1)

    public let value: Double

    public init(_ value: Double) throws {
        guard value.isFinite else {
            throw AudioError.invalidRenderGraphPlan("Gain must be finite.")
        }
        guard value >= 0 else {
            throw AudioError.invalidRenderGraphPlan("Gain must be non-negative.")
        }
        guard value <= Self.maximum else {
            throw AudioError.invalidRenderGraphPlan("Gain must be no greater than \(Self.maximum).")
        }
        self.value = value
    }

    public static func < (lhs: LinearGain, rhs: LinearGain) -> Bool {
        lhs.value < rhs.value
    }
}

public struct StartAudioSessionRequest: Equatable, Hashable, Sendable {
    public let sessionFormat: AudioSessionFormat
    public let initialSource: SourceSelection
    public let desktopRouteID: String?
    public let danteRouteID: String?
    public let desktopOutputEnabled: Bool
    public let danteOutputEnabled: Bool
    public let renderMode: RenderMode

    public init(
        sessionFormat: AudioSessionFormat,
        initialSource: SourceSelection = .off,
        desktopRouteID: String? = nil,
        danteRouteID: String? = nil,
        desktopOutputEnabled: Bool = true,
        danteOutputEnabled: Bool = false,
        renderMode: RenderMode = .automatic
    ) {
        self.sessionFormat = sessionFormat
        self.initialSource = initialSource
        self.desktopRouteID = desktopRouteID
        self.danteRouteID = danteRouteID
        self.desktopOutputEnabled = desktopOutputEnabled
        self.danteOutputEnabled = danteOutputEnabled
        self.renderMode = renderMode
    }
}

public struct StartAudioSessionResult: Equatable, Hashable, Sendable {
    public let sessionVersion: UInt64
    public let sessionFormat: AudioSessionFormat
    public let activeSource: SourceSelection
    public let desktopOutputEnabled: Bool
    public let danteOutputEnabled: Bool
    public let renderMode: RenderMode

    public init(
        sessionVersion: UInt64,
        sessionFormat: AudioSessionFormat,
        activeSource: SourceSelection,
        desktopOutputEnabled: Bool,
        danteOutputEnabled: Bool,
        renderMode: RenderMode
    ) {
        self.sessionVersion = sessionVersion
        self.sessionFormat = sessionFormat
        self.activeSource = activeSource
        self.desktopOutputEnabled = desktopOutputEnabled
        self.danteOutputEnabled = danteOutputEnabled
        self.renderMode = renderMode
    }
}

public struct PrepareLocalAssetRequest: Equatable, Hashable, Sendable {
    public let sourceID: String
    public let originalPath: String
    public let declaredSampleRate: AudioSampleRate?
    public let channelCount: Int?
    public let layout: AudioChannelLayoutDescriptor?
    public let durationFrames: Int64?
    public let sessionFormat: AudioSessionFormat?
    public let routeCapabilities: [DanteRouteCapability]

    public init(
        sourceID: String,
        originalPath: String,
        declaredSampleRate: AudioSampleRate? = nil,
        channelCount: Int? = nil,
        layout: AudioChannelLayoutDescriptor? = nil,
        durationFrames: Int64? = nil,
        sessionFormat: AudioSessionFormat? = nil,
        routeCapabilities: [DanteRouteCapability] = []
    ) {
        self.sourceID = sourceID
        self.originalPath = originalPath
        self.declaredSampleRate = declaredSampleRate
        self.channelCount = channelCount
        self.layout = layout
        self.durationFrames = durationFrames
        self.sessionFormat = sessionFormat
        self.routeCapabilities = routeCapabilities
    }
}

public struct ImportLocalAssetRequest: Equatable, Hashable, Sendable {
    public let sourceID: String
    public let originalPath: String
    public let sourceSampleRate: AudioSampleRate
    public let sourceChannelCount: Int
    public let sourceLayout: AudioChannelLayoutDescriptor
    public let durationFrames: Int64?
    public let targetSessionFormat: AudioSessionFormat
    public let managedAssetID: String
    public let managedPath: String
    public let codecDescription: String?
    public let containerDescription: String?

    public init(
        sourceID: String,
        originalPath: String,
        sourceSampleRate: AudioSampleRate,
        sourceChannelCount: Int,
        sourceLayout: AudioChannelLayoutDescriptor,
        durationFrames: Int64? = nil,
        targetSessionFormat: AudioSessionFormat,
        managedAssetID: String,
        managedPath: String,
        codecDescription: String? = nil,
        containerDescription: String? = nil
    ) {
        self.sourceID = sourceID
        self.originalPath = originalPath
        self.sourceSampleRate = sourceSampleRate
        self.sourceChannelCount = sourceChannelCount
        self.sourceLayout = sourceLayout
        self.durationFrames = durationFrames
        self.targetSessionFormat = targetSessionFormat
        self.managedAssetID = managedAssetID
        self.managedPath = managedPath
        self.codecDescription = codecDescription
        self.containerDescription = containerDescription
    }
}

public enum AudioOutputKind: String, CaseIterable, Equatable, Hashable, Sendable {
    case desktopMonitor
    case danteRenderer
}

public struct AudioRouteSnapshot: Equatable, Hashable, Sendable {
    public let sessionVersion: UInt64
    public let desktopRouteID: String?
    public let danteRouteID: String?
    public let availableRoutes: [OutputRouteDescriptor]
    public let validationMessages: [String]
    public let refreshedAtNanoseconds: UInt64?

    public init(
        sessionVersion: UInt64,
        desktopRouteID: String? = nil,
        danteRouteID: String? = nil,
        availableRoutes: [OutputRouteDescriptor] = [],
        validationMessages: [String] = [],
        refreshedAtNanoseconds: UInt64? = nil
    ) {
        self.sessionVersion = sessionVersion
        self.desktopRouteID = desktopRouteID
        self.danteRouteID = danteRouteID
        self.availableRoutes = availableRoutes
        self.validationMessages = validationMessages
        self.refreshedAtNanoseconds = refreshedAtNanoseconds
    }
}

public struct AudioGraphAuditSnapshot: Equatable, Hashable, Sendable {
    public let sessionVersion: UInt64
    public let isSessionRunning: Bool
    public let sessionFormat: AudioSessionFormat?
    public let activeSource: SourceSelection
    public let renderMode: RenderMode
    public let desktopMonitorGain: LinearGain
    public let danteOutputGain: LinearGain
    public let desktopOutputEnabled: Bool
    public let danteOutputEnabled: Bool
    public let validationMessages: [String]
    public let shellDescription: String

    public init(
        sessionVersion: UInt64,
        isSessionRunning: Bool,
        sessionFormat: AudioSessionFormat?,
        activeSource: SourceSelection,
        renderMode: RenderMode,
        desktopMonitorGain: LinearGain,
        danteOutputGain: LinearGain,
        desktopOutputEnabled: Bool,
        danteOutputEnabled: Bool,
        validationMessages: [String],
        shellDescription: String
    ) {
        self.sessionVersion = sessionVersion
        self.isSessionRunning = isSessionRunning
        self.sessionFormat = sessionFormat
        self.activeSource = activeSource
        self.renderMode = renderMode
        self.desktopMonitorGain = desktopMonitorGain
        self.danteOutputGain = danteOutputGain
        self.desktopOutputEnabled = desktopOutputEnabled
        self.danteOutputEnabled = danteOutputEnabled
        self.validationMessages = validationMessages
        self.shellDescription = shellDescription
    }
}

public enum AudioControlCommand: Equatable, Hashable, Sendable {
    case startSession(StartAudioSessionRequest)
    case stopSession
    case selectSource(SourceSelection)
    case setDesktopMonitorGain(LinearGain)
    case setDanteOutputGain(LinearGain)
    case setDanteOutputEnabled(Bool)
    case setDesktopOutputEnabled(Bool)
    case setRenderMode(RenderMode)
    case setDesktopMonitorMode(DesktopMonitorMode, AppleSpatialHeadphoneOptions)
    case prepareLocalAsset(PrepareLocalAssetRequest)
    case importLocalAssetToSessionRate(ImportLocalAssetRequest)
    case requestRouteRefresh
    case requestGraphAuditSnapshot
}

public enum AudioControlCommandResult: Equatable, Hashable, Sendable {
    case sessionStarted(StartAudioSessionResult)
    case sessionStopped(AudioGraphAuditSnapshot)
    case sourceSelected(SourceSelection)
    case gainChanged(AudioOutputKind, LinearGain)
    case outputEnabled(AudioOutputKind, Bool)
    case renderModeChanged(RenderMode)
    case desktopMonitorModeChanged(DesktopMonitorModeStatus)
    case assetReadiness(AssetReadiness)
    case assetImported(ManagedAssetDescriptor)
    case routeSnapshot(AudioRouteSnapshot)
    case graphAuditSnapshot(AudioGraphAuditSnapshot)
}

public protocol AudioCoreCompatibilityAdapter: Sendable {
    func commandAccepted(_ command: AudioControlCommand, snapshot: AudioGraphAuditSnapshot) throws
}

public struct NoOpAudioCoreCompatibilityAdapter: AudioCoreCompatibilityAdapter {
    public init() {}

    public func commandAccepted(_ command: AudioControlCommand, snapshot: AudioGraphAuditSnapshot) throws {}
}

public actor AudioCommandQueue {
    public typealias Handler = @Sendable (AudioControlCommand) throws -> AudioControlCommandResult

    private let handler: Handler

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    public func submit(_ command: AudioControlCommand) throws -> AudioControlCommandResult {
        try handler(command)
    }
}

public final class AudioTelemetry: @unchecked Sendable {
    private let lock = NSLock()
    private var meterSnapshot: MeterSnapshot?
    private var routeSnapshot: AudioRouteSnapshot?
    private var graphAudit: AudioGraphAuditSnapshot?
    private var conversionLedger: ConversionLedger?
    private var sessionFormat: AudioSessionFormat?
    private var desktopMonitorModeStatus: DesktopMonitorModeStatus?

    public init() {}

    public func latestMeterSnapshot() -> MeterSnapshot? {
        locked { meterSnapshot }
    }

    public func latestRouteSnapshot() -> AudioRouteSnapshot? {
        locked { routeSnapshot }
    }

    public func latestGraphAudit() -> AudioGraphAuditSnapshot? {
        locked { graphAudit }
    }

    public func latestConversionLedger() -> ConversionLedger? {
        locked { conversionLedger }
    }

    public func latestSessionFormat() -> AudioSessionFormat? {
        locked { sessionFormat }
    }

    public func latestDesktopMonitorModeStatus() -> DesktopMonitorModeStatus? {
        locked { desktopMonitorModeStatus }
    }

    func updateMeterSnapshot(_ snapshot: MeterSnapshot?) {
        locked { meterSnapshot = snapshot }
    }

    func updateRouteSnapshot(_ snapshot: AudioRouteSnapshot?) {
        locked { routeSnapshot = snapshot }
    }

    func updateGraphAudit(_ snapshot: AudioGraphAuditSnapshot?) {
        locked { graphAudit = snapshot }
    }

    func updateConversionLedger(_ ledger: ConversionLedger?) {
        locked { conversionLedger = ledger }
    }

    func updateSessionFormat(_ format: AudioSessionFormat?) {
        locked { sessionFormat = format }
    }

    func updateDesktopMonitorModeStatus(_ status: DesktopMonitorModeStatus?) {
        locked { desktopMonitorModeStatus = status }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

public final class AudioCoreShell: @unchecked Sendable {
    public let telemetry: AudioTelemetry

    private let compatibilityAdapter: AudioCoreCompatibilityAdapter
    private let managedAssetImporter: ManagedAssetImporter
    private let localAssetGate: ProductionLocalAssetGate
    private let appleSpatialHeadphoneMonitor: AppleSpatialHeadphoneMonitor
    private var state = AudioCoreShellState()

    public init(
        telemetry: AudioTelemetry = AudioTelemetry(),
        compatibilityAdapter: AudioCoreCompatibilityAdapter = NoOpAudioCoreCompatibilityAdapter(),
        managedAssetImporter: ManagedAssetImporter = ManagedAssetImporter(),
        localAssetGate: ProductionLocalAssetGate = ProductionLocalAssetGate(),
        appleSpatialHeadphoneMonitor: AppleSpatialHeadphoneMonitor = AppleSpatialHeadphoneMonitor()
    ) {
        self.telemetry = telemetry
        self.compatibilityAdapter = compatibilityAdapter
        self.managedAssetImporter = managedAssetImporter
        self.localAssetGate = localAssetGate
        self.appleSpatialHeadphoneMonitor = appleSpatialHeadphoneMonitor
        publishSnapshots(routeRefreshedAt: nil)
    }

    public func handle(_ command: AudioControlCommand) throws -> AudioControlCommandResult {
        let result = try apply(command)
        try compatibilityAdapter.commandAccepted(command, snapshot: auditSnapshot())
        return result
    }

    private func apply(_ command: AudioControlCommand) throws -> AudioControlCommandResult {
        switch command {
        case .startSession(let request):
            return try startSession(request)
        case .stopSession:
            return stopSession()
        case .selectSource(let selection):
            return try selectSource(selection)
        case .setDesktopMonitorGain(let gain):
            state.desktopMonitorGain = gain
            publishSnapshots(routeRefreshedAt: nil)
            return .gainChanged(.desktopMonitor, gain)
        case .setDanteOutputGain(let gain):
            state.danteOutputGain = gain
            publishSnapshots(routeRefreshedAt: nil)
            return .gainChanged(.danteRenderer, gain)
        case .setDanteOutputEnabled(let enabled):
            state.danteOutputEnabled = enabled
            publishSnapshots(routeRefreshedAt: nil)
            return .outputEnabled(.danteRenderer, enabled)
        case .setDesktopOutputEnabled(let enabled):
            state.desktopOutputEnabled = enabled
            publishSnapshots(routeRefreshedAt: nil)
            return .outputEnabled(.desktopMonitor, enabled)
        case .setRenderMode(let mode):
            state.renderMode = mode
            publishSnapshots(routeRefreshedAt: nil)
            return .renderModeChanged(mode)
        case .setDesktopMonitorMode:
            state.desktopMonitorMode = .referenceStereo
            state.appleSpatialHeadphoneOptions = .disabled
            let status = desktopMonitorModeStatus()
            publishSnapshots(routeRefreshedAt: nil)
            return .desktopMonitorModeChanged(status)
        case .prepareLocalAsset(let request):
            return try .assetReadiness(prepareLocalAsset(request))
        case .importLocalAssetToSessionRate(let request):
            let descriptor = try importLocalAssetToSessionRate(request)
            telemetry.updateConversionLedger(descriptor.conversionLedger)
            return .assetImported(descriptor)
        case .requestRouteRefresh:
            let timestamp = nowNanoseconds()
            publishSnapshots(routeRefreshedAt: timestamp)
            return .routeSnapshot(routeSnapshot(refreshedAt: timestamp))
        case .requestGraphAuditSnapshot:
            let snapshot = auditSnapshot()
            telemetry.updateGraphAudit(snapshot)
            return .graphAuditSnapshot(snapshot)
        }
    }

    private func startSession(_ request: StartAudioSessionRequest) throws -> AudioControlCommandResult {
        try request.sessionFormat.validate()
        try request.initialSource.validate(sessionFormat: request.sessionFormat)

        state.sessionVersion += 1
        state.isSessionRunning = true
        state.sessionFormat = request.sessionFormat
        state.activeSource = request.initialSource
        state.desktopRouteID = request.desktopRouteID
        state.danteRouteID = request.danteRouteID
        state.desktopOutputEnabled = request.desktopOutputEnabled
        state.danteOutputEnabled = request.danteOutputEnabled
        state.renderMode = request.renderMode

        publishSnapshots(routeRefreshedAt: nil)

        return .sessionStarted(
            StartAudioSessionResult(
                sessionVersion: state.sessionVersion,
                sessionFormat: request.sessionFormat,
                activeSource: request.initialSource,
                desktopOutputEnabled: request.desktopOutputEnabled,
                danteOutputEnabled: request.danteOutputEnabled,
                renderMode: request.renderMode
            )
        )
    }

    private func stopSession() -> AudioControlCommandResult {
        state.sessionVersion += 1
        state.isSessionRunning = false
        state.activeSource = .off
        telemetry.updateMeterSnapshot(nil)
        publishSnapshots(routeRefreshedAt: nil)
        return .sessionStopped(auditSnapshot())
    }

    private func selectSource(_ selection: SourceSelection) throws -> AudioControlCommandResult {
        guard let sessionFormat = state.sessionFormat else {
            if selection == .off {
                state.activeSource = .off
                publishSnapshots(routeRefreshedAt: nil)
                return .sourceSelected(selection)
            }
            throw AudioError.invalidRenderGraphPlan("A session format is required before selecting a source.")
        }

        try selection.validate(sessionFormat: sessionFormat)
        state.activeSource = selection
        publishSnapshots(routeRefreshedAt: nil)
        return .sourceSelected(selection)
    }

    private func prepareLocalAsset(_ request: PrepareLocalAssetRequest) throws -> AssetReadiness {
        guard !request.sourceID.isEmpty else {
            throw AudioError.invalidRenderGraphPlan("Local asset source ID is required.")
        }
        guard !request.originalPath.isEmpty else {
            return .unsupported(reason: "Local asset path is empty.")
        }
        let sessionFormat = try request.sessionFormat ?? requiredSessionFormat()
        try validateLocalAssetShape(
            channelCount: request.channelCount,
            layout: request.layout,
            durationFrames: request.durationFrames
        )

        let probe = try localAssetProbeResult(for: request)
        return localAssetGate.readiness(
            for: probe,
            sessionFormat: sessionFormat,
            routeCapabilities: request.routeCapabilities,
            isSessionRunning: state.isSessionRunning
        )
    }

    private func importLocalAssetToSessionRate(_ request: ImportLocalAssetRequest) throws -> ManagedAssetDescriptor {
        try request.targetSessionFormat.validate()
        try validateLocalAssetShape(
            channelCount: request.sourceChannelCount,
            layout: request.sourceLayout,
            durationFrames: request.durationFrames
        )
        guard !request.sourceID.isEmpty else {
            throw AudioError.invalidRenderGraphPlan("Local asset source ID is required.")
        }
        guard !request.originalPath.isEmpty, !request.managedPath.isEmpty, !request.managedAssetID.isEmpty else {
            throw AudioError.invalidRenderGraphPlan("Managed local asset paths and ID are required.")
        }

        return try managedAssetImporter.importAsset(
            originalPath: request.originalPath,
            managedPath: request.managedPath,
            managedAssetID: request.managedAssetID,
            targetSessionFormat: request.targetSessionFormat,
            declaredSourceSampleRate: request.sourceSampleRate,
            declaredSourceChannelCount: request.sourceChannelCount,
            declaredSourceLayout: request.sourceLayout,
            durationFrames: request.durationFrames,
            codecDescription: request.codecDescription,
            containerDescription: request.containerDescription
        )
    }

    private func localAssetProbeResult(for request: PrepareLocalAssetRequest) throws -> LocalAssetProbeResult {
        if FileManager.default.fileExists(atPath: request.originalPath) {
            return try managedAssetImporter.probe(path: request.originalPath)
        }

        guard let declaredSampleRate = request.declaredSampleRate else {
            return LocalAssetProbeResult(
                path: request.originalPath,
                sourceSampleRate: try AudioSampleRate(hertz: 1),
                channelCount: request.channelCount ?? 0,
                channelLayout: request.layout ?? .discrete(count: request.channelCount ?? 0)
            )
        }

        let channelCount = request.channelCount ?? 2
        return LocalAssetProbeResult(
            path: request.originalPath,
            durationFrames: request.durationFrames,
            durationSeconds: request.durationFrames.map { Double($0) / declaredSampleRate.hertz },
            sourceSampleRate: declaredSampleRate,
            channelCount: channelCount,
            codecDescription: nil,
            channelLayout: request.layout ?? .fallbackLayout(channelCount: channelCount),
            containerDescription: nil,
            estimatedDecodedBytes: estimatedDecodedBytes(
                durationFrames: request.durationFrames,
                channelCount: channelCount
            )
        )
    }

    private func validateLocalAssetShape(
        channelCount: Int?,
        layout: AudioChannelLayoutDescriptor?,
        durationFrames: Int64?
    ) throws {
        if let channelCount, !SourceDescriptor.sourceChannelLimit.contains(channelCount) {
            throw AudioError.sourceChannelCountOutOfRange(count: channelCount, minimum: 1, maximum: 64)
        }
        if let channelCount, let layout {
            let errors = layout.validationErrors(expectedChannelCount: channelCount)
            if let error = errors.first {
                throw error
            }
        }
        if let durationFrames, durationFrames < 0 {
            throw AudioError.invalidRenderGraphPlan("Local asset duration frames must not be negative.")
        }
    }

    private func requiredSessionFormat() throws -> AudioSessionFormat {
        guard let sessionFormat = state.sessionFormat else {
            throw AudioError.invalidRenderGraphPlan("A session format is required for this command.")
        }
        return sessionFormat
    }

    private func estimatedDecodedBytes(durationFrames: Int64?, channelCount: Int) -> Int64? {
        guard let durationFrames,
              durationFrames >= 0,
              channelCount > 0
        else { return nil }

        let estimate = Double(durationFrames) * Double(channelCount) * Double(MemoryLayout<Float>.size)
        guard estimate.isFinite,
              estimate >= 0,
              estimate <= Double(Int64.max)
        else { return nil }

        return Int64(estimate.rounded(.up))
    }

    private func publishSnapshots(routeRefreshedAt: UInt64?) {
        telemetry.updateSessionFormat(state.sessionFormat)
        telemetry.updateGraphAudit(auditSnapshot())
        telemetry.updateRouteSnapshot(routeSnapshot(refreshedAt: routeRefreshedAt))
        telemetry.updateDesktopMonitorModeStatus(desktopMonitorModeStatus())
    }

    private func desktopMonitorModeStatus() -> DesktopMonitorModeStatus {
        let route = state.desktopRouteID.flatMap { routeID in
            state.availableRoutes.first { $0.id == routeID }
        }
        return appleSpatialHeadphoneMonitor.status(
            mode: state.desktopMonitorMode,
            options: state.appleSpatialHeadphoneOptions,
            route: route,
            sessionSampleRate: state.sessionFormat?.sampleRate,
            liveDesktopBranchConnected: false
        )
    }

    private func auditSnapshot() -> AudioGraphAuditSnapshot {
        AudioGraphAuditSnapshot(
            sessionVersion: state.sessionVersion,
            isSessionRunning: state.isSessionRunning,
            sessionFormat: state.sessionFormat,
            activeSource: state.activeSource,
            renderMode: state.renderMode,
            desktopMonitorGain: state.desktopMonitorGain,
            danteOutputGain: state.danteOutputGain,
            desktopOutputEnabled: state.desktopOutputEnabled,
            danteOutputEnabled: state.danteOutputEnabled,
            validationMessages: state.validationMessages,
            shellDescription: "AudioCore initial command shell"
        )
    }

    private func routeSnapshot(refreshedAt: UInt64?) -> AudioRouteSnapshot {
        AudioRouteSnapshot(
            sessionVersion: state.sessionVersion,
            desktopRouteID: state.desktopRouteID,
            danteRouteID: state.danteRouteID,
            availableRoutes: state.availableRoutes,
            validationMessages: state.validationMessages,
            refreshedAtNanoseconds: refreshedAt
        )
    }

    private func ledger(
        sessionSampleRate: AudioSampleRate,
        sourceDescription: String,
        canonicalDescription: String,
        allowedConversions: [AllowedAudioConversion]
    ) -> ConversionLedger {
        ConversionLedger(
            sessionSampleRate: sessionSampleRate,
            sourceOriginalDescription: sourceDescription,
            sourceCanonicalDescription: canonicalDescription,
            allowedConversions: allowedConversions,
            forbiddenConversionsObserved: [],
            desktopOutputDescription: "desktop stereo monitor",
            danteOutputDescription: "Dante 31-channel renderer output"
        )
    }

    private func nowNanoseconds() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
    }
}

public final class AudioControl: @unchecked Sendable {
    public let telemetry: AudioTelemetry

    private let commandQueue: AudioCommandQueue

    public convenience init() {
        let telemetry = AudioTelemetry()
        let shell = AudioCoreShell(telemetry: telemetry)
        self.init(telemetry: telemetry, shell: shell)
    }

    public init(telemetry: AudioTelemetry, shell: AudioCoreShell) {
        self.telemetry = telemetry
        self.commandQueue = AudioCommandQueue { command in
            try shell.handle(command)
        }
    }

    public init(commandQueue: AudioCommandQueue, telemetry: AudioTelemetry = AudioTelemetry()) {
        self.commandQueue = commandQueue
        self.telemetry = telemetry
    }

    public func submit(_ command: AudioControlCommand) async throws -> AudioControlCommandResult {
        try await commandQueue.submit(command)
    }

    public func startSession(_ request: StartAudioSessionRequest) async throws -> StartAudioSessionResult {
        guard case .sessionStarted(let result) = try await submit(.startSession(request)) else {
            throw AudioError.invalidRenderGraphPlan("Unexpected result for start session command.")
        }
        return result
    }

    public func stopSession() async throws {
        _ = try await submit(.stopSession)
    }

    public func selectSource(_ source: SourceSelection) async throws {
        _ = try await submit(.selectSource(source))
    }

    public func setDesktopMonitorGain(_ gain: LinearGain) async throws {
        _ = try await submit(.setDesktopMonitorGain(gain))
    }

    public func setDanteOutputGain(_ gain: LinearGain) async throws {
        _ = try await submit(.setDanteOutputGain(gain))
    }

    public func setDanteOutputEnabled(_ enabled: Bool) async throws {
        _ = try await submit(.setDanteOutputEnabled(enabled))
    }

    public func setDesktopOutputEnabled(_ enabled: Bool) async throws {
        _ = try await submit(.setDesktopOutputEnabled(enabled))
    }

    public func setRenderMode(_ mode: RenderMode) async throws {
        _ = try await submit(.setRenderMode(mode))
    }

    public func setDesktopMonitorMode(
        _ mode: DesktopMonitorMode,
        options: AppleSpatialHeadphoneOptions = .enabledDefault
    ) async throws -> DesktopMonitorModeStatus {
        guard case .desktopMonitorModeChanged(let status) = try await submit(.setDesktopMonitorMode(mode, options)) else {
            throw AudioError.invalidRenderGraphPlan("Unexpected result for desktop monitor mode command.")
        }
        return status
    }

    public func prepareLocalAsset(_ request: PrepareLocalAssetRequest) async throws -> AssetReadiness {
        guard case .assetReadiness(let readiness) = try await submit(.prepareLocalAsset(request)) else {
            throw AudioError.invalidRenderGraphPlan("Unexpected result for prepare local asset command.")
        }
        return readiness
    }

    public func importLocalAssetToSessionRate(
        _ request: ImportLocalAssetRequest
    ) async throws -> ManagedAssetDescriptor {
        guard case .assetImported(let descriptor) = try await submit(.importLocalAssetToSessionRate(request)) else {
            throw AudioError.invalidRenderGraphPlan("Unexpected result for import local asset command.")
        }
        return descriptor
    }

    public func requestRouteRefresh() async throws -> AudioRouteSnapshot {
        guard case .routeSnapshot(let snapshot) = try await submit(.requestRouteRefresh) else {
            throw AudioError.invalidRenderGraphPlan("Unexpected result for route refresh command.")
        }
        return snapshot
    }

    public func requestGraphAuditSnapshot() async throws -> AudioGraphAuditSnapshot {
        guard case .graphAuditSnapshot(let snapshot) = try await submit(.requestGraphAuditSnapshot) else {
            throw AudioError.invalidRenderGraphPlan("Unexpected result for graph audit command.")
        }
        return snapshot
    }

    public func latestMeterSnapshot() -> MeterSnapshot? {
        telemetry.latestMeterSnapshot()
    }

    public func latestRouteSnapshot() -> AudioRouteSnapshot? {
        telemetry.latestRouteSnapshot()
    }

    public func latestGraphAudit() -> AudioGraphAuditSnapshot? {
        telemetry.latestGraphAudit()
    }

    public func latestConversionLedger() -> ConversionLedger? {
        telemetry.latestConversionLedger()
    }

    public func latestSessionFormat() -> AudioSessionFormat? {
        telemetry.latestSessionFormat()
    }

    public func latestDesktopMonitorModeStatus() -> DesktopMonitorModeStatus? {
        telemetry.latestDesktopMonitorModeStatus()
    }
}

private struct AudioCoreShellState {
    var sessionVersion: UInt64 = 0
    var isSessionRunning = false
    var sessionFormat: AudioSessionFormat?
    var activeSource: SourceSelection = .off
    var renderMode: RenderMode = .automatic
    var desktopMonitorGain: LinearGain = .unity
    var danteOutputGain: LinearGain = .unity
    var desktopOutputEnabled = true
    var danteOutputEnabled = false
    var desktopRouteID: String?
    var danteRouteID: String?
    var availableRoutes: [OutputRouteDescriptor] = []
    var validationMessages: [String] = []
    var desktopMonitorMode: DesktopMonitorMode = .referenceStereo
    var appleSpatialHeadphoneOptions: AppleSpatialHeadphoneOptions = .disabled
}
