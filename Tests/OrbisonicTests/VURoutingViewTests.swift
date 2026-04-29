import XCTest
@testable import Orbisonic

final class VURoutingViewTests: XCTestCase {
    func testStageTabsUseRequestedOrderAndLabels() {
        XCTAssertEqual(
            StageTab.allCases.map(\.rawValue),
            [
                "Input",
                "Routing",
                "Renderer",
                "Output",
                "VU",
                "Local Music",
                "Diagnostics",
                "Settings"
            ]
        )
    }

    func testVUMeterChannelLabelsAreBareNames() {
        XCTAssertEqual(VUMeterChannelLabel.text(for: SurroundChannel(index: 0, role: .frontLeft)), "L")
        XCTAssertEqual(VUMeterChannelLabel.text(for: SurroundChannel(index: 1, role: .frontRight)), "R")
        XCTAssertEqual(VUMeterChannelLabel.text(for: SurroundChannel(index: 2, role: .center)), "C")
        XCTAssertEqual(VUMeterChannelLabel.text(for: SurroundChannel(index: 3, role: .lfe)), "LFE")
        XCTAssertEqual(VUMeterChannelLabel.text(for: SurroundChannel(index: 0, role: .discrete(0))), "1")
        XCTAssertEqual(VUMeterChannelLabel.text(for: SurroundChannel(index: 29, role: .discrete(29))), "30")
    }

    func testRendererMeterDisplayAlwaysUsesFullThirtyOneChannelSurface() {
        let scene = RendererMatrixBuilder.sceneModel(
            for: SurroundLayoutDetector.fallbackLayout(for: 30),
            preset: .sonicSphere30Point1,
            renderMode: .automatic
        )

        XCTAssertEqual(scene.renderMode, .direct30)
        XCTAssertEqual(scene.outputSpeakers.count, 31)

        let channels = RendererMeterDisplayModel.channels(for: scene)
        XCTAssertEqual(channels.count, 31)
        XCTAssertEqual(channels.last?.role, .lfe)

        let levels = RendererMeterDisplayModel.levels(
            for: scene,
            sourceLevels: Array(repeating: 0.5, count: scene.matrix.inputCount)
        )
        XCTAssertEqual(levels.count, 31)
        XCTAssertGreaterThan(levels.prefix(30).max() ?? 0, 0)
        XCTAssertEqual(levels[30], 0)
    }

    @MainActor
    func testMonitorMeterStoreRemainsStereoWhenRendererOutputIsNone() {
        let model = OrbisonicViewModel()

        model.selectNoRendererOutput()

        XCTAssertEqual(model.monitorChannelWalkCount, 2)
        XCTAssertEqual(model.monitorMeterStore.channelMeters.count, 2)
        XCTAssertEqual(
            model.monitorMeterStore.channelMeters.map { VUMeterChannelLabel.text(for: $0.channel) },
            ["L", "R"]
        )
    }

    func testMonitorMeterDisplayFallsBackToSourceWhenTapIsSilent() {
        let levels = MonitorMeterDisplayModel.levels(
            tappedLevels: [0, 0],
            sourceLevels: [0.64, 0.58],
            channelCount: 2
        )

        XCTAssertEqual(levels, [0.64, 0.58])
    }

    func testMonitorMeterDisplayPrefersActiveTapLevels() {
        let levels = MonitorMeterDisplayModel.levels(
            tappedLevels: [0.21, 0.22],
            sourceLevels: [0.64, 0.58],
            channelCount: 2
        )

        XCTAssertEqual(levels, [0.21, 0.22])
    }

    @MainActor
    func testDiagnosticSpeakerChannelSelectionClampsWithoutRecursion() {
        let model = OrbisonicViewModel()

        model.selectDiagnosticSpeakerChannel(0)
        XCTAssertEqual(model.selectedDiagnosticSpeakerChannel, 1)

        model.selectDiagnosticSpeakerChannel(32)
        XCTAssertEqual(model.selectedDiagnosticSpeakerChannel, 31)

        model.selectDiagnosticSpeakerChannel(12)
        XCTAssertEqual(model.selectedDiagnosticSpeakerChannel, 12)
    }
}
