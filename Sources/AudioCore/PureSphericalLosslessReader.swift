import AudioContracts
import Foundation

public enum PureSphericalLosslessSampleEncoding: String, Equatable, Hashable, Sendable {
    case float32
    case pcm24Integer
}

public struct PureSphericalLosslessPCMFormat: Equatable, Hashable, Sendable {
    public let containerKind: PureSphericalLosslessContainerKind
    public let sampleRate: AudioSampleRate
    public let channelCount: Int
    public let bitsPerSample: Int
    public let bytesPerSample: Int
    public let encoding: PureSphericalLosslessSampleEncoding
    public let isInterleaved: Bool

    public init(
        containerKind: PureSphericalLosslessContainerKind,
        sampleRate: AudioSampleRate,
        channelCount: Int,
        bitsPerSample: Int,
        bytesPerSample: Int,
        encoding: PureSphericalLosslessSampleEncoding,
        isInterleaved: Bool
    ) {
        self.containerKind = containerKind
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bitsPerSample = bitsPerSample
        self.bytesPerSample = bytesPerSample
        self.encoding = encoding
        self.isInterleaved = isInterleaved
    }
}

public struct PureSphericalLosslessReaderContext: Equatable, Hashable, Sendable {
    public let sessionID: String
    public let sourceID: String?
    public let sourceKind: SourceKind
    public let generation: UInt64

    public init(
        sessionID: String = "pure-spherical-lossless-reader",
        sourceID: String? = nil,
        sourceKind: SourceKind = .localFile,
        generation: UInt64 = 1
    ) {
        self.sessionID = sessionID
        self.sourceID = sourceID
        self.sourceKind = sourceKind
        self.generation = generation
    }
}

public struct PureSphericalLosslessReadResult: Sendable {
    public let samples: CanonicalAudioBlock
    public let renderedBlock: RenderedSphereBlock
    public let ledger: AudioConversionLedger
    public let validation: PureSphericalLosslessValidation
    public let sourceFormat: PureSphericalLosslessPCMFormat
    public let frameStart: Int64
    public let frameCount: Int

    public init(
        samples: CanonicalAudioBlock,
        renderedBlock: RenderedSphereBlock,
        ledger: AudioConversionLedger,
        validation: PureSphericalLosslessValidation,
        sourceFormat: PureSphericalLosslessPCMFormat,
        frameStart: Int64,
        frameCount: Int
    ) {
        self.samples = samples
        self.renderedBlock = renderedBlock
        self.ledger = ledger
        self.validation = validation
        self.sourceFormat = sourceFormat
        self.frameStart = frameStart
        self.frameCount = frameCount
    }
}

public final class PureSphericalLosslessReader: @unchecked Sendable {
    private var session: OpenSession?

    public private(set) var sourceFormat: PureSphericalLosslessPCMFormat?

    public init() {}

