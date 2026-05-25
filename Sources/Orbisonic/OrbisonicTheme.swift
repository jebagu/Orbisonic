import SwiftUI

enum OrbisonicColorScheme: String, CaseIterable, Identifiable {
    case lab
    case kimiPurple
    case daftPunkBow
    case rackMint
    case rackPink
    case rackBlue
    case ember
    case graphite
    case flamingoGreen
    case flamingoPink
    case dustyRose

    static let storageKey = "Orbisonic.colorScheme"
    static let defaultScheme: OrbisonicColorScheme = .lab

    var id: String { rawValue }

    var name: String {
        switch self {
        case .lab:
            "Orbisonic Lab"
        case .kimiPurple:
            "Kimi Purple"
        case .daftPunkBow:
            "Daft Punk Bow"
        case .rackMint:
            "Rack Mint"
        case .rackPink:
            "Rack Pink"
        case .rackBlue:
            "Rack Blue"
        case .ember:
            "Ember Console"
        case .graphite:
            "Graphite"
        case .flamingoGreen:
            "Flamingo Green"
        case .flamingoPink:
            "Flamingo Pink"
        case .dustyRose:
            "Dusty Rose"
        }
    }

    var subtitle: String {
        switch self {
        case .lab:
            "Cyan technical workbench"
        case .kimiPurple:
            "Vital-inspired purple glow"
        case .daftPunkBow:
            "Rainbow VU speaker metering"
        case .rackMint:
            "Dark rack with mint signal"
        case .rackPink:
            "Dark rack with delay pink"
        case .rackBlue:
            "Dark rack with phaser blue"
        case .ember:
            "Warm amber monitoring room"
        case .graphite:
            "Neutral high-contrast surface"
        case .flamingoGreen:
            "Green lead with pink lift"
        case .flamingoPink:
            "Pink lead with green support"
        case .dustyRose:
            "Rose lead with deep green support"
        }
    }

