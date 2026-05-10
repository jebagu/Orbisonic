import AudioContracts
import Foundation

public enum PureSphericalLosslessContainerKind: String, Equatable, Hashable, Sendable {
    case bw64 = "BW64"
    case caf = "CAF"
}

public enum PureSphericalLosslessMetadataSource: Equatable, Hashable, Sendable {
    case embeddedORBI
    case sidecar(URL)
    case missing
}

public struct PureSphericalLosslessChannelManifest: Codable, Equatable, Hashable, Sendable {
    public let index: Int
    public let channelID: String
    public let speakerID: String
    public let logicalOutputChannel: Int
    public let physicalOutputChannel: Int?
    public let danteTransmitChannel: Int?
    public let role: String
    public let azimuth: Double?
    public let elevation: Double?
    public let radius: Double?
    public let trimDb: Double
    public let delayMs: Double
    public let polarity: Int
    public let isReservedSilent: Bool

    enum CodingKeys: String, CodingKey {
        case index
        case channelID
        case speakerID
        case logicalOutputChannel
        case physicalOutputChannel
        case danteTransmitChannel
        case role
        case azimuth
        case elevation
        case radius
        case trimDb
        case delayMs
        case polarity
        case isReservedSilent
        case reserved
        case silent
    }

    public init(
        index: Int,
        channelID: String,
        speakerID: String,
        logicalOutputChannel: Int,
        physicalOutputChannel: Int? = nil,
        danteTransmitChannel: Int? = nil,
        role: String,
        azimuth: Double? = nil,
        elevation: Double? = nil,
        radius: Double? = nil,
        trimDb: Double = 0,
        delayMs: Double = 0,
        polarity: Int = 1,
        isReservedSilent: Bool = false
    ) {
        self.index = index
        self.channelID = channelID
        self.speakerID = speakerID
        self.logicalOutputChannel = logicalOutputChannel
        self.physicalOutputChannel = physicalOutputChannel
        self.danteTransmitChannel = danteTransmitChannel
        self.role = role
        self.azimuth = azimuth
        self.elevation = elevation
        self.radius = radius
        self.trimDb = trimDb
        self.delayMs = delayMs
        self.polarity = polarity
        self.isReservedSilent = isReservedSilent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = try container.decode(Int.self, forKey: .index)
        channelID = try container.decode(String.self, forKey: .channelID)
        speakerID = try container.decode(String.self, forKey: .speakerID)
        logicalOutputChannel = try container.decode(Int.self, forKey: .logicalOutputChannel)
        physicalOutputChannel = try container.decodeIfPresent(Int.self, forKey: .physicalOutputChannel)
        danteTransmitChannel = try container.decodeIfPresent(Int.self, forKey: .danteTransmitChannel)
        role = try container.decode(String.self, forKey: .role)
        azimuth = try container.decodeIfPresent(Double.self, forKey: .azimuth)
        elevation = try container.decodeIfPresent(Double.self, forKey: .elevation)
        radius = try container.decodeIfPresent(Double.self, forKey: .radius)
        trimDb = try container.decodeIfPresent(Double.self, forKey: .trimDb) ?? 0
        delayMs = try container.decodeIfPresent(Double.self, forKey: .delayMs) ?? 0
        polarity = try container.decodeIfPresent(Int.self, forKey: .polarity) ?? 1
        let explicitReserved = try container.decodeIfPresent(Bool.self, forKey: .isReservedSilent)
        let reserved = try container.decodeIfPresent(Bool.self, forKey: .reserved)
        let silent = try container.decodeIfPresent(Bool.self, forKey: .silent)
        isReservedSilent = explicitReserved ?? ((reserved ?? false) && (silent ?? false))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(channelID, forKey: .channelID)
        try container.encode(speakerID, forKey: .speakerID)
        try container.encode(logicalOutputChannel, forKey: .logicalOutputChannel)
        try container.encodeIfPresent(physicalOutputChannel, forKey: .physicalOutputChannel)
        try container.encodeIfPresent(danteTransmitChannel, forKey: .danteTransmitChannel)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(azimuth, forKey: .azimuth)
        try container.encodeIfPresent(elevation, forKey: .elevation)
        try container.encodeIfPresent(radius, forKey: .radius)
        try container.encode(trimDb, forKey: .trimDb)
        try container.encode(delayMs, forKey: .delayMs)
        try container.encode(polarity, forKey: .polarity)
        try container.encode(isReservedSilent, forKey: .isReservedSilent)
    }
}

