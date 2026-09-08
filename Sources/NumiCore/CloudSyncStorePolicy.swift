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
    private static let currentLedgerKey = "app.currentLedgerID"

    public static var isCloudSyncEnabled: Bool {
        UserDefaults(suiteName: appGroupIdentifier)?.bool(forKey: key) ?? false
    }

    public static func setCloudSyncEnabled(_ isEnabled: Bool) {
        UserDefaults(suiteName: appGroupIdentifier)?.set(isEnabled, forKey: key)
    }

    public static var currentLedgerID: UUID? {
        guard let rawValue = UserDefaults(suiteName: appGroupIdentifier)?.string(forKey: currentLedgerKey) else {
            return nil
        }
        return UUID(uuidString: rawValue)
    }

    public static func setCurrentLedgerID(_ ledgerID: UUID?) {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        if let ledgerID {
            defaults?.set(ledgerID.uuidString, forKey: currentLedgerKey)
        } else {
            defaults?.removeObject(forKey: currentLedgerKey)
        }
    }
}

public enum CurrentLedgerSelectionPolicy {
    public static func resolve(currentLedgerID: UUID?, from ledgers: [Ledger]) -> Ledger? {
        guard let currentLedgerID else { return ledgers.first }
        return ledgers.first(where: { $0.id == currentLedgerID }) ?? ledgers.first
    }
}
