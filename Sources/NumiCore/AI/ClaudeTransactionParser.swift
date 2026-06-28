import Foundation

/// 基于 Claude API 的账单解析器
public final class ClaudeTransactionParser: TransactionLLMService, @unchecked Sendable {
    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func parseTransaction(_ text: String, categories: [String], accounts: [String]) async throws -> ParsedTransaction {
        let prompt = buildPrompt(text: text, categories: categories, accounts: accounts)
        let dto = try await callLLM(prompt: prompt)
        return try mapToDomain(dto)
    }

    // MARK: - Prompt

    private func buildPrompt(text: String, categories: [String], accounts: [String]) -> String {
        let today = ISO8601DateFormatter().string(from: Date())
        let exampleCategory = categories.first ?? "Other"
        let availableAccounts = accounts.isEmpty ? "（未提供）" : accounts.joined(separator: "、")
        let exampleAccount = accounts.first ?? "Cash"
        return """
        你是一个记账助手。从用户输入中提取账单信息。

        用户输入：「\(text)」

        可用分类：\(categories.joined(separator: "、"))
        可用账户：\(availableAccounts)

        严格按以下 JSON 格式返回，不要输出其他内容：
        {
          "type": "expense",
          "amount": 35.00,
          "category": "\(exampleCategory)",
          "account": "\(exampleAccount)",
          "targetAccount": null,
          "date": "2026-06-18",
          "note": "午饭"
        }

        规则：
        - type 只能是 expense、income、transfer
        - expense / income 时，category 必须从可用分类中选择最接近的
        - transfer 时，category 返回“转账”或与用户输入一致的转账语义词即可
        - account 表示转出账户 / 收支账户；targetAccount 仅在 transfer 时使用，表示转入账户
        - 如果提供了可用账户，account 和 targetAccount 必须优先从可用账户中选择最接近的；未指定时返回 null
        - date 用 ISO 8601 格式（今天=\(today)），相对日期转为绝对日期
        - amount 为正数
        """
    }

    // MARK: - Claude API

    private func callLLM(prompt: String) async throws -> ParsedTransactionDTO {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 256,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw LLMError.httpError(httpResponse.statusCode)
        }

        let claudeResp = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let content = claudeResp.content.first?.text else {
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
            targetAccountName: dto.targetAccount,
            occurredAt: LLMMapper.parseDate(dto.date),
            note: dto.note ?? ""
        )
    }

    // MARK: - Helpers

    private func extractJSON(from text: String) -> String {
        // 去掉 ```json ... ``` 包裹
        if let start = text.range(of: "{"),
           let end = text.range(of: "}", options: .backwards) {
            return String(text[start.lowerBound..<end.upperBound])
        }
        return text
    }
}

// MARK: - Claude Response

private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]
    struct ContentBlock: Decodable {
        let text: String
    }
}

// MARK: - Errors

public enum LLMError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case emptyResponse
    case invalidJSON

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return NumiLocalized.string("error.ai.invalid.url")
        case .invalidResponse: return NumiLocalized.string("error.ai.invalid.response")
        case .httpError(let code): return NumiLocalized.string("error.ai.http", code)
        case .emptyResponse: return NumiLocalized.string("error.ai.empty.response")
        case .invalidJSON: return NumiLocalized.string("error.ai.invalid.json")
        }
    }
}

// MARK: - ISO8601 Extensions

extension ISO8601DateFormatter {
    convenience init(_ options: Options) {
        self.init()
        formatOptions = options
    }
}

// MARK: - Shared Mapper

enum LLMMapper {
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parseDate(_ string: String?) -> Date {
        guard let string else { return Date() }
        return formatter.date(from: string) ?? Date()
    }

    static func extractJSON(from text: String) -> String {
        if let start = text.range(of: "{"),
           let end = text.range(of: "}", options: .backwards) {
            return String(text[start.lowerBound..<end.upperBound])
        }
        return text
    }
}
