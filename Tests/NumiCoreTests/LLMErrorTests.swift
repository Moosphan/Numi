import XCTest
@testable import NumiCore

final class LLMErrorTests: XCTestCase {
    private let languageKey = "app.language"
    private var originalLanguage: String?

    override func setUp() {
        super.setUp()
        originalLanguage = UserDefaults.standard.string(forKey: languageKey)
    }

    override func tearDown() {
        if let originalLanguage {
            UserDefaults.standard.set(originalLanguage, forKey: languageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: languageKey)
        }
        super.tearDown()
    }

    func testInvalidURLError() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        let error = LLMError.invalidURL
        XCTAssertEqual(error.errorDescription, "请求地址无效")
    }

    func testInvalidResponseError() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        let error = LLMError.invalidResponse
        XCTAssertEqual(error.errorDescription, "服务器响应无效")
    }

    func testHTTPError() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        let error = LLMError.httpError(401)
        XCTAssertEqual(error.errorDescription, "服务器错误 (401)")
    }

    func testHTTPError500() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        let error = LLMError.httpError(500)
        XCTAssertEqual(error.errorDescription, "服务器错误 (500)")
    }

    func testEmptyResponseError() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        let error = LLMError.emptyResponse
        XCTAssertEqual(error.errorDescription, "AI 返回为空")
    }

    func testInvalidJSONError() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        let error = LLMError.invalidJSON
        XCTAssertEqual(error.errorDescription, "AI 返回格式错误")
    }

    func testErrorsTrackRuntimeLanguage() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(LLMError.invalidURL.errorDescription, "请求地址无效")
        XCTAssertEqual(LLMError.httpError(403).errorDescription, "服务器错误 (403)")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(LLMError.invalidURL.errorDescription, "Request URL is invalid")
        XCTAssertEqual(LLMError.httpError(403).errorDescription, "Server error (403)")
    }

    func testAllErrorsAreLocalized() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
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
