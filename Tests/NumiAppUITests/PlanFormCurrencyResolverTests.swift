import XCTest
@testable import NumiAppUI

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
}
