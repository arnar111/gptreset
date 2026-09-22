import Foundation

public enum StateReducer {
    /// Merges a status payload and/or a history page into local state.
    /// Pass nil for a payload that came back `304 Not Modified`.
    /// The first successful merge establishes a baseline and does not notify for rows that already existed.
    public static func merge(
        state: PersistedState,
        status: NormalizedStatus?,
        history: [ResetEvent]?,
        timeZone: TimeZone
    ) -> ReduceResult {
        var next = state
        let before = signature(of: state)

        var byID: [String: ResetEvent] = [:]
        for event in state.events where event.lifecycle == .confirmed {
            byID[event.id] = event
        }
        if let history {
            for event in history where event.lifecycle == .confirmed {
                byID[event.id] = event
            }
        }
        if let latest = status?.latestReset, latest.lifecycle == .confirmed {
            byID[latest.id] = latest
        }

        if let status {
            if var scheduled = status.scheduledReset {
                scheduled.lifecycle = .scheduled
                if byID[scheduled.id]?.lifecycle == .confirmed {
                    next.scheduled = nil
                } else {
                    next.scheduled = scheduled
                }
            } else {
                next.scheduled = nil
            }
            next.watch = status.watch
            next.stats = status.stats
        }

        if let scheduled = next.scheduled, byID[scheduled.id]?.lifecycle == .confirmed {
            next.scheduled = nil
        }

        next.events = byID.values.sorted { lhs, rhs in
            if lhs.announcedAt == rhs.announcedAt { return lhs.id > rhs.id }
            return lhs.announcedAt > rhs.announcedAt
        }
        if next.events.count > 300 {
            next.events = Array(next.events.prefix(300))
        }

        let confirmed = next.events.filter { $0.lifecycle == .confirmed }
        let establishing = !state.baselineEstablished
        BankedInventory.ingest(events: confirmed, into: &next.bankedRecords, baseline: establishing)

        var notifications: [PlannedNotification] = []
        let candidateEvents = confirmed + (next.scheduled.map { [$0] } ?? [])
        // Wait for a history page before closing the baseline. A status-only
        // response does not include older banked announcements, and those must
        // not be credited later as if they were new.
        if establishing {
            if history != nil {
                let keys = candidateEvents.map(\.dedupeKey)
                next.notifiedKeys = mergeKeys(existing: next.notifiedKeys, new: keys)
                next.baselineEstablished = true
            }
        } else {
            let known = Set(next.notifiedKeys)
            notifications = NotificationPlanner.plan(
                events: candidateEvents,
                preferences: next.preferences,
                alreadyNotified: known,
                timeZone: timeZone
            )
            let remembered = candidateEvents
                .filter { $0.kind != .unclassified }
                .map(\.dedupeKey)
            next.notifiedKeys = mergeKeys(existing: next.notifiedKeys, new: remembered)
        }

        let reload = signature(of: next) != before
        return ReduceResult(state: next, notifications: notifications, widgetsNeedReload: reload)
    }

    private static func mergeKeys(existing: [String], new: [String]) -> [String] {
        var seen = Set<String>()
        var combined: [String] = []
        for key in existing + new where seen.insert(key).inserted {
            combined.append(key)
        }
        if combined.count > 1000 {
            combined.removeFirst(combined.count - 1000)
        }
        return combined
    }

    private struct Signature: Equatable {
        var fullID: String?
        var fullAt: Date?
        var latestID: String?
        var banked: Int
        var scheduledID: String?
        var scheduledFor: Date?
        var scheduledKind: ResetKind?
    }

    private static func signature(of state: PersistedState) -> Signature {
        let full = DashboardDerivation.latestFull(in: state)
        let latest = DashboardDerivation.latestConfirmed(in: state)
        return Signature(
            fullID: full?.id,
            fullAt: full?.announcedAt,
            latestID: latest?.id,
            banked: BankedInventory.availableCount(state.bankedRecords),
            scheduledID: state.scheduled?.id,
            scheduledFor: state.scheduled?.scheduledFor,
            scheduledKind: state.scheduled?.kind
        )
    }
}
