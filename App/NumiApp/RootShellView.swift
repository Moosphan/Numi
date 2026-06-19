import SwiftUI
import Foundation
import NumiCore
import NumiPersistence
import NumiAppUI

struct RootShellView: View {
    @AppStorage("app.theme.id") private var themeID = NumiTheme.defaultTheme.id

    enum Tab: String, CaseIterable {
        case transactions = "明细"
        case insights = "洞悉"
        case plans = "计划"
        case settings = "我的"

        var systemImage: String {
            switch self {
            case .transactions: "list.bullet.rectangle"
            case .insights: "chart.bar"
            case .plans: "calendar.badge.clock"
            case .settings: "person.crop.circle"
            }
        }
    }

    @State private var selectedTab: Tab = .transactions
    @State private var isAddingRecord = false
    @StateObject private var store: SwiftDataBookkeepingStore
    @State private var initializationError: String?
    @State private var lastDeletedTransactionID: UUID?
    @State private var selectedTransactionID: UUID?
    @State private var editingTransactionID: UUID?
    @State private var isTransactionSearchPresented = false
    @State private var shareSheetPayload: ShareSheetPayload?
    @State private var selectedHomePeriod: HomePeriod = .month
    @State private var homeAnchorDate = Date()

    init() {
        do {
            let store = try Self.makeStore()
            try store.seedDefaultsIfNeeded()
            try Self.seedDemoDataIfNeeded(store: store)
            _store = StateObject(wrappedValue: store)
        } catch {
            initializationError = error.localizedDescription
            _store = StateObject(wrappedValue: Self.makeFallbackStore())
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if let initializationError {
                VStack(spacing: NumiSpacing.s3) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(NumiColor.negativeText)
                    Text("本地数据初始化失败")
                        .font(NumiFont.bodyStrong)
                        .foregroundStyle(NumiColor.textPrimary)
                    Text(initializationError)
                        .font(NumiFont.bodySmall)
                        .foregroundStyle(NumiColor.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(NumiSpacing.s6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(NumiColor.surfacePage)
            } else {
                currentPage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if !isAddingRecord && !isTransactionSearchPresented {
                VStack(spacing: 0) {
                    Spacer()
                    ZStack(alignment: .leading) {
                        // Sliding indicator
                        Capsule()
                            .fill(NumiColor.accentPrimary.opacity(0.14))
                            .frame(
                                width: NumiChromeMetrics.tabBarSelectionWidth,
                                height: NumiChromeMetrics.tabBarSelectionHeight
                            )
                            .offset(x: indicatorOffset)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)

                        HStack(spacing: 0) {
                            ForEach(Tab.allCases, id: \.self) { tab in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedTab = tab
                                    }
                                } label: {
                                    VStack(spacing: NumiChromeMetrics.tabBarLabelSpacing) {
                                        Image(systemName: tab.systemImage)
                                            .font(.system(size: NumiChromeMetrics.tabBarSymbolSize, weight: .medium))
                                        Text(tab.rawValue)
                                            .font(.system(size: 11, weight: selectedTab == tab ? .medium : .regular))
                                    }
                                    .foregroundStyle(selectedTab == tab ? NumiColor.textPrimary : NumiColor.textTertiary)
                                    .frame(maxWidth: .infinity, minHeight: NumiChromeMetrics.tabBarItemMinHeight)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("tab.\(tab.rawValue)")
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, NumiChromeMetrics.tabBarTopPadding)
                    .padding(.bottom, NumiChromeMetrics.tabBarBottomPadding)
                    .background(.ultraThinMaterial)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .tint(NumiColor.accentDeep)
        .sheet(isPresented: $isAddingRecord, onDismiss: {
            isAddingRecord = false
        }) {
            AddRecordFlowView(
                categories: store.categories,
                accounts: store.accounts,
                currencyOptions: currencyOptions
            ) { type, money, category, account, targetAccount, occurredAt, note in
                guard let accountID = account?.id ?? store.accounts.first?.id else { return }
                let targetAccountID = type == .transfer ? targetAccount?.id : nil
                _ = try? store.createTransaction(
                    type: type,
                    amount: money,
                    categoryID: type == .transfer ? nil : category?.id,
                    accountID: accountID,
                    targetAccountID: targetAccountID,
                    note: note,
                    occurredAt: occurredAt
                )
            }
            .accessibilityIdentifier("sheet.addRecord")
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sheet(item: selectedTransactionBinding) { transaction in
            let category = category(for: transaction)
            RecordDetailView(
                transaction: transaction,
                categoryName: category.name,
                iconName: category.icon,
                accountName: accountName(for: transaction),
                targetAccountName: targetAccountName(for: transaction),
                onClose: {
                    selectedTransactionID = nil
                },
                onEdit: {
                    let transactionID = transaction.id
                    selectedTransactionID = nil
                    DispatchQueue.main.async {
                        editingTransactionID = transactionID
                    }
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: editingTransactionBinding) { transaction in
            EditRecordView(transaction: transaction, categories: store.categories, accounts: store.accounts) { type, money, category, account, targetAccount, occurredAt, note in
                guard let accountID = account?.id ?? transaction.accountID ?? store.accounts.first?.id else { return }
                let targetAccountID = type == .transfer ? (targetAccount?.id ?? transaction.targetAccountID) : nil
                do {
                    try store.updateTransaction(
                        id: transaction.id,
                        type: type,
                        amount: money,
                        categoryID: type == .transfer ? nil : category?.id,
                        accountID: accountID,
                        targetAccountID: targetAccountID,
                        note: note,
                        occurredAt: occurredAt
                    )
                    editingTransactionID = nil
                    selectedTransactionID = nil
                } catch {
                    initializationError = error.localizedDescription
                }
            }
            .presentationDetents([.large])
        }
        .sheet(item: $shareSheetPayload) { payload in
            NumiShareSheet(items: [payload.text])
        }
        .fullScreenCover(isPresented: $isTransactionSearchPresented) {
            NavigationStack {
                TransactionSearchView(rows: searchRows()) { transaction in
                    isTransactionSearchPresented = false
                    selectedTransactionID = transaction.id
                }
            }
        }
    }

    @ViewBuilder
    private var currentPage: some View {
        switch selectedTab {
        case .transactions:
            let data = summaryAndSections()
            NavigationStack {
                TransactionsHomeView(
                    summary: data.summary,
                    periodTitle: homePeriodTitle,
                    selectedPeriod: selectedHomePeriod,
                    isNextPeriodEnabled: canMoveHomePeriodForward,
                    sections: data.sections,
                    onPreviousPeriod: moveHomePeriodBackward,
                    onNextPeriod: moveHomePeriodForward,
                    onSelectPeriod: { period in
                        selectedHomePeriod = period
                    },
                    onSearch: {
                        isTransactionSearchPresented = true
                    },
                    onSelect: { transaction in
                        selectedTransactionID = transaction.id
                    },
                    onPrimaryAction: {
                        isAddingRecord = true
                    },
                    onEdit: { transaction in
                        editingTransactionID = transaction.id
                    },
                    onShare: { transaction in
                        shareSheetPayload = ShareSheetPayload(text: shareText(for: transaction))
                    },
                    onDelete: { transaction in
                        do {
                            try store.softDeleteTransaction(id: transaction.id)
                            lastDeletedTransactionID = transaction.id
                        } catch {
                            initializationError = error.localizedDescription
                        }
                    },
                    onUndoDelete: {
                        guard let transactionID = lastDeletedTransactionID else { return }
                        do {
                            try store.restoreTransaction(id: transactionID)
                            lastDeletedTransactionID = nil
                        } catch {
                            initializationError = error.localizedDescription
                        }
                    }
                )
                .accessibilityHidden(isTransactionSearchPresented)
                .overlay(alignment: .bottomTrailing) {
                    if !isTransactionSearchPresented {
                        NumiFloatingActionButton {
                            isAddingRecord = true
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 92)
                        .accessibilityIdentifier("button.addRecord")
                    }
                }
            }
        case .insights:
            let summary = summary()
            let distribution = insightDistribution()
            NavigationStack {
                InsightsView(summary: summary, distribution: distribution)
            }
        case .plans:
            NavigationStack {
                PlansView(
                    budgets: budgetCards(),
                    onSaveBudget: { period, amount, isEnabled in
                        do {
                            try store.upsertBudgetSetting(period: period, amount: amount, isEnabled: isEnabled)
                        } catch {
                            initializationError = error.localizedDescription
                        }
                    }
                )
            }
        case .settings:
            NavigationStack {
                SettingsView(
                    categories: store.categories,
                    accounts: store.accounts,
                    onCategoryVisibilityChange: { category, isHidden in
                        do {
                            try store.updateCategoryVisibility(id: category.id, isHidden: isHidden)
                        } catch {
                            initializationError = error.localizedDescription
                        }
                    },
                    onAccountVisibilityChange: { account, isHidden in
                        do {
                            try store.updateAccountVisibility(id: account.id, isHidden: isHidden)
                        } catch {
                            initializationError = error.localizedDescription
                        }
                    },
                    onAccountCreate: { draft in
                        do {
                            guard let balance = try? Money(decimalString: draft.balanceText, currencyCode: draft.currencyCode) else { return }
                            try store.createAccount(
                                name: draft.name,
                                type: draft.type,
                                balance: balance,
                                isIncludedInAssets: draft.isIncludedInAssets,
                                isHidden: draft.isHidden
                            )
                        } catch {
                            initializationError = error.localizedDescription
                        }
                    },
                    onAccountUpdate: { account, draft in
                        do {
                            guard let balance = try? Money(decimalString: draft.balanceText, currencyCode: draft.currencyCode) else { return }
                            try store.updateAccount(
                                id: account.id,
                                name: draft.name,
                                type: draft.type,
                                balance: balance,
                                isIncludedInAssets: draft.isIncludedInAssets,
                                isHidden: draft.isHidden
                            )
                        } catch {
                            initializationError = error.localizedDescription
                        }
                    }
                )
            }
        }
    }

    private func summary() -> TransactionSummary {
        (try? TransactionSummary.monthly(transactions: store.visibleTransactions, currencyCode: "CNY"))
            ?? TransactionSummary(
                expense: .zero(currencyCode: "CNY"),
                income: .zero(currencyCode: "CNY"),
                balance: .zero(currencyCode: "CNY"),
                recordCount: 0
            )
    }

    private func summaryAndSections() -> (summary: TransactionSummary, sections: [TransactionHomeSection]) {
        let transactions = filteredHomeTransactions
        let rows = transactions.map { transaction in
            let category = store.categories.first { $0.id == transaction.categoryID }
            return TransactionHomeRow(
                transaction: transaction,
                categoryName: displayName(for: transaction, categoryName: category?.name),
                iconName: displayIcon(for: transaction, categoryIcon: category?.icon),
                subtitle: transferSubtitle(for: transaction)
            )
        }

        let grouped = Dictionary(grouping: rows) {
            homeSectionDayKeyFormatter.string(from: $0.transaction.occurredAt)
        }

        let sections = grouped
            .compactMap { key, rows -> TransactionHomeSection? in
                guard let date = homeSectionDayKeyFormatter.date(from: key) else { return nil }
                let sortedRows = rows.sorted { $0.transaction.occurredAt > $1.transaction.occurredAt }
                return TransactionHomeSection(
                    id: homeSectionAccessibilityIdentifier(for: date, fallback: key),
                    title: homeSectionTitle(for: date),
                    rows: sortedRows
                )
            }
            .sorted { $0.rows.first?.transaction.occurredAt ?? .distantPast > $1.rows.first?.transaction.occurredAt ?? .distantPast }

        return (summary(for: transactions), sections: sections)
    }

    private func searchRows() -> [TransactionSearchRow] {
        store.visibleTransactions
            .sorted { $0.occurredAt > $1.occurredAt }
            .map { transaction in
                let category = store.categories.first { $0.id == transaction.categoryID }
                return TransactionSearchRow(
                    transaction: transaction,
                    categoryName: displayName(for: transaction, categoryName: category?.name),
                    iconName: displayIcon(for: transaction, categoryIcon: category?.icon),
                    subtitle: transferSubtitle(for: transaction)
                )
            }
    }

    private func insightDistribution() -> [InsightsDistributionRow] {
        let items = (try? CategoryDistribution.expense(transactions: store.visibleTransactions, currencyCode: "CNY")) ?? []
        return items.map { item in
            let category = store.categories.first { $0.id == item.categoryID }
            return InsightsDistributionRow(
                categoryID: item.categoryID,
                categoryName: category?.name ?? "其他",
                iconName: category?.icon ?? "ellipsis.circle",
                amount: item.amount,
                percentage: item.percentage
            )
        }
    }

    private var selectedTransactionBinding: Binding<NumiCore.Transaction?> {
        Binding(
            get: { transaction(id: selectedTransactionID) },
            set: { value in selectedTransactionID = value?.id }
        )
    }

    private var editingTransactionBinding: Binding<NumiCore.Transaction?> {
        Binding(
            get: { transaction(id: editingTransactionID) },
            set: { value in editingTransactionID = value?.id }
        )
    }

    private func transaction(id: UUID?) -> NumiCore.Transaction? {
        guard let id else { return nil }
        return store.visibleTransactions.first { $0.id == id }
    }

    private func category(for transaction: NumiCore.Transaction) -> (name: String, icon: String) {
        let category = store.categories.first { $0.id == transaction.categoryID }
        return (
            displayName(for: transaction, categoryName: category?.name),
            displayIcon(for: transaction, categoryIcon: category?.icon)
        )
    }

    private func accountName(for transaction: NumiCore.Transaction) -> String {
        guard let accountID = transaction.accountID else { return "未选择" }
        return store.accounts.first { $0.id == accountID }?.name ?? "未选择"
    }

    private func targetAccountName(for transaction: NumiCore.Transaction) -> String? {
        guard let targetAccountID = transaction.targetAccountID else { return nil }
        return store.accounts.first { $0.id == targetAccountID }?.name ?? "未选择"
    }

    private func shareText(for transaction: NumiCore.Transaction) -> String {
        let category = category(for: transaction)
        let amount = transaction.amount.formatted()
        let date = NumiDatePickerRow.displayText(for: transaction.occurredAt)
        let account = accountName(for: transaction)
        let transfer = transaction.type == .transfer ? " -> \(targetAccountName(for: transaction) ?? "未选择")" : ""
        let note = transaction.note.isEmpty ? "" : "\n备注：\(transaction.note)"
        return """
        \(category.name) \(amount)
        时间：\(date)
        账户：\(account)\(transfer)\(note)
        """
    }

    private func displayName(for transaction: NumiCore.Transaction, categoryName: String?) -> String {
        transaction.type == .transfer ? "转账" : (categoryName ?? "其他")
    }

    private func displayIcon(for transaction: NumiCore.Transaction, categoryIcon: String?) -> String {
        transaction.type == .transfer ? "arrow.left.arrow.right.circle" : (categoryIcon ?? "ellipsis.circle")
    }

    private func transferSubtitle(for transaction: NumiCore.Transaction) -> String? {
        guard transaction.type == .transfer else { return nil }
        return "\(accountName(for: transaction)) -> \(targetAccountName(for: transaction) ?? "未选择")"
    }

    private func budgetCards(today: Date = Date(), calendar: Calendar = Calendar.current) -> [BudgetCardModel] {
        let settings = store.budgetSettings
        return [BudgetPeriod.week, .month].map { period in
            let setting = settings.first { $0.period == period }
            let amount = setting?.amount ?? defaultBudgetAmount(for: period)
            let range = budgetDateRange(for: period, today: today, calendar: calendar)
            let spent = spentAmount(from: range.start, to: range.end)
            let limit = BudgetLimit(amount: amount, period: period, startsOn: range.start, endsOn: range.end)
            let status = (try? BudgetCalculator.status(for: limit, spent: spent, today: today, calendar: calendar))
                ?? BudgetStatus(remaining: amount, dailySuggestion: amount, isOverBudget: false)

            return BudgetCardModel(
                period: period,
                amount: amount,
                spent: spent,
                status: status,
                isEnabled: setting?.isEnabled ?? true
            )
        }
    }

    private func defaultBudgetAmount(for period: BudgetPeriod) -> Money {
        switch period {
        case .week:
            Money(minorUnits: 80_000, currencyCode: "CNY")
        case .month:
            Money(minorUnits: 300_000, currencyCode: "CNY")
        }
    }

    private func budgetDateRange(
        for period: BudgetPeriod,
        today: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let component: Calendar.Component = period == .week ? .weekOfYear : .month
        guard let interval = calendar.dateInterval(of: component, for: today) else {
            return (calendar.startOfDay(for: today), today)
        }
        let end = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
        return (interval.start, end)
    }

    private func spentAmount(from start: Date, to end: Date) -> Money {
        store.visibleTransactions
            .filter { transaction in
                transaction.type == .expense
                    && transaction.occurredAt >= start
                    && transaction.occurredAt <= end
            }
            .reduce(Money.zero(currencyCode: "CNY")) { partial, transaction in
                (try? partial.adding(transaction.amount)) ?? partial
            }
    }

    private var filteredHomeTransactions: [NumiCore.Transaction] {
        let interval = homeDateInterval
        return store.visibleTransactions.filter { transaction in
            interval.contains(transaction.occurredAt)
        }
    }

    private var homeDateInterval: DateInterval {
        dateInterval(for: selectedHomePeriod, anchorDate: homeAnchorDate)
    }

    private var homePeriodTitle: String {
        let interval = homeDateInterval
        let start = interval.start
        let end = interval.end.addingTimeInterval(-1)

        switch selectedHomePeriod {
        case .week:
            return "\(monthDayFormatter.string(from: start)) - \(monthDayFormatter.string(from: end))"
        case .month:
            return yearMonthFormatter.string(from: start)
        case .quarter:
            let quarter = ((calendar.component(.month, from: start) - 1) / 3) + 1
            let year = calendar.component(.year, from: start)
            return "\(year)年第\(quarter)季度"
        case .year:
            return "\(calendar.component(.year, from: start))年"
        }
    }

    private var canMoveHomePeriodForward: Bool {
        let now = Date()
        let nextInterval = dateInterval(for: selectedHomePeriod, anchorDate: nextAnchorDate(from: homeAnchorDate))
        return nextInterval.start <= now
    }

    private func moveHomePeriodBackward() {
        homeAnchorDate = previousAnchorDate(from: homeAnchorDate)
    }

    private func moveHomePeriodForward() {
        guard canMoveHomePeriodForward else { return }
        homeAnchorDate = nextAnchorDate(from: homeAnchorDate)
    }

    private func previousAnchorDate(from date: Date) -> Date {
        switch selectedHomePeriod {
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: -1, to: date) ?? date
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: date) ?? date
        case .quarter:
            return calendar.date(byAdding: .month, value: -3, to: date) ?? date
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: date) ?? date
        }
    }

    private func nextAnchorDate(from date: Date) -> Date {
        switch selectedHomePeriod {
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .month:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarter:
            return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .year:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }

    private func dateInterval(for period: HomePeriod, anchorDate: Date) -> DateInterval {
        switch period {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: anchorDate)
                ?? fallbackInterval(for: anchorDate)
        case .month:
            return calendar.dateInterval(of: .month, for: anchorDate)
                ?? fallbackInterval(for: anchorDate)
        case .quarter:
            let month = calendar.component(.month, from: anchorDate)
            let startMonth = ((month - 1) / 3) * 3 + 1
            var components = calendar.dateComponents([.year], from: anchorDate)
            components.month = startMonth
            components.day = 1
            let start = calendar.date(from: components) ?? calendar.startOfDay(for: anchorDate)
            let end = calendar.date(byAdding: .month, value: 3, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .year:
            return calendar.dateInterval(of: .year, for: anchorDate)
                ?? fallbackInterval(for: anchorDate)
        }
    }

    private func fallbackInterval(for date: Date) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private func summary(for transactions: [NumiCore.Transaction]) -> TransactionSummary {
        (try? TransactionSummary.monthly(transactions: transactions, currencyCode: "CNY"))
            ?? TransactionSummary(
                expense: .zero(currencyCode: "CNY"),
                income: .zero(currencyCode: "CNY"),
                balance: .zero(currencyCode: "CNY"),
                recordCount: 0
            )
    }

    private func homeSectionTitle(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "今天"
        }
        if calendar.isDateInYesterday(date) {
            return "昨天"
        }
        if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            return monthDayWeekdayFormatter.string(from: date)
        }
        return yearMonthDayFormatter.string(from: date)
    }

    private func homeSectionAccessibilityIdentifier(for date: Date, fallback: String) -> String {
        if calendar.isDateInToday(date) {
            return "today"
        }
        if calendar.isDateInYesterday(date) {
            return "yesterday"
        }
        return fallback
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        return calendar
    }

    private var yearMonthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }

    private var monthDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = calendar
        formatter.dateFormat = "M月d日"
        return formatter
    }

    private var monthDayWeekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = calendar
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }

    private var yearMonthDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }

    private var homeSectionDayKeyFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private var currencyOptions: [NumiCurrencyOption] {
        [
            NumiCurrencyOption(code: "CNY", title: "人民币", symbol: "¥"),
            NumiCurrencyOption(code: "USD", title: "美元", symbol: "$"),
            NumiCurrencyOption(code: "HKD", title: "港币", symbol: "HK$"),
            NumiCurrencyOption(code: "JPY", title: "日元", symbol: "¥"),
            NumiCurrencyOption(code: "EUR", title: "欧元", symbol: "€")
        ]
    }

    private static func makeStore() throws -> SwiftDataBookkeepingStore {
        let environment = ProcessInfo.processInfo.environment
        if let storeID = environment["NUMI_UI_TEST_STORE_ID"], !storeID.isEmpty {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("NumiUITests", isDirectory: true)
                .appendingPathComponent(storeID, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return try SwiftDataBookkeepingStore(storeURL: directory.appendingPathComponent("Numi.store"))
        }
        if let storeID = environment["NUMI_DEV_STORE_ID"], !storeID.isEmpty {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("NumiDevStores", isDirectory: true)
                .appendingPathComponent(storeID, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return try SwiftDataBookkeepingStore(storeURL: directory.appendingPathComponent("Numi.store"))
        }
        return try SwiftDataBookkeepingStore()
    }

    private static func makeFallbackStore() -> SwiftDataBookkeepingStore {
        do {
            let store = try SwiftDataBookkeepingStore(inMemory: true)
            try store.seedDefaultsIfNeeded()
            try seedDemoDataIfNeeded(store: store)
            return store
        } catch {
            fatalError("Unable to create in-memory fallback store: \(error)")
        }
    }

    private static func seedDemoDataIfNeeded(store: SwiftDataBookkeepingStore) throws {
        let environment = ProcessInfo.processInfo.environment
        guard let profile = DemoDataSeeder.profile(from: environment) else { return }
        try DemoDataSeeder.seed(
            profile: profile,
            into: store,
            resetBeforeSeeding: DemoDataSeeder.shouldReset(from: environment)
        )
    }

    private var indicatorOffset: CGFloat {
        let index = CGFloat(Tab.allCases.firstIndex(of: selectedTab) ?? 0)
        let tabWidth = (UIScreen.main.bounds.width - 28) / CGFloat(Tab.allCases.count)
        let centerOffset = (tabWidth - NumiChromeMetrics.tabBarSelectionWidth) / 2
        return index * tabWidth + centerOffset
    }
}

private struct ShareSheetPayload: Identifiable {
    let id = UUID()
    let text: String
}
