import AVFoundation
import Foundation

struct LiveInputSource {
    let layout: SurroundLayout
    let metadata: AudioSourceMetadata
}

enum LiveInputError: LocalizedError {
    case inputDeviceUnavailable(String)
    case inputDeviceSelectionFailed(deviceName: String, status: OSStatus)
    case inputAudioUnitUnavailable(String)
    case noInputChannels
    case unsupportedChannelRequest(requested: Int, available: UInt32)
    case monoFormatCreationFailed(Double)

    var errorDescription: String? {
        switch self {
        case .inputDeviceUnavailable(let deviceName):
            "The selected input device is not available: \(deviceName)."
        case .inputDeviceSelectionFailed(let deviceName, let status):
            "Unable to capture \(deviceName) directly. Core Audio returned \(status)."
        case .inputAudioUnitUnavailable(let deviceName):
            "Unable to access the Core Audio input unit for \(deviceName)."
        case .noInputChannels:
            "The selected input device has no input channels."
        case .unsupportedChannelRequest(let requested, let available):
            "Requested \(requested) live input channels, but the current input device exposes \(available)."
        case .monoFormatCreationFailed(let sampleRate):
            "Unable to create a live mono render format at \(sampleRate) Hz."
        }
    }
}

final class LiveChannelRingBuffer {
    private var storage: [Float]
    private var readIndex = 0
    private var writeIndex = 0
    private var availableFrames = 0
    private let targetLatencyFrames: Int
    private let highWaterFrames: Int
    private var isPriming = true
    private var underflowCount = 0
    private var underflowFrames = 0
    private var overflowDropFrames = 0
    private let lock = NSLock()

    init(capacity: Int, targetLatencyFrames: Int, highWaterFrames: Int) {
        let clampedCapacity = max(capacity, 1_024)
        storage = Array(repeating: 0, count: clampedCapacity)
        self.targetLatencyFrames = min(max(targetLatencyFrames, 1), clampedCapacity)
        self.highWaterFrames = min(max(highWaterFrames, self.targetLatencyFrames), clampedCapacity)
    }

    var capacity: Int {
        storage.count
    }

    func write(_ source: UnsafePointer<Float>, frameCount: Int) {
        guard frameCount > 0 else { return }

        lock.lock()
        defer { lock.unlock() }

        for frame in 0..<frameCount {
            storage[writeIndex] = source[frame]
            writeIndex = (writeIndex + 1) % storage.count

            if availableFrames == storage.count {
                readIndex = (readIndex + 1) % storage.count
                overflowDropFrames += 1
            } else {
                availableFrames += 1
            }
        }

        trimToTargetLatencyIfNeeded()
    }

    func read(into destination: UnsafeMutablePointer<Float>, frameCount: Int) -> Int {
        guard frameCount > 0 else { return 0 }

        lock.lock()
        defer { lock.unlock() }

        if isPriming {
            guard availableFrames >= targetLatencyFrames else {
                destination.initialize(repeating: 0, count: frameCount)
                return 0
            }

            isPriming = false
        }

        let framesToRead = min(frameCount, availableFrames)
        if framesToRead > 0 {
            for frame in 0..<framesToRead {
                destination[frame] = storage[readIndex]
                readIndex = (readIndex + 1) % storage.count
            }
            availableFrames -= framesToRead
        }

        if framesToRead < frameCount {
            let missingFrames = frameCount - framesToRead
            destination.advanced(by: framesToRead).initialize(repeating: 0, count: missingFrames)
            underflowCount += 1
            underflowFrames += missingFrames
            isPriming = true
        }

        return framesToRead
    }

    func status() -> LiveChannelRingBufferStatus {
        lock.lock()
        defer { lock.unlock() }

        return LiveChannelRingBufferStatus(
            availableFrames: availableFrames,
            targetLatencyFrames: targetLatencyFrames,
            highWaterFrames: highWaterFrames,
            capacityFrames: storage.count,
            isPriming: isPriming,
            underflowCount: underflowCount,
            underflowFrames: underflowFrames,
            overflowDropFrames: overflowDropFrames
        )
    }

    func reset() {
        lock.lock()
        readIndex = 0
        writeIndex = 0
        availableFrames = 0
        isPriming = true
        underflowCount = 0
        underflowFrames = 0
        overflowDropFrames = 0
        lock.unlock()
    }

    private func trimToTargetLatencyIfNeeded() {
        guard availableFrames > highWaterFrames else { return }

        let framesToDrop = max(availableFrames - targetLatencyFrames, 0)
        guard framesToDrop > 0 else { return }

        readIndex = (readIndex + framesToDrop) % storage.count
        availableFrames -= framesToDrop
        overflowDropFrames += framesToDrop
        isPriming = false
    }
}

struct LiveChannelRingBufferStatus: Equatable {
    let availableFrames: Int
    let targetLatencyFrames: Int
    let highWaterFrames: Int
    let capacityFrames: Int
    let isPriming: Bool
    let underflowCount: Int
    let underflowFrames: Int
    let overflowDropFrames: Int
}

