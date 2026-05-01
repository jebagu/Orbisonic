import XCTest
@testable import Orbisonic

final class NormalMonitorGraphTopologyTests: XCTestCase {
    private let tolerance: Float = 1e-6

    func testNormalMonitorGraphHasExactlyOneAudiblePath() {
        for topology in NormalMonitorGraphTopology.audibleTopologies() {
            XCTAssertTrue(topology.hasExactlyOneAudiblePath, "\(topology.sourceFamily)")
            XCTAssertEqual(topology.audiblePaths.count, 1, "\(topology.sourceFamily)")
            XCTAssertEqual(
                topology.audiblePaths.first,
                [.sourcePCM, .normalMonitorStereoDownmixer, .outputGainMixer, .mainMixerNode, .systemOutput],
                "\(topology.sourceFamily)"
            )
        }
    }

    func testNormalMonitorGraphHasNoDuplicateDirectAndStagedRoutes() throws {
        for topology in NormalMonitorGraphTopology.audibleTopologies() {
            XCTAssertFalse(topology.hasDuplicateDirectAndStagedRoutes, "\(topology.sourceFamily)")
            XCTAssertFalse(topology.hasEdge(from: .sourcePCM, to: .mainMixerNode), "\(topology.sourceFamily)")
        }

        let engine = try sourceFile("Sources/Orbisonic/OrbisonicEngine.swift")
        XCTAssertFalse(engine.contains("engine.connect(player, to: engine.mainMixerNode"))
        XCTAssertFalse(engine.contains("engine.connect(sourceNode, to: engine.mainMixerNode"))
        XCTAssertFalse(engine.contains("engine.connect(node, to: engine.mainMixerNode"))
    }

    func testNormalMonitorGraphDoesNotContainEnvironmentNode() throws {
        XCTAssertTrue(NormalMonitorGraphTopology.audibleTopologies().allSatisfy { !$0.containsEnvironmentNode })

        let audibleSources = try [
            sourceFile("Sources/Orbisonic/OrbisonicEngine.swift"),
            sourceFile("Sources/Orbisonic/LiveAudioBridge.swift"),
            sourceFile("Sources/Orbisonic/LoopbackSourceSupport.swift")
        ].joined(separator: "\n")
        XCTAssertFalse(audibleSources.contains("AVAudioEnvironmentNode"))
        XCTAssertFalse(audibleSources.contains("to: environment"))
        XCTAssertFalse(audibleSources.contains("connect(environment"))
    }

    func testNormalMonitorGraphDoesNotContainAudibleSonicSphereMatrixNode() {
        for topology in NormalMonitorGraphTopology.audibleTopologies() {
            XCTAssertFalse(topology.containsAudibleSonicSphereMatrixNode, "\(topology.sourceFamily)")
            XCTAssertFalse(topology.nodes.contains(.audibleSonicSphereMatrix), "\(topology.sourceFamily)")
        }
    }

    func testMonitorGainIsAppliedExactlyOnce() {
        for topology in NormalMonitorGraphTopology.audibleTopologies() {
            XCTAssertEqual(topology.monitorGainApplicationCount, 1, "\(topology.sourceFamily)")
            XCTAssertEqual(
                topology.gainStages.filter(\.appliesMonitorVolume).map(\.node),
                [.outputGainMixer],
                "\(topology.sourceFamily)"
            )
        }
    }

    func testMainMixerDoesNotDoubleApplyVolume() throws {
        for topology in NormalMonitorGraphTopology.audibleTopologies() {
            XCTAssertFalse(topology.mainMixerAppliesMonitorVolume, "\(topology.sourceFamily)")
            guard let mainMixerGain = topology.gainStages.first(where: { $0.node == .mainMixerNode })?.gain else {
                XCTFail("Missing main mixer gain stage for \(topology.sourceFamily)")
                continue
            }
            XCTAssertEqual(mainMixerGain, 1, accuracy: tolerance)
        }

        let engine = try sourceFile("Sources/Orbisonic/OrbisonicEngine.swift")
        XCTAssertTrue(engine.contains("engine.mainMixerNode.outputVolume = 1"))
        XCTAssertFalse(engine.contains("engine.mainMixerNode.outputVolume = min(max(volume"))
    }

