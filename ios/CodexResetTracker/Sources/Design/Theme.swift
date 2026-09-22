import SwiftUI
import CodexResetCore

enum Palette {
    static func ember(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.98, green: 0.66, blue: 0.32)
            : Color(red: 0.70, green: 0.30, blue: 0.07)
    }

    static func teal(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.49, green: 0.80, blue: 0.74)
            : Color(red: 0.07, green: 0.36, blue: 0.34)
    }

    static func dusk(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.73, green: 0.75, blue: 0.90)
            : Color(red: 0.27, green: 0.31, blue: 0.50)
    }
}

struct TrackerCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
    }
}

struct KindGlyph: View {
    var systemName: String
    var tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(tint.opacity(0.14), in: Circle())
            .accessibilityHidden(true)
    }
}

struct AttributionFooter: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Link(destination: ResetTrackerDefaults.attributionURL) {
                Text("Data from Codex Resets")
            }
            Text("Not affiliated with OpenAI.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens codex-resets.com")
    }
}

extension ResetKind {
    var title: String {
        switch self {
        case .full: return "Full reset"
        case .banked: return "Banked reset"
        case .combined: return "Full + banked"
        case .unclassified: return "Reset update"
        }
    }

    var symbolName: String {
        switch self {
        case .full: return "flame.fill"
        case .banked: return "building.columns.fill"
        case .combined: return "flame.fill"
        case .unclassified: return "questionmark"
        }
    }
}
