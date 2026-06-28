import SwiftUI
import NumiCore

public struct AddRecordFlowView: View {
    @Environment(\.dismiss) private var dismiss

    private let categories: [NumiCore.Category]
    private let accounts: [Account]
    private let currencyOptions: [NumiCurrencyOption]
    private let onSave: (TransactionType, Money, NumiCore.Category?, Account?, Account?, Date, String) -> Void

    @State private var selectedType: TransactionType = .expense
    @State private var selectedDraft: TransactionDraft?
    @State private var savedContext: SavedRecordContext?

    public init(
        categories: [NumiCore.Category],
        accounts: [Account],
        currencyOptions: [NumiCurrencyOption],
        onSave: @escaping (TransactionType, Money, NumiCore.Category?, Account?, Account?, Date, String) -> Void
    ) {
        self.categories = categories
        self.accounts = accounts
        self.currencyOptions = currencyOptions
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                categorySelectionPage
                    .scaleEffect(selectedDraft == nil ? 1 : 0.985, anchor: .top)
                    .overlay {
                        if selectedDraft != nil {
                            Color.black.opacity(0.14)
                                .ignoresSafeArea()
                                .transition(.opacity)
                        }
                    }

                if let draft = selectedDraft {
                    AddRecordEditorOverlay(
                        draft: draft,
                        categories: categories,
                        accounts: accounts,
                        currencyOptions: currencyOptions,
                        savedContext: savedContext,
                        onBack: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                selectedDraft = nil
                            }
                        },
                        onSave: { type, money, category, account, targetAccount, occurredAt, note in
                            onSave(type, money, category, account, targetAccount, occurredAt, note)
                            savedContext = SavedRecordContext(
                                accountID: account?.id,
                                targetAccountID: targetAccount?.id,
                                occurredAt: occurredAt,
                                currencyCode: money.currencyCode
                            )
                        },
                        onDone: {
                            dismiss()
                        },
                        onAddAnother: {
                            // 回到分类选择页，保留上下文
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                selectedDraft = nil
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(NumiColor.surfacePage.ignoresSafeArea())
            .animation(.spring(response: 0.34, dampingFraction: 0.9), value: selectedDraft != nil)
        }
        .interactiveDismissDisabled(selectedDraft != nil)
    }

    private var categorySelectionPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                Picker("record.type", selection: $selectedType) {
                    Text("record.expense").tag(TransactionType.expense).accessibilityIdentifier("transactionType.expense")
                    Text("record.income").tag(TransactionType.income).accessibilityIdentifier("transactionType.income")
                    Text("record.transfer").tag(TransactionType.transfer).accessibilityIdentifier("transactionType.transfer")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("picker.transactionType")

                if selectedType == .transfer {
                    transferCard
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: NumiSpacing.s3), count: 4), spacing: NumiSpacing.s4) {
                        ForEach(visibleCategories) { category in
                            Button {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                                    selectedDraft = TransactionDraft(type: selectedType, categoryID: category.id)
                                }
                            } label: {
                                VStack(spacing: NumiSpacing.s2) {
                                    CategoryIconView(category: category, size: 68)
                                        .background(NumiColor.surfaceCard)
                                        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
                                    Text(category.localizedDisplayName)
                                        .font(NumiFont.footnote)
                                        .foregroundStyle(NumiColor.textPrimary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("category.\(category.id.uuidString)")
                        }
                    }
                }
            }
            .padding(NumiSpacing.s5)
            .padding(.bottom, 40)
        }
        .accessibilityIdentifier("sheet.addRecord")
        .navigationTitle("record.select.category")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel") {
                    dismiss()
                }
                .tint(NumiColor.accentDeep)
                .accessibilityIdentifier("action.closeAddRecordSelection")
            }
        }
        #if os(iOS)
        .toolbarBackground(NumiColor.surfacePage, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .tint(NumiColor.accentDeep)
    }

    private var visibleCategories: [NumiCore.Category] {
        categories
            .filter { $0.kind == (selectedType == .income ? .income : .expense) && !$0.isHidden }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var transferCard: some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                selectedDraft = TransactionDraft(type: .transfer, categoryID: nil)
            }
        } label: {
            VStack(alignment: .leading, spacing: NumiSpacing.s4) {
                HStack(spacing: NumiSpacing.s3) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(NumiColor.accentDeep)
                    Text("record.new.transfer")
                        .font(NumiFont.bodyStrong)
                        .foregroundStyle(NumiColor.textPrimary)
                }
                Text("addRecordFlow.transfer.description")
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.textTertiary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(NumiSpacing.s5)
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.sheet, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("category.transfer")
    }
}

