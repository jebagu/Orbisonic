import AudioContracts
import AudioCore
import XCTest

final class AppleSpatialHeadphoneMonitorTests: XCTestCase {
    private let tolerance: Float = 0.000_001

    func testAppleSpatialHeadphoneMonitorDefaultsDisabled() {
        let options = AppleSpatialHeadphoneOptions()
        XCTAssertFalse(options.isEnabled)
        XCTAssertTrue(options.preferHRTFHQ)
        XCTAssertTrue(options.enableHeadTrackingWhenAvailable)
        XCTAssertEqual(options.lfePolicy, .omitReferenceLFE)
        XCTAssertTrue(options.requiresHeadphones)
    }

    func testAppleSpatialHeadphonesUnavailableForDante() {
        let capability = AppleSpatialRouteClassifier().capability(
            route: route(name: "Dante Virtual Soundcard", manufacturer: "Audinate", transport: "Virtual", risk: .preferredDante),
            sessionSampleRate: .rate48000,
            options: .enabledDefault
        )

        XCTAssertEqual(capability, .unsupportedBecauseDanteRoute)
    }

    func testAppleSpatialHeadphonesUnavailableForBuiltInSpeakers() {
        let capability = AppleSpatialRouteClassifier().capability(
            route: route(name: "MacBook Pro Speakers", transport: "Built-In"),
            sessionSampleRate: .rate48000,
            options: .enabledDefault
        )

        XCTAssertEqual(capability, .unsupportedBecauseBuiltInSpeakers)
    }

    func testAppleSpatialHeadphonesModuleIsDisabledForAirPodsLikeRoute() {
        let status = AppleSpatialHeadphoneMonitor().status(
            mode: .appleSpatialHeadphones,
            options: .enabledDefault,
            route: route(name: "AirPods Pro", manufacturer: "Apple", transport: "Bluetooth"),
            sessionSampleRate: .rate48000,
            liveDesktopBranchConnected: false
        )

        XCTAssertEqual(status.mode, .referenceStereo)
        XCTAssertEqual(status.capability, .validationOnly)
        XCTAssertFalse(status.isActive)
        XCTAssertFalse(status.isPendingRestart)
        XCTAssertTrue(status.userVisibleMessage.contains("disabled"))
    }

    func testAppleSpatialHeadphonesRejectsSampleRateMismatch() {
        let capability = AppleSpatialRouteClassifier().capability(
            route: route(name: "AirPods Max", transport: "Bluetooth", sampleRate: .rate44100),
            sessionSampleRate: .rate48000,
            options: .enabledDefault
        )

        XCTAssertEqual(capability, .unsupportedBecauseSessionSampleRateMismatch)
    }

    func testAppleSpatialHeadphonesPreservesDanteOutputHash() throws {
        let plan = try makePlan()
        let before = try renderDanteHash(plan: plan)

        _ = AppleSpatialHeadphoneMonitor().status(
            mode: .appleSpatialHeadphones,
            options: .enabledDefault,
            route: route(name: "AirPods Pro", manufacturer: "Apple", transport: "Bluetooth"),
            sessionSampleRate: .rate48000,
            liveDesktopBranchConnected: false
        )

        let after = try renderDanteHash(plan: plan)
        XCTAssertEqual(before, after)
    }

    func testAppleSpatialHeadphonesChangesOnlyDesktopMonitorMode() async throws {
        let control = AudioControl()
        let before = try XCTUnwrap(control.latestGraphAudit())

        let status = try await control.setDesktopMonitorMode(.appleSpatialHeadphones)
        let after = try XCTUnwrap(control.latestGraphAudit())

        XCTAssertEqual(status.mode, .referenceStereo)
        XCTAssertEqual(before.danteOutputGain, after.danteOutputGain)
        XCTAssertEqual(before.danteOutputEnabled, after.danteOutputEnabled)
        XCTAssertEqual(before.renderMode, after.renderMode)
    }

    func testAppleSpatialSpeakerPositionMapMapsKnownRoles() {
        let layout = AudioChannelLayoutDescriptor(
            name: "known roles",
            roles: [.frontLeft, .frontRight, .center, .sideLeft, .sideRight, .rearLeft, .rearRight, .topMiddleCenter]
        )
        let positions = AppleSpatialSpeakerPositionMap.positions(for: layout)

        XCTAssertEqual(positions.count, layout.channelCount)
        XCTAssertLessThan(positions[0].x, 0)
        XCTAssertGreaterThan(positions[1].x, 0)
        XCTAssertEqual(positions[2].x, 0, accuracy: tolerance)
        XCTAssertLessThan(positions[2].z, 0)
        XCTAssertLessThan(positions[3].x, 0)
        XCTAssertGreaterThan(positions[4].x, 0)
        XCTAssertGreaterThan(positions[7].y, 0)
    }

    func testAppleSpatialSpeakerPositionMapOmitsLFEByDefault() {
        let positions = AppleSpatialSpeakerPositionMap.positions(for: .surround51)
        let lfe = positions.first { $0.role == .lfe }

        XCTAssertEqual(lfe?.isOmitted, true)
        XCTAssertEqual(lfe?.x, 0)
        XCTAssertEqual(lfe?.y, 0)
        XCTAssertEqual(lfe?.z, 0)
    }

    func testAppleSpatialGraphDoesNotExposeAVAudioNodesToUI() throws {
        let source = try String(contentsOf: packageRoot().appendingPathComponent("Sources/AudioContracts/AudioContracts.swift"))
        let forbidden = [
            "AVAudioEngine",
            "AVAudioEnvironmentNode",
            "AVAudioNode",
            "AudioUnit",
            "AudioDeviceID",
            "AudioBufferList",
            "UnsafeMutablePointer"
        ]
        for token in forbidden {
            XCTAssertFalse(source.contains(token), "\(token) must not appear in AudioContracts.")
        }
    }

