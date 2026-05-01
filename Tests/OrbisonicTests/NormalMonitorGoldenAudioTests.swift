import XCTest
@testable import Orbisonic

final class NormalMonitorGoldenAudioTests: XCTestCase {
    private let tolerance: Float = 1e-6

    func testNormalMonitorStereoIdentityGolden() throws {
        let fixture = NormalMonitorGoldenFixture(roles: [.frontLeft, .frontRight])
        let input: [[Float]] = [
            [0.25, -0.5, 0.75, -1],
            [-0.125, 0.375, -0.625, 0.875]
        ]

        let output = try fixture.render(input)

        assertSamples(output, equals: input)
    }

    func testNormalMonitorStereoNullAgainstInput() throws {
        let fixture = NormalMonitorGoldenFixture(roles: [.frontLeft, .frontRight])
        let input: [[Float]] = [
            [1, -0.25, 0.5, -0.75],
            [-1, 0.25, -0.5, 0.75]
        ]
        let output = try fixture.render(input)
        let null = zip(output, input).map { outputChannel, inputChannel in
            zip(outputChannel, inputChannel).map { $0 - $1 }
        }

        assertSamples(null, equals: [
            [0, 0, 0, 0],
            [0, 0, 0, 0]
        ])
    }

    func testNormalMonitorImpulseHasNoDuplicateDelayedCopy() throws {
        let fixture = NormalMonitorGoldenFixture(roles: [.frontLeft, .frontRight], sourceFamily: .localFile)
        let output = try fixture.render([
            [0, 0, 1, 0, 0, 0],
            [0, 0, 0, 0, 0, 0]
        ])

        assertSamples(output, equals: [
            [0, 0, 1, 0, 0, 0],
            [0, 0, 0, 0, 0, 0]
        ])
        XCTAssertEqual(nonZeroSamples(in: output), 1)
        XCTAssertEqual(output[0][2], 1, accuracy: tolerance)
        XCTAssertFalse(fixture.topology.hasDuplicateDirectAndStagedRoutes)
        XCTAssertTrue(fixture.topology.hasExactlyOneAudiblePath)
    }

    func testNormalMonitorFiveOneGoldenDownmix() throws {
        let fixture = NormalMonitorGoldenFixture(
            roles: [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight]
        )
        let output = try fixture.render([
            [10, 11],
            [20, 21],
            [30, 31],
            [40, 41],
            [50, 51],
            [60, 61]
        ])

        assertSamples(output, equals: [
            [
                10 + 30 * 0.70710678 + 50 * 0.70710678,
                11 + 31 * 0.70710678 + 51 * 0.70710678
            ],
            [
                20 + 30 * 0.70710678 + 60 * 0.70710678,
                21 + 31 * 0.70710678 + 61 * 0.70710678
            ]
        ])
    }

    func testCenterOnlyInputProducesEqualLeftRight() throws {
        let fixture = NormalMonitorGoldenFixture(roles: [.center])
        let output = try fixture.render([[0.5, -1, 2]])

        assertSamples(output, equals: [
            [0.5 * 0.70710678, -1 * 0.70710678, 2 * 0.70710678],
            [0.5 * 0.70710678, -1 * 0.70710678, 2 * 0.70710678]
        ])
        assertSamples([output[0]], equals: [output[1]])
    }

    func testLFEOnlyInputIsSilentInDefaultMonitorOutput() throws {
        let fixture = NormalMonitorGoldenFixture(roles: [.lfe])
        let output = try fixture.render([[1, -1, 0.5, -0.5]])

        assertSamples(output, equals: [
            [0, 0, 0, 0],
            [0, 0, 0, 0]
        ])
    }

