import XCTest
@testable import Orbisonic

final class VURoutingViewTests: XCTestCase {
    func testStageTabsUseRequestedOrderAndLabels() {
        XCTAssertEqual(
            StageTab.allCases.map(\.rawValue),
            [
                "Input",
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

    func testLegacySonicSphereMeterUsesAnalysisLabelNotDanteOutputLabel() throws {
        let source = try String(contentsOf: packageRoot().appendingPathComponent("Sources/Orbisonic/ContentView.swift"))

        XCTAssertTrue(source.contains("Sonic Sphere Analysis Meter"))
        XCTAssertFalse(source.contains("Sonic Sphere VU meter"))
        XCTAssertFalse(source.contains("Dante Output Meter"))
    }

    func testActiveVUMeterUsesAudioMotionSparkleStyles() throws {
        let source = try String(contentsOf: packageRoot().appendingPathComponent("Sources/Orbisonic/ContentView.swift"))

        XCTAssertTrue(source.contains("case .analyzerVU:\n            stageViewport { analyzerVUTab }"))
        XCTAssertFalse(source.contains("case .analyzerVU:\n            stageViewport { vuMeterTab }"))
        XCTAssertTrue(source.contains("case sparkles = \"Sparkles\""))
        XCTAssertTrue(source.contains("case blockyPixelSparkles = \"Blocky Pixel Sparkles\""))
        XCTAssertTrue(source.contains("drawSparkleBars("))
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
    func testLocalMonitorDiagnosticMetersUseLeftOnlyForFirstStereoChannel() {
        let model = OrbisonicViewModel()

        model.applyLocalMonitorDiagnosticMeterLevels(index: 0)

        XCTAssertEqual(model.monitorChannelWalkCount, 2)
        XCTAssertEqual(model.monitorMeterStore.channelMeters.map(\.level), [0.86, 0])
        XCTAssertTrue(model.rendererMeterStore.channelMeters.allSatisfy { $0.level == 0 })
    }

    @MainActor
    func testLocalMonitorDiagnosticMetersUseRightOnlyForSecondStereoChannel() {
        let model = OrbisonicViewModel()

        model.applyLocalMonitorDiagnosticMeterLevels(index: 1)

        XCTAssertEqual(model.monitorChannelWalkCount, 2)
        XCTAssertEqual(model.monitorMeterStore.channelMeters.map(\.level), [0, 0.86])
        XCTAssertTrue(model.rendererMeterStore.channelMeters.allSatisfy { $0.level == 0 })
    }

    func testLocalMonitorDiagnosticPlaybackNeverUsesDownmix() {
        let options = DiagnosticChannelPlaybackPolicy.options(
            targetsRenderer: false,
            rendererMonitorDownmixAvailable: true,
            rendererUsesNormalMonitor: true
        )

        XCTAssertEqual(
            options,
            DiagnosticChannelPlaybackOptions(
                monitorDownmix: false,
                primaryOutputEnabled: true
            )
        )
    }

    func testRendererDiagnosticPlaybackUsesSingleNormalMonitorPath() {
        let options = DiagnosticChannelPlaybackPolicy.options(
            targetsRenderer: true,
            rendererMonitorDownmixAvailable: true,
            rendererUsesNormalMonitor: false
        )

        XCTAssertEqual(
            options,
            DiagnosticChannelPlaybackOptions(
                monitorDownmix: false,
                primaryOutputEnabled: true
            )
        )
    }

    @MainActor
    func testRendererDiagnosticMonitorMetersMirrorFirstActiveChannel() {
        let model = OrbisonicViewModel()

        model.applyRendererDiagnosticMeterLevels(index: 0, monitorDownmixActive: true)

        let rendererLevels = model.rendererMeterStore.channelMeters.map(\.level)
        let monitorLevels = model.monitorMeterStore.channelMeters.map(\.level)
        XCTAssertEqual(rendererLevels[0], 0.86, accuracy: 0.001)
        XCTAssertEqual(monitorLevels.count, 2)
        XCTAssertEqual(monitorLevels[0], rendererLevels[0], accuracy: 0.001)
        XCTAssertEqual(monitorLevels[1], rendererLevels[0], accuracy: 0.001)
    }

    @MainActor
    func testRendererDiagnosticMonitorMetersMirrorLaterActiveChannel() {
        let model = OrbisonicViewModel()

        model.applyRendererDiagnosticMeterLevels(index: 11, monitorDownmixActive: true)

        let rendererLevels = model.rendererMeterStore.channelMeters.map(\.level)
        let monitorLevels = model.monitorMeterStore.channelMeters.map(\.level)
        XCTAssertEqual(rendererLevels[11], 0.86, accuracy: 0.001)
        XCTAssertEqual(monitorLevels.count, 2)
        XCTAssertEqual(monitorLevels[0], rendererLevels[11], accuracy: 0.001)
        XCTAssertEqual(monitorLevels[1], rendererLevels[11], accuracy: 0.001)
    }

    @MainActor
    func testRendererDiagnosticMonitorMetersResetWhenDownmixUnavailable() {
        let model = OrbisonicViewModel()
        model.monitorMeterStore.configureIfNeeded(channels: SurroundLayoutDetector.fallbackLayout(for: model.monitorChannelWalkCount).channels)
        model.monitorMeterStore.update(with: [0.5, 0.5])

        model.applyRendererDiagnosticMeterLevels(index: 0, monitorDownmixActive: false)

        XCTAssertEqual(model.monitorMeterStore.channelMeters.map(\.level), [0, 0])
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

    @MainActor
    func testDiagnosticToneActivitySummaryIsIdleByDefault() {
        let model = OrbisonicViewModel()

        XCTAssertEqual(model.diagnosticToneActivitySummary, .idle)
    }

    @MainActor
    func testDiagnosticToneActivitySummaryReportsActiveChannel() {
        let model = OrbisonicViewModel()
        model.isTestTonePlaying = true
        model.activeDiagnosticWalkTitle = "Test Tone"
        model.activeDiagnosticChannelIndex = 11
        model.activeDiagnosticChannelCount = 31
        model.testToneStatus = "Playing channel 12 on Output 2 Renderer."

        let summary = model.diagnosticToneActivitySummary

        XCTAssertTrue(summary.isActive)
        XCTAssertEqual(summary.headline, "Test Tone 12 / 31")
        XCTAssertEqual(summary.detail, "Playing channel 12 on Output 2 Renderer.")
    }

    @MainActor
    func testDiagnosticToneActivitySummaryNamesSelectedPipelineTone() {
        let model = OrbisonicViewModel()
        model.isTestTonePlaying = true
        model.selectedTestTonePoint = .rendererFrontLeft
        model.testToneStatus = "Playing Renderer: Front Left until stopped."

        let summary = model.diagnosticToneActivitySummary

        XCTAssertTrue(summary.isActive)
        XCTAssertEqual(summary.headline, "Renderer: Front Left")
        XCTAssertEqual(summary.detail, "Playing Renderer: Front Left until stopped.")
    }

    @MainActor
    func testStopTestToneClearsToneStateAndMeters() {
        let model = OrbisonicViewModel()
        model.isTestTonePlaying = true
        model.isDiagnosticSequencePlaying = true
        model.meterStore.configure(channels: [SurroundChannel(index: 0, role: .frontLeft)])
        model.meterStore.update(with: [0.82])
        model.monitorMeterStore.configureIfNeeded(channels: SurroundLayoutDetector.fallbackLayout(for: model.monitorChannelWalkCount).channels)
        model.monitorMeterStore.update(with: [0.82, 0.82])
        model.rendererMeterStore.configureIfNeeded(channels: [SurroundChannel(index: 0, role: .frontLeft)])
        model.rendererMeterStore.update(with: [0.82])

        model.stopTestTone()

        XCTAssertFalse(model.isTestTonePlaying)
        XCTAssertFalse(model.isDiagnosticSequencePlaying)
        XCTAssertFalse(model.isDiagnosticTransitioning)
        XCTAssertEqual(model.meterStore.channelMeters.map(\.level), [0])
        XCTAssertEqual(model.monitorMeterStore.channelMeters.map(\.level), [0, 0])
        XCTAssertEqual(model.rendererMeterStore.channelMeters.map(\.level), [0])
        XCTAssertEqual(model.testToneStatus, "Diagnostic tone stopped.")
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
