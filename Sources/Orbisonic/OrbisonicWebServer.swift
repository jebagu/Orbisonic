import AppKit
import Darwin
import Foundation
import Network

private enum OrbisonicWebConstants {
    static let port: UInt16 = 37_943
    static let basePath = "/Orbisonic"
}

struct OrbisonicWebURLSet: Equatable {
    let publicURL: String
}

private enum OrbisonicWebID {
    static func stableID(for value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }
}

private struct OrbisonicWebRequest {
    let method: String
    let path: String
    let query: [String: String]
    let headers: [String: String]
    let body: Data

    var token: String? {
        if let headerToken = headers["x-orbisonic-token"], !headerToken.isEmpty {
            return headerToken
        }

        if let auth = headers["authorization"],
           auth.localizedCaseInsensitiveContains("bearer ") {
            return auth.split(separator: " ").last.map(String.init)
        }

        return query["token"]
    }
}

private struct OrbisonicWebCommandPayload: Decodable {
    var action: String?
    var id: String?
    var value: String?
    var query: String?
    var sort: String?
    var index: Int?
    var seconds: Int?
    var shuffle: Bool?
}

private struct OrbisonicWebCommandResponse: Encodable {
    let ok: Bool
    let message: String
    let state: OrbisonicWebState?
}

struct OrbisonicWebState: Encodable {
    struct URLs: Encodable {
        let publicPage: String
        let controlPage: String?
    }

    struct Player: Encodable {
        let title: String
        let subtitle: String
        let source: String
        let status: String
        let isPlaying: Bool
        let artworkURL: String?
        let volume: Int
        let currentTime: String
        let duration: String
        let progress: Double
        let details: [Detail]
        let controls: [String]
        let enabledControls: [String]
    }

    struct Detail: Encodable {
        let title: String
        let value: String
    }

    struct Route: Encodable {
        let id: String
        let name: String
        let detail: String
        let isSelected: Bool
        let isSelectable: Bool
    }

    struct SourceButton: Encodable {
        let value: String
        let title: String
        let subtitle: String
        let isSelected: Bool
        let severity: String
    }

    struct SourcePanel: Encodable {
        let title: String
        let status: String
        let headline: String
        let body: String
        let rows: [Detail]
        let severity: String
        let isSwitching: Bool
    }

    struct Input: Encodable {
        let source: String
        let selectedDevice: String
        let status: String
        let monitorState: String
        let availableSources: [String]
        let availableInputs: [Route]
        let sourceButtons: [SourceButton]
        let sourcePanel: SourcePanel
    }

    struct Routing: Encodable {
        let source: String
        let incoming: String
        let monitorOutput: String
        let monitorStatus: String
        let rendererOutput: String
        let rendererStatus: String
        let rendererScene: String
        let monitorOptions: [Route]
        let rendererOptions: [Route]
    }

    struct LocalMusic: Encodable {
        let search: String
        let sort: String
        let count: String
        let queue: String
        let tracks: [Track]
        let playlists: [Playlist]
        let sessionQueue: [QueueItem]
    }

    struct Track: Encodable {
        let id: String
        let title: String
        let subtitle: String
        let album: String
        let artist: String
        let channels: String
        let duration: String
        let isSelected: Bool
        let isCurrent: Bool
        let isPending: Bool
    }

    struct Playlist: Encodable {
        let id: String
        let name: String
        let fileName: String
        let trackCount: Int
        let isSelected: Bool
    }

    struct QueueItem: Encodable {
        let index: Int
        let title: String
        let subtitle: String
        let channels: String
        let isSelected: Bool
        let isCurrent: Bool
        let isPending: Bool
    }

    struct Diagnostics: Encodable {
        let active: String
        let toneStatus: String
        let monitorChannelCount: Int
        let rendererChannelCount: Int
        let isRunning: Bool
        let isTransitioning: Bool
        let selectedChannel: Int
        let availableTests: [String]
    }

    struct Build: Encodable {
        let webServer: String
        let appStatus: String
        let lastError: String?
        let appVersion: String
        let buildNumber: String
        let machineIP: String
    }

    let generatedAt: String
    let controlEnabled: Bool
    let urls: URLs
    let player: Player
    let input: Input
    let routing: Routing
    let localMusic: LocalMusic?
    let diagnostics: Diagnostics
    let build: Build
}

final class OrbisonicWebServer {
    private weak var model: OrbisonicViewModel?
    private var controlToken: String
    private let controlTokenLock = NSLock()
    private let queue = DispatchQueue(label: "orbisonic.web-server")
    private var listener: NWListener?
    private let statusHandler: @MainActor (String) -> Void

    init(
        model: OrbisonicViewModel,
        controlToken: String,
        statusHandler: @escaping @MainActor (String) -> Void
    ) {
        self.model = model
        self.controlToken = controlToken
        self.statusHandler = statusHandler
    }

    func updateControlToken(_ token: String) {
        controlTokenLock.lock()
        controlToken = token
        controlTokenLock.unlock()
    }

    static func urlSet(controlToken: String) -> OrbisonicWebURLSet {
        let host = preferredLANHost()
        let baseURL = "http://\(host):\(OrbisonicWebConstants.port)\(OrbisonicWebConstants.basePath)"
        return OrbisonicWebURLSet(
            publicURL: "\(baseURL)/"
        )
    }

