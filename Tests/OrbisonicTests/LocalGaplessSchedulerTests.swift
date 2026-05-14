import AVFoundation
import XCTest
@testable import Orbisonic

final class LocalGaplessSchedulerTests: XCTestCase {
    func testStartPauseResumeAndStopTransitions() throws {
        let format = try Self.makeFormat()
        let source = FakeLocalTrackSource(id: "track-1", format: format)
        let player = FakeGaplessPlayer()
        let scheduler = LocalGaplessScheduler(format: format, schedulingPlayer: player)
        var events: [LocalGaplessSchedulerEvent] = []
        scheduler.onEvent = { events.append($0) }

        try scheduler.start(sources: [source])
        scheduler.flushPendingWorkForTesting()
        let started = scheduler.snapshot()
        XCTAssertEqual(started.state, .ready)
        XCTAssertEqual(started.generation, 1)
        XCTAssertEqual(started.queueCount, 1)
        XCTAssertEqual(started.currentIndex, 0)
        XCTAssertEqual(started.currentTrack, source.track)
        XCTAssertEqual(player.playCount, 1)

        scheduler.pause()
        XCTAssertEqual(scheduler.snapshot().state, .paused)
        XCTAssertEqual(scheduler.snapshot().generation, started.generation)
        XCTAssertEqual(player.pauseCount, 1)

        scheduler.resume()
        scheduler.flushPendingWorkForTesting()
        XCTAssertEqual(scheduler.snapshot().state, .ready)
        XCTAssertEqual(scheduler.snapshot().generation, started.generation)
        XCTAssertEqual(player.playCount, 2)

        scheduler.stop(reason: "unit test")
        let stopped = scheduler.snapshot()
        XCTAssertEqual(stopped.state, .stopped)
        XCTAssertEqual(stopped.generation, 2)
        XCTAssertEqual(stopped.queueCount, 0)
        XCTAssertTrue(source.didClose)
        XCTAssertEqual(player.stopCount, 1)
        XCTAssertTrue(events.contains(.logicalTrackStarted(source.track)))
        XCTAssertTrue(events.contains(.schedulerStopped(reason: "unit test")))
    }

    func testRetainedBuffersAreReleasedByMatchingGeneration() throws {
        let format = try Self.makeFormat()
        let scheduler = LocalGaplessScheduler(
            format: format,
            config: LocalGaplessSchedulerConfig(maxRetainedPCMBytes: 64 * 1_024),
            schedulingPlayer: FakeGaplessPlayer()
        )
        try scheduler.start(sources: [])
        let generation = scheduler.currentGeneration()
        let buffer = try Self.makeBuffer(format: format, frames: 512)

        let id = try scheduler.retainScheduledBuffer(buffer, generation: generation)
        var retained = scheduler.snapshot()
        XCTAssertEqual(retained.retainedBufferCount, 1)
        XCTAssertEqual(retained.scheduledAheadFrames, 512)
        XCTAssertGreaterThan(retained.retainedPCMBytes, 0)

        XCTAssertTrue(scheduler.scheduledBufferDidFinish(id, generation: generation))
        retained = scheduler.snapshot()
        XCTAssertEqual(retained.retainedBufferCount, 0)
        XCTAssertEqual(retained.scheduledAheadFrames, 0)
        XCTAssertEqual(retained.retainedPCMBytes, 0)
    }

