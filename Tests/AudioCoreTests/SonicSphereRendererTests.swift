import AudioContracts
import AudioCore
import XCTest

final class SonicSphereRendererTests: XCTestCase {
    private let tolerance: Float = 0.000_001

    func testDirect30IdentityRendersFirstThirtyChannelsAndEmitsRenderedSphereBlock() throws {
        let source = try audioBlock(channelCount: 30, layout: .direct30)
        for channel in 0..<30 {
            try source.setSample(Float(channel + 1), channel: channel, frame: 0)
        }
        let sourceBlock = try canonicalSourceBlock(
            sourceID: "direct30",
            channelCount: 30,
            layout: .direct30,
            authority: .containerMetadata
        )

        let result = try MatrixSonicSphereRenderer().render(
            source: source,
            sourceBlock: sourceBlock,
            profile: .directThirtyOne(),
            policy: .direct30Identity,
            context: context()
        )

        XCTAssertEqual(result.resolvedRenderMode, .direct30)
        XCTAssertEqual(result.samples.channelCount, 31)
        XCTAssertEqual(result.samples.frameCount, 1)
        for channel in 0..<30 {
            XCTAssertEqual(
                result.samples.sample(channel: channel, frame: 0),
                Float(channel + 1),
                accuracy: tolerance
            )
        }
        XCTAssertEqual(result.samples.sample(channel: 30, frame: 0), 0, accuracy: tolerance)
        XCTAssertEqual(result.renderedBlock.sourceID, "direct30")
        XCTAssertEqual(result.renderedBlock.channelCount, 31)
        XCTAssertEqual(result.renderedBlock.outputMapID, "direct-30.1-logical")
        XCTAssertEqual(result.renderedBlock.sphereProfileID, "sonic-sphere-31-reference")
        XCTAssertEqual(result.renderedBlock.contract.layout.authority, .rendererOutputMap)
        XCTAssertEqual(result.renderedBlock.contract.layout.authorityID, "direct-30.1-logical")
        XCTAssertTrue(result.ledger.contains(stage: .render, owner: .sonicSphereRenderer))
        XCTAssertFalse(result.ledger.hasHiddenConversionRisk)
    }

    func testFiftyTwoChannelSourceIsBlockedByDefaultProfilePolicy() throws {
        let source = try audioBlock(channelCount: 52, layout: .discrete(count: 52))
        try source.setFrameCount(1)
        let sourceBlock = try canonicalSourceBlock(
            sourceID: "wide-52",
            channelCount: 52,
            layout: .discrete(count: 52),
            authority: .containerMetadata
        )

        XCTAssertThrowsError(
            try MatrixSonicSphereRenderer().render(
                source: source,
                sourceBlock: sourceBlock,
                profile: .directThirtyOne(),
                policy: .production(),
                context: context()
            )
        ) { error in
            XCTAssertEqual(
                error as? AudioError,
                .invalidRenderGraphPlan(
                    "SonicSphereRenderer blocks 52-channel sources above profile output count 31."
                )
            )
        }
    }

    func testRendererRejectsUnknownOrBypassLayoutAuthority() throws {
        let source = try audioBlock(channelCount: 2, layout: .stereo)
        try source.setFrameCount(1)
        let pureSphericalSource = try canonicalSourceBlock(
            sourceID: "already-rendered",
            channelCount: 2,
            layout: .stereo,
            authority: .pureSphericalManifest
        )

        XCTAssertThrowsError(
            try MatrixSonicSphereRenderer().render(
                source: source,
                sourceBlock: pureSphericalSource,
                profile: .directThirtyOne(),
                policy: .production(),
                context: context()
            )
        ) { error in
            XCTAssertEqual(
                error as? AudioError,
                .invalidRenderGraphPlan("SonicSphereRenderer rejects source layout authority pureSphericalManifest.")
            )
        }
    }

    func testDirect30PolicyRejectsNonThirtyChannelSource() throws {
        let source = try audioBlock(channelCount: 31, layout: .direct31)
        try source.setFrameCount(1)
        let sourceBlock = try canonicalSourceBlock(
            sourceID: "direct31",
            channelCount: 31,
            layout: .direct31,
            authority: .containerMetadata
        )

        XCTAssertThrowsError(
            try MatrixSonicSphereRenderer().render(
                source: source,
                sourceBlock: sourceBlock,
                profile: .directThirtyOne(),
                policy: .direct30Identity,
                context: context()
            )
        ) { error in
            XCTAssertEqual(
                error as? AudioError,
                .invalidRenderGraphPlan("SonicSphere render policy direct30-identity requires 30 source channels.")
            )
        }
    }

    func testSonicSphereRendererDoesNotReferenceVLCMonitorTypes() throws {
        let source = try String(contentsOf: sonicSphereRendererSourceURL(), encoding: .utf8)

        for forbidden in [
            "VLC",
            "Vlc",
            "OrbisonicVLCReference",
            "StereoMonitorBlock"
        ] {
            XCTAssertFalse(source.contains(forbidden), "SonicSphereRenderer.swift references \(forbidden)")
        }
    }

    private func audioBlock(
        channelCount: Int,
        layout: AudioChannelLayoutDescriptor,
        sampleRate: AudioSampleRate = .rate48000
    ) throws -> CanonicalAudioBlock {
        try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: sampleRate,
                channelCount: channelCount,
                frameCount: 1,
                layout: layout
            )
        )
    }

    private func canonicalSourceBlock(
        sourceID: String,
        channelCount: Int,
        layout: AudioChannelLayoutDescriptor,
        authority: SourceLayoutAuthority,
        sampleRate: AudioSampleRate = .rate48000
    ) throws -> CanonicalSourceBlock {
        try CanonicalSourceBlock(
            contract: AudioBlockContract(
                sourceID: sourceID,
                generation: 7,
                sampleRate: sampleRate,
                frameStart: 0,
                frameCount: 1,
                channelCount: channelCount,
                processingFormat: .float32NonInterleavedPCM,
                layout: SourceLayout(descriptor: layout, authority: authority)
            )
        )
    }

    private func context() -> SonicSphereRenderContext {
        SonicSphereRenderContext(sessionID: "sonic-sphere-tests", sourceKind: .localFile)
    }

    private func sonicSphereRendererSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AudioCore/SonicSphereRenderer.swift")
    }
}
