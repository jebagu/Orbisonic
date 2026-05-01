import AudioContracts
import Foundation

public enum AudioSessionPlanningIntent: String, CaseIterable, Equatable, Hashable, Sendable {
    case production
    case desktopPreview
    case offlineValidation
}

public enum SourceProductionReadiness: Equatable, Hashable, Sendable {
    case sessionNative
    case managedImportedAssetAtSessionRate
    case requiresManagedImport
}

public enum SessionRouteValidationStatus: Equatable, Hashable, Sendable {
    case valid
    case invalid([AudioError])

    public var errors: [AudioError] {
        switch self {
        case .valid:
            []
        case .invalid(let errors):
            errors
        }
    }
}

public enum SessionConversionPolicyStatus: Equatable, Hashable, Sendable {
    case clean
    case blocked([AudioError])

    public var errors: [AudioError] {
        switch self {
        case .clean:
            []
        case .blocked(let errors):
            errors
        }
    }
}

public struct AudioSessionPlanRequest: Equatable, Hashable, Sendable {
    public let desiredSampleRateHertz: Double?
    public let desiredDesktopRoute: OutputRouteDescriptor?
    public let desiredDanteRoute: DanteRouteCapability?
    public let desiredSource: SourceDescriptor?
    public let sourceReadiness: SourceProductionReadiness
    public let renderMode: RenderMode
    public let intent: AudioSessionPlanningIntent
    public let currentSessionFormat: AudioSessionFormat?
    public let currentDesktopRouteID: String?
    public let currentDanteRouteID: String?

    public init(
        desiredSampleRateHertz: Double? = nil,
        desiredDesktopRoute: OutputRouteDescriptor? = nil,
        desiredDanteRoute: DanteRouteCapability? = nil,
        desiredSource: SourceDescriptor? = nil,
        sourceReadiness: SourceProductionReadiness = .sessionNative,
        renderMode: RenderMode = .automatic,
        intent: AudioSessionPlanningIntent = .production,
        currentSessionFormat: AudioSessionFormat? = nil,
        currentDesktopRouteID: String? = nil,
        currentDanteRouteID: String? = nil
    ) {
        self.desiredSampleRateHertz = desiredSampleRateHertz
        self.desiredDesktopRoute = desiredDesktopRoute
        self.desiredDanteRoute = desiredDanteRoute
        self.desiredSource = desiredSource
        self.sourceReadiness = sourceReadiness
        self.renderMode = renderMode
        self.intent = intent
        self.currentSessionFormat = currentSessionFormat
        self.currentDesktopRouteID = currentDesktopRouteID
        self.currentDanteRouteID = currentDanteRouteID
    }

    public init(
        desiredSampleRate: AudioSampleRate?,
        desiredDesktopRoute: OutputRouteDescriptor? = nil,
        desiredDanteRoute: DanteRouteCapability? = nil,
        desiredSource: SourceDescriptor? = nil,
        sourceReadiness: SourceProductionReadiness = .sessionNative,
        renderMode: RenderMode = .automatic,
        intent: AudioSessionPlanningIntent = .production,
        currentSessionFormat: AudioSessionFormat? = nil,
        currentDesktopRouteID: String? = nil,
        currentDanteRouteID: String? = nil
    ) {
        self.init(
            desiredSampleRateHertz: desiredSampleRate?.hertz,
            desiredDesktopRoute: desiredDesktopRoute,
            desiredDanteRoute: desiredDanteRoute,
            desiredSource: desiredSource,
            sourceReadiness: sourceReadiness,
            renderMode: renderMode,
            intent: intent,
            currentSessionFormat: currentSessionFormat,
            currentDesktopRouteID: currentDesktopRouteID,
            currentDanteRouteID: currentDanteRouteID
        )
    }
}

