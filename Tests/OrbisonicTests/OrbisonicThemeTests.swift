import XCTest
@testable import Orbisonic

final class OrbisonicThemeTests: XCTestCase {
    func testColorSchemesExposeStableRawValuesAndDisplayText() {
        XCTAssertEqual(
            OrbisonicColorScheme.allCases.map(\.rawValue),
            [
                "lab",
                "kimiPurple",
                "daftPunkBow",
                "rackMint",
                "rackPink",
                "rackBlue",
                "ember",
                "graphite",
                "flamingoGreen",
                "flamingoPink",
                "dustyRose"
            ]
        )
        XCTAssertEqual(OrbisonicColorScheme.defaultScheme, .lab)

        for scheme in OrbisonicColorScheme.allCases {
            XCTAssertFalse(scheme.name.isEmpty)
            XCTAssertFalse(scheme.subtitle.isEmpty)
            XCTAssertEqual(scheme.palette.vuRamp.count >= 3, true)
        }
    }

    func testDaftPunkBowUsesSevenStopCompressedRainbowRamp() {
        let palette = OrbisonicColorScheme.daftPunkBow.palette

        XCTAssertTrue(palette.usesCompressedRainbowLinearControls)
        XCTAssertTrue(palette.compressesLinearControlRampIntoActiveSegment)
        XCTAssertEqual(palette.vuRamp.count, 7)
        XCTAssertEqual(palette.vuRamp.map(\.position), [0.00, 0.18, 0.34, 0.50, 0.66, 0.82, 1.00])
        XCTAssertEqual(palette.linearControlRampStops.count, 7)
        XCTAssertEqual(palette.linearControlRampStops.map(\.position), [0.00, 0.18, 0.34, 0.50, 0.66, 0.82, 1.00])
    }

    func testNonDaftSchemesUseNormalControlRamp() {
        for scheme in OrbisonicColorScheme.allCases where scheme != .daftPunkBow {
            XCTAssertFalse(scheme.palette.usesCompressedRainbowLinearControls, "\(scheme.name) should use normal accent-gradient controls")
            XCTAssertFalse(scheme.palette.compressesLinearControlRampIntoActiveSegment)
            XCTAssertEqual(scheme.palette.vuRamp.count, 3)
            XCTAssertEqual(scheme.palette.vuRamp.map(\.position), [0.0, 0.5, 1.0])
            XCTAssertEqual(scheme.palette.linearControlRampStops.count, 2)
            XCTAssertEqual(scheme.palette.linearControlRampStops.map(\.position), [0, 1])
        }
    }

    func testSavedThemeMigrationAndFallback() {
        XCTAssertEqual(OrbisonicColorScheme.from(rawValue: "techRainbow"), .daftPunkBow)
        XCTAssertEqual(OrbisonicColorScheme.from(rawValue: "doesNotExist"), .lab)
    }
}
