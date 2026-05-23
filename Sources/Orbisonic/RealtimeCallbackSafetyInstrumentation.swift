import Darwin
import Foundation

enum RealtimeCallbackGateStatus: String, Equatable, Sendable {
    case passed
    case warning
    case blocked
}

enum RealtimeDenormalHandlingStatus: String, Equatable, Sendable {
    case notVerified = "not verified"
    case flushToZeroVerified = "flush-to-zero verified"
    case notApplicable = "not applicable"
}

enum RealtimeRouteMismatchBehavior: String, Equatable, Sendable {
    case blockedBeforeArming = "blocked before arming"
    case notExercised = "not exercised"
    case silentlyAccepted = "silently accepted"
}

struct RealtimeCallbackPerformanceBudget: Equatable, Sendable {
    var p95BlockFraction: Double
    var p99BlockFraction: Double
    var maxBlockFraction: Double
    var requiredDeadlineMissCount: Int

    static let familyStartingPoint = RealtimeCallbackPerformanceBudget(
        p95BlockFraction: 0.50,
        p99BlockFraction: 0.70,
        maxBlockFraction: 0.90,
        requiredDeadlineMissCount: 0
    )
}

struct RealtimeCallbackStressScene: Equatable, Sendable {
    var name: String
    var sampleRate: Double
    var minimumBlockSize: Int
    var maximumBlockSize: Int
    var inputChannelCount: Int
    var outputChannelCount: Int
    var activeSourceDescription: String
    var eventBurstDescription: String
    var uiActive: Bool
    var metersActive: Bool
    var telemetryActive: Bool
    var routeValidationBeforeArming: Bool
    var panicStopBehavior: String
    var durationSeconds: Double

    static let orbisonicMaximumConfigured = RealtimeCallbackStressScene(
        name: "Orbisonic maximum configured realtime callback stress",
        sampleRate: 48_000,
        minimumBlockSize: 128,
        maximumBlockSize: Int(LiveInputCapture.maxCallbackFrameCapacity),
        inputChannelCount: OrbisonicAudioLimits.maxSourceChannelCount,
        outputChannelCount: 31,
        activeSourceDescription: "maximum configured live source channels with Sonic Sphere analysis meters active",
        eventBurstDescription: "bursty route, meter, telemetry, and stop/panic events are coalesced or dropped outside audio",
        uiActive: true,
        metersActive: true,
        telemetryActive: true,
        routeValidationBeforeArming: true,
        panicStopBehavior: "stop transport, publish failure state, and keep callbacks bounded without retrying inside audio",
        durationSeconds: 60
    )

    var blockSizeRangeDescription: String {
        minimumBlockSize == maximumBlockSize
            ? "\(minimumBlockSize)"
            : "\(minimumBlockSize)-\(maximumBlockSize)"
    }
}

struct RealtimeCallbackTimingSummary: Equatable, Sendable {
    var callbackCount: Int
    var sampleRate: Double
    var minimumBlockSize: Int
    var maximumBlockSize: Int
    var p50Nanoseconds: Int
    var p95Nanoseconds: Int
    var p99Nanoseconds: Int
    var maxNanoseconds: Int
    var deadlineMissCount: Int

    var minimumBlockDurationNanoseconds: Double {
        guard sampleRate > 0, minimumBlockSize > 0 else { return 0 }
        return Double(minimumBlockSize) / sampleRate * 1_000_000_000
    }

    var p95CPUPercentOfMinimumBlock: Double {
        guard minimumBlockDurationNanoseconds > 0 else { return 0 }
        return Double(p95Nanoseconds) / minimumBlockDurationNanoseconds * 100
    }
}

struct RealtimeCallbackSafetyCounters: Equatable, Sendable {
    var callbackAllocationCount: Int
    var callbackDeallocationCount: Int
    var callbackBlockingLockCount: Int
    var callbackWaitSleepCount: Int
    var maxEventsDrainedPerBlock: Int
    var eventDropOrCoalesceCount: Int
    var telemetryDropCount: Int
    var meterDropOrCoalesceCount: Int
    var routeMismatchBlockCount: Int
}

struct RealtimeCallbackSafetyReport: Equatable, Sendable {
    var scene: RealtimeCallbackStressScene
    var budget: RealtimeCallbackPerformanceBudget
    var timing: RealtimeCallbackTimingSummary
    var counters: RealtimeCallbackSafetyCounters
    var denormalHandlingStatus: RealtimeDenormalHandlingStatus
    var routeMismatchBehavior: RealtimeRouteMismatchBehavior
    var evidenceGaps: [String]

