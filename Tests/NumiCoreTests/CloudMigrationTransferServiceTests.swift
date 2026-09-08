import XCTest
@testable import NumiCore

final class CloudMigrationTransferServiceTests: XCTestCase {
    func testStagedSnapshotRoundTripsAndCanBeDiscarded() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = CloudMigrationTransferService(directory: directory)
        let snapshot = BookkeepingSnapshot(
            ledgers: [Ledger(name: "Local", currencyCode: "CNY")],
            transactions: [Transaction(type: .expense, amount: Money(minorUnits: 1_200, currencyCode: "CNY"))]
        )

        try service.stage(snapshot)

        XCTAssertTrue(service.hasStagedSnapshot)
        XCTAssertEqual(try service.load(), snapshot)
        try service.discard()
        XCTAssertFalse(service.hasStagedSnapshot)
    }

    func testStagingAgainAtomicallyReplacesThePreviousSnapshot() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = CloudMigrationTransferService(directory: directory)
        let first = BookkeepingSnapshot(ledgers: [Ledger(name: "First", currencyCode: "CNY")])
        let replacement = BookkeepingSnapshot(ledgers: [Ledger(name: "Replacement", currencyCode: "USD")])

        try service.stage(first)
        try service.stage(replacement)

        XCTAssertEqual(try service.load(), replacement)
    }

    func testCloudRecoverySnapshotIsStoredSeparatelyFromTheLocalSource() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = CloudMigrationTransferService(directory: directory)
        let local = BookkeepingSnapshot(ledgers: [Ledger(name: "Local", currencyCode: "CNY")])
        let cloud = BookkeepingSnapshot(ledgers: [Ledger(name: "Cloud", currencyCode: "USD")])

        try service.stage(local)
        try service.stageCloudRecovery(cloud)

        XCTAssertEqual(try service.load(), local)
        XCTAssertEqual(try service.loadCloudRecovery(), cloud)
    }

    func testCompletingMigrationPreservesRecoveryCopiesAndNewStageReopensIt() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = CloudMigrationTransferService(directory: directory)
        let local = BookkeepingSnapshot(ledgers: [Ledger(name: "Local", currencyCode: "CNY")])
        let cloud = BookkeepingSnapshot(ledgers: [Ledger(name: "Cloud", currencyCode: "USD")])

        try service.stage(local)
        try service.stageCloudRecovery(cloud)
        XCTAssertTrue(service.isMigrationPending)

        try service.markCompleted()

        XCTAssertFalse(service.isMigrationPending)
        XCTAssertEqual(try service.load(), local)
        XCTAssertEqual(try service.loadCloudRecovery(), cloud)

        try service.stage(local)
        XCTAssertTrue(service.isMigrationPending)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CloudMigrationTransferServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
