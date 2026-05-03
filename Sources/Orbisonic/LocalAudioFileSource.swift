import AudioToolbox
import AVFoundation
import Foundation

enum LocalAudioFileSourceError: LocalizedError, Equatable {
    case nonFileURL(String)
    case invalidConfiguration(String)
    case unsupportedFormat(String)
    case sourceClosed
    case emptyDecodedChunk(String)

    var errorDescription: String? {
        switch self {
        case .nonFileURL(let value):
            "Local gapless source expected a file URL, but got \(value)."
        case .invalidConfiguration(let message):
            "Invalid local gapless source configuration: \(message)"
        case .unsupportedFormat(let message):
            "Unsupported local gapless source format: \(message)"
        case .sourceClosed:
            "The local gapless source is closed."
        case .emptyDecodedChunk(let fileName):
            "Decoded an empty local gapless chunk before EOF for \(fileName)."
        }
    }
}

final class LocalAudioFileSource: LocalTrackSource, @unchecked Sendable {
    let track: LocalGaplessTrackDescriptor
    let outputFormat: AVAudioFormat
    let trimInfo: GaplessTrimInfo

    private let url: URL
    private let sourceFormat: AVAudioFormat
    private let chunkFrames: AVAudioFrameCount
    private let durationFrames: AVAudioFramePosition
    private let playableStartFrame: AVAudioFramePosition
    private let playableFrameCount: AVAudioFramePosition
    private var file: AVAudioFile?
    private var converter: AVAudioConverter?
    private var currentReadPosition: AVAudioFramePosition = 0

    var readPosition: AVAudioFramePosition {
        currentReadPosition
    }

    init(
        track: LocalGaplessTrackDescriptor,
        outputFormat: AVAudioFormat,
        config: LocalGaplessSchedulerConfig = LocalGaplessSchedulerConfig(),
        trimInfoOverride: GaplessTrimInfo? = nil
    ) throws {
        try Self.validate(outputFormat: outputFormat, chunkFrames: config.chunkFrames)
        guard track.url.isFileURL else {
            throw LocalAudioFileSourceError.nonFileURL(track.url.absoluteString)
        }

        let openedFile = try AVAudioFile(forReading: track.url)
        let processingFormat = openedFile.processingFormat
        guard processingFormat.sampleRate > 0,
              processingFormat.channelCount > 0
        else {
            throw LocalAudioFileSourceError.unsupportedFormat("missing source sample rate or channel count")
        }
        guard OrbisonicAudioLimits.supportsSourceChannelCount(Int(processingFormat.channelCount)) else {
            throw AudioFileLoaderError.unsupportedChannelCount(
                processingFormat.channelCount,
                maxSupported: OrbisonicAudioLimits.maxSourceChannelCount
            )
        }
        let durationFrames = max(0, openedFile.length)
        let trimResolution = Self.resolveTrimInfo(
            for: track.url,
            fileFormat: openedFile.fileFormat,
            decodedFrameCount: durationFrames,
            config: config,
            override: trimInfoOverride
        )

        self.track = track
        self.url = track.url
        self.outputFormat = outputFormat
        self.sourceFormat = processingFormat
        self.chunkFrames = config.chunkFrames
        self.durationFrames = durationFrames
        self.trimInfo = trimResolution.trimInfo
        self.playableStartFrame = trimResolution.startFrame
        self.playableFrameCount = trimResolution.frameCount
        self.file = openedFile

        if !Self.formatsMatchForDirectRead(processingFormat, outputFormat) {
            guard let converter = AVAudioConverter(from: processingFormat, to: outputFormat) else {
                throw LocalAudioFileSourceError.unsupportedFormat("could not create local gapless format converter")
            }
            self.converter = converter
        }
        if playableStartFrame > 0 {
            openedFile.framePosition = playableStartFrame
        }
        Self.logTrimResolution(trimResolution, url: track.url)
    }

    convenience init(
        url: URL,
        outputFormat: AVAudioFormat,
        id: String? = nil,
        queueIndex: Int? = nil,
        displayName: String? = nil,
        config: LocalGaplessSchedulerConfig = LocalGaplessSchedulerConfig(),
        trimInfoOverride: GaplessTrimInfo? = nil
    ) throws {
        let track = LocalGaplessTrackDescriptor(
            id: id ?? url.path,
            url: url,
            queueIndex: queueIndex,
            displayName: displayName
        )
        try self.init(track: track, outputFormat: outputFormat, config: config, trimInfoOverride: trimInfoOverride)
    }

