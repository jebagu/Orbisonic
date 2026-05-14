import AudioContracts
import Foundation

public typealias ProductionOutputRoute = OutputRouteDescriptor

public enum ProductionOutputSessionState: String, CaseIterable, Equatable, Hashable, Sendable {
    case unopened
    case opened
    case configured
    case active
    case flushed
    case drained
    case stopped
    case closed
    case failed
}

public enum DanteOutputPayloadKind: String, CaseIterable, Equatable, Hashable, Sendable {
    case int24LittleEndianInterleaved
    case float32Interleaved
}

public extension DanteOutputPayload {
    var kind: DanteOutputPayloadKind {
        switch self {
        case .int24LittleEndianInterleaved:
            .int24LittleEndianInterleaved
        case .float32Interleaved:
            .float32Interleaved
        }
    }
}

public enum ProductionOutputSessionError: Error, Equatable, Hashable, Sendable, CustomStringConvertible {
    case routeUnavailable(String)
    case routeSampleRateUnknown(routeID: String)
    case routeSampleRateMismatch(expected: AudioSampleRate, actual: AudioSampleRate)
    case routeChannelCountMismatch(expected: Int, actual: Int)
    case notOpened
    case notConfigured
    case notActive
    case packetProfileMismatch
    case packetSampleRateMismatch(expected: AudioSampleRate, actual: AudioSampleRate)
    case packetLogicalChannelCountMismatch(expected: Int, actual: Int)
    case packetPhysicalChannelCountMismatch(expected: Int, actual: Int)
    case packetPayloadKindMismatch(expected: DanteOutputPayloadKind, actual: DanteOutputPayloadKind)
    case packetGenerationMismatch(expected: UInt64, actual: UInt64)
    case staleGeneration(UInt64)
    case backendWriteFailed(String)

    public var description: String {
        switch self {
        case .routeUnavailable(let routeID):
            "Production route is unavailable: \(routeID)."
        case .routeSampleRateUnknown(let routeID):
            "Production route sample rate is unknown: \(routeID)."
        case .routeSampleRateMismatch(let expected, let actual):
            "Production route sample rate mismatch: expected \(expected.hertz) Hz, got \(actual.hertz) Hz."
        case .routeChannelCountMismatch(let expected, let actual):
            "Production route channel count mismatch: expected \(expected), got \(actual)."
        case .notOpened:
            "Production output session must be opened before configuration."
        case .notConfigured:
            "Production output session must be configured before starting."
        case .notActive:
            "Production output session is not active."
        case .packetProfileMismatch:
            "Production output packet profile does not match the negotiated profile."
        case .packetSampleRateMismatch(let expected, let actual):
            "Production output packet sample rate mismatch: expected \(expected.hertz) Hz, got \(actual.hertz) Hz."
        case .packetLogicalChannelCountMismatch(let expected, let actual):
            "Production output packet logical channel count mismatch: expected \(expected), got \(actual)."
        case .packetPhysicalChannelCountMismatch(let expected, let actual):
            "Production output packet physical channel count mismatch: expected \(expected), got \(actual)."
        case .packetPayloadKindMismatch(let expected, let actual):
            "Production output packet payload mismatch: expected \(expected.rawValue), got \(actual.rawValue)."
        case .packetGenerationMismatch(let expected, let actual):
            "Production output packet generation mismatch: expected \(expected), got \(actual)."
        case .staleGeneration(let generation):
            "Production output rejected stale generation \(generation)."
        case .backendWriteFailed(let message):
            "Production output fake backend write failed: \(message)"
        }
    }
}

public struct ProductionOutputNegotiation: Equatable, Hashable, Sendable {
    public let requestedRoute: ProductionOutputRoute
    public let actualRoute: ProductionOutputRoute
    public let requestedProfile: DanteTargetProfile
    public let actualProfile: DanteTargetProfile
    public let requestedOutputFormat: AudioFormatSummary
    public let actualOutputFormat: AudioFormatSummary
    public let validationMessages: [String]

