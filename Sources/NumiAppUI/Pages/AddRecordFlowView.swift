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
                        onBack: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                selectedDraft = nil
                            }
                        },
                        onSave: { type, money, category, account, targetAccount, occurredAt, note in
                            onSave(type, money, category, account, targetAccount, occurredAt, note)
                            dismiss()
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
                Picker("类型", selection: $selectedType) {
                    Text("支出").tag(TransactionType.expense).accessibilityIdentifier("transactionType.支出")
                    Text("收入").tag(TransactionType.income).accessibilityIdentifier("transactionType.收入")
                    Text("转账").tag(TransactionType.transfer).accessibilityIdentifier("transactionType.转账")
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
                                    Image(systemName: category.icon)
                                        .font(.system(size: 28, weight: .medium))
                                        .frame(width: 68, height: 68)
                                        .background(NumiColor.surfaceCard)
                                        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
                                    Text(category.name)
                                        .font(NumiFont.footnote)
                                        .foregroundStyle(NumiColor.textPrimary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("category.\(category.name)")
                        }
                    }
                }
            }
            .padding(NumiSpacing.s5)
            .padding(.bottom, 40)
        }
        .accessibilityIdentifier("sheet.addRecord")
        .navigationTitle("选择分类")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
                .tint(NumiColor.accentDeep)
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
                    Text("新建转账")
                        .font(NumiFont.bodyStrong)
                        .foregroundStyle(NumiColor.textPrimary)
                }
                Text("先选转出和转入账户，再填写金额、日期、备注和币种。")
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
    let onBack: () -> Void
    let onSave: (TransactionType, Money, NumiCore.Category?, Account?, Account?, Date, String) -> Void

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
                            Button("返回", action: onBack)
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
                            onSave: onSave
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
            return "新建支出"
        case .income:
            return "新建收入"
        case .transfer:
            return "新建转账"
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
    let onSave: (TransactionType, Money, NumiCore.Category?, Account?, Account?, Date, String) -> Void

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
        onSave: @escaping (TransactionType, Money, NumiCore.Category?, Account?, Account?, Date, String) -> Void
    ) {
        self.draft = draft
        self.categories = categories
        self.accounts = accounts
        self.currencyOptions = currencyOptions
        self.bottomSafeAreaInset = bottomSafeAreaInset
        self.onSave = onSave
        let initialCurrency = currencyOptions.first?.code ?? "CNY"
        _selectedCurrencyCode = State(initialValue: initialCurrency)
        _inputState = State(initialValue: MoneyInputState(currencyCode: initialCurrency))
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
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("收起") {
                    isNoteFocused = false
                }
                Spacer()
                Button(draft.type == .transfer ? "保存转账" : "记一笔") {
                    save()
                }
                .disabled(!canSubmit)
                .accessibilityIdentifier("action.keyboardSubmitRecord")
            }
        }
    }

    private var categorySummaryCard: some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: categoryIconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(NumiColor.accentDeep)
                .frame(width: 38, height: 38)
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
        .background(NumiColor.surfaceCardSubtle)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
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
            Button {
                save()
            } label: {
                Text(draft.type == .transfer ? "保存转账" : "记一笔")
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
            } else {
                HStack(spacing: NumiSpacing.s2) {
                    inlineAccountMenu(
                        title: "账户",
                        selectedName: selectedAccount?.name ?? "未选择",
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
            TextField("备注", text: $note)
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
        draft.type == .transfer ? "账户转账" : (selectedCategory?.name ?? "未分类")
    }

    private var categoryIconName: String {
        draft.type == .transfer ? "arrow.left.arrow.right.circle.fill" : (selectedCategory?.icon ?? "tag.fill")
    }

    private var summarySubtitle: String {
        draft.type == .transfer ? "选择转出与转入账户后完成转账" : "金额、账户、日期和备注都在下方完成"
    }

    private var selectedCurrencySymbol: String {
        currencyOptions.first { $0.code == selectedCurrencyCode }?.symbol ?? selectedCurrencyCode
    }

    private var currentDateShortcutTitle: String {
        NumiDatePickerRow.displayText(for: selectedDate)
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
            title: "选择日期",
            showsGrabber: false,
            accessibilityPrefix: "sheet.datePicker",
            dismissAccessibilitySuffix: "cancel",
            confirmAccessibilitySuffix: "confirm",
            dismissTitle: "取消",
            confirmTitle: "完成",
            onDismiss: {
                isDatePickerPresented = false
            },
            onConfirm: {
                selectedDate = pendingDate
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
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
