import XCTest
@testable import NumiCore

final class TransactionSummaryTests: XCTestCase {
    func testMonthlySummaryExcludesTransfersFromIncomeAndExpense() throws {
        let transactions = [
            Transaction.sample(type: .expense, amount: try Money(decimalString: "80", currencyCode: "CNY")),
            Transaction.sample(type: .income, amount: try Money(decimalString: "200", currencyCode: "CNY")),
            Transaction.sample(type: .transfer, amount: try Money(decimalString: "50", currencyCode: "CNY"))
        ]

        let summary = try TransactionSummary.monthly(transactions: transactions, currencyCode: "CNY")

        XCTAssertEqual(summary.expense.formatted(), "¥80.00")
        XCTAssertEqual(summary.income.formatted(), "¥200.00")
        XCTAssertEqual(summary.balance.formatted(), "¥120.00")
        XCTAssertEqual(summary.recordCount, 3)
    }

    func testCategoryDistributionRanksExpenseCategories() throws {
        let food = UUID()
        let transport = UUID()
        let transactions = [
            Transaction.sample(type: .expense, amount: try Money(decimalString: "80", currencyCode: "CNY"), categoryID: food),
            Transaction.sample(type: .expense, amount: try Money(decimalString: "20", currencyCode: "CNY"), categoryID: transport),
            Transaction.sample(type: .income, amount: try Money(decimalString: "100", currencyCode: "CNY"), categoryID: UUID())
        ]

        let distribution = try CategoryDistribution.expense(transactions: transactions, currencyCode: "CNY")

        XCTAssertEqual(distribution.map(\.categoryID), [food, transport])
        XCTAssertEqual(distribution[0].amount.formatted(), "¥80.00")
        XCTAssertEqual(distribution[0].percentage, 0.8, accuracy: 0.0001)
    }
}
