public struct AudioSampleRate: Equatable, Hashable, Sendable, Comparable {
    public static let explicitToleranceHertz = 1.0

    public static let rate44100 = AudioSampleRate(uncheckedHertz: 44_100)
    public static let rate48000 = AudioSampleRate(uncheckedHertz: 48_000)
    public static let rate88200 = AudioSampleRate(uncheckedHertz: 88_200)
    public static let rate96000 = AudioSampleRate(uncheckedHertz: 96_000)
    public static let rate176400 = AudioSampleRate(uncheckedHertz: 176_400)
    public static let rate192000 = AudioSampleRate(uncheckedHertz: 192_000)
    public static let defaultProduction = AudioSampleRate.rate48000

    public let hertz: Double

    public init(hertz: Double) throws {
        guard hertz.isFinite, hertz > 0 else {
            throw AudioError.invalidRenderGraphPlan("Sample rate must be positive and finite.")
        }
        self.hertz = hertz
    }

    private init(uncheckedHertz hertz: Double) {
        self.hertz = hertz
    }

    public var isDanteThirtyOneChannelProductionEligible: Bool {
        Self.danteThirtyOneChannelProductionRates.contains { matches($0) }
    }

    public static var danteThirtyOneChannelProductionRates: [AudioSampleRate] {
        [.rate44100, .rate48000, .rate88200, .rate96000]
    }

    public func matches(
        _ other: AudioSampleRate,
        toleranceHertz: Double = AudioSampleRate.explicitToleranceHertz
    ) -> Bool {
        abs(hertz - other.hertz) <= toleranceHertz
    }

    public static func < (lhs: AudioSampleRate, rhs: AudioSampleRate) -> Bool {
        lhs.hertz < rhs.hertz
    }
}

public enum ProcessingFormat: String, CaseIterable, Equatable, Hashable, Sendable {
    case float32NonInterleavedPCM

    public var sampleFormat: String {
        "Float32"
    }

    public var isPCM: Bool {
        true
    }

    public var isInterleaved: Bool {
        false
    }

    public var isProductionInternalFormat: Bool {
        self == .float32NonInterleavedPCM
    }
}

public enum AudioChannelRole: Equatable, Hashable, Sendable {
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
    case frontLeftCenter
    case frontRightCenter
    case wideLeft
    case wideRight
    case topFrontLeft
    case topFrontRight
    case topFrontCenter
    case topMiddleLeft
    case topMiddleRight
    case topMiddleCenter
    case topRearLeft
    case topRearRight
    case topRearCenter
    case discrete(index: Int)
    case unknown(index: Int)

    public var shortLabel: String {
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
        case .frontLeftCenter: "FLC"
        case .frontRightCenter: "FRC"
        case .wideLeft: "WL"
        case .wideRight: "WR"
        case .topFrontLeft: "TFL"
        case .topFrontRight: "TFR"
        case .topFrontCenter: "TFC"
        case .topMiddleLeft: "TML"
        case .topMiddleRight: "TMR"
        case .topMiddleCenter: "TMC"
        case .topRearLeft: "TRL"
        case .topRearRight: "TRR"
        case .topRearCenter: "TRC"
        case .discrete(let index): "CH\(index + 1)"
        case .unknown(let index): "UNK\(index + 1)"
        }
    }

    public var displayName: String {
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
        case .frontLeftCenter: "Front Left Center"
        case .frontRightCenter: "Front Right Center"
        case .wideLeft: "Wide Left"
        case .wideRight: "Wide Right"
        case .topFrontLeft: "Top Front Left"
        case .topFrontRight: "Top Front Right"
        case .topFrontCenter: "Top Front Center"
        case .topMiddleLeft: "Top Middle Left"
        case .topMiddleRight: "Top Middle Right"
        case .topMiddleCenter: "Top Middle Center"
        case .topRearLeft: "Top Rear Left"
        case .topRearRight: "Top Rear Right"
        case .topRearCenter: "Top Rear Center"
        case .discrete(let index): "Discrete \(index + 1)"
        case .unknown(let index): "Unknown \(index + 1)"
        }
    }

    public var indexValue: Int? {
        switch self {
        case .discrete(let index), .unknown(let index):
            index
        default:
            nil
        }
    }
}

public struct AudioChannelLayoutDescriptor: Equatable, Hashable, Sendable {
    public let name: String
    public let roles: [AudioChannelRole]

