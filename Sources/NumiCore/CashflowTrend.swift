import Foundation

public struct CashflowTrendPoint: Identifiable, Equatable, Sendable {
    public let date: Date
    public let expense: Money
    public let income: Money

    public var id: Date { date }

    public init(date: Date, expense: Money, income: Money) {
        self.date = date
        self.expense = expense
        self.income = income
    }
}

public enum CashflowTrend {
    public static func daily(
        transactions: [Transaction],
        interval: DateInterval,
        currencyCode: String,
        exchangeRateHistory: ExchangeRateHistory? = nil,
        calendar: Calendar
    ) throws -> [CashflowTrendPoint] {
        let normalizedCurrencyCode = currencyCode.uppercased()
        var totals: [Date: (expense: Money, income: Money)] = [:]
        var date = calendar.startOfDay(for: interval.start)

        while date < interval.end {
            totals[date] = (
                expense: .zero(currencyCode: normalizedCurrencyCode),
                income: .zero(currencyCode: normalizedCurrencyCode)
            )
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date), nextDate > date else { break }
            date = nextDate
        }

        for transaction in transactions where transaction.type != .transfer {
            let day = calendar.startOfDay(for: transaction.occurredAt)
            guard var dailyTotal = totals[day] else { continue }
            let amount = try normalizedAmount(
                transaction,
                currencyCode: normalizedCurrencyCode,
                exchangeRateHistory: exchangeRateHistory
            )
            switch transaction.type {
            case .expense:
                dailyTotal.expense = try dailyTotal.expense.adding(amount)
            case .income:
                dailyTotal.income = try dailyTotal.income.adding(amount)
            case .transfer:
                break
            }
            totals[day] = dailyTotal
        }

        return totals.keys.sorted().compactMap { date in
            guard let total = totals[date] else { return nil }
            return CashflowTrendPoint(date: date, expense: total.expense, income: total.income)
        }
    }

    private static func normalizedAmount(
        _ transaction: Transaction,
        currencyCode: String,
        exchangeRateHistory: ExchangeRateHistory?
    ) throws -> Money {
        guard transaction.amount.currencyCode != currencyCode else { return transaction.amount }
        if let convertedAmount = transaction.convertedAmountAtRecord,
           convertedAmount.currencyCode == currencyCode {
            return convertedAmount
        }
        if let exchangeRateHistory,
           let convertedAmount = exchangeRateHistory.convert(transaction.amount, to: currencyCode, on: transaction.occurredAt) {
            return convertedAmount
        }
        throw TransactionSummaryError.missingExchangeRate(
            sourceCurrencyCode: transaction.amount.currencyCode,
            targetCurrencyCode: currencyCode
        )
    }
}
