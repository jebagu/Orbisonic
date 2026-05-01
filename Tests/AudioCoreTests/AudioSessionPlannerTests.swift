import AudioContracts
import AudioCore
import XCTest

final class AudioSessionPlannerTests: XCTestCase {
    func testDefaultProductionSessionPlansAtFortyEightKilohertz() {
        let plan = planner.plan(
            AudioSessionPlanRequest(
                desiredDesktopRoute: desktopRoute(rate: .rate48000),
                desiredDanteRoute: danteCapability(rate: .rate48000, channels: 31)
            )
        )

        XCTAssertTrue(plan.isAccepted, plan.validationMessages.joined(separator: "\n"))
        XCTAssertEqual(plan.plannedSessionFormat?.sampleRate, .rate48000)
    }

    func testPlannerRejectsNonFiniteAndNonPositiveSampleRates() {
        for rawRate in [Double.nan, -48_000, 0] {
            let plan = planner.plan(
                AudioSessionPlanRequest(
                    desiredSampleRateHertz: rawRate,
                    desiredDesktopRoute: desktopRoute(rate: .rate48000),
                    desiredDanteRoute: danteCapability(rate: .rate48000, channels: 31)
                )
            )

            XCTAssertFalse(plan.isAccepted, "\(rawRate)")
            XCTAssertTrue(
                plan.validationErrors.contains(.invalidRenderGraphPlan("Requested sample rate must be positive and finite.")),
                "\(rawRate)"
            )
        }
    }

    func testThirtyOneChannelDanteRouteWithThirtyTwoPhysicalChannelsReservesChannelThirtyTwo() {
        let plan = planner.plan(
            AudioSessionPlanRequest(
                desiredDesktopRoute: desktopRoute(rate: .rate48000),
                desiredDanteRoute: danteCapability(rate: .rate48000, channels: 32)
            )
        )

        XCTAssertTrue(plan.isAccepted, plan.validationMessages.joined(separator: "\n"))
        XCTAssertEqual(plan.selectedDanteOutputFormat?.logicalChannelCount, 31)
        XCTAssertEqual(plan.selectedDanteOutputFormat?.physicalChannelCount, 32)
        XCTAssertEqual(plan.selectedDanteOutputFormat?.isChannel32Reserved, true)
    }

    func testThirtyOneChannelDanteRouteRejectsSixteenChannelRoute() {
        let plan = planner.plan(
            AudioSessionPlanRequest(
                desiredDesktopRoute: desktopRoute(rate: .rate48000),
                desiredDanteRoute: danteCapability(rate: .rate48000, channels: 16)
            )
        )

        XCTAssertFalse(plan.isAccepted)
        XCTAssertTrue(plan.validationErrors.contains(.danteRouteInsufficientChannels(required: 31, actual: 16)))
    }

    func testThirtyOneChannelDanteRouteAcceptsFortyEightKilohertzWhenOutputChannelCountIsEnough() {
        let plan = planner.plan(
            AudioSessionPlanRequest(
                desiredSampleRate: .rate48000,
                desiredDesktopRoute: desktopRoute(rate: .rate48000),
                desiredDanteRoute: danteCapability(rate: .rate48000, channels: 32)
            )
        )

        XCTAssertTrue(plan.isAccepted, plan.validationMessages.joined(separator: "\n"))
    }

    func testThirtyOneChannelDanteRouteAcceptsNinetySixKilohertzWhenOutputChannelCountIsEnough() {
        let plan = planner.plan(
            AudioSessionPlanRequest(
                desiredSampleRate: .rate96000,
                desiredDesktopRoute: desktopRoute(rate: .rate96000),
                desiredDanteRoute: danteCapability(rate: .rate96000, channels: 31)
            )
        )

        XCTAssertTrue(plan.isAccepted, plan.validationMessages.joined(separator: "\n"))
    }

