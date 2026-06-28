import Foundation
import NumiCore

enum RuntimeLocalizedDisplay {
    static func categoryName(
        for transaction: NumiCore.Transaction,
        categories: [NumiCore.Category],
        fallbackCategoryName: String? = nil
    ) -> String {
        if transaction.type == .transfer {
            return NumiLocalized.string("other.transfer")
        }

        guard let categoryID = transaction.categoryID else {
            return fallbackCategoryName ?? NumiLocalized.string("other.fallback")
        }

        return categoryName(
            for: categoryID,
            categories: categories,
            fallbackCategoryName: fallbackCategoryName
        )
    }

    static func categoryName(
        for categoryID: UUID,
        categories: [NumiCore.Category],
        fallbackCategoryName: String? = nil
    ) -> String {
        categories.first(where: { $0.id == categoryID })?.localizedDisplayName
            ?? fallbackCategoryName
            ?? NumiLocalized.string("other.fallback")
    }

    static func categoryIconName(
        for transaction: NumiCore.Transaction,
        categories: [NumiCore.Category],
        fallbackCategoryIcon: String? = nil
    ) -> String {
        if transaction.type == .transfer {
            return "arrow.left.arrow.right.circle"
        }

        guard let categoryID = transaction.categoryID else {
            return fallbackCategoryIcon ?? "ellipsis.circle"
        }

        return categoryIconName(
            for: categoryID,
            categories: categories,
            fallbackCategoryIcon: fallbackCategoryIcon
        )
    }

    static func categoryIconName(
        for categoryID: UUID,
        categories: [NumiCore.Category],
        fallbackCategoryIcon: String? = nil
    ) -> String {
        categories.first(where: { $0.id == categoryID })?.icon
            ?? fallbackCategoryIcon
            ?? "ellipsis.circle"
    }

    static func accountName(for accountID: UUID?, accounts: [Account]) -> String {
        guard let accountID else {
            return NumiLocalized.string("empty.no.selection")
        }

        return accounts.first(where: { $0.id == accountID })?.localizedDisplayName
            ?? NumiLocalized.string("empty.no.selection")
    }

    static func transferAccountFlowText(
        sourceAccountID: UUID?,
        targetAccountID: UUID?,
        accounts: [Account]
    ) -> String {
        "\(accountName(for: sourceAccountID, accounts: accounts)) -> \(accountName(for: targetAccountID, accounts: accounts))"
    }

    static func transferSubtitle(
        for transaction: NumiCore.Transaction,
        accounts: [Account],
        fallbackSubtitle: String? = nil
    ) -> String? {
        guard transaction.type == .transfer else { return fallbackSubtitle }

        if transaction.accountID != nil || transaction.targetAccountID != nil {
            return transferAccountFlowText(
                sourceAccountID: transaction.accountID,
                targetAccountID: transaction.targetAccountID,
                accounts: accounts
            )
        }

        return fallbackSubtitle
    }
}
