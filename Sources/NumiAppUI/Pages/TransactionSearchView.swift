import SwiftUI
import NumiCore

public struct TransactionSearchRow: Identifiable {
    public let transaction: NumiCore.Transaction
    public let categoryName: String
    public let iconName: String
    public let subtitle: String?

    public var id: UUID { transaction.id }

    public init(transaction: NumiCore.Transaction, categoryName: String, iconName: String, subtitle: String?) {
        self.transaction = transaction
        self.categoryName = categoryName
        self.iconName = iconName
        self.subtitle = subtitle
    }
}

public struct TransactionSearchView: View {
    @Environment(\.dismiss) private var dismiss

    private let rows: [TransactionSearchRow]
    private let onSelect: (NumiCore.Transaction) -> Void

    @State private var query = ""

    public init(
        rows: [TransactionSearchRow],
        onSelect: @escaping (NumiCore.Transaction) -> Void = { _ in }
    ) {
        self.rows = rows
        self.onSelect = onSelect
    }

    public var body: some View {
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
                        categoryName: row.categoryName,
                        iconName: row.iconName,
                        subtitle: row.subtitle,
                        style: .card
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(row.transaction)
                    }
                    .accessibilityIdentifier("search.record.\(row.categoryName)")
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
        .navigationTitle("搜索账单")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    dismiss()
                }
            }
        }
        .accessibilityIdentifier("page.transactionSearch")
        #if os(iOS)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索分类、备注、金额或时间")
        .navigationBarTitleDisplayMode(.inline)
        #else
        .searchable(text: $query, prompt: "搜索分类、备注、金额或时间")
        #endif
    }

    private var filteredRows: [TransactionSearchRow] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return rows }

        return rows.filter { (row: TransactionSearchRow) in
            row.categoryName.localizedCaseInsensitiveContains(keyword)
            || row.transaction.note.localizedCaseInsensitiveContains(keyword)
            || row.transaction.amount.formatted().localizedCaseInsensitiveContains(keyword)
            || (row.subtitle?.localizedCaseInsensitiveContains(keyword) ?? false)
            || NumiDatePickerRow.displayText(for: row.transaction.occurredAt).localizedCaseInsensitiveContains(keyword)
        }
    }

    private var searchEmptyState: some View {
        VStack(spacing: NumiSpacing.s4) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(NumiColor.textTertiary)
            Text("没有匹配的账单")
                .font(NumiFont.bodyStrong)
                .foregroundStyle(NumiColor.textPrimary)
            Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "输入分类、备注、金额或时间来快速查找。" : "换个关键词试试，或者返回首页浏览最近记录。")
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}