    func testAppleSpatialModeStatusIsValueOnly() {
        let status = DesktopMonitorModeStatus(
            mode: .appleSpatialHeadphones,
            isActive: false,
            isPendingRestart: true,
            capability: .supported,
            userVisibleMessage: "pending",
            headTrackingStatus: .unavailable(reason: "test"),
            effectiveOutputRouteName: "AirPods Pro",
            sessionSampleRate: .rate48000
        )

        XCTAssertEqual(status.mode, .appleSpatialHeadphones)
        XCTAssertTrue(status.isPendingRestart)
        XCTAssertEqual(status.effectiveOutputRouteName, "AirPods Pro")
    }

    func testVUConsumerCannotAffectAppleSpatialAudio() throws {
        let plan = try makePlan()
        let baseDante = try renderDanteHash(plan: plan)
        let baseDesktop = try renderDesktopHash(plan: plan)

        let meterBus = MeterCopyBus(maxQueuedBlockCount: 1)
        let source = try sourceBlock(for: plan)
        let desktop = try renderDesktopBlock(plan: plan, source: source)
        let dante = try renderDanteBlock(plan: plan, source: source)
        _ = meterBus.submit(
            copyPoint: .inputSourceBus,
            block: source,
            sessionVersion: plan.version,
            sourceID: plan.source.id,
            framePosition: 0
        )
        _ = meterBus.submit(
            copyPoint: .desktopPostRenderPreOutputGain,
            block: desktop,
            sessionVersion: plan.version,
            sourceID: plan.source.id,
            framePosition: 1
        )
        _ = meterBus.submit(
            copyPoint: .dantePostRenderPreOutputGain,
            block: dante,
            sessionVersion: plan.version,
            sourceID: plan.source.id,
            framePosition: 2
        )

        XCTAssertEqual(baseDante, try renderDanteHash(plan: plan))
        XCTAssertEqual(baseDesktop, try renderDesktopHash(plan: plan))
    }

    private func route(
        name: String,
        manufacturer: String? = nil,
        transport: String? = nil,
        sampleRate: AudioSampleRate = .rate48000,
        channelCount: Int = 2,
        risk: OutputRouteRisk = .safe
    ) -> OutputRouteDescriptor {
        OutputRouteDescriptor(
            id: name,
            uid: name,
            name: name,
            manufacturer: manufacturer,
            transportName: transport,
            outputChannelCount: channelCount,
            nominalSampleRate: sampleRate,
            isAvailable: true,
            risk: risk
        )
    }

    private func makePlan() throws -> RenderGraphPlan {
        let session = AudioSessionFormat(
            sampleRate: .rate48000,
            maxFramesPerBlock: 8,
            dante: DanteOutputFormat(physicalChannelCount: 32, sampleRate: .rate48000),
            desktop: DesktopOutputFormat(sampleRate: .rate48000)
        )
        let source = SourceDescriptor(
            id: "direct31-fixture",
            kind: .testTone,
            sampleRate: .rate48000,
            channelCount: 31,
            layout: .direct31
        )
        return try RenderGraphPlanner().makeValidatedPlan(
            RenderGraphPlanRequest(
                version: 1,
                sessionFormat: session,
                source: source,
                renderMode: .direct31,
                createdAtUnixTimeSeconds: nil
            )
        )
    }

    private func sourceBlock(for plan: RenderGraphPlan) throws -> CanonicalAudioBlock {
        let block = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: plan.sessionFormat.sampleRate,
                channelCount: plan.source.channelCount,
                frameCount: 2,
                layout: plan.source.layout
            )
        )
        try block.setSample(1, channel: 0, frame: 0)
        try block.setSample(0.5, channel: 30, frame: 1)
        return block
    }

    private func renderDesktopBlock(plan: RenderGraphPlan, source: CanonicalAudioBlock) throws -> CanonicalAudioBlock {
        let desktop = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: plan.sessionFormat.sampleRate,
                channelCount: 2,
                frameCount: source.frameCount,
                layout: .stereo
            )
        )
        try DesktopMonitorRenderer(plan: plan.desktopDownmix, gainPlan: plan.gainPlan)
            .process(source: source, destination: desktop, frameCount: source.frameCount)
        return desktop
    }

    private func renderDanteBlock(plan: RenderGraphPlan, source: CanonicalAudioBlock) throws -> CanonicalAudioBlock {
        let dante = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: plan.sessionFormat.sampleRate,
                channelCount: plan.danteRenderer.physicalOutputCount,
                frameCount: source.frameCount,
                layout: .discrete(count: plan.danteRenderer.physicalOutputCount)
            )
        )
        try DanteSonicSphereRenderer(plan: plan.danteRenderer, gainPlan: plan.gainPlan)
            .process(source: source, destination: dante, frameCount: source.frameCount)
        return dante
    }

    private func renderDesktopHash(plan: RenderGraphPlan) throws -> UInt64 {
        let source = try sourceBlock(for: plan)
        return hash(block: try renderDesktopBlock(plan: plan, source: source))
    }

    private func renderDanteHash(plan: RenderGraphPlan) throws -> UInt64 {
        let source = try sourceBlock(for: plan)
        return hash(block: try renderDanteBlock(plan: plan, source: source))
    }

    private func hash(block: CanonicalAudioBlock) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for channel in 0..<block.channelCount {
            for sample in block.channelSamplesCopy(channel: channel) {
                hash ^= UInt64(sample.bitPattern)
                hash &*= 0x1000_0000_01b3
            }
        }
        return hash
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
