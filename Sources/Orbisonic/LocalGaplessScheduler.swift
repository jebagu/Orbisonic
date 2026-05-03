import AVFoundation
import Foundation

enum LocalGaplessSchedulerState: String, Equatable, Sendable {
    case idle
    case ready
    case paused
    case stopped
}

enum LocalGaplessSchedulerError: LocalizedError, Equatable {
    case invalidQueue(String)
    case invalidQueueIndex(Int)
    case incompatibleOutputFormat(trackID: String)
    case generationInvalidated(expected: UInt64, actual: UInt64)
    case emptyBuffer
    case retainedPCMByteLimitExceeded(bufferBytes: Int, maxBytes: Int)

    var errorDescription: String? {
        switch self {
        case .invalidQueue(let message):
            "Invalid local gapless scheduler queue: \(message)"
        case .invalidQueueIndex(let index):
            "Invalid local gapless scheduler queue index: \(index)."
        case .incompatibleOutputFormat(let trackID):
            "Local gapless source \(trackID) does not match the scheduler output format."
        case .generationInvalidated(let expected, let actual):
            "Local gapless scheduler generation invalidated. expected=\(expected) actual=\(actual)"
        case .emptyBuffer:
            "Local gapless scheduler will not retain or schedule an empty buffer."
        case .retainedPCMByteLimitExceeded(let bufferBytes, let maxBytes):
            "Local gapless scheduler retained PCM cap exceeded. bufferBytes=\(bufferBytes) maxBytes=\(maxBytes)"
        }
    }
}

struct LocalGaplessSchedulerSnapshot: Equatable, Sendable {
    let state: LocalGaplessSchedulerState
    let generation: UInt64
    let queueCount: Int
    let currentIndex: Int?
    let currentTrack: LocalGaplessTrackDescriptor?
    let retainedBufferCount: Int
    let retainedPCMBytes: Int
    let scheduledAheadFrames: AVAudioFramePosition
}

protocol LocalGaplessPlayerScheduling: AnyObject {
    func scheduleGaplessBuffer(
        _ buffer: AVAudioPCMBuffer,
        completion: @escaping (AVAudioPlayerNodeCompletionCallbackType) -> Void
    )
    func playGapless()
    func pauseGapless()
    func stopGapless()
}

typealias LocalGaplessSourceFactory = (
    LocalGaplessTrackDescriptor,
    AVAudioFormat,
    LocalGaplessSchedulerConfig
) throws -> any LocalTrackSource

extension AVAudioPlayerNode: LocalGaplessPlayerScheduling {
    func scheduleGaplessBuffer(
        _ buffer: AVAudioPCMBuffer,
        completion: @escaping (AVAudioPlayerNodeCompletionCallbackType) -> Void
    ) {
        scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack, completionHandler: completion)
    }

    func playGapless() {
        play()
    }

    func pauseGapless() {
        pause()
    }

    func stopGapless() {
        stop()
    }
}

final class LocalGaplessScheduler: @unchecked Sendable {
    var onEvent: ((LocalGaplessSchedulerEvent) -> Void)?

    let playerNode: AVAudioPlayerNode
    let format: AVAudioFormat
    let config: LocalGaplessSchedulerConfig

    private let stateQueue = DispatchQueue(label: "Orbisonic.LocalGaplessScheduler")
    private let schedulingPlayer: LocalGaplessPlayerScheduling
    private let sourceFactory: LocalGaplessSourceFactory
    private var storage = SchedulerStorage()

    init(
        playerNode: AVAudioPlayerNode = AVAudioPlayerNode(),
        format: AVAudioFormat,
        config: LocalGaplessSchedulerConfig = LocalGaplessSchedulerConfig(),
        schedulingPlayer: LocalGaplessPlayerScheduling? = nil,
        sourceFactory: @escaping LocalGaplessSourceFactory = { track, format, config in
            try LocalAudioFileSource(track: track, outputFormat: format, config: config)
        }
    ) {
        self.playerNode = playerNode
        self.format = format
        self.config = config
        self.schedulingPlayer = schedulingPlayer ?? playerNode
        self.sourceFactory = sourceFactory
    }

    func start(source: any LocalTrackSource) throws {
        try start(sources: [source])
    }

