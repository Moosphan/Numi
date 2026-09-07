import Foundation
import NumiCore

public enum InsightsAccountFilterPolicy {
    public static func includes(_ transaction: Transaction, accountID: UUID?) -> Bool {
        guard let accountID else { return true }
        return transaction.accountID == accountID || transaction.targetAccountID == accountID
    }
}
