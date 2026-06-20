import XCTest
@testable import NumiCore

/// DeepSeekTransactionParser 单元测试（Mock URLSession）
final class DeepSeekTransactionParserTests: XCTestCase {

    private var parser: DeepSeekTransactionParser!
    private var session: URLSession!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        parser = DeepSeekTransactionParser(apiKey: "test-key", session: session)
    }

    override func tearDown() {
        MockURLProtocol.mockResponse = nil
        parser = nil
        session = nil
    }

    func testParseExpense() async throws {
        MockURLProtocol.mockResponse = (makeDSJSON("""
        {"type":"expense","amount":18,"category":"餐饮","account":null,"date":"2026-06-20","note":"早餐"}
        """), HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)

        let result = try await parser.parseTransaction("早餐18块", categories: ["餐饮", "交通"])

        XCTAssertEqual(result.type, .expense)
        XCTAssertEqual(result.amount, 18)
        XCTAssertEqual(result.categoryName, "餐饮")
        XCTAssertEqual(result.note, "早餐")
    }

    func testParseWithDecimalAmount() async throws {
        MockURLProtocol.mockResponse = (makeDSJSON("""
        {"type":"expense","amount":99.9,"category":"购物","account":"支付宝","date":"2026-06-20","note":"买衣服"}
        """), HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)

        let result = try await parser.parseTransaction("支付宝买衣服99.9", categories: ["购物"])

        XCTAssertEqual(result.amount, 99.9)
        XCTAssertEqual(result.accountName, "支付宝")
    }

    func testHTTPError401() async {
        MockURLProtocol.mockResponse = (Data(), HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 401, httpVersion: nil, headerFields: nil)!)

        do {
            _ = try await parser.parseTransaction("test", categories: [])
            XCTFail("Should throw")
        } catch {
            guard case LLMError.httpError(401) = error else {
                XCTFail("Expected httpError(401), got \(error)")
                return
            }
        }
    }

    func testEmptyResponse() async {
        let json = #"{"id":"chatcmpl-test","object":"chat.completion","choices":[]}"#
        MockURLProtocol.mockResponse = (json.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)

        do {
            _ = try await parser.parseTransaction("test", categories: [])
            XCTFail("Should throw")
        } catch {
            guard case LLMError.emptyResponse = error else {
                XCTFail("Expected emptyResponse, got \(error)")
                return
            }
        }
    }

    // MARK: - Helpers

    private func makeDSJSON(_ content: String, content extraContent: String? = nil) -> Data {
        let text = extraContent ?? content
        let json = """
        {"id":"chatcmpl-test","object":"chat.completion","choices":[{"index":0,"message":{"role":"assistant","content":\(jsonEscape(text))},"finish_reason":"stop"}]}
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