    func start(track: LocalGaplessTrackDescriptor) throws {
        try start(queue: [track])
    }

    func start(
        queue: [LocalGaplessTrackDescriptor],
        startIndex: Int = 0
    ) throws {
        var fillGeneration: UInt64?
        let events = try stateQueue.sync {
            try Self.validate(queue: queue, startIndex: startIndex)
            Self.closeSources(Array(storage.openSources.values))
            storage.generation = Self.nextGeneration(after: storage.generation)
            storage.queue = queue
            storage.openSources = [:]
            storage.currentIndex = queue.isEmpty ? nil : startIndex
            storage.initialPlaybackIndex = storage.currentIndex
            storage.state = queue.isEmpty ? .stopped : .ready
            storage.resetSchedulingState()
            if queue.isEmpty {
                return [LocalGaplessSchedulerEvent.queueEnded]
            }
            do {
                _ = try openSourceLocked(at: startIndex)
                let preparationEvents = prepareNextSourceLocked(after: startIndex)
                fillGeneration = storage.generation
                return preparationEvents
            } catch {
                storage.state = .stopped
                storage.queueReadExhausted = true
                return [
                    LocalGaplessSchedulerEvent.sourceFailed(
                        track: queue[startIndex],
                        message: error.localizedDescription
                    )
                ]
            }
        }
        emit(events)
        if let fillGeneration {
            requestFill(generation: fillGeneration)
        }
    }

    func start(
        sources: [any LocalTrackSource],
        startIndex: Int = 0
    ) throws {
        var fillGeneration: UInt64?
        let events = try stateQueue.sync {
            try Self.validate(sources: sources, startIndex: startIndex, format: format)
            Self.closeSources(Array(storage.openSources.values))
            storage.generation = Self.nextGeneration(after: storage.generation)
            storage.queue = sources.map(\.track)
            storage.openSources = Dictionary(uniqueKeysWithValues: sources.enumerated().map { ($0.offset, $0.element) })
            storage.currentIndex = sources.isEmpty ? nil : startIndex
            storage.initialPlaybackIndex = storage.currentIndex
            storage.state = sources.isEmpty ? .stopped : .ready
            storage.resetSchedulingState()
            if sources.isEmpty {
                return [LocalGaplessSchedulerEvent.queueEnded]
            }
            let preparationEvents = prepareNextSourceLocked(after: startIndex)
            fillGeneration = storage.generation
            return preparationEvents
        }
        emit(events)
        if let fillGeneration {
            requestFill(generation: fillGeneration)
        }
    }

    func stop(reason: String = "stopped") {
        let events = stateQueue.sync {
            storage.generation = Self.nextGeneration(after: storage.generation)
            Self.closeSources(Array(storage.openSources.values))
            storage.queue = []
            storage.openSources = [:]
            storage.currentIndex = nil
            storage.initialPlaybackIndex = nil
            storage.state = .stopped
            storage.resetSchedulingState()
            return [LocalGaplessSchedulerEvent.schedulerStopped(reason: reason)]
        }
        schedulingPlayer.stopGapless()
        emit(events)
    }

    func pause() {
        stateQueue.sync {
            guard storage.state == .ready else { return }
            storage.state = .paused
        }
        schedulingPlayer.pauseGapless()
    }

    func resume() {
        var fillGeneration: UInt64?
        var shouldPlay = false
        stateQueue.sync {
            guard storage.state == .paused else { return }
            storage.state = .ready
            shouldPlay = storage.didStartPlayer
            fillGeneration = storage.generation
        }
        if shouldPlay {
            schedulingPlayer.playGapless()
        }
        if let fillGeneration {
            requestFill(generation: fillGeneration)
        }
    }

