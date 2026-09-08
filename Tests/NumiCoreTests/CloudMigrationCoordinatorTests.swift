import XCTest
@testable import NumiCore

final class CloudMigrationCoordinatorTests: XCTestCase {
    func testCancelDoesNotApplyEitherSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let transfer = CloudMigrationTransferService(directory: directory)
        let local = BookkeepingSnapshot(ledgers: [Ledger(name: "Local", currencyCode: "CNY")])
        let cloud = BookkeepingSnapshot(ledgers: [Ledger(name: "Cloud", currencyCode: "USD")])
        var applied = false

        try CloudMigrationCoordinator(transferService: transfer).apply(
            local: local, cloud: cloud, strategy: .cancel
        ) { _ in applied = true }

        XCTAssertFalse(applied)
        XCTAssertEqual(try transfer.load(), local)
        XCTAssertEqual(try transfer.loadCloudRecovery(), cloud)
        XCTAssertTrue(transfer.isMigrationPending)
    }

    func testKeepingICloudDoesNotRewriteTheCloudDestination() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let transfer = CloudMigrationTransferService(directory: directory)
        let local = BookkeepingSnapshot(ledgers: [Ledger(name: "Local", currencyCode: "CNY")])
        let cloud = BookkeepingSnapshot(ledgers: [Ledger(name: "Cloud", currencyCode: "USD")])
        var applied = false

        try CloudMigrationCoordinator(transferService: transfer).apply(
            local: local, cloud: cloud, strategy: .preferICloud
        ) { _ in applied = true }

        XCTAssertFalse(applied)
        XCTAssertEqual(try transfer.load(), local)
        XCTAssertEqual(try transfer.loadCloudRecovery(), cloud)
        XCTAssertFalse(transfer.isMigrationPending)
    }
}
