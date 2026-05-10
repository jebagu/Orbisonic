import AudioContracts
import Foundation

public struct VlcStereoMonitorRequest: Equatable, Hashable, Sendable {
    public let sourceID: String
    public let generation: UInt64
    public let requestedSampleRate: AudioSampleRate
    public let sourceFormat: AudioFormatSummary
    public let ringCapacityBlocks: Int

    public init(
        sourceID: String,
        generation: UInt64,
        requestedSampleRate: AudioSampleRate,
        sourceFormat: AudioFormatSummary? = nil,
        ringCapacityBlocks: Int = 8
    ) {
        self.sourceID = sourceID
        self.generation = generation
        self.requestedSampleRate = requestedSampleRate
        self.sourceFormat = sourceFormat ?? AudioFormatSummary(
            sampleRate: requestedSampleRate,
            channelCount: nil,
            sampleFormat: "unknown",
            layoutName: nil
        )
        self.ringCapacityBlocks = max(ringCapacityBlocks, 1)
    }
}

public struct VlcStereoMonitorCallbackFormat: Equatable, Hashable, Sendable {
    public let formatFourCC: String
    public let sampleRate: AudioSampleRate
    public let channelCount: Int

    public init(formatFourCC: String, sampleRate: AudioSampleRate, channelCount: Int) {
        self.formatFourCC = formatFourCC
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }
}

public struct VlcStereoMonitorCallbackBuffer: Equatable, Sendable {
    public let generation: UInt64
    public let frameStart: Int64
    public let frameCount: Int
    public let format: VlcStereoMonitorCallbackFormat
    public let interleavedSamples: [Float]
    public let isDiscontinuity: Bool

    public init(
        generation: UInt64,
        frameStart: Int64,
        frameCount: Int,
        format: VlcStereoMonitorCallbackFormat,
        interleavedSamples: [Float],
        isDiscontinuity: Bool = false
    ) {
        self.generation = generation
        self.frameStart = frameStart
        self.frameCount = frameCount
        self.format = format
        self.interleavedSamples = interleavedSamples
        self.isDiscontinuity = isDiscontinuity
    }
}

public struct VlcStereoMonitorBlock: Equatable, Sendable {
    public let monitorBlock: StereoMonitorBlock
    public let interleavedSamples: [Float]

    public init(monitorBlock: StereoMonitorBlock, interleavedSamples: [Float]) {
        self.monitorBlock = monitorBlock
        self.interleavedSamples = interleavedSamples
    }
}

public enum VlcStereoMonitorError: Error, Equatable {
    case vlcUnavailable
    case pluginDirectoryMissing
    case mediaOpenFailed(String)
    case unsupportedCallbackFormat(expected: VlcStereoMonitorCallbackContract, actual: VlcStereoMonitorCallbackFormat)
    case callbackDidNotReturnStereo(actualChannelCount: Int)
    case callbackSampleCountMismatch(expected: Int, actual: Int)
    case ringOverflow
    case ringUnderflow
    case staleGenerationRejected(expected: UInt64, actual: UInt64)
    case sessionClosed
}

public struct VlcStereoMonitorDiagnostics: Equatable, Sendable {
    public let capabilityReport: VlcCapabilityReport
    public let downmixOwner: AudioConversionOwner
    public let nativeLocalDownmixCallCount: Int
    public let acceptedCallbackBlockCount: Int
    public let staleGenerationRejectedCount: Int
    public let callbackFormatViolationCount: Int
    public let ringOverflowCount: Int
    public let ringUnderflowCount: Int
    public let lastLedger: AudioConversionLedger?

    public init(
        capabilityReport: VlcCapabilityReport,
        downmixOwner: AudioConversionOwner = .vlc,
        nativeLocalDownmixCallCount: Int = 0,
        acceptedCallbackBlockCount: Int = 0,
        staleGenerationRejectedCount: Int = 0,
        callbackFormatViolationCount: Int = 0,
        ringOverflowCount: Int = 0,
        ringUnderflowCount: Int = 0,
        lastLedger: AudioConversionLedger? = nil
    ) {
        self.capabilityReport = capabilityReport
        self.downmixOwner = downmixOwner
        self.nativeLocalDownmixCallCount = nativeLocalDownmixCallCount
        self.acceptedCallbackBlockCount = max(acceptedCallbackBlockCount, 0)
        self.staleGenerationRejectedCount = max(staleGenerationRejectedCount, 0)
        self.callbackFormatViolationCount = max(callbackFormatViolationCount, 0)
        self.ringOverflowCount = max(ringOverflowCount, 0)
        self.ringUnderflowCount = max(ringUnderflowCount, 0)
        self.lastLedger = lastLedger
    }
}

public struct VlcLocalStereoMonitorSource {
    private let capabilityReportProvider: () -> VlcCapabilityReport

    public init(capabilityProbe: VlcCapabilityProbe = VlcCapabilityProbe()) {
        self.capabilityReportProvider = {
            capabilityProbe.probeCapabilities()
        }
    }

    public init(capabilityReport: VlcCapabilityReport) {
        self.capabilityReportProvider = {
            capabilityReport
        }
    }

