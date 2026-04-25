import Foundation

struct RendererVector3: Codable, Hashable {
    var x: Double
    var y: Double
    var z: Double

    static let zero = RendererVector3(x: 0, y: 0, z: 0)

    var length: Double {
        sqrt(x * x + y * y + z * z)
    }

    var normalized: RendererVector3 {
        let magnitude = length
        guard magnitude > 0 else { return .zero }
        return RendererVector3(x: x / magnitude, y: y / magnitude, z: z / magnitude)
    }

    func distance(to other: RendererVector3) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        let dz = z - other.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }

    static func cartesian(azimuth: Double, elevation: Double, radius: Double) -> RendererVector3 {
        let azimuthRadians = azimuth * .pi / 180
        let elevationRadians = elevation * .pi / 180
        let x = -sin(azimuthRadians) * cos(elevationRadians) * radius
        let y = sin(elevationRadians) * radius
        let z = -cos(azimuthRadians) * cos(elevationRadians) * radius
        return RendererVector3(x: x, y: y, z: z)
    }
}

enum RendererOutputTopologyKind: String, Codable, CaseIterable, Identifiable {
    case sonicSphere

    var id: String { rawValue }
}

enum RendererSpherePlacement: String, Codable, CaseIterable, Identifiable {
    case fibonacciSphere

    var id: String { rawValue }
}

enum RendererAlgorithm: String, Codable, CaseIterable, Identifiable {
    case distanceWeightedPower

    var id: String { rawValue }
}

enum RendererLFEPolicy: String, Codable, CaseIterable, Identifiable {
    case lfeBusOnly

    var id: String { rawValue }
}

struct RendererOutputTopology: Codable, Hashable {
    var kind: RendererOutputTopologyKind
    var fullRangeCount: Int
    var lfeCount: Int
    var placement: RendererSpherePlacement

    var outputCount: Int {
        fullRangeCount + lfeCount
    }
}

struct RendererInputGeometry: Codable, Hashable {
    var bedRadius: Double
    var overheadRadiusScale: Double
}

struct RendererParameters: Codable, Hashable {
    var algorithm: RendererAlgorithm
    var spread: Double
    var normalizePower: Bool
    var lfePolicy: RendererLFEPolicy
}

struct RendererPreset: Codable, Identifiable, Hashable {
    var schemaVersion: Int
    var id: String
    var name: String
    var description: String
    var outputTopology: RendererOutputTopology
    var inputGeometry: RendererInputGeometry
    var rendering: RendererParameters

    static let currentSchemaVersion = 1

    static let sonicSphere30Point1 = RendererPreset(
        schemaVersion: currentSchemaVersion,
        id: "sonic-sphere-30-1-default",
        name: "Sonic Sphere 30.1 Default",
        description: "Default Sonic Sphere renderer with a 30-speaker shell, one LFE bus, and a radius-scaled input bed.",
        outputTopology: RendererOutputTopology(
            kind: .sonicSphere,
            fullRangeCount: 30,
            lfeCount: 1,
            placement: .fibonacciSphere
        ),
        inputGeometry: RendererInputGeometry(
            bedRadius: 1.0,
            overheadRadiusScale: 1.0
        ),
        rendering: RendererParameters(
            algorithm: .distanceWeightedPower,
            spread: 1.0,
            normalizePower: true,
            lfePolicy: .lfeBusOnly
        )
    )

    func replacingBedRadius(_ radius: Double) -> RendererPreset {
        var copy = self
        copy.inputGeometry.bedRadius = radius
        return copy
    }
}

struct RendererOutputSpeaker: Identifiable, Hashable {
    let index: Int
    let isLFE: Bool
    let position: RendererVector3

    var id: String {
        isLFE ? "lfe-\(index)" : "sphere-\(index)"
    }

    var displayName: String {
        isLFE ? "LFE \(index + 1)" : "Sphere \(index + 1)"
    }

    var shortLabel: String {
        isLFE ? "LFE" : "\(index + 1)"
    }
}

struct RendererInputSpeaker: Identifiable, Hashable {
    let channel: SurroundChannel
    let position: RendererVector3

    var id: String { channel.id }
    var displayName: String { channel.displayName }
    var shortLabel: String { channel.shortLabel }
}

struct RendererSceneModel: Hashable {
    var preset: RendererPreset
    var inputSpeakers: [RendererInputSpeaker]
    var outputSpeakers: [RendererOutputSpeaker]
    var matrix: RendererMatrix

    static let empty = RendererSceneModel(
        preset: .sonicSphere30Point1,
        inputSpeakers: [],
        outputSpeakers: SonicSphereTopology.outputSpeakers(for: .sonicSphere30Point1),
        matrix: .empty
    )
}

