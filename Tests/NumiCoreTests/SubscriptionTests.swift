import XCTest
@testable import NumiCore

final class SubscriptionTests: XCTestCase {
    func testQuarterlyCycleAdvancesBillingDateByThreeMonths() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let billingDate = Date(timeIntervalSince1970: 1_700_000_000)
        let subscription = Subscription(
            name: "Quarterly Service",
            amount: try Money(decimalString: "10", currencyCode: "USD"),
            cycle: .quarterly,
            nextBillingDate: billingDate
        )

        XCTAssertEqual(
            subscription.nextBillingDateAfter(billingDate, calendar: calendar),
            calendar.date(byAdding: .month, value: 3, to: billingDate)
        )
    }

    func testQuarterlyCycleIsLocalizedInAllSupportedLanguages() {
        let expectedValues = [
            "zh-Hans": "每季度",
            "en": "Quarterly",
            "zh-Hant": "每季",
            "ja": "四半期ごと"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("subscription.cycle.quarterly", locale: Locale(identifier: language)),
                expected
            )
        }
    }

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

    func testReminderDateIsOneDayBeforeNextBillingForEnabledSubscription() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let billingDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 10)))
        let subscription = Subscription(
            name: "Monthly",
            amount: Money(minorUnits: 1000, currencyCode: "CNY"),
            cycle: .monthly,
            nextBillingDate: billingDate
        )

        XCTAssertEqual(
            subscription.reminderDate(daysBefore: 1, calendar: calendar),
            calendar.date(byAdding: .day, value: -1, to: billingDate)
        )
        XCTAssertNil(subscription.reminderDate(daysBefore: -1, calendar: calendar))
        XCTAssertNil(
            Subscription(
                name: "Disabled",
                amount: subscription.amount,
                cycle: .monthly,
                nextBillingDate: billingDate,
                isEnabled: false
            ).reminderDate(daysBefore: 1, calendar: calendar)
        )
    }
}
