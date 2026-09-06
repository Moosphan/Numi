import XCTest
@testable import NumiAppUI

final class ReminderLeadTimeTests: XCTestCase {
    func testUsesOnDateCopyForSameDayReminder() {
        XCTAssertEqual(
            ReminderLeadTime.displayLocalizationKey(for: 0),
            "setting.reminder.days.onDate"
        )
    }

    func testKeepsAheadOfTimeCopyForFutureReminder() {
        XCTAssertEqual(
            ReminderLeadTime.displayLocalizationKey(for: 3),
            "setting.reminder.days.value"
        )
    }
}
