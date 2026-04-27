import AVFoundation
import CoreAudio
import CoreAudioTypes

struct LoadedAudioFile {
    let url: URL
    let monoFormat: AVAudioFormat
    let sampleRate: Double
    let frameCount: AVAudioFramePosition
    let layout: SurroundLayout
    let metadata: AudioSourceMetadata
    let monoBuffers: [AVAudioPCMBuffer]

    var duration: TimeInterval {
        guard sampleRate > 0 else { return 0 }
        return Double(frameCount) / sampleRate
    }
}

enum AudioFileLoaderError: LocalizedError {
    case unsupportedChannelCount(UInt32, maxSupported: Int)
    case fileTooLarge
    case sourceBufferAllocationFailed
    case layoutCreationFailed(UInt32)
    case surroundFormatCreationFailed(Double, UInt32)
    case convertedBufferAllocationFailed
    case monoFormatCreationFailed(Double)
    case monoBufferAllocationFailed
    case converterCreationFailed
    case formatConversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedChannelCount(let count, let maxSupported):
            count == 0
                ? "Expected at least 1 channel, but got 0."
                : "Orbisonic supports up to \(maxSupported) source channels in this build. This file has \(count) channels."
        case .fileTooLarge:
            "This build reads the file into memory and the file is too large for that path."
        case .sourceBufferAllocationFailed:
            "Unable to allocate the source audio buffer."
        case .layoutCreationFailed(let channelCount):
            "Unable to create an internal layout for \(channelCount) channels."
        case .surroundFormatCreationFailed(let sampleRate, let channels):
            "Unable to create an internal \(channels)-channel float format at \(sampleRate) Hz."
        case .convertedBufferAllocationFailed:
            "Unable to allocate the converted audio buffer."
        case .monoFormatCreationFailed(let sampleRate):
            "Unable to create an internal mono float format at \(sampleRate) Hz."
        case .monoBufferAllocationFailed:
            "Unable to allocate a mono playback buffer."
        case .converterCreationFailed:
            "Unable to create the audio format converter."
        case .formatConversionFailed(let message):
            "Audio conversion failed: \(message)"
        }
    }
}

final class AudioFileLoader {
    func load(url: URL) throws -> LoadedAudioFile {
        AppLogger.shared.info(category: "loader", "Opening file: \(url.path)")

        var readURL = url
        var temporaryDecodedURL: URL?
        var matroskaStreamInfo: MatroskaAudioStreamInfo?
        var tags = AudioMetadataBuilder.tags(for: url)

        if MatroskaFLACSupport.isMatroska(url) {
            let streamInfo = try MatroskaAudioProbe().probe(url: url)
            let decodedURL = try MatroskaFLACDemuxer().demuxToCAF(url: url, streamInfo: streamInfo)
            readURL = decodedURL
            temporaryDecodedURL = decodedURL
            matroskaStreamInfo = streamInfo
            tags = streamInfo.tags
            AppLogger.shared.info(
                category: "loader",
                "Decoded Matroska FLAC stream index=\(streamInfo.streamIndex) channels=\(streamInfo.channelCount) " +
                    "sampleRate=\(streamInfo.sampleRate) bitDepth=\(streamInfo.bitDepth)"
            )
        }

        defer {
            if let temporaryDecodedURL {
                try? FileManager.default.removeItem(at: temporaryDecodedURL)
            }
        }

        let file = try AVAudioFile(forReading: readURL)
        let inputFormat = file.processingFormat
        let channelCount = inputFormat.channelCount

        guard OrbisonicAudioLimits.supportsSourceChannelCount(Int(channelCount)) else {
            throw AudioFileLoaderError.unsupportedChannelCount(
                channelCount,
                maxSupported: OrbisonicAudioLimits.maxSourceChannelCount
            )
        }

        guard file.length <= AVAudioFramePosition(UInt32.max) else {
            throw AudioFileLoaderError.fileTooLarge
        }

        let detectedLayout = SurroundLayoutDetector.detect(for: inputFormat)
        let inputLayout = try buildChannelLayout(for: inputFormat, fallback: detectedLayout)

        AppLogger.shared.info(
            category: "loader",
            "Detected source format codec=\(AudioMetadataBuilder.build(for: file, layout: detectedLayout, duration: 0, sourceURL: url, containerName: matroskaStreamInfo == nil ? nil : "Matroska", codecName: matroskaStreamInfo?.codecName, bitDepth: matroskaStreamInfo?.bitDepth, tags: tags).codecName) " +
                "sampleRate=\(inputFormat.sampleRate) channelCount=\(channelCount) layout=\(detectedLayout.name) channels=\(detectedLayout.channelSummary)"
        )

        let frameCapacity = AVAudioFrameCount(file.length)
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frameCapacity) else {
            throw AudioFileLoaderError.sourceBufferAllocationFailed
        }
        try file.read(into: sourceBuffer)

