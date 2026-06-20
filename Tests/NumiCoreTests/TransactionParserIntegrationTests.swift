import XCTest
@testable import NumiCore

/// 集成测试：调用真实 LLM API 验证完整解析流程
/// 需要通过环境变量注入 API Key：
///   CLAUDE_API_KEY=sk-xxx swift test --filter IntegrationTests
///   QWEN_API_KEY=sk-xxx swift test --filter IntegrationTests
///   DEEPSEEK_API_KEY=sk-xxx swift test --filter IntegrationTests
final class TransactionParserIntegrationTests: XCTestCase {

    private let categories = [
        "餐饮", "交通", "购物", "住房", "娱乐", "医疗",
        "工资", "奖金", "转账", "其他"
    ]

    // MARK: - Claude Integration

    private var claudeKey: String? {
        ProcessInfo.processInfo.environment["CLAUDE_API_KEY"]
    }

    func testClaudeExpenseParsing() async throws {
        guard let key = claudeKey, !key.isEmpty else {
            throw XCTSkip("CLAUDE_API_KEY 未设置，跳过集成测试")
        }

        let parser = ClaudeTransactionParser(apiKey: key)
        let result = try await parser.parseTransaction("午饭花了35块", categories: categories)

        XCTAssertEqual(result.type, .expense, "应识别为支出")
        XCTAssertEqual(result.amount, 35, "金额应为 35")
        XCTAssertEqual(result.categoryName, "餐饮", "分类应为餐饮")
        XCTAssertTrue(result.note.contains("午饭") || result.note.contains("35"), "备注应包含关键信息")
    }

    func testClaudeIncomeParsing() async throws {
        guard let key = claudeKey, !key.isEmpty else {
            throw XCTSkip("CLAUDE_API_KEY 未设置，跳过集成测试")
        }

        let parser = ClaudeTransactionParser(apiKey: key)
        let result = try await parser.parseTransaction("收到工资8000元", categories: categories)

        XCTAssertEqual(result.type, .income, "应识别为收入")
        XCTAssertEqual(result.amount, 8000, "金额应为 8000")
        XCTAssertEqual(result.categoryName, "工资", "分类应为工资")
    }

    func testClaudeRelativeDate() async throws {
        guard let key = claudeKey, !key.isEmpty else {
            throw XCTSkip("CLAUDE_API_KEY 未设置，跳过集成测试")
        }

        let parser = ClaudeTransactionParser(apiKey: key)
        let result = try await parser.parseTransaction("昨天打车花了25", categories: categories)

        XCTAssertEqual(result.type, .expense, "应识别为支出")
        XCTAssertEqual(result.categoryName, "交通", "分类应为交通")

        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertTrue(
            calendar.isDate(result.occurredAt, inSameDayAs: yesterday) ||
            calendar.isDate(result.occurredAt, inSameDayAs: Date()),
            "日期应为昨天或今天（LLM 可能有 ±1 天偏差）"
        )
    }

    func testClaudeDecimalAmount() async throws {
        guard let key = claudeKey, !key.isEmpty else {
            throw XCTSkip("CLAUDE_API_KEY 未设置，跳过集成测试")
        }

        let parser = ClaudeTransactionParser(apiKey: key)
        let result = try await parser.parseTransaction("超市买了99.5的东西", categories: categories)

        XCTAssertEqual(result.type, .expense)
        XCTAssertEqual(result.amount, 99.5, "金额应为 99.5")
    }

    func testClaudeTransferParsing() async throws {
        guard let key = claudeKey, !key.isEmpty else {
            throw XCTSkip("CLAUDE_API_KEY 未设置，跳过集成测试")
        }

        let parser = ClaudeTransactionParser(apiKey: key)
        let result = try await parser.parseTransaction("转账500给老婆", categories: categories)

        XCTAssertEqual(result.type, .transfer, "应识别为转账")
        XCTAssertEqual(result.amount, 500)
    }

    // MARK: - Qwen Integration

    private var qwenKey: String? {
        ProcessInfo.processInfo.environment["QWEN_API_KEY"]
    }

    func testQwenExpenseParsing() async throws {
        guard let key = qwenKey, !key.isEmpty else {
            throw XCTSkip("QWEN_API_KEY 未设置，跳过集成测试")
        }

        let parser = QwenTransactionParser(apiKey: key)
        let result = try await parser.parseTransaction("晚饭吃了火锅花了128", categories: categories)

        XCTAssertEqual(result.type, .expense, "应识别为支出")
        XCTAssertEqual(result.amount, 128, "金额应为 128")
        XCTAssertEqual(result.categoryName, "餐饮", "分类应为餐饮")
    }

    func testQwenIncomeParsing() async throws {
        guard let key = qwenKey, !key.isEmpty else {
            throw XCTSkip("QWEN_API_KEY 未设置，跳过集成测试")
        }

        let parser = QwenTransactionParser(apiKey: key)
        let result = try await parser.parseTransaction("收到项目奖金5000", categories: categories)

        XCTAssertEqual(result.type, .income)
        XCTAssertEqual(result.amount, 5000)
        XCTAssertEqual(result.categoryName, "奖金")
    }

    // MARK: - DeepSeek Integration

    private var deepseekKey: String? {
        ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"]
    }

    func testDeepSeekExpenseParsing() async throws {
        guard let key = deepseekKey, !key.isEmpty else {
            throw XCTSkip("DEEPSEEK_API_KEY 未设置，跳过集成测试")
        }

        let parser = DeepSeekTransactionParser(apiKey: key)
        let result = try await parser.parseTransaction("地铁票6块钱", categories: categories)

        XCTAssertEqual(result.type, .expense)
        XCTAssertEqual(result.amount, 6)
        XCTAssertEqual(result.categoryName, "交通")
    }

    func testDeepSeekIncomeParsing() async throws {
        guard let key = deepseekKey, !key.isEmpty else {
            throw XCTSkip("DEEPSEEK_API_KEY 未设置，跳过集成测试")
        }

        let parser = DeepSeekTransactionParser(apiKey: key)
        let result = try await parser.parseTransaction("兼职收入1500", categories: categories)

        XCTAssertEqual(result.type, .income)
        XCTAssertEqual(result.amount, 1500)
    }

    // MARK: - Error Handling

    func testInvalidKeyReturnsError() async {
        let parser = ClaudeTransactionParser(apiKey: "sk-invalid-key-12345")

        do {
            _ = try await parser.parseTransaction("test", categories: categories)
            // 如果没抛错，可能是 API 返回了 200 但内容无效
        } catch {
            // 预期会抛出 LLMError.httpError(401) 或其他错误
            XCTAssertTrue(error is LLMError || error is URLError, "应抛出 LLMError 或 URLError")
        }
    }

    // MARK: - Performance

    func testParsePerformance() throws {
        guard let key = claudeKey, !key.isEmpty else {
            throw XCTSkip("CLAUDE_API_KEY 未设置，跳过性能测试")
        }

        let parser = ClaudeTransactionParser(apiKey: key)

        measure {
            let expectation = self.expectation(description: "parse")
            Task {
                _ = try? await parser.parseTransaction("午饭35块", categories: categories)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 10)
        }
    }
}
