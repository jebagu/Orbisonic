import Foundation

struct AudioNodeFactoryDescriptor: Equatable, Sendable {
    let createsAVAudioEnvironmentNode: Bool
    let connectsAVAudioEnvironmentNode: Bool
    let selectsHRTF: Bool
    let selectsHRTFHQ: Bool
    let selectsHeadphoneEnvironmentOutput: Bool
    let convertsSourceToPointSource: Bool
}

enum AudioSpatialUsageAudit {
    static let normalMonitorAudiblePlayback = AudioNodeFactoryDescriptor(
        createsAVAudioEnvironmentNode: false,
        connectsAVAudioEnvironmentNode: false,
        selectsHRTF: false,
        selectsHRTFHQ: false,
        selectsHeadphoneEnvironmentOutput: false,
        convertsSourceToPointSource: false
    )

    static let audiblePlaybackDescriptors: [AudioNodeFactoryDescriptor] = [
        normalMonitorAudiblePlayback
    ]
}

enum NormalMonitorSpatialGuard {
    static func violations(for descriptor: AudioNodeFactoryDescriptor) -> [String] {
        var violations: [String] = []
        if descriptor.createsAVAudioEnvironmentNode {
            violations.append("AVAudioEnvironmentNode must not be created for audible monitor playback.")
        }
        if descriptor.connectsAVAudioEnvironmentNode {
            violations.append("AVAudioEnvironmentNode must not be connected for audible monitor playback.")
        }
        if descriptor.selectsHRTF {
            violations.append("HRTF must not be selected for audible monitor playback.")
        }
        if descriptor.selectsHRTFHQ {
            violations.append("HRTFHQ must not be selected for audible monitor playback.")
        }
        if descriptor.selectsHeadphoneEnvironmentOutput {
            violations.append("Headphone environment output must not be selected for audible monitor playback.")
        }
        if descriptor.convertsSourceToPointSource {
            violations.append("Source channels must not become 3D point sources for audible monitor playback.")
        }
        return violations
    }

    static func validatesAudiblePlayback(_ descriptor: AudioNodeFactoryDescriptor) -> Bool {
        violations(for: descriptor).isEmpty
    }
}
