import Foundation

public struct ElapsedTime: Equatable {
    /// Largest unit only: "10d", "4h", "23m", "now".
    public var short: String
    /// Up to two units: "10d 7h", "6h 12m", "23m".
    public var detailed: String
    /// Detailed plus "ago", or "just now".
    public var phrase: String
    public var accessible: String

    public init(short: String, detailed: String, phrase: String, accessible: String) {
        self.short = short
        self.detailed = detailed
        self.phrase = phrase
        self.accessible = accessible
    }
}

public struct ScheduledWindow: Equatable {
    public var compact: String
    public var phrase: String
    public var passed: Bool

    public init(compact: String, phrase: String, passed: Bool) {
        self.compact = compact
        self.phrase = phrase
        self.passed = passed
    }
}

public enum RelativeTime {
    public static func elapsed(from date: Date, now: Date) -> ElapsedTime {
        let seconds = max(0, Int(now.timeIntervalSince(date).rounded(.down)))
        if seconds < 60 {
            return ElapsedTime(short: "now", detailed: "now", phrase: "just now", accessible: "just now")
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return ElapsedTime(
                short: "\(minutes)m",
                detailed: "\(minutes)m",
                phrase: "\(minutes)m ago",
                accessible: "\(minutes) \(minutes == 1 ? "minute" : "minutes") ago"
            )
        }

        let hours = minutes / 60
        let remainMinutes = minutes % 60
        if hours < 24 {
            let detailed = remainMinutes == 0 ? "\(hours)h" : "\(hours)h \(remainMinutes)m"
            let accessible: String
            if remainMinutes == 0 {
                accessible = "\(hours) \(hours == 1 ? "hour" : "hours") ago"
            } else {
                accessible = "\(hours) \(hours == 1 ? "hour" : "hours") \(remainMinutes) \(remainMinutes == 1 ? "minute" : "minutes") ago"
            }
            return ElapsedTime(short: "\(hours)h", detailed: detailed, phrase: "\(detailed) ago", accessible: accessible)
        }

        let days = hours / 24
        let remainHours = hours % 24
        let detailed = remainHours == 0 ? "\(days)d" : "\(days)d \(remainHours)h"
        let accessible: String
        if remainHours == 0 {
            accessible = "\(days) \(days == 1 ? "day" : "days") ago"
        } else {
            accessible = "\(days) \(days == 1 ? "day" : "days") \(remainHours) \(remainHours == 1 ? "hour" : "hours") ago"
        }
        return ElapsedTime(short: "\(days)d", detailed: detailed, phrase: "\(detailed) ago", accessible: accessible)
    }

    /// "Within ~15h" / "< 15h". A passed `scheduledFor` stays scheduled; it is not a completion.
    public static func scheduledWindow(until date: Date?, now: Date) -> ScheduledWindow {
        guard let date else {
            return ScheduledWindow(compact: "soon", phrase: "Time not set", passed: false)
        }
        let seconds = date.timeIntervalSince(now)
        if seconds <= 0 {
            return ScheduledWindow(
                compact: "passed",
                phrase: "Expected time passed",
                passed: true
            )
        }
        let minutes = max(1, Int(ceil(seconds / 60)))
        if minutes < 60 {
            return ScheduledWindow(
                compact: "< \(minutes)m",
                phrase: "Within ~\(minutes)m",
                passed: false
            )
        }
        let hours = Int(ceil(Double(minutes) / 60.0))
        return ScheduledWindow(
            compact: "< \(hours)h",
            phrase: "Within ~\(hours)h",
            passed: false
        )
    }

    /// "Sep 12 · 08:09" or "Wed 23 Sep · 06:59". 24-hour clock, no extra precision.
    public static func stamp(
        _ date: Date,
        timeZone: TimeZone,
        locale: Locale = Locale(identifier: "en_US"),
        includeWeekday: Bool = false
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = includeWeekday ? "EEE d MMM" : "MMM d"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.timeZone = timeZone
        timeFormatter.dateFormat = "HH:mm"

        return "\(dateFormatter.string(from: date)) · \(timeFormatter.string(from: date))"
    }

    public static func stamp(
        _ date: Date,
        display: TimeDisplay,
        locale: Locale = .current,
        includeWeekday: Bool = false
    ) -> String {
        let text = stamp(date, timeZone: display.timeZone, locale: locale, includeWeekday: includeWeekday)
        if display == .utc {
            return text + " UTC"
        }
        return text
    }
}