    public init(
        requestedRoute: ProductionOutputRoute,
        actualRoute: ProductionOutputRoute,
        requestedProfile: DanteTargetProfile,
        actualProfile: DanteTargetProfile,
        requestedOutputFormat: AudioFormatSummary,
        actualOutputFormat: AudioFormatSummary,
        validationMessages: [String]
    ) {
        self.requestedRoute = requestedRoute
        self.actualRoute = actualRoute
        self.requestedProfile = requestedProfile
        self.actualProfile = actualProfile
        self.requestedOutputFormat = requestedOutputFormat
        self.actualOutputFormat = actualOutputFormat
        self.validationMessages = validationMessages
    }
}

public struct OutputTimingReport: Equatable, Sendable {
    public let state: ProductionOutputSessionState
    public let negotiation: ProductionOutputNegotiation?
    public let activeGeneration: UInt64?
    public let queuedPacketCount: Int
    public let submittedPacketCount: Int
    public let writtenPacketCount: Int
    public let flushedPacketCount: Int
    public let drainedPacketCount: Int
    public let queuedFrameCount: Int64
    public let consumedFramePosition: Int64
    public let flushedFrameCount: Int64
    public let drainedFrameCount: Int64
    public let flushCount: Int
    public let drainCount: Int
    public let staleGenerationRejectedCount: Int
    public let lastFlushReason: FlushReason?
    public let validationMessages: [String]
    public let failureMessage: String?
    public let diagnostics: PlaybackDiagnosticSnapshot?

    public init(
        state: ProductionOutputSessionState,
        negotiation: ProductionOutputNegotiation?,
        activeGeneration: UInt64?,
        queuedPacketCount: Int,
        submittedPacketCount: Int,
        writtenPacketCount: Int,
        flushedPacketCount: Int,
        drainedPacketCount: Int,
        queuedFrameCount: Int64,
        consumedFramePosition: Int64,
        flushedFrameCount: Int64,
        drainedFrameCount: Int64,
        flushCount: Int,
        drainCount: Int,
        staleGenerationRejectedCount: Int,
        lastFlushReason: FlushReason?,
        validationMessages: [String],
        failureMessage: String?,
        diagnostics: PlaybackDiagnosticSnapshot?
    ) {
        self.state = state
        self.negotiation = negotiation
        self.activeGeneration = activeGeneration
        self.queuedPacketCount = max(queuedPacketCount, 0)
        self.submittedPacketCount = max(submittedPacketCount, 0)
        self.writtenPacketCount = max(writtenPacketCount, 0)
        self.flushedPacketCount = max(flushedPacketCount, 0)
        self.drainedPacketCount = max(drainedPacketCount, 0)
        self.queuedFrameCount = max(queuedFrameCount, 0)
        self.consumedFramePosition = max(consumedFramePosition, 0)
        self.flushedFrameCount = max(flushedFrameCount, 0)
        self.drainedFrameCount = max(drainedFrameCount, 0)
        self.flushCount = max(flushCount, 0)
        self.drainCount = max(drainCount, 0)
        self.staleGenerationRejectedCount = max(staleGenerationRejectedCount, 0)
        self.lastFlushReason = lastFlushReason
        self.validationMessages = validationMessages
        self.failureMessage = failureMessage
        self.diagnostics = diagnostics
    }
}

public protocol ProductionOutputSession: AnyObject, Sendable {
    func open(route: ProductionOutputRoute) throws
    func configure(profile: DanteTargetProfile) throws -> ProductionOutputNegotiation
    func start() throws
    func submit(packet: DanteOutputPacket) throws
    func flush(reason: FlushReason)
    func drain() throws
    func stop()
    func close()
    func timingReport() -> OutputTimingReport
}

public struct ProductionChannelWalkObservation: Equatable, Hashable, Sendable {
    public let logicalChannel: Int
    public let physicalChannel: Int
    public let peak: Float

    public init(logicalChannel: Int, physicalChannel: Int, peak: Float) {
        self.logicalChannel = logicalChannel
        self.physicalChannel = physicalChannel
        self.peak = peak
    }
}

