import Foundation
import Testing
@testable import CodexResetCore

struct BehaviorTests {
    private let utc = TimeZone(secondsFromGMT: 0)!
    private let now = date("2026-09-22T16:00:00Z")

    @Test func fullResetArrivesWithoutChangingBankedCount() {
        var state = trackingState()
        BankedInventory.setAvailableCount(&state.bankedRecords, to: 2, now: now)
        let previousFull = state.events[0]

        let arrived = makeEvent(id: "full-new", kind: .full, at: "2026-09-22T15:00:00Z", text: "Reset all propagated.")
        let result = StateReducer.merge(
            state: state,
            status: status(latest: arrived, scheduled: nil),
            history: [previousFull, arrived],
            timeZone: utc
        )

        #expect(DashboardDerivation.latestFull(in: result.state)?.id == "full-new")
        #expect(BankedInventory.availableCount(result.state.bankedRecords) == 2)
        #expect(result.notifications.map(\.kind) == [.full])
        #expect(result.notifications.first?.title == "🔥 Codex Full Reset")
        #expect(result.widgetsNeedReload)
        #expect(result.state.bankedRecords.contains { $0.origin == .upstreamBaseline } == false)
    }

    @Test func bankedResetIncrementsInventoryOnceAndNotifies() {
        let state = trackingState()
        let banked = makeEvent(id: "bank-1", kind: .banked, at: "2026-09-22T12:00:00Z", text: "One banked reset.")
        let result = StateReducer.merge(
            state: state,
            status: status(latest: banked, scheduled: state.scheduled),
            history: state.events + [banked],
            timeZone: utc
        )

        #expect(BankedInventory.availableCount(result.state.bankedRecords) == 1)
        #expect(result.notifications.map(\.kind) == [.banked])
        #expect(result.notifications.first?.body == "A reset has been added to your bank.")
        #expect(result.widgetsNeedReload)
        #expect(DashboardDerivation.latestFull(in: result.state)?.id == "full-old")
    }

    @Test func sameBankedEventFetchedManyTimesIncrementsOnce() {
        var state = trackingState()
        let banked = makeEvent(id: "bank-1", kind: .banked, at: "2026-09-22T12:00:00Z", text: "One banked reset.")
        var notifications = 0
        for _ in 0..<100 {
            let result = StateReducer.merge(
                state: state,
                status: status(latest: banked, scheduled: nil),
                history: state.events + [banked],
                timeZone: utc
            )
            notifications += result.notifications.count
            state = result.state
        }
        #expect(BankedInventory.availableCount(state.bankedRecords) == 1)
        #expect(notifications == 1)
        #expect(state.bankedRecords.filter { $0.eventID == "bank-1" }.count == 1)
    }

    @Test func combinedResetUpdatesFullAndBankedWithOneNotification() {
        let state = trackingState()
        let combined = makeEvent(id: "both-1", kind: .combined, at: "2026-09-22T15:30:00Z", text: "Reset, and a banked credit.")
        let first = StateReducer.merge(
            state: state,
            status: status(latest: combined, scheduled: nil),
            history: state.events + [combined],
            timeZone: utc
        )
        #expect(DashboardDerivation.latestFull(in: first.state)?.id == "both-1")
        #expect(BankedInventory.availableCount(first.state.bankedRecords) == 1)
        #expect(first.notifications.count == 1)
        #expect(first.notifications.first?.kind == .combined)
        #expect(first.notifications.first?.title == "🔥 + 🏦 Double Reset")

        let second = StateReducer.merge(
            state: first.state,
            status: status(latest: combined, scheduled: nil),
            history: first.state.events,
            timeZone: utc
        )
        #expect(second.notifications.isEmpty)
        #expect(BankedInventory.availableCount(second.state.bankedRecords) == 1)
    }

