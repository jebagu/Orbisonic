import CoreAudio
import XCTest
@testable import Orbisonic

final class NormalMonitorRouteDescriptorTests: XCTestCase {
    func testLocalFilesUseOnlyNormalMonitor() {
        assertNormalMonitorRoute(
            NormalMonitorRoutePlanner.audibleRoute(
                sourceFamily: .localFile,
                sourceLayoutDescription: "7.1.4 local file"
            )
        )
    }

    func testRoonLiveUsesOnlyNormalMonitor() {
        assertNormalMonitorRoute(
            NormalMonitorRoutePlanner.route(
                for: .roon,
                sourceLayoutDescription: "Roon live loopback"
            ),
            expectedFamily: .liveLoopback
        )
    }

    func testSpotifyLiveUsesOnlyNormalMonitor() {
        assertNormalMonitorRoute(
            NormalMonitorRoutePlanner.route(
                for: .spotify,
                sourceLayoutDescription: "Spotify live loopback"
            ),
            expectedFamily: .liveLoopback
        )
    }

    func testAuxLiveUsesOnlyNormalMonitor() {
        assertNormalMonitorRoute(
            NormalMonitorRoutePlanner.route(
                for: .aux,
                sourceLayoutDescription: "Aux live loopback"
            ),
            expectedFamily: .liveLoopback
        )
    }

    func testAtmosDRPLiveUsesOnlyNormalMonitor() {
        assertNormalMonitorRoute(
            NormalMonitorRoutePlanner.route(
                for: .atmosDRP,
                sourceLayoutDescription: "Atmos DRP live loopback"
            ),
            expectedFamily: .liveLoopback
        )
    }

    func testBlackHoleLiveUsesOnlyNormalMonitorIfSupported() {
        assertNormalMonitorRoute(
            NormalMonitorRoutePlanner.audibleRoute(
                sourceFamily: .liveLoopback,
                sourceLayoutDescription: "Legacy BlackHole live loopback",
                warningDescriptions: ["Legacy BlackHole is treated as a loopback source only."]
            ),
            expectedFamily: .liveLoopback
        )
    }

    func testDiagnosticsUseOnlyNormalMonitorOrAreExplicitlyNonPlayback() {
        assertNormalMonitorRoute(
            NormalMonitorRoutePlanner.route(
                for: .testTone,
                sourceLayoutDescription: "Diagnostic tone"
            ),
            expectedFamily: .diagnostics
        )

        let idle = NormalMonitorRoutePlanner.route(
            for: .off,
            sourceLayoutDescription: "No active route"
        )
        XCTAssertEqual(idle.sourceFamily, .diagnostics)
        XCTAssertEqual(idle.warningDescriptions, ["No active audible source."])
        assertNormalMonitorRoute(idle, expectedFamily: .diagnostics)
    }

    func testNoAudibleRouteUsesReferenceMonitor() {
        for route in audibleRoutes {
            XCTAssertFalse(route.warningDescriptions.contains { $0.localizedCaseInsensitiveContains("reference monitor") })
            assertNormalMonitorRoute(route)
        }
    }

    func testBinauralRendererPreferenceDoesNotChangeNormalMonitorRoute() {
        XCTAssertTrue(RendererTwoChannelPreference.allCases.map(\.rawValue).contains("binaural_180"))
        XCTAssertTrue(RendererRenderMode.allCases.map(\.rawValue).contains("binaural_180"))

        let resolved = RendererModePolicy.effectiveRequestedMode(
            requestedMode: .automatic,
            inputChannelCount: 2,
            alwaysMono: false,
            twoChannelPreference: .binaural
        )
        XCTAssertEqual(resolved, .binaural)

        for route in audibleRoutes {
            XCTAssertFalse(route.warningDescriptions.contains { $0.localizedCaseInsensitiveContains("binaural") })
            assertNormalMonitorRoute(route)
        }
    }

    func testNoAudibleRouteUsesDirectSonicSphereMatrix() {
        XCTAssertFalse(RendererRenderMode.allCases.contains(.direct30))
        XCTAssertFalse(RendererRenderMode.allCases.contains(.direct31))
        XCTAssertFalse(RendererAudioRoutingPolicy.usesDirectRendererAudio(
            renderMode: .quad,
            activeOutputRoute: rendererCapableRoute,
            rendererOutputRoute: rendererCapableRoute,
            requiredOutputChannelCount: 31
        ))

        for route in audibleRoutes {
            XCTAssertFalse(route.usesAudibleDirectSonicSphereMatrix)
            assertNormalMonitorRoute(route)
        }
    }

    func testEveryAudibleRouteOutputsExactlyTwoChannels() {
        XCTAssertTrue(audibleRoutes.allSatisfy { $0.outputChannelCount == 2 })
    }

    private var audibleRoutes: [NormalMonitorRouteDescriptor] {
        [
            NormalMonitorRoutePlanner.route(for: .filePlayback, sourceLayoutDescription: "Local file"),
            NormalMonitorRoutePlanner.route(for: .roon, sourceLayoutDescription: "Roon live loopback"),
            NormalMonitorRoutePlanner.route(for: .spotify, sourceLayoutDescription: "Spotify live loopback"),
            NormalMonitorRoutePlanner.route(for: .aux, sourceLayoutDescription: "Aux live loopback"),
            NormalMonitorRoutePlanner.audibleRoute(sourceFamily: .liveLoopback, sourceLayoutDescription: "Legacy BlackHole live loopback"),
            NormalMonitorRoutePlanner.route(for: .testTone, sourceLayoutDescription: "Diagnostics")
        ]
    }

    private var rendererCapableRoute: OutputRouteInfo {
        OutputRouteInfo(
            deviceID: AudioDeviceID(99),
            uid: "dante-vsc",
            deviceName: "Dante Virtual Soundcard",
            manufacturer: "Audinate",
            transportName: "Virtual",
            outputChannelCount: 64,
            nominalSampleRate: 48_000
        )
    }

    private func assertNormalMonitorRoute(
        _ route: NormalMonitorRouteDescriptor,
        expectedFamily: NormalMonitorSourceFamily? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if let expectedFamily {
            XCTAssertEqual(route.sourceFamily, expectedFamily, file: file, line: line)
        }
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
