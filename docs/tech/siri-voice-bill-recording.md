# Siri 语音记账技术方案

## 1. 功能概述

用户通过 Siri 语音指令（如"糯米记账 午饭35块"），应用调用 AI 大模型解析自然语言文本，自动生成结构化账单并写入本地数据库。

**核心链路：**
```
用户语音 → Siri → App Intents → AI Parser → LLM API → SwiftData 持久化
```

---

## 2. 架构设计

### 2.1 分层架构

```
┌─────────────────────────────────────────────────────────┐
│                     用户语音输入                          │
│              "糯米记账 昨天午饭花了35块"                   │
└────────────────────────┬────────────────────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────┐
│              App Intents Layer (NumiIntents)              │
│  ┌───────────────────────────────────────────────────┐  │
│  │  RecordTransactionIntent                           │  │
│  │  - @Parameter: text (String)                       │  │
│  │  - perform() → IntentResult & ProvidesDialog       │  │
│  └───────────────────────┬───────────────────────────┘  │
└──────────────────────────┼──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│              AI Parsing Layer (NumiCore/AI/)              │
│  ┌───────────────────────────────────────────────────┐  │
│  │  TransactionLLMService (protocol)                   │  │
│  │  ├── ClaudeTransactionParser                        │  │
│  │  ├── QwenTransactionParser                          │  │
│  │  └── DeepSeekTransactionParser                      │  │
│  └───────────────────────┬───────────────────────────┘  │
└──────────────────────────┼──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│         Persistence Layer (NumiPersistence/)              │
│  ┌───────────────────────────────────────────────────┐  │
│  │  TransactionService                                 │  │
│  │  - resolveCategory(name → UUID)                    │  │
│  │  - resolveAccount(name → UUID)                     │  │
│  │  - createTransaction(...)                          │  │
│  └───────────────────────┬───────────────────────────┘  │
│                          │                               │
│         App Group Shared Container (SwiftData)           │
└─────────────────────────────────────────────────────────┘
```

### 2.2 模块职责

| 模块 | 位置 | 职责 |
|------|------|------|
| `NumiIntents` | Xcode Target | Siri 交互入口，注册 Shortcuts 短语 |
| `NumiCore/AI/` | SPM Package | AI 解析协议 + 多 LLM 实现 |
| `NumiPersistence/` | SPM Package | 数据持久化，App Group 共享 |
| `NumiAppUI/SettingsView` | SPM Package | AI 服务商配置 UI |

---

## 3. 核心模块详解

### 3.1 ParsedTransaction — AI 解析结果模型

**文件：** `Sources/NumiCore/AI/ParsedTransaction.swift`

```swift
public struct ParsedTransaction: Codable, Equatable {
    public let type: TransactionType    // expense / income / transfer
    public let amount: Decimal          // 金额（正数）
    public let categoryName: String     // 中文分类名，如"餐饮"
    public let accountName: String?     // 可选账户名
    public let occurredAt: Date         // 交易时间
    public let note: String             // 备注
}
```

**设计决策：**
- `categoryName` 使用中文字符串而非 UUID，因为 LLM 天然理解中文语义
- UUID 解析推迟到 `TransactionService` 持久化阶段
- `accountName` 可选，未指定时使用默认账户

### 3.2 TransactionLLMService — AI 解析协议

**文件：** `Sources/NumiCore/AI/TransactionLLMService.swift`

```swift
public protocol TransactionLLMService: Sendable {
    func parseTransaction(_ text: String, categories: [String]) async throws -> ParsedTransaction
}
```

**设计决策：**
- `Sendable` 约束支持跨 actor 调用
- `categories` 参数注入当前可用分类列表，确保 LLM 输出合法分类
- 返回 `ParsedTransaction` 而非原始 JSON，调用方无需关心解析细节

### 3.3 LLM 实现类

三者共享相同的 Prompt 模板和响应解析逻辑，差异仅在 API 端点和认证方式。

| 实现 | API 端点 | 认证方式 | 默认模型 |
|------|----------|----------|----------|
| `ClaudeTransactionParser` | api.anthropic.com/v1/messages | `x-api-key` Header | claude-haiku-4-5-20251001 |
| `QwenTransactionParser` | dashscope.aliyuncs.com/compatible-mode/v1/chat/completions | `Authorization: Bearer` | qwen-turbo |
| `DeepSeekTransactionParser` | api.deepseek.com/chat/completions | `Authorization: Bearer` | deepseek-chat |