    public func open(
        validation: PureSphericalLosslessValidation,
        context: PureSphericalLosslessReaderContext = PureSphericalLosslessReaderContext()
    ) throws {
        close()

        guard validation.state == .validForCurrentSphere else {
            throw AudioError.invalidRenderGraphPlan(
                "PureSphericalLosslessReader requires a file validated for the current sphere."
            )
        }
        guard let manifest = validation.manifest else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader requires validated metadata.")
        }
        guard let containerKind = validation.containerKind else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader requires a supported container.")
        }

        let parsed = try ParsedLPCMContainer.parse(url: validation.url, expectedKind: containerKind)
        try Self.validate(parsed: parsed, manifest: manifest)

        let handle = try FileHandle(forReadingFrom: validation.url)
        try handle.seek(toOffset: parsed.dataOffset)
        let resolvedSourceID = context.sourceID ?? validation.url.deletingPathExtension().lastPathComponent
        let openSession = OpenSession(
            validation: validation,
            manifest: manifest,
            parsed: parsed,
            handle: handle,
            context: context,
            sourceID: resolvedSourceID
        )
        session = openSession
        sourceFormat = parsed.publicFormat
    }

    public func readBlock(maxFrames: Int) throws -> PureSphericalLosslessReadResult {
        guard maxFrames > 0 else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader maxFrames must be positive.")
        }
        guard let session else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader is not open.")
        }

        let remainingFrames = session.parsed.totalFrames - session.frameCursor
        guard remainingFrames > 0 else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader reached end of file.")
        }

        let framesToRead = min(maxFrames, remainingFrames)
        let bytesToRead = framesToRead * session.parsed.bytesPerFrameAcrossAllChannels
        let data = session.handle.readData(ofLength: bytesToRead)
        guard data.count == bytesToRead else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader encountered a short LPCM read.")
        }

        let layout = Self.layout(for: session.manifest.channelCount)
        let samples = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: session.manifest.sampleRate,
                channelCount: session.manifest.channelCount,
                frameCount: framesToRead,
                layout: layout
            )
        )
        try fill(samples: samples, from: data, parsed: session.parsed, frameCount: framesToRead)
        try validateReservedSilentChannels(samples: samples, manifest: session.manifest)

        let frameStart = Int64(session.frameCursor)
        let renderedBlock = try RenderedSphereBlock(
            contract: AudioBlockContract(
                sourceID: session.sourceID,
                generation: session.context.generation,
                sampleRate: session.manifest.sampleRate,
                frameStart: frameStart,
                frameCount: framesToRead,
                channelCount: session.manifest.channelCount,
                processingFormat: .float32NonInterleavedPCM,
                layout: SourceLayout(
                    descriptor: layout,
                    authority: .pureSphericalManifest,
                    authorityID: session.manifest.outputMapID
                )
            ),
            outputMapID: session.manifest.outputMapID,
            sphereProfileID: session.manifest.sphereProfileID
        )
        let ledger = Self.ledger(
            session: session,
            output: samples,
            frameStart: frameStart,
            frameCount: framesToRead
        )

        session.frameCursor += framesToRead
        return PureSphericalLosslessReadResult(
            samples: samples,
            renderedBlock: renderedBlock,
            ledger: ledger,
            validation: session.validation,
            sourceFormat: session.parsed.publicFormat,
            frameStart: frameStart,
            frameCount: framesToRead
        )
    }

    public func close() {
        if let session {
            try? session.handle.close()
        }
        session = nil
        sourceFormat = nil
    }

    deinit {
        close()
    }

    private static func validate(
        parsed: ParsedLPCMContainer,
        manifest: PureSphericalLosslessManifest
    ) throws {
        guard parsed.sampleRate.matches(manifest.sampleRate) else {
            throw AudioError.sampleRateMismatch(
                expected: manifest.sampleRate,
                actual: parsed.sampleRate,
                context: "PureSphericalLosslessReader container"
            )
        }
        guard parsed.channelCount == manifest.channelCount else {
            throw AudioError.layoutChannelCountMismatch(
                expected: manifest.channelCount,
                actual: parsed.channelCount
            )
        }
        guard parsed.totalFrames > 0 else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader requires non-empty LPCM data.")
        }
        guard parsed.dataByteCount.isMultiple(of: UInt64(parsed.bytesPerFrameAcrossAllChannels)) else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader LPCM data is not frame-aligned.")
        }
        guard manifest.channels.map(\.index).sorted() == Array(0..<manifest.channelCount) else {
            throw AudioError.invalidRenderGraphPlan(
                "PureSphericalLosslessReader requires contiguous channel indexes in file order."
            )
        }
        guard parsed.encoding == (try expectedEncoding(for: manifest.sampleFormat)) else {
            throw AudioError.invalidRenderGraphPlan(
                "PureSphericalLosslessReader sample format does not match validated metadata."
            )
        }
    }

    private static func expectedEncoding(for manifestSampleFormat: String) throws -> PureSphericalLosslessSampleEncoding {
        let normalized = manifestSampleFormat
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")

        if normalized.contains("float32") || normalized.contains("32bitfloat") {
            return .float32
        }
        if normalized.contains("pcm24") ||
            normalized.contains("int24") ||
            normalized.contains("signed24") ||
            normalized.contains("24bitpcm") ||
            normalized.contains("24bitinteger") {
            return .pcm24Integer
        }
        throw AudioError.invalidRenderGraphPlan(
            "PureSphericalLosslessReader supports float32 render masters and 24-bit PCM prints."
        )
    }

    private func fill(
        samples: CanonicalAudioBlock,
        from data: Data,
        parsed: ParsedLPCMContainer,
        frameCount: Int
    ) throws {
        for channel in 0..<parsed.channelCount {
            for frame in 0..<frameCount {
                let offset = parsed.byteOffset(channel: channel, frame: frame, framesInBlock: frameCount)
                let sample = try parsed.decodeSample(data: data, offset: offset)
                try samples.setSample(sample, channel: channel, frame: frame)
            }
        }
        try samples.setFrameCount(frameCount)
    }

    private func validateReservedSilentChannels(
        samples: CanonicalAudioBlock,
        manifest: PureSphericalLosslessManifest
    ) throws {
        for channel in manifest.channels where channel.isReservedSilent {
            for frame in 0..<samples.frameCount {
                if abs(samples.sample(channel: channel.index, frame: frame)) > 0.000_000_1 {
                    throw AudioError.invalidRenderGraphPlan(
                        "PureSphericalLosslessReader reserved channel \(channel.index) is not silent."
                    )
                }
            }
        }
    }

    private static func ledger(
        session: OpenSession,
        output: CanonicalAudioBlock,
        frameStart: Int64,
        frameCount: Int
    ) -> AudioConversionLedger {
        AudioConversionLedger(
            sessionID: session.context.sessionID,
            sourceID: session.sourceID,
            sourceKind: session.context.sourceKind,
            entries: [
                AudioConversionLedgerEntry(
                    stage: .validation,
                    owner: .pureSphericalLosslessValidator,
                    input: AudioFormatSummary(
                        sampleRate: session.parsed.sampleRate,
                        channelCount: session.parsed.channelCount,
                        sampleFormat: session.parsed.encoding.rawValue,
                        layoutName: layout(for: session.manifest.channelCount).name
                    ),
                    output: AudioFormatSummary(
                        sampleRate: session.manifest.sampleRate,
                        channelCount: session.manifest.channelCount,
                        sampleFormat: session.manifest.sampleFormat,
                        layoutName: layout(for: session.manifest.channelCount).name
                    ),
                    isExplicit: true,
                    note: "state=validForCurrentSphere; metadata=\(session.validation.metadataSource.ledgerDescription)"
                ),
                AudioConversionLedgerEntry(
                    stage: .directRead,
                    owner: .pureSphericalLosslessReader,
                    input: AudioFormatSummary(
                        sampleRate: session.parsed.sampleRate,
                        channelCount: session.parsed.channelCount,
                        sampleFormat: session.parsed.encoding.rawValue,
                        layoutName: layout(for: session.manifest.channelCount).name
                    ),
                    output: AudioFormatSummary(
                        sampleRate: output.sampleRate,
                        channelCount: output.channelCount,
                        sampleFormat: output.processingFormat.sampleFormat,
                        layoutName: output.layout.name
                    ),
                    isExplicit: true,
                    note: [
                        "container=\(session.parsed.containerKind.rawValue)",
                        "frameStart=\(frameStart)",
                        "frameCount=\(frameCount)",
                        "channelOrder=file-order",
                        "outputMapID=\(session.manifest.outputMapID)"
                    ].joined(separator: "; ")
                )
            ]
        )
    }

    private static func layout(for channelCount: Int) -> AudioChannelLayoutDescriptor {
        channelCount == AudioChannelLayoutDescriptor.direct31.channelCount ? .direct31 : .discrete(count: channelCount)
    }
}