public struct AudioSessionPlan: Equatable, Hashable, Sendable {
    public let plannedSessionFormat: AudioSessionFormat?
    public let validationMessages: [String]
    public let requiredStopRebuild: StopRebuildDecision
    public let selectedDesktopOutputFormat: DesktopOutputFormat?
    public let selectedDanteOutputFormat: DanteOutputFormat?
    public let routeValidationStatus: SessionRouteValidationStatus
    public let conversionPolicyStatus: SessionConversionPolicyStatus
    public let conversionLedger: ConversionLedger

    public var isAccepted: Bool {
        plannedSessionFormat != nil
            && routeValidationStatus.errors.isEmpty
            && conversionPolicyStatus.errors.isEmpty
    }

    public var validationErrors: [AudioError] {
        routeValidationStatus.errors + conversionPolicyStatus.errors
    }
}

public enum ProductionSampleRatePolicy {
    public static let defaultProductionSampleRate = AudioSampleRate.defaultProduction
    public static let allowedThirtyOneChannelDanteRates = AudioSampleRate.danteThirtyOneChannelProductionRates

    public static func isAllowedThirtyOneChannelDanteRate(_ sampleRate: AudioSampleRate) -> Bool {
        allowedThirtyOneChannelDanteRates.contains { $0.matches(sampleRate) }
    }

    public static func validationErrors(
        sampleRate: AudioSampleRate,
        danteCapability: DanteRouteCapability?
    ) -> [AudioError] {
        var errors: [AudioError] = []
        if !isAllowedThirtyOneChannelDanteRate(sampleRate) {
            errors.append(.danteUnsupportedSampleRate(sampleRate))
        }
        if let danteCapability {
            errors.append(contentsOf: danteCapability.validationErrors(for: sampleRate))
        }
        return Array(Set(errors)).sorted(by: { $0.description < $1.description })
    }

    public static func validationMessage(
        sampleRate: AudioSampleRate,
        danteCapability: DanteRouteCapability?
    ) -> String {
        let errors = validationErrors(sampleRate: sampleRate, danteCapability: danteCapability)
        if errors.isEmpty {
            return "\(format(sampleRate)) is valid for 31-channel Dante production on the selected route."
        }
        return errors.map(\.description).joined(separator: " ")
    }

    public static func format(_ sampleRate: AudioSampleRate) -> String {
        let kilohertz = sampleRate.hertz / 1_000
        if abs(kilohertz.rounded() - kilohertz) <= 0.01 {
            return "\(Int(kilohertz.rounded())) kHz"
        }
        return String(format: "%.1f kHz", kilohertz)
    }
}

public struct RouteCapabilityInput: Equatable, Hashable, Sendable {
    public let id: String
    public let uid: String?
    public let name: String
    public let manufacturer: String?
    public let transportName: String?
    public let inputChannelCount: Int
    public let outputChannelCount: Int
    public let nominalSampleRate: AudioSampleRate?
    public let isAvailable: Bool
    public let supportedSampleRates: [AudioSampleRate]?

    public init(
        id: String,
        uid: String? = nil,
        name: String,
        manufacturer: String? = nil,
        transportName: String? = nil,
        inputChannelCount: Int = 0,
        outputChannelCount: Int,
        nominalSampleRate: AudioSampleRate? = nil,
        isAvailable: Bool = true,
        supportedSampleRates: [AudioSampleRate]? = nil
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
        self.supportedSampleRates = supportedSampleRates
    }
}

public struct RouteCapabilityValidator: Sendable {
    public init() {}

    public func outputRouteDescriptor(from input: RouteCapabilityInput) -> OutputRouteDescriptor {
        OutputRouteDescriptor(
            id: input.id,
            uid: input.uid,
            name: input.name,
            manufacturer: input.manufacturer,
            transportName: input.transportName,
            inputChannelCount: input.inputChannelCount,
            outputChannelCount: input.outputChannelCount,
            nominalSampleRate: input.nominalSampleRate,
            isAvailable: input.isAvailable,
            risk: routeRisk(for: input)
        )
    }