    var blockingReasons: [String] {
        var reasons: [String] = []
        if timing.callbackCount == 0 {
            reasons.append("no callback samples recorded")
        }
        if counters.callbackAllocationCount > 0 {
            reasons.append("callback allocations are nonzero")
        }
        if counters.callbackDeallocationCount > 0 {
            reasons.append("callback deallocations are nonzero")
        }
        if counters.callbackBlockingLockCount > 0 {
            reasons.append("callback blocking locks are nonzero")
        }
        if counters.callbackWaitSleepCount > 0 {
            reasons.append("callback waits/sleeps are nonzero")
        }
        if timing.deadlineMissCount > budget.requiredDeadlineMissCount {
            reasons.append("deadline misses are nonzero")
        }
        let blockDuration = timing.minimumBlockDurationNanoseconds
        if blockDuration > 0 {
            if Double(timing.p99Nanoseconds) > blockDuration * budget.p99BlockFraction {
                reasons.append("p99 callback duration exceeds budget")
            }
            if Double(timing.maxNanoseconds) > blockDuration * budget.maxBlockFraction {
                reasons.append("max callback duration exceeds qualification budget")
            }
        }
        if routeMismatchBehavior == .silentlyAccepted {
            reasons.append("route mismatch is silently accepted")
        }
        return reasons
    }

    var warnings: [String] {
        var warnings = evidenceGaps
        if denormalHandlingStatus == .notVerified {
            warnings.append("denormal handling is not verified")
        }
        if routeMismatchBehavior == .notExercised {
            warnings.append("route mismatch behavior was not exercised")
        }
        let blockDuration = timing.minimumBlockDurationNanoseconds
        if blockDuration > 0,
           Double(timing.p95Nanoseconds) > blockDuration * budget.p95BlockFraction {
            warnings.append("p95 callback duration exceeds warning budget")
        }
        return warnings
    }

    var gateStatus: RealtimeCallbackGateStatus {
        if !blockingReasons.isEmpty {
            return .blocked
        }
        return warnings.isEmpty ? .passed : .warning
    }

    var requiredMetricLabels: [String] {
        [
            "sample rate",
            "block size range",
            "callback duration p50",
            "callback duration p95",
            "callback duration p99",
            "callback duration max",
            "deadline miss count",
            "callback allocation count",
            "callback deallocation count",
            "callback blocking-lock count",
            "callback wait/sleep count",
            "max events drained per block",
            "event drops/coalesces",
            "telemetry drops",
            "meter drops/coalesces",
            "CPU load under stress",
            "denormal handling status",
            "route mismatch behavior"
        ]
    }

    var textSummary: String {
        [
            "Stress scene: \(scene.name)",
            "Gate status: \(gateStatus.rawValue)",
            "Sample rate: \(Int(scene.sampleRate)) Hz",
            "Block size range: \(scene.blockSizeRangeDescription) frames",
            "Input channels: \(scene.inputChannelCount)",
            "Output channels: \(scene.outputChannelCount)",
            "p50 callback duration: \(timing.p50Nanoseconds) ns",
            "p95 callback duration: \(timing.p95Nanoseconds) ns",
            "p99 callback duration: \(timing.p99Nanoseconds) ns",
            "max callback duration: \(timing.maxNanoseconds) ns",
            "Deadline misses: \(timing.deadlineMissCount)",
            "Callback allocations: \(counters.callbackAllocationCount)",
            "Callback deallocations: \(counters.callbackDeallocationCount)",
            "Callback blocking locks: \(counters.callbackBlockingLockCount)",
            "Callback waits/sleeps: \(counters.callbackWaitSleepCount)",
            "Max events drained per block: \(counters.maxEventsDrainedPerBlock)",
            "Event drops/coalesces: \(counters.eventDropOrCoalesceCount)",
            "Telemetry drops: \(counters.telemetryDropCount)",
            "Meter drops/coalesces: \(counters.meterDropOrCoalesceCount)",
            "CPU load p95: \(String(format: "%.2f", timing.p95CPUPercentOfMinimumBlock))%",
            "Denormal handling: \(denormalHandlingStatus.rawValue)",
            "Route mismatch behavior: \(routeMismatchBehavior.rawValue)"
        ].joined(separator: "\n")
    }
}

