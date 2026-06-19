import SwiftUI
import NumiCore

public struct AddRecordView: View {
    @State private var selectedType: TransactionType = .expense
    @State private var selectedCategoryID: UUID?
    @State private var selectedAccountID: UUID?
    @State private var selectedTargetAccountID: UUID?
    @State private var selectedDate = Date()
    @State private var inputState = MoneyInputState(currencyCode: "CNY")
    @State private var note = ""
    @FocusState private var isNoteFocused: Bool
    private let categories: [NumiCore.Category]
    private let accounts: [Account]
    private let onSave: (TransactionType, Money, NumiCore.Category?, Account?, Account?, Date, String) -> Void

    public init(
        categories: [NumiCore.Category],
        accounts: [Account],
        onSave: @escaping (TransactionType, Money, NumiCore.Category?, Account?, Account?, Date, String) -> Void
    ) {
        self.categories = categories
        self.accounts = accounts
        self.onSave = onSave
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            categoryGrid
            amountPanel
        }
        .background(NumiColor.surfacePage)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sheet.addRecord")
        .onAppear(perform: ensureSelectedCategory)
        .onChange(of: selectedType) {
            ensureSelectedCategory()
            ensureSelectedTargetAccount()
        }
    }

    private var header: some View {
        HStack {
            Picker("类型", selection: $selectedType) {
                Text("支出").tag(TransactionType.expense).accessibilityIdentifier("transactionType.支出")
                Text("收入").tag(TransactionType.income).accessibilityIdentifier("transactionType.收入")
                Text("转账").tag(TransactionType.transfer).accessibilityIdentifier("transactionType.转账")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("picker.transactionType")
        }
        .padding(NumiSpacing.s5)
    }

    private var categoryGrid: some View {
        Group {
            if selectedType == .transfer {
                VStack(spacing: NumiSpacing.s3) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(NumiColor.accentDeep)
                    Text("账户转账")
                        .font(NumiFont.bodyStrong)
                        .foregroundStyle(NumiColor.textPrimary)
                    Text("转账只调整账户余额，不计入支出或收入。")
                        .font(NumiFont.bodySmall)
                        .foregroundStyle(NumiColor.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, NumiSpacing.s5)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: NumiSpacing.s3), count: 4), spacing: NumiSpacing.s4) {
                        ForEach(visibleCategories) { category in
                            Button {
                                selectedCategoryID = category.id
                            } label: {
                                VStack(spacing: NumiSpacing.s2) {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 28, weight: .medium))
                                        .frame(width: 62, height: 62)
                                        .background(category.id == selectedCategoryID ? NumiColor.accentPrimary.opacity(0.52) : NumiColor.surfaceCard)
                                        .overlay {
                                            if category.id == selectedCategoryID {
                                                RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous)
                                                    .stroke(NumiColor.accentDeep.opacity(0.32), lineWidth: 1)
                                            }
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
                                    Text(category.name)
                                        .font(NumiFont.footnote)
                                        .foregroundStyle(category.id == selectedCategoryID ? NumiColor.textPrimary : NumiColor.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(category.name)
                            .accessibilityAddTraits(category.id == selectedCategoryID ? [.isSelected] : [])
                            .accessibilityIdentifier("category.\(category.name)")
                        }
                    }
                    .padding(.horizontal, NumiSpacing.s5)
                    .padding(.bottom, NumiSpacing.s5)
                }
            }
        }
    }

    private var amountPanel: some View {
        NumiGlassSurface(role: .modal) {
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
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, NumiSpacing.s4)

                accountRows

                NumiDatePickerRow(
                    selectedDate: $selectedDate,
                    accessibilityIdentifier: "picker.addRecordDate"
                )
                .padding(.horizontal, NumiSpacing.s4)

                noteField

                if isNoteFocused {
                    focusedNoteActions
                } else {
                    NumiAmountKeypad(state: $inputState)
                }
            }
            .padding(.top, NumiSpacing.s5)
        }
        .padding(NumiSpacing.s3)
    }

    private var accountRows: some View {
        Group {
            if selectedType == .transfer {
                VStack(spacing: NumiSpacing.s3) {
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
                }
                .padding(.horizontal, NumiSpacing.s4)
                .onChange(of: selectedAccountID) {
                    ensureSelectedTargetAccount()
                }
            } else {
                NumiAccountPickerRow(
                    accounts: accounts,
                    selectedAccountID: $selectedAccountID,
                    accessibilityIdentifier: "picker.addRecordAccount"
                )
                .padding(.horizontal, NumiSpacing.s4)
            }
        }
    }

    private var noteField: some View {
        HStack(spacing: NumiSpacing.s2) {
            Image(systemName: "note.text")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NumiColor.textTertiary)
            TextField("备注", text: $note)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isNoteFocused)
                .accessibilityIdentifier("input.addRecordNote")
            if !note.isEmpty {
                Button {
                    note = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(NumiColor.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("action.clearAddRecordNote")
            }
        }
        .padding(.horizontal, NumiSpacing.s4)
        .frame(minHeight: 44)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
        .padding(.horizontal, NumiSpacing.s4)
    }

    private var focusedNoteActions: some View {
        HStack(spacing: NumiSpacing.s3) {
            Button {
                save()
                inputState.apply(.clear)
            } label: {
                Text("再记")
                    .font(NumiFont.bodyStrong)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(NumiColor.accentPrimary.opacity(0.62))
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
                    .foregroundStyle(NumiColor.textPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("action.saveAndContinue")

            Button {
                save()
            } label: {
                Text("记一笔")
                    .font(NumiFont.bodyStrong)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(NumiColor.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
                    .foregroundStyle(NumiColor.textPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("action.saveRecord")
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.bottom, NumiSpacing.s2)
    }

    private func save() {
        isNoteFocused = false
        guard let money = try? inputState.money() else { return }
        if selectedType == .transfer, selectedAccount?.id == selectedTargetAccount?.id {
            return
        }
        onSave(selectedType, money, selectedCategory, selectedAccount, selectedTargetAccount, selectedDate, note.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var visibleCategories: [NumiCore.Category] {
        guard selectedType != .transfer else { return [] }
        return categories.filter { $0.kind == (selectedType == .income ? .income : .expense) && !$0.isHidden }
    }

    private var selectedCategory: NumiCore.Category? {
        guard selectedType != .transfer else { return nil }
        return visibleCategories.first { $0.id == selectedCategoryID } ?? visibleCategories.first
    }

    private var selectedAccount: Account? {
        accounts.filter { !$0.isHidden }.first { $0.id == selectedAccountID } ?? accounts.first { !$0.isHidden }
    }

    private var selectedTargetAccount: Account? {
        targetAccounts.first { $0.id == selectedTargetAccountID } ?? targetAccounts.first
    }

    private var targetAccounts: [Account] {
        accounts.filter { !$0.isHidden && $0.id != selectedAccountID }
    }

    private func ensureSelectedCategory() {
        if selectedCategory == nil {
            selectedCategoryID = visibleCategories.first?.id
        }
    }

    private func ensureSelectedTargetAccount() {
        guard selectedType == .transfer else { return }
        if selectedTargetAccount == nil {
            selectedTargetAccountID = targetAccounts.first?.id
        }
    }
}
