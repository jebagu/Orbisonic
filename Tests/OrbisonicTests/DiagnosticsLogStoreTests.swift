import Foundation
import XCTest
@testable import Orbisonic

final class DiagnosticsLogStoreTests: XCTestCase {
    func testReadsOnlyRecentTailWhenFilteringWarningsAndErrors() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OrbisonicDiagnosticsLogStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let logURL = directory.appendingPathComponent("Orbisonic.log")
        let filler = (0..<2_000).map { index in
            "[2026-04-29T00:00:00Z] [INFO] [test] filler-\(index) \(String(repeating: "x", count: 80))"
        }
        let lines = [
            "[2026-04-29T00:00:00Z] [WARNING] [test] old-warning"
        ] + filler + [
            "[2026-04-29T00:00:01Z] [ERROR] [test] recent-error",
            "[2026-04-29T00:00:02Z] [WARNING] [test] recent-warning"
        ]
        try lines.joined(separator: "\n").write(to: logURL, atomically: true, encoding: .utf8)

        let store = DiagnosticsLogStore(logFileURL: logURL)
        let result = await store.readRecentInterestingLines(maxBytes: 2_048, maxLines: 500)

        XCTAssertEqual(result, [
            "[2026-04-29T00:00:01Z] [ERROR] [test] recent-error",
            "[2026-04-29T00:00:02Z] [WARNING] [test] recent-warning"
        ])
    }

    func testLimitsReturnedInterestingLines() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OrbisonicDiagnosticsLogStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let logURL = directory.appendingPathComponent("Orbisonic.log")
        let lines = (0..<20).map { index in
            "[2026-04-29T00:00:\(String(format: "%02d", index))Z] [WARNING] [test] warning-\(index)"
        }
        try lines.joined(separator: "\n").write(to: logURL, atomically: true, encoding: .utf8)

        let store = DiagnosticsLogStore(logFileURL: logURL)
        let result = await store.readRecentInterestingLines(maxBytes: 16 * 1024, maxLines: 6)

        XCTAssertEqual(result.count, 6)
        XCTAssertEqual(result.first, lines[14])
        XCTAssertEqual(result.last, lines[19])
    }

    func testDefaultMetricsNeverReadMoreThanDefaultByteLimit() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OrbisonicDiagnosticsLogStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let logURL = directory.appendingPathComponent("Orbisonic.log")
        let line = "[2026-04-29T00:00:00Z] [WARNING] [test] bounded-read \(String(repeating: "x", count: 200))"
        let lines = Array(repeating: line, count: 3_000)
        try lines.joined(separator: "\n").write(to: logURL, atomically: true, encoding: .utf8)

        let store = DiagnosticsLogStore(logFileURL: logURL)
        let result = await store.readRecentInterestingLinesWithMetrics()

        XCTAssertLessThanOrEqual(result.bytesRead, DiagnosticsLogStore.defaultMaxBytes)
        XCTAssertGreaterThan(result.fileSizeBytes, UInt64(DiagnosticsLogStore.defaultMaxBytes))
        XCTAssertLessThanOrEqual(result.lines.count, DiagnosticsLogStore.defaultMaxLines)
        XCTAssertGreaterThanOrEqual(result.elapsedMilliseconds, 0)
    }
}
