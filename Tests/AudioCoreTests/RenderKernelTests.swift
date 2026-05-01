import AudioContracts
import AudioCore
import XCTest

final class RenderKernelTests: XCTestCase {
    private let tolerance: Float = 0.000_001

    func testMonoImpulseRendersToDesktopLeftRightAccordingToPolicy() throws {
        let plan = try makePlan(source: source(id: "mono", channelCount: 1, layout: .mono), renderMode: .mono)
        let sourceBlock = try sourceBlock(for: plan, impulses: [(0, 0, 1)])
        let desktop = try desktopBlock(for: plan)

        try DesktopMonitorRenderer(plan: plan.desktopDownmix, gainPlan: plan.gainPlan)
            .process(source: sourceBlock, destination: desktop, frameCount: 1)

        XCTAssertEqual(desktop.sample(channel: 0, frame: 0), Float(0.70710678), accuracy: tolerance)
        XCTAssertEqual(desktop.sample(channel: 1, frame: 0), Float(0.70710678), accuracy: tolerance)
    }

    func testStereoLeftImpulseRendersOnlyToDesktopLeft() throws {
        let plan = try makePlan(source: stereoSource())
        let sourceBlock = try sourceBlock(for: plan, impulses: [(0, 0, 1)])
        let desktop = try desktopBlock(for: plan)

        try DesktopMonitorRenderer(plan: plan.desktopDownmix, gainPlan: plan.gainPlan)
            .process(source: sourceBlock, destination: desktop, frameCount: 1)

        XCTAssertEqual(desktop.sample(channel: 0, frame: 0), 1, accuracy: tolerance)
        XCTAssertEqual(desktop.sample(channel: 1, frame: 0), 0, accuracy: tolerance)
    }

    func testStereoRightImpulseRendersOnlyToDesktopRight() throws {
        let plan = try makePlan(source: stereoSource())
        let sourceBlock = try sourceBlock(for: plan, impulses: [(1, 0, 1)])
        let desktop = try desktopBlock(for: plan)

        try DesktopMonitorRenderer(plan: plan.desktopDownmix, gainPlan: plan.gainPlan)
            .process(source: sourceBlock, destination: desktop, frameCount: 1)

        XCTAssertEqual(desktop.sample(channel: 0, frame: 0), 0, accuracy: tolerance)
        XCTAssertEqual(desktop.sample(channel: 1, frame: 0), 1, accuracy: tolerance)
    }

    func testCenterImpulseRendersEqualPowerToDesktopLeftRightWithHeadroom() throws {
        let layout = AudioChannelLayoutDescriptor(
            name: "3.0",
            roles: [.frontLeft, .frontRight, .center]
        )
        let plan = try makePlan(source: source(id: "three-zero", channelCount: 3, layout: layout), renderMode: .mono)
        let sourceBlock = try sourceBlock(for: plan, impulses: [(2, 0, 1)])
        let desktop = try desktopBlock(for: plan)

        try DesktopMonitorRenderer(plan: plan.desktopDownmix, gainPlan: plan.gainPlan)
            .process(source: sourceBlock, destination: desktop, frameCount: 1)

        let expected = Float(0.70710678 * 0.50118723)
        XCTAssertEqual(desktop.sample(channel: 0, frame: 0), expected, accuracy: tolerance)
        XCTAssertEqual(desktop.sample(channel: 1, frame: 0), expected, accuracy: tolerance)
    }

    func testLFEImpulseIsOmittedFromReferenceStereo() throws {
        let plan = try makePlan(source: source(id: "five-one", channelCount: 6, layout: .surround51), renderMode: .surround51)
        let sourceBlock = try sourceBlock(for: plan, impulses: [(3, 0, 1)])
        let desktop = try desktopBlock(for: plan)

        try DesktopMonitorRenderer(plan: plan.desktopDownmix, gainPlan: plan.gainPlan)
            .process(source: sourceBlock, destination: desktop, frameCount: 1)

        XCTAssertEqual(desktop.sample(channel: 0, frame: 0), 0, accuracy: tolerance)
        XCTAssertEqual(desktop.sample(channel: 1, frame: 0), 0, accuracy: tolerance)
    }

    func testDiscreteMultichannelSourceReceivesDeterministicDesktopMapping() throws {
        let plan = try makePlan(source: source(id: "discrete4", channelCount: 4, layout: .discrete(count: 4)), renderMode: .mono)
        let sourceBlock = try sourceBlock(
            for: plan,
            impulses: [
                (0, 0, 1),
                (1, 0, 2),
                (2, 0, 3),
                (3, 0, 4)
            ]
        )
        let desktop = try desktopBlock(for: plan)

        try DesktopMonitorRenderer(plan: plan.desktopDownmix, gainPlan: plan.gainPlan)
            .process(source: sourceBlock, destination: desktop, frameCount: 1)

        let headroom = Float(0.50118723)
        XCTAssertEqual(desktop.sample(channel: 0, frame: 0), (1 + 3) * headroom, accuracy: tolerance)
        XCTAssertEqual(desktop.sample(channel: 1, frame: 0), (2 + 4) * headroom, accuracy: tolerance)
    }

