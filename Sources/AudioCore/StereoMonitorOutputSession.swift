import AudioContracts
import Foundation

public typealias MonitorRoute = OutputRouteDescriptor

public struct StereoMonitorFormat: Equatable, Hashable, Sendable {
    public let sampleRate: AudioSampleRate
    public let channelCount: Int
    public let processingFormat: ProcessingFormat
    public let layout: AudioChannelLayoutDescriptor

    public init(
        sampleRate: AudioSampleRate,
        channelCount: Int = 2,
        processingFormat: ProcessingFormat = .float32InterleavedPCM,
        layout: AudioChannelLayoutDescriptor = .stereo
    ) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.processingFormat = processingFormat
        self.layout = layout
    }

    public var summary: AudioFormatSummary {
        AudioFormatSummary(
            sampleRate: sampleRate,
            channelCount: channelCount,
            sampleFormat: processingFormat.sampleFormat,
            layoutName: layout.name
        )
    }
}

public struct MonitorOutputNegotiation: Equatable, Hashable, Sendable {
    public let requestedRoute: MonitorRoute
    public let actualRoute: MonitorRoute
    public let requestedFormat: StereoMonitorFormat
    public let actualFormat: StereoMonitorFormat
    public let validationMessages: [String]

    public init(
        requestedRoute: MonitorRoute,
        actualRoute: MonitorRoute,
        requestedFormat: StereoMonitorFormat,
        actualFormat: StereoMonitorFormat,
        validationMessages: [String]
    ) {
        self.requestedRoute = requestedRoute
        self.actualRoute = actualRoute
        self.requestedFormat = requestedFormat
        self.actualFormat = actualFormat
        self.validationMessages = validationMessages
    }
}

public enum MonitorOutputSessionState: String, CaseIterable, Equatable, Hashable, Sendable {
    case unconfigured
    case configured
    case active
    case flushed
    case stopped
    case failed
}

public enum FlushReason: String, CaseIterable, Equatable, Hashable, Sendable {
    case userStop
    case sourceChanged
    case routeChanged
    case underrun
    case teardown
}

public enum StereoMonitorOutputSessionError: Error, Equatable, Hashable, Sendable {
    case routeUnavailable(String)
    case routeInsufficientChannels(required: Int, actual: Int)
    case routeSampleRateMismatch(expected: AudioSampleRate, actual: AudioSampleRate)
    case unsupportedMonitorFormat(StereoMonitorFormat)
    case notConfigured
    case notActive
    case blockSampleRateMismatch(expected: AudioSampleRate, actual: AudioSampleRate)
    case blockFormatMismatch(expected: StereoMonitorFormat, actual: StereoMonitorFormat)
}

public struct MonitorOutputStatus: Equatable, Hashable, Sendable {
    public let state: MonitorOutputSessionState
    public let negotiation: MonitorOutputNegotiation?
    public let submittedBlockCount: Int
    public let consumedFramePosition: Int64
    public let underflowCount: Int
    public let overflowCount: Int
    public let flushCount: Int
    public let lastFlushReason: FlushReason?
    public let validationMessages: [String]
    public let failureMessage: String?
    public let diagnostics: PlaybackDiagnosticSnapshot?

    public init(
        state: MonitorOutputSessionState,
        negotiation: MonitorOutputNegotiation?,
        submittedBlockCount: Int,
        consumedFramePosition: Int64,
        underflowCount: Int,
        overflowCount: Int,
        flushCount: Int,
        lastFlushReason: FlushReason?,
        validationMessages: [String],
        failureMessage: String?,
        diagnostics: PlaybackDiagnosticSnapshot?
    ) {
        self.state = state
        self.negotiation = negotiation
        self.submittedBlockCount = max(submittedBlockCount, 0)
        self.consumedFramePosition = max(consumedFramePosition, 0)
        self.underflowCount = max(underflowCount, 0)
        self.overflowCount = max(overflowCount, 0)
        self.flushCount = max(flushCount, 0)
        self.lastFlushReason = lastFlushReason
        self.validationMessages = validationMessages
        self.failureMessage = failureMessage
        self.diagnostics = diagnostics
    }
}

