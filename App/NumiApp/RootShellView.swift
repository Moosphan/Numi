import SwiftUI
import Foundation
import LocalAuthentication
import NumiCore
import NumiPersistence
import NumiAppUI
import NumiAppUI

struct RootShellView: View {
    private struct CurrencySummaryResult {
        let summary: TransactionSummary
        let hasUnavailableHistoricalRate: Bool
    }

    private struct InsightsTrendResult {
        let points: [CashflowTrendPoint]
        let hasUnavailableHistoricalRate: Bool
    }

    @AppStorage("app.theme.id") private var themeID = NumiTheme.default.id
    @AppStorage("app.privacy.lockEnabled") private var isLockEnabled = false
    @AppStorage("app.privacy.autoBlur") private var isAutoBlurEnabled = false
    @AppStorage("app.privacy.hideAmounts") private var isAmountDisplayHidden = false
    @AppStorage("app.subscription.requiresConfirmation") private var requiresSubscriptionConfirmation = false
    @AppStorage("app.installment.reminder.daysBefore") private var installmentReminderDaysBefore = 1
    @AppStorage("app.subscription.reminder.daysBefore") private var subscriptionReminderDaysBefore = 1
    @AppStorage("app.currency.default") private var defaultCurrencyCode = "CNY"
    @AppStorage("app.currentLedgerID") private var currentLedgerIDString: String = ""
    @AppStorage("app.ai.privacy.acknowledgedProvider") private var acknowledgedAIPrivacyProviderID = ""
    @AppStorage(NumiAppLanguage.pendingToastDefaultsKey) private var pendingLanguageToastCode: String = ""
    @StateObject private var rateService = ExchangeRateService.shared
    @ObservedObject private var membership = MembershipController.shared

    enum Tab: String, CaseIterable {
        case transactions
        case insights
        case plans
        case settings

