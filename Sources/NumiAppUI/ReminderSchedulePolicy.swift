import Foundation

enum ReminderSchedulePolicy {
    static func canSchedule(reminderDate: Date?, now: Date = Date()) -> Bool {
        guard let reminderDate else { return false }
        return reminderDate > now
    }
}
