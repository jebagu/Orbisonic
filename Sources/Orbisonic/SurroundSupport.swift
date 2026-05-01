import AVFoundation
import CoreAudio
import CoreAudioTypes
import Foundation

enum SurroundChannelRole: Hashable, Sendable {
    case frontLeft
    case frontRight
    case center
    case lfe
    case lfe2
    case sideLeft
    case sideRight
    case rearLeft
    case rearRight
    case rearCenter
    case wideLeft
    case wideRight
    case frontLeftCenter
    case frontRightCenter
    case topFrontLeft
    case topFrontCenter
    case topFrontRight
    case topMiddleLeft
    case topMiddleCenter
    case topMiddleRight
    case topRearLeft
    case topRearCenter
    case topRearRight
    case discrete(Int)

    var id: String {
        switch self {
        case .frontLeft: "front-left"
        case .frontRight: "front-right"
        case .center: "center"
        case .lfe: "lfe-1"
        case .lfe2: "lfe-2"
        case .sideLeft: "side-left"
        case .sideRight: "side-right"
        case .rearLeft: "rear-left"
        case .rearRight: "rear-right"
        case .rearCenter: "rear-center"
        case .wideLeft: "wide-left"
        case .wideRight: "wide-right"
        case .frontLeftCenter: "front-left-center"
        case .frontRightCenter: "front-right-center"
        case .topFrontLeft: "top-front-left"
        case .topFrontCenter: "top-front-center"
        case .topFrontRight: "top-front-right"
        case .topMiddleLeft: "top-middle-left"
        case .topMiddleCenter: "top-middle-center"
        case .topMiddleRight: "top-middle-right"
        case .topRearLeft: "top-rear-left"
        case .topRearCenter: "top-rear-center"
        case .topRearRight: "top-rear-right"
        case .discrete(let index): "discrete-\(index)"
        }
    }

    var displayName: String {
        switch self {
        case .frontLeft: "Front Left"
        case .frontRight: "Front Right"
        case .center: "Center"
        case .lfe: "LFE 1"
        case .lfe2: "LFE 2"
        case .sideLeft: "Side Left"
        case .sideRight: "Side Right"
        case .rearLeft: "Rear Left"
        case .rearRight: "Rear Right"
        case .rearCenter: "Rear Center"
        case .wideLeft: "Wide Left"
        case .wideRight: "Wide Right"
        case .frontLeftCenter: "Front Left Center"
        case .frontRightCenter: "Front Right Center"
        case .topFrontLeft: "Top Front Left"
        case .topFrontCenter: "Top Front Center"
        case .topFrontRight: "Top Front Right"
        case .topMiddleLeft: "Top Middle Left"
        case .topMiddleCenter: "Top Middle Center"
        case .topMiddleRight: "Top Middle Right"
        case .topRearLeft: "Top Rear Left"
        case .topRearCenter: "Top Rear Center"
        case .topRearRight: "Top Rear Right"
        case .discrete(let index): "Discrete \(index + 1)"
        }
    }

    var shortLabel: String {
        switch self {
        case .frontLeft: "FL"
        case .frontRight: "FR"
        case .center: "C"
        case .lfe: "LFE1"
        case .lfe2: "LFE2"
        case .sideLeft: "SL"
        case .sideRight: "SR"
        case .rearLeft: "RL"
        case .rearRight: "RR"
        case .rearCenter: "RC"
        case .wideLeft: "WL"
        case .wideRight: "WR"
        case .frontLeftCenter: "FLC"
        case .frontRightCenter: "FRC"
        case .topFrontLeft: "TFL"
        case .topFrontCenter: "TFC"
        case .topFrontRight: "TFR"
        case .topMiddleLeft: "TML"
        case .topMiddleCenter: "TMC"
        case .topMiddleRight: "TMR"
        case .topRearLeft: "TRL"
        case .topRearCenter: "TRC"
        case .topRearRight: "TRR"
        case .discrete(let index): "CH\(index + 1)"
        }
    }

    var isLFE: Bool {
        switch self {
        case .lfe, .lfe2: true
        default: false
        }
    }

    var isRear: Bool {
        switch self {
        case .rearLeft, .rearRight, .rearCenter, .topRearLeft, .topRearCenter, .topRearRight: true
        default: false
        }
    }

