import Foundation

struct MonitorDownmixPanelModel: Equatable, Sendable {
    let signalText: String
    let inputText: String
    let mappingText: String
    let renderText: String
    let rulesText: String
    let outputText: String
    let warningText: String?

    static func make(
        sourceMode: SourceMode,
        metadata: AudioSourceMetadata?,
        signalText: String,
        outputText: String,
        liveReadinessText: String
    ) -> MonitorDownmixPanelModel {
        let inputText: String
        let mappingText: String
        let rulesText: String
        let warningText: String?

        if let metadata {
            inputText = inputDescription(for: metadata)
            mappingText = mappingDescription(for: metadata)
            rulesText = rulesDescription(channelCount: metadata.channelCount)
            warningText = warningDescription(for: metadata)
        } else {
            inputText = sourceMode.isLiveInput ? liveReadinessText : "No source loaded"
            mappingText = sourceMode == .testTone ? "Diagnostic source" : "No source layout"
            rulesText = rulesDescription(channelCount: 0)
            warningText = nil
        }

        return MonitorDownmixPanelModel(
            signalText: signalText,
            inputText: inputText,
            mappingText: mappingText,
            renderText: "NormalMonitorStereoDownmixer",
            rulesText: rulesText,
            outputText: outputText,
            warningText: warningText
        )
    }

    private static func inputDescription(for metadata: AudioSourceMetadata) -> String {
        let countText = metadata.channelCount == 1 ? "1 ch" : "\(metadata.channelCount) ch"
        guard !metadata.channelSummary.isEmpty else { return countText }
        return "\(countText) • \(metadata.channelSummary)"
    }

    private static func mappingDescription(for metadata: AudioSourceMetadata) -> String {
        let confidence = metadata.channelLayoutConfidence == .high ? "Explicit" : "Fallback"
        return "\(confidence) • \(metadata.channelLayoutSourceDescription)"
    }

    private static func rulesDescription(channelCount: Int) -> String {
        switch channelCount {
        case 0:
            "Stereo identity; multichannel fold; LFE muted"
        case 1:
            "Mono center to L/R; no LFE fold"
        case 2:
            "Stereo identity; no multichannel fold"
        default:
            "Multichannel headroom; center/surround fold; LFE muted"
        }
    }

    private static func warningDescription(for metadata: AudioSourceMetadata) -> String? {
        if let warning = metadata.channelLayoutWarnings.first?.trimmedNilIfBlank {
            return warning
        }
        guard metadata.channelCount > 2,
              metadata.channelLayoutConfidence == .low
        else { return nil }
        return "Channel layout is ambiguous. Orbisonic is using fallback order \(metadata.channelSummary)."
    }
}