    func testMeteringSnapshotFindsRetainedChunkByTrackAndFrameRange() throws {
        let format = try Self.makeFormat()
        let source = FakeLocalTrackSource(id: "track-1", format: format, chunkFrameLengths: [64])
        try source.seek(to: 100)
        let scheduler = LocalGaplessScheduler(
            format: format,
            config: LocalGaplessSchedulerConfig(targetAheadSeconds: Double(64) / 48_000, chunkFrames: 64),
            schedulingPlayer: FakeGaplessPlayer()
        )

        try scheduler.start(source: source)
        scheduler.flushPendingWorkForTesting()

        let fullWindow = try XCTUnwrap(
            scheduler.meteringSnapshot(trackID: source.track.id, frame: 116, frameCount: 32)
        )
        XCTAssertEqual(fullWindow.track, source.track)
        XCTAssertEqual(fullWindow.bufferFrameOffset, 16)
        XCTAssertEqual(fullWindow.frameCount, 32)
        XCTAssertEqual(fullWindow.buffer.frameLength, 64)

        let clippedWindow = try XCTUnwrap(
            scheduler.meteringSnapshot(trackID: source.track.id, frame: 150, frameCount: 32)
        )
        XCTAssertEqual(clippedWindow.bufferFrameOffset, 50)
        XCTAssertEqual(clippedWindow.frameCount, 14)

        XCTAssertNil(scheduler.meteringSnapshot(trackID: "other", frame: 116, frameCount: 32))

        scheduler.stop(reason: "snapshot invalidation")
        XCTAssertNil(scheduler.meteringSnapshot(trackID: source.track.id, frame: 116, frameCount: 32))
    }

    func testMeteringSnapshotUsesCurrentGenerationAfterRebuild() throws {
        let format = try Self.makeFormat()
        let original = FakeLocalTrackSource(id: "track-1", format: format, chunkFrameLengths: [64])
        let replacement = FakeLocalTrackSource(id: "track-2", format: format, chunkFrameLengths: [64])
        let scheduler = LocalGaplessScheduler(
            format: format,
            config: LocalGaplessSchedulerConfig(targetAheadSeconds: Double(64) / 48_000, chunkFrames: 64),
            schedulingPlayer: FakeGaplessPlayer()
        )

        try scheduler.start(source: original)
        scheduler.flushPendingWorkForTesting()
        XCTAssertNotNil(scheduler.meteringSnapshot(trackID: original.track.id, frame: 0, frameCount: 32))

        try scheduler.rebuildQueue(sources: [replacement], currentIndex: 0)
        scheduler.flushPendingWorkForTesting()

        XCTAssertNil(scheduler.meteringSnapshot(trackID: original.track.id, frame: 0, frameCount: 32))
        XCTAssertNotNil(scheduler.meteringSnapshot(trackID: replacement.track.id, frame: 0, frameCount: 32))
    }

    func testGenerationInvalidatesRetainedBufferCompletions() throws {
        let format = try Self.makeFormat()
        let source = FakeLocalTrackSource(id: "track-1", format: format, chunkFrameLengths: [256, 256])
        let player = FakeGaplessPlayer()
        let scheduler = LocalGaplessScheduler(
            format: format,
            config: LocalGaplessSchedulerConfig(targetAheadSeconds: Double(256) / 48_000, chunkFrames: 256),
            schedulingPlayer: player
        )
        var events: [LocalGaplessSchedulerEvent] = []
        scheduler.onEvent = { events.append($0) }

        try scheduler.start(sources: [source])
        scheduler.flushPendingWorkForTesting()
        let staleGeneration = scheduler.currentGeneration()
        XCTAssertEqual(player.scheduledBuffers.count, 1)

        try scheduler.seek(to: 1_024)
        scheduler.flushPendingWorkForTesting()
        let afterSeek = scheduler.snapshot()
        XCTAssertEqual(afterSeek.generation, staleGeneration + 1)
        XCTAssertGreaterThanOrEqual(afterSeek.retainedBufferCount, 0)
        XCTAssertGreaterThanOrEqual(source.readPosition, 1_024)

        player.completeScheduledBuffer(at: 0)
        scheduler.flushPendingWorkForTesting()
        XCTAssertFalse(events.contains(.schedulerStopped(reason: "generation invalidated")))
    }

