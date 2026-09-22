import SwiftUI
import CodexResetCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var backendDraft = ""

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Full resets", isOn: preference(\.fullResets))
                Toggle("Banked resets", isOn: preference(\.bankedResets))
                Toggle("Scheduled resets", isOn: preference(\.scheduledResets))
                Button("Enable notifications") {
                    Task { await model.enableNotifications() }
                }
                LabeledContent("Push status", value: model.pushStatus)
                Text("Alerts are delivered by this app's server, which polls Codex Resets. The iPhone cannot reliably check every minute on its own.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Push server") {
                TextField("https://your-worker.workers.dev", text: $backendDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .onSubmit { model.setBackendURL(backendDraft) }
                Button("Save server URL") {
                    model.setBackendURL(backendDraft)
                }
            }

            Section("Widget") {
                Stepper(value: Binding(
                    get: { model.state.celebrationHours },
                    set: { model.setCelebrationHours($0) }
                ), in: 1...24) {
                    Text("Recent reset celebration: \(model.state.celebrationHours) hours")
                }
                Picker("Time display", selection: Binding(
                    get: { model.state.timeDisplay },
                    set: { model.setTimeDisplay($0) }
                )) {
                    Text("Local").tag(TimeDisplay.local)
                    Text("UTC").tag(TimeDisplay.utc)
                }
            }

            Section("Banked resets") {
                LabeledContent("Available", value: "\(model.bankedAvailable)")
                NavigationLink("Correct banked count") {
                    BankedCorrectionView()
                }
            }

            Section("About") {
                AttributionFooter()
                Text("Codex Reset Tracker follows public reset announcements. It does not sign in to ChatGPT, estimate remaining usage, or track you.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                LabeledContent("Version", value: appVersion)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            backendDraft = model.state.backendBaseURL ?? model.resolvedBackendURL ?? ""
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func preference(_ keyPath: WritableKeyPath<NotificationPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.state.preferences[keyPath: keyPath] },
            set: { newValue in
                var preferences = model.state.preferences
                preferences[keyPath: keyPath] = newValue
                model.setPreferences(preferences)
            }
        )
    }
}