struct LiveAudioPipeStatus: Equatable {
    let minimumBufferedFrames: Int
    let maximumBufferedFrames: Int
    let targetLatencyFrames: Int
    let highWaterFrames: Int
    let capacityFrames: Int
    let isPriming: Bool
    let underflowCount: Int
    let underflowFrames: Int
    let overflowDropFrames: Int

    func displayText(sampleRate: Double) -> String {
        let minimumMilliseconds = milliseconds(for: minimumBufferedFrames, sampleRate: sampleRate)
        let maximumMilliseconds = milliseconds(for: maximumBufferedFrames, sampleRate: sampleRate)
        let targetMilliseconds = milliseconds(for: targetLatencyFrames, sampleRate: sampleRate)
        let mode = isPriming ? "priming" : "locked"

        return "\(mode) • \(minimumMilliseconds)-\(maximumMilliseconds) ms buffered • target \(targetMilliseconds) ms"
    }

    private func milliseconds(for frames: Int, sampleRate: Double) -> Int {
        guard sampleRate > 0 else { return 0 }
        return Int((Double(frames) / sampleRate * 1_000).rounded())
    }
}

final class LiveAudioPipe {
    let channelCount: Int
    let sampleRate: Double

    private let rings: [LiveChannelRingBuffer]
    private let meterLock = NSLock()
    private var meterLevels: [Float]

    init(channelCount: Int, sampleRate: Double, latencySeconds: Double = 0.15) {
        self.channelCount = channelCount
        self.sampleRate = sampleRate
        let targetLatencyFrames = max(Int(sampleRate * max(latencySeconds, 0.05)), 512)
        let highWaterFrames = max(Int(Double(targetLatencyFrames) * 1.75), targetLatencyFrames + 1_024)
        let capacity = max(Int(sampleRate * max(latencySeconds * 8, 0.75)), highWaterFrames * 2, 4_096)
        rings = (0..<channelCount).map {
            _ in LiveChannelRingBuffer(
                capacity: capacity,
                targetLatencyFrames: targetLatencyFrames,
                highWaterFrames: highWaterFrames
            )
        }
        meterLevels = Array(repeating: 0, count: channelCount)
    }

    func write(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else {
            return
        }

        let frames = Int(buffer.frameLength)
        let sourceChannelCount = Int(buffer.format.channelCount)
        let channelsToWrite = min(channelCount, sourceChannelCount)
        guard frames > 0, channelsToWrite > 0 else { return }

        var nextMeters = Array(repeating: Float(0), count: channelCount)

        for channel in 0..<channelsToWrite {
            let source = channelData[channel]
            rings[channel].write(source, frameCount: frames)
            nextMeters[channel] = Self.meterLevel(samples: source, frameCount: frames)
        }

        meterLock.lock()
        meterLevels = nextMeters
        meterLock.unlock()
    }

    func render(channelIndex: Int, audioBufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: AVAudioFrameCount) -> OSStatus {
        guard channelIndex >= 0, channelIndex < rings.count else {
            return noErr
        }

        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let frames = Int(frameCount)

        for bufferIndex in buffers.indices {
            guard let rawData = buffers[bufferIndex].mData else {
                continue
            }

            let output = rawData.assumingMemoryBound(to: Float.self)
            if bufferIndex == 0 {
                _ = rings[channelIndex].read(into: output, frameCount: frames)
            } else {
                output.initialize(repeating: 0, count: frames)
            }
        }

        return noErr
    }

    func latestMeterLevels() -> [Float] {
        meterLock.lock()
        let levels = meterLevels
        meterLock.unlock()
        return levels
    }

    func status() -> LiveAudioPipeStatus? {
        let statuses = rings.map { $0.status() }
        guard let first = statuses.first else { return nil }

        return LiveAudioPipeStatus(
            minimumBufferedFrames: statuses.map(\.availableFrames).min() ?? 0,
            maximumBufferedFrames: statuses.map(\.availableFrames).max() ?? 0,
            targetLatencyFrames: first.targetLatencyFrames,
            highWaterFrames: first.highWaterFrames,
            capacityFrames: first.capacityFrames,
            isPriming: statuses.contains(where: \.isPriming),
            underflowCount: statuses.map(\.underflowCount).reduce(0, +),
            underflowFrames: statuses.map(\.underflowFrames).reduce(0, +),
            overflowDropFrames: statuses.map(\.overflowDropFrames).reduce(0, +)
        )
    }

    func reset() {
        rings.forEach { $0.reset() }
        meterLock.lock()
        meterLevels = Array(repeating: 0, count: channelCount)
        meterLock.unlock()
    }

    private static func meterLevel(samples: UnsafePointer<Float>, frameCount: Int) -> Float {
        guard frameCount > 0 else { return 0 }

        var energy: Float = 0
        for index in 0..<frameCount {
            let sample = samples[index]
            energy += sample * sample
        }

        let rms = sqrtf(energy / Float(frameCount))
        let db = 20 * log10f(max(rms, 0.000_01))
        return min(max((db + 60) / 60, 0), 1)
    }
}
