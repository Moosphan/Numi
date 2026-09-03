import XCTest
import NumiCore
@testable import NumiAppUI

final class PrivacyAmountDisplayPolicyTests: XCTestCase {
    func testDisplayMasksMoneyOnlyWhenPolicyIsHidden() throws {
        let amount = try Money(decimalString: "1234.56", currencyCode: "CNY")

        XCTAssertEqual(
            PrivacyAmountDisplayPolicy(isHidden: false).display(amount),
            amount.formatted()
        )
        XCTAssertEqual(
            PrivacyAmountDisplayPolicy(isHidden: true).display(amount),
            "••••"
        )
    }

    func testDisplayPreservesSignForHiddenSignedAmounts() throws {
        let amount = try Money(decimalString: "42.00", currencyCode: "CNY")

        XCTAssertEqual(
            PrivacyAmountDisplayPolicy(isHidden: true).display(amount, prefix: "-"),
            "-••••"
        )
    }
}
