import XCTest
@testable import Orbisonic

final class AudioSpatialUsageAuditTests: XCTestCase {
    func testAudiblePlaybackNeverCreatesAVAudioEnvironmentNode() throws {
        XCTAssertTrue(AudioSpatialUsageAudit.audiblePlaybackDescriptors.allSatisfy(NormalMonitorSpatialGuard.validatesAudiblePlayback))
        try assertAudiblePlaybackSourcesDoNotContain(["AVAudioEnvironmentNode"])
    }

    func testAudiblePlaybackNeverConnectsAVAudioEnvironmentNode() throws {
        for descriptor in AudioSpatialUsageAudit.audiblePlaybackDescriptors {
            XCTAssertFalse(descriptor.connectsAVAudioEnvironmentNode)
        }
        try assertAudiblePlaybackSourcesDoNotContain([
            "connect(environment",
            "to: environment",
            "from: environment"
        ])
    }

    func testAudiblePlaybackNeverUsesHRTF() throws {
        for descriptor in AudioSpatialUsageAudit.audiblePlaybackDescriptors {
            XCTAssertFalse(descriptor.selectsHRTF)
        }
        try assertAudiblePlaybackSourcesDoNotContain([
            ".HRTF",
            "renderingAlgorithm = .HRTF"
        ])
    }

    func testAudiblePlaybackNeverUsesHRTFHQ() throws {
        for descriptor in AudioSpatialUsageAudit.audiblePlaybackDescriptors {
            XCTAssertFalse(descriptor.selectsHRTFHQ)
        }
        try assertAudiblePlaybackSourcesDoNotContain([
            ".HRTFHQ",
            "renderingAlgorithm = .HRTFHQ"
        ])
    }

    func testAudiblePlaybackNeverUsesHeadphoneEnvironmentOutput() throws {
        for descriptor in AudioSpatialUsageAudit.audiblePlaybackDescriptors {
            XCTAssertFalse(descriptor.selectsHeadphoneEnvironmentOutput)
        }
        try assertAudiblePlaybackSourcesDoNotContain([
            "outputType = .headphones",
            ".outputType=.headphones"
        ])
    }

    func testAudiblePlaybackNeverUsesPointSourcePlacement() throws {
        for descriptor in AudioSpatialUsageAudit.audiblePlaybackDescriptors {
            XCTAssertFalse(descriptor.convertsSourceToPointSource)
        }
        try assertAudiblePlaybackSourcesDoNotContain([
            "AVAudio3DMixing",
            "AVAudio3DPoint",
            "sourceMode = .pointSource",
            ".sourceMode=.pointSource",
            "listenerPosition",
            "listenerAngularOrientation",
            ".position ="
        ])
    }

    func testLocalFallbackDoesNotUseSpatialPreview() {
        let route = NormalMonitorRoutePlanner.route(
            for: .filePlayback,
            sourceLayoutDescription: "Local fallback"
        )

        assertNoSpatialPreview(route)
    }

    func testLiveFallbackDoesNotUseSpatialPreview() {
        for sourceMode in [SourceMode.roon, .spotify, .aux] {
            let route = NormalMonitorRoutePlanner.route(
                for: sourceMode,
                sourceLayoutDescription: "\(sourceMode.rawValue) fallback"
            )

            assertNoSpatialPreview(route)
        }
    }

    func testMonitorRoutePlannerHasNoBinauralPreviewMode() throws {
        XCTAssertTrue(RendererRenderMode.allCases.map(\.rawValue).contains("binaural_180"))
        XCTAssertTrue(RendererTwoChannelPreference.allCases.map(\.rawValue).contains("binaural_180"))
        try XCTAssertFalse(sourceFile("Sources/Orbisonic/NormalMonitorRouteDescriptor.swift").localizedCaseInsensitiveContains("binaural"))
    }

    func testRoutePlannerHasNoReferenceMode() throws {
        XCTAssertFalse(NormalMonitorSourceFamily.allCases.map(\.rawValue).contains("reference"))
        XCTAssertFalse(RendererRenderMode.allCases.map(\.displayName).contains { $0.localizedCaseInsensitiveContains("reference") })
        try XCTAssertFalse(sourceFile("Sources/Orbisonic/NormalMonitorRouteDescriptor.swift").localizedCaseInsensitiveContains("reference"))
    }

    private let audiblePlaybackSourcePaths = [
        "Sources/Orbisonic/OrbisonicEngine.swift",
        "Sources/Orbisonic/LiveAudioBridge.swift",
        "Sources/Orbisonic/LoopbackSourceSupport.swift",
        "Sources/Orbisonic/TestToneSupport.swift",
        "Sources/Orbisonic/SpatialTuning.swift"
    ]

    private func assertAudiblePlaybackSourcesDoNotContain(
        _ forbiddenSymbols: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        for sourcePath in audiblePlaybackSourcePaths {
            let text = try sourceFile(sourcePath)
            for symbol in forbiddenSymbols {
                XCTAssertFalse(
                    text.contains(symbol),
                    "\(sourcePath) contains forbidden audible spatial symbol \(symbol)",
                    file: file,
                    line: line
                )
            }
        }
    }

    private func assertNoSpatialPreview(
        _ route: NormalMonitorRouteDescriptor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(route.usesNormalMonitor, file: file, line: line)
        XCTAssertTrue(route.usesStereoDownmix, file: file, line: line)
        XCTAssertEqual(route.outputChannelCount, 2, file: file, line: line)
        XCTAssertFalse(route.usesAVAudioEnvironmentNode, file: file, line: line)
        XCTAssertFalse(route.usesHRTF, file: file, line: line)
        XCTAssertFalse(route.usesHRTFHQ, file: file, line: line)
        XCTAssertFalse(route.usesHeadphoneEnvironmentOutput, file: file, line: line)
        XCTAssertFalse(route.usesPointSourceSpatialPlacement, file: file, line: line)
        XCTAssertFalse(route.usesAudibleDirectSonicSphereMatrix, file: file, line: line)
        XCTAssertFalse(route.warningDescriptions.contains { $0.localizedCaseInsensitiveContains("spatial") }, file: file, line: line)
        XCTAssertFalse(route.warningDescriptions.contains { $0.localizedCaseInsensitiveContains("binaural") }, file: file, line: line)
        XCTAssertFalse(route.warningDescriptions.contains { $0.localizedCaseInsensitiveContains("reference") }, file: file, line: line)
    }

    private func sourceFile(_ relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = projectRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