    public func danteRouteCapability(from input: RouteCapabilityInput) -> DanteRouteCapability {
        let route = outputRouteDescriptor(from: input)
        return DanteRouteCapability(
            route: route,
            supportedSampleRates: input.supportedSampleRates,
            currentNominalSampleRate: input.nominalSampleRate,
            outputChannelCount: input.outputChannelCount,
            validationMessages: danteRouteMessages(for: input)
        )
    }

    public func routeRisk(for input: RouteCapabilityInput) -> OutputRouteRisk {
        guard input.isAvailable else { return .unavailable }

        let text = normalizedText(for: input)
        if isKnownOrbisonicLoopback(input) || text.contains("orbisonic roon input")
            || text.contains("orbisonic spotify input") || text.contains("orbisonic aux cable") {
            return .feedbackLoopRisk
        }
        if text.contains("blackhole") || text.contains("existential") {
            return .feedbackLoopRisk
        }
        if isLikelyDanteRoute(input) {
            return .preferredDante
        }
        if normalized(input.transportName ?? "") == "virtual" {
            return .virtualOutputRisk
        }
        return .safe
    }

    public func isLikelyDanteRoute(_ input: RouteCapabilityInput) -> Bool {
        let text = normalizedText(for: input)
        return text.contains("dante")
            || text.contains("audinate")
            || text.contains("dante virtual soundcard")
    }

    private func danteRouteMessages(for input: RouteCapabilityInput) -> [String] {
        guard isLikelyDanteRoute(input) else { return [] }
        if input.outputChannelCount < 31 {
            return ["Dante production requires at least 31 output channels."]
        }
        return ["Route appears to be a Dante renderer candidate."]
    }

    private func isKnownOrbisonicLoopback(_ input: RouteCapabilityInput) -> Bool {
        guard let uid = input.uid else { return false }
        return [
            "audio.orbisonic.rooninput.device",
            "audio.orbisonic.spotifyinput.device",
            "audio.orbisonic.auxcable.device"
        ].contains(uid)
    }

    private func normalizedText(for input: RouteCapabilityInput) -> String {
        [
            input.name,
            input.manufacturer ?? "",
            input.transportName ?? "",
            input.uid ?? ""
        ].map(normalized).joined(separator: " ")
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
    }
}

public enum StopRebuildChange: Equatable, Hashable, Sendable {
    case sessionSampleRate(current: AudioSampleRate?, requested: AudioSampleRate)
    case danteOutputRoute(currentRouteID: String?, requestedRouteID: String?)
    case desktopOutputRoute(currentRouteID: String?, requestedRouteID: String?)
    case desktopMonitorGain
    case danteOutputGain
    case vuDisplay
    case sourceSelection(source: SourceDescriptor, sessionFormat: AudioSessionFormat)
}

public struct StopRebuildDecision: Equatable, Hashable, Sendable {
    public let requiresStopAndRebuild: Bool
    public let blocksChange: Bool
    public let reason: String

    public static let noRebuild = StopRebuildDecision(
        requiresStopAndRebuild: false,
        blocksChange: false,
        reason: "Change can be applied without rebuilding the production graph."
    )

    public static func rebuild(_ reason: String) -> StopRebuildDecision {
        StopRebuildDecision(requiresStopAndRebuild: true, blocksChange: false, reason: reason)
    }

    public static func blocked(_ reason: String) -> StopRebuildDecision {
        StopRebuildDecision(requiresStopAndRebuild: false, blocksChange: true, reason: reason)
    }
}

