import XCTest

final class InsightsHeaderDesignTests: XCTestCase {
    func testAdvancedOptionsAreConsolidatedAndCustomRangeUsesRuntimeLocalization() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: sourceRoot.appendingPathComponent("Sources/NumiAppUI/Pages/InsightsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("showsAdvancedOptions"))
        XCTAssertTrue(source.contains("action.insightsAdvancedOptions"))
        XCTAssertFalse(source.contains("Text(customRange == nil ? \"insight.custom.range\""))
        XCTAssertTrue(source.contains("NumiLocalized.string(\"insight.custom.range\")"))
    }
}
