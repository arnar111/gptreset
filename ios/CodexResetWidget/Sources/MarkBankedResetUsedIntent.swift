import AppIntents
import WidgetKit
import CodexResetCore

struct MarkBankedResetUsedIntent: AppIntent {
    static var title: LocalizedStringResource = "Used banked reset"
    static var description = IntentDescription("Mark one banked Codex reset as used.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        let directory = SharedStateStore.directory()
        let store = FileResetStore(directory: directory)
        guard store.loadIfPresent() != nil else {
            return .result()
        }
        var changed = false
        _ = SharedStateStore.update { state in
            changed = BankedInventory.markOneUsed(&state.bankedRecords, now: Date())
        }
        if changed {
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}