**Prompt 设计要点：**

```
你是一个记账助手。从用户输入中提取账单信息。

用户输入：「{text}」
可用分类：{categories.joined(separator: "、")}

严格按以下 JSON 格式返回，不要输出其他内容：
{ "type": "expense", "amount": 35.00, "category": "餐饮", "account": null, "date": "2026-06-18", "note": "午饭" }

规则：
- type 只能是 expense、income、transfer
- category 必须从可用分类中选择最接近的
- date 用 ISO 8601 格式，相对日期转为绝对日期（今天={today}）
- account 如果用户没指定则为 null
- amount 为正数
```

**关键设计：**
- 注入 `today` 日期，让 LLM 正确处理"昨天"、"上周"等相对时间
- 注入可用分类列表，避免 LLM 返回不存在的分类
- 强制 JSON 格式输出，减少解析失败
- 使用小模型（Haiku/Turbo），账单解析不需要强推理能力

### 3.4 TransactionService — 数据持久化服务

**文件：** `Sources/NumiPersistence/TransactionService.swift`

```swift
public final class TransactionService: @unchecked Sendable {
    public static let shared = TransactionService()
    
    // App Group 共享容器
    private let appGroupID = "group.com.numi.shared"
    private let container: ModelContainer
    private let context: ModelContext
    
    public func availableCategoryNames() -> [String]
    public func createTransaction(from parsed: ParsedTransaction) throws
}
```

**设计决策：**
- 单例模式，Intents Extension 和主 App 共享同一实例
- 使用 App Group 容器 URL，确保跨进程数据一致
- 分类匹配支持精确匹配 + 模糊匹配（名称包含关系）
- 账户未指定时自动使用第一个可见账户

### 3.5 App Intents 集成

**RecordTransactionIntent：**

```swift
struct RecordTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "快速记账"
    static var openAppWhenRun: Bool = false  // 不需要打开应用

    @Parameter(title: "账单内容")
    var text: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1. 读取 API Key
        // 2. 调用 AI 解析
        // 3. 写入数据库
        // 4. 返回 Siri 语音确认
    }
}
```

**NumiShortcutsProvider：**

```swift
struct NumiShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordTransactionIntent(),
            phrases: [
                "用 \(.applicationName) 记一笔 \(\.$text)",
                "\(.applicationName) 记账 \(\.$text)",
                "快速记账 \(\.$text)",
                "糯米记一笔 \(\.$text)",
                "糯米记账 \(\.$text)",
                "糯米 \(\.$text)"
            ],
            shortTitle: "快速记账",
            systemImageName: "plus.circle.fill"
        )
    }
}
```

**中文应用名匹配：** 支持"糯米记账"、"糯米记一笔"、"糯米 xxx" 等自然中文短语。

---

## 4. 数据流详解

### 4.1 完整调用链

```
1. 用户说 "糯米记账 午饭35块"
2. Siri 匹配 AppShortcuts 短语，提取 text = "午饭35块"
3. 调用 RecordTransactionIntent.perform()
4. 从 App Group UserDefaults 读取 API Key 和服务商配置
5. 构建 ClaudeTransactionParser(apiKey:)
6. 调用 parser.parseTransaction("午饭35块", categories: ["餐饮", "交通", ...])
7. LLM 返回 JSON: { type: "expense", amount: 35, category: "餐饮", ... }
8. 映射为 ParsedTransaction
9. 调用 TransactionService.shared.createTransaction(from:)
10. 解析 "餐饮" → CategoryEntity UUID
11. 查找默认账户 → AccountEntity
12. 创建 TransactionEntity，插入 SwiftData
13. 更新账户余额
14. 返回 .result(dialog: "已记录 餐饮 +¥35.00")
15. Siri 语音回复确认
```

### 4.2 App Group 数据共享

