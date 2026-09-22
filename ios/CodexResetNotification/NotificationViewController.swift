import UIKit
import UserNotifications
import UserNotificationsUI

/// Expanded Lock Screen / Notification Center card. The collapsed banner stays the system title.
@objc(NotificationViewController)
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private let glow = UIView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let hairline = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 16 / 255, green: 17 / 255, blue: 19 / 255, alpha: 1)

        glow.translatesAutoresizingMaskIntoConstraints = false
        glow.backgroundColor = coral.withAlphaComponent(0.20)
        glow.layer.cornerRadius = 54
        glow.layer.shadowColor = coral.cgColor
        glow.layer.shadowOpacity = 0.45
        glow.layer.shadowRadius = 22
        glow.layer.shadowOffset = .zero
        glow.isHidden = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 2
        titleLabel.textColor = .white

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .preferredFont(forTextStyle: .subheadline)
        bodyLabel.adjustsFontForContentSizeCategory = true
        bodyLabel.numberOfLines = 3
        bodyLabel.textColor = UIColor(white: 1, alpha: 0.62)

        hairline.translatesAutoresizingMaskIntoConstraints = false
        hairline.backgroundColor = UIColor(white: 1, alpha: 0.14)

        view.addSubview(glow)
        view.addSubview(titleLabel)
        view.addSubview(bodyLabel)
        view.addSubview(hairline)

        NSLayoutConstraint.activate([
            glow.widthAnchor.constraint(equalToConstant: 108),
            glow.heightAnchor.constraint(equalToConstant: 108),
            glow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -18),
            glow.topAnchor.constraint(equalTo: view.topAnchor, constant: -36),

            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),

            bodyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            hairline.heightAnchor.constraint(equalToConstant: 0.5),
            hairline.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            hairline.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            hairline.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 12),
            hairline.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
        ])
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        titleLabel.text = content.title
        bodyLabel.text = content.body
        let kind = (content.userInfo["kind"] as? String) ?? content.threadIdentifier
        let fullReset = kind == "full"
        titleLabel.textColor = fullReset ? coral : UIColor(white: 0.94, alpha: 1)
        glow.isHidden = !fullReset
        view.accessibilityLabel = "\(content.title). \(content.body)"
    }

    private var coral: UIColor {
        UIColor(red: 232 / 255, green: 137 / 255, blue: 106 / 255, alpha: 1)
    }
}
