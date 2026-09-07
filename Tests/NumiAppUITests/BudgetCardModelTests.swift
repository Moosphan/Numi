import XCTest
import NumiCore
@testable import NumiAppUI

final class BudgetCardModelTests: XCTestCase {
    func testAvailableAmountIncludesOnlyConfiguredCarryover() throws {
        let budget = try Money(decimalString: "100", currencyCode: "CNY")
        let carried = try Money(decimalString: "36", currencyCode: "CNY")
        let model = BudgetCardModel(
            period: .month,
            amount: budget,
            spent: .zero(currencyCode: "CNY"),
            status: BudgetStatus(
                remaining: try Money(decimalString: "136", currencyCode: "CNY"),
                dailySuggestion: budget,
                isOverBudget: false
            ),
            isEnabled: true,
            isRolloverEnabled: true,
            carriedOverAmount: carried
        )

        XCTAssertEqual(model.availableAmount, try Money(decimalString: "136", currencyCode: "CNY"))
    }
}
