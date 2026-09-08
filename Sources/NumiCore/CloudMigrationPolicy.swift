import Foundation

/// The only safe automatic migration uses a complete snapshot. Entity-level
/// merging is intentionally deferred because account balances and plan links
/// cannot be recomputed losslessly from two independently edited snapshots.
public enum CloudMigrationResolution: Equatable, Sendable {
    case importLocal
    case keepICloud
    case requiresDecision
}

public enum CloudMigrationConflictStrategy: Equatable, Sendable {
    case preferLocal
    case preferICloud
    case cancel
}

public struct CloudMigrationAssessment: Equatable, Sendable {
    public let localTransactionCount: Int
    public let cloudTransactionCount: Int
    public let localAccountCount: Int
    public let cloudAccountCount: Int
    public let localInstallmentPlanCount: Int
    public let cloudInstallmentPlanCount: Int
    public let resolution: CloudMigrationResolution

    public init(local: BookkeepingSnapshot, cloud: BookkeepingSnapshot) {
        localTransactionCount = local.transactions.count
        cloudTransactionCount = cloud.transactions.count
        localAccountCount = local.accounts.count
        cloudAccountCount = cloud.accounts.count
        localInstallmentPlanCount = local.installmentPlans.count
        cloudInstallmentPlanCount = cloud.installmentPlans.count
        if cloud.transactions.isEmpty && cloud.accounts.isEmpty && cloud.ledgers.isEmpty {
            resolution = .importLocal
        } else if local.transactions.isEmpty && local.accounts.isEmpty && local.ledgers.isEmpty {
            resolution = .keepICloud
        } else {
            resolution = .requiresDecision
        }
    }
}

public enum CloudMigrationPolicy {
    public static func assessment(
        local: BookkeepingSnapshot,
        cloud: BookkeepingSnapshot
    ) -> CloudMigrationAssessment {
        CloudMigrationAssessment(local: local, cloud: cloud)
    }

    /// The selected snapshot is applied atomically by the migration coordinator.
    /// Returning nil for cancel guarantees that neither source is overwritten.
    public static func snapshotToApply(
        local: BookkeepingSnapshot,
        cloud: BookkeepingSnapshot,
        strategy: CloudMigrationConflictStrategy
    ) -> BookkeepingSnapshot? {
        switch strategy {
        case .preferLocal:
            local
        case .preferICloud:
            cloud
        case .cancel:
            nil
        }
    }
}