    func testDirect30DanteMapsFirstAndThirtiethSourceChannelsToMatchingFullRangeOutputs() throws {
        let plan = try makePlan(
            source: source(id: "direct30", channelCount: 30, layout: .direct30),
            renderMode: .direct30,
            physicalDanteChannels: 32
        )
        let sourceBlock = try sourceBlock(for: plan, impulses: [(0, 0, 0.25), (29, 0, 0.75)])
        let dante = try danteBlock(for: plan)

        try DanteSonicSphereRenderer(plan: plan.danteRenderer, gainPlan: plan.gainPlan)
            .process(source: sourceBlock, destination: dante, frameCount: 1)

        XCTAssertEqual(dante.sample(channel: 0, frame: 0), 0.25, accuracy: tolerance)
        XCTAssertEqual(dante.sample(channel: 29, frame: 0), 0.75, accuracy: tolerance)
        XCTAssertEqual(dante.sample(channel: 30, frame: 0), 0, accuracy: tolerance)
    }

    func testDirect31DanteMapsSourceChannelThirtyOneToLFE() throws {
        let plan = try makePlan(
            source: source(id: "direct31", channelCount: 31, layout: .direct31),
            renderMode: .direct31,
            physicalDanteChannels: 32
        )
        let sourceBlock = try sourceBlock(for: plan, impulses: [(30, 0, 0.5)])
        let dante = try danteBlock(for: plan)

        try DanteSonicSphereRenderer(plan: plan.danteRenderer, gainPlan: plan.gainPlan)
            .process(source: sourceBlock, destination: dante, frameCount: 1)

        XCTAssertEqual(dante.sample(channel: 30, frame: 0), 0.5, accuracy: tolerance)
        XCTAssertEqual(dante.sample(channel: 0, frame: 0), 0, accuracy: tolerance)
    }

    func testThirtyTwoChannelPhysicalDanteBlockHasChannelThirtyTwoSilent() throws {
        let plan = try makePlan(
            source: source(id: "direct31", channelCount: 31, layout: .direct31),
            renderMode: .direct31,
            physicalDanteChannels: 32
        )
        let impulses = (0..<31).map { ($0, 0, Float(1)) }
        let sourceBlock = try sourceBlock(for: plan, impulses: impulses)
        let dante = try danteBlock(for: plan)

        try DanteSonicSphereRenderer(plan: plan.danteRenderer, gainPlan: plan.gainPlan)
            .process(source: sourceBlock, destination: dante, frameCount: 1)

        XCTAssertEqual(dante.sample(channel: 31, frame: 0), 0, accuracy: tolerance)
    }

    func testDesktopGainDoesNotChangeDanteOutput() throws {
        let source = stereoSource()
        let base = try makePlan(source: source)
        let desktopBoosted = try makePlan(
            source: source,
            gainPlan: GainPlan(desktopMonitorGain: try LinearGain(0.25))
        )
        let baseDante = try renderDante(plan: base, impulses: [(0, 0, 1), (1, 0, 0.5)])
        let boostedDante = try renderDante(plan: desktopBoosted, impulses: [(0, 0, 1), (1, 0, 0.5)])

        XCTAssertEqual(blockSamples(baseDante), blockSamples(boostedDante))
    }

    func testDanteGainDoesNotChangeDesktopOutput() throws {
        let source = stereoSource()
        let base = try makePlan(source: source)
        let danteTrimmed = try makePlan(
            source: source,
            gainPlan: GainPlan(danteOutputGain: try LinearGain(0.25))
        )
        let baseDesktop = try renderDesktop(plan: base, impulses: [(0, 0, 1), (1, 0, 0.5)])
        let trimmedDesktop = try renderDesktop(plan: danteTrimmed, impulses: [(0, 0, 1), (1, 0, 0.5)])

        XCTAssertEqual(blockSamples(baseDesktop), blockSamples(trimmedDesktop))
    }

    func testMatrixRenderWithZeroGainsOutputsSilence() throws {
        let kernel = MatrixRenderKernel(matrix: try ImmutableMatrix(inputRows: [[0, 0], [0, 0]]))
        let source = try sourceBlock(
            sampleRate: .rate48000,
            channelCount: 2,
            layout: .stereo,
            impulses: [(0, 0, 1), (1, 0, 1)]
        )
        let destination = try block(sampleRate: .rate48000, channelCount: 2, layout: .stereo)

        try kernel.process(source: source, destination: destination, frameCount: 1)

        XCTAssertEqual(blockSamples(destination), [[0], [0]])
    }

