import SwiftUI
import NumiCore

public enum HomePeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case quarter
    case year

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .week: NumiLocalized.string("insight.dim.week")
        case .month: NumiLocalized.string("insight.dim.month")
        case .quarter: NumiLocalized.string("insight.dim.quarter")
        case .year: NumiLocalized.string("insight.dim.year")
        }
    }
}

public struct TransactionHomeRow: Identifiable {
    public let transaction: NumiCore.Transaction
    public let fallbackCategoryName: String
    public let fallbackIconName: String
    public let fallbackSubtitle: String?

    public var id: UUID { transaction.id }

    public init(
        transaction: NumiCore.Transaction,
        fallbackCategoryName: String,
        fallbackIconName: String,
        fallbackSubtitle: String?
    ) {
        self.transaction = transaction
        self.fallbackCategoryName = fallbackCategoryName
        self.fallbackIconName = fallbackIconName
        self.fallbackSubtitle = fallbackSubtitle
    }
}

public struct TransactionHomeSection: Identifiable {
    public let id: String
    public let title: String
    public let rows: [TransactionHomeRow]
    public let dailyExpense: Money?
    public let dailyIncome: Money?

    public init(id: String, title: String, rows: [TransactionHomeRow], dailyExpense: Money? = nil, dailyIncome: Money? = nil) {
        self.id = id
        self.title = title
        self.rows = rows
        self.dailyExpense = dailyExpense
        self.dailyIncome = dailyIncome
    }
}

public struct TransactionsHomeView: View {
    private let summary: TransactionSummary
    private let periodTitle: String
    private let selectedPeriod: HomePeriod
    private let isNextPeriodEnabled: Bool
    private let sections: [TransactionHomeSection]
    private let categories: [NumiCore.Category]
    private let accounts: [Account]
    private let currentLedger: Ledger?
    private let ledgers: [Ledger]
    private let onPreviousPeriod: () -> Void
    private let onNextPeriod: () -> Void
    private let onSelectPeriod: (HomePeriod) -> Void
    private let onSelect: (NumiCore.Transaction) -> Void
    private let onPrimaryAction: () -> Void
    private let onDelete: (NumiCore.Transaction) -> Void
    private let onUndoDelete: () -> Void
    private let onSearch: () -> Void
    private let onEdit: (NumiCore.Transaction) -> Void
    private let onShare: (NumiCore.Transaction) -> Void
    private let onSelectLedger: (Ledger) -> Void
    @State private var pendingDelete: NumiCore.Transaction?
    @State private var showsUndo = false
    @State private var showsPeriodPicker = false
    @State private var showsLedgerPicker = false

    public init(
        summary: TransactionSummary,
        periodTitle: String,
        selectedPeriod: HomePeriod,
        isNextPeriodEnabled: Bool,
        sections: [TransactionHomeSection],
        categories: [NumiCore.Category] = [],
        accounts: [Account] = [],
        currentLedger: Ledger? = nil,
        ledgers: [Ledger] = [],
        onPreviousPeriod: @escaping () -> Void = {},
        onNextPeriod: @escaping () -> Void = {},
        onSelectPeriod: @escaping (HomePeriod) -> Void = { _ in },
        onSearch: @escaping () -> Void = {},
        onSelect: @escaping (NumiCore.Transaction) -> Void = { _ in },
        onPrimaryAction: @escaping () -> Void = {},
        onEdit: @escaping (NumiCore.Transaction) -> Void = { _ in },
        onShare: @escaping (NumiCore.Transaction) -> Void = { _ in },
        onDelete: @escaping (NumiCore.Transaction) -> Void = { _ in },
        onUndoDelete: @escaping () -> Void = {},
        onSelectLedger: @escaping (Ledger) -> Void = { _ in }
    ) {
        self.summary = summary
        self.periodTitle = periodTitle
        self.selectedPeriod = selectedPeriod
        self.isNextPeriodEnabled = isNextPeriodEnabled
        self.sections = sections
        self.categories = categories
        self.accounts = accounts
        self.currentLedger = currentLedger
        self.ledgers = ledgers
        self.onPreviousPeriod = onPreviousPeriod
        self.onNextPeriod = onNextPeriod
        self.onSelectPeriod = onSelectPeriod
        self.onSearch = onSearch
        self.onSelect = onSelect
        self.onPrimaryAction = onPrimaryAction
        self.onEdit = onEdit
        self.onShare = onShare
        self.onDelete = onDelete
        self.onUndoDelete = onUndoDelete
        self.onSelectLedger = onSelectLedger
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            contentView
                .background(NumiColor.surfacePage)
                .modifier(HomeToolbarChrome(periodToolbarControl: periodToolbarControl, searchToolbarButton: searchToolbarButton))
                .confirmationDialog(
                    Text("record.delete.confirm"),
                    isPresented: deleteConfirmationBinding,
                    titleVisibility: .visible,
                    presenting: pendingDelete
                ) { transaction in
                    Button("common.delete", role: .destructive) {
                        onDelete(transaction)
                        showsUndo = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            withAnimation {
                                showsUndo = false
                            }
                        }
                    }
                    .accessibilityIdentifier("action.confirmDeleteRecord")

                    Button("common.cancel", role: .cancel) {}
                } message: { _ in
                    Text("record.deleted.msg")
                }