        var title: String {
            switch self {
            case .transactions: NumiLocalized.string( "tab.transactions")
            case .insights: NumiLocalized.string( "tab.insights")
            case .plans: NumiLocalized.string( "tab.plans")
            case .settings: NumiLocalized.string( "tab.settings")
            }
        }

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
    @State private var lastBatchCategoryChanges: [BatchTransactionCategoryChange] = []
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
    @State private var aiRecordToastIsError = false
    @State private var showAIRecordToast = false
    @State private var pendingAIRecordText: String?
    @State private var pendingAIRecordProviderID: String?
    @State private var isAIPrivacyDisclosurePresented = false
    @State private var aiRecordDraft: TransactionDraft?
    @State private var membershipPaywallContext: MembershipPaywallContext?
    @State private var isAIQuickRecordConfigurationPresented = false
    @State private var isAIRecordParsing = false
    @State private var failedAIQuickRecordPrompt: String?
    @State private var aiQuickRecordFailureMessage = ""
    @State private var isAIQuickRecordFailurePresented = false
    @State private var insightsDimension: InsightsTimeDimension = .month
    @State private var insightsAnchorDate = Date()
    @State private var insightsCustomRange: InsightsCustomRange?
    @State private var insightsAccountID: UUID?
    @State private var selectedCategoryID: UUID?
    @State private var selectedCategoryType: String = "expense"
    @State private var isBottomAccessoryHiddenByPage = false
    @State private var bottomAccessoryMeasuredHeight: CGFloat = 0
    @State private var bottomAccessoryHiddenProgress: CGFloat = 0
    @StateObject private var bottomAccessoryController = NumiBottomAccessoryController()
    @State private var isManagingLedgers = false

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
                    // SwiftData/CloudKit performs import and export asynchronously.
                    // Initialising the same container only proves that the request was
                    // scheduled. The app may later observe CloudKit activity, but that
                    // global event stream is not a receipt for this specific request.
                    return .scheduled
                } catch {
                    return .failed
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
                    Text(NumiLocalized.string("error.data.init.failed"))
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
                    .environment(
                        \.privacyAmountDisplayPolicy,
                        PrivacyAmountDisplayPolicy(isHidden: isAmountDisplayHidden)
                    )
            }
        }
        .environmentObject(bottomAccessoryController)
        .onReceive(bottomAccessoryController.$isHidden) { isHidden in
            isBottomAccessoryHiddenByPage = isHidden
        }
        .onAppear {
            bottomAccessoryHiddenProgress = bottomAccessoryShouldBeHidden ? 1 : 0
            consumePendingLanguageToastIfNeeded()
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
        .overlay {
            if isAIRecordParsing {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: NumiSpacing.s3) {
                            ProgressView()
                                .controlSize(.large)
                            Text(NumiLocalized.string("ai.quickRecord.loading"))
                                .font(NumiFont.bodyStrong)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(NumiColor.textPrimary)
                        .padding(NumiSpacing.s5)
                        .background(NumiColor.surfaceFloatingSolid, in: RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
                        .padding(NumiSpacing.s6)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(NumiLocalized.string("ai.quickRecord.loading"))
                    .accessibilityAddTraits(.isModal)
            }
        }
        .tint(NumiColor.accentDeep)
        .environment(
            \.privacyAmountDisplayPolicy,
            PrivacyAmountDisplayPolicy(isHidden: isAmountDisplayHidden)
        )
        .task {
            await membership.start()
            if !requiresSubscriptionConfirmation {
                do {
                    try store.processDueSubscriptions()
                } catch {
                    initializationError = error.localizedDescription
                }
            }
            await SubscriptionReminderScheduler.schedule(
                subscriptions: store.subscriptions,
                daysBefore: subscriptionReminderDaysBefore
            )
            await InstallmentReminderScheduler.schedule(
                plans: store.installmentPlans,
                periods: store.installmentPeriods,
                daysBefore: installmentReminderDaysBefore
            )
        }
        .onChange(of: installmentReminderDaysBefore) { _, _ in
            Task {
                await InstallmentReminderScheduler.schedule(
                    plans: store.installmentPlans,
                    periods: store.installmentPeriods,
                    daysBefore: installmentReminderDaysBefore
                )
            }
        }
        .onChange(of: subscriptionReminderDaysBefore) { _, _ in
            Task {
                await SubscriptionReminderScheduler.schedule(
                    subscriptions: store.subscriptions,
                    daysBefore: subscriptionReminderDaysBefore
                )
            }
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
                    .background(aiRecordToastIsError ? Color.red.opacity(0.9) : Color.green.opacity(0.9))
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
            store.refreshFromExternalChanges()

            if !requiresSubscriptionConfirmation {
                do {
                    try store.processDueSubscriptions()
                } catch {
                    initializationError = error.localizedDescription
                }
            }

            Task {
                await SubscriptionReminderScheduler.schedule(
                    subscriptions: store.subscriptions,
                    daysBefore: subscriptionReminderDaysBefore
                )
            }

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
                currencyOptions: currencyOptions,
                onAIQuickRecord: { prompt in
                    failedAIQuickRecordPrompt = nil
                    beginAIQuickRecord(text: prompt, dismissingAddRecord: true)
                },
                initialAIQuickRecordPrompt: failedAIQuickRecordPrompt,
                opensAIQuickRecordOnAppear: failedAIQuickRecordPrompt != nil
            ) { type, money, category, account, targetAccount, occurredAt, note in
                guard let accountID = account?.id ?? store.accounts.first?.id,
                      let ledgerID = currentLedger?.id else { return false }
                let targetAccountID = type == .transfer ? targetAccount?.id : nil
                do {
                    _ = try store.createTransaction(
                        type: type,
                        amount: money,
                        categoryID: type == .transfer ? nil : category?.id,
                        accountID: accountID,
                        targetAccountID: targetAccountID,
                        ledgerID: ledgerID,
                        note: note,
                        occurredAt: occurredAt,
                        convertedAmountAtRecord: convertedAmountCapturedAtRecord(for: money, occurredAt: occurredAt)
                    )
                    alignHomeAnchorDate(to: occurredAt)
                    return true
                } catch {
                    showToast(NumiLocalized.string("error.record.save.failed"), isError: true)
                    return false
                }
            }
            .accessibilityIdentifier("sheet.addRecord")
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sheet(item: $aiRecordDraft) { draft in
            AddRecordFlowView(
                categories: store.categories,
                accounts: store.accounts,
                currencyOptions: currencyOptions,
                initialDraft: draft,
                reviewMessage: NumiLocalized.string("ai.record.review.message")
            ) { type, money, category, account, targetAccount, occurredAt, note in
                saveAIRecordDraft(
                    type: type,
                    money: money,
                    category: category,
                    account: account,
                    targetAccount: targetAccount,
                    occurredAt: occurredAt,
                    note: note
                )
            }
            .accessibilityIdentifier("sheet.aiRecordReview")
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sheet(item: selectedTransactionBinding) { transaction in
            let category = category(for: transaction)
            RecordDetailView(
                transaction: transaction,
                categories: store.categories,
                accounts: store.accounts,
                fallbackCategoryName: category.localizedName,
                fallbackIconName: category.icon,
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
            .environment(
                \.privacyAmountDisplayPolicy,
                PrivacyAmountDisplayPolicy(isHidden: isAmountDisplayHidden)
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
                        occurredAt: occurredAt,
                        convertedAmountAtRecord: convertedAmountCapturedAtRecord(for: money, occurredAt: occurredAt),
                        replaceConvertedAmountAtRecord: true
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
                TransactionSearchView(
                    rows: searchRows(),
                    categories: store.categories,
                    accounts: store.accounts
                ) { transaction in
                    isTransactionSearchPresented = false
                    selectedTransactionID = transaction.id
                }
            }
        }
        .sheet(isPresented: $isManagingLedgers) {
            NavigationStack {
                LedgerManagementView(
                    ledgers: store.ledgers,
                    transactionCounts: ledgerTransactionCounts,
                    currentLedgerID: currentLedger?.id ?? UUID(),
                    onCreate: { draft in
                        do {
                            _ = try store.createLedger(name: draft.name, currencyCode: draft.currencyCode)
                        } catch {
                            initializationError = error.localizedDescription
                        }
                    },
                    onUpdate: { ledger, draft in
                        do {
                            _ = try store.updateLedger(id: ledger.id, name: draft.name, currencyCode: draft.currencyCode)
                        } catch {
                            initializationError = error.localizedDescription
                        }
                    },
                    onDelete: { ledger in
                        do {
                            try store.deleteLedger(id: ledger.id)
                            // 如果删除的是当前账本，切换到默认账本
                            if ledger.id == currentLedger?.id {
                                currentLedgerIDString = store.ledgers.first?.id.uuidString ?? ""
                            }
                        } catch {
                            initializationError = error.localizedDescription
                        }
                    },
                    onSelect: { ledger in
                        currentLedgerIDString = ledger.id.uuidString
                    }
                )
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(28)
        }
        .confirmationDialog(
            NumiLocalized.string("ai.record.privacy.title"),
            isPresented: $isAIPrivacyDisclosurePresented,
            titleVisibility: .visible
        ) {
            Button(NumiLocalized.string("ai.record.privacy.continue")) {
                guard let text = pendingAIRecordText,
                      let providerID = pendingAIRecordProviderID else { return }
                acknowledgedAIPrivacyProviderID = providerID
                pendingAIRecordText = nil
                pendingAIRecordProviderID = nil
                Task { await performAIRecord(text: text) }
            }
            Button(NumiLocalized.string("common.cancel"), role: .cancel) {
                pendingAIRecordText = nil
                pendingAIRecordProviderID = nil
            }
        } message: {
            Text(NumiLocalized.string("ai.record.privacy.message", aiProviderDisplayName(for: pendingAIRecordProviderID)))
        }
        .membershipPaywall(context: $membershipPaywallContext)
        .alert(
            NumiLocalized.string("ai.quickRecord.configure.title"),
            isPresented: $isAIQuickRecordConfigurationPresented
        ) {
            Button(NumiLocalized.string("ai.quickRecord.configure.settings")) {
                UserDefaults.standard.set(true, forKey: "app.settings.requestAIConfiguration")
                selectedTab = .settings
            }
            Button(NumiLocalized.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(NumiLocalized.string("ai.quickRecord.configure.message"))
        }
        .alert(
            NumiLocalized.string("ai.quickRecord.failure.title"),
            isPresented: $isAIQuickRecordFailurePresented
        ) {
            Button(NumiLocalized.string("ai.quickRecord.failure.retry")) {
                guard let prompt = failedAIQuickRecordPrompt else { return }
                beginAIPrivacyCheckedRecord(text: prompt)
            }
            Button(NumiLocalized.string("ai.quickRecord.failure.edit")) {
                guard failedAIQuickRecordPrompt != nil else { return }
                isAddingRecord = true
            }
            Button(NumiLocalized.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(aiQuickRecordFailureMessage)
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
                hasUnavailableHistoricalRate: data.hasUnavailableHistoricalRate,
                periodTitle: homePeriodTitle,
                selectedPeriod: selectedHomePeriod,
                isNextPeriodEnabled: canMoveHomePeriodForward,
                sections: data.sections,
                categories: store.categories,
                accounts: store.accounts,
                currentLedger: currentLedger,
                ledgers: store.ledgers,
                onPreviousPeriod: moveHomePeriodBackward,
                onNextPeriod: moveHomePeriodForward,
                onSelectPeriod: { period in
                    homeAnchorDate = HomePeriodSelectionBehavior.anchorDate(
                        currentPeriod: selectedHomePeriod,
                        selectedPeriod: period,
                        currentAnchorDate: homeAnchorDate
                    )
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
                },
                onSelectLedger: { ledger in
                    currentLedgerIDString = ledger.id.uuidString
                },
                onBatchCategory: { transactionIDs, categoryID in
                    do {
                        lastBatchCategoryChanges = try store.changeTransactionCategories(
                            ids: transactionIDs,
                            categoryID: categoryID
                        )
                        return true
                    } catch {
                        initializationError = error.localizedDescription
                        return false
                    }
                },
                onUndoBatchCategory: {
                    guard !lastBatchCategoryChanges.isEmpty else { return false }
                    do {
                        try store.restoreTransactionCategories(lastBatchCategoryChanges)
                        lastBatchCategoryChanges = []
                        return true
                    } catch {
                        initializationError = error.localizedDescription
                        return false
                    }
                }
            )
            .numiBottomAccessoryNavigationDepth()
            .accessibilityHidden(isTransactionSearchPresented)
        }
    }

    private var insightsRoot: some View {
        let summaryResult = insightsSummary()
        let previousSummaryResult = insightsPreviousPeriodSummary()
        let trendResult = insightsTrend()
        let distribution = insightsDistribution()
        let income = insightsIncomeDistribution()
        let periodTitle = insightsPeriodTitle

        return NavigationStack {
            InsightsView(
                summary: summaryResult.summary,
                previousPeriodSummary: previousSummaryResult?.summary,
                trendPoints: trendResult?.points ?? [],
                hasUnavailableHistoricalRate: summaryResult.hasUnavailableHistoricalRate || (previousSummaryResult?.hasUnavailableHistoricalRate ?? false) || (trendResult?.hasUnavailableHistoricalRate ?? false),
                distribution: distribution,
                incomeDistribution: income,
                categories: store.categories,
                accounts: store.accounts,
                periodTitle: periodTitle,
                customRange: insightsCustomRange,
                selectedAccountID: effectiveInsightsAccountID,
                onPreviousPeriod: { moveInsightsPeriod(-1) },
                onNextPeriod: { moveInsightsPeriod(1) },
                onTimeDimensionChange: { dim in
                    insightsDimension = dim
                    insightsAnchorDate = Date()
                    insightsCustomRange = nil
                },
                onApplyCustomRange: { range in
                    insightsCustomRange = range
                },
                onClearCustomRange: {
                    insightsCustomRange = nil
                },
                onApplyAccountFilter: { accountID in
                    insightsAccountID = accountID
                },
                onSelectCategory: { row, type in
                    selectedCategoryID = row.categoryID
                    selectedCategoryType = type
                }
            )
            .numiBottomAccessoryNavigationDepth()
            .navigationDestination(isPresented: Binding(
                get: { selectedCategoryID != nil },
                set: { if !$0 { selectedCategoryID = nil } }
            )) {
                if let selectedCategoryRow {
                    let accentColor = selectedCategoryType == "expense" ? NumiColor.expenseText : NumiColor.incomeText
                    CategoryTransactionsDetailView(
                        categoryID: selectedCategoryRow.categoryID,
                        transactions: categoryTransactions(for: selectedCategoryRow.categoryID),
                        categories: store.categories,
                        accentColor: accentColor,
                        totalAmount: selectedCategoryRow.amount,
                        currencyCode: activeCurrencyCode,
                        exchangeRateHistory: rateService.history,
                        transactionType: selectedCategoryType == "expense" ? .expense : .income,
                        periodTitle: insightsPeriodTitle,
                        fallbackCategoryName: selectedCategoryRow.fallbackCategoryName,
                        fallbackIconName: selectedCategoryRow.fallbackIconName
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
                defaultCurrencyCode: activeCurrencyCode,
                onSaveBudget: { existingID, period, amount, isEnabled, isRolloverEnabled, categoryID, accountID in
                    do {
                        if let existingID {
                            _ = try store.updateBudgetSetting(
                                id: existingID,
                                period: period,
                                amount: amount,
                                isEnabled: isEnabled,
                                categoryID: categoryID,
                                accountID: accountID,
                                isRolloverEnabled: isRolloverEnabled
                            )
                        } else {
                            guard let ledgerID = currentLedger?.id else { return }
                            try store.upsertBudgetSetting(
                                period: period,
                                amount: amount,
                                isEnabled: isEnabled,
                                isRolloverEnabled: isRolloverEnabled,
                                ledgerID: ledgerID,
                                categoryID: categoryID,
                                accountID: accountID
                            )
                        }
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
                        Task {
                            await SubscriptionReminderScheduler.schedule(subscription: sub, daysBefore: subscriptionReminderDaysBefore)
                        }
                    } catch {
                        initializationError = error.localizedDescription
                    }
                },
                onDeleteSubscription: { id in
                    do {
                        try store.deleteSubscription(id: id)
                        SubscriptionReminderScheduler.cancel(subscriptionID: id)
                    } catch {
                        initializationError = error.localizedDescription
                    }
                },
                onSkipSubscriptionBilling: { id in
                    do {
                        _ = try store.skipNextSubscriptionBilling(id: id)
                    } catch {
                        initializationError = error.localizedDescription
                    }
                },
                onEnableSubscriptionReminder: { id in
                    guard let subscription = store.subscriptions.first(where: { $0.id == id }) else { return }
                    Task {
                        guard await SubscriptionReminderScheduler.requestAuthorization() else {
                            showToast(NumiLocalized.string("reminder.permission.denied"), isError: true)
                            return
                        }
                        guard await SubscriptionReminderScheduler.schedule(subscription: subscription, daysBefore: subscriptionReminderDaysBefore) else {
                            showToast(NumiLocalized.string("reminder.schedule.failed"), isError: true)
                            return
                        }
                    }
                },
                onRecordSubscriptionBilling: { id in
                    do {
                        _ = try store.recordNextSubscriptionBilling(id: id)
                        if let subscription = store.subscriptions.first(where: { $0.id == id }) {
                            Task {
                                await SubscriptionReminderScheduler.schedule(subscription: subscription, daysBefore: subscriptionReminderDaysBefore)
                            }
                        }
                    } catch {
                        initializationError = error.localizedDescription
                    }
                },
                onEnableInstallmentReminder: { id in
                    guard let plan = store.installmentPlans.first(where: { $0.id == id }) else { return }
                    Task {
                        guard await SubscriptionReminderScheduler.requestAuthorization() else {
                            showToast(NumiLocalized.string("reminder.permission.denied"), isError: true)
                            return
                        }
                        guard await InstallmentReminderScheduler.schedule(
                            plan: plan,
                            periods: store.installmentPeriods,
                            daysBefore: installmentReminderDaysBefore
                        ) else {
                            showToast(NumiLocalized.string("reminder.schedule.failed"), isError: true)
                            return
                        }
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
                        try store.updateInstallmentPlan(plan)
                        if let updatedPlan = store.installmentPlans.first(where: { $0.id == plan.id }) {
                            Task {
                                await InstallmentReminderScheduler.schedule(
                                    plan: updatedPlan,
                                    periods: store.installmentPeriods,
                                    daysBefore: installmentReminderDaysBefore
                                )
                            }
                        }
                    } catch {
                        initializationError = error.localizedDescription
                    }
                },
                onDeleteInstallmentPlan: { id in
                    do {
                        try store.deleteInstallmentPlan(id: id)
                        InstallmentReminderScheduler.cancel(planID: id)
                    } catch {
                        initializationError = error.localizedDescription
                    }
                },
                onUpdateInstallmentPeriod: { period in
                    do {
                        try store.updateInstallmentPeriod(period)
                        if let plan = store.installmentPlans.first(where: { $0.id == period.planID }) {
                            Task {
                                await InstallmentReminderScheduler.schedule(
                                    plan: plan,
                                    periods: store.installmentPeriods,
                                    daysBefore: installmentReminderDaysBefore
                                )
                            }
                        }
                    } catch {
                        initializationError = error.localizedDescription
                    }
                },
                onRecordInstallmentPayment: { period, occurredAt in
                    do {
                        guard let ledgerID = currentLedger?.id else {
                            initializationError = SwiftDataBookkeepingStoreError.ledgerNotFound.localizedDescription
                            return
                        }
                        try store.recordInstallmentPayment(periodID: period.id, ledgerID: ledgerID, occurredAt: occurredAt)
                        if let plan = store.installmentPlans.first(where: { $0.id == period.planID }) {
                            Task {
                                await InstallmentReminderScheduler.schedule(
                                    plan: plan,
                                    periods: store.installmentPeriods,
                                    daysBefore: installmentReminderDaysBefore
                                )
                            }
                        }
                    } catch {
                        showToast(NumiLocalized.string("error.installment.record.fail", error.localizedDescription), isError: true)
                    }
                },
                onSettleInstallmentPlan: { plan in
                    do {
                        guard let ledgerID = currentLedger?.id else {
                            showToast(NumiLocalized.string("error.installment.settle.fail", SwiftDataBookkeepingStoreError.ledgerNotFound.localizedDescription), isError: true)
                            return
                        }
                        _ = try store.settleInstallmentPlan(planID: plan.id, ledgerID: ledgerID)
                        Task {
                            await InstallmentReminderScheduler.schedule(
                                plan: plan,
                                periods: store.installmentPeriods,
                                daysBefore: installmentReminderDaysBefore
                            )
                        }
                    } catch {
                        showToast(NumiLocalized.string("error.installment.settle.fail", error.localizedDescription), isError: true)
                    }
                },
                onSkipInstallmentPeriod: { period in
                    do {
                        try store.skipInstallmentPeriod(periodID: period.id)
                        if let plan = store.installmentPlans.first(where: { $0.id == period.planID }) {
                            Task {
                                await InstallmentReminderScheduler.schedule(
                                    plan: plan,
                                    periods: store.installmentPeriods,
                                    daysBefore: installmentReminderDaysBefore
                                )
                            }
                        }
                    } catch {
                        showToast(NumiLocalized.string("error.installment.skip.fail", error.localizedDescription), isError: true)
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
                exchangeRateHistory: rateService.history,
                ledgers: store.ledgers,
                currentLedgerID: currentLedger?.id,
                ledgerTransactionCounts: ledgerTransactionCounts,
                exportSnapshot: {
                    var snapshot = store.exportSnapshot()
                    snapshot.exchangeRateHistory = rateService.history
                    return snapshot
                },
                importSnapshot: { snapshot in
                    try store.importSnapshot(snapshot)
                    if let history = snapshot.exchangeRateHistory {
                        rateService.replaceHistory(history)
                    }
                },
                appendTransactions: { transactions in try store.appendTransactions(transactions) },
                onManageLedgers: {
                    isManagingLedgers = true
                },
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

    private func summaryAndSections() -> (summary: TransactionSummary, hasUnavailableHistoricalRate: Bool, sections: [TransactionHomeSection]) {
        let transactions = filteredHomeTransactions
        let summaryResult = currencySummary(for: transactions)
        let rows = transactions.map { transaction in
            let category = store.categories.first { $0.id == transaction.categoryID }
            return TransactionHomeRow(
                transaction: transaction,
                fallbackCategoryName: displayName(for: transaction, categoryName: category?.localizedDisplayName),
                fallbackIconName: displayIcon(for: transaction, categoryIcon: category?.icon),
                fallbackSubtitle: transferSubtitle(for: transaction)
            )
        }

        let grouped = Dictionary(grouping: rows) {
            homeSectionDayKeyFormatter.string(from: $0.transaction.occurredAt)
        }

        let sections = grouped
            .compactMap { key, rows -> TransactionHomeSection? in
                guard let date = homeSectionDayKeyFormatter.date(from: key) else { return nil }
                let sortedRows = rows.sorted { $0.transaction.occurredAt > $1.transaction.occurredAt }

                let dailyResult = currencySummary(for: rows.map(\.transaction))
                let dailyExpense = dailyResult.summary.expense.minorUnits > 0 ? dailyResult.summary.expense : nil
                let dailyIncome = dailyResult.summary.income.minorUnits > 0 ? dailyResult.summary.income : nil

                return TransactionHomeSection(
                    id: homeSectionAccessibilityIdentifier(for: date, fallback: key),
                    title: homeSectionTitle(for: date),
                    rows: sortedRows,
                    dailyExpense: dailyExpense,
                    dailyIncome: dailyIncome,
                    hasUnavailableHistoricalRate: dailyResult.hasUnavailableHistoricalRate
                )
            }
            .sorted { $0.rows.first?.transaction.occurredAt ?? .distantPast > $1.rows.first?.transaction.occurredAt ?? .distantPast }

        return (
            summary: summaryResult.summary,
            hasUnavailableHistoricalRate: summaryResult.hasUnavailableHistoricalRate,
            sections: sections
        )
    }

    private func searchRows() -> [TransactionSearchRow] {
        store.visibleTransactions
            .sorted { $0.occurredAt > $1.occurredAt }
            .map { transaction in
                let category = store.categories.first { $0.id == transaction.categoryID }
                return TransactionSearchRow(
                    transaction: transaction,
                    fallbackCategoryName: displayName(for: transaction, categoryName: category?.localizedDisplayName),
                    fallbackIconName: displayIcon(for: transaction, categoryIcon: category?.icon),
                    fallbackSubtitle: transferSubtitle(for: transaction)
                )
            }
    }

    // MARK: - Insights Data

    private var insightsFilteredTransactions: [NumiCore.Transaction] {
        let interval = insightsDateInterval
        let ledgerID = currentLedger?.id
        return store.visibleTransactions.filter { tx in
            InsightsCustomRangePolicy.contains(tx.occurredAt, in: interval)
                && (ledgerID == nil || tx.ledgerID == ledgerID)
                && InsightsAccountFilterPolicy.includes(tx, accountID: effectiveInsightsAccountID)
        }
    }

    private var effectiveInsightsAccountID: UUID? {
        guard let insightsAccountID,
              store.accounts.contains(where: { $0.id == insightsAccountID }) else {
            return nil
        }
        return insightsAccountID
    }

    private var insightsDateInterval: DateInterval {
        let cal = calendar
        if let insightsCustomRange {
            return InsightsCustomRangePolicy.dateInterval(
                start: insightsCustomRange.start,
                end: insightsCustomRange.end,
                calendar: cal
            )
        }
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
        if insightsCustomRange != nil {
            let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            return "\(yearMonthDayFormatter.string(from: start)) - \(yearMonthDayFormatter.string(from: end))"
        }
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
            return NumiLocalized.string("period.quarter", String(year), String(quarter))
        case .year:
            return NumiLocalized.string("period.year", String(calendar.component(.year, from: start)))
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

    private func insightsSummary() -> CurrencySummaryResult {
        currencySummary(for: insightsFilteredTransactions)
    }

    private func insightsPreviousPeriodSummary() -> CurrencySummaryResult? {
        guard insightsCustomRange != nil else { return nil }
        let previousInterval = InsightsCustomRangePolicy.previousInterval(
            for: insightsDateInterval,
            calendar: calendar
        )
        let ledgerID = currentLedger?.id
        let transactions = store.visibleTransactions.filter { transaction in
            InsightsCustomRangePolicy.contains(transaction.occurredAt, in: previousInterval)
                && (ledgerID == nil || transaction.ledgerID == ledgerID)
                && InsightsAccountFilterPolicy.includes(transaction, accountID: effectiveInsightsAccountID)
        }
        return currencySummary(for: transactions)
    }

    private func insightsTrend() -> InsightsTrendResult? {
        guard insightsCustomRange != nil else { return nil }
        do {
            return InsightsTrendResult(
                points: try CashflowTrend.daily(
                    transactions: insightsFilteredTransactions,
                    interval: insightsDateInterval,
                    currencyCode: activeCurrencyCode,
                    exchangeRateHistory: rateService.history,
                    calendar: calendar
                ),
                hasUnavailableHistoricalRate: false
            )
        } catch {
            return InsightsTrendResult(points: [], hasUnavailableHistoricalRate: true)
        }
    }

    private func insightsDistribution() -> [InsightsDistributionRow] {
        let txs = insightsFilteredTransactions
        let items = (try? CategoryDistribution.expense(
            transactions: txs,
            currencyCode: activeCurrencyCode,
            exchangeRateHistory: rateService.history
        )) ?? []
        return items.map { item in
            let category = store.categories.first { $0.id == item.categoryID }
            return InsightsDistributionRow(
                categoryID: item.categoryID,
                fallbackCategoryName: category?.localizedDisplayName ?? NumiLocalized.string( "other.fallback"),
                fallbackIconName: category?.icon ?? "ellipsis.circle",
                amount: item.amount,
                percentage: item.percentage
            )
        }
    }

    private func insightsIncomeDistribution() -> [InsightsDistributionRow] {
        let txs = insightsFilteredTransactions
        let items = (try? CategoryDistribution.income(
            transactions: txs,
            currencyCode: activeCurrencyCode,
            exchangeRateHistory: rateService.history
        )) ?? []
        return items.map { item in
            let category = store.categories.first { $0.id == item.categoryID }
            return InsightsDistributionRow(
                categoryID: item.categoryID,
                fallbackCategoryName: category?.localizedDisplayName ?? NumiLocalized.string( "other.fallback"),
                fallbackIconName: category?.icon ?? "ellipsis.circle",
                amount: item.amount,
                percentage: item.percentage
            )
        }
    }

    private var selectedCategoryRow: InsightsDistributionRow? {
        guard let selectedCategoryID else { return nil }
        return (selectedCategoryType == "expense" ? insightsDistribution() : insightsIncomeDistribution())
            .first(where: { $0.categoryID == selectedCategoryID })
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

    private func category(for transaction: NumiCore.Transaction) -> (localizedName: String, icon: String) {
        let category = store.categories.first { $0.id == transaction.categoryID }
        return (
            displayName(for: transaction, categoryName: category?.localizedDisplayName),
            displayIcon(for: transaction, categoryIcon: category?.icon)
        )
    }

    private func accountName(for transaction: NumiCore.Transaction) -> String {
        guard let accountID = transaction.accountID else { return NumiLocalized.string( "empty.no.selection") }
        return store.accounts.first { $0.id == accountID }?.localizedDisplayName ?? NumiLocalized.string( "empty.no.selection")
    }

    private func targetAccountName(for transaction: NumiCore.Transaction) -> String? {
        guard let targetAccountID = transaction.targetAccountID else { return nil }
        return store.accounts.first { $0.id == targetAccountID }?.localizedDisplayName ?? NumiLocalized.string( "empty.no.selection")
    }

    private func shareText(for transaction: NumiCore.Transaction) -> String {
        let category = category(for: transaction)
        let amount = PrivacyAmountDisplayPolicy(isHidden: isAmountDisplayHidden).display(transaction.amount)
        let date = NumiDatePickerRow.displayText(for: transaction.occurredAt)
        let account = accountName(for: transaction)
        let noSelection = NumiLocalized.string( "empty.no.selection")
        let transfer = transaction.type == .transfer ? " -> \(targetAccountName(for: transaction) ?? noSelection)" : ""
        let note = transaction.note.isEmpty ? "" : "\n\(NumiLocalized.string( "share.note"))\(transaction.note)"
        let timeLabel = NumiLocalized.string( "share.time")
        let accountLabel = NumiLocalized.string( "share.account")
        return """
        \(category.localizedName) \(amount)
        \(timeLabel)\(date)
        \(accountLabel)\(account)\(transfer)\(note)
        """
    }

    private func displayName(for transaction: NumiCore.Transaction, categoryName: String?) -> String {
        transaction.type == .transfer ? NumiLocalized.string( "other.transfer") : (categoryName ?? NumiLocalized.string( "other.fallback"))
    }

    private func displayIcon(for transaction: NumiCore.Transaction, categoryIcon: String?) -> String {
        transaction.type == .transfer ? "arrow.left.arrow.right.circle" : (categoryIcon ?? "ellipsis.circle")
    }

    private func transferSubtitle(for transaction: NumiCore.Transaction) -> String? {
        guard transaction.type == .transfer else { return nil }
        return "\(accountName(for: transaction)) -> \(targetAccountName(for: transaction) ?? NumiLocalized.string( "empty.no.selection"))"
    }

    private func budgetCards(today: Date = Date(), calendar: Calendar = Calendar.current) -> [BudgetCardModel] {
        let ledgerID = currentLedger?.id
        let settings = store.budgetSettings.filter { ledgerID == nil || $0.ledgerID == ledgerID }
        let globalCards = [BudgetPeriod.week, .month].map { period in
            let setting = settings.first { $0.period == period && $0.categoryID == nil && $0.accountID == nil }
            let amount = setting?.amount ?? defaultBudgetAmount(for: period)
            let range = budgetDateRange(for: period, today: today, calendar: calendar)
            let spent = spentAmount(from: range.start, to: range.end, categoryID: nil, accountID: nil)
            let carriedOverAmount = rolloverAmount(for: setting, currentRange: range, calendar: calendar)
            let availableAmount = Money(
                minorUnits: amount.minorUnits + carriedOverAmount.minorUnits,
                currencyCode: amount.currencyCode
            )
            let limit = BudgetLimit(amount: availableAmount, period: period, startsOn: range.start, endsOn: range.end)
            let status = (try? BudgetCalculator.status(for: limit, spent: spent, today: today, calendar: calendar))
                ?? BudgetStatus(remaining: amount, dailySuggestion: amount, isOverBudget: false)

            return BudgetCardModel(
                period: period,
                amount: amount,
                spent: spent,
                status: status,
                isEnabled: setting?.isEnabled ?? true,
                isRolloverEnabled: setting?.isRolloverEnabled ?? false,
                carriedOverAmount: carriedOverAmount,
                id: setting?.id ?? BudgetCardModel.defaultID(for: period),
                persistedBudgetID: setting?.id
            )
        }
        let scopedCards = settings
            .filter { $0.categoryID != nil || $0.accountID != nil }
            .map { setting in
                let range = budgetDateRange(for: setting.period, today: today, calendar: calendar)
                let spent = spentAmount(from: range.start, to: range.end, categoryID: setting.categoryID, accountID: setting.accountID)
                let carriedOverAmount = rolloverAmount(for: setting, currentRange: range, calendar: calendar)
                let availableAmount = Money(
                    minorUnits: setting.amount.minorUnits + carriedOverAmount.minorUnits,
                    currencyCode: setting.amount.currencyCode
                )
                let limit = BudgetLimit(amount: availableAmount, period: setting.period, startsOn: range.start, endsOn: range.end)
                let status = (try? BudgetCalculator.status(for: limit, spent: spent, today: today, calendar: calendar))
                    ?? BudgetStatus(remaining: setting.amount, dailySuggestion: setting.amount, isOverBudget: false)
                let scopeName = setting.categoryID.flatMap { id in store.categories.first { $0.id == id }?.localizedDisplayName }
                    ?? setting.accountID.flatMap { id in store.accounts.first { $0.id == id }?.localizedDisplayName }
                return BudgetCardModel(
                    period: setting.period,
                    amount: setting.amount,
                    spent: spent,
                    status: status,
                    isEnabled: setting.isEnabled,
                    isRolloverEnabled: setting.isRolloverEnabled,
                    carriedOverAmount: carriedOverAmount,
                    id: setting.id,
                    persistedBudgetID: setting.id,
                    categoryID: setting.categoryID,
                    accountID: setting.accountID,
                    scopeName: scopeName
                )
            }
        return globalCards + scopedCards
    }

    private func rolloverAmount(
        for setting: BudgetSetting?,
        currentRange: (start: Date, end: Date),
        calendar: Calendar
    ) -> Money {
        guard let setting, setting.isEnabled, setting.isRolloverEnabled else {
            return .zero(currencyCode: setting?.amount.currencyCode ?? activeCurrencyCode)
        }
        let component: Calendar.Component = setting.period == .week ? .weekOfYear : .month
        guard let priorAnchor = calendar.date(byAdding: component, value: -1, to: currentRange.start) else {
            return .zero(currencyCode: setting.amount.currencyCode)
        }
        let previousRange = budgetDateRange(for: setting.period, today: priorAnchor, calendar: calendar)
        let previousSpent = spentAmount(
            from: previousRange.start,
            to: previousRange.end,
            categoryID: setting.categoryID,
            accountID: setting.accountID
        )
        return (try? BudgetCalculator.unusedCarryover(
            budgetAmount: setting.amount,
            previousSpent: previousSpent
        )) ?? .zero(currencyCode: setting.amount.currencyCode)
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

    private func spentAmount(from start: Date, to end: Date, categoryID: UUID?, accountID: UUID?) -> Money {
        let ledgerID = currentLedger?.id
        let transactions = store.visibleTransactions
            .filter { transaction in
                transaction.occurredAt >= start
                    && transaction.occurredAt <= end
                    && (ledgerID == nil || transaction.ledgerID == ledgerID)
            }
        return (try? BudgetSpendingCalculator.spending(
            from: transactions,
            categoryID: categoryID,
            accountID: accountID,
            currencyCode: currentLedger?.currencyCode ?? "CNY",
            exchangeRateHistory: rateService.history
        )) ?? Money.zero(currencyCode: currentLedger?.currencyCode ?? "CNY")
    }

    private var filteredHomeTransactions: [NumiCore.Transaction] {
        let interval = homeDateInterval
        let ledgerID = currentLedger?.id
        return store.visibleTransactions.filter { transaction in
            interval.contains(transaction.occurredAt)
                && (ledgerID == nil || transaction.ledgerID == ledgerID)
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
            return NumiLocalized.string("period.quarter", String(year), String(quarter))
        case .year:
            return NumiLocalized.string("period.year", String(calendar.component(.year, from: start)))
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

    private func currencySummary(for transactions: [NumiCore.Transaction]) -> CurrencySummaryResult {
        do {
            return CurrencySummaryResult(
                summary: try TransactionSummary.monthly(
                    transactions: transactions,
                    currencyCode: activeCurrencyCode,
                    exchangeRateHistory: rateService.history
                ),
                hasUnavailableHistoricalRate: false
            )
        } catch {
            return CurrencySummaryResult(
                summary: TransactionSummary(
                    expense: .zero(currencyCode: activeCurrencyCode),
                    income: .zero(currencyCode: activeCurrencyCode),
                    balance: .zero(currencyCode: activeCurrencyCode),
                    recordCount: transactions.count
                ),
                hasUnavailableHistoricalRate: true
            )
        }
    }

    private func homeSectionTitle(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return NumiLocalized.string( "date.today")
        }
        if calendar.isDateInYesterday(date) {
            return NumiLocalized.string( "date.yesterday")
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
        calendar.locale = NumiLocalized.currentLocale
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        return calendar
    }

    private var yearMonthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = NumiLocalized.currentLocale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMM")
        return formatter
    }

    private var monthDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = NumiLocalized.currentLocale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }

    private var monthDayWeekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = NumiLocalized.currentLocale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("MMMMdEEEE")
        return formatter
    }

    private var yearMonthDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = NumiLocalized.currentLocale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMdd")
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

    private var currentLedger: Ledger? {
        let ledgers = store.ledgers
        if let id = UUID(uuidString: currentLedgerIDString),
           let match = ledgers.first(where: { $0.id == id }) {
            return match
        }
        // 回退到默认账本（第一个）
        let fallback = ledgers.first
        if let fallback {
            currentLedgerIDString = fallback.id.uuidString
        }
        return fallback
    }

    private var activeCurrencyCode: String {
        currentLedger?.currencyCode ?? defaultCurrencyCode
    }

    private func convertedAmountCapturedAtRecord(for amount: Money, occurredAt: Date) -> Money? {
        guard amount.currencyCode != activeCurrencyCode.uppercased(), occurredAt <= Date() else { return nil }
        return rateService.history.convert(amount, to: activeCurrencyCode, on: occurredAt)
    }

    private var ledgerTransactionCounts: [UUID: Int] {
        let allTxs = store.visibleTransactions
        var counts: [UUID: Int] = [:]
        for tx in allTxs {
            counts[tx.ledgerID, default: 0] += 1
        }
        return counts
    }

    // MARK: - URL Scheme 处理

    /// numi://record?text=午饭35块
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "numi", url.host == "record" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let text = components?.queryItems?.first(where: { $0.name == "text" })?.value else {
            showToast(NumiLocalized.string( "error.missing.text"), isError: true)
            return
        }
        beginAIQuickRecord(text: text)
    }

    private func beginAIQuickRecord(text: String, dismissingAddRecord: Bool = false) {
        guard let normalizedText = AIQuickRecordPrompt.normalized(text) else {
            showToast(NumiLocalized.string("error.missing.text"), isError: true)
            return
        }

        if membership.hasResolvedStatus {
            routeAIQuickRecord(normalizedText, dismissingAddRecord: dismissingAddRecord)
        } else {
            Task {
                await membership.start()
                routeAIQuickRecord(normalizedText, dismissingAddRecord: dismissingAddRecord)
            }
        }
    }

    private func routeAIQuickRecord(_ text: String, dismissingAddRecord: Bool) {
        let destination = AIQuickRecordLaunchPolicy.destination(
            accessDecision: membership.decision(for: .openAIRecord),
            hasConfiguredProvider: resolvedAIProviderID() != nil
        )

        switch destination {
        case .upgrade(let context):
            presentAfterAddRecordDismissal(dismissingAddRecord) {
                membershipPaywallContext = context
            }
        case .configureProvider:
            presentAfterAddRecordDismissal(dismissingAddRecord) {
                isAIQuickRecordConfigurationPresented = true
            }
        case .parse:
            presentAfterAddRecordDismissal(dismissingAddRecord) {
                beginAIPrivacyCheckedRecord(text: text)
            }
        }
    }

    private func presentAfterAddRecordDismissal(_ dismissingAddRecord: Bool, action: @escaping () -> Void) {
        guard dismissingAddRecord else {
            action()
            return
        }

        isAddingRecord = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: action)
    }

    private func beginAIPrivacyCheckedRecord(text: String) {
        guard let providerID = resolvedAIProviderID() else {
            isAIQuickRecordConfigurationPresented = true
            return
        }

        if AIRecordPrivacyPolicy.requiresDisclosure(
            providerID: providerID,
            acknowledgedProviderID: acknowledgedAIPrivacyProviderID
        ) {
            pendingAIRecordText = text
            pendingAIRecordProviderID = providerID
            isAIPrivacyDisclosurePresented = true
            return
        }

        Task { await performAIRecord(text: text) }
    }

    private func performAIRecord(text: String) async {
        let defaults = UserDefaults.standard
        let claudeKey = defaults.string(forKey: "app.ai.claudeAPIKey") ?? ""
        let qwenKey = defaults.string(forKey: "app.ai.qwenAPIKey") ?? ""
        let dsKey = defaults.string(forKey: "app.ai.deepseekAPIKey") ?? ""

        guard let provider = resolvedAIProviderID() else {
            showToast(NumiLocalized.string("error.ai.no.key"), isError: true)
            return
        }

        isAIRecordParsing = true
        defer { isAIRecordParsing = false }

        let parser: TransactionLLMService
        switch provider {
        case "qwen":
            parser = QwenTransactionParser(apiKey: qwenKey)
        case "deepseek":
            parser = DeepSeekTransactionParser(apiKey: dsKey)
        case "claude":
            parser = ClaudeTransactionParser(apiKey: claudeKey)
        default:
            assertionFailure("Unsupported AI provider")
            return
        }

        let visibleCategories = store.categories.filter { !$0.isHidden }
        let visibleAccounts = store.accounts.filter { !$0.isHidden }
        let categories = visibleCategories.localizedCategoryNames()
        let accounts = visibleAccounts.localizedAccountNames()

        do {
            let parsed = try await parser.parseTransaction(text, categories: categories, accounts: accounts)

            let category = parsed.type == .transfer
                ? nil
                : visibleCategories.resolveLocalizedCategory(named: parsed.categoryName)
            let transferResolution = parsed.type == .transfer
                ? visibleAccounts.resolveLocalizedTransferAccounts(
                    parsedAccountName: parsed.accountName,
                    parsedTargetAccountName: parsed.targetAccountName
                )
                : nil
            let rawAccount = visibleAccounts.resolveLocalizedAccount(named: parsed.accountName)
            let targetAccount = transferResolution?.target
            let account = parsed.type == .transfer
                ? transferResolution?.source
                : (rawAccount ?? visibleAccounts.first)

            guard let account,
                  parsed.type == .transfer ? targetAccount != nil : category != nil else {
                presentAIQuickRecordFailure(
                    message: NumiLocalized.string("error.ai.parse.fail"),
                    prompt: text
                )
                return
            }

            let money = try Money(decimalString: "\(parsed.amount)", currencyCode: activeCurrencyCode)
            guard currentLedger != nil else {
                presentAIQuickRecordFailure(
                    message: NumiLocalized.string("error.ai.no.ledger"),
                    prompt: text
                )
                return
            }

            aiRecordDraft = TransactionDraft(
                type: parsed.type,
                categoryID: category?.id,
                amount: money,
                accountID: account.id,
                targetAccountID: parsed.type == .transfer ? targetAccount?.id : nil,
                occurredAt: parsed.occurredAt,
                note: parsed.note
            )
        } catch {
            presentAIQuickRecordFailure(
                message: NumiLocalized.string("error.ai.record.fail", error.localizedDescription),
                prompt: text
            )
        }
    }

    private func presentAIQuickRecordFailure(message: String, prompt: String) {
        failedAIQuickRecordPrompt = prompt
        aiQuickRecordFailureMessage = message
        isAIQuickRecordFailurePresented = true
    }

    private func saveAIRecordDraft(
        type: TransactionType,
        money: Money,
        category: NumiCore.Category?,
        account: Account?,
        targetAccount: Account?,
        occurredAt: Date,
        note: String
    ) -> Bool {
        guard let accountID = account?.id,
              let ledgerID = currentLedger?.id else { return false }
        do {
            _ = try store.createTransaction(
                type: type,
                amount: money,
                categoryID: type == .transfer ? nil : category?.id,
                accountID: accountID,
                targetAccountID: type == .transfer ? targetAccount?.id : nil,
                ledgerID: ledgerID,
                note: note,
                occurredAt: occurredAt,
                convertedAmountAtRecord: convertedAmountCapturedAtRecord(for: money, occurredAt: occurredAt)
            )
            alignHomeAnchorDate(to: occurredAt)
            let symbol = switch type {
            case .income: "+"
            case .expense: "-"
            case .transfer: ""
            }
            let categoryName = type == .transfer
                ? NumiLocalized.string("other.transfer")
                : (category?.localizedDisplayName ?? NumiLocalized.string("empty.no.category"))
            showToast(NumiLocalized.string(
                "error.ai.record.success",
                categoryName,
                symbol,
                money.formatted(locale: NumiLocalized.currentLocale)
            ))
            return true
        } catch {
            showToast(NumiLocalized.string("error.record.save.failed"), isError: true)
            return false
        }
    }

    private func resolvedAIProviderID() -> String? {
        let defaults = UserDefaults.standard
        let preferredProvider = defaults.string(forKey: "app.ai.provider") ?? "claude"
        let availableKeys = [
            "claude": defaults.string(forKey: "app.ai.claudeAPIKey") ?? "",
            "qwen": defaults.string(forKey: "app.ai.qwenAPIKey") ?? "",
            "deepseek": defaults.string(forKey: "app.ai.deepseekAPIKey") ?? ""
        ]

        if let preferredKey = availableKeys[preferredProvider], !preferredKey.isEmpty {
            return preferredProvider
        }
        return ["deepseek", "claude", "qwen"].first { !(availableKeys[$0] ?? "").isEmpty }
    }

    private func aiProviderDisplayName(for providerID: String?) -> String {
        switch providerID {
        case "qwen": "Qwen"
        case "deepseek": "DeepSeek"
        default: "Claude"
        }
    }

    private func showToast(_ message: String, isError: Bool = false) {
        aiRecordToast = message
        aiRecordToastIsError = isError
        withAnimation { showAIRecordToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showAIRecordToast = false }
        }
    }

    private func consumePendingLanguageToastIfNeeded() {
        guard !pendingLanguageToastCode.isEmpty else { return }
        let languageName = NumiAppLanguage.displayName(for: pendingLanguageToastCode)
        pendingLanguageToastCode = ""
        showToast(NumiLocalized.string("language.switch.success", languageName))
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
        if cloudSync {
            return try SwiftDataBookkeepingStore(enableCloudSync: true)
        }

        let fileManager = FileManager.default
        let legacyStoreURL = try appStoreDirectoryURL(fileManager: fileManager)
            .appendingPathComponent(SharedBookkeepingStoreLocation.storeFileName)

        if let sharedStoreURL = SharedBookkeepingStoreLocation.storeURL(fileManager: fileManager) {
            _ = try SharedBookkeepingStoreLocation.migrateLegacyStoreIfNeeded(
                legacyStoreURL: legacyStoreURL,
                sharedStoreURL: sharedStoreURL,
                fileManager: fileManager
            )
            return try SwiftDataBookkeepingStore(storeURL: sharedStoreURL)
        }

        // Keep the main app usable in environments without App Group entitlement.
        return try SwiftDataBookkeepingStore(storeURL: legacyStoreURL)
    }

    static func appStoreDirectoryURL(fileManager: FileManager) throws -> URL {
        let baseDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseDirectory.appendingPathComponent("Numi", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
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
                    title: $0.title,
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
            trailingActionTitle: NumiLocalized.string( "common.newBill"),
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

                    Text(NumiLocalized.string("security.app.blurred"))
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
            let reason = NumiLocalized.string( "security.verify.to.unlock")
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = NumiLocalized.string( "security.verify.to.unlock")
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
