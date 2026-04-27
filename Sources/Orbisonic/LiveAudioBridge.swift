import AudioToolbox
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
    case inputAudioUnitConfigurationFailed(deviceName: String, operation: String, status: OSStatus)
    case inputAudioUnitStartFailed(deviceName: String, status: OSStatus)
    case noInputChannels
    case unsupportedChannelRequest(requested: Int, available: UInt32, maxSupported: Int)
    case monoFormatCreationFailed(Double)

    var errorDescription: String? {
        switch self {
        case .inputDeviceUnavailable(let deviceName):
            "The selected input device is not available: \(deviceName)."
        case .inputDeviceSelectionFailed(let deviceName, let status):
            "Unable to capture \(deviceName) directly. Core Audio returned \(status)."
        case .inputAudioUnitUnavailable(let deviceName):
            "Unable to access the Core Audio input unit for \(deviceName)."
        case .inputAudioUnitConfigurationFailed(let deviceName, let operation, let status):
            "Unable to configure \(deviceName) for live capture while \(operation). Core Audio returned \(status)."
        case .inputAudioUnitStartFailed(let deviceName, let status):
            "Unable to start live capture from \(deviceName). Core Audio returned \(status)."
        case .noInputChannels:
            "The selected input device has no input channels."
        case .unsupportedChannelRequest(let requested, let available, let maxSupported):
            requested > maxSupported
                ? "Orbisonic supports up to \(maxSupported) live input channels in this build. Requested \(requested) channels."
                : "Requested \(requested) live input channels, but the selected input device exposes \(available)."
        case .monoFormatCreationFailed(let sampleRate):
            "Unable to create a live mono render format at \(sampleRate) Hz."
        }
    }
}

final class LiveInputCapture {
    private let inputRoute: InputRouteInfo
    private let pipe: LiveAudioPipe
    private let activeChannelCount: Int
    private let captureChannelCount: Int
    private let sampleRate: Double
    private var audioUnit: AudioUnit?
    private var isStarted = false

    init(
        inputRoute: InputRouteInfo,
        activeChannelCount: Int,
        sampleRate: Double,
        pipe: LiveAudioPipe
    ) throws {
        self.inputRoute = inputRoute
        self.activeChannelCount = activeChannelCount
        self.captureChannelCount = min(
            max(inputRoute.inputChannelCount, activeChannelCount, 1),
            OrbisonicAudioLimits.maxSourceChannelCount
        )
        self.sampleRate = sampleRate
        self.pipe = pipe

        do {
            audioUnit = try Self.makeHALInputUnit(deviceName: inputRoute.deviceName)
            try configure()
        } catch {
            dispose()
            throw error
        }
    }

    deinit {
        dispose()
    }

    func start() throws {
        guard let audioUnit else {
            throw LiveInputError.inputAudioUnitUnavailable(inputRoute.deviceName)
        }

        let status = AudioOutputUnitStart(audioUnit)
        guard status == noErr else {
            throw LiveInputError.inputAudioUnitStartFailed(
                deviceName: inputRoute.deviceName,
                status: status
            )
        }

        isStarted = true
        AppLogger.shared.notice(
            category: "live-input",
            "Started HAL capture device=\(inputRoute.deviceName) uid=\(inputRoute.uid) captureChannels=\(captureChannelCount) activeChannels=\(activeChannelCount) sampleRate=\(sampleRate)"
        )
    }

    func stop() {
        dispose()
    }

    private static func makeHALInputUnit(deviceName: String) throws -> AudioUnit {
        var description = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        guard let component = AudioComponentFindNext(nil, &description) else {
            throw LiveInputError.inputAudioUnitUnavailable(deviceName)
        }

        var audioUnit: AudioUnit?
        let status = AudioComponentInstanceNew(component, &audioUnit)
        guard status == noErr, let audioUnit else {
            throw LiveInputError.inputAudioUnitConfigurationFailed(
                deviceName: deviceName,
                operation: "creating the HAL input unit",
                status: status
            )
        }

        return audioUnit
    }