        let surroundFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: inputFormat.sampleRate,
            interleaved: false,
            channelLayout: inputLayout
        )

        guard surroundFormat.channelCount == channelCount else {
            throw AudioFileLoaderError.surroundFormatCreationFailed(inputFormat.sampleRate, channelCount)
        }

        guard let surroundBuffer = AVAudioPCMBuffer(pcmFormat: surroundFormat, frameCapacity: sourceBuffer.frameLength) else {
            throw AudioFileLoaderError.convertedBufferAllocationFailed
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: surroundFormat) else {
            throw AudioFileLoaderError.converterCreationFailed
        }

        var suppliedInput = false
        var conversionError: NSError?

        let status = converter.convert(to: surroundBuffer, error: &conversionError) { _, outStatus in
            if suppliedInput {
                outStatus.pointee = .endOfStream
                return nil
            }

            suppliedInput = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if status == .error || conversionError != nil {
            throw AudioFileLoaderError.formatConversionFailed(conversionError?.localizedDescription ?? "unknown converter error")
        }

        surroundBuffer.frameLength = sourceBuffer.frameLength

        guard let monoFormat = AVAudioFormat(
            standardFormatWithSampleRate: surroundFormat.sampleRate,
            channels: 1
        ) else {
            throw AudioFileLoaderError.monoFormatCreationFailed(surroundFormat.sampleRate)
        }

        guard let channelData = surroundBuffer.floatChannelData else {
            throw AudioFileLoaderError.formatConversionFailed("missing float channel data")
        }

        let monoBuffers = try (0..<Int(channelCount)).map { channelIndex in
            guard let monoBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: surroundBuffer.frameLength) else {
                throw AudioFileLoaderError.monoBufferAllocationFailed
            }

            monoBuffer.frameLength = surroundBuffer.frameLength
            let source = channelData[channelIndex]
            guard let monoChannelData = monoBuffer.floatChannelData else {
                throw AudioFileLoaderError.formatConversionFailed("missing mono float channel data")
            }
            let destination = monoChannelData[0]
            destination.update(from: source, count: Int(surroundBuffer.frameLength))
            return monoBuffer
        }

        let duration = Double(surroundBuffer.frameLength) / surroundFormat.sampleRate
        let metadata = AudioMetadataBuilder.build(
            for: file,
            layout: detectedLayout,
            duration: duration,
            sourceURL: url,
            containerName: matroskaStreamInfo == nil ? nil : "Matroska",
            codecName: matroskaStreamInfo?.codecName,
            bitDepth: matroskaStreamInfo?.bitDepth,
            tags: tags
        )

        AppLogger.shared.notice(
            category: "loader",
            "Prepared playback buffers file=\(metadata.fileName) layout=\(metadata.layoutName) codec=\(metadata.codecName) " +
                "channels=\(metadata.channelCount) sampleRate=\(metadata.sampleRateText) bitDepth=\(metadata.bitDepthText) duration=\(metadata.durationText)"
        )

        return LoadedAudioFile(
            url: url,
            monoFormat: monoFormat,
            sampleRate: surroundFormat.sampleRate,
            frameCount: AVAudioFramePosition(surroundBuffer.frameLength),
            layout: detectedLayout,
            metadata: metadata,
            monoBuffers: monoBuffers
        )
    }

    private func buildChannelLayout(for inputFormat: AVAudioFormat, fallback: SurroundLayout) throws -> AVAudioChannelLayout {
        if let channelLayout = inputFormat.channelLayout,
           Self.channelDescriptionCount(in: channelLayout, fallbackCount: Int(inputFormat.channelCount)) == Int(inputFormat.channelCount) {
            return channelLayout
        }

        let managedLayout = ManagedAudioChannelLayout(
            channelDescriptions: fallback.channels.map { channel in
                var description = AudioChannelDescription()
                description.mChannelLabel = audioChannelLabel(for: channel.role)
                description.mChannelFlags = AudioChannelFlags(rawValue: 0)
                description.mCoordinates = (0, 0, 0)
                return description
            }
        )

        let channelLayout = managedLayout.withUnsafePointer { pointer in
            AVAudioChannelLayout(layout: pointer)
        }

        return channelLayout
    }

    private static func channelDescriptionCount(in channelLayout: AVAudioChannelLayout, fallbackCount: Int) -> Int {
        let descriptions = AudioChannelLayout.UnsafePointer(channelLayout.layout)
        return descriptions.count == 0 ? fallbackCount : descriptions.count
    }

    private func audioChannelLabel(for role: SurroundChannelRole) -> AudioChannelLabel {
        switch role {
        case .frontLeft:
            AudioChannelLabel(kAudioChannelLabel_Left)
        case .frontRight:
            AudioChannelLabel(kAudioChannelLabel_Right)
        case .center:
            AudioChannelLabel(kAudioChannelLabel_Center)
        case .lfe:
            AudioChannelLabel(kAudioChannelLabel_LFEScreen)
        case .lfe2:
            AudioChannelLabel(kAudioChannelLabel_LFE2)
        case .sideLeft:
            AudioChannelLabel(kAudioChannelLabel_LeftSideSurround)
        case .sideRight:
            AudioChannelLabel(kAudioChannelLabel_RightSideSurround)
        case .rearLeft:
            AudioChannelLabel(kAudioChannelLabel_LeftBackSurround)
        case .rearRight:
            AudioChannelLabel(kAudioChannelLabel_RightBackSurround)
        case .rearCenter:
            AudioChannelLabel(kAudioChannelLabel_CenterSurround)
        case .wideLeft:
            AudioChannelLabel(kAudioChannelLabel_LeftWide)
        case .wideRight:
            AudioChannelLabel(kAudioChannelLabel_RightWide)
        case .frontLeftCenter:
            AudioChannelLabel(kAudioChannelLabel_LeftCenter)
        case .frontRightCenter:
            AudioChannelLabel(kAudioChannelLabel_RightCenter)
        case .topFrontLeft:
            AudioChannelLabel(kAudioChannelLabel_LeftTopFront)
        case .topFrontCenter:
            AudioChannelLabel(kAudioChannelLabel_CenterTopFront)
        case .topFrontRight:
            AudioChannelLabel(kAudioChannelLabel_RightTopFront)
        case .topMiddleLeft:
            AudioChannelLabel(kAudioChannelLabel_LeftTopMiddle)
        case .topMiddleCenter:
            AudioChannelLabel(kAudioChannelLabel_CenterTopMiddle)
        case .topMiddleRight:
            AudioChannelLabel(kAudioChannelLabel_RightTopMiddle)
        case .topRearLeft:
            AudioChannelLabel(kAudioChannelLabel_LeftTopRear)
        case .topRearCenter:
            AudioChannelLabel(kAudioChannelLabel_CenterTopRear)
        case .topRearRight:
            AudioChannelLabel(kAudioChannelLabel_RightTopRear)
        case .discrete(let index):
            AudioChannelLabel(kAudioChannelLabel_Discrete_0 + UInt32(index))
        }
    }
}
