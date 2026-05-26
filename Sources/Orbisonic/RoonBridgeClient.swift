import Foundation

enum RoonBridgeControl: String, Codable, CaseIterable {
    case play
    case pause
    case playpause
    case stop
    case previous
    case next
}

struct RoonBridgeSnapshot: Codable, Equatable {
    var ok: Bool
    var updatedAt: String?
    var bridge: RoonBridgeInfo
    var core: RoonBridgeCore?
    var selectedZoneId: String?
    var selectedZone: RoonBridgeZone?
    var zones: [RoonBridgeZone]

    var isReadyForTransport: Bool {
        ok && selectedZone != nil
    }

    var statusText: String {
        if let selectedZone {
            return "\(selectedZone.displayName) / \(selectedZone.state.uppercased())"
        }
        return bridge.message
    }

    var audioPathText: String {
        if let output = selectedZone?.outputs.first(where: {
            $0.displayName.localizedCaseInsensitiveContains("Orbisonic Roon Input")
        }) {
            return output.displayName
        }

        if let output = selectedZone?.outputs.first {
            return output.displayName
        }

        if let zoneHint = bridge.zoneHint, !zoneHint.isEmpty {
            return zoneHint
        }

        return "Orbisonic Roon Input"
    }

    var compactStatusText: String {
        if isReadyForTransport {
            return "Connected"
        }
        switch bridge.state {
        case "waiting_for_authorization":
            return "Enable in Roon"
        case "waiting_for_zone":
            return "No zone"
        case "missing_dependencies":
            return "Install bridge"
        case "missing_node":
            return "Install Node"
        default:
            return "Offline"
        }
    }

    static let unavailable = RoonBridgeSnapshot(
        ok: false,
        updatedAt: nil,
        bridge: RoonBridgeInfo(
            state: "offline",
            message: "Roon API bridge is offline.",
            zoneHint: "Orbisonic Roon Input"
        ),
        core: nil,
        selectedZoneId: nil,
        selectedZone: nil,
        zones: []
    )
}

struct RoonBridgeInfo: Codable, Equatable {
    var state: String
    var message: String
    var zoneHint: String?
    var version: String? = nil
    var supportsImage: Bool? = nil
    var imageServiceAvailable: Bool? = nil

    var hasImageCapability: Bool {
        supportsImage == true && imageServiceAvailable != false
    }
}

struct RoonBridgeCore: Codable, Equatable {
    var coreId: String?
    var displayName: String
    var displayVersion: String?
}

struct RoonBridgeZone: Codable, Equatable, Identifiable {
    var zoneId: String
    var displayName: String
    var state: String
    var isPlayAllowed: Bool
    var isPauseAllowed: Bool
    var isPreviousAllowed: Bool
    var isNextAllowed: Bool
    var isSeekAllowed: Bool
    var outputs: [RoonBridgeOutput]
    var nowPlaying: RoonBridgeNowPlaying?
    var controls: RoonBridgeControls?

    var id: String { zoneId }

    var isPlaying: Bool {
        state == "playing" || state == "loading"
    }

    var titleText: String? {
        nowPlaying?.titleText
    }

    var subtitleText: String? {
        nowPlaying?.subtitleText
    }

    func allows(_ control: RoonBridgeControl) -> Bool {
        if let controls {
            return controls.allows(control)
        }

        switch control {
        case .play:
            return isPlayAllowed
        case .pause:
            return isPauseAllowed
        case .playpause:
            return isPlayAllowed || isPauseAllowed
        case .stop:
            return isPlaying || state == "paused"
        case .previous:
            return isPreviousAllowed
        case .next:
            return isNextAllowed
        }
    }
}

struct RoonBridgeOutput: Codable, Equatable, Identifiable {
    var outputId: String
    var displayName: String
    var state: String?

    var id: String { outputId }
}

struct RoonBridgeControls: Codable, Equatable {
    var play: Bool
    var pause: Bool
    var playpause: Bool
    var stop: Bool
    var previous: Bool
    var next: Bool

    func allows(_ control: RoonBridgeControl) -> Bool {
        switch control {
        case .play:
            return play
        case .pause:
            return pause
        case .playpause:
            return playpause
        case .stop:
            return stop
        case .previous:
            return previous
        case .next:
            return next
        }
    }
}

struct RoonBridgeNowPlaying: Codable, Equatable {
    var seekPosition: Double?
    var length: Double?
    var imageKey: String?
    var albumId: String?
    var trackId: String?
    var oneLine: RoonBridgeOneLine?
    var twoLine: RoonBridgeTwoLine?
    var threeLine: RoonBridgeThreeLine?

    var titleText: String? {
        threeLine?.line1 ?? twoLine?.line1 ?? oneLine?.line1
    }

    var subtitleText: String? {
        if let line2 = threeLine?.line2, let line3 = threeLine?.line3 {
            return "\(line2) - \(line3)"
        }
        return threeLine?.line2 ?? twoLine?.line2
    }

