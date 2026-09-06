import XCTest
@testable import NumiAppUI

final class BudgetScopeConflictPolicyTests: XCTestCase {
    func testDetectsAnExactCategoryAndAccountScopeMatch() {
        let categoryID = UUID()
        let accountID = UUID()
        let existingScopes = [
            BudgetScope(period: .week, categoryID: categoryID, accountID: nil),
            BudgetScope(period: .month, categoryID: categoryID, accountID: accountID)
        ]

        XCTAssertTrue(
            BudgetScopeConflictPolicy.hasConflict(
                existingScopes: existingScopes,
                period: .month,
                categoryID: categoryID,
                accountID: accountID
            )
        )
    }

    func testAllowsAChangingScopeThatDoesNotMatchAnotherBudget() {
        let existingScopes = [
            BudgetScope(period: .month, categoryID: UUID(), accountID: nil),
            BudgetScope(period: .month, categoryID: nil, accountID: UUID())
        ]

        XCTAssertFalse(
            BudgetScopeConflictPolicy.hasConflict(
                existingScopes: existingScopes,
                period: .month,
                categoryID: UUID(),
                accountID: UUID()
            )
        )
    }

    func testAllowsTheSameScopeForAnotherBudgetPeriod() {
        let categoryID = UUID()
        let accountID = UUID()

        XCTAssertFalse(
            BudgetScopeConflictPolicy.hasConflict(
                existingScopes: [BudgetScope(period: .week, categoryID: categoryID, accountID: accountID)],
                period: .month,
                categoryID: categoryID,
                accountID: accountID
            )
        )
    }
}
