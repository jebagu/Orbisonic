import AudioContracts
import Foundation

public enum MeterDisplaySurface: String, CaseIterable, Equatable, Hashable, Sendable {
    case inputSourceMeter
    case desktopOutputMeter
    case danteOutputMeter
    case sonicSphereAnalysisMeter

    public var title: String {
        switch self {
        case .inputSourceMeter:
            "Input Meter"
        case .desktopOutputMeter:
            "Desktop Output Meter"
        case .danteOutputMeter:
            "Dante Output Meter"
        case .sonicSphereAnalysisMeter:
            "Sonic Sphere Analysis Meter"
        }
    }

    public var isActualAudibleOutput: Bool {
        switch self {
        case .desktopOutputMeter, .danteOutputMeter:
            true
        case .inputSourceMeter, .sonicSphereAnalysisMeter:
            false
        }
    }

    public static func sonicSphereTitle(isActualDanteRenderBus: Bool) -> String {
        isActualDanteRenderBus
            ? MeterDisplaySurface.danteOutputMeter.title
            : MeterDisplaySurface.sonicSphereAnalysisMeter.title
    }
}

public struct MeterCopiedBlock: Equatable, Sendable {
    public let copyPoint: MeterCopyPoint
    public let sampleRate: AudioSampleRate
    public let channelCount: Int
    public let frameCount: Int
    public let layout: AudioChannelLayoutDescriptor
    public let sessionVersion: UInt64
    public let sourceID: String?
    public let framePosition: Int64

    private let samples: [[Float]]

    public init(
        copyPoint: MeterCopyPoint,
        block: CanonicalAudioBlock,
        sessionVersion: UInt64,
        sourceID: String?,
        framePosition: Int64
    ) {
        self.copyPoint = copyPoint
        self.sampleRate = block.sampleRate
        self.channelCount = block.channelCount
        self.frameCount = block.frameCount
        self.layout = block.layout
        self.sessionVersion = sessionVersion
        self.sourceID = sourceID
        self.framePosition = framePosition
        self.samples = (0..<block.channelCount).map { block.channelSamplesCopy(channel: $0) }
    }

    public init(
        copyPoint: MeterCopyPoint,
        sampleRate: AudioSampleRate,
        layout: AudioChannelLayoutDescriptor,
        sessionVersion: UInt64,
        sourceID: String?,
        framePosition: Int64,
        samples: [[Float]]
    ) {
        let resolvedFrameCount = samples.map(\.count).min() ?? 0
        self.copyPoint = copyPoint
        self.sampleRate = sampleRate
        self.channelCount = samples.count
        self.frameCount = resolvedFrameCount
        self.layout = layout
        self.sessionVersion = sessionVersion
        self.sourceID = sourceID
        self.framePosition = framePosition
        self.samples = samples.map { Array($0.prefix(resolvedFrameCount)) }
    }

    public func samplesCopy(channel: Int) -> [Float] {
        guard channel >= 0, channel < samples.count else { return [] }
        return samples[channel]
    }
}

public struct MeterCopyBusStatus: Equatable, Hashable, Sendable {
    public let queuedBlockCount: Int
    public let droppedBlockCount: Int
    public let lockContentionDropCount: Int
    public let maxQueuedBlockCount: Int

    public init(
        queuedBlockCount: Int,
        droppedBlockCount: Int,
        lockContentionDropCount: Int,
        maxQueuedBlockCount: Int
    ) {
        self.queuedBlockCount = queuedBlockCount
        self.droppedBlockCount = droppedBlockCount
        self.lockContentionDropCount = lockContentionDropCount
        self.maxQueuedBlockCount = maxQueuedBlockCount
    }
}

public final class MeterCopyBus: @unchecked Sendable {
    private let lock = NSLock()
    private let maxQueuedBlockCount: Int
    private var queuedBlocks: [MeterCopiedBlock] = []
    private var droppedBlockCount = 0
    private var lockContentionDropCount = 0

    public init(maxQueuedBlockCount: Int = 8) {
        self.maxQueuedBlockCount = max(1, maxQueuedBlockCount)
    }

    @discardableResult
    public func submit(
        copyPoint: MeterCopyPoint,
        block: CanonicalAudioBlock,
        sessionVersion: UInt64,
        sourceID: String?,
        framePosition: Int64
    ) -> Bool {
        guard lock.try() else { return false }
        defer { lock.unlock() }

        guard queuedBlocks.count < maxQueuedBlockCount else {
            droppedBlockCount += 1
            return false
        }

        queuedBlocks.append(
            MeterCopiedBlock(
                copyPoint: copyPoint,
                block: block,
                sessionVersion: sessionVersion,
                sourceID: sourceID,
                framePosition: framePosition
            )
        )
        return true
    }

    public func drainCopies() -> [MeterCopiedBlock] {
        lock.lock()
        defer { lock.unlock() }
        let drained = queuedBlocks
        queuedBlocks.removeAll(keepingCapacity: true)
        return drained
    }

    public func statusSnapshot() -> MeterCopyBusStatus {
        lock.lock()
        defer { lock.unlock() }
        return MeterCopyBusStatus(
            queuedBlockCount: queuedBlocks.count,
            droppedBlockCount: droppedBlockCount,
            lockContentionDropCount: lockContentionDropCount,
            maxQueuedBlockCount: maxQueuedBlockCount
        )
    }
}