    func start() {
        do {
            let port = NWEndpoint.Port(rawValue: OrbisonicWebConstants.port)!
            let listener = try NWListener(using: .tcp, on: port)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                self?.handleListenerState(state)
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            Task { @MainActor [statusHandler] in
                statusHandler("Web server unavailable on port \(OrbisonicWebConstants.port): \(error.localizedDescription)")
            }
            AppLogger.shared.error(category: "web", "Web server failed to start: \(error.localizedDescription)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handleListenerState(_ state: NWListener.State) {
        let message: String
        switch state {
        case .ready:
            message = "Web pages listening on port \(OrbisonicWebConstants.port)."
            AppLogger.shared.notice(category: "web", message)
        case .failed(let error):
            message = "Web server failed: \(error.localizedDescription)"
            AppLogger.shared.error(category: "web", message)
        case .cancelled:
            message = "Web server stopped."
        case .waiting(let error):
            message = "Web server waiting: \(error.localizedDescription)"
        default:
            message = "Web server starting."
        }

        Task { @MainActor [statusHandler] in
            statusHandler(message)
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1_024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var nextBuffer = buffer
            if let data {
                nextBuffer.append(data)
            }

            if let error {
                AppLogger.shared.warning(category: "web", "HTTP receive failed: \(error.localizedDescription)")
                connection.cancel()
                return
            }

            if let request = Self.parseRequest(nextBuffer) {
                self.respond(to: request, on: connection)
                return
            }

            if isComplete {
                self.send(status: 400, contentType: "text/plain; charset=utf-8", body: "Bad request", on: connection)
            } else {
                self.receive(on: connection, buffer: nextBuffer)
            }
        }
    }

    private func respond(to request: OrbisonicWebRequest, on connection: NWConnection) {
        if request.method == "OPTIONS" {
            send(status: 204, contentType: "text/plain; charset=utf-8", body: "", on: connection)
            return
        }

        if request.method == "GET", isPublicPagePath(request.path) {
            send(status: 200, contentType: "text/html; charset=utf-8", body: Self.publicPageHTML, on: connection)
            return
        }

        if request.method == "GET", request.path == "\(OrbisonicWebConstants.basePath)/api/public-state" {
            Task { @MainActor [weak self] in
                guard let self, let model else { return }
                let state = model.makeWebState(controlEnabled: false)
                self.sendJSON(state, on: connection)
            }
            return
        }

        guard request.path.hasPrefix("\(OrbisonicWebConstants.basePath)/api/") else {
            sendJSON(OrbisonicWebCommandResponse(ok: false, message: "Not found.", state: nil), status: 404, on: connection)
            return
        }

        guard isValidControlToken(request.token) else {
            sendJSON(OrbisonicWebCommandResponse(ok: false, message: "Control token required.", state: nil), status: 401, on: connection)
            return
        }

        if request.method == "GET", request.path == "\(OrbisonicWebConstants.basePath)/api/state" {
            Task { @MainActor [weak self] in
                guard let self, let model else { return }
                self.sendJSON(model.makeWebState(controlEnabled: true), on: connection)
            }
            return
        }

        if request.method == "GET", request.path == "\(OrbisonicWebConstants.basePath)/api/artwork/current" {
            Task { @MainActor [weak self] in
                guard let self, let artworkURL = model?.webCurrentArtworkURL else {
                    self?.send(status: 404, contentType: "text/plain; charset=utf-8", body: "Artwork unavailable", on: connection)
                    return
                }

                Task.detached { [weak self] in
                    guard let self else { return }
                    do {
                        let data = try Data(contentsOf: artworkURL)
                        let contentType = Self.artworkContentType(for: artworkURL, data: data)
                        self.send(status: 200, contentType: contentType, bodyData: data, on: connection)
                    } catch {
                        self.send(status: 404, contentType: "text/plain; charset=utf-8", body: "Artwork unavailable", on: connection)
                    }
                }
            }
            return
        }

        if request.method == "POST" {
            let payload = (try? JSONDecoder().decode(OrbisonicWebCommandPayload.self, from: request.body)) ?? OrbisonicWebCommandPayload()
            Task { @MainActor [weak self] in
                guard let self, let model else { return }
                do {
                    let state = try model.performWebCommand(path: request.path, payload: payload)
                    self.sendJSON(OrbisonicWebCommandResponse(ok: true, message: model.statusMessage, state: state), on: connection)
                } catch {
                    self.sendJSON(
                        OrbisonicWebCommandResponse(ok: false, message: error.localizedDescription, state: model.makeWebState(controlEnabled: true)),
                        status: 400,
                        on: connection
                    )
                }
            }
            return
        }

        sendJSON(OrbisonicWebCommandResponse(ok: false, message: "Unsupported method.", state: nil), status: 405, on: connection)
    }

    private func isPublicPagePath(_ path: String) -> Bool {
        path == "/" ||
            path == OrbisonicWebConstants.basePath ||
            path == "\(OrbisonicWebConstants.basePath)/" ||
            path == "\(OrbisonicWebConstants.basePath)/public" ||
            path == "\(OrbisonicWebConstants.basePath)/public/"
    }

    private func isValidControlToken(_ token: String?) -> Bool {
        controlTokenLock.lock()
        let expectedToken = controlToken
        controlTokenLock.unlock()

        return token == expectedToken
    }

    private func sendJSON<T: Encodable>(_ value: T, status: Int = 200, on connection: NWConnection) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(value)
            send(status: status, contentType: "application/json; charset=utf-8", bodyData: data, on: connection)
        } catch {
            send(status: 500, contentType: "text/plain; charset=utf-8", body: "JSON encode failed", on: connection)
        }
    }

    private func send(status: Int, contentType: String, body: String, on connection: NWConnection) {
        let data = Data(body.utf8)
        send(status: status, contentType: contentType, bodyData: data, on: connection)
    }

    private func send(status: Int, contentType: String, bodyData: Data, on connection: NWConnection) {
        let reason = Self.reasonPhrase(for: status)
        let headers = [
            "HTTP/1.1 \(status) \(reason)",
            "Content-Type: \(contentType)",
            "Content-Length: \(bodyData.count)",
            "Cache-Control: no-store",
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Methods: GET, POST, OPTIONS",
            "Access-Control-Allow-Headers: Content-Type, X-Orbisonic-Token, Authorization",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")

        var responseData = Data(headers.utf8)
        responseData.append(bodyData)
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func parseRequest(_ data: Data) -> OrbisonicWebRequest? {
        guard let headerEndRange = data.range(of: Data("\r\n\r\n".utf8)),
              let headerText = String(data: data[..<headerEndRange.lowerBound], encoding: .utf8)
        else {
            return nil
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            headers[key] = value
        }

        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = headerEndRange.upperBound
        guard data.count >= bodyStart + contentLength else {
            return nil
        }

        let target = parts[1]
        let splitTarget = target.split(separator: "?", maxSplits: 1).map(String.init)
        let rawPath = splitTarget.first ?? "/"
        let path = rawPath.removingPercentEncoding ?? rawPath
        let query = splitTarget.count > 1 ? parseQuery(splitTarget[1]) : [:]
        let body = data[bodyStart..<(bodyStart + contentLength)]

        return OrbisonicWebRequest(
            method: parts[0].uppercased(),
            path: path,
            query: query,
            headers: headers,
            body: Data(body)
        )
    }

    private static func parseQuery(_ query: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard let key = parts.first?.removingPercentEncoding, !key.isEmpty else { continue }
            let value = parts.count > 1 ? (parts[1].removingPercentEncoding ?? parts[1]) : ""
            result[key] = value
        }
        return result
    }

    private static func reasonPhrase(for status: Int) -> String {
        switch status {
        case 200: "OK"
        case 204: "No Content"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        default: "Server Error"
        }
    }

    private static func artworkContentType(for url: URL, data: Data) -> String {
        let ext = url.pathExtension.lowercased()
        if ext == "png" || data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "image/png"
        }
        return "image/jpeg"
    }

    private static func preferredLANHost() -> String {
        preferredIPv4Address() ?? "127.0.0.1"
    }

    private static func preferredIPv4Address() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else {
            return nil
        }
        defer { freeifaddrs(ifaddr) }

        var fallback: String?
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            guard let address = current.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET)
            else { continue }

            let flags = Int32(current.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0,
                  (flags & IFF_LOOPBACK) == 0
            else { continue }

            var socketAddress = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            let result = inet_ntop(AF_INET, &socketAddress.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN))
            guard result != nil else { continue }
            let ip = String(cString: buffer)
            guard !ip.hasPrefix("169.254.") else { continue }

            let name = current.pointee.ifa_name.map { String(cString: $0) } ?? ""
            if name == "en0" || name == "en1" {
                return ip
            }
            fallback = fallback ?? ip
        }

        return fallback
    }
}

@MainActor
extension OrbisonicViewModel {
    fileprivate func makeWebState(controlEnabled: Bool) -> OrbisonicWebState {
        OrbisonicWebState(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            controlEnabled: controlEnabled,
            urls: OrbisonicWebState.URLs(
                publicPage: self.webPublicPageURL,
                controlPage: nil
            ),
            player: makeWebPlayerState(controlEnabled: controlEnabled),
            input: controlEnabled ? makeWebInputState() : makeWebPublicInputState(),
            routing: controlEnabled ? makeWebRoutingState() : makeWebPublicRoutingState(),
            localMusic: controlEnabled ? makeWebLocalMusicState() : nil,
            diagnostics: controlEnabled ? makeWebDiagnosticsState() : makeWebPublicDiagnosticsState(),
            build: controlEnabled ? makeWebBuildState() : makeWebPublicBuildState()
        )
    }

    func webStateForTesting(controlEnabled: Bool) -> OrbisonicWebState {
        makeWebState(controlEnabled: controlEnabled)
    }

