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

public struct TransactionSearchView: View {
    @Environment(\.dismiss) private var dismiss

    private let rows: [TransactionSearchRow]
    private let categories: [NumiCore.Category]
    private let accounts: [Account]
    private let onSelect: (NumiCore.Transaction) -> Void

    @State private var query = ""
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
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return [] }

        return rows.filter { (row: TransactionSearchRow) in
            resolvedCategoryName(for: row).localizedCaseInsensitiveContains(keyword)
            || row.fallbackCategoryName.localizedCaseInsensitiveContains(keyword)
            || row.transaction.note.localizedCaseInsensitiveContains(keyword)
            || row.transaction.amount.formatted().localizedCaseInsensitiveContains(keyword)
            || (resolvedSubtitle(for: row)?.localizedCaseInsensitiveContains(keyword) ?? false)
            || (row.fallbackSubtitle?.localizedCaseInsensitiveContains(keyword) ?? false)
            || NumiDatePickerRow.displayText(for: row.transaction.occurredAt).localizedCaseInsensitiveContains(keyword)
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
