import Foundation

public struct FileResetStore {
    public var directory: URL
    public var fileName: String

    public init(directory: URL, fileName: String = ResetTrackerDefaults.stateFileName) {
        self.directory = directory
        self.fileName = fileName
    }

    public var fileURL: URL {
        directory.appendingPathComponent(fileName)
    }

    public func loadIfPresent() -> PersistedState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(PersistedState.self, from: data)
        } catch {
            CodexLog.debug("Cached state could not be read and was ignored: \(error)")
            return nil
        }
    }

    public func load() -> PersistedState {
        loadIfPresent() ?? .fresh()
    }

    public func save(_ state: PersistedState) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
    }
}
