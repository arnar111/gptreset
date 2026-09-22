import Foundation

public enum CodexLog {
    public static func debug(_ message: String) {
        #if DEBUG
        print("[CodexReset] \(message)")
        #endif
    }
}
