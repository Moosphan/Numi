import Foundation

public enum TransactionAIProvider: String, CaseIterable, Sendable {
    case claude
    case qwen
    case deepSeek = "deepseek"

    public static func resolve(
        preferredProvider: String,
        hasClaudeKey: Bool,
        hasQwenKey: Bool,
        hasDeepSeekKey: Bool
    ) -> TransactionAIProvider? {
        let preferred = TransactionAIProvider(rawValue: preferredProvider)
        switch preferred {
        case .claude where hasClaudeKey:
            return .claude
        case .qwen where hasQwenKey:
            return .qwen
        case .deepSeek where hasDeepSeekKey:
            return .deepSeek
        default:
            if hasDeepSeekKey { return .deepSeek }
            if hasClaudeKey { return .claude }
            if hasQwenKey { return .qwen }
            return nil
        }
    }
}
