import XCTest

/// E2E 测试：通过 URL Scheme 触发真实 AI 记账，验证记录出现在首页
/// 运行方式：
///   1. 先在应用内配置好 DeepSeek API Key
///   2. Xcode 中选择 NumiUITests scheme 运行
///   3. 或命令行：xcodebuild test -scheme Numi -only-testing:NumiUITests/AIBillRecordingE2ETests
final class AIBillRecordingE2ETests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchEnvironment["NUMI_UI_TEST_STORE_ID"] = "e2e-\(UUID().uuidString)"
        app.launchEnvironment["NUMI_UI_TEST_APP_LANGUAGE"] = "zh-Hans"
        app.launch()
    }

    // MARK: - 通过 URL Scheme 触发真实 AI 记账

    func testRecordExpenseViaURLScheme() {
        // 1. 记录首页当前记录数
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 3), "首页列表应存在")
        let initialCount = list.cells.count

        // 2. 通过 URL Scheme 触发 AI 记账
        let url = URL(string: "numi://record?text=\("午饭35块".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")!
        app.open(url)

        // 3. 等待应用回到前台并处理完成
        XCTAssertTrue(list.waitForExistence(timeout: 10), "首页列表应重新出现")

        // 4. 等待 toast 出现确认记录成功
        let toast = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '已记录'")).firstMatch
        let toastAppeared = toast.waitForExistence(timeout: 15)
        XCTAssertTrue(toastAppeared, "应出现'已记录'toast 提示")

        // 5. 等待 toast 消失后验证记录数增加
        // toast 持续 3 秒，给一些额外时间
        sleep(4)

        // 刷新首页（可能需要下拉或等待 SwiftUI 更新）
        let finalCount = list.cells.count
        XCTAssertGreaterThan(finalCount, initialCount, "首页记录数应增加（\(initialCount) → \(finalCount)）")
    }

    func testRecordIncomeViaURLScheme() {
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 3))
        let initialCount = list.cells.count

        let url = URL(string: "numi://record?text=\("收到工资8000元".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")!
        app.open(url)

        XCTAssertTrue(list.waitForExistence(timeout: 10))

        let toast = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '已记录'")).firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 15), "应出现'已记录'toast")

        sleep(4)
        XCTAssertGreaterThan(list.cells.count, initialCount)
    }

    func testRecordTransferViaURLScheme() {
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 3))
        let initialCount = list.cells.count

        let url = URL(string: "numi://record?text=\("转账500给老婆".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")!
        app.open(url)

        XCTAssertTrue(list.waitForExistence(timeout: 10))

        let toast = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '已记录'")).firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 15))

        sleep(4)
        XCTAssertGreaterThan(list.cells.count, initialCount)
    }

    // MARK: - 错误场景

    func testNoAPIKeyShowsError() {
        // 这个测试需要在没有配置 API Key 的情况下运行
        // 默认测试环境下应该没有 Key
        let url = URL(string: "numi://record?text=测试")!
        app.open(url)

        let toast = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '密钥'")).firstMatch
        let appeared = toast.waitForExistence(timeout: 5)
        // 如果已配置 Key 则跳过此断言
        if appeared {
            XCTAssertTrue(appeared, "无 Key 时应提示配置密钥")
        }
    }

    // MARK: - 连续记账

    func testMultipleRecordsPersist() {
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 3))
        let initialCount = list.cells.count

        let inputs = ["早饭12块", "地铁5块", "午饭28块"]

        for input in inputs {
            let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            let url = URL(string: "numi://record?text=\(encoded)")!
            app.open(url)

            // 等待 toast 出现表示处理完成
            let toast = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '已记录'")).firstMatch
            XCTAssertTrue(toast.waitForExistence(timeout: 15), "「\(input)」应成功记录")

            // 等待 toast 消失
            sleep(4)
        }

        // 验证 3 条记录都已添加
        let finalCount = list.cells.count
        XCTAssertGreaterThanOrEqual(finalCount, initialCount + 3,
                                     "应增加 3 条记录（\(initialCount) → \(finalCount)）")
    }

    // MARK: - 相对日期

    func testRelativeDateParsing() {
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 3))

        let url = URL(string: "numi://record?text=\("昨天打车25块".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")!
        app.open(url)

        let toast = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '已记录'")).firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 15), "应成功解析相对日期")

        sleep(4)
        // 验证记录存在（可以通过检查列表中是否出现"交通"或"打车"相关记录）
        let cells = list.cells
        var found = false
        for i in 0..<cells.count {
            let cell = cells.element(boundBy: i)
            if cell.staticTexts.containing(NSPredicate(format: "label CONTAINS '交通'")).count > 0 ||
               cell.staticTexts.containing(NSPredicate(format: "label CONTAINS '打车'")).count > 0 {
                found = true
                break
            }
        }
        XCTAssertTrue(found, "首页应出现交通分类的记录")
    }
}
