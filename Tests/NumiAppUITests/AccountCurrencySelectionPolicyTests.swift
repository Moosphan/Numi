import XCTest
import NumiCore
@testable import NumiAppUI

final class AccountCurrencySelectionPolicyTests: XCTestCase {
    func testSelectingTheSameCurrencyDoesNotNeedProAccess() {
        XCTAssertNil(AccountCurrencySelectionPolicy.featureRequest(
            currentCurrencyCode: "CNY",
            selectedCurrencyCode: "cny"
        ))
    }

    func testSelectingAnotherCurrencyUsesTheSharedMultiCurrencyGate() {
        XCTAssertEqual(AccountCurrencySelectionPolicy.featureRequest(
            currentCurrencyCode: "CNY",
            selectedCurrencyCode: "USD"
        ), .openMultiCurrency)
    }
}
