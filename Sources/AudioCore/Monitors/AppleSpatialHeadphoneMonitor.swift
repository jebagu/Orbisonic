import AudioContracts
import AVFAudio
import Foundation

public struct AppleSpatialSpeakerPosition: Equatable, Hashable, Sendable {
    public let role: AudioChannelRole
    public let x: Float
    public let y: Float
    public let z: Float
    public let isOmitted: Bool
    public let message: String?

    public init(
        role: AudioChannelRole,
        x: Float,
        y: Float,
        z: Float,
        isOmitted: Bool = false,
        message: String? = nil
    ) {
        self.role = role
        self.x = x
        self.y = y
        self.z = z
        self.isOmitted = isOmitted
        self.message = message
    }
}

public enum AppleSpatialSpeakerPositionMap {
    public static func positions(
        for layout: AudioChannelLayoutDescriptor,
        options: AppleSpatialHeadphoneOptions = .enabledDefault
    ) -> [AppleSpatialSpeakerPosition] {
        layout.roles.enumerated().map { index, role in
            position(for: role, index: index, count: layout.channelCount, options: options)
        }
    }

    public static func position(
        for role: AudioChannelRole,
        index: Int,
        count: Int,
        options: AppleSpatialHeadphoneOptions = .enabledDefault
    ) -> AppleSpatialSpeakerPosition {
        switch role {
        case .frontLeft:
            point(role, -0.5, 0, -0.866)
        case .frontRight:
            point(role, 0.5, 0, -0.866)
        case .center:
            point(role, 0, 0, -1)
        case .lfe, .lfe2:
            lfePosition(role: role, options: options)
        case .sideLeft:
            point(role, -1, 0, 0)
        case .sideRight:
            point(role, 1, 0, 0)
        case .rearLeft:
            point(role, -0.707, 0, 0.707)
        case .rearRight:
            point(role, 0.707, 0, 0.707)
        case .rearCenter:
            point(role, 0, 0, 1)
        case .frontLeftCenter:
            point(role, -0.25, 0, -0.966)
        case .frontRightCenter:
            point(role, 0.25, 0, -0.966)
        case .wideLeft:
            point(role, -0.866, 0, -0.5)
        case .wideRight:
            point(role, 0.866, 0, -0.5)
        case .topFrontLeft:
            point(role, -0.5, 0.65, -0.866)
        case .topFrontRight:
            point(role, 0.5, 0.65, -0.866)
        case .topFrontCenter:
            point(role, 0, 0.65, -1)
        case .topMiddleLeft:
            point(role, -1, 0.75, 0)
        case .topMiddleRight:
            point(role, 1, 0.75, 0)
        case .topMiddleCenter:
            point(role, 0, 1, 0)
        case .topRearLeft:
            point(role, -0.707, 0.65, 0.707)
        case .topRearRight:
            point(role, 0.707, 0.65, 0.707)
        case .topRearCenter:
            point(role, 0, 0.65, 1)
        case .discrete, .unknown:
            fallbackRingPosition(role: role, index: index, count: count)
        }
    }

    private static func lfePosition(
        role: AudioChannelRole,
        options: AppleSpatialHeadphoneOptions
    ) -> AppleSpatialSpeakerPosition {
        switch options.lfePolicy {
        case .omitReferenceLFE:
            AppleSpatialSpeakerPosition(
                role: role,
                x: 0,
                y: 0,
                z: 0,
                isOmitted: true,
                message: "LFE is omitted from the reference Apple Spatial Headphones monitor."
            )
        }
    }

    private static func fallbackRingPosition(
        role: AudioChannelRole,
        index: Int,
        count: Int
    ) -> AppleSpatialSpeakerPosition {
        let safeCount = max(count, 1)
        let angle = (Double(index) / Double(safeCount)) * Double.pi * 2.0
        return AppleSpatialSpeakerPosition(
            role: role,
            x: Float(sin(angle)),
            y: 0,
            z: Float(-cos(angle)),
            message: "Discrete or unknown channel placed on deterministic monitor ring."
        )
    }

