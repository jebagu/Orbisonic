import AudioContracts
import AudioCore
import XCTest

final class OutputAdapterTests: XCTestCase {
    func testDesktopRouteFailureDoesNotAlterDanteRenderedBlock() throws {
        let block = try direct31Block(frameCount: 8, impulses: [(0, 0, 1), (30, 0, 0.5)])
        let source = managedSource(channelCount: 31, layout: .direct31, queuedBlocks: [block])
        let plan = try makePlan(source: source.descriptor, renderMode: .direct31)
        let desktop = OfflineDesktopOutputAdapter(route: desktopRoute(), shouldFailOnConsume: true)
        let dante = danteAdapter()
        let coordinator = DualOutputRenderCoordinator(
            plan: plan,
            sourceAdapter: source,
            desktopAdapter: desktop,
            danteAdapter: dante,
            frameCapacity: 8
        )

        try coordinator.prepare()
        try coordinator.start()
        let status = try coordinator.render(frameCount: 8)

        let danteBlock = try XCTUnwrap(dante.lastConsumedBlockForTestingCopy())
        XCTAssertEqual(danteBlock.sample(channel: 0, frame: 0), 1, accuracy: tolerance)
        XCTAssertEqual(danteBlock.sample(channel: 30, frame: 0), 0.5, accuracy: tolerance)
        XCTAssertEqual(status.desktop.snapshot.state, .failed)
        XCTAssertFalse(status.productionOutputFailed)
    }

    func testDesktopRouteFailureSetsDesktopStatusOnly() throws {
        let source = managedSource(
            channelCount: 2,
            layout: .stereo,
            queuedBlocks: [try stereoBlock(left: 1, right: 0, frameCount: 4)]
        )
        let plan = try makePlan(source: source.descriptor, renderMode: .stereo)
        let desktop = OfflineDesktopOutputAdapter(route: desktopRoute(), shouldFailOnConsume: true)
        let dante = danteAdapter()
        let coordinator = DualOutputRenderCoordinator(
            plan: plan,
            sourceAdapter: source,
            desktopAdapter: desktop,
            danteAdapter: dante,
            frameCapacity: 4
        )

        try coordinator.prepare()
        try coordinator.start()
        let status = try coordinator.render(frameCount: 4)

        XCTAssertTrue(status.desktop.desktopOutputFailed)
        XCTAssertEqual(status.desktop.snapshot.state, .failed)
        XCTAssertFalse(status.dante.productionOutputFailed)
        XCTAssertEqual(status.dante.snapshot.state, .validationOnly)
    }

    func testDanteRouteFailureSetsProductionFailedStatus() throws {
        let source = managedSource(
            channelCount: 31,
            layout: .direct31,
            queuedBlocks: [try direct31Block(frameCount: 4, impulses: [(0, 0, 1)])]
        )
        let plan = try makePlan(source: source.descriptor, renderMode: .direct31)
        let dante = danteAdapter(shouldFailOnConsume: true)
        let coordinator = DualOutputRenderCoordinator(
            plan: plan,
            sourceAdapter: source,
            desktopAdapter: OfflineDesktopOutputAdapter(route: desktopRoute()),
            danteAdapter: dante,
            frameCapacity: 4
        )

        try coordinator.prepare()
        try coordinator.start()
        XCTAssertThrowsError(try coordinator.render(frameCount: 4))

        let status = coordinator.latestStatusSnapshot()
        XCTAssertTrue(status.productionOutputFailed)
        XCTAssertEqual(status.dante.snapshot.state, .failed)
    }

    func testDesktopGainChangeDoesNotAlterDanteOutputHash() throws {
        let unityHash = try renderHash(
            sourceBlock: direct31Block(frameCount: 8, impulses: [(0, 0, 1), (10, 2, 0.25), (30, 3, 0.5)]),
            channelCount: 31,
            layout: .direct31,
            renderMode: .direct31,
            desktopGain: .unity,
            danteGain: .unity
        ).dante
        let changedHash = try renderHash(
            sourceBlock: direct31Block(frameCount: 8, impulses: [(0, 0, 1), (10, 2, 0.25), (30, 3, 0.5)]),
            channelCount: 31,
            layout: .direct31,
            renderMode: .direct31,
            desktopGain: try LinearGain(0.25),
            danteGain: .unity
        ).dante

        XCTAssertEqual(unityHash, changedHash)
    }