    func readNextChunk() throws -> LocalDecodedChunk? {
        try readNextChunk(maxFrames: chunkFrames)
    }

    func readNextChunk(maxFrames: AVAudioFrameCount) throws -> LocalDecodedChunk? {
        try Task.checkCancellation()
        guard maxFrames > 0 else {
            throw LocalAudioFileSourceError.invalidConfiguration("maxFrames must be greater than zero")
        }
        guard let file else { throw LocalAudioFileSourceError.sourceClosed }
        guard currentReadPosition < playableFrameCount else { return nil }

        let logicalStartFrame = currentReadPosition
        let sourceStartFrame = playableStartFrame + logicalStartFrame
        if file.framePosition != sourceStartFrame {
            file.framePosition = sourceStartFrame
        }
        let remainingFrames = playableFrameCount - logicalStartFrame
        let requestedFrames = min(
            maxFrames,
            chunkFrames,
            AVAudioFrameCount(min(Int64(UInt32.max), remainingFrames))
        )
        guard requestedFrames > 0 else { return nil }

        let outputBuffer: AVAudioPCMBuffer
        if let converter {
            outputBuffer = try readConvertedChunk(file: file, converter: converter, requestedFrames: requestedFrames)
        } else {
            outputBuffer = try readDirectChunk(file: file, requestedFrames: requestedFrames)
        }

        let sourceEndFrame = file.framePosition
        currentReadPosition = max(0, min(sourceEndFrame - playableStartFrame, playableFrameCount))
        guard outputBuffer.frameLength > 0 else {
            if currentReadPosition >= playableFrameCount {
                return nil
            }
            throw LocalAudioFileSourceError.emptyDecodedChunk(url.lastPathComponent)
        }

        let sourceFrameRange = sourceStartFrame..<sourceEndFrame
        return LocalDecodedChunk(
            buffer: outputBuffer,
            track: track,
            sourceFrameRange: sourceFrameRange,
            startsLogicalTrack: logicalStartFrame == 0,
            endsLogicalTrack: currentReadPosition >= playableFrameCount
        )
    }

    func seek(to frame: AVAudioFramePosition) throws {
        try Task.checkCancellation()
        guard let file else { throw LocalAudioFileSourceError.sourceClosed }
        let clampedFrame = max(0, min(frame, playableFrameCount))
        file.framePosition = playableStartFrame + clampedFrame
        currentReadPosition = clampedFrame
        converter?.reset()
    }

    func seek(toSeconds seconds: TimeInterval) throws {
        let clampedSeconds = max(0, seconds)
        let frame = AVAudioFramePosition((clampedSeconds * sourceFormat.sampleRate).rounded(.toNearestOrAwayFromZero))
        try seek(to: frame)
    }

    func close() {
        file = nil
        converter = nil
    }

