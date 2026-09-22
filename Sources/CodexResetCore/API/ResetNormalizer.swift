import Foundation

enum ResetNormalizer {
    static func status(from envelope: StatusEnvelopeDTO) -> NormalizedStatus? {
        guard let data = envelope.data else {
            CodexLog.debug("Status response had no data object.")
            return nil
        }
        return NormalizedStatus(
            latestReset: event(from: data.latestReset, forcedLifecycle: .confirmed),
            scheduledReset: event(from: data.scheduledReset, forcedLifecycle: .scheduled),
            watch: watch(from: data.activeWatch),
            stats: stats(from: data.stats),
            generatedAt: envelope.meta?.generatedAt.flatMap(CodexDate.parse)
        )
    }

    static func events(from envelope: ResetListEnvelopeDTO) -> [ResetEvent] {
        envelope.data.compactMap { event(from: $0, forcedLifecycle: .confirmed) }
    }

    static func event(from dto: ResetDTO?, forcedLifecycle: ResetLifecycle) -> ResetEvent? {
        guard let dto else { return nil }
        guard let announcedAt = dto.announcedAt.flatMap(CodexDate.parse) else {
            CodexLog.debug("Skipping reset \(dto.id ?? "?") with no announced_at.")
            return nil
        }

        let kind = kind(from: dto)
        let text = dto.text ?? ""
        let sourceURL = dto.source?.url
        let upstreamID = dto.id?.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = (upstreamID?.isEmpty == false ? upstreamID! : nil) ?? fingerprint(
            kind: kind,
            announcedAt: announcedAt,
            text: text,
            sourceURL: sourceURL
        )

        let lifecycle: ResetLifecycle
        if forcedLifecycle == .scheduled || dto.status?.lowercased() == "scheduled" {
            lifecycle = .scheduled
        } else {
            lifecycle = .confirmed
        }

        let scheduledFor = dto.scheduledFor.flatMap(CodexDate.parse)
        return ResetEvent(
            id: id,
            kind: kind,
            lifecycle: lifecycle,
            announcedAt: announcedAt,
            scheduledFor: lifecycle == .scheduled ? scheduledFor : nil,
            text: text,
            sourceURLString: sourceURL,
            sourceAuthor: dto.source?.author,
            sourceType: dto.source?.type,
            rawUpstreamID: upstreamID
        )
    }

    static func kind(from dto: ResetDTO) -> ResetKind {
        if dto.isFullReset != nil || dto.addsBankedReset != nil {
            switch (dto.isFullReset == true, dto.addsBankedReset == true) {
            case (true, true):
                return .combined
            case (true, false):
                return .full
            case (false, true):
                return .banked
            case (false, false):
                return .unclassified
            }
        }
        return kind(fromResetType: dto.resetType)
    }

    static func kind(fromResetType raw: String?) -> ResetKind {
        switch raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "regular", "full", "standard":
            return .full
        case "banked", "bank":
            return .banked
        case "combined", "both", "full_banked", "full+banked", "regular_and_banked":
            return .combined
        default:
            return .unclassified
        }
    }

    /// Used when upstream omits an id. Includes the announcement text so two events
    /// that share a timestamp still stay distinct.
    static func fingerprint(kind: ResetKind, announcedAt: Date, text: String, sourceURL: String?) -> String {
        let canonical = [
            "v1",
            kind.rawValue,
            String(CodexDate.milliseconds(announcedAt)),
            text,
            sourceURL ?? "",
        ].joined(separator: "|")
        return "fp_" + SHA256.hex(canonical)
    }

    private static func watch(from dto: WatchDTO?) -> WatchSignal? {
        guard let dto else { return nil }
        let text = dto.text ?? ""
        let level = dto.level ?? ""
        if text.isEmpty && level.isEmpty { return nil }
        return WatchSignal(
            level: level,
            resetChancePercent: dto.resetChancePercent,
            forecastWindow: dto.forecastWindow ?? "",
            observedAt: dto.observedAt.flatMap(CodexDate.parse),
            expiresAt: dto.expiresAt.flatMap(CodexDate.parse),
            text: text,
            sourceURLString: dto.source?.url
        )
    }

    private static func stats(from dto: StatsDTO?) -> ResetStats? {
        guard let dto else { return nil }
        return ResetStats(
            total: dto.total,
            lastResetAt: dto.lastResetAt.flatMap(CodexDate.parse),
            daysSinceLast: dto.daysSinceLast,
            averageIntervalDays: dto.averageIntervalDays
        )
    }
}
