import XCTest
@testable import NumiCore

final class SubscriptionTests: XCTestCase {
    func testDueDatesIncludesEachOccurrenceThroughReferenceDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))
        let through = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 3)))
        let subscription = Subscription(
            name: "Daily",
            amount: Money(minorUnits: 1000, currencyCode: "CNY"),
            cycle: .daily,
            nextBillingDate: start
        )

        XCTAssertEqual(subscription.dueDates(through: through, calendar: calendar), [
            start,
            calendar.date(byAdding: .day, value: 1, to: start)!,
            calendar.date(byAdding: .day, value: 2, to: start)!
        ])
    }

    func testDueDatesIgnoresDisabledOrFutureSubscriptions() throws {
        let future = Date(timeIntervalSinceNow: 86_400)
        let disabled = Subscription(
            name: "Disabled",
            amount: Money(minorUnits: 1000, currencyCode: "CNY"),
            cycle: .monthly,
            nextBillingDate: Date(timeIntervalSinceNow: -86_400),
            isEnabled: false
        )
        let upcoming = Subscription(
            name: "Upcoming",
            amount: Money(minorUnits: 1000, currencyCode: "CNY"),
            cycle: .monthly,
            nextBillingDate: future
        )

        XCTAssertTrue(disabled.dueDates(through: Date()).isEmpty)
        XCTAssertTrue(upcoming.dueDates(through: Date()).isEmpty)
    }
}