    func testRebuildQueueAndSkipAdvanceGeneration() throws {
        let format = try Self.makeFormat()
        let first = FakeLocalTrackSource(id: "track-1", format: format)
        let second = FakeLocalTrackSource(id: "track-2", format: format)
        let replacement = FakeLocalTrackSource(id: "track-3", format: format)
        let scheduler = LocalGaplessScheduler(format: format, schedulingPlayer: FakeGaplessPlayer())

        try scheduler.start(sources: [first, second])
        scheduler.flushPendingWorkForTesting()
        XCTAssertEqual(scheduler.snapshot().generation, 1)

        try scheduler.skipTo(1)
        scheduler.flushPendingWorkForTesting()
        var snapshot = scheduler.snapshot()
        XCTAssertEqual(snapshot.generation, 2)
        XCTAssertEqual(snapshot.currentIndex, 1)
        XCTAssertEqual(snapshot.currentTrack, second.track)
        XCTAssertGreaterThan(second.readPosition, 0)

        try scheduler.rebuildQueue(sources: [replacement], currentIndex: 0)
        scheduler.flushPendingWorkForTesting()
        snapshot = scheduler.snapshot()
        XCTAssertEqual(snapshot.generation, 3)
        XCTAssertEqual(snapshot.queueCount, 1)
        XCTAssertEqual(snapshot.currentTrack, replacement.track)
        XCTAssertTrue(first.didClose)
        XCTAssertTrue(second.didClose)
    }

    func testRejectsIncompatibleSourceFormat() throws {
        let schedulerFormat = try Self.makeFormat(sampleRate: 48_000)
        let sourceFormat = try Self.makeFormat(sampleRate: 44_100)
        let scheduler = LocalGaplessScheduler(format: schedulerFormat, schedulingPlayer: FakeGaplessPlayer())
        let source = FakeLocalTrackSource(id: "track-1", format: sourceFormat)

        XCTAssertThrowsError(try scheduler.start(sources: [source])) { error in
            XCTAssertEqual(
                error as? LocalGaplessSchedulerError,
                .incompatibleOutputFormat(trackID: "track-1")
            )
        }
        XCTAssertEqual(scheduler.snapshot().state, .idle)
        XCTAssertEqual(scheduler.snapshot().generation, 0)
    }

    func testStartSchedulesChunksToTargetAndStartsPlayer() throws {
        let format = try Self.makeFormat()
        let player = FakeGaplessPlayer()
        let source = FakeLocalTrackSource(id: "track-1", format: format, chunkFrameLengths: [512, 512, 512])
        let scheduler = LocalGaplessScheduler(
            format: format,
            config: LocalGaplessSchedulerConfig(targetAheadSeconds: Double(1_024) / 48_000, chunkFrames: 512),
            schedulingPlayer: player
        )
        var events: [LocalGaplessSchedulerEvent] = []
        scheduler.onEvent = { events.append($0) }

        try scheduler.start(source: source)
        scheduler.flushPendingWorkForTesting()

        let snapshot = scheduler.snapshot()
        XCTAssertEqual(player.scheduledBuffers.count, 2)
        XCTAssertEqual(player.playCount, 1)
        XCTAssertEqual(snapshot.retainedBufferCount, 2)
        XCTAssertEqual(snapshot.scheduledAheadFrames, 1_024)
        XCTAssertEqual(source.readCount, 2)
        XCTAssertEqual(events, [.logicalTrackStarted(source.track)])
    }