    var displayOrder: Int {
        switch self {
        case .frontLeft: 0
        case .frontRight: 1
        case .center: 2
        case .frontLeftCenter: 3
        case .frontRightCenter: 4
        case .wideLeft: 5
        case .wideRight: 6
        case .sideLeft: 7
        case .sideRight: 8
        case .rearLeft: 9
        case .rearCenter: 10
        case .rearRight: 11
        case .topFrontLeft: 12
        case .topFrontCenter: 13
        case .topFrontRight: 14
        case .topMiddleLeft: 15
        case .topMiddleCenter: 16
        case .topMiddleRight: 17
        case .topRearLeft: 18
        case .topRearCenter: 19
        case .topRearRight: 20
        case .discrete(let index): 40 + index
        case .lfe: 90
        case .lfe2: 91
        }
    }
}

struct SurroundChannel: Identifiable, Hashable, Sendable {
    let index: Int
    let role: SurroundChannelRole

    var id: String {
        "\(index)-\(role.id)"
    }

    var displayName: String {
        role.displayName
    }

    var shortLabel: String {
        role.shortLabel
    }
}

struct SurroundLayout: Hashable, Sendable {
    let name: String
    let channels: [SurroundChannel]

    var channelCount: Int {
        channels.count
    }

    var channelSummary: String {
        channels.map(\.shortLabel).joined(separator: ", ")
    }
}

enum ChannelLayoutConfidence: String, Comparable, Sendable {
    case low
    case high

    static func < (lhs: ChannelLayoutConfidence, rhs: ChannelLayoutConfidence) -> Bool {
        switch (lhs, rhs) {
        case (.low, .high):
            return true
        default:
            return false
        }
    }
}

enum ChannelLayoutDescriptorSource: Equatable, Sendable {
    case fallbackChannelCount
    case explicitChannelDescriptions
    case explicitCoreAudioLayoutTag(String)
    case unknown
}

struct ChannelRoleLayoutDescriptor: Equatable, Sendable {
    let layoutName: String
    let roles: [SurroundChannelRole]
    let source: ChannelLayoutDescriptorSource
    let confidence: ChannelLayoutConfidence
    let sourceDescription: String
    let warningDescriptions: [String]

    var channelCount: Int {
        roles.count
    }

    var layout: SurroundLayout {
        SurroundLayout(
            name: layoutName,
            channels: roles.enumerated().map { index, role in
                SurroundChannel(index: index, role: role)
            }
        )
    }

    var roleSummary: String {
        layout.channelSummary
    }

    var appliesMPEGFiveOneCRemap: Bool {
        roles == Self.mpegFiveOneCRoles && confidence == .high
    }

    static func fallback(for channelCount: Int) -> ChannelRoleLayoutDescriptor {
        let fallback = fallbackNameAndRoles(for: channelCount)
        return ChannelRoleLayoutDescriptor(
            layoutName: fallback.name,
            roles: fallback.roles,
            source: .fallbackChannelCount,
            confidence: .low,
            sourceDescription: "Fallback by channel count",
            warningDescriptions: []
        )
    }

    static func unknown(channelCount: Int, sourceDescription: String) -> ChannelRoleLayoutDescriptor {
        let fallback = fallbackNameAndRoles(for: channelCount)
        return ChannelRoleLayoutDescriptor(
            layoutName: fallback.name,
            roles: fallback.roles,
            source: .unknown,
            confidence: .low,
            sourceDescription: sourceDescription,
            warningDescriptions: lowConfidenceWarnings(channelCount: channelCount, sourceDescription: sourceDescription)
        )
    }

    static func mpegFiveOneC(
        confidence: ChannelLayoutConfidence,
        sourceDescription: String
    ) -> ChannelRoleLayoutDescriptor {
        guard confidence == .high else {
            let fallback = fallbackNameAndRoles(for: 6)
            return ChannelRoleLayoutDescriptor(
                layoutName: fallback.name,
                roles: fallback.roles,
                source: .unknown,
                confidence: .low,
                sourceDescription: sourceDescription,
                warningDescriptions: [
                    "Low-confidence MPEG 5.1 C layout ignored; using legacy 5.1 order L R C LFE Ls Rs."
                ]
            )
        }

        return ChannelRoleLayoutDescriptor(
            layoutName: "5.1 Surround",
            roles: mpegFiveOneCRoles,
            source: .explicitCoreAudioLayoutTag("MPEG 5.1 C"),
            confidence: .high,
            sourceDescription: sourceDescription,
            warningDescriptions: []
        )
    }

