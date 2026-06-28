import XCTest
@testable import NumiCore

/// ClaudeTransactionParser 单元测试（Mock URLSession）
final class ClaudeTransactionParserTests: XCTestCase {

    private var parser: ClaudeTransactionParser!
    private var session: URLSession!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        parser = ClaudeTransactionParser(apiKey: "test-key", session: session)
    }

    override func tearDown() {
        MockURLProtocol.mockResponse = nil
        parser = nil
        session = nil
    }

    // MARK: - Success Cases

    func testParseExpense() async throws {
        MockURLProtocol.mockResponse = (makeClaudeJSON("""
        {"type":"expense","amount":35,"category":"餐饮","account":null,"date":"2026-06-18","note":"午饭"}
        """), HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)

        let result = try await parser.parseTransaction("午饭35块", categories: ["餐饮", "交通"])

        XCTAssertEqual(result.type, .expense)
        XCTAssertEqual(result.amount, 35)
        XCTAssertEqual(result.categoryName, "餐饮")
        XCTAssertNil(result.accountName)
        XCTAssertEqual(result.note, "午饭")
    }

    func testParseIncome() async throws {
        MockURLProtocol.mockResponse = (makeClaudeJSON("""
        {"type":"income","amount":8000,"category":"工资","account":"银行卡","targetAccount":null,"date":"2026-06-18","note":"6月工资"}
        """), HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)

        let result = try await parser.parseTransaction("收到工资8000", categories: ["工资", "餐饮"])

        XCTAssertEqual(result.type, .income)
        XCTAssertEqual(result.amount, 8000)
        XCTAssertEqual(result.categoryName, "工资")
        XCTAssertEqual(result.accountName, "银行卡")
        XCTAssertNil(result.targetAccountName)
    }

    func testParseTransfer() async throws {
        MockURLProtocol.mockResponse = (makeClaudeJSON("""
        {"type":"transfer","amount":500,"category":"转账","account":"现金","targetAccount":"银行卡","date":"2026-06-18","note":"转给老婆"}
        """), HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)

        let result = try await parser.parseTransaction("转账500给老婆", categories: ["转账"], accounts: ["现金", "银行卡"])

        XCTAssertEqual(result.type, .transfer)
        XCTAssertEqual(result.amount, 500)
        XCTAssertEqual(result.accountName, "现金")
        XCTAssertEqual(result.targetAccountName, "银行卡")
    }

    func testParseWithMarkdownCodeBlock() async throws {
        MockURLProtocol.mockResponse = (makeClaudeJSON("""
        ```json
        {"type":"expense","amount":25,"category":"交通","account":null,"date":"2026-06-18","note":"地铁"}
        ```
        """), HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)

        let result = try await parser.parseTransaction("坐地铁25块", categories: ["交通"])

        XCTAssertEqual(result.type, .expense)
        XCTAssertEqual(result.amount, 25)
        XCTAssertEqual(result.categoryName, "交通")
    }

    // MARK: - Error Cases

    func testHTTPError401() async {
        MockURLProtocol.mockResponse = (Data(), HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 401, httpVersion: nil, headerFields: nil)!)

        do {
            _ = try await parser.parseTransaction("test", categories: ["餐饮"])
            XCTFail("Should throw")
        } catch {
            guard case LLMError.httpError(401) = error else {
                XCTFail("Expected httpError(401), got \(error)")
                return
            }
        }
    }

    func testHTTPError500() async {
        MockURLProtocol.mockResponse = (Data(), HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 500, httpVersion: nil, headerFields: nil)!)

        do {
            _ = try await parser.parseTransaction("test", categories: ["餐饮"])
            XCTFail("Should throw")
        } catch {
            guard case LLMError.httpError(500) = error else {
                XCTFail("Expected httpError(500), got \(error)")
                return
            }
        }
    }

    func testEmptyContentThrows() async {
        // Mock 返回空 content 数组（没有 text 字段）
        let json = #"{"id":"msg_test","type":"message","role":"assistant","content":[]}"#
        MockURLProtocol.mockResponse = (json.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)

        do {
            _ = try await parser.parseTransaction("test", categories: ["餐饮"])
            XCTFail("Should throw")
        } catch {
            guard case LLMError.emptyResponse = error else {
                XCTFail("Expected emptyResponse, got \(error)")
                return
            }
        }
    }

    func testInvalidJSONThrows() async {
        MockURLProtocol.mockResponse = (makeClaudeJSON("not json at all"), HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)

        do {
            _ = try await parser.parseTransaction("test", categories: ["餐饮"])
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is DecodingError || error is LLMError)
        }
    }

    // MARK: - Helpers

    private func makeClaudeJSON(_ content: String, content extraContent: String? = nil) -> Data {
        let text = extraContent ?? content
        let json = """
        {"id":"msg_test","type":"message","role":"assistant","content":[{"type":"text","text":\(jsonEscape(text))}]}
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

// MARK: - Mock URL Protocol

class MockURLProtocol: URLProtocol {
    static var mockResponse: (Data, HTTPURLResponse)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let (data, response) = MockURLProtocol.mockResponse else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "test", code: -1))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