    func seek(to frame: AVAudioFramePosition) throws {
        var fillGeneration: UInt64?
        var shouldStopPlayer = false
        let events: [LocalGaplessSchedulerEvent] = stateQueue.sync {
            let shouldStopForDiscard = storage.didStartPlayer || !storage.retainedBuffers.isEmpty
            storage.generation = Self.nextGeneration(after: storage.generation)
            let currentIndex = storage.currentIndex
            if let currentIndex {
                let futureSources = storage.openSources
                    .filter { $0.key != currentIndex }
                    .map(\.value)
                Self.closeSources(futureSources)
                storage.openSources = storage.openSources.filter { $0.key == currentIndex }
            }
            storage.resetSchedulingState(keepStartedTrackIndices: currentIndex.map { Set([$0]) } ?? [])
            guard let currentIndex,
                  storage.queue.indices.contains(currentIndex)
            else { return [] }
            do {
                shouldStopPlayer = shouldStopForDiscard
                let source = try openSourceLocked(at: currentIndex)
                try source.seek(to: frame)
                storage.initialPlaybackIndex = currentIndex
                fillGeneration = storage.generation
                return []
            } catch {
                return [
                    LocalGaplessSchedulerEvent.sourceFailed(
                        track: storage.queue[currentIndex],
                        message: error.localizedDescription
                    )
                ]
            }
        }
        if shouldStopPlayer {
            schedulingPlayer.stopGapless()
        }
        emit(events)
        if let fillGeneration {
            requestFill(generation: fillGeneration)
        }
    }

    func rebuildQueue(
        queue: [LocalGaplessTrackDescriptor],
        currentIndex: Int = 0,
        seekFrame: AVAudioFramePosition? = nil,
        preserveCurrentTrackStart: Bool = false
    ) throws {
        var fillGeneration: UInt64?
        var shouldStopPlayer = false
        let events = try stateQueue.sync {
            try Self.validate(queue: queue, startIndex: currentIndex)
            let wasPaused = storage.state == .paused
            shouldStopPlayer = storage.didStartPlayer || !storage.retainedBuffers.isEmpty
            storage.generation = Self.nextGeneration(after: storage.generation)
            Self.closeSources(Array(storage.openSources.values))
            storage.queue = queue
            storage.openSources = [:]
            storage.currentIndex = queue.isEmpty ? nil : currentIndex
            storage.initialPlaybackIndex = storage.currentIndex
            storage.state = queue.isEmpty ? .stopped : (wasPaused ? .paused : .ready)
            storage.resetSchedulingState(
                keepStartedTrackIndices: preserveCurrentTrackStart ? Set([currentIndex]) : []
            )
            if queue.isEmpty {
                return [LocalGaplessSchedulerEvent.queueEnded]
            }
            do {
                let source = try openSourceLocked(at: currentIndex)
                if let seekFrame {
                    try source.seek(to: seekFrame)
                }
                let preparationEvents = prepareNextSourceLocked(after: currentIndex)
                fillGeneration = wasPaused ? nil : storage.generation
                return preparationEvents
            } catch {
                storage.state = .stopped
                storage.queueReadExhausted = true
                return [
                    LocalGaplessSchedulerEvent.sourceFailed(
                        track: queue[currentIndex],
                        message: error.localizedDescription
                    )
                ]
            }
        }
        if shouldStopPlayer {
            schedulingPlayer.stopGapless()
        }
        emit(events)
        if let fillGeneration {
            requestFill(generation: fillGeneration)
        }
    }

    func rebuildQueue(
        sources: [any LocalTrackSource],
        currentIndex: Int = 0
    ) throws {
        var fillGeneration: UInt64?
        var shouldStopPlayer = false
        let events = try stateQueue.sync {
            try Self.validate(sources: sources, startIndex: currentIndex, format: format)
            let wasPaused = storage.state == .paused
            shouldStopPlayer = storage.didStartPlayer || !storage.retainedBuffers.isEmpty
            storage.generation = Self.nextGeneration(after: storage.generation)
            Self.closeSources(Array(storage.openSources.values))
            storage.queue = sources.map(\.track)
            storage.openSources = Dictionary(uniqueKeysWithValues: sources.enumerated().map { ($0.offset, $0.element) })
            storage.currentIndex = sources.isEmpty ? nil : currentIndex
            storage.initialPlaybackIndex = storage.currentIndex
            storage.state = sources.isEmpty ? .stopped : (wasPaused ? .paused : .ready)
            storage.resetSchedulingState()
            if sources.isEmpty {
                return [LocalGaplessSchedulerEvent.queueEnded]
            }
            let preparationEvents = prepareNextSourceLocked(after: currentIndex)
            fillGeneration = wasPaused ? nil : storage.generation
            return preparationEvents
        }
        if shouldStopPlayer {
            schedulingPlayer.stopGapless()
        }
        emit(events)
        if let fillGeneration {
            requestFill(generation: fillGeneration)
        }
    }

