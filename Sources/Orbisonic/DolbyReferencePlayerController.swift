import Darwin
import Foundation

enum DolbyReferencePlayerOutputLayout: String, CaseIterable, Codable, Identifiable, Sendable {
    case sevenOneFour = "7.1.4"
    case sevenOneSix = "7.1.6"
    case nineOneFour = "9.1.4"
    case nineOneSix = "9.1.6"

    static let defaultLayout: DolbyReferencePlayerOutputLayout = .nineOneSix

    var id: String { rawValue }
}

enum AtmosDRPRoutingPolicy {
    static var captureLoopback: OrbisonicLoopbackDevice { .auxCable }
    static var drpOutputDeviceName: String { captureLoopback.displayName }
    static let drpOutputVolume = 1.0
}

struct DolbyReferencePlayerDevice: Equatable, Sendable {
    let id: Int
    let name: String
    let channelCount: Int

    static func parseListDevicesOutput(_ output: String) -> [DolbyReferencePlayerDevice] {
        output.components(separatedBy: .newlines).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard parts.count == 2, let id = Int(parts[0]) else { return nil }

            let rest = String(parts[1])
            guard let channelRange = rest.range(of: #"\(([0-9]+) channels?\)$"#, options: [.regularExpression]) else {
                return DolbyReferencePlayerDevice(id: id, name: rest, channelCount: 0)
            }

            let name = rest[..<channelRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let channelText = rest[channelRange]
                .filter(\.isNumber)
            return DolbyReferencePlayerDevice(id: id, name: name, channelCount: Int(channelText) ?? 0)
        }
    }

    static func preferredAtmosOutputDevice(in devices: [DolbyReferencePlayerDevice]) -> DolbyReferencePlayerDevice? {
        devices.first {
            $0.name.localizedCaseInsensitiveCompare(AtmosDRPRoutingPolicy.drpOutputDeviceName) == .orderedSame
        } ?? devices.first {
            $0.name.localizedCaseInsensitiveContains(AtmosDRPRoutingPolicy.drpOutputDeviceName)
        }
    }
}

enum DolbyReferencePlayerSessionState: String, Codable, Sendable {
    case idle
    case starting
    case playing
    case paused
    case stopping
    case stopped
    case failed
}

struct DolbyReferencePlayerSession: Equatable, Sendable {
    let fileURL: URL
    let processIdentifier: Int32
    let metadataDirectoryURL: URL
    let outputDevice: DolbyReferencePlayerDevice
    let outputLayout: DolbyReferencePlayerOutputLayout
    let startedAt: Date
    var state: DolbyReferencePlayerSessionState
    var pausedAt: Date?
    var accumulatedPausedDuration: TimeInterval

    var isRunning: Bool {
        switch state {
        case .starting, .playing, .paused, .stopping:
            true
        case .idle, .stopped, .failed:
            false
        }
    }

    func elapsedPlaybackTime(now: Date = Date()) -> TimeInterval {
        let effectiveNow = pausedAt ?? now
        return max(0, effectiveNow.timeIntervalSince(startedAt) - accumulatedPausedDuration)
    }

    func progress(duration: TimeInterval, now: Date = Date()) -> Double {
        guard duration > 0 else { return 0 }
        return min(max(elapsedPlaybackTime(now: now) / duration, 0), 1)
    }
}

struct DolbyBitstreamInfo: Equatable, Sendable {
    var codec: String?
    var bitRateKbps: Int?
    var codedChannels: String?
    var hasAtmos: Bool?
    var sampleRateHz: Int?
    var dynamicObjectCount: Int?
    var objectInfoBlockCount: Int?
    var bedObjectConfiguration: String?
    var complexityIndex: Int?

    var formatSummary: String {
        var parts: [String] = []
        if let codec { parts.append(codec) }
        if hasAtmos == true { parts.append("Dolby Atmos") }
        if let bitRateKbps { parts.append("\(bitRateKbps) kbps") }
        if let codedChannels { parts.append(codedChannels) }
        return parts.joined(separator: " / ")
    }

    var isEmpty: Bool {
        self == DolbyBitstreamInfo()
    }

    mutating func merge(_ other: DolbyBitstreamInfo) {
        codec = other.codec ?? codec
        bitRateKbps = other.bitRateKbps ?? bitRateKbps
        codedChannels = other.codedChannels ?? codedChannels
        hasAtmos = other.hasAtmos ?? hasAtmos
        sampleRateHz = other.sampleRateHz ?? sampleRateHz
        dynamicObjectCount = other.dynamicObjectCount ?? dynamicObjectCount
        objectInfoBlockCount = other.objectInfoBlockCount ?? objectInfoBlockCount
        bedObjectConfiguration = other.bedObjectConfiguration ?? bedObjectConfiguration
        complexityIndex = other.complexityIndex ?? complexityIndex
    }