    var palette: OrbisonicPalette {
        switch self {
        case .lab:
            OrbisonicPalette(
                backgroundTop: Self.rgb(7, 16, 20),
                backgroundBottom: Self.rgb(2, 7, 10),
                panel: Self.rgb(13, 24, 29).opacity(0.9),
                panelSoft: Color.white.opacity(0.045),
                toolbar: Self.rgb(5, 12, 15).opacity(0.7),
                line: Self.rgb(217, 251, 255).opacity(0.14),
                text: Self.rgb(239, 252, 255),
                textSoft: Self.rgb(159, 185, 189),
                accent: Self.rgb(94, 234, 212),
                accentSecondary: Self.rgb(96, 165, 250),
                success: Self.rgb(34, 197, 94),
                warning: Self.rgb(250, 204, 21),
                danger: Self.rgb(251, 113, 133)
            )
        case .kimiPurple:
            OrbisonicPalette(
                backgroundTop: Self.rgb(10, 8, 17),
                backgroundBottom: Self.rgb(0, 0, 0),
                panel: Self.rgb(20, 24, 28).opacity(0.92),
                panelSoft: Self.rgb(170, 136, 255).opacity(0.09),
                toolbar: Self.rgb(29, 33, 37).opacity(0.82),
                line: Color.white.opacity(0.12),
                text: Self.rgb(242, 242, 242),
                textSoft: Self.rgb(170, 172, 173),
                accent: Self.rgb(170, 136, 255),
                accentSecondary: Self.rgb(50, 214, 191),
                success: Self.rgb(24, 206, 15),
                warning: Self.rgb(255, 178, 54),
                danger: Self.rgb(255, 54, 54)
            )
        case .daftPunkBow:
            OrbisonicPalette(
                backgroundTop: Self.rgb(10, 8, 17),
                backgroundBottom: Self.rgb(0, 0, 0),
                panel: Self.rgb(20, 24, 28).opacity(0.92),
                panelSoft: Self.rgb(170, 136, 255).opacity(0.09),
                toolbar: Self.rgb(29, 33, 37).opacity(0.82),
                line: Color.white.opacity(0.12),
                text: Self.rgb(242, 242, 242),
                textSoft: Self.rgb(170, 172, 173),
                accent: Self.rgb(170, 136, 255),
                accentSecondary: Self.rgb(50, 214, 191),
                success: Self.rgb(24, 206, 15),
                warning: Self.rgb(255, 178, 54),
                danger: Self.rgb(255, 54, 54),
                usesCompressedRainbowLinearControls: true,
                compressedRainbowWell: Self.daftRainbowWell,
                vuRamp: [
                    OrbisonicVURampStop(position: 0.00, color: Self.daftViolet),
                    OrbisonicVURampStop(position: 0.18, color: Self.daftBlue),
                    OrbisonicVURampStop(position: 0.34, color: Self.daftCyan),
                    OrbisonicVURampStop(position: 0.50, color: Self.daftEmerald),
                    OrbisonicVURampStop(position: 0.66, color: Self.daftYellow),
                    OrbisonicVURampStop(position: 0.82, color: Self.daftOrange),
                    OrbisonicVURampStop(position: 1.00, color: Self.daftRed)
                ]
            )
        case .rackMint:
            OrbisonicPalette(
                backgroundTop: Self.rackPageBackground,
                backgroundBottom: Self.rackWell,
                panel: Self.rackSurface.opacity(0.94),
                panelSoft: Self.rackCard.opacity(0.92),
                toolbar: Self.rackDivider.opacity(0.88),
                line: Self.rackTextSecondary.opacity(0.18),
                text: Self.rackText,
                textSoft: Self.rackTextSecondary,
                accent: Self.rackMintColor,
                accentSecondary: Self.rackPinkColor,
                success: Self.rackMintColor,
                warning: Self.rackBlueColor,
                danger: Self.rackPinkColor
            )
        case .rackPink:
            OrbisonicPalette(
                backgroundTop: Self.rackPageBackground,
                backgroundBottom: Self.rackWell,
                panel: Self.rackSurface.opacity(0.94),
                panelSoft: Self.rackCard.opacity(0.92),
                toolbar: Self.rackDivider.opacity(0.88),
                line: Self.rackTextSecondary.opacity(0.18),
                text: Self.rackText,
                textSoft: Self.rackTextSecondary,
                accent: Self.rackPinkColor,
                accentSecondary: Self.rackMintColor,
                success: Self.rackMintColor,
                warning: Self.rackBlueColor,
                danger: Self.rackPinkColor
            )
        case .rackBlue:
            OrbisonicPalette(
                backgroundTop: Self.rackPageBackground,
                backgroundBottom: Self.rackWell,
                panel: Self.rackSurface.opacity(0.94),
                panelSoft: Self.rackCard.opacity(0.92),
                toolbar: Self.rackDivider.opacity(0.88),
                line: Self.rackTextSecondary.opacity(0.18),
                text: Self.rackText,
                textSoft: Self.rackTextSecondary,
                accent: Self.rackBlueColor,
                accentSecondary: Self.rackMintColor,
                success: Self.rackMintColor,
                warning: Self.rackPinkColor,
                danger: Self.rgb(255, 109, 122)
            )
        case .ember:
            OrbisonicPalette(
                backgroundTop: Self.rgb(20, 13, 8),
                backgroundBottom: Self.rgb(6, 5, 4),
                panel: Self.rgb(27, 22, 18).opacity(0.92),
                panelSoft: Self.rgb(255, 178, 54).opacity(0.075),
                toolbar: Self.rgb(18, 13, 10).opacity(0.78),
                line: Self.rgb(255, 226, 177).opacity(0.16),
                text: Self.rgb(255, 246, 232),
                textSoft: Self.rgb(203, 180, 151),
                accent: Self.rgb(255, 178, 54),
                accentSecondary: Self.rgb(94, 234, 212),
                success: Self.rgb(77, 212, 132),
                warning: Self.rgb(250, 204, 21),
                danger: Self.rgb(251, 113, 133)
            )
        case .graphite:
            OrbisonicPalette(
                backgroundTop: Self.rgb(15, 16, 18),
                backgroundBottom: Self.rgb(4, 5, 6),
                panel: Self.rgb(25, 27, 30).opacity(0.94),
                panelSoft: Color.white.opacity(0.055),
                toolbar: Self.rgb(16, 18, 21).opacity(0.8),
                line: Color.white.opacity(0.16),
                text: Self.rgb(245, 247, 250),
                textSoft: Self.rgb(170, 176, 184),
                accent: Self.rgb(229, 231, 235),
                accentSecondary: Self.rgb(94, 234, 212),
                success: Self.rgb(52, 211, 153),
                warning: Self.rgb(251, 191, 36),
                danger: Self.rgb(248, 113, 113)
            )
        case .flamingoGreen:
            OrbisonicPalette(
                backgroundTop: Self.flamingoSecondaryDark,
                backgroundBottom: Self.flamingoPrimaryDark,
                panel: Self.flamingoPrimaryDark.opacity(0.94),
                panelSoft: Self.flamingoPrimaryGreen.opacity(0.08),
                toolbar: Self.flamingoSecondaryDark.opacity(0.82),
                line: Self.flamingoPrimaryGreen.opacity(0.2),
                text: Self.rgb(248, 251, 249),
                textSoft: Self.rgb(184, 198, 195),
                accent: Self.flamingoPrimaryGreen,
                accentSecondary: Self.flamingoPinkColor,
                success: Self.flamingoPrimaryGreen,
                warning: Self.flamingoDeepGreen,
                danger: Self.flamingoDustyRose
            )
        case .flamingoPink:
            OrbisonicPalette(
                backgroundTop: Self.flamingoSecondaryDark,
                backgroundBottom: Self.flamingoPrimaryDark,
                panel: Self.flamingoPrimaryDark.opacity(0.94),
                panelSoft: Self.flamingoDustyRose.opacity(0.1),
                toolbar: Self.flamingoSecondaryDark.opacity(0.82),
                line: Self.flamingoPinkColor.opacity(0.22),
                text: Self.rgb(255, 247, 250),
                textSoft: Self.rgb(206, 184, 194),
                accent: Self.flamingoPinkColor,
                accentSecondary: Self.flamingoPrimaryGreen,
                success: Self.flamingoPrimaryGreen,
                warning: Self.flamingoDustyRose,
                danger: Self.flamingoPinkColor
            )
        case .dustyRose:
            OrbisonicPalette(
                backgroundTop: Self.flamingoSecondaryDark,
                backgroundBottom: Self.flamingoPrimaryDark,
                panel: Self.flamingoPrimaryDark.opacity(0.94),
                panelSoft: Self.flamingoDustyRose.opacity(0.09),
                toolbar: Self.flamingoSecondaryDark.opacity(0.82),
                line: Self.flamingoDustyRose.opacity(0.26),
                text: Self.rgb(255, 248, 250),
                textSoft: Self.rgb(201, 181, 189),
                accent: Self.flamingoDustyRose,
                accentSecondary: Self.flamingoPrimaryGreen,
                success: Self.flamingoPrimaryGreen,
                warning: Self.flamingoDeepGreen,
                danger: Self.flamingoPinkColor
            )
        }
    }

