import AudioToolbox
import AVFoundation

enum TransportState: String {
    case idle
    case ready
    case playing
    case paused
}

final class OrbisonicEngine {
    var onPlaybackEnded: (() -> Void)?

    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    private let loader = AudioFileLoader()

    private(set) var loadedFile: LoadedAudioFile?
    private(set) var state: TransportState = .idle
    private(set) var tuning: SpatialTuning = .default
    private(set) var liveInputSource: LiveInputSource?

    private var playerNodes: [AVAudioPlayerNode] = []
    private var sourceNodes: [AVAudioSourceNode] = []
    private var testToneNodes: [AVAudioSourceNode] = []
    private var livePipe: LiveAudioPipe?
    private var liveCapture: LiveInputCapture?
    private var liveStartDate: Date?
    private let monitorMeterLock = NSLock()
    private var monitorMeterLevelSnapshot: [Float] = []
    private var currentStartFrame: AVAudioFramePosition = 0
    private var completionToken = UUID()

    init() {
        configureGraph()
        applyTuning(.default)
        AppLogger.shared.notice(category: "engine", "Engine initialized. outputType=headphones logFile=\(AppLogger.logFilePath)")
    }

    func loadFile(url: URL) throws -> LoadedAudioFile {
        AppLogger.shared.info(category: "engine", "Loading file into engine: \(url.lastPathComponent)")

        stopLiveInput()
        detachSourceNodes()

        let loaded = try loader.load(url: url)
        loadedFile = loaded
        liveInputSource = nil
        currentStartFrame = 0
        state = .ready

        rebuildPlayers(for: loaded)
        applyTuning(tuning)

        AppLogger.shared.notice(
            category: "engine",
            "Load complete state=\(state.rawValue) layout=\(loaded.layout.name) channels=\(loaded.layout.channelSummary)"
        )

        return loaded
    }

    func startLiveInput(
        activeChannelCount requestedChannelCount: Int,
        inputRoute: InputRouteInfo,
        sourceName: String = "Live Input"
    ) throws -> LiveInputSource {
        stopTestTone()
        stop()
        detachPlayerNodes()
        detachSourceNodes()

        guard inputRoute.isAvailable else {
            throw LiveInputError.inputDeviceUnavailable(inputRoute.deviceName)
        }

        let availableChannels = UInt32(inputRoute.inputChannelCount)
        let sampleRate = inputRoute.nominalSampleRate > 0
            ? inputRoute.nominalSampleRate
            : preferredOutputSampleRate()

        guard availableChannels > 0 else {
            throw LiveInputError.noInputChannels
        }

        guard requestedChannelCount > 0, requestedChannelCount <= Int(availableChannels) else {
            throw LiveInputError.unsupportedChannelRequest(
                requested: requestedChannelCount,
                available: availableChannels
            )
        }

        guard let monoFormat = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ) else {
            throw LiveInputError.monoFormatCreationFailed(sampleRate)
        }

        let layout = SurroundLayoutDetector.fallbackLayout(for: requestedChannelCount)
        let metadata = AudioSourceMetadata(
            fileName: sourceName,
            containerName: "Live",
            codecName: "CoreAudio Float32",
            layoutName: layout.name,
            channelSummary: layout.channelSummary,
            channelCount: layout.channelCount,
            sampleRate: sampleRate,
            bitDepth: 32,
            duration: 0
        )
        let liveSource = LiveInputSource(layout: layout, metadata: metadata)
        let pipe = LiveAudioPipe(channelCount: requestedChannelCount, sampleRate: sampleRate)
        let capture = try LiveInputCapture(
            inputRoute: inputRoute,
            activeChannelCount: requestedChannelCount,
            sampleRate: sampleRate,
            pipe: pipe
        )

        livePipe = pipe
        liveCapture = capture
        liveInputSource = liveSource
        loadedFile = nil
        currentStartFrame = 0

