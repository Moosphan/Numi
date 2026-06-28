import XCTest
import NumiCore
@testable import NumiAppUI

final class NumiAmountKeypadStyleTests: XCTestCase {
    func testConcreteDateHidesDateAccessoryIcon() {
        let keypad = NumiAmountKeypad(
            state: .constant(MoneyInputState(currencyCode: "CNY")),
            dateShortcutTitle: "6月12日",
            dateShortcutAccessibilityKey: "custom"
        )

        XCTAssertFalse(keypad.showsDateAccessoryIcon(for: "6月12日"))
    }

    func testNamedDateShortcutShowsDateAccessoryIconByStableShortcutKey() {
        let keypad = NumiAmountKeypad(
            state: .constant(MoneyInputState(currencyCode: "CNY")),
            dateShortcutTitle: "Today",
            dateShortcutAccessibilityKey: "today"
        )

        XCTAssertTrue(keypad.showsDateAccessoryIcon(for: "Today"))
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
            dateShortcutTitle: "Today",
            dateShortcutAccessibilityKey: "today"
        )

        XCTAssertEqual(keypad.keyStyle(for: "Today"), .dateAccent)
    }

    func testDigitsAndOperatorsUseNeutralStyle() {
        let keypad = NumiAmountKeypad(
            state: .constant(MoneyInputState(currencyCode: "CNY")),
            dateShortcutTitle: "Today",
            dateShortcutAccessibilityKey: "today"
        )

        XCTAssertEqual(keypad.keyStyle(for: "8"), .neutral)
        XCTAssertEqual(keypad.keyStyle(for: "delete.left"), .neutral)
        XCTAssertEqual(keypad.keyStyle(for: "+"), .neutral)
        XCTAssertEqual(keypad.keyStyle(for: "="), .neutral)
    }

    func testCustomShortcutAccessibilityKeyRemainsStableWithoutLocalizedComparison() {
        let keypad = NumiAmountKeypad(
            state: .constant(MoneyInputState(currencyCode: "CNY")),
            dateShortcutTitle: "Jun 12",
            dateShortcutAccessibilityKey: "custom"
        )

        XCTAssertEqual(keypad.resolvedDateShortcutAccessibilityKey, "custom")
    }
}
