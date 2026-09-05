import Foundation
import NumiCore

#if canImport(UserNotifications)
import UserNotifications
#endif

public enum SubscriptionReminderScheduler {
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

    public static func schedule(subscription: Subscription, daysBefore: Int = 1, calendar: Calendar = .current) async -> Bool {
        #if canImport(UserNotifications)
        let identifier = "subscription-reminder-\(subscription.id.uuidString)"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard let reminderDate = subscription.reminderDate(daysBefore: daysBefore, calendar: calendar), ReminderSchedulePolicy.canSchedule(reminderDate: reminderDate) else { return false }

        let content = UNMutableNotificationContent()
        content.title = NumiLocalized.string("subscription.reminder.title")
        content.body = NumiLocalized.string("subscription.reminder.body", subscription.name, subscription.amount.formatted())
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    public static func schedule(subscriptions: [Subscription], daysBefore: Int = 1, calendar: Calendar = .current) async {
        for subscription in subscriptions {
            await schedule(subscription: subscription, daysBefore: daysBefore, calendar: calendar)
        }
    }

    public static func cancel(subscriptionID: UUID) {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["subscription-reminder-\(subscriptionID.uuidString)"]
        )
        #endif
    }
}
