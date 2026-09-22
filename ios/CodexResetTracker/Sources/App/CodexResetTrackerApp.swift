import SwiftUI
import CodexResetCore

@main
struct CodexResetTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task {
                    await model.refresh()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await model.refresh() }
                    }
                }
                .onOpenURL { url in
                    model.handle(url: url)
                }
        }
    }
}