private final class OpenSession {
    let validation: PureSphericalLosslessValidation
    let manifest: PureSphericalLosslessManifest
    let parsed: ParsedLPCMContainer
    let handle: FileHandle
    let context: PureSphericalLosslessReaderContext
    let sourceID: String
    var frameCursor: Int

    init(
        validation: PureSphericalLosslessValidation,
        manifest: PureSphericalLosslessManifest,
        parsed: ParsedLPCMContainer,
        handle: FileHandle,
        context: PureSphericalLosslessReaderContext,
        sourceID: String
    ) {
        self.validation = validation
        self.manifest = manifest
        self.parsed = parsed
        self.handle = handle
        self.context = context
        self.sourceID = sourceID
        self.frameCursor = 0
    }
}

private struct ParsedLPCMContainer {
    let containerKind: PureSphericalLosslessContainerKind
    let sampleRate: AudioSampleRate
    let channelCount: Int
    let bitsPerSample: Int
    let bytesPerSample: Int
    let encoding: PureSphericalLosslessSampleEncoding
    let isInterleaved: Bool
    let isBigEndian: Bool
    let dataOffset: UInt64
    let dataByteCount: UInt64

    var bytesPerFrameAcrossAllChannels: Int {
        channelCount * bytesPerSample
    }

    var totalFrames: Int {
        Int(dataByteCount / UInt64(bytesPerFrameAcrossAllChannels))
    }

