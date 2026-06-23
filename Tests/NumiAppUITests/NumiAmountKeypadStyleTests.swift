import XCTest
@testable import NumiAppUI

final class NumiAmountKeypadStyleTests: XCTestCase {
    func testConcreteDateHidesDateAccessoryIcon() {
        let keypad = NumiAmountKeypad(
            state: .constant(MoneyInputState(currencyCode: "CNY")),
            dateShortcutTitle: "6月12日"
        )

        XCTAssertFalse(keypad.showsDateAccessoryIcon(for: "6月12日"))
        XCTAssertTrue(keypad.showsDateAccessoryIcon(for: "今天"))
    }

    func testDateDisplayWithoutTimeUsesMonthAndDayOnly() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 15, minute: 40))!

        XCTAssertEqual(
            NumiDatePickerRow.displayText(for: date, calendar: calendar, includesTime: false),
            "6月3日"
        )
    }

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