public struct PureSphericalLosslessManifest: Codable, Equatable, Hashable, Sendable {
    public static let schemaV1 = "com.orbisonic.pure-spherical-lossless.v1"
    public static let expectedDisplayLabel = "Pure Spherical Lossless"

    public let schema: String
    public let displayLabel: String
    public let renderKind: String
    public let lossless: Bool
    public let codec: String
    public let alreadyRendered: Bool
    public let requiresRendererAtPlayback: Bool
    public let requiresVlcDownmix: Bool
    public let downmixOccurred: Bool
    public let lossyCodec: Bool
    public let sampleRate: AudioSampleRate
    public let channelCount: Int
    public let sampleFormat: String
    public let sphereProfileID: String
    public let calibrationID: String?
    public let outputMapID: String
    public let rendererVersion: String?
    public let rendererMatrixHash: String?
    public let channels: [PureSphericalLosslessChannelManifest]

    enum CodingKeys: String, CodingKey {
        case schema
        case displayLabel
        case renderKind
        case lossless
        case codec
        case alreadyRendered
        case requiresRendererAtPlayback
        case requiresVlcDownmix
        case downmixOccurred
        case lossyCodec
        case sampleRate
        case channelCount
        case sampleFormat
        case sphereProfileID
        case calibrationID
        case outputMapID
        case rendererVersion
        case rendererMatrixHash
        case channels
    }

    public init(
        schema: String = schemaV1,
        displayLabel: String = expectedDisplayLabel,
        renderKind: String = "sonicSphere.discreteSpeakerBed",
        lossless: Bool = true,
        codec: String = "LPCM",
        alreadyRendered: Bool = true,
        requiresRendererAtPlayback: Bool = false,
        requiresVlcDownmix: Bool = false,
        downmixOccurred: Bool = false,
        lossyCodec: Bool = false,
        sampleRate: AudioSampleRate,
        channelCount: Int,
        sampleFormat: String,
        sphereProfileID: String,
        calibrationID: String? = nil,
        outputMapID: String,
        rendererVersion: String? = nil,
        rendererMatrixHash: String? = nil,
        channels: [PureSphericalLosslessChannelManifest]
    ) {
        self.schema = schema
        self.displayLabel = displayLabel
        self.renderKind = renderKind
        self.lossless = lossless
        self.codec = codec
        self.alreadyRendered = alreadyRendered
        self.requiresRendererAtPlayback = requiresRendererAtPlayback
        self.requiresVlcDownmix = requiresVlcDownmix
        self.downmixOccurred = downmixOccurred
        self.lossyCodec = lossyCodec
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.sampleFormat = sampleFormat
        self.sphereProfileID = sphereProfileID
        self.calibrationID = calibrationID
        self.outputMapID = outputMapID
        self.rendererVersion = rendererVersion
        self.rendererMatrixHash = rendererMatrixHash
        self.channels = channels
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schema = try container.decode(String.self, forKey: .schema)
        displayLabel = try container.decode(String.self, forKey: .displayLabel)
        renderKind = try container.decode(String.self, forKey: .renderKind)
        lossless = try container.decode(Bool.self, forKey: .lossless)
        codec = try container.decode(String.self, forKey: .codec)
        alreadyRendered = try container.decode(Bool.self, forKey: .alreadyRendered)
        requiresRendererAtPlayback = try container.decode(Bool.self, forKey: .requiresRendererAtPlayback)
        requiresVlcDownmix = try container.decode(Bool.self, forKey: .requiresVlcDownmix)
        downmixOccurred = try container.decodeIfPresent(Bool.self, forKey: .downmixOccurred) ?? false
        lossyCodec = try container.decodeIfPresent(Bool.self, forKey: .lossyCodec) ?? !lossless
        let sampleRateValue = try container.decode(Double.self, forKey: .sampleRate)
        sampleRate = try AudioSampleRate(hertz: sampleRateValue)
        channelCount = try container.decode(Int.self, forKey: .channelCount)
        sampleFormat = try container.decode(String.self, forKey: .sampleFormat)
        sphereProfileID = try container.decode(String.self, forKey: .sphereProfileID)
        calibrationID = try container.decodeIfPresent(String.self, forKey: .calibrationID)
        outputMapID = try container.decode(String.self, forKey: .outputMapID)
        rendererVersion = try container.decodeIfPresent(String.self, forKey: .rendererVersion)
        rendererMatrixHash = try container.decodeIfPresent(String.self, forKey: .rendererMatrixHash)
        channels = try container.decode([PureSphericalLosslessChannelManifest].self, forKey: .channels)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schema, forKey: .schema)
        try container.encode(displayLabel, forKey: .displayLabel)
        try container.encode(renderKind, forKey: .renderKind)
        try container.encode(lossless, forKey: .lossless)
        try container.encode(codec, forKey: .codec)
        try container.encode(alreadyRendered, forKey: .alreadyRendered)
        try container.encode(requiresRendererAtPlayback, forKey: .requiresRendererAtPlayback)
        try container.encode(requiresVlcDownmix, forKey: .requiresVlcDownmix)
        try container.encode(downmixOccurred, forKey: .downmixOccurred)
        try container.encode(lossyCodec, forKey: .lossyCodec)
        try container.encode(sampleRate.hertz, forKey: .sampleRate)
        try container.encode(channelCount, forKey: .channelCount)
        try container.encode(sampleFormat, forKey: .sampleFormat)
        try container.encode(sphereProfileID, forKey: .sphereProfileID)
        try container.encodeIfPresent(calibrationID, forKey: .calibrationID)
        try container.encode(outputMapID, forKey: .outputMapID)
        try container.encodeIfPresent(rendererVersion, forKey: .rendererVersion)
        try container.encodeIfPresent(rendererMatrixHash, forKey: .rendererMatrixHash)
        try container.encode(channels, forKey: .channels)
    }
}

