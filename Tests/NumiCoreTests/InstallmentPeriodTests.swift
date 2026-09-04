import XCTest
@testable import NumiCore

final class InstallmentPeriodTests: XCTestCase {
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
}