public final class StereoMonitorOutputSession: @unchecked Sendable {
    private let lock = NSLock()
    private var state: MonitorOutputSessionState = .unconfigured
    private var negotiation: MonitorOutputNegotiation?
    private var submittedBlockCount = 0
    private var consumedFramePosition: Int64 = 0
    private var underflowCount = 0
    private var overflowCount = 0
    private var flushCount = 0
    private var lastFlushReason: FlushReason?
    private var validationMessages: [String] = []
    private var failureMessage: String?
    private var diagnostics: PlaybackDiagnosticSnapshot?
    private var lastAcceptedBlock: StereoMonitorBlock?

    public init() {}

    @discardableResult
    public func configure(
        route: MonitorRoute,
        format requestedFormat: StereoMonitorFormat
    ) throws -> MonitorOutputNegotiation {
        lock.lock()
        defer { lock.unlock() }

        guard requestedFormat.channelCount == 2,
              requestedFormat.layout.channelCount == 2,
              requestedFormat.processingFormat.sampleFormat == "Float32"
        else {
            setFailure("Stereo monitor format must be Float32 stereo.")
            throw StereoMonitorOutputSessionError.unsupportedMonitorFormat(requestedFormat)
        }
        guard route.isAvailable else {
            setFailure("Monitor route is unavailable.")
            throw StereoMonitorOutputSessionError.routeUnavailable(route.id)
        }
        guard route.outputChannelCount >= 2 else {
            setFailure("Monitor route exposes fewer than two output channels.")
            throw StereoMonitorOutputSessionError.routeInsufficientChannels(
                required: 2,
                actual: route.outputChannelCount
            )
        }
        if let nominalSampleRate = route.nominalSampleRate,
           !nominalSampleRate.matches(requestedFormat.sampleRate) {
            setFailure("Monitor route sample rate does not match requested output.")
            throw StereoMonitorOutputSessionError.routeSampleRateMismatch(
                expected: requestedFormat.sampleRate,
                actual: nominalSampleRate
            )
        }

        let actualFormat = StereoMonitorFormat(
            sampleRate: route.nominalSampleRate ?? requestedFormat.sampleRate,
            channelCount: 2,
            processingFormat: requestedFormat.processingFormat,
            layout: .stereo
        )
        let messages = [
            "Monitor route \(route.id) configured for stereo Float32 output.",
            "Requested \(Int(requestedFormat.sampleRate.hertz)) Hz; actual \(Int(actualFormat.sampleRate.hertz)) Hz."
        ]
        let result = MonitorOutputNegotiation(
            requestedRoute: route,
            actualRoute: route,
            requestedFormat: requestedFormat,
            actualFormat: actualFormat,
            validationMessages: messages
        )

        negotiation = result
        state = .configured
        validationMessages = messages
        failureMessage = nil
        diagnostics = nil
        lastAcceptedBlock = nil
        submittedBlockCount = 0
        consumedFramePosition = 0
        underflowCount = 0
        overflowCount = 0
        flushCount = 0
        lastFlushReason = nil
        return result
    }

    public func start() throws {
        lock.lock()
        defer { lock.unlock() }

        guard negotiation != nil else {
            setFailure("Monitor output session is not configured.")
            throw StereoMonitorOutputSessionError.notConfigured
        }
        state = .active
    }