    func testHeightInputsFoldWithoutSpatialFlags() throws {
        let fixture = NormalMonitorGoldenFixture(roles: [.topFrontLeft, .topFrontRight, .topMiddleCenter])
        let output = try fixture.render([
            [2, 4],
            [6, 8],
            [10, 12]
        ])

        assertSamples(output, equals: [
            [
                2 * 0.5 + 10 * (0.5 * 0.70710678),
                4 * 0.5 + 12 * (0.5 * 0.70710678)
            ],
            [
                6 * 0.5 + 10 * (0.5 * 0.70710678),
                8 * 0.5 + 12 * (0.5 * 0.70710678)
            ]
        ])
        XCTAssertFalse(fixture.route.usesAVAudioEnvironmentNode)
        XCTAssertFalse(fixture.route.usesHRTF)
        XCTAssertFalse(fixture.route.usesHRTFHQ)
        XCTAssertFalse(fixture.route.usesPointSourceSpatialPlacement)
    }

    func testMetersEnabledAndDisabledProduceIdenticalPCM() throws {
        let fixture = NormalMonitorGoldenFixture(
            roles: [.frontLeft, .frontRight, .center, .lfe, .sideLeft, .sideRight]
        )
        let input: [[Float]] = [
            [10, 11, 12],
            [20, 21, 22],
            [30, 31, 32],
            [40, 41, 42],
            [50, 51, 52],
            [60, 61, 62]
        ]

        let metersOff = try fixture.render(input)
        let metersOn = try fixture.renderWithMetersEnabled(input)

        assertSamples(metersOn, equals: metersOff)
    }

    func testLocalToLiveToLocalRouteSwitchHasNoStalePath() throws {
        let localFixture = NormalMonitorGoldenFixture(roles: [.frontLeft, .frontRight], sourceFamily: .localFile)
        let liveFixture = NormalMonitorGoldenFixture(roles: [.frontLeft, .frontRight], sourceFamily: .liveLoopback)
        let input: [[Float]] = [
            [0, 1, 0, -1],
            [1, 0, -1, 0]
        ]
        let expected = try localFixture.render(input)

        let localToLive = NormalMonitorGraphTopology.rebuilding(localFixture.topology, for: .liveLoopback)
        XCTAssertFalse(localToLive.edges.contains { $0.sourceFamily == .localFile })
        XCTAssertFalse(localToLive.containsStaleConnections(for: .liveLoopback))
        XCTAssertFalse(localToLive.hasDuplicateDirectAndStagedRoutes)
        XCTAssertTrue(localToLive.hasExactlyOneAudiblePath)
        assertSamples(try liveFixture.render(input), equals: expected)

        let liveToLocal = NormalMonitorGraphTopology.rebuilding(localToLive, for: .localFile)
        XCTAssertFalse(liveToLocal.edges.contains { $0.sourceFamily == .liveLoopback })
        XCTAssertFalse(liveToLocal.containsStaleConnections(for: .localFile))
        XCTAssertFalse(liveToLocal.hasDuplicateDirectAndStagedRoutes)
        XCTAssertTrue(liveToLocal.hasExactlyOneAudiblePath)
        assertSamples(try localFixture.render(input), equals: expected)
    }

    func testGoldenFixtureNeverUsesEnvironmentNode() {
        for sourceFamily in NormalMonitorSourceFamily.allCases {
            let fixture = NormalMonitorGoldenFixture(roles: [.frontLeft, .frontRight], sourceFamily: sourceFamily)

            XCTAssertFalse(fixture.route.usesAVAudioEnvironmentNode)
            XCTAssertFalse(fixture.topology.containsEnvironmentNode)
        }
    }

    func testGoldenFixtureNeverUsesHRTF() {
        for sourceFamily in NormalMonitorSourceFamily.allCases {
            let fixture = NormalMonitorGoldenFixture(roles: [.frontLeft, .frontRight], sourceFamily: sourceFamily)

            XCTAssertFalse(fixture.route.usesHRTF)
            XCTAssertFalse(fixture.route.usesHRTFHQ)
            XCTAssertFalse(fixture.route.usesHeadphoneEnvironmentOutput)
            XCTAssertFalse(AudioSpatialUsageAudit.normalMonitorAudiblePlayback.selectsHRTF)
            XCTAssertFalse(AudioSpatialUsageAudit.normalMonitorAudiblePlayback.selectsHRTFHQ)
        }
    }