    @Test func scheduledResetDoesNotCompleteFullReset() {
        let state = trackingState()
        let scheduled = makeEvent(
            id: "sched-1",
            kind: .full,
            at: "2026-09-22T04:31:32Z",
            text: "Reset on Tuesday.",
            lifecycle: .scheduled,
            scheduledFor: date("2026-09-23T06:59:00Z")
        )
        let result = StateReducer.merge(
            state: state,
            status: status(latest: state.events[0], scheduled: scheduled),
            history: state.events,
            timeZone: utc
        )

        #expect(result.state.scheduled?.id == "sched-1")
        #expect(result.state.scheduled?.lifecycle == .scheduled)
        #expect(DashboardDerivation.latestFull(in: result.state)?.id == "full-old")
        #expect(result.notifications.map(\.kind) == [.scheduled])
        #expect(result.notifications.first?.title == "⏳ Codex Reset Scheduled")
        #expect(result.notifications.first?.body.contains("Wed 23 Sep · 06:59") == true)
        #expect(DashboardDerivation.isCelebrating(result.state, now: now) == false)
        #expect(BankedInventory.availableCount(result.state.bankedRecords) == 0)

        let content = WidgetContentBuilder.make(state: result.state, now: now)
        #expect(content.mode == .tracking)
        #expect(content.scheduledCompact == "< 15h")
    }

    @Test func scheduledResetBecomesCompleted() {
        var state = trackingState()
        let scheduled = makeEvent(
            id: "sched-1",
            kind: .full,
            at: "2026-09-22T04:31:32Z",
            lifecycle: .scheduled,
            scheduledFor: date("2026-09-23T06:59:00Z")
        )
        state.scheduled = scheduled
        state.notifiedKeys.append(scheduled.dedupeKey)

        let completed = makeEvent(id: "full-landed", kind: .full, at: "2026-09-23T06:59:30Z", text: "Reset all propagated.")
        let result = StateReducer.merge(
            state: state,
            status: status(latest: completed, scheduled: nil),
            history: state.events + [completed],
            timeZone: utc
        )

        #expect(result.state.scheduled == nil)
        #expect(DashboardDerivation.latestFull(in: result.state)?.id == "full-landed")
        #expect(result.notifications.map(\.kind) == [.full])
        #expect(result.notifications.contains { $0.kind == .scheduled } == false)
    }

    @Test func sameUpstreamIDMovingFromScheduledToConfirmedNotifiesFull() {
        var state = trackingState()
        let scheduled = makeEvent(
            id: "same-id",
            kind: .full,
            at: "2026-09-22T04:00:00Z",
            lifecycle: .scheduled,
            scheduledFor: date("2026-09-23T06:59:00Z")
        )
        state.scheduled = scheduled
        state.notifiedKeys.append(scheduled.dedupeKey)

        let completed = makeEvent(id: "same-id", kind: .full, at: "2026-09-23T07:00:00Z", text: "It landed.")
        let result = StateReducer.merge(
            state: state,
            status: status(latest: completed, scheduled: nil),
            history: state.events + [completed],
            timeZone: utc
        )
        #expect(result.state.scheduled == nil)
        #expect(result.notifications.map(\.kind) == [.full])
        #expect(result.notifications.first?.dedupeKey != scheduled.dedupeKey)
    }

    @Test func markOneBankedResetUsedNeverGoesBelowZero() {
        var records: [BankedResetRecord] = []
        BankedInventory.setAvailableCount(&records, to: 2, now: now)
        #expect(BankedInventory.availableCount(records) == 2)
        #expect(BankedInventory.markOneUsed(&records, now: now))
        #expect(BankedInventory.availableCount(records) == 1)
        #expect(BankedInventory.markOneUsed(&records, now: now))
        #expect(BankedInventory.availableCount(records) == 0)
        #expect(BankedInventory.markOneUsed(&records, now: now) == false)
        #expect(BankedInventory.availableCount(records) == 0)
    }

    @Test func manualCorrectionDoesNotDoubleCountFutureAPIEvents() {
        var state = trackingState()
        let historical = makeEvent(id: "bank-old", kind: .banked, at: "2026-09-01T00:00:00Z")
        let baseline = StateReducer.merge(
            state: PersistedState(installID: state.installID),
            status: status(latest: state.events[0], scheduled: nil),
            history: [state.events[0], historical],
            timeZone: utc,
            now: now
        )
        state = baseline.state
        #expect(baseline.notifications.isEmpty)
        #expect(BankedInventory.availableCount(state.bankedRecords) == 0)

        BankedInventory.setAvailableCount(&state.bankedRecords, to: 2, now: now)
        let replay = StateReducer.merge(
            state: state,
            status: status(latest: state.events[0], scheduled: nil),
            history: state.events + [historical],
            timeZone: utc,
            now: now
        )
        #expect(BankedInventory.availableCount(replay.state.bankedRecords) == 2)

        let fresh = makeEvent(id: "bank-new", kind: .banked, at: "2026-09-22T12:00:00Z")
        let after = StateReducer.merge(
            state: replay.state,
            status: status(latest: fresh, scheduled: nil),
            history: replay.state.events + [fresh],
            timeZone: utc
        )
        #expect(BankedInventory.availableCount(after.state.bankedRecords) == 3)
        #expect(after.notifications.map(\.kind) == [.banked])
    }

