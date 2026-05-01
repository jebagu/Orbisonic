import Foundation

enum NormalMonitorGraphNode: String, CaseIterable, Sendable {
    case sourcePCM
    case normalMonitorStereoDownmixer
    case outputGainMixer
    case mainMixerNode
    case systemOutput
    case avAudioEnvironmentNode
    case audibleSonicSphereMatrix
}

struct NormalMonitorGraphEdge: Equatable, Sendable {
    let sourceFamily: NormalMonitorSourceFamily
    let from: NormalMonitorGraphNode
    let to: NormalMonitorGraphNode
}

struct NormalMonitorGraphGainStage: Equatable, Sendable {
    let node: NormalMonitorGraphNode
    let gain: Float
    let appliesMonitorVolume: Bool
}

struct NormalMonitorGraphTopology: Equatable, Sendable {
    static let defaultMonitorOutputGain: Float = 0.92

    let sourceFamily: NormalMonitorSourceFamily
    let terminalRenderer: NormalMonitorTerminalRenderer
    let nodes: [NormalMonitorGraphNode]
    let edges: [NormalMonitorGraphEdge]
    let gainStages: [NormalMonitorGraphGainStage]

    init(
        sourceFamily: NormalMonitorSourceFamily,
        terminalRenderer: NormalMonitorTerminalRenderer = .normalMonitorStereoDownmixer,
        nodes: [NormalMonitorGraphNode],
        edges: [NormalMonitorGraphEdge],
        gainStages: [NormalMonitorGraphGainStage]
    ) {
        self.sourceFamily = sourceFamily
        self.terminalRenderer = terminalRenderer
        self.nodes = nodes
        self.edges = edges
        self.gainStages = gainStages
    }

    static func audible(sourceFamily: NormalMonitorSourceFamily) -> NormalMonitorGraphTopology {
        let nodes: [NormalMonitorGraphNode] = [
            .sourcePCM,
            .normalMonitorStereoDownmixer,
            .outputGainMixer,
            .mainMixerNode,
            .systemOutput
        ]
        return NormalMonitorGraphTopology(
            sourceFamily: sourceFamily,
            nodes: nodes,
            edges: [
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .sourcePCM, to: .normalMonitorStereoDownmixer),
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .normalMonitorStereoDownmixer, to: .outputGainMixer),
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .outputGainMixer, to: .mainMixerNode),
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .mainMixerNode, to: .systemOutput)
            ],
            gainStages: [
                NormalMonitorGraphGainStage(
                    node: .outputGainMixer,
                    gain: defaultMonitorOutputGain,
                    appliesMonitorVolume: true
                ),
                NormalMonitorGraphGainStage(
                    node: .mainMixerNode,
                    gain: 1,
                    appliesMonitorVolume: false
                )
            ]
        )
    }

    static func audibleTopologies() -> [NormalMonitorGraphTopology] {
        NormalMonitorSourceFamily.allCases.map { audible(sourceFamily: $0) }
    }

    static func rebuilding(
        _ previous: NormalMonitorGraphTopology,
        for sourceFamily: NormalMonitorSourceFamily
    ) -> NormalMonitorGraphTopology {
        _ = previous
        return audible(sourceFamily: sourceFamily)
    }

    var audiblePaths: [[NormalMonitorGraphNode]] {
        paths(from: .sourcePCM, to: .systemOutput)
    }

    var hasExactlyOneAudiblePath: Bool {
        audiblePaths == [[.sourcePCM, .normalMonitorStereoDownmixer, .outputGainMixer, .mainMixerNode, .systemOutput]]
    }

    var hasDuplicateDirectAndStagedRoutes: Bool {
        hasEdge(from: .sourcePCM, to: .mainMixerNode)
            && hasPath([.sourcePCM, .normalMonitorStereoDownmixer, .outputGainMixer, .mainMixerNode])
    }

    var containsEnvironmentNode: Bool {
        nodes.contains(.avAudioEnvironmentNode)
    }

    var containsAudibleSonicSphereMatrixNode: Bool {
        nodes.contains(.audibleSonicSphereMatrix)
    }

    var monitorGainApplicationCount: Int {
        gainStages.filter(\.appliesMonitorVolume).count
    }

    var mainMixerAppliesMonitorVolume: Bool {
        gainStages.contains { $0.node == .mainMixerNode && $0.appliesMonitorVolume }
    }

    func containsStaleConnections(for expectedSourceFamily: NormalMonitorSourceFamily) -> Bool {
        edges.contains { $0.sourceFamily != expectedSourceFamily }
    }

    func hasEdge(from: NormalMonitorGraphNode, to: NormalMonitorGraphNode) -> Bool {
        edges.contains { $0.from == from && $0.to == to }
    }

    func render(
        inputs: [[Float]],
        layout: SurroundLayout,
        monitorOutputGain: Float = defaultMonitorOutputGain
    ) throws -> [[Float]] {
        let downmixer = NormalMonitorStereoDownmixer(layout: layout)
        var output = try downmixer.render(inputs: inputs)
        guard monitorGainApplicationCount == 1 else { return output }
        for channelIndex in output.indices {
            for frameIndex in output[channelIndex].indices {
                output[channelIndex][frameIndex] *= monitorOutputGain
            }
        }
        return output
    }

    private func paths(
        from start: NormalMonitorGraphNode,
        to end: NormalMonitorGraphNode
    ) -> [[NormalMonitorGraphNode]] {
        func walk(
            _ current: NormalMonitorGraphNode,
            visited: [NormalMonitorGraphNode]
        ) -> [[NormalMonitorGraphNode]] {
            if current == end {
                return [visited]
            }

            return edges
                .filter { $0.from == current && !visited.contains($0.to) }
                .flatMap { edge in
                    walk(edge.to, visited: visited + [edge.to])
                }
        }

        return walk(start, visited: [start])
    }

    private func hasPath(_ nodes: [NormalMonitorGraphNode]) -> Bool {
        guard nodes.count >= 2 else { return false }
        return zip(nodes, nodes.dropFirst()).allSatisfy { from, to in
            hasEdge(from: from, to: to)
        }
    }
}
