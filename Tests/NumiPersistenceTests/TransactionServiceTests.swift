import XCTest
import SwiftData
@testable import NumiCore
@testable import NumiPersistence

@MainActor
final class TransactionServiceTests: XCTestCase {
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

    // MARK: - Category Name Lookup

    func testAvailableCategoryNames() throws {
        // 通过主 store 验证默认分类存在
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()

        let names = store.categories.map(\.name)
        XCTAssertTrue(names.contains("餐饮"))
        XCTAssertTrue(names.contains("交通"))
        XCTAssertTrue(names.contains("工资"))
        XCTAssertTrue(names.contains("购物"))
    }

    func testLocalizedCategoryNamesTrackRuntimeLanguage() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertTrue(store.categories.localizedCategoryNames().contains("餐饮"))

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertTrue(store.categories.localizedCategoryNames().contains("Dining"))
    }

    func testResolveLocalizedCategoryCanMatchBuiltInAliasesAcrossLanguages() {
        let category = Category(
            kind: .expense,
            name: "__legacy_dining__",
            builtInKey: "category.default.expense.dining",
            icon: "acai-bowl",
            sortOrder: 0
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual([category].resolveLocalizedCategory(named: "Dining")?.id, category.id)
        XCTAssertEqual([category].resolveLocalizedCategory(named: "餐饮")?.id, category.id)
    }

    func testResolveLocalizedAccountCanMatchBuiltInAliasesAcrossLanguages() {
        let account = Account(
            name: "__legacy_cash__",
            builtInKey: "account.default.cash",
            type: .cash,
            balance: .zero(currencyCode: "CNY")
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual([account].resolveLocalizedAccount(named: "Cash")?.id, account.id)
        XCTAssertEqual([account].resolveLocalizedAccount(named: "现金")?.id, account.id)
    }

    func testCategoryCount() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()

        let expenseCategories = store.categories.filter { $0.kind == .expense }
        let incomeCategories = store.categories.filter { $0.kind == .income }

        XCTAssertGreaterThan(expenseCategories.count, 20)
        XCTAssertGreaterThan(incomeCategories.count, 10)
    }

    func testSeedDefaultsUseRuntimeLanguageForLedgerAndAccounts() throws {
        UserDefaults.standard.set("en", forKey: languageKey)

        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()

        XCTAssertEqual(store.ledgers.first?.name, "Default Ledger")
        XCTAssertEqual(store.accounts.first(where: { $0.type == .cash })?.name, "Cash")
        XCTAssertEqual(store.accounts.first(where: { $0.type == .debitCard })?.name, "Bank Card")
    }

    func testTransactionServiceErrorsTrackRuntimeLanguage() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(TransactionServiceError.noAccount.errorDescription, "没有可用账户")
        XCTAssertEqual(TransactionServiceError.noLedger.errorDescription, "没有可用账本")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(TransactionServiceError.noAccount.errorDescription, "No available account")
        XCTAssertEqual(TransactionServiceError.noLedger.errorDescription, "No available ledger")
    }

    func testTransactionServiceInitializationFailureIsLocalized() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(TransactionServiceError.initializationFailed.errorDescription, "无法初始化本地数据")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(TransactionServiceError.initializationFailed.errorDescription, "Unable to initialize local data")
    }

    func testTransactionServiceWritesToTheSharedAppStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TransactionServiceSharedStoreTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("Numi.store")
        let appStore = try SwiftDataBookkeepingStore(storeURL: storeURL)
        try appStore.seedDefaultsIfNeeded()
        let initialCount = appStore.visibleTransactions.count

        let service = TransactionService(storeURL: storeURL)
        XCTAssertTrue(service.isAvailable)

        let ledger = try XCTUnwrap(appStore.ledgers.first)
        let account = try XCTUnwrap(appStore.accounts.first)
        _ = try service.createTransaction(from: ParsedTransaction(
            type: .expense,
            amount: 28,
            categoryName: "餐饮",
            accountName: account.name,
            occurredAt: Date(timeIntervalSince1970: 1_725_000_000),
            note: "快捷指令午餐"
        ))

        let reopenedStore = try SwiftDataBookkeepingStore(storeURL: storeURL)
        XCTAssertEqual(reopenedStore.visibleTransactions.count, initialCount + 1)
        XCTAssertEqual(reopenedStore.visibleTransactions.last?.ledgerID, ledger.id)
        XCTAssertEqual(reopenedStore.visibleTransactions.last?.note, "快捷指令午餐")
    }

    func testTransactionServiceUsesTheRequestedCurrentLedgerAndCurrency() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TransactionServiceCurrentLedgerTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("Numi.store")
        let appStore = try SwiftDataBookkeepingStore(storeURL: storeURL)
        try appStore.seedDefaultsIfNeeded()
        let travelLedger = try appStore.createLedger(name: "Travel", currencyCode: "USD")
        let travelAccount = try appStore.createAccount(
            name: "Travel Cash",
            type: .cash,
            balance: .zero(currencyCode: "USD")
        )

        let service = TransactionService(storeURL: storeURL, currentLedgerID: travelLedger.id)
        _ = try service.createTransaction(from: ParsedTransaction(
            type: .expense,
            amount: 28,
            categoryName: "餐饮",
            accountName: travelAccount.name,
            occurredAt: Date(timeIntervalSince1970: 1_725_000_000),
            note: "Travel lunch"
        ))

        let reopenedStore = try SwiftDataBookkeepingStore(storeURL: storeURL)
        XCTAssertEqual(reopenedStore.visibleTransactions.last?.ledgerID, travelLedger.id)
        XCTAssertEqual(reopenedStore.visibleTransactions.last?.amount.currencyCode, "USD")
    }

    func testTransactionServiceRejectsAnAccountWhoseCurrencyDiffersFromTheCurrentLedger() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TransactionServiceAccountCurrencyTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("Numi.store")
        let appStore = try SwiftDataBookkeepingStore(storeURL: storeURL)
        try appStore.seedDefaultsIfNeeded()
        let travelLedger = try appStore.createLedger(name: "Travel", currencyCode: "USD")
        let cnyAccount = try XCTUnwrap(appStore.accounts.first)
        let service = TransactionService(storeURL: storeURL, currentLedgerID: travelLedger.id)

        XCTAssertThrowsError(try service.createTransaction(from: ParsedTransaction(
            type: .expense,
            amount: 28,
            categoryName: "餐饮",
            accountName: cnyAccount.name,
            occurredAt: Date(timeIntervalSince1970: 1_725_000_000),
            note: "Mismatched account"
        ))) { error in
            guard case TransactionServiceError.noAccount = error else {
                return XCTFail("Expected an unavailable-account error, got \(error)")
            }
        }
    }

    func testSharedStoreRefreshPublishesShortcutTransactionWrittenElsewhere() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TransactionServiceExternalRefreshTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("Numi.store")
        let appStore = try SwiftDataBookkeepingStore(storeURL: storeURL)
        try appStore.seedDefaultsIfNeeded()
        let initialRevision = appStore.changeRevision
        let initialCount = appStore.visibleTransactions.count
        let ledger = try XCTUnwrap(appStore.ledgers.first)
        let account = try XCTUnwrap(appStore.accounts.first)

        let service = TransactionService(storeURL: storeURL)
        _ = try service.createTransaction(from: ParsedTransaction(
            type: .expense,
            amount: 36,
            categoryName: "餐饮",
            accountName: account.name,
            occurredAt: Date(timeIntervalSince1970: 1_725_000_000),
            note: "快捷指令晚餐"
        ))

        appStore.refreshFromExternalChanges()

        XCTAssertEqual(appStore.changeRevision, initialRevision + 1)
        XCTAssertEqual(appStore.visibleTransactions.count, initialCount + 1)
        XCTAssertEqual(appStore.visibleTransactions.last?.ledgerID, ledger.id)
        XCTAssertEqual(appStore.visibleTransactions.last?.note, "快捷指令晚餐")
    }

    func testTransactionServiceUsesRuntimeLocalizedNamesForShortcutParsing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TransactionServiceLocalizationTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("Numi.store")
        let appStore = try SwiftDataBookkeepingStore(storeURL: storeURL)
        try appStore.seedDefaultsIfNeeded()
        let diningCategory = try XCTUnwrap(appStore.categories.first { $0.builtInKey == "category.default.expense.dining" })
        let cashAccount = try XCTUnwrap(appStore.accounts.first { $0.builtInKey == "account.default.cash" })

        UserDefaults.standard.set("en", forKey: languageKey)
        let service = TransactionService(storeURL: storeURL)
        XCTAssertTrue(service.availableCategoryNames().contains("Dining"))

        _ = try service.createTransaction(from: ParsedTransaction(
            type: .expense,
            amount: 12,
            categoryName: "Dining",
            accountName: "Cash",
            occurredAt: Date(timeIntervalSince1970: 1_725_000_000),
            note: "Lunch"
        ))

        let reopenedStore = try SwiftDataBookkeepingStore(storeURL: storeURL)
        XCTAssertEqual(reopenedStore.visibleTransactions.last?.categoryID, diningCategory.id)
        XCTAssertEqual(reopenedStore.visibleTransactions.last?.accountID, cashAccount.id)
    }

    func testSharedStoreMigrationCopiesLegacySQLiteFilesOnlyWhenNeeded() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SharedStoreMigrationTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let legacyStoreURL = directory.appendingPathComponent("legacy.store")
        let sharedStoreURL = directory.appendingPathComponent("shared/Numi.store")
        let legacyWALURL = directory.appendingPathComponent("legacy.store-wal")
        let sharedWALURL = directory.appendingPathComponent("shared/Numi.store-wal")
        try Data("database".utf8).write(to: legacyStoreURL)
        try Data("wal".utf8).write(to: legacyWALURL)

        XCTAssertTrue(
            try SharedBookkeepingStoreLocation.migrateLegacyStoreIfNeeded(
                legacyStoreURL: legacyStoreURL,
                sharedStoreURL: sharedStoreURL,
                fileManager: .default
            )
        )
        XCTAssertEqual(try Data(contentsOf: sharedStoreURL), Data("database".utf8))
        XCTAssertEqual(try Data(contentsOf: sharedWALURL), Data("wal".utf8))

        try Data("new database".utf8).write(to: sharedStoreURL)
        XCTAssertFalse(
            try SharedBookkeepingStoreLocation.migrateLegacyStoreIfNeeded(
                legacyStoreURL: legacyStoreURL,
                sharedStoreURL: sharedStoreURL,
                fileManager: .default
            )
        )
        XCTAssertEqual(try Data(contentsOf: sharedStoreURL), Data("new database".utf8))
    }

    // MARK: - Transaction Creation via Store

    func testCreateExpenseTransaction() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()

        guard let category = store.categories.first(where: { $0.name == "餐饮" }),
              let account = store.accounts.first else {
            XCTFail("Missing default data")
            return
        }

        let money = try Money(decimalString: "35.00", currencyCode: "CNY")
        let tx = try store.createTransaction(
            type: .expense,
            amount: money,
            categoryID: category.id,
            accountID: account.id,
            ledgerID: store.ledgers.first!.id,
            note: "午饭"
        )

        XCTAssertEqual(tx.type, .expense)
        XCTAssertEqual(tx.amount.minorUnits, 3500)
        XCTAssertEqual(tx.categoryID, category.id)
        XCTAssertEqual(tx.accountID, account.id)
        XCTAssertEqual(tx.note, "午饭")
    }

    func testCreateIncomeTransaction() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()

        guard let category = store.categories.first(where: { $0.name == "工资" }),
              let account = store.accounts.first else {
            XCTFail("Missing default data")
            return
        }

        let money = try Money(decimalString: "8000.00", currencyCode: "CNY")
        let tx = try store.createTransaction(
            type: .income,
            amount: money,
            categoryID: category.id,
            accountID: account.id,
            ledgerID: store.ledgers.first!.id,
            note: "6月工资"
        )

        XCTAssertEqual(tx.type, .income)
        XCTAssertEqual(tx.amount.minorUnits, 800000)
    }

    func testTransactionAppearsInVisibleTransactions() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()

        guard let account = store.accounts.first else {
            XCTFail("No account")
            return
        }

        let initialCount = store.visibleTransactions.count

        let money = try Money(decimalString: "10.00", currencyCode: "CNY")
        _ = try store.createTransaction(
            type: .expense,
            amount: money,
            categoryID: nil,
            accountID: account.id,
            ledgerID: store.ledgers.first!.id,
            note: "test"
        )

        XCTAssertEqual(store.visibleTransactions.count, initialCount + 1)
    }

    // MARK: - Balance Effect

    func testExpenseReducesBalance() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()

        guard let account = store.accounts.first else {
            XCTFail("No account")
            return
        }

        let initialBalance = account.balance.minorUnits
        let money = try Money(decimalString: "100.00", currencyCode: "CNY")

        _ = try store.createTransaction(
            type: .expense,
            amount: money,
            categoryID: nil,
            accountID: account.id,
            ledgerID: store.ledgers.first!.id,
            note: "test"
        )

        let updatedAccount = store.accounts.first { $0.id == account.id }!
        XCTAssertEqual(updatedAccount.balance.minorUnits, initialBalance - 10000)
    }

    func testIncomeIncreasesBalance() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()

        guard let account = store.accounts.first else {
            XCTFail("No account")
            return
        }

        let initialBalance = account.balance.minorUnits
        let money = try Money(decimalString: "500.00", currencyCode: "CNY")

        _ = try store.createTransaction(
            type: .income,
            amount: money,
            categoryID: nil,
            accountID: account.id,
            ledgerID: store.ledgers.first!.id,
            note: "test"
        )

        let updatedAccount = store.accounts.first { $0.id == account.id }!
        XCTAssertEqual(updatedAccount.balance.minorUnits, initialBalance + 50000)
    }

    // MARK: - Soft Delete

    func testSoftDeleteTransaction() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()

        guard let account = store.accounts.first else {
            XCTFail("No account")
            return
        }

        let money = try Money(decimalString: "5.00", currencyCode: "CNY")
        let tx = try store.createTransaction(
            type: .expense,
            amount: money,
            categoryID: nil,
            accountID: account.id,
            ledgerID: store.ledgers.first!.id,
            note: "test"
        )

        let countBefore = store.visibleTransactions.count
        try store.softDeleteTransaction(id: tx.id)
        let countAfter = store.visibleTransactions.count

        XCTAssertEqual(countAfter, countBefore - 1)
        XCTAssertTrue(store.allTransactions.contains { $0.id == tx.id })
    }

    func testRestoreTransaction() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()

        guard let account = store.accounts.first else {
            XCTFail("No account")
            return
        }

        let money = try Money(decimalString: "5.00", currencyCode: "CNY")
        let tx = try store.createTransaction(
            type: .expense,
            amount: money,
            categoryID: nil,
            accountID: account.id,
            ledgerID: store.ledgers.first!.id,
            note: "test"
        )

        try store.softDeleteTransaction(id: tx.id)
        let countAfterDelete = store.visibleTransactions.count

        try store.restoreTransaction(id: tx.id)
        let countAfterRestore = store.visibleTransactions.count

        XCTAssertEqual(countAfterRestore, countAfterDelete + 1)
    }
}