    static func explicit(
        layoutName: String,
        roles: [SurroundChannelRole],
        source: ChannelLayoutDescriptorSource,
        sourceDescription: String
    ) -> ChannelRoleLayoutDescriptor {
        ChannelRoleLayoutDescriptor(
            layoutName: layoutName,
            roles: roles,
            source: source,
            confidence: .high,
            sourceDescription: sourceDescription,
            warningDescriptions: []
        )
    }

    private static let mpegFiveOneCRoles: [SurroundChannelRole] = [
        .frontLeft, .center, .frontRight, .sideLeft, .sideRight, .lfe
    ]

    private static func lowConfidenceWarnings(
        channelCount: Int,
        sourceDescription: String
    ) -> [String] {
        switch channelCount {
        case 6:
            return [
                "Low-confidence 5.1 layout \(sourceDescription); using legacy order L R C LFE Ls Rs."
            ]
        case 8:
            return [
                "Low-confidence 7.1 layout \(sourceDescription); using legacy order L R C LFE Ls Rs Lrs Rrs."
            ]
        default:
            return []
        }
    }

    private static func fallbackNameAndRoles(
        for channelCount: Int
    ) -> (name: String, roles: [SurroundChannelRole]) {
        switch channelCount {
        case 1:
            return ("Mono", [.center])
        case 2:
            return ("Stereo", [.frontLeft, .frontRight])
        case 3:
            return ("3.0", [.frontLeft, .frontRight, .center])
        case 4:
            return ("Quadraphonic (4.0)", [.frontLeft, .frontRight, .rearLeft, .rearRight])
        case 5:
            return ("5.0 Surround", [.frontLeft, .frontRight, .center, .sideLeft, .sideRight])
        case 6:
            return ("5.1 Surround", [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight])
        case 7:
            return ("6.1 Surround", [.frontLeft, .frontRight, .center, .lfe, .rearCenter, .sideLeft, .sideRight])
        case 8:
            return ("7.1 Surround", [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight, .rearLeft, .rearRight])
        case 9:
            return ("9.0 Surround", [.frontLeft, .frontRight, .center, .rearLeft, .rearRight, .sideLeft, .sideRight, .wideLeft, .wideRight])
        case 10:
            return ("7.1.2", [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight, .rearLeft, .rearRight, .topFrontLeft, .topFrontRight])
        case 11:
            return ("9.2 Surround", [.frontLeft, .frontRight, .center, .rearLeft, .rearRight, .sideLeft, .sideRight, .wideLeft, .wideRight, .lfe, .lfe2])
        case 12:
            return ("7.1.4", [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight, .rearLeft, .rearRight, .topFrontLeft, .topFrontRight, .topRearLeft, .topRearRight])
        case 14:
            return ("9.1.4", [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight, .rearLeft, .rearRight, .wideLeft, .wideRight, .topFrontLeft, .topFrontRight, .topRearLeft, .topRearRight])
        case 16:
            return ("9.1.6", [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight, .rearLeft, .rearRight, .wideLeft, .wideRight, .topFrontLeft, .topFrontRight, .topMiddleLeft, .topMiddleRight, .topRearLeft, .topRearRight])
        default:
            return ("\(channelCount)-Channel Discrete", (0..<channelCount).map { .discrete($0) })
        }
    }
}

extension Sequence where Element == SurroundChannel {
    func displayOrdered() -> [SurroundChannel] {
        sorted { lhs, rhs in
            if lhs.role.displayOrder == rhs.role.displayOrder {
                return lhs.index < rhs.index
            }
            return lhs.role.displayOrder < rhs.role.displayOrder
        }
    }
}

struct AudioSourceMetadata {
    let fileName: String
    let containerName: String
    let codecName: String
    let layoutName: String
    let channelSummary: String
    let channelCount: Int
    let sampleRate: Double
    let bitDepth: UInt32
    let duration: TimeInterval
    let title: String?
    let album: String?
    let artist: String?
    let formatNote: String?