    var publicFormat: PureSphericalLosslessPCMFormat {
        PureSphericalLosslessPCMFormat(
            containerKind: containerKind,
            sampleRate: sampleRate,
            channelCount: channelCount,
            bitsPerSample: bitsPerSample,
            bytesPerSample: bytesPerSample,
            encoding: encoding,
            isInterleaved: isInterleaved
        )
    }

    static func parse(
        url: URL,
        expectedKind: PureSphericalLosslessContainerKind
    ) throws -> ParsedLPCMContainer {
        switch expectedKind {
        case .bw64:
            try parseBW64(url: url)
        case .caf:
            try parseCAF(url: url)
        }
    }

    func byteOffset(channel: Int, frame: Int, framesInBlock: Int) -> Int {
        if isInterleaved {
            return ((frame * channelCount) + channel) * bytesPerSample
        }
        return ((channel * framesInBlock) + frame) * bytesPerSample
    }

    func decodeSample(data: Data, offset: Int) throws -> Float {
        switch encoding {
        case .float32:
            let bits = isBigEndian ? try data.uint32BE(at: offset) : try data.uint32LE(at: offset)
            return Float(bitPattern: bits)
        case .pcm24Integer:
            return try decodePCM24(data: data, offset: offset)
        }
    }

    private func decodePCM24(data: Data, offset: Int) throws -> Float {
        let b0 = Int32(try data.byte(at: offset))
        let b1 = Int32(try data.byte(at: offset + 1))
        let b2 = Int32(try data.byte(at: offset + 2))
        var value: Int32
        if isBigEndian {
            value = (b0 << 16) | (b1 << 8) | b2
        } else {
            value = b0 | (b1 << 8) | (b2 << 16)
        }
        if value & 0x80_0000 != 0 {
            value |= ~0xFF_FFFF
        }
        return Float(value) / 8_388_608
    }

    private static func parseBW64(url: URL) throws -> ParsedLPCMContainer {
        let fileSize = try fileSize(url: url)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        try handle.seek(toOffset: 0)
        let header = handle.readData(ofLength: 12)
        guard header.count == 12,
              try header.asciiString(at: 0, count: 4) == "BW64",
              try header.asciiString(at: 8, count: 4) == "WAVE" else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader expected BW64/WAVE header.")
        }

        var offset: UInt64 = 12
        var format: WaveFormat?
        var dataOffset: UInt64?
        var dataByteCount: UInt64?

        while offset + 8 <= fileSize {
            try handle.seek(toOffset: offset)
            let chunkHeader = handle.readData(ofLength: 8)
            guard chunkHeader.count == 8 else { break }
            let chunkID = try chunkHeader.asciiString(at: 0, count: 4)
            let declaredSize = UInt64(try chunkHeader.uint32LE(at: 4))
            let payloadOffset = offset + 8
            let payloadSize = declaredSize == UInt64(UInt32.max)
                ? fileSize - payloadOffset
                : min(declaredSize, fileSize - payloadOffset)

            if chunkID == "fmt " {
                try handle.seek(toOffset: payloadOffset)
                let payload = handle.readData(ofLength: Int(min(payloadSize, 64)))
                format = try WaveFormat(data: payload)
            } else if chunkID == "data" {
                dataOffset = payloadOffset
                dataByteCount = payloadSize
            }

            let paddedSize = payloadSize + (payloadSize % 2)
            offset = payloadOffset + paddedSize
        }

