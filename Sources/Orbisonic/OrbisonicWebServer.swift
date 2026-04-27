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
    let controlURL: String
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

    struct Input: Encodable {
        let source: String
        let selectedDevice: String
        let status: String
        let monitorState: String
        let availableSources: [String]
        let availableInputs: [Route]
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
            publicURL: "\(baseURL)/",
            controlURL: "\(baseURL)/control/#token=\(controlToken)"
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

        if request.method == "GET", isControlPagePath(request.path) {
            send(status: 200, contentType: "text/html; charset=utf-8", body: Self.controlPageHTML, on: connection)
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

    private func isControlPagePath(_ path: String) -> Bool {
        path == "\(OrbisonicWebConstants.basePath)/control" ||
            path == "\(OrbisonicWebConstants.basePath)/control/"
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
                controlPage: controlEnabled ? self.webControlPageURL : nil
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
            isPlaying: isPlaying || isTestTonePlaying || liveMonitorState.isCapturing,
            artworkURL: controlEnabled ? webArtworkPath : nil,
            volume: sphereOutputVolumeValue,
            currentTime: formattedCurrentTime(),
            duration: formattedDuration(),
            progress: min(max(scrubProgress, 0), 1),
            details: webPlayerDetails,
            controls: webPlayerControls
        )
    }

    fileprivate var webCurrentArtworkURL: URL? {
        switch sourceMode {
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
            monitorState: liveMonitorState.statusLabel,
            availableSources: SourceMode.musicInputs.map(\.rawValue),
            availableInputs: []
        )
    }

    private func makeWebPublicInputState() -> OrbisonicWebState.Input {
        OrbisonicWebState.Input(
            source: sourceMode.rawValue,
            selectedDevice: "",
            status: webPublicSignalText,
            monitorState: webPlayerStatus,
            availableSources: [],
            availableInputs: []
        )
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
        if sourceMode == .roon, let title = roonTransportTitleText, !title.isEmpty {
            return title
        }
        if let nowPlaying = roonNowPlaying, sourceMode == .roon {
            return nowPlaying.title
        }
        if sourceMode == .testTone {
            return selectedTestTonePoint.rawValue
        }
        if sourceMode == .aux {
            return "Aux Cable"
        }
        if sourceMode == .spotify {
            return spotifyNowPlaying?.displayTitle ?? "Spotify"
        }
        if sourceMode == .filePlayback, let track = selectedLocalMusicTrack {
            return track.displayTitle
        }
        if let metadata = sourceMetadata {
            return metadata.title?.trimmedNilIfBlank ?? metadata.fileName
        }
        return "No source loaded"
    }

    private var webNowPlayingSubtitle: String {
        if sourceMode == .roon, let subtitle = roonTransportSubtitleText, !subtitle.isEmpty {
            return subtitle
        }
        if let nowPlaying = roonNowPlaying, sourceMode == .roon {
            return nowPlaying.artist.isEmpty ? "Roon" : nowPlaying.artist
        }
        if sourceMode == .testTone {
            return testToneStatus
        }
        if sourceMode == .aux {
            return "Controlled in the source app."
        }
        if sourceMode == .spotify {
            return spotifyNowPlaying?.artistText ?? "Controlled from Spotify Connect."
        }
        if sourceMode == .filePlayback, let track = selectedLocalMusicTrack {
            return track.displaySubtitle
        }
        if let metadata = sourceMetadata {
            let albumArtist = [metadata.album?.trimmedNilIfBlank, metadata.artist?.trimmedNilIfBlank].compactMap { $0 }.joined(separator: " - ")
            return albumArtist.isEmpty ? "\(metadata.layoutName) • \(metadata.channelCount) ch • \(metadata.sampleRateText)" : albumArtist
        }
        return "Choose Roon, Spotify, Aux Cable, or Local Files."
    }

    private var webPlayerStatus: String {
        if sourceMode.isLiveInput {
            return liveMonitorState.statusLabel
        }
        if sourceMode == .testTone {
            return isTestTonePlaying ? "TONE" : "READY"
        }
        return isPlaying ? "PLAYING" : "READY"
    }

    private var webPublicSignalText: String {
        switch sourceMode {
        case .roon:
            if let signalPath = roonSignalPath {
                return signalPath.sourceChannelText == "-" ? signalPath.statusText : signalPath.sourceChannelText
            }
            return roonNowPlayingStatus.trimmedNilIfBlank ?? liveSignalStatus
        case .spotify:
            return spotifyNowPlaying == nil ? "Spotify Connect" : "Spotify Connect • stereo"
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
        case .roon:
            var rows: [OrbisonicWebState.Detail] = []
            if let zoneName = roonBridgeSnapshot.selectedZone?.displayName, !zoneName.isEmpty {
                rows.append(.init(title: "Zone", value: zoneName))
            } else {
                rows.append(.init(title: "Status", value: roonTransportStatusText))
            }
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
                .init(title: "Length", value: spotifyNowPlaying?.durationText ?? "-")
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
            if let track = currentQueueTrack ?? currentLocalMusicTrack ?? selectedLocalMusicTrack {
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
        switch sourceMode {
        case .roon:
            return ["previous", "playPause", "stop", "next"]
        case .spotify:
            return ["previous", "playPause", "next", "seekBackward", "seekForward"]
        case .filePlayback:
            return ["previous", "playPause", "stop", "next"]
        case .testTone:
            return ["playPause", "stop"]
        case .aux:
            return []
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
            OrbisonicWebState.Route(id: "none", name: "not set", detail: "Local monitor disabled", isSelected: monitorOutputSelectionText == "not set", isSelectable: true),
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
            OrbisonicWebState.Route(id: "none", name: "not set", detail: "Explicit renderer not selected", isSelected: rendererOutputSelectionText == "not set", isSelectable: true)
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
            isSelected: selectedLocalMusicTrackID == track.id,
            isCurrent: currentFileURL?.path == track.id
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
        switch payload.action {
        case "playPause":
            switch sourceMode {
            case .roon:
                toggleRoonTransport()
            case .spotify:
                toggleSpotifyTransport()
            case .filePlayback:
                toggleLocalMusicPlayback()
            case .testTone:
                togglePlayback()
            case .aux:
                throw OrbisonicWebCommandError.unsupportedCommand
            }
        case "stop":
            switch sourceMode {
            case .roon:
                stopRoonTransport()
            case .filePlayback, .testTone:
                stop()
            case .spotify, .aux:
                stopSelectedLiveMonitor()
            }
        case "previous":
            switch sourceMode {
            case .roon:
                playPreviousRoonTrack()
            case .spotify:
                playPreviousSpotifyTrack()
            case .filePlayback:
                playPreviousLocalMusicTrack()
            case .aux, .testTone:
                throw OrbisonicWebCommandError.unsupportedCommand
            }
        case "next":
            switch sourceMode {
            case .roon:
                playNextRoonTrack()
            case .spotify:
                playNextSpotifyTrack()
            case .filePlayback:
                playNextLocalMusicTrack()
            case .aux, .testTone:
                throw OrbisonicWebCommandError.unsupportedCommand
            }
        case "seekBackward":
            if sourceMode == .spotify {
                seekSpotifyBy(seconds: -(payload.seconds ?? 15))
            } else {
                throw OrbisonicWebCommandError.unsupportedCommand
            }
        case "seekForward":
            if sourceMode == .spotify {
                seekSpotifyBy(seconds: payload.seconds ?? 15)
            } else {
                throw OrbisonicWebCommandError.unsupportedCommand
            }
        default:
            throw OrbisonicWebCommandError.unsupportedCommand
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
              let mode = SourceMode(rawValue: value)
        else { throw OrbisonicWebCommandError.invalidPayload }
        selectSourceMode(mode)
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
                <h3>Renderer</h3>
                <p id="rendererText" class="large-line">-</p>
              </article>
            </section>
          </main>
          <script>\(publicPageJS)</script>
        </body>
        </html>
        """
    }

    static var controlPageHTML: String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <title>Orbisonic Sonic Sphere Control</title>
          <style>\(baseCSS)</style>
        </head>
        <body>
          <main class="shell">
            <section class="hero">
              <div>
                <p class="eyebrow">Orbisonic</p>
                <h1>Sonic Sphere Control</h1>
              </div>
              <div id="statusChip" class="chip">CONNECTING</div>
            </section>
            <nav class="tabs">
              <button data-tab="player" class="active">Player</button>
              <button data-tab="input">Input</button>
              <button data-tab="routing">Routing</button>
              <button data-tab="local">Local Music</button>
              <button data-tab="diagnostics">Diagnostics</button>
              <button data-tab="status">Status</button>
            </nav>
            <section id="tab-player" class="tab-panel active"></section>
            <section id="tab-input" class="tab-panel"></section>
            <section id="tab-routing" class="tab-panel"></section>
            <section id="tab-local" class="tab-panel"></section>
            <section id="tab-diagnostics" class="tab-panel"></section>
            <section id="tab-status" class="tab-panel"></section>
          </main>
          <script>\(controlPageJS)</script>
        </body>
        </html>
        """
    }

    static let baseCSS = """
    :root{color-scheme:dark;--bg:#071014;--panel:#0d181de6;--soft:#ffffff12;--line:#d9fbff24;--text:#effcff;--muted:#9fb9bd;--cyan:#5eead4;--blue:#60a5fa;--amber:#facc15;--red:#fb7185}
    *{box-sizing:border-box}body{margin:0;min-height:100vh;background:radial-gradient(circle at 18% 0%,#12333a 0,#071014 36%,#02070a 100%);color:var(--text);font:14px/1.45 -apple-system,BlinkMacSystemFont,"SF Pro Display","Segoe UI",sans-serif}
    button,input,select{font:inherit}button{cursor:pointer}.shell{width:min(1180px,calc(100vw - 28px));margin:0 auto;padding:22px 0 34px}.public-shell{width:min(860px,calc(100vw - 28px));padding-top:42px}
    .hero{display:flex;align-items:center;justify-content:space-between;gap:18px;margin-bottom:16px}.eyebrow{margin:0 0 5px;color:var(--cyan);text-transform:uppercase;font-size:11px;font-weight:800;letter-spacing:.08em}h1{margin:0;font-size:28px;line-height:1.05}h2{margin:0;font-size:34px;line-height:1.05}h3{margin:0 0 10px;font-size:15px}
    .chip{border:1px solid var(--line);border-radius:7px;background:var(--soft);color:var(--muted);font-weight:900;font-size:11px;padding:7px 10px}.chip.on{background:var(--cyan);border-color:var(--cyan);color:var(--bg)}
    .tabs{display:grid;grid-template-columns:repeat(6,1fr);gap:4px;padding:4px;border:1px solid var(--line);border-radius:8px;background:#050c0fb3;margin-bottom:16px}.tabs button,.btn,.icon-btn{border:1px solid var(--line);border-radius:7px;background:#ffffff0b;color:var(--muted);font-weight:800;min-height:34px;padding:7px 10px}.tabs button.active,.btn.active{border-color:#5eead48c;background:#5eead424;color:var(--text)}
    .tab-panel{display:none}.tab-panel.active{display:block}.grid{display:grid;gap:14px}.two{grid-template-columns:repeat(2,minmax(0,1fr))}.three{grid-template-columns:repeat(3,minmax(0,1fr))}
    .panel,.now-card{border:1px solid var(--line);border-radius:8px;background:var(--panel);box-shadow:0 18px 34px #0000005a;padding:16px}.now-card{padding:20px;margin-bottom:14px}.subtitle{color:var(--muted);font-weight:700;margin:8px 0 16px}.large-line{font-size:16px;font-weight:800;color:var(--text);margin:0}
    .progress{height:8px;border:1px solid var(--line);border-radius:99px;background:#ffffff0a;overflow:hidden}.progress span{display:block;height:100%;width:0;background:linear-gradient(90deg,var(--cyan),var(--blue))}
    .details{display:grid;gap:8px;margin-top:14px}.row{display:grid;grid-template-columns:120px minmax(0,1fr);gap:10px;align-items:start}.row b{color:var(--muted);text-transform:uppercase;font-size:11px}.row span{font-weight:750;overflow-wrap:anywhere}
    .player-head{display:grid;grid-template-columns:82px minmax(0,1fr);gap:14px;align-items:center}.artwork{width:82px;height:82px;border-radius:8px;border:1px solid var(--line);object-fit:cover;background:#ffffff0b}.slider-row{display:grid;grid-template-columns:70px minmax(0,1fr) 42px;gap:10px;align-items:center;margin-top:12px}.slider-row input{accent-color:var(--cyan);width:100%}.slider-row code{font-weight:900;color:var(--cyan);font-size:13px}.error{border-color:#fb718577;background:#fb718517;color:#ffd5dc}
    .controls{display:flex;gap:8px;flex-wrap:wrap;margin-top:12px}.list{display:grid;gap:7px;max-height:470px;overflow:auto;padding-right:4px}.item{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:10px;align-items:center;border:1px solid transparent;border-radius:8px;background:#ffffff09;padding:9px 10px}.item.current,.item.selected{border-color:#5eead473;background:#5eead41a}.item-title{font-weight:850;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.item-sub{color:var(--muted);font-size:12px;font-weight:650;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.item-actions{display:flex;gap:5px;align-items:center}
    .form-row{display:flex;gap:8px;align-items:center;margin-bottom:10px}.form-row input,.form-row select{min-height:34px;border:1px solid var(--line);border-radius:7px;background:#00000029;color:var(--text);padding:7px 10px}.form-row input{flex:1}.form-row select{min-width:170px}.url-row{display:grid;grid-template-columns:110px minmax(0,1fr) 42px;gap:10px;align-items:center;margin:8px 0}.url-row code{font-size:12px;color:var(--text);background:#0000002e;border:1px solid var(--line);border-radius:7px;padding:8px;overflow:auto}.muted{color:var(--muted)}@media(max-width:760px){.hero{align-items:flex-start;flex-direction:column}.tabs{grid-template-columns:repeat(2,1fr)}.two,.three{grid-template-columns:1fr}.row,.url-row{grid-template-columns:1fr}h2{font-size:27px}}
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

    static let controlPageJS = """
    const tokenParams=new URLSearchParams(location.hash.replace(/^#/,''));
    const token=tokenParams.get('token')||localStorage.getItem('orbisonic-token')||'';
    if(token) localStorage.setItem('orbisonic-token',token);
    const $=id=>document.getElementById(id);
    let state=null;
    function esc(v){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
    function post(path,payload={}){return fetch(path,{method:'POST',headers:{'Content-Type':'application/json','X-Orbisonic-Token':token},body:JSON.stringify(payload)}).then(r=>r.json()).then(j=>{if(!j.ok)throw new Error(j.message);state=j.state;render();return j})}
    async function load(){try{const r=await fetch('/Orbisonic/api/state',{headers:{'X-Orbisonic-Token':token},cache:'no-store'});const j=await r.json();if(j.ok===false)throw new Error(j.message);state=j;render()}catch(e){$('statusChip').textContent=token?'OFFLINE':'TOKEN NEEDED';$('tab-status').innerHTML=`<article class="panel"><h3>Status</h3><p class="muted">${esc(e.message||e)}</p></article>`}}
    function button(label,action,active=false){return `<button class="btn ${active?'active':''}" onclick="${action}">${label}</button>`}
    function rows(items){return (items||[]).map(r=>`<div class="row"><b>${esc(r.title)}</b><span>${esc(r.value)}</span></div>`).join('')}
    function renderPlayer(){const p=state.player;const art=p.artworkURL?`<img class="artwork" src="${esc(p.artworkURL)}" alt="">`:`<div class="artwork"></div>`;$('tab-player').innerHTML=`<article class="now-card"><div class="player-head">${art}<div><p class="eyebrow">${esc(p.source)}</p><h2>${esc(p.title)}</h2><p class="subtitle">${esc(p.subtitle)}</p></div></div><div class="progress"><span style="width:${(p.progress*100).toFixed(1)}%"></span></div><div class="controls">${p.controls.map(c=>button(labelFor(c),`post('/Orbisonic/api/player/control',{action:'${c}'})`,c==='playPause'&&p.isPlaying)).join('')}</div><div class="slider-row"><b>Volume</b><input type="range" min="0" max="100" value="${p.volume}" oninput="document.getElementById('volText').textContent=this.value" onchange="post('/Orbisonic/api/player/volume',{value:this.value})"><code id="volText">${p.volume}</code></div><div class="details">${rows(p.details)}</div></article>`}
    function labelFor(c){return {previous:'Back',playPause:'Play / Pause',stop:'Stop',next:'Next',seekBackward:'-15s',seekForward:'+15s'}[c]||c}
    function renderInput(){const i=state.input;$('tab-input').innerHTML=`<article class="panel"><h3>Source</h3><div class="controls">${i.availableSources.map(s=>button(esc(s),`post('/Orbisonic/api/input/source',{value:'${esc(s)}'})`,s===i.source)).join('')}</div><div class="details"><div class="row"><b>Selected</b><span>${esc(i.source)}</span></div><div class="row"><b>Status</b><span>${esc(i.status)}</span></div></div></article>`}
    function renderRouting(){const r=state.routing;$('tab-routing').innerHTML=`<article class="panel"><h3>Signal Flow</h3><div class="details"><div class="row"><b>Source</b><span>${esc(r.source)}</span></div><div class="row"><b>Incoming</b><span>${esc(r.incoming)}</span></div><div class="row"><b>Monitor</b><span>${esc(r.monitorOutput)} • ${esc(r.monitorStatus)}</span></div><div class="row"><b>Renderer</b><span>${esc(r.rendererOutput)} • ${esc(r.rendererStatus)}</span></div><div class="row"><b>Matrix</b><span>${esc(r.rendererScene)}</span></div></div></article>`}
    function renderLocal(){const l=state.localMusic;if(!l){return}$('tab-local').innerHTML=`<div class="form-row"><input id="musicSearch" value="${esc(l.search)}" placeholder="Search song, artist, album"><select id="musicSort"><option ${l.sort==='Name'?'selected':''}>Name</option><option ${l.sort==='Artist'?'selected':''}>Artist</option><option ${l.sort==='Album'?'selected':''}>Album</option></select><button class="btn active" onclick="post('/Orbisonic/api/local-music/search',{query:document.getElementById('musicSearch').value,sort:document.getElementById('musicSort').value})">Apply</button></div><div class="grid two"><article class="panel"><h3>Tracks</h3><p class="muted">${esc(l.count)}</p><div class="list">${l.tracks.map(t=>`<div class="item ${t.isCurrent?'current':t.isSelected?'selected':''}"><div><div class="item-title">${esc(t.title)}</div><div class="item-sub">${esc(t.subtitle)} • ${esc(t.channels)} • ${esc(t.duration)}</div></div></div>`).join('')}</div></article><article class="panel"><h3>Playlists</h3><div class="list">${l.playlists.map(p=>`<div class="item ${p.isSelected?'selected':''}"><div><div class="item-title">${esc(p.name)}</div><div class="item-sub">${esc(p.fileName)} • ${p.trackCount} tracks</div></div></div>`).join('')}</div></article></div>`}
    function renderDiagnostics(){const d=state.diagnostics;$('tab-diagnostics').innerHTML=`<div class="grid three"><article class="panel"><h3>Monitor Channel Walk</h3><p class="large-line">${d.monitorChannelCount} ch</p><div class="controls">${button('Walk Monitor',`post('/Orbisonic/api/diagnostics',{action:'monitorWalk'})`,d.isRunning)}${button('Stop',`post('/Orbisonic/api/diagnostics',{action:'stop'})`)}</div></article><article class="panel"><h3>Renderer Channel Walk</h3><p class="large-line">${d.rendererChannelCount} ch</p><div class="controls">${button('Walk Renderer',`post('/Orbisonic/api/diagnostics',{action:'rendererWalk'})`,d.isRunning)}${button('Stop',`post('/Orbisonic/api/diagnostics',{action:'stop'})`)}</div></article><article class="panel"><h3>Test Tone</h3><div class="form-row"><input id="diagChannel" type="number" min="1" max="${d.rendererChannelCount}" value="${d.selectedChannel||1}"></div><div class="controls">${button('Play Tone',`post('/Orbisonic/api/diagnostics',{action:'testTone',index:Number(document.getElementById('diagChannel').value)||1})`,d.isRunning)}${button('Stop',`post('/Orbisonic/api/diagnostics',{action:'stop'})`)}</div></article></div><article class="panel" style="margin-top:14px"><h3>Status</h3><div class="details"><div class="row"><b>Active</b><span>${esc(d.isTransitioning?'Settling audio handoff':d.active)}</span></div><div class="row"><b>Tone</b><span>${esc(d.toneStatus)}</span></div></div></article>`}
    function renderStatus(){const u=state.urls;const err=state.build.lastError?`<article class="panel error"><h3>Desktop Error</h3><p>${esc(state.build.lastError)}</p></article>`:'';$('tab-status').innerHTML=`${err}<article class="panel"><h3>Web Pages</h3><div class="url-row"><b>Public</b><code>${esc(u.publicPage)}</code><button class="icon-btn" onclick="navigator.clipboard.writeText('${esc(u.publicPage)}')">Copy</button></div><div class="url-row"><b>Control</b><code>${esc(u.controlPage||'')}</code><button class="icon-btn" onclick="navigator.clipboard.writeText('${esc(u.controlPage||'')}')">Copy</button></div><div class="details"><div class="row"><b>Server</b><span>${esc(state.build.webServer)}</span></div><div class="row"><b>IP</b><span>${esc(state.build.machineIP)}</span></div><div class="row"><b>Build</b><span>${esc(state.build.appVersion)} (${esc(state.build.buildNumber)})</span></div><div class="row"><b>App</b><span>${esc(state.build.appStatus)}</span></div></div></article>`}
    function render(){if(!state)return;$('statusChip').textContent=state.player.status;$('statusChip').classList.toggle('on',state.player.isPlaying);renderPlayer();renderInput();renderRouting();renderLocal();renderDiagnostics();renderStatus()}
    document.querySelectorAll('.tabs button').forEach(b=>b.onclick=()=>{document.querySelectorAll('.tabs button').forEach(x=>x.classList.remove('active'));document.querySelectorAll('.tab-panel').forEach(x=>x.classList.remove('active'));b.classList.add('active');document.getElementById('tab-'+b.dataset.tab).classList.add('active')});
    load();setInterval(load,1500);
    """
}