    var artworkRequest: RoonArtworkRequest? {
        guard let imageKey = imageKey?.trimmedNilIfBlank else { return nil }
        let stableKey = artworkStableKey ?? "image:\(imageKey)"
        return RoonArtworkRequest(
            stableKey: stableKey,
            imageKey: imageKey,
            title: titleText?.trimmedNilIfBlank ?? "Roon artwork"
        )
    }

    private var artworkStableKey: String? {
        if let imageKey = imageKey?.trimmedNilIfBlank {
            return "image:\(imageKey)"
        }
        if let albumId = albumId?.trimmedNilIfBlank {
            return "album:\(albumId)"
        }
        if let trackId = trackId?.trimmedNilIfBlank {
            return "track:\(trackId)"
        }

        let fallback = [
            titleText?.trimmedNilIfBlank,
            subtitleText?.trimmedNilIfBlank,
            length.map { String(format: "%.3f", $0) }
        ].compactMap { $0 }.joined(separator: "|")
        return fallback.isEmpty ? nil : "metadata:\(fallback)"
    }
}

struct RoonBridgeOneLine: Codable, Equatable {
    var line1: String?
}

struct RoonBridgeTwoLine: Codable, Equatable {
    var line1: String?
    var line2: String?
}

struct RoonBridgeThreeLine: Codable, Equatable {
    var line1: String?
    var line2: String?
    var line3: String?
}

struct RoonBridgeCommandResponse: Codable, Equatable {
    var ok: Bool
    var message: String?
    var error: String?
    var state: RoonBridgeSnapshot?
}

enum RoonBridgeClientError: LocalizedError {
    case bridgeResourceMissing
    case missingDependencies(String)
    case missingNodeRuntime
    case requestFailed(String)
    case httpFailure(Int, String?)
    case commandRejected(String)

    var errorDescription: String? {
        switch self {
        case .bridgeResourceMissing:
            return "Roon bridge helper is missing from the app bundle."
        case .missingDependencies(let message):
            return message
        case .missingNodeRuntime:
            return "Node.js was not found. Install Node.js, or set ORBISONIC_NODE_PATH to the node executable path before launching Orbisonic."
        case .requestFailed(let message):
            return message
        case .httpFailure(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Roon bridge returned HTTP \(statusCode): \(message)"
            }
            return "Roon bridge returned HTTP \(statusCode)."
        case .commandRejected(let message):
            return message
        }
    }

    var isRetryableArtworkFetchFailure: Bool {
        switch self {
        case .httpFailure(let statusCode, _):
            return statusCode == 404 || statusCode == 502 || statusCode == 503
        case .requestFailed, .missingDependencies, .missingNodeRuntime, .bridgeResourceMissing:
            return true
        case .commandRejected:
            return false
        }
    }
}

final class RoonBridgeClient {
    private let port: Int
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder = JSONEncoder()
    private var process: Process?

    init(port: Int = 37_942, session: URLSession = .shared) {
        self.port = port
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    deinit {
        stop()
    }

    var supportDirectoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Orbisonic/RoonBridge", isDirectory: true)
    }

    var installCommand: String {
        "scripts/install-roon-bridge.sh"
    }

    func startIfNeeded() throws {
        if let process, process.isRunning {
            return
        }

        try prepareSupportDirectory()

        guard dependenciesAreInstalled() else {
            throw RoonBridgeClientError.missingDependencies(
                "Roon bridge dependencies are missing. Run \(installCommand), then reopen Orbisonic."
            )
        }

        let nodeURL = try nodeExecutableURL()
        let process = Process()
        process.currentDirectoryURL = supportDirectoryURL
        process.executableURL = nodeURL
        process.arguments = ["bridge.js"]
        process.environment = ProcessInfo.processInfo.environment.merging([
            "ORBISONIC_ROON_BRIDGE_PORT": "\(port)",
            "PATH": bridgeRuntimePath
        ]) { _, new in new }

        try FileManager.default.createDirectory(
            at: AppLogger.logDirectoryURL,
            withIntermediateDirectories: true
        )
        let outputURL = AppLogger.logDirectoryURL.appendingPathComponent("RoonBridge.out.log")
        let errorURL = AppLogger.logDirectoryURL.appendingPathComponent("RoonBridge.err.log")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        try outputHandle.seekToEnd()
        try errorHandle.seekToEnd()
        process.standardOutput = outputHandle
        process.standardError = errorHandle

        process.terminationHandler = { process in
            AppLogger.shared.notice(
                category: "roon-bridge",
                "Roon bridge exited status=\(process.terminationStatus)"
            )
        }

        try process.run()
        self.process = process
        AppLogger.shared.notice(category: "roon-bridge", "Started Roon bridge on port \(port) node=\(nodeURL.path).")
    }