    public var channelCount: Int {
        roles.count
    }

    public var roleSummary: String {
        roles.map(\.shortLabel).joined(separator: ", ")
    }

    public init(name: String, roles: [AudioChannelRole]) {
        self.name = name
        self.roles = roles
    }

    public static let mono = AudioChannelLayoutDescriptor(name: "Mono", roles: [.center])
    public static let stereo = AudioChannelLayoutDescriptor(name: "Stereo", roles: [.frontLeft, .frontRight])
    public static let quad = AudioChannelLayoutDescriptor(
        name: "Quadraphonic (4.0)",
        roles: [.frontLeft, .frontRight, .rearLeft, .rearRight]
    )
    public static let surround51 = AudioChannelLayoutDescriptor(
        name: "5.1 Surround",
        roles: [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight]
    )
    public static let surround71 = AudioChannelLayoutDescriptor(
        name: "7.1 Surround",
        roles: [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight, .rearLeft, .rearRight]
    )
    public static let surround714 = AudioChannelLayoutDescriptor(
        name: "7.1.4",
        roles: [
            .frontLeft, .frontRight, .center, .lfe,
            .sideLeft, .sideRight, .rearLeft, .rearRight,
            .topFrontLeft, .topFrontRight, .topRearLeft, .topRearRight
        ]
    )
    public static let surround916 = AudioChannelLayoutDescriptor(
        name: "9.1.6",
        roles: [
            .frontLeft, .frontRight, .center, .lfe,
            .sideLeft, .sideRight, .rearLeft, .rearRight,
            .wideLeft, .wideRight,
            .topFrontLeft, .topFrontRight, .topMiddleLeft, .topMiddleRight, .topRearLeft, .topRearRight
        ]
    )
    public static let direct30 = AudioChannelLayoutDescriptor(
        name: "Direct 30",
        roles: (0..<30).map { .discrete(index: $0) }
    )
    public static let direct31 = AudioChannelLayoutDescriptor(
        name: "Direct 30.1",
        roles: (0..<30).map { .discrete(index: $0) } + [.lfe]
    )

    public static func discrete(count: Int) -> AudioChannelLayoutDescriptor {
        AudioChannelLayoutDescriptor(
            name: "\(count)-Channel Discrete",
            roles: (0..<max(count, 0)).map { .discrete(index: $0) }
        )
    }

    public static func fallbackLayout(channelCount: Int) -> AudioChannelLayoutDescriptor {
        switch channelCount {
        case 1:
            .mono
        case 2:
            .stereo
        case 4:
            .quad
        case 6:
            .surround51
        case 8:
            .surround71
        case 12:
            .surround714
        case 16:
            .surround916
        case 30:
            .direct30
        case 31:
            .direct31
        default:
            .discrete(count: channelCount)
        }
    }

    public func validationErrors(expectedChannelCount: Int? = nil) -> [AudioError] {
        var errors: [AudioError] = []
        if let expectedChannelCount, expectedChannelCount != channelCount {
            errors.append(.layoutChannelCountMismatch(expected: expectedChannelCount, actual: channelCount))
        }
        for role in roles {
            if let index = role.indexValue, index < 0 {
                errors.append(.invalidRenderGraphPlan("Channel role index must be non-negative."))
            }
        }
        return errors
    }
}

public enum SourceKind: String, CaseIterable, Equatable, Hashable, Sendable {
    case off
    case roon
    case spotify
    case aux
    case localFile
    case testTone

    public var defaultIsLive: Bool {
        switch self {
        case .roon, .spotify, .aux:
            true
        case .off, .localFile, .testTone:
            false
        }
    }
}

public struct SourceDescriptor: Equatable, Hashable, Sendable {
    public static let sourceChannelLimit = 1...64

    public let id: String
    public let kind: SourceKind
    public let sampleRate: AudioSampleRate
    public let channelCount: Int
    public let layout: AudioChannelLayoutDescriptor
    public let durationFrames: Int64?
    public let isLive: Bool
    public let codecDescription: String?
    public let originalPath: String?

    public init(
        id: String,
        kind: SourceKind,
        sampleRate: AudioSampleRate,
        channelCount: Int,
        layout: AudioChannelLayoutDescriptor,
        durationFrames: Int64? = nil,
        isLive: Bool? = nil,
        codecDescription: String? = nil,
        originalPath: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.layout = layout
        self.durationFrames = durationFrames
        self.isLive = isLive ?? kind.defaultIsLive
        self.codecDescription = codecDescription
        self.originalPath = originalPath
    }

