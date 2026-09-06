import Foundation
import NumiCore

public enum BudgetScopeMembershipPolicy {
    public static func featureRequest(
        existingCategoryID: UUID?,
        existingAccountID: UUID?,
        selectedCategoryID: UUID?,
        selectedAccountID: UUID?
    ) -> MembershipFeatureRequest? {
        let alreadyScoped = existingCategoryID != nil || existingAccountID != nil
        let selectsScopedBudget = selectedCategoryID != nil || selectedAccountID != nil
        return !alreadyScoped && selectsScopedBudget ? .openAdvancedBudget : nil
    }
}
