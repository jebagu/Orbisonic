import Darwin
import XCTest
@testable import Orbisonic

@MainActor
final class DolbyReferencePlayerControllerTests: XCTestCase {
    func testParsesDeviceListAndSelectsAuxLoopback() {
        let output = """
        1 MacBook Pro Speakers (2 channels)
        7 Orbisonic Aux Cable (64 channels)
        8 Other Device (2 channels)
        """

        let devices = DolbyReferencePlayerDevice.parseListDevicesOutput(output)
        let selected = DolbyReferencePlayerDevice.preferredAtmosOutputDevice(in: devices)

        XCTAssertEqual(devices, [
            DolbyReferencePlayerDevice(id: 1, name: "MacBook Pro Speakers", channelCount: 2),
            DolbyReferencePlayerDevice(id: 7, name: "Orbisonic Aux Cable", channelCount: 64),
            DolbyReferencePlayerDevice(id: 8, name: "Other Device", channelCount: 2)
        ])
        XCTAssertEqual(selected, DolbyReferencePlayerDevice(id: 7, name: "Orbisonic Aux Cable", channelCount: 64))
    }

    func testBuildsDRPCommandArgumentsWithoutPCMOutputFile() {
        let fileURL = URL(fileURLWithPath: "/tmp/song.ec3")
        let metadataURL = URL(fileURLWithPath: "/tmp/orbisonic-drp-meta", isDirectory: true)

        let arguments = DolbyReferencePlayerController.commandArguments(
            fileURL: fileURL,
            deviceID: 42,
            outputLayout: .nineOneSix,
            volume: 0.75,
            metadataDirectoryURL: metadataURL
        )

        XCTAssertEqual(arguments, [
            "--device", "42",
            "--out-ch-config", "9.1.6",
            "--volume", "0.750",
            "--print-info",
            "--metadata-directory", "/tmp/orbisonic-drp-meta",
            "/tmp/song.ec3"
        ])
        XCTAssertFalse(arguments.contains("--audio-out-file"))
    }

    func testRecognizesDRPPlayableLocalLibraryExtensions() {
        for ext in ["ec3", "eac3", "ac3", "ac4", "mlp", "mp4", "mov", "m4a", "m2ts", "ts"] {
            let url = URL(fileURLWithPath: "/tmp/track.\(ext)")
            XCTAssertTrue(DolbyReferencePlayerController.supportsFile(url), ext)
            XCTAssertTrue(LocalMusicLibrary.isSupportedAudioFile(url), ext)
        }
        XCTAssertFalse(DolbyReferencePlayerController.supportsFile(URL(fileURLWithPath: "/tmp/track.flac")))
    }

    func testParsesPrintInfoAndAudioCSVMetadata() {
        let printInfo = """
        Dolby Digital Plus
        Data rate [kbps]: 768
        Coded channels: L, R, C, LFE, Ls, Rs
        Dolby Atmos: Yes
        Sample rate [Hz]: 48000
        Number of dynamic objects: 12
        Complexity index: 15
        """
        let csv = """
        Audio: Dolby Atmos,Audio: Number of dynamic objects,Audio: Number of object info blocks,Audio: Bed-object configuration,Audio: Complexity index
        Yes,16,20,5.1.4,18
        """

        var info = DolbyBitstreamInfo.parsePrintInfo(printInfo)
        info.merge(DolbyBitstreamInfo.parseMetadataCSV(csv))

        XCTAssertEqual(info.codec, "Dolby Digital Plus")
        XCTAssertEqual(info.bitRateKbps, 768)
        XCTAssertEqual(info.codedChannels, "L, R, C, LFE, Ls, Rs")
        XCTAssertEqual(info.hasAtmos, true)
        XCTAssertEqual(info.sampleRateHz, 48_000)
        XCTAssertEqual(info.dynamicObjectCount, 16)
        XCTAssertEqual(info.objectInfoBlockCount, 20)
        XCTAssertEqual(info.bedObjectConfiguration, "5.1.4")
        XCTAssertEqual(info.complexityIndex, 18)
    }

    func testFakeProcessLifecyclePlayPauseResumeStop() async throws {
        let executableURL = try Self.makeTemporaryExecutable()
        let harness = ProcessHarness()
        let controller = DolbyReferencePlayerController(
            executableURL: executableURL,
            deviceDiscovery: {
                [DolbyReferencePlayerDevice(id: 7, name: "Orbisonic Aux Cable", channelCount: 64)]
            },
            processFactory: { _, arguments, onOutput, onTermination in
                harness.arguments = arguments
                harness.onOutput = onOutput
                harness.onTermination = onTermination
                let process = FakeDRPProcess(processIdentifier: 1234)
                harness.process = process
                return process
            }
        )

        try controller.play(
            fileURL: URL(fileURLWithPath: "/tmp/track.ec3"),
            volume: 1.0,
            outputLayout: .sevenOneFour
        )

        XCTAssertEqual(harness.arguments, [
            "--device", "7",
            "--out-ch-config", "7.1.4",
            "--volume", "1.000",
            "--print-info",
            "--metadata-directory", controller.snapshot.session?.metadataDirectoryURL.path ?? "",
            "/tmp/track.ec3"
        ])
        XCTAssertEqual(controller.snapshot.state, .playing)
        XCTAssertEqual(controller.snapshot.session?.processIdentifier, 1234)

        harness.onOutput?("Dolby Digital Plus\nDolby Atmos: Yes\n")
        try await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertEqual(controller.snapshot.bitstreamInfo?.codec, "Dolby Digital Plus")
        XCTAssertEqual(controller.snapshot.bitstreamInfo?.hasAtmos, true)

        try controller.pause()
        XCTAssertEqual(harness.process?.signals, [SIGSTOP])
        XCTAssertEqual(controller.snapshot.state, .paused)

        try controller.resume()
        XCTAssertEqual(harness.process?.signals, [SIGSTOP, SIGCONT])
        XCTAssertEqual(controller.snapshot.state, .playing)

        try controller.stop(waitBeforeTerminate: false)
        XCTAssertEqual(harness.process?.interruptCount, 1)
        XCTAssertEqual(harness.process?.terminateCount, 1)
        XCTAssertEqual(controller.snapshot.state, .stopped)
    }

    private static func makeTemporaryExecutable() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("orbisonic-fake-drp-\(UUID().uuidString)", isDirectory: false)
        XCTAssertTrue(FileManager.default.createFile(atPath: url.path, contents: Data()))
        return url
    }
}

private final class ProcessHarness {
    var arguments: [String] = []
    var onOutput: ((String) -> Void)?
    var onTermination: ((Int32) -> Void)?
    var process: FakeDRPProcess?
}

private final class FakeDRPProcess: DolbyReferencePlayerManagedProcess {
    let processIdentifier: Int32
    var isRunning = true
    var interruptCount = 0
    var terminateCount = 0
    var signals: [Int32] = []

    init(processIdentifier: Int32) {
        self.processIdentifier = processIdentifier
    }

    func interrupt() {
        interruptCount += 1
    }

    func terminate() {
        terminateCount += 1
        isRunning = false
    }

    func sendSignal(_ signal: Int32) {
        signals.append(signal)
    }
}