    public func validationErrors(sessionFormat: AudioSessionFormat) -> [AudioError] {
        var errors: [AudioError] = []
        if !Self.sourceChannelLimit.contains(channelCount) {
            errors.append(.sourceChannelCountOutOfRange(count: channelCount, minimum: 1, maximum: 64))
        }
        if channelCount > sessionFormat.sourceChannelLimit {
            errors.append(.sourceChannelCountOutOfRange(count: channelCount, minimum: 1, maximum: sessionFormat.sourceChannelLimit))
        }
        if !sampleRate.matches(sessionFormat.sampleRate) {
            errors.append(.sampleRateMismatch(expected: sessionFormat.sampleRate, actual: sampleRate, context: "source"))
        }
        errors.append(contentsOf: layout.validationErrors(expectedChannelCount: channelCount))
        if let durationFrames, durationFrames < 0 {
            errors.append(.invalidRenderGraphPlan("Source duration frames must not be negative."))
        }
        return errors
    }

    public func validate(sessionFormat: AudioSessionFormat) throws {
        if let error = validationErrors(sessionFormat: sessionFormat).first {
            throw error
        }
    }
}

public struct DanteOutputFormat: Equatable, Hashable, Sendable {
    public let logicalChannelCount: Int
    public let physicalChannelCount: Int
    public let sampleRate: AudioSampleRate
    public let channelMap: AudioChannelLayoutDescriptor

    public var isChannel32Reserved: Bool {
        physicalChannelCount == 32
    }

    public init(
        logicalChannelCount: Int = 31,
        physicalChannelCount: Int,
        sampleRate: AudioSampleRate,
        channelMap: AudioChannelLayoutDescriptor = .direct31
    ) {
        self.logicalChannelCount = logicalChannelCount
        self.physicalChannelCount = physicalChannelCount
        self.sampleRate = sampleRate
        self.channelMap = channelMap
    }

    public func validationErrors(sessionSampleRate: AudioSampleRate) -> [AudioError] {
        var errors: [AudioError] = []
        if logicalChannelCount != 31 {
            errors.append(.invalidRenderGraphPlan("Dante logical channel count must be 31."))
        }
        if physicalChannelCount < 31 {
            errors.append(.danteRouteInsufficientChannels(required: 31, actual: physicalChannelCount))
        } else if physicalChannelCount > 32 {
            errors.append(.invalidRenderGraphPlan("Dante physical channel count must be 31 or 32."))
        }
        if !sampleRate.matches(sessionSampleRate) {
            errors.append(.sampleRateMismatch(expected: sessionSampleRate, actual: sampleRate, context: "Dante output"))
        }
        if !sampleRate.isDanteThirtyOneChannelProductionEligible {
            errors.append(.danteUnsupportedSampleRate(sampleRate))
        }
        errors.append(contentsOf: channelMap.validationErrors(expectedChannelCount: logicalChannelCount))
        return errors
    }
}

public struct DesktopOutputFormat: Equatable, Hashable, Sendable {
    public let channelCount: Int
    public let sampleRate: AudioSampleRate
    public let role: String

    public init(
        channelCount: Int = 2,
        sampleRate: AudioSampleRate,
        role: String = "stereoMonitor"
    ) {
        self.channelCount = channelCount
        self.sampleRate = sampleRate
        self.role = role
    }

    public func validationErrors(sessionSampleRate: AudioSampleRate) -> [AudioError] {
        var errors: [AudioError] = []
        if channelCount != 2 {
            errors.append(.desktopRouteInsufficientChannels(required: 2, actual: channelCount))
        }
        if !sampleRate.matches(sessionSampleRate) {
            errors.append(.sampleRateMismatch(expected: sessionSampleRate, actual: sampleRate, context: "desktop output"))
        }
        return errors
    }
}

public struct AudioSessionFormat: Equatable, Hashable, Sendable {
    public static let maximumSourceChannelLimit = 64
    public static let maximumReasonableFramesPerBlock = 16_384

    public let sampleRate: AudioSampleRate
    public let maxFramesPerBlock: Int
    public let processingFormat: ProcessingFormat
    public let sourceChannelLimit: Int
    public let dante: DanteOutputFormat
    public let desktop: DesktopOutputFormat