    fileprivate func performWebCommand(path: String, payload: OrbisonicWebCommandPayload) throws -> OrbisonicWebState {
        switch path {
        case "\(OrbisonicWebConstants.basePath)/api/player/control":
            try performWebPlayerCommand(payload)
        case "\(OrbisonicWebConstants.basePath)/api/player/volume":
            try performWebVolumeCommand(payload)
        case "\(OrbisonicWebConstants.basePath)/api/input/source":
            try performWebSourceCommand(payload)
        case "\(OrbisonicWebConstants.basePath)/api/input/route":
            try performWebInputRouteCommand(payload)
        case "\(OrbisonicWebConstants.basePath)/api/input/monitor":
            try performWebMonitorCommand(payload)
        case "\(OrbisonicWebConstants.basePath)/api/routing/monitor-output":
            try performWebMonitorOutputCommand(payload)
        case "\(OrbisonicWebConstants.basePath)/api/routing/renderer-output":
            try performWebRendererOutputCommand(payload)
        case "\(OrbisonicWebConstants.basePath)/api/local-music/search":
            localMusicSearchText = payload.query ?? ""
            if let sort = payload.sort, let mode = PlaylistSortMode(rawValue: sort) {
                localMusicSortMode = mode
            }
        case "\(OrbisonicWebConstants.basePath)/api/local-music/track":
            throw OrbisonicWebCommandError.webControlReadOnly
        case "\(OrbisonicWebConstants.basePath)/api/local-music/playlist":
            throw OrbisonicWebCommandError.webControlReadOnly
        case "\(OrbisonicWebConstants.basePath)/api/local-music/queue":
            throw OrbisonicWebCommandError.webControlReadOnly
        case "\(OrbisonicWebConstants.basePath)/api/local-music/rescan":
            throw OrbisonicWebCommandError.webControlReadOnly
        case "\(OrbisonicWebConstants.basePath)/api/diagnostics":
            try performWebDiagnosticsCommand(payload)
        default:
            throw OrbisonicWebCommandError.unsupportedCommand
        }

        return makeWebState(controlEnabled: true)
    }

    private func makeWebPlayerState(controlEnabled: Bool) -> OrbisonicWebState.Player {
        OrbisonicWebState.Player(
            title: webNowPlayingTitle,
            subtitle: webNowPlayingSubtitle,
            source: sourceMode.rawValue,
            status: webPlayerStatus,
            isPlaying: webPlayerIsPlaying,
            artworkURL: controlEnabled ? webArtworkPath : nil,
            volume: sphereOutputVolumeValue,
            currentTime: webPlayerCurrentTime,
            duration: webPlayerDuration,
            progress: webPlayerProgress,
            details: webPlayerDetails,
            controls: webPlayerControls,
            enabledControls: webEnabledPlayerControls
        )
    }

    private var webPlayerIsPlaying: Bool {
        switch sourceMode {
        case .spotify:
            return spotifyVisibleNowPlaying?.isPlaying == true
        case .roon, .aux:
            return liveMonitorState == .monitoring
        case .filePlayback:
            return isPlaying
        case .testTone:
            return isTestTonePlaying
        case .off:
            return false
        }
    }

    fileprivate var webCurrentArtworkURL: URL? {
        switch sourceMode {
        case .off:
            nil
        case .roon:
            roonArtworkURL
        case .spotify:
            spotifyArtworkURL
        case .filePlayback:
            currentLocalArtworkURL
        case .aux, .testTone:
            nil
        }
    }

    private var webArtworkPath: String? {
        guard let artworkURL = webCurrentArtworkURL else { return nil }
        let cacheKey = OrbisonicWebID.stableID(for: artworkURL.absoluteString)
        return "\(OrbisonicWebConstants.basePath)/api/artwork/current?token=\(webControlTokenForLocalServer)&v=\(cacheKey)"
    }

    private func makeWebInputState() -> OrbisonicWebState.Input {
        OrbisonicWebState.Input(
            source: sourceMode.rawValue,
            selectedDevice: inputRoute.displayName,
            status: selectedSourceDeviceStatusText,
            monitorState: webSelectedSourceStatusText,
            availableSources: SourceMode.musicInputs.map(\.rawValue),
            availableInputs: [],
            sourceButtons: webSourceButtons,
            sourcePanel: webSourcePanel
        )
    }

    private func makeWebPublicInputState() -> OrbisonicWebState.Input {
        OrbisonicWebState.Input(
            source: sourceMode.rawValue,
            selectedDevice: "",
            status: webPublicSignalText,
            monitorState: webPlayerStatus,
            availableSources: [],
            availableInputs: [],
            sourceButtons: [],
            sourcePanel: OrbisonicWebState.SourcePanel(
                title: (sourceSwitchTargetMode ?? sourceMode).rawValue,
                status: webSelectedSourceStatusText,
                headline: webSelectedSourceHeadline,
                body: webSelectedSourceBody,
                rows: [],
                severity: webSourceSeverity,
                isSwitching: isLiveMonitorTransitioning
            )
        )
    }

    private var webSourceButtons: [OrbisonicWebState.SourceButton] {
        SourceMode.musicInputs.map { mode in
            OrbisonicWebState.SourceButton(
                value: mode.rawValue,
                title: mode.rawValue,
                subtitle: "",
                isSelected: sourceSwitchTargetMode == mode || sourceMode == mode,
                severity: webSourceButtonSeverity(for: mode)
            )
        }
    }

    private var webSourcePanel: OrbisonicWebState.SourcePanel {
        OrbisonicWebState.SourcePanel(
            title: (sourceSwitchTargetMode ?? sourceMode).rawValue,
            status: webSelectedSourceStatusText,
            headline: webSelectedSourceHeadline,
            body: webSelectedSourceBody,
            rows: webSelectedSourceRows,
            severity: webSourceSeverity,
            isSwitching: isLiveMonitorTransitioning
        )
    }

    private var webSelectedSourceStatusText: String {
        if let sourceSwitchStatusText {
            return sourceSwitchStatusText
        }
        if sourceMode == .off {
            return "Orbisonic is idle"
        }

        switch sourceMode {
        case .roon:
            if webSelectedLiveSourceUnavailable {
                return "Roon unavailable"
            }
            return liveMonitorState == .monitoring ? "Playing through Orbisonic" : "Waiting for Roon audio"
        case .spotify:
            if webSpotifyReceiverUnavailable {
                return "Receiver unavailable"
            }
            if liveMonitorState == .monitoring {
                return "Playing through Orbisonic"
            }
            return spotifyVisibleNowPlaying == nil ? "Waiting for Spotify" : "No audio yet"
        case .aux:
            if webSelectedLiveSourceUnavailable || webLiveInputReadyValue(expected: .auxCable) == "Missing" {
                return "Input unavailable"
            }
            return liveMonitorState == .monitoring ? "Playing through Orbisonic" : "Listening for input"
        case .filePlayback:
            return "Ready"
        case .testTone:
            return isTestTonePlaying ? "Playing through Orbisonic" : "Ready"
        case .off:
            return "Orbisonic is idle"
        }
    }

    private var webSelectedSourceHeadline: String {
        if let sourceSwitchStatusText {
            return sourceSwitchStatusText
        }

        switch sourceMode {
        case .off:
            return "Orbisonic is idle"
        case .roon:
            if webSelectedLiveSourceUnavailable {
                return "Roon unavailable"
            }
            return liveMonitorState == .monitoring ? "Playing through Orbisonic" : "Waiting for Roon audio"
        case .spotify:
            if webSpotifyReceiverUnavailable {
                return "Spotify receiver unavailable"
            }
            if liveMonitorState == .monitoring {
                return "Playing through Orbisonic"
            }
            return spotifyVisibleNowPlaying == nil ? "Waiting for Spotify" : "Waiting for audio"
        case .aux:
            if webSelectedLiveSourceUnavailable || webLiveInputReadyValue(expected: .auxCable) == "Missing" {
                return "Input unavailable"
            }
            return liveMonitorState == .monitoring ? "Playing through Orbisonic" : "Listening for input"
        case .filePlayback:
            return "Ready"
        case .testTone:
            return "Diagnostics source is selected."
        }
    }