    func testDanteGainChangeDoesNotAlterDesktopOutputHash() throws {
        let unityHash = try renderHash(
            sourceBlock: stereoBlock(left: 1, right: 0.5, frameCount: 8),
            channelCount: 2,
            layout: .stereo,
            renderMode: .stereo,
            desktopGain: .unity,
            danteGain: .unity
        ).desktop
        let changedHash = try renderHash(
            sourceBlock: stereoBlock(left: 1, right: 0.5, frameCount: 8),
            channelCount: 2,
            layout: .stereo,
            renderMode: .stereo,
            desktopGain: .unity,
            danteGain: try LinearGain(0.25)
        ).desktop

        XCTAssertEqual(unityHash, changedHash)
    }

    func testThirtyTwoChannelDanteOutputKeepsChannelThirtyTwoSilent() throws {
        let source = managedSource(
            channelCount: 31,
            layout: .direct31,
            queuedBlocks: [try direct31Block(frameCount: 6, impulses: [(0, 0, 1), (29, 1, 0.75), (30, 2, 0.5)])]
        )
        let plan = try makePlan(source: source.descriptor, renderMode: .direct31)
        let dante = danteAdapter(physicalChannels: 32)
        let coordinator = DualOutputRenderCoordinator(
            plan: plan,
            sourceAdapter: source,
            desktopAdapter: OfflineDesktopOutputAdapter(route: desktopRoute()),
            danteAdapter: dante,
            frameCapacity: 6
        )

        try coordinator.prepare()
        try coordinator.start()
        try coordinator.render(frameCount: 6)

        let block = try XCTUnwrap(dante.lastConsumedBlockForTestingCopy())
        XCTAssertEqual(block.channelCount, 32)
        for frame in 0..<block.frameCount {
            XCTAssertEqual(block.sample(channel: 31, frame: frame), 0, accuracy: tolerance)
        }
    }

    func testCoordinatorRendersDesktopAndDanteFromSameSourceFrameIndex() throws {
        let source = managedSource(
            channelCount: 2,
            layout: .stereo,
            queuedBlocks: [try stereoBlock(left: 0.5, right: 0.25, frameCount: 8)]
        )
        let plan = try makePlan(source: source.descriptor, renderMode: .stereo)
        let coordinator = DualOutputRenderCoordinator(
            plan: plan,
            sourceAdapter: source,
            desktopAdapter: OfflineDesktopOutputAdapter(route: desktopRoute()),
            danteAdapter: danteAdapter(),
            frameCapacity: 8
        )

        try coordinator.prepare()
        try coordinator.start()
        let status = try coordinator.render(frameCount: 8)

        XCTAssertEqual(status.sourceFrameIndex, 8)
        XCTAssertEqual(status.desktop.snapshot.sourceFrameIndex, 8)
        XCTAssertEqual(status.dante.snapshot.sourceFrameIndex, 8)
    }

    func testCoordinatorRejectsRouteSampleRateMismatch() throws {
        let source = managedSource(
            channelCount: 2,
            layout: .stereo,
            queuedBlocks: [try stereoBlock(left: 1, right: 0, frameCount: 4)]
        )
        let plan = try makePlan(source: source.descriptor, renderMode: .stereo)
        let coordinator = DualOutputRenderCoordinator(
            plan: plan,
            sourceAdapter: source,
            desktopAdapter: OfflineDesktopOutputAdapter(route: desktopRoute()),
            danteAdapter: danteAdapter(sampleRate: .rate44100),
            frameCapacity: 4
        )

        XCTAssertThrowsError(try coordinator.prepare()) { error in
            guard case AudioError.sampleRateMismatch = error else {
                return XCTFail("Expected sample-rate mismatch, got \(error).")
            }
        }
    }