    static func parsePrintInfo(_ output: String) -> DolbyBitstreamInfo {
        var info = DolbyBitstreamInfo()
        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if ["Dolby Digital Plus", "Dolby Digital", "Dolby TrueHD", "Dolby AC-4"].contains(line) {
                info.codec = line
                continue
            }

            let parts = line.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
            apply(key: key, value: value, to: &info)
        }
        return info
    }

    static func parseMetadataCSV(_ contents: String) -> DolbyBitstreamInfo {
        let rows = contents
            .components(separatedBy: .newlines)
            .map(parseCSVRow)
            .filter { !$0.isEmpty }
        guard let header = rows.first,
              let lastDataRow = rows.dropFirst().last
        else { return DolbyBitstreamInfo() }

        var info = DolbyBitstreamInfo()
        for (index, headerValue) in header.enumerated() where index < lastDataRow.count {
            let key = headerValue
                .components(separatedBy: ":")
                .last?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? headerValue
            let value = lastDataRow[index].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            apply(key: key, value: value, to: &info)
        }
        return info
    }

    private static func apply(key: String, value: String, to info: inout DolbyBitstreamInfo) {
        let normalizedKey = key.lowercased()
        if normalizedKey == "audio codec" || normalizedKey == "codec" || normalizedKey == "profile" {
            info.codec = cleanValue(value)
        } else if normalizedKey == "data rate [kbps]" || normalizedKey == "data rate" || normalizedKey == "bit rate" {
            info.bitRateKbps = firstInteger(in: value)
        } else if normalizedKey == "coded channels" {
            info.codedChannels = cleanValue(value)
        } else if normalizedKey == "dolby atmos" {
            info.hasAtmos = cleanValue(value).localizedCaseInsensitiveContains("yes")
        } else if normalizedKey == "sample rate [hz]" || normalizedKey == "sample rate" {
            info.sampleRateHz = firstInteger(in: value)
        } else if normalizedKey == "number of dynamic objects" {
            info.dynamicObjectCount = firstInteger(in: value)
        } else if normalizedKey == "number of object info blocks" {
            info.objectInfoBlockCount = firstInteger(in: value)
        } else if normalizedKey == "bed-object configuration" {
            info.bedObjectConfiguration = cleanValue(value)
        } else if normalizedKey == "complexity index" {
            info.complexityIndex = firstInteger(in: value)
        }
    }

    private static func firstInteger(in text: String) -> Int? {
        let pattern = #"-?\d+"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return Int(text[range])
    }

    private static func cleanValue(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseCSVRow(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var isQuoted = false
        let characters = Array(line)
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                if isQuoted, index + 1 < characters.count, characters[index + 1] == "\"" {
                    current.append("\"")
                    index += 1
                } else {
                    isQuoted.toggle()
                }
            } else if character == "," && !isQuoted {
                fields.append(current)
                current = ""
            } else {
                current.append(character)
            }
            index += 1
        }

        fields.append(current)
        return fields
    }
}

struct DolbyReferencePlayerControllerSnapshot: Equatable, Sendable {
    static let idle = DolbyReferencePlayerControllerSnapshot(session: nil, bitstreamInfo: nil, lastOutput: "", lastError: nil)

    var session: DolbyReferencePlayerSession?
    var bitstreamInfo: DolbyBitstreamInfo?
    var lastOutput: String
    var lastError: String?

    var state: DolbyReferencePlayerSessionState { session?.state ?? .idle }
}

protocol DolbyReferencePlayerManagedProcess: AnyObject {
    var processIdentifier: Int32 { get }
    var isRunning: Bool { get }
    func interrupt()
    func terminate()
    func sendSignal(_ signal: Int32)
}

final class FoundationDolbyReferencePlayerProcess: DolbyReferencePlayerManagedProcess {
    private let process: Process
    private let outputPipe = Pipe()
    private let errorPipe = Pipe()

    var processIdentifier: Int32 { process.processIdentifier }
    var isRunning: Bool { process.isRunning }

    init(
        executableURL: URL,
        arguments: [String],
        onOutput: @escaping @Sendable (String) -> Void,
        onTermination: @escaping @Sendable (Int32) -> Void
    ) throws {
        process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            onOutput(String(decoding: data, as: UTF8.self))
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            onOutput(String(decoding: data, as: UTF8.self))
        }
        process.terminationHandler = { process in
            onTermination(process.terminationStatus)
        }

