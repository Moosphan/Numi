import Foundation
import XCTest
@testable import NumiCore

final class ImportRecoveryPointServiceTests: XCTestCase {
    func testRecoveryPointRoundTripsTheCapturedSnapshot() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshot = BookkeepingSnapshot(
            ledgers: [Ledger(name: "Before import", currencyCode: "USD")],
            exportedAt: Date(timeIntervalSince1970: 1_725_000_000)
        )
        let service = ImportRecoveryPointService(directory: directory)

        try service.save(snapshot)

        XCTAssertTrue(service.hasRecoveryPoint)
        XCTAssertEqual(try service.load(), snapshot)
    }

    func testDiscardRemovesTheRecoveryPoint() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = ImportRecoveryPointService(directory: directory)
        try service.save(BookkeepingSnapshot())

        try service.discard()

        XCTAssertFalse(service.hasRecoveryPoint)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