    @Test func appRestartPreservesState() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = FileResetStore(directory: directory)
        var state = trackingState()
        BankedInventory.setAvailableCount(&state.bankedRecords, to: 2, now: now)
        state.celebrationHours = 6
        state.timeDisplay = .utc
        state.preferences.scheduledResets = false
        try store.save(state)

        let reloaded = FileResetStore(directory: directory).load()
        #expect(reloaded.installID == state.installID)
        #expect(BankedInventory.availableCount(reloaded.bankedRecords) == 2)
        #expect(reloaded.events.map(\.id) == state.events.map(\.id))
        #expect(reloaded.celebrationHours == 6)
        #expect(reloaded.timeDisplay == .utc)
        #expect(reloaded.preferences.scheduledResets == false)
        #expect(reloaded.baselineEstablished)
    }

    @Test func historyAfterStatusDoesNotCreditOlderBankedResets() {
        let full = makeEvent(id: "full-old", kind: .full, at: "2026-09-12T08:09:17Z")
        let olderBanked = makeEvent(id: "bank-old", kind: .banked, at: "2026-09-05T00:39:25Z")
        let partial = StateReducer.merge(
            state: PersistedState(installID: "install-test"),
            status: status(latest: full, scheduled: nil),
            history: nil,
            timeZone: utc,
            now: now
        )
        #expect(partial.state.baselineEstablished == false)
        #expect(partial.notifications.isEmpty)

        let complete = StateReducer.merge(
            state: partial.state,
            status: nil,
            history: [full, olderBanked],
            timeZone: utc,
            now: now
        )
        #expect(complete.state.baselineEstablished)
        #expect(complete.notifications.isEmpty)
        #expect(BankedInventory.availableCount(complete.state.bankedRecords) == 0)
    }

    @Test func offlineRefreshKeepsCachedData() async {
        var state = trackingState()
        state.lastUpdated = now
        let fetcher = ScriptedFetcher(
            status: [.failure(CodexAPIError.transport("offline"))],
            history: [.failure(CodexAPIError.transport("offline"))]
        )
        let outcome = await RefreshService.refresh(state: state, fetcher: fetcher, now: now, timeZone: utc)
        #expect(outcome.usedCache)
        #expect(outcome.state.lastRefreshFailed)
        #expect(outcome.state.events.map(\.id) == ["full-old"])
        #expect(outcome.notifications.isEmpty)
        #expect(outcome.widgetsNeedReload == false)
    }

    @Test func malformedNoncriticalFieldsDoNotCrash() throws {
        let statusData = try fixture("status.json")
        let status = try APIDecoder.decode(StatusEnvelopeDTO.self, from: statusData)
        let normalized = ResetNormalizer.status(from: status)
        #expect(normalized?.latestReset?.id == "2098685367058612394")
        #expect(normalized?.latestReset?.kind == .full)
        #expect(normalized?.latestReset?.lifecycle == .confirmed)
        #expect(normalized?.scheduledReset?.id == "2102254445082116335")
        #expect(normalized?.scheduledReset?.lifecycle == .scheduled)
        #expect(normalized?.scheduledReset?.isConfirmedFullReset == false)
        #expect(normalized?.stats?.total == 53)

        let list = try APIDecoder.decode(ResetListEnvelopeDTO.self, from: fixture("resets.json"))
        let events = ResetNormalizer.events(from: list)
        #expect(events.map(\.id) == [
            "2098685367058612394",
            "observed-2097043464538264003",
            "2096035437299237298",
            "2095651088502591861",
        ])
        #expect(events.contains { $0.id == "2096035437299237298" && $0.text.isEmpty && $0.kind == .banked })

        let garbage = Data("{\"data\":\"nope\"}".utf8)
        #expect(throws: CodexAPIError.self) {
            _ = try APIDecoder.decode(StatusEnvelopeDTO.self, from: garbage)
        }
    }

    @Test func corruptCacheDoesNotCrash() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(ResetTrackerDefaults.stateFileName)
        try? Data("this is not json".utf8).write(to: url)
        let store = FileResetStore(directory: directory)
        #expect(store.loadIfPresent() == nil)
        #expect(store.load().events.isEmpty)
    }

    @Test func unknownResetTypeIsStoredWithoutMutatingCounts() {
        let state = trackingState()
        let mystery = makeEvent(id: "mystery", kind: .unclassified, at: "2026-09-22T15:00:00Z", text: "???")
        let result = StateReducer.merge(
            state: state,
            status: status(latest: mystery, scheduled: nil),
            history: state.events + [mystery],
            timeZone: utc
        )
        #expect(DashboardDerivation.latestFull(in: result.state)?.id == "full-old")
        #expect(BankedInventory.availableCount(result.state.bankedRecords) == 0)
        #expect(result.notifications.isEmpty)
        #expect(result.state.events.contains { $0.id == "mystery" })
    }

    @Test func eventsSharingATimestampStayDistinct() {
        let first = ResetNormalizer.event(
            from: ResetDTO(id: nil, resetType: "banked", announcedAt: "2026-09-22T12:00:00Z", text: "One", source: nil, status: nil, scheduledFor: nil, isFullReset: nil, addsBankedReset: nil),
            forcedLifecycle: .confirmed
        )
        let second = ResetNormalizer.event(
            from: ResetDTO(id: nil, resetType: "banked", announcedAt: "2026-09-22T12:00:00Z", text: "Two", source: nil, status: nil, scheduledFor: nil, isFullReset: nil, addsBankedReset: nil),
            forcedLifecycle: .confirmed
        )
        #expect(first?.id != second?.id)
        #expect(first?.id == ResetNormalizer.event(
            from: ResetDTO(id: nil, resetType: "banked", announcedAt: "2026-09-22T12:00:00Z", text: "One", source: nil, status: nil, scheduledFor: nil, isFullReset: nil, addsBankedReset: nil),
            forcedLifecycle: .confirmed
        )?.id)
    }

    @Test func celebrationWindowFollowsConfirmedFullResetOnly() {
        var state = trackingState(fullAt: "2026-09-22T10:00:00Z")
        let inside = date("2026-09-22T16:00:00Z")
        #expect(DashboardDerivation.isCelebrating(state, now: inside))
        let content = WidgetContentBuilder.make(state: state, now: inside)
        #expect(content.mode == .celebration)
        #expect(content.compactValue == "RESET")
        #expect(content.headline == "RESET!")
        #expect(content.caption == "100% reset")
        #expect(content.ago == "6h ago")
        let tracking = WidgetContentBuilder.make(state: trackingState(), now: now)
        #expect(tracking.mode == .tracking)
        #expect(tracking.compactValue == "10d")
        #expect(tracking.headline == "10d 7h")

        let boundary = date("2026-09-22T16:00:00Z")
        state = trackingState(fullAt: "2026-09-22T10:00:00Z")
        #expect(DashboardDerivation.isCelebrating(state, now: boundary))
        let justAfter = date("2026-09-22T16:00:01Z")
        #expect(DashboardDerivation.isCelebrating(state, now: justAfter) == false)
        #expect(WidgetContentBuilder.make(state: state, now: justAfter).mode == .tracking)

        state.events = []
        state.scheduled = makeEvent(
            id: "sched",
            kind: .full,
            at: "2026-09-22T15:00:00Z",
            lifecycle: .scheduled,
            scheduledFor: date("2026-09-22T18:00:00Z")
        )
        #expect(DashboardDerivation.isCelebrating(state, now: inside) == false)
        #expect(WidgetContentBuilder.make(state: state, now: inside).mode == .scheduled)
    }

    @Test func booleanFlagsCanExpressCombinedAheadOfResetType() {
        let dto = ResetDTO(
            id: "flagged",
            resetType: "regular",
            announcedAt: "2026-09-22T12:00:00Z",
            text: "Both",
            source: nil,
            status: nil,
            scheduledFor: nil,
            isFullReset: true,
            addsBankedReset: true
        )
        let event = ResetNormalizer.event(from: dto, forcedLifecycle: .confirmed)
        #expect(event?.kind == .combined)
        #expect(event?.isConfirmedFullReset == true)
        #expect(event?.addsBankedReset == true)
    }

    @Test func freshInstallCreditsCurrentBankedLatestAndWidgetShowsIt() {
        let observed = date("2026-09-22T21:23:37Z")
        let banked = makeEvent(
            id: "2102463847714247142",
            kind: .banked,
            at: "2026-09-22T18:23:37Z",
            text: "Banked reset."
        )
        let full = makeEvent(id: "full-sep12", kind: .full, at: "2026-09-12T08:09:17Z", text: "Full reset.")
        let ancient = makeEvent(id: "bank-ancient", kind: .banked, at: "2026-09-05T00:39:25Z")
        let scheduled = makeEvent(
            id: "sched-live",
            kind: .full,
            at: "2026-09-22T04:31:32Z",
            text: "Reset on Wednesday.",
            lifecycle: .scheduled,
            scheduledFor: date("2026-09-23T06:59:00Z")
        )

        let partial = StateReducer.merge(
            state: PersistedState(installID: "install-test"),
            status: status(latest: banked, scheduled: scheduled),
            history: nil,
            timeZone: utc,
            now: observed
        )
        #expect(partial.state.baselineEstablished == false)
        #expect(partial.notifications.isEmpty)
        #expect(BankedInventory.availableCount(partial.state.bankedRecords) == 1)

        let result = StateReducer.merge(
            state: partial.state,
            status: status(latest: banked, scheduled: scheduled),
            history: [banked, full, ancient],
            timeZone: utc,
            now: observed
        )
        #expect(result.state.baselineEstablished)
        #expect(result.notifications.isEmpty)
        #expect(result.widgetsNeedReload)
        #expect(BankedInventory.availableCount(result.state.bankedRecords) == 1)
        #expect(result.state.bankedRecords.first { $0.eventID == banked.id }?.origin == .upstreamCredited)
        #expect(result.state.bankedRecords.first { $0.eventID == ancient.id }?.origin == .upstreamBaseline)
        #expect(result.state.bankedRecords.filter { $0.eventID == banked.id }.count == 1)
        #expect(DashboardDerivation.isCelebrating(result.state, now: observed) == false)

        let content = WidgetContentBuilder.make(state: result.state, now: observed)
        #expect(content.mode == .bankedRecent)
        #expect(content.headline == "BANKED")
        #expect(content.compactValue == "+1")
        #expect(content.caption == "+1")
        #expect(content.ago == "3h ago")
        #expect(content.fullAgeCompact == "10d")
        #expect(content.fullAgeDetailed == "10d 13h")
        #expect(content.scheduledPhrase == "Within ~10h")
        #expect(content.bankedCount == 1)
        #expect(content.bankedCue == "+1 · 3h ago")
        #expect(content.accessibilityLabel.contains("Last full reset"))
        #expect(content.accessibilityLabel.contains("Next reset"))

        let replay = StateReducer.merge(
            state: result.state,
            status: status(latest: banked, scheduled: scheduled),
            history: result.state.events,
            timeZone: utc,
            now: observed
        )
        #expect(BankedInventory.availableCount(replay.state.bankedRecords) == 1)
        #expect(replay.state.bankedRecords.filter { $0.eventID == banked.id }.count == 1)
        #expect(replay.notifications.isEmpty)
    }

    @Test func firstSyncCreditsBankedInsideFortyEightHoursAndNotOlder() {
        let inside = makeEvent(id: "bank-inside", kind: .banked, at: "2026-09-20T16:00:00Z")
        let alsoRecent = makeEvent(id: "bank-also", kind: .banked, at: "2026-09-21T16:00:00Z")
        let outside = makeEvent(id: "bank-outside", kind: .banked, at: "2026-09-20T15:59:59Z")
        let full = makeEvent(id: "full-newer", kind: .full, at: "2026-09-22T08:00:00Z")
        let result = StateReducer.merge(
            state: PersistedState(installID: "install-test"),
            status: status(latest: full, scheduled: nil),
            history: [full, inside, alsoRecent, outside],
            timeZone: utc,
            now: now
        )
        #expect(result.notifications.isEmpty)
        #expect(BankedInventory.availableCount(result.state.bankedRecords) == 2)
        #expect(result.state.bankedRecords.first { $0.eventID == inside.id }?.origin == .upstreamCredited)
        #expect(result.state.bankedRecords.first { $0.eventID == alsoRecent.id }?.origin == .upstreamCredited)
        #expect(result.state.bankedRecords.first { $0.eventID == outside.id }?.origin == .upstreamBaseline)
        let tracking = WidgetContentBuilder.make(state: result.state, now: now)
        #expect(tracking.mode == .tracking)
        #expect(tracking.bankedCue == nil)
    }

    @Test func firstSyncCreditsLatestBankedWhenItIsOlderThanFortyEightHours() {
        let latest = makeEvent(id: "bank-stale-latest", kind: .banked, at: "2026-09-10T00:00:00Z", text: "Still the latest.")
        let ancient = makeEvent(id: "bank-ancient", kind: .banked, at: "2026-09-01T00:00:00Z")
        let full = makeEvent(id: "full-older", kind: .full, at: "2026-09-02T00:00:00Z")
        let partial = StateReducer.merge(
            state: PersistedState(installID: "install-test"),
            status: status(latest: latest, scheduled: nil),
            history: nil,
            timeZone: utc,
            now: now
        )
        #expect(partial.state.baselineEstablished == false)
        #expect(BankedInventory.availableCount(partial.state.bankedRecords) == 1)
        #expect(partial.state.bankedRecords.first { $0.eventID == latest.id }?.origin == .upstreamCredited)

        let complete = StateReducer.merge(
            state: partial.state,
            status: nil,
            history: [latest, ancient, full],
            timeZone: utc,
            now: now
        )
        #expect(complete.state.baselineEstablished)
        #expect(complete.notifications.isEmpty)
        #expect(BankedInventory.availableCount(complete.state.bankedRecords) == 1)
        #expect(complete.state.bankedRecords.first { $0.eventID == latest.id }?.origin == .upstreamCredited)
        #expect(complete.state.bankedRecords.first { $0.eventID == ancient.id }?.origin == .upstreamBaseline)
        #expect(complete.state.bankedRecords.first { $0.eventID == ancient.id }?.countsAsAvailable == false)
    }

    @Test func fullCelebrationOutranksANewerBankedEvent() {
        var state = trackingState(fullAt: "2026-09-22T12:00:00Z")
        let banked = makeEvent(id: "bank-newer", kind: .banked, at: "2026-09-22T15:00:00Z", text: "Added after the full reset.")
        state.events.insert(banked, at: 0)
        #expect(DashboardDerivation.isCelebrating(state, now: now))
        #expect(DashboardDerivation.bankedRecentEvent(in: state, now: now) == nil)
        let content = WidgetContentBuilder.make(state: state, now: now)
        #expect(content.mode == .celebration)
        #expect(content.headline == "RESET!")
        #expect(content.fullAgeCompact == nil)
        #expect(content.bankedCue == "+1 · 1h ago")
    }

    @Test func combinedResetCelebratesAsFullThenBecomesBankedRecent() {
        var state = trackingState(fullAt: "2026-09-01T00:00:00Z")
        let combined = makeEvent(id: "both-recent", kind: .combined, at: "2026-09-22T14:00:00Z", text: "Reset, and a banked credit.")
        state.events.insert(combined, at: 0)
        #expect(DashboardDerivation.latestFull(in: state)?.id == combined.id)
        #expect(DashboardDerivation.isCelebrating(state, now: now))
        let celebrating = WidgetContentBuilder.make(state: state, now: now)
        #expect(celebrating.mode == .celebration)
        #expect(celebrating.bankedCue == "+1 · 2h ago")

        let later = date("2026-09-22T23:00:00Z")
        #expect(DashboardDerivation.isCelebrating(state, now: later) == false)
        let content = WidgetContentBuilder.make(state: state, now: later)
        #expect(content.mode == .bankedRecent)
        #expect(content.headline == "BANKED")
        #expect(content.ago == "9h ago")
        #expect(content.fullAgeDetailed == "9h")
        #expect(content.bankedCue == "+1 · 9h ago")
        #expect(DashboardDerivation.bankedRecentEvent(in: state, now: later)?.id == combined.id)
    }

    @Test func nextSyncCreditsARecentRowThatWasStoredAsBaseline() {
        var state = trackingState()
        let banked = makeEvent(id: "bank-recent", kind: .banked, at: "2026-09-22T13:00:00Z", text: "One banked reset.")
        state.events.insert(banked, at: 0)
        state.bankedRecords.append(
            BankedResetRecord(
                eventID: banked.id,
                receivedAt: banked.announcedAt,
                usedAt: nil,
                origin: .upstreamBaseline
            )
        )
        state.notifiedKeys.append(banked.dedupeKey)
        #expect(BankedInventory.availableCount(state.bankedRecords) == 0)

        let result = StateReducer.merge(
            state: state,
            status: status(latest: banked, scheduled: nil),
            history: state.events,
            timeZone: utc,
            now: now
        )
        #expect(BankedInventory.availableCount(result.state.bankedRecords) == 1)
        #expect(result.state.bankedRecords.first { $0.eventID == banked.id }?.origin == .upstreamCredited)
        #expect(result.state.bankedRecords.filter { $0.eventID == banked.id }.count == 1)
        #expect(result.notifications.isEmpty)
        #expect(result.widgetsNeedReload)
        #expect(WidgetContentBuilder.make(state: result.state, now: now).mode == .bankedRecent)
    }

    @Test func nextSyncLeavesAncientBaselineRowsUncounted() {
        var state = trackingState()
        let ancient = makeEvent(id: "bank-ancient", kind: .banked, at: "2026-09-01T00:00:00Z")
        state.events.append(ancient)
        state.bankedRecords.append(
            BankedResetRecord(
                eventID: ancient.id,
                receivedAt: ancient.announcedAt,
                usedAt: nil,
                origin: .upstreamBaseline
            )
        )
        state.notifiedKeys.append(ancient.dedupeKey)
        let result = StateReducer.merge(
            state: state,
            status: status(latest: state.events[0], scheduled: nil),
            history: state.events,
            timeZone: utc,
            now: now
        )
        #expect(BankedInventory.availableCount(result.state.bankedRecords) == 0)
        #expect(result.state.bankedRecords.first { $0.eventID == ancient.id }?.origin == .upstreamBaseline)
        #expect(result.notifications.isEmpty)
    }

    private func trackingState(fullAt: String = "2026-09-12T08:09:17Z") -> PersistedState {
        let full = makeEvent(id: "full-old", kind: .full, at: fullAt, text: "Older full reset.")
        var state = PersistedState(installID: "install-test")
        state.events = [full]
        state.baselineEstablished = true
        state.notifiedKeys = [full.dedupeKey]
        state.celebrationHours = 6
        state.timeDisplay = .utc
        return state
    }

    private func status(latest: ResetEvent?, scheduled: ResetEvent?) -> NormalizedStatus {
        NormalizedStatus(latestReset: latest, scheduledReset: scheduled, watch: nil, stats: nil, generatedAt: now)
    }
}

