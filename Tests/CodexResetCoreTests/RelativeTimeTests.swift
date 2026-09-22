import Foundation
import Testing
@testable import CodexResetCore

struct RelativeTimeTests {
    private let utc = TimeZone(secondsFromGMT: 0)!
    private let now = date("2026-09-22T18:00:00Z")

    @Test func relativePhrasesMatchTheProductCopy() {
        #expect(elapsed(minutes: 23).phrase == "23m ago")
        #expect(elapsed(minutes: 23).short == "23m")
        #expect(elapsed(hours: 4).phrase == "4h ago")
        #expect(elapsed(minutes: 12, hours: 6).phrase == "6h 12m ago")
        #expect(elapsed(hours: 7, days: 2).phrase == "2d 7h ago")
        #expect(elapsed(hours: 7, days: 10).phrase == "10d 7h ago")
        #expect(elapsed(hours: 7, days: 10).short == "10d")
        #expect(elapsed(seconds: 12).phrase == "just now")
        #expect(elapsed(minutes: 23).accessible == "23 minutes ago")
        #expect(elapsed(hours: 7, days: 10).accessible == "10 days 7 hours ago")
    }

    @Test func stampsUseA24HourClock() {
        let morning = date("2026-09-12T08:09:00Z")
        #expect(RelativeTime.stamp(morning, timeZone: utc, locale: Locale(identifier: "en_US")) == "Sep 12 · 08:09")
        let scheduled = date("2026-09-23T06:59:00Z")
        #expect(RelativeTime.stamp(scheduled, timeZone: utc, locale: Locale(identifier: "en_US"), includeWeekday: true) == "Wed 23 Sep · 06:59")
        #expect(RelativeTime.stamp(morning, display: .utc, locale: Locale(identifier: "en_US")).hasSuffix("UTC"))
    }

    @Test func scheduledWindowRoundsUpAndDoesNotImplyCompletion() {
        let fifteen = date("2026-09-23T08:01:00Z")
        let window = RelativeTime.scheduledWindow(until: fifteen, now: now)
        #expect(window.compact == "< 15h")
        #expect(window.phrase == "Within ~15h")
        #expect(window.passed == false)

        let passed = RelativeTime.scheduledWindow(until: date("2026-09-22T12:00:00Z"), now: now)
        #expect(passed.passed)
        #expect(passed.phrase == "Expected time passed")
    }

    @Test func sha256MatchesTheKnownVector() {
        #expect(SHA256.hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    private func elapsed(seconds: Int = 0, minutes: Int = 0, hours: Int = 0, days: Int = 0) -> ElapsedTime {
        let total = seconds + minutes * 60 + hours * 3600 + days * 86400
        return RelativeTime.elapsed(from: now.addingTimeInterval(TimeInterval(-total)), now: now)
    }
}
