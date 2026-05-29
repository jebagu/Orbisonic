import CoreAudio
import XCTest
@testable import Orbisonic

final class NormalMonitorRouteBranchRemovalTests: XCTestCase {
    func testOldDirectRendererConditionNowUsesNormalMonitor() {
        let route = selectRoute(
            rendererMode: .quad,
            activeOutputRoute: rendererCapableRoute,
            rendererOutputRoute: rendererCapableRoute,
            requiredSonicSphereOutputChannelCount: 31
        )

        XCTAssertFalse(RendererAudioRoutingPolicy.usesDirectRendererAudio(
            renderMode: .quad,
            activeOutputRoute: rendererCapableRoute,
            rendererOutputRoute: rendererCapableRoute,
            requiredOutputChannelCount: 31
        ))
        assertNormalMonitor(route)
    }

    func testOldEnvironmentFallbackConditionNowUsesNormalMonitor() {
        let route = selectRoute(
            rendererMode: .surround51,
            activeOutputRoute: builtInStereoRoute,
            rendererOutputRoute: .unavailable,
            requiredSonicSphereOutputChannelCount: 31
        )

        assertNormalMonitor(route)
        XCTAssertFalse(route.usesAVAudioEnvironmentNode)
        XCTAssertFalse(route.usesPointSourceSpatialPlacement)
    }

    func testRendererCapableRouteStillUsesNormalMonitor() {
        let route = selectRoute(
            rendererMode: .surround51,
            activeOutputRoute: builtInStereoRoute,
            rendererOutputRoute: rendererCapableRoute,
            requiredSonicSphereOutputChannelCount: 31
        )

        assertNormalMonitor(route)
    }

    func testRendererIncapableRouteStillUsesNormalMonitor() {
        let route = selectRoute(
            rendererMode: .surround51,
            activeOutputRoute: builtInStereoRoute,
            rendererOutputRoute: rendererIncapableRoute,
            requiredSonicSphereOutputChannelCount: 31
        )

        assertNormalMonitor(route)
    }

    func testInsufficientChannelRouteStillUsesNormalMonitor() {
        let route = selectRoute(
            rendererMode: .quad,
            activeOutputRoute: rendererIncapableRoute,
            rendererOutputRoute: rendererIncapableRoute,
            requiredSonicSphereOutputChannelCount: 31
        )

        assertNormalMonitor(route)
    }

    func testNormalMonitorDoesNotDependOnRendererCapableRoute() {
        let capable = selectRoute(
            rendererMode: .surround51,
            activeOutputRoute: builtInStereoRoute,
            rendererOutputRoute: rendererCapableRoute,
            requiredSonicSphereOutputChannelCount: 31
        )
        let incapable = selectRoute(
            rendererMode: .surround51,
            activeOutputRoute: builtInStereoRoute,
            rendererOutputRoute: rendererIncapableRoute,
            requiredSonicSphereOutputChannelCount: 31
        )

        XCTAssertEqual(capable, incapable)
        assertNormalMonitor(capable)
        assertNormalMonitor(incapable)
    }

    func testNormalMonitorDoesNotDependOnSonicSphereOutputChannelCount() {
        let fullSphere = selectRoute(
            rendererMode: .quad,
            activeOutputRoute: builtInStereoRoute,
            rendererOutputRoute: rendererCapableRoute,
            requiredSonicSphereOutputChannelCount: 31
        )
        let noSphere = selectRoute(
            rendererMode: .quad,
            activeOutputRoute: builtInStereoRoute,
            rendererOutputRoute: rendererCapableRoute,
            requiredSonicSphereOutputChannelCount: 0
        )

        XCTAssertEqual(fullSphere, noSphere)
        assertNormalMonitor(fullSphere)
        assertNormalMonitor(noSphere)
    }