final class ScriptedFetcher: ResetFetching {
    var status: [Result<ConditionalPayload<NormalizedStatus>, Error>]
    var history: [Result<ConditionalPayload<[ResetEvent]>, Error>]
    private var statusIndex = 0
    private var historyIndex = 0

    init(
        status: [Result<ConditionalPayload<NormalizedStatus>, Error>],
        history: [Result<ConditionalPayload<[ResetEvent]>, Error>]
    ) {
        self.status = status
        self.history = history
    }

    func fetchStatus(etag: String?) async throws -> ConditionalPayload<NormalizedStatus> {
        let index = min(statusIndex, max(status.count - 1, 0))
        statusIndex += 1
        return try status[index].get()
    }

    func fetchHistory(etag: String?) async throws -> ConditionalPayload<[ResetEvent]> {
        let index = min(historyIndex, max(history.count - 1, 0))
        historyIndex += 1
        return try history[index].get()
    }
}

func date(_ string: String) -> Date {
    CodexDate.parse(string)!
}

func makeEvent(
    id: String,
    kind: ResetKind,
    at: String,
    text: String = "",
    lifecycle: ResetLifecycle = .confirmed,
    scheduledFor: Date? = nil
) -> ResetEvent {
    ResetEvent(
        id: id,
        kind: kind,
        lifecycle: lifecycle,
        announcedAt: date(at),
        scheduledFor: scheduledFor,
        text: text,
        rawUpstreamID: id
    )
}

func fixture(_ name: String) throws -> Data {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
    return try Data(contentsOf: url)
}