/// 保存上下文，用于"再记一笔"保留日期/账户/币种
struct SavedRecordContext {
    let accountID: UUID?
    let targetAccountID: UUID?
    let occurredAt: Date
    let currencyCode: String

    /// 只保留日期部分，时间用当前时间，避免多笔记录时间戳相同导致排序问题
    var dateOnly: Date {
        Calendar.current.startOfDay(for: occurredAt)
    }
}

public struct TransactionDraft: Hashable, Identifiable {
    public let type: TransactionType
    public let categoryID: UUID?

    public var id: String {
        "\(type.rawValue)-\(categoryID?.uuidString ?? "transfer")"
    }

    public init(type: TransactionType, categoryID: UUID?) {
        self.type = type
        self.categoryID = categoryID
    }
}

private struct AddRecordEditorOverlay: View {
    let draft: TransactionDraft
    let categories: [NumiCore.Category]
    let accounts: [Account]
    let currencyOptions: [NumiCurrencyOption]
    let savedContext: SavedRecordContext?
    let onBack: () -> Void
    let onSave: (TransactionType, Money, NumiCore.Category?, Account?, Account?, Date, String) -> Void
    let onDone: () -> Void
    let onAddAnother: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(NumiColor.surfacePage)
                        .frame(height: bottomInset + 40)

                    VStack(spacing: 0) {
                        Capsule()
                            .fill(NumiColor.textTertiary.opacity(0.28))
                            .frame(width: 38, height: 5)
                            .padding(.top, 10)
                            .padding(.bottom, 8)

                        HStack(spacing: NumiSpacing.s3) {
                            Button("common.back", action: onBack)
                                .font(NumiFont.body)
                                .foregroundStyle(NumiColor.textSecondary)
                                .accessibilityIdentifier("sheet.addRecordEditor.back")

                            Spacer(minLength: NumiSpacing.s2)

                            Text(title)
                                .font(NumiFont.bodyStrong)
                                .foregroundStyle(NumiColor.textPrimary)
                                .accessibilityIdentifier("sheet.addRecordEditor.title")

                            Spacer(minLength: NumiSpacing.s2)

                            Color.clear
                                .frame(width: 44, height: 28)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, NumiSpacing.s4)
                        .padding(.bottom, NumiSpacing.s2)

                        AddRecordEntryContent(
                            draft: draft,
                            categories: categories,
                            accounts: accounts,
                            currencyOptions: currencyOptions,
                            bottomSafeAreaInset: bottomInset,
                            savedContext: savedContext,
                            onSave: onSave,
                            onDone: onDone,
                            onAddAnother: onAddAnother
                        )
                    }
                    .background(NumiColor.surfacePage)
                    .clipShape(
                        UnevenRoundedRectangle(
                            cornerRadii: RectangleCornerRadii(
                                topLeading: 30,
                                bottomLeading: 0,
                                bottomTrailing: 0,
                                topTrailing: 30
                            ),
                            style: .continuous
                        )
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            cornerRadii: RectangleCornerRadii(
                                topLeading: 30,
                                bottomLeading: 0,
                                bottomTrailing: 0,
                                topTrailing: 30
                            ),
                            style: .continuous
                        )
                        .strokeBorder(.white.opacity(0.26), lineWidth: 0.8)
                    )
                }
                .offset(y: dragOffset)
                .contentShape(Rectangle())
                .highPriorityGesture(dismissGesture)
                .shadow(color: .black.opacity(0.08), radius: 18, y: -2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sheet.addRecordEditor")
    }

    private var title: String {
        switch draft.type {
        case .expense:
            return NumiLocalized.string( "record.new.expense")
        case .income:
            return NumiLocalized.string( "record.new.income")
        case .transfer:
            return NumiLocalized.string( "record.new.transfer")
        }
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                let shouldDismiss = value.translation.height > 120 || value.predictedEndTranslation.height > 180
                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                    dragOffset = 0
                }
                if shouldDismiss {
                    onBack()
                }
            }
    }
}

