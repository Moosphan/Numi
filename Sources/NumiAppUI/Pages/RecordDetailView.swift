import SwiftUI
import NumiCore

public struct RecordDetailView: View {
    private let transaction: NumiCore.Transaction
    private let categoryName: String
    private let iconName: String
    private let accountName: String
    private let targetAccountName: String?
    private let onEdit: () -> Void
    private let onClose: () -> Void

    public init(
        transaction: NumiCore.Transaction,
        categoryName: String,
        iconName: String,
        accountName: String,
        targetAccountName: String? = nil,
        onClose: @escaping () -> Void = {},
        onEdit: @escaping () -> Void
    ) {
        self.transaction = transaction
        self.categoryName = categoryName
        self.iconName = iconName
        self.accountName = accountName
        self.targetAccountName = targetAccountName
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
            .background(NumiColor.surfacePage)
            .navigationTitle("账单详情")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", action: onClose)
                        .accessibilityIdentifier("action.closeRecordDetail")
                }
                ToolbarItem {
                    Button("编辑", action: onEdit)
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
                Image(systemName: iconName)
                    .font(.system(size: 28, weight: .semibold))
                    .frame(width: 56, height: 56)
                    .background(NumiColor.surfaceCardSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))

                VStack(alignment: .leading, spacing: NumiSpacing.s1) {
                    Text(categoryName)
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
            detailRow(title: transaction.type == .transfer ? "账户流向" : "账户", value: accountText)
            detailRow(title: "日期", value: dateText)
            detailRow(title: "备注", value: transaction.note.isEmpty ? "无" : transaction.note)
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
        case .expense: "支出"
        case .income: "收入"
        case .transfer: "转账"
        }
    }

    private var amountColor: Color {
        NumiColor.textPrimary
    }

    private var dateText: String {
        NumiDatePickerRow.displayText(for: transaction.occurredAt)
    }

    private var accountText: String {
        guard transaction.type == .transfer else { return accountName }
        return "\(accountName) -> \(targetAccountName ?? "未选择")"
    }
}
