import SwiftUI
import Foundation
import LocalAuthentication
import NumiCore
import NumiPersistence
import NumiAppUI
import NumiAppUI

struct RootShellView: View {
    @AppStorage("app.theme.id") private var themeID = NumiTheme.default.id
    @AppStorage("app.privacy.lockEnabled") private var isLockEnabled = false
    @AppStorage("app.privacy.autoBlur") private var isAutoBlurEnabled = false
    @AppStorage("app.currency.default") private var defaultCurrencyCode = "CNY"
    @StateObject private var rateService = ExchangeRateService.shared

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
    @State private var isLocked = false
    @State private var isBlurred = false
    @State private var backgroundTime: Date?
    @State private var lockTimer: Timer?
    @State private var aiRecordToast: String?
    @State private var showAIRecordToast = false
    @State private var insightsDimension: InsightsTimeDimension = .month
    @State private var insightsAnchorDate = Date()
    @State private var selectedCategoryRow: InsightsDistributionRow?
    @State private var selectedCategoryType: String = "expense"
    @State private var isBottomAccessoryHiddenByPage = false
    @State private var bottomAccessoryMeasuredHeight: CGFloat = 0
    @State private var bottomAccessoryHiddenProgress: CGFloat = 0
    @StateObject private var bottomAccessoryController = NumiBottomAccessoryController()

