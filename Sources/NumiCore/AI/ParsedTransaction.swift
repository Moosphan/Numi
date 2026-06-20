import Foundation

// MARK: - AI 解析结果

public struct ParsedTransaction: Codable, Equatable {
    public let type: TransactionType
    public let amount: Decimal
    public let categoryName: String
    public let accountName: String?
    public let occurredAt: Date
    public let note: String

    public init(
        type: TransactionType,
        amount: Decimal,
        categoryName: String,
        accountName: String? = nil,
        occurredAt: Date = Date(),
        note: String = ""
    ) {
        self.type = type
        self.amount = amount
        self.categoryName = categoryName
        self.accountName = accountName
        self.occurredAt = occurredAt
        self.note = note
    }
}

// MARK: - LLM 返回的原始 DTO

struct ParsedTransactionDTO: Decodable {
    let type: String
    let amount: Decimal
    let category: String
    let account: String?
    let date: String?
    let note: String?
}
