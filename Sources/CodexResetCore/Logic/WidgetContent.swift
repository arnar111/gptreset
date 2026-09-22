import Foundation

public struct WidgetContent: Equatable {
    public enum Mode: String, Equatable {
        case empty
        case celebration
        case tracking
        case scheduled
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
        self.accessibilityLabel = accessibilityLabel
    }
}

public enum WidgetContentBuilder {
    public static func make(state: PersistedState, now: Date, locale: Locale = Locale(identifier: "en_US")) -> WidgetContent {
        let full = DashboardDerivation.latestFull(in: state)
        let banked = BankedInventory.availableCount(state.bankedRecords)
        let celebrating = DashboardDerivation.isCelebrating(state, now: now)
        let window = state.scheduled?.scheduledFor.map { RelativeTime.scheduledWindow(until: $0, now: now) }
            ?? (state.scheduled == nil ? nil : RelativeTime.scheduledWindow(until: nil, now: now))

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
                accessibilityLabel: "Full reset, \(elapsed.accessible). \(banked) banked \(banked == 1 ? "reset" : "resets") available."
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
            accessibilityLabel: "No reset data yet. \(banked) banked available."
        )
    }
}
