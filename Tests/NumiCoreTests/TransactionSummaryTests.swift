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

    func testMonthlySummaryConvertsForeignTransactionsUsingHistoricalRates() throws {
        let ledgerID = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let history = ExchangeRateHistory(snapshots: [
            ExchangeRateSnapshot(baseCode: "CNY", rates: ["CNY": 1, "USD": 0.14], effectiveDate: date)
        ])
        let transactions = [
            Transaction(type: .expense, amount: Money(minorUnits: 1_000, currencyCode: "CNY"), occurredAt: date, ledgerID: ledgerID),
            Transaction(type: .expense, amount: Money(minorUnits: 1_000, currencyCode: "USD"), occurredAt: date, ledgerID: ledgerID)
        ]

        let summary = try TransactionSummary.monthly(
            transactions: transactions,
            currencyCode: "CNY",
            exchangeRateHistory: history
        )

        XCTAssertEqual(summary.expense, try Money(decimalString: "81.43", currencyCode: "CNY"))
        XCTAssertEqual(summary.income, Money.zero(currencyCode: "CNY"))
    }

    func testMonthlySummaryThrowsWhenHistoricalRateIsMissing() throws {
        let transaction = Transaction(
            type: .expense,
            amount: try Money(decimalString: "10", currencyCode: "USD"),
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertThrowsError(
            try TransactionSummary.monthly(
                transactions: [transaction],
                currencyCode: "CNY",
                exchangeRateHistory: ExchangeRateHistory()
            )
        ) { error in
            XCTAssertEqual(error as? TransactionSummaryError, .missingExchangeRate(sourceCurrencyCode: "USD", targetCurrencyCode: "CNY"))
        }
    }
}