public enum StopRebuildPolicy {
    public static func decision(for change: StopRebuildChange) -> StopRebuildDecision {
        switch change {
        case .sessionSampleRate(let current, let requested):
            guard let current else {
                return .rebuild("Starting a production session builds a graph at \(ProductionSampleRatePolicy.format(requested)).")
            }
            return current.matches(requested)
                ? .noRebuild
                : .rebuild("Changing the session sample rate requires a stopped session and graph rebuild.")
        case .danteOutputRoute(let currentRouteID, let requestedRouteID):
            return currentRouteID == requestedRouteID
                ? .noRebuild
                : .rebuild("Changing the Dante output route requires stop and rebuild until live route swaps are proven safe.")
        case .desktopOutputRoute(let currentRouteID, let requestedRouteID):
            return currentRouteID == requestedRouteID
                ? .noRebuild
                : .rebuild("Changing the desktop output route is conservatively treated as a graph rebuild.")
        case .desktopMonitorGain, .danteOutputGain:
            return .noRebuild
        case .vuDisplay:
            return .noRebuild
        case .sourceSelection(let source, let sessionFormat):
            return source.sampleRate.matches(sessionFormat.sampleRate)
                ? .noRebuild
                : .blocked("Mismatched sources require session-rate import or a stopped-session rate switch, never hidden SRC.")
        }
    }

    public static func combined(_ decisions: [StopRebuildDecision]) -> StopRebuildDecision {
        if let blocked = decisions.first(where: \.blocksChange) {
            return blocked
        }
        if let rebuild = decisions.first(where: \.requiresStopAndRebuild) {
            return rebuild
        }
        return .noRebuild
    }
}

public struct AudioSessionPlanner: Sendable {
    private let routeValidator: RouteCapabilityValidator

    public init(routeValidator: RouteCapabilityValidator = RouteCapabilityValidator()) {
        self.routeValidator = routeValidator
    }

    public func plan(_ request: AudioSessionPlanRequest) -> AudioSessionPlan {
        var errors: [AudioError] = []
        var conversionErrors: [AudioError] = []
        var messages: [String] = []

        let sampleRate = resolveSampleRate(request.desiredSampleRateHertz, errors: &errors)
        let desktopFormat = makeDesktopFormat(
            sampleRate: sampleRate,
            route: request.desiredDesktopRoute,
            intent: request.intent,
            errors: &errors,
            messages: &messages
        )
        let danteFormat = makeDanteFormat(
            sampleRate: sampleRate,
            capability: request.desiredDanteRoute,
            intent: request.intent,
            errors: &errors,
            messages: &messages
        )

        if let sampleRate, let source = request.desiredSource {
            validateSource(
                source,
                readiness: request.sourceReadiness,
                sessionSampleRate: sampleRate,
                conversionErrors: &conversionErrors,
                messages: &messages
            )
        }

        let plannedFormat: AudioSessionFormat?
        if errors.isEmpty,
           conversionErrors.isEmpty,
           let sampleRate,
           let desktopFormat,
           let danteFormat {
            let candidate = AudioSessionFormat(
                sampleRate: sampleRate,
                maxFramesPerBlock: request.currentSessionFormat?.maxFramesPerBlock ?? 512,
                processingFormat: .float32NonInterleavedPCM,
                sourceChannelLimit: AudioSessionFormat.maximumSourceChannelLimit,
                dante: danteFormat,
                desktop: desktopFormat
            )
            let formatErrors = candidate.validationErrors()
            if formatErrors.isEmpty {
                plannedFormat = candidate
            } else {
                errors.append(contentsOf: formatErrors)
                plannedFormat = nil
            }
        } else {
            plannedFormat = nil
        }

        let stopRebuild = stopRebuildDecision(
            request: request,
            sampleRate: sampleRate,
            plannedFormat: plannedFormat
        )
        let allErrors = errors + conversionErrors
        messages.append(contentsOf: allErrors.map(\.description))

        let ledger = conversionLedger(
            request: request,
            sessionSampleRate: sampleRate ?? ProductionSampleRatePolicy.defaultProductionSampleRate,
            desktopRoute: request.desiredDesktopRoute,
            danteRoute: request.desiredDanteRoute,
            productionSRCRequired: !conversionErrors.isEmpty
        )

        return AudioSessionPlan(
            plannedSessionFormat: plannedFormat,
            validationMessages: Array(Set(messages)).sorted(),
            requiredStopRebuild: stopRebuild,
            selectedDesktopOutputFormat: desktopFormat,
            selectedDanteOutputFormat: danteFormat,
            routeValidationStatus: errors.isEmpty ? .valid : .invalid(errors),
            conversionPolicyStatus: conversionErrors.isEmpty ? .clean : .blocked(conversionErrors),
            conversionLedger: ledger
        )
    }

