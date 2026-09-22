import SwiftUI
import CodexResetCore

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var filter: HistoryFilter = .all

    var body: some View {
        NavigationStack {
            let rows = DashboardDerivation.history(model.state, filter: filter)
            List {
                if model.state.lastRefreshFailed {
                    Text("Unable to refresh. Showing the last saved update.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
                if rows.isEmpty {
                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rows, id: \.dedupeKey) { event in
                        NavigationLink {
                            ResetDetailView(eventID: event.id)
                        } label: {
                            HistoryRow(event: event, timeDisplay: model.state.timeDisplay)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("Filter", selection: $filter) {
                    Text("All").tag(HistoryFilter.all)
                    Text("Full").tag(HistoryFilter.full)
                    Text("Banked").tag(HistoryFilter.banked)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.bar)
                .accessibilityLabel("Filter announcements")
            }
            .refreshable {
                await model.refresh(force: true)
            }
            .safeAreaInset(edge: .bottom) {
                AttributionFooter()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.bar)
            }
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .all: return "No announcements cached yet."
        case .full: return "No full resets in the cache."
        case .banked: return "No banked resets in the cache."
        }
    }
}

struct HistoryRow: View {
    @Environment(\.colorScheme) private var scheme
    var event: ResetEvent
    var timeDisplay: TimeDisplay

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            KindGlyph(systemName: event.kind.symbolName, tint: tint)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.kind.title)
                        .font(.body.weight(.semibold))
                    Spacer(minLength: 8)
                    if event.lifecycle == .scheduled {
                        Text("Scheduled")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.dusk(scheme))
                    }
                }
                Text(stamp)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !event.text.isEmpty {
                    Text(event.text)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var stamp: String {
        if event.lifecycle == .scheduled, let when = event.scheduledFor {
            return "By \(RelativeTime.stamp(when, display: timeDisplay, includeWeekday: true))"
        }
        return RelativeTime.stamp(event.announcedAt, display: timeDisplay)
    }

    private var tint: Color {
        switch event.kind {
        case .full, .combined: return Palette.ember(scheme)
        case .banked: return Palette.teal(scheme)
        case .unclassified: return .secondary
        }
    }
}
