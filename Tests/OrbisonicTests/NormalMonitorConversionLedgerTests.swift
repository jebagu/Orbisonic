import XCTest
@testable import Orbisonic

final class NormalMonitorConversionLedgerTests: XCTestCase {
    func testLocalLedgerCleanWhenSourceEngineAndOutputRatesMatch() {
        let fortyFourOne = NormalMonitorConversionLedger.localFile(
            sourceSampleRate: 44_100,
            engineSampleRate: 44_100,
            outputHardwareSampleRate: 44_100
        )
        XCTAssertEqual(fortyFourOne.sourceSampleRate, 44_100)
        XCTAssertNil(fortyFourOne.inputRouteSampleRate)
        XCTAssertEqual(fortyFourOne.engineSampleRate, 44_100)
        XCTAssertEqual(fortyFourOne.monitorRenderSampleRate, 44_100)
        XCTAssertEqual(fortyFourOne.outputHardwareSampleRate, 44_100)
        XCTAssertEqual(fortyFourOne.knownInternalSRCCount, 0)
        XCTAssertFalse(fortyFourOne.suspectedExternalSRC)
        XCTAssertFalse(fortyFourOne.suspectedFinalBoundarySRC)
        XCTAssertTrue(fortyFourOne.warningDescriptions.isEmpty)

        let ninetySix = NormalMonitorConversionLedger.localFile(
            sourceSampleRate: 96_000,
            engineSampleRate: 96_000,
            outputHardwareSampleRate: 96_000
        )
        XCTAssertTrue(ninetySix.warningDescriptions.isEmpty)
        XCTAssertFalse(ninetySix.suspectedExternalSRC)
        XCTAssertFalse(ninetySix.suspectedFinalBoundarySRC)
    }

    func testLocalLedgerWarnsWhenOutputHardwareRateDiffers() {
        let ledger = NormalMonitorConversionLedger.localFile(
            sourceSampleRate: 44_100,
            engineSampleRate: 44_100,
            outputHardwareSampleRate: 48_000
        )

        XCTAssertEqual(ledger.sourceSampleRate, 44_100)
        XCTAssertEqual(ledger.monitorRenderSampleRate, 44_100)
        XCTAssertEqual(ledger.outputHardwareSampleRate, 48_000)
        XCTAssertEqual(ledger.knownInternalSRCCount, 0)
        XCTAssertFalse(ledger.suspectedExternalSRC)
        XCTAssertTrue(ledger.suspectedFinalBoundarySRC)
        XCTAssertEqual(ledger.warningDescriptions.count, 1)
        XCTAssertTrue(ledger.warningDescriptions[0].localizedCaseInsensitiveContains("final boundary SRC"))
    }

    func testLiveRoonLedgerCleanWhenMetadataAndInputRateMatch() {
        let ledger = NormalMonitorConversionLedger.liveLoopback(
            sourceSampleRate: 44_100,
            inputRouteSampleRate: 44_100,
            engineSampleRate: 44_100,
            outputHardwareSampleRate: 44_100,
            sourceDescription: "Roon"
        )

        XCTAssertEqual(ledger.sourceSampleRate, 44_100)
        XCTAssertEqual(ledger.inputRouteSampleRate, 44_100)
        XCTAssertEqual(ledger.engineSampleRate, 44_100)
        XCTAssertEqual(ledger.monitorRenderSampleRate, 44_100)
        XCTAssertEqual(ledger.outputHardwareSampleRate, 44_100)
        XCTAssertEqual(ledger.knownInternalSRCCount, 0)
        XCTAssertFalse(ledger.suspectedExternalSRC)
        XCTAssertFalse(ledger.suspectedFinalBoundarySRC)
        XCTAssertTrue(ledger.warningDescriptions.isEmpty)
    }

    func testLiveRoonLedgerWarnsWhenMetadataAndInputRateMismatch() {
        let ledger = NormalMonitorConversionLedger.liveLoopback(
            sourceSampleRate: 44_100,
            inputRouteSampleRate: 48_000,
            engineSampleRate: 48_000,
            outputHardwareSampleRate: 48_000,
            sourceDescription: "Roon"
        )

        XCTAssertEqual(ledger.sourceSampleRate, 44_100)
        XCTAssertEqual(ledger.inputRouteSampleRate, 48_000)
        XCTAssertEqual(ledger.monitorRenderSampleRate, 48_000)
        XCTAssertEqual(ledger.outputHardwareSampleRate, 48_000)
        XCTAssertEqual(ledger.knownInternalSRCCount, 0)
        XCTAssertTrue(ledger.suspectedExternalSRC)
        XCTAssertFalse(ledger.suspectedFinalBoundarySRC)
        XCTAssertEqual(ledger.warningDescriptions.count, 1)
        XCTAssertTrue(ledger.warningDescriptions[0].contains("Roon"))
        XCTAssertTrue(ledger.warningDescriptions[0].localizedCaseInsensitiveContains("upstream or loopback SRC"))
    }

