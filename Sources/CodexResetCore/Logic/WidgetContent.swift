import Foundation

public struct WidgetContent: Equatable {
    public enum Mode: String, Equatable {
        case empty
        case celebration
        case tracking
        case scheduled
        /// Newest confirmed event added a banked credit, and full celebration is not active.
        case bankedRecent
    }

    public var mode: Mode
    public var symbolName: String
    /// Lock Screen and other tight surfaces. Celebration stays "RESET".
    public var compactValue: String
    /// Home Screen headline. Celebration is "RESET!"; tracking is two units ("10d 7h").
    public var headline: String
    public var caption: String
    public var ago: String
    public var stamp: String
    public var bankedCount: Int
    public var scheduledCompact: String?
    public var scheduledPhrase: String?
    /// Largest unit of the last full reset, such as "10d", when the hero is banked.
    public var fullAgeCompact: String?
    /// Up to two units of the last full reset, such as "10d 7h", when the hero is banked.
    public var fullAgeDetailed: String?
    /// Set when the newest confirmed announcement added a banked credit, including during full celebration.
    /// Example: "+1 · 3h ago". The medium widget shows this on the banked half.
    public var bankedCue: String?
    /// Glóð's mood for this moment. See `GlodDerivation`.
    public var mood: GlodMood
    /// Glóð's speech bubble on the medium widget.
    public var moodLine: String
    public var accessibilityLabel: String

    public init(
        mode: Mode,
        symbolName: String,
        compactValue: String,
        headline: String,
        caption: String,
        ago: String,
        stamp: String,
        bankedCount: Int,
        scheduledCompact: String?,
        scheduledPhrase: String?,
        fullAgeCompact: String? = nil,
        fullAgeDetailed: String? = nil,
        bankedCue: String? = nil,
        mood: GlodMood = .content,
        moodLine: String = "",
        accessibilityLabel: String
    ) {
        self.mode = mode
        self.symbolName = symbolName
        self.compactValue = compactValue
        self.headline = headline
        self.caption = caption
        self.ago = ago
        self.stamp = stamp
        self.bankedCount = bankedCount
        self.scheduledCompact = scheduledCompact
        self.scheduledPhrase = scheduledPhrase
        self.fullAgeCompact = fullAgeCompact
        self.fullAgeDetailed = fullAgeDetailed
        self.bankedCue = bankedCue
        self.mood = mood
        self.moodLine = moodLine
        self.accessibilityLabel = accessibilityLabel
    }
}

public enum WidgetContentBuilder {
    public static func make(state: PersistedState, now: Date, locale: Locale = Locale(identifier: "en_US")) -> WidgetContent {
        var content = makeText(state: state, now: now, locale: locale)
        content.mood = GlodDerivation.mood(in: state, now: now)
        content.moodLine = GlodDerivation.line(for: content.mood, bankedCount: content.bankedCount)
        return content
    }