    func testBufferCompletionRefillsThenEmitsTrackAndQueueEnd() throws {
        let format = try Self.makeFormat()
        let player = FakeGaplessPlayer()
        let source = FakeLocalTrackSource(id: "track-1", format: format, chunkFrameLengths: [512, 512, 512])
        let scheduler = LocalGaplessScheduler(
            format: format,
            config: LocalGaplessSchedulerConfig(targetAheadSeconds: Double(1_024) / 48_000, chunkFrames: 512),
            schedulingPlayer: player
        )
        var events: [LocalGaplessSchedulerEvent] = []
        scheduler.onEvent = { events.append($0) }

        try scheduler.start(source: source)
        scheduler.flushPendingWorkForTesting()
        player.completeScheduledBuffer(at: 0)
        scheduler.flushPendingWorkForTesting()

        var snapshot = scheduler.snapshot()
        XCTAssertEqual(player.scheduledBuffers.count, 3)
        XCTAssertEqual(snapshot.retainedBufferCount, 2)
        XCTAssertEqual(snapshot.scheduledAheadFrames, 1_024)
        XCTAssertEqual(source.readCount, 3)
        XCTAssertFalse(events.contains(.queueEnded))

        player.completeScheduledBuffer(at: 1)
        scheduler.flushPendingWorkForTesting()
        snapshot = scheduler.snapshot()
        XCTAssertEqual(snapshot.retainedBufferCount, 1)
        XCTAssertEqual(snapshot.scheduledAheadFrames, 512)
        XCTAssertFalse(events.contains(.queueEnded))

        player.completeScheduledBuffer(at: 2)
        scheduler.flushPendingWorkForTesting()
        snapshot = scheduler.snapshot()
        XCTAssertEqual(snapshot.state, .stopped)
        XCTAssertEqual(snapshot.retainedBufferCount, 0)
        XCTAssertEqual(snapshot.scheduledAheadFrames, 0)
        XCTAssertEqual(player.stopCount, 0)
        XCTAssertEqual(
            events,
            [
                .logicalTrackStarted(source.track),
                .logicalTrackEnded(source.track),
                .queueEnded
            ]
        )
    }

    func testQueueSchedulingContinuesIntoNextTrackWithoutStoppingPlayer() throws {
        let format = try Self.makeFormat()
        let player = FakeGaplessPlayer()
        let first = FakeLocalTrackSource(id: "track-1", format: format, chunkFrameLengths: [512, 512])
        let second = FakeLocalTrackSource(id: "track-2", format: format, chunkFrameLengths: [512, 512])
        var openedTrackIDs: [String] = []
        let sources = [first.track.id: first, second.track.id: second]
        let scheduler = LocalGaplessScheduler(
            format: format,
            config: LocalGaplessSchedulerConfig(targetAheadSeconds: Double(1_536) / 48_000, chunkFrames: 512),
            schedulingPlayer: player,
            sourceFactory: { track, _, _ in
                openedTrackIDs.append(track.id)
                return try XCTUnwrap(sources[track.id])
            }
        )
        var events: [LocalGaplessSchedulerEvent] = []
        scheduler.onEvent = { events.append($0) }

        try scheduler.start(queue: [first.track, second.track])
        scheduler.flushPendingWorkForTesting()

        XCTAssertEqual(openedTrackIDs, ["track-1", "track-2"])
        XCTAssertEqual(player.scheduledBuffers.count, 3)
        XCTAssertEqual(first.readCount, 2)
        XCTAssertEqual(second.readCount, 1)
        XCTAssertEqual(player.playCount, 1)
        XCTAssertEqual(player.stopCount, 0)
        XCTAssertEqual(events, [.logicalTrackStarted(first.track)])

        player.completeScheduledBuffer(at: 0)
        scheduler.flushPendingWorkForTesting()
        XCTAssertEqual(player.scheduledBuffers.count, 4)
        XCTAssertEqual(second.readCount, 2)

        player.completeScheduledBuffer(at: 1)
        scheduler.flushPendingWorkForTesting()
        XCTAssertEqual(
            events,
            [
                .logicalTrackStarted(first.track),
                .logicalTrackEnded(first.track),
                .logicalTrackStarted(second.track)
            ]
        )
        XCTAssertEqual(player.stopCount, 0)

        player.completeScheduledBuffer(at: 2)
        scheduler.flushPendingWorkForTesting()
        XCTAssertFalse(events.contains(.queueEnded))

        player.completeScheduledBuffer(at: 3)
        scheduler.flushPendingWorkForTesting()
        XCTAssertEqual(scheduler.snapshot().state, .stopped)
        XCTAssertEqual(player.stopCount, 0)
        XCTAssertEqual(
            events,
            [
                .logicalTrackStarted(first.track),
                .logicalTrackEnded(first.track),
                .logicalTrackStarted(second.track),
                .logicalTrackEnded(second.track),
                .queueEnded
            ]
        )
    }

