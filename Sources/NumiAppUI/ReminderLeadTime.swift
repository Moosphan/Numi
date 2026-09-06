import Foundation

public enum ReminderLeadTime {
    public static let supportedDays = [0, 1, 3, 7]

    public static func displayLocalizationKey(for days: Int) -> String {
        days == 0 ? "setting.reminder.days.onDate" : "setting.reminder.days.value"
    }
}
