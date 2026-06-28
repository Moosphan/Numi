import Foundation

// MARK: - Subscription Cycle

public enum SubscriptionCycle: String, Codable, CaseIterable, Sendable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"

    public var displayName: String {
        switch self {
        case .daily: return NumiLocalized.string( "subscription.cycle.daily")
        case .weekly: return NumiLocalized.string( "subscription.cycle.weekly")
        case .monthly: return NumiLocalized.string( "subscription.cycle.monthly")
        case .yearly: return NumiLocalized.string( "subscription.cycle.yearly")
        }
    }
}

// MARK: - Subscription Model

public struct Subscription: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var amount: Money
    public var cycle: SubscriptionCycle
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
        case .yearly: return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}
