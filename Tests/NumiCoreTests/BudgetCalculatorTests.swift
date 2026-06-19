import XCTest
@testable import NumiCore

final class BudgetCalculatorTests: XCTestCase {
    func testMonthlyBudgetReportsRemainingAndDailySuggestion() throws {
        let budget = BudgetLimit(
            amount: try Money(decimalString: "3000", currencyCode: "CNY"),
            period: .month,
            startsOn: DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 6, day: 1).date!,
            endsOn: DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 6, day: 30).date!
        )
        let spent = try Money(decimalString: "1200", currencyCode: "CNY")
        let today = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 6, day: 18).date!

        let status = try BudgetCalculator.status(for: budget, spent: spent, today: today)

        XCTAssertEqual(status.remaining.formatted(), "¥1,800.00")
        XCTAssertEqual(status.dailySuggestion.formatted(), "¥138.46")
        XCTAssertFalse(status.isOverBudget)
    }

    func testOverBudgetReportsNegativeRemaining() throws {
        let budget = BudgetLimit(
            amount: try Money(decimalString: "100", currencyCode: "CNY"),
            period: .week,
            startsOn: DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 6, day: 15).date!,
            endsOn: DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 6, day: 21).date!
        )
        let spent = try Money(decimalString: "140", currencyCode: "CNY")
        let today = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 6, day: 18).date!

        let status = try BudgetCalculator.status(for: budget, spent: spent, today: today)

        XCTAssertEqual(status.remaining.formatted(), "-¥40.00")
        XCTAssertTrue(status.isOverBudget)
        XCTAssertEqual(status.dailySuggestion.formatted(), "¥0.00")
    }
}
