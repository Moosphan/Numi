import SwiftUI
import NumiCore

public struct RecordDetailView: View {
    private let transaction: NumiCore.Transaction
    private let categories: [NumiCore.Category]
    private let accounts: [Account]
    private let fallbackCategoryName: String?
    private let fallbackIconName: String?
    private let onEdit: () -> Void
    private let onClose: () -> Void

    public init(
        transaction: NumiCore.Transaction,
        categories: [NumiCore.Category] = [],
        accounts: [Account] = [],
        fallbackCategoryName: String? = nil,
        fallbackIconName: String? = nil,
        onClose: @escaping () -> Void = {},
        onEdit: @escaping () -> Void
    ) {
        self.transaction = transaction
        self.categories = categories
        self.accounts = accounts
        self.fallbackCategoryName = fallbackCategoryName
        self.fallbackIconName = fallbackIconName
        self.onClose = onClose
        self.onEdit = onEdit
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                    amountCard
                    detailRows
                }
                .padding(NumiSpacing.s5)
            }
            .accessibilityIdentifier("page.recordDetail")
            .background(NumiColor.surfacePage)
            .navigationTitle(Text("record.detail"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close", action: onClose)
                        .accessibilityIdentifier("action.closeRecordDetail")
                }
                ToolbarItem {
                    Button("common.edit", action: onEdit)
                        .accessibilityIdentifier("action.editRecord")
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s4) {
            HStack(spacing: NumiSpacing.s3) {
                CategoryIconView(iconName: resolvedIconName, size: 56)
                    .background(NumiColor.surfaceCardSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))

                VStack(alignment: .leading, spacing: NumiSpacing.s1) {
                    Text(resolvedCategoryName)
                        .font(NumiFont.bodyStrong)
                        .foregroundStyle(NumiColor.textPrimary)
                    Text(typeText)
                        .font(NumiFont.bodySmall)
                        .foregroundStyle(NumiColor.textTertiary)
                }
            }

            Text(transaction.amount.formatted())
                .font(NumiFont.amountLarge.monospacedDigit())
                .foregroundStyle(amountColor)
                .accessibilityIdentifier("detail.amount")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NumiSpacing.s5)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
    }

    private var detailRows: some View {
        VStack(spacing: 0) {
            detailRow(title: NumiLocalized.string( transaction.type == .transfer ? "recordDetail.accountFlow" : "record.account"), value: accountText)
            detailRow(title: NumiLocalized.string( "record.date"), value: dateText)
            detailRow(title: NumiLocalized.string( "record.note"), value: transaction.note.isEmpty ? NumiLocalized.string( "common.none") : transaction.note)
        }
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(NumiFont.body)
                .foregroundStyle(NumiColor.textSecondary)
            Spacer()
            Text(value)
                .font(NumiFont.bodyStrong)
                .foregroundStyle(NumiColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(NumiSpacing.s4)
    }

    private var typeText: String {
        switch transaction.type {
        case .expense: NumiLocalized.string( "record.expense")
        case .income: NumiLocalized.string( "record.income")
        case .transfer: NumiLocalized.string( "record.transfer")
        }
    }

    private var amountColor: Color {
        NumiColor.textPrimary
    }

    private var dateText: String {
        NumiDatePickerRow.displayText(for: transaction.occurredAt)
    }

    private var accountText: String {
        guard transaction.type == .transfer else {
            return RuntimeLocalizedDisplay.accountName(for: transaction.accountID, accounts: accounts)
        }
        return RuntimeLocalizedDisplay.transferAccountFlowText(
            sourceAccountID: transaction.accountID,
            targetAccountID: transaction.targetAccountID,
            accounts: accounts
        )
    }

    private var resolvedCategoryName: String {
        RuntimeLocalizedDisplay.categoryName(
            for: transaction,
            categories: categories,
            fallbackCategoryName: fallbackCategoryName
        )
    }

    private var resolvedIconName: String {
        RuntimeLocalizedDisplay.categoryIconName(
            for: transaction,
            categories: categories,
            fallbackCategoryIcon: fallbackIconName
        )
    }
}
