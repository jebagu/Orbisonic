import XCTest
@testable import Orbisonic

final class RendererModuleTests: XCTestCase {
    func testDefaultPresetBuildsThirtyPointOneSpeakerTopology() {
        let preset = RendererPreset.sonicSphere30Point1
        let speakers = SonicSphereTopology.outputSpeakers(for: preset)

        XCTAssertEqual(speakers.count, 31)
        XCTAssertEqual(speakers.filter(\.isLFE).count, 1)
        XCTAssertEqual(speakers.filter { !$0.isLFE }.count, 30)

        for speaker in speakers where !speaker.isLFE {
            XCTAssertEqual(speaker.position.length, 1.0, accuracy: 0.000_1)
        }
    }

    func testInputBedRadiusPlacesEarHeightChannelsOnEquator() {
        var preset = RendererPreset.sonicSphere30Point1
        preset.inputGeometry.bedRadius = 1.25
        let layout = SurroundLayoutDetector.fallbackLayout(for: 6)
        let inputs = RendererInputLayoutGeometry.inputSpeakers(for: layout, preset: preset)

        let center = inputs.first { $0.channel.role == .center }
        XCTAssertEqual(center?.position.y ?? -1, 0, accuracy: 0.000_1)
        XCTAssertEqual(center?.position.length ?? 0, 1.25, accuracy: 0.000_1)
        XCTAssertLessThan(center?.position.z ?? 1, 0)
    }

    func testOverheadSpeakersUseScaledBedRadius() {
        var preset = RendererPreset.sonicSphere30Point1
        preset.inputGeometry.bedRadius = 1.2
        preset.inputGeometry.overheadRadiusScale = 0.75
        let layout = SurroundLayoutDetector.fallbackLayout(for: 12)
        let inputs = RendererInputLayoutGeometry.inputSpeakers(for: layout, preset: preset)

        let topFrontLeft = inputs.first { $0.channel.role == .topFrontLeft }
        XCTAssertGreaterThan(topFrontLeft?.position.y ?? 0, 0)
        XCTAssertEqual(topFrontLeft?.position.length ?? 0, 0.9, accuracy: 0.000_1)
    }

    func testMatrixNormalizesFullRangeInputPowerAndRoutesLFEToLFEBus() {
        let preset = RendererPreset.sonicSphere30Point1
        let layout = SurroundLayoutDetector.fallbackLayout(for: 6)
        let scene = RendererMatrixBuilder.sceneModel(for: layout, preset: preset)

        XCTAssertEqual(scene.matrix.inputCount, 6)
        XCTAssertEqual(scene.matrix.outputCount, 31)

        let frontLeftIndex = layout.channels.firstIndex { $0.role == .frontLeft }!
        let frontLeftPower = scene.matrix.gains[frontLeftIndex].reduce(0) { partial, gain in
            partial + gain * gain
        }
        XCTAssertEqual(frontLeftPower, 1.0, accuracy: 0.000_1)
        XCTAssertEqual(scene.matrix.gains[frontLeftIndex].last ?? -1, 0, accuracy: 0.000_1)

        let lfeIndex = layout.channels.firstIndex { $0.role == .lfe }!
        XCTAssertEqual(scene.matrix.gains[lfeIndex].dropLast().reduce(0, +), 0, accuracy: 0.000_1)
        XCTAssertEqual(scene.matrix.gains[lfeIndex].last ?? 0, 1, accuracy: 0.000_1)
    }

    func testAudioRendererAppliesMatrixToMultichannelFrames() {
        let matrix = RendererMatrix(gains: [
            [1.0, 0.5, 0.0],
            [0.0, 0.5, 1.0]
        ])
        let outputs = SonicSphereAudioRenderer.render(
            inputChannels: [
                [1.0, 0.5],
                [0.25, -0.25]
            ],
            matrix: matrix
        )

        XCTAssertEqual(outputs.count, 3)
        XCTAssertEqual(outputs[0], [1.0, 0.5])
        XCTAssertEqual(outputs[1][0], 0.625, accuracy: 0.000_1)
        XCTAssertEqual(outputs[1][1], 0.125, accuracy: 0.000_1)
        XCTAssertEqual(outputs[2], [0.25, -0.25])
    }

    func testPresetStoreRoundTripsHumanReadableJSON() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("orbisonic-renderer-tests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = RendererPresetStore(directoryURL: directory)
        var preset = RendererPreset.sonicSphere30Point1
        preset.id = "custom-radius"
        preset.name = "Custom Radius"
        preset.inputGeometry.bedRadius = 1.4

        let url = try store.save(preset)
        let data = try Data(contentsOf: url)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\n"))
        XCTAssertTrue(json.contains("\"bedRadius\" : 1.4"))

        let loaded = try store.loadPresets()
        XCTAssertTrue(loaded.contains(where: { $0.id == "custom-radius" && $0.inputGeometry.bedRadius == 1.4 }))
    }
}
