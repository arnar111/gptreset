import Foundation
import UserNotifications
import CodexResetCore

struct NotificationPresenter {
    func deliver(_ notes: [PlannedNotification], pushActive: Bool) async {
        guard !notes.isEmpty else { return }
        #if targetEnvironment(simulator)
        let useLocal = true
        #else
        let useLocal = !pushActive
        #endif
        guard useLocal else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }
        for note in notes {
            let content = UNMutableNotificationContent()
            content.title = note.title
            content.body = note.body
            content.sound = .default
            content.threadIdentifier = note.kind.rawValue
            content.userInfo = [
                "eventId": note.eventID,
                "dedupeKey": note.dedupeKey,
                "link": note.deepLink,
            ]
            let request = UNNotificationRequest(identifier: note.dedupeKey, content: content, trigger: nil)
            try? await center.add(request)
        }
    }
}
