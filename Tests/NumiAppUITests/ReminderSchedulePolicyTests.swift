import XCTest
@testable import NumiAppUI

final class ReminderSchedulePolicyTests: XCTestCase {
    func testRejectsMissingOrPastReminderDate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertFalse(ReminderSchedulePolicy.canSchedule(reminderDate: nil, now: now))
        XCTAssertFalse(ReminderSchedulePolicy.canSchedule(reminderDate: now, now: now))
        XCTAssertFalse(ReminderSchedulePolicy.canSchedule(reminderDate: now.addingTimeInterval(-1), now: now))
    }

    func testAcceptsFutureReminderDate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertTrue(ReminderSchedulePolicy.canSchedule(reminderDate: now.addingTimeInterval(1), now: now))
    }
}