        sourceNodes = layout.channels.enumerated().map { index, _ in
            AVAudioSourceNode { [weak pipe] _, _, frameCount, audioBufferList in
                pipe?.render(channelIndex: index, audioBufferList: audioBufferList, frameCount: frameCount) ?? noErr
            }
        }

        for sourceNode in sourceNodes {
            engine.attach(sourceNode)
            engine.connect(sourceNode, to: environment, format: monoFormat)
        }

        applyTuning(tuning)

        do {
            if !engine.isRunning {
                try engine.start()
                AppLogger.shared.notice(category: "engine", "AVAudioEngine started for live input.")
            }
            try capture.start()
        } catch {
            stopLiveInput()
            throw error
        }

        liveStartDate = Date()
        state = .playing

        AppLogger.shared.notice(
            category: "live-input",
            "Started live input source=\(sourceName) input=\(inputRoute.deviceName) inputUID=\(inputRoute.uid) inputChannels=\(availableChannels) activeChannels=\(requestedChannelCount) sampleRate=\(sampleRate) layout=\(layout.name)"
        )

        return liveSource
    }

    func play() throws {
        stopTestTone()

        guard let loadedFile else {
            AppLogger.shared.error(category: "engine", "Play requested with no loaded file.")
            return
        }

        if !engine.isRunning {
            try engine.start()
            AppLogger.shared.notice(category: "engine", "AVAudioEngine started successfully.")
        }

        switch state {
        case .paused:
            playerNodes.forEach { $0.play() }
            state = .playing
            AppLogger.shared.notice(category: "transport", "Resumed playback at \(formatTime(currentTime())) / \(loadedFile.metadata.durationText).")
        case .playing:
            AppLogger.shared.debug(category: "transport", "Play requested while already playing.")
        case .idle, .ready:
            scheduleFromCurrentPosition()
            startPlayers()
            state = .playing
            AppLogger.shared.notice(
                category: "transport",
                "Started playback state=\(state.rawValue) startFrame=\(currentStartFrame) layout=\(loadedFile.layout.name)"
            )
        }
    }

    func pause() {
        guard state == .playing else { return }
        currentStartFrame = playbackFrame()
        playerNodes.forEach { $0.pause() }
        state = .paused
        AppLogger.shared.notice(category: "transport", "Paused playback at frame=\(currentStartFrame) time=\(formatTime(currentTime())).")
    }

    func stop() {
        playerNodes.forEach { $0.stop() }
        if liveInputSource != nil {
            stopLiveInput()
        }
        stopTestTone()
        stopEngineIfRunning(reason: "transport stop")
        completionToken = UUID()
        currentStartFrame = 0
        state = loadedFile == nil ? .idle : .ready
        AppLogger.shared.notice(category: "transport", "Stopped playback. state=\(state.rawValue)")
    }

    func playTestTone(_ point: TestTonePipelinePoint) throws {
        playerNodes.forEach { $0.stop() }
        if liveInputSource != nil {
            stopLiveInput()
        }
        stopTestTone()

        let sampleRate = preferredOutputSampleRate()
        let node = makeToneNode(
            frequency: point.frequency,
            sampleRate: sampleRate,
            gain: point.gain
        )

        engine.attach(node)

        if let spatialChannel = point.spatialChannel {
            guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
                throw LiveInputError.monoFormatCreationFailed(sampleRate)
            }

            engine.connect(node, to: environment, format: monoFormat)
            configureSpatialNode(node, for: spatialChannel, tuning: tuning)
        } else {
            guard let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
                throw LiveInputError.monoFormatCreationFailed(sampleRate)
            }

            engine.connect(node, to: engine.mainMixerNode, format: stereoFormat)
        }

        testToneNodes = [node]

        if !engine.isRunning {
            try engine.start()
            AppLogger.shared.notice(category: "engine", "AVAudioEngine started for diagnostic tone.")
        }

        AppLogger.shared.notice(
            category: "diagnostics",
            "Started test tone point=\(point.rawValue) frequency=\(point.frequency)Hz route=\(point.pipelineDescription)"
        )
    }

    func stopTestTone() {
        guard !testToneNodes.isEmpty else { return }

        testToneNodes.forEach { node in
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }
        testToneNodes = []
        AppLogger.shared.notice(category: "diagnostics", "Stopped test tone.")
    }

    func seek(toProgress progress: Double) {
        guard let loadedFile else { return }
        let clampedProgress = progress.clamped(to: 0...1)
        let nextFrame = AVAudioFramePosition(Double(loadedFile.frameCount) * clampedProgress)
        currentStartFrame = min(nextFrame, max(loadedFile.frameCount - 1, 0))

        AppLogger.shared.info(
            category: "transport",
            "Seek requested progress=\(String(format: "%.3f", clampedProgress)) frame=\(currentStartFrame)"
        )

        if state == .playing {
            playerNodes.forEach { $0.stop() }
            scheduleFromCurrentPosition()
            startPlayers()
        } else if state == .paused {
            playerNodes.forEach { $0.stop() }
        }
    }

    func currentTime() -> TimeInterval {
        if liveInputSource != nil {
            return Date().timeIntervalSince(liveStartDate ?? Date())
        }

        guard let loadedFile else { return 0 }
        return Double(playbackFrame()) / loadedFile.sampleRate
    }

    func duration() -> TimeInterval {
        if liveInputSource != nil {
            return 0
        }

        return loadedFile?.duration ?? 0
    }

    func channelMeterLevels() -> [Float] {
        if let livePipe {
            return livePipe.latestMeterLevels()
        }

        guard let loadedFile else {
            return []
        }

        guard state == .playing || state == .paused else {
            return Array(repeating: 0, count: loadedFile.layout.channelCount)
        }

        let currentFrame = playbackFrame()
        let sampleWindow = max(Int(loadedFile.sampleRate * 0.015), 512)

        return loadedFile.monoBuffers.map { buffer in
            Self.meterLevel(for: buffer, atFrame: currentFrame, sampleWindow: sampleWindow)
        }
    }

    func monitorMeterChannelCount() -> Int {
        monitorMeterLock.lock()
        let currentCount = monitorMeterLevelSnapshot.count
        monitorMeterLock.unlock()

        if currentCount > 0 {
            return currentCount
        }

        let mixerCount = Int(engine.mainMixerNode.outputFormat(forBus: 0).channelCount)
        if mixerCount > 0 {
            return mixerCount
        }

        let outputCount = Int(engine.outputNode.inputFormat(forBus: 0).channelCount)
        return max(outputCount, 2)
    }

    func monitorMeterLevels() -> [Float] {
        monitorMeterLock.lock()
        let levels = monitorMeterLevelSnapshot
        monitorMeterLock.unlock()

        if !levels.isEmpty {
            return levels
        }

        return Array(repeating: 0, count: monitorMeterChannelCount())
    }

    func liveInputStatus() -> LiveAudioPipeStatus? {
        livePipe?.status()
    }

    func updateTuning(_ tuning: SpatialTuning) {
        self.tuning = tuning
        applyTuning(tuning)
        AppLogger.shared.info(
            category: "tuning",
            "Updated tuning preset=\(tuning.preset.rawValue) frontAngle=\(tuning.frontAngle) rearAngle=\(tuning.rearAngle) headTracking=\(tuning.headTrackingEnabled)"
        )
    }

    private func configureGraph() {
        engine.attach(environment)
        engine.connect(environment, to: engine.mainMixerNode, format: nil)

        environment.outputType = .headphones
        environment.reverbParameters.enable = false
        environment.distanceAttenuationParameters.distanceAttenuationModel = .exponential
        environment.distanceAttenuationParameters.referenceDistance = 1
        environment.distanceAttenuationParameters.maximumDistance = 10
        environment.distanceAttenuationParameters.rolloffFactor = 0.2
        engine.mainMixerNode.outputVolume = 0.92
        installMonitorMeterTap()
    }

    private func rebuildPlayers(for loadedFile: LoadedAudioFile) {
        detachPlayerNodes()

        playerNodes = loadedFile.layout.channels.map { _ in AVAudioPlayerNode() }

        for player in playerNodes {
            engine.attach(player)
            engine.connect(player, to: environment, format: loadedFile.monoFormat)
        }

        AppLogger.shared.info(
            category: "engine",
            "Rebuilt player graph with \(playerNodes.count) mono point sources."
        )
    }

    private func applyTuning(_ tuning: SpatialTuning) {
        environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: 0, pitch: 0, roll: 0)

        // Head tracking is controlled by the active output route/profile when the SDK exposes it.

        if let loadedFile {
            for (channel, player) in zip(loadedFile.layout.channels, playerNodes) {
                configureSpatialNode(player, for: channel, tuning: tuning)
            }
        }

        if let liveInputSource {
            for (channel, sourceNode) in zip(liveInputSource.layout.channels, sourceNodes) {
                configureSpatialNode(sourceNode, for: channel, tuning: tuning)
            }
        }
    }

    private func configureSpatialNode(_ node: AVAudio3DMixing, for channel: SurroundChannel, tuning: SpatialTuning) {
        node.position = tuning.position(for: channel)
        node.renderingAlgorithm = channel.role.isLFE ? .equalPowerPanning : .HRTFHQ
        node.sourceMode = channel.role.isLFE ? .bypass : .pointSource
        node.reverbBlend = 0

        if let audioMixing = node as? AVAudioMixing {
            audioMixing.volume = volume(for: channel.role)
        }
    }

    private func scheduleFromCurrentPosition() {
        guard let loadedFile else { return }
        completionToken = UUID()

        AppLogger.shared.debug(
            category: "transport",
            "Scheduling \(playerNodes.count) channels from frame=\(currentStartFrame)"
        )

        for (index, player) in playerNodes.enumerated() {
            player.stop()
            let sourceBuffer = loadedFile.monoBuffers[index]
            let scheduledBuffer = Self.slice(buffer: sourceBuffer, fromFrame: currentStartFrame)

            if index == 0 {
                let token = completionToken
                player.scheduleBuffer(scheduledBuffer, at: nil, options: []) { [token] in
                    Task { @MainActor [weak self] in
                        guard let self, self.completionToken == token else { return }
                        AppLogger.shared.notice(category: "transport", "Playback finished naturally.")
                        self.stop()
                        self.onPlaybackEnded?()
                    }
                }
            } else {
                player.scheduleBuffer(scheduledBuffer, at: nil, options: [])
            }
        }
    }

    private func startPlayers() {
        let hostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.03)
        let startTime = AVAudioTime(hostTime: hostTime)
        playerNodes.forEach { $0.play(at: startTime) }
    }

    private func preferredOutputSampleRate() -> Double {
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        if outputFormat.sampleRate > 0 {
            return outputFormat.sampleRate
        }

        let mixerFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        return mixerFormat.sampleRate > 0 ? mixerFormat.sampleRate : 48_000
    }

    private func makeToneNode(
        frequency: Double,
        sampleRate: Double,
        gain: Float
    ) -> AVAudioSourceNode {
        let tone = SineToneState(frequency: frequency, sampleRate: sampleRate, gain: gain)

        return AVAudioSourceNode { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frames = Int(frameCount)

            for frame in 0..<frames {
                let sample = tone.nextSample()

                for buffer in buffers {
                    guard let rawData = buffer.mData else { continue }
                    rawData.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }

            return noErr
        }
    }

    private func playbackFrame() -> AVAudioFramePosition {
        guard let loadedFile else { return 0 }

        if state == .playing,
           let renderTime = playerNodes.first?.lastRenderTime,
           let playerTime = playerNodes.first?.playerTime(forNodeTime: renderTime) {
            let frame = currentStartFrame + AVAudioFramePosition(playerTime.sampleTime)
            return min(frame, loadedFile.frameCount)
        }

        return min(currentStartFrame, loadedFile.frameCount)
    }

    private func stopLiveInput() {
        let hadLiveInput = liveInputSource != nil || livePipe != nil || liveCapture != nil || !sourceNodes.isEmpty
        guard hadLiveInput else { return }

        liveCapture?.stop()
        liveCapture = nil
        livePipe?.reset()
        livePipe = nil
        liveInputSource = nil
        liveStartDate = nil
        detachSourceNodes()
        AppLogger.shared.notice(category: "live-input", "Stopped live input.")
        stopEngineIfRunning(reason: "live input stop")
    }

    private func stopEngineIfRunning(reason: String) {
        guard engine.isRunning else { return }
        engine.stop()
        resetMonitorMeterLevels()
        AppLogger.shared.notice(category: "engine", "AVAudioEngine stopped. reason=\(reason)")
    }

    private func detachPlayerNodes() {
        playerNodes.forEach { player in
            player.stop()
            engine.disconnectNodeOutput(player)
            engine.detach(player)
        }
        playerNodes = []
    }

    private func detachSourceNodes() {
        sourceNodes.forEach { sourceNode in
            engine.disconnectNodeOutput(sourceNode)
            engine.detach(sourceNode)
        }
        sourceNodes = []
    }

    private func volume(for role: SurroundChannelRole) -> Float {
        if role.isLFE {
            return 0.94
        }
        return 1
    }

    private func installMonitorMeterTap() {
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1_024, format: nil) { [weak self] buffer, _ in
            self?.captureMonitorMeters(from: buffer)
        }
    }

    private func captureMonitorMeters(from buffer: AVAudioPCMBuffer) {
        let channelCount = Int(buffer.format.channelCount)
        guard channelCount > 0, let channelData = buffer.floatChannelData else {
            resetMonitorMeterLevels()
            return
        }

        let frameCount = Int(buffer.frameLength)
        var levels = Array(repeating: Float(0), count: channelCount)

        for channel in 0..<channelCount {
            levels[channel] = Self.meterLevel(samples: channelData[channel], frameCount: frameCount)
        }

        monitorMeterLock.lock()
        monitorMeterLevelSnapshot = levels
        monitorMeterLock.unlock()
    }

    private func resetMonitorMeterLevels() {
        let channelCount = monitorMeterChannelCount()
        monitorMeterLock.lock()
        monitorMeterLevelSnapshot = Array(repeating: 0, count: channelCount)
        monitorMeterLock.unlock()
    }

    private func formatTime(_ value: TimeInterval) -> String {
        let totalSeconds = max(Int(value.rounded(.down)), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private static func slice(buffer: AVAudioPCMBuffer, fromFrame startFrame: AVAudioFramePosition) -> AVAudioPCMBuffer {
        let sourceStart = max(startFrame, 0)
        let availableFrames = AVAudioFramePosition(buffer.frameLength)
        let framesRemaining = max(availableFrames - sourceStart, 1)
        let monoFormat = buffer.format
        let slice = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: AVAudioFrameCount(framesRemaining))!
        slice.frameLength = AVAudioFrameCount(framesRemaining)

        let source = buffer.floatChannelData![0]
        let destination = slice.floatChannelData![0]
        let offset = Int(sourceStart)
        destination.update(from: source.advanced(by: offset), count: Int(framesRemaining))
        return slice
    }

    private static func meterLevel(
        for buffer: AVAudioPCMBuffer,
        atFrame frame: AVAudioFramePosition,
        sampleWindow: Int
    ) -> Float {
        guard let channelData = buffer.floatChannelData else {
            return 0
        }

        let samples = channelData[0]
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            return 0
        }

        let startFrame = max(0, min(Int(frame), frameLength - 1))
        let endFrame = min(frameLength, startFrame + sampleWindow)
        let count = max(endFrame - startFrame, 1)

        var energy: Float = 0
        for index in startFrame..<endFrame {
            let sample = samples[index]
            energy += sample * sample
        }

        let rms = sqrtf(energy / Float(count))
        let db = 20 * log10f(max(rms, 0.000_01))
        return min(max((db + 60) / 60, 0), 1)
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

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
