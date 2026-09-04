import SwiftUI
import NumiCore

public struct TransactionSearchRow: Identifiable {
    public let transaction: NumiCore.Transaction
    public let fallbackCategoryName: String
    public let fallbackIconName: String
    public let fallbackSubtitle: String?

    public var id: UUID { transaction.id }

    public init(transaction: NumiCore.Transaction, fallbackCategoryName: String, fallbackIconName: String, fallbackSubtitle: String?) {
        self.transaction = transaction
        self.fallbackCategoryName = fallbackCategoryName
        self.fallbackIconName = fallbackIconName
        self.fallbackSubtitle = fallbackSubtitle
    }
}

public struct TransactionSearchFilter: Equatable {
    public var query: String
    public var type: TransactionType?
    public var categoryID: UUID?
    public var accountID: UUID?
    public var dateInterval: DateInterval?
    public var minimumAmount: Money?
    public var maximumAmount: Money?

    public init(
        query: String = "",
        type: TransactionType? = nil,
        categoryID: UUID? = nil,
        accountID: UUID? = nil,
        dateInterval: DateInterval? = nil,
        minimumAmount: Money? = nil,
        maximumAmount: Money? = nil
    ) {
        self.query = query
        self.type = type
        self.categoryID = categoryID
        self.accountID = accountID
        self.dateInterval = dateInterval
        self.minimumAmount = minimumAmount
        self.maximumAmount = maximumAmount
    }

    public var hasActiveCriteria: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || type != nil
            || categoryID != nil
            || accountID != nil
            || dateInterval != nil
            || minimumAmount != nil
            || maximumAmount != nil
    }

    public func matches(row: TransactionSearchRow, categoryName: String, subtitle: String?) -> Bool {
        let transaction = row.transaction
        if let type, transaction.type != type { return false }
        if let categoryID, transaction.categoryID != categoryID { return false }
        if let accountID, transaction.accountID != accountID { return false }
        if let dateInterval, !dateInterval.contains(transaction.occurredAt) { return false }

        if let minimumAmount {
            guard transaction.amount.currencyCode == minimumAmount.currencyCode,
                  transaction.amount.minorUnits >= minimumAmount.minorUnits else { return false }
        }
        if let maximumAmount {
            guard transaction.amount.currencyCode == maximumAmount.currencyCode,
                  transaction.amount.minorUnits <= maximumAmount.minorUnits else { return false }
        }

        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return true }
        return [
            categoryName,
            row.fallbackCategoryName,
            subtitle ?? "",
            row.fallbackSubtitle ?? "",
            transaction.note,
            transaction.amount.formatted(),
            NumiDatePickerRow.displayText(for: transaction.occurredAt)
        ].contains { $0.localizedCaseInsensitiveContains(keyword) }
    }
}

public struct TransactionSearchView: View {
    @Environment(\.dismiss) private var dismiss

    private let rows: [TransactionSearchRow]
    private let categories: [NumiCore.Category]
    private let accounts: [Account]
    private let onSelect: (NumiCore.Transaction) -> Void

    @State private var query = ""
    @State private var filter = TransactionSearchFilter()
    @State private var isFilterPresented = false
    @FocusState private var isSearchFocused: Bool

    public init(
        rows: [TransactionSearchRow],
        categories: [NumiCore.Category] = [],
        accounts: [Account] = [],
        onSelect: @escaping (NumiCore.Transaction) -> Void = { _ in }
    ) {
        self.rows = rows
        self.categories = categories
        self.accounts = accounts
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, NumiSpacing.s4)
                .padding(.vertical, NumiSpacing.s2)
                .background(NumiColor.surfacePage)

