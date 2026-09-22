import UIKit
import UserNotifications
import CodexResetCore

/// Routes APNs callbacks into the SwiftUI model without holding it strongly.
@MainActor
final class PushBridge {
    static let shared = PushBridge()
    var onToken: ((String) -> Void)?
    var onDeepLink: ((String) -> Void)?
    var onRemote: (() -> Void)?
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: ResetTrackerDefaults.notificationCategory,
                actions: [],
                intentIdentifiers: [],
                options: []
            ),
        ])
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            PushBridge.shared.onToken?(token)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        CodexLog.debug("APNs registration failed: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        await MainActor.run {
            PushBridge.shared.onRemote?()
        }
        return .newData
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        await MainActor.run {
            PushBridge.shared.onRemote?()
        }
        return [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let eventID = response.notification.request.content.userInfo["eventId"] as? String
        await MainActor.run {
            if let eventID {
                PushBridge.shared.onDeepLink?(eventID)
            }
            PushBridge.shared.onRemote?()
        }
    }
}