        try process.run()
    }

    deinit {
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
    }

    func interrupt() { process.interrupt() }
    func terminate() { process.terminate() }
    func sendSignal(_ signal: Int32) { Darwin.kill(processIdentifier, signal) }
}

enum DolbyReferencePlayerControllerError: LocalizedError, Equatable {
    case executableMissing(String)
    case deviceUnavailable(String)
    case processNotRunning

    var errorDescription: String? {
        switch self {
        case .executableMissing(let path):
            "Dolby Reference Player CLI was not found at \(path)."
        case .deviceUnavailable(let name):
            "Dolby Reference Player cannot see \(name) as an output device."
        case .processNotRunning:
            "Dolby Reference Player is not running."
        }
    }
}

@MainActor
final class DolbyReferencePlayerController {
    typealias ProcessFactory = (
        _ executableURL: URL,
        _ arguments: [String],
        _ onOutput: @escaping @Sendable (String) -> Void,
        _ onTermination: @escaping @Sendable (Int32) -> Void
    ) throws -> DolbyReferencePlayerManagedProcess

    typealias DeviceDiscovery = () throws -> [DolbyReferencePlayerDevice]

    nonisolated static let defaultExecutableURL = URL(
        fileURLWithPath: "/Applications/Dolby/Dolby Reference Player.app/Contents/MacOS/drp",
        isDirectory: false
    )

    private let executableURL: URL
    private let processFactory: ProcessFactory
    private let deviceDiscovery: DeviceDiscovery?
    private let fileManager: FileManager
    private var process: DolbyReferencePlayerManagedProcess?
    private var outputBuffer = ""
    private(set) var snapshot = DolbyReferencePlayerControllerSnapshot.idle

    var onSnapshotChanged: ((DolbyReferencePlayerControllerSnapshot) -> Void)?

    init(
        executableURL: URL = DolbyReferencePlayerController.defaultExecutableURL,
        fileManager: FileManager = .default,
        deviceDiscovery: DeviceDiscovery? = nil,
        processFactory: @escaping ProcessFactory = { executableURL, arguments, onOutput, onTermination in
            try FoundationDolbyReferencePlayerProcess(
                executableURL: executableURL,
                arguments: arguments,
                onOutput: onOutput,
                onTermination: onTermination
            )
        }
    ) {
        self.executableURL = executableURL
        self.fileManager = fileManager
        self.deviceDiscovery = deviceDiscovery
        self.processFactory = processFactory
    }