public struct MeterAccumulator: Sendable {
    public static let silenceDBFS: Float = -120

    public let referenceDBFS: Float
    public let clippingThreshold: Float

    public init(referenceDBFS: Float = -18, clippingThreshold: Float = 1.0) {
        self.referenceDBFS = referenceDBFS
        self.clippingThreshold = clippingThreshold
    }

    public func meters(
        for block: MeterCopiedBlock,
        meterCalibrationGain: LinearGain = .unity
    ) -> [ChannelMeter] {
        (0..<block.channelCount).map { channel in
            meter(for: block.samplesCopy(channel: channel), meterCalibrationGain: meterCalibrationGain)
        }
    }

    public func snapshot(
        from copiedBlocks: [MeterCopiedBlock],
        meterCalibrationGain: LinearGain = .unity
    ) -> MeterSnapshot? {
        guard !copiedBlocks.isEmpty else { return nil }

        let latestInput = latestBlock(for: .inputSourceBus, in: copiedBlocks)
        let latestDesktop = latestBlock(for: .desktopPostRenderPreOutputGain, in: copiedBlocks)
        let latestDante = latestBlock(for: .dantePostRenderPreOutputGain, in: copiedBlocks)
        let newest = copiedBlocks.max { $0.framePosition < $1.framePosition } ?? copiedBlocks[copiedBlocks.startIndex]

        return MeterSnapshot(
            sessionVersion: newest.sessionVersion,
            sourceID: newest.sourceID,
            framePosition: newest.framePosition,
            inputMeters: latestInput.map { meters(for: $0, meterCalibrationGain: meterCalibrationGain) } ?? [],
            desktopMeters: latestDesktop.map { meters(for: $0, meterCalibrationGain: meterCalibrationGain) } ?? [],
            danteMeters: latestDante.map { meters(for: $0, meterCalibrationGain: meterCalibrationGain) } ?? [],
            timestampNanoseconds: nowNanoseconds()
        )
    }

    private func meter(
        for samples: [Float],
        meterCalibrationGain: LinearGain
    ) -> ChannelMeter {
        guard !samples.isEmpty else {
            return ChannelMeter(
                rmsDBFS: Self.silenceDBFS,
                peakDBFS: Self.silenceDBFS,
                vuDB: Self.silenceDBFS,
                normalizedLevel: 0,
                isClipped: false
            )
        }

        var energy: Float = 0
        var peak: Float = 0
        var clipped = false
        for sample in samples {
            let magnitude = abs(sample)
            energy += sample * sample
            peak = max(peak, magnitude)
            if magnitude >= clippingThreshold {
                clipped = true
            }
        }

        guard peak > 0 else {
            return ChannelMeter(
                rmsDBFS: Self.silenceDBFS,
                peakDBFS: Self.silenceDBFS,
                vuDB: Self.silenceDBFS,
                normalizedLevel: 0,
                isClipped: false
            )
        }

        let rms = sqrtf(energy / Float(samples.count))
        let rmsDBFS = dbFS(rms)
        let peakDBFS = dbFS(peak)
        let vuDB = rmsDBFS - referenceDBFS + dbGain(meterCalibrationGain)

        return ChannelMeter(
            rmsDBFS: rmsDBFS,
            peakDBFS: peakDBFS,
            vuDB: vuDB,
            normalizedLevel: normalizedLevel(forVU: vuDB),
            isClipped: clipped || peakDBFS >= 0
        )
    }

    private func latestBlock(
        for copyPoint: MeterCopyPoint,
        in copiedBlocks: [MeterCopiedBlock]
    ) -> MeterCopiedBlock? {
        copiedBlocks
            .filter { $0.copyPoint == copyPoint }
            .max { $0.framePosition < $1.framePosition }
    }

    private func dbFS(_ value: Float) -> Float {
        guard value > 0 else { return Self.silenceDBFS }
        return max(Self.silenceDBFS, 20 * log10f(value))
    }

    private func dbGain(_ gain: LinearGain) -> Float {
        guard gain.value > 0 else { return Self.silenceDBFS }
        return Float(20 * log10(gain.value))
    }

    private func normalizedLevel(forVU vuDB: Float) -> Float {
        min(max((vuDB + 36) / 42, 0), 1)
    }

    private func nowNanoseconds() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
    }
}

public final class PureAudioMeteringService: @unchecked Sendable {
    public let copyBus: MeterCopyBus
    public let accumulator: MeterAccumulator

    private let telemetry: AudioTelemetry?

    public init(
        copyBus: MeterCopyBus = MeterCopyBus(),
        accumulator: MeterAccumulator = MeterAccumulator(),
        telemetry: AudioTelemetry? = nil
    ) {
        self.copyBus = copyBus
        self.accumulator = accumulator
        self.telemetry = telemetry
    }

    @discardableResult
    public func publishLatestSnapshot(meterCalibrationGain: LinearGain = .unity) -> MeterSnapshot? {
        let copiedBlocks = copyBus.drainCopies()
        guard let snapshot = accumulator.snapshot(
            from: copiedBlocks,
            meterCalibrationGain: meterCalibrationGain
        ) else {
            return nil
        }
        telemetry?.updateMeterSnapshot(snapshot)
        return snapshot
    }
}
