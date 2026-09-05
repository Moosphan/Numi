import Foundation

// MARK: - Subscription Cycle

public enum SubscriptionCycle: String, Codable, CaseIterable, Sendable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"
    case custom = "custom"

    public var displayName: String {
        switch self {
        case .daily: return NumiLocalized.string( "subscription.cycle.daily")
        case .weekly: return NumiLocalized.string( "subscription.cycle.weekly")
        case .monthly: return NumiLocalized.string( "subscription.cycle.monthly")
        case .quarterly: return NumiLocalized.string("subscription.cycle.quarterly")
        case .yearly: return NumiLocalized.string( "subscription.cycle.yearly")
        case .custom: return NumiLocalized.string("subscription.cycle.custom")
        }
    }
}

public enum SubscriptionIntervalUnit: String, Codable, CaseIterable, Sendable {
    case day
    case week
    case month
    case year

    public var displayName: String {
        switch self {
        case .day: return NumiLocalized.string("subscription.interval.unit.day")
        case .week: return NumiLocalized.string("subscription.interval.unit.week")
        case .month: return NumiLocalized.string("subscription.interval.unit.month")
        case .year: return NumiLocalized.string("subscription.interval.unit.year")
        }
    }
}

public struct SubscriptionInterval: Codable, Equatable, Hashable, Sendable {
    public let value: Int
    public let unit: SubscriptionIntervalUnit

    public init?(value: Int, unit: SubscriptionIntervalUnit) {
        guard value > 0 else { return nil }
        self.value = value
        self.unit = unit
    }
}

// MARK: - Subscription Model

public struct Subscription: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var amount: Money
    public var cycle: SubscriptionCycle
    public var customInterval: SubscriptionInterval?
    public var categoryID: UUID?
    public var accountID: UUID?
    public var nextBillingDate: Date
    public var isEnabled: Bool
    public var note: String

    public init(
        id: UUID = UUID(),
        name: String,
        amount: Money,
        cycle: SubscriptionCycle,
        customInterval: SubscriptionInterval? = nil,
        categoryID: UUID? = nil,
        accountID: UUID? = nil,
        nextBillingDate: Date,
        isEnabled: Bool = true,
        note: String = ""
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.cycle = cycle
        self.customInterval = customInterval
        self.categoryID = categoryID
        self.accountID = accountID
        self.nextBillingDate = nextBillingDate
        self.isEnabled = isEnabled
        self.note = note
    }

    /// 计算下次扣费日期
    public func nextBillingDateAfter(_ date: Date, calendar: Calendar = .current) -> Date {
        switch cycle {
        case .daily: return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly: return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly: return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .yearly: return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        case .custom:
            guard let customInterval, customInterval.value > 0 else { return date }
            switch customInterval.unit {
            case .day: return calendar.date(byAdding: .day, value: customInterval.value, to: date) ?? date
            case .week: return calendar.date(byAdding: .weekOfYear, value: customInterval.value, to: date) ?? date
            case .month: return calendar.date(byAdding: .month, value: customInterval.value, to: date) ?? date
            case .year: return calendar.date(byAdding: .year, value: customInterval.value, to: date) ?? date
            }
        }
    }

    public func dueDates(through date: Date, calendar: Calendar = .current) -> [Date] {
        guard isEnabled else { return [] }
        var dates: [Date] = []
        var nextDate = nextBillingDate
        while nextDate <= date {
            dates.append(nextDate)
            let advanced = nextBillingDateAfter(nextDate, calendar: calendar)
            guard advanced > nextDate else { break }
            nextDate = advanced
        }
        return dates
    }

    public func reminderDate(daysBefore: Int = 1, calendar: Calendar = .current) -> Date? {
        guard isEnabled, daysBefore >= 0 else { return nil }
        return calendar.date(byAdding: .day, value: -daysBefore, to: nextBillingDate)
    }
}
