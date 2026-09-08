import Foundation
import NumiCore

#if canImport(UserNotifications)
import UserNotifications
#endif

public enum BackupReminderSchedulePolicy {
    public static func nextReminderDate(
        lastBackupAt: Date?,
        intervalDays: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard intervalDays > 0 else { return nil }
        let reminderDate = lastBackupAt.flatMap {
            calendar.date(byAdding: .day, value: intervalDays, to: $0)
        } ?? now
        guard reminderDate <= now else { return reminderDate }
        guard let currentMinute = calendar.dateInterval(of: .minute, for: now)?.start else {
            return now.addingTimeInterval(60)
        }
        return calendar.date(byAdding: .minute, value: 1, to: currentMinute)
    }
}

public enum BackupReminderPreferencePolicy {
    public static func enabledValue(
        requestedEnabled: Bool,
        schedulingSucceeded: Bool
    ) -> Bool {
        requestedEnabled && schedulingSucceeded
    }
}

public enum BackupReminderScheduler {
    private static let identifier = "backup-reminder"

    public static func requestAuthorization() async -> Bool {
        #if canImport(UserNotifications)
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    public static func schedule(lastBackupAt: Date?, intervalDays: Int) async -> Bool {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard let date = BackupReminderSchedulePolicy.nextReminderDate(
            lastBackupAt: lastBackupAt,
            intervalDays: intervalDays
        ) else { return false }
        let content = UNMutableNotificationContent()
        content.title = NumiLocalized.string("backup.reminder.notification.title")
        content.body = NumiLocalized.string("backup.reminder.notification.body")
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        do {
            try await center.add(UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            ))
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    public static func cancel() {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        #endif
    }
}
