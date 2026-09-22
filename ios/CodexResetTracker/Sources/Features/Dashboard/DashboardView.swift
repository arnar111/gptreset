import SwiftUI
import CodexResetCore

struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if model.state.lastRefreshFailed {
                        Text(model.state.events.isEmpty && model.state.scheduled == nil
                             ? "Unable to refresh. Check the connection and pull to try again."
                             : "Unable to refresh. Showing the last saved update.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Unable to refresh")
                    }

                    hero
                    bankedCard
                    nextCard
                    recentSection
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Codex Resets")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .refreshable {
                await model.refresh(force: true)
            }
            .navigationDestination(item: Binding(
                get: { model.presentedEventID },
                set: { model.presentedEventID = $0 }
            )) { eventID in
                ResetDetailView(eventID: eventID)
            }
        }
    }

    @ViewBuilder
    private var hero: some View {
        let full = DashboardDerivation.latestFull(in: model.state)
        let celebrating = DashboardDerivation.isCelebrating(model.state, now: Date())
        TrackerCard {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        KindGlyph(systemName: "flame.fill", tint: Palette.ember(scheme))
                        Text(celebrating ? "Full reset" : "Latest full reset")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ember(scheme))
                    }
                    if let full {
                        let elapsed = RelativeTime.elapsed(from: full.announcedAt, now: context.date)
                        if celebrating {
                            Text("100% reset")
                                .font(.title2.weight(.semibold))
                        }
                        Text(elapsed.phrase)
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .minimumScaleFactor(0.7)
                            .lineLimit(2)
                        Text(RelativeTime.stamp(full.announcedAt, display: model.state.timeDisplay))
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text(full.text)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                            .padding(.top, 4)
                    } else {
                        Text("No full reset yet")
                            .font(.title2.weight(.semibold))
                        Text("Pull to refresh once Codex Resets has published one.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var bankedCard: some View {
        TrackerCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    KindGlyph(systemName: "building.columns.fill", tint: Palette.teal(scheme))
                    Text("Banked resets")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.teal(scheme))
                }
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    Text("\(model.bankedAvailable) available")
                        .font(.system(.title, design: .rounded, weight: .bold))
                }
                Text("Counted on this iPhone. A full reset does not clear them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    model.markOneUsed()
                } label: {
                    Text("Mark one as used")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.teal(scheme))
                .disabled(model.bankedAvailable == 0)
                .accessibilityLabel("Mark one banked reset as used")
                .accessibilityHint(model.bankedAvailable == 0 ? "None available" : "Decreases the count by one")
            }
        }
    }

    @ViewBuilder
    private var nextCard: some View {
        TrackerCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    KindGlyph(systemName: "hourglass", tint: Palette.dusk(scheme))
                    Text("Next reset")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.dusk(scheme))
                }
                if let scheduled = model.state.scheduled {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        let window = RelativeTime.scheduledWindow(until: scheduled.scheduledFor, now: context.date)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Scheduled")
                                .font(.title3.weight(.semibold))
                            Text(window.phrase)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                            if let when = scheduled.scheduledFor {
                                Text("By \(RelativeTime.stamp(when, display: model.state.timeDisplay, includeWeekday: true))")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No exact time was announced.")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            if window.passed {
                                Text("The expected time has passed. This is not a completed reset.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if !scheduled.text.isEmpty {
                        Text(scheduled.text)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .lineLimit(4)
                    }
                } else if let watch = model.state.watch, watch.isActive(at: Date()) {
                    Text("Forecast")
                        .font(.title3.weight(.semibold))
                    Text(watch.text.isEmpty ? "Codex Resets is watching for a reset." : watch.text)
                        .font(.callout)
                    Text("A forecast is not a scheduled reset and not an OpenAI commitment.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Nothing scheduled")
                        .font(.title3.weight(.semibold))
                    Text("When Codex Resets publishes a coming reset, it will show here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent activity")
                .font(.headline)
            let rows = DashboardDerivation.recent(model.state, limit: 4)
            if rows.isEmpty {
                Text("No announcements cached yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(rows, id: \.dedupeKey) { event in
                        Button {
                            model.presentedEventID = event.id
                        } label: {
                            HistoryRow(event: event, timeDisplay: model.state.timeDisplay)
                        }
                        .buttonStyle(.plain)
                        if event.id != rows.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                if let updated = model.state.lastUpdated {
                    Text("Updated \(RelativeTime.elapsed(from: updated, now: context.date).phrase)")
                } else {
                    Text("Not updated yet")
                }
            }
            .font(.footnote)
            .foregroundStyle(.tertiary)
            AttributionFooter()
        }
        .padding(.top, 4)
    }
}