    static func from(rawValue: String) -> OrbisonicColorScheme {
        if rawValue == "techRainbow" {
            return .daftPunkBow
        }

        return OrbisonicColorScheme(rawValue: rawValue) ?? defaultScheme
    }

    private static func rgb(_ red: Double, _ green: Double, _ blue: Double, opacity: Double = 1) -> Color {
        Color(.sRGB, red: red / 255, green: green / 255, blue: blue / 255, opacity: opacity)
    }

    private static let flamingoPrimaryDark = rgb(30, 33, 42)
    private static let flamingoSecondaryDark = rgb(42, 46, 56)
    private static let flamingoPrimaryGreen = rgb(46, 204, 138)
    private static let flamingoDeepGreen = rgb(25, 123, 103)
    private static let flamingoPinkColor = rgb(244, 143, 170)
    private static let flamingoDustyRose = rgb(167, 84, 114)

    private static let daftViolet = rgb(167, 139, 250)
    private static let daftBlue = rgb(91, 140, 255)
    private static let daftCyan = rgb(34, 211, 238)
    private static let daftEmerald = rgb(52, 211, 153)
    private static let daftYellow = rgb(253, 224, 71)
    private static let daftOrange = rgb(251, 146, 60)
    private static let daftRed = rgb(239, 68, 68)
    private static let daftRainbowWell = rgb(52, 64, 71)

    private static let rackPageBackground = rgb(38, 41, 44)
    private static let rackSurface = rgb(76, 79, 82)
    private static let rackDivider = rgb(62, 65, 68)
    private static let rackCard = rgb(47, 50, 53)
    private static let rackWell = rgb(32, 34, 38)
    private static let rackText = rgb(252, 255, 255)
    private static let rackTextSecondary = rgb(208, 212, 216)
    private static let rackMintColor = rgb(121, 228, 184)
    private static let rackPinkColor = rgb(238, 164, 230)
    private static let rackBlueColor = rgb(118, 203, 248)
}

struct OrbisonicVURampStop {
    let position: Double
    let color: Color
}

struct OrbisonicPalette {
    let backgroundTop: Color
    let backgroundBottom: Color
    let panel: Color
    let panelSoft: Color
    let toolbar: Color
    let line: Color
    let text: Color
    let textSoft: Color
    let accent: Color
    let accentSecondary: Color
    let success: Color
    let warning: Color
    let danger: Color
    let usesCompressedRainbowLinearControls: Bool
    let compressedRainbowWell: Color
    let vuRamp: [OrbisonicVURampStop]