    public init(
        sampleRate: AudioSampleRate,
        maxFramesPerBlock: Int,
        processingFormat: ProcessingFormat = .float32NonInterleavedPCM,
        sourceChannelLimit: Int = AudioSessionFormat.maximumSourceChannelLimit,
        dante: DanteOutputFormat,
        desktop: DesktopOutputFormat
    ) {
        self.sampleRate = sampleRate
        self.maxFramesPerBlock = maxFramesPerBlock
        self.processingFormat = processingFormat
        self.sourceChannelLimit = sourceChannelLimit
        self.dante = dante
        self.desktop = desktop
    }

    public func validationErrors() -> [AudioError] {
        var errors: [AudioError] = []
        if !processingFormat.isProductionInternalFormat {
            errors.append(.invalidRenderGraphPlan("Processing format must be Float32 non-interleaved PCM."))
        }
        if sourceChannelLimit < 1 || sourceChannelLimit > Self.maximumSourceChannelLimit {
            errors.append(.sourceChannelCountOutOfRange(count: sourceChannelLimit, minimum: 1, maximum: Self.maximumSourceChannelLimit))
        }
        if maxFramesPerBlock <= 0 || maxFramesPerBlock > Self.maximumReasonableFramesPerBlock {
            errors.append(.invalidRenderGraphPlan("maxFramesPerBlock must be positive and no greater than \(Self.maximumReasonableFramesPerBlock)."))
        }
        errors.append(contentsOf: desktop.validationErrors(sessionSampleRate: sampleRate))
        errors.append(contentsOf: dante.validationErrors(sessionSampleRate: sampleRate))
        return errors
    }

    public func validate() throws {
        if let error = validationErrors().first {
            throw error
        }
    }
}

public enum OutputRouteRisk: String, CaseIterable, Equatable, Hashable, Sendable {
    case safe
    case preferredDante
    case feedbackLoopRisk
    case virtualOutputRisk
    case unavailable
    case unknown
}

public struct OutputRouteDescriptor: Equatable, Hashable, Sendable {
    public let id: String
    public let uid: String?
    public let name: String
    public let manufacturer: String?
    public let transportName: String?
    public let inputChannelCount: Int
    public let outputChannelCount: Int
    public let nominalSampleRate: AudioSampleRate?
    public let isAvailable: Bool
    public let risk: OutputRouteRisk

    public init(
        id: String,
        uid: String? = nil,
        name: String,
        manufacturer: String? = nil,
        transportName: String? = nil,
        inputChannelCount: Int = 0,
        outputChannelCount: Int = 0,
        nominalSampleRate: AudioSampleRate? = nil,
        isAvailable: Bool,
        risk: OutputRouteRisk = .unknown
    ) {
        self.id = id
        self.uid = uid
        self.name = name
        self.manufacturer = manufacturer
        self.transportName = transportName
        self.inputChannelCount = inputChannelCount
        self.outputChannelCount = outputChannelCount
        self.nominalSampleRate = nominalSampleRate
        self.isAvailable = isAvailable
        self.risk = risk
    }
}

public struct DanteRouteCapability: Equatable, Hashable, Sendable {
    public let route: OutputRouteDescriptor
    public let supportedSampleRates: [AudioSampleRate]?
    public let currentNominalSampleRate: AudioSampleRate?
    public let outputChannelCount: Int
    public let validationMessages: [String]

    public init(
        route: OutputRouteDescriptor,
        supportedSampleRates: [AudioSampleRate]? = nil,
        currentNominalSampleRate: AudioSampleRate? = nil,
        outputChannelCount: Int? = nil,
        validationMessages: [String] = []
    ) {
        self.route = route
        self.supportedSampleRates = supportedSampleRates
        self.currentNominalSampleRate = currentNominalSampleRate ?? route.nominalSampleRate
        self.outputChannelCount = outputChannelCount ?? route.outputChannelCount
        self.validationMessages = validationMessages
    }

    public func supportsThirtyOneChannelProduction(at sampleRate: AudioSampleRate) -> Bool {
        validationErrors(for: sampleRate).isEmpty
    }

