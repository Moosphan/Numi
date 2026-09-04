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
    public let ledgerID: UUID
    public let note: String
    public let reimbursementID: UUID?
    public let refundOfTransactionID: UUID?

    private enum CodingKeys: String, CodingKey {
        case id, type, amount, occurredAt, categoryID, accountID, targetAccountID, ledgerID, note
        case reimbursementID, refundOfTransactionID
    }

    public init(
        id: UUID = UUID(),
        type: TransactionType,
        amount: Money,
        occurredAt: Date = Date(),
        categoryID: UUID? = nil,
        accountID: UUID? = nil,
        targetAccountID: UUID? = nil,
        ledgerID: UUID = UUID(),
        note: String = "",
        reimbursementID: UUID? = nil,
        refundOfTransactionID: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.occurredAt = occurredAt
        self.categoryID = categoryID
        self.accountID = accountID
        self.targetAccountID = targetAccountID
        self.ledgerID = ledgerID
        self.note = note
        self.reimbursementID = reimbursementID
        self.refundOfTransactionID = refundOfTransactionID
    }

    public init(
        id: UUID = UUID(),
        type: TransactionType,
        amount: Money,
        occurredAt: Date = Date(),
        categoryID: UUID?,
        accountID: UUID?,
        targetAccountID: UUID?,
        ledgerID: UUID,
        note: String
    ) {
        self.init(
            id: id,
            type: type,
            amount: amount,
            occurredAt: occurredAt,
            categoryID: categoryID,
            accountID: accountID,
            targetAccountID: targetAccountID,
            ledgerID: ledgerID,
            note: note,
            reimbursementID: nil,
            refundOfTransactionID: nil
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.type = try container.decode(TransactionType.self, forKey: .type)
        self.amount = try container.decode(Money.self, forKey: .amount)
        self.occurredAt = try container.decode(Date.self, forKey: .occurredAt)
        self.categoryID = try container.decodeIfPresent(UUID.self, forKey: .categoryID)
        self.accountID = try container.decodeIfPresent(UUID.self, forKey: .accountID)
        self.targetAccountID = try container.decodeIfPresent(UUID.self, forKey: .targetAccountID)
        self.ledgerID = try container.decode(UUID.self, forKey: .ledgerID)
        self.note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        self.reimbursementID = try container.decodeIfPresent(UUID.self, forKey: .reimbursementID)
        self.refundOfTransactionID = try container.decodeIfPresent(UUID.self, forKey: .refundOfTransactionID)
    }

    public static func sample(
        type: TransactionType,
        amount: Money,
        categoryID: UUID? = nil,
        accountID: UUID? = nil,
        targetAccountID: UUID? = nil,
        ledgerID: UUID = UUID()
    ) -> Transaction {
        Transaction(type: type, amount: amount, categoryID: categoryID, accountID: accountID, targetAccountID: targetAccountID, ledgerID: ledgerID)
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

    public static func monthly(
        transactions: [Transaction],
        currencyCode: String,
        exchangeRateHistory: ExchangeRateHistory? = nil
    ) throws -> TransactionSummary {
        var expense = Money.zero(currencyCode: currencyCode)
        var income = Money.zero(currencyCode: currencyCode)

        for transaction in transactions {
            switch transaction.type {
            case .expense:
                let amount = try normalizedAmount(
                    transaction,
                    currencyCode: currencyCode,
                    exchangeRateHistory: exchangeRateHistory
                )
                expense = try expense.adding(amount)
            case .income:
                let amount = try normalizedAmount(
                    transaction,
                    currencyCode: currencyCode,
                    exchangeRateHistory: exchangeRateHistory
                )
                income = try income.adding(amount)
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

    private static func normalizedAmount(
        _ transaction: Transaction,
        currencyCode: String,
        exchangeRateHistory: ExchangeRateHistory?
    ) throws -> Money {
        guard transaction.amount.currencyCode != currencyCode.uppercased() else { return transaction.amount }
        guard let exchangeRateHistory,
              let converted = exchangeRateHistory.convert(transaction.amount, to: currencyCode, on: transaction.occurredAt)
        else {
            throw TransactionSummaryError.missingExchangeRate(
                sourceCurrencyCode: transaction.amount.currencyCode,
                targetCurrencyCode: currencyCode.uppercased()
            )
        }
        return converted
    }
}

public enum TransactionSummaryError: Error, Equatable {
    case missingExchangeRate(sourceCurrencyCode: String, targetCurrencyCode: String)
}

public struct CategoryDistributionItem: Equatable {
    public let categoryID: UUID
    public let amount: Money
    public let percentage: Double
}

public enum CategoryDistribution {
    public static func expense(
        transactions: [Transaction],
        currencyCode: String,
        exchangeRateHistory: ExchangeRateHistory? = nil
    ) throws -> [CategoryDistributionItem] {
        return try distribution(
            transactions: transactions,
            type: .expense,
            currencyCode: currencyCode,
            exchangeRateHistory: exchangeRateHistory
        )
    }

    public static func income(
        transactions: [Transaction],
        currencyCode: String,
        exchangeRateHistory: ExchangeRateHistory? = nil
    ) throws -> [CategoryDistributionItem] {
        return try distribution(
            transactions: transactions,
            type: .income,
            currencyCode: currencyCode,
            exchangeRateHistory: exchangeRateHistory
        )
    }

    private static func distribution(
        transactions: [Transaction],
        type: TransactionType,
        currencyCode: String,
        exchangeRateHistory: ExchangeRateHistory?
    ) throws -> [CategoryDistributionItem] {
        var totals: [UUID: Money] = [:]

        for transaction in transactions where transaction.type == type {
            guard let categoryID = transaction.categoryID else { continue }
            let amount: Money
            if transaction.amount.currencyCode == currencyCode.uppercased() {
                amount = transaction.amount
            } else if let exchangeRateHistory,
                      let converted = exchangeRateHistory.convert(transaction.amount, to: currencyCode, on: transaction.occurredAt) {
                amount = converted
            } else {
                throw TransactionSummaryError.missingExchangeRate(
                    sourceCurrencyCode: transaction.amount.currencyCode,
                    targetCurrencyCode: currencyCode.uppercased()
                )
            }
            let current = totals[categoryID] ?? .zero(currencyCode: currencyCode)
            totals[categoryID] = try current.adding(amount)
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