    func testDanteRouteSampleRateMustMatchRequestedSessionSampleRate() {
        let plan = planner.plan(
            AudioSessionPlanRequest(
                desiredSampleRate: .rate96000,
                desiredDesktopRoute: desktopRoute(rate: .rate96000),
                desiredDanteRoute: danteCapability(rate: .rate48000, channels: 31)
            )
        )

        XCTAssertFalse(plan.isAccepted)
        XCTAssertTrue(
            plan.validationErrors.contains {
                if case .sampleRateMismatch(let expected, _, let context) = $0 {
                    return expected == .rate96000 && context == "Dante supported sample rates"
                }
                return false
            }
        )
    }

    func testThirtyOneChannelDanteRouteRejectsHighRatesForDanteVirtualSoundcard() {
        for rate in [AudioSampleRate.rate176400, .rate192000] {
            let plan = planner.plan(
                AudioSessionPlanRequest(
                    desiredSampleRate: rate,
                    desiredDesktopRoute: desktopRoute(rate: rate),
                    desiredDanteRoute: danteCapability(rate: rate, channels: 32)
                )
            )

            XCTAssertFalse(plan.isAccepted, "\(rate.hertz)")
            XCTAssertTrue(plan.validationErrors.contains(.danteUnsupportedSampleRate(rate)), "\(rate.hertz)")
        }
    }

    func testDesktopRouteMustHaveAtLeastTwoChannels() {
        let plan = planner.plan(
            AudioSessionPlanRequest(
                desiredDesktopRoute: desktopRoute(rate: .rate48000, channels: 1),
                desiredDanteRoute: danteCapability(rate: .rate48000, channels: 31)
            )
        )

        XCTAssertFalse(plan.isAccepted)
        XCTAssertTrue(plan.validationErrors.contains(.desktopRouteInsufficientChannels(required: 2, actual: 1)))
    }

    func testDesktopRouteSampleRateMustMatchSessionSampleRate() {
        let plan = planner.plan(
            AudioSessionPlanRequest(
                desiredSampleRate: .rate48000,
                desiredDesktopRoute: desktopRoute(rate: .rate44100),
                desiredDanteRoute: danteCapability(rate: .rate48000, channels: 31)
            )
        )

        XCTAssertFalse(plan.isAccepted)
        XCTAssertTrue(
            plan.validationErrors.contains {
                if case .sampleRateMismatch(let expected, let actual, let context) = $0 {
                    return expected == .rate48000 && actual == .rate44100 && context == "desktop route"
                }
                return false
            }
        )
    }

    func testSourceSampleRateMismatchRejectsProductionSession() {
        let source = SourceDescriptor(
            id: "roon",
            kind: .roon,
            sampleRate: .rate44100,
            channelCount: 2,
            layout: .stereo
        )
        let plan = planner.plan(
            AudioSessionPlanRequest(
                desiredSampleRate: .rate48000,
                desiredDesktopRoute: desktopRoute(rate: .rate48000),
                desiredDanteRoute: danteCapability(rate: .rate48000, channels: 31),
                desiredSource: source
            )
        )

        XCTAssertFalse(plan.isAccepted)
        XCTAssertEqual(plan.conversionLedger.validationStatus, .invalid([.productionSampleRateConversionForbidden]))
    }

    func testSampleRateChangeRequiresStopRebuild() {
        let decision = StopRebuildPolicy.decision(
            for: .sessionSampleRate(current: .rate48000, requested: .rate96000)
        )

        XCTAssertTrue(decision.requiresStopAndRebuild)
        XCTAssertFalse(decision.blocksChange)
    }

    func testGainChangeDoesNotRequireStopRebuild() {
        XCTAssertFalse(StopRebuildPolicy.decision(for: .desktopMonitorGain).requiresStopAndRebuild)
        XCTAssertFalse(StopRebuildPolicy.decision(for: .danteOutputGain).requiresStopAndRebuild)
    }

