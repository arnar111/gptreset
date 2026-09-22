import Foundation

public struct RefreshOutcome: Equatable {
    public var state: PersistedState
    public var notifications: [PlannedNotification]
    public var widgetsNeedReload: Bool
    /// True when this refresh failed and previously saved rows are still being shown.
    public var usedCache: Bool

    public init(state: PersistedState, notifications: [PlannedNotification], widgetsNeedReload: Bool, usedCache: Bool) {
        self.state = state
        self.notifications = notifications
        self.widgetsNeedReload = widgetsNeedReload
        self.usedCache = usedCache
    }
}

public enum RefreshService {
    public static func refresh(
        state: PersistedState,
        fetcher: ResetFetching,
        now: Date,
        timeZone: TimeZone
    ) async -> RefreshOutcome {
        let statusOutcome = await catching { try await fetcher.fetchStatus(etag: state.statusETag) }
        let historyOutcome = await catching { try await fetcher.fetchHistory(etag: state.historyETag) }

        switch (statusOutcome, historyOutcome) {
        case let (.success(statusResult), .success(historyResult)):
            return apply(
                state: state,
                status: statusResult,
                history: historyResult,
                now: now,
                timeZone: timeZone,
                partialFailure: false
            )
        case let (.success(statusResult), .failure(error)):
            CodexLog.debug("History refresh failed, merging status only: \(error)")
            return apply(
                state: state,
                status: statusResult,
                history: nil,
                now: now,
                timeZone: timeZone,
                partialFailure: true
            )
        case let (.failure(error), .success(historyResult)):
            CodexLog.debug("Status refresh failed, merging history only: \(error)")
            return apply(
                state: state,
                status: nil,
                history: historyResult,
                now: now,
                timeZone: timeZone,
                partialFailure: true
            )
        case let (.failure(statusError), .failure(historyError)):
            CodexLog.debug("Refresh failed, keeping cached resets: \(statusError) / \(historyError)")
            var cached = state
            cached.lastRefreshFailed = true
            let hasCache = !state.events.isEmpty || state.scheduled != nil || state.lastUpdated != nil
            return RefreshOutcome(state: cached, notifications: [], widgetsNeedReload: false, usedCache: hasCache)
        }
    }

    private static func apply(
        state: PersistedState,
        status: ConditionalPayload<NormalizedStatus>?,
        history: ConditionalPayload<[ResetEvent]>?,
        now: Date,
        timeZone: TimeZone,
        partialFailure: Bool
    ) -> RefreshOutcome {
        let statusNotModified = status?.notModified ?? true
        let historyNotModified = history?.notModified ?? true
        if statusNotModified && historyNotModified && !partialFailure {
            var unchanged = state
            unchanged.lastUpdated = now
            unchanged.lastRefreshFailed = false
            if let etag = status?.etag { unchanged.statusETag = etag }
            if let etag = history?.etag { unchanged.historyETag = etag }
            return RefreshOutcome(state: unchanged, notifications: [], widgetsNeedReload: false, usedCache: false)
        }

        let reduced = StateReducer.merge(
            state: state,
            status: statusNotModified ? nil : status?.value,
            history: historyNotModified ? nil : history?.value,
            timeZone: timeZone
        )
        var next = reduced.state
        next.lastUpdated = now
        next.lastRefreshFailed = partialFailure
        if let etag = status?.etag { next.statusETag = etag }
        if let etag = history?.etag { next.historyETag = etag }
        let hasCache = !state.events.isEmpty || state.scheduled != nil
        return RefreshOutcome(
            state: next,
            notifications: reduced.notifications,
            widgetsNeedReload: reduced.widgetsNeedReload,
            usedCache: partialFailure && hasCache
        )
    }

    private static func catching<T>(_ body: () async throws -> T) async -> Result<T, Error> {
        do {
            return .success(try await body())
        } catch {
            return .failure(error)
        }
    }
}