public struct PureSphericalLosslessValidation: Equatable, Sendable {
    public let url: URL
    public let state: PureSphericalLosslessState
    public let containerKind: PureSphericalLosslessContainerKind?
    public let metadataSource: PureSphericalLosslessMetadataSource
    public let manifest: PureSphericalLosslessManifest?
    public let validationMessages: [String]

    public init(
        url: URL,
        state: PureSphericalLosslessState,
        containerKind: PureSphericalLosslessContainerKind?,
        metadataSource: PureSphericalLosslessMetadataSource,
        manifest: PureSphericalLosslessManifest?,
        validationMessages: [String]
    ) {
        self.url = url
        self.state = state
        self.containerKind = containerKind
        self.metadataSource = metadataSource
        self.manifest = manifest
        self.validationMessages = validationMessages
    }

    public var badgeText: String? {
        state.badgeText
    }
}

public struct PureSphericalLosslessValidator: Sendable {
    public init() {}

    public func validate(
        url: URL,
        currentSphere: SonicSphereProfile?,
        route: OutputRouteDescriptor?
    ) throws -> PureSphericalLosslessValidation {
        let containerKind = try Self.containerKind(for: url)
        guard let containerKind else {
            return invalid(
                url: url,
                containerKind: nil,
                metadataSource: .missing,
                manifest: nil,
                reason: "unsupported container"
            )
        }

        let metadata = Self.readMetadata(for: url)
        switch metadata {
        case .failure(let message):
            return invalid(
                url: url,
                containerKind: containerKind,
                metadataSource: .missing,
                manifest: nil,
                reason: message
            )
        case .success(let source, let manifest):
            return validate(
                url: url,
                containerKind: containerKind,
                metadataSource: source,
                manifest: manifest,
                currentSphere: currentSphere,
                route: route
            )
        }
    }

