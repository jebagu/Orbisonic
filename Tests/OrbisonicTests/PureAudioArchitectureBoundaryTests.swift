import Foundation
import XCTest

final class PureAudioArchitectureBoundaryTests: XCTestCase {
    func testAudioContractsHasNoAudioImplementationImports() throws {
        let files = try swiftSourceFiles(under: "Sources/AudioContracts")
        XCTAssertFalse(files.isEmpty)

        let forbiddenPatterns = ArchitectureBoundaryAllowlist.audioImplementationImports
            + ArchitectureBoundaryAllowlist.uiImports
            + ArchitectureBoundaryAllowlist.audioImplementationSymbols.filter {
                [
                    "AVAudioEngine", "AVAudioNode", "AudioDeviceID", "AudioBufferList",
                    "UnsafeMutablePointer<Float>"
                ].contains($0.id)
            }

        let violations = try violations(in: files, patterns: forbiddenPatterns)
        XCTAssertTrue(violations.isEmpty, formatted(violations))
    }

    func testUIAndViewModelsDoNotOwnAudioGraph() throws {
        let files = try existingFiles(ArchitectureBoundaryAllowlist.uiAndViewModelFiles)
        let forbiddenPatterns = ArchitectureBoundaryAllowlist.audioImplementationImports
            + ArchitectureBoundaryAllowlist.audioImplementationSymbols

        let violations = try violations(in: files, patterns: forbiddenPatterns)
        XCTAssertTrue(violations.isEmpty, formatted(violations))
    }

    func testVUDisplayDoesNotOwnAudioGraph() throws {
        let files = try existingFiles(ArchitectureBoundaryAllowlist.vuDisplayFiles)
        let forbiddenPatterns = ArchitectureBoundaryAllowlist.audioImplementationSymbols.filter {
            [
                "AVAudioEngine", "AVAudioNode", "AVAudioMixerNode", "AVAudioPlayerNode",
                "AVAudioSourceNode", "AVAudioEnvironmentNode", "AVAudioPCMBuffer",
                "AudioUnit", "AudioDeviceID", "AudioBufferList", "UnsafeMutablePointer<Float>",
                "UnsafeBufferPointer<Float>", "RendererMatrix", "RingBuffer", "LiveAudioPipe",
                "installTap", "connectCall", "disconnectCall", "mainMixerNode", "outputNode"
            ].contains($0.id)
        }

        let violations = try violations(in: files, patterns: forbiddenPatterns)
        XCTAssertTrue(violations.isEmpty, formatted(violations))
    }

    func testAudioImportDoesNotOwnLiveOutput() throws {
        let files = try existingFiles(ArchitectureBoundaryAllowlist.audioImportCompatibilityFiles)
        let forbiddenPatterns = ArchitectureBoundaryAllowlist.audioImplementationSymbols.filter {
            [
                "AVAudioEngine", "AVAudioMixerNode", "AVAudioPlayerNode", "AVAudioSourceNode",
                "AVAudioEnvironmentNode", "AudioUnit", "AudioDeviceID", "installTap",
                "connectCall", "disconnectCall", "mainMixerNode", "outputNode"
            ].contains($0.id)
        }

        let violations = try rawViolations(in: files, patterns: forbiddenPatterns)
        XCTAssertTrue(violations.isEmpty, formatted(violations))
    }

    func testAudioCoreDoesNotImportUI() throws {
        let futureAudioCoreFiles = try swiftSourceFiles(under: "Sources/AudioCore")
            + swiftSourceFilesIfPresent(under: "Sources/Orbisonic/AudioCore")
        let legacyAudioCoreFiles = try existingFiles(ArchitectureBoundaryAllowlist.legacyAudioCoreCompatibilityFiles)
        let files = futureAudioCoreFiles + legacyAudioCoreFiles

        let violations = try violations(in: files, patterns: ArchitectureBoundaryAllowlist.uiImports)
        XCTAssertTrue(violations.isEmpty, formatted(violations))
    }

    func testForbiddenAudioSymbolsAreNotUsedOutsideAllowlist() throws {
        let files = try swiftSourceFiles(under: "Sources")
        let forbiddenPatterns = ArchitectureBoundaryAllowlist.audioImplementationImports
            + ArchitectureBoundaryAllowlist.audioImplementationSymbols

        let violations = try violations(in: files, patterns: forbiddenPatterns)
        XCTAssertTrue(violations.isEmpty, formatted(violations))
    }

