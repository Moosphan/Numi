import Foundation

public enum AdvancedBudgetCreationPolicy {
    public static func hasScope(categoryID: UUID?, accountID: UUID?) -> Bool {
        categoryID != nil || accountID != nil
    }
}
