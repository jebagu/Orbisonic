import XCTest

final class AppleSpatialHeadphoneUITests: XCTestCase {
    func testAppleSpatialHeadphonesToggleIsAbsentFromOutputUI() throws {
        let contentView = try source("Sources/Orbisonic/ContentView.swift")
        let viewModel = try source("Sources/Orbisonic/OrbisonicViewModel.swift")

        XCTAssertFalse(contentView.contains("Apple Spatial Headphones"))
        XCTAssertFalse(contentView.contains("model.setAppleSpatialHeadphonesEnabled"))
        XCTAssertFalse(contentView.contains("import AVFAudio"))
        XCTAssertFalse(contentView.contains("import CoreAudio"))
        XCTAssertFalse(contentView.contains("AVAudioEnvironmentNode"))
        XCTAssertFalse(viewModel.contains("AVAudioEnvironmentNode"))
        XCTAssertFalse(viewModel.contains("AudioBufferList"))
        XCTAssertTrue(viewModel.contains("appleSpatialHeadphonesEnabled = false"))
    }

    func testOutputMonitorDoesNotContainAppleSpatialToggle() throws {
        let contentView = try source("Sources/Orbisonic/ContentView.swift")

        XCTAssertTrue(contentView.contains(#"title: "Output 1: Listen locally""#))
        XCTAssertTrue(contentView.contains(#"title: "Output 2: Sonic Sphere""#))
        XCTAssertFalse(contentView.contains("appleSpatialHeadphonesMonitorToggle"))
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