    func testLocalFileSchedulerConcatenatesSplitSineWithoutHandoffGap() throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sampleRate = 48_000.0
        let totalFrames = 4_096
        let splitFrame = 2_048
        let frequency = 997.0
        let phase = 0.37
        let format = try Self.makeFormat(sampleRate: sampleRate, channels: 2)
        let firstURL = directory.appendingPathComponent("sine-a.wav")
        let secondURL = directory.appendingPathComponent("sine-b.wav")

        try Self.writeSineAudioFile(
            to: firstURL,
            format: format,
            startFrame: 0,
            frameCount: splitFrame,
            sampleRate: sampleRate,
            frequency: frequency,
            phase: phase
        )
        try Self.writeSineAudioFile(
            to: secondURL,
            format: format,
            startFrame: splitFrame,
            frameCount: totalFrames - splitFrame,
            sampleRate: sampleRate,
            frequency: frequency,
            phase: phase
        )

        let first = LocalGaplessTrackDescriptor(id: "sine-a", url: firstURL)
        let second = LocalGaplessTrackDescriptor(id: "sine-b", url: secondURL)
        let player = FakeGaplessPlayer()
        let scheduler = LocalGaplessScheduler(
            format: format,
            config: LocalGaplessSchedulerConfig(
                targetAheadSeconds: Double(totalFrames) / sampleRate,
                chunkFrames: 512,
                maxRetainedPCMBytes: 8 * 1_024 * 1_024
            ),
            schedulingPlayer: player
        )
        var events: [LocalGaplessSchedulerEvent] = []
        scheduler.onEvent = { events.append($0) }

        try scheduler.start(queue: [first, second])
        scheduler.flushPendingWorkForTesting()

        let concatenated = player.scheduledBuffers.flatMap { Self.samples(in: $0.buffer, channel: 0) }
        let expected = Self.expectedSineSamples(
            startFrame: 0,
            frameCount: totalFrames,
            sampleRate: sampleRate,
            frequency: frequency,
            phase: phase
        )

        XCTAssertEqual(concatenated.count, totalFrames)
        XCTAssertEqual(player.scheduledBuffers.reduce(0) { $0 + Int($1.buffer.frameLength) }, totalFrames)
        XCTAssertEqual(player.playCount, 1)
        XCTAssertEqual(player.stopCount, 0)
        XCTAssertGreaterThan(abs(concatenated[splitFrame - 1]), 1.0e-4)
        XCTAssertGreaterThan(abs(concatenated[splitFrame]), 1.0e-4)
        XCTAssertNotEqual(concatenated[splitFrame - 1], concatenated[splitFrame], accuracy: 1.0e-5)

        for index in 0..<totalFrames {
            XCTAssertEqual(concatenated[index], expected[index], accuracy: 1.0e-5, "Mismatch at frame \(index)")
        }

        var completionIndex = 0
        while completionIndex < player.scheduledBuffers.count {
            player.completeScheduledBuffer(at: completionIndex)
            scheduler.flushPendingWorkForTesting()
            completionIndex += 1
        }