    func testGoldenFixtureNeverUsesDirectSonicSphereAudibleOutput() {
        for sourceFamily in NormalMonitorSourceFamily.allCases {
            let fixture = NormalMonitorGoldenFixture(roles: [.frontLeft, .frontRight], sourceFamily: sourceFamily)

            XCTAssertFalse(fixture.route.usesAudibleDirectSonicSphereMatrix)
            XCTAssertFalse(fixture.topology.containsAudibleSonicSphereMatrixNode)
            XCTAssertEqual(fixture.route.terminalRenderer, .normalMonitorStereoDownmixer)
        }
    }

    private func nonZeroSamples(in output: [[Float]]) -> Int {
        output.flatMap { $0 }.filter { abs($0) > tolerance }.count
    }

    private func assertSamples(
        _ actual: [[Float]],
        equals expected: [[Float]],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for channelIndex in expected.indices {
            XCTAssertEqual(actual[channelIndex].count, expected[channelIndex].count, file: file, line: line)
            for frameIndex in expected[channelIndex].indices {
                XCTAssertEqual(
                    actual[channelIndex][frameIndex],
                    expected[channelIndex][frameIndex],
                    accuracy: tolerance,
                    "channel \(channelIndex) frame \(frameIndex)",
                    file: file,
                    line: line
                )
            }
        }
    }
}

private struct NormalMonitorGoldenFixture {
    let layout: SurroundLayout
    let route: NormalMonitorRouteDescriptor
    let topology: NormalMonitorGraphTopology

    init(
        roles: [SurroundChannelRole],
        sourceFamily: NormalMonitorSourceFamily = .localFile
    ) {
        layout = SurroundLayout(
            name: "Golden \(roles.count) channel fixture",
            channels: roles.enumerated().map { index, role in
                SurroundChannel(index: index, role: role)
            }
        )
        route = NormalMonitorRoutePlanner.audibleRoute(
            sourceFamily: sourceFamily,
            sourceLayoutDescription: "Golden fixture \(roles.map(\.shortLabel).joined(separator: ", "))"
        )
        topology = NormalMonitorGraphTopology.audible(sourceFamily: sourceFamily)
    }

    func render(_ input: [[Float]]) throws -> [[Float]] {
        try assertUsableRoute()
        return try NormalMonitorStereoDownmixer(layout: layout, appliesHeadroom: false)
            .render(inputs: input)
    }

    func renderWithMetersEnabled(_ input: [[Float]]) throws -> [[Float]] {
        let output = try render(input)
        let service = MeteringService()
        service.ingest(signal: .input, sampleBuffers: input, frameCount: frameCount(in: input))
        service.ingest(signal: .monitor, sampleBuffers: output, frameCount: frameCount(in: output))
        return try render(input)
    }

    private func assertUsableRoute() throws {
        guard route.usesNormalMonitor,
              route.usesStereoDownmix,
              route.outputChannelCount == 2,
              route.terminalRenderer == .normalMonitorStereoDownmixer,
              !route.usesAVAudioEnvironmentNode,
              !route.usesHRTF,
              !route.usesHRTFHQ,
              !route.usesHeadphoneEnvironmentOutput,
              !route.usesPointSourceSpatialPlacement,
              !route.usesAudibleDirectSonicSphereMatrix,
              !route.hasDuplicateAudiblePath,
              topology.hasExactlyOneAudiblePath,
              !topology.containsEnvironmentNode,
              !topology.containsAudibleSonicSphereMatrixNode,
              !topology.hasDuplicateDirectAndStagedRoutes
        else {
            throw NormalMonitorGoldenFixtureError.invalidNormalMonitorFixture
        }
    }

    private func frameCount(in samples: [[Float]]) -> Int {
        samples.first?.count ?? 0
    }
}

private enum NormalMonitorGoldenFixtureError: Error {
    case invalidNormalMonitorFixture
}
