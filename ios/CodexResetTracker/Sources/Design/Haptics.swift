import UIKit

enum Haptics {
    static func success() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
