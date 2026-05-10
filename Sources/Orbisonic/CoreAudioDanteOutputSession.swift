import AudioContracts
import AudioCore
import CoreAudio
import Foundation

struct CoreAudioDanteHostFormat: Equatable, Hashable, Sendable {
    let sampleRate: AudioSampleRate?
    let channelCount: Int
    let formatID: UInt32
    let formatIDDescription: String
    let formatFlags: UInt32
    let bitsPerChannel: Int
    let bytesPerFrame: Int
    let framesPerPacket: Int
    let bytesPerPacket: Int
    let isFloat: Bool
    let isIntegerPCM: Bool
    let isInterleaved: Bool

    init(
        sampleRate: AudioSampleRate?,
        channelCount: Int,
        formatID: UInt32,
        formatIDDescription: String,
        formatFlags: UInt32,
        bitsPerChannel: Int,
        bytesPerFrame: Int,
        framesPerPacket: Int,
        bytesPerPacket: Int,
        isFloat: Bool,
        isIntegerPCM: Bool,
        isInterleaved: Bool
    ) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.formatID = formatID
        self.formatIDDescription = formatIDDescription
        self.formatFlags = formatFlags
        self.bitsPerChannel = bitsPerChannel
        self.bytesPerFrame = bytesPerFrame
        self.framesPerPacket = framesPerPacket
        self.bytesPerPacket = bytesPerPacket
        self.isFloat = isFloat
        self.isIntegerPCM = isIntegerPCM
        self.isInterleaved = isInterleaved
    }

    init(asbd: AudioStreamBasicDescription) {
        let sampleRate = try? AudioSampleRate(hertz: asbd.mSampleRate)
        let isLinearPCM = asbd.mFormatID == kAudioFormatLinearPCM
        let isFloat = isLinearPCM && (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        let isNonInterleaved = (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0
        self.init(
            sampleRate: sampleRate,
            channelCount: Int(asbd.mChannelsPerFrame),
            formatID: asbd.mFormatID,
            formatIDDescription: Self.formatIDDescription(asbd.mFormatID),
            formatFlags: asbd.mFormatFlags,
            bitsPerChannel: Int(asbd.mBitsPerChannel),
            bytesPerFrame: Int(asbd.mBytesPerFrame),
            framesPerPacket: Int(asbd.mFramesPerPacket),
            bytesPerPacket: Int(asbd.mBytesPerPacket),
            isFloat: isFloat,
            isIntegerPCM: isLinearPCM && !isFloat,
            isInterleaved: !isNonInterleaved
        )
    }

    var summary: AudioFormatSummary {
        AudioFormatSummary(
            sampleRate: sampleRate,
            channelCount: channelCount,
            sampleFormat: sampleFormatDescription,
            layoutName: "CoreAudio host stream"
        )
    }

    var sampleFormatDescription: String {
        if isFloat {
            return "CoreAudio host Float\(bitsPerChannel)"
        }
        if isIntegerPCM {
            return "CoreAudio host PCM \(bitsPerChannel)-bit"
        }
        return "CoreAudio host \(formatIDDescription) \(bitsPerChannel)-bit"
    }

    private static func formatIDDescription(_ formatID: UInt32) -> String {
        guard formatID != 0 else { return "unknown" }
        let bytes = [
            UInt8((formatID >> 24) & 0xff),
            UInt8((formatID >> 16) & 0xff),
            UInt8((formatID >> 8) & 0xff),
            UInt8(formatID & 0xff)
        ]
        if bytes.allSatisfy({ $0 >= 32 && $0 <= 126 }),
           let text = String(bytes: bytes, encoding: .ascii) {
            return text
        }
        return String(formatID)
    }
}

struct CoreAudioDanteRouteFacts: Equatable, Hashable, Sendable {
    let requestedRoute: ProductionOutputRoute
    let actualRoute: ProductionOutputRoute
    let deviceID: UInt32?
    let hostOutputFormat: CoreAudioDanteHostFormat?
    let queryMessages: [String]

    init(
        requestedRoute: ProductionOutputRoute,
        actualRoute: ProductionOutputRoute,
        deviceID: UInt32?,
        hostOutputFormat: CoreAudioDanteHostFormat?,
        queryMessages: [String] = []
    ) {
        self.requestedRoute = requestedRoute
        self.actualRoute = actualRoute
        self.deviceID = deviceID
        self.hostOutputFormat = hostOutputFormat
        self.queryMessages = queryMessages
    }
}

enum CoreAudioDanteSessionError: Error, Equatable, Hashable, Sendable, CustomStringConvertible {
    case routeFactsUnavailable(routeID: String)
    case routeIsNotDante(routeName: String, risk: AudioContracts.OutputRouteRisk)
    case actualRouteSampleRateMismatch(expected: AudioSampleRate, actual: AudioSampleRate)
    case actualRouteChannelCountMismatch(expected: Int, actual: Int)
    case hostOutputFormatUnavailable(routeID: String)
    case hostOutputSampleRateMismatch(expected: AudioSampleRate, actual: AudioSampleRate)
    case hostOutputChannelCountMismatch(expected: Int, actual: Int)

    var description: String {
        switch self {
        case .routeFactsUnavailable(let routeID):
            "CoreAudio route facts are unavailable for \(routeID)."
        case .routeIsNotDante(let routeName, let risk):
            "Production output requires an intended Dante route; \(routeName) is \(risk.rawValue)."
        case .actualRouteSampleRateMismatch(let expected, let actual):
            "CoreAudio route sample rate mismatch: expected \(expected.hertz) Hz, got \(actual.hertz) Hz."
        case .actualRouteChannelCountMismatch(let expected, let actual):
            "CoreAudio route channel count mismatch: expected \(expected), got \(actual)."
        case .hostOutputFormatUnavailable(let routeID):
            "CoreAudio host output stream format is unavailable for \(routeID)."
        case .hostOutputSampleRateMismatch(let expected, let actual):
            "CoreAudio host output sample rate mismatch: expected \(expected.hertz) Hz, got \(actual.hertz) Hz."
        case .hostOutputChannelCountMismatch(let expected, let actual):
            "CoreAudio host output channel count mismatch: expected \(expected), got \(actual)."
        }
    }
}

protocol CoreAudioDanteRouteFactProviding: Sendable {
    func routeFacts(for route: ProductionOutputRoute) throws -> CoreAudioDanteRouteFacts
}

struct LiveCoreAudioDanteRouteFactProvider: CoreAudioDanteRouteFactProviding {
    func routeFacts(for route: ProductionOutputRoute) throws -> CoreAudioDanteRouteFacts {
        guard let routeInfo = resolveRoute(route) else {
            throw CoreAudioDanteSessionError.routeFactsUnavailable(routeID: route.id)
        }

        let actualRoute = RouteCapabilityValidator().outputRouteDescriptor(from: routeInfo)
        let hostFormat = Self.hostOutputFormat(deviceID: routeInfo.deviceID)
        return CoreAudioDanteRouteFacts(
            requestedRoute: route,
            actualRoute: actualRoute,
            deviceID: UInt32(routeInfo.deviceID),
            hostOutputFormat: hostFormat,
            queryMessages: [
                "CoreAudio deviceID=\(routeInfo.deviceID)",
                "CoreAudio route name=\(routeInfo.deviceName)",
                "CoreAudio route channels=\(routeInfo.outputChannelCount)",
                "CoreAudio route nominalRate=\(routeInfo.nominalSampleRate)"
            ]
        )
    }

    private func resolveRoute(_ route: ProductionOutputRoute) -> OutputRouteInfo? {
        if let uid = route.uid, !uid.isEmpty,
           let routeInfo = OutputRouteMonitor.outputRoute(uid: uid) {
            return routeInfo
        }
        if let routeInfo = OutputRouteMonitor.outputRoute(uid: route.id) {
            return routeInfo
        }
        if let deviceID = UInt32(route.id),
           let routeInfo = OutputRouteMonitor.outputRoute(deviceID: AudioDeviceID(deviceID)) {
            return routeInfo
        }
        return nil
    }

    private static func hostOutputFormat(deviceID: AudioDeviceID) -> CoreAudioDanteHostFormat? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamFormat,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var asbd = AudioStreamBasicDescription()

        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &propertySize,
            &asbd
        )

        guard status == noErr else { return nil }
        return CoreAudioDanteHostFormat(asbd: asbd)
    }
}