    private var webSelectedSourceBody: String {
        if let sourceSwitchStatusText {
            return sourceSwitchStatusText == "Stopping audio..."
                ? "Orbisonic is ramping down before stopping the active audio path."
                : "Orbisonic is ramping down before changing the active audio path."
        }

        switch sourceMode {
        case .off:
            return "Select a source to begin listening or playback."
        case .roon:
            if webSelectedLiveSourceUnavailable {
                return "Orbisonic could not connect to the Roon service."
            }
            return liveMonitorState == .monitoring
                ? "Roon audio is being rendered by Orbisonic."
                : "Use Roon to send audio to Orbisonic."
        case .spotify:
            if webSpotifyReceiverUnavailable {
                return "Orbisonic could not start the Spotify receiver."
            }
            if spotifyVisibleNowPlaying != nil, liveMonitorState != .monitoring {
                return "Spotify is connected. Press play in Spotify to hear it through Orbisonic."
            }
            return liveMonitorState == .monitoring
                ? "Spotify audio is being rendered by Orbisonic."
                : "Use the Spotify app to connect to \"Orbisonic Spotify\" and press play there."
        case .aux:
            if webSelectedLiveSourceUnavailable || webLiveInputReadyValue(expected: .auxCable) == "Missing" {
                return "Orbisonic could not find the selected Aux input."
            }
            return liveMonitorState == .monitoring
                ? "Aux audio is being rendered by Orbisonic."
                : "Connect an audio source to the selected input."
        case .filePlayback:
            return "Use the Player below to choose files and control playback."
        case .testTone:
            return "Test tones remain available for diagnostics."
        }
    }

    private var webSelectedSourceRows: [OrbisonicWebState.Detail] {
        switch sourceMode {
        case .off:
            return [
                .init(title: "Engine", value: "Idle"),
                .init(title: "Output", value: "Silent")
            ]
        case .roon:
            return [
                .init(title: "Roon", value: webRoonSourceStatusValue),
                .init(title: "Input", value: webLiveInputReadyValue(expected: .roonInput)),
                .init(title: "Signal", value: webLiveSignalValue)
            ]
        case .spotify:
            return [
                .init(title: "Receiver", value: webSpotifyReceiverStatusValue),
                .init(title: "Input", value: webLiveInputReadyValue(expected: .spotifyInput)),
                .init(title: "Signal", value: webLiveSignalValue)
            ]
        case .aux:
            return [
                .init(title: "Input", value: webLiveInputReadyValue(expected: .auxCable)),
                .init(title: "Signal", value: webLiveSignalValue)
            ]
        case .filePlayback:
            return [
                .init(title: "Library", value: "Ready"),
                .init(title: "Playback", value: "Controlled by Orbisonic")
            ]
        case .testTone:
            return [
                .init(title: "Diagnostics", value: testToneStatus.isEmpty ? "Ready" : testToneStatus)
            ]
        }
    }

    private var webRoonSourceStatusValue: String {
        if case .error = liveMonitorState {
            return "Unavailable"
        }
        if roonBridgeSnapshot.isReadyForTransport {
            return liveMonitorState == .monitoring ? "Connected" : "Ready"
        }
        return "Unavailable"
    }

    private var webSpotifyReceiverStatusValue: String {
        switch spotifyReceiverStatus.state {
        case .waitingForConnection:
            return spotifyVisibleNowPlaying == nil ? "Ready" : "Connected"
        case .running:
            return "Connected"
        case .restarting:
            return "Ready"
        case .failed, .embeddedModuleUnavailable:
            return "Failed"
        case .notStarted:
            return "Ready"
        }
    }

    private func webLiveInputReadyValue(expected: OrbisonicLoopbackDevice) -> String {
        inputRoute.uid == expected.deviceUID ? "Ready" : "Missing"
    }

    private var webSelectedLiveSourceUnavailable: Bool {
        guard sourceMode.isLiveInput else { return false }
        if sourceMode == .roon && liveMonitorState != .monitoring && !roonBridgeSnapshot.isReadyForTransport {
            return true
        }
        switch liveMonitorState {
        case .unavailable, .error:
            return true
        case .stopped, .monitoring, .muted, .silent:
            return false
        }
    }

    private var webSpotifyReceiverUnavailable: Bool {
        switch spotifyReceiverStatus.state {
        case .failed, .embeddedModuleUnavailable:
            return true
        case .notStarted, .waitingForConnection, .running, .restarting:
            return false
        }
    }

    private var webLiveSignalValue: String {
        switch liveMonitorState {
        case .monitoring:
            return "Present"
        case .silent, .stopped, .muted:
            return "No audio yet"
        case .unavailable, .error:
            return "No audio"
        }
    }

    private func webSourceButtonSeverity(for mode: SourceMode) -> String {
        guard sourceSwitchTargetMode == mode || sourceMode == mode else {
            return "ready"
        }
        return webSourceSeverity
    }

    private var webSourceSeverity: String {
        if isLiveMonitorTransitioning {
            return "waiting"
        }
        if sourceMode == .off {
            return "idle"
        }
        if sourceMode.isLiveInput {
            if webSelectedLiveSourceUnavailable ||
                (sourceMode == .spotify && webSpotifyReceiverUnavailable) ||
                (sourceMode == .aux && webLiveInputReadyValue(expected: .auxCable) == "Missing") {
                return "failed"
            }
            switch liveMonitorState {
            case .monitoring:
                return "active"
            case .silent, .muted:
                return "waiting"
            case .stopped:
                return "ready"
            case .unavailable, .error:
                return "failed"
            }
        }
        return isPlaying || isTestTonePlaying ? "active" : "ready"
    }

    private func makeWebRoutingState() -> OrbisonicWebState.Routing {
        OrbisonicWebState.Routing(
            source: sourceFlowTitle,
            incoming: inputNowText,
            monitorOutput: monitorOutputSelectionText,
            monitorStatus: monitorOutputStatusText,
            rendererOutput: rendererOutputSelectionText,
            rendererStatus: rendererOutputStatusText,
            rendererScene: rendererSceneOutputText,
            monitorOptions: [],
            rendererOptions: []
        )
    }

    private func makeWebPublicRoutingState() -> OrbisonicWebState.Routing {
        OrbisonicWebState.Routing(
            source: sourceMode.rawValue,
            incoming: webPublicSignalText,
            monitorOutput: "",
            monitorStatus: "",
            rendererOutput: "",
            rendererStatus: "",
            rendererScene: rendererSceneOutputText,
            monitorOptions: [],
            rendererOptions: []
        )
    }

    private func makeWebLocalMusicState() -> OrbisonicWebState.LocalMusic {
        OrbisonicWebState.LocalMusic(
            search: localMusicSearchText,
            sort: localMusicSortMode.rawValue,
            count: localMusicCountText,
            queue: "",
            tracks: visibleLocalMusicTracks.prefix(80).map(webTrackState),
            playlists: localMusicPlaylists.prefix(80).map(webPlaylistState),
            sessionQueue: []
        )
    }

    private func makeWebDiagnosticsState() -> OrbisonicWebState.Diagnostics {
        OrbisonicWebState.Diagnostics(
            active: activeDiagnosticText,
            toneStatus: testToneStatus,
            monitorChannelCount: monitorChannelWalkCount,
            rendererChannelCount: rendererOutputChannelWalkCount,
            isRunning: isDiagnosticSequencePlaying,
            isTransitioning: isDiagnosticTransitioning,
            selectedChannel: selectedDiagnosticSpeakerChannel,
            availableTests: ["monitorWalk", "rendererWalk", "testTone"]
        )
    }

    private func makeWebPublicDiagnosticsState() -> OrbisonicWebState.Diagnostics {
        OrbisonicWebState.Diagnostics(
            active: "",
            toneStatus: "",
            monitorChannelCount: 0,
            rendererChannelCount: 0,
            isRunning: false,
            isTransitioning: false,
            selectedChannel: 0,
            availableTests: []
        )
    }

    private func makeWebBuildState() -> OrbisonicWebState.Build {
        OrbisonicWebState.Build(
            webServer: self.webServerStatus,
            appStatus: self.statusMessage,
            lastError: self.controlLastError,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "dev",
            machineIP: URLComponents(string: webPublicPageURL).flatMap(\.host) ?? "unknown"
        )
    }

