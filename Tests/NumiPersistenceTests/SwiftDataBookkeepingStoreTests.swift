import XCTest
import Foundation
import NumiCore
@testable import NumiPersistence

final class SwiftDataBookkeepingStoreTests: XCTestCase {
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
        XCTAssertEqual(store.categories.filter { $0.kind == .expense }.count, 16)
        XCTAssertEqual(store.categories.filter { $0.kind == .income }.count, 8)
        XCTAssertEqual(store.accounts.count, 2)
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
            note: "午餐"
        )

        XCTAssertEqual(transaction.note, "午餐")
        XCTAssertEqual(store.visibleTransactions.count, 1)
        XCTAssertEqual(store.accounts.first?.balance.formatted(), "-¥32.50")
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
    func testUpsertsBudgetSettingsAndPersistsThem() throws {
        let url = try temporaryStoreURL()
        do {
            let store = try SwiftDataBookkeepingStore(storeURL: url)
            try store.seedDefaultsIfNeeded()

            let weekly = try store.upsertBudgetSetting(
                period: .week,
                amount: Money(decimalString: "500", currencyCode: "CNY"),
                isEnabled: true
            )
            let monthly = try store.upsertBudgetSetting(
                period: .month,
                amount: Money(decimalString: "3000", currencyCode: "CNY"),
                isEnabled: true
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

    private func temporaryStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Numi.store")
    }
}
