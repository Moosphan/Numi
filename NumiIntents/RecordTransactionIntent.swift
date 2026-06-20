import AppIntents
import NumiCore
import NumiPersistence

struct RecordTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "快速记账"
    static var description = IntentDescription("通过语音快速记录一笔账单")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "账单内容")
    var text: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = TransactionService.shared
        let categories = service.availableCategoryNames()

        guard !categories.isEmpty else {
            return .result(dialog: "请先在应用中设置分类")
        }

        let apiKey = Config.llmAPIKey
        guard !apiKey.isEmpty else {
            return .result(dialog: "请先在设置中配置 AI 服务密钥")
        }

        let parser = ClaudeTransactionParser(apiKey: apiKey)

        do {
            let parsed = try await parser.parseTransaction(text, categories: categories)
            try service.createTransaction(from: parsed)

            let symbol = parsed.type == .income ? "+" : "-"
            return .result(
                dialog: "已记录 \(parsed.categoryName) \(symbol)¥\(parsed.amount)"
            )
        } catch {
            return .result(dialog: "记录失败：\(error.localizedDescription)")
        }
    }
}
