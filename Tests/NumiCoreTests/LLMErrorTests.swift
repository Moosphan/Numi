import XCTest
@testable import NumiCore

final class LLMErrorTests: XCTestCase {

    func testInvalidURLError() {
        let error = LLMError.invalidURL
        XCTAssertEqual(error.errorDescription, "请求地址无效")
    }

    func testInvalidResponseError() {
        let error = LLMError.invalidResponse
        XCTAssertEqual(error.errorDescription, "服务器响应无效")
    }

    func testHTTPError() {
        let error = LLMError.httpError(401)
        XCTAssertEqual(error.errorDescription, "服务器错误 (401)")
    }

    func testHTTPError500() {
        let error = LLMError.httpError(500)
        XCTAssertEqual(error.errorDescription, "服务器错误 (500)")
    }

    func testEmptyResponseError() {
        let error = LLMError.emptyResponse
        XCTAssertEqual(error.errorDescription, "AI 返回为空")
    }

    func testInvalidJSONError() {
        let error = LLMError.invalidJSON
        XCTAssertEqual(error.errorDescription, "AI 返回格式错误")
    }

    func testAllErrorsAreLocalized() {
        let errors: [LLMError] = [
            .invalidURL, .invalidResponse, .httpError(403),
            .emptyResponse, .invalidJSON
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}