    public func validationErrors(for sampleRate: AudioSampleRate) -> [AudioError] {
        var errors: [AudioError] = []
        guard route.isAvailable else {
            return [.routeUnavailable(route.id)]
        }
        if outputChannelCount < 31 {
            errors.append(.danteRouteInsufficientChannels(required: 31, actual: outputChannelCount))
        }
        if !sampleRate.isDanteThirtyOneChannelProductionEligible {
            errors.append(.danteUnsupportedSampleRate(sampleRate))
        }
        if appearsToBeDanteVirtualSoundcard,
           sampleRate.matches(.rate176400) || sampleRate.matches(.rate192000) {
            errors.append(.danteUnsupportedSampleRate(sampleRate))
        }

        if let supportedSampleRates {
            if !supportedSampleRates.contains(where: { $0.matches(sampleRate) }) {
                errors.append(.sampleRateMismatch(expected: sampleRate, actual: currentNominalSampleRate ?? sampleRate, context: "Dante supported sample rates"))
            }
        } else if let currentNominalSampleRate {
            if !currentNominalSampleRate.matches(sampleRate) {
                errors.append(.sampleRateMismatch(expected: sampleRate, actual: currentNominalSampleRate, context: "Dante nominal sample rate"))
            }
        } else {
            errors.append(.invalidRenderGraphPlan("Dante sample-rate support is unknown."))
        }

        return errors
    }

    public func validationMessages(for sampleRate: AudioSampleRate) -> [String] {
        validationMessages + validationErrors(for: sampleRate).map(\.description)
    }

    private var appearsToBeDanteVirtualSoundcard: Bool {
        let text = [
            route.name,
            route.manufacturer ?? "",
            route.transportName ?? "",
            route.uid ?? ""
        ].joined(separator: " ").lowercased()
        return text.contains("dante virtual soundcard")
            || (text.contains("dante") && text.contains("audinate"))
    }
}

public enum RenderMode: String, CaseIterable, Equatable, Hashable, Sendable {
    case automatic
    case mono
    case stereo
    case quad
    case surround51
    case auro80 = "auro_8_0"
    case auro91 = "auro_9_1"
    case auro101 = "auro_10_1"
    case auro111714h = "auro_11_1_7_1_4h"
    case auro111515hT = "auro_11_1_5_1_5h_t"
    case auro121 = "auro_12_1"
    case auro131 = "auro_13_1"
    case direct30
    case direct31

    public var expectedInputCount: Int? {
        switch self {
        case .automatic:
            nil
        case .mono:
            1
        case .stereo:
            2
        case .quad:
            4
        case .surround51:
            6
        case .auro80:
            8
        case .auro91:
            10
        case .auro101:
            11
        case .auro111714h, .auro111515hT:
            12
        case .auro121:
            13
        case .auro131:
            14
        case .direct30:
            30
        case .direct31:
            31
        }
    }
}

public enum DesktopMonitorMode: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case referenceStereo
    case appleSpatialHeadphones

    public var displayName: String {
        switch self {
        case .referenceStereo:
            "Reference Stereo Monitor"
        case .appleSpatialHeadphones:
            "Apple Spatial Headphones"
        }
    }
}

public enum AppleSpatialHeadphoneOutputTypePolicy: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case headphonesOrAuto
    case headphonesOnly
    case auto
}

public enum AppleSpatialHeadphoneRoomProfile: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case none
    case smallStudio
}

public enum AppleSpatialHeadphoneLFEPolicy: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case omitReferenceLFE
}

public enum AppleSpatialHeadphoneSourceLayoutPolicy: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case useSourceLayoutFallbacks
}

public struct AppleSpatialHeadphoneOptions: Codable, Equatable, Hashable, Sendable {
    public let isEnabled: Bool
    public let preferHRTFHQ: Bool
    public let enableHeadTrackingWhenAvailable: Bool
    public let outputTypePolicy: AppleSpatialHeadphoneOutputTypePolicy
    public let roomProfile: AppleSpatialHeadphoneRoomProfile
    public let lfePolicy: AppleSpatialHeadphoneLFEPolicy
    public let sourceLayoutPolicy: AppleSpatialHeadphoneSourceLayoutPolicy
    public let requiresHeadphones: Bool

    public static let disabled = AppleSpatialHeadphoneOptions()
    public static let enabledDefault = AppleSpatialHeadphoneOptions(isEnabled: true)