    func skipTo(_ index: Int) throws {
        var fillGeneration: UInt64?
        var shouldStopPlayer = false
        let events: [LocalGaplessSchedulerEvent] = try stateQueue.sync {
            guard storage.queue.indices.contains(index) else {
                throw LocalGaplessSchedulerError.invalidQueueIndex(index)
            }
            let wasPaused = storage.state == .paused
            shouldStopPlayer = storage.didStartPlayer || !storage.retainedBuffers.isEmpty
            storage.generation = Self.nextGeneration(after: storage.generation)
            let staleSources = storage.openSources
                .filter { $0.key != index }
                .map(\.value)
            Self.closeSources(staleSources)
            storage.openSources = storage.openSources.filter { $0.key == index }
            storage.currentIndex = index
            storage.initialPlaybackIndex = index
            storage.state = wasPaused ? .paused : .ready
            storage.resetSchedulingState()
            do {
                let source = try openSourceLocked(at: index)
                try source.seek(to: 0)
                let preparationEvents = prepareNextSourceLocked(after: index)
                fillGeneration = wasPaused ? nil : storage.generation
                return preparationEvents
            } catch {
                return [
                    LocalGaplessSchedulerEvent.sourceFailed(
                        track: storage.queue[index],
                        message: error.localizedDescription
                    )
                ]
            }
        }
        if shouldStopPlayer {
            schedulingPlayer.stopGapless()
        }
        emit(events)
        if let fillGeneration {
            requestFill(generation: fillGeneration)
        }
    }

    func currentGeneration() -> UInt64 {
        stateQueue.sync { storage.generation }
    }

    func snapshot() -> LocalGaplessSchedulerSnapshot {
        stateQueue.sync {
            LocalGaplessSchedulerSnapshot(
                state: storage.state,
                generation: storage.generation,
                queueCount: storage.queue.count,
                currentIndex: storage.currentIndex,
                currentTrack: storage.currentTrack,
                retainedBufferCount: storage.retainedBuffers.count,
                retainedPCMBytes: storage.retainedPCMBytes,
                scheduledAheadFrames: storage.scheduledAheadFrames
            )
        }
    }

    @discardableResult
    func retainScheduledChunk(
        _ chunk: LocalDecodedChunk,
        generation: UInt64
    ) throws -> UUID {
        try stateQueue.sync {
            try retainScheduledChunkLocked(
                chunk,
                generation: generation,
                trackIndex: nil,
                endsLogicalTrack: chunk.endsLogicalTrack
            )
        }
    }

    @discardableResult
    func retainScheduledBuffer(
        _ buffer: AVAudioPCMBuffer,
        track: LocalGaplessTrackDescriptor? = nil,
        generation: UInt64
    ) throws -> UUID {
        try stateQueue.sync {
            try retainScheduledBufferLocked(buffer, track: track, generation: generation)
        }
    }

    func meteringSnapshot(
        trackID: String?,
        frame: AVAudioFramePosition,
        frameCount: AVAudioFrameCount
    ) -> LocalGaplessMeterSnapshot? {
        stateQueue.sync {
            guard frameCount > 0,
                  storage.state == .ready || storage.state == .paused
            else { return nil }

            let requestedStart = max(frame, 0)
            let matchingBuffers = storage.retainedBuffers.values
                .filter { retained in
                    retained.generation == storage.generation &&
                        retained.track != nil &&
                        (trackID == nil || retained.track?.id == trackID) &&
                        retained.sourceFrameRange.contains(requestedStart)
                }
                .sorted { lhs, rhs in
                    lhs.sourceFrameRange.lowerBound < rhs.sourceFrameRange.lowerBound
                }

            guard let retained = matchingBuffers.first,
                  let track = retained.track
            else { return nil }

            let bufferOffset = requestedStart - retained.sourceFrameRange.lowerBound
            guard bufferOffset >= 0,
                  bufferOffset < AVAudioFramePosition(retained.frameCount)
            else { return nil }

            let requestedFrames = AVAudioFramePosition(frameCount)
            let framesAvailableInRange = retained.sourceFrameRange.upperBound - requestedStart
            let framesAvailableInBuffer = AVAudioFramePosition(retained.frameCount) - bufferOffset
            let availableFrames = min(requestedFrames, framesAvailableInRange, framesAvailableInBuffer)
            guard availableFrames > 0 else { return nil }

            return LocalGaplessMeterSnapshot(
                buffer: retained.buffer,
                track: track,
                bufferFrameOffset: bufferOffset,
                frameCount: AVAudioFrameCount(availableFrames)
            )
        }
    }

