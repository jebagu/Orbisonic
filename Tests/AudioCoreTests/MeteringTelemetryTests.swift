import AudioContracts
import AudioCore
import XCTest

final class MeteringTelemetryTests: XCTestCase {
    private let tolerance: Float = 0.000_001

    func testMeterCopyBusCopiesInputWithoutMutatingSource() throws {
        let block = try stereoBlock(left: 1, right: -0.5, frameCount: 4)
        let originalLeft = block.channelSamplesCopy(channel: 0)
        let bus = MeterCopyBus(maxQueuedBlockCount: 2)

        XCTAssertTrue(
            bus.submit(
                copyPoint: .inputSourceBus,
                block: block,
                sessionVersion: 7,
                sourceID: "source",
                framePosition: 4
            )
        )
        try block.setSample(0.25, channel: 0, frame: 0)

        let copy = try XCTUnwrap(bus.drainCopies().first)
        XCTAssertEqual(copy.samplesCopy(channel: 0), originalLeft)
        XCTAssertEqual(block.sample(channel: 0, frame: 0), 0.25, accuracy: tolerance)
    }

    func testMeterCopyBusDropsWhenFullRatherThanBlocking() throws {
        let block = try stereoBlock(left: 1, right: 0, frameCount: 4)
        let bus = MeterCopyBus(maxQueuedBlockCount: 1)

        XCTAssertTrue(bus.submit(copyPoint: .inputSourceBus, block: block, sessionVersion: 1, sourceID: "source", framePosition: 4))
        XCTAssertFalse(bus.submit(copyPoint: .desktopPostRenderPreOutputGain, block: block, sessionVersion: 1, sourceID: "source", framePosition: 4))

        let status = bus.statusSnapshot()
        XCTAssertEqual(status.queuedBlockCount, 1)
        XCTAssertEqual(status.droppedBlockCount, 1)
    }

    func testMeterAccumulatorCalculatesPeakAndRMSForDeterministicSamples() {
        let copied = MeterCopiedBlock(
            copyPoint: .inputSourceBus,
            sampleRate: .defaultProduction,
            layout: .stereo,
            sessionVersion: 1,
            sourceID: "source",
            framePosition: 4,
            samples: [[0.5, -0.5, 0.5, -0.5]]
        )

        let meter = MeterAccumulator().meters(for: copied)[0]

        XCTAssertEqual(meter.peakDBFS, dbFS(0.5), accuracy: 0.0001)
        XCTAssertEqual(meter.rmsDBFS, dbFS(0.5), accuracy: 0.0001)
        XCTAssertFalse(meter.isClipped)
    }