    func testLiveUnknownSourceRateIsNotMarkedClean() {
        let spotify = NormalMonitorConversionLedger.liveLoopback(
            sourceSampleRate: nil,
            inputRouteSampleRate: 48_000,
            engineSampleRate: 48_000,
            outputHardwareSampleRate: 48_000,
            sourceDescription: "Spotify"
        )
        let aux = NormalMonitorConversionLedger.liveLoopback(
            sourceSampleRate: nil,
            inputRouteSampleRate: 48_000,
            engineSampleRate: 48_000,
            outputHardwareSampleRate: 48_000,
            sourceDescription: "Aux"
        )

        for ledger in [spotify, aux] {
            XCTAssertNil(ledger.sourceSampleRate)
            XCTAssertEqual(ledger.inputRouteSampleRate, 48_000)
            XCTAssertEqual(ledger.knownInternalSRCCount, 0)
            XCTAssertTrue(ledger.suspectedExternalSRC)
            XCTAssertFalse(ledger.suspectedFinalBoundarySRC)
            XCTAssertFalse(ledger.warningDescriptions.isEmpty)
            XCTAssertTrue(ledger.warningDescriptions[0].localizedCaseInsensitiveContains("unknown"))
        }
    }

    func testLedgerCountsOnlyIntentionalInternalSRC() {
        let suspectedOnly = NormalMonitorConversionLedger.localFile(
            sourceSampleRate: 44_100,
            engineSampleRate: 48_000,
            outputHardwareSampleRate: 48_000,
            monitorRenderSampleRate: 44_100
        )
        XCTAssertFalse(suspectedOnly.warningDescriptions.isEmpty)
        XCTAssertEqual(suspectedOnly.knownInternalSRCCount, 0)

        let intentional = NormalMonitorConversionLedger.localFile(
            sourceSampleRate: 44_100,
            engineSampleRate: 48_000,
            outputHardwareSampleRate: 48_000,
            monitorRenderSampleRate: 48_000,
            knownInternalSRCCount: 1
        )
        XCTAssertEqual(intentional.knownInternalSRCCount, 1)
        XCTAssertTrue(intentional.warningDescriptions.contains { $0.localizedCaseInsensitiveContains("AVAudioEngine SRC") })
    }

    func testSampleRateWarningDoesNotChangeNormalMonitorRoute() {
        let warningLedger = mismatchedRoonLedger()
        XCTAssertFalse(warningLedger.warningDescriptions.isEmpty)

        let cleanRoute = NormalMonitorRoutePlanner.route(
            for: .roon,
            sourceLayoutDescription: "Roon 44.1 kHz clean"
        )
        let routeAfterWarning = NormalMonitorRoutePlanner.route(
            for: .roon,
            sourceLayoutDescription: "Roon 44.1 kHz input mismatch"
        )

        assertNormalMonitor(routeAfterWarning)
        XCTAssertEqual(routeAfterWarning.terminalRenderer, cleanRoute.terminalRenderer)
        XCTAssertEqual(routeAfterWarning.outputChannelCount, cleanRoute.outputChannelCount)
    }

    func testSampleRateWarningDoesNotEnableSpatialFallback() {
        let warningLedger = mismatchedRoonLedger()
        XCTAssertTrue(warningLedger.suspectedExternalSRC)

        let route = NormalMonitorRoutePlanner.route(
            for: .roon,
            sourceLayoutDescription: "Roon with sample-rate warning"
        )
        let topology = NormalMonitorGraphTopology.audible(sourceFamily: .liveLoopback)

        assertNormalMonitor(route)
        XCTAssertFalse(route.usesAVAudioEnvironmentNode)
        XCTAssertFalse(route.usesHRTF)
        XCTAssertFalse(route.usesHRTFHQ)
        XCTAssertFalse(route.usesHeadphoneEnvironmentOutput)
        XCTAssertFalse(route.usesPointSourceSpatialPlacement)
        XCTAssertFalse(topology.containsEnvironmentNode)
    }

    func testSampleRateWarningDoesNotEnableDirectSonicSphereOutput() {
        let warningLedger = mismatchedRoonLedger()
        XCTAssertFalse(warningLedger.warningDescriptions.isEmpty)

        let route = NormalMonitorRoutePlanner.route(
            for: .roon,
            sourceLayoutDescription: "Roon with sample-rate warning"
        )
        let topology = NormalMonitorGraphTopology.audible(sourceFamily: .liveLoopback)

        assertNormalMonitor(route)
        XCTAssertFalse(route.usesAudibleDirectSonicSphereMatrix)
        XCTAssertFalse(topology.containsAudibleSonicSphereMatrixNode)
    }

    private func mismatchedRoonLedger() -> NormalMonitorConversionLedger {
        NormalMonitorConversionLedger.liveLoopback(
            sourceSampleRate: 44_100,
            inputRouteSampleRate: 48_000,
            engineSampleRate: 48_000,
            outputHardwareSampleRate: 48_000,
            sourceDescription: "Roon"
        )
    }

    private func assertNormalMonitor(
        _ route: NormalMonitorRouteDescriptor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(route.usesNormalMonitor, file: file, line: line)
        XCTAssertTrue(route.usesStereoDownmix, file: file, line: line)
        XCTAssertEqual(route.outputChannelCount, 2, file: file, line: line)
        XCTAssertEqual(route.terminalRenderer, .normalMonitorStereoDownmixer, file: file, line: line)
        XCTAssertFalse(route.usesAVAudioEnvironmentNode, file: file, line: line)
        XCTAssertFalse(route.usesHRTF, file: file, line: line)
        XCTAssertFalse(route.usesHRTFHQ, file: file, line: line)
        XCTAssertFalse(route.usesHeadphoneEnvironmentOutput, file: file, line: line)
        XCTAssertFalse(route.usesPointSourceSpatialPlacement, file: file, line: line)
        XCTAssertFalse(route.usesAudibleDirectSonicSphereMatrix, file: file, line: line)
        XCTAssertFalse(route.hasDuplicateAudiblePath, file: file, line: line)
    }
}
