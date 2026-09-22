import Foundation

public struct NotificationPreferences: Codable, Equatable {
    public var fullResets: Bool
    public var bankedResets: Bool
    public var scheduledResets: Bool

    public init(fullResets: Bool, bankedResets: Bool, scheduledResets: Bool) {
        self.fullResets = fullResets
        self.bankedResets = bankedResets
        self.scheduledResets = scheduledResets
    }

    public static let allOn = NotificationPreferences(fullResets: true, bankedResets: true, scheduledResets: true)

    public var anyEnabled: Bool {
        fullResets || bankedResets || scheduledResets
    }
}

public enum TimeDisplay: String, Codable, Equatable {
    case local
    case utc

    public var timeZone: TimeZone {
        switch self {
        case .local:
            return .current
        case .utc:
            return TimeZone(secondsFromGMT: 0) ?? .current
        }
    }
}

public struct PersistedState: Codable, Equatable {
    public var schemaVersion: Int
    public var events: [ResetEvent]
    public var scheduled: ResetEvent?
    public var watch: WatchSignal?
    public var stats: ResetStats?
    public var bankedRecords: [BankedResetRecord]
    public var baselineEstablished: Bool
    public var notifiedKeys: [String]
    public var lastUpdated: Date?
    public var lastRefreshFailed: Bool
    public var preferences: NotificationPreferences
    public var timeDisplay: TimeDisplay
    public var celebrationHours: Int
    public var installID: String
    public var didPromptForNotifications: Bool
    public var backendBaseURL: String?
    public var backendDeviceRegistered: Bool
    public var registeredTimeZone: String?
    public var statusETag: String?
    public var historyETag: String?

    public init(
        schemaVersion: Int = 1,
        events: [ResetEvent] = [],
        scheduled: ResetEvent? = nil,
        watch: WatchSignal? = nil,
        stats: ResetStats? = nil,
        bankedRecords: [BankedResetRecord] = [],
        baselineEstablished: Bool = false,
        notifiedKeys: [String] = [],
        lastUpdated: Date? = nil,
        lastRefreshFailed: Bool = false,
        preferences: NotificationPreferences = .allOn,
        timeDisplay: TimeDisplay = .local,
        celebrationHours: Int = ResetTrackerDefaults.celebrationHours,
        installID: String = UUID().uuidString,
        didPromptForNotifications: Bool = false,
        backendBaseURL: String? = nil,
        backendDeviceRegistered: Bool = false,
        registeredTimeZone: String? = nil,
        statusETag: String? = nil,
        historyETag: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.events = events
        self.scheduled = scheduled
        self.watch = watch
        self.stats = stats
        self.bankedRecords = bankedRecords
        self.baselineEstablished = baselineEstablished
        self.notifiedKeys = notifiedKeys
        self.lastUpdated = lastUpdated
        self.lastRefreshFailed = lastRefreshFailed
        self.preferences = preferences
        self.timeDisplay = timeDisplay
        self.celebrationHours = celebrationHours
        self.installID = installID
        self.didPromptForNotifications = didPromptForNotifications
        self.backendBaseURL = backendBaseURL
        self.backendDeviceRegistered = backendDeviceRegistered
        self.registeredTimeZone = registeredTimeZone
        self.statusETag = statusETag
        self.historyETag = historyETag
    }

    public static func fresh() -> PersistedState {
        PersistedState()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        events = try container.decodeIfPresent([ResetEvent].self, forKey: .events) ?? []
        scheduled = try container.decodeIfPresent(ResetEvent.self, forKey: .scheduled)
        watch = try container.decodeIfPresent(WatchSignal.self, forKey: .watch)
        stats = try container.decodeIfPresent(ResetStats.self, forKey: .stats)
        bankedRecords = try container.decodeIfPresent([BankedResetRecord].self, forKey: .bankedRecords) ?? []
        baselineEstablished = try container.decodeIfPresent(Bool.self, forKey: .baselineEstablished) ?? false
        notifiedKeys = try container.decodeIfPresent([String].self, forKey: .notifiedKeys) ?? []
        lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated)
        lastRefreshFailed = try container.decodeIfPresent(Bool.self, forKey: .lastRefreshFailed) ?? false
        preferences = try container.decodeIfPresent(NotificationPreferences.self, forKey: .preferences) ?? .allOn
        timeDisplay = try container.decodeIfPresent(TimeDisplay.self, forKey: .timeDisplay) ?? .local
        celebrationHours = try container.decodeIfPresent(Int.self, forKey: .celebrationHours) ?? ResetTrackerDefaults.celebrationHours
        installID = try container.decodeIfPresent(String.self, forKey: .installID) ?? UUID().uuidString
        didPromptForNotifications = try container.decodeIfPresent(Bool.self, forKey: .didPromptForNotifications) ?? false
        backendBaseURL = try container.decodeIfPresent(String.self, forKey: .backendBaseURL)
        backendDeviceRegistered = try container.decodeIfPresent(Bool.self, forKey: .backendDeviceRegistered) ?? false
        registeredTimeZone = try container.decodeIfPresent(String.self, forKey: .registeredTimeZone)
        statusETag = try container.decodeIfPresent(String.self, forKey: .statusETag)
        historyETag = try container.decodeIfPresent(String.self, forKey: .historyETag)
    }
}

public struct PlannedNotification: Equatable {
    public enum Kind: String, Equatable {
        case full
        case banked
        case combined
        case scheduled
    }

    public var dedupeKey: String
    public var kind: Kind
    public var title: String
    public var body: String
    public var eventID: String
    public var deepLink: String

    public init(dedupeKey: String, kind: Kind, title: String, body: String, eventID: String, deepLink: String) {
        self.dedupeKey = dedupeKey
        self.kind = kind
        self.title = title
        self.body = body
        self.eventID = eventID
        self.deepLink = deepLink
    }
}

public struct ReduceResult: Equatable {
    public var state: PersistedState
    public var notifications: [PlannedNotification]
    public var widgetsNeedReload: Bool

    public init(state: PersistedState, notifications: [PlannedNotification], widgetsNeedReload: Bool) {
        self.state = state
        self.notifications = notifications
        self.widgetsNeedReload = widgetsNeedReload
    }
}
