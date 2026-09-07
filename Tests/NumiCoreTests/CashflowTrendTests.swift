import XCTest
@testable import NumiCore

final class CashflowTrendTests: XCTestCase {
    func testDailyTrendFillsEmptyDaysAndUsesRecordedConvertedAmounts() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayOne = calendar.date(from: DateComponents(year: 2025, month: 2, day: 1))!
        let dayTwo = calendar.date(byAdding: .day, value: 1, to: dayOne)!
        let dayThree = calendar.date(byAdding: .day, value: 2, to: dayOne)!
        let interval = DateInterval(start: dayOne, end: calendar.date(byAdding: .day, value: 3, to: dayOne)!)
        let transactions = [
            Transaction(type: .expense, amount: Money(minorUnits: 1_000, currencyCode: "USD"), occurredAt: dayOne, ledgerID: UUID(), convertedAmountAtRecord: Money(minorUnits: 7_200, currencyCode: "CNY")),
            Transaction(type: .income, amount: Money(minorUnits: 3_000, currencyCode: "CNY"), occurredAt: dayThree, ledgerID: UUID())
        ]

        let trend = try CashflowTrend.daily(
            transactions: transactions,
            interval: interval,
            currencyCode: "CNY",
            calendar: calendar
        )

        XCTAssertEqual(trend.map(\.date), [dayOne, dayTwo, dayThree])
        XCTAssertEqual(trend[0].expense, Money(minorUnits: 7_200, currencyCode: "CNY"))
        XCTAssertEqual(trend[1].expense, .zero(currencyCode: "CNY"))
        XCTAssertEqual(trend[2].income, Money(minorUnits: 3_000, currencyCode: "CNY"))
    }
}