    public init(
        isEnabled: Bool = false,
        preferHRTFHQ: Bool = true,
        enableHeadTrackingWhenAvailable: Bool = true,
        outputTypePolicy: AppleSpatialHeadphoneOutputTypePolicy = .headphonesOrAuto,
        roomProfile: AppleSpatialHeadphoneRoomProfile = .none,
        lfePolicy: AppleSpatialHeadphoneLFEPolicy = .omitReferenceLFE,
        sourceLayoutPolicy: AppleSpatialHeadphoneSourceLayoutPolicy = .useSourceLayoutFallbacks,
        requiresHeadphones: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.preferHRTFHQ = preferHRTFHQ
        self.enableHeadTrackingWhenAvailable = enableHeadTrackingWhenAvailable
        self.outputTypePolicy = outputTypePolicy
        self.roomProfile = roomProfile
        self.lfePolicy = lfePolicy
        self.sourceLayoutPolicy = sourceLayoutPolicy
        self.requiresHeadphones = requiresHeadphones
    }
}

public enum AppleSpatialHeadTrackingStatus: Equatable, Hashable, Sendable {
    case notRequested
    case enabled
    case unavailable(reason: String)

    public var displayText: String {
        switch self {
        case .notRequested:
            "Head tracking not requested."
        case .enabled:
            "Head tracking enabled."
        case .unavailable(let reason):
            "Head tracking unavailable: \(reason)"
        }
    }
}

public enum AppleSpatialHeadphoneCapability: Equatable, Hashable, Sendable {
    case supported
    case supportedWithoutHeadTracking(reason: String)
    case unsupportedRoute(reason: String)
    case unsupportedSDK(reason: String)
    case unsupportedBecauseDanteRoute
    case unsupportedBecauseBuiltInSpeakers
    case unsupportedBecauseNoDesktopRoute
    case unsupportedBecauseSessionSampleRateMismatch
    case validationOnly

    public var isUsable: Bool {
        switch self {
        case .supported, .supportedWithoutHeadTracking:
            true
        case .unsupportedRoute, .unsupportedSDK, .unsupportedBecauseDanteRoute,
             .unsupportedBecauseBuiltInSpeakers, .unsupportedBecauseNoDesktopRoute,
             .unsupportedBecauseSessionSampleRateMismatch, .validationOnly:
            false
        }
    }

    public var userVisibleMessage: String {
        switch self {
        case .supported:
            "Apple Spatial Headphones is available for this desktop route."
        case .supportedWithoutHeadTracking(let reason):
            "Apple Spatial Headphones is available. \(reason)"
        case .unsupportedRoute(let reason):
            reason
        case .unsupportedSDK(let reason):
            reason
        case .unsupportedBecauseDanteRoute:
            "Unavailable for Dante output."
        case .unsupportedBecauseBuiltInSpeakers:
            "Unavailable on built-in speakers."
        case .unsupportedBecauseNoDesktopRoute:
            "Requires a headphone desktop monitor route."
        case .unsupportedBecauseSessionSampleRateMismatch:
            "Session sample rate must match the desktop monitor route."
        case .validationOnly:
            "Apple Spatial Headphones is disabled in this build."
        }
    }
}

public struct DesktopMonitorModeStatus: Equatable, Hashable, Sendable {
    public let mode: DesktopMonitorMode
    public let isActive: Bool
    public let isPendingRestart: Bool
    public let capability: AppleSpatialHeadphoneCapability
    public let userVisibleMessage: String
    public let headTrackingStatus: AppleSpatialHeadTrackingStatus
    public let effectiveOutputRouteName: String?
    public let sessionSampleRate: AudioSampleRate?
    public let lastError: String?

    public init(
        mode: DesktopMonitorMode,
        isActive: Bool,
        isPendingRestart: Bool,
        capability: AppleSpatialHeadphoneCapability,
        userVisibleMessage: String,
        headTrackingStatus: AppleSpatialHeadTrackingStatus = .notRequested,
        effectiveOutputRouteName: String? = nil,
        sessionSampleRate: AudioSampleRate? = nil,
        lastError: String? = nil
    ) {
        self.mode = mode
        self.isActive = isActive
        self.isPendingRestart = isPendingRestart
        self.capability = capability
        self.userVisibleMessage = userVisibleMessage
        self.headTrackingStatus = headTrackingStatus
        self.effectiveOutputRouteName = effectiveOutputRouteName
        self.sessionSampleRate = sessionSampleRate
        self.lastError = lastError
    }