    private func makeWebPublicBuildState() -> OrbisonicWebState.Build {
        OrbisonicWebState.Build(
            webServer: self.webServerStatus,
            appStatus: "",
            lastError: nil,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "dev",
            machineIP: URLComponents(string: webPublicPageURL).flatMap(\.host) ?? "unknown"
        )
    }

    private var webNowPlayingTitle: String {
        switch sourceMode {
        case .off:
            return "Off"
        case .roon:
            if let title = roonTransportTitleText, !title.isEmpty {
                return title
            }
            if let nowPlaying = roonNowPlaying {
                return nowPlaying.title
            }
            return "Roon"
        case .testTone:
            return selectedTestTonePoint.rawValue
        case .aux:
            return "Aux Cable"
        case .spotify:
            return spotifyVisibleNowPlaying?.displayTitle ?? "Spotify"
        case .filePlayback:
            if let track = currentQueueTrack ?? currentLocalMusicTrack {
                return track.displayTitle
            }
            if let metadata = sourceMetadata {
                return metadata.title?.trimmedNilIfBlank ?? metadata.fileName
            }
            return "No source loaded"
        }
    }

    private var webNowPlayingSubtitle: String {
        switch sourceMode {
        case .off:
            return "Orbisonic is idle"
        case .roon:
            if let subtitle = roonTransportSubtitleText, !subtitle.isEmpty {
                return subtitle
            }
            if let nowPlaying = roonNowPlaying {
                return nowPlaying.artist.isEmpty ? "Roon" : nowPlaying.artist
            }
            return "Controlled from Roon."
        case .testTone:
            return testToneStatus
        case .aux:
            return "Controlled in the source app."
        case .spotify:
            return spotifyVisibleNowPlaying?.artistText ?? "Controlled from Spotify Connect."
        case .filePlayback:
            if let track = currentQueueTrack ?? currentLocalMusicTrack {
                return track.displaySubtitle
            }
            if let metadata = sourceMetadata {
                let albumArtist = [metadata.album?.trimmedNilIfBlank, metadata.artist?.trimmedNilIfBlank].compactMap { $0 }.joined(separator: " - ")
                return albumArtist.isEmpty ? "\(metadata.layoutName) • \(metadata.channelCount) ch • \(metadata.sampleRateText)" : albumArtist
            }
            return "Choose Roon, Spotify, Aux Cable, or Local Files."
        }
    }

    private var webPlayerStatus: String {
        if isLiveMonitorTransitioning {
            return sourceSwitchStatusText ?? "Stopping audio..."
        }

        switch sourceMode {
        case .off:
            return "Orbisonic is idle"
        case .roon:
            return webRoonPlaybackStatus
        case .spotify:
            return webSpotifyPlaybackStatus
        case .aux:
            return "Aux has no transport"
        case .testTone:
            return isTestTonePlaying ? "Test tone playing" : "Test tone ready"
        case .filePlayback:
            return webLocalPlaybackStatus
        }
    }

    private var webLocalPlaybackStatus: String {
        if isLocalFileLoading {
            return webCondensedLocalLoadingStatus(statusMessage)
        }
        if isPlaying {
            return "Local playback playing"
        }
        if statusMessage.localizedCaseInsensitiveContains("paused") {
            return "Local playback paused"
        }
        return "Local playback stopped"
    }

    private func webCondensedLocalLoadingStatus(_ status: String) -> String {
        if status.hasPrefix("Starting playback") {
            return "Starting playback..."
        }
        if status.hasPrefix("Loading selected track") {
            return "Loading selected track..."
        }
        if status.hasPrefix("Loading previous track") {
            return "Loading previous track..."
        }
        if status.hasPrefix("Loading large audio file") {
            return "Loading large audio file..."
        }
        if status.hasPrefix("Still loading") {
            return "Still loading. You can press Stop to cancel."
        }
        return "Loading next track..."
    }

    private var webRoonPlaybackStatus: String {
        guard let state = roonBridgeSnapshot.selectedZone?.state.lowercased() else {
            return liveMonitorState == .monitoring ? "Roon playing" : "Roon playback stopped"
        }
        switch state {
        case "playing", "loading":
            return "Roon playing"
        case "paused":
            return "Roon playback paused"
        default:
            return "Roon playback stopped"
        }
    }

    private var webSpotifyPlaybackStatus: String {
        guard spotifyReceiverStatus.isRunning else {
            return "Spotify playback stopped"
        }
        if spotifyVisibleNowPlaying?.isPlaying == true {
            return "Spotify playing"
        }
        return spotifyVisibleNowPlaying == nil ? "No Spotify track selected" : "Spotify playback paused"
    }

    private var webPlayerCurrentTime: String {
        switch sourceMode {
        case .roon:
            return webTimeText(seconds: roonBridgeSnapshot.selectedZone?.nowPlaying?.seekPosition)
        case .spotify:
            return spotifyVisibleNowPlaying?.positionText ?? "0:00"
        case .filePlayback:
            return sourceMetadata == nil ? "0:00" : formattedCurrentTime()
        case .off, .aux, .testTone:
            return "0:00"
        }
    }

    private var webPlayerDuration: String {
        switch sourceMode {
        case .roon:
            return webTimeText(seconds: roonBridgeSnapshot.selectedZone?.nowPlaying?.length)
        case .spotify:
            return spotifyVisibleNowPlaying?.durationText ?? "0:00"
        case .filePlayback:
            return sourceMetadata == nil ? "0:00" : formattedDuration()
        case .off, .aux, .testTone:
            return "0:00"
        }
    }

    private var webPlayerProgress: Double {
        switch sourceMode {
        case .roon:
            guard let nowPlaying = roonBridgeSnapshot.selectedZone?.nowPlaying,
                  let position = nowPlaying.seekPosition,
                  let length = nowPlaying.length,
                  length > 0
            else { return 0 }
            return min(max(position / length, 0), 1)
        case .spotify:
            guard let position = spotifyVisibleNowPlaying?.positionMs,
                  let duration = spotifyVisibleNowPlaying?.durationMs,
                  duration > 0
            else { return 0 }
            return min(max(Double(position) / Double(duration), 0), 1)
        case .filePlayback:
            return min(max(scrubProgress, 0), 1)
        case .off, .aux, .testTone:
            return 0
        }
    }