    private func validate(
        url: URL,
        containerKind: PureSphericalLosslessContainerKind,
        metadataSource: PureSphericalLosslessMetadataSource,
        manifest: PureSphericalLosslessManifest,
        currentSphere: SonicSphereProfile?,
        route: OutputRouteDescriptor?
    ) -> PureSphericalLosslessValidation {
        var messages: [String] = ["container=\(containerKind.rawValue)", "metadata=\(metadataSource.description)"]
        let manifestErrors = Self.manifestErrors(manifest)
        if let firstError = manifestErrors.first {
            messages.append(contentsOf: manifestErrors)
            return PureSphericalLosslessValidation(
                url: url,
                state: .invalid(reason: firstError),
                containerKind: containerKind,
                metadataSource: metadataSource,
                manifest: manifest,
                validationMessages: messages
            )
        }

        guard let currentSphere else {
            messages.append("current sphere profile unavailable")
            return PureSphericalLosslessValidation(
                url: url,
                state: .validForDifferentSphere,
                containerKind: containerKind,
                metadataSource: metadataSource,
                manifest: manifest,
                validationMessages: messages
            )
        }

        let sphereMatches = manifest.sphereProfileID == currentSphere.id &&
            manifest.outputMapID == currentSphere.outputMapID &&
            manifest.channelCount == currentSphere.outputChannelCount &&
            manifest.sampleRate.matches(currentSphere.sampleRate)

        guard sphereMatches else {
            messages.append("validated for different sphere or output map")
            return PureSphericalLosslessValidation(
                url: url,
                state: .validForDifferentSphere,
                containerKind: containerKind,
                metadataSource: metadataSource,
                manifest: manifest,
                validationMessages: messages
            )
        }

        guard Self.routeCanPlay(manifest: manifest, route: route) else {
            messages.append("route cannot currently carry validated sphere bed")
            return PureSphericalLosslessValidation(
                url: url,
                state: .routeNotReady,
                containerKind: containerKind,
                metadataSource: metadataSource,
                manifest: manifest,
                validationMessages: messages
            )
        }

        messages.append("valid for current sphere")
        return PureSphericalLosslessValidation(
            url: url,
            state: .validForCurrentSphere,
            containerKind: containerKind,
            metadataSource: metadataSource,
            manifest: manifest,
            validationMessages: messages
        )
    }

    private func invalid(
        url: URL,
        containerKind: PureSphericalLosslessContainerKind?,
        metadataSource: PureSphericalLosslessMetadataSource,
        manifest: PureSphericalLosslessManifest?,
        reason: String
    ) -> PureSphericalLosslessValidation {
        PureSphericalLosslessValidation(
            url: url,
            state: .invalid(reason: reason),
            containerKind: containerKind,
            metadataSource: metadataSource,
            manifest: manifest,
            validationMessages: [reason]
        )
    }

