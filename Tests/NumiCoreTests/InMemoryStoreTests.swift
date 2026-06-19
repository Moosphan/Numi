import XCTest
@testable import NumiCore

final class InMemoryStoreTests: XCTestCase {
    func testSeedsDefaultLedgerCategoriesAndAccountsOnce() throws {
        let store = InMemoryBookkeepingStore()

        try store.seedDefaultsIfNeeded()
        try store.seedDefaultsIfNeeded()

        XCTAssertEqual(store.ledgers.count, 1)
        XCTAssertEqual(store.categories.filter { $0.kind == .expense }.count, 28)
        XCTAssertEqual(store.categories.filter { $0.kind == .income }.count, 19)
        XCTAssertEqual(store.accounts.count, 2)
    }

    func testCreatesTransactionAndUpdatesAccountBalance() throws {
        let store = InMemoryBookkeepingStore()
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
        XCTAssertEqual(store.accounts.first?.balance.formatted(), "-¥32.50")
    }

    func testSoftDeleteAndRestoreTransactionReversesAccountBalance() throws {
        let store = InMemoryBookkeepingStore()
        try store.seedDefaultsIfNeeded()
        let accountID = try XCTUnwrap(store.accounts.first?.id)

        let transaction = try store.createTransaction(
            type: .income,
            amount: Money(decimalString: "100", currencyCode: "CNY"),
            categoryID: nil,
            accountID: accountID,
            note: "红包"
        )

        try store.softDeleteTransaction(id: transaction.id)
        XCTAssertEqual(store.visibleTransactions.count, 0)
        XCTAssertEqual(store.accounts.first?.balance.formatted(), "¥0.00")

        try store.restoreTransaction(id: transaction.id)
        XCTAssertEqual(store.visibleTransactions.count, 1)
        XCTAssertEqual(store.accounts.first?.balance.formatted(), "¥100.00")
    }
}