final class CoreAudioDanteOutputSession: ProductionOutputSession, @unchecked Sendable {
    private let lock = NSLock()
    private let factProvider: any CoreAudioDanteRouteFactProviding
    private let lifecycle: FakeProductionOutputSession
    private var requestedRoute: ProductionOutputRoute?
    private var latestFacts: CoreAudioDanteRouteFacts?
    private var latestNegotiation: ProductionOutputNegotiation?
    private var latestDiagnostics: PlaybackDiagnosticSnapshot?
    private var latestValidationMessages: [String] = []
    private var overrideState: ProductionOutputSessionState?
    private var overrideFailureMessage: String?

    init(
        factProvider: any CoreAudioDanteRouteFactProviding = LiveCoreAudioDanteRouteFactProvider(),
        lifecycle: FakeProductionOutputSession = FakeProductionOutputSession()
    ) {
        self.factProvider = factProvider
        self.lifecycle = lifecycle
    }

    func open(route: ProductionOutputRoute) throws {
        try lifecycle.open(route: route)
        lock.lock()
        requestedRoute = route
        latestFacts = nil
        latestNegotiation = nil
        latestDiagnostics = nil
        latestValidationMessages = ["CoreAudio Dante route \(route.id) opened for strict fact query."]
        overrideState = nil
        overrideFailureMessage = nil
        lock.unlock()
    }