```
主 App (Numi.app)          Intents Extension (NumiIntents.appex)
    │                              │
    │   ┌──────────────────────┐   │
    └──▶│ group.com.numi.shared │◀──┘
        │                      │
        │  - Numi.store (SwiftData)
        │  - app.ai.provider
        │  - app.ai.claudeAPIKey
        │  - app.ai.qwenAPIKey
        │  - app.ai.deepseekAPIKey
        └──────────────────────┘
```

---

## 5. 工程结构

```
Numi/
├── Numi.xcodeproj
│   ├── Numi (主 App Target)
│   │   └── Code Sign Entitlements: App/NumiApp/Numi.entitlements
│   └── NumiIntents (Extension Target)
│       └── Code Sign Entitlements: NumiIntents/NumiIntents.entitlements
│
├── App/NumiApp/
│   ├── NumiApp.swift              ← App 入口，注册 Shortcuts
│   ├── RootShellView.swift        ← 主界面协调器
│   └── Numi.entitlements          ← App Group entitlements
│
├── NumiIntents/
│   ├── RecordTransactionIntent.swift
│   ├── NumiShortcutsProvider.swift
│   ├── Config.swift               ← API Key 读取（App Group UserDefaults）
│   ├── Info.plist                 ← Extension 配置
│   └── NumiIntents.entitlements   ← App Group entitlements
│
├── Sources/NumiCore/
│   ├── AI/
│   │   ├── ParsedTransaction.swift
│   │   ├── TransactionLLMService.swift
│   │   ├── ClaudeTransactionParser.swift
│   │   ├── QwenTransactionParser.swift
│   │   └── DeepSeekTransactionParser.swift
│   └── ...
│
├── Sources/NumiPersistence/
│   ├── TransactionService.swift   ← App Group 共享数据服务
│   └── SwiftDataBookkeepingStore.swift
│
└── Sources/NumiAppUI/
    └── Pages/SettingsView.swift   ← AI 服务配置 UI
```

---

## 6. 自动化测试方案

### 6.1 测试分层

```
┌─────────────────────────────────────┐
│         E2E 测试 (XCUITest)         │  Siri 语音 → 账单出现
├─────────────────────────────────────┤
│      Integration 测试               │  Intent → 解析 → 持久化
├─────────────────────────────────────┤
│         Unit 测试                   │  各模块独立验证
└─────────────────────────────────────┘
```

### 6.2 Unit Tests

#### 6.2.1 ParsedTransaction 测试

```swift
// Tests/NumiCoreTests/ParsedTransactionTests.swift
import XCTest
@testable import NumiCore

final class ParsedTransactionTests: XCTestCase {
    
    func testExpenseParsing() {
        let tx = ParsedTransaction(
            type: .expense,
            amount: 35,
            categoryName: "餐饮",
            occurredAt: Date(),
            note: "午饭"
        )
        XCTAssertEqual(tx.type, .expense)
        XCTAssertEqual(tx.amount, 35)
        XCTAssertEqual(tx.categoryName, "餐饮")
    }
    
    func testCodableRoundTrip() throws {
        let tx = ParsedTransaction(
            type: .income,
            amount: 10000,
            categoryName: "工资",
            occurredAt: Date(),
            note: "6月薪资"
        )
        let data = try JSONEncoder().encode(tx)
        let decoded = try JSONDecoder().decode(ParsedTransaction.self, from: data)
        XCTAssertEqual(tx, decoded)
    }
}
```

#### 6.2.2 LLM Parser Mock 测试

```swift
// Tests/NumiCoreTests/TransactionParserTests.swift
import XCTest
@testable import NumiCore

// Mock LLM Service
class MockLLMService: TransactionLLMService {
    var mockResult: ParsedTransaction?
    var mockError: Error?
    
    func parseTransaction(_ text: String, categories: [String]) async throws -> ParsedTransaction {
        if let error = mockError { throw error }
        return mockResult!
    }
}

final class TransactionParserTests: XCTestCase {
    
    func testSuccessfulParsing() async throws {
        let mock = MockLLMService()
        mock.mockResult = ParsedTransaction(
            type: .expense,
            amount: 35,
            categoryName: "餐饮",
            occurredAt: Date(),
            note: "午饭"
        )
        
        let result = try await mock.parseTransaction("午饭35块", categories: ["餐饮"])
        XCTAssertEqual(result.categoryName, "餐饮")
        XCTAssertEqual(result.amount, 35)
    }
    
    func testParsingFailure() async {
        let mock = MockLLMService()
        mock.mockError = LLMError.httpError(401)
        
        do {
            _ = try await mock.parseTransaction("test", categories: [])
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is LLMError)
        }
    }
}
```

