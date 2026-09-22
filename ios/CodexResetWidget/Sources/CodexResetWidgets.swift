import SwiftUI
import WidgetKit
import CodexResetCore

/// Variant B High-End. Home Screen widgets only; Lock Screen accessories stay template.
enum HighEnd {
    static let coral = Color(red: 232 / 255, green: 137 / 255, blue: 106 / 255)
    static let coralSoft = Color(red: 240 / 255, green: 168 / 255, blue: 144 / 255)
    static let mist = Color.white.opacity(0.62)
    static let hairline = Color.white.opacity(0.14)
    static let charcoalTop = Color(red: 28 / 255, green: 29 / 255, blue: 33 / 255)
    static let charcoalBottom = Color(red: 12 / 255, green: 13 / 255, blue: 15 / 255)
}

struct HighEndBackground: View {
    var celebrating: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [HighEnd.charcoalTop, HighEnd.charcoalBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                colors: [Color.white.opacity(0.07), Color.white.opacity(0)],
                startPoint: .top,
                endPoint: .center
            )
            if celebrating {
                RadialGradient(
                    colors: [HighEnd.coral.opacity(0.42), HighEnd.coral.opacity(0)],
                    center: UnitPoint(x: 0.15, y: 0.0),
                    startRadius: 0,
                    endRadius: 170
                )
                RadialGradient(
                    colors: [HighEnd.coralSoft.opacity(0.16), Color.clear],
                    center: UnitPoint(x: 0.85, y: 1.0),
                    startRadius: 0,
                    endRadius: 140
                )
            }
        }
    }
}

