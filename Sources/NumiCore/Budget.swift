import Foundation

public enum BudgetPeriod: String, Codable, Sendable {
    case week
    case month
}

public struct BudgetLimit: Equatable, Sendable {
    public let amount: Money
    public let period: BudgetPeriod
    public let startsOn: Date
    public let endsOn: Date

    public init(amount: Money, period: BudgetPeriod, startsOn: Date, endsOn: Date) {
        self.amount = amount
        self.period = period
        self.startsOn = startsOn
        self.endsOn = endsOn
    }
}

public struct BudgetSetting: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var period: BudgetPeriod
    public var amount: Money
    public var isEnabled: Bool
    public var ledgerID: UUID

    public init(
        id: UUID = UUID(),
        period: BudgetPeriod,
        amount: Money,
        isEnabled: Bool = true,
        ledgerID: UUID = UUID()
    ) {
        self.id = id
        self.period = period
        self.amount = amount
        self.isEnabled = isEnabled
        self.ledgerID = ledgerID
    }
}

public struct BudgetStatus: Equatable, Sendable {
    public let remaining: Money
    public let dailySuggestion: Money
    public let isOverBudget: Bool

    public init(remaining: Money, dailySuggestion: Money, isOverBudget: Bool) {
        self.remaining = remaining
        self.dailySuggestion = dailySuggestion
        self.isOverBudget = isOverBudget
    }
}

public enum BudgetCalculator {
    public static func status(
        for budget: BudgetLimit,
        spent: Money,
        today: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) throws -> BudgetStatus {
        let remaining = try budget.amount.subtracting(spent)
        let isOverBudget = remaining.minorUnits < 0
        let dailySuggestion: Money

        if isOverBudget {
            dailySuggestion = .zero(currencyCode: budget.amount.currencyCode)
        } else {
            let remainingDays = max(1, inclusiveDays(from: today, through: budget.endsOn, calendar: calendar))
            dailySuggestion = Money(
                minorUnits: remaining.minorUnits / Int64(remainingDays),
                currencyCode: budget.amount.currencyCode
            )
        }

        return BudgetStatus(
            remaining: remaining,
            dailySuggestion: dailySuggestion,
            isOverBudget: isOverBudget
        )
    }

    private static func inclusiveDays(from start: Date, through end: Date, calendar: Calendar) -> Int {
        let startOfDay = calendar.startOfDay(for: start)
        let endOfDay = calendar.startOfDay(for: end)
        let components = calendar.dateComponents([.day], from: startOfDay, to: endOfDay)
        return (components.day ?? 0) + 1
    }
}
