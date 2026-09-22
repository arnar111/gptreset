import Foundation
import CodexResetCore

enum PushRegistrationError: Error {
    case badURL
    case rejected(Int)
}

enum PushRegistrationService {
    struct Payload: Encodable {
        struct Preferences: Encodable {
            var full: Bool
            var banked: Bool
            var scheduled: Bool
        }

        var apnsToken: String
        var sandbox: Bool
        var timeZone: String
        var preferences: Preferences
    }

    static func register(
        baseURL: URL,
        installID: String,
        token: String,
        sandbox: Bool,
        timeZone: String,
        preferences: NotificationPreferences
    ) async throws {
        let url = try deviceURL(baseURL: baseURL, installID: installID)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = Payload(
            apnsToken: token,
            sandbox: sandbox,
            timeZone: timeZone,
            preferences: Payload.Preferences(
                full: preferences.fullResets,
                banked: preferences.bankedResets,
                scheduled: preferences.scheduledResets
            )
        )
        request.httpBody = try JSONEncoder().encode(payload)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw PushRegistrationError.rejected(code)
        }
    }

    static func unregister(baseURL: URL, installID: String) async throws {
        let url = try deviceURL(baseURL: baseURL, installID: installID)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 20
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw PushRegistrationError.rejected(code)
        }
    }

    private static func deviceURL(baseURL: URL, installID: String) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw PushRegistrationError.badURL
        }
        let prefix = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let basePath = prefix.isEmpty ? "" : "/" + prefix
        let encoded = installID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? installID
        components.path = basePath + "/v1/devices/" + encoded
        guard let url = components.url else { throw PushRegistrationError.badURL }
        return url
    }
}
