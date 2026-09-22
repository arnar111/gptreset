import SwiftUI

struct NotificationPromptView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Know when a reset lands")
                    .font(.largeTitle.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Codex Reset Tracker can alert you when usage limits are reset, when a banked reset is added, and when a reset is scheduled. It never sees your ChatGPT account.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Button {
                    Task {
                        await model.enableNotifications()
                        dismiss()
                    }
                } label: {
                    Text("Enable notifications")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button("Not now") {
                    model.dismissNotificationPrompt()
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
            }
            .padding(24)
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