    public func submit(block: StereoMonitorBlock) throws {
        lock.lock()
        defer { lock.unlock() }

        guard state == .active else {
            setFailure("Monitor output session is not active.")
            throw StereoMonitorOutputSessionError.notActive
        }
        guard let negotiation else {
            setFailure("Monitor output session is not configured.")
            throw StereoMonitorOutputSessionError.notConfigured
        }
        guard block.sampleRate.matches(negotiation.actualFormat.sampleRate) else {
            setFailure("Monitor block sample rate does not match output.")
            throw StereoMonitorOutputSessionError.blockSampleRateMismatch(
                expected: negotiation.actualFormat.sampleRate,
                actual: block.sampleRate
            )
        }

        let actualBlockFormat = StereoMonitorFormat(
            sampleRate: block.sampleRate,
            channelCount: block.contract.channelCount,
            processingFormat: block.contract.processingFormat,
            layout: block.contract.layout.descriptor
        )
        guard actualBlockFormat.channelCount == negotiation.actualFormat.channelCount,
              actualBlockFormat.layout == negotiation.actualFormat.layout,
              actualBlockFormat.processingFormat == negotiation.actualFormat.processingFormat
        else {
            setFailure("Monitor block format does not match output.")
            throw StereoMonitorOutputSessionError.blockFormatMismatch(
                expected: negotiation.actualFormat,
                actual: actualBlockFormat
            )
        }

        submittedBlockCount += 1
        consumedFramePosition += Int64(block.frameCount)
        lastAcceptedBlock = block
        diagnostics = makeDiagnostics(for: block, negotiation: negotiation)
        failureMessage = nil
    }

    public func flush(reason: FlushReason) {
        lock.lock()
        flushCount += 1
        lastFlushReason = reason
        underflowCount += reason == .underrun ? 1 : 0
        lastAcceptedBlock = nil
        state = .flushed
        lock.unlock()
    }

    public func stop() {
        lock.lock()
        state = .stopped
        lastAcceptedBlock = nil
        lock.unlock()
    }

    public func status() -> MonitorOutputStatus {
        lock.lock()
        defer { lock.unlock() }

        return MonitorOutputStatus(
            state: state,
            negotiation: negotiation,
            submittedBlockCount: submittedBlockCount,
            consumedFramePosition: consumedFramePosition,
            underflowCount: underflowCount,
            overflowCount: overflowCount,
            flushCount: flushCount,
            lastFlushReason: lastFlushReason,
            validationMessages: validationMessages,
            failureMessage: failureMessage,
            diagnostics: diagnostics
        )
    }

    public func lastAcceptedBlockForTesting() -> StereoMonitorBlock? {
        lock.lock()
        defer { lock.unlock() }
        return lastAcceptedBlock
    }

    private func setFailure(_ message: String) {
        state = .failed
        failureMessage = message
        validationMessages = [message]
    }

    private func makeDiagnostics(
        for block: StereoMonitorBlock,
        negotiation: MonitorOutputNegotiation
    ) -> PlaybackDiagnosticSnapshot {
        let sourceFormat = AudioFormatSummary(
            sampleRate: block.sampleRate,
            channelCount: block.contract.channelCount,
            sampleFormat: block.contract.processingFormat.sampleFormat,
            layoutName: block.contract.layout.descriptor.name
        )
        let ledger = AudioConversionLedger(
            sessionID: "stereo-monitor-output-\(block.generation)",
            sourceID: block.sourceID,
            sourceKind: .localFile,
            entries: [
                AudioConversionLedgerEntry(
                    stage: .routeValidation,
                    owner: .orbisonic,
                    input: sourceFormat,
                    output: negotiation.actualFormat.summary,
                    isExplicit: true,
                    note: "stereo monitor output route validation"
                ),
                AudioConversionLedgerEntry(
                    stage: .format,
                    owner: .orbisonic,
                    input: sourceFormat,
                    output: negotiation.actualFormat.summary,
                    isExplicit: true,
                    note: "finished stereo PCM output"
                )
            ]
        )

        return PlaybackDiagnosticSnapshot(
            sessionID: ledger.sessionID,
            sourceID: block.sourceID,
            sourceKind: .localFile,
            sourceSampleRate: block.sampleRate,
            sourceChannelCount: block.contract.channelCount,
            requestedOutputFormat: negotiation.requestedFormat.summary,
            actualOutputFormat: negotiation.actualFormat.summary,
            routeChannelCount: negotiation.actualRoute.outputChannelCount,
            underflowCount: underflowCount,
            overflowCount: overflowCount,
            conversionLedger: ledger
        )
    }
}
