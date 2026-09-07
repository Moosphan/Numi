import XCTest
import NumiCore
@testable import NumiAppUI

final class InsightsAccountFilterPolicyTests: XCTestCase {
    func testIncludesAllTransactionsWhenNoAccountIsSelected() {
        let transaction = Transaction(
            type: .expense,
            amount: Money(minorUnits: 1200, currencyCode: "CNY"),
            occurredAt: Date(),
            categoryID: UUID(),
            accountID: UUID()
        )

        XCTAssertTrue(InsightsAccountFilterPolicy.includes(transaction, accountID: nil))
    }

    func testMatchesBothSidesOfTransferForSelectedAccount() {
        let sourceAccountID = UUID()
        let targetAccountID = UUID()
        let transfer = Transaction(
            type: .transfer,
            amount: Money(minorUnits: 1200, currencyCode: "CNY"),
            occurredAt: Date(),
            categoryID: UUID(),
            accountID: sourceAccountID,
            targetAccountID: targetAccountID
        )

        XCTAssertTrue(InsightsAccountFilterPolicy.includes(transfer, accountID: sourceAccountID))
        XCTAssertTrue(InsightsAccountFilterPolicy.includes(transfer, accountID: targetAccountID))
        XCTAssertFalse(InsightsAccountFilterPolicy.includes(transfer, accountID: UUID()))
    }
}