        XCTAssertEqual(
            events,
            [
                .logicalTrackStarted(first),
                .logicalTrackEnded(first),
                .logicalTrackStarted(second),
                .logicalTrackEnded(second),
                .queueEnded
            ]
        )
        XCTAssertEqual(player.stopCount, 0)
    }

    func testLocalFileScheduledBufferStaleCallbackAfterRebuildDoesNothing() throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let format = try Self.makeFormat(sampleRate: 48_000, channels: 2)
        let fileURL = directory.appendingPathComponent("sine.wav")
        try Self.writeSineAudioFile(
            to: fileURL,
            format: format,
            startFrame: 0,
            frameCount: 2_048,
            sampleRate: 48_000,
            frequency: 997,
            phase: 0.37
        )

        let track = LocalGaplessTrackDescriptor(id: "sine", url: fileURL)
        let player = FakeGaplessPlayer()
        let scheduler = LocalGaplessScheduler(
            format: format,
            config: LocalGaplessSchedulerConfig(
                targetAheadSeconds: 512.0 / 48_000.0,
                chunkFrames: 512,
                maxRetainedPCMBytes: 8 * 1_024 * 1_024
            ),
            schedulingPlayer: player
        )
        var events: [LocalGaplessSchedulerEvent] = []
        scheduler.onEvent = { events.append($0) }

        try scheduler.start(queue: [track])
        scheduler.flushPendingWorkForTesting()
        XCTAssertEqual(player.scheduledBuffers.count, 1)
        XCTAssertEqual(scheduler.snapshot().retainedBufferCount, 1)

        try scheduler.rebuildQueue(queue: [track], currentIndex: 0, seekFrame: 0)
        scheduler.flushPendingWorkForTesting()
        XCTAssertEqual(player.scheduledBuffers.count, 2)
        XCTAssertEqual(scheduler.snapshot().retainedBufferCount, 1)
        let eventsAfterRebuild = events

        player.completeScheduledBuffer(at: 0)
        scheduler.flushPendingWorkForTesting()

        XCTAssertEqual(events, eventsAfterRebuild)
        XCTAssertEqual(scheduler.snapshot().retainedBufferCount, 1)
    }

    func testGaplessMissForUnavailableNextSourceEndsQueueCleanly() throws {
        let format = try Self.makeFormat()
        let player = FakeGaplessPlayer()
        let first = FakeLocalTrackSource(id: "track-1", format: format, chunkFrameLengths: [512])
        let missing = LocalGaplessTrackDescriptor(id: "missing", url: URL(fileURLWithPath: "/tmp/missing.wav"))
        let scheduler = LocalGaplessScheduler(
            format: format,
            config: LocalGaplessSchedulerConfig(targetAheadSeconds: Double(1_024) / 48_000, chunkFrames: 512),
            schedulingPlayer: player,
            sourceFactory: { track, _, _ in
                guard track.id == first.track.id else {
                    throw LocalGaplessSchedulerError.invalidQueue("missing test source")
                }
                return first
            }
        )
        var events: [LocalGaplessSchedulerEvent] = []
        scheduler.onEvent = { events.append($0) }

        try scheduler.start(queue: [first.track, missing])
        scheduler.flushPendingWorkForTesting()

        XCTAssertTrue(events.contains(.gaplessMiss(track: missing, reason: "Invalid local gapless scheduler queue: missing test source")))
        XCTAssertEqual(player.scheduledBuffers.count, 1)
        XCTAssertEqual(player.playCount, 1)

        player.completeScheduledBuffer(at: 0)
        scheduler.flushPendingWorkForTesting()

        XCTAssertEqual(scheduler.snapshot().state, .stopped)
        XCTAssertEqual(player.stopCount, 0)
        XCTAssertTrue(events.contains(.logicalTrackStarted(first.track)))
        XCTAssertTrue(events.contains(.logicalTrackEnded(first.track)))
        XCTAssertTrue(events.contains(.queueEnded))
    }

    func testStaleCallbacksAfterStopAreIgnored() throws {
        let format = try Self.makeFormat()
        let player = FakeGaplessPlayer()
        let source = FakeLocalTrackSource(id: "track-1", format: format, chunkFrameLengths: [512, 512])
        let scheduler = LocalGaplessScheduler(
            format: format,
            config: LocalGaplessSchedulerConfig(targetAheadSeconds: Double(512) / 48_000, chunkFrames: 512),
            schedulingPlayer: player
        )
        var events: [LocalGaplessSchedulerEvent] = []
        scheduler.onEvent = { events.append($0) }

        try scheduler.start(source: source)
        scheduler.flushPendingWorkForTesting()
        XCTAssertEqual(player.scheduledBuffers.count, 1)

        scheduler.stop(reason: "unit stop")
        player.completeScheduledBuffer(at: 0)
        scheduler.flushPendingWorkForTesting()

        XCTAssertEqual(scheduler.snapshot().state, .stopped)
        XCTAssertEqual(player.stopCount, 1)
        XCTAssertEqual(
            events,
            [
                .logicalTrackStarted(source.track),
                .schedulerStopped(reason: "unit stop")
            ]
        )
    }

    func testQueueRebuildStopsPlayerAndIgnoresStaleCompletions() throws {
        let format = try Self.makeFormat()
        let player = FakeGaplessPlayer()
        let original = FakeLocalTrackSource(id: "track-1", format: format, chunkFrameLengths: [512, 512])
        let replacement = FakeLocalTrackSource(id: "track-2", format: format, chunkFrameLengths: [512, 512])
        let scheduler = LocalGaplessScheduler(
            format: format,
            config: LocalGaplessSchedulerConfig(targetAheadSeconds: Double(512) / 48_000, chunkFrames: 512),
            schedulingPlayer: player
        )
        var events: [LocalGaplessSchedulerEvent] = []
        scheduler.onEvent = { events.append($0) }

        try scheduler.start(source: original)
        scheduler.flushPendingWorkForTesting()
        XCTAssertEqual(player.scheduledBuffers.count, 1)
        XCTAssertEqual(scheduler.snapshot().retainedBufferCount, 1)

        try scheduler.rebuildQueue(sources: [replacement], currentIndex: 0)
        scheduler.flushPendingWorkForTesting()
        let eventsAfterRebuild = events

        XCTAssertEqual(scheduler.snapshot().generation, 2)
        XCTAssertEqual(scheduler.snapshot().currentTrack, replacement.track)
        XCTAssertEqual(player.stopCount, 1)
        XCTAssertTrue(original.didClose)
        XCTAssertEqual(scheduler.snapshot().retainedBufferCount, 1)

        player.completeScheduledBuffer(at: 0)
        scheduler.flushPendingWorkForTesting()

        XCTAssertEqual(events, eventsAfterRebuild)
        XCTAssertEqual(scheduler.snapshot().retainedBufferCount, 1)
    }

    func testPausedQueueRebuildWaitsForResumeBeforeSchedulingAndPlaying() throws {
        let format = try Self.makeFormat()
        let player = FakeGaplessPlayer()
        let original = FakeLocalTrackSource(id: "track-1", format: format, chunkFrameLengths: [512, 512])
        let replacement = FakeLocalTrackSource(id: "track-2", format: format, chunkFrameLengths: [512, 512])
        let scheduler = LocalGaplessScheduler(
            format: format,
            config: LocalGaplessSchedulerConfig(targetAheadSeconds: Double(512) / 48_000, chunkFrames: 512),
            schedulingPlayer: player
        )

        try scheduler.start(source: original)
        scheduler.flushPendingWorkForTesting()
        scheduler.pause()
        XCTAssertEqual(scheduler.snapshot().state, .paused)
        XCTAssertEqual(player.pauseCount, 1)

        try scheduler.rebuildQueue(sources: [replacement], currentIndex: 0)
        scheduler.flushPendingWorkForTesting()

        XCTAssertEqual(scheduler.snapshot().state, .paused)
        XCTAssertEqual(scheduler.snapshot().generation, 2)
        XCTAssertEqual(scheduler.snapshot().retainedBufferCount, 0)
        XCTAssertEqual(player.playCount, 1)
        XCTAssertEqual(player.stopCount, 1)

        scheduler.resume()
        scheduler.flushPendingWorkForTesting()

        XCTAssertEqual(scheduler.snapshot().state, .ready)
        XCTAssertEqual(scheduler.snapshot().currentTrack, replacement.track)
        XCTAssertEqual(scheduler.snapshot().retainedBufferCount, 1)
        XCTAssertEqual(player.playCount, 2)
    }

    private static func makeFormat(
        sampleRate: Double = 48_000,
        channels: AVAudioChannelCount = 2
    ) throws -> AVAudioFormat {
        try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels))
    }

    private static func makeBuffer(
        format: AVAudioFormat,
        frames: AVAudioFrameCount
    ) throws -> AVAudioPCMBuffer {
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        return buffer
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("orbisonic-local-gapless-scheduler-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func writeSineAudioFile(
        to url: URL,
        format: AVAudioFormat,
        startFrame: Int,
        frameCount: Int,
        sampleRate: Double,
        frequency: Double,
        phase: Double
    ) throws {
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)))
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let channelData = try XCTUnwrap(buffer.floatChannelData)
        for channel in 0..<Int(format.channelCount) {
            for offset in 0..<frameCount {
                let frame = startFrame + offset
                channelData[channel][offset] = Float(sin((2.0 * Double.pi * frequency * Double(frame) / sampleRate) + phase))
            }
        }

        let file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
        try file.write(from: buffer)
    }

    private static func expectedSineSamples(
        startFrame: Int,
        frameCount: Int,
        sampleRate: Double,
        frequency: Double,
        phase: Double
    ) -> [Float] {
        (0..<frameCount).map { offset in
            let frame = startFrame + offset
            return Float(sin((2.0 * Double.pi * frequency * Double(frame) / sampleRate) + phase))
        }
    }

    private static func samples(in buffer: AVAudioPCMBuffer, channel: Int) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        return (0..<Int(buffer.frameLength)).map { channelData[channel][$0] }
    }
}

