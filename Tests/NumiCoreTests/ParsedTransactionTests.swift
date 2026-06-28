import XCTest
@testable import NumiCore

final class ParsedTransactionTests: XCTestCase {

    // MARK: - Init

    func testDefaultInit() {
        let tx = ParsedTransaction(
            type: .expense,
            amount: 35,
            categoryName: "餐饮"
        )
        XCTAssertEqual(tx.type, .expense)
        XCTAssertEqual(tx.amount, 35)
        XCTAssertEqual(tx.categoryName, "餐饮")
        XCTAssertNil(tx.accountName)
        XCTAssertNil(tx.targetAccountName)
        XCTAssertEqual(tx.note, "")
    }

    func testFullInit() {
        let date = Date()
        let tx = ParsedTransaction(
            type: .income,
            amount: 8000,
            categoryName: "工资",
            accountName: "银行卡",
            targetAccountName: "现金",
            occurredAt: date,
            note: "6月薪资"
        )
        XCTAssertEqual(tx.type, .income)
        XCTAssertEqual(tx.amount, 8000)
        XCTAssertEqual(tx.categoryName, "工资")
        XCTAssertEqual(tx.accountName, "银行卡")
        XCTAssertEqual(tx.targetAccountName, "现金")
        XCTAssertEqual(tx.occurredAt, date)
        XCTAssertEqual(tx.note, "6月薪资")
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1718800000)
        let tx = ParsedTransaction(
            type: .expense,
            amount: 123.45,
            categoryName: "交通",
            accountName: "微信",
            targetAccountName: "银行卡",
            occurredAt: date,
            note: "打车"
        )

        let data = try JSONEncoder().encode(tx)
        let decoded = try JSONDecoder().decode(ParsedTransaction.self, from: data)

        XCTAssertEqual(decoded.type, .expense)
        XCTAssertEqual(decoded.amount, 123.45)
        XCTAssertEqual(decoded.categoryName, "交通")
        XCTAssertEqual(decoded.accountName, "微信")
        XCTAssertEqual(decoded.targetAccountName, "银行卡")
        XCTAssertEqual(decoded.note, "打车")
    }

    func testCodableWithNilOptionals() throws {
        let tx = ParsedTransaction(
            type: .transfer,
            amount: 500,
            categoryName: "转账"
        )

        let data = try JSONEncoder().encode(tx)
        let decoded = try JSONDecoder().decode(ParsedTransaction.self, from: data)

        XCTAssertEqual(decoded.type, .transfer)
        XCTAssertNil(decoded.accountName)
        XCTAssertNil(decoded.targetAccountName)
        XCTAssertEqual(decoded.note, "")
    }

    // MARK: - Equatable

    func testEquatable() {
        let date = Date()
        let a = ParsedTransaction(type: .expense, amount: 10, categoryName: "餐饮", occurredAt: date)
        let b = ParsedTransaction(type: .expense, amount: 10, categoryName: "餐饮", occurredAt: date)
        XCTAssertEqual(a, b)
    }

    func testNotEqualDifferentAmount() {
        let date = Date()
        let a = ParsedTransaction(type: .expense, amount: 10, categoryName: "餐饮", occurredAt: date)
        let b = ParsedTransaction(type: .expense, amount: 20, categoryName: "餐饮", occurredAt: date)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - TransactionType

    func testAllTransactionTypes() {
        for type in [TransactionType.expense, .income, .transfer] {
            let tx = ParsedTransaction(type: type, amount: 1, categoryName: "测试")
            XCTAssertEqual(tx.type, type)
        }
    }
}