    @discardableResult
    func scheduledBufferDidFinish(
        _ id: UUID,
        generation: UInt64
    ) -> Bool {
        let result = stateQueue.sync {
            guard generation == storage.generation else {
                return ScheduledBufferReleaseResult(
                    didRelease: false,
                    shouldRefill: false,
                    generation: storage.generation,
                    events: []
                )
            }
            guard let retained = storage.retainedBuffers.removeValue(forKey: id) else {
                return ScheduledBufferReleaseResult(
                    didRelease: false,
                    shouldRefill: false,
                    generation: storage.generation,
                    events: []
                )
            }
            storage.scheduledAheadFrames = max(
                0,
                storage.scheduledAheadFrames - AVAudioFramePosition(retained.frameCount)
            )
            storage.retainedPCMBytes = max(0, storage.retainedPCMBytes - retained.byteCount)
            var events: [LocalGaplessSchedulerEvent] = []
            if let trackIndex = retained.trackIndex,
               shouldEmitTrackEndLocked(for: trackIndex, retained: retained),
               storage.emittedTrackEndIndices.insert(trackIndex).inserted,
               let track = retained.track {
                events.append(.logicalTrackEnded(track))
                if let nextTrackStart = emitPendingTrackStartLocked(afterEndingTrackAt: trackIndex) {
                    events.append(nextTrackStart)
                }
            }
            if storage.queueReadExhausted, storage.retainedBuffers.isEmpty {
                events.append(contentsOf: finishQueueEndedLocked())
            }
            return ScheduledBufferReleaseResult(
                didRelease: true,
                shouldRefill: storage.state == .ready && storage.queueReadExhausted == false,
                generation: storage.generation,
                events: events
            )
        }
        emit(result.events)
        if result.shouldRefill {
            requestFill(generation: result.generation)
        }
        return result.didRelease
    }

    func flushPendingWorkForTesting() {
        stateQueue.sync {}
    }

    private func requestFill(generation: UInt64) {
        stateQueue.async { [weak self] in
            guard let self else { return }
            let events = self.fillScheduledAudioLocked(generation: generation)
            self.emit(events)
        }
    }

    private func fillScheduledAudioLocked(generation: UInt64) -> [LocalGaplessSchedulerEvent] {
        guard generation == storage.generation,
              storage.state == .ready,
              storage.currentIndex != nil
        else { return [] }

        let targetFrames = targetAheadFrames()
        var events: [LocalGaplessSchedulerEvent] = []

        while storage.queueReadExhausted == false,
              storage.scheduledAheadFrames < targetFrames {
            guard let currentIndex = storage.currentIndex,
                  storage.queue.indices.contains(currentIndex)
            else {
                storage.queueReadExhausted = true
                break
            }

            do {
                let source = try openSourceLocked(at: currentIndex)
                guard let chunk = try source.readNextChunk(maxFrames: config.chunkFrames) else {
                    advanceBeyondExhaustedTrackLocked(currentIndex, events: &events)
                    continue
                }
                guard chunk.frameCount > 0 else {
                    throw LocalGaplessSchedulerError.emptyBuffer
                }

                _ = storage.scheduledTrackStartIndices.insert(currentIndex)
                if currentIndex == storage.initialPlaybackIndex,
                   storage.emittedTrackStartIndices.insert(currentIndex).inserted {
                    events.append(.logicalTrackStarted(chunk.track))
                }

                let id = try retainScheduledChunkLocked(
                    chunk,
                    generation: generation,
                    trackIndex: currentIndex,
                    endsLogicalTrack: chunk.endsLogicalTrack
                )
                schedulingPlayer.scheduleGaplessBuffer(chunk.buffer) { [weak self] _ in
                    self?.scheduledBufferDidFinish(id, generation: generation)
                }

                if chunk.endsLogicalTrack {
                    advanceBeyondExhaustedTrackLocked(currentIndex, events: &events)
                }
            } catch {
                let failedTrack = storage.currentTrack
                storage.queueReadExhausted = true
                storage.state = .stopped
                if let failedTrack {
                    events.append(.sourceFailed(track: failedTrack, message: error.localizedDescription))
                }
                break
            }
        }

        if storage.didStartPlayer == false,
           storage.retainedBuffers.isEmpty == false,
           shouldStartPlayerLocked(targetFrames: targetFrames) {
            storage.didStartPlayer = true
            schedulingPlayer.playGapless()
        }

        if storage.queueReadExhausted, storage.retainedBuffers.isEmpty {
            events.append(contentsOf: finishQueueEndedLocked())
        }

        return events
    }