private final class FakeLocalTrackSource: LocalTrackSource, @unchecked Sendable {
    let track: LocalGaplessTrackDescriptor
    let outputFormat: AVAudioFormat
    let trimInfo: GaplessTrimInfo = .unknown
    private(set) var readPosition: AVAudioFramePosition = 0
    private(set) var readCount = 0
    private(set) var didClose = false
    private let chunkFrameLengths: [AVAudioFrameCount]?

    init(
        id: String,
        format: AVAudioFormat,
        chunkFrameLengths: [AVAudioFrameCount]? = nil
    ) {
        self.track = LocalGaplessTrackDescriptor(
            id: id,
            url: URL(fileURLWithPath: "/tmp/\(id).wav")
        )
        self.outputFormat = format
        self.chunkFrameLengths = chunkFrameLengths
    }

    func readNextChunk(maxFrames: AVAudioFrameCount) throws -> LocalDecodedChunk? {
        let frames: AVAudioFrameCount
        let endsLogicalTrack: Bool
        if let chunkFrameLengths {
            guard readCount < chunkFrameLengths.count else { return nil }
            frames = min(chunkFrameLengths[readCount], maxFrames)
            endsLogicalTrack = readCount == chunkFrameLengths.count - 1
        } else {
            frames = maxFrames
            endsLogicalTrack = false
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frames) else {
            return nil
        }
        buffer.frameLength = frames
        let startFrame = readPosition
        readPosition += AVAudioFramePosition(frames)
        readCount += 1
        return LocalDecodedChunk(
            buffer: buffer,
            track: track,
            sourceFrameRange: startFrame..<readPosition,
            startsLogicalTrack: startFrame == 0,
            endsLogicalTrack: endsLogicalTrack
        )
    }

