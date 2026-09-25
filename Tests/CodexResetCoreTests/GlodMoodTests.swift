import Foundation
import Testing
@testable import CodexResetCore

struct GlodMoodTests {
    private let now = date("2026-09-22T16:00:00Z")

    @Test func celebratesInsideTheWindow() {
        let state = stateWith(events: [makeEvent(id: "f", kind: .full, at: "2026-09-22T15:37:00Z")])
        #expect(GlodDerivation.mood(in: state, now: now) == .celebrating)
    }

    @Test func richWhenNewestAddedABankedCreditThatIsStillAvailable() {
        var state = stateWith(events: [
            makeEvent(id: "f", kind: .full, at: "2026-09-12T08:00:00Z"),
            makeEvent(id: "b", kind: .banked, at: "2026-09-22T13:00:00Z"),
        ])
        BankedInventory.setAvailableCount(&state.bankedRecords, to: 1, now: now)
        #expect(GlodDerivation.mood(in: state, now: now) == .rich)
    }

    @Test func notRichOnceTheBankIsEmpty() {
        let state = stateWith(events: [
            makeEvent(id: "f", kind: .full, at: "2026-09-12T08:00:00Z"),
            makeEvent(id: "b", kind: .banked, at: "2026-09-22T13:00:00Z"),
        ])
        #expect(GlodDerivation.mood(in: state, now: now) == .content)
    }

    @Test func sleepyAfterThePublishedAverageGap() {
        var state = stateWith(events: [makeEvent(id: "f", kind: .full, at: "2026-09-10T16:00:00Z")])
        state.stats = ResetStats(total: 20, lastResetAt: nil, daysSinceLast: nil, averageIntervalDays: 10)
        #expect(GlodDerivation.mood(in: state, now: now) == .sleepy)
        state.stats?.averageIntervalDays = 14
        #expect(GlodDerivation.mood(in: state, now: now) == .content)
    }

    @Test func typicalGapFallsBackToCachedFullResets() {
        let state = stateWith(events: [
            makeEvent(id: "a", kind: .full, at: "2026-08-01T00:00:00Z"),
            makeEvent(id: "b", kind: .banked, at: "2026-08-05T00:00:00Z"),
            makeEvent(id: "c", kind: .full, at: "2026-08-09T00:00:00Z"),
            makeEvent(id: "d", kind: .combined, at: "2026-08-21T00:00:00Z"),
        ])
        #expect(GlodDerivation.typicalIntervalDays(in: state) == 10)
        #expect(GlodDerivation.mood(in: state, now: now) == .sleepy)
    }

    @Test func contentWithoutAnyTypicalGap() {
        let state = stateWith(events: [makeEvent(id: "f", kind: .full, at: "2026-08-01T00:00:00Z")])
        #expect(GlodDerivation.typicalIntervalDays(in: state) == nil)
        #expect(GlodDerivation.mood(in: state, now: now) == .content)
    }

    @Test func waitingWithoutAFullReset() {
        #expect(GlodDerivation.mood(in: stateWith(events: []), now: now) == .waiting)
    }

    @Test func widgetContentCarriesMoodAndLine() {
        var state = stateWith(events: [makeEvent(id: "f", kind: .full, at: "2026-09-22T15:37:00Z")])
        BankedInventory.setAvailableCount(&state.bankedRecords, to: 2, now: now)
        let content = WidgetContentBuilder.make(state: state, now: now)
        #expect(content.mode == .celebration)
        #expect(content.mood == .celebrating)
        #expect(content.moodLine == "Fresh limits! Go build.")
        #expect(content.bankedCount == 2)
    }

    private func stateWith(events: [ResetEvent]) -> PersistedState {
        var state = PersistedState(installID: "install-test")
        state.events = events
        state.baselineEstablished = true
        state.celebrationHours = 6
        state.timeDisplay = .utc
        return state
    }
}
