import AudioContracts
import AudioCore
import Foundation
import XCTest

final class AudioControlTests: XCTestCase {
    func testAudioControlPublicAPIDoesNotExposeGraphObjects() throws {
        let files = try swiftSourceFiles(under: "Sources/AudioCore")
        XCTAssertFalse(files.isEmpty)

        let forbiddenSymbols = [
            "AVAudioEngine",
            "AVAudioNode",
            "AudioUnit",
            "AudioDeviceID",
            "AudioBufferList",
            "UnsafeMutablePointer",
            "RendererMatrix",
            "LiveAudioPipe",
            "RingBuffer"
        ]

        let violations = try files.flatMap { file in
            let source = try String(contentsOf: file.url, encoding: .utf8)
            return forbiddenSymbols.compactMap { symbol in
                source.contains(symbol) ? "\(file.relativePath) contains \(symbol)" : nil
            }
        }

        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    func testAudioControlAcceptsTypedCommands() async throws {
        let control = AudioControl()
        let result = try await control.startSession(
            StartAudioSessionRequest(
                sessionFormat: Self.defaultSessionFormat(),
                initialSource: .off,
                desktopRouteID: "desktop-route",
                danteRouteID: "dante-route",
                desktopOutputEnabled: true,
                danteOutputEnabled: false,
                renderMode: .automatic
            )
        )

        XCTAssertEqual(result.sessionVersion, 1)
        XCTAssertEqual(result.sessionFormat.sampleRate, .defaultProduction)

        try await control.setDesktopMonitorGain(try LinearGain(0.75))
        try await control.setDanteOutputGain(try LinearGain(0.5))
        try await control.setDanteOutputEnabled(true)
        try await control.setDesktopOutputEnabled(false)
        try await control.setRenderMode(.stereo)

        let audit = try await control.requestGraphAuditSnapshot()
        XCTAssertTrue(audit.isSessionRunning)
        XCTAssertEqual(audit.desktopMonitorGain, try LinearGain(0.75))
        XCTAssertEqual(audit.danteOutputGain, try LinearGain(0.5))
        XCTAssertTrue(audit.danteOutputEnabled)
        XCTAssertFalse(audit.desktopOutputEnabled)
        XCTAssertEqual(audit.renderMode, .stereo)
    }

    func testAudioControlRejectsInvalidGain() {
        XCTAssertThrowsError(try LinearGain(-0.1))
        XCTAssertThrowsError(try LinearGain(.nan))
        XCTAssertThrowsError(try LinearGain(2.1))
    }

    func testAudioTelemetryReturnsValueSnapshotsOnly() async throws {
        let control = AudioControl()
        let sessionFormat = Self.defaultSessionFormat()
        _ = try await control.startSession(StartAudioSessionRequest(sessionFormat: sessionFormat))

        XCTAssertEqual(control.latestSessionFormat(), sessionFormat)
        XCTAssertNil(control.latestMeterSnapshot())

        let routeSnapshot = try XCTUnwrap(control.latestRouteSnapshot())
        XCTAssertEqual(routeSnapshot.sessionVersion, 1)

        let audit = try XCTUnwrap(control.latestGraphAudit())
        XCTAssertEqual(audit.sessionFormat, sessionFormat)
        XCTAssertEqual(audit.activeSource, .off)
    }

    func testAudioControlCanCreateStoppedInitialState() throws {
        let control = AudioControl()
        let audit = try XCTUnwrap(control.latestGraphAudit())

        XCTAssertFalse(audit.isSessionRunning)
        XCTAssertEqual(audit.sessionVersion, 0)
        XCTAssertEqual(audit.activeSource, .off)
        XCTAssertNil(audit.sessionFormat)
    }

    func testAudioCommandQueueSerializesCommands() async throws {
        let recorder = SerializedCommandRecorder()
        let queue = AudioCommandQueue { command in
            recorder.handle(command)
        }

        async let first = queue.submit(.setRenderMode(.mono))
        async let second = queue.submit(.setRenderMode(.stereo))
        async let third = queue.submit(.setRenderMode(.quad))

        _ = try await [first, second, third]

        XCTAssertEqual(recorder.maxActiveHandlers, 1)
        XCTAssertEqual(recorder.handledCount, 3)
    }

    func testPrepareLocalAssetRequiresManagedImportForSampleRateMismatch() async throws {
        let control = AudioControl()
        let sessionFormat = Self.defaultSessionFormat()
        _ = try await control.startSession(StartAudioSessionRequest(sessionFormat: sessionFormat))

        let readiness = try await control.prepareLocalAsset(
            PrepareLocalAssetRequest(
                sourceID: "asset-1",
                originalPath: "track.wav",
                declaredSampleRate: .rate44100,
                channelCount: 2,
                layout: .stereo
            )
        )

        guard case .requiresManagedImport(let sourceID, let sessionSampleRate, _) = readiness else {
            return XCTFail("Expected managed import requirement for a mismatched local asset.")
        }

        XCTAssertEqual(sourceID, "asset-1")
        XCTAssertEqual(sessionSampleRate, .defaultProduction)
    }

    func testImportLocalAssetPublishesConversionLedger() async throws {
        let control = AudioControl()
        let sessionFormat = Self.defaultSessionFormat()

        let descriptor = try await control.importLocalAssetToSessionRate(
            ImportLocalAssetRequest(
                sourceID: "source-1",
                originalPath: "source.wav",
                sourceSampleRate: .rate44100,
                sourceChannelCount: 2,
                sourceLayout: .stereo,
                targetSessionFormat: sessionFormat,
                managedAssetID: "managed-1",
                managedPath: "managed/source.wav"
            )
        )

        XCTAssertEqual(descriptor.sampleRate, .defaultProduction)
        XCTAssertTrue(
            descriptor.conversionLedger.allowedConversions.contains(.offlineManagedSampleRateConversion)
        )
        XCTAssertEqual(control.latestConversionLedger(), descriptor.conversionLedger)
    }

    private static func defaultSessionFormat() -> AudioSessionFormat {
        AudioSessionFormat(
            sampleRate: .defaultProduction,
            maxFramesPerBlock: 512,
            dante: DanteOutputFormat(
                physicalChannelCount: 32,
                sampleRate: .defaultProduction
            ),
            desktop: DesktopOutputFormat(sampleRate: .defaultProduction)
        )
    }

    private struct SourceFile {
        let relativePath: String
        let url: URL
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
    }

    private func relativePath(for url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath + "/") else { return path }
        return String(path.dropFirst(rootPath.count + 1))
    }
}

private final class SerializedCommandRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var activeHandlers = 0
    private var handledCommands = 0
    private var maximumActiveHandlers = 0

    var maxActiveHandlers: Int {
        lock.lock()
        defer { lock.unlock() }
        return maximumActiveHandlers
    }

    var handledCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return handledCommands
    }

    func handle(_ command: AudioControlCommand) -> AudioControlCommandResult {
        lock.lock()
        activeHandlers += 1
        maximumActiveHandlers = max(maximumActiveHandlers, activeHandlers)
        lock.unlock()

        Thread.sleep(forTimeInterval: 0.01)

        lock.lock()
        activeHandlers -= 1
        handledCommands += 1
        lock.unlock()

        return .graphAuditSnapshot(
            AudioGraphAuditSnapshot(
                sessionVersion: UInt64(handledCount),
                isSessionRunning: false,
                sessionFormat: nil,
                activeSource: .off,
                renderMode: .automatic,
                desktopMonitorGain: .unity,
                danteOutputGain: .unity,
                desktopOutputEnabled: true,
                danteOutputEnabled: false,
                validationMessages: [],
                shellDescription: "test"
            )
        )
    }
}