    private static func point(
        _ role: AudioChannelRole,
        _ x: Float,
        _ y: Float,
        _ z: Float
    ) -> AppleSpatialSpeakerPosition {
        AppleSpatialSpeakerPosition(role: role, x: x, y: y, z: z)
    }
}

public struct AppleSpatialRouteClassifier: Sendable {
    public init() {}

    public func capability(
        route: OutputRouteDescriptor?,
        sessionSampleRate: AudioSampleRate?,
        options: AppleSpatialHeadphoneOptions
    ) -> AppleSpatialHeadphoneCapability {
        guard let route, route.isAvailable else {
            return .unsupportedBecauseNoDesktopRoute
        }

        if route.risk == .preferredDante || isLikelyDante(route) {
            return .unsupportedBecauseDanteRoute
        }
        if route.risk == .feedbackLoopRisk {
            return .unsupportedRoute(reason: "Unavailable for feedback-loop routes.")
        }
        if route.risk == .unavailable {
            return .unsupportedRoute(reason: "Desktop monitor route is unavailable.")
        }
        if route.outputChannelCount < 2 {
            return .unsupportedRoute(reason: "Requires a stereo desktop monitor route.")
        }
        if let sessionSampleRate,
           let nominalSampleRate = route.nominalSampleRate,
           !nominalSampleRate.matches(sessionSampleRate) {
            return .unsupportedBecauseSessionSampleRateMismatch
        }
        if options.requiresHeadphones && isBuiltInSpeakers(route) {
            return .unsupportedBecauseBuiltInSpeakers
        }
        if options.requiresHeadphones && !isHeadphoneCapable(route) {
            return .unsupportedRoute(reason: "Requires a headphone desktop monitor route.")
        }

        return .supported
    }

    public func isHeadphoneCapable(_ route: OutputRouteDescriptor) -> Bool {
        let text = normalizedText(for: route)
        if text.contains("airpods")
            || text.contains("beats")
            || text.contains("headphone")
            || text.contains("headphones")
            || text.contains("headset")
            || text.contains("buds") {
            return true
        }
        if text.contains("bluetooth"), route.outputChannelCount <= 2 {
            return true
        }
        if text.contains("usb"), text.contains("phone") {
            return true
        }
        return false
    }

    public func isBuiltInSpeakers(_ route: OutputRouteDescriptor) -> Bool {
        let text = normalizedText(for: route)
        return text.contains("built-in")
            && (text.contains("speaker") || text.contains("speakers"))
    }

    public func isLikelyDante(_ route: OutputRouteDescriptor) -> Bool {
        let text = normalizedText(for: route)
        return text.contains("dante") || text.contains("audinate")
    }

    private func normalizedText(for route: OutputRouteDescriptor) -> String {
        [
            route.uid ?? "",
            route.name,
            route.manufacturer ?? "",
            route.transportName ?? ""
        ]
        .joined(separator: " ")
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        .lowercased()
    }
}

public final class AppleSpatialHeadphoneMonitor: @unchecked Sendable {
    private let classifier: AppleSpatialRouteClassifier
    private let lock = NSLock()
    private var validationNode: AVAudioEnvironmentNode?

    public init(classifier: AppleSpatialRouteClassifier = AppleSpatialRouteClassifier()) {
        self.classifier = classifier
    }

