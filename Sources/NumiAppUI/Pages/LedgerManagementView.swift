import SwiftUI
import NumiCore

// MARK: - Ledger Draft

public struct LedgerDraft: Identifiable {
    public var id: UUID?
    public var name: String
    public var currencyCode: String

    public init(id: UUID? = nil, name: String, currencyCode: String) {
        self.id = id
        self.name = name
        self.currencyCode = currencyCode
    }

    static func new(currencyCode: String) -> LedgerDraft {
        LedgerDraft(id: nil, name: "", currencyCode: currencyCode)
    }

    static func existing(_ ledger: Ledger) -> LedgerDraft {
        LedgerDraft(id: ledger.id, name: ledger.name, currencyCode: ledger.currencyCode)
    }

    var isNew: Bool { id == nil }
}

// MARK: - Ledger Management View

public struct LedgerManagementView: View {
    @State private var editingDraft: LedgerDraft?
    @State private var pendingDelete: Ledger?
    @State private var showDeleteConfirm = false

    private let ledgers: [Ledger]
    private let transactionCounts: [UUID: Int]
    private let currentLedgerID: UUID
    private let onCreate: (LedgerDraft) -> Void
    private let onUpdate: (Ledger, LedgerDraft) -> Void
    private let onDelete: (Ledger) -> Void
    private let onSelect: (Ledger) -> Void

    public init(
        ledgers: [Ledger],
        transactionCounts: [UUID: Int] = [:],
        currentLedgerID: UUID,
        onCreate: @escaping (LedgerDraft) -> Void = { _ in },
        onUpdate: @escaping (Ledger, LedgerDraft) -> Void = { _, _ in },
        onDelete: @escaping (Ledger) -> Void = { _ in },
        onSelect: @escaping (Ledger) -> Void = { _ in }
    ) {
        self.ledgers = ledgers
        self.transactionCounts = transactionCounts
        self.currentLedgerID = currentLedgerID
        self.onCreate = onCreate
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onSelect = onSelect
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                // 说明卡片
                VStack(alignment: .leading, spacing: NumiSpacing.s2) {
                    Text("ledger.info")
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textTertiary)
                }
                .padding(NumiSpacing.s5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NumiColor.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)