            if showsUndo {
                undoBar
                    .padding(.horizontal, NumiSpacing.s5)
                    .padding(.bottom, 152)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showsPeriodPicker) {
            homePeriodPickerSheet
                .presentationDetents([.height(320)])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showsLedgerPicker) {
            ledgerPickerSheet
                .presentationDetents([.medium])
                .presentationCornerRadius(28)
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDelete = nil
                }
            }
        )
    }

    private var periodToolbarControl: some View {
        HStack(spacing: 2) {
            toolbarChevronButton(
                systemImage: "chevron.left",
                identifier: "home.period.previous",
                action: onPreviousPeriod
            )
            Button {
                showsPeriodPicker = true
            } label: {
                HStack(spacing: 2) {
                    Text(periodTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(NumiColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NumiColor.textTertiary)
                        .padding(.horizontal, 2)
                }
                .frame(minWidth: 132)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.period.title")
            .accessibilityLabel(periodTitle)
            toolbarChevronButton(
                systemImage: "chevron.right",
                identifier: "home.period.next",
                isEnabled: isNextPeriodEnabled,
                action: onNextPeriod
            )
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: NumiSpacing.s3) {
            NumiSummaryTile(title: NumiLocalized.string( "record.expense"), value: summary.expense.formatted(), systemImage: "cart", variant: .expense, accessibilityKey: "home.expense")
            NumiSummaryTile(title: NumiLocalized.string( "record.income"), value: summary.income.formatted(), systemImage: "creditcard", variant: .income, accessibilityKey: "home.income")
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if sections.isEmpty {
            GeometryReader { proxy in
                NumiBottomAccessoryTrackingScrollView(accessibilityIdentifier: "scroll.transactionsHome") {
                    VStack(spacing: NumiSpacing.s5) {
                        ledgerSwitcherChip
                        summaryGrid
                        homeEmptyState
                            .frame(minHeight: max(proxy.size.height - 220, 360))
                    }
                    .padding(.horizontal, NumiSpacing.s5)
                    .padding(.top, NumiSpacing.s3)
                    .padding(.bottom, 120)
                }
            }
        } else {
            NumiBottomAccessoryTrackingScrollView(accessibilityIdentifier: "scroll.transactionsHome") {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ledgerSwitcherChip
                        .padding(.horizontal, NumiSpacing.s5)
                        .padding(.top, NumiSpacing.s3)
                        .padding(.bottom, NumiSpacing.s2)

                    summaryGrid
                        .padding(.horizontal, NumiSpacing.s5)
                        .padding(.bottom, NumiSpacing.s4)

                    recordsList
                }
                .padding(.bottom, 120)
            }
        }
    }

    private var recordsList: some View {
        ForEach(sections) { section in
            Section {
                NumiGroupedCard {
                    ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                        let isLast = index == section.rows.count - 1

                        PressableRow(onSelect: { onSelect(row.transaction) }) {
                            NumiRecordRow(
                                transaction: row.transaction,
                                categoryName: resolvedCategoryName(for: row),
                                iconName: resolvedIconName(for: row),
                                subtitle: resolvedSubtitle(for: row),
                                style: .grouped
                            )
                        }
                        .contextMenu {
                            Button {
                                onEdit(row.transaction)
                            } label: {
                                Label("common.edit", systemImage: "square.and.pencil")
                            }
                            .accessibilityIdentifier("action.context.editRecord")

                            Button {
                                pendingDelete = row.transaction
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }
                            .accessibilityIdentifier("action.context.deleteRecord")

                            Button {
                                onShare(row.transaction)
                            } label: {
                                Label("common.share", systemImage: "square.and.arrow.up")
                            }
                            .accessibilityIdentifier("action.context.shareRecord")
                        }

                        if !isLast {
                            NumiInsetDivider()
                        }
                    }
                }
                .padding(.horizontal, NumiSpacing.s5)
                .padding(.bottom, NumiSpacing.s4)
            } header: {
                HStack {
                    Text(section.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NumiColor.textSecondary.opacity(section.id == "today" || section.id == "yesterday" ? 1 : 0.92))

                    Spacer()

                    HStack(spacing: NumiSpacing.s1) {
                        if let expense = section.dailyExpense, expense.minorUnits > 0 {
                            Text("-\(expense.formatted())")
                                .font(NumiFont.caption)
                                .foregroundStyle(NumiColor.expenseText)
                                .monospacedDigit()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(NumiColor.expenseBackground)
                                .clipShape(Capsule())
                        }
                        if let income = section.dailyIncome, income.minorUnits > 0 {
                            Text("+\(income.formatted())")
                                .font(NumiFont.caption)
                                .foregroundStyle(NumiColor.incomeText)
                                .monospacedDigit()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(NumiColor.incomeBackground)
                                .clipShape(Capsule())
                        }
                    }
                }
                .textCase(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, NumiSpacing.s5)
                .padding(.top, NumiSpacing.s4)
                .padding(.bottom, NumiSpacing.s2)
                .background(NumiColor.surfacePage)
                .accessibilityIdentifier("home.sectionDate.\(section.id)")
            }
        }
    }

    private var undoBar: some View {
        HStack(spacing: NumiSpacing.s3) {
            Text("record.deleted")
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textPrimary)
            Spacer()
            Button {
                onUndoDelete()
                showsUndo = false
            } label: {
                Text("record.undo")
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.accentDeep)
                    .frame(minWidth: 72, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("action.undoDeleteRecord")
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, NumiSpacing.s3)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
    }

    private var searchToolbarButton: some View {
        Button {
            onSearch()
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: NumiChromeMetrics.toolbarSymbolSize, weight: .semibold))
                .foregroundStyle(NumiColor.textSecondary)
                .frame(
                    width: NumiChromeMetrics.toolbarButtonHitSize,
                    height: NumiChromeMetrics.toolbarButtonHitSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("action.openTransactionSearch")
    }

    private var homeEmptyState: some View {
        VStack(spacing: NumiSpacing.s5) {
            Spacer(minLength: 0)
            Image(systemName: "tray.full")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(NumiColor.textTertiary)
            VStack(spacing: NumiSpacing.s2) {
                Text("empty.home.title")
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)
                    .accessibilityIdentifier("home.empty.title")
                Text("empty.home.desc")
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.textTertiary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("home.empty.subtitle")
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, NumiSpacing.s6)
        .padding(.vertical, NumiSpacing.s5)
    }

    private func toolbarChevronButton(
        systemImage: String,
        identifier: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: NumiChromeMetrics.toolbarSymbolSize, weight: .semibold))
                .foregroundStyle(NumiColor.textSecondary)
                .frame(
                    width: 30,
                    height: NumiChromeMetrics.toolbarButtonHitSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.32)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Ledger Switcher

    @ViewBuilder
    private var ledgerSwitcherChip: some View {
        if let ledger = currentLedger, ledgers.count > 1 {
            Button {
                showsLedgerPicker = true
            } label: {
                HStack(spacing: NumiSpacing.s1) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 12, weight: .medium))
                    Text(ledger.localizedDisplayName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(NumiColor.accentDeep)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(NumiColor.accentPrimary.opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("button.ledgerSwitcher")
        }
    }

    private var ledgerPickerSheet: some View {
        NumiBottomSheet(
            title: NumiLocalized.string( "ledger.switch.title"),
            contentMode: .scroll,
            accessibilityPrefix: "sheet.ledgerPicker",
            dismissTitle: NumiLocalized.string( "common.close"),
            onDismiss: {
                showsLedgerPicker = false
            }
        ) {
            VStack(spacing: NumiSpacing.s2) {
                ForEach(ledgers) { ledger in
                    Button {
                        onSelectLedger(ledger)
                        showsLedgerPicker = false
                    } label: {
                        HStack(spacing: NumiSpacing.s3) {
                            ZStack {
                                Circle()
                                    .fill(ledger.id == currentLedger?.id ? NumiColor.accentPrimary.opacity(0.15) : NumiColor.surfaceCardSubtle)
                                    .frame(width: 36, height: 36)
                                Image(systemName: ledger.id == currentLedger?.id ? "book.fill" : "book")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(ledger.id == currentLedger?.id ? NumiColor.accentDeep : NumiColor.textTertiary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ledger.localizedDisplayName)
                                    .font(NumiFont.bodyStrong)
                                    .foregroundStyle(NumiColor.textPrimary)
                                Text(ledger.currencyCode)
                                    .font(NumiFont.footnote)
                                    .foregroundStyle(NumiColor.textTertiary)
                            }
                            Spacer()
                            if ledger.id == currentLedger?.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(NumiColor.accentDeep)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                        .padding(.horizontal, NumiSpacing.s4)
                        .background(
                            RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous)
                                .fill(ledger.id == currentLedger?.id ? NumiColor.surfaceCardSubtle : NumiColor.surfaceCard)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ledger.option.\(ledger.id.uuidString)")
                }
            }
            .padding(.horizontal, NumiSpacing.s4)
            .padding(.bottom, NumiSpacing.s4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sheet.ledgerPicker")
    }

    private var homePeriodPickerSheet: some View {
        NumiBottomSheet(
            title: NumiLocalized.string( "home.timeRange"),
            contentMode: .scroll,
            accessibilityPrefix: "sheet.homePeriodPicker",
            dismissTitle: NumiLocalized.string( "common.close"),
            onDismiss: {
                showsPeriodPicker = false
            }
        ) {
            VStack(spacing: NumiSpacing.s2) {
                ForEach(HomePeriod.allCases) { period in
                    Button {
                        onSelectPeriod(period)
                        showsPeriodPicker = false
                    } label: {
                        HStack(spacing: NumiSpacing.s3) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(periodTitle(for: period))
                                    .font(NumiFont.bodyStrong)
                                    .foregroundStyle(NumiColor.textPrimary)
                                Text(periodDescription(for: period))
                                    .font(NumiFont.footnote)
                                    .foregroundStyle(NumiColor.textTertiary)
                            }
                            Spacer()
                            if period == selectedPeriod {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(NumiColor.accentDeep)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                        .padding(.horizontal, NumiSpacing.s4)
                        .background(
                            RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous)
                                .fill(period == selectedPeriod ? NumiColor.surfaceCardSubtle : NumiColor.surfaceCard)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.period.option.\(periodOptionIdentifier(period))")
                }
            }
            .padding(.horizontal, NumiSpacing.s4)
            .padding(.bottom, NumiSpacing.s4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sheet.homePeriodPicker")
    }

    private func periodTitle(for period: HomePeriod) -> String {
        switch period {
        case .week:
            return NumiLocalized.string( "home.period.week")
        case .month:
            return NumiLocalized.string( "home.period.month")
        case .quarter:
            return NumiLocalized.string( "home.period.quarter")
        case .year:
            return NumiLocalized.string( "home.period.year")
        }
    }

    private func periodDescription(for period: HomePeriod) -> String {
        switch period {
        case .week:
            return NumiLocalized.string( "home.period.desc.week")
        case .month:
            return NumiLocalized.string( "home.period.desc.month")
        case .quarter:
            return NumiLocalized.string( "home.period.desc.quarter")
        case .year:
            return NumiLocalized.string( "home.period.desc.year")
        }
    }

    private func periodOptionIdentifier(_ period: HomePeriod) -> String {
        switch period {
        case .week:
            return "week"
        case .month:
            return "month"
        case .quarter:
            return "quarter"
        case .year:
            return "year"
        }
    }

    private func resolvedCategoryName(for row: TransactionHomeRow) -> String {
        RuntimeLocalizedDisplay.categoryName(
            for: row.transaction,
            categories: categories,
            fallbackCategoryName: row.fallbackCategoryName
        )
    }

    private func resolvedIconName(for row: TransactionHomeRow) -> String {
        RuntimeLocalizedDisplay.categoryIconName(
            for: row.transaction,
            categories: categories,
            fallbackCategoryIcon: row.fallbackIconName
        )
    }

    private func resolvedSubtitle(for row: TransactionHomeRow) -> String? {
        RuntimeLocalizedDisplay.transferSubtitle(
            for: row.transaction,
            accounts: accounts,
            fallbackSubtitle: row.fallbackSubtitle
        )
    }
}

private struct HomeToolbarChrome<Principal: View, Trailing: View>: ViewModifier {
    let periodToolbarControl: Principal
    let searchToolbarButton: Trailing

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    periodToolbarControl
                }
                ToolbarItem(placement: .topBarTrailing) {
                    searchToolbarButton
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        #else
        content
        #endif
    }
}

// MARK: - PressableRow

private struct PressableRow<Content: View>: View {
    let onSelect: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
    }
}