    static func supportsFile(_ url: URL) -> Bool {
        let supportedExtensions: Set<String> = ["ec3", "eac3", "ac3", "ac4", "mlp", "mp4", "mov", "m4a", "m2ts", "ts"]
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func commandArguments(
        fileURL: URL,
        deviceID: Int,
        outputLayout: DolbyReferencePlayerOutputLayout,
        volume: Double,
        metadataDirectoryURL: URL
    ) -> [String] {
        [
            "--device", "\(deviceID)",
            "--out-ch-config", outputLayout.rawValue,
            "--volume", String(format: "%.3f", min(max(volume, 0), 10)),
            "--print-info",
            "--metadata-directory", metadataDirectoryURL.path,
            fileURL.path
        ]
    }

    func discoverDevices() throws -> [DolbyReferencePlayerDevice] {
        if let deviceDiscovery {
            return try deviceDiscovery()
        }
        guard fileManager.fileExists(atPath: executableURL.path) else {
            throw DolbyReferencePlayerControllerError.executableMissing(executableURL.path)
        }
        let result = try MatroskaAudioProbe.runProcess(executableURL: executableURL, arguments: ["--list-devices"])
        let output = String(decoding: result.outputData, as: UTF8.self) + "\n" + result.errorText
        return DolbyReferencePlayerDevice.parseListDevicesOutput(output)
    }

    func play(fileURL: URL, volume: Double, outputLayout: DolbyReferencePlayerOutputLayout) throws {
        try stop(waitBeforeTerminate: false)
        guard fileManager.fileExists(atPath: executableURL.path) else {
            throw DolbyReferencePlayerControllerError.executableMissing(executableURL.path)
        }
        let devices = try discoverDevices()
        guard let device = DolbyReferencePlayerDevice.preferredAtmosOutputDevice(in: devices) else {
            throw DolbyReferencePlayerControllerError.deviceUnavailable(AtmosDRPRoutingPolicy.drpOutputDeviceName)
        }

        let metadataDirectoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("orbisonic-drp-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: metadataDirectoryURL, withIntermediateDirectories: true)

        outputBuffer = ""
        let startedAt = Date()
        snapshot = DolbyReferencePlayerControllerSnapshot(
            session: DolbyReferencePlayerSession(
                fileURL: fileURL,
                processIdentifier: 0,
                metadataDirectoryURL: metadataDirectoryURL,
                outputDevice: device,
                outputLayout: outputLayout,
                startedAt: startedAt,
                state: .starting,
                pausedAt: nil,
                accumulatedPausedDuration: 0
            ),
            bitstreamInfo: nil,
            lastOutput: "",
            lastError: nil
        )
        publishSnapshot()

        let arguments = Self.commandArguments(
            fileURL: fileURL,
            deviceID: device.id,
            outputLayout: outputLayout,
            volume: volume,
            metadataDirectoryURL: metadataDirectoryURL
        )
        let managedProcess = try processFactory(
            executableURL,
            arguments,
            { [weak self] text in Task { @MainActor in self?.ingestOutput(text) } },
            { [weak self] status in Task { @MainActor in self?.handleTermination(status: status) } }
        )
        process = managedProcess
        snapshot.session = DolbyReferencePlayerSession(
            fileURL: fileURL,
            processIdentifier: managedProcess.processIdentifier,
            metadataDirectoryURL: metadataDirectoryURL,
            outputDevice: device,
            outputLayout: outputLayout,
            startedAt: startedAt,
            state: .playing,
            pausedAt: nil,
            accumulatedPausedDuration: 0
        )
        publishSnapshot()
    }

    func pause() throws {
        guard let process, process.isRunning, var session = snapshot.session else {
            throw DolbyReferencePlayerControllerError.processNotRunning
        }
        guard session.state != .paused else { return }
        process.sendSignal(SIGSTOP)
        session.state = .paused
        session.pausedAt = Date()
        snapshot.session = session
        publishSnapshot()
    }

    func resume() throws {
        guard let process, process.isRunning, var session = snapshot.session else {
            throw DolbyReferencePlayerControllerError.processNotRunning
        }
        if let pausedAt = session.pausedAt {
            session.accumulatedPausedDuration += Date().timeIntervalSince(pausedAt)
        }
        process.sendSignal(SIGCONT)
        session.state = .playing
        session.pausedAt = nil
        snapshot.session = session
        publishSnapshot()
    }

    func stop(waitBeforeTerminate: Bool = true) throws {
        guard let process else {
            snapshot.session?.state = .stopped
            publishSnapshot()
            return
        }
        snapshot.session?.state = .stopping
        publishSnapshot()
        if process.isRunning {
            process.interrupt()
            if waitBeforeTerminate {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self, weak process] in
                    guard let self, let process, process.isRunning else { return }
                    process.terminate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self, weak process] in
                        guard let self, let process, process.isRunning else { return }
                        process.sendSignal(SIGKILL)
                        self.handleTermination(status: SIGKILL)
                    }
                }
            } else {
                process.terminate()
                self.process = nil
                snapshot.session?.state = .stopped
                publishSnapshot()
            }
        }
    }

    func refreshMetadata() {
        var info = DolbyBitstreamInfo.parsePrintInfo(outputBuffer)
        if let csvURL = snapshot.session?.metadataDirectoryURL.appendingPathComponent("audio.csv"),
           let csvContents = try? String(contentsOf: csvURL, encoding: .utf8) {
            info.merge(DolbyBitstreamInfo.parseMetadataCSV(csvContents))
        }
        if !info.isEmpty {
            snapshot.bitstreamInfo = info
            publishSnapshot()
        }
    }

    private func ingestOutput(_ text: String) {
        outputBuffer += text
        snapshot.lastOutput = outputBuffer
        var info = snapshot.bitstreamInfo ?? DolbyBitstreamInfo()
        info.merge(DolbyBitstreamInfo.parsePrintInfo(outputBuffer))
        snapshot.bitstreamInfo = info.isEmpty ? nil : info
        publishSnapshot()
    }

    private func handleTermination(status: Int32) {
        process = nil
        let expectedStopStatuses: Set<Int32> = [0, SIGINT, SIGTERM, SIGKILL]
        snapshot.session?.state = expectedStopStatuses.contains(status) ? .stopped : .failed
        if snapshot.session?.state == .failed {
            snapshot.lastError = "Dolby Reference Player exited with status \(status)."
        }
        refreshMetadata()
        publishSnapshot()
    }

    private func publishSnapshot() {
        onSnapshotChanged?(snapshot)
    }
}
