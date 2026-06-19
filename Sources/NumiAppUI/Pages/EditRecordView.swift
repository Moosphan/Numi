import SwiftUI
import NumiCore

public struct EditRecordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: TransactionType
    @State private var selectedCategoryID: UUID?
    @State private var selectedAccountID: UUID?
    @State private var selectedTargetAccountID: UUID?
    @State private var selectedDate: Date
    @State private var inputState: MoneyInputState
    @State private var note: String
    @State private var selectedCurrencyCode: String

    private let categories: [NumiCore.Category]
    private let accounts: [Account]
    private let transaction: NumiCore.Transaction
    private let onSave: (TransactionType, Money, NumiCore.Category?, Account?, Account?, Date, String) -> Void

    public init(
        transaction: NumiCore.Transaction,
        categories: [NumiCore.Category],
        accounts: [Account],
        onSave: @escaping (TransactionType, Money, NumiCore.Category?, Account?, Account?, Date, String) -> Void
    ) {
        self.transaction = transaction
        self.categories = categories
        self.accounts = accounts
        self.onSave = onSave
        _selectedType = State(initialValue: transaction.type)
        _selectedCategoryID = State(initialValue: transaction.categoryID)
        _selectedAccountID = State(initialValue: transaction.accountID)
        _selectedTargetAccountID = State(initialValue: transaction.targetAccountID)
        _selectedDate = State(initialValue: transaction.occurredAt)
        _inputState = State(initialValue: MoneyInputState(money: transaction.amount))
        _note = State(initialValue: transaction.note)
        _selectedCurrencyCode = State(initialValue: transaction.amount.currencyCode)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: NumiSpacing.s5) {
                    typeCard
                    amountCard
                    detailsCard
                }
                .padding(NumiSpacing.s5)
                .padding(.bottom, 24)
            }
            .background(NumiColor.surfacePage)
            .navigationTitle("编辑账单")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("action.submitRecord")
                }
            }
            .onAppear {
                ensureSelectedCategory()
                ensureSelectedTargetAccount()
            }
            .onChange(of: selectedType) { _, _ in
                ensureSelectedCategory()
                ensureSelectedTargetAccount()
            }
            .onChange(of: selectedCurrencyCode) { _, newValue in
                inputState.updateCurrencyCode(newValue)
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private var typeCard: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s4) {
            Picker("类型", selection: $selectedType) {
                Text("支出").tag(TransactionType.expense).accessibilityIdentifier("transactionType.支出")
                Text("收入").tag(TransactionType.income).accessibilityIdentifier("transactionType.收入")
                Text("转账").tag(TransactionType.transfer).accessibilityIdentifier("transactionType.转账")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("picker.transactionType")

            if selectedType == .transfer {
                HStack(spacing: NumiSpacing.s3) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(NumiColor.accentDeep)
                        .frame(width: 44, height: 44)
                        .background(NumiColor.surfaceCardSubtle)
                        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("账户转账")
                            .font(NumiFont.bodyStrong)
                            .foregroundStyle(NumiColor.textPrimary)
                        Text("编辑转出、转入账户与金额。")
                            .font(NumiFont.bodySmall)
                            .foregroundStyle(NumiColor.textTertiary)
                    }
                    Spacer()
                }
            } else {
                categoryPickerRow
            }
        }
        .padding(NumiSpacing.s4)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
    }

    private var categoryPickerRow: some View {
        Menu {
            ForEach(visibleCategories) { category in
                Button {
                    selectedCategoryID = category.id
                } label: {
                    Label(category.name, systemImage: category.icon)
                }
                .accessibilityIdentifier("category.\(category.name)")
            }
        } label: {
            HStack(spacing: NumiSpacing.s3) {
                Image(systemName: selectedCategory?.icon ?? "ellipsis.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NumiColor.textTertiary)
                    .frame(width: 24)
                Text("分类")
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.textSecondary)
                Spacer()
                Text(selectedCategory?.name ?? "未选择")
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NumiColor.textTertiary)
            }
            .padding(.horizontal, NumiSpacing.s4)
            .frame(minHeight: 44)
            .background(NumiColor.surfaceCardSubtle)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("picker.editRecordCategory")
    }

    private var amountCard: some View {
        VStack(spacing: NumiSpacing.s4) {
            HStack {
                Text("金额")
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.textTertiary)
                Spacer()
                Text(inputState.displayText)
                    .font(NumiFont.amountLarge)
                    .foregroundStyle(NumiColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .accessibilityIdentifier("edit.amountDisplay")
            }

            NumiAmountKeypad(state: $inputState)
        }
        .padding(NumiSpacing.s4)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
    }

    private var detailsCard: some View {
        VStack(spacing: NumiSpacing.s3) {
            if selectedType == .transfer {
                NumiAccountPickerRow(
                    title: "转出",
                    accounts: accounts,
                    selectedAccountID: $selectedAccountID,
                    accessibilityIdentifier: "picker.transferSourceAccount"
                )
                NumiAccountPickerRow(
                    title: "转入",
                    accounts: accounts,
                    selectedAccountID: $selectedTargetAccountID,
                    excludedAccountID: selectedAccountID,
                    accessibilityIdentifier: "picker.transferTargetAccount"
                )
            } else {
                NumiAccountPickerRow(
                    accounts: accounts,
                    selectedAccountID: $selectedAccountID,
                    accessibilityIdentifier: "picker.editRecordAccount"
                )
            }

            NumiCurrencyPickerRow(
                options: currencyOptions,
                selectedCode: $selectedCurrencyCode,
                accessibilityIdentifier: "picker.recordCurrency"
            )

            NumiDatePickerRow(
                selectedDate: $selectedDate,
                accessibilityIdentifier: "picker.editRecordDate"
            )

            HStack(spacing: NumiSpacing.s2) {
                Image(systemName: "note.text")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NumiColor.textTertiary)
                TextField("备注", text: $note)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .accessibilityIdentifier("input.editRecordNote")
                if !note.isEmpty {
                    Button {
                        note = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(NumiColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("action.clearEditRecordNote")
                }
            }
            .padding(.horizontal, NumiSpacing.s4)
            .frame(minHeight: 52)
            .background(NumiColor.surfaceCardSubtle)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
        }
        .padding(NumiSpacing.s4)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
    }

    private var visibleCategories: [NumiCore.Category] {
        guard selectedType != .transfer else { return [] }
        return categories
            .filter { $0.kind == (selectedType == .income ? .income : .expense) && !$0.isHidden }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var visibleAccounts: [Account] {
        accounts.filter { !$0.isHidden }
    }

    private var targetAccounts: [Account] {
        visibleAccounts.filter { $0.id != selectedAccountID }
    }

    private var selectedCategory: NumiCore.Category? {
        visibleCategories.first { $0.id == selectedCategoryID } ?? visibleCategories.first
    }

    private var selectedAccount: Account? {
        visibleAccounts.first { $0.id == selectedAccountID } ?? visibleAccounts.first
    }

    private var selectedTargetAccount: Account? {
        targetAccounts.first { $0.id == selectedTargetAccountID } ?? targetAccounts.first
    }

    private var currencyOptions: [NumiCurrencyOption] {
        [
            NumiCurrencyOption(code: "CNY", title: "人民币", symbol: "¥"),
            NumiCurrencyOption(code: "USD", title: "美元", symbol: "$"),
            NumiCurrencyOption(code: "EUR", title: "欧元", symbol: "€"),
            NumiCurrencyOption(code: "JPY", title: "日元", symbol: "¥"),
            NumiCurrencyOption(code: "HKD", title: "港币", symbol: "HK$")
        ]
    }

    private var canSave: Bool {
        guard (try? inputState.money()) != nil else { return false }
        if selectedType == .transfer {
            return selectedAccount?.id != nil && selectedAccount?.id != selectedTargetAccount?.id && selectedTargetAccount?.id != nil
        }
        return selectedCategory != nil && selectedAccount != nil
    }

    private func ensureSelectedCategory() {
        if selectedType == .transfer {
            selectedCategoryID = nil
            return
        }
        if selectedCategory == nil {
            selectedCategoryID = visibleCategories.first?.id
        }
    }

    private func ensureSelectedTargetAccount() {
        if selectedAccountID == nil {
            selectedAccountID = visibleAccounts.first?.id
        }
        guard selectedType == .transfer else {
            selectedTargetAccountID = nil
            return
        }
        if selectedTargetAccount == nil {
            selectedTargetAccountID = targetAccounts.first?.id
        }
    }

    private func save() {
        guard canSave, let money = try? inputState.money() else { return }
        onSave(
            selectedType,
            money,
            selectedCategory,
            selectedAccount,
            selectedTargetAccount,
            selectedDate,
            note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
