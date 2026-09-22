import Foundation

/// Where a banked-reset row came from.
///
/// Baseline rows are older announcements that already existed the first time this
/// install synced. They are remembered so later fetches do not count them again,
/// and they do not change the number the user can redeem.
/// A banked announcement from the last 48 hours, and the current latest reset
/// when it adds a banked credit, is stored as credited instead so a fresh install
/// still receives that reset.
/// Credited rows are announcements discovered after that baseline, plus those
/// recent first-sync exceptions.
/// Manual rows are the user's own correction and never collide with upstream ids.
public enum BankedOrigin: String, Codable, Equatable {
    case upstreamBaseline
    case upstreamCredited
    case manual
}

public struct BankedResetRecord: Codable, Equatable, Identifiable {
    public var eventID: String
    public var receivedAt: Date
    public var usedAt: Date?
    public var origin: BankedOrigin

    public var id: String { eventID }

    public init(eventID: String, receivedAt: Date, usedAt: Date?, origin: BankedOrigin) {
        self.eventID = eventID
        self.receivedAt = receivedAt
        self.usedAt = usedAt
        self.origin = origin
    }

    public var countsAsAvailable: Bool {
        origin != .upstreamBaseline && usedAt == nil
    }
}