struct RendererMatrix: Hashable {
    var gains: [[Double]]

    static let empty = RendererMatrix(gains: [])

    var inputCount: Int {
        gains.count
    }

    var outputCount: Int {
        gains.first?.count ?? 0
    }

    func strongestOutputs(forInputAt inputIndex: Int, limit: Int = 3) -> [(index: Int, gain: Double)] {
        guard gains.indices.contains(inputIndex) else { return [] }
        return gains[inputIndex]
            .enumerated()
            .filter { $0.element > 0.0001 }
            .sorted { $0.element > $1.element }
            .prefix(limit)
            .map { (index: $0.offset, gain: $0.element) }
    }
}

enum SonicSphereAudioRenderer {
    static func render(inputChannels: [[Float]], matrix: RendererMatrix) -> [[Float]] {
        guard matrix.inputCount > 0,
              matrix.outputCount > 0,
              inputChannels.count == matrix.inputCount,
              let frameCount = inputChannels.first?.count,
              inputChannels.allSatisfy({ $0.count == frameCount })
        else {
            return []
        }

        var outputs = Array(
            repeating: Array(repeating: Float(0), count: frameCount),
            count: matrix.outputCount
        )

        for inputIndex in 0..<matrix.inputCount {
            let input = inputChannels[inputIndex]
            for outputIndex in 0..<matrix.outputCount {
                let gain = Float(matrix.gains[inputIndex][outputIndex])
                guard abs(gain) > 0.000_001 else { continue }

                for frame in 0..<frameCount {
                    outputs[outputIndex][frame] += input[frame] * gain
                }
            }
        }

        return outputs
    }
}

enum SonicSphereTopology {
    static func outputSpeakers(for preset: RendererPreset) -> [RendererOutputSpeaker] {
        let fullRangeCount = max(preset.outputTopology.fullRangeCount, 0)
        var speakers = fibonacciSphere(count: fullRangeCount).enumerated().map { index, point in
            RendererOutputSpeaker(index: index, isLFE: false, position: point)
        }

        let lfeCount = max(preset.outputTopology.lfeCount, 0)
        speakers += (0..<lfeCount).map { index in
            RendererOutputSpeaker(
                index: fullRangeCount + index,
                isLFE: true,
                position: RendererVector3(x: 0, y: -1.12, z: 0)
            )
        }

        return speakers
    }

    private static func fibonacciSphere(count: Int) -> [RendererVector3] {
        guard count > 0 else { return [] }
        let goldenAngle = Double.pi * (3 - sqrt(5))

        return (0..<count).map { index in
            let sample = Double(index) + 0.5
            let y = 1 - (2 * sample / Double(count))
            let radius = sqrt(max(0, 1 - y * y))
            let theta = goldenAngle * Double(index)
            let x = cos(theta) * radius
            let z = sin(theta) * radius
            return RendererVector3(x: x, y: y, z: z).normalized
        }
    }
}

enum RendererInputLayoutGeometry {
    static func inputSpeakers(for layout: SurroundLayout, preset: RendererPreset) -> [RendererInputSpeaker] {
        layout.channels.map { channel in
            RendererInputSpeaker(
                channel: channel,
                position: position(for: channel, in: layout, geometry: preset.inputGeometry)
            )
        }
    }

    private static func position(
        for channel: SurroundChannel,
        in layout: SurroundLayout,
        geometry: RendererInputGeometry
    ) -> RendererVector3 {
        let placement = placement(for: channel.role, index: channel.index, channelCount: layout.channelCount)
        let radius = placement.isHeight
            ? geometry.bedRadius * geometry.overheadRadiusScale
            : geometry.bedRadius
        return RendererVector3.cartesian(
            azimuth: placement.azimuth,
            elevation: placement.elevation,
            radius: radius
        )
    }

    private static func placement(
        for role: SurroundChannelRole,
        index: Int,
        channelCount: Int
    ) -> (azimuth: Double, elevation: Double, isHeight: Bool) {
        switch role {
        case .frontLeft:
            return (30, 0, false)
        case .frontRight:
            return (-30, 0, false)
        case .center:
            return (0, 0, false)
        case .lfe:
            return (-18, -18, false)
        case .lfe2:
            return (18, -18, false)
        case .frontLeftCenter:
            return (15, 0, false)
        case .frontRightCenter:
            return (-15, 0, false)
        case .wideLeft:
            return (60, 0, false)
        case .wideRight:
            return (-60, 0, false)
        case .sideLeft:
            return (90, 0, false)
        case .sideRight:
            return (-90, 0, false)
        case .rearLeft:
            return (135, 0, false)
        case .rearRight:
            return (-135, 0, false)
        case .rearCenter:
            return (180, 0, false)
        case .topFrontLeft:
            return (30, 52, true)
        case .topFrontCenter:
            return (0, 54, true)
        case .topFrontRight:
            return (-30, 52, true)
        case .topMiddleLeft:
            return (90, 65, true)
        case .topMiddleCenter:
            return (0, 68, true)
        case .topMiddleRight:
            return (-90, 65, true)
        case .topRearLeft:
            return (135, 55, true)
        case .topRearCenter:
            return (180, 58, true)
        case .topRearRight:
            return (-135, 55, true)
        case .discrete:
            let count = max(channelCount, 1)
            let azimuth = 180 - (360 / Double(count)) * Double(index)
            return (azimuth, 0, false)
        }
    }
}

