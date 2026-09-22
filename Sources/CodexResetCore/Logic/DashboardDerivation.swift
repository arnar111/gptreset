import Foundation

public enum HistoryFilter: String, CaseIterable, Equatable {
    case all
    case full
    case banked

    public func includes(_ event: ResetEvent) -> Bool {
        switch self {
        case .all:
            return true
        case .full:
            return event.kind == .full || event.kind == .combined
        case .banked:
            return event.kind == .banked || event.kind == .combined
        }
    }
}

public enum DashboardDerivation {
    public static func latestFull(in state: PersistedState) -> ResetEvent? {
        state.events
            .filter(\.isConfirmedFullReset)
            .max { lhs, rhs in
                if lhs.announcedAt == rhs.announcedAt { return lhs.id < rhs.id }
                return lhs.announcedAt < rhs.announcedAt
            }
    }

    public static func latestConfirmed(in state: PersistedState) -> ResetEvent? {
        state.events.max { lhs, rhs in
            if lhs.announcedAt == rhs.announcedAt { return lhs.id < rhs.id }
            return lhs.announcedAt < rhs.announcedAt
        }
    }

    public static func isCelebrating(_ state: PersistedState, now: Date) -> Bool {
        guard state.celebrationHours > 0, let full = latestFull(in: state) else { return false }
        let age = now.timeIntervalSince(full.announcedAt)
        let window = TimeInterval(state.celebrationHours) * 3600
        return age >= 0 && age <= window
    }

    public static func recent(_ state: PersistedState, limit: Int = 4) -> [ResetEvent] {
        Array(history(state, filter: .all).prefix(limit))
    }

    public static func history(_ state: PersistedState, filter: HistoryFilter) -> [ResetEvent] {
        var rows = state.events
        if let scheduled = state.scheduled, !rows.contains(where: { $0.id == scheduled.id }) {
            rows.append(scheduled)
        }
        return rows
            .filter(filter.includes)
            .sorted { lhs, rhs in
                if lhs.announcedAt == rhs.announcedAt { return lhs.id > rhs.id }
                return lhs.announcedAt > rhs.announcedAt
            }
    }

    public static func event(id: String, in state: PersistedState) -> ResetEvent? {
        if let scheduled = state.scheduled, scheduled.id == id {
            return scheduled
        }
        return state.events.first { $0.id == id }
    }
}
