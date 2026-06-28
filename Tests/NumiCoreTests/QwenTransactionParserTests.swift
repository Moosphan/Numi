import XCTest
@testable import NumiCore

/// QwenTransactionParser 单元测试（Mock URLSession）
final class QwenTransactionParserTests: XCTestCase {

    private var parser: QwenTransactionParser!
    private var session: URLSession!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        parser = QwenTransactionParser(apiKey: "test-key", session: session)
    }

    override func tearDown() {
        MockURLProtocol.mockResponse = nil
        parser = nil
        session = nil
    }

    func testParseExpense() async throws {
        MockURLProtocol.mockResponse = (makeQwenJSON("""
        {"type":"expense","amount":42.5,"category":"购物","account":null,"date":"2026-06-20","note":"超市"}
        """), HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)

        let result = try await parser.parseTransaction("超市买了42.5的东西", categories: ["购物", "餐饮"])

        XCTAssertEqual(result.type, .expense)
        XCTAssertEqual(result.amount, 42.5)
        XCTAssertEqual(result.categoryName, "购物")
    }

    func testParseIncome() async throws {
        MockURLProtocol.mockResponse = (makeQwenJSON("""
        {"type":"income","amount":5000,"category":"奖金","account":null,"date":"2026-06-20","note":"绩效奖"}
        """), HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)

        let result = try await parser.parseTransaction("收到绩效奖金5000", categories: ["奖金", "工资"])

        XCTAssertEqual(result.type, .income)
        XCTAssertEqual(result.amount, 5000)
        XCTAssertEqual(result.categoryName, "奖金")
    }

    func testParseTransferWithTargetAccount() async throws {
        MockURLProtocol.mockResponse = (makeQwenJSON("""
        {"type":"transfer","amount":320,"category":"转账","account":"支付宝","targetAccount":"银行卡","date":"2026-06-20","note":"提现"}
        """), HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)

        let result = try await parser.parseTransaction("支付宝提现320到银行卡", categories: ["转账"], accounts: ["支付宝", "银行卡"])

        XCTAssertEqual(result.type, .transfer)
        XCTAssertEqual(result.amount, 320)
        XCTAssertEqual(result.accountName, "支付宝")
        XCTAssertEqual(result.targetAccountName, "银行卡")
    }

    func testHTTPError() async {
        MockURLProtocol.mockResponse = (Data(), HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 403, httpVersion: nil, headerFields: nil)!)

        do {
            _ = try await parser.parseTransaction("test", categories: [])
            XCTFail("Should throw")
        } catch {
            guard case LLMError.httpError(403) = error else {
                XCTFail("Expected httpError(403), got \(error)")
                return
            }
        }
    }

    // MARK: - Helpers

    private func makeQwenJSON(_ content: String) -> Data {
        let json = """
        {"id":"chatcmpl-test","object":"chat.completion","choices":[{"index":0,"message":{"role":"assistant","content":\(jsonEscape(content))},"finish_reason":"stop"}]}
        """
        return json.data(using: .utf8)!
    }

    private func jsonEscape(_ string: String) -> String {
        let escaped = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}
