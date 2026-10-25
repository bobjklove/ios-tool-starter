import Foundation
import Combine

@MainActor final class FreeTierStore: ObservableObject {
    static let key = "free-export-history-v1"
    private struct History: Codable {
        var version = 1
        var fingerprints: Set<String> = []
    }
    @Published private var history = History()
    @Published private(set) var error: Error?
    private let defaults: UserDefaults
    var remaining: Int { error == nil ? max(0, AppConfiguration.freeExports - history.fingerprints.count) : 0 }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key) {
            do {
                history = try JSONDecoder().decode(History.self, from: data)
                guard history.version == 1 else { throw StarterError.unsupportedVersion }
            } catch { self.error = error }
        }
    }
    func allows(_ fingerprint: String, unlocked: Bool) -> Bool {
        unlocked || (error == nil && (remaining > 0 || history.fingerprints.contains(fingerprint)))
    }
    /// Call only after a successful share, never for generation, cancellation or failure.
    func recordCompleted(_ fingerprint: String, unlocked: Bool) throws {
        guard !unlocked else { return }
        guard allows(fingerprint, unlocked: false) else { throw StarterError.quota }
        history.fingerprints.insert(fingerprint)
        defaults.set(try JSONEncoder().encode(history), forKey: Self.key)
    }
}
