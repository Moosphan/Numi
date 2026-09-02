import Foundation
import XCTest
@testable import NumiCore

final class BackupServiceTests: XCTestCase {
    func testRestoreBackupReturnsTheOriginalSnapshot() throws {
        let snapshot = BookkeepingSnapshot(
            ledgers: [Ledger(name: "Travel", currencyCode: "USD")],
            exportedAt: Date(timeIntervalSince1970: 1_725_000_000)
        )
        let url = try createBackup(for: snapshot, password: "correct horse")
        defer { try? FileManager.default.removeItem(at: url) }

        switch BackupService.shared.restoreBackup(from: url, password: "correct horse") {
        case .success(let restoredSnapshot):
            XCTAssertEqual(restoredSnapshot, snapshot)
        case .failure(let error):
            XCTFail("Expected restore success, got \(error)")
        }
    }

    func testRestoreBackupRejectsWrongPassword() throws {
        let url = try createBackup(for: BookkeepingSnapshot(), password: "correct horse")
        defer { try? FileManager.default.removeItem(at: url) }

        switch BackupService.shared.restoreBackup(from: url, password: "wrong password") {
        case .success:
            XCTFail("Expected restore failure for a wrong password")
        case .failure(let error):
            XCTAssertEqual(error, .restoreBackup)
        }
    }

    private func createBackup(for snapshot: BookkeepingSnapshot, password: String) throws -> URL {
        switch BackupService.shared.createBackup(snapshot: snapshot, password: password) {
        case .success(let url):
            return url
        case .failure(let error):
            throw NSError(domain: "BackupServiceTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Unable to create test backup: \(error)"
            ])
        }
    }
}
