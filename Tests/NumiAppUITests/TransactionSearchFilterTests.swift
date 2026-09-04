import XCTest
import Foundation
import NumiCore
@testable import NumiAppUI

final class TransactionSearchFilterTests: XCTestCase {
    func testCombinedFilterMatchesAllSelectedDimensions() throws {
        let ledgerID = UUID()
        let categoryID = UUID()
        let accountID = UUID()
        let date = ISO8601DateFormatter().date(from: "2026-08-15T12:00:00Z")!
        let transaction = Transaction(
            type: .expense,
            amount: try Money(decimalString: "88.50", currencyCode: "CNY"),
            occurredAt: date,
            categoryID: categoryID,
            accountID: accountID,
            ledgerID: ledgerID,
            note: "周末聚餐"
        )
        let row = TransactionSearchRow(
            transaction: transaction,
            fallbackCategoryName: "餐饮",
            fallbackIconName: "fork.knife",
            fallbackSubtitle: "现金"
        )
        let filter = TransactionSearchFilter(
            query: "聚餐",
            type: .expense,
            categoryID: categoryID,
            accountID: accountID,
            dateInterval: DateInterval(start: date.addingTimeInterval(-3600), end: date.addingTimeInterval(3600)),
            minimumAmount: try Money(decimalString: "80", currencyCode: "CNY"),
            maximumAmount: try Money(decimalString: "90", currencyCode: "CNY")
        )

        XCTAssertTrue(filter.matches(row: row, categoryName: "餐饮", subtitle: "现金"))
    }

    func testFilterRejectsTransactionOutsideAmountAndDateRange() throws {
        let transaction = Transaction(
            type: .income,
            amount: try Money(decimalString: "120", currencyCode: "CNY"),
            occurredAt: ISO8601DateFormatter().date(from: "2026-07-01T12:00:00Z")!,
            note: "工资"
        )
        let row = TransactionSearchRow(transaction: transaction, fallbackCategoryName: "工资", fallbackIconName: "banknote", fallbackSubtitle: nil)
        let filter = TransactionSearchFilter(
            type: .income,
            dateInterval: DateInterval(
                start: ISO8601DateFormatter().date(from: "2026-08-01T00:00:00Z")!,
                end: ISO8601DateFormatter().date(from: "2026-08-31T23:59:59Z")!
            ),
            minimumAmount: try Money(decimalString: "100", currencyCode: "CNY"),
            maximumAmount: try Money(decimalString: "130", currencyCode: "CNY")
        )

        XCTAssertFalse(filter.matches(row: row, categoryName: "工资", subtitle: nil))
    }
}
