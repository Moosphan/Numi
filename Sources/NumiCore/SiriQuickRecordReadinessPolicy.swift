import Foundation

public enum SiriQuickRecordReadiness: Equatable, Sendable {
    case ready
    case setUpCategories
    case waitForCloudData
}

/// Keeps a fresh CloudKit store from being mistaken for an unconfigured local
/// installation when Siri starts before the initial import is visible.
public enum SiriQuickRecordReadinessPolicy {
    public static func state(
        hasCategories: Bool,
        storageMode: CloudSyncStoreMode
    ) -> SiriQuickRecordReadiness {
        guard !hasCategories else { return .ready }
        return storageMode == .cloudKit ? .waitForCloudData : .setUpCategories
    }
}