    func seek(to frame: AVAudioFramePosition) throws {
        readPosition = max(0, frame)
    }

    func close() {
        didClose = true
    }
}

private final class FakeGaplessPlayer: LocalGaplessPlayerScheduling {
    struct ScheduledBuffer {
        let buffer: AVAudioPCMBuffer
        let completion: (AVAudioPlayerNodeCompletionCallbackType) -> Void
        var didComplete = false
    }

    private(set) var scheduledBuffers: [ScheduledBuffer] = []
    private(set) var playCount = 0
    private(set) var pauseCount = 0
    private(set) var stopCount = 0

    func scheduleGaplessBuffer(
        _ buffer: AVAudioPCMBuffer,
        completion: @escaping (AVAudioPlayerNodeCompletionCallbackType) -> Void
    ) {
        scheduledBuffers.append(ScheduledBuffer(buffer: buffer, completion: completion))
    }

    func playGapless() {
        playCount += 1
    }

    func pauseGapless() {
        pauseCount += 1
    }

    func stopGapless() {
        stopCount += 1
    }

    func completeScheduledBuffer(at index: Int) {
        guard scheduledBuffers.indices.contains(index),
              scheduledBuffers[index].didComplete == false
        else { return }
        scheduledBuffers[index].didComplete = true
        scheduledBuffers[index].completion(.dataPlayedBack)
    }
}
