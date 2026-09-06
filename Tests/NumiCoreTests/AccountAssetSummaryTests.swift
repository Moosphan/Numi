import XCTest
@testable import NumiCore

final class AccountAssetSummaryTests: XCTestCase {
    func testCalculateConvertsIncludedAccountsToTargetCurrency() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let history = ExchangeRateHistory(snapshots: [
            ExchangeRateSnapshot(baseCode: "CNY", rates: ["CNY": 1, "USD": 0.14], effectiveDate: date)
        ])

        let summary = AccountAssetSummary.calculate(
            accounts: [
                Account(name: "Cash", type: .cash, balance: try Money(decimalString: "100", currencyCode: "CNY")),
                Account(name: "USD", type: .debitCard, balance: try Money(decimalString: "14", currencyCode: "USD"))
            ],
            targetCurrencyCode: "CNY",
            exchangeRateHistory: history,
            at: date
        )

        XCTAssertEqual(summary.total, try Money(decimalString: "200", currencyCode: "CNY"))
        XCTAssertEqual(summary.includedAccountCount, 2)
        XCTAssertEqual(summary.convertedAccountCount, 2)
        XCTAssertEqual(summary.unavailableAccountCount, 0)
    }

    func testCalculateDisclosesIncludedAccountsWithoutAnExchangeRate() throws {
        let summary = AccountAssetSummary.calculate(
            accounts: [
                Account(name: "Cash", type: .cash, balance: try Money(decimalString: "100", currencyCode: "CNY")),
                Account(name: "USD", type: .debitCard, balance: try Money(decimalString: "14", currencyCode: "USD"))
            ],
            targetCurrencyCode: "CNY",
            exchangeRateHistory: ExchangeRateHistory(),
            at: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(summary.total, try Money(decimalString: "100", currencyCode: "CNY"))
        XCTAssertEqual(summary.includedAccountCount, 2)
        XCTAssertEqual(summary.convertedAccountCount, 1)
        XCTAssertEqual(summary.unavailableAccountCount, 1)
    }
}
