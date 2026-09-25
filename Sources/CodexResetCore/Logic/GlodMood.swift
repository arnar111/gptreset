import Foundation

/// Glóð is the ember character on the Home Screen widgets and on Status.
/// Its mood follows the same state as the widget text, so it never disagrees
/// with the numbers beside it.
public enum GlodMood: String, Codable, Equatable, CaseIterable {
    /// Inside the full-reset celebration window.
    case celebrating
    /// The newest confirmed announcement added a banked credit and one is still available.
    case rich
    /// Waiting, still inside the typical gap between full resets.
    case content
    /// Waiting longer than the typical gap between full resets.
    case sleepy
    /// No confirmed full reset is cached yet.
    case waiting
}

public enum GlodDerivation {
    /// Typical gap between full resets, in days. Uses `avg_interval_days` from
    /// Codex Resets when it is published, otherwise the mean gap between cached
    /// full resets. Nil when neither is available.
    public static func typicalIntervalDays(in state: PersistedState) -> Double? {
        if let published = state.stats?.averageIntervalDays, published > 0 {
            return published
        }
        let fulls = state.events
            .filter(\.isConfirmedFullReset)
            .map(\.announcedAt)
            .sorted()
        guard fulls.count >= 2 else { return nil }
        let gaps = zip(fulls.dropFirst(), fulls)
            .map { later, earlier in later.timeIntervalSince(earlier) / 86_400 }
            .filter { $0 > 0 }
        guard !gaps.isEmpty else { return nil }
        return gaps.reduce(0, +) / Double(gaps.count)
    }

    public static func mood(in state: PersistedState, now: Date) -> GlodMood {
        if DashboardDerivation.isCelebrating(state, now: now) {
            return .celebrating
        }
        if DashboardDerivation.bankedRecentEvent(in: state, now: now) != nil,
           BankedInventory.availableCount(state.bankedRecords) > 0 {
            return .rich
        }
        guard let full = DashboardDerivation.latestFull(in: state) else {
            return .waiting
        }
        guard let typical = typicalIntervalDays(in: state) else {
            return .content
        }
        let days = now.timeIntervalSince(full.announcedAt) / 86_400
        return days > typical ? .sleepy : .content
    }

    /// Speech bubble on the medium widget and on Status.
    public static func line(for mood: GlodMood, bankedCount: Int) -> String {
        switch mood {
        case .celebrating:
            return "Fresh limits! Go build."
        case .rich:
            return "Ooh, a coin for the jar!"
        case .content:
            return bankedCount > 0 ? "\(bankedCount) in the jar. We're good." : "Keeping the fire warm."
        case .sleepy:
            return bankedCount > 0 ? "Longer than usual. Use a coin?" : "Zzz… longer than usual."
        case .waiting:
            return "Waiting for the first reset."
        }
    }
}
