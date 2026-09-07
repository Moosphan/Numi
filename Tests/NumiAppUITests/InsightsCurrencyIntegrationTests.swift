import XCTest

final class InsightsCurrencyIntegrationTests: XCTestCase {
    func testCategoryDetailReceivesPreconvertedDistributionAmount() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let rootShellSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("App/NumiApp/RootShellView.swift"),
            encoding: .utf8
        )
        let detailSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("Sources/NumiAppUI/Pages/InsightsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(rootShellSource.contains("totalAmount: selectedCategoryRow.amount"))
        XCTAssertTrue(rootShellSource.contains("currencyCode: activeCurrencyCode"))
        XCTAssertTrue(rootShellSource.contains("exchangeRateHistory: rateService.history"))
        XCTAssertTrue(detailSource.contains("private let totalAmount: Money"))
        XCTAssertTrue(detailSource.contains("private let currencyCode: String"))
        XCTAssertTrue(detailSource.contains("private let exchangeRateHistory: ExchangeRateHistory"))
        XCTAssertFalse(detailSource.contains("private var totalAmount: Money"))
    }
}
