import XCTest
@testable import NumiCore

final class UpcomingPlanCashflowForecastTests: XCTestCase {
    func testForecastIncludesRecurringSubscriptionDatesAndPendingInstallmentsInRange() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 30)))
        let plan = InstallmentPlan(
            name: "Laptop",
            totalAmount: try Money(decimalString: "900", currencyCode: "CNY"),
            feePerPeriod: try Money(decimalString: "3", currencyCode: "CNY"),
            periodCount: 3,
            firstPaymentDate: start
        )
        let subscription = Subscription(
            name: "Music",
            amount: try Money(decimalString: "12", currencyCode: "CNY"),
            cycle: .weekly,
            nextBillingDate: start
        )
        let periods = [
            InstallmentPeriod(planID: plan.id, periodIndex: 0, dueDate: start),
            InstallmentPeriod(planID: plan.id, periodIndex: 1, dueDate: end),
            InstallmentPeriod(planID: plan.id, periodIndex: 2, dueDate: end, isPaid: true)
        ]

        let forecast = UpcomingPlanCashflowForecast.make(
            subscriptions: [subscription],
            installmentPlans: [plan],
            installmentPeriods: periods,
            from: start,
            through: end,
            currencyCode: "CNY",
            calendar: calendar
        )

        XCTAssertEqual(forecast.items.count, 7)
        XCTAssertEqual(forecast.total, try Money(decimalString: "666", currencyCode: "CNY"))
        XCTAssertEqual(forecast.excludedCurrencyItemCount, 0)
        XCTAssertEqual(forecast.items.map(\.kind), [.subscription, .installment, .subscription, .subscription, .subscription, .subscription, .installment])
    }

    func testForecastDoesNotSilentlyIncludeDifferentCurrencyPlans() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let subscription = Subscription(
            name: "US Service",
            amount: try Money(decimalString: "10", currencyCode: "USD"),
            cycle: .monthly,
            nextBillingDate: date
        )

        let forecast = UpcomingPlanCashflowForecast.make(
            subscriptions: [subscription],
            installmentPlans: [],
            installmentPeriods: [],
            from: date,
            through: date,
            currencyCode: "CNY"
        )

        XCTAssertEqual(forecast.total, .zero(currencyCode: "CNY"))
        XCTAssertEqual(forecast.items, [])
        XCTAssertEqual(forecast.excludedCurrencyItemCount, 1)
    }
}
