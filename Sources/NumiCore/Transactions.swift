import Foundation

public enum TransactionType: String, Codable, Sendable {
    case expense
    case income
    case transfer
}

public struct Transaction: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let type: TransactionType
    public let amount: Money
    public let occurredAt: Date
    public let categoryID: UUID?
    public let accountID: UUID?
    public let targetAccountID: UUID?
    public let note: String

    public init(
        id: UUID = UUID(),
        type: TransactionType,
        amount: Money,
        occurredAt: Date = Date(),
        categoryID: UUID? = nil,
        accountID: UUID? = nil,
        targetAccountID: UUID? = nil,
        note: String = ""
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.occurredAt = occurredAt
        self.categoryID = categoryID
        self.accountID = accountID
        self.targetAccountID = targetAccountID
        self.note = note
    }

    public static func sample(
        type: TransactionType,
        amount: Money,
        categoryID: UUID? = nil,
        accountID: UUID? = nil,
        targetAccountID: UUID? = nil
    ) -> Transaction {
        Transaction(type: type, amount: amount, categoryID: categoryID, accountID: accountID, targetAccountID: targetAccountID)
    }
}

public struct TransactionSummary: Equatable {
    public let expense: Money
    public let income: Money
    public let balance: Money
    public let recordCount: Int

    public init(expense: Money, income: Money, balance: Money, recordCount: Int) {
        self.expense = expense
        self.income = income
        self.balance = balance
        self.recordCount = recordCount
    }

    public static func monthly(transactions: [Transaction], currencyCode: String) throws -> TransactionSummary {
        var expense = Money.zero(currencyCode: currencyCode)
        var income = Money.zero(currencyCode: currencyCode)

        for transaction in transactions {
            switch transaction.type {
            case .expense:
                expense = try expense.adding(transaction.amount)
            case .income:
                income = try income.adding(transaction.amount)
            case .transfer:
                continue
            }
        }

        return TransactionSummary(
            expense: expense,
            income: income,
            balance: try income.subtracting(expense),
            recordCount: transactions.count
        )
    }
}

public struct CategoryDistributionItem: Equatable {
    public let categoryID: UUID
    public let amount: Money
    public let percentage: Double
}

public enum CategoryDistribution {
    public static func expense(transactions: [Transaction], currencyCode: String) throws -> [CategoryDistributionItem] {
        return try distribution(transactions: transactions, type: .expense, currencyCode: currencyCode)
    }

    public static func income(transactions: [Transaction], currencyCode: String) throws -> [CategoryDistributionItem] {
        return try distribution(transactions: transactions, type: .income, currencyCode: currencyCode)
    }

    private static func distribution(transactions: [Transaction], type: TransactionType, currencyCode: String) throws -> [CategoryDistributionItem] {
        var totals: [UUID: Money] = [:]

        for transaction in transactions where transaction.type == type {
            guard let categoryID = transaction.categoryID else { continue }
            let current = totals[categoryID] ?? .zero(currencyCode: currencyCode)
            totals[categoryID] = try current.adding(transaction.amount)
        }

        let totalMinorUnits = totals.values.reduce(Int64(0)) { $0 + $1.minorUnits }
        guard totalMinorUnits > 0 else { return [] }

        return totals
            .map { categoryID, money in
                CategoryDistributionItem(
                    categoryID: categoryID,
                    amount: money,
                    percentage: Double(money.minorUnits) / Double(totalMinorUnits)
                )
            }
            .sorted { $0.amount.minorUnits > $1.amount.minorUnits }
    }
}