struct RealtimeCallbackTraceToken: Equatable, Sendable {
    fileprivate var startTick: UInt64
    fileprivate var blockSize: Int
}

final class RealtimeCallbackSafetyProbe {
    let sampleRate: Double
    let budget: RealtimeCallbackPerformanceBudget

    private let sampleCapacity: Int
    private let durationsNanoseconds: [RealtimeAtomicInt]
    private let blockSizes: [RealtimeAtomicInt]
    private let nextSampleIndex = RealtimeAtomicInt()
    private let callbackCount = RealtimeAtomicInt()
    private let deadlineMissCount = RealtimeAtomicInt()
    private let callbackAllocationCount = RealtimeAtomicInt()
    private let callbackDeallocationCount = RealtimeAtomicInt()
    private let callbackBlockingLockCount = RealtimeAtomicInt()
    private let callbackWaitSleepCount = RealtimeAtomicInt()
    private let maxEventsDrainedPerBlock = RealtimeAtomicInt()
    private let eventDropOrCoalesceCount = RealtimeAtomicInt()
    private let telemetryDropCount = RealtimeAtomicInt()
    private let meterDropOrCoalesceCount = RealtimeAtomicInt()
    private let routeMismatchBlockCount = RealtimeAtomicInt()
    private let timebaseNumer: UInt64
    private let timebaseDenom: UInt64

    init(
        sampleRate: Double,
        budget: RealtimeCallbackPerformanceBudget = .familyStartingPoint,
        sampleCapacity: Int = 8_192
    ) {
        self.sampleRate = sampleRate
        self.budget = budget
        self.sampleCapacity = max(sampleCapacity, 1)
        durationsNanoseconds = (0..<self.sampleCapacity).map { _ in RealtimeAtomicInt() }
        blockSizes = (0..<self.sampleCapacity).map { _ in RealtimeAtomicInt() }

        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        timebaseNumer = UInt64(max(timebase.numer, 1))
        timebaseDenom = UInt64(max(timebase.denom, 1))
    }

    func begin(blockSize: Int) -> RealtimeCallbackTraceToken {
        RealtimeCallbackTraceToken(
            startTick: mach_absolute_time(),
            blockSize: max(blockSize, 0)
        )
    }

    func end(_ token: RealtimeCallbackTraceToken) {
        let elapsedTicks = mach_absolute_time() &- token.startTick
        let elapsedNanoseconds = Int((elapsedTicks &* timebaseNumer) / timebaseDenom)
        recordCallbackDuration(nanoseconds: elapsedNanoseconds, blockSize: token.blockSize)
    }

    func recordCallbackDuration(nanoseconds: Int, blockSize: Int) {
        let sampleIndex = nextSampleIndex.load()
        nextSampleIndex.add(1)
        callbackCount.add(1)

        let slot = sampleIndex % sampleCapacity
        let clampedDuration = max(nanoseconds, 0)
        let clampedBlockSize = max(blockSize, 0)
        durationsNanoseconds[slot].store(clampedDuration)
        blockSizes[slot].store(clampedBlockSize)

        if sampleRate > 0, clampedBlockSize > 0 {
            let blockDurationNanoseconds = Double(clampedBlockSize) / sampleRate * 1_000_000_000
            if Double(clampedDuration) > blockDurationNanoseconds {
                deadlineMissCount.add(1)
            }
        }
    }

    func recordCallbackAllocation(count: Int = 1) {
        callbackAllocationCount.add(max(count, 0))
    }

    func recordCallbackDeallocation(count: Int = 1) {
        callbackDeallocationCount.add(max(count, 0))
    }

    func recordBlockingLock(count: Int = 1) {
        callbackBlockingLockCount.add(max(count, 0))
    }

    func recordWaitOrSleep(count: Int = 1) {
        callbackWaitSleepCount.add(max(count, 0))
    }

    func recordEventsDrained(count: Int) {
        maxEventsDrainedPerBlock.max(count)
    }

    func recordEventDropOrCoalesce(count: Int = 1) {
        eventDropOrCoalesceCount.add(max(count, 0))
    }

    func recordTelemetryDrop(count: Int = 1) {
        telemetryDropCount.add(max(count, 0))
    }

    func recordMeterDropOrCoalesce(count: Int = 1) {
        meterDropOrCoalesceCount.add(max(count, 0))
    }

    func recordRouteMismatchBlocked(count: Int = 1) {
        routeMismatchBlockCount.add(max(count, 0))
    }