    func testMigrationExceptionsRemainDocumented() {
        for path in ArchitectureBoundaryAllowlist.allowedForbiddenPatternIDsByFile.keys {
            if ArchitectureBoundaryAllowlist.allowedForbiddenPatternIDsByFile[path]?.isEmpty == false {
                XCTAssertNotNil(
                    ArchitectureBoundaryAllowlist.migrationExceptionNotes[path]
                        ?? defaultDocumentedAllowlistReason(for: path),
                    "\(path) has an allowlist entry without a documented migration reason."
                )
            }
        }
    }

    private struct SourceFile {
        let relativePath: String
        let url: URL
    }

    private struct BoundaryViolation {
        let relativePath: String
        let line: Int
        let patternID: String
        let sourceLine: String
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func swiftSourceFiles(under relativeDirectory: String) throws -> [SourceFile] {
        let root = packageRoot()
        let directory = root.appendingPathComponent(relativeDirectory)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { return nil }
            return SourceFile(relativePath: relativePath(for: url, root: root), url: url)
        }
        .sorted { $0.relativePath < $1.relativePath }
    }

    private func swiftSourceFilesIfPresent(under relativeDirectory: String) -> [SourceFile] {
        (try? swiftSourceFiles(under: relativeDirectory)) ?? []
    }

    private func existingFiles(_ relativePaths: Set<String>) throws -> [SourceFile] {
        let root = packageRoot()
        return relativePaths.sorted().compactMap { relativePath in
            let url = root.appendingPathComponent(relativePath)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return SourceFile(relativePath: relativePath, url: url)
        }
    }

    private func violations(
        in files: [SourceFile],
        patterns: [ArchitectureBoundaryAllowlist.Pattern]
    ) throws -> [BoundaryViolation] {
        let raw = try rawViolations(in: files, patterns: patterns)
        return raw.filter { violation in
            !allowedPatternIDs(for: violation.relativePath).contains(violation.patternID)
        }
    }

    private func rawViolations(
        in files: [SourceFile],
        patterns: [ArchitectureBoundaryAllowlist.Pattern]
    ) throws -> [BoundaryViolation] {
        var results: [BoundaryViolation] = []
        for file in files {
            let source = try String(contentsOf: file.url, encoding: .utf8)
            let lines = source.components(separatedBy: .newlines)
            for (offset, line) in lines.enumerated() {
                for pattern in patterns where line.matches(pattern.expression) {
                    results.append(
                        BoundaryViolation(
                            relativePath: file.relativePath,
                            line: offset + 1,
                            patternID: pattern.id,
                            sourceLine: line.trimmingCharacters(in: .whitespaces)
                        )
                    )
                }
            }
        }
        return results
    }

    private func allowedPatternIDs(for relativePath: String) -> Set<String> {
        var allowed = ArchitectureBoundaryAllowlist.allowedForbiddenPatternIDsByFile[relativePath] ?? []
        allowed.formUnion(ArchitectureBoundaryAllowlist.uiImportExceptionsByFile[relativePath] ?? [])
        return allowed
    }

    private func relativePath(for url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath + "/") else { return path }
        return String(path.dropFirst(rootPath.count + 1))
    }

    private func formatted(_ violations: [BoundaryViolation]) -> String {
        guard !violations.isEmpty else { return "" }
        return "\n" + violations.map { violation in
            "\(violation.relativePath):\(violation.line) [\(violation.patternID)] \(violation.sourceLine)"
        }.joined(separator: "\n")
    }

    private func defaultDocumentedAllowlistReason(for path: String) -> String? {
        if ArchitectureBoundaryAllowlist.audioImportCompatibilityFiles.contains(path) {
            return "AudioImport compatibility file."
        }
        if ArchitectureBoundaryAllowlist.legacyAudioCoreCompatibilityFiles.contains(path) {
            return "Legacy AudioCore compatibility file."
        }
        if path.contains("NormalMonitor") || path.contains("AudioSpatialUsageAudit") {
            return "Legacy architecture descriptor or audit source."
        }
        return nil
    }
}

private extension String {
    func matches(_ pattern: String) -> Bool {
        range(of: pattern, options: .regularExpression) != nil
    }
}
