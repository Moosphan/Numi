import AppIntents
import NumiCore
import NumiPersistence

struct RecordTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.record.title"
    static var description = IntentDescription("intent.record.description")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "intent.param.content")
    var text: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = TransactionService.shared
        guard service.isAvailable else {
            let message = NumiLocalized.string("error.transaction.initialization.failed")
            return .result(dialog: IntentDialog("\(message)"))
        }
        let categories = service.availableCategoryNames()

        guard !categories.isEmpty else {
            return .result(dialog: IntentDialog(LocalizedStringResource("intent.error.no.categories")))
        }

        let apiKey = Config.llmAPIKey
        guard !apiKey.isEmpty else {
            return .result(dialog: IntentDialog(LocalizedStringResource("intent.error.no.key")))
        }

        let parser = ClaudeTransactionParser(apiKey: apiKey)

        do {
            let parsed = try await parser.parseTransaction(text, categories: categories)
            let recordedAmount = try service.createTransaction(from: parsed)

            let symbol = parsed.type == .income ? "+" : "-"
            let message = NumiLocalized.string("intent.success", parsed.categoryName, symbol, recordedAmount.formatted())
            return .result(
                dialog: IntentDialog("\(message)")
            )
        } catch {
            let message = NumiLocalized.string("intent.fail", error.localizedDescription)
            return .result(dialog: IntentDialog("\(message)"))
        }
    }
}
