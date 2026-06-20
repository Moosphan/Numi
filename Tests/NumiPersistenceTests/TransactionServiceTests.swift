import XCTest
import SwiftData
@testable import NumiCore
@testable import NumiPersistence

@MainActor
final class TransactionServiceTests: XCTestCase {

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

    func testCategoryCount() throws {
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()

        let expenseCategories = store.categories.filter { $0.kind == .expense }
        let incomeCategories = store.categories.filter { $0.kind == .income }

        XCTAssertGreaterThan(expenseCategories.count, 20)
        XCTAssertGreaterThan(incomeCategories.count, 10)
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
            note: "test"
        )

        try store.softDeleteTransaction(id: tx.id)
        let countAfterDelete = store.visibleTransactions.count

        try store.restoreTransaction(id: tx.id)
        let countAfterRestore = store.visibleTransactions.count

        XCTAssertEqual(countAfterRestore, countAfterDelete + 1)
    }
}
