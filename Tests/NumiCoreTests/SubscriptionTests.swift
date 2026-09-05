import XCTest
@testable import NumiCore

final class SubscriptionTests: XCTestCase {
    func testCustomMonthIntervalAdvancesBillingDateByIntervalValue() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 31)))
        let subscription = Subscription(
            name: "Bi-monthly service",
            amount: Money(minorUnits: 1000, currencyCode: "CNY"),
            cycle: .custom,
            customInterval: try XCTUnwrap(SubscriptionInterval(value: 2, unit: .month)),
            nextBillingDate: start
        )

        XCTAssertEqual(
            subscription.nextBillingDateAfter(start, calendar: calendar),
            calendar.date(byAdding: .month, value: 2, to: start)
        )
    }

    func testCustomCycleWithoutIntervalDoesNotAdvance() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let subscription = Subscription(
            name: "Invalid custom",
            amount: Money(minorUnits: 1000, currencyCode: "CNY"),
            cycle: .custom,
            nextBillingDate: start
        )

        XCTAssertEqual(subscription.nextBillingDateAfter(start), start)
    }

    func testCustomCycleWithInvalidDecodedIntervalDoesNotAdvance() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let interval = try JSONDecoder().decode(
            SubscriptionInterval.self,
            from: Data("{\"value\":-1,\"unit\":\"month\"}".utf8)
        )
        let subscription = Subscription(
            name: "Invalid decoded custom",
            amount: Money(minorUnits: 1000, currencyCode: "CNY"),
            cycle: .custom,
            customInterval: interval,
            nextBillingDate: start
        )

        XCTAssertEqual(subscription.nextBillingDateAfter(start), start)
    }

    func testCustomSubscriptionCycleAndIntervalUnitsAreLocalizedInAllSupportedLanguages() {
        let expectedCycleValues = [
            "zh-Hans": "自定义间隔",
            "zh-Hant": "自訂間隔",
            "en": "Custom interval",
            "ja": "カスタム間隔"
        ]
        let expectedMonthUnitValues = [
            "zh-Hans": "个月",
            "zh-Hant": "個月",
            "en": "Months",
            "ja": "か月"
        ]

        for (language, expected) in expectedCycleValues {
            XCTAssertEqual(
                NumiLocalized.lookup("subscription.cycle.custom", locale: Locale(identifier: language)),
                expected
            )
        }
        for (language, expected) in expectedMonthUnitValues {
            XCTAssertEqual(
                NumiLocalized.lookup("subscription.interval.unit.month", locale: Locale(identifier: language)),
                expected
            )
        }
    }

    func testSubscriptionIntervalUnitUsesLocalizedDisplayName() {
        XCTAssertEqual(
            SubscriptionIntervalUnit.month.displayName,
            NumiLocalized.string("subscription.interval.unit.month")
        )
    }

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

    func testMonthEndCycleAdvancesToLastDayOfFollowingMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let januaryEnd = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 31)))
        let februaryEnd = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 2, day: 28)))
        let subscription = Subscription(
            name: "Month end",
            amount: Money(minorUnits: 1000, currencyCode: "CNY"),
            cycle: .monthEnd,
            nextBillingDate: januaryEnd
        )

        XCTAssertEqual(subscription.nextBillingDateAfter(januaryEnd, calendar: calendar), februaryEnd)
    }

    func testMonthEndDateUsesLeapYearFebruary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 1)))
        let expected = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 29)))

        XCTAssertEqual(Subscription.monthEndDate(containing: date, calendar: calendar), expected)
    }

    func testWeekdayCycleAdvancesFromFridayToMonday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let friday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 4, day: 4)))
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 4, day: 7)))
        let subscription = Subscription(
            name: "Weekday",
            amount: Money(minorUnits: 1000, currencyCode: "CNY"),
            cycle: .weekdays,
            nextBillingDate: friday
        )

        XCTAssertEqual(subscription.nextBillingDateAfter(friday, calendar: calendar), monday)
    }

    func testWeekdayDateMovesWeekendToMonday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let sunday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 4, day: 6)))
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 4, day: 7)))

        XCTAssertEqual(Subscription.weekdayDate(onOrAfter: sunday, calendar: calendar), monday)
    }

    func testMonthlyFirstWeekdayCycleSkipsWeekendAtBeginningOfFollowingMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let mayFirst = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 5, day: 1)))
        let juneSecond = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 6, day: 2)))
        let subscription = Subscription(
            name: "First weekday",
            amount: Money(minorUnits: 1000, currencyCode: "CNY"),
            cycle: .monthlyFirstWeekday,
            nextBillingDate: mayFirst
        )

        XCTAssertEqual(subscription.nextBillingDateAfter(mayFirst, calendar: calendar), juneSecond)
    }

    func testFirstWeekdayDateSkipsWeekendAtBeginningOfMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let juneFifteenth = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 6, day: 15)))
        let juneSecond = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 6, day: 2)))

        XCTAssertEqual(Subscription.firstWeekdayDate(containing: juneFifteenth, calendar: calendar), juneSecond)
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

    func testMonthEndCycleIsLocalizedInAllSupportedLanguages() {
        let expectedValues = [
            "zh-Hans": "每月末",
            "zh-Hant": "每月末",
            "en": "Month End",
            "ja": "毎月末"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("subscription.cycle.month.end", locale: Locale(identifier: language)),
                expected
            )
        }
    }

    func testWeekdayCycleIsLocalizedInAllSupportedLanguages() {
        let expectedValues = [
            "zh-Hans": "每个工作日",
            "zh-Hant": "每個工作日",
            "en": "Weekdays",
            "ja": "平日"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("subscription.cycle.weekdays", locale: Locale(identifier: language)),
                expected
            )
        }
    }

    func testMonthlyFirstWeekdayCycleIsLocalizedInAllSupportedLanguages() {
        let expectedValues = [
            "zh-Hans": "每月首个工作日",
            "zh-Hant": "每月首個工作日",
            "en": "First weekday of month",
            "ja": "毎月最初の平日"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("subscription.cycle.monthly.first.weekday", locale: Locale(identifier: language)),
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
