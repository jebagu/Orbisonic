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

final class MeteringService {
    private struct ChannelState {
        var rawRMSDbFS: Float = MeterChannelLevel.silenceDbFS
        var peakDbFS: Float = MeterChannelLevel.silenceDbFS
        var smoothedRMSDbFS: Float = MeterChannelLevel.silenceDbFS
    }

    private let lock = NSLock()
    private var calibration = VUMeterCalibrationSettings.default
    private var states: [MeterSignalID: [ChannelState]] = [:]
    private var activeSignals: Set<MeterSignalID> = []

    func updateCalibration(_ nextCalibration: VUMeterCalibrationSettings) {
        lock.lock()
        calibration = nextCalibration.clamped()
        lock.unlock()
    }

    func resetAll() {
        lock.lock()
        states.removeAll()
        activeSignals.removeAll()
        lock.unlock()
    }

    func reset(signal: MeterSignalID, channelCount: Int = 0) {
        lock.lock()
        states[signal] = Array(repeating: ChannelState(), count: max(channelCount, 0))
        activeSignals.remove(signal)
        lock.unlock()
    }

    func setInactive(signal: MeterSignalID, channelCount: Int) {
        reset(signal: signal, channelCount: channelCount)
    }

    func isActive(signal: MeterSignalID) -> Bool {
        lock.lock()
        let active = activeSignals.contains(signal)
        lock.unlock()
        return active
    }

    func levels(signal: MeterSignalID, channelCount: Int? = nil) -> [MeterChannelLevel] {
        lock.lock()
        let currentCalibration = calibration
        let currentStates = states[signal] ?? []
        let isActive = activeSignals.contains(signal)
        lock.unlock()

        let targetCount = channelCount ?? currentStates.count
        guard targetCount > 0 else { return [] }

        let paddedStates: [ChannelState]
        if currentStates.count >= targetCount {
            paddedStates = Array(currentStates.prefix(targetCount))
        } else {
            paddedStates = currentStates + Array(
                repeating: ChannelState(),
                count: targetCount - currentStates.count
            )
        }

        guard isActive else {
            return Array(repeating: MeterChannelLevel.silence, count: targetCount)
        }

        return paddedStates.map { channelState in
            Self.channelLevel(
                state: channelState,
                signal: signal,
                calibration: currentCalibration
            )
        }
    }

    func ingest(
        signal: MeterSignalID,
        bufferList: UnsafeMutableAudioBufferListPointer,
        frameCount: Int
    ) {
        guard frameCount > 0 else { return }
        let measurements = bufferList.compactMap { buffer -> (rmsDbFS: Float, peakDbFS: Float)? in
            guard let rawData = buffer.mData else { return nil }
            let availableFrames = Int(buffer.mDataByteSize) / MemoryLayout<Float>.stride
            let frames = min(frameCount, availableFrames)
            guard frames > 0 else { return nil }
            return Self.measure(samples: rawData.assumingMemoryBound(to: Float.self), frameCount: frames)
        }
        update(signal: signal, measurements: measurements)
    }

    func ingest(
        signal: MeterSignalID,
        buffers: [AVAudioPCMBuffer],
        startFrame: Int,
        frameCount: Int
    ) {
        guard frameCount > 0 else { return }
        let measurements = buffers.compactMap { buffer -> (rmsDbFS: Float, peakDbFS: Float)? in
            guard let channelData = buffer.floatChannelData else { return nil }
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else { return nil }
            let start = max(0, min(startFrame, frameLength - 1))
            let frames = min(frameCount, frameLength - start)
            guard frames > 0 else { return nil }
            return Self.measure(samples: channelData[0].advanced(by: start), frameCount: frames)
        }
        update(signal: signal, measurements: measurements)
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

        let channelCount = Int(buffer.format.channelCount)
        let measurements = (0..<channelCount).map { channel -> (rmsDbFS: Float, peakDbFS: Float) in
            Self.measure(samples: channelData[channel].advanced(by: start), frameCount: frames)
        }
        update(signal: signal, measurements: measurements)
    }

    func ingest(
        signal: MeterSignalID,
        sampleBuffers: [[Float]],
        frameCount: Int
    ) {
        guard frameCount > 0 else { return }
        let measurements = sampleBuffers.compactMap { samples -> (rmsDbFS: Float, peakDbFS: Float)? in
            let frames = min(frameCount, samples.count)
            guard frames > 0 else { return nil }
            return samples.withUnsafeBufferPointer { buffer in
                guard let baseAddress = buffer.baseAddress else { return nil }
                return Self.measure(samples: baseAddress, frameCount: frames)
            }
        }
        update(signal: signal, measurements: measurements)
    }

    private func update(signal: MeterSignalID, measurements: [(rmsDbFS: Float, peakDbFS: Float)]) {
        lock.lock()
        defer { lock.unlock() }

        guard !measurements.isEmpty else {
            states[signal] = []
            activeSignals.remove(signal)
            return
        }

        var currentStates = states[signal] ?? []
        if currentStates.count != measurements.count {
            currentStates = Array(repeating: ChannelState(), count: measurements.count)
        }

        let response = calibration.responseMode
        for index in measurements.indices {
            let measurement = measurements[index]
            var state = currentStates[index]
            let alpha = measurement.rmsDbFS > state.smoothedRMSDbFS
                ? response.riseAlpha
                : response.releaseAlpha
            state.rawRMSDbFS = measurement.rmsDbFS
            state.peakDbFS = measurement.peakDbFS
            if state.smoothedRMSDbFS <= MeterChannelLevel.silenceDbFS + 0.1 {
                state.smoothedRMSDbFS = measurement.rmsDbFS
            } else {
                state.smoothedRMSDbFS = state.smoothedRMSDbFS + (measurement.rmsDbFS - state.smoothedRMSDbFS) * alpha
            }
            currentStates[index] = state
        }

        states[signal] = currentStates
        if measurements.contains(where: { $0.peakDbFS > MeterChannelLevel.activePeakFloorDbFS }) {
            activeSignals.insert(signal)
        } else {
            activeSignals.remove(signal)
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
        state: ChannelState,
        signal: MeterSignalID,
        calibration: VUMeterCalibrationSettings
    ) -> MeterChannelLevel {
        let reference = Float(calibration.referenceDbFS)
        let vuDb = state.smoothedRMSDbFS - reference + calibration.displayTrimDb(for: signal)
        return MeterChannelLevel(
            rawRMSDbFS: state.rawRMSDbFS,
            peakDbFS: state.peakDbFS,
            vuDb: vuDb,
            displayLevel: displayLevel(forVU: vuDb, peakDbFS: state.peakDbFS)
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