private struct AddRecordEntryContent: View {
    let draft: TransactionDraft
    let categories: [NumiCore.Category]
    let accounts: [Account]
    let currencyOptions: [NumiCurrencyOption]
    let bottomSafeAreaInset: CGFloat
    let savedContext: SavedRecordContext?
    let onSave: (TransactionType, Money, NumiCore.Category?, Account?, Account?, Date, String) -> Void
    let onDone: () -> Void
    let onAddAnother: () -> Void

    @State private var selectedAccountID: UUID?
    @State private var selectedTargetAccountID: UUID?
    @State private var selectedDate = Date()
    @State private var inputState: MoneyInputState
    @State private var note = ""
    @State private var selectedCurrencyCode: String
    @State private var isDatePickerPresented = false
    @State private var pendingDate = Date()
    @FocusState private var isNoteFocused: Bool

    init(
        draft: TransactionDraft,
        categories: [NumiCore.Category],
        accounts: [Account],
        currencyOptions: [NumiCurrencyOption],
        bottomSafeAreaInset: CGFloat = 0,
        savedContext: SavedRecordContext? = nil,
        onSave: @escaping (TransactionType, Money, NumiCore.Category?, Account?, Account?, Date, String) -> Void,
        onDone: @escaping () -> Void = {},
        onAddAnother: @escaping () -> Void = {}
    ) {
        self.draft = draft
        self.categories = categories
        self.accounts = accounts
        self.currencyOptions = currencyOptions
        self.bottomSafeAreaInset = bottomSafeAreaInset
        self.savedContext = savedContext
        self.onSave = onSave
        self.onDone = onDone
        self.onAddAnother = onAddAnother
        let initialCurrency = savedContext?.currencyCode ?? currencyOptions.first?.code ?? "CNY"
        _selectedCurrencyCode = State(initialValue: initialCurrency)
        _inputState = State(initialValue: MoneyInputState(currencyCode: initialCurrency))
        _selectedDate = State(initialValue: Date())  // 始终用当前时间
        _selectedAccountID = State(initialValue: savedContext?.accountID)
        _selectedTargetAccountID = State(initialValue: savedContext?.targetAccountID)
    }