    private static func containerKind(for url: URL) throws -> PureSphericalLosslessContainerKind? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let header = handle.readData(ofLength: 12)
        guard header.count >= 4 else { return nil }
        let prefix = String(data: header.prefix(4), encoding: .ascii)
        if prefix == "BW64" {
            return .bw64
        }
        if prefix == "caff" {
            return .caf
        }
        return nil
    }

    private enum MetadataReadResult {
        case success(PureSphericalLosslessMetadataSource, PureSphericalLosslessManifest)
        case failure(String)
    }

    private static func readMetadata(for url: URL) -> MetadataReadResult {
        if let embedded = try? embeddedManifest(for: url) {
            return .success(.embeddedORBI, embedded)
        }

        for sidecarURL in sidecarCandidates(for: url) {
            guard FileManager.default.fileExists(atPath: sidecarURL.path) else { continue }
            do {
                let data = try Data(contentsOf: sidecarURL)
                return .success(.sidecar(sidecarURL), try JSONDecoder().decode(PureSphericalLosslessManifest.self, from: data))
            } catch {
                return .failure("invalid Pure Spherical Lossless sidecar metadata: \(error.localizedDescription)")
            }
        }

        return .failure("Pure Spherical Lossless metadata missing")
    }

    private static func sidecarCandidates(for url: URL) -> [URL] {
        [
            url.appendingPathExtension("orbi.json"),
            url.deletingPathExtension().appendingPathExtension("orbi.json")
        ]
    }

    private static func embeddedManifest(for url: URL) throws -> PureSphericalLosslessManifest? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = handle.readData(ofLength: 1_048_576)
        guard let markerRange = data.range(of: Data("ORBI\n".utf8)) else { return nil }
        let jsonData = data.subdata(in: markerRange.upperBound..<data.endIndex)
        guard !jsonData.isEmpty else { return nil }
        return try JSONDecoder().decode(PureSphericalLosslessManifest.self, from: jsonData)
    }

    private static func manifestErrors(_ manifest: PureSphericalLosslessManifest) -> [String] {
        var errors: [String] = []
        if manifest.schema != PureSphericalLosslessManifest.schemaV1 {
            errors.append("unsupported Pure Spherical Lossless schema")
        }
        if manifest.displayLabel != PureSphericalLosslessManifest.expectedDisplayLabel {
            errors.append("display label is not Pure Spherical Lossless")
        }
        if manifest.renderKind != "sonicSphere.discreteSpeakerBed" {
            errors.append("render kind is not a SonicSphere discrete speaker bed")
        }
        if !manifest.lossless || manifest.lossyCodec {
            errors.append("manifest does not describe lossless LPCM")
        }
        if !manifest.codec.caseInsensitiveEquals("LPCM") && !manifest.codec.caseInsensitiveEquals("PCM") {
            errors.append("codec is not LPCM")
        }
        if !manifest.alreadyRendered {
            errors.append("file is not already rendered")
        }
        if manifest.requiresRendererAtPlayback {
            errors.append("file requires renderer at playback")
        }
        if manifest.requiresVlcDownmix {
            errors.append("file requires VLC downmix")
        }
        if manifest.downmixOccurred {
            errors.append("manifest reports downmix occurred")
        }
        if manifest.channelCount <= 0 {
            errors.append("channel count must be positive")
        }
        if manifest.channels.count != manifest.channelCount {
            errors.append("channel manifest count does not match audio channel count")
        }
        errors.append(contentsOf: channelErrors(manifest.channels, channelCount: manifest.channelCount))
        if manifest.sampleFormat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("sample format missing")
        }
        if manifest.sphereProfileID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("sphere profile id missing")
        }
        if manifest.outputMapID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("output map id missing")
        }
        return errors
    }

    private static func channelErrors(
        _ channels: [PureSphericalLosslessChannelManifest],
        channelCount: Int
    ) -> [String] {
        var errors: [String] = []
        let indexes = Set(channels.map(\.index))
        if indexes.count != channels.count {
            errors.append("channel indexes must be unique")
        }
        for channel in channels {
            if channel.index < 0 || channel.index >= channelCount {
                errors.append("channel index \(channel.index) is outside the audio channel count")
            }
            if channel.logicalOutputChannel <= 0 || channel.logicalOutputChannel > channelCount {
                errors.append("logical output channel \(channel.logicalOutputChannel) is outside the audio channel count")
            }
            if channel.channelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("channel \(channel.index) is missing channelID")
            }
            if channel.speakerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("channel \(channel.index) is missing speakerID")
            }
            if channel.polarity != 1 && channel.polarity != -1 {
                errors.append("channel \(channel.index) has invalid polarity")
            }
        }
        return errors
    }

    private static func routeCanPlay(
        manifest: PureSphericalLosslessManifest,
        route: OutputRouteDescriptor?
    ) -> Bool {
        guard let route, route.isAvailable else { return false }
        guard route.outputChannelCount >= manifest.channelCount else { return false }
        guard let routeSampleRate = route.nominalSampleRate else { return false }
        return routeSampleRate.matches(manifest.sampleRate)
    }
}

private extension String {
    func caseInsensitiveEquals(_ other: String) -> Bool {
        localizedCaseInsensitiveCompare(other) == .orderedSame
    }
}

private extension PureSphericalLosslessMetadataSource {
    var description: String {
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
