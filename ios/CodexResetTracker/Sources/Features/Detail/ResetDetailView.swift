import SwiftUI
import CodexResetCore

struct ResetDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    var eventID: String

    var body: some View {
        Group {
            if let event = DashboardDerivation.event(id: eventID, in: model.state) {
                detail(event)
            } else {
                ContentUnavailableView {
                    Label("Reset not in cache", systemImage: "clock")
                } description: {
                    Text("Pull to refresh on Status. Cached announcements stay available offline.")
                }
            }
        }
        .navigationTitle("Reset")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func detail(_ event: ResetEvent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    KindGlyph(systemName: event.kind.symbolName, tint: tint(for: event))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.kind.title)
                            .font(.title2.weight(.semibold))
                        Text(event.lifecycle == .scheduled ? "Scheduled" : "Confirmed")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    VStack(alignment: .leading, spacing: 4) {
                        if event.lifecycle == .scheduled {
                            let window = RelativeTime.scheduledWindow(until: event.scheduledFor, now: context.date)
                            Text(window.phrase)
                                .font(.title3.weight(.semibold))
                            if let when = event.scheduledFor {
                                Text("By \(RelativeTime.stamp(when, display: model.state.timeDisplay, includeWeekday: true))")
                            }
                            if window.passed {
                                Text("Still scheduled. A passed time is not a completed reset.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(RelativeTime.elapsed(from: event.announcedAt, now: context.date).phrase)
                                .font(.title3.weight(.semibold))
                            Text(RelativeTime.stamp(event.announcedAt, display: model.state.timeDisplay))
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                if !event.text.isEmpty {
                    Text(event.text)
                        .font(.body)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let source = event.sourceURL {
                    Link(destination: source) {
                        Label("View announcement", systemImage: "arrow.up.right")
                    }
                    .font(.body.weight(.semibold))
                }
                AttributionFooter()
                    .padding(.top, 8)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tint(for event: ResetEvent) -> Color {
        switch event.kind {
        case .full, .combined: return Palette.ember(scheme)
        case .banked: return Palette.teal(scheme)
        case .unclassified: return .secondary
        }
    }
}
