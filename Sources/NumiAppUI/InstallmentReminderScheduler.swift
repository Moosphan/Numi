import Foundation
import NumiCore

#if canImport(UserNotifications)
import UserNotifications
#endif

public enum InstallmentReminderScheduler {
    public static func schedule(
        plan: InstallmentPlan,
        periods: [InstallmentPeriod],
        daysBefore: Int = 1,
        calendar: Calendar = .current
    ) async {
        #if canImport(UserNotifications)
        let identifier = notificationIdentifier(for: plan.id)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard let period = plan.nextPendingInstallmentPeriod(from: periods),
              let reminderDate = period.reminderDate(daysBefore: daysBefore, calendar: calendar),
              reminderDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = NumiLocalized.string("installment.reminder.title")
        content.body = NumiLocalized.string(
            "installment.reminder.body",
            plan.name,
            NumiLocalized.string("installment.period.n", period.periodIndex + 1),
            plan.amountPerPeriod.formatted()
        )
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
        #endif
    }

    public static func schedule(
        plans: [InstallmentPlan],
        periods: [InstallmentPeriod],
        daysBefore: Int = 1,
        calendar: Calendar = .current
    ) async {
        for plan in plans {
            await schedule(plan: plan, periods: periods, daysBefore: daysBefore, calendar: calendar)
        }
    }

    public static func cancel(planID: UUID) {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier(for: planID)]
        )
        #endif
    }

    private static func notificationIdentifier(for planID: UUID) -> String {
        "installment-reminder-\(planID.uuidString)"
    }
}