    var body: some View {
        VStack(spacing: NumiSpacing.s2) {
            categorySummaryCard
            amountCard
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.bottom, max(NumiSpacing.s4, bottomSafeAreaInset + 6))
        .background(NumiColor.surfacePage)
        .onAppear(perform: ensureSelectedAccounts)
        .onChange(of: selectedCurrencyCode) { _, newValue in
            inputState.updateCurrencyCode(newValue)
        }
        .sheet(isPresented: $isDatePickerPresented) {
            datePickerSheet
                .presentationDetents([.height(430)])
                .presentationCornerRadius(28)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button(NumiLocalized.string( "common.collapse")) {
                    isNoteFocused = false
                }
                Spacer()
                Button(NumiLocalized.string( "addRecordFlow.action.saveAndAddAnother")) {
                    save()
                    onAddAnother()
                }
                .disabled(!canSubmit)
                Button(draft.type == .transfer ? NumiLocalized.string( "addRecordFlow.action.saveTransfer") : NumiLocalized.string( "addRecordFlow.action.saveRecord")) {
                    save()
                    onDone()
                }
                .disabled(!canSubmit)
                .accessibilityIdentifier("action.keyboardSubmitRecord")
            }
        }
    }

    private var categorySummaryCard: some View {
        HStack(spacing: NumiSpacing.s3) {
            CategoryIconView(iconName: categoryIconName, size: 38)
                .foregroundStyle(NumiColor.accentDeep)
                .background(NumiColor.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(categoryTitle)
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)
                Text(summarySubtitle)
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, NumiSpacing.s2)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
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
            HStack(spacing: NumiSpacing.s2) {
                Button {
                    save()
                    onAddAnother()
                } label: {
                    Text("addRecordFlow.action.saveAndAddAnother")
                        .font(NumiFont.bodyStrong)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(NumiColor.controlFill)
                        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
                        .foregroundStyle(NumiColor.accentDeep)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .opacity(isNoteFocused ? 0.001 : 1)
                .allowsHitTesting(!isNoteFocused)
                .accessibilityIdentifier("action.saveAndAddAnother")
                .accessibilityValue("style.dateAccent")

                Button {
                    save()
                    onDone()
                } label: {
                    Text(draft.type == .transfer ? "addRecordFlow.action.saveTransfer" : "addRecordFlow.action.saveRecord")
                        .font(NumiFont.bodyStrong)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(NumiColor.accentPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
                        .foregroundStyle(NumiColor.textPrimary)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .opacity(isNoteFocused ? 0.001 : 1)
                .allowsHitTesting(!isNoteFocused)
                .accessibilityIdentifier("action.submitRecord")
                .accessibilityValue("style.accent")
            }
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
                        Label("\(option.symbol) \(option.code)", systemImage: selectedCurrencyCode == option.code ? "checkmark.circle.fill" : "circle")
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
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NumiColor.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("picker.inlineRecordCurrency")
        }
    }

    private var inlineMetaBar: some View {
        VStack(spacing: NumiSpacing.s2) {
            if draft.type == .transfer {
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
            } else {
                HStack(spacing: NumiSpacing.s2) {
                    inlineAccountMenu(
                        title: NumiLocalized.string( "record.account"),
                        selectedName: selectedAccount?.localizedDisplayName ?? NumiLocalized.string( "empty.no.selection"),
                        accessibilityIdentifier: "picker.inlineRecordAccount",
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
                .accessibilityIdentifier("input.inlineRecordNote")
            if !note.isEmpty {
                Button {
                    note = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(NumiColor.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("action.clearInlineRecordNote")
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(NumiColor.surfaceCardSubtle)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    private var selectedCategory: NumiCore.Category? {
        categories.first { $0.id == draft.categoryID }
    }

    private var visibleAccounts: [Account] {
        accounts.filter { !$0.isHidden }
    }

    private var targetAccounts: [Account] {
        visibleAccounts.filter { $0.id != selectedAccountID }
    }

    private var selectedAccount: Account? {
        visibleAccounts.first { $0.id == selectedAccountID } ?? visibleAccounts.first
    }

    private var selectedTargetAccount: Account? {
        targetAccounts.first { $0.id == selectedTargetAccountID } ?? targetAccounts.first
    }

    private var categoryTitle: String {
        draft.type == .transfer ? NumiLocalized.string( "record.transfer.title") : (selectedCategory?.localizedDisplayName ?? NumiLocalized.string( "empty.no.category"))
    }

    private var categoryIconName: String {
        draft.type == .transfer ? "arrow.left.arrow.right.circle.fill" : (selectedCategory?.icon ?? "tag.fill")
    }

    private var summarySubtitle: String {
        draft.type == .transfer ? NumiLocalized.string( "addRecordFlow.transfer.subtitle") : NumiLocalized.string( "addRecordFlow.record.subtitle")
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

    private var canSubmit: Bool {
        guard (try? inputState.money()) != nil else { return false }
        if draft.type == .transfer {
            return selectedAccount?.id != nil && selectedTargetAccount?.id != nil && selectedAccount?.id != selectedTargetAccount?.id
        }
        return selectedAccount?.id != nil
    }

    private func ensureSelectedAccounts() {
        if selectedAccountID == nil {
            selectedAccountID = visibleAccounts.first?.id
        }
        if draft.type == .transfer, selectedTargetAccountID == nil {
            selectedTargetAccountID = targetAccounts.first?.id
        }
    }

    private func save() {
        isNoteFocused = false
        guard let money = try? inputState.money() else { return }
        if draft.type == .transfer, selectedAccount?.id == selectedTargetAccount?.id {
            return
        }
        onSave(
            draft.type,
            money,
            selectedCategory,
            selectedAccount,
            selectedTargetAccount,
            selectedDate,
            note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
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
                selectedDate = pendingDate
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