    func testKernelRejectsSampleRateMismatchBeforeProcessing() throws {
        let kernel = MatrixRenderKernel(matrix: try ImmutableMatrix(inputRows: [[1, 0], [0, 1]]))
        let source = try sourceBlock(
            sampleRate: .rate48000,
            channelCount: 2,
            layout: .stereo,
            impulses: [(0, 0, 1)]
        )
        let destination = try block(sampleRate: .rate44100, channelCount: 2, layout: .stereo)
        try destination.setSample(99, channel: 0, frame: 0)

        XCTAssertThrowsError(try kernel.process(source: source, destination: destination, frameCount: 1))
        XCTAssertEqual(destination.sample(channel: 0, frame: 0), 99, accuracy: tolerance)
    }

    func testCanonicalSourceBusAcceptsFixtureInjectionAndTracksMonotonicFrameIndex() throws {
        let source = stereoSource()
        let plan = try makePlan(source: source)
        let bus = try CanonicalSourceBus(sessionFormat: plan.sessionFormat, source: source, frameCapacity: 4)
        let injected = try sourceBlock(for: plan, frameCapacity: 4, impulses: [(0, 0, 1), (1, 3, 0.5)])

        try bus.injectFixtureBlock(injected)
        let copy = try bus.currentBlockForTestingCopy()

        XCTAssertEqual(bus.frameIndex, 4)
        XCTAssertEqual(copy.sample(channel: 0, frame: 0), 1, accuracy: tolerance)
        XCTAssertEqual(copy.sample(channel: 1, frame: 3), 0.5, accuracy: tolerance)
    }

