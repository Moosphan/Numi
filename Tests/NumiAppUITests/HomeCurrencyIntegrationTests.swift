import XCTest

final class HomeCurrencyIntegrationTests: XCTestCase {
    func testHomeAndInsightsDiscloseUnavailableHistoricalRates() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let rootShellSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("App/NumiApp/RootShellView.swift"),
            encoding: .utf8
        )
        let homeSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("Sources/NumiAppUI/Pages/TransactionsHomeView.swift"),
            encoding: .utf8
        )
        let insightsSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("Sources/NumiAppUI/Pages/InsightsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(rootShellSource.contains("let dailyResult = currencySummary(for: rows.map(\\.transaction))"))
        XCTAssertTrue(rootShellSource.contains("hasUnavailableHistoricalRate: dailyResult.hasUnavailableHistoricalRate"))
        XCTAssertTrue(rootShellSource.contains("hasUnavailableHistoricalRate: data.hasUnavailableHistoricalRate"))
        XCTAssertTrue(rootShellSource.contains("hasUnavailableHistoricalRate: summaryResult.hasUnavailableHistoricalRate"))
        XCTAssertTrue(homeSource.contains("private let hasUnavailableHistoricalRate: Bool"))
        XCTAssertTrue(insightsSource.contains("private let hasUnavailableHistoricalRate: Bool"))
    }
}
