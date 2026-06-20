import Foundation

/// 基于通义千问 API 的账单解析器
public final class QwenTransactionParser: TransactionLLMService, @unchecked Sendable {
    private let apiKey: String
    private let session: URLSession
    private let model: String

    public init(apiKey: String, model: String = "qwen-turbo", session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    public func parseTransaction(_ text: String, categories: [String]) async throws -> ParsedTransaction {
        let prompt = buildPrompt(text: text, categories: categories)
        let dto = try await callLLM(prompt: prompt)
        return try mapToDomain(dto)
    }

    // MARK: - Prompt

    private func buildPrompt(text: String, categories: [String]) -> String {
        let today = ISO8601DateFormatter().string(from: Date())
        return """
        你是一个记账助手。从用户输入中提取账单信息。

        用户输入：「\(text)」

        可用分类：\(categories.joined(separator: "、"))

        严格按以下 JSON 格式返回，不要输出其他内容：
        {
          "type": "expense",
          "amount": 35.00,
          "category": "餐饮",
          "account": null,
          "date": "2026-06-18",
          "note": "午饭"
        }

        规则：
        - type 只能是 expense、income、transfer
        - category 必须从可用分类中选择最接近的
        - date 用 ISO 8601 格式（今天=\(today)），相对日期转为绝对日期
        - account 如果用户没指定则为 null
        - amount 为正数
        """
    }

    // MARK: - Qwen API

    private func callLLM(prompt: String) async throws -> ParsedTransactionDTO {
        guard let url = URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions") else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 256
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw LLMError.httpError(code)
        }

        let qwenResp = try JSONDecoder().decode(QwenResponse.self, from: data)
        guard let content = qwenResp.choices.first?.message.content else {
            throw LLMError.emptyResponse
        }

        let jsonStr = extractJSON(from: content)
        guard let jsonData = jsonStr.data(using: .utf8) else {
            throw LLMError.invalidJSON
        }

        return try JSONDecoder().decode(ParsedTransactionDTO.self, from: jsonData)
    }

    // MARK: - Mapping

    private func mapToDomain(_ dto: ParsedTransactionDTO) throws -> ParsedTransaction {
        let type: TransactionType = switch dto.type {
            case "income": .income
            case "transfer": .transfer
            default: .expense
        }

        return ParsedTransaction(
            type: type,
            amount: dto.amount,
            categoryName: dto.category,
            accountName: dto.account,
            occurredAt: LLMMapper.parseDate(dto.date),
            note: dto.note ?? ""
        )
    }

    // MARK: - Helpers

    private func extractJSON(from text: String) -> String {
        if let start = text.range(of: "{"),
           let end = text.range(of: "}", options: .backwards) {
            return String(text[start.lowerBound..<end.upperBound])
        }
        return text
    }
}

// MARK: - Qwen Response

private struct QwenResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let message: Message
        struct Message: Decodable {
            let content: String
        }
    }
}
