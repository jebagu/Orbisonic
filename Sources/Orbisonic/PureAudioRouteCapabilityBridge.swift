import AudioContracts
import AudioCore

extension RouteCapabilityInput {
    static func legacyOutputRoute(_ route: OutputRouteInfo) -> RouteCapabilityInput {
        RouteCapabilityInput(
            id: route.id,
            uid: route.uid.isEmpty ? nil : route.uid,
            name: route.deviceName,
            manufacturer: route.manufacturer.isEmpty ? nil : route.manufacturer,
            transportName: route.transportName.isEmpty ? nil : route.transportName,
            outputChannelCount: route.outputChannelCount,
            nominalSampleRate: try? AudioSampleRate(hertz: route.nominalSampleRate),
            isAvailable: route.isAvailable
        )
    }
}

extension RouteCapabilityValidator {
    func outputRouteDescriptor(from route: OutputRouteInfo) -> AudioContracts.OutputRouteDescriptor {
        outputRouteDescriptor(from: .legacyOutputRoute(route))
    }

    func danteRouteCapability(from route: OutputRouteInfo) -> DanteRouteCapability {
        danteRouteCapability(from: .legacyOutputRoute(route))
    }
}
