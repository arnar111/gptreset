import SwiftUI
import CodexResetCore

/// Top of Status: Glóð, what it has to say, and the headline reset.
struct GlodStage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var jumping = false
    @State private var poked = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let mood = GlodDerivation.mood(in: model.state, now: context.date)
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom, spacing: 10) {
                    character(mood: mood)
                        .frame(width: 132, height: 132)
                    Text(GlodDerivation.line(for: mood, bankedCount: model.bankedAvailable))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(GlodPalette.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.bottom, 64)
                        .id(mood)
                        .transition(.scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
                }
                headline(now: context.date)
            }
            .foregroundStyle(.white)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GlodBackground(mood: mood)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .animation(.spring(duration: 0.6, bounce: 0.3), value: mood)
        }
    }

    private func character(mood: GlodMood) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let pose = currentPose(mood: mood, at: timeline.date)
            GlodCharacter(mood: mood, pose: pose)
        }
        .scaleEffect(jumping ? 1.08 : 1, anchor: .bottom)
        .offset(y: jumping ? -26 : 0)
        .contentShape(Rectangle())
        .onTapGesture(perform: poke)
        .accessibilityElement()
        .accessibilityLabel("Glóð")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Poke", poke)
    }

    private func currentPose(mood: GlodMood, at date: Date) -> GlodPose {
        var pose = reduceMotion ? GlodPose.rest : GlodPose.live(at: date.timeIntervalSinceReferenceDate, mood: mood)
        pose.poked = poked
        return pose
    }

    private func poke() {
        Haptics.success()
        withAnimation(.spring(duration: 0.25, bounce: 0.4)) {
            jumping = true
            poked = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(240))
            withAnimation(.spring(duration: 0.5, bounce: 0.55)) {
                jumping = false
            }
            try? await Task.sleep(for: .milliseconds(900))
            poked = false
        }
    }

    @ViewBuilder
    private func headline(now: Date) -> some View {
        let full = DashboardDerivation.latestFull(in: model.state)
        let display = model.state.timeDisplay
        VStack(alignment: .leading, spacing: 6) {
            if let recent = DashboardDerivation.bankedRecentEvent(in: model.state, now: now) {
                eyebrow(recent.kind == .combined ? "Full + banked" : "Banked reset")
                Text("+1 · \(RelativeTime.elapsed(from: recent.announcedAt, now: now).phrase)")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .contentTransition(.numericText())
                Text(RelativeTime.stamp(recent.announcedAt, display: display))
                    .font(.callout)
                    .opacity(0.85)
                if let full, full.id != recent.id {
                    Text("Full reset \(RelativeTime.elapsed(from: full.announcedAt, now: now).phrase)")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .padding(.top, 2)
                }
                announcement(recent.text)
            } else if let full {
                let elapsed = RelativeTime.elapsed(from: full.announcedAt, now: now)
                let celebrating = DashboardDerivation.isCelebrating(model.state, now: now)
                eyebrow(celebrating ? "Full reset · 100% reset" : "Since the last full reset")
                Text(celebrating ? "RESET!" : elapsed.detailed)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                Text(celebrating ? "\(elapsed.phrase) · \(RelativeTime.stamp(full.announcedAt, display: display))" : RelativeTime.stamp(full.announcedAt, display: display))
                    .font(.callout)
                    .opacity(0.85)
                if let typical = GlodDerivation.typicalIntervalDays(in: model.state), !celebrating {
                    Text("Usual gap about \(typical.formatted(.number.precision(.fractionLength(0...1)))) days")
                        .font(.footnote)
                        .opacity(0.8)
                }
                announcement(full.text)
            } else {
                eyebrow("Latest full reset")
                Text("No full reset yet")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Pull to refresh once Codex Resets has published one.")
                    .font(.callout)
                    .opacity(0.85)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(.caption, design: .rounded, weight: .bold))
            .tracking(0.8)
            .opacity(0.85)
    }

    @ViewBuilder
    private func announcement(_ text: String) -> some View {
        if !text.isEmpty {
            Text(text)
                .font(.callout)
                .lineLimit(3)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 4)
        }
    }
}

/// The bank is the loudest number on Status after Glóð.
struct GlodBankCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let count = model.bankedAvailable
        TrackerCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("BANKED")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Palette.teal(scheme))
                    Spacer()
                    Text(count == 1 ? "reset available" : "resets available")
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .center, spacing: 16) {
                    Text("\(count)")
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText(value: Double(count)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    GlodJar(count: count)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .animation(.spring(duration: 0.55, bounce: 0.45), value: count)
                Button {
                    model.markOneUsed()
                } label: {
                    Text("Use one")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Palette.teal(scheme))
                .disabled(count == 0)
                .accessibilityLabel("Mark one banked reset as used")
                .accessibilityHint(count == 0 ? "None available" : "Decreases the count by one")
                Text("Counted on this iPhone. A full reset does not clear them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Coins drop in from the top when a banked reset arrives and pop out when one is used.
struct GlodJar: View {
    var count: Int
    private let shown = 8

    var body: some View {
        let columns = Array(repeating: GridItem(.fixed(24), spacing: 4), count: 4)
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            ForEach(0..<min(count, shown), id: \.self) { _ in
                GlodCoin()
                    .frame(width: 24, height: 24)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.2).combined(with: .opacity)
                    ))
            }
            if count > shown {
                Text("+\(count - shown)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            if count == 0 {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .frame(width: 24, height: 24)
            }
        }
        .accessibilityHidden(true)
    }
}