    func testCoordinatorRejectsDanteRouteWithFewerThanThirtyOneChannels() throws {
        let source = managedSource(
            channelCount: 2,
            layout: .stereo,
            queuedBlocks: [try stereoBlock(left: 1, right: 0, frameCount: 4)]
        )
        let plan = try makePlan(source: source.descriptor, renderMode: .stereo)
        let coordinator = DualOutputRenderCoordinator(
            plan: plan,
            sourceAdapter: source,
            desktopAdapter: OfflineDesktopOutputAdapter(route: desktopRoute()),
            danteAdapter: danteAdapter(physicalChannels: 16),
            frameCapacity: 4
        )

        XCTAssertThrowsError(try coordinator.prepare()) { error in
            XCTAssertEqual(error as? AudioError, .danteRouteInsufficientChannels(required: 31, actual: 16))
        }
    }

    func testOutputAdapterPublicAPIDoesNotExposeGraphHandles() throws {
        let source = try String(contentsOf: packageRoot().appendingPathComponent("Sources/AudioCore/OutputAdapters.swift"))
        let forbiddenSymbols = [
            "AVAudioEngine",
            "AVAudioNode",
            "AudioUnit",
            "AudioDeviceID",
            "AudioBufferList",
            "UnsafeMutablePointer",
            "RendererMatrix",
            "LiveAudioPipe",
            "RingBuffer",
            "mainMixerNode",
            "outputNode"
        ]

        let violations = forbiddenSymbols.filter { source.contains($0) }
        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    func testDeterministicStereoSourceProducesDesktopAndDanteBlocks() throws {
        let source = managedSource(
            channelCount: 2,
            layout: .stereo,
            queuedBlocks: [try stereoBlock(left: 1, right: 0, frameCount: 4)]
        )
        let desktop = OfflineDesktopOutputAdapter(route: desktopRoute())
        let dante = danteAdapter()
        let coordinator = DualOutputRenderCoordinator(
            plan: try makePlan(source: source.descriptor, renderMode: .stereo),
            sourceAdapter: source,
            desktopAdapter: desktop,
            danteAdapter: dante,
            frameCapacity: 4
        )

        try coordinator.prepare()
        try coordinator.start()
        try coordinator.render(frameCount: 4)

        let desktopBlock = try XCTUnwrap(desktop.lastConsumedBlockForTestingCopy())
        let danteBlock = try XCTUnwrap(dante.lastConsumedBlockForTestingCopy())
        XCTAssertEqual(desktopBlock.sample(channel: 0, frame: 0), 1, accuracy: tolerance)
        XCTAssertNotEqual(hash(block: danteBlock), 0)
    }

    func testDeterministicDirect31SourceProducesDanteIdentityAndDesktopFold() throws {
        let source = managedSource(
            channelCount: 31,
            layout: .direct31,
            queuedBlocks: [try direct31Block(frameCount: 4, impulses: [(0, 0, 1), (1, 0, 0.5), (30, 0, 0.25)])]
        )
        let desktop = OfflineDesktopOutputAdapter(route: desktopRoute())
        let dante = danteAdapter()
        let coordinator = DualOutputRenderCoordinator(
            plan: try makePlan(source: source.descriptor, renderMode: .direct31),
            sourceAdapter: source,
            desktopAdapter: desktop,
            danteAdapter: dante,
            frameCapacity: 4
        )

        try coordinator.prepare()
        try coordinator.start()
        try coordinator.render(frameCount: 4)

        let desktopBlock = try XCTUnwrap(desktop.lastConsumedBlockForTestingCopy())
        let danteBlock = try XCTUnwrap(dante.lastConsumedBlockForTestingCopy())
        XCTAssertEqual(danteBlock.sample(channel: 0, frame: 0), 1, accuracy: tolerance)
        XCTAssertEqual(danteBlock.sample(channel: 1, frame: 0), 0.5, accuracy: tolerance)
        XCTAssertEqual(danteBlock.sample(channel: 30, frame: 0), 0.25, accuracy: tolerance)
        XCTAssertGreaterThan(abs(desktopBlock.sample(channel: 0, frame: 0)), 0)
    }

    func testLocalManagedAssetSourceRendersDualOutputOffline() throws {
        let block = try stereoBlock(left: 0.25, right: 0.75, frameCount: 4)
        let source = managedSource(channelCount: 2, layout: .stereo, queuedBlocks: [block])
        let desktop = OfflineDesktopOutputAdapter(route: desktopRoute())
        let dante = danteAdapter()
        let coordinator = DualOutputRenderCoordinator(
            plan: try makePlan(source: source.descriptor, renderMode: .stereo),
            sourceAdapter: source,
            desktopAdapter: desktop,
            danteAdapter: dante,
            frameCapacity: 4
        )

        try coordinator.prepare()
        try coordinator.start()
        let status = try coordinator.render(frameCount: 4)

        XCTAssertEqual(status.desktop.snapshot.consumedFramePosition, 4)
        XCTAssertEqual(status.dante.snapshot.consumedFramePosition, 4)
    }

    func testTestToneSourceRendersDanteChannelIDOffline() throws {
        let source = TestToneSourceAdapter(
            sessionSampleRate: .defaultProduction,
            mode: .danteChannelID(channelIndex: 4)
        )
        let plan = try makePlan(source: source.descriptor, renderMode: .direct31)
        let dante = danteAdapter()
        let coordinator = DualOutputRenderCoordinator(
            plan: plan,
            sourceAdapter: source,
            desktopAdapter: OfflineDesktopOutputAdapter(route: desktopRoute()),
            danteAdapter: dante,
            frameCapacity: 8
        )

        try coordinator.prepare()
        try coordinator.start()
        try coordinator.render(frameCount: 8)

        let block = try XCTUnwrap(dante.lastConsumedBlockForTestingCopy())
        XCTAssertNotEqual(block.sample(channel: 4, frame: 1), 0)
        XCTAssertEqual(block.sample(channel: 3, frame: 1), 0, accuracy: tolerance)
    }

    private let tolerance: Float = 0.000_001

    private func renderHash(
        sourceBlock: CanonicalAudioBlock,
        channelCount: Int,
        layout: AudioChannelLayoutDescriptor,
        renderMode: RenderMode,
        desktopGain: LinearGain,
        danteGain: LinearGain
    ) throws -> (desktop: UInt64, dante: UInt64) {
        let source = managedSource(channelCount: channelCount, layout: layout, queuedBlocks: [sourceBlock])
        let plan = try makePlan(
            source: source.descriptor,
            renderMode: renderMode,
            gainPlan: GainPlan(desktopMonitorGain: desktopGain, danteOutputGain: danteGain)
        )
        let desktop = OfflineDesktopOutputAdapter(route: desktopRoute())
        let dante = danteAdapter()
        let coordinator = DualOutputRenderCoordinator(
            plan: plan,
            sourceAdapter: source,
            desktopAdapter: desktop,
            danteAdapter: dante,
            frameCapacity: sourceBlock.frameCapacity
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
        gainPlan: GainPlan = GainPlan()
    ) throws -> RenderGraphPlan {
        try RenderGraphPlanner().makeValidatedPlan(
            RenderGraphPlanRequest(
                version: 1,
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

    private func desktopRoute(
        sampleRate: AudioSampleRate = .defaultProduction,
        channels: Int = 2,
        isAvailable: Bool = true
    ) -> OutputRouteDescriptor {
        OutputRouteDescriptor(
            id: "desktop",
            uid: "desktop",
            name: "Desktop Monitor",
            manufacturer: "Orbisonic",
            transportName: "Built-In",
            outputChannelCount: channels,
            nominalSampleRate: sampleRate,
            isAvailable: isAvailable,
            risk: .safe
        )
    }

    private func danteAdapter(
        physicalChannels: Int = 32,
        sampleRate: AudioSampleRate = .defaultProduction,
        shouldFailOnConsume: Bool = false
    ) -> OfflineDanteOutputAdapter {
        OfflineDanteOutputAdapter(
            capability: DanteRouteCapability(
                route: OutputRouteDescriptor(
                    id: "dante",
                    uid: "dante",
                    name: "Dante Virtual Soundcard",
                    manufacturer: "Audinate",
                    transportName: "Dante",
                    outputChannelCount: physicalChannels,
                    nominalSampleRate: sampleRate,
                    isAvailable: true,
                    risk: .preferredDante
                ),
                supportedSampleRates: [sampleRate],
                currentNominalSampleRate: sampleRate,
                outputChannelCount: physicalChannels
            ),
            shouldFailOnConsume: shouldFailOnConsume
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

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
