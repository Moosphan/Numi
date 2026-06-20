import Foundation

// MARK: - Installment Plan

public struct InstallmentPlan: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var totalAmount: Money
    public var feePerPeriod: Money
    public var periodCount: Int
    public var firstPaymentDate: Date
    public var accountID: UUID?
    public var categoryID: UUID?
    public var note: String

    public init(
        id: UUID = UUID(),
        name: String,
        totalAmount: Money,
        feePerPeriod: Money,
        periodCount: Int,
        firstPaymentDate: Date,
        accountID: UUID? = nil,
        categoryID: UUID? = nil,
        note: String = ""
    ) {
        self.id = id
        self.name = name
        self.totalAmount = totalAmount
        self.feePerPeriod = feePerPeriod
        self.periodCount = periodCount
        self.firstPaymentDate = firstPaymentDate
        self.accountID = accountID
        self.categoryID = categoryID
        self.note = note
    }

    /// 每期应付金额（含手续费）
    public var amountPerPeriod: Money {
        let basePerPeriod = totalAmount.minorUnits / Int64(periodCount)
        return Money(
            minorUnits: basePerPeriod + feePerPeriod.minorUnits,
            currencyCode: totalAmount.currencyCode
        )
    }

    /// 根据首期日期生成所有期次的到期日
    public func generateDueDates(calendar: Calendar = .current) -> [Date] {
        (0..<periodCount).compactMap { index in
            calendar.date(byAdding: .month, value: index, to: firstPaymentDate)
        }
    }
}

// MARK: - Installment Period

public struct InstallmentPeriod: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let planID: UUID
    public var periodIndex: Int
    public var dueDate: Date
    public var isRecorded: Bool
    public var isPaid: Bool
    public var transactionID: UUID?

    public init(
        id: UUID = UUID(),
        planID: UUID,
        periodIndex: Int,
        dueDate: Date,
        isRecorded: Bool = false,
        isPaid: Bool = false,
        transactionID: UUID? = nil
    ) {
        self.id = id
        self.planID = planID
        self.periodIndex = periodIndex
        self.dueDate = dueDate
        self.isRecorded = isRecorded
        self.isPaid = isPaid
        self.transactionID = transactionID
    }
}
