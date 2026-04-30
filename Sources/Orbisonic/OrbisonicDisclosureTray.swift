import SwiftUI

enum OrbisonicDisclosureTrayStyle {
    case stage
    case diagnostics
    case inline

    var cornerRadius: CGFloat {
        switch self {
        case .stage, .diagnostics:
            return LabTheme.panelRadius
        case .inline:
            return LabTheme.controlRadius
        }
    }

    var fill: Color {
        switch self {
        case .stage:
            return Color.black.opacity(0.16)
        case .diagnostics:
            return LabTheme.panelSoft
        case .inline:
            return Color.black.opacity(0.12)
        }
    }

    var padding: CGFloat {
        switch self {
        case .stage:
            return 14
        case .diagnostics:
            return 16
        case .inline:
            return 8
        }
    }
}

/// Default collapsible tray for Orbisonic UI surfaces.
struct OrbisonicDisclosureTray<Content: View>: View {
    @Binding var isExpanded: Bool
    let title: String
    var systemImage: String?
    var trailingSummary: String?
    var showsWarning = false
    var titleFontSize: CGFloat = 12
    var headerMinHeight: CGFloat = 34
    var contentTopPadding: CGFloat = 10
    var contentSpacing: CGFloat = 12
    var style: OrbisonicDisclosureTrayStyle = .stage
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.14)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LabTheme.cyan)
                        .frame(width: 14)

                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 12, weight: .bold))
                    }

                    Text(title)
                        .font(.system(size: titleFontSize, weight: .bold))

                    if showsWarning {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(LabTheme.amber)
                    }

                    Spacer(minLength: 0)

                    if let trailingSummary {
                        Text(trailingSummary)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(LabTheme.textSoft)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .foregroundStyle(LabTheme.text)
                .frame(maxWidth: .infinity, minHeight: headerMinHeight, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if isExpanded {
                VStack(alignment: .leading, spacing: contentSpacing) {
                    content()
                }
                .padding(.top, contentTopPadding)
            }
        }
        .padding(style.padding)
        .background(
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(style.fill)
                .overlay(
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .stroke(LabTheme.line, lineWidth: 1)
                )
        )
    }
}
