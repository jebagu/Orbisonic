import AudioToolbox
import AppKit
import AVFoundation

enum TransportState: String {
    case idle
    case ready
    case playing
    case paused
}

enum OutputDeviceSelectionError: LocalizedError {
    case invalidDevice
    case outputAudioUnitUnavailable
    case setDeviceFailed(OSStatus)
    case invalidDiagnosticChannel(Int, Int)
    case diagnosticFormatCreationFailed(channelCount: Int, sampleRate: Double)
    case rendererFormatCreationFailed(channelCount: Int, sampleRate: Double)

    var errorDescription: String? {
        switch self {
        case .invalidDevice:
            "No valid output device was selected."
        case .outputAudioUnitUnavailable:
            "The output audio unit is not available yet."
        case .setDeviceFailed(let status):
            "Could not select that output device. Core Audio returned \(status)."
        case .invalidDiagnosticChannel(let index, let count):
            "Diagnostic channel \(index + 1) is outside the available \(count)-channel range."
        case .diagnosticFormatCreationFailed(let channelCount, let sampleRate):
            "Unable to create a \(channelCount)-channel diagnostic output format at \(sampleRate) Hz."
        case .rendererFormatCreationFailed(let channelCount, let sampleRate):
            "Unable to create a \(channelCount)-channel renderer output format at \(sampleRate) Hz."
        }
    }
}

private final class StreamingScheduledChunk {
    let id = UUID()
    let startFrame: AVAudioFramePosition
    let frameCount: AVAudioFrameCount
    let monoBuffers: [AVAudioPCMBuffer]

    init(
        startFrame: AVAudioFramePosition,
        frameCount: AVAudioFrameCount,
        monoBuffers: [AVAudioPCMBuffer]
    ) {
        self.startFrame = startFrame
        self.frameCount = frameCount
        self.monoBuffers = monoBuffers
    }

    var byteCount: Int {
        monoBuffers.reduce(0) { partial, buffer in
            let audioBuffers = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
            let listedBytes = audioBuffers.reduce(0) { bytePartial, audioBuffer in
                bytePartial + Int(audioBuffer.mDataByteSize)
            }
            if listedBytes > 0 {
                return partial + listedBytes
            }

            let bytes = PreparedPCMPolicy.estimatedDecodedPCMBytes(
                frameCount: AVAudioFramePosition(buffer.frameLength),
                channelCount: 1
            ) ?? 0
            return partial + bytes
        }
    }
}

private final class StreamingPlaybackContext {
    let token = UUID()
    let source: StreamingAudioFileSource
    let descriptor: AudioAssetDescriptor
    let layout: SurroundLayout
    let metadata: AudioSourceMetadata
    let monoFormat: AVAudioFormat
    let monoBufferPool: PCMBufferPool

    var scheduledChunks: [UUID: StreamingScheduledChunk] = [:]
    var scheduledFrames: AVAudioFramePosition = 0
    var scheduledBytes = 0
    var scheduledChunkCount = 0
    var reachedEndOfSource = false
    var scheduleTask: Task<Void, Never>?

    init(
        source: StreamingAudioFileSource,
        descriptor: AudioAssetDescriptor,
        layout: SurroundLayout,
        metadata: AudioSourceMetadata,
        monoFormat: AVAudioFormat
    ) {
        self.source = source
        self.descriptor = descriptor
        self.layout = layout
        self.metadata = metadata
        self.monoFormat = monoFormat
        self.monoBufferPool = PCMBufferPool(
            format: monoFormat,
            maxRetainedBuffers: max(layout.channelCount * 4, 4),
            maxFrameCapacity: StreamingLocalPlaybackPolicy.steadyChunkFrames
        )
    }

    var durationFrames: AVAudioFramePosition {
        descriptor.durationFrames ?? 0
    }

    var durationSeconds: TimeInterval {
        descriptor.durationSeconds ?? 0
    }
}

final class OrbisonicEngine {
    var onPlaybackEnded: (() -> Void)?

    private static let maxStreamingScheduledAheadSeconds: TimeInterval = 2
    private static let maxStreamingScheduledPCMBytes = 64 * 1_024 * 1_024

    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    private let loader = AudioFileLoader()
    private let diagnosticMonitorEngine = AVAudioEngine()

    private(set) var loadedFile: LoadedAudioFile?
    private(set) var state: TransportState = .idle
    private(set) var tuning: SpatialTuning = .default
    private(set) var liveInputSource: LiveInputSource?

