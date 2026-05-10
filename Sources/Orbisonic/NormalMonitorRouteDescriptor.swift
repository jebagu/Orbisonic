import Foundation

enum NormalMonitorSourceFamily: String, CaseIterable, Sendable {
    case localFile
    case liveLoopback
    case diagnostics
}

enum NormalMonitorTerminalRenderer: String, CaseIterable, Sendable {
    case normalMonitorStereoDownmixer
}

struct NormalMonitorRouteDescriptor: Equatable, Sendable {
    let sourceFamily: NormalMonitorSourceFamily
    let usesNormalMonitor: Bool
    let outputChannelCount: Int
    let usesStereoDownmix: Bool
    let terminalRenderer: NormalMonitorTerminalRenderer
    let usesAVAudioEnvironmentNode: Bool
    let usesHRTF: Bool
    let usesHRTFHQ: Bool
    let usesHeadphoneEnvironmentOutput: Bool
    let usesPointSourceSpatialPlacement: Bool
    let usesAudibleDirectSonicSphereMatrix: Bool
    let hasDuplicateAudiblePath: Bool
    let sourceLayoutDescription: String
    let warningDescriptions: [String]
}

enum NormalMonitorRoutePlanner {
    static func audibleRoute(
        sourceFamily: NormalMonitorSourceFamily,
        sourceLayoutDescription: String,
        warningDescriptions: [String] = []
    ) -> NormalMonitorRouteDescriptor {
        NormalMonitorRouteDescriptor(
            sourceFamily: sourceFamily,
            usesNormalMonitor: true,
            outputChannelCount: 2,
            usesStereoDownmix: true,
            terminalRenderer: .normalMonitorStereoDownmixer,
            usesAVAudioEnvironmentNode: false,
            usesHRTF: false,
            usesHRTFHQ: false,
            usesHeadphoneEnvironmentOutput: false,
            usesPointSourceSpatialPlacement: false,
            usesAudibleDirectSonicSphereMatrix: false,
            hasDuplicateAudiblePath: false,
            sourceLayoutDescription: sourceLayoutDescription,
            warningDescriptions: warningDescriptions
        )
    }

    static func route(for sourceMode: SourceMode, sourceLayoutDescription: String) -> NormalMonitorRouteDescriptor {
        switch sourceMode {
        case .filePlayback:
            return audibleRoute(sourceFamily: .localFile, sourceLayoutDescription: sourceLayoutDescription)
        case .roon, .spotify, .aux, .atmosDRP:
            return audibleRoute(sourceFamily: .liveLoopback, sourceLayoutDescription: sourceLayoutDescription)
        case .testTone:
            return audibleRoute(sourceFamily: .diagnostics, sourceLayoutDescription: sourceLayoutDescription)
        case .off:
            return audibleRoute(
                sourceFamily: .diagnostics,
                sourceLayoutDescription: sourceLayoutDescription,
                warningDescriptions: ["No active audible source."]
            )
        }
    }
}

enum NormalMonitorAudibleRouteSelector {
    static func select(
        sourceFamily: NormalMonitorSourceFamily,
        sourceLayoutDescription: String,
        rendererMode: RendererRenderMode,
        activeOutputRoute: OutputRouteInfo,
        rendererOutputRoute: OutputRouteInfo,
        requiredSonicSphereOutputChannelCount: Int
    ) -> NormalMonitorRouteDescriptor {
        // Normal monitor route selection is a stereo preview branch. Production
        // renderer mode, output route capability, and Sonic Sphere channel count
        // must not alter this audible monitor path.
        _ = rendererMode
        _ = activeOutputRoute
        _ = rendererOutputRoute
        _ = requiredSonicSphereOutputChannelCount
        return NormalMonitorRoutePlanner.audibleRoute(
            sourceFamily: sourceFamily,
            sourceLayoutDescription: sourceLayoutDescription
        )
    }
}

enum NormalMonitorDownmixPolicy {
    static func pan(for role: SurroundChannelRole, sourceChannelCount: Int = 2) -> Float {
        let coefficients = NormalMonitorDownmixMatrix.coefficients(
            for: role,
            sourceChannelCount: sourceChannelCount
        )
        let sum = coefficients.left + coefficients.right
        guard sum > 0 else { return 0 }
        return (coefficients.right - coefficients.left) / sum
    }

    static func gain(for role: SurroundChannelRole, sourceChannelCount: Int = 2) -> Float {
        let coefficients = NormalMonitorDownmixMatrix.coefficients(
            for: role,
            sourceChannelCount: sourceChannelCount
        )
        return max(coefficients.left, coefficients.right)
    }
}
