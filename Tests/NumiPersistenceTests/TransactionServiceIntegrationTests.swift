import XCTest
@testable import NumiCore
@testable import NumiPersistence

/// 端到端集成测试：真实 LLM 解析 → 分类匹配 → 持久化
/// 运行方式：
///   CLAUDE_API_KEY=sk-xxx swift test --filter TransactionServiceIntegrationTests
///   DEEPSEEK_API_KEY=sk-xxx swift test --filter TransactionServiceIntegrationTests
///   QWEN_API_KEY=sk-xxx swift test --filter TransactionServiceIntegrationTests
@MainActor
final class TransactionServiceIntegrationTests: XCTestCase {

    private func makeParser() throws -> TransactionLLMService {
        if let key = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"], !key.isEmpty {
            return ClaudeTransactionParser(apiKey: key)
        }
        if let key = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !key.isEmpty {
            return DeepSeekTransactionParser(apiKey: key)
        }
        if let key = ProcessInfo.processInfo.environment["QWEN_API_KEY"], !key.isEmpty {
            return QwenTransactionParser(apiKey: key)
        }
        throw XCTSkip("未设置任何 LLM API Key，跳过集成测试")
    }

    // MARK: - Full Pipeline: AI Parse → Category Match → Persist

    func testExpenseFullPipeline() async throws {
        let parser = try makeParser()
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()

        let categoryNames = store.categories.map(\.name)

        // Step 1: AI 解析
        let parsed = try await parser.parseTransaction("中午外卖28块", categories: categoryNames)

        XCTAssertEqual(parsed.type, .expense)
        XCTAssertEqual(parsed.amount, 28)
        XCTAssertTrue(categoryNames.contains(parsed.categoryName),
                       "AI 返回的分类 '\(parsed.categoryName)' 应存在于默认分类中")

        // Step 2: 匹配分类
        let category = store.categories.first { $0.name == parsed.categoryName }
        XCTAssertNotNil(category, "分类 '\(parsed.categoryName)' 应可精确匹配")

        // Step 3: 创建账单
        guard let account = store.accounts.first else {
            XCTFail("无默认账户")
            return
        }

        let money = try Money(decimalString: "\(parsed.amount)", currencyCode: "CNY")
        let tx = try store.createTransaction(
            type: parsed.type,
            amount: money,
            categoryID: category?.id,
            accountID: account.id,
            note: parsed.note
        )

        // Step 4: 验证持久化
        XCTAssertEqual(tx.type, .expense)
        XCTAssertEqual(tx.amount.minorUnits, 2800)
        XCTAssertEqual(tx.categoryID, category?.id)
        XCTAssertTrue(store.visibleTransactions.contains { $0.id == tx.id })
    }

    func testIncomeFullPipeline() async throws {
        let parser = try makeParser()
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()

        let parsed = try await parser.parseTransaction("收到工资8000元", categories: store.categories.map(\.name))

        XCTAssertEqual(parsed.type, .income)
        XCTAssertEqual(parsed.amount, 8000)

        let category = store.categories.first { $0.name == parsed.categoryName }
        XCTAssertNotNil(category, "分类 '\(parsed.categoryName)' 应可匹配")

        guard let account = store.accounts.first else { XCTFail("无默认账户"); return }
        let money = try Money(decimalString: "\(parsed.amount)", currencyCode: "CNY")
        let tx = try store.createTransaction(
            type: parsed.type,
            amount: money,
            categoryID: category?.id,
            accountID: account.id,
            note: parsed.note
        )

        XCTAssertEqual(tx.type, .income)
        XCTAssertTrue(store.visibleTransactions.contains { $0.id == tx.id })
    }

    func testTransferFullPipeline() async throws {
        let parser = try makeParser()
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()

        let parsed = try await parser.parseTransaction("转账500给老婆", categories: store.categories.map(\.name))

        XCTAssertEqual(parsed.type, .transfer)
        XCTAssertEqual(parsed.amount, 500)

        guard let account = store.accounts.first else { XCTFail("无默认账户"); return }
        let money = try Money(decimalString: "\(parsed.amount)", currencyCode: "CNY")
        let tx = try store.createTransaction(
            type: parsed.type,
            amount: money,
            categoryID: nil,
            accountID: account.id,
            note: parsed.note
        )

        XCTAssertEqual(tx.type, .transfer)
        XCTAssertTrue(store.visibleTransactions.contains { $0.id == tx.id })
    }

    // MARK: - Balance Verification

    func testExpenseReducesBalance() async throws {
        let parser = try makeParser()
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()

        guard let account = store.accounts.first else { XCTFail("无默认账户"); return }
        let initialBalance = account.balance.minorUnits

        let parsed = try await parser.parseTransaction("买咖啡32块", categories: store.categories.map(\.name))
        let money = try Money(decimalString: "\(parsed.amount)", currencyCode: "CNY")
        _ = try store.createTransaction(
            type: parsed.type,
            amount: money,
            categoryID: nil,
            accountID: account.id,
            note: parsed.note
        )

        let updatedAccount = store.accounts.first { $0.id == account.id }!
        XCTAssertLessThan(updatedAccount.balance.minorUnits, initialBalance, "支出后余额应减少")
    }

    // MARK: - Data Consistency

    func testMultipleTransactionsPersist() async throws {
        let parser = try makeParser()
        let store = try SwiftDataBookkeepingStore(inMemory: true)
        try store.seedDefaultsIfNeeded()

        guard let account = store.accounts.first else { XCTFail("无默认账户"); return }
        let inputs = ["早饭12块", "地铁5块", "午饭28块"]

        for input in inputs {
            let parsed = try await parser.parseTransaction(input, categories: store.categories.map(\.name))
            let money = try Money(decimalString: "\(parsed.amount)", currencyCode: "CNY")
            _ = try store.createTransaction(
                type: parsed.type,
                amount: money,
                categoryID: nil,
                accountID: account.id,
                note: parsed.note
            )
        }

        XCTAssertEqual(store.visibleTransactions.count, 3, "应有 3 条记录")
    }
}