public struct ProductionChannelWalkReport: Equatable, Hashable, Sendable {
    public let expectedLogicalChannelCount: Int
    public let observations: [ProductionChannelWalkObservation]
    public let reservedPhysicalChannelsWithSignal: [Int]
    public let passed: Bool

    public init(
        expectedLogicalChannelCount: Int,
        observations: [ProductionChannelWalkObservation],
        reservedPhysicalChannelsWithSignal: [Int]
    ) {
        self.expectedLogicalChannelCount = expectedLogicalChannelCount
        self.observations = observations.sorted {
            ($0.logicalChannel, $0.physicalChannel) < ($1.logicalChannel, $1.physicalChannel)
        }
        self.reservedPhysicalChannelsWithSignal = reservedPhysicalChannelsWithSignal.sorted()
        let observed = Set(observations.map(\.logicalChannel))
        self.passed = observed == Set(0..<expectedLogicalChannelCount) && reservedPhysicalChannelsWithSignal.isEmpty
    }
}

public final class FakeProductionOutputBackend: @unchecked Sendable {
    private let lock = NSLock()
    private var writtenPackets: [DanteOutputPacket] = []
    private var closeCount = 0
    private var flushCount = 0
    private var drainCount = 0

    public init() {}

    public func write(packet: DanteOutputPacket) throws {
        lock.lock()
        writtenPackets.append(packet)
        lock.unlock()
    }

    public func flush() {
        lock.lock()
        flushCount += 1
        lock.unlock()
    }

    public func drain() throws {
        lock.lock()
        drainCount += 1
        lock.unlock()
    }

    public func close() {
        lock.lock()
        closeCount += 1
        lock.unlock()
    }

    public func capturedPackets() -> [DanteOutputPacket] {
        lock.lock()
        defer { lock.unlock() }
        return writtenPackets
    }

    public func lifecycleCounts() -> (flush: Int, drain: Int, close: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (flushCount, drainCount, closeCount)
    }

    public func channelWalkReport(threshold: Float = 0.001) throws -> ProductionChannelWalkReport {
        lock.lock()
        let packets = writtenPackets
        lock.unlock()

        guard let profile = packets.first?.profile else {
            return ProductionChannelWalkReport(
                expectedLogicalChannelCount: 0,
                observations: [],
                reservedPhysicalChannelsWithSignal: []
            )
        }

        var observations: [ProductionChannelWalkObservation] = []
        var reservedPhysicalChannelsWithSignal = Set<Int>()

        for packet in packets {
            let samples = try packet.payload.normalizedFloat32Samples(
                frameCount: packet.frameCount,
                physicalChannelCount: packet.physicalChannelCount
            )
            var peaks = Array(repeating: Float(0), count: packet.physicalChannelCount)
            for frame in 0..<packet.frameCount {
                for physicalChannel in 0..<packet.physicalChannelCount {
                    let index = frame * packet.physicalChannelCount + physicalChannel
                    peaks[physicalChannel] = max(peaks[physicalChannel], abs(samples[index]))
                }
            }

            for (physicalChannel, peak) in peaks.enumerated() where peak >= threshold {
                guard let logicalChannel = packet.profile.physicalChannelMap[physicalChannel] else {
                    reservedPhysicalChannelsWithSignal.insert(physicalChannel)
                    continue
                }
                observations.append(
                    ProductionChannelWalkObservation(
                        logicalChannel: logicalChannel,
                        physicalChannel: physicalChannel,
                        peak: peak
                    )
                )
            }
        }

        return ProductionChannelWalkReport(
            expectedLogicalChannelCount: profile.logicalChannelCount,
            observations: observations,
            reservedPhysicalChannelsWithSignal: Array(reservedPhysicalChannelsWithSignal)
        )
    }
}

public final class FakeProductionOutputSession: ProductionOutputSession, @unchecked Sendable {
    public let backend: FakeProductionOutputBackend

