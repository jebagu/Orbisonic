import XCTest

final class AppleSpatialHeadphoneUITests: XCTestCase {
    func testAppleSpatialHeadphonesToggleSendsCommandOnly() throws {
        let contentView = try source("Sources/Orbisonic/ContentView.swift")
        let viewModel = try source("Sources/Orbisonic/OrbisonicViewModel.swift")

        XCTAssertTrue(contentView.contains("Apple Spatial Headphones"))
        XCTAssertTrue(contentView.contains("model.setAppleSpatialHeadphonesEnabled"))
        XCTAssertFalse(contentView.contains("import AVFAudio"))
        XCTAssertFalse(contentView.contains("import CoreAudio"))
        XCTAssertFalse(contentView.contains("AVAudioEnvironmentNode"))
        XCTAssertFalse(viewModel.contains("AVAudioEnvironmentNode"))
        XCTAssertFalse(viewModel.contains("AudioBufferList"))
    }

    func testOutputMonitorToggleIsInOutputOneOnly() throws {
        let contentView = try source("Sources/Orbisonic/ContentView.swift")
        let outputOneRange = try XCTUnwrap(contentView.range(of: #"title: "Output 1: Listen locally""#))
        let outputTwoRange = try XCTUnwrap(contentView.range(of: #"title: "Output 2: Sonic Sphere""#))
        let toggleRange = try XCTUnwrap(contentView.range(of: "appleSpatialHeadphonesMonitorToggle"))

        XCTAssertLessThan(outputOneRange.lowerBound, toggleRange.lowerBound)
        XCTAssertLessThan(toggleRange.lowerBound, outputTwoRange.lowerBound)
    }

    func testAppleSpatialGraphDoesNotExposeImplementationObjectsToUI() throws {
        let contentView = try source("Sources/Orbisonic/ContentView.swift")
        let forbidden = [
            "AVAudioEngine",
            "AVAudioEnvironmentNode",
            "AVAudioNode",
            "AudioUnit",
            "AudioDeviceID",
            "AudioBufferList",
            "UnsafeMutablePointer"
        ]
        for token in forbidden {
            XCTAssertFalse(contentView.contains(token), "\(token) must not be in the Output Monitor UI.")
        }
    }

    private func source(_ relativePath: String) throws -> String {
        try String(contentsOf: packageRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
