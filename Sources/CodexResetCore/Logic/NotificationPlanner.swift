import Foundation

public enum NotificationPlanner {
    public static func plan(
        events: [ResetEvent],
        preferences: NotificationPreferences,
        alreadyNotified: Set<String>,
        timeZone: TimeZone,
        locale: Locale = Locale(identifier: "en_US"),
        limit: Int = 5
    ) -> [PlannedNotification] {
        let fresh = events
            .filter { !alreadyNotified.contains($0.dedupeKey) }
            .filter { $0.kind != .unclassified }
            .sorted { lhs, rhs in
                if lhs.announcedAt == rhs.announcedAt { return lhs.id < rhs.id }
                return lhs.announcedAt > rhs.announcedAt
            }

        var planned: [PlannedNotification] = []
        for event in fresh.prefix(limit) {
            guard let note = make(event: event, preferences: preferences, timeZone: timeZone, locale: locale) else {
                continue
            }
            planned.append(note)
        }
        return planned
    }

    private static func make(
        event: ResetEvent,
        preferences: NotificationPreferences,
        timeZone: TimeZone,
        locale: Locale
    ) -> PlannedNotification? {
        let kind = notificationKind(for: event)
        guard allowed(kind, preferences: preferences) else { return nil }

        let title: String
        let body: String
        switch kind {
        case .full:
            title = "🔥 Codex Full Reset"
            body = "Usage limits have been reset."
        case .banked:
            title = "🏦 Banked Reset Available"
            body = "A reset has been added to your bank."
        case .combined:
            title = "🔥 + 🏦 Double Reset"
            body = "Usage was reset and a banked reset was added."
        case .scheduled:
            title = "⏳ Codex Reset Scheduled"
            if let when = event.scheduledFor {
                let stamp = RelativeTime.stamp(when, timeZone: timeZone, locale: locale, includeWeekday: true)
                body = "A new reset has been announced. Expected by \(stamp)."
            } else {
                body = "A new reset has been announced."
            }
        }

        return PlannedNotification(
            dedupeKey: event.dedupeKey,
            kind: kind,
            title: title,
            body: body,
            eventID: event.id,
            deepLink: "\(ResetTrackerDefaults.urlScheme)://event/\(event.id)"
        )
    }

    private static func notificationKind(for event: ResetEvent) -> PlannedNotification.Kind {
        if event.lifecycle == .scheduled {
            return .scheduled
        }
        switch event.kind {
        case .full:
            return .full
        case .banked:
            return .banked
        case .combined:
            return .combined
        case .unclassified:
            return .full
        }
    }

    private static func allowed(_ kind: PlannedNotification.Kind, preferences: NotificationPreferences) -> Bool {
        switch kind {
        case .full:
            return preferences.fullResets
        case .banked:
            return preferences.bankedResets
        case .scheduled:
            return preferences.scheduledResets
        case .combined:
            return preferences.fullResets || preferences.bankedResets
        }
    }
}
