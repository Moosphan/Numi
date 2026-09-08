import XCTest
@testable import NumiAppUI

final class BackupReminderSchedulePolicyTests: XCTestCase {
    func testNextReminderUsesConfiguredIntervalAfterLastBackup() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let lastBackup = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertEqual(
            BackupReminderSchedulePolicy.nextReminderDate(
                lastBackupAt: lastBackup,
                intervalDays: 14,
                now: lastBackup,
                calendar: calendar
            ),
            calendar.date(byAdding: .day, value: 14, to: lastBackup)
        )
    }

    func testNextReminderFallsBackToNowWhenNoBackupExists() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertEqual(
            BackupReminderSchedulePolicy.nextReminderDate(
                lastBackupAt: nil,
                intervalDays: 7,
                now: now
            ),
            now
        )
    }

    func testOnlyPersistsAnEnabledReminderAfterSchedulingSucceeds() {
        XCTAssertFalse(
            BackupReminderPreferencePolicy.enabledValue(
                requestedEnabled: true,
                schedulingSucceeded: false
            )
        )
        XCTAssertTrue(
            BackupReminderPreferencePolicy.enabledValue(
                requestedEnabled: true,
                schedulingSucceeded: true
            )
        )
        XCTAssertFalse(
            BackupReminderPreferencePolicy.enabledValue(
                requestedEnabled: false,
                schedulingSucceeded: true
            )
        )
    }
}
