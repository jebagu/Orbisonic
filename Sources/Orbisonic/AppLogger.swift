import Foundation
import OSLog

enum AppLogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case notice = "NOTICE"
    case warning = "WARNING"
    case error = "ERROR"

    var osLogType: OSLogType {
        switch self {
        case .debug: .debug
        case .info: .info
        case .notice, .warning: .default
        case .error: .error
        }
    }
}

final class AppLogger {
    static let subsystem = "com.orbisonic.app"
    static let logDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Orbisonic", isDirectory: true)
    static let logFileURL = logDirectoryURL.appendingPathComponent("Orbisonic.log", isDirectory: false)

    static let shared = AppLogger()

    private let queue = DispatchQueue(label: "Orbisonic.Logger", qos: .utility)
    private let formatter: ISO8601DateFormatter
    private let osLogger = Logger(subsystem: subsystem, category: "runtime")

    private var fileHandle: FileHandle?

    private init() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = .current
        self.formatter = formatter
        queue.sync {
            self.bootstrapLogFile()
            self.writeSessionBanner()
        }
    }

    static var logFilePath: String {
        logFileURL.path
    }

    func debug(category: String, _ message: String) {
        log(.debug, category: category, message)
    }

    func info(category: String, _ message: String) {
        log(.info, category: category, message)
    }

    func notice(category: String, _ message: String) {
        log(.notice, category: category, message)
    }

    func warning(category: String, _ message: String) {
        log(.warning, category: category, message)
    }

    func error(category: String, _ message: String) {
        log(.error, category: category, message)
    }

    func log(_ level: AppLogLevel, category: String, _ message: String) {
        queue.async {
            let line = "[\(self.timestamp())] [\(level.rawValue)] [\(category)] \(message)"
            self.osLogger.log(level: level.osLogType, "\(line, privacy: .public)")
            self.append(line)
        }
    }

    private func bootstrapLogFile() {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: Self.logDirectoryURL, withIntermediateDirectories: true)

        if !fileManager.fileExists(atPath: Self.logFileURL.path) {
            fileManager.createFile(atPath: Self.logFileURL.path, contents: nil)
        }

        fileHandle = try? FileHandle(forWritingTo: Self.logFileURL)
        _ = try? fileHandle?.seekToEnd()
    }

    private func writeSessionBanner() {
        append("--------------------------------------------------------------------------------")
        append("[\(timestamp())] [NOTICE] [logger] Session started. Log file: \(Self.logFileURL.path)")
    }

    private func append(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8) else { return }
        try? fileHandle?.write(contentsOf: data)
    }

    private func timestamp() -> String {
        formatter.string(from: Date())
    }
}
