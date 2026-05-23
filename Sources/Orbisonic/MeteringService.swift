import AVFoundation
import Foundation

enum MeterSignalID: String, Hashable, Sendable {
    case input
    case monitor
    case sonicSphere
}

enum VUMeterResponseMode: String, CaseIterable, Identifiable, Sendable {
    case smooth = "Smooth"
    case standard = "Standard"
    case fast = "Fast"

    var id: String { rawValue }

    var riseAlpha: Float {
        switch self {
        case .smooth:
            0.22
        case .standard:
            0.46
        case .fast:
            0.78
        }
    }

    var releaseAlpha: Float {
        switch self {
        case .smooth:
            0.06
        case .standard:
            0.14
        case .fast:
            0.28
        }
    }
}

struct VUMeterCalibrationSettings: Equatable, Sendable {
    static let defaultReferenceDbFS: Double = -18
    static let trimRange: ClosedRange<Double> = -6...6
    static let referenceRange: ClosedRange<Double> = -24...(-12)

    var referenceDbFS: Double
    var responseMode: VUMeterResponseMode
    var monitorTrimDb: Double
    var sonicSphereTrimDb: Double

    static let `default` = VUMeterCalibrationSettings(
        referenceDbFS: defaultReferenceDbFS,
        responseMode: .standard,
        monitorTrimDb: 0,
        sonicSphereTrimDb: 0
    )

    func clamped() -> VUMeterCalibrationSettings {
        VUMeterCalibrationSettings(
            referenceDbFS: Self.clamp(referenceDbFS, to: Self.referenceRange),
            responseMode: responseMode,
            monitorTrimDb: Self.clamp(monitorTrimDb, to: Self.trimRange),
            sonicSphereTrimDb: Self.clamp(sonicSphereTrimDb, to: Self.trimRange)
        )
    }

