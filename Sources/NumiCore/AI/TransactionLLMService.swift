import Foundation

/// AI 账单解析服务协议
public protocol TransactionLLMService: Sendable {
    func parseTransaction(_ text: String, categories: [String]) async throws -> ParsedTransaction
}