    private func resolveSampleRate(
        _ desiredSampleRateHertz: Double?,
        errors: inout [AudioError]
    ) -> AudioSampleRate? {
        let requested = desiredSampleRateHertz ?? ProductionSampleRatePolicy.defaultProductionSampleRate.hertz
        do {
            return try AudioSampleRate(hertz: requested)
        } catch {
            errors.append(.invalidRenderGraphPlan("Requested sample rate must be positive and finite."))
            return nil
        }
    }

    private func makeDesktopFormat(
        sampleRate: AudioSampleRate?,
        route: OutputRouteDescriptor?,
        intent: AudioSessionPlanningIntent,
        errors: inout [AudioError],
        messages: inout [String]
    ) -> DesktopOutputFormat? {
        guard let sampleRate else { return nil }
        guard let route else {
            if intent == .production {
                errors.append(.routeUnavailable("desktop"))
            }
            return intent == .offlineValidation ? DesktopOutputFormat(sampleRate: sampleRate) : nil
        }
        guard route.isAvailable else {
            errors.append(.routeUnavailable(route.id))
            return nil
        }
        if route.outputChannelCount < 2 {
            errors.append(.desktopRouteInsufficientChannels(required: 2, actual: route.outputChannelCount))
        }
        if let nominalSampleRate = route.nominalSampleRate,
           !nominalSampleRate.matches(sampleRate) {
            errors.append(.sampleRateMismatch(expected: sampleRate, actual: nominalSampleRate, context: "desktop route"))
        } else if route.nominalSampleRate == nil {
            errors.append(.invalidRenderGraphPlan("Desktop route sample-rate support is unknown."))
        }
        messages.append("Desktop route \(route.name) validated as stereo monitor candidate.")
        return DesktopOutputFormat(channelCount: 2, sampleRate: sampleRate)
    }

    private func makeDanteFormat(
        sampleRate: AudioSampleRate?,
        capability: DanteRouteCapability?,
        intent: AudioSessionPlanningIntent,
        errors: inout [AudioError],
        messages: inout [String]
    ) -> DanteOutputFormat? {
        guard let sampleRate else { return nil }
        guard let capability else {
            if intent == .production {
                errors.append(.routeUnavailable("dante"))
            }
            return intent == .desktopPreview
                ? DanteOutputFormat(physicalChannelCount: 31, sampleRate: sampleRate)
                : nil
        }

        let danteErrors = ProductionSampleRatePolicy.validationErrors(
            sampleRate: sampleRate,
            danteCapability: capability
        )
        errors.append(contentsOf: danteErrors)
        messages.append(ProductionSampleRatePolicy.validationMessage(sampleRate: sampleRate, danteCapability: capability))

        let physicalChannelCount = capability.outputChannelCount >= 32 ? 32 : capability.outputChannelCount
        let format = DanteOutputFormat(
            logicalChannelCount: 31,
            physicalChannelCount: physicalChannelCount,
            sampleRate: sampleRate,
            channelMap: .direct31
        )
        errors.append(contentsOf: format.validationErrors(sessionSampleRate: sampleRate))
        if format.isChannel32Reserved {
            messages.append("Dante physical channel 32 is reserved and silent in this plan.")
        }
        return format
    }

