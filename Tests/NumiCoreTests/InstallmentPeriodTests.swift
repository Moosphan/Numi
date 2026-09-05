import XCTest
@testable import NumiCore

final class InstallmentPeriodTests: XCTestCase {
    func testNextPendingPeriodReminderDateIsOneDayBeforeDueDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dueDate = Date(timeIntervalSince1970: 1_700_000_000)
        let planID = UUID()
        let plan = InstallmentPlan(
            id: planID,
            name: "Phone",
            totalAmount: try Money(decimalString: "100", currencyCode: "USD"),
            feePerPeriod: .zero(currencyCode: "USD"),
            periodCount: 3,
            firstPaymentDate: dueDate
        )
        let periods = [
            InstallmentPeriod(planID: planID, periodIndex: 0, dueDate: dueDate, isPaid: true),
            InstallmentPeriod(planID: planID, periodIndex: 1, dueDate: calendar.date(byAdding: .month, value: 1, to: dueDate)!),
            InstallmentPeriod(planID: planID, periodIndex: 2, dueDate: calendar.date(byAdding: .month, value: 2, to: dueDate)!, isSkipped: true)
        ]

        let pending = try XCTUnwrap(plan.nextPendingInstallmentPeriod(from: periods))
        XCTAssertEqual(pending.periodIndex, 1)
        XCTAssertEqual(
            pending.reminderDate(calendar: calendar),
            calendar.date(byAdding: .day, value: -1, to: pending.dueDate)
        )
    }

    func testUnpaidPeriodBecomesOverdueAfterDueDate() {
        let dueDate = Date(timeIntervalSince1970: 1_000)
        let period = InstallmentPeriod(planID: UUID(), periodIndex: 0, dueDate: dueDate)

        XCTAssertFalse(period.isOverdue(asOf: dueDate))
        XCTAssertTrue(period.isOverdue(asOf: Date(timeIntervalSince1970: 1_001)))
    }

    func testPaidPeriodIsNeverOverdue() {
        let period = InstallmentPeriod(
            planID: UUID(),
            periodIndex: 0,
            dueDate: Date(timeIntervalSince1970: 1_000),
            isPaid: true
        )

        XCTAssertFalse(period.isOverdue(asOf: Date(timeIntervalSince1970: 2_000)))
    }

    func testSkippedPeriodIsNeverOverdue() {
        let period = InstallmentPeriod(
            planID: UUID(),
            periodIndex: 0,
            dueDate: Date(timeIntervalSince1970: 1_000),
            isSkipped: true
        )

        XCTAssertFalse(period.isOverdue(asOf: Date(timeIntervalSince1970: 2_000)))
    }
}
