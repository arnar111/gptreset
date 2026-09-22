import Foundation

/// Values that are part of the product, not user data.
public enum ResetTrackerDefaults {
    /// Widgets stay in celebration mode for this long after a confirmed full reset.
    public static let celebrationHours = 6
    public static let historyPageSize = 50
    public static let maxHistoryPages = 2
    public static let apiBaseURL = URL(string: "https://codex-resets.com")!
    public static let attributionURL = URL(string: "https://codex-resets.com/")!
    public static let appGroupIdentifier = "group.com.arnar111.codexresettracker"
    public static let urlScheme = "codexreset"
    public static let stateFileName = "state.json"
    /// Shared by local alerts, APNs, and the notification content extension.
    public static let notificationCategory = "codex.reset"
}