    func testImpulseIsNotDuplicatedByMonitorTopology() throws {
        let topology = NormalMonitorGraphTopology.audible(sourceFamily: .localFile)
        let layout = SurroundLayout(
            name: "Stereo",
            channels: [
                SurroundChannel(index: 0, role: .frontLeft),
                SurroundChannel(index: 1, role: .frontRight)
            ]
        )
        let output = try topology.render(
            inputs: [
                [0, 1, 0, 0],
                [0, 0, 0, 0]
            ],
            layout: layout,
            monitorOutputGain: 0.92
        )

        assertFloatArrayEqual(output[0], [0, 0.92, 0, 0])
        assertFloatArrayEqual(output[1], [0, 0, 0, 0])
        XCTAssertEqual(nonZeroSampleCount(output), 1)
        XCTAssertEqual(output.flatMap { $0 }.max() ?? 0, Float(0.92), accuracy: tolerance)
    }

    func testRebuildingGraphDoesNotLeaveStaleConnections() {
        let stale = staleTopology(sourceFamily: .localFile)
        let rebuilt = NormalMonitorGraphTopology.rebuilding(stale, for: .localFile)

        XCTAssertFalse(rebuilt.containsEnvironmentNode)
        XCTAssertFalse(rebuilt.containsAudibleSonicSphereMatrixNode)
        XCTAssertFalse(rebuilt.hasDuplicateDirectAndStagedRoutes)
        XCTAssertFalse(rebuilt.containsStaleConnections(for: .localFile))
        XCTAssertTrue(rebuilt.hasExactlyOneAudiblePath)
    }

    func testSwitchingSourceFamilyDoesNotLeaveStaleConnections() {
        let previous = NormalMonitorGraphTopology.audible(sourceFamily: .localFile)
        let switched = NormalMonitorGraphTopology.rebuilding(previous, for: .liveLoopback)

        XCTAssertEqual(switched.sourceFamily, .liveLoopback)
        XCTAssertFalse(switched.edges.contains { $0.sourceFamily == .localFile })
        XCTAssertFalse(switched.containsStaleConnections(for: .liveLoopback))
        XCTAssertTrue(switched.hasExactlyOneAudiblePath)
    }

    private func staleTopology(sourceFamily: NormalMonitorSourceFamily) -> NormalMonitorGraphTopology {
        NormalMonitorGraphTopology(
            sourceFamily: sourceFamily,
            nodes: [
                .sourcePCM,
                .normalMonitorStereoDownmixer,
                .outputGainMixer,
                .mainMixerNode,
                .systemOutput,
                .avAudioEnvironmentNode,
                .audibleSonicSphereMatrix
            ],
            edges: [
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .sourcePCM, to: .normalMonitorStereoDownmixer),
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .normalMonitorStereoDownmixer, to: .outputGainMixer),
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .outputGainMixer, to: .mainMixerNode),
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .sourcePCM, to: .mainMixerNode),
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .sourcePCM, to: .avAudioEnvironmentNode),
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .sourcePCM, to: .audibleSonicSphereMatrix),
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .mainMixerNode, to: .systemOutput)
            ],
            gainStages: [
                NormalMonitorGraphGainStage(node: .outputGainMixer, gain: 0.92, appliesMonitorVolume: true),
                NormalMonitorGraphGainStage(node: .mainMixerNode, gain: 0.92, appliesMonitorVolume: true)
            ]
        )
    }

    private func nonZeroSampleCount(_ output: [[Float]]) -> Int {
        output.flatMap { $0 }.filter { abs($0) > tolerance }.count
    }

    private func assertFloatArrayEqual(
        _ actual: [Float],
        _ expected: [Float],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for index in actual.indices {
            XCTAssertEqual(actual[index], expected[index], accuracy: tolerance, file: file, line: line)
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