    private func configure() throws {
        guard let audioUnit else {
            throw LiveInputError.inputAudioUnitUnavailable(inputRoute.deviceName)
        }

        var enableInput: UInt32 = 1
        try setProperty(
            audioUnit,
            kAudioOutputUnitProperty_EnableIO,
            scope: kAudioUnitScope_Input,
            element: 1,
            data: &enableInput,
            size: MemoryLayout<UInt32>.size,
            operation: "enabling input"
        )

        var disableOutput: UInt32 = 0
        try setProperty(
            audioUnit,
            kAudioOutputUnitProperty_EnableIO,
            scope: kAudioUnitScope_Output,
            element: 0,
            data: &disableOutput,
            size: MemoryLayout<UInt32>.size,
            operation: "disabling HAL output"
        )

        var deviceID = inputRoute.deviceID
        try setProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            scope: kAudioUnitScope_Global,
            element: 0,
            data: &deviceID,
            size: MemoryLayout<AudioDeviceID>.size,
            operation: "selecting the input device"
        )

        var format = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat
                | kAudioFormatFlagsNativeEndian
                | kAudioFormatFlagIsPacked
                | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: UInt32(MemoryLayout<Float>.size),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(MemoryLayout<Float>.size),
            mChannelsPerFrame: UInt32(captureChannelCount),
            mBitsPerChannel: UInt32(MemoryLayout<Float>.size * 8),
            mReserved: 0
        )

        try setProperty(
            audioUnit,
            kAudioUnitProperty_StreamFormat,
            scope: kAudioUnitScope_Output,
            element: 1,
            data: &format,
            size: MemoryLayout<AudioStreamBasicDescription>.size,
            operation: "setting the input stream format"
        )

        var callback = AURenderCallbackStruct(
            inputProc: Self.inputCallback,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        try setProperty(
            audioUnit,
            kAudioOutputUnitProperty_SetInputCallback,
            scope: kAudioUnitScope_Global,
            element: 0,
            data: &callback,
            size: MemoryLayout<AURenderCallbackStruct>.size,
            operation: "installing the input callback"
        )

        let status = AudioUnitInitialize(audioUnit)
        guard status == noErr else {
            throw LiveInputError.inputAudioUnitConfigurationFailed(
                deviceName: inputRoute.deviceName,
                operation: "initializing the HAL input unit",
                status: status
            )
        }

        AppLogger.shared.notice(
            category: "live-input",
            "Configured direct HAL input device=\(inputRoute.deviceName) uid=\(inputRoute.uid) deviceID=\(inputRoute.deviceID) captureChannels=\(captureChannelCount) activeChannels=\(activeChannelCount) sampleRate=\(sampleRate)"
        )
    }

    private func setProperty(
        _ audioUnit: AudioUnit,
        _ propertyID: AudioUnitPropertyID,
        scope: AudioUnitScope,
        element: AudioUnitElement,
        data: UnsafeRawPointer,
        size: Int,
        operation: String
    ) throws {
        let status = AudioUnitSetProperty(
            audioUnit,
            propertyID,
            scope,
            element,
            data,
            UInt32(size)
        )

        guard status == noErr else {
            throw LiveInputError.inputAudioUnitConfigurationFailed(
                deviceName: inputRoute.deviceName,
                operation: operation,
                status: status
            )
        }
    }

    private static let inputCallback: AURenderCallback = { refCon, ioActionFlags, timeStamp, _, frameCount, _ in
        let capture = Unmanaged<LiveInputCapture>.fromOpaque(refCon).takeUnretainedValue()
        return capture.renderInput(
            ioActionFlags: ioActionFlags,
            timeStamp: timeStamp,
            frameCount: frameCount
        )
    }

    private func renderInput(
        ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timeStamp: UnsafePointer<AudioTimeStamp>,
        frameCount: UInt32
    ) -> OSStatus {
        guard let audioUnit else {
            return kAudioUnitErr_Uninitialized
        }

        guard frameCount > 0 else {
            return noErr
        }

        let bufferList = makeBufferList(frameCount: frameCount)
        defer {
            releaseBufferList(bufferList)
        }

        let status = AudioUnitRender(
            audioUnit,
            ioActionFlags,
            timeStamp,
            1,
            frameCount,
            bufferList
        )

        guard status == noErr else {
            return status
        }

        pipe.write(bufferList: UnsafeMutableAudioBufferListPointer(bufferList), frameCount: Int(frameCount))
        return noErr
    }

    private func makeBufferList(frameCount: UInt32) -> UnsafeMutablePointer<AudioBufferList> {
        let channelCount = max(captureChannelCount, 1)
        let byteCount = MemoryLayout<AudioBufferList>.size
            + MemoryLayout<AudioBuffer>.stride * (channelCount - 1)
        let rawBufferList = UnsafeMutableRawPointer.allocate(
            byteCount: byteCount,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        rawBufferList.initializeMemory(as: UInt8.self, repeating: 0, count: byteCount)

        let bufferList = rawBufferList.bindMemory(to: AudioBufferList.self, capacity: 1)
        bufferList.pointee.mNumberBuffers = UInt32(channelCount)

        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        let dataByteCount = Int(frameCount) * MemoryLayout<Float>.size

        for index in buffers.indices {
            let channelData = UnsafeMutableRawPointer.allocate(
                byteCount: dataByteCount,
                alignment: MemoryLayout<Float>.alignment
            )
            channelData.initializeMemory(as: Float.self, repeating: 0, count: Int(frameCount))

            buffers[index] = AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: UInt32(dataByteCount),
                mData: channelData
            )
        }

        return bufferList
    }

    private func releaseBufferList(_ bufferList: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        for index in buffers.indices {
            buffers[index].mData?.deallocate()
        }
        UnsafeMutableRawPointer(bufferList).deallocate()
    }

    private func dispose() {
        guard let audioUnit else { return }

        if isStarted {
            AudioOutputUnitStop(audioUnit)
            isStarted = false
        }

        AudioUnitUninitialize(audioUnit)
        AudioComponentInstanceDispose(audioUnit)
        self.audioUnit = nil
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

    func write(bufferList: UnsafeMutableAudioBufferListPointer, frameCount: Int) {
        let channelsToWrite = min(channelCount, bufferList.count)
        guard frameCount > 0, channelsToWrite > 0 else { return }

        var nextMeters = Array(repeating: Float(0), count: channelCount)

        for channel in 0..<channelsToWrite {
            guard let rawData = bufferList[channel].mData else {
                continue
            }

            let source = rawData.assumingMemoryBound(to: Float.self)
            let availableFrames = Int(bufferList[channel].mDataByteSize) / MemoryLayout<Float>.size
            let framesToWrite = min(frameCount, availableFrames)
            guard framesToWrite > 0 else {
                continue
            }

            rings[channel].write(source, frameCount: framesToWrite)
            nextMeters[channel] = Self.meterLevel(samples: source, frameCount: framesToWrite)
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

    func render(
        matrix: RendererMatrix,
        audioBufferList: UnsafeMutablePointer<AudioBufferList>,
        frameCount: AVAudioFrameCount
    ) -> OSStatus {
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let frames = Int(frameCount)
        guard frames > 0,
              matrix.inputCount == rings.count,
              matrix.outputCount > 0
        else {
            clear(audioBufferList: audioBufferList, frameCount: frames)
            return noErr
        }

        var inputScratch = Array(
            repeating: Array(repeating: Float(0), count: frames),
            count: matrix.inputCount
        )

        for inputIndex in 0..<matrix.inputCount {
            inputScratch[inputIndex].withUnsafeMutableBufferPointer { destination in
                guard let baseAddress = destination.baseAddress else { return }
                _ = rings[inputIndex].read(into: baseAddress, frameCount: frames)
            }
        }

        for buffer in buffers {
            guard let rawData = buffer.mData else { continue }
            let sampleCount = min(
                Int(buffer.mDataByteSize) / MemoryLayout<Float>.stride,
                frames
            )
            rawData.assumingMemoryBound(to: Float.self).initialize(repeating: 0, count: sampleCount)
        }

        let outputLimit = min(buffers.count, matrix.outputCount)
        for outputIndex in 0..<outputLimit {
            guard let rawData = buffers[outputIndex].mData else { continue }
            let output = rawData.assumingMemoryBound(to: Float.self)

            for inputIndex in 0..<matrix.inputCount {
                let gain = Float(matrix.gains[inputIndex][outputIndex])
                guard abs(gain) > 0.000_001 else { continue }

                let input = inputScratch[inputIndex]
                for frame in 0..<frames {
                    output[frame] += input[frame] * gain
                }
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

    private func clear(audioBufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: Int) {
        guard frameCount > 0 else { return }

        for buffer in UnsafeMutableAudioBufferListPointer(audioBufferList) {
            guard let rawData = buffer.mData else { continue }
            let sampleCount = min(
                Int(buffer.mDataByteSize) / MemoryLayout<Float>.stride,
                frameCount
            )
            rawData.assumingMemoryBound(to: Float.self).initialize(repeating: 0, count: sampleCount)
        }
    }
}