        guard let format else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader missing BW64 fmt chunk.")
        }
        guard let dataOffset, let dataByteCount else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader missing BW64 data chunk.")
        }

        return try ParsedLPCMContainer(
            containerKind: .bw64,
            sampleRate: format.sampleRate,
            channelCount: format.channelCount,
            bitsPerSample: format.bitsPerSample,
            bytesPerSample: format.bytesPerSample,
            encoding: format.encoding,
            isInterleaved: true,
            isBigEndian: false,
            dataOffset: dataOffset,
            dataByteCount: dataByteCount
        )
    }

    private static func parseCAF(url: URL) throws -> ParsedLPCMContainer {
        let fileSize = try fileSize(url: url)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        try handle.seek(toOffset: 0)
        let header = handle.readData(ofLength: 8)
        guard header.count == 8,
              try header.asciiString(at: 0, count: 4) == "caff" else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader expected CAF header.")
        }

        var offset: UInt64 = 8
        var format: CAFFormat?
        var dataOffset: UInt64?
        var dataByteCount: UInt64?

        while offset + 12 <= fileSize {
            try handle.seek(toOffset: offset)
            let chunkHeader = handle.readData(ofLength: 12)
            guard chunkHeader.count == 12 else { break }
            let chunkID = try chunkHeader.asciiString(at: 0, count: 4)
            let declaredSize = try chunkHeader.uint64BE(at: 4)
            let payloadOffset = offset + 12
            let payloadSize = declaredSize == UInt64.max
                ? fileSize - payloadOffset
                : min(declaredSize, fileSize - payloadOffset)

            if chunkID == "desc" {
                try handle.seek(toOffset: payloadOffset)
                let payload = handle.readData(ofLength: Int(min(payloadSize, 32)))
                format = try CAFFormat(data: payload)
            } else if chunkID == "data" {
                guard payloadSize >= 4 else {
                    throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader CAF data chunk is too small.")
                }
                dataOffset = payloadOffset + 4
                dataByteCount = payloadSize - 4
            }

            offset = payloadOffset + payloadSize
        }

        guard let format else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader missing CAF desc chunk.")
        }
        guard let dataOffset, let dataByteCount else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader missing CAF data chunk.")
        }

        return try ParsedLPCMContainer(
            containerKind: .caf,
            sampleRate: format.sampleRate,
            channelCount: format.channelCount,
            bitsPerSample: format.bitsPerSample,
            bytesPerSample: format.bytesPerSample,
            encoding: format.encoding,
            isInterleaved: !format.isNonInterleaved,
            isBigEndian: format.isBigEndian,
            dataOffset: dataOffset,
            dataByteCount: dataByteCount
        )
    }

    private static func fileSize(url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader cannot determine file size.")
        }
        return size.uint64Value
    }

    private init(
        containerKind: PureSphericalLosslessContainerKind,
        sampleRate: AudioSampleRate,
        channelCount: Int,
        bitsPerSample: Int,
        bytesPerSample: Int,
        encoding: PureSphericalLosslessSampleEncoding,
        isInterleaved: Bool,
        isBigEndian: Bool,
        dataOffset: UInt64,
        dataByteCount: UInt64
    ) throws {
        guard channelCount > 0 else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader channel count must be positive.")
        }
        guard bytesPerSample > 0 else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader bytes per sample must be positive.")
        }
        self.containerKind = containerKind
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bitsPerSample = bitsPerSample
        self.bytesPerSample = bytesPerSample
        self.encoding = encoding
        self.isInterleaved = isInterleaved
        self.isBigEndian = isBigEndian
        self.dataOffset = dataOffset
        self.dataByteCount = dataByteCount
    }
}

private struct WaveFormat {
    let sampleRate: AudioSampleRate
    let channelCount: Int
    let bitsPerSample: Int
    let bytesPerSample: Int
    let encoding: PureSphericalLosslessSampleEncoding

    init(data: Data) throws {
        guard data.count >= 16 else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader BW64 fmt chunk is too small.")
        }
        let audioFormat = try data.uint16LE(at: 0)
        channelCount = Int(try data.uint16LE(at: 2))
        sampleRate = try AudioSampleRate(hertz: Double(try data.uint32LE(at: 4)))
        let blockAlign = Int(try data.uint16LE(at: 12))
        bitsPerSample = Int(try data.uint16LE(at: 14))
        bytesPerSample = bitsPerSample / 8

