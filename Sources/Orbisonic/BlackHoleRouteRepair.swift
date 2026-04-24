import CoreAudio
import Foundation

enum BlackHoleRouteRepair {
    @discardableResult
    static func prepareDefaultInputDeviceForCapture(preferredSampleRate: Double? = nil) -> Bool {
        let route = OutputRouteMonitor.currentInputRoute()
        return prepareInputDeviceForCapture(route, preferredSampleRate: preferredSampleRate)
    }

    @discardableResult
    static func prepareInputDeviceForCapture(
        _ route: InputRouteInfo,
        preferredSampleRate: Double? = nil
    ) -> Bool {
        guard route.isBlackHole else { return false }

        var sampleRateChanged = false
        if let preferredSampleRate,
           preferredSampleRate > 0,
           abs(route.nominalSampleRate - preferredSampleRate) > 1 {
            sampleRateChanged = setNominalSampleRate(preferredSampleRate, deviceID: route.deviceID)
        }
        repair(deviceID: route.deviceID)
        AppLogger.shared.notice(
            category: "route",
            "Prepared BlackHole capture route device=\(route.deviceName) sampleRate=\(String(format: "%.0f", preferredSampleRate ?? route.nominalSampleRate)) volume=1 mute=false sampleRateChanged=\(sampleRateChanged)"
        )

        return sampleRateChanged
    }

    private static func repair(deviceID: AudioDeviceID) {
        for scope in [kAudioDevicePropertyScopeOutput, kAudioDevicePropertyScopeInput] {
            setMute(false, deviceID: deviceID, scope: scope, element: kAudioObjectPropertyElementMain)
            setVolume(1.0, deviceID: deviceID, scope: scope, element: kAudioObjectPropertyElementMain)

            for channel in 1...64 {
                setMute(false, deviceID: deviceID, scope: scope, element: AudioObjectPropertyElement(channel))
                setVolume(1.0, deviceID: deviceID, scope: scope, element: AudioObjectPropertyElement(channel))
            }
        }
    }

    private static func setMute(
        _ muted: Bool,
        deviceID: AudioDeviceID,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) {
        var address = propertyAddress(kAudioDevicePropertyMute, scope: scope, element: element)
        guard AudioObjectHasProperty(deviceID, &address), isSettable(deviceID: deviceID, address: &address) else {
            return
        }

        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &value)

        if status != noErr {
            AppLogger.shared.warning(
                category: "route",
                "Failed to set BlackHole mute scope=\(scope) element=\(element) status=\(status)"
            )
        }
    }

    private static func setVolume(
        _ volume: Float32,
        deviceID: AudioDeviceID,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) {
        var address = propertyAddress(kAudioDevicePropertyVolumeScalar, scope: scope, element: element)
        guard AudioObjectHasProperty(deviceID, &address), isSettable(deviceID: deviceID, address: &address) else {
            return
        }

        var value = volume
        let size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &value)

        if status != noErr {
            AppLogger.shared.warning(
                category: "route",
                "Failed to set BlackHole volume scope=\(scope) element=\(element) status=\(status)"
            )
        }
    }

    private static func setNominalSampleRate(_ sampleRate: Double, deviceID: AudioDeviceID) -> Bool {
        var address = propertyAddress(kAudioDevicePropertyNominalSampleRate, scope: kAudioObjectPropertyScopeGlobal, element: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(deviceID, &address), isSettable(deviceID: deviceID, address: &address) else {
            AppLogger.shared.warning(
                category: "route",
                "BlackHole sample rate is not settable requested=\(String(format: "%.0f", sampleRate))"
            )
            return false
        }

        var value = Float64(sampleRate)
        let size = UInt32(MemoryLayout<Float64>.size)
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &value)

        if status != noErr {
            AppLogger.shared.warning(
                category: "route",
                "Failed to set BlackHole sample rate requested=\(String(format: "%.0f", sampleRate)) status=\(status)"
            )
            return false
        }

        AppLogger.shared.notice(
            category: "route",
            "Set BlackHole sample rate requested=\(String(format: "%.0f", sampleRate))"
        )
        return true
    }

    private static func isSettable(deviceID: AudioDeviceID, address: inout AudioObjectPropertyAddress) -> Bool {
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr && settable.boolValue
    }

    private static func propertyAddress(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
    }
}