enum RendererMatrixBuilder {
    static func sceneModel(for layout: SurroundLayout?, preset: RendererPreset) -> RendererSceneModel {
        let outputs = SonicSphereTopology.outputSpeakers(for: preset)
        let inputs = layout.map { RendererInputLayoutGeometry.inputSpeakers(for: $0, preset: preset) } ?? []
        let matrix = build(inputSpeakers: inputs, outputSpeakers: outputs, preset: preset)
        return RendererSceneModel(
            preset: preset,
            inputSpeakers: inputs,
            outputSpeakers: outputs,
            matrix: matrix
        )
    }

    static func build(
        inputSpeakers: [RendererInputSpeaker],
        outputSpeakers: [RendererOutputSpeaker],
        preset: RendererPreset
    ) -> RendererMatrix {
        guard !inputSpeakers.isEmpty, !outputSpeakers.isEmpty else {
            return .empty
        }

        let rows = inputSpeakers.map { input in
            gains(for: input, outputSpeakers: outputSpeakers, preset: preset)
        }

        return RendererMatrix(gains: rows)
    }

    private static func gains(
        for input: RendererInputSpeaker,
        outputSpeakers: [RendererOutputSpeaker],
        preset: RendererPreset
    ) -> [Double] {
        if input.channel.role.isLFE, preset.rendering.lfePolicy == .lfeBusOnly {
            let lfeIndexes = outputSpeakers.indices.filter { outputSpeakers[$0].isLFE }
            guard !lfeIndexes.isEmpty else {
                return Array(repeating: 0, count: outputSpeakers.count)
            }

            let gain = 1 / sqrt(Double(lfeIndexes.count))
            return outputSpeakers.indices.map { lfeIndexes.contains($0) ? gain : 0 }
        }

        let spread = max(preset.rendering.spread, 0.1)
        let raw = outputSpeakers.map { output -> Double in
            guard !output.isLFE else { return 0 }
            let distance = max(input.position.distance(to: output.position), 0.0001)
            return pow(1 / distance, 1.8 * spread)
        }

        guard preset.rendering.normalizePower else {
            return raw
        }

        let power = sqrt(raw.reduce(0) { partial, gain in
            partial + gain * gain
        })

        guard power > 0 else { return raw }
        return raw.map { $0 / power }
    }
}

struct RendererPresetStore {
    let fileManager: FileManager
    let directoryURL: URL

    init(fileManager: FileManager = .default, directoryURL: URL? = nil) {
        self.fileManager = fileManager
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            self.directoryURL = support
                .appendingPathComponent("Orbisonic", isDirectory: true)
                .appendingPathComponent("Renderer Presets", isDirectory: true)
        }
    }

    func loadPresets() throws -> [RendererPreset] {
        try ensureDirectoryAndDefaultPreset()

        let files = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension.caseInsensitiveCompare("json") == .orderedSame }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        let decoder = JSONDecoder()
        let presets = files.compactMap { url -> RendererPreset? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(RendererPreset.self, from: data)
        }

        if presets.isEmpty {
            return [.sonicSphere30Point1]
        }

        return presets.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    @discardableResult
    func save(_ preset: RendererPreset) throws -> URL {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let url = directoryURL.appendingPathComponent(Self.fileName(for: preset), isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(preset)
        try data.write(to: url, options: .atomic)
        return url
    }

    func ensureDirectoryAndDefaultPreset() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let defaultURL = directoryURL.appendingPathComponent(Self.fileName(for: .sonicSphere30Point1))
        if !fileManager.fileExists(atPath: defaultURL.path) {
            try save(.sonicSphere30Point1)
        }
    }

    static func fileName(for preset: RendererPreset) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = preset.id.map { character in
            character.unicodeScalars.allSatisfy { allowed.contains($0) } ? character : "-"
        }
        let stem = String(cleaned).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(stem.isEmpty ? "renderer-preset" : stem).json"
    }
}
