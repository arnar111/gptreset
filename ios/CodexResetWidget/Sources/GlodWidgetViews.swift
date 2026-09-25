import SwiftUI
import WidgetKit
import CodexResetCore

/// Glóð look for the Home Screen. The bank is the largest number on both sizes.
/// WidgetKit cannot run a continuous animation, so Glóð moves between timeline
/// entries (one pose per minute) and when tapped. See `GlodPose.widgetCycle`.
enum GlodWidget {
    static let motion = Animation.spring(duration: 1.2, bounce: 0.45)
    static let ink = GlodPalette.ink
    static let soft = Color.white.opacity(0.82)
    static let panel = Color.white.opacity(0.18)
}

struct GlodSmallView: View {
    var content: WidgetContent
    var pose: GlodPose

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                GlodPokeButton(mood: content.mood, pose: pose)
                    .frame(width: 64, height: 64)
                    .offset(x: -6, y: -4)
                Spacer(minLength: 2)
                VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: 4) {
                        GlodCoin()
                            .frame(width: 18, height: 18)
                        Text("\(content.bankedCount)")
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .contentTransition(.numericText(value: Double(content.bankedCount)))
                            .widgetAccentable()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                    Text("banked")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(GlodWidget.soft)
                }
            }
            Spacer(minLength: 0)
            Text(GlodText.primary(content))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(GlodText.secondary(content))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(GlodWidget.soft)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(GlodWidget.motion, value: pose)
        .animation(GlodWidget.motion, value: content.bankedCount)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(content.accessibilityLabel)
    }
}

struct GlodMediumView: View {
    var content: WidgetContent
    var pose: GlodPose

    var body: some View {
        HStack(spacing: 10) {
            GlodPokeButton(mood: content.mood, pose: pose)
                .frame(width: 92, height: 92)
                .frame(maxHeight: .infinity, alignment: .bottom)

            VStack(alignment: .leading, spacing: 4) {
                Text(content.moodLine)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(GlodWidget.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .transition(.scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
                    .id(content.moodLine)
                Spacer(minLength: 0)
                Text(GlodText.fullEyebrow(content))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(GlodWidget.soft)
                Text(GlodText.primary(content))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text(GlodText.mediumSecondary(content))
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(GlodWidget.soft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            GlodBankPanel(content: content)
                .frame(width: 112)
        }
        .foregroundStyle(.white)
        .animation(GlodWidget.motion, value: pose)
        .animation(GlodWidget.motion, value: content.bankedCount)
        .animation(GlodWidget.motion, value: content.moodLine)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(content.accessibilityLabel)
    }
}

/// Banked-only small widget in the Glóð look.
struct GlodBankedSmallView: View {
    var count: Int
    var mood: GlodMood
    var pose: GlodPose
    var hasState: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top) {
                Text("BANKED")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(GlodWidget.soft)
                Spacer(minLength: 0)
                GlodPokeButton(mood: mood, pose: pose)
                    .frame(width: 44, height: 44)
                    .offset(x: 4, y: -6)
            }
            HStack(alignment: .center, spacing: 6) {
                GlodCoin()
                    .frame(width: 26, height: 26)
                Text("\(count)")
                    .font(.system(size: 50, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText(value: Double(count)))
                    .widgetAccentable()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            Text(count == 1 ? "reset available" : "resets available")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(GlodWidget.soft)
            Spacer(minLength: 0)
            if count > 0, hasState {
                GlodUseOneButton()
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(GlodWidget.motion, value: pose)
        .animation(GlodWidget.motion, value: count)
    }
}

struct GlodBankPanel: View {
    var content: WidgetContent

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("BANKED")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(GlodWidget.soft)
            Text("\(content.bankedCount)")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .contentTransition(.numericText(value: Double(content.bankedCount)))
                .widgetAccentable()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            GlodCoinRow(count: content.bankedCount)
            Text(content.bankedCue ?? "available")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(content.bankedCue == nil ? GlodWidget.soft : Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if content.bankedCount > 0 {
                GlodUseOneButton()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(GlodWidget.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Up to six coins, then "+n".
struct GlodCoinRow: View {
    var count: Int

    var body: some View {
        HStack(spacing: -4) {
            ForEach(0..<min(count, 6), id: \.self) { _ in
                GlodCoin()
                    .frame(width: 14, height: 14)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }
            if count > 6 {
                Text("+\(count - 6)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.leading, 6)
            }
            if count == 0 {
                Circle()
                    .strokeBorder(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .frame(width: 14, height: 14)
            }
        }
        .frame(height: 14)
    }
}

struct GlodPokeButton: View {
    var mood: GlodMood
    var pose: GlodPose

    var body: some View {
        Button(intent: PokeGlodIntent()) {
            GlodCharacter(mood: mood, pose: pose)
                .widgetAccentable()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Poke Glóð")
    }
}

struct GlodUseOneButton: View {
    var body: some View {
        Button(intent: MarkBankedResetUsedIntent()) {
            Text("Use one")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(GlodWidget.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.92), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Used banked reset")
    }
}

enum GlodText {
    static func primary(_ content: WidgetContent) -> String {
        switch content.mode {
        case .celebration:
            return "RESET!"
        case .bankedRecent:
            return "+1 banked"
        case .tracking, .scheduled:
            return content.headline
        case .empty:
            return "No reset yet"
        }
    }

    static func secondary(_ content: WidgetContent) -> String {
        switch content.mode {
        case .celebration:
            return content.ago
        case .bankedRecent:
            if let full = content.fullAgeCompact {
                return "\(content.ago) · \(full) full"
            }
            return content.ago
        case .tracking:
            return "since full reset"
        case .scheduled:
            return "reset scheduled"
        case .empty:
            return content.ago
        }
    }

    static func fullEyebrow(_ content: WidgetContent) -> String {
        switch content.mode {
        case .celebration, .tracking:
            return "FULL"
        case .bankedRecent:
            return "NEW"
        case .scheduled:
            return "NEXT"
        case .empty:
            return "CODEX"
        }
    }

    static func mediumSecondary(_ content: WidgetContent) -> String {
        switch content.mode {
        case .celebration:
            return content.ago
        case .bankedRecent:
            if let full = content.fullAgeDetailed {
                return "\(content.ago) · \(full) since full"
            }
            return content.ago
        case .tracking:
            if let next = content.scheduledCompact {
                return "since full · next \(next)"
            }
            return "since full reset"
        case .scheduled:
            return content.stamp
        case .empty:
            return content.ago
        }
    }
}
