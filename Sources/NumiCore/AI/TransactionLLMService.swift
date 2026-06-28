import Foundation

/// AI 账单解析服务协议
public protocol TransactionLLMService: Sendable {
    func parseTransaction(_ text: String, categories: [String], accounts: [String]) async throws -> ParsedTransaction
}

public extension TransactionLLMService {
    func parseTransaction(_ text: String, categories: [String]) async throws -> ParsedTransaction {
        try await parseTransaction(text, categories: categories, accounts: [])
    }
}
