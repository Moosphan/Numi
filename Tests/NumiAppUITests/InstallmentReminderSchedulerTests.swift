import XCTest
@testable import NumiAppUI
import NumiCore

final class InstallmentReminderSchedulerTests: XCTestCase {
    func testReminderActionCancelsWhenAllPeriodsAreSettled() throws {
        let planID = UUID()
        let plan = InstallmentPlan(
            id: planID,
            name: "Phone",
            totalAmount: try Money(decimalString: "100", currencyCode: "USD"),
            feePerPeriod: .zero(currencyCode: "USD"),
            periodCount: 2,
            firstPaymentDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let periods = [
            InstallmentPeriod(planID: planID, periodIndex: 0, dueDate: plan.firstPaymentDate, isPaid: true),
            InstallmentPeriod(planID: planID, periodIndex: 1, dueDate: plan.firstPaymentDate, isSkipped: true)
        ]

        XCTAssertEqual(
            InstallmentReminderScheduler.reminderAction(plan: plan, periods: periods),
            .cancel
        )
    }
}
