import Foundation

/// Executes an already-confirmed whole-snapshot migration. The caller owns the
/// destination (iCloud) store; this coordinator guarantees both sources are
/// staged before any destination write. Keeping iCloud and cancelling are
/// no-ops for the destination store.
public struct CloudMigrationCoordinator: Sendable {
    private let transferService: CloudMigrationTransferService

    public init(transferService: CloudMigrationTransferService = .shared) {
        self.transferService = transferService
    }

    public func apply(
        local: BookkeepingSnapshot,
        cloud: BookkeepingSnapshot,
        strategy: CloudMigrationConflictStrategy,
        writeDestination: (BookkeepingSnapshot) throws -> Void
    ) throws {
        try transferService.stage(local)
        try transferService.stageCloudRecovery(cloud)
        switch strategy {
        case .preferLocal:
            try writeDestination(local)
            try transferService.markCompleted()
        case .preferICloud:
            try transferService.markCompleted()
        case .cancel:
            return
        }
    }
}