    private func webTimeText(seconds: Double?) -> String {
        guard let seconds, seconds.isFinite, seconds > 0 else {
            return "0:00"
        }

        let totalSeconds = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private var webPublicSignalText: String {
        switch sourceMode {
        case .off:
            return "Orbisonic is idle."
        case .roon:
            if let signalPath = roonSignalPath {
                return signalPath.sourceChannelText == "-" ? signalPath.statusText : signalPath.sourceChannelText
            }
            return roonNowPlayingStatus.trimmedNilIfBlank ?? liveSignalStatus
        case .spotify:
            return spotifyVisibleNowPlaying == nil ? "Spotify Connect" : "Spotify Connect • stereo"
        case .aux:
            return liveMonitorState.isCapturing ? "Aux live input active" : "Aux live input idle"
        case .testTone:
            return testToneStatus
        case .filePlayback:
            guard let metadata = sourceMetadata else { return "No local file loaded." }
            return "\(webFormatText(for: metadata)) • \(metadata.channelCount) ch • \(metadata.sampleRateText)"
        }
    }

    private var webPlayerDetails: [OrbisonicWebState.Detail] {
        switch sourceMode {
        case .off:
            return [
                .init(title: "Engine", value: "Idle"),
                .init(title: "Output", value: "Silent")
            ]
        case .roon:
            var rows: [OrbisonicWebState.Detail] = []
            rows.append(.init(title: "Roon", value: roonBridgeSnapshot.isReadyForTransport ? "Ready" : "Unavailable"))
            if let nowPlaying = roonNowPlaying {
                rows.append(.init(title: "Format", value: nowPlaying.tidyFormatText))
            } else if !roonNowPlayingStatus.isEmpty {
                rows.append(.init(title: "Metadata", value: roonNowPlayingStatus))
            }
            if let signalPath = roonSignalPath {
                rows.append(.init(title: "Signal Path", value: signalPath.statusText == "-" ? signalPath.sourceChannelText : signalPath.statusText))
            } else {
                rows.append(.init(title: "Signal", value: liveSignalStatus))
            }
            return rows
        case .spotify:
            return [
                .init(title: "Format", value: "Spotify Connect 320 kbps"),
                .init(title: "Channels", value: "2"),
                .init(title: "Length", value: spotifyVisibleNowPlaying?.durationText ?? "-")
            ]
        case .aux:
            return [
                .init(title: "Signal", value: liveSignalStatus),
                .init(title: "Buffer", value: liveBufferStatus)
            ]
        case .filePlayback:
            if let metadata = sourceMetadata {
                var rows: [OrbisonicWebState.Detail] = [
                    .init(title: "Format", value: webFormatText(for: metadata)),
                    .init(title: "Channels", value: metadata.channelCount > 0 ? "\(metadata.channelCount)" : "-"),
                    .init(title: "Layout", value: metadata.layoutName),
                    .init(title: "Length", value: metadata.durationText)
                ]
                if let note = metadata.formatNote?.trimmedNilIfBlank {
                    rows.insert(.init(title: "Note", value: note), at: 1)
                }
                return rows
            }
            if let track = currentQueueTrack ?? currentLocalMusicTrack {
                return [
                    .init(title: "Format", value: track.url.pathExtension.uppercased().trimmedNilIfBlank ?? "Local file"),
                    .init(title: "Channels", value: track.channelCount > 0 ? "\(track.channelCount)" : "-"),
                    .init(title: "Layout", value: track.layoutName),
                    .init(title: "Length", value: track.durationText)
                ]
            }
            return []
        case .testTone:
            return [.init(title: "Diagnostics", value: activeDiagnosticText)]
        }
    }

    private var webPlayerControls: [String] {
        ["previous", "play", "pause", "stop", "next"]
    }

    private var webEnabledPlayerControls: [String] {
        webPlayerControls.filter { webPlayerControlIsEnabled($0) }
    }

    private func webPlayerControlIsEnabled(_ control: String) -> Bool {
        switch sourceMode {
        case .off, .aux:
            return false
        case .roon:
            switch control {
            case "previous": return canSendRoonTransport(.previous)
            case "play": return canSendRoonTransport(.play)
            case "pause": return canSendRoonTransport(.pause)
            case "next": return canSendRoonTransport(.next)
            case "stop": return canSendRoonTransport(.stop)
            default: return false
            }
        case .spotify:
            return false
        case .filePlayback:
            let hasPlayableLocalSource = sourceMetadata != nil || !localMusicTracks.isEmpty
            switch control {
            case "previous", "next":
                return !sessionQueue.isEmpty || !localMusicTracks.isEmpty
            case "play":
                return hasPlayableLocalSource && !isPlaying && !isLocalFileLoading
            case "pause":
                return isPlaying || isLocalFileLoading
            case "stop":
                return hasPlayableLocalSource || isLocalFileLoading
            default:
                return false
            }
        case .testTone:
            switch control {
            case "play": return !isTestTonePlaying
            case "stop": return isTestTonePlaying
            default: return false
            }
        }
    }

    private func webFormatText(for metadata: AudioSourceMetadata) -> String {
        if metadata.containerName.localizedCaseInsensitiveContains("Matroska"),
           !metadata.codecName.isEmpty {
            return metadata.codecName.localizedCaseInsensitiveContains("Matroska")
                ? metadata.codecName
                : "Matroska \(metadata.codecName)"
        }
        return metadata.codecName.isEmpty ? metadata.containerName : metadata.codecName
    }

    private func webMonitorOutputOptions() -> [OrbisonicWebState.Route] {
        [
            OrbisonicWebState.Route(id: "none", name: "not set", detail: "Output 1 Monitor disabled", isSelected: monitorOutputSelectionText == "not set", isSelectable: true),
            OrbisonicWebState.Route(id: "system", name: "System Default", detail: systemOutputNowText, isSelected: monitorOutputSelectionText.hasPrefix("System Default"), isSelectable: systemOutputRoute.isSelectableOutputTarget)
        ] + availableOutputRoutes.map { route in
            OrbisonicWebState.Route(
                id: route.uid,
                name: route.deviceName,
                detail: route.routeDetail,
                isSelected: route.uid == monitorOutputRoute.uid,
                isSelectable: route.isSelectableOutputTarget
            )
        }
    }

    private func webRendererOutputOptions() -> [OrbisonicWebState.Route] {
        [
            OrbisonicWebState.Route(id: "none", name: "not set", detail: "Output 2 Renderer not selected", isSelected: rendererOutputSelectionText == "not set", isSelectable: true)
        ] + availableOutputRoutes.map { route in
            OrbisonicWebState.Route(
                id: route.uid,
                name: route.deviceName,
                detail: route.routeDetail,
                isSelected: route.uid == rendererOutputRoute.uid,
                isSelectable: route.isSelectableOutputTarget
            )
        }
    }

    private func webTrackState(_ track: LocalMusicTrack) -> OrbisonicWebState.Track {
        OrbisonicWebState.Track(
            id: OrbisonicWebID.stableID(for: track.id),
            title: track.displayTitle,
            subtitle: track.displaySubtitle,
            album: track.displayAlbum,
            artist: track.displayArtist,
            channels: track.channelText,
            duration: track.durationText,
            isSelected: selectedLibraryTrackID == track.id,
            isCurrent: currentFileURL?.path == track.id,
            isPending: pendingSessionQueueIndex.flatMap { index in
                sessionQueue.indices.contains(index) ? sessionQueue[index].id : nil
            } == track.id
        )
    }

    private func webPlaylistState(_ playlist: LocalMusicPlaylist) -> OrbisonicWebState.Playlist {
        OrbisonicWebState.Playlist(
            id: OrbisonicWebID.stableID(for: playlist.id),
            name: playlist.name,
            fileName: playlist.fileName,
            trackCount: tracks(for: playlist).count,
            isSelected: selectedLocalMusicPlaylistID == playlist.id
        )
    }

    private func performWebPlayerCommand(_ payload: OrbisonicWebCommandPayload) throws {
        let stateBefore = debugPlaybackStateSnapshot()
        let sourceBefore = sourceMode
        let action = payload.action ?? ""
        var allowed = webPlayerControlIsEnabled(action)
        var commandError: String?
        defer {
            logTransportDebug(
                source: sourceBefore,
                command: action,
                allowed: allowed,
                handler: "performWebPlayerCommand",
                stateBefore: stateBefore,
                stateAfter: debugPlaybackStateSnapshot(),
                error: commandError
            )
        }

        do {
            switch action {
            case "play":
                switch sourceMode {
                case .roon:
                    playRoonTransport()
                case .filePlayback:
                    playLocalTransport()
                case .testTone:
                    playSelectedTestTone()
                case .off, .spotify, .aux:
                    allowed = false
                    throw OrbisonicWebCommandError.unsupportedCommand
                }
            case "pause":
                switch sourceMode {
                case .roon:
                    pauseRoonTransport()
                case .filePlayback:
                    pauseLocalTransport()
                case .off, .spotify, .aux, .testTone:
                    allowed = false
                    throw OrbisonicWebCommandError.unsupportedCommand
                }
            case "stop":
                switch sourceMode {
                case .roon:
                    stopRoonTransport()
                case .filePlayback:
                    stopLocalTransport()
                case .testTone:
                    stop()
                case .off, .spotify, .aux:
                    allowed = false
                    throw OrbisonicWebCommandError.unsupportedCommand
                }
            case "previous":
                switch sourceMode {
                case .roon:
                    playPreviousRoonTrack()
                case .filePlayback:
                    skipLocalTransport(offset: -1)
                case .off, .spotify, .aux, .testTone:
                    allowed = false
                    throw OrbisonicWebCommandError.unsupportedCommand
                }
            case "next":
                switch sourceMode {
                case .roon:
                    playNextRoonTrack()
                case .filePlayback:
                    skipLocalTransport(offset: 1)
                case .off, .spotify, .aux, .testTone:
                    allowed = false
                    throw OrbisonicWebCommandError.unsupportedCommand
                }
            default:
                allowed = false
                throw OrbisonicWebCommandError.unsupportedCommand
            }
        } catch {
            commandError = error.localizedDescription
            throw error
        }
    }

    private func performWebVolumeCommand(_ payload: OrbisonicWebCommandPayload) throws {
        let rawValue = payload.value ?? payload.query ?? payload.id ?? ""
        guard let volume = Double(rawValue) else {
            throw OrbisonicWebCommandError.invalidPayload
        }

        setSphereOutputVolume(volume)
    }

    private func performWebSourceCommand(_ payload: OrbisonicWebCommandPayload) throws {
        guard let value = payload.value,
              let mode = SourceMode(rawValue: value),
              SourceMode.musicInputs.contains(mode)
        else { throw OrbisonicWebCommandError.invalidPayload }
        selectSourceMode(mode, reason: "web source selected", requestedBy: "web")
    }

    private func performWebInputRouteCommand(_ payload: OrbisonicWebCommandPayload) throws {
        guard let id = payload.id ?? payload.value,
              let route = availableInputRoutes.first(where: { $0.uid == id })
        else { throw OrbisonicWebCommandError.invalidPayload }
        selectInputRoute(route)
    }

    private func performWebMonitorCommand(_ payload: OrbisonicWebCommandPayload) throws {
        switch payload.action {
        case "start":
            startSelectedLiveMonitor()
        case "mute":
            muteLiveMonitor()
        case "resume":
            resumeLiveMonitor()
        case "stop":
            stopSelectedLiveMonitor()
        default:
            throw OrbisonicWebCommandError.unsupportedCommand
        }
    }

    private func performWebMonitorOutputCommand(_ payload: OrbisonicWebCommandPayload) throws {
        let value = payload.value ?? payload.id ?? ""
        if value == "none" {
            selectNoMonitorOutput()
            return
        }
        if value == "system" {
            selectSystemMonitorOutput()
            return
        }
        guard let route = availableOutputRoutes.first(where: { $0.uid == value }) else {
            throw OrbisonicWebCommandError.invalidPayload
        }
        selectMonitorOutputRoute(route)
    }

    private func performWebRendererOutputCommand(_ payload: OrbisonicWebCommandPayload) throws {
        let value = payload.value ?? payload.id ?? ""
        if value == "none" {
            selectNoRendererOutput()
            return
        }
        guard let route = availableOutputRoutes.first(where: { $0.uid == value }) else {
            throw OrbisonicWebCommandError.invalidPayload
        }
        selectRendererOutputRoute(route)
    }

    private func performWebTrackCommand(_ payload: OrbisonicWebCommandPayload) throws {
        guard let id = payload.id,
              let track = localMusicTracks.first(where: { OrbisonicWebID.stableID(for: $0.id) == id })
        else { throw OrbisonicWebCommandError.invalidPayload }

        switch payload.action {
        case "select":
            selectLocalMusicTrack(track)
        case "play":
            playLocalMusicTrackNow(track)
        case "add":
            addLocalMusicTrackToQueue(track)
        default:
            throw OrbisonicWebCommandError.unsupportedCommand
        }
    }

    private func performWebPlaylistCommand(_ payload: OrbisonicWebCommandPayload) throws {
        guard let id = payload.id,
              let playlist = localMusicPlaylists.first(where: { OrbisonicWebID.stableID(for: $0.id) == id })
        else { throw OrbisonicWebCommandError.invalidPayload }

        switch payload.action {
        case "select":
            selectedLocalMusicPlaylistID = playlist.id
        case "play":
            playLocalMusicPlaylist(playlist, shuffle: payload.shuffle ?? false)
        case "add":
            addLocalMusicPlaylistToQueue(playlist, shuffle: payload.shuffle ?? false)
        default:
            throw OrbisonicWebCommandError.unsupportedCommand
        }
    }

    private func performWebQueueCommand(_ payload: OrbisonicWebCommandPayload) throws {
        switch payload.action {
        case "play":
            guard let index = payload.index else { throw OrbisonicWebCommandError.invalidPayload }
            playSessionQueueIndex(index)
        case "select":
            guard let index = payload.index else { throw OrbisonicWebCommandError.invalidPayload }
            selectSessionQueueIndex(index)
        case "up":
            guard let index = payload.index else { throw OrbisonicWebCommandError.invalidPayload }
            moveSessionQueueItemUp(index)
        case "down":
            guard let index = payload.index else { throw OrbisonicWebCommandError.invalidPayload }
            moveSessionQueueItemDown(index)
        case "remove":
            guard let index = payload.index else { throw OrbisonicWebCommandError.invalidPayload }
            removeSessionQueueItem(index)
        case "clear":
            clearSessionQueue()
        default:
            throw OrbisonicWebCommandError.unsupportedCommand
        }
    }

    private func performWebDiagnosticsCommand(_ payload: OrbisonicWebCommandPayload) throws {
        switch payload.action {
        case "monitorWalk":
            startMonitorChannelWalk()
        case "rendererWalk":
            startRendererOutputChannelWalk()
        case "testTone":
            if let index = payload.index {
                selectDiagnosticSpeakerChannel(index)
            }
            playSelectedDiagnosticSpeakerTone()
        case "stop":
            if isTestTonePlaying {
                stopTestTone()
            } else {
                stopDiagnosticsAndReturnToMusic()
            }
        default:
            throw OrbisonicWebCommandError.unsupportedCommand
        }
    }
}

private enum OrbisonicWebCommandError: LocalizedError {
    case invalidPayload
    case unsupportedCommand
    case webControlReadOnly

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            "The web command payload was invalid."
        case .unsupportedCommand:
            "That web command is not supported for the current source."
        case .webControlReadOnly:
            "That control is desktop-only. The web page is read-only for this panel."
        }
    }
}