struct StatusEntry: TimelineEntry {
    var date: Date
    var content: WidgetContent?
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: Date(), content: celebrationSample)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(entry(at: Date(), sampleIfEmpty: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        let now = Date()
        let entries = (0..<30).map { index in
            entry(at: now.addingTimeInterval(TimeInterval(index * 60)), sampleIfEmpty: false)
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
    }

    private func entry(at date: Date, sampleIfEmpty: Bool) -> StatusEntry {
        if let state = SharedStateStore.loadIfPresent() {
            return StatusEntry(date: date, content: WidgetContentBuilder.make(state: state, now: date))
        }
        return StatusEntry(date: date, content: sampleIfEmpty ? celebrationSample : nil)
    }

    private var celebrationSample: WidgetContent {
        WidgetContent(
            mode: .celebration,
            symbolName: "flame.fill",
            compactValue: "RESET",
            headline: "RESET!",
            caption: "100% reset",
            ago: "23m ago",
            stamp: "Sep 22 · 18:42",
            bankedCount: 2,
            scheduledCompact: "< 15h",
            scheduledPhrase: "Within ~15h",
            accessibilityLabel: "Full reset, 23 minutes ago. 2 banked resets available."
        )
    }
}

struct CodexStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CodexStatus", provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Codex Reset")
        .description("Time since the last full reset, banked resets you have left, and whether another reset is scheduled.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}

struct StatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    var entry: StatusEntry

    private var celebrating: Bool { entry.content?.mode == .celebration }

    private var accent: Color {
        renderingMode == .accented ? .primary : HighEnd.coral
    }

    var body: some View {
        Group {
            if let content = entry.content {
                switch family {
                case .systemMedium:
                    homeCard(content, prominent: false)
                case .systemLarge:
                    homeCard(content, prominent: true)
                case .accessoryInline:
                    inline(content)
                case .accessoryCircular:
                    circular(content)
                case .accessoryRectangular:
                    rectangular(content)
                default:
                    small(content)
                }
            } else {
                Text("Open Codex Reset")
                    .font(.caption)
                    .foregroundStyle(HighEnd.mist)
            }
        }
        .widgetURL(URL(string: "codexreset://latest"))
        .containerBackground(for: .widget) {
            if family.isHomeScreen {
                HighEndBackground(celebrating: celebrating)
            } else {
                AccessoryWidgetBackground()
            }
        }
    }

    private func small(_ content: WidgetContent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(content.mode == .celebration ? "RESET!" : content.headline)
                .font(.title2.weight(.semibold))
                .foregroundStyle(content.mode == .celebration ? accent : Color.white)
                .widgetAccentable()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(smallSecondary(content))
                .font(.subheadline)
                .foregroundStyle(HighEnd.mist)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(content.bankedCount) banked")
                .font(.caption.weight(.medium))
                .foregroundStyle(content.mode == .celebration ? HighEnd.coralSoft : Color.white.opacity(0.88))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityLabel(content.accessibilityLabel)
    }

    private func smallSecondary(_ content: WidgetContent) -> String {
        switch content.mode {
        case .celebration:
            return content.ago
        case .tracking:
            return "since full"
        default:
            return content.caption
        }
    }

    private func homeCard(_ content: WidgetContent, prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: prominent ? 10 : 6) {
            if content.mode == .celebration {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("🔥 RESET!")
                        .font((prominent ? Font.title : Font.title3).weight(.semibold))
                        .foregroundStyle(accent)
                        .widgetAccentable()
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(content.ago)
                        .font(.subheadline)
                        .foregroundStyle(HighEnd.mist)
                        .lineLimit(1)
                }
                Text("Usage limits cleared")
                    .font(.subheadline)
                    .foregroundStyle(HighEnd.mist)
            } else {
                Text(content.headline)
                    .font((prominent ? Font.largeTitle : Font.title2).weight(.semibold))
                    .foregroundStyle(.white)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(idleCaption(content))
                    .font(.subheadline)
                    .foregroundStyle(HighEnd.mist)
                    .lineLimit(1)
            }

            VStack(spacing: 0) {
                metricRow("BANKED", value: "\(content.bankedCount)")
                hairline
                metricRow("NEXT", value: content.scheduledPhrase ?? content.scheduledCompact ?? "None")
                hairline
                metricRow(stampLabel(content), value: content.stamp.isEmpty ? "—" : content.stamp)
            }

            if content.bankedCount > 0 {
                usedChip
            }
            if prominent {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityLabel(content.accessibilityLabel)
    }

    private func idleCaption(_ content: WidgetContent) -> String {
        switch content.mode {
        case .tracking:
            return "since full reset"
        case .scheduled:
            return "reset scheduled"
        case .empty:
            return content.caption
        case .celebration:
            return "Usage limits cleared"
        }
    }

    private func stampLabel(_ content: WidgetContent) -> String {
        switch content.mode {
        case .celebration:
            return "PRIOR FULL"
        case .scheduled:
            return "EXPECTED"
        default:
            return "LAST FULL"
        }
    }

    private func metricRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .tracking(0.7)
                .foregroundStyle(HighEnd.mist)
            Spacer(minLength: 8)
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 3)
    }

    private var hairline: some View {
        Rectangle()
            .fill(HighEnd.hairline)
            .frame(height: 0.5)
    }

    private var usedChip: some View {
        Button(intent: MarkBankedResetUsedIntent()) {
            Text("Used banked reset")
                .font(.caption.weight(.medium))
                .foregroundStyle(HighEnd.coralSoft)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(HighEnd.coral.opacity(0.14), in: Capsule())
                .overlay(Capsule().stroke(HighEnd.hairline, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func inline(_ content: WidgetContent) -> some View {
        let text: String
        switch content.mode {
        case .celebration:
            text = "RESET \(content.ago.replacingOccurrences(of: " ago", with: ""))"
        case .scheduled:
            text = content.compactValue
        case .tracking:
            text = "\(content.compactValue) since reset"
        case .empty:
            text = "Codex"
        }
        return Text(text).accessibilityLabel(content.accessibilityLabel)
    }

    private func circular(_ content: WidgetContent) -> some View {
        VStack(spacing: 0) {
            Image(systemName: content.symbolName)
                .font(.caption2)
                .widgetAccentable()
            Text(content.compactValue)
                .font(.headline)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .accessibilityLabel(content.accessibilityLabel)
    }

    private func rectangular(_ content: WidgetContent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rectangularTitle(content))
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(content.bankedCount) banked")
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(content.accessibilityLabel)
    }

    private func rectangularTitle(_ content: WidgetContent) -> String {
        switch content.mode {
        case .celebration:
            return "RESET! · \(content.ago)"
        case .tracking:
            return "\(content.headline) since full"
        default:
            return "\(content.compactValue) \(content.caption)"
        }
    }
}

private extension WidgetFamily {
    var isHomeScreen: Bool {
        switch self {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge:
            return true
        default:
            return false
        }
    }
}

struct BankedProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: Date(), content: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(StatusEntry(date: Date(), content: content(at: Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        let now = Date()
        let entry = StatusEntry(date: now, content: content(at: now))
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(30 * 60))))
    }

    private func content(at date: Date) -> WidgetContent? {
        guard let state = SharedStateStore.loadIfPresent() else { return nil }
        return WidgetContentBuilder.make(state: state, now: date)
    }
}

struct CodexBankedWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CodexBanked", provider: BankedProvider()) { entry in
            BankedWidgetView(entry: entry)
        }
        .configurationDisplayName("Banked resets")
        .description("How many banked resets you still have. On the Home Screen widget, mark one as used without opening the app.")
        .supportedFamilies([.systemSmall, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct BankedWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    var entry: StatusEntry

    private var count: Int { entry.content?.bankedCount ?? 0 }

    private var accent: Color {
        renderingMode == .accented ? .primary : HighEnd.coral
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text("\(count) banked")
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Image(systemName: "building.columns.fill")
                        .font(.caption2)
                        .widgetAccentable()
                    Text("\(count)")
                        .font(.headline)
                }
            case .accessoryRectangular:
                VStack(alignment: .leading) {
                    Text("\(count) banked")
                        .font(.headline)
                    Text(count == 1 ? "Reset available" : "Resets available")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            default:
                VStack(alignment: .leading, spacing: 4) {
                    Text("BANKED")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(HighEnd.mist)
                    Text("\(count)")
                        .font(.system(size: 40, weight: .semibold, design: .default))
                        .foregroundStyle(accent)
                        .widgetAccentable()
                    Text(count == 1 ? "reset available" : "resets available")
                        .font(.caption)
                        .foregroundStyle(HighEnd.mist)
                    Spacer(minLength: 0)
                    if count > 0, entry.content != nil {
                        Button(intent: MarkBankedResetUsedIntent()) {
                            Text("Used banked reset")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(HighEnd.coralSoft)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(HighEnd.coral.opacity(0.14), in: Capsule())
                                .overlay(Capsule().stroke(HighEnd.hairline, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .accessibilityLabel("\(count) banked \(count == 1 ? "reset" : "resets") available")
        .widgetURL(URL(string: "codexreset://latest"))
        .containerBackground(for: .widget) {
            if family.isHomeScreen {
                HighEndBackground(celebrating: false)
            } else {
                AccessoryWidgetBackground()
            }
        }
    }
}