    func stop() {
        guard let process else { return }
        if process.isRunning {
            process.terminate()
        }
        self.process = nil
    }

    func refresh() async throws -> RoonBridgeSnapshot {
        let (data, response) = try await session.data(from: endpoint("/state"))
        try validate(response: response)
        return try decoder.decode(RoonBridgeSnapshot.self, from: data)
    }

    func refreshStartingIfNeeded() async throws -> RoonBridgeSnapshot {
        do {
            return try await refresh()
        } catch {
            guard shouldStartBridge(after: error) else {
                throw error
            }

            try startIfNeeded()
            return try await refresh()
        }
    }

    func send(_ control: RoonBridgeControl) async throws -> RoonBridgeCommandResponse {
        var request = URLRequest(url: endpoint("/control"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(["control": control.rawValue])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RoonBridgeClientError.requestFailed("Roon bridge returned an invalid response.")
        }

        let payload = try decoder.decode(RoonBridgeCommandResponse.self, from: data)
        guard (200..<300).contains(httpResponse.statusCode), payload.ok else {
            throw RoonBridgeClientError.commandRejected(payload.error ?? "Roon command failed.")
        }

        return payload
    }

    func sendStartingIfNeeded(_ control: RoonBridgeControl) async throws -> RoonBridgeCommandResponse {
        do {
            return try await send(control)
        } catch {
            guard shouldStartBridge(after: error) else {
                throw error
            }

            try startIfNeeded()
            return try await send(control)
        }
    }

    func imageURL(for imageKey: String) -> URL? {
        guard !imageKey.isEmpty,
              let encoded = imageKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else {
            return nil
        }

        return endpoint("/image/\(encoded)")
    }

    func fetchImageData(for imageKey: String) async throws -> Data {
        guard let url = imageURL(for: imageKey) else {
            throw RoonBridgeClientError.requestFailed("Roon artwork image key is empty.")
        }

        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)
        return data
    }

    func fetchImageDataStartingIfNeeded(for imageKey: String) async throws -> Data {
        do {
            return try await fetchImageData(for: imageKey)
        } catch {
            guard shouldStartBridge(after: error) else {
                throw error
            }

            try startIfNeeded()
            return try await fetchImageData(for: imageKey)
        }
    }

    private func endpoint(_ path: String) -> URL {
        URL(string: "http://127.0.0.1:\(port)\(path)")!
    }

    private func validate(response: URLResponse) throws {
        try validate(response: response, data: nil)
    }

    private func validate(response: URLResponse, data: Data?) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RoonBridgeClientError.requestFailed("Roon bridge returned an invalid response.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw RoonBridgeClientError.httpFailure(
                httpResponse.statusCode,
                data.flatMap(Self.bridgeErrorMessage(from:))
            )
        }
    }

    private static func bridgeErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return object["error"] as? String
    }

    private func shouldStartBridge(after error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }

        switch urlError.code {
        case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet, .timedOut, .cannotFindHost:
            return true
        default:
            return false
        }
    }

    private var bridgeRuntimePath: String {
        let existingPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let standardPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        return existingPath.isEmpty ? standardPaths : "\(standardPaths):\(existingPath)"
    }

    private func nodeExecutableURL() throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        let pathCandidates = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
            .map { URL(fileURLWithPath: $0).appendingPathComponent("node") }

        let candidates = [
            environment["ORBISONIC_NODE_PATH"].map(URL.init(fileURLWithPath:)),
            URL(fileURLWithPath: "/opt/homebrew/bin/node"),
            URL(fileURLWithPath: "/usr/local/bin/node"),
            URL(fileURLWithPath: "/usr/bin/node")
        ].compactMap { $0 } + pathCandidates

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate.path) {
            return candidate
        }

        throw RoonBridgeClientError.missingNodeRuntime
    }

    private func prepareSupportDirectory() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: supportDirectoryURL, withIntermediateDirectories: true)

        let resourceURL = try bundledBridgeURL()
        for filename in ["bridge.js", "package.json"] {
            let source = resourceURL.appendingPathComponent(filename)
            let destination = supportDirectoryURL.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
        }
    }

    private func dependenciesAreInstalled() -> Bool {
        let nodeModules = supportDirectoryURL.appendingPathComponent("node_modules", isDirectory: true)
        let apiModule = nodeModules.appendingPathComponent("node-roon-api", isDirectory: true)
        let imageModule = nodeModules.appendingPathComponent("node-roon-api-image", isDirectory: true)
        return FileManager.default.fileExists(atPath: apiModule.path) &&
            FileManager.default.fileExists(atPath: imageModule.path)
    }

    private func bundledBridgeURL() throws -> URL {
        if let url = OrbisonicResourceLocator.directory(
            containing: ["bridge.js", "package.json"],
            preferredSubdirectory: "RoonBridge"
        ) {
            return url
        }

        throw RoonBridgeClientError.bridgeResourceMissing
    }
}