    func configure(profile: DanteTargetProfile) throws -> ProductionOutputNegotiation {
        let route = try currentRoute()
        let facts: CoreAudioDanteRouteFacts
        let negotiation: ProductionOutputNegotiation
        do {
            facts = try factProvider.routeFacts(for: route)
            try validate(facts: facts, profile: profile)
            negotiation = makeNegotiation(facts: facts, profile: profile)
            try lifecycle.open(route: facts.actualRoute)
            _ = try lifecycle.configure(profile: profile)
        } catch {
            recordFailure(error)
            throw error
        }

        lock.lock()
        latestFacts = facts
        latestNegotiation = negotiation
        latestDiagnostics = makeRouteDiagnostics(facts: facts, negotiation: negotiation)
        latestValidationMessages = negotiation.validationMessages
        overrideState = nil
        overrideFailureMessage = nil
        lock.unlock()
        return negotiation
    }

    func start() throws {
        try lifecycle.start()
    }

    func submit(packet: DanteOutputPacket) throws {
        try lifecycle.submit(packet: packet)
        lock.lock()
        if let facts = latestFacts,
           let negotiation = latestNegotiation {
            latestDiagnostics = makePacketDiagnostics(packet: packet, facts: facts, negotiation: negotiation)
        }
        lock.unlock()
    }

    func flush(reason: FlushReason) {
        lifecycle.flush(reason: reason)
    }

    func drain() throws {
        try lifecycle.drain()
    }

    func stop() {
        lifecycle.stop()
    }

    func close() {
        lifecycle.close()
        lock.lock()
        requestedRoute = nil
        latestFacts = nil
        latestNegotiation = nil
        latestDiagnostics = nil
        latestValidationMessages = []
        overrideState = nil
        overrideFailureMessage = nil
        lock.unlock()
    }

    func timingReport() -> OutputTimingReport {
        let base = lifecycle.timingReport()
        lock.lock()
        let state = overrideState ?? base.state
        let failureMessage = overrideFailureMessage ?? base.failureMessage
        let negotiation = latestNegotiation ?? base.negotiation
        let diagnostics = latestDiagnostics ?? base.diagnostics
        let validationMessages = latestValidationMessages.isEmpty ? base.validationMessages : latestValidationMessages
        lock.unlock()

        return OutputTimingReport(
            state: state,
            negotiation: negotiation,
            activeGeneration: base.activeGeneration,
            queuedPacketCount: base.queuedPacketCount,
            submittedPacketCount: base.submittedPacketCount,
            writtenPacketCount: base.writtenPacketCount,
            flushedPacketCount: base.flushedPacketCount,
            drainedPacketCount: base.drainedPacketCount,
            queuedFrameCount: base.queuedFrameCount,
            consumedFramePosition: base.consumedFramePosition,
            flushedFrameCount: base.flushedFrameCount,
            drainedFrameCount: base.drainedFrameCount,
            flushCount: base.flushCount,
            drainCount: base.drainCount,
            staleGenerationRejectedCount: base.staleGenerationRejectedCount,
            lastFlushReason: base.lastFlushReason,
            validationMessages: validationMessages,
            failureMessage: failureMessage,
            diagnostics: diagnostics
        )
    }

