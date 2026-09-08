import Foundation

/// Selects one backing store for every process that can write transactions.
/// App Intents must never keep writing the App Group database after the main
/// app has moved to the CloudKit-backed store.
public enum CloudSyncStoreMode: Equatable, Sendable {
    case sharedAppGroup
    case cloudKit
}

public enum CloudSyncStorePolicy {
    public static func storageMode(isCloudSyncEnabled: Bool) -> CloudSyncStoreMode {
        isCloudSyncEnabled ? .cloudKit : .sharedAppGroup
    }
}

/// The main app mirrors this preference into the App Group so its App Intent
/// extension can choose the same storage mode in a fresh process.
public enum CloudSyncSharedPreference {
    public static let appGroupIdentifier = "group.com.numi.shared"
    private static let key = "app.sync.icloudEnabled"

    public static var isCloudSyncEnabled: Bool {
        UserDefaults(suiteName: appGroupIdentifier)?.bool(forKey: key) ?? false
    }

    public static func setCloudSyncEnabled(_ isEnabled: Bool) {
        UserDefaults(suiteName: appGroupIdentifier)?.set(isEnabled, forKey: key)
    }
}
