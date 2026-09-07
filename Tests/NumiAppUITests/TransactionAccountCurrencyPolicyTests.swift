import XCTest
import NumiCore
@testable import NumiAppUI

final class TransactionAccountCurrencyPolicyTests: XCTestCase {
    func testCompatibleAccountsKeepOnlyTheSelectedTransactionCurrency() {
        let cny = Account(name: "现金", type: .cash, balance: .zero(currencyCode: "CNY"))
        let usd = Account(name: "USD Cash", type: .cash, balance: .zero(currencyCode: "USD"))

        XCTAssertEqual(
            TransactionAccountCurrencyPolicy.compatibleAccounts([cny, usd], currencyCode: "usd").map(\.id),
            [usd.id]
        )
    }
}