    private let lock = NSLock()
    private var state: ProductionOutputSessionState = .unopened
    private var route: ProductionOutputRoute?
    private var negotiation: ProductionOutputNegotiation?
    private var profile: DanteTargetProfile?
    private var packetQueue: [DanteOutputPacket] = []
    private var activeGeneration: UInt64?
    private var rejectedGenerations = Set<UInt64>()
    private var submittedPacketCount = 0
    private var writtenPacketCount = 0
    private var flushedPacketCount = 0
    private var drainedPacketCount = 0
    private var consumedFramePosition: Int64 = 0
    private var flushedFrameCount: Int64 = 0
    private var drainedFrameCount: Int64 = 0
    private var flushCount = 0
    private var drainCount = 0
    private var staleGenerationRejectedCount = 0
    private var lastFlushReason: FlushReason?
    private var validationMessages: [String] = []
    private var failureMessage: String?
    private var diagnostics: PlaybackDiagnosticSnapshot?

    public init(backend: FakeProductionOutputBackend = FakeProductionOutputBackend()) {
        self.backend = backend
    }

    public func open(route: ProductionOutputRoute) throws {
        lock.lock()
        defer { lock.unlock() }

        guard route.isAvailable else {
            setFailure("Production route is unavailable.")
            throw ProductionOutputSessionError.routeUnavailable(route.id)
        }

        self.route = route
        state = .opened
        validationMessages = ["Production route \(route.id) opened for strict validation."]
        failureMessage = nil
        diagnostics = nil
        packetQueue.removeAll()
        activeGeneration = nil
        rejectedGenerations.removeAll()
    }

    public func configure(profile: DanteTargetProfile) throws -> ProductionOutputNegotiation {
        lock.lock()
        defer { lock.unlock() }

        guard let route else {
            setFailure("Production output route is not open.")
            throw ProductionOutputSessionError.notOpened
        }
        do {
            try profile.validate()
            try validate(route: route, profile: profile)
        } catch {
            setFailure(errorDescription(error))
            throw error
        }

        let requestedFormat = Self.formatSummary(for: profile)
        let actualFormat = Self.formatSummary(for: profile, route: route)
        let messages = [
            "Production route \(route.id) validated for strict output.",
            "Requested \(Int(profile.sampleRate.hertz)) Hz, \(profile.physicalChannelCount) physical channels.",
            "Actual \(Int((route.nominalSampleRate ?? profile.sampleRate).hertz)) Hz, \(route.outputChannelCount) physical channels."
        ]
        let result = ProductionOutputNegotiation(
            requestedRoute: route,
            actualRoute: route,
            requestedProfile: profile,
            actualProfile: profile,
            requestedOutputFormat: requestedFormat,
            actualOutputFormat: actualFormat,
            validationMessages: messages
        )

        self.profile = profile
        negotiation = result
        state = .configured
        validationMessages = messages
        failureMessage = nil
        diagnostics = nil
        packetQueue.removeAll()
        activeGeneration = nil
        rejectedGenerations.removeAll()
        submittedPacketCount = 0
        writtenPacketCount = 0
        flushedPacketCount = 0
        drainedPacketCount = 0
        consumedFramePosition = 0
        flushedFrameCount = 0
        drainedFrameCount = 0
        flushCount = 0
        drainCount = 0
        staleGenerationRejectedCount = 0
        lastFlushReason = nil
        return result
    }

    public func start() throws {
        lock.lock()
        defer { lock.unlock() }

        guard negotiation != nil else {
            setFailure("Production output session is not configured.")
            throw ProductionOutputSessionError.notConfigured
        }
        state = .active
    }

    public func submit(packet: DanteOutputPacket) throws {
        lock.lock()
        defer { lock.unlock() }

        guard state == .active else {
            setFailure("Production output session is not active.")
            throw ProductionOutputSessionError.notActive
        }
        guard let profile else {
            setFailure("Production output session is not configured.")
            throw ProductionOutputSessionError.notConfigured
        }

        do {
            try validate(packet: packet, profile: profile)
        } catch let error as ProductionOutputSessionError {
            if case .staleGeneration = error {
                staleGenerationRejectedCount += 1
                validationMessages = [errorDescription(error)]
                throw error
            }
            setFailure(errorDescription(error))
            throw error
        } catch {
            setFailure(errorDescription(error))
            throw error
        }

        if activeGeneration == nil {
            activeGeneration = packet.generation
        }
        submittedPacketCount += 1
        packetQueue.append(packet)
        diagnostics = makeDiagnostics(packet: packet)
        failureMessage = nil
    }

