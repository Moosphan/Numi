import XCTest
@testable import NumiCore

final class MoneyInputStateTests: XCTestCase {
    func testEvaluatesSimpleAddition() throws {
        var state = MoneyInputState(currencyCode: "CNY")

        ["1", "2", "+", "3", "="].forEach { state.apply(.token($0)) }

        XCTAssertEqual(try state.money().formatted(), "¥15.00")
        XCTAssertEqual(state.displayText, "15")
    }

    func testDeleteRemovesLastDigit() throws {
        var state = MoneyInputState(currencyCode: "CNY")

        ["1", "2", "3"].forEach { state.apply(.token($0)) }
        state.apply(.delete)

        XCTAssertEqual(state.displayText, "12")
        XCTAssertEqual(try state.money().formatted(), "¥12.00")
    }

    func testIgnoresExtraFractionDigit() throws {
        var state = MoneyInputState(currencyCode: "CNY")

        ["1", ".", "2", "3", "4"].forEach { state.apply(.token($0)) }

        XCTAssertEqual(state.displayText, "1.23")
        XCTAssertEqual(try state.money().formatted(), "¥1.23")
    }

    func testCanStartFromExistingMoneyForEditing() throws {
        let state = MoneyInputState(money: Money(minorUnits: 3_450, currencyCode: "CNY"))

        XCTAssertEqual(state.displayText, "34.50")
        XCTAssertEqual(try state.money(), Money(minorUnits: 3_450, currencyCode: "CNY"))
    }
}