    private func validateSource(
        _ source: SourceDescriptor,
        readiness: SourceProductionReadiness,
        sessionSampleRate: AudioSampleRate,
        conversionErrors: inout [AudioError],
        messages: inout [String]
    ) {
        if !SourceDescriptor.sourceChannelLimit.contains(source.channelCount) {
            conversionErrors.append(.sourceChannelCountOutOfRange(count: source.channelCount, minimum: 1, maximum: 64))
        }
        if let error = source.layout.validationErrors(expectedChannelCount: source.channelCount).first {
            conversionErrors.append(error)
        }

        guard !source.sampleRate.matches(sessionSampleRate) else {
            messages.append("Source sample rate matches the planned session rate.")
            return
        }

        if source.kind == .localFile {
            switch readiness {
            case .managedImportedAssetAtSessionRate:
                conversionErrors.append(
                    .sampleRateMismatch(expected: sessionSampleRate, actual: source.sampleRate, context: "managed local asset")
                )
            case .sessionNative, .requiresManagedImport:
                conversionErrors.append(.localAssetRequiresManagedImport(sourceID: source.id))
            }
        } else {
            conversionErrors.append(.sampleRateMismatch(expected: sessionSampleRate, actual: source.sampleRate, context: "source"))
        }
    }

    private func stopRebuildDecision(
        request: AudioSessionPlanRequest,
        sampleRate: AudioSampleRate?,
        plannedFormat: AudioSessionFormat?
    ) -> StopRebuildDecision {
        var decisions: [StopRebuildDecision] = []
        if let sampleRate {
            decisions.append(
                StopRebuildPolicy.decision(
                    for: .sessionSampleRate(
                        current: request.currentSessionFormat?.sampleRate,
                        requested: sampleRate
                    )
                )
            )
        }
        decisions.append(
            StopRebuildPolicy.decision(
                for: .desktopOutputRoute(
                    currentRouteID: request.currentDesktopRouteID,
                    requestedRouteID: request.desiredDesktopRoute?.id
                )
            )
        )
        decisions.append(
            StopRebuildPolicy.decision(
                for: .danteOutputRoute(
                    currentRouteID: request.currentDanteRouteID,
                    requestedRouteID: request.desiredDanteRoute?.route.id
                )
            )
        )
        if let source = request.desiredSource, let plannedFormat {
            decisions.append(
                StopRebuildPolicy.decision(
                    for: .sourceSelection(source: source, sessionFormat: plannedFormat)
                )
            )
        }
        return StopRebuildPolicy.combined(decisions)
    }

    private func conversionLedger(
        request: AudioSessionPlanRequest,
        sessionSampleRate: AudioSampleRate,
        desktopRoute: OutputRouteDescriptor?,
        danteRoute: DanteRouteCapability?,
        productionSRCRequired: Bool
    ) -> ConversionLedger {
        let sourceRate = request.desiredSource?.sampleRate.hertz.description ?? "unknown"
        let desktopRate = desktopRoute?.nominalSampleRate?.hertz.description ?? "unknown"
        let danteRate = danteRoute?.currentNominalSampleRate?.hertz.description ?? "unknown"
        return ConversionLedger(
            sessionSampleRate: sessionSampleRate,
            sourceOriginalDescription: "sourceSampleRate=\(sourceRate)",
            sourceCanonicalDescription: "sessionSampleRate=\(sessionSampleRate.hertz)",
            allowedConversions: request.sourceReadiness == .managedImportedAssetAtSessionRate
                ? [.offlineManagedSampleRateConversion, .codecDecodeToPCM, .integerPCMToFloat32, .interleavedToDeinterleaved]
                : [.codecDecodeToPCM, .integerPCMToFloat32, .interleavedToDeinterleaved, .layoutMetadataNormalization],
            forbiddenConversionsObserved: productionSRCRequired ? [.productionSampleRateConversion] : [],
            desktopOutputDescription: "desktopRouteSampleRate=\(desktopRate)",
            danteOutputDescription: "danteRouteSampleRate=\(danteRate)"
        )
    }
}