    public func status(
        mode: DesktopMonitorMode,
        options: AppleSpatialHeadphoneOptions,
        route: OutputRouteDescriptor?,
        sessionSampleRate: AudioSampleRate?,
        liveDesktopBranchConnected: Bool = false
    ) -> DesktopMonitorModeStatus {
        switch mode {
        case .referenceStereo:
            return .referenceStereo(
                routeName: route?.name,
                sessionSampleRate: sessionSampleRate
            )
        case .appleSpatialHeadphones:
            guard options.isEnabled else {
                return DesktopMonitorModeStatus(
                    mode: .appleSpatialHeadphones,
                    isActive: false,
                    isPendingRestart: false,
                    capability: .validationOnly,
                    userVisibleMessage: "Apple Spatial Headphones is off.",
                    effectiveOutputRouteName: route?.name,
                    sessionSampleRate: sessionSampleRate
                )
            }

            let capability = classifier.capability(
                route: route,
                sessionSampleRate: sessionSampleRate,
                options: options
            )
            guard capability.isUsable else {
                return DesktopMonitorModeStatus(
                    mode: .appleSpatialHeadphones,
                    isActive: false,
                    isPendingRestart: false,
                    capability: capability,
                    userVisibleMessage: capability.userVisibleMessage,
                    effectiveOutputRouteName: route?.name,
                    sessionSampleRate: sessionSampleRate,
                    lastError: capability.userVisibleMessage
                )
            }

            let configuration = validateEnvironment(options: options)
            let active = liveDesktopBranchConnected
            let message: String
            if active {
                message = activeMessage(routeName: route?.name, configuration: configuration)
            } else {
                message = "Preference saved. Live Apple Spatial Headphones output is not wired yet."
            }

            return DesktopMonitorModeStatus(
                mode: .appleSpatialHeadphones,
                isActive: active,
                isPendingRestart: false,
                capability: configuration.capability,
                userVisibleMessage: message,
                headTrackingStatus: configuration.headTrackingStatus,
                effectiveOutputRouteName: route?.name,
                sessionSampleRate: sessionSampleRate
            )
        }
    }

    public func configureSpatialSource(
        _ source: AVAudio3DMixing,
        position: AppleSpatialSpeakerPosition,
        options: AppleSpatialHeadphoneOptions = .enabledDefault
    ) {
        guard !position.isOmitted else { return }
        source.position = AVAudio3DPoint(x: position.x, y: position.y, z: position.z)
        source.renderingAlgorithm = options.preferHRTFHQ ? .HRTFHQ : .HRTF
        source.sourceMode = .pointSource
    }

    private func validateEnvironment(options: AppleSpatialHeadphoneOptions) -> EnvironmentConfiguration {
        let environment = AVAudioEnvironmentNode()
        switch options.outputTypePolicy {
        case .headphonesOrAuto, .headphonesOnly:
            environment.outputType = .headphones
        case .auto:
            environment.outputType = .auto
        }

        let headTrackingStatus = headTrackingStatus(for: environment, options: options)
        lock.lock()
        validationNode = environment
        lock.unlock()

        if case .unavailable(let reason) = headTrackingStatus,
           options.enableHeadTrackingWhenAvailable {
            return EnvironmentConfiguration(
                capability: .supportedWithoutHeadTracking(reason: reason),
                headTrackingStatus: headTrackingStatus,
                hrtfHQRequested: options.preferHRTFHQ
            )
        }

        return EnvironmentConfiguration(
            capability: .supported,
            headTrackingStatus: headTrackingStatus,
            hrtfHQRequested: options.preferHRTFHQ
        )
    }

    private func headTrackingStatus(
        for environment: AVAudioEnvironmentNode,
        options: AppleSpatialHeadphoneOptions
    ) -> AppleSpatialHeadTrackingStatus {
        guard options.enableHeadTrackingWhenAvailable else {
            return .notRequested
        }

        let selector = NSSelectorFromString("setListenerHeadTrackingEnabled:")
        guard environment.responds(to: selector) else {
            return .unavailable(reason: "Head tracking unavailable on this SDK, route, or hardware.")
        }

        environment.perform(selector, with: NSNumber(value: true))
        return .enabled
    }

    private func activeMessage(
        routeName: String?,
        configuration: EnvironmentConfiguration
    ) -> String {
        var parts: [String] = []
        if let routeName, !routeName.isEmpty {
            parts.append("Active on \(routeName)")
        } else {
            parts.append("Active")
        }
        if configuration.hrtfHQRequested {
            parts.append("HRTF HQ enabled")
        }
        switch configuration.headTrackingStatus {
        case .enabled:
            parts.append("Head tracking enabled")
        case .unavailable:
            parts.append("Head tracking unavailable")
        case .notRequested:
            break
        }
        parts.append("Monitor only, Dante unaffected")
        return parts.joined(separator: " • ")
    }

    private struct EnvironmentConfiguration {
        let capability: AppleSpatialHeadphoneCapability
        let headTrackingStatus: AppleSpatialHeadTrackingStatus
        let hrtfHQRequested: Bool
    }
}
