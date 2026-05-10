import OrbisonicVLCReference
import XCTest

final class VlcCapabilityProbeTests: XCTestCase {
    func testDefaultBuildReportsDisabledInsteadOfRequiringVlcRuntime() {
        var checkedFiles: [String] = []
        var checkedDirectories: [String] = []
        let probe = VlcCapabilityProbe(
            configuration: VlcCapabilityProbeConfiguration(
                candidateLibraryPaths: ["/missing/libvlc.dylib"],
                candidatePluginDirectoryPaths: ["/missing/plugins"]
            ),
            fileExists: { path in
                checkedFiles.append(path)
                return false
            },
            directoryExists: { path in
                checkedDirectories.append(path)
                return false
            }
        )

        let report = probe.probeCapabilities()

        XCTAssertFalse(report.buildFlagEnabled)
        XCTAssertEqual(report.status, .disabledAtBuild)
        XCTAssertFalse(report.runtimeAvailable)
        XCTAssertFalse(report.canOpenLocalStereoMonitor)
        XCTAssertNil(report.libraryPath)
        XCTAssertNil(report.pluginDirectoryPath)
        XCTAssertEqual(report.diagnostics.map(\.code), [.buildFlagDisabled])
        XCTAssertTrue(checkedFiles.isEmpty)
        XCTAssertTrue(checkedDirectories.isEmpty)
    }

    func testEnabledBuildReportsUnavailableWhenRuntimeFilesAreMissing() {
        let probe = VlcCapabilityProbe(
            configuration: VlcCapabilityProbeConfiguration(
                buildFlagEnabled: true,
                candidateLibraryPaths: ["/missing/libvlc.dylib"],
                candidatePluginDirectoryPaths: ["/missing/plugins"]
            ),
            fileExists: { _ in false },
            directoryExists: { _ in false }
        )

        let report = probe.probeCapabilities()

        XCTAssertTrue(report.buildFlagEnabled)
        XCTAssertEqual(report.status, .unavailable)
        XCTAssertFalse(report.runtimeAvailable)
        XCTAssertFalse(report.canOpenLocalStereoMonitor)
        XCTAssertNil(report.libraryPath)
        XCTAssertNil(report.pluginDirectoryPath)
        XCTAssertEqual(
            Set(report.diagnostics.map(\.code)),
            [.libraryNotFound, .pluginDirectoryMissing]
        )
    }

    func testEnabledBuildReportsUnavailableWhenPluginDirectoryIsMissing() {
        let probe = VlcCapabilityProbe(
            configuration: VlcCapabilityProbeConfiguration(
                buildFlagEnabled: true,
                candidateLibraryPaths: ["/vlc/libvlc.dylib"],
                candidatePluginDirectoryPaths: ["/missing/plugins"]
            ),
            fileExists: { $0 == "/vlc/libvlc.dylib" },
            directoryExists: { _ in false }
        )

        let report = probe.probeCapabilities()

        XCTAssertEqual(report.status, .unavailable)
        XCTAssertFalse(report.runtimeAvailable)
        XCTAssertFalse(report.canOpenLocalStereoMonitor)
        XCTAssertEqual(report.libraryPath, "/vlc/libvlc.dylib")
        XCTAssertNil(report.pluginDirectoryPath)
        XCTAssertEqual(report.diagnostics.map(\.code), [.pluginDirectoryMissing])
    }

    func testEnabledBuildReportsAvailableWhenLibraryAndPluginsExist() {
        let probe = VlcCapabilityProbe(
            configuration: VlcCapabilityProbeConfiguration(
                buildFlagEnabled: true,
                candidateLibraryPaths: ["/missing/libvlc.dylib", "/vlc/libvlc.dylib"],
                candidatePluginDirectoryPaths: ["/missing/plugins", "/vlc/plugins"]
            ),
            fileExists: { $0 == "/vlc/libvlc.dylib" },
            directoryExists: { $0 == "/vlc/plugins" }
        )

        let report = probe.probeCapabilities()

        XCTAssertEqual(report.status, .available)
        XCTAssertTrue(report.runtimeAvailable)
        XCTAssertTrue(report.canOpenLocalStereoMonitor)
        XCTAssertEqual(report.libraryPath, "/vlc/libvlc.dylib")
        XCTAssertEqual(report.pluginDirectoryPath, "/vlc/plugins")
        XCTAssertEqual(report.diagnostics.map(\.code), [.runtimeAvailable])
        XCTAssertEqual(report.callbackContract.formatFourCC, "FL32")
        XCTAssertEqual(report.callbackContract.channelCount, 2)
    }

    func testBuildFlagNameIsStableForPackageAndReleaseScripts() {
        XCTAssertEqual(VlcReferenceBuildSettings.swiftFlagName, "ORBISONIC_ENABLE_VLC_REFERENCE")
    }
}