                // 账本列表
                VStack(alignment: .leading, spacing: NumiSpacing.s3) {
                    Text("ledger.section")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(NumiColor.textSecondary)

                    VStack(spacing: 0) {
                        ForEach(sortedLedgers) { ledger in
                            ledgerRow(ledger)
                            if ledger.id != sortedLedgers.last?.id {
                                Divider().padding(.leading, 36 + NumiSpacing.s3)
                            }
                        }
                    }
                    .background(NumiColor.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                }
            }
            .padding(.horizontal, NumiSpacing.s5)
            .padding(.top, NumiSpacing.s4)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(NumiColor.surfacePage)
        .navigationTitle("ledger.title")
        .modifier(LargeTitleNavigationChrome())
        .tint(NumiColor.accentDeep)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingDraft = .new(currencyCode: "CNY")
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("button.addLedger")
            }
        }
        .sheet(item: $editingDraft) { draft in
            LedgerFormSheet(
                draft: draft,
                existingNames: sortedLedgers.map(\.name)
            ) { saved in
                if saved.isNew {
                    onCreate(saved)
                } else if let ledger = sortedLedgers.first(where: { $0.id == saved.id }) {
                    onUpdate(ledger, saved)
                }
                editingDraft = nil
            }
            .presentationDetents([.medium])
            .presentationCornerRadius(28)
        }
        .alert("ledger.delete.confirm", isPresented: $showDeleteConfirm) {
            Button("common.cancel", role: .cancel) {
                pendingDelete = nil
            }
            Button("common.delete", role: .destructive) {
                if let ledger = pendingDelete {
                    onDelete(ledger)
                    pendingDelete = nil
                }
            }
        } message: {
            if let ledger = pendingDelete {
                let count = transactionCounts[ledger.id] ?? 0
                Text(NumiLocalized.string("ledger.delete.msg", ledger.localizedDisplayName, count))
            }
        }
    }

    private var sortedLedgers: [Ledger] {
        ledgers.sortedForLocalizedDisplay()
    }

    @ViewBuilder
    private func ledgerRow(_ ledger: Ledger) -> some View {
        let isCurrent = ledger.id == currentLedgerID
        let count = transactionCounts[ledger.id] ?? 0

        HStack(spacing: NumiSpacing.s3) {
            ZStack {
                Circle()
                    .fill(isCurrent ? NumiColor.accentPrimary.opacity(0.15) : NumiColor.surfaceCardSubtle)
                    .frame(width: 36, height: 36)
                Image(systemName: isCurrent ? "book.fill" : "book")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isCurrent ? NumiColor.accentDeep : NumiColor.textTertiary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: NumiSpacing.s1) {
                    Text(ledger.localizedDisplayName)
                        .font(NumiFont.bodyStrong)
                        .foregroundStyle(NumiColor.textPrimary)
                    if isCurrent {
                        Text("ledger.current")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(NumiColor.accentDeep)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(NumiColor.accentPrimary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text("\(ledger.currencyCode) · \(NumiLocalized.string("insight.transaction.count", count))")
                    .font(NumiFont.footnote)
                    .foregroundStyle(NumiColor.textTertiary)
            }

            Spacer()

            Menu {
                if !isCurrent {
                    Button {
                        onSelect(ledger)
                    } label: {
                        Label("ledger.switch", systemImage: "arrow.left.arrow.right")
                    }
                }
                Button {
                    editingDraft = .existing(ledger)
                } label: {
                    Label("common.edit", systemImage: "pencil")
                }
                if sortedLedgers.count > 1 {
                    Button(role: .destructive) {
                        pendingDelete = ledger
                        showDeleteConfirm = true
                    } label: {
                        Label("common.delete", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(NumiColor.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, NumiSpacing.s3)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isCurrent {
                onSelect(ledger)
            }
        }
    }
}

// MARK: - Ledger Form Sheet

private struct LedgerFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LedgerDraft
    @State private var showCurrencyPicker = false

    private let existingNames: [String]
    private let onSave: (LedgerDraft) -> Void

    init(draft: LedgerDraft, existingNames: [String], onSave: @escaping (LedgerDraft) -> Void) {
        self._draft = State(initialValue: draft)
        self.existingNames = existingNames
        self.onSave = onSave
    }

    private var isValid: Bool {
        let trimmed = draft.name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        // 新建时检查重名
        if draft.isNew {
            return !existingNames.contains(trimmed)
        }
        // 编辑时允许保留原名
        return true
    }

    private var currencyDisplayName: String {
        CurrencyDefinition.common.first { $0.code == draft.currencyCode }?.name ?? draft.currencyCode
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("account.name") {
                    TextField("ledger.name.placeholder", text: $draft.name)
                        .font(NumiFont.body)
                }

                Section("ledger.currency") {
                    Button {
                        showCurrencyPicker = true
                    } label: {
                        HStack {
                            Text("ledger.currency")
                                .foregroundStyle(NumiColor.textPrimary)
                            Spacer()
                            Text("\(draft.currencyCode) \(currencyDisplayName)")
                                .foregroundStyle(NumiColor.textTertiary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(NumiColor.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if !isValid && !draft.name.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section {
                        Text("ledger.name.exists")
                            .font(NumiFont.footnote)
                            .foregroundStyle(NumiColor.negativeText)
                    }
                }
            }
            .navigationTitle(draft.isNew ? Text("ledger.new") : Text("ledger.edit"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
                        onSave(draft)
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showCurrencyPicker) {
                NavigationStack {
                    List(CurrencyDefinition.common, id: \.code) { currency in
                        Button {
                            draft.currencyCode = currency.code
                            showCurrencyPicker = false
                        } label: {
                            HStack {
                                Text("\(currency.symbol) \(currency.name)")
                                    .foregroundStyle(NumiColor.textPrimary)
                                Spacer()
                                Text(currency.code)
                                    .foregroundStyle(NumiColor.textTertiary)
                                if currency.code == draft.currencyCode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(NumiColor.accentDeep)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .navigationTitle("ledger.select.currency")
#if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
#endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common.cancel") { showCurrencyPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}