    private func shouldStartPlayerLocked(targetFrames: AVAudioFramePosition) -> Bool {
        let minimumStartFrames = min(targetFrames, AVAudioFramePosition(config.chunkFrames))
        return storage.scheduledAheadFrames >= max(minimumStartFrames, 1) || storage.queueReadExhausted
    }

    private func advanceBeyondExhaustedTrackLocked(
        _ index: Int,
        events: inout [LocalGaplessSchedulerEvent]
    ) {
        storage.exhaustedTrackIndices.insert(index)
        let nextIndex = index + 1
        guard storage.queue.indices.contains(nextIndex) else {
            storage.queueReadExhausted = true
            return
        }

        do {
            if storage.sourceOpenFailures[nextIndex] != nil {
                storage.queueReadExhausted = true
                return
            }
            _ = try openSourceLocked(at: nextIndex)
            storage.currentIndex = nextIndex
            events.append(contentsOf: prepareNextSourceLocked(after: nextIndex))
        } catch {
            storage.sourceOpenFailures[nextIndex] = error.localizedDescription
            storage.queueReadExhausted = true
            events.append(
                .gaplessMiss(
                    track: storage.queue[nextIndex],
                    reason: error.localizedDescription
                )
            )
        }
    }

    private func prepareNextSourceLocked(after index: Int) -> [LocalGaplessSchedulerEvent] {
        let nextIndex = index + 1
        guard storage.queue.indices.contains(nextIndex),
              storage.openSources[nextIndex] == nil
        else { return [] }

        do {
            _ = try openSourceLocked(at: nextIndex)
            return []
        } catch {
            storage.sourceOpenFailures[nextIndex] = error.localizedDescription
            return [
                .gaplessMiss(
                    track: storage.queue[nextIndex],
                    reason: error.localizedDescription
                )
            ]
        }
    }

    private func openSourceLocked(at index: Int) throws -> any LocalTrackSource {
        guard storage.queue.indices.contains(index) else {
            throw LocalGaplessSchedulerError.invalidQueueIndex(index)
        }
        if let source = storage.openSources[index] {
            return source
        }

        let track = storage.queue[index]
        let source = try sourceFactory(track, format, config)
        guard Self.formatsMatch(source.outputFormat, format) else {
            source.close()
            throw LocalGaplessSchedulerError.incompatibleOutputFormat(trackID: source.track.id)
        }
        storage.openSources[index] = source
        storage.sourceOpenFailures.removeValue(forKey: index)
        return source
    }

    private func emitPendingTrackStartLocked(afterEndingTrackAt endedIndex: Int) -> LocalGaplessSchedulerEvent? {
        let nextIndex = endedIndex + 1
        guard storage.scheduledTrackStartIndices.contains(nextIndex),
              storage.emittedTrackStartIndices.contains(nextIndex) == false,
              storage.queue.indices.contains(nextIndex)
        else { return nil }

        storage.emittedTrackStartIndices.insert(nextIndex)
        return .logicalTrackStarted(storage.queue[nextIndex])
    }

    private func shouldEmitTrackEndLocked(
        for trackIndex: Int,
        retained: ScheduledBuffer
    ) -> Bool {
        retained.endsLogicalTrack ||
            (
                storage.exhaustedTrackIndices.contains(trackIndex) &&
                    (storage.retainedBuffers.values.contains { $0.trackIndex == trackIndex }) == false
            )
    }

