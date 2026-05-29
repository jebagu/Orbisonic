import XCTest
@testable import Orbisonic

final class MonitorDownmixPanelModelTests: XCTestCase {
    func testStereoShowsIdentityWithoutWarning() {
        let panel = MonitorDownmixPanelModel.make(
            sourceMode: .filePlayback,
            metadata: metadata(channelCount: 2, layoutName: "Stereo", channelSummary: "FL, FR"),
            signalText: "Stereo -> Normal Monitor",
            outputText: "Built-in Output",
            liveReadinessText: "No live input"
        )

        XCTAssertEqual(panel.inputText, "2 ch • FL, FR")
        XCTAssertEqual(panel.mappingText, "Explicit • Source layout metadata")
        XCTAssertEqual(panel.rulesText, "Stereo identity; no multichannel fold")
        XCTAssertNil(panel.warningText)
    }

    func testExplicitFiveOneShowsNoAmbiguityWarning() {
        let panel = MonitorDownmixPanelModel.make(
            sourceMode: .filePlayback,
            metadata: metadata(
                channelCount: 6,
                layoutName: "5.1 Surround",
                channelSummary: "FL, FR, C, LFE1, SL, SR",
                confidence: .high,
                sourceDescription: "Explicit Core Audio channel descriptions"
            ),
            signalText: "5.1 Surround -> Normal Monitor stereo downmix",
            outputText: "Built-in Output",
            liveReadinessText: "No live input"
        )

        XCTAssertEqual(panel.mappingText, "Explicit • Explicit Core Audio channel descriptions")
        XCTAssertEqual(panel.renderText, "NormalMonitorStereoDownmixer")
        XCTAssertEqual(panel.rulesText, "Multichannel headroom; center/surround fold; LFE muted")
        XCTAssertNil(panel.warningText)
    }

    func testAmbiguousFiveOneShowsWarning() {
        let warning = "Low-confidence 5.1 layout unknown Core Audio layout tag; using legacy order L R C LFE Ls Rs."
        let panel = MonitorDownmixPanelModel.make(
            sourceMode: .filePlayback,
            metadata: metadata(
                channelCount: 6,
                layoutName: "5.1 Surround",
                channelSummary: "FL, FR, C, LFE1, SL, SR",
                confidence: .low,
                sourceDescription: "unknown Core Audio layout tag",
                warnings: [warning]
            ),
            signalText: "5.1 Surround -> Normal Monitor stereo downmix",
            outputText: "Built-in Output",
            liveReadinessText: "No live input"
        )

        XCTAssertEqual(panel.mappingText, "Fallback • unknown Core Audio layout tag")
        XCTAssertEqual(panel.warningText, warning)
    }

    func testLiveMultichannelFallbackShowsWarning() {
        let panel = MonitorDownmixPanelModel.make(
            sourceMode: .roon,
            metadata: metadata(
                channelCount: 8,
                layoutName: "7.1 Surround",
                channelSummary: "FL, FR, C, LFE1, SL, SR, RL, RR",
                confidence: .low,
                sourceDescription: "Live Core Audio route channel count; no explicit semantic layout"
            ),
            signalText: "7.1 Surround live -> Normal Monitor stereo downmix",
            outputText: "Monitor Output",
            liveReadinessText: "Live input ready"
        )

        XCTAssertTrue(panel.mappingText.contains("Fallback"))
        XCTAssertTrue(panel.warningText?.contains("Channel layout is ambiguous") == true)
        XCTAssertTrue(panel.warningText?.contains("FL, FR, C, LFE1, SL, SR, RL, RR") == true)
    }

    func testAtmosMetadataStillDescribesBedOnlySignal() {
        let panel = MonitorDownmixPanelModel.make(
            sourceMode: .filePlayback,
            metadata: metadata(
                channelCount: 6,
                layoutName: "5.1 Surround",
                channelSummary: "FL, FR, C, LFE1, SL, SR",
                formatNote: "Dolby Atmos metadata present; Orbisonic is using the decoded channel bed, not object rendering."
            ),
            signalText: "Atmos 5.1 -> Normal Monitor stereo downmix",
            outputText: "Built-in Output",
            liveReadinessText: "No live input"
        )

        XCTAssertEqual(panel.signalText, "Atmos 5.1 -> Normal Monitor stereo downmix")
        XCTAssertFalse(panel.signalText.localizedCaseInsensitiveContains("object"))
    }

    private func metadata(
        channelCount: Int,
        layoutName: String,
        channelSummary: String,
        confidence: ChannelLayoutConfidence = .high,
        sourceDescription: String = "Source layout metadata",
        warnings: [String] = [],
        formatNote: String? = nil
    ) -> AudioSourceMetadata {
        AudioSourceMetadata(
            fileName: "fixture.wav",
            containerName: "WAV",
            codecName: "PCM",
            layoutName: layoutName,
            channelSummary: channelSummary,
            channelCount: channelCount,
            sampleRate: 48_000,
            bitDepth: 24,
            duration: 1,
            formatNote: formatNote,
            channelLayoutConfidence: confidence,
            channelLayoutSourceDescription: sourceDescription,
            channelLayoutWarnings: warnings
        )
    }
}
