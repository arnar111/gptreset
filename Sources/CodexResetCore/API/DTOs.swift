import Foundation

/// Wire types for https://codex-resets.com/api/openapi.json (Public API 1.0.0).
/// Every field is optional so one unexpected or missing value cannot crash a screen.
struct ResetDTO: Decodable {
    var id: String?
    var resetType: String?
    var announcedAt: String?
    var text: String?
    var source: SourceDTO?
    var status: String?
    var scheduledFor: String?
    var isFullReset: Bool?
    var addsBankedReset: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case resetType = "reset_type"
        case announcedAt = "announced_at"
        case text
        case source
        case status
        case scheduledFor = "scheduled_for"
        case isFullReset = "is_full_reset"
        case addsBankedReset = "adds_banked_reset"
    }
}

struct SourceDTO: Decodable {
    var type: String?
    var author: String?
    var url: String?
}

struct WatchDTO: Decodable {
    var level: String?
    var resetChancePercent: Int?
    var forecastWindow: String?
    var observedAt: String?
    var expiresAt: String?
    var text: String?
    var source: SourceDTO?

    enum CodingKeys: String, CodingKey {
        case level
        case resetChancePercent = "reset_chance_percent"
        case forecastWindow = "forecast_window"
        case observedAt = "observed_at"
        case expiresAt = "expires_at"
        case text
        case source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        level = container.decodeLossy(String.self, forKey: .level)
        resetChancePercent = container.decodeLossy(Int.self, forKey: .resetChancePercent)
        forecastWindow = container.decodeLossy(String.self, forKey: .forecastWindow)
        observedAt = container.decodeLossy(String.self, forKey: .observedAt)
        expiresAt = container.decodeLossy(String.self, forKey: .expiresAt)
        text = container.decodeLossy(String.self, forKey: .text)
        source = container.decodeLossy(SourceDTO.self, forKey: .source)
    }
}

struct StatsDTO: Decodable {
    var total: Int?
    var lastResetAt: String?
    var daysSinceLast: Double?
    var averageIntervalDays: Double?

    enum CodingKeys: String, CodingKey {
        case total
        case lastResetAt = "last_reset_at"
        case daysSinceLast = "days_since_last"
        case averageIntervalDays = "avg_interval_days"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = container.decodeLossy(Int.self, forKey: .total)
        lastResetAt = container.decodeLossy(String.self, forKey: .lastResetAt)
        daysSinceLast = container.decodeLossy(Double.self, forKey: .daysSinceLast)
        averageIntervalDays = container.decodeLossy(Double.self, forKey: .averageIntervalDays)
    }
}

struct MetaDTO: Decodable {
    var apiVersion: String?
    var generatedAt: String?

    enum CodingKeys: String, CodingKey {
        case apiVersion = "api_version"
        case generatedAt = "generated_at"
    }
}

struct PaginationDTO: Decodable {
    var hasMore: Bool?
    var nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case hasMore = "has_more"
        case nextCursor = "next_cursor"
    }
}

struct StatusEnvelopeDTO: Decodable {
    var data: StatusDataDTO?
    var meta: MetaDTO?

    struct StatusDataDTO: Decodable {
        var latestReset: ResetDTO?
        var scheduledReset: ResetDTO?
        var activeWatch: WatchDTO?
        var stats: StatsDTO?

        enum CodingKeys: String, CodingKey {
            case latestReset = "latest_reset"
            case scheduledReset = "scheduled_reset"
            case activeWatch = "active_watch"
            case stats
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            latestReset = container.decodeLossy(ResetDTO.self, forKey: .latestReset)
            scheduledReset = container.decodeLossy(ResetDTO.self, forKey: .scheduledReset)
            activeWatch = container.decodeLossy(WatchDTO.self, forKey: .activeWatch)
            stats = container.decodeLossy(StatsDTO.self, forKey: .stats)
        }
    }
}

struct ResetListEnvelopeDTO: Decodable {
    var data: [ResetDTO]
    var pagination: PaginationDTO?
    var meta: MetaDTO?

    enum CodingKeys: String, CodingKey {
        case data
        case pagination
        case meta
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard container.contains(.data) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "Missing reset list data.")
            )
        }
        let values = try container.decode([JSONValue].self, forKey: .data)
        data = values.compactMap { value in
            guard let dto = value.decode(ResetDTO.self) else {
                if case .object = value {
                    CodexLog.debug("Skipped a reset object that did not match the announcement shape.")
                }
                return nil
            }
            return dto
        }
        pagination = container.decodeLossy(PaginationDTO.self, forKey: .pagination)
        meta = container.decodeLossy(MetaDTO.self, forKey: .meta)
    }
}

/// A JSON value that always consumes its token, so one bad list row cannot shift the rest.
enum JSONValue: Codable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .number(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
            return
        }
        if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized JSON value.")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }

    func decode<T: Decodable>(_ type: T.Type) -> T? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

extension KeyedDecodingContainer {
    func decodeLossy<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        guard contains(key) else { return nil }
        do {
            return try decodeIfPresent(T.self, forKey: key)
        } catch {
            CodexLog.debug("Ignored field \(key.stringValue): \(error)")
            return nil
        }
    }
}