    func testMeterSnapshotExposesNoBuffers() throws {
        let source = try String(
            contentsOf: packageRoot().appendingPathComponent("Sources/AudioContracts/AudioContracts.swift"),
            encoding: .utf8
        )
        let forbiddenSymbols = [
            "AVAudioEngine",
            "AVAudioNode",
            "AudioUnit",
            "AudioDeviceID",
            "AudioBufferList",
            "UnsafeMutablePointer",
            "CanonicalAudioBlock"
        ]

        guard let meterSnapshotRange = source.range(of: "public struct MeterSnapshot") else {
            return XCTFail("MeterSnapshot declaration not found.")
        }
        let meterSnapshotSource = String(source[meterSnapshotRange.lowerBound...])
        let violations = forbiddenSymbols.filter { meterSnapshotSource.contains($0) }
        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    func testVUDisplayCodeForbiddenImportsTestPasses() throws {
        let source = try String(
            contentsOf: packageRoot().appendingPathComponent("Sources/Orbisonic/ContentView.swift"),
            encoding: .utf8
        )
        let forbiddenSymbols = [
            "import AVFAudio",
            "import CoreAudio",
            "import AudioToolbox",
            "import AudioUnit",
            "AVAudioEngine",
            "AVAudioNode",
            "AudioDeviceID",
            "AudioBufferList",
            "installTap"
        ]

        let violations = forbiddenSymbols.filter { source.contains($0) }
        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    func testSonicSphereAnalysisMeterIsNotLabeledAsDanteOutputMeterUnlessActualDanteRenderBus() {
        XCTAssertEqual(
            MeterDisplaySurface.sonicSphereTitle(isActualDanteRenderBus: false),
            "Sonic Sphere Analysis Meter"
        )
        XCTAssertEqual(
            MeterDisplaySurface.sonicSphereTitle(isActualDanteRenderBus: true),
            "Dante Output Meter"
        )
    }

    func testDanteOutputMeterMetersPostRenderDanteBlockPreOutputGain() throws {
        let block = try direct31Block(frameCount: 4, impulses: [(0, 0, 1)])
        let result = try renderWithTelemetry(
            sourceBlock: block,
            sourceChannelCount: 31,
            layout: .direct31,
            renderMode: .direct31,
            gainPlan: GainPlan(danteOutputGain: try LinearGain(0.25))
        )

        let danteBlock = try XCTUnwrap(result.dante.lastConsumedBlockForTestingCopy())
        XCTAssertEqual(danteBlock.sample(channel: 0, frame: 0), 0.25, accuracy: tolerance)
        let snapshot = try XCTUnwrap(result.telemetry.latestMeterSnapshot())
        XCTAssertEqual(snapshot.danteMeters.count, 32)
        XCTAssertEqual(snapshot.danteMeters[0].peakDBFS, 0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.danteMeters[31].peakDBFS, MeterAccumulator.silenceDBFS, accuracy: tolerance)
    }

    func testDesktopMeterIsPostRenderDesktopBlockPreOutputGain() throws {
        let block = try stereoBlock(left: 1, right: 0, frameCount: 4)
        let result = try renderWithTelemetry(
            sourceBlock: block,
            sourceChannelCount: 2,
            layout: .stereo,
            renderMode: .stereo,
            gainPlan: GainPlan(desktopMonitorGain: try LinearGain(0.25))
        )

        let desktopBlock = try XCTUnwrap(result.desktop.lastConsumedBlockForTestingCopy())
        XCTAssertEqual(desktopBlock.sample(channel: 0, frame: 0), 0.25, accuracy: tolerance)
        let snapshot = try XCTUnwrap(result.telemetry.latestMeterSnapshot())
        XCTAssertEqual(snapshot.desktopMeters.count, 2)
        XCTAssertEqual(snapshot.desktopMeters[0].peakDBFS, 0, accuracy: 0.0001)
    }

    func testMeterCalibrationDoesNotChangeAudibleOutput() throws {
        let sourceBlock = try stereoBlock(left: 0.5, right: -0.25, frameCount: 8)
        let base = try renderHash(
            sourceBlock: sourceBlock,
            sourceChannelCount: 2,
            layout: .stereo,
            renderMode: .stereo,
            gainPlan: GainPlan()
        )
        let calibrated = try renderHash(
            sourceBlock: try stereoBlock(left: 0.5, right: -0.25, frameCount: 8),
            sourceChannelCount: 2,
            layout: .stereo,
            renderMode: .stereo,
            gainPlan: GainPlan(meterCalibrationGain: try LinearGain(0.5))
        )

        XCTAssertEqual(base.desktop, calibrated.desktop)
        XCTAssertEqual(base.dante, calibrated.dante)
    }

    func testVUConsumerLoadDoesNotChangeOutputHashAndDropsMeterData() throws {
        let sourceBlock = try direct31Block(frameCount: 8, impulses: [(0, 0, 1), (10, 1, 0.5), (30, 2, 0.25)])
        let baseline = try renderHash(
            sourceBlock: sourceBlock,
            sourceChannelCount: 31,
            layout: .direct31,
            renderMode: .direct31,
            gainPlan: GainPlan(),
            meteringService: nil
        )
        let meteringService = PureAudioMeteringService(copyBus: MeterCopyBus(maxQueuedBlockCount: 1))
        let metered = try renderHash(
            sourceBlock: try direct31Block(frameCount: 8, impulses: [(0, 0, 1), (10, 1, 0.5), (30, 2, 0.25)]),
            sourceChannelCount: 31,
            layout: .direct31,
            renderMode: .direct31,
            gainPlan: GainPlan(),
            meteringService: meteringService
        )

        XCTAssertEqual(baseline.desktop, metered.desktop)
        XCTAssertEqual(baseline.dante, metered.dante)
        XCTAssertGreaterThan(meteringService.copyBus.statusSnapshot().droppedBlockCount, 0)
    }

    private func renderWithTelemetry(
        sourceBlock: CanonicalAudioBlock,
        sourceChannelCount: Int,
        layout: AudioChannelLayoutDescriptor,
        renderMode: RenderMode,
        gainPlan: GainPlan
    ) throws -> (telemetry: AudioTelemetry, desktop: OfflineDesktopOutputAdapter, dante: OfflineDanteOutputAdapter) {
        let telemetry = AudioTelemetry()
        let meteringService = PureAudioMeteringService(
            copyBus: MeterCopyBus(maxQueuedBlockCount: 8),
            telemetry: telemetry
        )
        let source = managedSource(channelCount: sourceChannelCount, layout: layout, queuedBlocks: [sourceBlock])
        let desktop = OfflineDesktopOutputAdapter(route: desktopRoute())
        let dante = danteAdapter()
        let coordinator = DualOutputRenderCoordinator(
            plan: try makePlan(source: source.descriptor, renderMode: renderMode, gainPlan: gainPlan),
            sourceAdapter: source,
            desktopAdapter: desktop,
            danteAdapter: dante,
            frameCapacity: sourceBlock.frameCapacity,
            meteringService: meteringService
        )

        try coordinator.prepare()
        try coordinator.start()
        try coordinator.render(frameCount: sourceBlock.frameCapacity)
        return (telemetry, desktop, dante)
    }

    private func renderHash(
        sourceBlock: CanonicalAudioBlock,
        sourceChannelCount: Int,
        layout: AudioChannelLayoutDescriptor,
        renderMode: RenderMode,
        gainPlan: GainPlan,
        meteringService: PureAudioMeteringService? = PureAudioMeteringService()
    ) throws -> (desktop: UInt64, dante: UInt64) {
        let source = managedSource(channelCount: sourceChannelCount, layout: layout, queuedBlocks: [sourceBlock])
        let desktop = OfflineDesktopOutputAdapter(route: desktopRoute())
        let dante = danteAdapter()
        let coordinator = DualOutputRenderCoordinator(
            plan: try makePlan(source: source.descriptor, renderMode: renderMode, gainPlan: gainPlan),
            sourceAdapter: source,
            desktopAdapter: desktop,
            danteAdapter: dante,
            frameCapacity: sourceBlock.frameCapacity,
            meteringService: meteringService
        )

        try coordinator.prepare()
        try coordinator.start()
        try coordinator.render(frameCount: sourceBlock.frameCapacity)

        return (
            hash(block: try XCTUnwrap(desktop.lastConsumedBlockForTestingCopy())),
            hash(block: try XCTUnwrap(dante.lastConsumedBlockForTestingCopy()))
        )
    }

    private func makePlan(
        source: SourceDescriptor,
        renderMode: RenderMode,
        gainPlan: GainPlan
    ) throws -> RenderGraphPlan {
        try RenderGraphPlanner().makeValidatedPlan(
            RenderGraphPlanRequest(
                version: 11,
                sessionFormat: sessionFormat(),
                source: source,
                renderMode: renderMode,
                gainPlan: gainPlan
            )
        )
    }

    private func managedSource(
        channelCount: Int,
        layout: AudioChannelLayoutDescriptor,
        queuedBlocks: [CanonicalAudioBlock]
    ) -> ManagedLocalAssetSourceAdapter {
        ManagedLocalAssetSourceAdapter(
            asset: ManagedAssetDescriptor(
                id: "managed-\(channelCount)",
                originalPath: "original.wav",
                managedPath: "managed.caf",
                originalSampleRate: .defaultProduction,
                managedSampleRate: .defaultProduction,
                channelCount: channelCount,
                layout: layout,
                conversionLedger: ConversionLedger(
                    sessionSampleRate: .defaultProduction,
                    sourceOriginalDescription: "test original",
                    sourceCanonicalDescription: "test managed",
                    allowedConversions: [.codecDecodeToPCM, .integerPCMToFloat32, .interleavedToDeinterleaved],
                    forbiddenConversionsObserved: [],
                    desktopOutputDescription: "desktop",
                    danteOutputDescription: "dante"
                )
            ),
            queuedBlocks: queuedBlocks
        )
    }

    private func stereoBlock(left: Float, right: Float, frameCount: Int) throws -> CanonicalAudioBlock {
        let block = try block(channelCount: 2, layout: .stereo, frameCount: frameCount)
        try block.setSample(left, channel: 0, frame: 0)
        try block.setSample(right, channel: 1, frame: 0)
        try block.setFrameCount(frameCount)
        return block
    }

    private func direct31Block(
        frameCount: Int,
        impulses: [(channel: Int, frame: Int, value: Float)]
    ) throws -> CanonicalAudioBlock {
        let block = try block(channelCount: 31, layout: .direct31, frameCount: frameCount)
        for impulse in impulses {
            try block.setSample(impulse.value, channel: impulse.channel, frame: impulse.frame)
        }
        try block.setFrameCount(frameCount)
        return block
    }

    private func block(
        channelCount: Int,
        layout: AudioChannelLayoutDescriptor,
        frameCount: Int
    ) throws -> CanonicalAudioBlock {
        try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: .defaultProduction,
                channelCount: channelCount,
                frameCount: frameCount,
                layout: layout
            )
        )
    }

