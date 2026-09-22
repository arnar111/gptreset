import Foundation

#if os(iOS)
public enum SharedStateStore {
    public static func directory() -> URL {
        if let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ResetTrackerDefaults.appGroupIdentifier
        ) {
            return url
        }
        CodexLog.debug("App Group \(ResetTrackerDefaults.appGroupIdentifier) is not available. Using application support until signing is configured.")
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let fallback = base.appendingPathComponent("CodexResetTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }

    public static func store() -> FileResetStore {
        FileResetStore(directory: directory())
    }

    public static func load() -> PersistedState {
        store().load()
    }

    public static func loadIfPresent() -> PersistedState? {
        store().loadIfPresent()
    }

    public static func save(_ state: PersistedState) {
        do {
            try store().save(state)
        } catch {
            CodexLog.debug("Failed to save shared state: \(error)")
        }
    }

    @discardableResult
    public static func update(_ mutate: (inout PersistedState) -> Void) -> PersistedState {
        let url = directory().appendingPathComponent(ResetTrackerDefaults.stateFileName)
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var result = load()
        coordinator.coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { coordinated in
            let fileStore = FileResetStore(
                directory: coordinated.deletingLastPathComponent(),
                fileName: coordinated.lastPathComponent
            )
            var state = fileStore.load()
            mutate(&state)
            do {
                try fileStore.save(state)
                result = state
            } catch {
                CodexLog.debug("Coordinated save failed: \(error)")
                result = state
            }
        }
        if let coordinationError {
            CodexLog.debug("File coordination failed: \(coordinationError)")
            var state = load()
            mutate(&state)
            save(state)
            return state
        }
        return result
    }
}
#endif