    private func currentRoute() throws -> ProductionOutputRoute {
        lock.lock()
        let route = requestedRoute
        lock.unlock()
        guard let route else {
            throw ProductionOutputSessionError.notOpened
        }
        return route
    }

    private func validate(
        facts: CoreAudioDanteRouteFacts,
        profile: DanteTargetProfile
    ) throws {
        try profile.validate()
        guard facts.actualRoute.risk == .preferredDante else {
            throw CoreAudioDanteSessionError.routeIsNotDante(
                routeName: facts.actualRoute.name,
                risk: facts.actualRoute.risk
            )
        }
        guard let actualRouteSampleRate = facts.actualRoute.nominalSampleRate else {
            throw ProductionOutputSessionError.routeSampleRateUnknown(routeID: facts.actualRoute.id)
        }
        guard actualRouteSampleRate.matches(profile.sampleRate) else {
            throw CoreAudioDanteSessionError.actualRouteSampleRateMismatch(
                expected: profile.sampleRate,
                actual: actualRouteSampleRate
            )
        }
        guard facts.actualRoute.outputChannelCount == profile.physicalChannelCount else {
            throw CoreAudioDanteSessionError.actualRouteChannelCountMismatch(
                expected: profile.physicalChannelCount,
                actual: facts.actualRoute.outputChannelCount
            )
        }
        guard let hostFormat = facts.hostOutputFormat else {
            throw CoreAudioDanteSessionError.hostOutputFormatUnavailable(routeID: facts.actualRoute.id)
        }
        guard let hostSampleRate = hostFormat.sampleRate else {
            throw CoreAudioDanteSessionError.hostOutputFormatUnavailable(routeID: facts.actualRoute.id)
        }
        guard hostSampleRate.matches(profile.sampleRate) else {
            throw CoreAudioDanteSessionError.hostOutputSampleRateMismatch(
                expected: profile.sampleRate,
                actual: hostSampleRate
            )
        }
        guard hostFormat.channelCount == profile.physicalChannelCount else {
            throw CoreAudioDanteSessionError.hostOutputChannelCountMismatch(
                expected: profile.physicalChannelCount,
                actual: hostFormat.channelCount
            )
        }
    }

    private func recordFailure(_ error: Error) {
        lock.lock()
        overrideState = .failed
        overrideFailureMessage = String(describing: error)
        latestValidationMessages = [String(describing: error)]
        lock.unlock()
    }

    private func makeNegotiation(
        facts: CoreAudioDanteRouteFacts,
        profile: DanteTargetProfile
    ) -> ProductionOutputNegotiation {
        let requestedFormat = targetSummary(for: profile)
        let actualFormat = facts.hostOutputFormat?.summary ?? AudioFormatSummary(
            sampleRate: facts.actualRoute.nominalSampleRate,
            channelCount: facts.actualRoute.outputChannelCount,
            sampleFormat: "CoreAudio host format unavailable",
            layoutName: "CoreAudio host stream"
        )
        let messages = facts.queryMessages + [
            "Target Dante profile \(targetFormatDescription(profile)) at \(Int(profile.sampleRate.hertz)) Hz.",
            "Actual CoreAudio route \(facts.actualRoute.name) has \(facts.actualRoute.outputChannelCount) channels at \(Int(facts.actualRoute.nominalSampleRate?.hertz ?? 0)) Hz.",
            "CoreAudio host format \(actualFormat.sampleFormat) channels=\(actualFormat.channelCount ?? 0).",
            "CoreAudio host format is not treated as Dante network encoding."
        ] + bitDepthClassificationMessages(facts: facts, profile: profile)

        return ProductionOutputNegotiation(
            requestedRoute: facts.requestedRoute,
            actualRoute: facts.actualRoute,
            requestedProfile: profile,
            actualProfile: profile,
            requestedOutputFormat: requestedFormat,
            actualOutputFormat: actualFormat,
            validationMessages: messages
        )
    }

