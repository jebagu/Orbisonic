import AVFoundation
import Foundation

struct GaplessTrimInfo: Equatable, Sendable {
    static let unknown = GaplessTrimInfo()

    let leadingPrimingFrames: AVAudioFramePosition
    let trailingPaddingFrames: AVAudioFramePosition
    let validFrameCount: AVAudioFramePosition?
    let isTrustworthy: Bool

    init(
        leadingPrimingFrames: AVAudioFramePosition = 0,
        trailingPaddingFrames: AVAudioFramePosition = 0,
        validFrameCount: AVAudioFramePosition? = nil,
        isTrustworthy: Bool = false
    ) {
        self.leadingPrimingFrames = max(0, leadingPrimingFrames)
        self.trailingPaddingFrames = max(0, trailingPaddingFrames)
        self.validFrameCount = validFrameCount.map { max(0, $0) }
        self.isTrustworthy = isTrustworthy
    }
}

struct LocalGaplessTrackDescriptor: Equatable, Hashable, Sendable {
    let id: String
    let url: URL
    let queueIndex: Int?
    let displayName: String?

    init(
        id: String,
        url: URL,
        queueIndex: Int? = nil,
        displayName: String? = nil
    ) {
        self.id = id
        self.url = url
        self.queueIndex = queueIndex
        self.displayName = displayName
    }
}

struct LocalDecodedChunk: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    let track: LocalGaplessTrackDescriptor
    let sourceFrameRange: Range<AVAudioFramePosition>
    let startsLogicalTrack: Bool
    let endsLogicalTrack: Bool

    init(
        buffer: AVAudioPCMBuffer,
        track: LocalGaplessTrackDescriptor,
        sourceFrameRange: Range<AVAudioFramePosition>,
        startsLogicalTrack: Bool = false,
        endsLogicalTrack: Bool = false
    ) {
        self.buffer = buffer
        self.track = track
        self.sourceFrameRange = sourceFrameRange
        self.startsLogicalTrack = startsLogicalTrack
        self.endsLogicalTrack = endsLogicalTrack
    }

    var frameCount: AVAudioFrameCount {
        buffer.frameLength
    }
}

struct LocalGaplessMeterSnapshot: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    let track: LocalGaplessTrackDescriptor
    let bufferFrameOffset: AVAudioFramePosition
    let frameCount: AVAudioFrameCount

    init(
        buffer: AVAudioPCMBuffer,
        track: LocalGaplessTrackDescriptor,
        bufferFrameOffset: AVAudioFramePosition,
        frameCount: AVAudioFrameCount
    ) {
        self.buffer = buffer
        self.track = track
        self.bufferFrameOffset = max(0, bufferFrameOffset)
        self.frameCount = frameCount
    }
}

protocol LocalTrackSource: Sendable {
    var track: LocalGaplessTrackDescriptor { get }
    var outputFormat: AVAudioFormat { get }
    var trimInfo: GaplessTrimInfo { get }
    var readPosition: AVAudioFramePosition { get }

    func readNextChunk(maxFrames: AVAudioFrameCount) throws -> LocalDecodedChunk?
    func seek(to frame: AVAudioFramePosition) throws
    func close()
}

enum LocalGaplessSchedulerEvent: Equatable, Sendable {
    case logicalTrackStarted(LocalGaplessTrackDescriptor)
    case logicalTrackEnded(LocalGaplessTrackDescriptor)
    case queueEnded
    case gaplessMiss(track: LocalGaplessTrackDescriptor?, reason: String)
    case sourceFailed(track: LocalGaplessTrackDescriptor, message: String)
    case schedulerStopped(reason: String)
}

struct LocalGaplessSchedulerConfig: Equatable, Sendable {
    let isEnabled: Bool
    let targetAheadSeconds: TimeInterval
    let chunkFrames: AVAudioFrameCount
    let maxRetainedPCMBytes: Int
    let enableCompressedTrim: Bool

    init(
        isEnabled: Bool = LocalGaplessPlaybackPolicy.enableLocalGaplessScheduler,
        targetAheadSeconds: TimeInterval = LocalGaplessPlaybackPolicy.localGaplessTargetAheadSeconds,
        chunkFrames: AVAudioFrameCount = LocalGaplessPlaybackPolicy.localGaplessChunkFrames,
        maxRetainedPCMBytes: Int = LocalGaplessPlaybackPolicy.localGaplessMaxRetainedPCMBytes,
        enableCompressedTrim: Bool = LocalGaplessPlaybackPolicy.localGaplessEnableCompressedTrim
    ) {
        self.isEnabled = isEnabled
        self.targetAheadSeconds = targetAheadSeconds
        self.chunkFrames = chunkFrames
        self.maxRetainedPCMBytes = maxRetainedPCMBytes
        self.enableCompressedTrim = enableCompressedTrim
    }
}