    private func readDirectChunk(
        file: AVAudioFile,
        requestedFrames: AVAudioFrameCount
    ) throws -> AVAudioPCMBuffer {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: requestedFrames) else {
            throw AudioFileLoaderError.convertedBufferAllocationFailed
        }
        try file.read(into: buffer, frameCount: requestedFrames)
        return buffer
    }

    private func readConvertedChunk(
        file: AVAudioFile,
        converter: AVAudioConverter,
        requestedFrames: AVAudioFrameCount
    ) throws -> AVAudioPCMBuffer {
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: requestedFrames) else {
            throw AudioFileLoaderError.sourceBufferAllocationFailed
        }
        try file.read(into: sourceBuffer, frameCount: requestedFrames)
        guard sourceBuffer.frameLength > 0 else {
            guard let emptyOutput = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 1) else {
                throw AudioFileLoaderError.convertedBufferAllocationFailed
            }
            emptyOutput.frameLength = 0
            return emptyOutput
        }

        let outputCapacity = outputFrameCapacity(forSourceFrames: sourceBuffer.frameLength)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
            throw AudioFileLoaderError.convertedBufferAllocationFailed
        }

        var suppliedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if Task.isCancelled {
                outStatus.pointee = .noDataNow
                return nil
            }
            if suppliedInput {
                outStatus.pointee = .endOfStream
                return nil
            }
            suppliedInput = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        try Task.checkCancellation()
        if status == .error || conversionError != nil {
            throw AudioFileLoaderError.formatConversionFailed(conversionError?.localizedDescription ?? "unknown converter error")
        }
        return outputBuffer
    }

    private func outputFrameCapacity(forSourceFrames sourceFrames: AVAudioFrameCount) -> AVAudioFrameCount {
        guard sourceFormat.sampleRate > 0,
              outputFormat.sampleRate > 0
        else { return sourceFrames }

        let ratio = outputFormat.sampleRate / sourceFormat.sampleRate
        let estimatedFrames = (Double(sourceFrames) * ratio).rounded(.up) + 32
        let clampedFrames = min(max(estimatedFrames, 1), Double(UInt32.max))
        return AVAudioFrameCount(clampedFrames)
    }

    private static func validate(outputFormat: AVAudioFormat, chunkFrames: AVAudioFrameCount) throws {
        guard chunkFrames > 0 else {
            throw LocalAudioFileSourceError.invalidConfiguration("chunkFrames must be greater than zero")
        }
        guard outputFormat.sampleRate > 0,
              outputFormat.channelCount > 0
        else {
            throw LocalAudioFileSourceError.unsupportedFormat("missing output sample rate or channel count")
        }
    }

    private static func formatsMatchForDirectRead(_ lhs: AVAudioFormat, _ rhs: AVAudioFormat) -> Bool {
        lhs.commonFormat == rhs.commonFormat &&
            lhs.sampleRate == rhs.sampleRate &&
            lhs.channelCount == rhs.channelCount &&
            lhs.isInterleaved == rhs.isInterleaved
    }

    private struct TrimResolution {
        let trimInfo: GaplessTrimInfo
        let startFrame: AVAudioFramePosition
        let frameCount: AVAudioFramePosition
        let decodedFrameCount: AVAudioFramePosition
        let unavailableReason: String?

        var didApplyTrim: Bool {
            trimInfo.isTrustworthy && (startFrame > 0 || frameCount < decodedFrameCount)
        }
    }

    private static func resolveTrimInfo(
        for url: URL,
        fileFormat: AVAudioFormat,
        decodedFrameCount: AVAudioFramePosition,
        config: LocalGaplessSchedulerConfig,
        override: GaplessTrimInfo?
    ) -> TrimResolution {
        let untrusted = GaplessTrimInfo(validFrameCount: decodedFrameCount, isTrustworthy: false)
        guard config.enableCompressedTrim else {
            return trimResolution(for: untrusted, decodedFrameCount: decodedFrameCount, unavailableReason: nil)
        }

        if let override {
            return trimResolution(
                for: override,
                decodedFrameCount: decodedFrameCount,
                unavailableReason: override.isTrustworthy ? nil : "explicit trim metadata is untrusted"
            )
        }

        guard isCompressed(fileFormat) else {
            return trimResolution(for: untrusted, decodedFrameCount: decodedFrameCount, unavailableReason: nil)
        }

        guard let packetTableTrimInfo = packetTableTrimInfo(for: url, decodedFrameCount: decodedFrameCount) else {
            return trimResolution(
                for: untrusted,
                decodedFrameCount: decodedFrameCount,
                unavailableReason: "Core Audio packet table trim metadata unavailable"
            )
        }

        return trimResolution(
            for: packetTableTrimInfo,
            decodedFrameCount: decodedFrameCount,
            unavailableReason: packetTableTrimInfo.isTrustworthy ? nil : "Core Audio packet table trim metadata is invalid"
        )
    }

    private static func trimResolution(
        for trimInfo: GaplessTrimInfo,
        decodedFrameCount: AVAudioFramePosition,
        unavailableReason: String?
    ) -> TrimResolution {
        guard trimInfo.isTrustworthy else {
            return TrimResolution(
                trimInfo: GaplessTrimInfo(validFrameCount: decodedFrameCount, isTrustworthy: false),
                startFrame: 0,
                frameCount: decodedFrameCount,
                decodedFrameCount: decodedFrameCount,
                unavailableReason: unavailableReason
            )
        }

        let leadingFrames = trimInfo.leadingPrimingFrames
        let trailingFrames = trimInfo.trailingPaddingFrames
        let validFrameCount: AVAudioFramePosition
        if let explicitValidFrameCount = trimInfo.validFrameCount {
            validFrameCount = explicitValidFrameCount
        } else {
            guard leadingFrames + trailingFrames <= decodedFrameCount else {
                return TrimResolution(
                    trimInfo: GaplessTrimInfo(validFrameCount: decodedFrameCount, isTrustworthy: false),
                    startFrame: 0,
                    frameCount: decodedFrameCount,
                    decodedFrameCount: decodedFrameCount,
                    unavailableReason: "trim window exceeds decoded frame count"
                )
            }
            validFrameCount = decodedFrameCount - leadingFrames - trailingFrames
        }

        guard leadingFrames <= decodedFrameCount,
              validFrameCount <= decodedFrameCount - leadingFrames,
              trailingFrames <= decodedFrameCount - leadingFrames - validFrameCount
        else {
            return TrimResolution(
                trimInfo: GaplessTrimInfo(validFrameCount: decodedFrameCount, isTrustworthy: false),
                startFrame: 0,
                frameCount: decodedFrameCount,
                decodedFrameCount: decodedFrameCount,
                unavailableReason: "trim window exceeds decoded frame count"
            )
        }

        let normalizedTrimInfo = GaplessTrimInfo(
            leadingPrimingFrames: leadingFrames,
            trailingPaddingFrames: trailingFrames,
            validFrameCount: validFrameCount,
            isTrustworthy: true
        )
        return TrimResolution(
            trimInfo: normalizedTrimInfo,
            startFrame: leadingFrames,
            frameCount: validFrameCount,
            decodedFrameCount: decodedFrameCount,
            unavailableReason: nil
        )
    }

    private static func packetTableTrimInfo(
        for url: URL,
        decodedFrameCount: AVAudioFramePosition
    ) -> GaplessTrimInfo? {
        var audioFileID: AudioFileID?
        let openStatus = AudioFileOpenURL(url as CFURL, .readPermission, 0, &audioFileID)
        guard openStatus == noErr, let audioFileID else { return nil }
        defer { AudioFileClose(audioFileID) }

        var propertySize = UInt32(MemoryLayout<AudioFilePacketTableInfo>.size)
        var isWritable: UInt32 = 0
        let infoStatus = AudioFileGetPropertyInfo(
            audioFileID,
            kAudioFilePropertyPacketTableInfo,
            &propertySize,
            &isWritable
        )
        guard infoStatus == noErr,
              propertySize >= UInt32(MemoryLayout<AudioFilePacketTableInfo>.size)
        else { return nil }

        var packetTableInfo = AudioFilePacketTableInfo(
            mNumberValidFrames: 0,
            mPrimingFrames: 0,
            mRemainderFrames: 0
        )
        let readStatus = AudioFileGetProperty(
            audioFileID,
            kAudioFilePropertyPacketTableInfo,
            &propertySize,
            &packetTableInfo
        )
        guard readStatus == noErr else { return nil }

        let validFrames = AVAudioFramePosition(max(0, packetTableInfo.mNumberValidFrames))
        let leadingFrames = AVAudioFramePosition(max(0, packetTableInfo.mPrimingFrames))
        let trailingFrames = AVAudioFramePosition(max(0, packetTableInfo.mRemainderFrames))
        guard validFrames > 0,
              leadingFrames <= decodedFrameCount,
              validFrames <= decodedFrameCount - leadingFrames,
              trailingFrames <= decodedFrameCount - leadingFrames - validFrames
        else {
            return GaplessTrimInfo(validFrameCount: decodedFrameCount, isTrustworthy: false)
        }

        return GaplessTrimInfo(
            leadingPrimingFrames: leadingFrames,
            trailingPaddingFrames: trailingFrames,
            validFrameCount: validFrames,
            isTrustworthy: true
        )
    }

    private static func isCompressed(_ fileFormat: AVAudioFormat) -> Bool {
        fileFormat.streamDescription.pointee.mFormatID != kAudioFormatLinearPCM
    }

    private static func logTrimResolution(_ resolution: TrimResolution, url: URL) {
        guard resolution.unavailableReason != nil || resolution.didApplyTrim else { return }

        if resolution.didApplyTrim {
            AppLogger.shared.notice(
                category: LocalGaplessSchedulerLog.category,
                LocalGaplessSchedulerLog.message(
                    .compressedTrimApplied,
                    fileName: url.lastPathComponent,
                    reason: "leadingFrames=\(resolution.trimInfo.leadingPrimingFrames) trailingFrames=\(resolution.trimInfo.trailingPaddingFrames) validFrames=\(resolution.frameCount)"
                )
            )
        } else if let unavailableReason = resolution.unavailableReason {
            AppLogger.shared.debug(
                category: LocalGaplessSchedulerLog.category,
                LocalGaplessSchedulerLog.message(
                    .compressedTrimUnavailable,
                    fileName: url.lastPathComponent,
                    reason: unavailableReason
                )
            )
        }
    }
}
