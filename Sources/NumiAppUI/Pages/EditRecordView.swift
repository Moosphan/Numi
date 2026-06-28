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
            .accessibilityIdentifier("page.editRecord")
            .background(NumiColor.surfacePage)
            .navigationTitle("record.edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        save()
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("action.submitRecord")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Button(NumiLocalized.string( "common.collapse")) {
                        isNoteFocused = false
                    }
                    Spacer()
                    Button("common.save") {
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
            Picker("record.type", selection: $selectedType) {
                Text("record.expense").tag(TransactionType.expense).accessibilityIdentifier("transactionType.expense")
                Text("record.income").tag(TransactionType.income).accessibilityIdentifier("transactionType.income")
                Text("record.transfer").tag(TransactionType.transfer).accessibilityIdentifier("transactionType.transfer")
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
                        Text("record.transfer.title")
                            .font(NumiFont.bodyStrong)
                            .foregroundStyle(NumiColor.textPrimary)
                        Text("editRecord.transfer.subtitle")
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
                        Text(category.localizedDisplayName)
                    } icon: {
                        CategoryIconView(category: category, size: 20)
                    }
                }
                .accessibilityIdentifier("category.\(category.id.uuidString)")
            }
        } label: {
            HStack(spacing: NumiSpacing.s3) {
                CategoryIconView(iconName: selectedCategory?.icon ?? "ellipsis.circle", size: 24)
                    .foregroundStyle(NumiColor.textTertiary)
                Text("record.category")
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.textSecondary)
                Spacer()
                Text(selectedCategory?.localizedDisplayName ?? NumiLocalized.string( "empty.no.selection"))
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
                dateShortcutAccessibilityKey: currentDateShortcutAccessibilityKey,
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
            Text("record.amount")
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
                        title: NumiLocalized.string( "record.transfer.from"),
                        selectedName: selectedAccount?.localizedDisplayName ?? NumiLocalized.string( "empty.no.selection"),
                        accessibilityIdentifier: "picker.transferSourceAccount",
                        accounts: visibleAccounts,
                        selectedID: $selectedAccountID
                    )
                    inlineAccountMenu(
                        title: NumiLocalized.string( "record.transfer.to"),
                        selectedName: selectedTargetAccount?.localizedDisplayName ?? NumiLocalized.string( "empty.no.selection"),
                        accessibilityIdentifier: "picker.transferTargetAccount",
                        accounts: targetAccounts,
                        selectedID: $selectedTargetAccountID
                    )
                }
                inlineNoteField
            } else {
                HStack(spacing: NumiSpacing.s2) {
                    inlineAccountMenu(
                        title: NumiLocalized.string( "record.account"),
                        selectedName: selectedAccount?.localizedDisplayName ?? NumiLocalized.string( "empty.no.selection"),
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
            TextField("record.note", text: $note)
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
            NumiCurrencyOption(code: "CNY", title: NumiLocalized.string( "currency.name.CNY"), symbol: "¥"),
            NumiCurrencyOption(code: "USD", title: NumiLocalized.string( "currency.name.USD"), symbol: "$"),
            NumiCurrencyOption(code: "EUR", title: NumiLocalized.string( "currency.name.EUR"), symbol: "€"),
            NumiCurrencyOption(code: "JPY", title: NumiLocalized.string( "currency.name.JPY"), symbol: "¥"),
            NumiCurrencyOption(code: "HKD", title: NumiLocalized.string( "currency.name.HKD"), symbol: "HK$")
        ]
    }

    private var selectedCurrencySymbol: String {
        currencyOptions.first { $0.code == selectedCurrencyCode }?.symbol ?? selectedCurrencyCode
    }

    private var currentDateShortcutTitle: String {
        NumiDatePickerRow.displayText(for: selectedDate, includesTime: false)
    }

    private var currentDateShortcutAccessibilityKey: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "today"
        }
        if Calendar.current.isDateInYesterday(selectedDate) {
            return "yesterday"
        }
        if let dayBeforeYesterday = Calendar.current.date(byAdding: .day, value: -2, to: Date()),
           Calendar.current.isDate(selectedDate, inSameDayAs: dayBeforeYesterday) {
            return "dayBeforeYesterday"
        }
        return "custom"
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
            title: NumiLocalized.string( "addRecordFlow.datePicker.title"),
            contentMode: .fit,
            accessibilityPrefix: "sheet.datePicker",
            dismissAccessibilitySuffix: "cancel",
            confirmAccessibilitySuffix: "confirm",
            dismissTitle: NumiLocalized.string( "common.cancel"),
            confirmTitle: NumiLocalized.string( "common.done"),
            onDismiss: {
                isDatePickerPresented = false
            },
            onConfirm: {
                selectedDate = mergedDate(pendingDate, keepingTimeFrom: selectedDate)
                isDatePickerPresented = false
            }
        ) {
            DatePicker(
                "record.date",
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
                    Label(account.localizedDisplayName, systemImage: "circle")
                }
                .accessibilityIdentifier("account.\(account.id.uuidString)")
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
