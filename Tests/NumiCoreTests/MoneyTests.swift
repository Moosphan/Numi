import XCTest
@testable import NumiCore

final class MoneyTests: XCTestCase {
    func testParsesDecimalAmountIntoMinorUnits() throws {
        let money = try Money(decimalString: "2514.95", currencyCode: "CNY")

        XCTAssertEqual(money.minorUnits, 251_495)
        XCTAssertEqual(money.currencyCode, "CNY")
        XCTAssertEqual(money.formatted(), "¥2,514.95")
    }

    func testRejectsTooManyFractionDigitsForCurrency() {
        XCTAssertThrowsError(try Money(decimalString: "12.345", currencyCode: "CNY")) { error in
            XCTAssertEqual(error as? Money.ParseError, .tooManyFractionDigits(maximum: 2))
        }
    }

    func testAddsMoneyWithSameCurrency() throws {
        let first = try Money(decimalString: "12.30", currencyCode: "CNY")
        let second = try Money(decimalString: "7.70", currencyCode: "CNY")

        XCTAssertEqual((try first.adding(second)).formatted(), "¥20.00")
    }

    func testRejectsAddingDifferentCurrencies() throws {
        let cny = try Money(decimalString: "12", currencyCode: "CNY")
        let usd = try Money(decimalString: "12", currencyCode: "USD")

        XCTAssertThrowsError(try cny.adding(usd)) { error in
            XCTAssertEqual(error as? Money.ArithmeticError, .currencyMismatch(left: "CNY", right: "USD"))
        }
    }
}
