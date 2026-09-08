import Foundation

/// Retains the single persistent store instance for a process lifetime.
///
/// SwiftUI may recreate a `View` value whenever unrelated observable state
/// changes. Creating a SwiftData `ModelContainer` from that view initializer
/// would reopen the SQLite store every time and exhaust file descriptors.
@MainActor
public final class PersistentStoreBootstrap<Store> {
    private let build: () -> Store
    private var cachedStore: Store?

    public init(build: @escaping () -> Store) {
        self.build = build
    }

    public func store() -> Store {
        if let cachedStore {
            return cachedStore
        }

        let store = build()
        cachedStore = store
        return store
    }
}
