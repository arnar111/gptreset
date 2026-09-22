import SwiftUI
import WidgetKit
import CodexResetCore

struct StatusEntry: TimelineEntry {
    var date: Date
    var content: WidgetContent?
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: Date(), content: sample)
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
        return StatusEntry(date: date, content: sampleIfEmpty ? sample : nil)
    }

    private var sample: WidgetContent {
        WidgetContent(
            mode: .tracking,
            symbolName: "flame.fill",
            compactValue: "10d",
            caption: "since full reset",
            ago: "10d 7h ago",
            stamp: "Sep 12 · 08:09",
            bankedCount: 2,
            scheduledCompact: "< 15h",
            scheduledPhrase: "Within ~15h",
            accessibilityLabel: "Last full reset 10 days ago. 2 banked available. Next reset within about 15 hours."
        )
    }
}

struct CodexStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CodexStatus", provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
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
    var entry: StatusEntry

    var body: some View {
        Group {
            if let content = entry.content {
                switch family {
                case .systemMedium:
                    medium(content)
                case .systemLarge:
                    large(content)
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
            }
        }
        .widgetURL(URL(string: "codexreset://latest"))
    }

    private func small(_ content: WidgetContent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CODEX")
                .font(.caption2.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(.secondary)
            Label(content.compactValue, systemImage: content.symbolName)
                .font(.title2.weight(.bold))
                .widgetAccentable()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(content.mode == .celebration ? content.ago : content.caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(content.bankedCount) banked")
                .font(.caption.weight(.semibold))
            if content.mode == .tracking, let scheduled = content.scheduledCompact {
                Text(scheduled)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(content.accessibilityLabel)
    }

    private func medium(_ content: WidgetContent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CODEX RESETS")
                .font(.caption2.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(.secondary)
            HStack(alignment: .top) {
                column(symbol: content.symbolName, title: content.mode == .celebration ? "FULL" : "FULL", value: content.mode == .celebration ? "RESET" : content.compactValue, detail: content.mode == .celebration ? content.ago : content.ago)
                column(symbol: "building.columns.fill", title: "BANKED", value: "\(content.bankedCount)", detail: "available")
                column(symbol: "hourglass", title: "NEXT", value: content.scheduledCompact ?? "—", detail: content.scheduledPhrase ?? "None")
            }
            if content.bankedCount > 0 {
                Button(intent: MarkBankedResetUsedIntent()) {
                    Text("Used banked reset")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .accessibilityLabel(content.accessibilityLabel)
    }

    private func large(_ content: WidgetContent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CODEX RESETS")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Label(content.mode == .celebration ? "Full reset" : content.caption, systemImage: content.symbolName)
                .font(.headline)
                .widgetAccentable()
            Text(content.mode == .celebration ? content.caption : content.ago)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(2)
            if !content.stamp.isEmpty {
                Text(content.stamp)
                    .foregroundStyle(.secondary)
            }
            Text("\(content.bankedCount) banked available")
                .font(.title3.weight(.semibold))
            if let phrase = content.scheduledPhrase {
                Text("Next · \(phrase)")
                    .foregroundStyle(.secondary)
            }
            if content.bankedCount > 0 {
                Button(intent: MarkBankedResetUsedIntent()) {
                    Text("Used banked reset")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(content.accessibilityLabel)
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
            Text("\(content.compactValue) \(content.caption)")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(content.bankedCount) banked")
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(content.accessibilityLabel)
    }

    private func column(symbol: String, title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: symbol)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .widgetAccentable()
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Banked resets")
        .description("How many banked resets you still have. On the Home Screen widget, mark one as used without opening the app.")
        .supportedFamilies([.systemSmall, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct BankedWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: StatusEntry

    private var count: Int { entry.content?.bankedCount ?? 0 }

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
                VStack(alignment: .leading, spacing: 6) {
                    Text("BANKED")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(.secondary)
                    Text("\(count)")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text(count == 1 ? "reset available" : "resets available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if count > 0, entry.content != nil {
                        Button(intent: MarkBankedResetUsedIntent()) {
                            Text("Used")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityLabel("\(count) banked \(count == 1 ? "reset" : "resets") available")
        .widgetURL(URL(string: "codexreset://latest"))
    }
}