    private func targetAheadFrames() -> AVAudioFramePosition {
        guard format.sampleRate > 0 else {
            return AVAudioFramePosition(config.chunkFrames)
        }
        let configuredFrames = (config.targetAheadSeconds * format.sampleRate).rounded(.up)
        let clampedFrames = min(max(configuredFrames, Double(config.chunkFrames)), Double(AVAudioFramePosition.max))
        return AVAudioFramePosition(clampedFrames)
    }

    private func finishQueueEndedLocked() -> [LocalGaplessSchedulerEvent] {
        guard storage.didEmitQueueEnd == false else { return [] }

        storage.didEmitQueueEnd = true
        storage.state = .stopped
        Self.closeSources(Array(storage.openSources.values))
        storage.openSources = [:]
        return [.queueEnded]
    }

    @discardableResult
    private func retainScheduledChunkLocked(
        _ chunk: LocalDecodedChunk,
        generation: UInt64
    ) throws -> UUID {
        try retainScheduledChunkLocked(
            chunk,
            generation: generation,
            trackIndex: nil,
            endsLogicalTrack: chunk.endsLogicalTrack
        )
    }

    @discardableResult
    private func retainScheduledChunkLocked(
        _ chunk: LocalDecodedChunk,
        generation: UInt64,
        trackIndex: Int?,
        endsLogicalTrack: Bool
    ) throws -> UUID {
        try retainScheduledBufferLocked(
            chunk.buffer,
            track: chunk.track,
            generation: generation,
            trackIndex: trackIndex,
            endsLogicalTrack: endsLogicalTrack,
            sourceFrameRange: chunk.sourceFrameRange
        )
    }

    @discardableResult
    private func retainScheduledBufferLocked(
        _ buffer: AVAudioPCMBuffer,
        track: LocalGaplessTrackDescriptor? = nil,
        generation: UInt64,
        trackIndex: Int? = nil,
        endsLogicalTrack: Bool = false,
        sourceFrameRange: Range<AVAudioFramePosition>? = nil
    ) throws -> UUID {
        guard generation == storage.generation else {
            throw LocalGaplessSchedulerError.generationInvalidated(
                expected: generation,
                actual: storage.generation
            )
        }
        guard buffer.frameLength > 0 else {
            throw LocalGaplessSchedulerError.emptyBuffer
        }
        let byteCount = Self.estimatedPCMByteCount(for: buffer)
        guard storage.retainedPCMBytes + byteCount <= config.maxRetainedPCMBytes else {
            throw LocalGaplessSchedulerError.retainedPCMByteLimitExceeded(
                bufferBytes: byteCount,
                maxBytes: config.maxRetainedPCMBytes
            )
        }

        let id = UUID()
        storage.retainedBuffers[id] = ScheduledBuffer(
            id: id,
            generation: generation,
            trackIndex: trackIndex,
            track: track,
            buffer: buffer,
            sourceFrameRange: sourceFrameRange ?? 0..<AVAudioFramePosition(buffer.frameLength),
            frameCount: buffer.frameLength,
            byteCount: byteCount,
            endsLogicalTrack: endsLogicalTrack
        )
        storage.scheduledAheadFrames += AVAudioFramePosition(buffer.frameLength)
        storage.retainedPCMBytes += byteCount
        return id
    }

    private func emit(_ events: [LocalGaplessSchedulerEvent]) {
        guard let onEvent, !events.isEmpty else { return }
        for event in events {
            onEvent(event)
        }
    }

    private static func validate(
        sources: [any LocalTrackSource],
        startIndex: Int,
        format: AVAudioFormat
    ) throws {
        if sources.isEmpty {
            guard startIndex == 0 else {
                throw LocalGaplessSchedulerError.invalidQueueIndex(startIndex)
            }
            return
        }
        guard sources.indices.contains(startIndex) else {
            throw LocalGaplessSchedulerError.invalidQueueIndex(startIndex)
        }
        for source in sources where !formatsMatch(source.outputFormat, format) {
            throw LocalGaplessSchedulerError.incompatibleOutputFormat(trackID: source.track.id)
        }
    }

