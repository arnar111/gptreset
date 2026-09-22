import Foundation
import SwiftUI
import UIKit
import UserNotifications
import WidgetKit
import CodexResetCore

@MainActor
@Observable
final class AppModel {
    var state: PersistedState
    var selectedTab = 0
    var presentedEventID: String?
    var isRefreshing = false
    var pushStatus = "Not registered"

    private let client: CodexResetsAPIClient
    private let presenter = NotificationPresenter()
    private var lastRefreshAt: Date?

    init(client: CodexResetsAPIClient = CodexResetsAPIClient()) {
        self.client = client
        state = SharedStateStore.load()
        PushBridge.shared.onToken = { [weak self] token in
            Task { @MainActor in
                await self?.register(token: token)
            }
        }
        PushBridge.shared.onDeepLink = { [weak self] eventID in
            Task { @MainActor in
                self?.open(eventID: eventID)
            }
        }
        PushBridge.shared.onRemote = { [weak self] in
            Task { @MainActor in
                await self?.refresh(force: true)
            }
        }
        pushStatus = state.backendDeviceRegistered ? "Registered for reset alerts" : "Not registered"
    }

    var bankedAvailable: Int {
        BankedInventory.availableCount(state.bankedRecords)
    }

    var resolvedBackendURL: String? {
        if let stored = state.backendBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines), !stored.isEmpty {
            return stored
        }
        let bundled = (Bundle.main.object(forInfoDictionaryKey: "CodexResetBackendURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return bundled.isEmpty ? nil : bundled
    }

    func refresh(force: Bool = false) async {
        if isRefreshing { return }
        if !force, let lastRefreshAt, Date().timeIntervalSince(lastRefreshAt) < 2 {
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        let outcome = await RefreshService.refresh(
            state: state,
            fetcher: client,
            now: Date(),
            timeZone: state.timeDisplay.timeZone
        )
        state = outcome.state
        lastRefreshAt = Date()
        SharedStateStore.save(state)
        if outcome.widgetsNeedReload {
            WidgetCenter.shared.reloadAllTimelines()
        }
        await presenter.deliver(outcome.notifications, pushActive: remotePushIsActive)
    }

    func markOneUsed() {
        guard BankedInventory.markOneUsed(&state.bankedRecords, now: Date()) else {
            Haptics.warning()
            return
        }
        Haptics.success()
        persist(reloadWidgets: true)
    }

    func setBankedCount(_ count: Int) {
        BankedInventory.setAvailableCount(&state.bankedRecords, to: count, now: Date())
        Haptics.success()
        persist(reloadWidgets: true)
    }

    func setCelebrationHours(_ hours: Int) {
        state.celebrationHours = min(24, max(1, hours))
        persist(reloadWidgets: true)
    }

    func setTimeDisplay(_ display: TimeDisplay) {
        state.timeDisplay = display
        persist(reloadWidgets: true)
        Task { await syncPushRegistration() }
    }

    func setPreferences(_ preferences: NotificationPreferences) {
        state.preferences = preferences
        persist(reloadWidgets: false)
        Task { await syncPushRegistration() }
    }

    func setBackendURL(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        state.backendBaseURL = trimmed.isEmpty ? nil : trimmed
        state.backendDeviceRegistered = false
        persist(reloadWidgets: false)
        Task { await syncPushRegistration() }
    }

    func open(eventID: String) {
        selectedTab = 0
        presentedEventID = eventID
    }

    func handle(url: URL) {
        guard url.scheme == ResetTrackerDefaults.urlScheme else { return }
        let host = url.host?.lowercased()
        if host == "event" {
            let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !id.isEmpty {
                open(eventID: id)
                return
            }
        }
        selectedTab = 0
    }

    func dismissNotificationPrompt() {
        state.didPromptForNotifications = true
        persist(reloadWidgets: false)
    }

    func enableNotifications() async {
        state.didPromptForNotifications = true
        persist(reloadWidgets: false)
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else {
            pushStatus = "Notifications are off in iOS Settings"
            await unregisterDevice()
            return
        }
        #if targetEnvironment(simulator)
        pushStatus = "Local alerts are on. Remote push needs a physical iPhone."
        #else
        UIApplication.shared.registerForRemoteNotifications()
        pushStatus = "Waiting for an APNs token"
        #endif
    }

    func persist(reloadWidgets: Bool) {
        SharedStateStore.save(state)
        if reloadWidgets {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private var remotePushIsActive: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return state.backendDeviceRegistered
        #endif
    }

    private func register(token: String) async {
        KeychainStore.saveToken(token)
        await syncPushRegistration()
    }

    private func syncPushRegistration() async {
        #if targetEnvironment(simulator)
        pushStatus = "Local alerts are on. Remote push needs a physical iPhone."
        return
        #else
        guard state.preferences.anyEnabled else {
            await unregisterDevice()
            pushStatus = "Reset alerts are off"
            return
        }
        guard let token = KeychainStore.loadToken() else {
            pushStatus = resolvedBackendURL == nil ? "Add the push server URL in Settings" : "Waiting for an APNs token"
            return
        }
        guard let base = resolvedBackendURL, let baseURL = URL(string: base) else {
            pushStatus = "Add the push server URL in Settings"
            state.backendDeviceRegistered = false
            persist(reloadWidgets: false)
            return
        }
        let zone = state.timeDisplay == .utc ? "UTC" : TimeZone.current.identifier
        do {
            try await PushRegistrationService.register(
                baseURL: baseURL,
                installID: state.installID,
                token: token,
                sandbox: isSandboxBuild,
                timeZone: zone,
                preferences: state.preferences
            )
            state.backendDeviceRegistered = true
            state.registeredTimeZone = zone
            pushStatus = "Registered for reset alerts"
            persist(reloadWidgets: false)
        } catch {
            state.backendDeviceRegistered = false
            pushStatus = "Could not reach the push server"
            persist(reloadWidgets: false)
            CodexLog.debug("Push registration failed: \(error.localizedDescription)")
        }
        #endif
    }

    private func unregisterDevice() async {
        state.backendDeviceRegistered = false
        persist(reloadWidgets: false)
        guard let base = resolvedBackendURL, let baseURL = URL(string: base) else { return }
        try? await PushRegistrationService.unregister(baseURL: baseURL, installID: state.installID)
    }

    private var isSandboxBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
