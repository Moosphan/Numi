import XCTest
@testable import NumiCore

final class BudgetCalculatorTests: XCTestCase {

    func testBudgetSpendingExcludesReimbursedExpenseAndOffsetsRefund() throws {
        let ledgerID = UUID()
        let categoryID = UUID()
        let accountID = UUID()
        let originalID = UUID()
        let reimbursed = Transaction(
            id: UUID(), type: .expense, amount: try Money(decimalString: "80", currencyCode: "CNY"),
            categoryID: categoryID, accountID: accountID, ledgerID: ledgerID, reimbursementID: UUID()
        )
        let original = Transaction(
            id: originalID, type: .expense, amount: try Money(decimalString: "120", currencyCode: "CNY"),
            categoryID: categoryID, accountID: accountID, ledgerID: ledgerID
        )
        let refund = Transaction(
            id: UUID(), type: .income, amount: try Money(decimalString: "30", currencyCode: "CNY"),
            categoryID: UUID(), accountID: accountID, ledgerID: ledgerID, refundOfTransactionID: originalID
        )

        let spending = try BudgetSpendingCalculator.spending(
            from: [reimbursed, original, refund], categoryID: categoryID, accountID: accountID, currencyCode: "CNY"
        )

        XCTAssertEqual(spending, try Money(decimalString: "90", currencyCode: "CNY"))
    }

    func testLegacyTransactionJSONWithoutBudgetLinksStillDecodes() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","type":"expense","amount":{"minorUnits":100,"currencyCode":"CNY"},"occurredAt":"2026-01-01T00:00:00Z","ledgerID":"00000000-0000-0000-0000-000000000002","note":"旧数据"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let transaction = try decoder.decode(Transaction.self, from: json)
        XCTAssertNil(transaction.reimbursementID)
        XCTAssertNil(transaction.refundOfTransactionID)
    }
    func testMonthlyBudgetReportsRemainingAndDailySuggestion() throws {
        let budget = BudgetLimit(
            amount: try Money(decimalString: "3000", currencyCode: "CNY"),
            period: .month,
            startsOn: DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 6, day: 1).date!,
            endsOn: DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 6, day: 30).date!
        )
        let spent = try Money(decimalString: "1200", currencyCode: "CNY")
        let today = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 6, day: 18).date!

        let status = try BudgetCalculator.status(for: budget, spent: spent, today: today)

        XCTAssertEqual(status.remaining.formatted(), "¥1,800.00")
        XCTAssertEqual(status.dailySuggestion.formatted(), "¥138.46")
        XCTAssertFalse(status.isOverBudget)
    }

    func testOverBudgetReportsNegativeRemaining() throws {
        let budget = BudgetLimit(
            amount: try Money(decimalString: "100", currencyCode: "CNY"),
            period: .week,
            startsOn: DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 6, day: 15).date!,
            endsOn: DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 6, day: 21).date!
        )
        let spent = try Money(decimalString: "140", currencyCode: "CNY")
        let today = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 6, day: 18).date!

        let status = try BudgetCalculator.status(for: budget, spent: spent, today: today)

        XCTAssertEqual(status.remaining.formatted(), "-¥40.00")
        XCTAssertTrue(status.isOverBudget)
        XCTAssertEqual(status.dailySuggestion.formatted(), "¥0.00")
    }
}