    public func openLocalStereoMonitor(
        url: URL,
        request: VlcStereoMonitorRequest
    ) throws -> VlcStereoMonitorSession {
        let report = capabilityReportProvider()
        guard report.buildFlagEnabled, report.runtimeAvailable, report.canOpenLocalStereoMonitor else {
            if report.diagnostics.contains(where: { $0.code == .pluginDirectoryMissing })
                && !report.diagnostics.contains(where: { $0.code == .libraryNotFound })
            {
                throw VlcStereoMonitorError.pluginDirectoryMissing
            }
            throw VlcStereoMonitorError.vlcUnavailable
        }

        return VlcStereoMonitorSession(
            localFileURL: url,
            request: request,
            capabilityReport: report
        )
    }
}

public final class VlcStereoMonitorSession {
    public let localFileURL: URL
    public let request: VlcStereoMonitorRequest

    private let lock = NSLock()
    private let capabilityReport: VlcCapabilityReport
    private var ring: [VlcStereoMonitorBlock] = []
    private var isClosed = false
    private var acceptedCallbackBlockCount = 0
    private var staleGenerationRejectedCount = 0
    private var callbackFormatViolationCount = 0
    private var ringOverflowCount = 0
    private var ringUnderflowCount = 0
    private var lastLedger: AudioConversionLedger?

    public init(
        localFileURL: URL,
        request: VlcStereoMonitorRequest,
        capabilityReport: VlcCapabilityReport
    ) {
        self.localFileURL = localFileURL
        self.request = request
        self.capabilityReport = capabilityReport
    }

    public func acceptCallback(_ callback: VlcStereoMonitorCallbackBuffer) throws {
        lock.lock()
        defer { lock.unlock() }

        guard !isClosed else {
            throw VlcStereoMonitorError.sessionClosed
        }

        guard callback.generation == request.generation else {
            staleGenerationRejectedCount += 1
            throw VlcStereoMonitorError.staleGenerationRejected(
                expected: request.generation,
                actual: callback.generation
            )
        }

        guard callback.format.channelCount == VlcStereoMonitorCallbackContract.standard.channelCount else {
            callbackFormatViolationCount += 1
            throw VlcStereoMonitorError.callbackDidNotReturnStereo(
                actualChannelCount: callback.format.channelCount
            )
        }

        guard callback.format.formatFourCC == VlcStereoMonitorCallbackContract.standard.formatFourCC,
              callback.format.sampleRate.matches(request.requestedSampleRate)
        else {
            callbackFormatViolationCount += 1
            throw VlcStereoMonitorError.unsupportedCallbackFormat(
                expected: VlcStereoMonitorCallbackContract.standard,
                actual: callback.format
            )
        }

        let expectedSampleCount = callback.frameCount * callback.format.channelCount
        guard callback.interleavedSamples.count == expectedSampleCount else {
            callbackFormatViolationCount += 1
            throw VlcStereoMonitorError.callbackSampleCountMismatch(
                expected: expectedSampleCount,
                actual: callback.interleavedSamples.count
            )
        }

        guard ring.count < request.ringCapacityBlocks else {
            ringOverflowCount += 1
            throw VlcStereoMonitorError.ringOverflow
        }

        let monitorFormat = AudioFormatSummary(
            sampleRate: callback.format.sampleRate,
            channelCount: callback.format.channelCount,
            sampleFormat: "Float32",
            layoutName: "Stereo"
        )
        let ledger = AudioConversionLedger.localVLCMonitor(
            sessionID: "vlc-monitor-\(request.generation)",
            sourceID: request.sourceID,
            source: request.sourceFormat,
            monitor: monitorFormat
        )
        let contract = AudioBlockContract(
            sourceID: request.sourceID,
            generation: request.generation,
            sampleRate: callback.format.sampleRate,
            frameStart: callback.frameStart,
            frameCount: callback.frameCount,
            channelCount: callback.format.channelCount,
            processingFormat: .float32InterleavedPCM,
            layout: SourceLayout(
                descriptor: .stereo,
                authority: .fallback,
                authorityID: "vlc-monitor-callback"
            ),
            isDiscontinuity: callback.isDiscontinuity
        )
        let block = try StereoMonitorBlock(contract: contract)
        ring.append(
            VlcStereoMonitorBlock(
                monitorBlock: block,
                interleavedSamples: callback.interleavedSamples
            )
        )
        acceptedCallbackBlockCount += 1
        lastLedger = ledger
    }

    public func readBlock() throws -> VlcStereoMonitorBlock {
        lock.lock()
        defer { lock.unlock() }

        guard !ring.isEmpty else {
            ringUnderflowCount += 1
            throw VlcStereoMonitorError.ringUnderflow
        }

        return ring.removeFirst()
    }

    public func close() {
        lock.lock()
        ring.removeAll()
        isClosed = true
        lock.unlock()
    }

    public func currentDiagnostics() -> VlcStereoMonitorDiagnostics {
        lock.lock()
        defer { lock.unlock() }

        return VlcStereoMonitorDiagnostics(
            capabilityReport: capabilityReport,
            downmixOwner: .vlc,
            nativeLocalDownmixCallCount: 0,
            acceptedCallbackBlockCount: acceptedCallbackBlockCount,
            staleGenerationRejectedCount: staleGenerationRejectedCount,
            callbackFormatViolationCount: callbackFormatViolationCount,
            ringOverflowCount: ringOverflowCount,
            ringUnderflowCount: ringUnderflowCount,
            lastLedger: lastLedger
        )
    }
}