    func displayTrimDb(for signal: MeterSignalID) -> Float {
        switch signal {
        case .input:
            0
        case .monitor:
            Float(Self.clamp(monitorTrimDb, to: Self.trimRange))
        case .sonicSphere:
            Float(Self.clamp(sonicSphereTrimDb, to: Self.trimRange))
        }
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

struct MeterChannelLevel: Equatable, Sendable {
    static let silenceDbFS: Float = -120
    static let activePeakFloorDbFS: Float = -96

    var rawRMSDbFS: Float
    var peakDbFS: Float
    var vuDb: Float
    var displayLevel: Float

    static let silence = MeterChannelLevel(
        rawRMSDbFS: silenceDbFS,
        peakDbFS: silenceDbFS,
        vuDb: silenceDbFS,
        displayLevel: 0
    )
}

enum VUMeterDefaultsMigration {
    static let currentScaleVersion = 5

    static let scaleVersionKey = "Orbisonic.vuMeterScaleVersion"
    static let referenceDbFSKey = "Orbisonic.vuMeterReferenceDbFS"
    static let responseModeKey = "Orbisonic.vuMeterResponseMode"
    static let monitorTrimDbKey = "Orbisonic.vuMeterMonitorTrimDb"
    static let sonicSphereTrimDbKey = "Orbisonic.vuMeterSonicSphereTrimDb"

    private static let retiredKeys = [
        "Orbisonic.vuMeterInputVisualGainOffset",
        "Orbisonic.vuMeterMonitorVisualGainOffset",
        "Orbisonic.vuMeterRendererVisualGainOffset",
        "Orbisonic.vuMeterActivityCompressionOffset",
        "Orbisonic.vuMeterNormalizesVisualEnergy",
        "Orbisonic.vuMeterMatchesPanelActivity",
        "Orbisonic.vuMeterActivityMatchStrength",
        "Orbisonic.vuMeterTargetActivity",
        "Orbisonic.vuMeterInputActivityTrimOffset",
        "Orbisonic.vuMeterMonitorActivityTrimOffset",
        "Orbisonic.vuMeterRendererActivityTrimOffset",
        "Orbisonic.vuMeterResponseSpeed"
    ]

    @discardableResult
    static func migrate(defaults: UserDefaults) -> Bool {
        let storedVersion = defaults.integer(forKey: scaleVersionKey)
        guard storedVersion < currentScaleVersion else { return false }

        if storedVersion < 4 {
            retiredKeys.forEach { defaults.removeObject(forKey: $0) }
            defaults.set(VUMeterCalibrationSettings.default.referenceDbFS, forKey: referenceDbFSKey)
            defaults.set(VUMeterCalibrationSettings.default.responseMode.rawValue, forKey: responseModeKey)
            defaults.set(VUMeterCalibrationSettings.default.sonicSphereTrimDb, forKey: sonicSphereTrimDbKey)
        }
        if storedVersion < 5 {
            defaults.set(VUMeterCalibrationSettings.default.monitorTrimDb, forKey: monitorTrimDbKey)
        }
        defaults.set(currentScaleVersion, forKey: scaleVersionKey)
        return true
    }

    static func settings(defaults: UserDefaults) -> VUMeterCalibrationSettings {
        let responseMode = defaults.string(forKey: responseModeKey)
            .flatMap(VUMeterResponseMode.init(rawValue:))
            ?? VUMeterCalibrationSettings.default.responseMode

        return VUMeterCalibrationSettings(
            referenceDbFS: defaults.object(forKey: referenceDbFSKey) as? Double
                ?? VUMeterCalibrationSettings.default.referenceDbFS,
            responseMode: responseMode,
            monitorTrimDb: defaults.object(forKey: monitorTrimDbKey) as? Double
                ?? VUMeterCalibrationSettings.default.monitorTrimDb,
            sonicSphereTrimDb: defaults.object(forKey: sonicSphereTrimDbKey) as? Double
                ?? VUMeterCalibrationSettings.default.sonicSphereTrimDb
        ).clamped()
    }
}

struct MeteringSignalStatus: Equatable, Sendable {
    var signal: MeterSignalID
    var channelCount: Int
    var maxChannelCount: Int
    var droppedChannelMeasurementCount: Int
}

private final class MeteringCalibrationState {
    private let referenceDbFS = RealtimeAtomicFloat(Float(VUMeterCalibrationSettings.default.referenceDbFS))
    private let responseModeIndex = RealtimeAtomicInt(
        VUMeterResponseMode.allCases.firstIndex(of: VUMeterCalibrationSettings.default.responseMode) ?? 0
    )
    private let monitorTrimDb = RealtimeAtomicFloat(Float(VUMeterCalibrationSettings.default.monitorTrimDb))
    private let sonicSphereTrimDb = RealtimeAtomicFloat(Float(VUMeterCalibrationSettings.default.sonicSphereTrimDb))

    func store(_ nextCalibration: VUMeterCalibrationSettings) {
        let clamped = nextCalibration.clamped()
        referenceDbFS.store(Float(clamped.referenceDbFS))
        responseModeIndex.store(VUMeterResponseMode.allCases.firstIndex(of: clamped.responseMode) ?? 0)
        monitorTrimDb.store(Float(clamped.monitorTrimDb))
        sonicSphereTrimDb.store(Float(clamped.sonicSphereTrimDb))
    }

    func load() -> VUMeterCalibrationSettings {
        let responseModes = VUMeterResponseMode.allCases
        let index = min(max(responseModeIndex.load(), 0), responseModes.count - 1)
        return VUMeterCalibrationSettings(
            referenceDbFS: Double(referenceDbFS.load()),
            responseMode: responseModes[index],
            monitorTrimDb: Double(monitorTrimDb.load()),
            sonicSphereTrimDb: Double(sonicSphereTrimDb.load())
        ).clamped()
    }
}

private final class MeterRealtimeChannelState {
    private let rawRMSDbFS = RealtimeAtomicFloat(MeterChannelLevel.silenceDbFS)
    private let peakDbFS = RealtimeAtomicFloat(MeterChannelLevel.silenceDbFS)
    private let smoothedRMSDbFS = RealtimeAtomicFloat(MeterChannelLevel.silenceDbFS)

    func publish(rawRMSDbFS: Float, peakDbFS: Float) {
        self.rawRMSDbFS.store(rawRMSDbFS)
        self.peakDbFS.store(peakDbFS)
    }

    func reset() {
        rawRMSDbFS.store(MeterChannelLevel.silenceDbFS)
        peakDbFS.store(MeterChannelLevel.silenceDbFS)
        smoothedRMSDbFS.store(MeterChannelLevel.silenceDbFS)
    }

    func rawLevel() -> (rmsDbFS: Float, peakDbFS: Float) {
        (rawRMSDbFS.load(), peakDbFS.load())
    }

    func smoothedLevel(for rawRMSDbFS: Float, response: VUMeterResponseMode) -> Float {
        let current = smoothedRMSDbFS.load()
        let alpha = rawRMSDbFS > current ? response.riseAlpha : response.releaseAlpha
        let next: Float
        if current <= MeterChannelLevel.silenceDbFS + 0.1 {
            next = rawRMSDbFS
        } else {
            next = current + (rawRMSDbFS - current) * alpha
        }
        smoothedRMSDbFS.store(next)
        return next
    }
}

private final class MeterSignalRealtimeState {
    let maxChannelCount: Int
    let channels: [MeterRealtimeChannelState]
    private let active = RealtimeAtomicFlag()
    private let channelCount = RealtimeAtomicInt()
    private let droppedChannelMeasurementCount = RealtimeAtomicInt()

    init(maxChannelCount: Int) {
        self.maxChannelCount = max(maxChannelCount, 0)
        channels = (0..<self.maxChannelCount).map { _ in MeterRealtimeChannelState() }
    }

    func reset(channelCount requestedChannelCount: Int = 0) {
        let count = min(max(requestedChannelCount, 0), maxChannelCount)
        for channel in channels {
            channel.reset()
        }
        channelCount.store(count)
        active.store(false)
    }

    func publish(channelCount requestedChannelCount: Int, active isActive: Bool, droppedChannelCount: Int) {
        let count = min(max(requestedChannelCount, 0), maxChannelCount)
        channelCount.store(count)
        active.store(isActive)
        if droppedChannelCount > 0 {
            droppedChannelMeasurementCount.add(droppedChannelCount)
        }
        guard count < maxChannelCount else { return }
        for index in count..<maxChannelCount {
            channels[index].reset()
        }
    }

    func isActive() -> Bool {
        active.load()
    }

    func status(signal: MeterSignalID) -> MeteringSignalStatus {
        MeteringSignalStatus(
            signal: signal,
            channelCount: channelCount.load(),
            maxChannelCount: maxChannelCount,
            droppedChannelMeasurementCount: droppedChannelMeasurementCount.load()
        )
    }
}

final class MeteringService {
    static let maxRealtimeChannelCount = OrbisonicAudioLimits.maxSourceChannelCount

    private let calibration = MeteringCalibrationState()
    private let inputState = MeterSignalRealtimeState(maxChannelCount: MeteringService.maxRealtimeChannelCount)
    private let monitorState = MeterSignalRealtimeState(maxChannelCount: MeteringService.maxRealtimeChannelCount)
    private let sonicSphereState = MeterSignalRealtimeState(maxChannelCount: MeteringService.maxRealtimeChannelCount)

    func updateCalibration(_ nextCalibration: VUMeterCalibrationSettings) {
        calibration.store(nextCalibration)
    }

    func resetAll() {
        inputState.reset()
        monitorState.reset()
        sonicSphereState.reset()
    }

    func reset(signal: MeterSignalID, channelCount: Int = 0) {
        state(for: signal).reset(channelCount: channelCount)
    }

    func setInactive(signal: MeterSignalID, channelCount: Int) {
        reset(signal: signal, channelCount: channelCount)
    }

    func isActive(signal: MeterSignalID) -> Bool {
        state(for: signal).isActive()
    }

    func status(signal: MeterSignalID) -> MeteringSignalStatus {
        state(for: signal).status(signal: signal)
    }

    func levels(signal: MeterSignalID, channelCount: Int? = nil) -> [MeterChannelLevel] {
        let currentCalibration = calibration.load()
        let currentState = state(for: signal)
        let status = currentState.status(signal: signal)
        let requestedCount = channelCount ?? status.channelCount
        let targetCount = min(max(requestedCount, 0), currentState.maxChannelCount)
        guard targetCount > 0 else { return [] }

        guard currentState.isActive() else {
            return Array(repeating: MeterChannelLevel.silence, count: targetCount)
        }

        var levels: [MeterChannelLevel] = []
        levels.reserveCapacity(targetCount)
        for channelIndex in 0..<targetCount {
            guard channelIndex < status.channelCount else {
                levels.append(.silence)
                continue
            }
            let channelState = currentState.channels[channelIndex]
            let rawLevel = channelState.rawLevel()
            let smoothedRMSDbFS = channelState.smoothedLevel(
                for: rawLevel.rmsDbFS,
                response: currentCalibration.responseMode
            )
            levels.append(
                Self.channelLevel(
                    rawRMSDbFS: rawLevel.rmsDbFS,
                    peakDbFS: rawLevel.peakDbFS,
                    smoothedRMSDbFS: smoothedRMSDbFS,
                    signal: signal,
                    calibration: currentCalibration
                )
            )
        }
        return levels
    }

    func ingest(
        signal: MeterSignalID,
        bufferList: UnsafeMutableAudioBufferListPointer,
        frameCount: Int
    ) {
        guard frameCount > 0 else { return }
        let currentState = state(for: signal)
        let channelLimit = min(bufferList.count, currentState.maxChannelCount)
        var anyActive = false

        for channelIndex in 0..<channelLimit {
            let buffer = bufferList[channelIndex]
            let measurement: (rmsDbFS: Float, peakDbFS: Float)
            if let rawData = buffer.mData {
                let availableFrames = Int(buffer.mDataByteSize) / MemoryLayout<Float>.stride
                let frames = min(frameCount, availableFrames)
                if frames > 0 {
                    measurement = Self.measure(samples: rawData.assumingMemoryBound(to: Float.self), frameCount: frames)
                } else {
                    measurement = (MeterChannelLevel.silenceDbFS, MeterChannelLevel.silenceDbFS)
                }
            } else {
                measurement = (MeterChannelLevel.silenceDbFS, MeterChannelLevel.silenceDbFS)
            }
            currentState.channels[channelIndex].publish(
                rawRMSDbFS: measurement.rmsDbFS,
                peakDbFS: measurement.peakDbFS
            )
            anyActive = anyActive || measurement.peakDbFS > MeterChannelLevel.activePeakFloorDbFS
        }

        currentState.publish(
            channelCount: channelLimit,
            active: anyActive,
            droppedChannelCount: max(bufferList.count - currentState.maxChannelCount, 0)
        )
    }

    func ingest(
        signal: MeterSignalID,
        buffers: [AVAudioPCMBuffer],
        startFrame: Int,
        frameCount: Int
    ) {
        guard frameCount > 0 else { return }
        let currentState = state(for: signal)
        let channelLimit = min(buffers.count, currentState.maxChannelCount)
        var anyActive = false

        for channelIndex in 0..<channelLimit {
            let buffer = buffers[channelIndex]
            let measurement: (rmsDbFS: Float, peakDbFS: Float)
            if let channelData = buffer.floatChannelData {
                let frameLength = Int(buffer.frameLength)
                if frameLength > 0 {
                    let start = max(0, min(startFrame, frameLength - 1))
                    let frames = min(frameCount, frameLength - start)
                    measurement = frames > 0
                        ? Self.measure(samples: channelData[0].advanced(by: start), frameCount: frames)
                        : (MeterChannelLevel.silenceDbFS, MeterChannelLevel.silenceDbFS)
                } else {
                    measurement = (MeterChannelLevel.silenceDbFS, MeterChannelLevel.silenceDbFS)
                }
            } else {
                measurement = (MeterChannelLevel.silenceDbFS, MeterChannelLevel.silenceDbFS)
            }
            currentState.channels[channelIndex].publish(
                rawRMSDbFS: measurement.rmsDbFS,
                peakDbFS: measurement.peakDbFS
            )
            anyActive = anyActive || measurement.peakDbFS > MeterChannelLevel.activePeakFloorDbFS
        }

        currentState.publish(
            channelCount: channelLimit,
            active: anyActive,
            droppedChannelCount: max(buffers.count - currentState.maxChannelCount, 0)
        )
    }

    func ingest(
        signal: MeterSignalID,
        buffer: AVAudioPCMBuffer,
        startFrame: Int,
        frameCount: Int
    ) {
        guard frameCount > 0,
              let channelData = buffer.floatChannelData
        else { return }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        let start = max(0, min(startFrame, frameLength - 1))
        let frames = min(frameCount, frameLength - start)
        guard frames > 0 else { return }

        let currentState = state(for: signal)
        let bufferChannelCount = Int(buffer.format.channelCount)
        let channelLimit = min(bufferChannelCount, currentState.maxChannelCount)
        var anyActive = false
        for channelIndex in 0..<channelLimit {
            let measurement = Self.measure(
                samples: channelData[channelIndex].advanced(by: start),
                frameCount: frames
            )
            currentState.channels[channelIndex].publish(
                rawRMSDbFS: measurement.rmsDbFS,
                peakDbFS: measurement.peakDbFS
            )
            anyActive = anyActive || measurement.peakDbFS > MeterChannelLevel.activePeakFloorDbFS
        }

        currentState.publish(
            channelCount: channelLimit,
            active: anyActive,
            droppedChannelCount: max(bufferChannelCount - currentState.maxChannelCount, 0)
        )
    }

    func ingest(
        signal: MeterSignalID,
        sampleBuffers: [[Float]],
        frameCount: Int
    ) {
        guard frameCount > 0 else { return }
        let currentState = state(for: signal)
        let channelLimit = min(sampleBuffers.count, currentState.maxChannelCount)
        var anyActive = false

        for channelIndex in 0..<channelLimit {
            let samples = sampleBuffers[channelIndex]
            let frames = min(frameCount, samples.count)
            let measurement = samples.withUnsafeBufferPointer { buffer -> (rmsDbFS: Float, peakDbFS: Float) in
                guard frames > 0, let baseAddress = buffer.baseAddress else {
                    return (MeterChannelLevel.silenceDbFS, MeterChannelLevel.silenceDbFS)
                }
                return Self.measure(samples: baseAddress, frameCount: frames)
            }
            currentState.channels[channelIndex].publish(
                rawRMSDbFS: measurement.rmsDbFS,
                peakDbFS: measurement.peakDbFS
            )
            anyActive = anyActive || measurement.peakDbFS > MeterChannelLevel.activePeakFloorDbFS
        }

        currentState.publish(
            channelCount: channelLimit,
            active: anyActive,
            droppedChannelCount: max(sampleBuffers.count - currentState.maxChannelCount, 0)
        )
    }

    private func state(for signal: MeterSignalID) -> MeterSignalRealtimeState {
        switch signal {
        case .input:
            inputState
        case .monitor:
            monitorState
        case .sonicSphere:
            sonicSphereState
        }
    }

    private static func measure(samples: UnsafePointer<Float>, frameCount: Int) -> (rmsDbFS: Float, peakDbFS: Float) {
        guard frameCount > 0 else {
            return (MeterChannelLevel.silenceDbFS, MeterChannelLevel.silenceDbFS)
        }

        var energy: Float = 0
        var peak: Float = 0
        for index in 0..<frameCount {
            let sample = samples[index]
            energy += sample * sample
            peak = max(peak, abs(sample))
        }

        guard peak > 0 else {
            return (MeterChannelLevel.silenceDbFS, MeterChannelLevel.silenceDbFS)
        }

        let rms = sqrtf(energy / Float(frameCount))
        return (dbFS(for: rms), dbFS(for: peak))
    }

    private static func channelLevel(
        rawRMSDbFS: Float,
        peakDbFS: Float,
        smoothedRMSDbFS: Float,
        signal: MeterSignalID,
        calibration: VUMeterCalibrationSettings
    ) -> MeterChannelLevel {
        let reference = Float(calibration.referenceDbFS)
        let vuDb = smoothedRMSDbFS - reference + calibration.displayTrimDb(for: signal)
        return MeterChannelLevel(
            rawRMSDbFS: rawRMSDbFS,
            peakDbFS: peakDbFS,
            vuDb: vuDb,
            displayLevel: displayLevel(forVU: vuDb, peakDbFS: peakDbFS)
        )
    }

    private static func dbFS(for value: Float) -> Float {
        20 * log10f(max(value, 0.000_001))
    }

    private static func displayLevel(forVU vuDb: Float, peakDbFS: Float) -> Float {
        let mappedLevel = min(max((vuDb + 36) / 42, 0), 1)
        guard mappedLevel == 0, peakDbFS > MeterChannelLevel.activePeakFloorDbFS else {
            return mappedLevel
        }

        let tailStartVUDB: Float = -36
        let tailEndVUDB: Float = -78
        let tailMaxLevel: Float = 0.012
        let tailPosition = min(max((vuDb - tailEndVUDB) / (tailStartVUDB - tailEndVUDB), 0), 1)
        return tailPosition * tailMaxLevel
    }
}