    public func flush(reason: FlushReason) {
        lock.lock()
        let queuedFrames = packetQueue.reduce(Int64(0)) { $0 + Int64($1.frameCount) }
        flushedPacketCount += packetQueue.count
        flushedFrameCount += queuedFrames
        if let activeGeneration {
            rejectedGenerations.insert(activeGeneration)
        }
        activeGeneration = nil
        packetQueue.removeAll()
        flushCount += 1
        lastFlushReason = reason
        state = .flushed
        backend.flush()
        lock.unlock()
    }

    public func drain() throws {
        lock.lock()
        guard state == .active else {
            setFailure("Production output session is not active.")
            lock.unlock()
            throw ProductionOutputSessionError.notActive
        }

        let packets = packetQueue
        packetQueue.removeAll()
        lock.unlock()

        do {
            for packet in packets {
                try backend.write(packet: packet)
            }
            try backend.drain()
        } catch {
            lock.lock()
            setFailure(errorDescription(error))
            lock.unlock()
            throw ProductionOutputSessionError.backendWriteFailed(errorDescription(error))
        }

        lock.lock()
        let drainedFrames = packets.reduce(Int64(0)) { $0 + Int64($1.frameCount) }
        writtenPacketCount += packets.count
        drainedPacketCount += packets.count
        drainedFrameCount += drainedFrames
        consumedFramePosition += drainedFrames
        drainCount += 1
        state = .drained
        lock.unlock()
    }

    public func stop() {
        lock.lock()
        packetQueue.removeAll()
        activeGeneration = nil
        state = .stopped
        lock.unlock()
    }

    public func close() {
        lock.lock()
        packetQueue.removeAll()
        activeGeneration = nil
        state = .closed
        backend.close()
        lock.unlock()
    }

    public func timingReport() -> OutputTimingReport {
        lock.lock()
        defer { lock.unlock() }

        return OutputTimingReport(
            state: state,
            negotiation: negotiation,
            activeGeneration: activeGeneration,
            queuedPacketCount: packetQueue.count,
            submittedPacketCount: submittedPacketCount,
            writtenPacketCount: writtenPacketCount,
            flushedPacketCount: flushedPacketCount,
            drainedPacketCount: drainedPacketCount,
            queuedFrameCount: packetQueue.reduce(Int64(0)) { $0 + Int64($1.frameCount) },
            consumedFramePosition: consumedFramePosition,
            flushedFrameCount: flushedFrameCount,
            drainedFrameCount: drainedFrameCount,
            flushCount: flushCount,
            drainCount: drainCount,
            staleGenerationRejectedCount: staleGenerationRejectedCount,
            lastFlushReason: lastFlushReason,
            validationMessages: validationMessages,
            failureMessage: failureMessage,
            diagnostics: diagnostics
        )
    }

    private func validate(route: ProductionOutputRoute, profile: DanteTargetProfile) throws {
        guard route.isAvailable else {
            throw ProductionOutputSessionError.routeUnavailable(route.id)
        }
        if profile.requireStrictRoute {
            guard let nominalSampleRate = route.nominalSampleRate else {
                throw ProductionOutputSessionError.routeSampleRateUnknown(routeID: route.id)
            }
            guard nominalSampleRate.matches(profile.sampleRate) else {
                throw ProductionOutputSessionError.routeSampleRateMismatch(
                    expected: profile.sampleRate,
                    actual: nominalSampleRate
                )
            }
            guard route.outputChannelCount == profile.physicalChannelCount else {
                throw ProductionOutputSessionError.routeChannelCountMismatch(
                    expected: profile.physicalChannelCount,
                    actual: route.outputChannelCount
                )
            }
        } else if route.outputChannelCount < profile.physicalChannelCount {
            throw ProductionOutputSessionError.routeChannelCountMismatch(
                expected: profile.physicalChannelCount,
                actual: route.outputChannelCount
            )
        }
    }