    public static func referenceStereo(
        routeName: String? = nil,
        sessionSampleRate: AudioSampleRate? = nil
    ) -> DesktopMonitorModeStatus {
        DesktopMonitorModeStatus(
            mode: .referenceStereo,
            isActive: true,
            isPendingRestart: false,
            capability: .validationOnly,
            userVisibleMessage: routeName.map { "Reference Stereo Monitor active on \($0)." }
                ?? "Reference Stereo Monitor active.",
            effectiveOutputRouteName: routeName,
            sessionSampleRate: sessionSampleRate
        )
    }
}

public struct ChannelMeter: Equatable, Hashable, Sendable {
    public let rmsDBFS: Float
    public let peakDBFS: Float
    public let vuDB: Float
    public let normalizedLevel: Float
    public let isClipped: Bool

    public init(
        rmsDBFS: Float,
        peakDBFS: Float,
        vuDB: Float,
        normalizedLevel: Float,
        isClipped: Bool? = nil
    ) {
        self.rmsDBFS = rmsDBFS
        self.peakDBFS = peakDBFS
        self.vuDB = vuDB
        self.normalizedLevel = min(max(normalizedLevel, 0), 1)
        self.isClipped = isClipped ?? (peakDBFS >= 0)
    }
}

public struct MeterSnapshot: Equatable, Hashable, Sendable {
    public let sessionVersion: UInt64
    public let sourceID: String?
    public let framePosition: Int64
    public let inputMeters: [ChannelMeter]
    public let desktopMeters: [ChannelMeter]
    public let danteMeters: [ChannelMeter]
    public let timestampNanoseconds: UInt64?

    public init(
        sessionVersion: UInt64,
        sourceID: String? = nil,
        framePosition: Int64,
        inputMeters: [ChannelMeter],
        desktopMeters: [ChannelMeter],
        danteMeters: [ChannelMeter],
        timestampNanoseconds: UInt64? = nil
    ) {
        self.sessionVersion = sessionVersion
        self.sourceID = sourceID
        self.framePosition = framePosition
        self.inputMeters = inputMeters
        self.desktopMeters = desktopMeters
        self.danteMeters = danteMeters
        self.timestampNanoseconds = timestampNanoseconds
    }
}

public enum AllowedAudioConversion: String, CaseIterable, Equatable, Hashable, Sendable {
    case codecDecodeToPCM
    case integerPCMToFloat32
    case interleavedToDeinterleaved
    case layoutMetadataNormalization
    case offlineManagedSampleRateConversion
}

public enum ForbiddenAudioConversion: String, CaseIterable, Equatable, Hashable, Sendable {
    case productionSampleRateConversion
    case realtimeFileIO
    case unknownGraphConversion
}

public enum ConversionLedgerValidationStatus: Equatable, Hashable, Sendable {
    case valid
    case invalid([AudioError])
}

public struct ConversionLedger: Equatable, Hashable, Sendable {
    public let sessionSampleRate: AudioSampleRate
    public let sourceOriginalDescription: String
    public let sourceCanonicalDescription: String
    public let allowedConversions: [AllowedAudioConversion]
    public let forbiddenConversionsObserved: [ForbiddenAudioConversion]
    public let desktopOutputDescription: String
    public let danteOutputDescription: String

    public var containsProductionSampleRateConversion: Bool {
        forbiddenConversionsObserved.contains(.productionSampleRateConversion)
    }

    public var validationStatus: ConversionLedgerValidationStatus {
        containsProductionSampleRateConversion
            ? .invalid([.productionSampleRateConversionForbidden])
            : .valid
    }

    public init(
        sessionSampleRate: AudioSampleRate,
        sourceOriginalDescription: String,
        sourceCanonicalDescription: String,
        allowedConversions: [AllowedAudioConversion],
        forbiddenConversionsObserved: [ForbiddenAudioConversion],
        desktopOutputDescription: String,
        danteOutputDescription: String
    ) {
        self.sessionSampleRate = sessionSampleRate
        self.sourceOriginalDescription = sourceOriginalDescription
        self.sourceCanonicalDescription = sourceCanonicalDescription
        self.allowedConversions = allowedConversions
        self.forbiddenConversionsObserved = forbiddenConversionsObserved
        self.desktopOutputDescription = desktopOutputDescription
        self.danteOutputDescription = danteOutputDescription
    }
}