        switch (audioFormat, bitsPerSample) {
        case (3, 32):
            encoding = .float32
        case (1, 24):
            encoding = .pcm24Integer
        default:
            throw AudioError.invalidRenderGraphPlan(
                "PureSphericalLosslessReader supports BW64 float32 and 24-bit PCM LPCM."
            )
        }

        guard blockAlign == channelCount * bytesPerSample else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader BW64 block alignment mismatch.")
        }
    }
}

private struct CAFFormat {
    let sampleRate: AudioSampleRate
    let channelCount: Int
    let bitsPerSample: Int
    let bytesPerSample: Int
    let encoding: PureSphericalLosslessSampleEncoding
    let isBigEndian: Bool
    let isNonInterleaved: Bool

    init(data: Data) throws {
        guard data.count >= 32 else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader CAF desc chunk is too small.")
        }
        sampleRate = try AudioSampleRate(hertz: data.double64BE(at: 0))
        let formatID = try data.asciiString(at: 8, count: 4)
        let flags = try data.uint32BE(at: 12)
        let framesPerPacket = try data.uint32BE(at: 20)
        channelCount = Int(try data.uint32BE(at: 24))
        bitsPerSample = Int(try data.uint32BE(at: 28))
        bytesPerSample = bitsPerSample / 8

        guard formatID == "lpcm" else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader CAF format is not LPCM.")
        }
        guard framesPerPacket == 1 else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader CAF LPCM must use one frame per packet.")
        }

        let isFloat = flags & 0x1 != 0
        isBigEndian = flags & 0x2 != 0
        let isSignedInteger = flags & 0x4 != 0
        isNonInterleaved = flags & 0x20 != 0

        if isFloat && bitsPerSample == 32 {
            encoding = .float32
        } else if isSignedInteger && bitsPerSample == 24 {
            encoding = .pcm24Integer
        } else {
            throw AudioError.invalidRenderGraphPlan(
                "PureSphericalLosslessReader supports CAF float32 and signed 24-bit PCM LPCM."
            )
        }
    }
}

private extension Data {
    func byte(at offset: Int) throws -> UInt8 {
        guard offset >= 0, offset < count else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader attempted to read past data bounds.")
        }
        return self[index(startIndex, offsetBy: offset)]
    }

    func asciiString(at offset: Int, count: Int) throws -> String {
        guard offset >= 0, count >= 0, offset + count <= self.count else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader attempted to read past data bounds.")
        }
        guard let string = String(data: subdata(in: offset..<(offset + count)), encoding: .ascii) else {
            throw AudioError.invalidRenderGraphPlan("PureSphericalLosslessReader expected ASCII chunk ID.")
        }
        return string
    }

    func uint16LE(at offset: Int) throws -> UInt16 {
        let b0 = UInt16(try byte(at: offset))
        let b1 = UInt16(try byte(at: offset + 1))
        return b0 | (b1 << 8)
    }

    func uint32LE(at offset: Int) throws -> UInt32 {
        let b0 = UInt32(try byte(at: offset))
        let b1 = UInt32(try byte(at: offset + 1))
        let b2 = UInt32(try byte(at: offset + 2))
        let b3 = UInt32(try byte(at: offset + 3))
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    func uint32BE(at offset: Int) throws -> UInt32 {
        let b0 = UInt32(try byte(at: offset))
        let b1 = UInt32(try byte(at: offset + 1))
        let b2 = UInt32(try byte(at: offset + 2))
        let b3 = UInt32(try byte(at: offset + 3))
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }

    func uint64BE(at offset: Int) throws -> UInt64 {
        var value: UInt64 = 0
        for byteOffset in 0..<8 {
            value = (value << 8) | UInt64(try byte(at: offset + byteOffset))
        }
        return value
    }

    func double64BE(at offset: Int) throws -> Double {
        Double(bitPattern: try uint64BE(at: offset))
    }
}

private extension PureSphericalLosslessMetadataSource {
    var ledgerDescription: String {
        switch self {
        case .embeddedORBI:
            "embedded ORBI"
        case .sidecar(let url):
            "sidecar \(url.lastPathComponent)"
        case .missing:
            "missing"
        }
    }
}
