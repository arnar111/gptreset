import SwiftUI

struct BankedCorrectionView: View {
    @Environment(AppModel.self) private var model
    @State private var draft = 0

    var body: some View {
        Form {
            Section {
                Stepper(value: $draft, in: 0...99) {
                    Text("\(draft) available")
                        .font(.title2.weight(.semibold))
                        .accessibilityLabel("\(draft) banked resets available")
                }
                Button("Save count") {
                    model.setBankedCount(draft)
                }
                .disabled(draft == model.bankedAvailable)
            } footer: {
                Text("Use this if you installed the app with credits already in your bank, or if the count drifted. Manual changes are stored separately from announcements, so the next banked reset from Codex Resets still adds one. Marking one as used never goes below zero.")
            }
        }
        .navigationTitle("Banked count")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            draft = model.bankedAvailable
        }
    }
}
