import Foundation

/// Confirmed resets change usage or the bank. Scheduled resets have not landed.
public enum ResetLifecycle: String, Codable, Equatable {
    case confirmed
    case scheduled
}

/// Upstream currently publishes `regular` and `banked`. Combined is supported
/// when an announcement explicitly grants both, including future API values.
public enum ResetKind: String, Codable, Equatable {
    case full
    case banked
    case combined
    case unclassified
}

public struct ResetEvent: Codable, Equatable, Identifiable {
    public var id: String
    public var kind: ResetKind
    public var lifecycle: ResetLifecycle
    public var announcedAt: Date
    public var scheduledFor: Date?
    public var text: String
    public var sourceURLString: String?
    public var sourceAuthor: String?
    public var sourceType: String?
    /// Upstream id before fingerprinting. Equal to `id` when the API sent one.
    public var rawUpstreamID: String?

    public init(
        id: String,
        kind: ResetKind,
        lifecycle: ResetLifecycle,
        announcedAt: Date,
        scheduledFor: Date? = nil,
        text: String,
        sourceURLString: String? = nil,
        sourceAuthor: String? = nil,
        sourceType: String? = nil,
        rawUpstreamID: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.lifecycle = lifecycle
        self.announcedAt = announcedAt
        self.scheduledFor = scheduledFor
        self.text = text
        self.sourceURLString = sourceURLString
        self.sourceAuthor = sourceAuthor
        self.sourceType = sourceType
        self.rawUpstreamID = rawUpstreamID
    }

    public var sourceURL: URL? {
        sourceURLString.flatMap(URL.init(string:))
    }

    /// A full reset only counts once upstream says it has actually happened.
    public var isConfirmedFullReset: Bool {
        lifecycle == .confirmed && (kind == .full || kind == .combined)
    }

    public var addsBankedReset: Bool {
        lifecycle == .confirmed && (kind == .banked || kind == .combined)
    }

    public var dedupeKey: String {
        DedupeKey.make(id: id, lifecycle: lifecycle, kind: kind, scheduledFor: scheduledFor)
    }
}

public enum DedupeKey {
    /// Scheduled and confirmed states are different keys, even when they share an id.
    /// A changed `scheduledFor` is a new scheduled announcement. Confirmed keys ignore text edits.
    public static func make(id: String, lifecycle: ResetLifecycle, kind: ResetKind, scheduledFor: Date?) -> String {
        switch lifecycle {
        case .scheduled:
            let millis = scheduledFor.map { String(CodexDate.milliseconds($0)) } ?? ""
            return "\(id)|scheduled|\(kind.rawValue)|\(millis)"
        case .confirmed:
            return "\(id)|confirmed|\(kind.rawValue)"
        }
    }
}

public struct WatchSignal: Codable, Equatable {
    public var level: String
    public var resetChancePercent: Int?
    public var forecastWindow: String
    public var observedAt: Date?
    public var expiresAt: Date?
    public var text: String
    public var sourceURLString: String?

    public init(
        level: String,
        resetChancePercent: Int?,
        forecastWindow: String,
        observedAt: Date?,
        expiresAt: Date?,
        text: String,
        sourceURLString: String?
    ) {
        self.level = level
        self.resetChancePercent = resetChancePercent
        self.forecastWindow = forecastWindow
        self.observedAt = observedAt
        self.expiresAt = expiresAt
        self.text = text
        self.sourceURLString = sourceURLString
    }

    public var sourceURL: URL? {
        sourceURLString.flatMap(URL.init(string:))
    }

    public func isActive(at now: Date) -> Bool {
        guard let expiresAt else { return true }
        return expiresAt > now
    }
}

public struct ResetStats: Codable, Equatable {
    public var total: Int?
    public var lastResetAt: Date?
    public var daysSinceLast: Double?
    public var averageIntervalDays: Double?

    public init(total: Int?, lastResetAt: Date?, daysSinceLast: Double?, averageIntervalDays: Double?) {
        self.total = total
        self.lastResetAt = lastResetAt
        self.daysSinceLast = daysSinceLast
        self.averageIntervalDays = averageIntervalDays
    }
}

public struct NormalizedStatus: Equatable {
    public var latestReset: ResetEvent?
    public var scheduledReset: ResetEvent?
    public var watch: WatchSignal?
    public var stats: ResetStats?
    public var generatedAt: Date?

    public init(
        latestReset: ResetEvent?,
        scheduledReset: ResetEvent?,
        watch: WatchSignal?,
        stats: ResetStats?,
        generatedAt: Date?
    ) {
        self.latestReset = latestReset
        self.scheduledReset = scheduledReset
        self.watch = watch
        self.stats = stats
        self.generatedAt = generatedAt
    }
}
