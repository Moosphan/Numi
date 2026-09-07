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
    /// When enabled, the previous period's unused balance is added to this period.
    /// This is an opt-in Pro enhancement; existing budgets remain unchanged.
    public var isRolloverEnabled: Bool
    public var ledgerID: UUID
    public var categoryID: UUID?
    public var accountID: UUID?

    public init(
        id: UUID = UUID(),
        period: BudgetPeriod,
        amount: Money,
        isEnabled: Bool = true,
        isRolloverEnabled: Bool = false,
        ledgerID: UUID = UUID(),
        categoryID: UUID? = nil,
        accountID: UUID? = nil
    ) {
        self.id = id
        self.period = period
        self.amount = amount
        self.isEnabled = isEnabled
        self.isRolloverEnabled = isRolloverEnabled
        self.ledgerID = ledgerID
        self.categoryID = categoryID
        self.accountID = accountID
    }

    private enum CodingKeys: String, CodingKey {
        case id, period, amount, isEnabled, isRolloverEnabled, ledgerID, categoryID, accountID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        period = try container.decode(BudgetPeriod.self, forKey: .period)
        amount = try container.decode(Money.self, forKey: .amount)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        isRolloverEnabled = try container.decodeIfPresent(Bool.self, forKey: .isRolloverEnabled) ?? false
        ledgerID = try container.decode(UUID.self, forKey: .ledgerID)
        categoryID = try container.decodeIfPresent(UUID.self, forKey: .categoryID)
        accountID = try container.decodeIfPresent(UUID.self, forKey: .accountID)
    }
}

public enum BudgetSpendingCalculator {
    public static func spending(
        from transactions: [Transaction],
        categoryID: UUID? = nil,
        accountID: UUID? = nil,
        currencyCode: String,
        exchangeRateHistory: ExchangeRateHistory? = nil
    ) throws -> Money {
        let expensesByID = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })
        func matchesScope(_ transaction: Transaction) -> Bool {
            if let categoryID, transaction.categoryID != categoryID { return false }
            if let accountID, transaction.accountID != accountID { return false }
            return true
        }
        func normalizedAmount(_ transaction: Transaction) throws -> Money {
            let targetCurrencyCode = currencyCode.uppercased()
            guard transaction.amount.currencyCode != targetCurrencyCode else { return transaction.amount }
            if let convertedAmountAtRecord = transaction.convertedAmountAtRecord,
               convertedAmountAtRecord.currencyCode == targetCurrencyCode {
                return convertedAmountAtRecord
            }
            guard let exchangeRateHistory,
                  let converted = exchangeRateHistory.convert(transaction.amount, to: currencyCode, on: transaction.occurredAt)
            else {
                throw TransactionSummaryError.missingExchangeRate(
                    sourceCurrencyCode: transaction.amount.currencyCode,
                    targetCurrencyCode: targetCurrencyCode
                )
            }
            return converted
        }
        var result = Money.zero(currencyCode: currencyCode)

        for transaction in transactions {
            switch transaction.type {
            case .expense:
                guard matchesScope(transaction) else { continue }
                guard transaction.reimbursementID == nil else { continue }
                result = try result.adding(normalizedAmount(transaction))
            case .income:
                guard let originalID = transaction.refundOfTransactionID,
                      let original = expensesByID[originalID],
                      original.type == .expense,
                      original.reimbursementID == nil,
                      matchesScope(original) else { continue }
                result = try result.subtracting(normalizedAmount(transaction))
            case .transfer:
                continue
            }
        }
        return result
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
    /// Carries forward only unused funds. A prior overspend never silently reduces
    /// the next period's budget, which keeps the user's configured limit stable.
    public static func unusedCarryover(
        budgetAmount: Money,
        previousSpent: Money
    ) throws -> Money {
        let remaining = try budgetAmount.subtracting(previousSpent)
        guard remaining.minorUnits > 0 else {
            return .zero(currencyCode: budgetAmount.currencyCode)
        }
        return remaining
    }

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