    private func desktopRoute() -> OutputRouteDescriptor {
        OutputRouteDescriptor(
            id: "desktop",
            uid: "desktop",
            name: "Desktop Monitor",
            manufacturer: "Orbisonic",
            transportName: "Built-In",
            outputChannelCount: 2,
            nominalSampleRate: .defaultProduction,
            isAvailable: true,
            risk: .safe
        )
    }

    private func danteAdapter() -> OfflineDanteOutputAdapter {
        OfflineDanteOutputAdapter(
            capability: DanteRouteCapability(
                route: OutputRouteDescriptor(
                    id: "dante",
                    uid: "dante",
                    name: "Dante Virtual Soundcard",
                    manufacturer: "Audinate",
                    transportName: "Dante",
                    outputChannelCount: 32,
                    nominalSampleRate: .defaultProduction,
                    isAvailable: true,
                    risk: .preferredDante
                ),
                supportedSampleRates: [.defaultProduction],
                currentNominalSampleRate: .defaultProduction,
                outputChannelCount: 32
            )
        )
    }

    private func sessionFormat() -> AudioSessionFormat {
        AudioSessionFormat(
            sampleRate: .defaultProduction,
            maxFramesPerBlock: 512,
            dante: DanteOutputFormat(physicalChannelCount: 32, sampleRate: .defaultProduction),
            desktop: DesktopOutputFormat(sampleRate: .defaultProduction)
        )
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

    private func dbFS(_ value: Float) -> Float {
        20 * log10f(max(value, 0.000_001))
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
