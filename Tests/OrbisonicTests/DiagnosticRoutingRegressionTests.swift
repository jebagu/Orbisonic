import XCTest

final class DiagnosticRoutingRegressionTests: XCTestCase {
    func testRendererDiagnosticPreparationUsesRendererRoute() throws {
        let source = try source("Sources/Orbisonic/OrbisonicViewModel.swift")
        let function = try block(
            named: "private func prepareDiagnosticOutput",
            endingBefore: "private func configureDiagnosticMonitorDownmix",
            in: source
        )
        let monitorCase = try block(
            named: "case .monitor:",
            endingBefore: "case .renderer:",
            in: function
        )
        let rendererCaseStart = try XCTUnwrap(function.range(of: "case .renderer:"))
        let rendererCase = String(function[rendererCaseStart.lowerBound...])

        XCTAssertTrue(function.contains("rendererDiagnosticsUsingNormalMonitor = false"))
        XCTAssertTrue(function.contains("rendererDiagnosticsMonitorDownmixAvailable = false"))
        XCTAssertTrue(function.contains("try? engine.setDiagnosticMonitorOutputDevice(nil)"))

        XCTAssertTrue(monitorCase.contains("return ensureOutputForAction(.monitor)"))
        XCTAssertTrue(rendererCase.contains("return ensureOutputForAction(.renderer)"))
        XCTAssertFalse(rendererCase.contains("return ensureOutputForAction(.monitor)"))
    }

    private func block(named startMarker: String, endingBefore endMarker: String, in source: String) throws -> String {
        let start = try XCTUnwrap(source.range(of: startMarker))
        let end = try XCTUnwrap(source.range(of: endMarker, range: start.upperBound..<source.endIndex))
        return String(source[start.lowerBound..<end.lowerBound])
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
