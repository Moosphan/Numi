import XCTest
@testable import NumiCore

final class LLMMapperTests: XCTestCase {

    // MARK: - Extract JSON

    func testExtractJSONFromPlainJSON() {
        let input = #"{"type":"expense","amount":35,"category":"餐饮"}"#
        let result = LLMMapper.extractJSON(from: input)
        XCTAssertTrue(result.hasPrefix("{"))
        XCTAssertTrue(result.hasSuffix("}"))
    }

    func testExtractJSONFromMarkdownCodeBlock() {
        let input = """
        这是解析结果：
        ```json
        {"type":"expense","amount":35,"category":"餐饮"}
        ```
        """
        let result = LLMMapper.extractJSON(from: input)
        XCTAssertTrue(result.contains("\"type\""))
        XCTAssertTrue(result.contains("\"expense\""))
    }

    func testExtractJSONFromTextWithBraces() {
        let input = "根据你的输入，我提取到：{\"type\":\"income\",\"amount\":1000}"
        let result = LLMMapper.extractJSON(from: input)
        XCTAssertTrue(result.hasPrefix("{"))
        XCTAssertTrue(result.hasSuffix("}"))
    }

    func testExtractJSONReturnsOriginalIfNoBraces() {
        let input = "no json here"
        let result = LLMMapper.extractJSON(from: input)
        XCTAssertEqual(result, input)
    }

    // MARK: - Parse Date

    func testParseNilDateReturnsNow() {
        let before = Date()
        let result = LLMMapper.parseDate(nil)
        let after = Date()
        XCTAssertTrue(result >= before && result <= after)
    }

    func testParseEmptyStringReturnsNow() {
        let before = Date()
        let result = LLMMapper.parseDate("")
        let after = Date()
        XCTAssertTrue(result >= before && result <= after)
    }

    func testParseValidISODate() {
        let result = LLMMapper.parseDate("2026-06-20")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(calendar.component(.year, from: result), 2026)
        XCTAssertEqual(calendar.component(.month, from: result), 6)
        XCTAssertEqual(calendar.component(.day, from: result), 20)
    }

    func testParseInvalidDateReturnsNow() {
        let before = Date()
        let result = LLMMapper.parseDate("not-a-date")
        let after = Date()
        XCTAssertTrue(result >= before && result <= after)
    }
}
