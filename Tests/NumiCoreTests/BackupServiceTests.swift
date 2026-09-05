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

    func testCSVExportPreservesTransactionRelationshipFields() throws {
        let targetAccountID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let reimbursementID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let refundID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let transaction = Transaction(
            type: .transfer,
            amount: try Money(decimalString: "12.30", currencyCode: "USD"),
            targetAccountID: targetAccountID,
            note: "Transfer, reimbursement",
            reimbursementID: reimbursementID,
            refundOfTransactionID: refundID
        )
        let url = try exportCSV(for: BookkeepingSnapshot(transactions: [transaction]))
        defer { try? FileManager.default.removeItem(at: url) }

        let csv = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(csv.contains("id,type,amount,currency,occurredAt,categoryID,accountID,targetAccountID,note,reimbursementID,refundOfTransactionID"))
        XCTAssertTrue(csv.contains(targetAccountID.uuidString))
        XCTAssertTrue(csv.contains(reimbursementID.uuidString))
        XCTAssertTrue(csv.contains(refundID.uuidString))
        XCTAssertTrue(csv.contains("\"Transfer, reimbursement\""))
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

    private func exportCSV(for snapshot: BookkeepingSnapshot) throws -> URL {
        switch BackupService.shared.exportCSV(snapshot: snapshot) {
        case .success(let url):
            return url
        case .failure(let error):
            throw NSError(domain: "BackupServiceTests", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Unable to export test CSV: \(error)"
            ])
        }
    }
}
