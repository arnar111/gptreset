import Foundation

enum CodexLog {
    static func debug(_ message: String) {
        #if DEBUG
        print("[CodexReset] \(message)")
        #endif
    }
}
