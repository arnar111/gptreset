import SwiftUI
import WidgetKit

@main
struct CodexResetWidgetBundle: WidgetBundle {
    var body: some Widget {
        CodexStatusWidget()
        CodexBankedWidget()
    }
}
