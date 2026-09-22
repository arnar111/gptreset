import Foundation

public enum BankedInventory {
    /// Banked announcements announced within this window are credited on the
    /// first sync. Older history stays a baseline so an install does not inherit
    /// the whole archive. The current `latest_reset` is also credited when it
    /// adds a banked credit, even if it is older than this window.
    public static let recentBaselineCreditWindow: TimeInterval = 48 * 60 * 60

    public static func availableCount(_ records: [BankedResetRecord]) -> Int {
        records.reduce(0) { count, record in
            record.countsAsAvailable ? count + 1 : count
        }
    }

    /// Marks the oldest available credit used. Returns false at zero and never goes negative.
    @discardableResult
    public static func markOneUsed(_ records: inout [BankedResetRecord], now: Date) -> Bool {
        let candidates = records.indices.filter { records[$0].countsAsAvailable }
        guard let index = candidates.min(by: { lhs, rhs in
            if records[lhs].receivedAt == records[rhs].receivedAt {
                return records[lhs].eventID < records[rhs].eventID
            }
            return records[lhs].receivedAt < records[rhs].receivedAt
        }) else {
            return false
        }
        records[index].usedAt = now
        return true
    }

    /// Sets the visible count without reusing upstream event ids.
    /// Raising the count adds manual rows. Lowering it marks available rows used.
    /// Future API events still credit once, because their ids are new.
    public static func setAvailableCount(_ records: inout [BankedResetRecord], to target: Int, now: Date) {
        let clamped = max(0, target)
        var current = availableCount(records)
        while current < clamped {
            let record = BankedResetRecord(
                eventID: "manual-\(UUID().uuidString.lowercased())",
                receivedAt: now.addingTimeInterval(TimeInterval(current)),
                usedAt: nil,
                origin: .manual
            )
            records.append(record)
            current += 1
        }
        while current > clamped {
            if !markOneUsed(&records, now: now) { break }
            current -= 1
        }
    }

    static func ingest(
        events: [ResetEvent],
        into records: inout [BankedResetRecord],
        baseline: Bool,
        now: Date,
        latestBankedResetID: String?
    ) {
        for event in events where event.addsBankedReset {
            if let index = records.firstIndex(where: { $0.eventID == event.id }) {
                // Installs that already stored this row as baseline can still
                // pick up a recent credit. Ancient baseline rows stay uncounted.
                if records[index].origin == .upstreamBaseline,
                   records[index].usedAt == nil,
                   creditsDuringBaseline(event, now: now, latestBankedResetID: latestBankedResetID) {
                    records[index].origin = .upstreamCredited
                }
                continue
            }
            let credit = !baseline || creditsDuringBaseline(
                event,
                now: now,
                latestBankedResetID: latestBankedResetID
            )
            records.append(
                BankedResetRecord(
                    eventID: event.id,
                    receivedAt: event.announcedAt,
                    usedAt: nil,
                    origin: credit ? .upstreamCredited : .upstreamBaseline
                )
            )
        }
    }

    /// Recent banked announcements, and the current latest reset when it adds a
    /// banked credit, are usable after install. Everything older is remembered
    /// only so a later fetch cannot count it again.
    private static func creditsDuringBaseline(
        _ event: ResetEvent,
        now: Date,
        latestBankedResetID: String?
    ) -> Bool {
        if event.id == latestBankedResetID {
            return true
        }
        return now.timeIntervalSince(event.announcedAt) <= recentBaselineCreditWindow
    }
}