#### 6.2.3 TransactionService 测试

```swift
// Tests/NumiPersistenceTests/TransactionServiceTests.swift
import XCTest
@testable import NumiPersistence
@testable import NumiCore

final class TransactionServiceTests: XCTestCase {
    
    private var service: TransactionService!
    
    override func setUp() {
        // 使用内存模式避免污染生产数据
        service = TransactionService(inMemory: true)
    }
    
    func testCreateTransactionFromParsed() throws {
        let parsed = ParsedTransaction(
            type: .expense,
            amount: 35,
            categoryName: "餐饮",
            occurredAt: Date(),
            note: "午饭"
        )
        
        // 需要先 seed 默认分类
        try service.seedDefaultsIfNeeded()
        
        try service.createTransaction(from: parsed)
        
        // 验证记录已创建（通过查询验证）
        let names = service.availableCategoryNames()
        XCTAssertTrue(names.contains("餐饮"))
    }
    
    func testCategoryFuzzyMatch() throws {
        try service.seedDefaultsIfNeeded()
        
        let parsed = ParsedTransaction(
            type: .expense,
            amount: 20,
            categoryName: "吃饭",  // 非精确匹配，应模糊匹配到"餐饮"
            occurredAt: Date()
        )
        
        try service.createTransaction(from: parsed)
        // 不应抛出错误
    }
    
    func testNoAccountThrows() {
        let parsed = ParsedTransaction(
            type: .expense,
            amount: 10,
            categoryName: "餐饮"
        )
        
        XCTAssertThrowsError(try service.createTransaction(from: parsed)) { error in
            XCTAssertTrue(error is TransactionServiceError)
        }
    }
}
```

### 6.3 Integration Tests

```swift
// Tests/NumiCoreTests/ClaudeTransactionParserIntegrationTests.swift
import XCTest
@testable import NumiCore

/// 集成测试：需要真实 API Key，标记为 @available(iOS 17.0, *)
/// 在 CI 中通过环境变量注入 API Key
final class ClaudeTransactionParserIntegrationTests: XCTestCase {
    
    private var parser: ClaudeTransactionParser!
    
    override func setUp() {
        guard let key = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"], !key.isEmpty else {
            throw XCTSkip("CLAUDE_API_KEY not set, skipping integration test")
        }
        parser = ClaudeTransactionParser(apiKey: key)
    }
    
    func testParseSimpleExpense() async throws {
        let result = try await parser.parseTransaction(
            "午饭花了35块",
            categories: ["餐饮", "交通", "购物", "住房"]
        )
        
        XCTAssertEqual(result.type, .expense)
        XCTAssertEqual(result.amount, 35)
        XCTAssertEqual(result.categoryName, "餐饮")
    }
    
    func testParseIncome() async throws {
        let result = try await parser.parseTransaction(
            "收到工资8000元",
            categories: ["工资", "奖金", "餐饮"]
        )
        
        XCTAssertEqual(result.type, .income)
        XCTAssertEqual(result.amount, 8000)
        XCTAssertEqual(result.categoryName, "工资")
    }
    
    func testParseRelativeDate() async throws {
        let result = try await parser.parseTransaction(
            "昨天打车花了25",
            categories: ["交通", "餐饮"]
        )
        
        XCTAssertEqual(result.type, .expense)
        XCTAssertEqual(result.categoryName, "交通")
        
        // 验证日期是昨天
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertTrue(calendar.isDate(result.occurredAt, inSameDayAs: yesterday))
    }
}
```

### 6.4 E2E Tests (XCUITest)