private extension OrbisonicWebServer {
    static var publicPageHTML: String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <title>What's Playing on Sonic Sphere</title>
          <style>\(baseCSS)</style>
        </head>
        <body>
          <main class="shell public-shell">
            <section class="hero">
              <div>
                <p class="eyebrow">Sonic Sphere</p>
                <h1>What's Playing on Sonic Sphere</h1>
              </div>
              <div id="statusChip" class="chip">CONNECTING</div>
            </section>
            <section class="now-card">
              <p class="eyebrow" id="sourceText">Source</p>
              <h2 id="titleText">Loading...</h2>
              <p id="subtitleText" class="subtitle">Waiting for Orbisonic.</p>
              <div class="progress"><span id="progressBar"></span></div>
              <div id="details" class="details"></div>
            </section>
            <section class="grid two">
              <article class="panel">
                <h3>Signal</h3>
                <p id="signalText" class="large-line">-</p>
              </article>
              <article class="panel">
                <h3>Output 2 Renderer</h3>
                <p id="rendererText" class="large-line">-</p>
              </article>
            </section>
          </main>
          <script>\(publicPageJS)</script>
        </body>
        </html>
        """
    }

    static let baseCSS = """
    :root{color-scheme:dark;--bg:#071014;--panel:#0d181de6;--soft:#ffffff12;--line:#d9fbff24;--text:#effcff;--muted:#9fb9bd;--cyan:#5eead4;--blue:#60a5fa;--green:#22c55e;--amber:#facc15;--red:#fb7185}
    *{box-sizing:border-box}body{margin:0;min-height:100vh;background:radial-gradient(circle at 18% 0%,#12333a 0,#071014 36%,#02070a 100%);color:var(--text);font:14px/1.45 -apple-system,BlinkMacSystemFont,"SF Pro Display","Segoe UI",sans-serif}
    button,input,select{font:inherit}button{cursor:pointer}button:disabled{cursor:not-allowed}.shell{width:min(1180px,calc(100vw - 28px));margin:0 auto;padding:22px 0 34px}.public-shell{width:min(860px,calc(100vw - 28px));padding-top:42px}
    .hero{display:flex;align-items:center;justify-content:space-between;gap:18px;margin-bottom:16px}.eyebrow{margin:0 0 5px;color:var(--cyan);text-transform:uppercase;font-size:11px;font-weight:800;letter-spacing:.08em}h1{margin:0;font-size:28px;line-height:1.05}h2{margin:0;font-size:34px;line-height:1.05}h3{margin:0 0 10px;font-size:15px}
    .chip{border:1px solid var(--line);border-radius:7px;background:var(--soft);color:var(--muted);font-weight:900;font-size:11px;padding:7px 10px}.chip.on{background:var(--green);border-color:var(--green);color:var(--bg)}
    .tabs{display:grid;grid-template-columns:repeat(6,1fr);gap:4px;padding:4px;border:1px solid var(--line);border-radius:8px;background:#050c0fb3;margin-bottom:16px}.tabs button,.btn,.icon-btn{border:1px solid var(--line);border-radius:7px;background:#ffffff0b;color:var(--muted);font-weight:800;min-height:34px;padding:7px 10px}.tabs button.active,.btn.active{border-color:#5eead48c;background:#5eead424;color:var(--text)}.btn:disabled,.icon-btn:disabled{opacity:.46;background:#ffffff07;color:#789095}
    .tab-panel{display:none}.tab-panel.active{display:block}.grid{display:grid;gap:14px}.two{grid-template-columns:repeat(2,minmax(0,1fr))}.three{grid-template-columns:repeat(3,minmax(0,1fr))}
    .panel,.now-card{border:1px solid var(--line);border-radius:8px;background:var(--panel);box-shadow:0 18px 34px #0000005a;padding:16px}.now-card{padding:20px;margin-bottom:14px}.subtitle{color:var(--muted);font-weight:700;margin:8px 0 16px}.large-line{font-size:16px;font-weight:800;color:var(--text);margin:0}
    .progress{height:8px;border:1px solid var(--line);border-radius:99px;background:#ffffff0a;overflow:hidden}.progress span{display:block;height:100%;width:0;background:linear-gradient(90deg,var(--cyan),var(--blue))}.progress-time{display:flex;justify-content:space-between;color:var(--muted);font-size:12px;font-weight:800;font-variant-numeric:tabular-nums;margin-top:6px}
    .details{display:grid;gap:8px;margin-top:14px}.row{display:grid;grid-template-columns:120px minmax(0,1fr);gap:10px;align-items:start}.row b{color:var(--muted);text-transform:uppercase;font-size:11px}.row span{font-weight:750;overflow-wrap:anywhere}
    .source-layout{display:grid;grid-template-columns:150px minmax(0,1fr);gap:12px}.source-list{display:grid;gap:8px}.source-btn{border:1px solid var(--line);border-radius:7px;background:#ffffff0a;color:var(--text);padding:10px 11px;text-align:left;min-height:40px}.source-btn strong{display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-size:12px}.source-btn.active{border-color:#5eead48c;background:#5eead41b;box-shadow:inset 3px 0 0 var(--cyan)}.source-btn.active.active{box-shadow:inset 3px 0 0 var(--green)}.source-btn.active.waiting{box-shadow:inset 3px 0 0 var(--amber)}.source-btn.active.failed{box-shadow:inset 3px 0 0 var(--red)}.source-status{min-height:168px;border:1px solid var(--line);border-radius:8px;background:#ffffff08;padding:14px}.source-status-head{display:flex;justify-content:space-between;gap:12px;align-items:flex-start}.source-status h3{margin:3px 0 0;font-size:16px}.severity-badge{border:1px solid var(--line);border-radius:7px;padding:5px 8px;color:var(--muted);font-size:11px;font-weight:900;white-space:nowrap}.severity-badge.active{border-color:#22c55e8c;color:var(--green)}.severity-badge.ready{border-color:#60a5fa70;color:#b8d7ff}.severity-badge.waiting{border-color:#facc1577;color:var(--amber)}.severity-badge.failed{border-color:#fb718577;color:var(--red)}.severity-badge.idle{color:var(--muted)}
    .player-head{display:grid;grid-template-columns:82px minmax(0,1fr);gap:14px;align-items:center}.artwork{width:82px;height:82px;border-radius:8px;border:1px solid var(--line);object-fit:cover;background:#ffffff0b}.slider-row{display:grid;grid-template-columns:70px minmax(0,1fr) 42px;gap:10px;align-items:center;margin-top:12px}.slider-row input{accent-color:var(--cyan);width:100%}.slider-row code{font-weight:900;color:var(--cyan);font-size:13px}.error{border-color:#fb718577;background:#fb718517;color:#ffd5dc}
    .controls{display:flex;gap:8px;flex-wrap:wrap;margin-top:12px}.transport-note{margin:8px 0 0;color:var(--muted);font-size:12px;font-weight:800}.list{display:grid;gap:7px;max-height:470px;overflow:auto;padding-right:4px}.item{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:10px;align-items:center;border:1px solid transparent;border-radius:8px;background:#ffffff09;padding:9px 10px}.item.current,.item.selected{border-color:#5eead473;background:#5eead41a}.item.pending{border-color:#facc1573;background:#facc1517}.item-title{font-weight:850;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.item-sub{color:var(--muted);font-size:12px;font-weight:650;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.item-actions{display:flex;gap:5px;align-items:center}
    .form-row{display:flex;gap:8px;align-items:center;margin-bottom:10px}.form-row input,.form-row select{min-height:34px;border:1px solid var(--line);border-radius:7px;background:#00000029;color:var(--text);padding:7px 10px}.form-row input{flex:1}.form-row select{min-width:170px}.url-row{display:grid;grid-template-columns:110px minmax(0,1fr) 42px;gap:10px;align-items:center;margin:8px 0}.url-row code{font-size:12px;color:var(--text);background:#0000002e;border:1px solid var(--line);border-radius:7px;padding:8px;overflow:auto}.muted{color:var(--muted)}@media(max-width:760px){.hero{align-items:flex-start;flex-direction:column}.tabs{grid-template-columns:repeat(2,1fr)}.two,.three,.source-layout{grid-template-columns:1fr}.row,.url-row{grid-template-columns:1fr}h2{font-size:27px}}
    """

    static let publicPageJS = """
    const $=id=>document.getElementById(id);
    function esc(v){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
    async function load(){
      try{
        const res=await fetch('/Orbisonic/api/public-state',{cache:'no-store'});
        const s=await res.json();
        $('statusChip').textContent=s.player.status;$('statusChip').classList.toggle('on',s.player.isPlaying);
        $('sourceText').textContent=s.player.source;$('titleText').textContent=s.player.title;$('subtitleText').textContent=s.player.subtitle;
        $('progressBar').style.width=((s.player.progress||0)*100).toFixed(1)+'%';
        $('details').innerHTML=s.player.details.map(r=>`<div class="row"><b>${esc(r.title)}</b><span>${esc(r.value)}</span></div>`).join('');
        $('signalText').textContent=s.input.status;$('rendererText').textContent=s.routing.rendererScene;
      }catch(e){$('statusChip').textContent='OFFLINE';$('statusChip').classList.remove('on')}
    }
    load();setInterval(load,1500);
    """

}
