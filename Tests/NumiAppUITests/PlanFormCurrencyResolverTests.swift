import XCTest
@testable import NumiAppUI
import NumiCore

final class PlanFormCurrencyResolverTests: XCTestCase {
    func testExistingPlanCurrencyOverridesCurrentLedgerCurrency() {
        XCTAssertEqual(
            PlanFormCurrencyResolver.currencyCode(existingCurrencyCode: "USD", defaultCurrencyCode: "CNY"),
            "USD"
        )
    }

    func testNewPlanUsesCurrentLedgerCurrency() {
        XCTAssertEqual(
            PlanFormCurrencyResolver.currencyCode(existingCurrencyCode: nil, defaultCurrencyCode: "JPY"),
            "JPY"
        )
    }

    func testCompatibleAccountsKeepsOnlyMatchingCurrencyInSourceOrder() {
        let usd = Account(name: "USD", type: .cash, balance: Money(minorUnits: 0, currencyCode: "USD"))
        let cny = Account(name: "CNY", type: .cash, balance: Money(minorUnits: 0, currencyCode: "CNY"))
        let secondUSD = Account(name: "USD Card", type: .debitCard, balance: Money(minorUnits: 0, currencyCode: "USD"))

        XCTAssertEqual(
            PlanFormCurrencyResolver.compatibleAccounts([usd, cny, secondUSD], currencyCode: "USD").map(\.id),
            [usd.id, secondUSD.id]
        )
    }
}