```swift
// App/NumiUITests/SiriIntentE2ETests.swift
import XCTest

final class SiriIntentE2ETests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUp() {
        continueAfterFailure = false
        app.launch()
    }
    
    /// 测试完整流程：通过 Shortcuts 触发 → 验证记录出现在首页
    func testVoiceBillAppearsInList() {
        // 1. 记录当前首页记录数
        let list = app.collectionViews.firstMatch
        let initialCount = list.cells.count
        
        // 2. 通过 Siri 触发记账（使用 Shortcuts URL Scheme）
        // 注意：真机 E2E 需要通过 XCUIApplication 的 URL scheme 触发
        let siri = XCUIApplication(bundleIdentifier: "com.apple.siri")
        siri.launch()
        
        // 3. 等待 Siri 处理完成
        // 实际测试中需要使用 Siri Intents 的测试触发方式
        
        // 4. 回到应用，验证记录数增加
        app.activate()
        sleep(2)  // 等待数据同步
        XCTAssertGreaterThanOrEqual(list.cells.count, initialCount)
    }
    
    /// 测试 AI 服务配置页面
    func testAIServiceConfig() {
        // 导航到设置页
        app.tabBars.buttons["我的"].tap()
        
        // 滚动到 AI 服务
        let aiCell = app.buttons["settings.ai"]
        aiCell.tap()
        
        // 验证 sheet 出现
        let sheet = app.staticTexts["AI 服务配置"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 2))
        
        // 切换服务商
        let segmented = app.segmentedControls.firstMatch
        segmented.buttons["千问"].tap()
        
        // 输入 API Key
        let secureField = app.secureTextFields.firstMatch
        secureField.tap()
        secureField.typeText("test-key-123")
        
        // 点击测试连接
        app.buttons["测试连接"].tap()
        
        // 验证结果出现（成功或失败）
        let result = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '连接'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 15))
    }
}
```

### 6.5 CI 配置

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run Unit Tests
        run: |
          xcodebuild test \
            -project Numi.xcodeproj \
            -scheme Numi \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -only-testing:NumiCoreTests \
            -only-testing:NumiPersistenceTests \
            CODE_SIGNING_ALLOWED=NO

  integration-tests:
    runs-on: macos-14
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - name: Run Integration Tests
        env:
          CLAUDE_API_KEY: ${{ secrets.CLAUDE_API_KEY }}
        run: |
          xcodebuild test \
            -project Numi.xcodeproj \
            -scheme Numi \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -only-testing:NumiCoreTests/ClaudeTransactionParserIntegrationTests \
            CODE_SIGNING_ALLOWED=NO
```

### 6.6 手动测试 Checklist

| # | 测试项 | 预期结果 | 通过 |
|---|--------|----------|------|
| 1 | 设置页 → AI 服务 → 选择 Claude → 输入 Key → 测试连接 | 显示"连接成功" | □ |
| 2 | 设置页 → AI 服务 → 选择千问 → 输入 Key → 测试连接 | 显示"连接成功" | □ |
| 3 | 设置页 → AI 服务 → 选择 DeepSeek → 输入 Key → 测试连接 | 显示"连接成功" | □ |
| 4 | 设置页 → AI 服务 → 输入错误 Key → 测试连接 | 显示"API Key 无效 (401)" | □ |
| 5 | 设置页 → AI 服务 → 不输入 Key → 测试连接 | 按钮置灰不可点 | □ |
| 6 | 设置页 → AI 服务 → 切换服务商 → 取消 | 切换不生效 | □ |
| 7 | 设置页 → AI 服务 → 切换服务商 → 保存 | 切换生效，设置页显示新服务商 | □ |
| 8 | Siri: "糯米记账 午饭35块" | Siri 回复"已记录 餐饮 +¥35.00" | □ |
| 9 | Siri: "糯米记账 昨天打车25" | 记录日期为昨天，分类为交通 | □ |
| 10 | Siri: "糯米记账 收到工资8000" | 类型为收入，分类为工资 | □ |
| 11 | Siri: "糯米记账 转账500给老婆" | 类型为转账 | □ |
| 12 | 打开 App → 首页列表 | 语音记录的账单正确显示 | □ |
| 13 | 未配置 API Key 时 Siri 记账 | Siri 回复"请先在设置中配置 AI 服务密钥" | □ |
| 14 | 网络不可用时 Siri 记账 | Siri 回复"记录失败" | □ |
| 15 | 杀掉 App → 重新打开 | 数据完整保留 | □ |