    private static func validate(
        queue: [LocalGaplessTrackDescriptor],
        startIndex: Int
    ) throws {
        if queue.isEmpty {
            guard startIndex == 0 else {
                throw LocalGaplessSchedulerError.invalidQueueIndex(startIndex)
            }
            return
        }
        guard queue.indices.contains(startIndex) else {
            throw LocalGaplessSchedulerError.invalidQueueIndex(startIndex)
        }
    }

    private static func closeSources(_ sources: [any LocalTrackSource]) {
        for source in sources {
            source.close()
        }
    }

    private static func nextGeneration(after generation: UInt64) -> UInt64 {
        generation == UInt64.max ? 1 : generation + 1
    }

    private static func formatsMatch(_ lhs: AVAudioFormat, _ rhs: AVAudioFormat) -> Bool {
        lhs.commonFormat == rhs.commonFormat &&
            lhs.sampleRate == rhs.sampleRate &&
            lhs.channelCount == rhs.channelCount &&
            lhs.isInterleaved == rhs.isInterleaved
    }

    private static func estimatedPCMByteCount(for buffer: AVAudioPCMBuffer) -> Int {
        let streamDescription = buffer.format.streamDescription.pointee
        let frames = Int(buffer.frameLength)
        let channelCount = max(Int(buffer.format.channelCount), 1)
        let bitsPerChannel = Int(streamDescription.mBitsPerChannel)
        let bytesPerSample = max(bitsPerChannel / 8, MemoryLayout<Float>.size)
        let bytesPerFrame = max(Int(streamDescription.mBytesPerFrame), channelCount * bytesPerSample)

        if buffer.format.isInterleaved {
            return frames * bytesPerFrame
        }
        return frames * channelCount * bytesPerSample
    }

    private struct SchedulerStorage {
        var state: LocalGaplessSchedulerState = .idle
        var generation: UInt64 = 0
        var queue: [LocalGaplessTrackDescriptor] = []
        var openSources: [Int: any LocalTrackSource] = [:]
        var currentIndex: Int?
        var initialPlaybackIndex: Int?
        var retainedBuffers: [UUID: ScheduledBuffer] = [:]
        var retainedPCMBytes = 0
        var scheduledAheadFrames: AVAudioFramePosition = 0
        var queueReadExhausted = false
        var exhaustedTrackIndices: Set<Int> = []
        var sourceOpenFailures: [Int: String] = [:]
        var scheduledTrackStartIndices: Set<Int> = []
        var emittedTrackStartIndices: Set<Int> = []
        var emittedTrackEndIndices: Set<Int> = []
        var didStartPlayer = false
        var didEmitQueueEnd = false

        var currentSource: (any LocalTrackSource)? {
            guard let currentIndex,
                  queue.indices.contains(currentIndex)
            else { return nil }
            return openSources[currentIndex]
        }

        var currentTrack: LocalGaplessTrackDescriptor? {
            guard let currentIndex,
                  queue.indices.contains(currentIndex)
            else { return nil }
            return queue[currentIndex]
        }

        mutating func clearScheduledBuffers() {
            retainedBuffers.removeAll()
            retainedPCMBytes = 0
            scheduledAheadFrames = 0
        }

        mutating func resetSchedulingState(keepStartedTrackIndices: Set<Int> = []) {
            clearScheduledBuffers()
            queueReadExhausted = false
            exhaustedTrackIndices = []
            sourceOpenFailures = [:]
            scheduledTrackStartIndices = []
            emittedTrackStartIndices = keepStartedTrackIndices
            emittedTrackEndIndices = []
            didStartPlayer = false
            didEmitQueueEnd = false
        }
    }

    private struct ScheduledBuffer {
        let id: UUID
        let generation: UInt64
        let trackIndex: Int?
        let track: LocalGaplessTrackDescriptor?
        let buffer: AVAudioPCMBuffer
        let sourceFrameRange: Range<AVAudioFramePosition>
        let frameCount: AVAudioFrameCount
        let byteCount: Int
        let endsLogicalTrack: Bool
    }

    private struct ScheduledBufferReleaseResult {
        let didRelease: Bool
        let shouldRefill: Bool
        let generation: UInt64
        let events: [LocalGaplessSchedulerEvent]
    }
}
