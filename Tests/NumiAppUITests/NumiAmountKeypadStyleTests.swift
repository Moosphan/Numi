import XCTest
@testable import NumiAppUI

final class NumiAmountKeypadStyleTests: XCTestCase {
    func testDateShortcutUsesDateAccentStyle() {
        let keypad = NumiAmountKeypad(
            state: .constant(MoneyInputState(currencyCode: "CNY")),
            dateShortcutTitle: "今天"
        )

        XCTAssertEqual(keypad.keyStyle(for: "今天"), .dateAccent)
    }

    func testDigitsAndOperatorsUseNeutralStyle() {
        let keypad = NumiAmountKeypad(
            state: .constant(MoneyInputState(currencyCode: "CNY")),
            dateShortcutTitle: "今天"
        )

        XCTAssertEqual(keypad.keyStyle(for: "8"), .neutral)
        XCTAssertEqual(keypad.keyStyle(for: "delete.left"), .neutral)
        XCTAssertEqual(keypad.keyStyle(for: "+"), .neutral)
        XCTAssertEqual(keypad.keyStyle(for: "="), .neutral)
    }
}