    init(
        fileName: String,
        containerName: String,
        codecName: String,
        layoutName: String,
        channelSummary: String,
        channelCount: Int,
        sampleRate: Double,
        bitDepth: UInt32,
        duration: TimeInterval,
        title: String? = nil,
        album: String? = nil,
        artist: String? = nil,
        formatNote: String? = nil
    ) {
        self.fileName = fileName
        self.containerName = containerName
        self.codecName = codecName
        self.layoutName = layoutName
        self.channelSummary = channelSummary
        self.channelCount = channelCount
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.duration = duration
        self.title = title
        self.album = album
        self.artist = artist
        self.formatNote = formatNote
    }

    var sampleRateText: String {
        if sampleRate >= 1_000 {
            return String(format: "%.1f kHz", sampleRate / 1_000)
        }
        return String(format: "%.0f Hz", sampleRate)
    }

    var bitDepthText: String {
        bitDepth > 0 ? "\(bitDepth)-bit" : "Unknown"
    }

    var durationText: String {
        let totalSeconds = max(Int(duration.rounded(.down)), 0)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct AudioSourceTags: Equatable, Sendable {
    var title: String?
    var album: String?
    var artist: String?

    static let empty = AudioSourceTags()

    var isEmpty: Bool {
        title?.trimmedNilIfBlank == nil
            && album?.trimmedNilIfBlank == nil
            && artist?.trimmedNilIfBlank == nil
    }
}

enum SpatialPreset: String, CaseIterable, Identifiable {
    case studioWide = "Studio Wide"
    case immersiveWrap = "Immersive Wrap"
    case diamond = "Diamond"

    var id: String { rawValue }

    var defaults: SpatialTuning {
        switch self {
        case .studioWide:
            SpatialTuning(
                preset: self,
                frontAngle: 34,
                rearAngle: 112
            )
        case .immersiveWrap:
            SpatialTuning(
                preset: self,
                frontAngle: 40,
                rearAngle: 132
            )
        case .diamond:
            SpatialTuning(
                preset: self,
                frontAngle: 45,
                rearAngle: 145
            )
        }
    }
}

struct SurroundLayoutDetector {
    static func detect(for format: AVAudioFormat) -> SurroundLayout {
        descriptor(for: format).layout
    }

    static func descriptor(for format: AVAudioFormat) -> ChannelRoleLayoutDescriptor {
        let channelCount = Int(format.channelCount)

        if let channelLayout = format.channelLayout {
            return descriptor(from: channelLayout, fallbackCount: channelCount)
        }

        return fallbackDescriptor(for: channelCount)
    }

    static func fallbackLayout(for channelCount: Int) -> SurroundLayout {
        fallbackDescriptor(for: channelCount).layout
    }

    static func fallbackDescriptor(for channelCount: Int) -> ChannelRoleLayoutDescriptor {
        ChannelRoleLayoutDescriptor.fallback(for: channelCount)
    }

    static func discreteRoles(for channelCount: Int) -> [SurroundChannelRole] {
        (0..<channelCount).map { .discrete($0) }
    }

    private static func descriptor(
        from channelLayout: AVAudioChannelLayout,
        fallbackCount: Int
    ) -> ChannelRoleLayoutDescriptor {
        let rawDescriptions = AudioChannelLayout.UnsafePointer(channelLayout.layout)
        if rawDescriptions.count == fallbackCount, rawDescriptions.count > 0 {
            let mapped = (0..<rawDescriptions.count).map { index in
                let description = rawDescriptions[index]
                return SurroundChannel(index: index, role: role(for: description.mChannelLabel, index: index))
            }

            let recognizedCount = mapped.reduce(into: 0) { partialResult, channel in
                if case .discrete = channel.role {
                    return
                }
                partialResult += 1
            }

            if recognizedCount > 0 {
                return ChannelRoleLayoutDescriptor.explicit(
                    layoutName: layoutName(for: mapped, fallbackCount: fallbackCount),
                    roles: mapped.map(\.role),
                    source: .explicitChannelDescriptions,
                    sourceDescription: "Explicit Core Audio channel descriptions"
                )
            }
        }

        let tag = channelLayout.layout.pointee.mChannelLayoutTag
        if let taggedDescriptor = descriptor(fromLayoutTag: tag, fallbackCount: fallbackCount) {
            return taggedDescriptor
        }

        return ChannelRoleLayoutDescriptor.unknown(
            channelCount: fallbackCount,
            sourceDescription: "unknown Core Audio layout tag \(tag)"
        )
    }

    private static func descriptor(
        fromLayoutTag tag: AudioChannelLayoutTag,
        fallbackCount: Int
    ) -> ChannelRoleLayoutDescriptor? {
        let roles: [SurroundChannelRole]
        let tagName: String
        switch tag {
        case kAudioChannelLayoutTag_Mono:
            roles = [.center]
            tagName = "Mono"
        case kAudioChannelLayoutTag_Stereo:
            roles = [.frontLeft, .frontRight]
            tagName = "Stereo"
        case kAudioChannelLayoutTag_MPEG_3_0_A:
            roles = [.frontLeft, .frontRight, .center]
            tagName = "MPEG 3.0 A"
        case kAudioChannelLayoutTag_MPEG_3_0_B:
            roles = [.center, .frontLeft, .frontRight]
            tagName = "MPEG 3.0 B"
        case kAudioChannelLayoutTag_MPEG_4_0_A:
            roles = [.frontLeft, .frontRight, .center, .rearCenter]
            tagName = "MPEG 4.0 A"
        case kAudioChannelLayoutTag_MPEG_4_0_B:
            roles = [.center, .frontLeft, .frontRight, .rearCenter]
            tagName = "MPEG 4.0 B"
        case kAudioChannelLayoutTag_MPEG_5_0_A:
            roles = [.frontLeft, .frontRight, .center, .sideLeft, .sideRight]
            tagName = "MPEG 5.0 A"
        case kAudioChannelLayoutTag_MPEG_5_0_B:
            roles = [.frontLeft, .frontRight, .sideLeft, .sideRight, .center]
            tagName = "MPEG 5.0 B"
        case kAudioChannelLayoutTag_MPEG_5_0_C:
            roles = [.frontLeft, .center, .frontRight, .sideLeft, .sideRight]
            tagName = "MPEG 5.0 C"
        case kAudioChannelLayoutTag_MPEG_5_0_D:
            roles = [.center, .frontLeft, .frontRight, .sideLeft, .sideRight]
            tagName = "MPEG 5.0 D"
        case kAudioChannelLayoutTag_MPEG_5_1_A:
            roles = [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight]
            tagName = "MPEG 5.1 A"
        case kAudioChannelLayoutTag_MPEG_5_1_B:
            roles = [.frontLeft, .frontRight, .sideLeft, .sideRight, .center, .lfe]
            tagName = "MPEG 5.1 B"
        case kAudioChannelLayoutTag_MPEG_5_1_C:
            return ChannelRoleLayoutDescriptor.mpegFiveOneC(
                confidence: .high,
                sourceDescription: "explicit Core Audio MPEG 5.1 C layout tag"
            )
        case kAudioChannelLayoutTag_MPEG_5_1_D:
            roles = [.center, .frontLeft, .frontRight, .sideLeft, .sideRight, .lfe]
            tagName = "MPEG 5.1 D"
        case kAudioChannelLayoutTag_MPEG_6_1_A:
            roles = [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight, .rearCenter]
            tagName = "MPEG 6.1 A"
        case kAudioChannelLayoutTag_MPEG_7_1_C:
            roles = [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight, .rearLeft, .rearRight]
            tagName = "MPEG 7.1 C"
        default:
            return nil
        }

        guard roles.count == fallbackCount else { return nil }
        let channels = roles.enumerated().map { index, role in
            SurroundChannel(index: index, role: role)
        }
        return ChannelRoleLayoutDescriptor.explicit(
            layoutName: layoutName(for: channels, fallbackCount: fallbackCount),
            roles: roles,
            source: .explicitCoreAudioLayoutTag(tagName),
            sourceDescription: "explicit Core Audio \(tagName) layout tag"
        )
    }

    private static func layoutName(for channels: [SurroundChannel], fallbackCount: Int) -> String {
        let roles = channels.map(\.role)

        if roles == [.frontLeft, .frontRight, .rearLeft, .rearRight] {
            return "Quadraphonic (4.0)"
        }
        if Set(roles) == Set([.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight]) {
            return "5.1 Surround"
        }
        if Set(roles) == Set([.frontLeft, .frontRight, .center, .lfe, .rearLeft, .rearRight, .sideLeft, .sideRight]) {
            return "7.1 Surround"
        }
        if roles == [.frontLeft, .frontRight, .center, .rearLeft, .rearRight, .sideLeft, .sideRight, .wideLeft, .wideRight, .lfe, .lfe2] {
            return "9.2 Surround"
        }

        let fallback = fallbackLayout(for: fallbackCount)
        if fallback.channelCount == channels.count && fallback.channels.map(\.role) == roles {
            return fallback.name
        }

        return "\(channels.count)-Channel Surround"
    }

    private static func role(for label: AudioChannelLabel, index: Int) -> SurroundChannelRole {
        switch label {
        case AudioChannelLabel(kAudioChannelLabel_Left):
            .frontLeft
        case AudioChannelLabel(kAudioChannelLabel_Right):
            .frontRight
        case AudioChannelLabel(kAudioChannelLabel_Center),
             AudioChannelLabel(kAudioChannelLabel_Mono):
            .center
        case AudioChannelLabel(kAudioChannelLabel_LFEScreen):
            .lfe
        case AudioChannelLabel(kAudioChannelLabel_LFE2),
             AudioChannelLabel(kAudioChannelLabel_LFE3):
            .lfe2
        case AudioChannelLabel(kAudioChannelLabel_LeftSurround),
             AudioChannelLabel(kAudioChannelLabel_LeftSurroundDirect),
             AudioChannelLabel(kAudioChannelLabel_LeftSideSurround):
            .sideLeft
        case AudioChannelLabel(kAudioChannelLabel_RightSurround),
             AudioChannelLabel(kAudioChannelLabel_RightSurroundDirect),
             AudioChannelLabel(kAudioChannelLabel_RightSideSurround):
            .sideRight
        case AudioChannelLabel(kAudioChannelLabel_RearSurroundLeft),
             AudioChannelLabel(kAudioChannelLabel_LeftBackSurround):
            .rearLeft
        case AudioChannelLabel(kAudioChannelLabel_RearSurroundRight),
             AudioChannelLabel(kAudioChannelLabel_RightBackSurround):
            .rearRight
        case AudioChannelLabel(kAudioChannelLabel_CenterSurround),
             AudioChannelLabel(kAudioChannelLabel_CenterSurroundDirect):
            .rearCenter
        case AudioChannelLabel(kAudioChannelLabel_LeftCenter):
            .frontLeftCenter
        case AudioChannelLabel(kAudioChannelLabel_RightCenter):
            .frontRightCenter
        case AudioChannelLabel(kAudioChannelLabel_LeftWide):
            .wideLeft
        case AudioChannelLabel(kAudioChannelLabel_RightWide):
            .wideRight
        case AudioChannelLabel(kAudioChannelLabel_LeftTopFront),
             AudioChannelLabel(kAudioChannelLabel_VerticalHeightLeft):
            .topFrontLeft
        case AudioChannelLabel(kAudioChannelLabel_CenterTopFront),
             AudioChannelLabel(kAudioChannelLabel_VerticalHeightCenter):
            .topFrontCenter
        case AudioChannelLabel(kAudioChannelLabel_RightTopFront),
             AudioChannelLabel(kAudioChannelLabel_VerticalHeightRight):
            .topFrontRight
        case AudioChannelLabel(kAudioChannelLabel_LeftTopMiddle):
            .topMiddleLeft
        case AudioChannelLabel(kAudioChannelLabel_CenterTopMiddle),
             AudioChannelLabel(kAudioChannelLabel_TopCenterSurround):
            .topMiddleCenter
        case AudioChannelLabel(kAudioChannelLabel_RightTopMiddle):
            .topMiddleRight
        case AudioChannelLabel(kAudioChannelLabel_LeftTopRear),
             AudioChannelLabel(kAudioChannelLabel_TopBackLeft),
             AudioChannelLabel(kAudioChannelLabel_LeftTopSurround):
            .topRearLeft
        case AudioChannelLabel(kAudioChannelLabel_CenterTopRear),
             AudioChannelLabel(kAudioChannelLabel_TopBackCenter):
            .topRearCenter
        case AudioChannelLabel(kAudioChannelLabel_RightTopRear),
             AudioChannelLabel(kAudioChannelLabel_TopBackRight),
             AudioChannelLabel(kAudioChannelLabel_RightTopSurround):
            .topRearRight
        default:
            .discrete(index)
        }
    }
}

struct AudioMetadataBuilder {
    static func build(
        for file: AVAudioFile,
        layout: SurroundLayout,
        duration: TimeInterval,
        sourceURL: URL? = nil,
        containerName: String? = nil,
        codecName: String? = nil,
        bitDepth: UInt32? = nil,
        tags: AudioSourceTags = .empty
    ) -> AudioSourceMetadata {
        let streamDescription = file.fileFormat.streamDescription.pointee
        let metadataURL = sourceURL ?? file.url
        let baseCodec = codecName ?? self.codecName(for: streamDescription.mFormatID)
        let compressedInfo = codecName == nil ? CompressedAudioProbe().probeIfAvailable(url: metadataURL) : nil
        let codec = Self.displayCodecName(baseCodec: baseCodec, streamInfo: compressedInfo, layout: layout)
        let formatNote = Self.formatNote(baseCodec: baseCodec, streamInfo: compressedInfo)
        let container = containerName ?? (metadataURL.pathExtension.isEmpty ? "Unknown" : metadataURL.pathExtension.uppercased())

        return AudioSourceMetadata(
            fileName: metadataURL.lastPathComponent,
            containerName: container,
            codecName: codec,
            layoutName: layout.name,
            channelSummary: layout.channelSummary,
            channelCount: layout.channelCount,
            sampleRate: file.fileFormat.sampleRate,
            bitDepth: bitDepth ?? streamDescription.mBitsPerChannel,
            duration: duration,
            title: tags.title?.trimmedNilIfBlank,
            album: tags.album?.trimmedNilIfBlank,
            artist: tags.artist?.trimmedNilIfBlank,
            formatNote: formatNote
        )
    }

    static func tags(for url: URL) -> AudioSourceTags {
        let metadata = AVURLAsset(url: url).commonMetadata
        return AudioSourceTags(
            title: metadataString(for: .commonKeyTitle, in: metadata),
            album: metadataString(for: .commonKeyAlbumName, in: metadata),
            artist: metadataString(for: .commonKeyArtist, in: metadata)
        )
    }

    private static func codecName(for formatID: AudioFormatID) -> String {
        switch formatID {
        case kAudioFormatLinearPCM:
            "PCM"
        case kAudioFormatAppleLossless:
            "Apple Lossless"
        case kAudioFormatFLAC:
            "FLAC"
        case kAudioFormatMPEG4AAC:
            "AAC"
        case kAudioFormatMPEGLayer3:
            "MP3"
        case kAudioFormatAC3:
            "AC-3"
        case kAudioFormatEnhancedAC3:
            "E-AC-3"
        default:
            fourCCString(from: formatID)
        }
    }

    private static func displayCodecName(
        baseCodec: String,
        streamInfo: CompressedAudioStreamInfo?,
        layout: SurroundLayout
    ) -> String {
        guard baseCodec == "E-AC-3" else { return baseCodec }
        guard streamInfo?.hasDolbyAtmos == true else { return baseCodec }
        return "\(baseCodec) \(layout.name.replacingOccurrences(of: " Surround", with: "")) bed"
    }

    private static func formatNote(baseCodec: String, streamInfo: CompressedAudioStreamInfo?) -> String? {
        guard baseCodec == "E-AC-3", streamInfo?.hasDolbyAtmos == true else { return nil }
        return "Dolby Atmos metadata present; Orbisonic is using the decoded channel bed, not object rendering."
    }

    private static func fourCCString(from formatID: AudioFormatID) -> String {
        let value = CFSwapInt32HostToBig(formatID)
        let scalar0 = UnicodeScalar((value >> 24) & 0xFF)
        let scalar1 = UnicodeScalar((value >> 16) & 0xFF)
        let scalar2 = UnicodeScalar((value >> 8) & 0xFF)
        let scalar3 = UnicodeScalar(value & 0xFF)

        let characters = [scalar0, scalar1, scalar2, scalar3].compactMap { $0 }.map(Character.init)
        let text = String(characters)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Format \(formatID)" : trimmed
    }

    private static func metadataString(for key: AVMetadataKey, in metadata: [AVMetadataItem]) -> String? {
        AVMetadataItem.metadataItems(from: metadata, withKey: key, keySpace: .common)
            .first?
            .stringValue?
            .trimmedNilIfBlank
    }
}