    private func validate(packet: DanteOutputPacket, profile: DanteTargetProfile) throws {
        guard !rejectedGenerations.contains(packet.generation) else {
            throw ProductionOutputSessionError.staleGeneration(packet.generation)
        }
        if let activeGeneration, packet.generation != activeGeneration {
            throw ProductionOutputSessionError.packetGenerationMismatch(
                expected: activeGeneration,
                actual: packet.generation
            )
        }
        guard packet.profile == profile else {
            throw ProductionOutputSessionError.packetProfileMismatch
        }
        guard packet.sampleRate.matches(profile.sampleRate) else {
            throw ProductionOutputSessionError.packetSampleRateMismatch(
                expected: profile.sampleRate,
                actual: packet.sampleRate
            )
        }
        guard packet.logicalChannelCount == profile.logicalChannelCount else {
            throw ProductionOutputSessionError.packetLogicalChannelCountMismatch(
                expected: profile.logicalChannelCount,
                actual: packet.logicalChannelCount
            )
        }
        guard packet.physicalChannelCount == profile.physicalChannelCount else {
            throw ProductionOutputSessionError.packetPhysicalChannelCountMismatch(
                expected: profile.physicalChannelCount,
                actual: packet.physicalChannelCount
            )
        }
        let expectedPayloadKind: DanteOutputPayloadKind = profile.encodingKind == .pcmInteger
            ? .int24LittleEndianInterleaved
            : .float32Interleaved
        guard packet.payload.kind == expectedPayloadKind else {
            throw ProductionOutputSessionError.packetPayloadKindMismatch(
                expected: expectedPayloadKind,
                actual: packet.payload.kind
            )
        }
    }

    private func makeDiagnostics(packet: DanteOutputPacket) -> PlaybackDiagnosticSnapshot? {
        guard let negotiation else { return nil }
        let routeEntry = AudioConversionLedgerEntry(
            stage: .routeValidation,
            owner: .productionOutputSession,
            input: negotiation.requestedOutputFormat,
            output: negotiation.actualOutputFormat,
            isExplicit: true,
            note: "strict production output route validation"
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
            routeChannelCount: negotiation.actualRoute.outputChannelCount,
            staleGenerationRejectedCount: staleGenerationRejectedCount,
            conversionLedger: ledger
        )
    }

    private func setFailure(_ message: String) {
        state = .failed
        failureMessage = message
        validationMessages = [message]
    }

    private func errorDescription(_ error: Error) -> String {
        return String(describing: error)
    }

    private static func formatSummary(
        for profile: DanteTargetProfile,
        route: ProductionOutputRoute? = nil
    ) -> AudioFormatSummary {
        AudioFormatSummary(
            sampleRate: route?.nominalSampleRate ?? profile.sampleRate,
            channelCount: route?.outputChannelCount ?? profile.physicalChannelCount,
            sampleFormat: sampleFormatDescription(profile),
            layoutName: "Dante physical map"
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

private extension DanteOutputPayload {
    func normalizedFloat32Samples(
        frameCount: Int,
        physicalChannelCount: Int
    ) throws -> [Float] {
        switch self {
        case .float32Interleaved(let samples):
            return samples
        case .int24LittleEndianInterleaved(let bytes):
            let expectedByteCount = frameCount * physicalChannelCount * 3
            guard bytes.count == expectedByteCount else {
                throw ProductionOutputSessionError.backendWriteFailed(
                    "Expected \(expectedByteCount) int24 bytes, got \(bytes.count)."
                )
            }
            var samples: [Float] = []
            samples.reserveCapacity(frameCount * physicalChannelCount)
            for offset in stride(from: 0, to: bytes.count, by: 3) {
                let unsigned = Int32(bytes[offset])
                    | (Int32(bytes[offset + 1]) << 8)
                    | (Int32(bytes[offset + 2]) << 16)
                let signed = (unsigned & 0x80_0000) == 0 ? unsigned : (unsigned | ~0xFF_FFFF)
                samples.append(Float(signed) / Float(8_388_607))
            }
            return samples
        }
    }
}
