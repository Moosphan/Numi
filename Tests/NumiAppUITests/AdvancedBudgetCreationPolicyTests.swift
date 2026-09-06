import XCTest
@testable import NumiAppUI

final class AdvancedBudgetCreationPolicyTests: XCTestCase {
    func testScopedBudgetRequiresCategoryOrAccount() {
        XCTAssertFalse(AdvancedBudgetCreationPolicy.hasScope(categoryID: nil, accountID: nil))
        XCTAssertTrue(AdvancedBudgetCreationPolicy.hasScope(categoryID: UUID(), accountID: nil))
        XCTAssertTrue(AdvancedBudgetCreationPolicy.hasScope(categoryID: nil, accountID: UUID()))
    }
}