    func testVUDisplayChangesCannotCauseRebuild() {
        let decision = StopRebuildPolicy.decision(for: .vuDisplay)

        XCTAssertFalse(decision.requiresStopAndRebuild)
        XCTAssertFalse(decision.blocksChange)
    }

    func testConversionLedgerFlagsProductionSRCAsInvalid() {
        let source = SourceDescriptor(
            id: "local-asset",
            kind: .localFile,
            sampleRate: .rate44100,
            channelCount: 2,
            layout: .stereo
        )
        let plan = planner.plan(
            AudioSessionPlanRequest(
                desiredSampleRate: .rate48000,
                desiredDesktopRoute: desktopRoute(rate: .rate48000),
                desiredDanteRoute: danteCapability(rate: .rate48000, channels: 31),
                desiredSource: source,
                sourceReadiness: .requiresManagedImport
            )
        )

        XCTAssertFalse(plan.isAccepted)
        XCTAssertTrue(plan.conversionLedger.containsProductionSampleRateConversion)
        XCTAssertEqual(plan.conversionLedger.validationStatus, .invalid([.productionSampleRateConversionForbidden]))
    }

    func testRouteCapabilityValidatorMapsRouteRiskAndDanteCapability() {
        let validator = RouteCapabilityValidator()
        let loopback = validator.outputRouteDescriptor(
            from: RouteCapabilityInput(
                id: "loopback",
                uid: "audio.orbisonic.rooninput.device",
                name: "Orbisonic Roon Input",
                manufacturer: "Orbisonic",
                transportName: "Virtual",
                outputChannelCount: 64,
                nominalSampleRate: .rate48000
            )
        )
        let blackHole = validator.outputRouteDescriptor(
            from: RouteCapabilityInput(
                id: "blackhole",
                name: "BlackHole 64ch",
                manufacturer: "Existential Audio",
                transportName: "Virtual",
                outputChannelCount: 64,
                nominalSampleRate: .rate48000
            )
        )
        let dante = validator.outputRouteDescriptor(
            from: RouteCapabilityInput(
                id: "dante",
                name: "Dante Virtual Soundcard",
                manufacturer: "Audinate",
                transportName: "Virtual",
                outputChannelCount: 32,
                nominalSampleRate: .rate48000
            )
        )
        let virtual = validator.outputRouteDescriptor(
            from: RouteCapabilityInput(
                id: "virtual",
                name: "Some Virtual Output",
                transportName: "Virtual",
                outputChannelCount: 2,
                nominalSampleRate: .rate48000
            )
        )

        XCTAssertEqual(loopback.risk, .feedbackLoopRisk)
        XCTAssertEqual(blackHole.risk, .feedbackLoopRisk)
        XCTAssertEqual(dante.risk, .preferredDante)
        XCTAssertEqual(virtual.risk, .virtualOutputRisk)
    }

    private let planner = AudioSessionPlanner()

    private func desktopRoute(
        rate: AudioSampleRate,
        channels: Int = 2,
        id: String = "desktop"
    ) -> OutputRouteDescriptor {
        OutputRouteDescriptor(
            id: id,
            uid: id,
            name: "Desktop Monitor",
            manufacturer: "Hardware",
            transportName: "Built-In",
            outputChannelCount: channels,
            nominalSampleRate: rate,
            isAvailable: true,
            risk: .safe
        )
    }

    private func danteCapability(
        rate: AudioSampleRate,
        channels: Int,
        id: String = "dante"
    ) -> DanteRouteCapability {
        let route = OutputRouteDescriptor(
            id: id,
            uid: id,
            name: "Dante Virtual Soundcard",
            manufacturer: "Audinate",
            transportName: "Virtual",
            outputChannelCount: channels,
            nominalSampleRate: rate,
            isAvailable: true,
            risk: .preferredDante
        )
        return DanteRouteCapability(
            route: route,
            supportedSampleRates: [rate],
            currentNominalSampleRate: rate,
            outputChannelCount: channels
        )
    }
}
