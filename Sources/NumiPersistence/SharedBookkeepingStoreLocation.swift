import Foundation

/// Resolves the database location shared by the main app and its App Intents extension.
///
/// The main database is deliberately kept in the App Group so a shortcut writes to
/// the exact same SwiftData store as the foreground app.
public enum SharedBookkeepingStoreLocation {
    public static let appGroupIdentifier = "group.com.numi.shared"
    public static let storeFileName = "Numi.store"

    public static func storeURL(fileManager: FileManager = .default) -> URL? {
        fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(storeFileName)
    }

    /// Copies an existing SQLite store into the shared container on first launch.
    /// The original database is left untouched so an interrupted migration remains recoverable.
    @discardableResult
    public static func migrateLegacyStoreIfNeeded(
        legacyStoreURL: URL,
        sharedStoreURL: URL,
        fileManager: FileManager = .default
    ) throws -> Bool {
        guard fileManager.fileExists(atPath: legacyStoreURL.path),
              !fileManager.fileExists(atPath: sharedStoreURL.path) else {
            return false
        }

        try fileManager.createDirectory(
            at: sharedStoreURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        for suffix in ["", "-wal", "-shm"] {
            let source = siblingURL(for: legacyStoreURL, suffix: suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let destination = siblingURL(for: sharedStoreURL, suffix: suffix)
            try fileManager.copyItem(at: source, to: destination)
        }
        return true
    }

    private static func siblingURL(for storeURL: URL, suffix: String) -> URL {
        storeURL.deletingLastPathComponent()
            .appendingPathComponent(storeURL.lastPathComponent + suffix)
    }
}