    private func bitDepthClassificationMessages(
        facts: CoreAudioDanteRouteFacts,
        profile: DanteTargetProfile
    ) -> [String] {
        guard let hostFormat = facts.hostOutputFormat,
              hostFormat.bitsPerChannel != profile.encodingBitDepth
        else { return [] }
        return [
            "Host API bit depth \(hostFormat.bitsPerChannel) differs from target Dante profile \(profile.encodingBitDepth); this is classified as host-vs-network format separation."
        ]
    }

    private func makeRouteDiagnostics(
        facts: CoreAudioDanteRouteFacts,
        negotiation: ProductionOutputNegotiation
    ) -> PlaybackDiagnosticSnapshot {
        let ledger = AudioConversionLedger(
            sessionID: "coreaudio-dante-route-\(facts.actualRoute.id)",
            sourceID: "route-validation",
            sourceKind: .testTone,
            entries: [
                AudioConversionLedgerEntry(
                    stage: .routeValidation,
                    owner: .productionOutputSession,
                    input: negotiation.requestedOutputFormat,
                    output: negotiation.actualOutputFormat,
                    isExplicit: true,
                    note: "CoreAudio ASBD and route facts validated against Dante target profile"
                )
            ]
        )

        return PlaybackDiagnosticSnapshot(
            sessionID: ledger.sessionID,
            sourceID: ledger.sourceID,
            sourceKind: ledger.sourceKind,
            sourceSampleRate: facts.actualRoute.nominalSampleRate,
            sourceChannelCount: facts.actualRoute.outputChannelCount,
            requestedOutputFormat: negotiation.requestedOutputFormat,
            actualOutputFormat: negotiation.actualOutputFormat,
            routeChannelCount: facts.actualRoute.outputChannelCount,
            conversionLedger: ledger
        )
    }

    private func makePacketDiagnostics(
        packet: DanteOutputPacket,
        facts: CoreAudioDanteRouteFacts,
        negotiation: ProductionOutputNegotiation
    ) -> PlaybackDiagnosticSnapshot {
        let routeEntry = AudioConversionLedgerEntry(
            stage: .routeValidation,
            owner: .productionOutputSession,
            input: negotiation.requestedOutputFormat,
            output: negotiation.actualOutputFormat,
            isExplicit: true,
            note: "CoreAudio ASBD route validation before packet submission"
        )
        let ledger = AudioConversionLedger(
            sessionID: packet.ledger.sessionID,
            sourceID: packet.ledger.sourceID,
            sourceKind: packet.ledger.sourceKind,
            entries: packet.ledger.entries + [routeEntry]
        )

        return PlaybackDiagnosticSnapshot(
            sessionID: ledger.sessionID,
            sourceID: ledger.sourceID,
            sourceKind: ledger.sourceKind,
            sourceSampleRate: packet.sampleRate,
            sourceChannelCount: packet.logicalChannelCount,
            outputFormatterOwner: .danteOutputFormatter,
            requestedOutputFormat: negotiation.requestedOutputFormat,
            actualOutputFormat: negotiation.actualOutputFormat,
            routeChannelCount: facts.actualRoute.outputChannelCount,
            staleGenerationRejectedCount: lifecycle.timingReport().staleGenerationRejectedCount,
            conversionLedger: ledger
        )
    }

    private func targetSummary(for profile: DanteTargetProfile) -> AudioFormatSummary {
        AudioFormatSummary(
            sampleRate: profile.sampleRate,
            channelCount: profile.physicalChannelCount,
            sampleFormat: targetFormatDescription(profile),
            layoutName: "Dante target profile"
        )
    }

    private func targetFormatDescription(_ profile: DanteTargetProfile) -> String {
        switch profile.encodingKind {
        case .pcmInteger:
            "PCM \(profile.encodingBitDepth)-bit"
        case .float32:
            "Float32"
        }
    }
}
