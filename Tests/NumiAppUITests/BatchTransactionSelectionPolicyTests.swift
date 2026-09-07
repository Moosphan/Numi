import XCTest
import NumiCore
@testable import NumiAppUI

final class BatchTransactionSelectionPolicyTests: XCTestCase {
    func testAllowsTransactionsOfTheSameNonTransferType() {
        XCTAssertTrue(
            BatchTransactionSelectionPolicy.canAdd(
                expense(id: UUID()),
                to: [expense(id: UUID())]
            )
        )
    }

    func testRejectsTransactionOfAnotherType() {
        XCTAssertFalse(
            BatchTransactionSelectionPolicy.canAdd(
                income(id: UUID()),
                to: [expense(id: UUID())]
            )
        )
    }

    func testRejectsTransfersEvenForAnEmptySelection() {
        XCTAssertFalse(
            BatchTransactionSelectionPolicy.canAdd(
                Transaction(
                    type: .transfer,
                    amount: try! Money(decimalString: "10", currencyCode: "CNY"),
                    categoryID: nil,
                    accountID: UUID(),
                    targetAccountID: UUID(),
                    ledgerID: UUID(),
                    note: ""
                ),
                to: []
            )
        )
    }

    private func expense(id: UUID) -> Transaction {
        transaction(id: id, type: .expense)
    }

    private func income(id: UUID) -> Transaction {
        transaction(id: id, type: .income)
    }

    private func transaction(id: UUID, type: TransactionType) -> Transaction {
        Transaction(
            id: id,
            type: type,
            amount: try! Money(decimalString: "10", currencyCode: "CNY"),
            categoryID: UUID(),
            accountID: UUID(),
            ledgerID: UUID(),
            note: ""
        )
    }
}