    let panelRadius: CGFloat = 8
    let controlRadius: CGFloat = 7

    init(
        backgroundTop: Color,
        backgroundBottom: Color,
        panel: Color,
        panelSoft: Color,
        toolbar: Color,
        line: Color,
        text: Color,
        textSoft: Color,
        accent: Color,
        accentSecondary: Color,
        success: Color,
        warning: Color,
        danger: Color,
        usesCompressedRainbowLinearControls: Bool = false,
        compressedRainbowWell: Color? = nil,
        vuRamp: [OrbisonicVURampStop]? = nil
    ) {
        self.backgroundTop = backgroundTop
        self.backgroundBottom = backgroundBottom
        self.panel = panel
        self.panelSoft = panelSoft
        self.toolbar = toolbar
        self.line = line
        self.text = text
        self.textSoft = textSoft
        self.accent = accent
        self.accentSecondary = accentSecondary
        self.success = success
        self.warning = warning
        self.danger = danger
        self.usesCompressedRainbowLinearControls = usesCompressedRainbowLinearControls
        self.compressedRainbowWell = compressedRainbowWell ?? line
        self.vuRamp = vuRamp ?? [
            OrbisonicVURampStop(position: 0.0, color: success),
            OrbisonicVURampStop(position: 0.5, color: warning),
            OrbisonicVURampStop(position: 1.0, color: danger)
        ]
    }

    var backgroundGradient: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .top, endPoint: .bottom)
    }

    var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var vuGradient: LinearGradient {
        LinearGradient(
            stops: vuRampGradientStops,
            startPoint: .bottom,
            endPoint: .top
        )
    }

    var horizontalVURampGradient: LinearGradient {
        LinearGradient(
            stops: vuRampGradientStops,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var linearControlWell: Color {
        usesCompressedRainbowLinearControls ? compressedRainbowWell : toolbar.opacity(0.82)
    }

    var linearControlThumb: Color {
        accent
    }

    var linearControlGradient: LinearGradient {
        if usesCompressedRainbowLinearControls {
            LinearGradient(
                stops: vuRampGradientStops,
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            LinearGradient(
                colors: [accent, accentSecondary],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    var linearControlRampStops: [OrbisonicVURampStop] {
        if usesCompressedRainbowLinearControls {
            return vuRamp.sorted { $0.position < $1.position }
        }

        return [
            OrbisonicVURampStop(position: 0, color: accent),
            OrbisonicVURampStop(position: 1, color: accentSecondary)
        ]
    }

    var compressesLinearControlRampIntoActiveSegment: Bool {
        usesCompressedRainbowLinearControls
    }

    func vuColor(for level: Double) -> Color {
        let normalized = min(max(level, 0), 1)
        return vuRamp
            .sorted { $0.position < $1.position }
            .last { normalized >= $0.position }?
            .color ?? success
    }

    private var vuRampGradientStops: [Gradient.Stop] {
        vuRamp
            .sorted { $0.position < $1.position }
            .map { Gradient.Stop(color: $0.color, location: $0.position) }
    }
}

private struct OrbisonicPaletteKey: EnvironmentKey {
    static let defaultValue = OrbisonicColorScheme.defaultScheme.palette
}

extension EnvironmentValues {
    var orbisonicPalette: OrbisonicPalette {
        get { self[OrbisonicPaletteKey.self] }
        set { self[OrbisonicPaletteKey.self] = newValue }
    }
}

extension View {
    func orbisonicPalette(_ palette: OrbisonicPalette) -> some View {
        environment(\.orbisonicPalette, palette)
    }
}

enum LabTheme {
    static var palette: OrbisonicPalette {
        let rawValue = UserDefaults.standard.string(forKey: OrbisonicColorScheme.storageKey) ??
            OrbisonicColorScheme.defaultScheme.rawValue
        return OrbisonicColorScheme.from(rawValue: rawValue).palette
    }

    static var bg: Color { palette.backgroundTop }
    static var bgBottom: Color { palette.backgroundBottom }
    static var panel: Color { palette.panel }
    static var panelSoft: Color { palette.panelSoft }
    static var toolbar: Color { palette.toolbar }
    static var line: Color { palette.line }
    static var text: Color { palette.text }
    static var textSoft: Color { palette.textSoft }
    static var cyan: Color { palette.accent }
    static var blue: Color { palette.accentSecondary }
    static var green: Color { palette.success }
    static var amber: Color { palette.warning }
    static var red: Color { palette.danger }

    static var panelRadius: CGFloat { palette.panelRadius }
    static var controlRadius: CGFloat { palette.controlRadius }
}