    private var playerNodes: [AVAudioPlayerNode] = []
    private var rendererSourceNode: AVAudioSourceNode?
    private var sourceNodes: [AVAudioSourceNode] = []
    private var testToneNodes: [AVAudioSourceNode] = []
    private var diagnosticMonitorToneNodes: [AVAudioSourceNode] = []
    private var diagnosticMonitorOutputDeviceID: AudioDeviceID?
    private var livePipe: LiveAudioPipe?
    private var liveCapture: LiveInputCapture?
    private var liveStartDate: Date?
    private var liveInputMuted = false
    private var rendererMode: RendererRenderMode = .automatic
    private var rendererScene: RendererSceneModel = .empty
    private var directRendererAudioEnabled = false
    private let rendererPlaybackLock = NSLock()
    private var rendererPlaybackFrame: AVAudioFramePosition = 0
    private var rendererPlaybackCompletionSent = false
    private var streamingPlayback: StreamingPlaybackContext?
    private let monitorMeterLock = NSLock()
    private var monitorMeterLevelSnapshot: [Float] = []
    private var currentStartFrame: AVAudioFramePosition = 0
    private var completionToken = UUID()
    private var pausedPlaybackNeedsReschedule = false
#if DEBUG
    private(set) var debugPlaybackGraphBuildCount = 0
    private(set) var debugScheduleFromCurrentPositionCount = 0
    var debugPausedPlaybackNeedsReschedule: Bool { pausedPlaybackNeedsReschedule }
#endif

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
        return loadPreparedFile(loaded)
    }

    func loadPreparedFile(_ loaded: LoadedAudioFile, debugTiming: DebugTimingContext? = nil) -> LoadedAudioFile {
        let commitStart = DispatchTime.now().uptimeNanoseconds
        debugTiming?.log("commit start", fileURL: loaded.url)
        AppLogger.shared.info(category: "engine", "Loading prepared file into engine: \(loaded.url.lastPathComponent)")

        cancelStreamingPlayback(reason: "prepared file loaded")
        debugTiming?.log(
            "stop old local playback start",
            fileURL: loaded.url,
            extra: ["engineState=\"\(state.rawValue)\"", "hadLoadedFile=\(loadedFile != nil)"]
        )
        stopLiveInput()
        detachSourceNodes()
        debugTiming?.log("stop old local playback end", fileURL: loaded.url)

        debugTiming?.log("replace current source start", fileURL: loaded.url)
        loadedFile = loaded
        liveInputSource = nil
        currentStartFrame = 0
        pausedPlaybackNeedsReschedule = false
        state = .ready
        debugTiming?.log("replace current source end", fileURL: loaded.url)

        rebuildPlaybackGraph(for: loaded, debugTiming: debugTiming)
        applyTuning(tuning)

        AppLogger.shared.notice(
            category: "engine",
            "Load complete state=\(state.rawValue) layout=\(loaded.layout.name) channels=\(loaded.layout.channelSummary)"
        )
        debugTiming?.log(
            "commit finish",
            fileURL: loaded.url,
            extra: ["commitMs=\(String(format: "%.1f", Double(DispatchTime.now().uptimeNanoseconds - commitStart) / 1_000_000.0))"]
        )

        return loaded
    }

    @MainActor
    func startStreaming(
        source: StreamingAudioFileSource,
        descriptor: AudioAssetDescriptor,
        debugTiming: DebugTimingContext? = nil
    ) async throws {
        let commitStart = DispatchTime.now().uptimeNanoseconds
        debugTiming?.log(
            "streaming engine commit start",
            fileURL: descriptor.url,
            extra: descriptor.logFields
        )

        guard descriptor.channelCount > 0,
              OrbisonicAudioLimits.supportsSourceChannelCount(descriptor.channelCount)
        else {
            throw AudioFileLoaderError.unsupportedChannelCount(
                UInt32(max(descriptor.channelCount, 0)),
                maxSupported: OrbisonicAudioLimits.maxSourceChannelCount
            )
        }
        guard let monoFormat = AVAudioFormat(
            standardFormatWithSampleRate: descriptor.sourceSampleRate,
            channels: 1
        ) else {
            throw AudioFileLoaderError.monoFormatCreationFailed(descriptor.sourceSampleRate)
        }

        stopLiveInput()
        stopTestTone()
        cancelStreamingPlayback(reason: "new streaming source")
        detachSourceNodes()
        detachRendererSourceNode()

        let metadata = Self.streamingMetadata(for: descriptor)
        let context = StreamingPlaybackContext(
            source: source,
            descriptor: descriptor,
            layout: descriptor.channelLayout,
            metadata: metadata,
            monoFormat: monoFormat
        )

        loadedFile = nil
        liveInputSource = nil
        streamingPlayback = context
        currentStartFrame = 0
        pausedPlaybackNeedsReschedule = false
        state = .ready
        completionToken = context.token

        rebuildStreamingPlaybackGraph(for: context, debugTiming: debugTiming)
        applyTuning(tuning)

        source.start()
        do {
            try await scheduleStreamingPreroll(for: context, debugTiming: debugTiming)
        } catch {
            cancelStreamingPlayback(reason: "initial preroll failed")
            throw error
        }

        if !engine.isRunning {
            try engine.start()
            AppLogger.shared.notice(category: "engine", "AVAudioEngine started for streaming local playback.")
        }
        debugTiming?.log(
            "playback scheduled",
            fileURL: descriptor.url,
            extra: [
                "scheduledFrames=\(context.scheduledFrames)",
                "currentBytes=\(context.scheduledBytes)",
                "capBytes=\(Self.maxStreamingScheduledPCMBytes)"
            ]
        )
        startPlayers()
        state = .playing
        startStreamingScheduleTask(for: context, debugTiming: debugTiming)
        debugTiming?.log(
            "playback started",
            fileURL: descriptor.url,
            extra: [
                "scheduledFrames=\(context.scheduledFrames)",
                "currentBytes=\(context.scheduledBytes)",
                "capBytes=\(Self.maxStreamingScheduledPCMBytes)"
            ]
        )

        AppLogger.shared.notice(
            category: "streaming",
            "Started streaming playback file=\(descriptor.url.lastPathComponent) channels=\(descriptor.channelCount) sampleRate=\(String(format: "%.1f", descriptor.sourceSampleRate)) scheduledBytes=\(context.scheduledBytes)"
        )
        debugTiming?.log(
            "streaming engine commit finish",
            fileURL: descriptor.url,
            extra: [
                "commitMs=\(String(format: "%.1f", Double(DispatchTime.now().uptimeNanoseconds - commitStart) / 1_000_000.0))",
                "scheduledFrames=\(context.scheduledFrames)",
                "scheduledBytes=\(context.scheduledBytes)"
            ]
        )
    }

    func updateRenderer(
        mode: RendererRenderMode,
        scene: RendererSceneModel,
        directRendererAudioEnabled: Bool
    ) {
        rendererMode = mode
        rendererScene = scene
        self.directRendererAudioEnabled = directRendererAudioEnabled

        guard let loadedFile, liveInputSource == nil, testToneNodes.isEmpty else { return }
        guard state != .playing, state != .paused else {
            AppLogger.shared.info(category: "renderer", "Deferred renderer graph rebuild until playback stops or resumes.")
            return
        }

        rebuildPlaybackGraph(for: loadedFile)
        applyTuning(tuning)
        AppLogger.shared.notice(
            category: "renderer",
            "Configured renderer mode=\(mode.rawValue) directAudio=\(directRendererAudioEnabled) matrix=\(scene.matrix.inputCount)x\(scene.matrix.outputCount)"
        )
    }

    func setOutputVolume(_ volume: Float) {
        engine.mainMixerNode.outputVolume = min(max(volume, 0), 1)
        diagnosticMonitorEngine.mainMixerNode.outputVolume = min(max(volume, 0), 1)
    }

    func setDiagnosticMonitorOutputDevice(_ deviceID: AudioDeviceID?) throws {
        guard let deviceID, deviceID != 0 else {
            diagnosticMonitorOutputDeviceID = nil
            return
        }

        guard let audioUnit = diagnosticMonitorEngine.outputNode.audioUnit else {
            throw OutputDeviceSelectionError.outputAudioUnitUnavailable
        }

        if diagnosticMonitorEngine.isRunning {
            diagnosticMonitorEngine.stop()
        }

        var selectedDeviceID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &selectedDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        guard status == noErr else {
            throw OutputDeviceSelectionError.setDeviceFailed(status)
        }

        diagnosticMonitorOutputDeviceID = deviceID
        AppLogger.shared.notice(category: "engine", "Selected diagnostic monitor output device id=\(deviceID).")
    }

    func startLiveInput(
        activeChannelCount requestedChannelCount: Int,
        inputRoute: InputRouteInfo,
        sourceName: String = "Live Input",
        rendererMode: RendererRenderMode = .automatic,
        rendererPreset: RendererPreset = .sonicSphere30Point1,
        directRendererAudioEnabled: Bool = false
    ) throws -> LiveInputSource {
        stopTestTone()
        stop()
        detachPlayerNodes()
        detachRendererSourceNode()
        detachSourceNodes()
        cancelStreamingPlayback(reason: "live input started")

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

        guard requestedChannelCount > 0,
              requestedChannelCount <= Int(availableChannels),
              OrbisonicAudioLimits.supportsSourceChannelCount(requestedChannelCount)
        else {
            throw LiveInputError.unsupportedChannelRequest(
                requested: requestedChannelCount,
                available: availableChannels,
                maxSupported: OrbisonicAudioLimits.maxSourceChannelCount
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
        let liveRendererScene = RendererMatrixBuilder.sceneModel(
            for: layout,
            preset: rendererPreset,
            renderMode: rendererMode
        )
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
        liveInputMuted = false
        loadedFile = nil
        currentStartFrame = 0
        self.rendererMode = liveRendererScene.renderMode
        rendererScene = liveRendererScene
        self.directRendererAudioEnabled = directRendererAudioEnabled

        if directRendererAudioEnabled,
           liveRendererScene.renderMode.usesDirectRendererAudio,
           liveRendererScene.matrix.inputCount == requestedChannelCount,
           liveRendererScene.matrix.outputCount > 0 {
            let rendererFormat = try rendererOutputFormat(
                channelCount: liveRendererScene.matrix.outputCount,
                sampleRate: sampleRate
            )
            let matrix = liveRendererScene.matrix
            let sourceNode = AVAudioSourceNode { [weak self, weak pipe] _, _, frameCount, audioBufferList in
                let status = pipe?.render(matrix: matrix, audioBufferList: audioBufferList, frameCount: frameCount) ?? noErr
                if self?.liveInputMuted == true {
                    Self.clear(audioBufferList: audioBufferList, frameCount: Int(frameCount))
                }
                return status
            }
            sourceNodes = [sourceNode]
            engine.attach(sourceNode)
            engine.connect(sourceNode, to: engine.mainMixerNode, format: rendererFormat)
        } else {
            sourceNodes = layout.channels.enumerated().map { index, _ in
                AVAudioSourceNode { [weak self, weak pipe] _, _, frameCount, audioBufferList in
                    let status = pipe?.render(channelIndex: index, audioBufferList: audioBufferList, frameCount: frameCount) ?? noErr
                    if self?.liveInputMuted == true {
                        Self.clear(audioBufferList: audioBufferList, frameCount: Int(frameCount))
                    }
                    return status
                }
            }

            for sourceNode in sourceNodes {
                engine.attach(sourceNode)
                engine.connect(sourceNode, to: environment, format: monoFormat)
            }
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
            "Started live input source=\(sourceName) input=\(inputRoute.deviceName) inputUID=\(inputRoute.uid) inputChannels=\(availableChannels) activeChannels=\(requestedChannelCount) sampleRate=\(sampleRate) layout=\(layout.name) rendererMode=\(rendererMode.rawValue) directAudio=\(directRendererAudioEnabled)"
        )

        return liveSource
    }

    func play(debugTiming: DebugTimingContext? = nil) throws {
        stopTestTone()

        if let streamingPlayback {
            try playStreaming(streamingPlayback, debugTiming: debugTiming)
            return
        }

        guard let loadedFile else {
            AppLogger.shared.error(category: "engine", "Play requested with no loaded file.")
            return
        }

        if usesDirectRendererPlayback {
            try playDirectRenderer(loadedFile: loadedFile, debugTiming: debugTiming)
            return
        }

        if !engine.isRunning {
            try engine.start()
            AppLogger.shared.notice(category: "engine", "AVAudioEngine started successfully.")
        }

        switch state {
        case .paused:
            if pausedPlaybackNeedsReschedule {
                scheduleFromCurrentPosition(debugTiming: debugTiming)
                startPlayers()
                AppLogger.shared.notice(category: "transport", "Rescheduled paused playback at frame=\(currentStartFrame).")
            } else {
                playerNodes.forEach { $0.play() }
            }
            pausedPlaybackNeedsReschedule = false
            state = .playing
            AppLogger.shared.notice(category: "transport", "Resumed playback at \(formatTime(currentTime())) / \(loadedFile.metadata.durationText).")
        case .playing:
            AppLogger.shared.debug(category: "transport", "Play requested while already playing.")
        case .idle, .ready:
            scheduleFromCurrentPosition(debugTiming: debugTiming)
            debugTiming?.log(
                "playback scheduled",
                fileURL: loadedFile.url,
                extra: [
                    "startFrame=\(currentStartFrame)",
                    "preparedBytes=\(loadedFile.preparedPCMByteCount)"
                ]
            )
            startPlayers()
            state = .playing
            debugTiming?.log(
                "playback started",
                fileURL: loadedFile.url,
                extra: [
                    "startFrame=\(currentStartFrame)",
                    "preparedBytes=\(loadedFile.preparedPCMByteCount)"
                ]
            )
            AppLogger.shared.notice(
                category: "transport",
                "Started playback state=\(state.rawValue) startFrame=\(currentStartFrame) layout=\(loadedFile.layout.name)"
            )
        }
    }

    func pause() {
        guard state == .playing else { return }
        currentStartFrame = playbackFrame()
        pausedPlaybackNeedsReschedule = false
        if streamingPlayback != nil {
            playerNodes.forEach { $0.pause() }
        } else if usesDirectRendererPlayback {
            engine.pause()
            resetMonitorMeterLevels()
        } else {
            playerNodes.forEach { $0.pause() }
        }
        state = .paused
        AppLogger.shared.notice(category: "transport", "Paused playback at frame=\(currentStartFrame) time=\(formatTime(currentTime())).")
    }

    func setLiveInputMuted(_ muted: Bool) {
        guard liveInputSource != nil else { return }
        liveInputMuted = muted
        AppLogger.shared.notice(category: "live-input", "Live input mute=\(muted)")
    }

    func setOutputDevice(_ deviceID: AudioDeviceID) throws {
        guard deviceID != 0 else {
            throw OutputDeviceSelectionError.invalidDevice
        }

        guard let audioUnit = engine.outputNode.audioUnit else {
            throw OutputDeviceSelectionError.outputAudioUnitUnavailable
        }

        if engine.isRunning {
            markPausedPlaybackNeedsReschedule(reason: "output device change")
            engine.stop()
            resetMonitorMeterLevels()
        }

        var selectedDeviceID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &selectedDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        guard status == noErr else {
            throw OutputDeviceSelectionError.setDeviceFailed(status)
        }

        AppLogger.shared.notice(category: "engine", "Selected output device id=\(deviceID).")
    }

    @discardableResult
    func setOutputDevicePreservingPlayback(_ deviceID: AudioDeviceID) throws -> Bool {
        let snapshot = OutputDevicePlaybackSnapshot(
            wasEngineRunning: engine.isRunning,
            transportState: state,
            resumeFrame: playbackFrame(),
            wasDirectRendererPlayback: usesDirectRendererPlayback,
            hadLiveInput: liveInputSource != nil || livePipe != nil || liveCapture != nil || !sourceNodes.isEmpty,
            hadTestTone: !testToneNodes.isEmpty
        )

        do {
            try setOutputDevice(deviceID)
        } catch {
            _ = try? restorePlayback(afterOutputDeviceChange: snapshot)
            throw error
        }

        return try restorePlayback(afterOutputDeviceChange: snapshot)
    }

    func stop() {
        let hadStreamingPlayback = streamingPlayback != nil
        playerNodes.forEach { $0.stop() }
        resetRendererPlayback(to: 0)
        cancelStreamingPlayback(reason: "transport stop")
        if liveInputSource != nil {
            stopLiveInput()
        }
        stopTestTone()
        stopDiagnosticMonitorTone()
        stopEngineIfRunning(reason: "transport stop")
        completionToken = UUID()
        currentStartFrame = 0
        pausedPlaybackNeedsReschedule = false
        state = (loadedFile == nil && !hadStreamingPlayback) ? .idle : .ready
        AppLogger.shared.notice(category: "transport", "Stopped playback. state=\(state.rawValue)")
    }

    func playTestTone(_ point: TestTonePipelinePoint, monitorDownmix: Bool = false) throws {
        playerNodes.forEach { $0.stop() }
        detachRendererSourceNode()
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

        if monitorDownmix {
            try playDiagnosticMonitorTone(
                frequency: point.frequency,
                sampleRate: sampleRate,
                gain: min(point.gain * 1.8, 0.28)
            )
        }

        AppLogger.shared.notice(
            category: "diagnostics",
            "Started test tone point=\(point.rawValue) frequency=\(point.frequency)Hz route=\(point.pipelineDescription) monitorDownmix=\(monitorDownmix)"
        )
    }

    func playDiagnosticChannelTone(channelIndex: Int, channelCount: Int, monitorDownmix: Bool = false) throws {
        guard channelCount > 0, channelIndex >= 0, channelIndex < channelCount else {
            throw OutputDeviceSelectionError.invalidDiagnosticChannel(channelIndex, channelCount)
        }

        playerNodes.forEach { $0.stop() }
        detachRendererSourceNode()
        if liveInputSource != nil {
            stopLiveInput()
        }
        stopTestTone()

        let sampleRate = preferredOutputSampleRate()
        let channelFormat = try diagnosticChannelFormat(channelCount: channelCount, sampleRate: sampleRate)

        let node: AVAudioSourceNode
        let diagnosticAudioDescription: String
        if let speechClip = DiagnosticSpeechRenderer.clip(for: channelIndex + 1) {
            node = makeChannelVoiceNode(
                clip: speechClip,
                channelIndex: channelIndex,
                outputSampleRate: sampleRate
            )
            diagnosticAudioDescription = "speechSampleRate=\(speechClip.sampleRate) outputSampleRate=\(sampleRate)"
        } else {
            let frequency = 440 + Double(channelIndex % 12) * 18
            node = makeChannelToneNode(
                channelIndex: channelIndex,
                frequency: frequency,
                sampleRate: sampleRate,
                gain: 0.14
            )
            diagnosticAudioDescription = "fallbackToneFrequency=\(frequency)Hz outputSampleRate=\(sampleRate)"
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: channelFormat)
        testToneNodes = [node]

        if !engine.isRunning {
            try engine.start()
            AppLogger.shared.notice(category: "engine", "AVAudioEngine started for channel diagnostic tone.")
        }

        if monitorDownmix {
            if let speechClip = DiagnosticSpeechRenderer.clip(for: channelIndex + 1) {
                try playDiagnosticMonitorVoice(clip: speechClip, sampleRate: sampleRate)
            } else {
                let frequency = 440 + Double(channelIndex % 12) * 18
                try playDiagnosticMonitorTone(frequency: frequency, sampleRate: sampleRate, gain: 0.18)
            }
        }

        AppLogger.shared.notice(
            category: "diagnostics",
            "Started channel diagnostic tone channel=\(channelIndex + 1)/\(channelCount) \(diagnosticAudioDescription) monitorDownmix=\(monitorDownmix)"
        )
    }

    private func diagnosticChannelFormat(channelCount: Int, sampleRate: Double) throws -> AVAudioFormat {
        guard channelCount > 2 else {
            guard let format = AVAudioFormat(
                standardFormatWithSampleRate: sampleRate,
                channels: AVAudioChannelCount(channelCount)
            ) else {
                throw OutputDeviceSelectionError.diagnosticFormatCreationFailed(
                    channelCount: channelCount,
                    sampleRate: sampleRate
                )
            }
            return format
        }

        let layoutTag = AudioChannelLayoutTag(kAudioChannelLayoutTag_DiscreteInOrder | UInt32(channelCount))
        guard let layout = AVAudioChannelLayout(layoutTag: layoutTag) else {
            throw OutputDeviceSelectionError.diagnosticFormatCreationFailed(
                channelCount: channelCount,
                sampleRate: sampleRate
            )
        }

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            interleaved: false,
            channelLayout: layout
        )

        return format
    }

    func stopTestTone() {
        stopDiagnosticMonitorTone()
        guard !testToneNodes.isEmpty else { return }

        testToneNodes.forEach { node in
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }
        testToneNodes = []
        AppLogger.shared.notice(category: "diagnostics", "Stopped test tone.")
    }

    private func stopDiagnosticMonitorTone() {
        guard !diagnosticMonitorToneNodes.isEmpty || diagnosticMonitorEngine.isRunning else { return }

        diagnosticMonitorToneNodes.forEach { node in
            diagnosticMonitorEngine.disconnectNodeOutput(node)
            diagnosticMonitorEngine.detach(node)
        }
        diagnosticMonitorToneNodes = []
        if diagnosticMonitorEngine.isRunning {
            diagnosticMonitorEngine.stop()
        }
        AppLogger.shared.notice(category: "diagnostics", "Stopped diagnostic monitor downmix.")
    }

    func seek(toProgress progress: Double) {
        if let streamingPlayback {
            let clampedProgress = progress.clamped(to: 0...1)
            let frameCount = streamingPlayback.durationFrames
            let nextFrame = AVAudioFramePosition(Double(frameCount) * clampedProgress)
            currentStartFrame = min(nextFrame, max(frameCount - 1, 0))
            AppLogger.shared.info(
                category: "streaming",
                "Streaming seek requested progress=\(String(format: "%.3f", clampedProgress)) frame=\(currentStartFrame); canceling current streaming decode."
            )
            playerNodes.forEach { $0.stop() }
            cancelStreamingPlayback(reason: "seek")
            pausedPlaybackNeedsReschedule = false
            state = .ready
            return
        }

        guard let loadedFile else { return }
        let clampedProgress = progress.clamped(to: 0...1)
        let nextFrame = AVAudioFramePosition(Double(loadedFile.frameCount) * clampedProgress)
        currentStartFrame = min(nextFrame, max(loadedFile.frameCount - 1, 0))

        AppLogger.shared.info(
            category: "transport",
            "Seek requested progress=\(String(format: "%.3f", clampedProgress)) frame=\(currentStartFrame)"
        )

        if state == .playing {
            if usesDirectRendererPlayback {
                resetRendererPlayback(to: currentStartFrame)
            } else {
                playerNodes.forEach { $0.stop() }
                scheduleFromCurrentPosition()
                startPlayers()
            }
        } else if state == .paused {
            playerNodes.forEach { $0.stop() }
            resetRendererPlayback(to: currentStartFrame)
            markPausedPlaybackNeedsReschedule(reason: "seek while paused")
        }
    }

    func currentTime() -> TimeInterval {
        if liveInputSource != nil {
            return Date().timeIntervalSince(liveStartDate ?? Date())
        }

        if let streamingPlayback {
            guard streamingPlayback.descriptor.sourceSampleRate > 0 else { return 0 }
            return Double(playbackFrame()) / streamingPlayback.descriptor.sourceSampleRate
        }

        guard let loadedFile else { return 0 }
        return Double(playbackFrame()) / loadedFile.sampleRate
    }

    func duration() -> TimeInterval {
        if liveInputSource != nil {
            return 0
        }

        if let streamingPlayback {
            return streamingPlayback.durationSeconds
        }

        return loadedFile?.duration ?? 0
    }

    func channelMeterLevels() -> [Float] {
        if let livePipe {
            return livePipe.latestMeterLevels()
        }

        if let streamingPlayback {
            guard state == .playing || state == .paused else {
                return Array(repeating: 0, count: streamingPlayback.layout.channelCount)
            }
            return Array(repeating: 0, count: streamingPlayback.layout.channelCount)
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
            "Updated tuning preset=\(tuning.preset.rawValue) frontAngle=\(tuning.frontAngle) rearAngle=\(tuning.rearAngle)"
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

    private struct OutputDevicePlaybackSnapshot {
        let wasEngineRunning: Bool
        let transportState: TransportState
        let resumeFrame: AVAudioFramePosition
        let wasDirectRendererPlayback: Bool
        let hadLiveInput: Bool
        let hadTestTone: Bool
    }

    @discardableResult
    private func restorePlayback(afterOutputDeviceChange snapshot: OutputDevicePlaybackSnapshot) throws -> Bool {
        guard snapshot.wasEngineRunning else { return false }

        if snapshot.transportState == .playing, let loadedFile {
            currentStartFrame = min(snapshot.resumeFrame, loadedFile.frameCount)
            if snapshot.wasDirectRendererPlayback {
                resetRendererPlayback(to: currentStartFrame)
                if !engine.isRunning {
                    try engine.start()
                }
            } else {
                scheduleFromCurrentPosition()
                if !engine.isRunning {
                    try engine.start()
                }
                startPlayers()
            }
            state = .playing
            AppLogger.shared.notice(category: "transport", "Resumed playback after output device change at frame=\(currentStartFrame).")
            return true
        }

        if snapshot.transportState == .paused, let loadedFile {
            currentStartFrame = min(snapshot.resumeFrame, loadedFile.frameCount)
            if snapshot.wasDirectRendererPlayback {
                resetRendererPlayback(to: currentStartFrame)
            } else {
                pausedPlaybackNeedsReschedule = true
            }
            if !engine.isRunning {
                try engine.start()
            }
            state = .paused
            AppLogger.shared.notice(category: "transport", "Preserved paused playback after output device change at frame=\(currentStartFrame).")
            return true
        }

        if snapshot.hadLiveInput || snapshot.hadTestTone {
            if !engine.isRunning {
                try engine.start()
            }
            state = snapshot.transportState
            AppLogger.shared.notice(category: "engine", "Restarted AVAudioEngine after output device change.")
            return true
        }

        if !engine.isRunning {
            try engine.start()
        }
        return true
    }

    private var usesDirectRendererPlayback: Bool {
        directRendererAudioEnabled && rendererMode.usesDirectRendererAudio && rendererSourceNode != nil
    }

    private func markPausedPlaybackNeedsReschedule(reason: String) {
        guard state == .paused else { return }
        pausedPlaybackNeedsReschedule = true
        AppLogger.shared.debug(category: "transport", "Paused playback will reschedule on resume. reason=\(reason) frame=\(currentStartFrame)")
    }

    private func rebuildStreamingPlaybackGraph(
        for context: StreamingPlaybackContext,
        debugTiming: DebugTimingContext? = nil
    ) {
        let graphStart = DispatchTime.now().uptimeNanoseconds
#if DEBUG
        debugPlaybackGraphBuildCount += 1
#endif
        debugTiming?.log("streaming graph rebuild start", fileURL: context.descriptor.url)
        detachPlayerNodes()
        detachRendererSourceNode()

        playerNodes = context.layout.channels.map { _ in AVAudioPlayerNode() }
        for player in playerNodes {
            engine.attach(player)
            engine.connect(player, to: environment, format: context.monoFormat)
        }

        AppLogger.shared.info(
            category: "streaming",
            "Rebuilt streaming player graph with \(playerNodes.count) mono point sources."
        )
        debugTiming?.log(
            "streaming graph rebuild end",
            fileURL: context.descriptor.url,
            extra: [
                "graphMs=\(String(format: "%.1f", Double(DispatchTime.now().uptimeNanoseconds - graphStart) / 1_000_000.0))",
                "playerNodes=\(playerNodes.count)"
            ]
        )
    }

    private func scheduleStreamingPreroll(
        for context: StreamingPlaybackContext,
        debugTiming: DebugTimingContext?
    ) async throws {
        let targetFrames = AVAudioFramePosition(StreamingLocalPlaybackPolicy.initialPrerollFrames)
        while context.scheduledFrames < targetFrames {
            try Task.checkCancellation()
            guard streamingPlayback?.token == context.token else {
                throw CancellationError()
            }
            guard let chunk = try await context.source.nextChunk() else {
                context.reachedEndOfSource = true
                break
            }
            try scheduleStreamingChunk(chunk, for: context, debugTiming: debugTiming)
        }

        guard context.scheduledFrames > 0 else {
            throw StreamingAudioFileSourceError.sourceClosed
        }
    }

    private func startStreamingScheduleTask(
        for context: StreamingPlaybackContext,
        debugTiming: DebugTimingContext?
    ) {
        context.scheduleTask?.cancel()
        context.scheduleTask = Task { @MainActor [weak self, weak context] in
            guard let self, let context else { return }
            do {
                while !Task.isCancelled {
                    guard self.streamingPlayback?.token == context.token else { return }
                    if context.reachedEndOfSource {
                        if context.scheduledFrames == 0 {
                            self.finishStreamingPlaybackNaturally(token: context.token)
                        }
                        return
                    }

                    if self.streamingScheduleIsFull(context) {
                        try await Task.sleep(nanoseconds: 10_000_000)
                        continue
                    }

                    guard let chunk = try await context.source.nextChunk() else {
                        context.reachedEndOfSource = true
                        if context.scheduledFrames == 0 {
                            self.finishStreamingPlaybackNaturally(token: context.token)
                            return
                        }
                        continue
                    }

                    try self.scheduleStreamingChunk(chunk, for: context, debugTiming: debugTiming)
                }
            } catch is CancellationError {
                AppLogger.shared.info(category: "streaming", "Streaming scheduler canceled file=\(context.descriptor.url.lastPathComponent)")
                debugTiming?.log("streaming scheduler canceled", fileURL: context.descriptor.url)
            } catch {
                guard self.streamingPlayback?.token == context.token else { return }
                AppLogger.shared.error(category: "streaming", "Streaming scheduler failed file=\(context.descriptor.url.lastPathComponent) error=\(error.localizedDescription)")
                debugTiming?.log(
                    "streaming scheduler failed",
                    fileURL: context.descriptor.url,
                    extra: ["error=\"\(error.localizedDescription)\""]
                )
                self.stop()
            }
        }
    }

    private func streamingScheduleIsFull(_ context: StreamingPlaybackContext) -> Bool {
        let byteCapReached = context.scheduledBytes >= Self.maxStreamingScheduledPCMBytes
        let frameCap = AVAudioFramePosition(
            max(context.descriptor.sourceSampleRate * Self.maxStreamingScheduledAheadSeconds, 0)
                .rounded(.up)
        )
        let frameCapReached = frameCap > 0 && context.scheduledFrames >= frameCap
        return byteCapReached || frameCapReached
    }

    private func scheduleStreamingChunk(
        _ chunk: PCMChunk,
        for context: StreamingPlaybackContext,
        debugTiming: DebugTimingContext?
    ) throws {
        guard streamingPlayback?.token == context.token else {
            chunk.recycleBuffer()
            throw CancellationError()
        }

        let scheduledChunk = try makeScheduledStreamingChunk(from: chunk, context: context)
        chunk.recycleBuffer()
        guard context.scheduledBytes + scheduledChunk.byteCount <= Self.maxStreamingScheduledPCMBytes else {
            scheduledChunk.monoBuffers.forEach { context.monoBufferPool.recycle($0) }
            throw StreamingAudioFileSourceError.chunkExceedsQueueLimit(
                chunkBytes: scheduledChunk.byteCount,
                maxBytes: Self.maxStreamingScheduledPCMBytes
            )
        }

        context.scheduledChunks[scheduledChunk.id] = scheduledChunk
        context.scheduledFrames += AVAudioFramePosition(scheduledChunk.frameCount)
        context.scheduledBytes += scheduledChunk.byteCount
        context.scheduledChunkCount += 1
#if DEBUG
        debugScheduleFromCurrentPositionCount += 1
#endif

        for (index, player) in playerNodes.enumerated() {
            let buffer = scheduledChunk.monoBuffers[index]
            if index == 0 {
                let token = context.token
                let chunkID = scheduledChunk.id
                player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.streamingChunkDidFinish(chunkID: chunkID, token: token)
                    }
                }
            } else {
                player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack)
            }
        }

        if context.scheduledChunkCount == 1 || context.scheduledChunkCount.isMultiple(of: 16) {
            AppLogger.shared.debug(
                category: "streaming",
                "Scheduled streaming chunk file=\(context.descriptor.url.lastPathComponent) startFrame=\(scheduledChunk.startFrame) frames=\(scheduledChunk.frameCount) currentBytes=\(context.scheduledBytes) capBytes=\(Self.maxStreamingScheduledPCMBytes)"
            )
            debugTiming?.log(
                context.scheduledChunkCount == 1 ? "first chunk playback scheduled" : "streaming schedule buffer usage",
                fileURL: context.descriptor.url,
                extra: [
                    "startFrame=\(scheduledChunk.startFrame)",
                    "frameCount=\(scheduledChunk.frameCount)",
                    "chunkBytes=\(scheduledChunk.byteCount)",
                    "scheduledFrames=\(context.scheduledFrames)",
                    "currentBytes=\(context.scheduledBytes)",
                    "capBytes=\(Self.maxStreamingScheduledPCMBytes)"
                ]
            )
        }
    }

    private func makeScheduledStreamingChunk(
        from chunk: PCMChunk,
        context: StreamingPlaybackContext
    ) throws -> StreamingScheduledChunk {
        guard let channelData = chunk.buffer.floatChannelData else {
            throw AudioFileLoaderError.formatConversionFailed("missing streaming chunk float channel data")
        }

        let frameCount = chunk.frameCount
        let sourceChannelCount = Int(chunk.buffer.format.channelCount)
        var monoBuffers: [AVAudioPCMBuffer] = []
        monoBuffers.reserveCapacity(context.layout.channelCount)

        for channelIndex in 0..<context.layout.channelCount {
            guard let monoBuffer = context.monoBufferPool.checkout(frameCapacity: frameCount),
                  let monoData = monoBuffer.floatChannelData
            else {
                throw AudioFileLoaderError.monoBufferAllocationFailed
            }

            monoBuffer.frameLength = frameCount
            let destination = monoData[0]
            if channelIndex < sourceChannelCount {
                destination.update(from: channelData[channelIndex], count: Int(frameCount))
            } else {
                destination.initialize(repeating: 0, count: Int(frameCount))
            }
            monoBuffers.append(monoBuffer)
        }

        return StreamingScheduledChunk(
            startFrame: chunk.startFrame,
            frameCount: frameCount,
            monoBuffers: monoBuffers
        )
    }

    private func streamingChunkDidFinish(chunkID: UUID, token: UUID) {
        guard let context = streamingPlayback,
              context.token == token,
              let chunk = context.scheduledChunks.removeValue(forKey: chunkID)
        else {
            AppLogger.shared.debug(category: "streaming", "Ignored stale streaming chunk completion.")
            return
        }

        context.scheduledFrames = max(context.scheduledFrames - AVAudioFramePosition(chunk.frameCount), 0)
        context.scheduledBytes = max(context.scheduledBytes - chunk.byteCount, 0)
        chunk.monoBuffers.forEach { context.monoBufferPool.recycle($0) }

        AppLogger.shared.debug(
            category: "streaming",
            "Streaming chunk consumed file=\(context.descriptor.url.lastPathComponent) chunkFrames=\(chunk.frameCount) scheduledBytes=\(context.scheduledBytes)"
        )

        if context.reachedEndOfSource && context.scheduledFrames == 0 {
            finishStreamingPlaybackNaturally(token: token)
        }
    }

    private func finishStreamingPlaybackNaturally(token: UUID) {
        guard let context = streamingPlayback,
              context.token == token,
              state == .playing
        else { return }

        AppLogger.shared.notice(category: "streaming", "Streaming playback finished naturally file=\(context.descriptor.url.lastPathComponent)")
        stop()
        onPlaybackEnded?()
    }

    private func playStreaming(
        _ context: StreamingPlaybackContext,
        debugTiming: DebugTimingContext?
    ) throws {
        if !engine.isRunning {
            try engine.start()
            AppLogger.shared.notice(category: "engine", "AVAudioEngine started for streaming playback.")
        }

        switch state {
        case .paused:
            playerNodes.forEach { $0.play() }
            pausedPlaybackNeedsReschedule = false
            state = .playing
            AppLogger.shared.notice(category: "streaming", "Resumed streaming playback at \(formatTime(currentTime())) / \(context.metadata.durationText).")
        case .playing:
            AppLogger.shared.debug(category: "streaming", "Streaming play requested while already playing.")
        case .idle, .ready:
            startPlayers()
            state = .playing
            startStreamingScheduleTask(for: context, debugTiming: debugTiming)
            AppLogger.shared.notice(category: "streaming", "Started streaming playback from ready state.")
        }
    }

    private func cancelStreamingPlayback(reason: String) {
        guard let context = streamingPlayback else { return }

        context.scheduleTask?.cancel()
        context.scheduleTask = nil
        context.source.cancel()
        Task {
            await context.source.clearBufferedChunks()
        }
        context.scheduledChunks.values.forEach { chunk in
            chunk.monoBuffers.forEach { context.monoBufferPool.recycle($0) }
        }
        context.scheduledChunks.removeAll()
        context.scheduledFrames = 0
        context.scheduledBytes = 0
        streamingPlayback = nil
        AppLogger.shared.info(category: "streaming", "Canceled streaming playback file=\(context.descriptor.url.lastPathComponent) reason=\(reason)")
    }

    private static func streamingMetadata(for descriptor: AudioAssetDescriptor) -> AudioSourceMetadata {
        AudioSourceMetadata(
            fileName: descriptor.url.lastPathComponent,
            containerName: descriptor.containerDescription ?? descriptor.url.pathExtension.trimmedNilIfBlank?.uppercased() ?? "Unknown",
            codecName: descriptor.codecDescription ?? "Unknown",
            layoutName: descriptor.channelLayout.name,
            channelSummary: descriptor.channelLayout.channelSummary,
            channelCount: descriptor.channelCount,
            sampleRate: descriptor.sourceSampleRate,
            bitDepth: 32,
            duration: descriptor.durationSeconds ?? 0,
            formatNote: "Streaming local playback; decoded in bounded chunks."
        )
    }

    private func rebuildPlaybackGraph(for loadedFile: LoadedAudioFile, debugTiming: DebugTimingContext? = nil) {
        let graphStart = DispatchTime.now().uptimeNanoseconds
#if DEBUG
        debugPlaybackGraphBuildCount += 1
#endif
        debugTiming?.log("replace current source graph rebuild start", fileURL: loadedFile.url)
        detachPlayerNodes()
        detachRendererSourceNode()

        if directRendererAudioEnabled,
           rendererMode.usesDirectRendererAudio,
           rendererScene.matrix.inputCount == loadedFile.layout.channelCount,
           rendererScene.matrix.outputCount > 0,
           let rendererFormat = try? rendererOutputFormat(
                channelCount: rendererScene.matrix.outputCount,
                sampleRate: loadedFile.sampleRate
           ) {
            let sourceNode = makeFileRendererNode(loadedFile: loadedFile, matrix: rendererScene.matrix)
            rendererSourceNode = sourceNode
            resetRendererPlayback(to: currentStartFrame)
            engine.attach(sourceNode)
            engine.connect(sourceNode, to: engine.mainMixerNode, format: rendererFormat)
            AppLogger.shared.info(
                category: "engine",
                "Rebuilt playback graph with direct FEY renderer outputs=\(rendererScene.matrix.outputCount) bypass=\(rendererScene.matrix.isBypass)."
            )
            debugTiming?.log(
                "replace current source graph rebuild end",
                fileURL: loadedFile.url,
                extra: [
                    "graphMs=\(String(format: "%.1f", Double(DispatchTime.now().uptimeNanoseconds - graphStart) / 1_000_000.0))",
                    "path=\"direct-renderer\""
                ]
            )
            return
        }

        playerNodes = loadedFile.layout.channels.map { _ in AVAudioPlayerNode() }

        for player in playerNodes {
            engine.attach(player)
            engine.connect(player, to: environment, format: loadedFile.monoFormat)
        }

        AppLogger.shared.info(
            category: "engine",
            "Rebuilt player graph with \(playerNodes.count) mono point sources."
        )
        debugTiming?.log(
            "replace current source graph rebuild end",
            fileURL: loadedFile.url,
            extra: [
                "graphMs=\(String(format: "%.1f", Double(DispatchTime.now().uptimeNanoseconds - graphStart) / 1_000_000.0))",
                "path=\"environment\"",
                "playerNodes=\(playerNodes.count)"
            ]
        )
    }

    private func playDirectRenderer(loadedFile: LoadedAudioFile, debugTiming: DebugTimingContext? = nil) throws {
        if rendererSourceNode == nil {
            rebuildPlaybackGraph(for: loadedFile, debugTiming: debugTiming)
        }

        guard rendererSourceNode != nil else {
            scheduleFromCurrentPosition(debugTiming: debugTiming)
            startPlayers()
            state = .playing
            return
        }

        switch state {
        case .paused:
            if !engine.isRunning {
                try engine.start()
                AppLogger.shared.notice(category: "engine", "AVAudioEngine restarted for direct renderer playback.")
            }
            state = .playing
            AppLogger.shared.notice(category: "transport", "Resumed direct renderer playback at \(formatTime(currentTime())) / \(loadedFile.metadata.durationText).")
        case .playing:
            AppLogger.shared.debug(category: "transport", "Direct renderer play requested while already playing.")
        case .idle, .ready:
            completionToken = UUID()
            debugTiming?.log("schedule buffer start", fileURL: loadedFile.url, extra: ["path=\"direct-renderer\""])
            resetRendererPlayback(to: currentStartFrame)
            debugTiming?.log("schedule buffer end", fileURL: loadedFile.url, extra: ["path=\"direct-renderer\""])
            if !engine.isRunning {
                try engine.start()
                AppLogger.shared.notice(category: "engine", "AVAudioEngine started for direct renderer playback.")
            }
            state = .playing
            AppLogger.shared.notice(
                category: "transport",
                "Started direct renderer playback state=\(state.rawValue) startFrame=\(currentStartFrame) layout=\(loadedFile.layout.name) outputs=\(rendererScene.matrix.outputCount)"
            )
        }
    }

    private func applyTuning(_ tuning: SpatialTuning) {
        environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: 0, pitch: 0, roll: 0)

        if let loadedFile {
            for (channel, player) in zip(loadedFile.layout.channels, playerNodes) {
                configureSpatialNode(player, for: channel, tuning: tuning)
            }
        }

        if let streamingPlayback {
            for (channel, player) in zip(streamingPlayback.layout.channels, playerNodes) {
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

    private func scheduleFromCurrentPosition(debugTiming: DebugTimingContext? = nil) {
        guard let loadedFile else { return }
        let scheduleStart = DispatchTime.now().uptimeNanoseconds
#if DEBUG
        debugScheduleFromCurrentPositionCount += 1
#endif
        debugTiming?.log(
            "schedule buffer start",
            fileURL: loadedFile.url,
            extra: ["startFrame=\(currentStartFrame)", "channels=\(playerNodes.count)"]
        )
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
                        guard self.state == .playing else {
                            AppLogger.shared.debug(
                                category: "transport",
                                "Ignored playback completion while state=\(self.state.rawValue)."
                            )
                            return
                        }
                        AppLogger.shared.notice(category: "transport", "Playback finished naturally.")
                        self.stop()
                        self.onPlaybackEnded?()
                    }
                }
            } else {
                player.scheduleBuffer(scheduledBuffer, at: nil, options: [])
            }
        }
        pausedPlaybackNeedsReschedule = false
        debugTiming?.log(
            "schedule buffer end",
            fileURL: loadedFile.url,
            extra: [
                "scheduleMs=\(String(format: "%.1f", Double(DispatchTime.now().uptimeNanoseconds - scheduleStart) / 1_000_000.0))",
                "channels=\(playerNodes.count)"
            ]
        )
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

    private func rendererOutputFormat(channelCount: Int, sampleRate: Double) throws -> AVAudioFormat {
        guard channelCount > 0 else {
            throw OutputDeviceSelectionError.rendererFormatCreationFailed(
                channelCount: channelCount,
                sampleRate: sampleRate
            )
        }

        if channelCount <= 2 {
            guard let format = AVAudioFormat(
                standardFormatWithSampleRate: sampleRate,
                channels: AVAudioChannelCount(channelCount)
            ) else {
                throw OutputDeviceSelectionError.rendererFormatCreationFailed(
                    channelCount: channelCount,
                    sampleRate: sampleRate
                )
            }
            return format
        }

        let layoutTag = AudioChannelLayoutTag(kAudioChannelLayoutTag_DiscreteInOrder | UInt32(channelCount))
        guard let layout = AVAudioChannelLayout(layoutTag: layoutTag) else {
            throw OutputDeviceSelectionError.rendererFormatCreationFailed(
                channelCount: channelCount,
                sampleRate: sampleRate
            )
        }

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            interleaved: false,
            channelLayout: layout
        )

        return format
    }

    private func makeFileRendererNode(loadedFile: LoadedAudioFile, matrix: RendererMatrix) -> AVAudioSourceNode {
        AVAudioSourceNode { [weak self, loadedFile, matrix] _, _, frameCount, audioBufferList in
            self?.renderLoadedFile(
                loadedFile: loadedFile,
                matrix: matrix,
                audioBufferList: audioBufferList,
                frameCount: frameCount
            ) ?? noErr
        }
    }

    private func renderLoadedFile(
        loadedFile: LoadedAudioFile,
        matrix: RendererMatrix,
        audioBufferList: UnsafeMutablePointer<AudioBufferList>,
        frameCount: AVAudioFrameCount
    ) -> OSStatus {
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let requestedFrames = Int(frameCount)
        guard requestedFrames > 0, matrix.inputCount == loadedFile.monoBuffers.count else {
            Self.clear(audioBufferList: audioBufferList, frameCount: requestedFrames)
            return noErr
        }

        for buffer in buffers {
            guard let rawData = buffer.mData else { continue }
            let sampleCount = min(
                Int(buffer.mDataByteSize) / MemoryLayout<Float>.stride,
                requestedFrames
            )
            rawData.assumingMemoryBound(to: Float.self).initialize(repeating: 0, count: sampleCount)
        }

        rendererPlaybackLock.lock()
        let startFrame = min(max(rendererPlaybackFrame, 0), loadedFile.frameCount)
        let framesRemaining = max(Int(loadedFile.frameCount - startFrame), 0)
        let framesToRender = min(requestedFrames, framesRemaining)
        rendererPlaybackFrame = startFrame + AVAudioFramePosition(framesToRender)
        let reachedEnd = rendererPlaybackFrame >= loadedFile.frameCount
        let shouldNotifyCompletion = reachedEnd && !rendererPlaybackCompletionSent
        if shouldNotifyCompletion {
            rendererPlaybackCompletionSent = true
        }
        rendererPlaybackLock.unlock()

        guard framesToRender > 0 else {
            if shouldNotifyCompletion {
                notifyDirectRendererPlaybackEnded()
            }
            return noErr
        }

        let outputLimit = min(buffers.count, matrix.outputCount)
        let sourceOffset = Int(startFrame)

        for inputIndex in 0..<matrix.inputCount {
            guard let sourceData = loadedFile.monoBuffers[inputIndex].floatChannelData else { continue }
            let input = sourceData[0].advanced(by: sourceOffset)

            for outputIndex in 0..<outputLimit {
                let gain = Float(matrix.gains[inputIndex][outputIndex])
                guard abs(gain) > 0.000_001,
                      let rawData = buffers[outputIndex].mData
                else {
                    continue
                }

                let output = rawData.assumingMemoryBound(to: Float.self)
                for frame in 0..<framesToRender {
                    output[frame] += input[frame] * gain
                }
            }
        }

        if shouldNotifyCompletion {
            notifyDirectRendererPlaybackEnded()
        }

        return noErr
    }

    private func notifyDirectRendererPlaybackEnded() {
        let token = completionToken
        Task { @MainActor [weak self] in
            guard let self, self.completionToken == token else { return }
            guard self.state == .playing else {
                AppLogger.shared.debug(
                    category: "transport",
                    "Ignored direct renderer playback completion while state=\(self.state.rawValue)."
                )
                return
            }
            AppLogger.shared.notice(category: "transport", "Direct renderer playback finished naturally.")
            self.stop()
            self.onPlaybackEnded?()
        }
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

    private func playDiagnosticMonitorTone(
        frequency: Double,
        sampleRate: Double,
        gain: Float
    ) throws {
        guard diagnosticMonitorOutputDeviceID != nil else { return }
        stopDiagnosticMonitorTone()

        let node = makeToneNode(frequency: frequency, sampleRate: sampleRate, gain: gain)
        guard let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw LiveInputError.monoFormatCreationFailed(sampleRate)
        }

        diagnosticMonitorEngine.attach(node)
        diagnosticMonitorEngine.connect(node, to: diagnosticMonitorEngine.mainMixerNode, format: stereoFormat)
        diagnosticMonitorToneNodes = [node]

        if !diagnosticMonitorEngine.isRunning {
            try diagnosticMonitorEngine.start()
            AppLogger.shared.notice(category: "engine", "Diagnostic monitor engine started.")
        }
    }

    private func playDiagnosticMonitorVoice(
        clip: DiagnosticSpeechClip,
        sampleRate: Double
    ) throws {
        guard diagnosticMonitorOutputDeviceID != nil else { return }
        stopDiagnosticMonitorTone()

        let node = makeMonitorVoiceNode(clip: clip, outputSampleRate: sampleRate)
        guard let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw LiveInputError.monoFormatCreationFailed(sampleRate)
        }

        diagnosticMonitorEngine.attach(node)
        diagnosticMonitorEngine.connect(node, to: diagnosticMonitorEngine.mainMixerNode, format: stereoFormat)
        diagnosticMonitorToneNodes = [node]

        if !diagnosticMonitorEngine.isRunning {
            try diagnosticMonitorEngine.start()
            AppLogger.shared.notice(category: "engine", "Diagnostic monitor speech engine started.")
        }
    }

    private func makeChannelToneNode(
        channelIndex: Int,
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

                for (bufferIndex, buffer) in buffers.enumerated() {
                    guard let rawData = buffer.mData else { continue }
                    rawData.assumingMemoryBound(to: Float.self)[frame] = bufferIndex == channelIndex ? sample : 0
                }
            }

            return noErr
        }
    }

    private func makeMonitorVoiceNode(
        clip: DiagnosticSpeechClip,
        outputSampleRate: Double
    ) -> AVAudioSourceNode {
        let playhead = DiagnosticSpeechPlayhead(
            clip: clip,
            targetSampleRate: outputSampleRate,
            gain: 0.50
        )

        return AVAudioSourceNode { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frames = Int(frameCount)

            for frame in 0..<frames {
                let sample = playhead.nextSample()

                for buffer in buffers {
                    guard let rawData = buffer.mData else { continue }
                    rawData.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }

            return noErr
        }
    }

    private func makeChannelVoiceNode(
        clip: DiagnosticSpeechClip,
        channelIndex: Int,
        outputSampleRate: Double
    ) -> AVAudioSourceNode {
        let playhead = DiagnosticSpeechPlayhead(
            clip: clip,
            targetSampleRate: outputSampleRate,
            gain: 0.72
        )

        return AVAudioSourceNode { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frames = Int(frameCount)

            for frame in 0..<frames {
                let sample = playhead.nextSample()

                for (bufferIndex, buffer) in buffers.enumerated() {
                    guard let rawData = buffer.mData else { continue }
                    rawData.assumingMemoryBound(to: Float.self)[frame] = bufferIndex == channelIndex ? sample : 0
                }
            }

            return noErr
        }
    }

    private func playbackFrame() -> AVAudioFramePosition {
        if let streamingPlayback {
            if state == .playing,
               let renderTime = playerNodes.first?.lastRenderTime,
               let playerTime = playerNodes.first?.playerTime(forNodeTime: renderTime) {
                let frame = currentStartFrame + AVAudioFramePosition(playerTime.sampleTime)
                if streamingPlayback.durationFrames > 0 {
                    return min(frame, streamingPlayback.durationFrames)
                }
                return max(frame, 0)
            }

            if streamingPlayback.durationFrames > 0 {
                return min(currentStartFrame, streamingPlayback.durationFrames)
            }
            return max(currentStartFrame, 0)
        }

        guard let loadedFile else { return 0 }

        if usesDirectRendererPlayback {
            rendererPlaybackLock.lock()
            let frame = rendererPlaybackFrame
            rendererPlaybackLock.unlock()
            return min(frame, loadedFile.frameCount)
        }

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
        liveInputMuted = false
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
        markPausedPlaybackNeedsReschedule(reason: "player graph detached")
        playerNodes.forEach { player in
            player.stop()
            engine.disconnectNodeOutput(player)
            engine.detach(player)
        }
        playerNodes = []
    }

    private func detachRendererSourceNode() {
        guard let rendererSourceNode else { return }
        engine.disconnectNodeOutput(rendererSourceNode)
        engine.detach(rendererSourceNode)
        self.rendererSourceNode = nil
        resetRendererPlayback(to: currentStartFrame)
    }

    private func detachSourceNodes() {
        sourceNodes.forEach { sourceNode in
            engine.disconnectNodeOutput(sourceNode)
            engine.detach(sourceNode)
        }
        sourceNodes = []
    }

    private func resetRendererPlayback(to frame: AVAudioFramePosition) {
        rendererPlaybackLock.lock()
        rendererPlaybackFrame = max(frame, 0)
        rendererPlaybackCompletionSent = false
        rendererPlaybackLock.unlock()
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

    private static func clear(audioBufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: Int) {
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

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