    init() {
        do {
            let store = try Self.makeStore()
            try store.seedDefaultsIfNeeded()
            try Self.seedDemoDataIfNeeded(store: store)
            _store = StateObject(wrappedValue: store)

            // 注入 CloudKit 同步闭包
            iCloudSyncService.shared.onPerformSync = {
                do {
                    let cloudStore = try SwiftDataBookkeepingStore(enableCloudSync: true)
                    _ = cloudStore.categories
                    _ = cloudStore.accounts
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    return true
                } catch {
                    return false
                }
            }
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
        }
        .environmentObject(bottomAccessoryController)
        .onReceive(bottomAccessoryController.$isHidden) { isHidden in
            isBottomAccessoryHiddenByPage = isHidden
        }
        .onAppear {
            bottomAccessoryHiddenProgress = bottomAccessoryShouldBeHidden ? 1 : 0
        }
        .onChange(of: isBottomAccessoryHiddenByPage) { _, _ in
            animateBottomAccessoryVisibility()
        }
        .onChange(of: showsBottomActionAccessory) { _, _ in
            animateBottomAccessoryVisibility()
        }
        .overlay {
            if isBlurred || isLocked {
                blurOverlay
                    .transition(.opacity)
                    .animation(.easeIn(duration: 0.3), value: isBlurred || isLocked)
            }
        }
        .tint(NumiColor.accentDeep)
        .task {
            await rateService.fetchRatesIfNeeded(base: defaultCurrencyCode)
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("NumiIncomingURL"))) { notification in
            if let url = notification.object as? URL {
                handleIncomingURL(url)
            }
        }
        .overlay {
            GeometryReader { proxy in
                bottomNavigationBar
                    .padding(.bottom, NumiSpacing.s2)
                    .offset(
                        y: bottomAccessoryHiddenProgress *
                            bottomAccessoryHiddenDistance(bottomSafeAreaInset: proxy.safeAreaInsets.bottom)
                    )
                    .allowsHitTesting(!bottomAccessoryShouldBeHidden && bottomAccessoryHiddenProgress < 0.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .overlay(alignment: .bottom) {
            if showAIRecordToast, let msg = aiRecordToast {
                Text(msg)
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, NumiSpacing.s4)
                    .padding(.vertical, 10)
                    .background(msg.contains("失败") ? Color.red.opacity(0.9) : Color.green.opacity(0.9))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 140)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showAIRecordToast)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            backgroundTime = Date()
            withAnimation(.easeIn(duration: 0.2)) {
                if isAutoBlurEnabled {
                    isBlurred = true
                }
            }
            // Start timer to check if we should lock after 2 minutes
            lockTimer?.invalidate()
            lockTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { _ in
                if isLockEnabled {
                    DispatchQueue.main.async {
                        withAnimation(.easeIn(duration: 0.3)) {
                            isLocked = true
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            lockTimer?.invalidate()
            lockTimer = nil

            let shouldLock: Bool
            if let backgroundTime {
                shouldLock = Date().timeIntervalSince(backgroundTime) >= 120
            } else {
                shouldLock = false
            }

            if isLockEnabled && shouldLock {
                isLocked = true
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    isBlurred = false
                }
            }
            backgroundTime = nil
        }
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
                alignHomeAnchorDate(to: occurredAt)
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
            transactionsRoot
        case .insights:
            insightsRoot
        case .plans:
            plansRoot
        case .settings:
            settingsRoot
        }
    }

    private var transactionsRoot: some View {
        let data = summaryAndSections()
        return NavigationStack {
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
            .numiBottomAccessoryNavigationDepth()
            .accessibilityHidden(isTransactionSearchPresented)
        }
    }

    private var insightsRoot: some View {
        let summary = insightsSummary()
        let distribution = insightsDistribution()
        let income = insightsIncomeDistribution()
        let periodTitle = insightsPeriodTitle

        return NavigationStack {
            InsightsView(
                summary: summary,
                distribution: distribution,
                incomeDistribution: income,
                periodTitle: periodTitle,
                onPreviousPeriod: { moveInsightsPeriod(-1) },
                onNextPeriod: { moveInsightsPeriod(1) },
                onTimeDimensionChange: { dim in
                    insightsDimension = dim
                    insightsAnchorDate = Date()
                },
                onSelectCategory: { row, type in
                    selectedCategoryRow = row
                    selectedCategoryType = type
                }
            )
            .numiBottomAccessoryNavigationDepth()
            .navigationDestination(isPresented: Binding(
                get: { selectedCategoryRow != nil },
                set: { if !$0 { selectedCategoryRow = nil } }
            )) {
                if let row = selectedCategoryRow {
                    let accentColor = selectedCategoryType == "expense" ? NumiColor.expenseText : NumiColor.incomeText
                    CategoryTransactionsDetailView(
                        categoryName: row.categoryName,
                        iconName: row.iconName,
                        transactions: categoryTransactions(for: row.categoryID),
                        categories: store.categories,
                        accentColor: accentColor,
                        periodTitle: insightsPeriodTitle
                    )
                }
            }
        }
    }

    private var plansRoot: some View {
        NavigationStack {
            PlansView(
                budgets: budgetCards(),
                subscriptions: store.subscriptions,
                installmentPlans: store.installmentPlans,
                installmentPeriods: store.installmentPeriods,
                categories: store.categories,
                accounts: store.accounts,
                onSaveBudget: { period, amount, isEnabled in
                    do {
                        try store.upsertBudgetSetting(period: period, amount: amount, isEnabled: isEnabled)
                    } catch {
                        initializationError = error.localizedDescription
                    }
                },
                onAddSubscription: { sub in
                    do {
                        try store.createSubscription(sub)
                    } catch {
                        initializationError = error.localizedDescription
                    }
                },
                onUpdateSubscription: { sub in
                    do {
                        try store.updateSubscription(sub)
                    } catch {
                        initializationError = error.localizedDescription
                    }
                },
                onDeleteSubscription: { id in
                    do {
                        try store.deleteSubscription(id: id)
                    } catch {
                        initializationError = error.localizedDescription
                    }
                },
                onAddInstallmentPlan: { plan in
                    do {
                        try store.createInstallmentPlan(plan)
                    } catch {
                        initializationError = error.localizedDescription
                    }
                },
                onUpdateInstallmentPlan: { plan in
                    do {
                        try store.deleteInstallmentPlan(id: plan.id)
                        try store.createInstallmentPlan(plan)
                    } catch {
                        initializationError = error.localizedDescription
                    }
                },
                onDeleteInstallmentPlan: { id in
                    do {
                        try store.deleteInstallmentPlan(id: id)
                    } catch {
                        initializationError = error.localizedDescription
                    }
                }
            )
            .numiBottomAccessoryNavigationDepth()
        }
    }

    private var settingsRoot: some View {
        NavigationStack {
            SettingsView(
                categories: store.categories,
                accounts: store.accounts,
                transactions: store.visibleTransactions,
                exportSnapshot: { store.exportSnapshot() },
                importSnapshot: { snapshot in try store.importSnapshot(snapshot) },
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
                },
                onCategoryCreate: { kind, name, icon in
                    do {
                        try store.createCategory(kind: kind, name: name, icon: icon)
                    } catch {
                        initializationError = error.localizedDescription
                    }
                },
                onCategoryDelete: { category in
                    do {
                        try store.deleteCategory(id: category.id)
                    } catch {
                        initializationError = error.localizedDescription
                    }
                },
                onAccountDelete: { account in
                    do {
                        try store.deleteAccount(id: account.id)
                    } catch {
                        initializationError = error.localizedDescription
                    }
                }
            )
            .numiBottomAccessoryNavigationDepth()
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

                // 计算当日支出和收入
                var expenseMinor: Int64 = 0
                var incomeMinor: Int64 = 0
                for row in rows {
                    switch row.transaction.type {
                    case .expense: expenseMinor += row.transaction.amount.minorUnits
                    case .income: incomeMinor += row.transaction.amount.minorUnits
                    case .transfer: break
                    }
                }
                let currencyCode = rows.first?.transaction.amount.currencyCode ?? "CNY"
                let dailyExpense = expenseMinor > 0 ? Money(minorUnits: expenseMinor, currencyCode: currencyCode) : nil
                let dailyIncome = incomeMinor > 0 ? Money(minorUnits: incomeMinor, currencyCode: currencyCode) : nil

                return TransactionHomeSection(
                    id: homeSectionAccessibilityIdentifier(for: date, fallback: key),
                    title: homeSectionTitle(for: date),
                    rows: sortedRows,
                    dailyExpense: dailyExpense,
                    dailyIncome: dailyIncome
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

    // MARK: - Insights Data

    private var insightsFilteredTransactions: [NumiCore.Transaction] {
        let interval = insightsDateInterval
        return store.visibleTransactions.filter { interval.contains($0.occurredAt) }
    }

    private var insightsDateInterval: DateInterval {
        let cal = calendar
        switch insightsDimension {
        case .day:
            return DateInterval(start: cal.startOfDay(for: insightsAnchorDate), duration: 86400)
        case .week:
            return cal.dateInterval(of: .weekOfYear, for: insightsAnchorDate) ?? DateInterval(start: insightsAnchorDate, duration: 86400)
        case .month:
            return cal.dateInterval(of: .month, for: insightsAnchorDate) ?? DateInterval(start: insightsAnchorDate, duration: 86400)
        case .quarter:
            let month = cal.component(.month, from: insightsAnchorDate)
            let startMonth = ((month - 1) / 3) * 3 + 1
            var components = cal.dateComponents([.year], from: insightsAnchorDate)
            components.month = startMonth
            components.day = 1
            let start = cal.date(from: components) ?? cal.startOfDay(for: insightsAnchorDate)
            let end = cal.date(byAdding: .month, value: 3, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .year:
            return cal.dateInterval(of: .year, for: insightsAnchorDate) ?? DateInterval(start: insightsAnchorDate, duration: 86400)
        }
    }

    private var insightsPeriodTitle: String {
        let interval = insightsDateInterval
        let start = interval.start
        switch insightsDimension {
        case .day:
            return monthDayWeekdayFormatter.string(from: start)
        case .week:
            let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
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

    private func moveInsightsPeriod(_ offset: Int) {
        switch insightsDimension {
        case .day:
            insightsAnchorDate = calendar.date(byAdding: .day, value: offset, to: insightsAnchorDate) ?? insightsAnchorDate
        case .week:
            insightsAnchorDate = calendar.date(byAdding: .weekOfYear, value: offset, to: insightsAnchorDate) ?? insightsAnchorDate
        case .month:
            insightsAnchorDate = calendar.date(byAdding: .month, value: offset, to: insightsAnchorDate) ?? insightsAnchorDate
        case .quarter:
            insightsAnchorDate = calendar.date(byAdding: .month, value: offset * 3, to: insightsAnchorDate) ?? insightsAnchorDate
        case .year:
            insightsAnchorDate = calendar.date(byAdding: .year, value: offset, to: insightsAnchorDate) ?? insightsAnchorDate
        }
    }

    private func categoryTransactions(for categoryID: UUID) -> [NumiCore.Transaction] {
        insightsFilteredTransactions
            .filter { $0.categoryID == categoryID }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    private func insightsSummary() -> TransactionSummary {
        let txs = insightsFilteredTransactions
        return (try? TransactionSummary.monthly(transactions: txs, currencyCode: "CNY"))
            ?? TransactionSummary(expense: .zero(currencyCode: "CNY"), income: .zero(currencyCode: "CNY"), balance: .zero(currencyCode: "CNY"), recordCount: 0)
    }

    private func insightsDistribution() -> [InsightsDistributionRow] {
        let txs = insightsFilteredTransactions
        let items = (try? CategoryDistribution.expense(transactions: txs, currencyCode: "CNY")) ?? []
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

    private func insightsIncomeDistribution() -> [InsightsDistributionRow] {
        let txs = insightsFilteredTransactions
        let items = (try? CategoryDistribution.income(transactions: txs, currencyCode: "CNY")) ?? []
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

    private func alignHomeAnchorDate(to occurredAt: Date) {
        homeAnchorDate = dateInterval(for: selectedHomePeriod, anchorDate: occurredAt).start
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
        CurrencyDefinition.common.map {
            NumiCurrencyOption(code: $0.code, title: $0.name, symbol: $0.symbol)
        }
    }

    // MARK: - URL Scheme 处理

    /// numi://record?text=午饭35块
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "numi", url.host == "record" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let text = components?.queryItems?.first(where: { $0.name == "text" })?.value, !text.isEmpty else {
            showToast("缺少 text 参数")
            return
        }

        Task {
            await performAIRecord(text: text)
        }
    }

    private func performAIRecord(text: String) async {
        let defaults = UserDefaults.standard
        let provider = defaults.string(forKey: "app.ai.provider") ?? "claude"
        let claudeKey = defaults.string(forKey: "app.ai.claudeAPIKey") ?? ""
        let qwenKey = defaults.string(forKey: "app.ai.qwenAPIKey") ?? ""
        let dsKey = defaults.string(forKey: "app.ai.deepseekAPIKey") ?? ""

        // 选择 parser
        let parser: TransactionLLMService
        switch provider {
        case "qwen" where !qwenKey.isEmpty:
            parser = QwenTransactionParser(apiKey: qwenKey)
        case "deepseek" where !dsKey.isEmpty:
            parser = DeepSeekTransactionParser(apiKey: dsKey)
        case "claude" where !claudeKey.isEmpty:
            parser = ClaudeTransactionParser(apiKey: claudeKey)
        default:
            // 尝试任意可用 key
            if !dsKey.isEmpty {
                parser = DeepSeekTransactionParser(apiKey: dsKey)
            } else if !claudeKey.isEmpty {
                parser = ClaudeTransactionParser(apiKey: claudeKey)
            } else if !qwenKey.isEmpty {
                parser = QwenTransactionParser(apiKey: qwenKey)
            } else {
                showToast("请先在设置中配置 AI 服务密钥")
                return
            }
        }

        let categories = store.categories.map(\.name)

        do {
            let parsed = try await parser.parseTransaction(text, categories: categories)

            guard let category = store.categories.first(where: { $0.name == parsed.categoryName }),
                  let account = store.accounts.first else {
                showToast("分类或账户匹配失败")
                return
            }

            let money = try Money(decimalString: "\(parsed.amount)", currencyCode: "CNY")
            _ = try store.createTransaction(
                type: parsed.type,
                amount: money,
                categoryID: category.id,
                accountID: account.id,
                note: parsed.note
            )

            let symbol = parsed.type == .income ? "+" : "-"
            showToast("已记录 \(parsed.categoryName) \(symbol)¥\(parsed.amount)")
        } catch {
            showToast("记账失败：\(error.localizedDescription)")
        }
    }

    private func showToast(_ message: String) {
        aiRecordToast = message
        withAnimation { showAIRecordToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showAIRecordToast = false }
        }
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
        let cloudSync = UserDefaults.standard.bool(forKey: "app.sync.icloudEnabled")
        return try SwiftDataBookkeepingStore(enableCloudSync: cloudSync)
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

    private var showsBottomActionAccessory: Bool {
        !isAddingRecord && !isTransactionSearchPresented
    }

    private var bottomAccessoryShouldBeHidden: Bool {
        isBottomAccessoryHiddenByPage || !showsBottomActionAccessory
    }

    private var bottomNavigationBar: some View {
        NumiBottomNavigationBar(
            items: Tab.allCases.map {
                NumiBottomNavigationBar.Item(
                    id: $0.rawValue,
                    title: $0.rawValue,
                    systemImage: $0.systemImage
                )
            },
            selectedID: selectedTab.rawValue,
            onSelect: { selectedID in
                guard let tab = Tab(rawValue: selectedID) else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTab = tab
                }
            },
            trailingActionTitle: "新建账单",
            trailingActionSystemImage: "pencil",
            trailingAction: {
                isAddingRecord = true
            }
        )
        .background(.clear)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        bottomAccessoryMeasuredHeight = proxy.size.height
                    }
                    .onChange(of: proxy.size.height) { _, newValue in
                        bottomAccessoryMeasuredHeight = newValue
                    }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func bottomAccessoryHiddenDistance(bottomSafeAreaInset: CGFloat) -> CGFloat {
        let measuredHeight = max(bottomAccessoryMeasuredHeight, NumiChromeMetrics.bottomAccessoryMinimumHeight)
        return measuredHeight + bottomSafeAreaInset + NumiChromeMetrics.bottomAccessoryHiddenAdditionalTravel
    }

    private func animateBottomAccessoryVisibility() {
        withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.84, blendDuration: 0.14)) {
            bottomAccessoryHiddenProgress = bottomAccessoryShouldBeHidden ? 1 : 0
        }
    }

}

private extension RootShellView {
    var blurOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            if isLocked {
                NumiLockScreen(isLocked: Binding(
                    get: { isLocked },
                    set: { newValue in
                        withAnimation(.easeOut(duration: 0.4)) {
                            isLocked = newValue
                            if !newValue {
                                isBlurred = false
                            }
                        }
                    }
                ))
            } else {
                VStack(spacing: NumiSpacing.s4) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(NumiColor.textSecondary)

                    Text("应用已模糊")
                        .font(NumiFont.bodyStrong)
                        .foregroundStyle(NumiColor.textPrimary)
                }
            }
        }
    }

    func authenticateUser(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "验证身份以解锁应用"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "验证身份以解锁应用"
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }
}

private struct ShareSheetPayload: Identifiable {
    let id = UUID()
    let text: String
}
