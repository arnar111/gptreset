import SwiftUI
import CodexResetCore

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView(selection: Binding(
            get: { model.selectedTab },
            set: { model.selectedTab = $0 }
        )) {
            DashboardView()
                .tag(0)
                .tabItem { Label("Status", systemImage: "flame") }
            HistoryView()
                .tag(1)
                .tabItem { Label("History", systemImage: "clock") }
        }
        .tint(Color(red: 0.70, green: 0.30, blue: 0.07))
        .sheet(isPresented: Binding(
            get: { !model.state.didPromptForNotifications },
            set: { isPresented in
                if !isPresented { model.dismissNotificationPrompt() }
            }
        )) {
            NotificationPromptView()
                .interactiveDismissDisabled(false)
        }
    }
}