    func testNormalMonitorDoesNotDependOnAnyRendererModeIncludingDirectBypass() {
        let reference = selectRoute(
            rendererMode: .automatic,
            activeOutputRoute: builtInStereoRoute,
            rendererOutputRoute: rendererCapableRoute,
            requiredSonicSphereOutputChannelCount: 31
        )

        for mode in rendererModesIncludingDirectBypass {
            let selected = selectRoute(
                rendererMode: mode,
                activeOutputRoute: builtInStereoRoute,
                rendererOutputRoute: rendererCapableRoute,
                requiredSonicSphereOutputChannelCount: 31
            )

            XCTAssertEqual(selected, reference, mode.displayName)
            assertNormalMonitor(selected)
        }
    }

    func testAudibleRouteSelectionHasSingleTerminalRenderer() throws {
        XCTAssertEqual(NormalMonitorTerminalRenderer.allCases, [.normalMonitorStereoDownmixer])

        let routes = [
            selectRoute(rendererMode: .automatic, activeOutputRoute: builtInStereoRoute, rendererOutputRoute: .unavailable, requiredSonicSphereOutputChannelCount: 0),
            selectRoute(rendererMode: .quad, activeOutputRoute: rendererCapableRoute, rendererOutputRoute: rendererCapableRoute, requiredSonicSphereOutputChannelCount: 31),
            selectRoute(rendererMode: .surround51, activeOutputRoute: builtInStereoRoute, rendererOutputRoute: rendererIncapableRoute, requiredSonicSphereOutputChannelCount: 31)
        ]

        XCTAssertTrue(routes.allSatisfy { $0.terminalRenderer == .normalMonitorStereoDownmixer })
        try assertOrbisonicEngineDoesNotContainOldAudibleBranchModel()
    }

    private func selectRoute(
        rendererMode: RendererRenderMode,
        activeOutputRoute: OutputRouteInfo,
        rendererOutputRoute: OutputRouteInfo,
        requiredSonicSphereOutputChannelCount: Int
    ) -> NormalMonitorRouteDescriptor {
        NormalMonitorAudibleRouteSelector.select(
            sourceFamily: .localFile,
            sourceLayoutDescription: "Synthetic 5.1 source",
            rendererMode: rendererMode,
            activeOutputRoute: activeOutputRoute,
            rendererOutputRoute: rendererOutputRoute,
            requiredSonicSphereOutputChannelCount: requiredSonicSphereOutputChannelCount
        )
    }

    private var rendererModesIncludingDirectBypass: [RendererRenderMode] {
        [
            .automatic,
            .mono,
            .stereo,
            .quad,
            .surround51,
            .auro80,
            .auro91,
            .auro101,
            .auro111714h,
            .auro111515hT,
            .auro121,
            .auro131,
            .direct30,
            .direct31
        ]
    }

    private var builtInStereoRoute: OutputRouteInfo {
        outputRoute(uid: "built-in", name: "MacBook Speakers", transport: "Built-In", channels: 2)
    }

    private var rendererCapableRoute: OutputRouteInfo {
        outputRoute(
            uid: "dante-vsc",
            name: "Dante Virtual Soundcard",
            manufacturer: "Audinate",
            transport: "Virtual",
            channels: 64
        )
    }

    private var rendererIncapableRoute: OutputRouteInfo {
        outputRoute(uid: "usb-16", name: "USB 16ch Interface", transport: "USB", channels: 16)
    }

    private func outputRoute(
        uid: String,
        name: String,
        manufacturer: String = "Test",
        transport: String,
        channels: Int
    ) -> OutputRouteInfo {
        OutputRouteInfo(
            deviceID: AudioDeviceID(channels),
            uid: uid,
            deviceName: name,
            manufacturer: manufacturer,
            transportName: transport,
            outputChannelCount: channels,
            nominalSampleRate: 48_000
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

    private func assertOrbisonicEngineDoesNotContainOldAudibleBranchModel() throws {
        let source = try sourceFile("Sources/Orbisonic/OrbisonicEngine.swift")
        for forbidden in [
            "usesDirectRendererPlayback",
            "playDirectRenderer",
            "makeFileRendererNode",
            "AVAudioEnvironmentNode",
            "outputType = .headphones",
            "path=\\\"direct-renderer\\\""
        ] {
            XCTAssertFalse(source.contains(forbidden), "OrbisonicEngine.swift still contains \(forbidden)")
        }
    }

    private func sourceFile(_ relativePath: String) throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = packageRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