            List {
                if filteredRows.isEmpty {
                    searchEmptyState
                        .listRowInsets(EdgeInsets(top: 48, leading: NumiSpacing.s5, bottom: 0, trailing: NumiSpacing.s5))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredRows) { row in
                        NumiRecordRow(
                            transaction: row.transaction,
                            categoryName: resolvedCategoryName(for: row),
                            iconName: resolvedIconName(for: row),
                            subtitle: resolvedSubtitle(for: row),
                            style: .card
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(row.transaction)
                        }
                        .accessibilityIdentifier("search.record.\(row.transaction.id.uuidString)")
                        .listRowInsets(EdgeInsets(top: 0, leading: NumiSpacing.s5, bottom: NumiSpacing.s3, trailing: NumiSpacing.s5))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(NumiColor.surfacePage)
            .accessibilityIdentifier("list.transactionSearchResults")
        }
        .background(NumiColor.surfacePage)
        .navigationTitle(NumiLocalized.string("common.search"))
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isFilterPresented = true
                } label: {
                    Image(systemName: filter.hasActiveCriteria ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel(NumiLocalized.string("search.filters"))
                .accessibilityIdentifier("action.openTransactionFilters")
            }
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Text(NumiLocalized.string("common.close"))
                }
                .accessibilityIdentifier("action.closeTransactionSearch")
            }
        }
        .accessibilityIdentifier("page.transactionSearch")
        .sheet(isPresented: $isFilterPresented) {
            TransactionSearchFilterSheet(
                filter: $filter,
                categories: categories,
                accounts: accounts
            )
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    private var searchBar: some View {
        HStack(spacing: NumiSpacing.s3) {
            HStack(spacing: NumiSpacing.s2) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(NumiColor.textTertiary)
                TextField(NumiLocalized.string("common.search"), text: $query)
                    .focused($isSearchFocused)
                    .textFieldStyle(.plain)
                    .font(NumiFont.body)
                    .accessibilityIdentifier("input.transactionSearch")
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(NumiColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("action.clearSearch")
                }
            }
            .padding(.horizontal, NumiSpacing.s3)
            .padding(.vertical, 10)
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))

            if isSearchFocused {
                Button {
                    query = ""
                    isSearchFocused = false
                } label: {
                    Text(NumiLocalized.string("common.cancel"))
                        .font(NumiFont.body)
                        .foregroundStyle(NumiColor.accentDeep)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("action.cancelSearch")
            }
        }
    }

    private var filteredRows: [TransactionSearchRow] {
        var activeFilter = filter
        activeFilter.query = query
        guard activeFilter.hasActiveCriteria else { return rows }
        return rows.filter { row in
            activeFilter.matches(
                row: row,
                categoryName: resolvedCategoryName(for: row),
                subtitle: resolvedSubtitle(for: row)
            )
        }
    }

    private func resolvedCategoryName(for row: TransactionSearchRow) -> String {
        RuntimeLocalizedDisplay.categoryName(
            for: row.transaction,
            categories: categories,
            fallbackCategoryName: row.fallbackCategoryName
        )
    }

    private func resolvedIconName(for row: TransactionSearchRow) -> String {
        RuntimeLocalizedDisplay.categoryIconName(
            for: row.transaction,
            categories: categories,
            fallbackCategoryIcon: row.fallbackIconName
        )
    }

    private func resolvedSubtitle(for row: TransactionSearchRow) -> String? {
        RuntimeLocalizedDisplay.transferSubtitle(
            for: row.transaction,
            accounts: accounts,
            fallbackSubtitle: row.fallbackSubtitle
        )
    }

    private var searchEmptyState: some View {
        VStack(spacing: NumiSpacing.s4) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(NumiColor.textTertiary)
            Text(NumiLocalized.string("empty.search"))
                .font(NumiFont.bodyStrong)
                .foregroundStyle(NumiColor.textPrimary)
            Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NumiLocalized.string( "empty.home.desc") : NumiLocalized.string( "empty.search"))
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

