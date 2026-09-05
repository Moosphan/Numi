import Foundation
import NumiCore

enum Config {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.numi.shared")
    }

    static func transactionParser() -> TransactionLLMService? {
        let claudeKey = defaults?.string(forKey: "app.ai.claudeAPIKey") ?? ""
        let qwenKey = defaults?.string(forKey: "app.ai.qwenAPIKey") ?? ""
        let deepSeekKey = defaults?.string(forKey: "app.ai.deepseekAPIKey") ?? ""
        let preferredProvider = defaults?.string(forKey: "app.ai.provider") ?? TransactionAIProvider.claude.rawValue

        switch TransactionAIProvider.resolve(
            preferredProvider: preferredProvider,
            hasClaudeKey: !claudeKey.isEmpty,
            hasQwenKey: !qwenKey.isEmpty,
            hasDeepSeekKey: !deepSeekKey.isEmpty
        ) {
        case .claude:
            return ClaudeTransactionParser(apiKey: claudeKey)
        case .qwen:
            return QwenTransactionParser(apiKey: qwenKey)
        case .deepSeek:
            return DeepSeekTransactionParser(apiKey: deepSeekKey)
        case nil:
            return nil
        }
    }
}