    private static func makeText(state: PersistedState, now: Date, locale: Locale) -> WidgetContent {
        let full = DashboardDerivation.latestFull(in: state)
        let banked = BankedInventory.availableCount(state.bankedRecords)
        let celebrating = DashboardDerivation.isCelebrating(state, now: now)
        let window = state.scheduled?.scheduledFor.map { RelativeTime.scheduledWindow(until: $0, now: now) }
            ?? (state.scheduled == nil ? nil : RelativeTime.scheduledWindow(until: nil, now: now))
        let bankedCue = bankedAdditionCue(in: state, now: now)

        if celebrating, let full {
            let elapsed = RelativeTime.elapsed(from: full.announcedAt, now: now)
            let stamp = RelativeTime.stamp(full.announcedAt, timeZone: state.timeDisplay.timeZone, locale: locale)
            return WidgetContent(
                mode: .celebration,
                symbolName: "flame.fill",
                compactValue: "RESET",
                headline: "RESET!",
                caption: "100% reset",
                ago: elapsed.phrase,
                stamp: stamp,
                bankedCount: banked,
                scheduledCompact: window?.compact,
                scheduledPhrase: window?.phrase,
                bankedCue: bankedCue,
                accessibilityLabel: "Full reset, \(elapsed.accessible). \(banked) banked \(banked == 1 ? "reset" : "resets") available."
            )
        }

        if let bankedEvent = DashboardDerivation.bankedRecentEvent(in: state, now: now) {
            let elapsed = RelativeTime.elapsed(from: bankedEvent.announcedAt, now: now)
            let fullElapsed = full.map { RelativeTime.elapsed(from: $0.announcedAt, now: now) }
            var label = "Banked reset added \(elapsed.accessible). \(banked) banked \(banked == 1 ? "reset" : "resets") available."
            if let fullElapsed {
                label += " Last full reset \(fullElapsed.accessible)."
            }
            if let window, let scheduled = state.scheduled {
                label += " Next reset \(window.phrase)."
                if let when = scheduled.scheduledFor {
                    label += " By \(RelativeTime.stamp(when, timeZone: state.timeDisplay.timeZone, locale: locale, includeWeekday: true))."
                }
            }
            return WidgetContent(
                mode: .bankedRecent,
                symbolName: "building.columns.fill",
                compactValue: "+1",
                headline: "BANKED",
                caption: "+1",
                ago: elapsed.phrase,
                stamp: fullElapsed?.detailed ?? "",
                bankedCount: banked,
                scheduledCompact: window?.compact,
                scheduledPhrase: window?.phrase,
                fullAgeCompact: fullElapsed?.short,
                fullAgeDetailed: fullElapsed?.detailed,
                bankedCue: bankedCue,
                accessibilityLabel: label
            )
        }

        if let full {
            let elapsed = RelativeTime.elapsed(from: full.announcedAt, now: now)
            let stamp = RelativeTime.stamp(full.announcedAt, timeZone: state.timeDisplay.timeZone, locale: locale)
            var label = "Last full reset \(elapsed.accessible). \(banked) banked available."
            if let window, let scheduled = state.scheduled {
                label += " Next reset \(window.phrase)."
                if let when = scheduled.scheduledFor {
                    label += " By \(RelativeTime.stamp(when, timeZone: state.timeDisplay.timeZone, locale: locale, includeWeekday: true))."
                }
            }
            return WidgetContent(
                mode: .tracking,
                symbolName: "flame.fill",
                compactValue: elapsed.short,
                headline: elapsed.detailed,
                caption: "since full reset",
                ago: elapsed.phrase,
                stamp: stamp,
                bankedCount: banked,
                scheduledCompact: window?.compact,
                scheduledPhrase: window?.phrase,
                bankedCue: bankedCue,
                accessibilityLabel: label
            )
        }

        if let scheduled = state.scheduled, let window {
            let stamp = scheduled.scheduledFor.map {
                RelativeTime.stamp($0, timeZone: state.timeDisplay.timeZone, locale: locale, includeWeekday: true)
            } ?? "Time not set"
            return WidgetContent(
                mode: .scheduled,
                symbolName: "hourglass",
                compactValue: window.compact,
                headline: window.compact,
                caption: "reset scheduled",
                ago: window.phrase,
                stamp: stamp,
                bankedCount: banked,
                scheduledCompact: window.compact,
                scheduledPhrase: window.phrase,
                bankedCue: bankedCue,
                accessibilityLabel: "Reset scheduled, \(window.phrase). \(banked) banked available."
            )
        }

        return WidgetContent(
            mode: .empty,
            symbolName: "flame",
            compactValue: "—",
            headline: "—",
            caption: "No reset yet",
            ago: "Open the app",
            stamp: "",
            bankedCount: banked,
            scheduledCompact: nil,
            scheduledPhrase: nil,
            bankedCue: bankedCue,
            accessibilityLabel: "No reset data yet. \(banked) banked available."
        )
    }

    /// Cue for the medium widget's banked half. Independent of celebration:
    /// a newer banked credit still shows here while the full half says RESET!.
    private static func bankedAdditionCue(in state: PersistedState, now: Date) -> String? {
        guard let latest = DashboardDerivation.latestConfirmed(in: state), latest.addsBankedReset else { return nil }
        let elapsed = RelativeTime.elapsed(from: latest.announcedAt, now: now)
        return "+1 · \(elapsed.phrase)"
    }
}
