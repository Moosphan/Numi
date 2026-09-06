import XCTest
import NumiCore
@testable import NumiAppUI

final class BudgetScopeMembershipPolicyTests: XCTestCase {
    func testBasicBudgetBecomesAdvancedWhenSelectingCategoryOrAccount() {
        XCTAssertEqual(
            BudgetScopeMembershipPolicy.featureRequest(
                existingCategoryID: nil,
                existingAccountID: nil,
                selectedCategoryID: UUID(),
                selectedAccountID: nil
            ),
            .openAdvancedBudget
        )
    }

    func testBasicBudgetDoesNotNeedProWhenScopeRemainsGlobal() {
        XCTAssertNil(
            BudgetScopeMembershipPolicy.featureRequest(
                existingCategoryID: nil,
                existingAccountID: nil,
                selectedCategoryID: nil,
                selectedAccountID: nil
            )
        )
    }

    func testExistingScopedBudgetDoesNotRelockAfterDowngrade() {
        XCTAssertNil(
            BudgetScopeMembershipPolicy.featureRequest(
                existingCategoryID: UUID(),
                existingAccountID: nil,
                selectedCategoryID: nil,
                selectedAccountID: UUID()
            )
        )
    }
}