    func report(
        scene: RealtimeCallbackStressScene = .orbisonicMaximumConfigured,
        denormalHandlingStatus: RealtimeDenormalHandlingStatus = .notVerified,
        routeMismatchBehavior: RealtimeRouteMismatchBehavior = .notExercised,
        evidenceGaps: [String] = []
    ) -> RealtimeCallbackSafetyReport {
        RealtimeCallbackSafetyReport(
            scene: scene,
            budget: budget,
            timing: timingSummary(),
            counters: RealtimeCallbackSafetyCounters(
                callbackAllocationCount: callbackAllocationCount.load(),
                callbackDeallocationCount: callbackDeallocationCount.load(),
                callbackBlockingLockCount: callbackBlockingLockCount.load(),
                callbackWaitSleepCount: callbackWaitSleepCount.load(),
                maxEventsDrainedPerBlock: maxEventsDrainedPerBlock.load(),
                eventDropOrCoalesceCount: eventDropOrCoalesceCount.load(),
                telemetryDropCount: telemetryDropCount.load(),
                meterDropOrCoalesceCount: meterDropOrCoalesceCount.load(),
                routeMismatchBlockCount: routeMismatchBlockCount.load()
            ),
            denormalHandlingStatus: denormalHandlingStatus,
            routeMismatchBehavior: routeMismatchBehavior,
            evidenceGaps: evidenceGaps
        )
    }

    private func timingSummary() -> RealtimeCallbackTimingSummary {
        let totalSamples = callbackCount.load()
        let storedSampleCount = min(totalSamples, sampleCapacity)
        var durations: [Int] = []
        var observedBlockSizes: [Int] = []
        durations.reserveCapacity(storedSampleCount)
        observedBlockSizes.reserveCapacity(storedSampleCount)

        for index in 0..<storedSampleCount {
            durations.append(durationsNanoseconds[index].load())
            let blockSize = blockSizes[index].load()
            if blockSize > 0 {
                observedBlockSizes.append(blockSize)
            }
        }

        durations.sort()
        let minBlockSize = observedBlockSizes.min() ?? 0
        let maxBlockSize = observedBlockSizes.max() ?? 0

        return RealtimeCallbackTimingSummary(
            callbackCount: totalSamples,
            sampleRate: sampleRate,
            minimumBlockSize: minBlockSize,
            maximumBlockSize: maxBlockSize,
            p50Nanoseconds: Self.percentile(durations, fraction: 0.50),
            p95Nanoseconds: Self.percentile(durations, fraction: 0.95),
            p99Nanoseconds: Self.percentile(durations, fraction: 0.99),
            maxNanoseconds: durations.last ?? 0,
            deadlineMissCount: deadlineMissCount.load()
        )
    }

    private static func percentile(_ sortedValues: [Int], fraction: Double) -> Int {
        guard !sortedValues.isEmpty else { return 0 }
        let clampedFraction = min(max(fraction, 0), 1)
        let rawIndex = Int(ceil(clampedFraction * Double(sortedValues.count))) - 1
        let index = min(max(rawIndex, 0), sortedValues.count - 1)
        return sortedValues[index]
    }
}

enum RealtimeCallbackStressHarness {
    static func standardSyntheticReport() -> RealtimeCallbackSafetyReport {
        let scene = RealtimeCallbackStressScene.orbisonicMaximumConfigured
        let probe = RealtimeCallbackSafetyProbe(sampleRate: scene.sampleRate)
        let blockSizes = [128, 256, 512, 1_024]
        for index in 0..<512 {
            let blockSize = blockSizes[index % blockSizes.count]
            let duration = 40_000 + (index % 17) * 1_000
            probe.recordCallbackDuration(nanoseconds: duration, blockSize: blockSize)
        }
        probe.recordEventsDrained(count: 16)
        probe.recordEventDropOrCoalesce(count: 2)
        probe.recordTelemetryDrop(count: 1)
        probe.recordMeterDropOrCoalesce(count: 3)
        probe.recordRouteMismatchBlocked()
        return probe.report(
            scene: scene,
            denormalHandlingStatus: .notVerified,
            routeMismatchBehavior: .blockedBeforeArming,
            evidenceGaps: [
                "malloc/free interposition is not installed; allocation counts cover explicit callback hooks only",
                "blocking lock and wait/sleep counts cover explicit hooks plus static source guards only"
            ]
        )
    }
}
