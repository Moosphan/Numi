import XCTest
import Foundation
import NumiCore
@testable import NumiPersistence

final class SwiftDataBookkeepingStoreTests: XCTestCase {
    private let languageKey = "app.language"
    private var originalLanguage: String?

    override func setUp() {
        super.setUp()
        originalLanguage = UserDefaults.standard.string(forKey: languageKey)
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
    }

    override func tearDown() {
        if let originalLanguage {
            UserDefaults.standard.set(originalLanguage, forKey: languageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: languageKey)
        }
        super.tearDown()
    }

    @MainActor
    func testShowcaseSeedProfileCreatesRichDemoState() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)

        try DemoDataSeeder.seed(profile: .showcase, into: store, resetBeforeSeeding: false)

        XCTAssertGreaterThanOrEqual(store.accounts.count, 5)
        XCTAssertGreaterThanOrEqual(store.visibleTransactions.count, 10)
        XCTAssertEqual(store.budgetSettings.count, 2)
        XCTAssertNotNil(store.accounts.first { $0.name == "招商银行卡" })
        XCTAssertNotNil(store.accounts.first { $0.name == "支付宝" })
        XCTAssertNotNil(store.visibleTransactions.first { $0.type == .transfer })
        XCTAssertNotNil(store.visibleTransactions.first { $0.note.contains("咖啡") })
        XCTAssertEqual(store.budgetSettings.first { $0.period == .week }?.amount.formatted(), "¥500.00")
        XCTAssertEqual(store.budgetSettings.first { $0.period == .month }?.amount.formatted(), "¥4,800.00")
        XCTAssertFalse(store.visibleTransactions.contains { $0.note.contains("__numi_demo_") })
    }

    @MainActor
    func testShowcaseSeedProfileUsesBuiltInDefaultsAcrossLanguages() throws {
        UserDefaults.standard.set("en", forKey: languageKey)
        let store = try SwiftDataBookkeepingStore(inMemory: true)

        try DemoDataSeeder.seed(profile: .showcase, into: store, resetBeforeSeeding: false)

        XCTAssertEqual(store.defaultLedger()?.name, "Default Ledger")
        XCTAssertEqual(store.accounts.first(where: { $0.type == .cash })?.name, "Cash")
        XCTAssertEqual(store.accounts.first(where: { $0.type == .debitCard })?.name, "招商银行卡")
        XCTAssertNotNil(store.categories.first {
            $0.kind == .expense &&
            $0.icon == "acai-bowl" &&
            $0.name == "Dining"
        })
        XCTAssertNotNil(store.categories.first {
            $0.kind == .income &&
            $0.icon == "cash" &&
            $0.name == "Salary"
        })
        XCTAssertNotNil(store.visibleTransactions.first { $0.note.contains("咖啡") })
    }

    @MainActor
    func testShowcaseSeedProfileIsIdempotentWithoutReset() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)

        try DemoDataSeeder.seed(profile: .showcase, into: store, resetBeforeSeeding: false)
        let firstCounts = (
            accounts: store.accounts.count,
            transactions: store.visibleTransactions.count,
            budgets: store.budgetSettings.count
        )

        try DemoDataSeeder.seed(profile: .showcase, into: store, resetBeforeSeeding: false)

        XCTAssertEqual(store.accounts.count, firstCounts.accounts)
        XCTAssertEqual(store.visibleTransactions.count, firstCounts.transactions)
        XCTAssertEqual(store.budgetSettings.count, firstCounts.budgets)
    }

    @MainActor
    func testShowcaseSeedProfileResetRemovesExistingDataBeforeReseeding() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let accountID = try XCTUnwrap(store.accounts.first?.id)
        let foodID = try XCTUnwrap(store.categories.first { $0.name == "餐饮" }?.id)
        _ = try store.createTransaction(
            type: .expense,
            amount: Money(decimalString: "88", currencyCode: "CNY"),
            categoryID: foodID,
            accountID: accountID,
            ledgerID: store.ledgers.first!.id,
            note: "旧数据"
        )

        try DemoDataSeeder.seed(profile: .showcase, into: store, resetBeforeSeeding: true)

        XCTAssertNil(store.visibleTransactions.first { $0.note == "旧数据" })
        XCTAssertNotNil(store.visibleTransactions.first { $0.note.contains("咖啡") })
        XCTAssertEqual(store.budgetSettings.count, 2)
    }

    @MainActor
    func testScreenshotShowcaseSeedProfileCreatesBalancedVisualState() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)

        try DemoDataSeeder.seed(profile: .screenshotShowcase, into: store, resetBeforeSeeding: false)

        XCTAssertGreaterThanOrEqual(store.accounts.count, 6)
        XCTAssertGreaterThanOrEqual(store.visibleTransactions.count, 12)
        XCTAssertEqual(store.budgetSettings.count, 2)
        XCTAssertNotNil(store.accounts.first { $0.name == "应急金" })
        XCTAssertNotNil(store.visibleTransactions.first { $0.note.contains("周末市集") })
        XCTAssertNotNil(store.visibleTransactions.first { $0.type == .transfer })
        XCTAssertFalse(store.visibleTransactions.contains { $0.note.contains("__numi_demo_") })

        let summary = try TransactionSummary.monthly(transactions: store.visibleTransactions, currencyCode: "CNY")
        XCTAssertEqual(summary.expense.formatted(), "¥3,066.50")
        XCTAssertEqual(summary.income.formatted(), "¥11,730.00")
        XCTAssertEqual(summary.balance.formatted(), "¥8,663.50")
        XCTAssertEqual(summary.recordCount, 13)

        let distribution = try CategoryDistribution.expense(transactions: store.visibleTransactions, currencyCode: "CNY")
        XCTAssertGreaterThanOrEqual(distribution.count, 5)
        XCTAssertEqual(distribution.first?.amount.formatted(), "¥1,810.00")
    }

    @MainActor
    func testProfileParsingRecognizesScreenshotShowcase() {
        let profile = DemoDataSeeder.profile(from: ["NUMI_SEED_PROFILE": "screenshot_showcase"])
        XCTAssertEqual(profile, .screenshotShowcase)
    }

    @MainActor
    func testSeedsDefaultsOnlyOnce() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)

        try store.seedDefaultsIfNeeded()
        try store.seedDefaultsIfNeeded()

        XCTAssertEqual(store.ledgers.count, 1)
        XCTAssertEqual(store.categories.filter { $0.kind == .expense }.count, 28)
        XCTAssertEqual(store.categories.filter { $0.kind == .income }.count, 19)
        XCTAssertEqual(store.accounts.count, 2)
        XCTAssertEqual(store.defaultLedger()?.builtInKey, "ledger.default.name")
        XCTAssertEqual(store.accounts.first { $0.type == .cash }?.builtInKey, "account.default.cash")
        XCTAssertEqual(
            store.categories.first { $0.kind == .expense && $0.icon == "acai-bowl" }?.builtInKey,
            "category.default.expense.dining"
        )
    }

    @MainActor
    func testSeedDefaultsBackfillsBuiltInKeysForLegacySnapshotData() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        let legacySnapshot = BookkeepingSnapshot(
            ledgers: [Ledger(name: "默认账本", currencyCode: "CNY")],
            categories: [
                Category(kind: .expense, name: "餐饮", icon: "acai-bowl", sortOrder: 0),
                Category(kind: .income, name: "工资", icon: "cash", sortOrder: 0)
            ],
            accounts: [
                Account(name: "现金", type: .cash, balance: .zero(currencyCode: "CNY")),
                Account(name: "银行卡", type: .debitCard, balance: .zero(currencyCode: "CNY"))
            ]
        )

        try store.importSnapshot(legacySnapshot)

        UserDefaults.standard.set("en", forKey: languageKey)
        try store.seedDefaultsIfNeeded()

        XCTAssertEqual(store.defaultLedger()?.builtInKey, "ledger.default.name")
        XCTAssertEqual(store.defaultLedger()?.localizedDisplayName, "Default Ledger")
        XCTAssertEqual(store.accounts.first { $0.type == .cash }?.builtInKey, "account.default.cash")
        XCTAssertEqual(store.accounts.first { $0.type == .cash }?.localizedDisplayName, "Cash")
        XCTAssertEqual(
            store.categories.first { $0.kind == .expense && $0.icon == "acai-bowl" }?.builtInKey,
            "category.default.expense.dining"
        )
        XCTAssertEqual(
            store.categories.first { $0.kind == .expense && $0.icon == "acai-bowl" }?.localizedDisplayName,
            "Dining"
        )
    }

    @MainActor
    func testCreatesExpenseAndUpdatesAccountBalance() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let accountID = try XCTUnwrap(store.accounts.first?.id)
        let foodID = try XCTUnwrap(store.categories.first { $0.name == "餐饮" }?.id)

        let transaction = try store.createTransaction(
            type: .expense,
            amount: Money(decimalString: "32.50", currencyCode: "CNY"),
            categoryID: foodID,
            accountID: accountID,
            ledgerID: store.ledgers.first!.id,
            note: "午餐"
        )

        XCTAssertEqual(transaction.note, "午餐")
        XCTAssertEqual(store.visibleTransactions.count, 1)
        XCTAssertEqual(store.accounts.first?.balance.formatted(), "-¥32.50")
    }

    @MainActor
    func testAppendingImportedTransactionsUpdatesAccountBalance() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let accountID = try XCTUnwrap(store.accounts.first?.id)
        let ledgerID = try XCTUnwrap(store.ledgers.first?.id)

        try store.appendTransactions([
            Transaction(
                type: .expense,
                amount: Money(decimalString: "12.30", currencyCode: "CNY"),
                accountID: accountID,
                ledgerID: ledgerID,
                note: "CSV 午餐"
            )
        ])

        XCTAssertEqual(store.visibleTransactions.count, 1)
        XCTAssertEqual(store.accounts.first?.balance.formatted(), "-¥12.30")
    }

    @MainActor
    func testPersistsTransactionsWhenStoreIsReopened() throws {
        let url = try temporaryStoreURL()
        do {
            let store = try SwiftDataBookkeepingStore(storeURL: url)
            try store.seedDefaultsIfNeeded()
            let accountID = try XCTUnwrap(store.accounts.first?.id)
            let foodID = try XCTUnwrap(store.categories.first { $0.name == "餐饮" }?.id)
            _ = try store.createTransaction(
                type: .expense,
                amount: Money(decimalString: "12", currencyCode: "CNY"),
                categoryID: foodID,
                accountID: accountID,
                ledgerID: store.ledgers.first!.id,
                note: "早餐"
            )
        }

        let reopenedStore = try SwiftDataBookkeepingStore(storeURL: url)
        try reopenedStore.seedDefaultsIfNeeded()

        XCTAssertEqual(reopenedStore.visibleTransactions.count, 1)
        XCTAssertEqual(reopenedStore.visibleTransactions.first?.note, "早餐")
        XCTAssertEqual(reopenedStore.accounts.first?.balance.formatted(), "-¥12.00")
    }

    @MainActor
    func testSoftDeleteAndRestoreTransactionReversesAccountBalance() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let accountID = try XCTUnwrap(store.accounts.first?.id)
        let foodID = try XCTUnwrap(store.categories.first { $0.name == "餐饮" }?.id)
        let transaction = try store.createTransaction(
            type: .expense,
            amount: Money(decimalString: "45", currencyCode: "CNY"),
            categoryID: foodID,
            accountID: accountID,
            ledgerID: store.ledgers.first!.id,
            note: "晚餐"
        )

        try store.softDeleteTransaction(id: transaction.id)

        XCTAssertTrue(store.visibleTransactions.isEmpty)
        XCTAssertEqual(store.accounts.first?.balance.formatted(), "¥0.00")

        try store.restoreTransaction(id: transaction.id)

        XCTAssertEqual(store.visibleTransactions.map(\.id), [transaction.id])
        XCTAssertEqual(store.accounts.first?.balance.formatted(), "-¥45.00")
    }

    @MainActor
    func testProcessDueSubscriptionsCreatesExpensesAndIsIdempotent() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let account = try XCTUnwrap(store.accounts.first)
        let categoryID = try XCTUnwrap(store.categories.first(where: { $0.kind == .expense })?.id)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))
        let through = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 3)))
        try store.createSubscription(Subscription(
            name: "Daily",
            amount: Money(minorUnits: 1000, currencyCode: account.balance.currencyCode),
            cycle: .daily,
            categoryID: categoryID,
            accountID: account.id,
            nextBillingDate: start
        ))

        XCTAssertEqual(try store.processDueSubscriptions(asOf: through, calendar: calendar), 3)
        XCTAssertEqual(store.visibleTransactions.count, 3)
        XCTAssertEqual(store.accounts.first?.balance.formatted(), "-¥30.00")
        XCTAssertEqual(try store.processDueSubscriptions(asOf: through, calendar: calendar), 0)
    }

    @MainActor
    func testSkippingNextSubscriptionBillingAdvancesDateWithoutTransaction() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let account = try XCTUnwrap(store.accounts.first)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))
        let subscription = Subscription(
            name: "Daily",
            amount: Money(minorUnits: 1000, currencyCode: account.balance.currencyCode),
            cycle: .daily,
            accountID: account.id,
            nextBillingDate: start
        )
        try store.createSubscription(subscription)

        XCTAssertTrue(try store.skipNextSubscriptionBilling(id: subscription.id, calendar: calendar))
        XCTAssertEqual(store.subscriptions.first?.nextBillingDate, calendar.date(byAdding: .day, value: 1, to: start))
        XCTAssertTrue(store.subscriptions.first?.isEnabled == true)
        XCTAssertTrue(store.visibleTransactions.isEmpty)
        XCTAssertFalse(try store.skipNextSubscriptionBilling(id: UUID(), calendar: calendar))
    }

    @MainActor
    func testRecordingNextSubscriptionBillingCreatesOneExpenseAndAdvancesDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let account = try XCTUnwrap(store.accounts.first)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))
        let subscription = Subscription(
            name: "Monthly",
            amount: Money(minorUnits: 1000, currencyCode: account.balance.currencyCode),
            cycle: .monthly,
            accountID: account.id,
            nextBillingDate: start
        )
        try store.createSubscription(subscription)

        let transaction = try XCTUnwrap(
            try store.recordNextSubscriptionBilling(id: subscription.id, asOf: start, calendar: calendar)
        )
        XCTAssertEqual(transaction.type, .expense)
        XCTAssertEqual(transaction.occurredAt, start)
        XCTAssertEqual(store.visibleTransactions.count, 1)
        XCTAssertEqual(store.subscriptions.first?.nextBillingDate, calendar.date(byAdding: .month, value: 1, to: start))
        XCTAssertNil(try store.recordNextSubscriptionBilling(id: subscription.id, asOf: start, calendar: calendar))
    }

    @MainActor
    func testSkippingQuarterlySubscriptionAdvancesDateByThreeMonths() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let account = try XCTUnwrap(store.accounts.first)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))
        let subscription = Subscription(
            name: "Quarterly",
            amount: Money(minorUnits: 1000, currencyCode: account.balance.currencyCode),
            cycle: .quarterly,
            accountID: account.id,
            nextBillingDate: start
        )
        try store.createSubscription(subscription)

        XCTAssertTrue(try store.skipNextSubscriptionBilling(id: subscription.id, calendar: calendar))
        XCTAssertEqual(store.subscriptions.first?.nextBillingDate, calendar.date(byAdding: .month, value: 3, to: start))
    }

    @MainActor
    func testSkippingMonthEndSubscriptionAdvancesToFollowingMonthEnd() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let account = try XCTUnwrap(store.accounts.first)
        let januaryEnd = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 31)))
        let februaryEnd = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 2, day: 28)))
        let subscription = Subscription(
            name: "Month end",
            amount: Money(minorUnits: 1000, currencyCode: account.balance.currencyCode),
            cycle: .monthEnd,
            accountID: account.id,
            nextBillingDate: januaryEnd
        )
        try store.createSubscription(subscription)

        XCTAssertTrue(try store.skipNextSubscriptionBilling(id: subscription.id, calendar: calendar))
        XCTAssertEqual(store.subscriptions.first?.nextBillingDate, februaryEnd)
    }

    @MainActor
    func testSkippingWeekdaySubscriptionAdvancesFromFridayToMonday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let account = try XCTUnwrap(store.accounts.first)
        let friday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 4, day: 4)))
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 4, day: 7)))
        let subscription = Subscription(
            name: "Weekday",
            amount: Money(minorUnits: 1000, currencyCode: account.balance.currencyCode),
            cycle: .weekdays,
            accountID: account.id,
            nextBillingDate: friday
        )
        try store.createSubscription(subscription)

        XCTAssertTrue(try store.skipNextSubscriptionBilling(id: subscription.id, calendar: calendar))
        XCTAssertEqual(store.subscriptions.first?.nextBillingDate, monday)
    }

    @MainActor
    func testSkippingMonthlyFirstWeekdaySubscriptionAdvancesToFirstWeekdayOfFollowingMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let account = try XCTUnwrap(store.accounts.first)
        let mayFirst = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 5, day: 1)))
        let juneSecond = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 6, day: 2)))
        let subscription = Subscription(
            name: "First weekday",
            amount: Money(minorUnits: 1000, currencyCode: account.balance.currencyCode),
            cycle: .monthlyFirstWeekday,
            accountID: account.id,
            nextBillingDate: mayFirst
        )
        try store.createSubscription(subscription)

        XCTAssertTrue(try store.skipNextSubscriptionBilling(id: subscription.id, calendar: calendar))
        XCTAssertEqual(store.subscriptions.first?.nextBillingDate, juneSecond)
    }

    @MainActor
    func testCustomSubscriptionIntervalPersists() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        let interval = try XCTUnwrap(SubscriptionInterval(value: 2, unit: .month))
        let subscription = Subscription(
            name: "Bi-monthly",
            amount: Money(minorUnits: 1200, currencyCode: "CNY"),
            cycle: .custom,
            customInterval: interval,
            nextBillingDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        try store.createSubscription(subscription)

        XCTAssertEqual(store.subscriptions.first?.customInterval, interval)
    }

    @MainActor
    func testSkippingCustomSubscriptionBillingAdvancesByConfiguredInterval() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let account = try XCTUnwrap(store.accounts.first)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))
        let subscription = Subscription(
            name: "Every two weeks",
            amount: Money(minorUnits: 1000, currencyCode: account.balance.currencyCode),
            cycle: .custom,
            customInterval: try XCTUnwrap(SubscriptionInterval(value: 2, unit: .week)),
            accountID: account.id,
            nextBillingDate: start
        )
        try store.createSubscription(subscription)

        XCTAssertTrue(try store.skipNextSubscriptionBilling(id: subscription.id, calendar: calendar))
        XCTAssertEqual(
            store.subscriptions.first?.nextBillingDate,
            calendar.date(byAdding: .weekOfYear, value: 2, to: start)
        )
    }

    @MainActor
    func testReschedulingPendingInstallmentPeriodPersistsDueDate() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let account = try XCTUnwrap(store.accounts.first)
        let plan = InstallmentPlan(
            name: "Phone",
            totalAmount: try Money(decimalString: "80", currencyCode: account.balance.currencyCode),
            feePerPeriod: .zero(currencyCode: account.balance.currencyCode),
            periodCount: 2,
            firstPaymentDate: Date(timeIntervalSince1970: 1_700_000_000),
            accountID: account.id
        )
        try store.createInstallmentPlan(plan)
        let period = try XCTUnwrap(store.installmentPeriods.first)
        let newDate = period.dueDate.addingTimeInterval(86_400 * 3)

        XCTAssertTrue(try store.rescheduleInstallmentPeriod(periodID: period.id, dueDate: newDate))
        XCTAssertEqual(store.installmentPeriods.first?.dueDate, newDate)
        XCTAssertFalse(try store.rescheduleInstallmentPeriod(periodID: UUID(), dueDate: newDate))
    }

    @MainActor
    func testUpdatingInstallmentPlanPreservesRecordedPeriodsAndTransactions() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let account = try XCTUnwrap(store.accounts.first)
        let ledgerID = try XCTUnwrap(store.ledgers.first?.id)
        let categoryID = try XCTUnwrap(store.categories.first(where: { $0.kind == .expense })?.id)
        let plan = InstallmentPlan(
            name: "Phone",
            totalAmount: Money(minorUnits: 10_000, currencyCode: account.balance.currencyCode),
            feePerPeriod: .zero(currencyCode: account.balance.currencyCode),
            periodCount: 2,
            firstPaymentDate: Date(timeIntervalSince1970: 1_700_000_000),
            accountID: account.id,
            categoryID: categoryID,
            note: "old note"
        )
        try store.createInstallmentPlan(plan)
        let firstPeriod = try XCTUnwrap(store.installmentPeriods.first(where: { $0.periodIndex == 0 }))
        let secondPeriod = try XCTUnwrap(store.installmentPeriods.first(where: { $0.periodIndex == 1 }))
        let adjustedSecondDueDate = secondPeriod.dueDate.addingTimeInterval(86_400 * 3)
        XCTAssertTrue(try store.rescheduleInstallmentPeriod(periodID: secondPeriod.id, dueDate: adjustedSecondDueDate))
        let recordedTransaction = try store.recordInstallmentPayment(periodID: firstPeriod.id, ledgerID: ledgerID)

        var updatedPlan = plan
        updatedPlan.name = "Renamed phone"
        updatedPlan.totalAmount = Money(minorUnits: 12_000, currencyCode: account.balance.currencyCode)
        updatedPlan.note = "new note"
        try store.updateInstallmentPlan(updatedPlan)

        XCTAssertEqual(store.installmentPlans.first?.name, "Renamed phone")
        XCTAssertEqual(store.installmentPlans.first?.note, "new note")
        XCTAssertEqual(store.installmentPeriods.count, 2)
        XCTAssertEqual(store.installmentPeriods.first(where: { $0.id == firstPeriod.id })?.transactionID, recordedTransaction.id)
        XCTAssertTrue(store.installmentPeriods.first(where: { $0.id == firstPeriod.id })?.isPaid == true)
        XCTAssertEqual(store.installmentPeriods.first(where: { $0.id == secondPeriod.id })?.dueDate, adjustedSecondDueDate)
        XCTAssertEqual(store.visibleTransactions.map(\.id), [recordedTransaction.id])
    }

    @MainActor
    func testRecordingInstallmentPaymentCreatesAndBindsExpenseTransaction() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let account = try XCTUnwrap(store.accounts.first)
        let ledgerID = try XCTUnwrap(store.ledgers.first?.id)
        let categoryID = try XCTUnwrap(store.categories.first(where: { $0.kind == .expense })?.id)
        let plan = InstallmentPlan(
            name: "Laptop",
            totalAmount: try Money(decimalString: "120", currencyCode: account.balance.currencyCode),
            feePerPeriod: .zero(currencyCode: account.balance.currencyCode),
            periodCount: 2,
            firstPaymentDate: Date(timeIntervalSince1970: 1_700_000_000),
            accountID: account.id,
            categoryID: categoryID
        )
        try store.createInstallmentPlan(plan)
        let period = try XCTUnwrap(store.installmentPeriods.first)

        let transaction = try store.recordInstallmentPayment(
            periodID: period.id,
            ledgerID: ledgerID,
            occurredAt: period.dueDate
        )

        XCTAssertEqual(transaction.type, .expense)
        XCTAssertEqual(transaction.amount, plan.amountPerPeriod)
        XCTAssertEqual(store.visibleTransactions.map(\.id), [transaction.id])
        XCTAssertEqual(store.installmentPeriods.first?.transactionID, transaction.id)
        XCTAssertTrue(store.installmentPeriods.first?.isPaid == true)
        XCTAssertTrue(store.installmentPeriods.first?.isRecorded == true)
        XCTAssertEqual(store.accounts.first?.balance, try account.balance.subtracting(plan.amountPerPeriod))

        let repeatedTransaction = try store.recordInstallmentPayment(periodID: period.id, ledgerID: ledgerID)
        XCTAssertEqual(repeatedTransaction.id, transaction.id)
        XCTAssertEqual(store.visibleTransactions.count, 1)
        XCTAssertEqual(store.accounts.first?.balance, try account.balance.subtracting(plan.amountPerPeriod))
    }

    @MainActor
    func testRecordingInstallmentPaymentUsesDefaultsWhenPlanHasNoAccountOrCategory() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let account = try XCTUnwrap(store.accounts.first)
        let ledgerID = try XCTUnwrap(store.ledgers.first?.id)
        let plan = InstallmentPlan(
            name: "Unassigned plan",
            totalAmount: try Money(decimalString: "50", currencyCode: account.balance.currencyCode),
            feePerPeriod: .zero(currencyCode: account.balance.currencyCode),
            periodCount: 1,
            firstPaymentDate: Date()
        )
        try store.createInstallmentPlan(plan)
        let period = try XCTUnwrap(store.installmentPeriods.first)

        let transaction = try store.recordInstallmentPayment(periodID: period.id, ledgerID: ledgerID)

        XCTAssertEqual(transaction.accountID, account.id)
        XCTAssertNotNil(transaction.categoryID)
        XCTAssertEqual(store.visibleTransactions.count, 1)
    }

    @MainActor
    func testUnpayingBoundInstallmentPeriodReversesAndUnlinksTransaction() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let account = try XCTUnwrap(store.accounts.first)
        let ledgerID = try XCTUnwrap(store.ledgers.first?.id)
        let categoryID = try XCTUnwrap(store.categories.first(where: { $0.kind == .expense })?.id)
        let plan = InstallmentPlan(
            name: "Phone",
            totalAmount: try Money(decimalString: "80", currencyCode: account.balance.currencyCode),
            feePerPeriod: .zero(currencyCode: account.balance.currencyCode),
            periodCount: 1,
            firstPaymentDate: Date(),
            accountID: account.id,
            categoryID: categoryID
        )
        try store.createInstallmentPlan(plan)
        let period = try XCTUnwrap(store.installmentPeriods.first)
        _ = try store.recordInstallmentPayment(periodID: period.id, ledgerID: ledgerID)

        var unpaid = try XCTUnwrap(store.installmentPeriods.first)
        unpaid.isPaid = false
        unpaid.isRecorded = false
        try store.updateInstallmentPeriod(unpaid)

        XCTAssertTrue(store.visibleTransactions.isEmpty)
        XCTAssertEqual(store.accounts.first?.balance, account.balance)
        XCTAssertNil(store.installmentPeriods.first?.transactionID)
    }

    @MainActor
    func testSettlingInstallmentPlanRecordsAllRemainingPeriodsIdempotently() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let account = try XCTUnwrap(store.accounts.first)
        let ledgerID = try XCTUnwrap(store.ledgers.first?.id)
        let categoryID = try XCTUnwrap(store.categories.first(where: { $0.kind == .expense })?.id)
        let plan = InstallmentPlan(
            name: "Camera",
            totalAmount: try Money(decimalString: "90", currencyCode: account.balance.currencyCode),
            feePerPeriod: .zero(currencyCode: account.balance.currencyCode),
            periodCount: 3,
            firstPaymentDate: Date(),
            accountID: account.id,
            categoryID: categoryID
        )
        try store.createInstallmentPlan(plan)

        XCTAssertEqual(
            try store.settleInstallmentPlan(planID: plan.id, ledgerID: ledgerID, occurredAt: Date()),
            3
        )
        XCTAssertTrue(store.installmentPeriods.allSatisfy(\.isPaid))
        XCTAssertEqual(store.visibleTransactions.count, 3)
        XCTAssertEqual(store.accounts.first?.balance, try account.balance.subtracting(Money(decimalString: "90", currencyCode: account.balance.currencyCode)))
        XCTAssertEqual(try store.settleInstallmentPlan(planID: plan.id, ledgerID: ledgerID), 0)
        XCTAssertEqual(store.visibleTransactions.count, 3)
    }

    @MainActor
    func testSkippingPendingInstallmentPeriodDoesNotCreateTransaction() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let account = try XCTUnwrap(store.accounts.first)
        let plan = InstallmentPlan(
            name: "Desk",
            totalAmount: try Money(decimalString: "100", currencyCode: account.balance.currencyCode),
            feePerPeriod: .zero(currencyCode: account.balance.currencyCode),
            periodCount: 1,
            firstPaymentDate: Date(),
            accountID: account.id,
            categoryID: try XCTUnwrap(store.categories.first(where: { $0.kind == .expense })?.id)
        )
        try store.createInstallmentPlan(plan)
        let period = try XCTUnwrap(store.installmentPeriods.first)

        try store.skipInstallmentPeriod(periodID: period.id)

        XCTAssertTrue(store.installmentPeriods.first?.isSkipped == true)
        XCTAssertFalse(store.installmentPeriods.first?.isPaid == true)
        XCTAssertNil(store.installmentPeriods.first?.transactionID)
        XCTAssertTrue(store.visibleTransactions.isEmpty)
        XCTAssertEqual(store.accounts.first?.balance, account.balance)
    }

    @MainActor
    func testUpdatingTransactionReversesOldBalanceAndAppliesNewBalance() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let accountID = try XCTUnwrap(store.accounts.first?.id)
        let foodID = try XCTUnwrap(store.categories.first { $0.name == "餐饮" }?.id)
        let salaryID = try XCTUnwrap(store.categories.first { $0.name == "工资" }?.id)
        let transaction = try store.createTransaction(
            type: .expense,
            amount: Money(decimalString: "20", currencyCode: "CNY"),
            categoryID: foodID,
            accountID: accountID,
            ledgerID: store.ledgers.first!.id,
            note: "午餐"
        )

        let updated = try store.updateTransaction(
            id: transaction.id,
            type: .income,
            amount: Money(decimalString: "120", currencyCode: "CNY"),
            categoryID: salaryID,
            accountID: accountID,
            note: "兼职"
        )

        XCTAssertEqual(updated.type, .income)
        XCTAssertEqual(updated.note, "兼职")
        XCTAssertEqual(store.visibleTransactions.count, 1)
        XCTAssertEqual(store.visibleTransactions.first?.amount.formatted(), "¥120.00")
        XCTAssertEqual(store.accounts.first?.balance.formatted(), "¥120.00")
    }

    @MainActor
    func testUpdatingTransactionToAnotherAccountMovesBalanceEffect() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let cashID = try XCTUnwrap(store.accounts.first?.id)
        let alipay = try store.createAccount(
            name: "支付宝",
            type: .alipay,
            balance: .zero(currencyCode: "CNY"),
            isIncludedInAssets: true,
            isHidden: false
        )
        let foodID = try XCTUnwrap(store.categories.first { $0.name == "餐饮" }?.id)
        let transaction = try store.createTransaction(
            type: .expense,
            amount: Money(decimalString: "20", currencyCode: "CNY"),
            categoryID: foodID,
            accountID: cashID,
            ledgerID: store.ledgers.first!.id,
            note: "午餐"
        )

        let updated = try store.updateTransaction(
            id: transaction.id,
            type: .expense,
            amount: Money(decimalString: "35", currencyCode: "CNY"),
            categoryID: foodID,
            accountID: alipay.id,
            note: "晚餐"
        )

        XCTAssertEqual(updated.accountID, alipay.id)
        XCTAssertEqual(store.accounts.first { $0.id == cashID }?.balance.formatted(), "¥0.00")
        XCTAssertEqual(store.accounts.first { $0.id == alipay.id }?.balance.formatted(), "-¥35.00")
    }

    @MainActor
    func testCreatesTransferAndUpdatesBothAccountBalancesWithoutAffectingSummary() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let cash = try XCTUnwrap(store.accounts.first { $0.name == "现金" })
        let card = try XCTUnwrap(store.accounts.first { $0.name == "银行卡" })

        let transfer = try store.createTransaction(
            type: .transfer,
            amount: Money(decimalString: "50", currencyCode: "CNY"),
            categoryID: nil,
            accountID: cash.id,
            targetAccountID: card.id,
            ledgerID: store.ledgers.first!.id,
            note: "备用金"
        )

        XCTAssertEqual(transfer.type, .transfer)
        XCTAssertEqual(transfer.accountID, cash.id)
        XCTAssertEqual(transfer.targetAccountID, card.id)
        XCTAssertEqual(store.accounts.first { $0.id == cash.id }?.balance.formatted(), "-¥50.00")
        XCTAssertEqual(store.accounts.first { $0.id == card.id }?.balance.formatted(), "¥50.00")

        let summary = try TransactionSummary.monthly(transactions: store.visibleTransactions, currencyCode: "CNY")
        XCTAssertEqual(summary.expense.formatted(), "¥0.00")
        XCTAssertEqual(summary.income.formatted(), "¥0.00")

        try store.softDeleteTransaction(id: transfer.id)
        XCTAssertEqual(store.accounts.first { $0.id == cash.id }?.balance.formatted(), "¥0.00")
        XCTAssertEqual(store.accounts.first { $0.id == card.id }?.balance.formatted(), "¥0.00")

        try store.restoreTransaction(id: transfer.id)
        XCTAssertEqual(store.accounts.first { $0.id == cash.id }?.balance.formatted(), "-¥50.00")
        XCTAssertEqual(store.accounts.first { $0.id == card.id }?.balance.formatted(), "¥50.00")
    }

    @MainActor
    func testUpdatingTransferReversesOldAccountsAndAppliesNewAccounts() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let cash = try XCTUnwrap(store.accounts.first { $0.name == "现金" })
        let card = try XCTUnwrap(store.accounts.first { $0.name == "银行卡" })
        let alipay = try store.createAccount(
            name: "支付宝",
            type: .alipay,
            balance: .zero(currencyCode: "CNY"),
            isIncludedInAssets: true,
            isHidden: false
        )
        let transfer = try store.createTransaction(
            type: .transfer,
            amount: Money(decimalString: "50", currencyCode: "CNY"),
            categoryID: nil,
            accountID: cash.id,
            targetAccountID: card.id,
            ledgerID: store.ledgers.first!.id,
            note: "备用金"
        )

        let updated = try store.updateTransaction(
            id: transfer.id,
            type: .transfer,
            amount: Money(decimalString: "30", currencyCode: "CNY"),
            categoryID: nil,
            accountID: card.id,
            targetAccountID: alipay.id,
            note: "转支付宝"
        )

        XCTAssertEqual(updated.accountID, card.id)
        XCTAssertEqual(updated.targetAccountID, alipay.id)
        XCTAssertEqual(store.accounts.first { $0.id == cash.id }?.balance.formatted(), "¥0.00")
        XCTAssertEqual(store.accounts.first { $0.id == card.id }?.balance.formatted(), "-¥30.00")
        XCTAssertEqual(store.accounts.first { $0.id == alipay.id }?.balance.formatted(), "¥30.00")
    }

    @MainActor
    func testTransferRequiresDistinctSourceAndTargetAccounts() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let cash = try XCTUnwrap(store.accounts.first { $0.name == "现金" })
        let ledgerID = try XCTUnwrap(store.ledgers.first?.id)

        XCTAssertThrowsError(try store.createTransaction(
            type: .transfer,
            amount: Money(decimalString: "50", currencyCode: "CNY"),
            categoryID: nil,
            accountID: cash.id,
            ledgerID: ledgerID,
            note: "缺少转入账户"
        )) { error in
            XCTAssertEqual(error as? SwiftDataBookkeepingStoreError, .transferTargetRequired)
        }

        XCTAssertThrowsError(try store.createTransaction(
            type: .transfer,
            amount: Money(decimalString: "50", currencyCode: "CNY"),
            categoryID: nil,
            accountID: cash.id,
            targetAccountID: cash.id,
            ledgerID: ledgerID,
            note: "相同账户"
        )) { error in
            XCTAssertEqual(error as? SwiftDataBookkeepingStoreError, .transferAccountsMustDiffer)
        }

        XCTAssertTrue(store.visibleTransactions.isEmpty)
        XCTAssertEqual(store.accounts.first { $0.id == cash.id }?.balance.minorUnits, 0)
    }

    @MainActor
    func testTransferRejectsCurrencyMismatchWithoutPersistingOrChangingBalances() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let cash = try XCTUnwrap(store.accounts.first { $0.name == "现金" })
        let ledgerID = try XCTUnwrap(store.ledgers.first?.id)
        let usd = try store.createAccount(
            name: "美元账户",
            type: .other,
            balance: Money(decimalString: "100", currencyCode: "USD")
        )

        XCTAssertThrowsError(try store.createTransaction(
            type: .transfer,
            amount: Money(decimalString: "50", currencyCode: "CNY"),
            categoryID: nil,
            accountID: cash.id,
            targetAccountID: usd.id,
            ledgerID: ledgerID,
            note: "跨币种转账"
        )) { error in
            XCTAssertEqual(error as? SwiftDataBookkeepingStoreError, .transferCurrencyMismatch)
        }

        XCTAssertTrue(store.visibleTransactions.isEmpty)
        XCTAssertEqual(store.accounts.first { $0.id == cash.id }?.balance.minorUnits, 0)
        XCTAssertEqual(store.accounts.first { $0.id == usd.id }?.balance.minorUnits, 10000)
    }

    @MainActor
    func testInvalidTransferUpdateLeavesOriginalTransactionAndBalancesUntouched() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let cash = try XCTUnwrap(store.accounts.first { $0.name == "现金" })
        let card = try XCTUnwrap(store.accounts.first { $0.name == "银行卡" })
        let ledgerID = try XCTUnwrap(store.ledgers.first?.id)
        let transfer = try store.createTransaction(
            type: .transfer,
            amount: Money(decimalString: "50", currencyCode: "CNY"),
            categoryID: nil,
            accountID: cash.id,
            targetAccountID: card.id,
            ledgerID: ledgerID,
            note: "原始转账"
        )

        XCTAssertThrowsError(try store.updateTransaction(
            id: transfer.id,
            type: .transfer,
            amount: Money(decimalString: "30", currencyCode: "CNY"),
            categoryID: nil,
            accountID: card.id,
            targetAccountID: card.id,
            note: "无效更新"
        )) { error in
            XCTAssertEqual(error as? SwiftDataBookkeepingStoreError, .transferAccountsMustDiffer)
        }

        let persisted = try XCTUnwrap(store.visibleTransactions.first { $0.id == transfer.id })
        XCTAssertEqual(persisted.amount.minorUnits, 5000)
        XCTAssertEqual(persisted.accountID, cash.id)
        XCTAssertEqual(persisted.targetAccountID, card.id)
        XCTAssertEqual(store.accounts.first { $0.id == cash.id }?.balance.minorUnits, -5000)
        XCTAssertEqual(store.accounts.first { $0.id == card.id }?.balance.minorUnits, 5000)
    }

    @MainActor
    func testUpdatesCategoryVisibilityAndPersistsIt() throws {
        let url = try temporaryStoreURL()
        let foodID: UUID
        do {
            let store = try SwiftDataBookkeepingStore(storeURL: url)
            try store.seedDefaultsIfNeeded()
            foodID = try XCTUnwrap(store.categories.first { $0.name == "餐饮" }?.id)

            let updated = try store.updateCategoryVisibility(id: foodID, isHidden: true)

            XCTAssertTrue(updated.isHidden)
            XCTAssertTrue(try XCTUnwrap(store.categories.first { $0.id == foodID }).isHidden)
        }

        let reopenedStore = try SwiftDataBookkeepingStore(storeURL: url)
        try reopenedStore.seedDefaultsIfNeeded()

        XCTAssertTrue(try XCTUnwrap(reopenedStore.categories.first { $0.id == foodID }).isHidden)
    }

    @MainActor
    func testUpdatesAccountVisibilityAndPersistsIt() throws {
        let url = try temporaryStoreURL()
        let cardID: UUID
        do {
            let store = try SwiftDataBookkeepingStore(storeURL: url)
            try store.seedDefaultsIfNeeded()
            cardID = try XCTUnwrap(store.accounts.first { $0.name == "银行卡" }?.id)

            let updated = try store.updateAccountVisibility(id: cardID, isHidden: true)

            XCTAssertTrue(updated.isHidden)
            XCTAssertTrue(try XCTUnwrap(store.accounts.first { $0.id == cardID }).isHidden)
        }

        let reopenedStore = try SwiftDataBookkeepingStore(storeURL: url)
        try reopenedStore.seedDefaultsIfNeeded()

        XCTAssertTrue(try XCTUnwrap(reopenedStore.accounts.first { $0.id == cardID }).isHidden)
    }

    @MainActor
    func testCreatesAccountWithEditableFieldsAndPersistsIt() throws {
        let url = try temporaryStoreURL()
        let accountID: UUID
        do {
            let store = try SwiftDataBookkeepingStore(storeURL: url)
            try store.seedDefaultsIfNeeded()

            let account = try store.createAccount(
                name: "招商储蓄卡",
                type: .debitCard,
                balance: Money(decimalString: "1288.66", currencyCode: "CNY"),
                isIncludedInAssets: false,
                isHidden: true
            )

            accountID = account.id
            XCTAssertEqual(account.name, "招商储蓄卡")
            XCTAssertEqual(account.type, .debitCard)
            XCTAssertEqual(account.balance.formatted(), "¥1,288.66")
            XCTAssertFalse(account.isIncludedInAssets)
            XCTAssertTrue(account.isHidden)
        }

        let reopenedStore = try SwiftDataBookkeepingStore(storeURL: url)
        try reopenedStore.seedDefaultsIfNeeded()
        let persisted = try XCTUnwrap(reopenedStore.accounts.first { $0.id == accountID })

        XCTAssertEqual(persisted.name, "招商储蓄卡")
        XCTAssertEqual(persisted.type, .debitCard)
        XCTAssertEqual(persisted.balance.formatted(), "¥1,288.66")
        XCTAssertFalse(persisted.isIncludedInAssets)
        XCTAssertTrue(persisted.isHidden)
    }

    @MainActor
    func testUpdatesAccountEditableFieldsAndPersistsThem() throws {
        let url = try temporaryStoreURL()
        let accountID: UUID
        do {
            let store = try SwiftDataBookkeepingStore(storeURL: url)
            try store.seedDefaultsIfNeeded()
            accountID = try XCTUnwrap(store.accounts.first { $0.name == "银行卡" }?.id)

            let updated = try store.updateAccount(
                id: accountID,
                name: "工资卡",
                type: .creditCard,
                balance: Money(decimalString: "-300.25", currencyCode: "CNY"),
                isIncludedInAssets: false,
                isHidden: true
            )

            XCTAssertEqual(updated.name, "工资卡")
            XCTAssertEqual(updated.type, .creditCard)
            XCTAssertEqual(updated.balance.formatted(), "-¥300.25")
            XCTAssertFalse(updated.isIncludedInAssets)
            XCTAssertTrue(updated.isHidden)
            XCTAssertEqual(try XCTUnwrap(store.accounts.first { $0.id == accountID }).name, "工资卡")
        }

        let reopenedStore = try SwiftDataBookkeepingStore(storeURL: url)
        try reopenedStore.seedDefaultsIfNeeded()
        let persisted = try XCTUnwrap(reopenedStore.accounts.first { $0.id == accountID })

        XCTAssertEqual(persisted.name, "工资卡")
        XCTAssertEqual(persisted.type, .creditCard)
        XCTAssertEqual(persisted.balance.formatted(), "-¥300.25")
        XCTAssertFalse(persisted.isIncludedInAssets)
        XCTAssertTrue(persisted.isHidden)
    }

    @MainActor
    func testUpdatingDefaultAccountWithBuiltInNameKeepsBuiltInKey() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let cash = try XCTUnwrap(store.accounts.first { $0.type == .cash })

        let updated = try store.updateAccount(
            id: cash.id,
            name: "现金",
            type: .cash,
            balance: .zero(currencyCode: "CNY"),
            isIncludedInAssets: true,
            isHidden: false
        )

        XCTAssertEqual(updated.builtInKey, "account.default.cash")
        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(updated.localizedDisplayName, "Cash")
    }

    @MainActor
    func testUpdatingDefaultAccountWithCustomNameClearsBuiltInKey() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let cash = try XCTUnwrap(store.accounts.first { $0.type == .cash })

        let updated = try store.updateAccount(
            id: cash.id,
            name: "钱包现金",
            type: .cash,
            balance: .zero(currencyCode: "CNY"),
            isIncludedInAssets: true,
            isHidden: false
        )

        XCTAssertNil(updated.builtInKey)
        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(updated.localizedDisplayName, "钱包现金")
    }

    @MainActor
    func testUpdatingDefaultLedgerWithCustomNameClearsBuiltInKey() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        let ledger = try XCTUnwrap(store.defaultLedger())

        let updated = try store.updateLedger(
            id: ledger.id,
            name: "家庭总账本",
            currencyCode: "CNY"
        )

        XCTAssertNil(updated.builtInKey)
        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(updated.localizedDisplayName, "家庭总账本")
    }

    @MainActor
    func testUpsertsBudgetSettingsAndPersistsThem() throws {
        let url = try temporaryStoreURL()
        do {
            let store = try SwiftDataBookkeepingStore(storeURL: url)
            try store.seedDefaultsIfNeeded()

            let weekly = try store.upsertBudgetSetting(
                period: .week,
                amount: Money(decimalString: "500", currencyCode: "CNY"),
                isEnabled: true,
                ledgerID: store.ledgers.first!.id
            )
            let monthly = try store.upsertBudgetSetting(
                period: .month,
                amount: Money(decimalString: "3000", currencyCode: "CNY"),
                isEnabled: true,
                ledgerID: store.ledgers.first!.id
            )

            XCTAssertEqual(weekly.amount.formatted(), "¥500.00")
            XCTAssertEqual(monthly.amount.formatted(), "¥3,000.00")
            XCTAssertEqual(store.budgetSettings.count, 2)
        }

        let reopenedStore = try SwiftDataBookkeepingStore(storeURL: url)
        try reopenedStore.seedDefaultsIfNeeded()

        XCTAssertEqual(reopenedStore.budgetSettings.first { $0.period == .week }?.amount.formatted(), "¥500.00")
        XCTAssertEqual(reopenedStore.budgetSettings.first { $0.period == .month }?.amount.formatted(), "¥3,000.00")
    }

    @MainActor
    func testCategoryBudgetAndTransactionLinksPersist() throws {
        let url = try temporaryStoreURL()
        let categoryID: UUID
        let accountID: UUID
        let ledgerID: UUID
        let originalID = UUID()
        do {
            let store = try SwiftDataBookkeepingStore(storeURL: url)
            try store.seedDefaultsIfNeeded()
            categoryID = try XCTUnwrap(store.categories.first { $0.kind == .expense }.map(\.id))
            accountID = try XCTUnwrap(store.accounts.first.map(\.id))
            ledgerID = try XCTUnwrap(store.ledgers.first.map(\.id))
            _ = try store.upsertBudgetSetting(
                period: .month,
                amount: Money(decimalString: "1000", currencyCode: "CNY"),
                isEnabled: true,
                ledgerID: ledgerID,
                categoryID: categoryID,
                accountID: accountID
            )
            _ = try store.createTransaction(
                type: .expense,
                amount: Money(decimalString: "120", currencyCode: "CNY"),
                categoryID: categoryID,
                accountID: accountID,
                ledgerID: ledgerID,
                note: "报销待处理",
                reimbursementID: UUID()
            )
            try store.appendTransactions([
                Transaction(
                    id: originalID,
                    type: .expense,
                    amount: Money(decimalString: "80", currencyCode: "CNY"),
                    categoryID: categoryID,
                    accountID: accountID,
                    ledgerID: ledgerID
                ),
                Transaction(
                    type: .income,
                    amount: Money(decimalString: "20", currencyCode: "CNY"),
                    categoryID: categoryID,
                    accountID: accountID,
                    ledgerID: ledgerID,
                    refundOfTransactionID: originalID
                )
            ])
        }

        let reopenedStore = try SwiftDataBookkeepingStore(storeURL: url)
        XCTAssertEqual(reopenedStore.budgetSettings.first { $0.categoryID == categoryID }?.accountID, accountID)
        XCTAssertEqual(reopenedStore.visibleTransactions.first { $0.reimbursementID != nil }?.note, "报销待处理")
        XCTAssertEqual(reopenedStore.visibleTransactions.first { $0.refundOfTransactionID == originalID }?.amount, try Money(decimalString: "20", currencyCode: "CNY"))
    }

    @MainActor
    func testImportSnapshotReplacesExistingSubscriptionsAndInstallmentData() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()
        try store.createSubscription(
            Subscription(
                name: "Stale subscription",
                amount: Money(minorUnits: 999, currencyCode: "CNY"),
                cycle: .monthly,
                nextBillingDate: Date()
            )
        )
        try store.createInstallmentPlan(
            InstallmentPlan(
                name: "Stale plan",
                totalAmount: Money(minorUnits: 9_999, currencyCode: "CNY"),
                feePerPeriod: Money(minorUnits: 0, currencyCode: "CNY"),
                periodCount: 2,
                firstPaymentDate: Date()
            )
        )
        let snapshot = BookkeepingSnapshot(ledgers: [Ledger(name: "Restored", currencyCode: "USD")])

        try store.importSnapshot(snapshot)

        let restoredSnapshot = store.exportSnapshot()
        XCTAssertEqual(restoredSnapshot.ledgers, snapshot.ledgers)
        XCTAssertEqual(restoredSnapshot.subscriptions, snapshot.subscriptions)
        XCTAssertEqual(restoredSnapshot.installmentPlans, snapshot.installmentPlans)
        XCTAssertEqual(restoredSnapshot.installmentPeriods, snapshot.installmentPeriods)
    }

    private func temporaryStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Numi.store")
    }
}