private struct TransactionSearchFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: TransactionSearchFilter
    let categories: [NumiCore.Category]
    let accounts: [Account]

    @State private var type: TransactionType?
    @State private var categoryID: UUID?
    @State private var accountID: UUID?
    @State private var useDateRange = false
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var minimumAmountText = ""
    @State private var maximumAmountText = ""

    init(filter: Binding<TransactionSearchFilter>, categories: [NumiCore.Category], accounts: [Account]) {
        self._filter = filter
        self.categories = categories.filter { !$0.isHidden }
        self.accounts = accounts.filter { !$0.isHidden }
        let value = filter.wrappedValue
        _type = State(initialValue: value.type)
        _categoryID = State(initialValue: value.categoryID)
        _accountID = State(initialValue: value.accountID)
        _useDateRange = State(initialValue: value.dateInterval != nil)
        _startDate = State(initialValue: value.dateInterval?.start ?? Date())
        _endDate = State(initialValue: value.dateInterval?.end ?? Date())
        _minimumAmountText = State(initialValue: value.minimumAmount.map(Self.decimalText) ?? "")
        _maximumAmountText = State(initialValue: value.maximumAmount.map(Self.decimalText) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("search.filter.type") {
                    Picker("search.filter.type", selection: $type) {
                        Text("search.filter.allTypes").tag(TransactionType?.none)
                        Text("record.expense").tag(TransactionType?.some(.expense))
                        Text("record.income").tag(TransactionType?.some(.income))
                        Text("record.transfer").tag(TransactionType?.some(.transfer))
                    }
                    .accessibilityIdentifier("picker.transactionFilterType")
                }
                Section("search.filter.scope") {
                    Picker("search.filter.category", selection: $categoryID) {
                        Text("search.filter.allCategories").tag(UUID?.none)
                        ForEach(categories.filter { $0.kind == .expense || $0.kind == .income }) { category in
                            Text(category.localizedDisplayName).tag(Optional(category.id))
                        }
                    }
                    .accessibilityIdentifier("picker.transactionFilterCategory")
                    Picker("search.filter.account", selection: $accountID) {
                        Text("search.filter.allAccounts").tag(UUID?.none)
                        ForEach(accounts) { account in
                            Text(account.localizedDisplayName).tag(Optional(account.id))
                        }
                    }
                    .accessibilityIdentifier("picker.transactionFilterAccount")
                }
                Section("search.filter.date") {
                    Toggle("search.filter.enableDate", isOn: $useDateRange)
                        .accessibilityIdentifier("toggle.transactionFilterDate")
                    if useDateRange {
                        DatePicker("search.filter.from", selection: $startDate, displayedComponents: .date)
                        DatePicker("search.filter.to", selection: $endDate, displayedComponents: .date)
                    }
                }
                Section("search.filter.amount") {
                    TextField("search.filter.minimum", text: $minimumAmountText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .accessibilityIdentifier("input.transactionFilterMinimum")
                    TextField("search.filter.maximum", text: $maximumAmountText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .accessibilityIdentifier("input.transactionFilterMaximum")
                }
            }
            .navigationTitle(NumiLocalized.string("search.filters"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.apply") {
                        apply()
                        dismiss()
                    }
                    .accessibilityIdentifier("action.applyTransactionFilters")
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("common.reset") {
                        reset()
                    }
                    .accessibilityIdentifier("action.resetTransactionFilters")
                }
            }
        }
    }

    private func apply() {
        let currencyCode = accounts.first?.balance.currencyCode ?? "CNY"
        filter.type = type
        filter.categoryID = categoryID
        filter.accountID = accountID
        filter.dateInterval = useDateRange
            ? DateInterval(start: min(startDate, endDate), end: max(startDate, endDate).addingTimeInterval(86_400))
            : nil
        filter.minimumAmount = try? Money(decimalString: minimumAmountText, currencyCode: currencyCode)
        filter.maximumAmount = try? Money(decimalString: maximumAmountText, currencyCode: currencyCode)
    }

    private func reset() {
        type = nil
        categoryID = nil
        accountID = nil
        useDateRange = false
        minimumAmountText = ""
        maximumAmountText = ""
        filter = TransactionSearchFilter()
    }

    private static func decimalText(_ money: Money) -> String {
        let scale = Money.scale(for: money.currencyCode)
        let whole = abs(money.minorUnits) / scale
        let fractionDigits = Money.fractionDigits(for: money.currencyCode)
        guard fractionDigits > 0 else { return "\(whole)" }
        let fraction = abs(money.minorUnits) % scale
        return "\(whole).\(String(format: "%0\(fractionDigits)lld", fraction))"
    }
}
