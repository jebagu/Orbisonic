import XCTest
@testable import Orbisonic

final class AppBuildInfoTests: XCTestCase {
    func testBuildStatusTextIncludesLauncherRefAndShortCommit() {
        let text = AppBuildInfo.statusText(
            version: "1.1",
            buildNumber: "2026.05.03.1",
            gitRefKind: "branch",
            gitRefName: "codex/pure-audio-branch",
            gitCommit: "609b2115350d9f0011d801947476b34187c408bb"
        )

        XCTAssertEqual(text, "v1.1 build 2026.05.03.1 · branch codex/pure-audio-branch · 609b211")
    }

    func testBuildStatusTextPreservesDirtySuffix() {
        let text = AppBuildInfo.statusText(
            version: "1.1",
            buildNumber: "2026.05.03.1",
            gitRefKind: "release",
            gitRefName: "stable-1.11",
            gitCommit: "02854b83ee92a0644a4a2b4c9d5187172f9c3926-dirty"
        )

        XCTAssertEqual(text, "v1.1 build 2026.05.03.1 · release stable-1.11 · 02854b8-dirty")
    }
}
