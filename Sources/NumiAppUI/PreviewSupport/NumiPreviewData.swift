import Foundation
import NumiCore

public enum NumiPreviewData {
    public static func store() -> InMemoryBookkeepingStore {
        let store = InMemoryBookkeepingStore()
        try? store.seedDefaultsIfNeeded()
        let accountID = store.accounts.first?.id
        let ledgerID = store.ledgers.first?.id ?? UUID()
        let foodID = store.categories.first { $0.builtInKey == "category.default.expense.dining" }?.id
        let transportID = store.categories.first { $0.builtInKey == "category.default.expense.transport" }?.id
        let salaryID = store.categories.first { $0.builtInKey == "category.default.income.salary" }?.id
        if let accountID {
            _ = try? store.createTransaction(
                type: .expense,
                amount: Money(decimalString: "32.50", currencyCode: "CNY"),
                categoryID: foodID,
                accountID: accountID,
                ledgerID: ledgerID,
                note: "午餐 星巴克"
            )
            _ = try? store.createTransaction(
                type: .expense,
                amount: Money(decimalString: "16.80", currencyCode: "CNY"),
                categoryID: transportID,
                accountID: accountID,
                ledgerID: ledgerID,
                note: "地铁"
            )
            _ = try? store.createTransaction(
                type: .income,
                amount: Money(decimalString: "5000", currencyCode: "CNY"),
                categoryID: salaryID,
                accountID: accountID,
                ledgerID: ledgerID,
                note: "工资"
            )
        }
        return store
    }

    public static func summaryAndRows() -> (TransactionSummary, [(Transaction, String, String)]) {
        let store = store()
        let summary = (try? TransactionSummary.monthly(transactions: store.visibleTransactions, currencyCode: "CNY"))
            ?? TransactionSummary(expense: .zero(currencyCode: "CNY"), income: .zero(currencyCode: "CNY"), balance: .zero(currencyCode: "CNY"), recordCount: 0)
        let rows = store.visibleTransactions.map { transaction in
            let category = store.categories.first { $0.id == transaction.categoryID }
            return (
                transaction,
                category?.localizedDisplayName ?? NumiLocalized.string("other.fallback"),
                category?.icon ?? "ellipsis.circle"
            )
        }
        return (summary, rows)
    }
}
