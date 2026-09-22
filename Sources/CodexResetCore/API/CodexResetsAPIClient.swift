import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct ConditionalPayload<T> {
    public var value: T?
    public var notModified: Bool
    public var etag: String?

    public init(value: T?, notModified: Bool, etag: String?) {
        self.value = value
        self.notModified = notModified
        self.etag = etag
    }
}

public enum CodexAPIError: Error, Equatable {
    case transport(String)
    case http(status: Int, detail: String?)
    case rateLimited(retryAfter: Int?)
    case decoding(String)
    case unavailable(String?)
}

public protocol ResetFetching {
    func fetchStatus(etag: String?) async throws -> ConditionalPayload<NormalizedStatus>
    func fetchHistory(etag: String?) async throws -> ConditionalPayload<[ResetEvent]>
}

public struct CodexResetsAPIClient: ResetFetching {
    public var baseURL: URL
    public var session: URLSession
    public var pageSize: Int
    public var maxPages: Int

    public init(
        baseURL: URL = ResetTrackerDefaults.apiBaseURL,
        session: URLSession = .shared,
        pageSize: Int = ResetTrackerDefaults.historyPageSize,
        maxPages: Int = ResetTrackerDefaults.maxHistoryPages
    ) {
        self.baseURL = baseURL
        self.session = session
        self.pageSize = min(max(pageSize, 1), 100)
        self.maxPages = max(maxPages, 1)
    }

    public func fetchStatus(etag: String?) async throws -> ConditionalPayload<NormalizedStatus> {
        let url = try endpoint("/api/v1/status")
        let response = try await send(url: url, etag: etag)
        if response.notModified {
            return ConditionalPayload(value: nil, notModified: true, etag: response.etag)
        }
        let envelope = try APIDecoder.decode(StatusEnvelopeDTO.self, from: response.body)
        guard let status = ResetNormalizer.status(from: envelope) else {
            throw CodexAPIError.decoding("Status response did not include a data object.")
        }
        return ConditionalPayload(value: status, notModified: false, etag: response.etag)
    }

    public func fetchHistory(etag: String?) async throws -> ConditionalPayload<[ResetEvent]> {
        var collected: [ResetEvent] = []
        var cursor: String?
        var firstETag: String?
        var pageIndex = 0

        while pageIndex < maxPages {
            let page: HistoryPage
            do {
                page = try await fetchHistoryPage(cursor: cursor, etag: pageIndex == 0 ? etag : nil)
            } catch {
                if collected.isEmpty { throw error }
                CodexLog.debug("Stopped history paging after a later page failed: \(error)")
                break
            }

            if pageIndex == 0, page.notModified {
                return ConditionalPayload(value: nil, notModified: true, etag: page.etag)
            }
            if pageIndex == 0 {
                firstETag = page.etag
            }
            collected.append(contentsOf: page.events)
            pageIndex += 1
            guard page.hasMore, let next = page.nextCursor, !next.isEmpty else { break }
            cursor = next
        }

        return ConditionalPayload(value: collected, notModified: false, etag: firstETag)
    }

    private struct RawResponse {
        var notModified: Bool
        var etag: String?
        var body: Data
    }

    private struct HistoryPage {
        var events: [ResetEvent]
        var hasMore: Bool
        var nextCursor: String?
        var notModified: Bool
        var etag: String?
    }

    private func fetchHistoryPage(cursor: String?, etag: String?) async throws -> HistoryPage {
        var items = [
            URLQueryItem(name: "limit", value: String(pageSize)),
            URLQueryItem(name: "order", value: "desc"),
        ]
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        let url = try endpoint("/api/v1/resets", query: items)
        let response = try await send(url: url, etag: etag)
        if response.notModified {
            return HistoryPage(events: [], hasMore: false, nextCursor: nil, notModified: true, etag: response.etag)
        }
        let envelope = try APIDecoder.decode(ResetListEnvelopeDTO.self, from: response.body)
        return HistoryPage(
            events: ResetNormalizer.events(from: envelope),
            hasMore: envelope.pagination?.hasMore == true,
            nextCursor: envelope.pagination?.nextCursor,
            notModified: false,
            etag: response.etag
        )
    }

    private func send(url: URL, etag: String?) async throws -> RawResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("CodexResetTracker/1.0", forHTTPHeaderField: "User-Agent")
        if let etag, !etag.isEmpty {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CodexAPIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CodexAPIError.transport("The reset service returned a non-HTTP response.")
        }
        let responseETag = http.value(forHTTPHeaderField: "ETag")
        switch http.statusCode {
        case 200:
            return RawResponse(notModified: false, etag: responseETag, body: data)
        case 304:
            return RawResponse(notModified: true, etag: responseETag ?? etag, body: Data())
        case 429:
            let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw CodexAPIError.rateLimited(retryAfter: retry)
        case 503:
            throw CodexAPIError.unavailable(problemDetail(data))
        default:
            throw CodexAPIError.http(status: http.statusCode, detail: problemDetail(data))
        }
    }

    private func endpoint(_ path: String, query: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw CodexAPIError.transport("Invalid API base URL.")
        }
        let trimmed = path.hasPrefix("/") ? path : "/" + path
        components.path = trimmed
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw CodexAPIError.transport("Could not build API URL.")
        }
        return url
    }

    private func problemDetail(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let detail = object["detail"] as? String
        let title = object["title"] as? String
        return detail ?? title
    }
}

enum APIDecoder {
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            CodexLog.debug("Decoding \(T.self) failed: \(error)")
            throw CodexAPIError.decoding(String(describing: error))
        }
    }
}