public struct ManagedAssetDescriptor: Equatable, Hashable, Sendable {
    public let id: String
    public let originalPath: String
    public let managedPath: String
    public let originalSampleRate: AudioSampleRate
    public let managedSampleRate: AudioSampleRate
    public let channelCount: Int
    public let layout: AudioChannelLayoutDescriptor
    public let codecDescription: String?
    public let containerDescription: String?
    public let durationFrames: Int64?
    public let conversionLedger: ConversionLedger
    public let createdAtUnixTimeSeconds: Double?

    public var sampleRate: AudioSampleRate {
        managedSampleRate
    }

    public init(
        id: String,
        originalPath: String,
        managedPath: String,
        originalSampleRate: AudioSampleRate,
        managedSampleRate: AudioSampleRate,
        channelCount: Int,
        layout: AudioChannelLayoutDescriptor,
        codecDescription: String? = nil,
        containerDescription: String? = nil,
        durationFrames: Int64? = nil,
        conversionLedger: ConversionLedger,
        createdAtUnixTimeSeconds: Double? = nil
    ) {
        self.id = id
        self.originalPath = originalPath
        self.managedPath = managedPath
        self.originalSampleRate = originalSampleRate
        self.managedSampleRate = managedSampleRate
        self.channelCount = channelCount
        self.layout = layout
        self.codecDescription = codecDescription
        self.containerDescription = containerDescription
        self.durationFrames = durationFrames
        self.conversionLedger = conversionLedger
        self.createdAtUnixTimeSeconds = createdAtUnixTimeSeconds
    }
}

public enum AssetReadiness: Equatable, Hashable, Sendable {
    case productionReady
    case requiresOfflineImport(reason: String, targetSampleRate: AudioSampleRate)
    case canRestartStoppedSessionAtFileRate(reason: String, fileSampleRate: AudioSampleRate)
    case unsupported(reason: String)
    case desktopPreviewOnly(reason: String)

    public var reason: String? {
        switch self {
        case .productionReady:
            nil
        case .requiresOfflineImport(let reason, _):
            reason
        case .canRestartStoppedSessionAtFileRate(let reason, _):
            reason
        case .unsupported(let reason):
            reason
        case .desktopPreviewOnly(let reason):
            reason
        }
    }
}

public enum AudioError: Error, Equatable, Hashable, Sendable, CustomStringConvertible {
    case sampleRateMismatch(expected: AudioSampleRate, actual: AudioSampleRate, context: String)
    case sourceChannelCountOutOfRange(count: Int, minimum: Int, maximum: Int)
    case layoutChannelCountMismatch(expected: Int, actual: Int)
    case danteRouteInsufficientChannels(required: Int, actual: Int)
    case danteUnsupportedSampleRate(AudioSampleRate)
    case desktopRouteInsufficientChannels(required: Int, actual: Int)
    case routeUnavailable(String)
    case productionSampleRateConversionForbidden
    case localAssetRequiresManagedImport(sourceID: String)
    case graphMutationRequiresStoppedSession
    case forbiddenAudioDependency(String)
    case invalidRenderGraphPlan(String)

    public var description: String {
        switch self {
        case .sampleRateMismatch(let expected, let actual, let context):
            "\(context) sample rate mismatch: expected \(expected.hertz) Hz, got \(actual.hertz) Hz."
        case .sourceChannelCountOutOfRange(let count, let minimum, let maximum):
            "Source channel count \(count) is outside \(minimum)...\(maximum)."
        case .layoutChannelCountMismatch(let expected, let actual):
            "Layout channel count mismatch: expected \(expected), got \(actual)."
        case .danteRouteInsufficientChannels(let required, let actual):
            "Dante route exposes \(actual) channels; \(required) are required."
        case .danteUnsupportedSampleRate(let sampleRate):
            "Dante 31-channel production does not support \(sampleRate.hertz) Hz."
        case .desktopRouteInsufficientChannels(let required, let actual):
            "Desktop route exposes \(actual) channels; \(required) are required."
        case .routeUnavailable(let routeID):
            "Route is unavailable: \(routeID)."
        case .productionSampleRateConversionForbidden:
            "Production sample-rate conversion is forbidden."
        case .localAssetRequiresManagedImport(let sourceID):
            "Local asset requires managed import before production playback: \(sourceID)."
        case .graphMutationRequiresStoppedSession:
            "Graph mutation requires a stopped session."
        case .forbiddenAudioDependency(let dependency):
            "Forbidden audio dependency: \(dependency)."
        case .invalidRenderGraphPlan(let message):
            "Invalid render graph plan: \(message)"
        }
    }
}
