import Foundation
import NumiCore

public struct BudgetScope: Hashable, Sendable {
    public let period: BudgetPeriod
    public let categoryID: UUID?
    public let accountID: UUID?

    public init(period: BudgetPeriod, categoryID: UUID?, accountID: UUID?) {
        self.period = period
        self.categoryID = categoryID
        self.accountID = accountID
    }
}

public enum BudgetScopeConflictPolicy {
    public static func hasConflict(
        existingScopes: [BudgetScope],
        period: BudgetPeriod,
        categoryID: UUID?,
        accountID: UUID?
    ) -> Bool {
        existingScopes.contains(BudgetScope(period: period, categoryID: categoryID, accountID: accountID))
    }
}
