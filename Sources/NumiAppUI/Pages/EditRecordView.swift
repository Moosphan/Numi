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
    @State private var isDatePickerPresented = false
    @State private var pendingDate: Date
    @FocusState private var isNoteFocused: Bool

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
        _pendingDate = State(initialValue: transaction.occurredAt)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: NumiSpacing.s5) {
                    typeCard
                    amountCard
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
                ToolbarItemGroup(placement: .keyboard) {
                    Button("收起") {
                        isNoteFocused = false
                    }
                    Spacer()
                    Button("保存") {
                        saveAndDismiss()
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("action.keyboardSubmitRecord")
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
            .sheet(isPresented: $isDatePickerPresented) {
                datePickerSheet
                    .presentationDetents([.height(430)])
                    .presentationCornerRadius(28)
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
                    Label {
                        Text(category.name)
                    } icon: {
                        CategoryIconView(category: category, size: 20)
                    }
                }
                .accessibilityIdentifier("category.\(category.name)")
            }
        } label: {
            HStack(spacing: NumiSpacing.s3) {
                CategoryIconView(iconName: selectedCategory?.icon ?? "ellipsis.circle", size: 24)
                    .foregroundStyle(NumiColor.textTertiary)
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
        VStack(spacing: NumiSpacing.s2) {
            amountHeader
            inlineMetaBar
            NumiAmountKeypad(
                state: $inputState,
                dateShortcutTitle: currentDateShortcutTitle,
                dateAccessorySystemImage: "calendar.badge.clock",
                onDateShortcut: presentDatePicker
            )
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.top, NumiSpacing.s2)
        .padding(.bottom, NumiSpacing.s3)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
    }

    private var amountHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: NumiSpacing.s3) {
            Text("金额")
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textTertiary)
            Spacer(minLength: NumiSpacing.s2)
            Menu {
                ForEach(currencyOptions) { option in
                    Button {
                        selectedCurrencyCode = option.code
                    } label: {
                        Label(
                            "\(option.symbol) \(option.code)",
                            systemImage: selectedCurrencyCode == option.code ? "checkmark.circle.fill" : "circle"
                        )
                    }
                    .accessibilityIdentifier("currency.\(option.code)")
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(selectedCurrencySymbol)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(NumiColor.textSecondary)
                    Text(inputState.displayText)
                        .font(NumiFont.amountLarge)
                        .foregroundStyle(NumiColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                        .accessibilityIdentifier("edit.amountDisplay")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NumiColor.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("picker.recordCurrency")
        }
    }

    private var inlineMetaBar: some View {
        VStack(spacing: NumiSpacing.s2) {
            if selectedType == .transfer {
                HStack(spacing: NumiSpacing.s2) {
                    inlineAccountMenu(
                        title: "转出",
                        selectedName: selectedAccount?.name ?? "未选择",
                        accessibilityIdentifier: "picker.transferSourceAccount",
                        accounts: visibleAccounts,
                        selectedID: $selectedAccountID
                    )
                    inlineAccountMenu(
                        title: "转入",
                        selectedName: selectedTargetAccount?.name ?? "未选择",
                        accessibilityIdentifier: "picker.transferTargetAccount",
                        accounts: targetAccounts,
                        selectedID: $selectedTargetAccountID
                    )
                }
                inlineNoteField
            } else {
                HStack(spacing: NumiSpacing.s2) {
                    inlineAccountMenu(
                        title: "账户",
                        selectedName: selectedAccount?.name ?? "未选择",
                        accessibilityIdentifier: "picker.editRecordAccount",
                        accounts: visibleAccounts,
                        selectedID: $selectedAccountID
                    )
                    inlineNoteField
                }
            }
        }
    }

    private var inlineNoteField: some View {
        HStack(spacing: NumiSpacing.s2) {
            Image(systemName: "note.text")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NumiColor.textTertiary)
            TextField("备注", text: $note)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isNoteFocused)
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
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(NumiColor.surfaceCardSubtle)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
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

    private var selectedCurrencySymbol: String {
        currencyOptions.first { $0.code == selectedCurrencyCode }?.symbol ?? selectedCurrencyCode
    }

    private var currentDateShortcutTitle: String {
        NumiDatePickerRow.displayText(for: selectedDate, includesTime: false)
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
        isNoteFocused = false
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

    private func saveAndDismiss() {
        save()
        if canSave {
            dismiss()
        }
    }

    private var datePickerSheet: some View {
        NumiBottomSheet(
            title: "选择日期",
            contentMode: .fit,
            accessibilityPrefix: "sheet.datePicker",
            dismissAccessibilitySuffix: "cancel",
            confirmAccessibilitySuffix: "confirm",
            dismissTitle: "取消",
            confirmTitle: "完成",
            onDismiss: {
                isDatePickerPresented = false
            },
            onConfirm: {
                selectedDate = mergedDate(pendingDate, keepingTimeFrom: selectedDate)
                isDatePickerPresented = false
            }
        ) {
            DatePicker(
                "日期",
                selection: $pendingDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(.horizontal, NumiSpacing.s3)
            .padding(.top, 2)
            .padding(.bottom, NumiSpacing.s3)
        }
    }

    private func presentDatePicker() {
        isNoteFocused = false
        pendingDate = selectedDate
        isDatePickerPresented = true
    }

    private func mergedDate(_ newDate: Date, keepingTimeFrom originalDate: Date) -> Date {
        let newDay = Calendar.current.dateComponents([.year, .month, .day], from: newDate)
        let originalTime = Calendar.current.dateComponents([.hour, .minute, .second], from: originalDate)
        var merged = DateComponents()
        merged.year = newDay.year
        merged.month = newDay.month
        merged.day = newDay.day
        merged.hour = originalTime.hour
        merged.minute = originalTime.minute
        merged.second = originalTime.second
        return Calendar.current.date(from: merged) ?? newDate
    }

    private func inlineAccountMenu(
        title: String,
        selectedName: String,
        accessibilityIdentifier: String,
        accounts: [Account],
        selectedID: Binding<UUID?>
    ) -> some View {
        Menu {
            ForEach(accounts) { account in
                Button {
                    selectedID.wrappedValue = account.id
                } label: {
                    Label(account.name, systemImage: "circle")
                }
                .accessibilityIdentifier("account.\(account.name)")
            }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.textSecondary)
                Spacer(minLength: 8)
                Text(selectedName)
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NumiColor.textTertiary)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(NumiColor.surfaceCardSubtle)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityValue("style.neutral")
    }
}
