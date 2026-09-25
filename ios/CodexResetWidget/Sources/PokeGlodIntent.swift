import AppIntents
import Foundation
import WidgetKit
import CodexResetCore

/// Tapping Glóð on a Home Screen widget. The next timeline starts with a
/// jump pose and settles back a few seconds later; WidgetKit animates both changes.
struct PokeGlodIntent: AppIntent {
    static var title: LocalizedStringResource = "Poke Glóð"
    static var description = IntentDescription("Make Glóð jump on the widget.")
    static var openAppWhenRun = false
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        GlodPokeStore.poke(now: Date())
        WidgetCenter.shared.reloadTimelines(ofKind: CodexStatusWidget.kind)
        WidgetCenter.shared.reloadTimelines(ofKind: CodexBankedWidget.kind)
        return .result()
    }
}

enum GlodPokeStore {
    private static let key = "glod.pokedAt"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: ResetTrackerDefaults.appGroupIdentifier) ?? .standard
    }

    static func poke(now: Date) {
        defaults.set(now.timeIntervalSince1970, forKey: key)
    }

    static func wasPoked(within seconds: TimeInterval, now: Date) -> Bool {
        let stamp = defaults.double(forKey: key)
        guard stamp > 0 else { return false }
        let age = now.timeIntervalSince1970 - stamp
        return age >= 0 && age <= seconds
    }
}

enum WidgetLook: String, AppEnum {
    case glod
    case classic

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Look"
    static var caseDisplayRepresentations: [WidgetLook: DisplayRepresentation] = [
        .glod: "Glóð",
        .classic: "Classic",
    ]
}

struct StatusWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Codex Reset"
    static var description = IntentDescription("Choose how the widget looks.")

    @Parameter(title: "Look", default: .glod)
    var look: WidgetLook
}