    func testRenderKernelAPIDoesNotExposeAudioGraphOrUITypes() throws {
        let source = try String(contentsOf: renderKernelSourceURL(), encoding: .utf8)
        let forbiddenSymbols = [
            "AVAudioEngine",
            "AVAudioNode",
            "AudioUnit",
            "AudioDeviceID",
            "SwiftUI",
            "AppKit",
            "AVAudioPCMBuffer",
            "RendererMatrix",
            "LiveAudioPipe"
        ]

        let violations = forbiddenSymbols.filter { source.contains($0) }
        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    func testGoldenOutputHashForDirect30Fixture() throws {
        let plan = try makePlan(
            source: source(id: "direct30", channelCount: 30, layout: .direct30),
            renderMode: .direct30,
            physicalDanteChannels: 32
        )
        let dante = try renderDante(plan: plan, impulses: [(0, 0, 0.25), (29, 0, 0.75)])

        XCTAssertEqual(fnv1aHash(dante), 0x0118_1ffb_4f1e_fb30)
    }

    func testRenderKernelAuditReportsNoSRCAndNotInstrumentedAllocations() throws {
        let plan = try makePlan(source: stereoSource())
        let sourceBlock = try sourceBlock(for: plan, impulses: [(0, 0, 1)])
        let desktop = try desktopBlock(for: plan)
        let dante = try danteBlock(for: plan)

        try DesktopMonitorRenderer(plan: plan.desktopDownmix, gainPlan: plan.gainPlan)
            .process(source: sourceBlock, destination: desktop, frameCount: 1)
        try DanteSonicSphereRenderer(plan: plan.danteRenderer, gainPlan: plan.gainPlan)
            .process(source: sourceBlock, destination: dante, frameCount: 1)
        let audit = RenderKernelAudit.make(plan: plan, source: sourceBlock, desktop: desktop, dante: dante)

        XCTAssertFalse(audit.sampleRateConversionOccurred)
        XCTAssertNil(audit.allocationsDetected)
        XCTAssertTrue(audit.allocationMeasurement.contains("not instrumented"))
        XCTAssertEqual(audit.renderPlanVersion, plan.version)
    }

    private func makePlan(
        source: SourceDescriptor,
        renderMode: RenderMode = .automatic,
        gainPlan: GainPlan = GainPlan(),
        physicalDanteChannels: Int = 32
    ) throws -> RenderGraphPlan {
        let format = AudioSessionFormat(
            sampleRate: source.sampleRate,
            maxFramesPerBlock: 512,
            dante: DanteOutputFormat(
                physicalChannelCount: physicalDanteChannels,
                sampleRate: source.sampleRate
            ),
            desktop: DesktopOutputFormat(sampleRate: source.sampleRate)
        )
        return try RenderGraphPlanner().makeValidatedPlan(
            RenderGraphPlanRequest(
                version: 1,
                sessionFormat: format,
                source: source,
                renderMode: renderMode,
                gainPlan: gainPlan,
                createdAtUnixTimeSeconds: nil
            )
        )
    }

    private func stereoSource() -> SourceDescriptor {
        source(id: "stereo", channelCount: 2, layout: .stereo)
    }

    private func source(
        id: String,
        channelCount: Int,
        layout: AudioChannelLayoutDescriptor,
        sampleRate: AudioSampleRate = .rate48000
    ) -> SourceDescriptor {
        SourceDescriptor(
            id: id,
            kind: .localFile,
            sampleRate: sampleRate,
            channelCount: channelCount,
            layout: layout
        )
    }

    private func renderDesktop(
        plan: RenderGraphPlan,
        impulses: [(channel: Int, frame: Int, value: Float)]
    ) throws -> CanonicalAudioBlock {
        let sourceBlock = try sourceBlock(for: plan, impulses: impulses)
        let desktop = try desktopBlock(for: plan)
        try DesktopMonitorRenderer(plan: plan.desktopDownmix, gainPlan: plan.gainPlan)
            .process(source: sourceBlock, destination: desktop, frameCount: sourceBlock.frameCount)
        return desktop
    }

    private func renderDante(
        plan: RenderGraphPlan,
        impulses: [(channel: Int, frame: Int, value: Float)]
    ) throws -> CanonicalAudioBlock {
        let sourceBlock = try sourceBlock(for: plan, impulses: impulses)
        let dante = try danteBlock(for: plan)
        try DanteSonicSphereRenderer(plan: plan.danteRenderer, gainPlan: plan.gainPlan)
            .process(source: sourceBlock, destination: dante, frameCount: sourceBlock.frameCount)
        return dante
    }

    private func sourceBlock(
        for plan: RenderGraphPlan,
        frameCapacity: Int = 1,
        impulses: [(channel: Int, frame: Int, value: Float)]
    ) throws -> CanonicalAudioBlock {
        try sourceBlock(
            sampleRate: plan.sessionFormat.sampleRate,
            channelCount: plan.source.channelCount,
            layout: plan.source.layout,
            frameCapacity: frameCapacity,
            impulses: impulses
        )
    }

    private func sourceBlock(
        sampleRate: AudioSampleRate,
        channelCount: Int,
        layout: AudioChannelLayoutDescriptor,
        frameCapacity: Int = 1,
        impulses: [(channel: Int, frame: Int, value: Float)]
    ) throws -> CanonicalAudioBlock {
        let block = try block(
            sampleRate: sampleRate,
            channelCount: channelCount,
            layout: layout,
            frameCapacity: frameCapacity
        )
        for impulse in impulses {
            try block.setSample(impulse.value, channel: impulse.channel, frame: impulse.frame)
        }
        if block.frameCount == 0 {
            try block.setFrameCount(frameCapacity)
        }
        return block
    }

    private func desktopBlock(for plan: RenderGraphPlan, frameCapacity: Int = 1) throws -> CanonicalAudioBlock {
        try block(
            sampleRate: plan.sessionFormat.sampleRate,
            channelCount: 2,
            layout: .stereo,
            frameCapacity: frameCapacity
        )
    }

    private func danteBlock(for plan: RenderGraphPlan, frameCapacity: Int = 1) throws -> CanonicalAudioBlock {
        try block(
            sampleRate: plan.sessionFormat.sampleRate,
            channelCount: plan.danteRenderer.physicalOutputCount,
            layout: .discrete(count: plan.danteRenderer.physicalOutputCount),
            frameCapacity: frameCapacity
        )
    }

    private func block(
        sampleRate: AudioSampleRate,
        channelCount: Int,
        layout: AudioChannelLayoutDescriptor,
        frameCapacity: Int = 1
    ) throws -> CanonicalAudioBlock {
        try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: sampleRate,
                channelCount: channelCount,
                frameCount: frameCapacity,
                layout: layout
            )
        )
    }

    private func blockSamples(_ block: CanonicalAudioBlock) -> [[Float]] {
        (0..<block.channelCount).map { block.channelSamplesCopy(channel: $0) }
    }

    private func fnv1aHash(_ block: CanonicalAudioBlock) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        let prime: UInt64 = 1_099_511_628_211
        for channel in 0..<block.channelCount {
            for sample in block.channelSamplesCopy(channel: channel) {
                let bits = sample.bitPattern
                for shift in stride(from: 0, through: 24, by: 8) {
                    hash ^= UInt64((bits >> UInt32(shift)) & 0xff)
                    hash = hash &* prime
                }
            }
        }
        return hash
    }

    private func renderKernelSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AudioCore/RenderKernels.swift")
    }
}
