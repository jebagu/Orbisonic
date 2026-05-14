import Foundation

public enum VlcReferenceBuildSettings {
    public static let swiftFlagName = "ORBISONIC_ENABLE_VLC_REFERENCE"

    public static var isEnabled: Bool {
        #if ORBISONIC_ENABLE_VLC_REFERENCE
        true
        #else
        false
        #endif
    }
}

public struct VlcStereoMonitorCallbackContract: Equatable, Hashable, Sendable {
    public static let standard = VlcStereoMonitorCallbackContract(
        formatFourCC: "FL32",
        channelCount: 2
    )

    public let formatFourCC: String
    public let channelCount: Int

    public init(formatFourCC: String, channelCount: Int) {
        self.formatFourCC = formatFourCC
        self.channelCount = channelCount
    }
}

public enum VlcCapabilityStatus: Equatable, Hashable, Sendable {
    case disabledAtBuild
    case unavailable
    case available
}

public enum VlcCapabilityDiagnosticSeverity: String, Equatable, Hashable, Sendable {
    case info
    case warning
}

public enum VlcCapabilityDiagnosticCode: String, Equatable, Hashable, Sendable {
    case buildFlagDisabled
    case libraryNotFound
    case pluginDirectoryMissing
    case runtimeAvailable
}

public struct VlcCapabilityDiagnostic: Equatable, Hashable, Sendable {
    public let severity: VlcCapabilityDiagnosticSeverity
    public let code: VlcCapabilityDiagnosticCode
    public let message: String

    public init(
        severity: VlcCapabilityDiagnosticSeverity,
        code: VlcCapabilityDiagnosticCode,
        message: String
    ) {
        self.severity = severity
        self.code = code
        self.message = message
    }
}

public struct VlcCapabilityReport: Equatable, Hashable, Sendable {
    public let buildFlagEnabled: Bool
    public let status: VlcCapabilityStatus
    public let runtimeAvailable: Bool
    public let libraryPath: String?
    public let pluginDirectoryPath: String?
    public let callbackContract: VlcStereoMonitorCallbackContract
    public let diagnostics: [VlcCapabilityDiagnostic]

    public init(
        buildFlagEnabled: Bool,
        status: VlcCapabilityStatus,
        runtimeAvailable: Bool,
        libraryPath: String?,
        pluginDirectoryPath: String?,
        callbackContract: VlcStereoMonitorCallbackContract = .standard,
        diagnostics: [VlcCapabilityDiagnostic]
    ) {
        self.buildFlagEnabled = buildFlagEnabled
        self.status = status
        self.runtimeAvailable = runtimeAvailable
        self.libraryPath = libraryPath
        self.pluginDirectoryPath = pluginDirectoryPath
        self.callbackContract = callbackContract
        self.diagnostics = diagnostics
    }

    public var canOpenLocalStereoMonitor: Bool {
        status == .available && runtimeAvailable
    }
}

public struct VlcCapabilityProbeConfiguration: Equatable, Hashable, Sendable {
    public static let defaultCandidateLibraryPaths = [
        "/Applications/VLC.app/Contents/MacOS/lib/libvlc.dylib",
        "/Applications/VLC.app/Contents/Frameworks/lib/libvlc.dylib",
        "/opt/homebrew/lib/libvlc.dylib",
        "/usr/local/lib/libvlc.dylib"
    ]

    public static let defaultCandidatePluginDirectoryPaths = [
        "/Applications/VLC.app/Contents/MacOS/plugins",
        "/Applications/VLC.app/Contents/Frameworks/plugins",
        "/opt/homebrew/lib/vlc/plugins",
        "/usr/local/lib/vlc/plugins"
    ]

    public let buildFlagEnabled: Bool
    public let candidateLibraryPaths: [String]
    public let candidatePluginDirectoryPaths: [String]

    public init(
        buildFlagEnabled: Bool = VlcReferenceBuildSettings.isEnabled,
        candidateLibraryPaths: [String] = Self.defaultCandidateLibraryPaths,
        candidatePluginDirectoryPaths: [String] = Self.defaultCandidatePluginDirectoryPaths
    ) {
        self.buildFlagEnabled = buildFlagEnabled
        self.candidateLibraryPaths = candidateLibraryPaths
        self.candidatePluginDirectoryPaths = candidatePluginDirectoryPaths
    }
}

public struct VlcCapabilityProbe {
    private let configuration: VlcCapabilityProbeConfiguration
    private let fileExists: (String) -> Bool
    private let directoryExists: (String) -> Bool

    public init(
        configuration: VlcCapabilityProbeConfiguration = VlcCapabilityProbeConfiguration(),
        fileExists: @escaping (String) -> Bool = { path in
            var isDirectory = ObjCBool(false)
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                && !isDirectory.boolValue
        },
        directoryExists: @escaping (String) -> Bool = { path in
            var isDirectory = ObjCBool(false)
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                && isDirectory.boolValue
        }
    ) {
        self.configuration = configuration
        self.fileExists = fileExists
        self.directoryExists = directoryExists
    }

    public func probeCapabilities() -> VlcCapabilityReport {
        guard configuration.buildFlagEnabled else {
            return VlcCapabilityReport(
                buildFlagEnabled: false,
                status: .disabledAtBuild,
                runtimeAvailable: false,
                libraryPath: nil,
                pluginDirectoryPath: nil,
                diagnostics: [
                    VlcCapabilityDiagnostic(
                        severity: .info,
                        code: .buildFlagDisabled,
                        message: "\(VlcReferenceBuildSettings.swiftFlagName) is not enabled; local monitor playback remains on the existing default path."
                    )
                ]
            )
        }

        let libraryPath = configuration.candidateLibraryPaths.first(where: fileExists)
        let pluginDirectoryPath = configuration.candidatePluginDirectoryPaths.first(where: directoryExists)
        var diagnostics: [VlcCapabilityDiagnostic] = []

        if libraryPath == nil {
            diagnostics.append(
                VlcCapabilityDiagnostic(
                    severity: .warning,
                    code: .libraryNotFound,
                    message: "No libvlc runtime library was found in the configured candidate paths."
                )
            )
        }

        if pluginDirectoryPath == nil {
            diagnostics.append(
                VlcCapabilityDiagnostic(
                    severity: .warning,
                    code: .pluginDirectoryMissing,
                    message: "No VLC plugin directory was found in the configured candidate paths."
                )
            )
        }

        let runtimeAvailable = libraryPath != nil && pluginDirectoryPath != nil
        if runtimeAvailable {
            diagnostics.append(
                VlcCapabilityDiagnostic(
                    severity: .info,
                    code: .runtimeAvailable,
                    message: "VLC runtime and plugin directory are available for the guarded reference monitor path."
                )
            )
        }

        return VlcCapabilityReport(
            buildFlagEnabled: true,
            status: runtimeAvailable ? .available : .unavailable,
            runtimeAvailable: runtimeAvailable,
            libraryPath: libraryPath,
            pluginDirectoryPath: pluginDirectoryPath,
            diagnostics: diagnostics
        )
    }
}
