import Foundation

struct DebugTimingContext: Sendable {
    let id: String
    let startedAt: Date
    let startedUptimeNanoseconds: UInt64
    let enabled: Bool
    let sourceModeLabel: String?

    static let disabled = DebugTimingContext(
        id: "disabled",
        startedAt: Date(timeIntervalSince1970: 0),
        startedUptimeNanoseconds: 0,
        enabled: false,
        sourceModeLabel: nil
    )

    var elapsedMilliseconds: Double? {
        guard enabled else { return nil }
        let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - startedUptimeNanoseconds
        return Double(elapsedNanoseconds) / 1_000_000.0
    }

    func log(
        _ event: String,
        sourceMode: SourceMode? = nil,
        sessionQueueIndex: Int? = nil,
        selectedSessionQueueIndex: Int? = nil,
        pendingSessionQueueIndex: Int? = nil,
        targetQueueIndex: Int? = nil,
        trackTitle: String? = nil,
        fileURL: URL? = nil,
        extra: [String] = []
    ) {
        DebugTimingLog.log(
            context: self,
            event: event,
            sourceMode: sourceMode,
            sessionQueueIndex: sessionQueueIndex,
            selectedSessionQueueIndex: selectedSessionQueueIndex,
            pendingSessionQueueIndex: pendingSessionQueueIndex,
            targetQueueIndex: targetQueueIndex,
            trackTitle: trackTitle,
            fileURL: fileURL,
            extra: extra
        )
    }
}

enum DebugTimingLog {
    #if DEBUG
    private static let lock = NSLock()
    private static var sequence = 0
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = .current
        return formatter
    }()
    #endif

    static func makeCommand(prefix: String, sourceMode: SourceMode? = nil) -> DebugTimingContext {
        #if DEBUG
        lock.lock()
        sequence += 1
        let next = sequence
        lock.unlock()

        return DebugTimingContext(
            id: "\(prefix)-\(String(format: "%04d", next))",
            startedAt: Date(),
            startedUptimeNanoseconds: DispatchTime.now().uptimeNanoseconds,
            enabled: true,
            sourceModeLabel: sourceMode?.rawValue
        )
        #else
        return .disabled
        #endif
    }

    static func log(
        context: DebugTimingContext?,
        event: String,
        sourceMode: SourceMode? = nil,
        sessionQueueIndex: Int? = nil,
        selectedSessionQueueIndex: Int? = nil,
        pendingSessionQueueIndex: Int? = nil,
        targetQueueIndex: Int? = nil,
        trackTitle: String? = nil,
        fileURL: URL? = nil,
        extra: [String] = []
    ) {
        #if DEBUG
        guard let context, context.enabled else { return }

        let elapsed = context.elapsedMilliseconds.map { String(format: "%.1f", $0) } ?? "n/a"
        var parts = [
            "id=\(context.id)",
            "event=\(quoted(event))",
            "timestamp=\(timestamp(Date()))",
            "elapsedMs=\(elapsed)",
            "mainThread=\(Thread.isMainThread)"
        ]

        if let source = sourceMode?.rawValue ?? context.sourceModeLabel {
            parts.append("source=\(quoted(source))")
        }
        if let sessionQueueIndex {
            parts.append("sessionQueueIndex=\(sessionQueueIndex)")
        }
        if let selectedSessionQueueIndex {
            parts.append("selectedSessionQueueIndex=\(selectedSessionQueueIndex)")
        }
        if let pendingSessionQueueIndex {
            parts.append("pendingSessionQueueIndex=\(pendingSessionQueueIndex)")
        }
        if let targetQueueIndex {
            parts.append("targetQueueIndex=\(targetQueueIndex)")
        }
        if let trackTitle, !trackTitle.isEmpty {
            parts.append("track=\(quoted(trackTitle))")
        }
        if let fileURL {
            parts.append("file=\(quoted(redactedPath(fileURL.path)))")
            if !fileURL.pathExtension.isEmpty {
                parts.append("extension=\(quoted(fileURL.pathExtension.lowercased()))")
            }
        }

        parts.append(contentsOf: extra)
        AppLogger.shared.debug(category: "timing", parts.joined(separator: " "))
        #endif
    }

    #if DEBUG
    private static func timestamp(_ date: Date) -> String {
        lock.lock()
        defer { lock.unlock() }
        return formatter.string(from: date)
    }

    private static func quoted(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "'").replacingOccurrences(of: "\n", with: " "))\""
    }

    private static func redactedPath(_ value: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard !home.isEmpty else { return value }
        return value.replacingOccurrences(of: home, with: "~")
    }
    #endif
}
