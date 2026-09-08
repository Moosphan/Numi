import XCTest
import NumiCore
@testable import NumiAppUI

final class InsightsReportFormatterTests: XCTestCase {
    override func setUp() {
        super.setUp()
        NumiAppUILocalization.registerBundle()
    }

    func testFormatsPeriodScopeAndComparisonForSharing() {
        let summary = TransactionSummary(
            expense: Money(minorUnits: 12_000, currencyCode: "CNY"),
            income: Money(minorUnits: 20_000, currencyCode: "CNY"),
            balance: Money(minorUnits: 8_000, currencyCode: "CNY"),
            recordCount: 3
        )
        let previous = TransactionSummary(
            expense: Money(minorUnits: 10_000, currencyCode: "CNY"),
            income: Money(minorUnits: 18_000, currencyCode: "CNY"),
            balance: Money(minorUnits: 8_000, currencyCode: "CNY"),
            recordCount: 2
        )

        let report = InsightsReportFormatter.text(
            periodTitle: "2026年9月",
            accountName: "现金",
            summary: summary,
            previousSummary: previous,
            locale: Locale(identifier: "zh-Hans")
        )

        XCTAssertTrue(report.contains("洞悉摘要"))
        XCTAssertTrue(report.contains("2026年9月"))
        XCTAssertTrue(report.contains("现金"))
        XCTAssertTrue(report.contains("¥120.00"))
        XCTAssertTrue(report.contains("与上一周期对比"))
    }

    func testFormatsMachineReadableCSVReportWithScopeAndSummaryRows() {
        let summary = TransactionSummary(
            expense: Money(minorUnits: 12_000, currencyCode: "CNY"),
            income: Money(minorUnits: 20_000, currencyCode: "CNY"),
            balance: Money(minorUnits: 8_000, currencyCode: "CNY"),
            recordCount: 3
        )

        let report = InsightsReportFormatter.csv(
            periodTitle: "2026年9月",
            accountName: "现金, 日常",
            summary: summary,
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(report.split(separator: "\n").first, "period,account,metric,value,currency")
        XCTAssertTrue(report.contains("\"现金, 日常\""))
        XCTAssertTrue(report.contains("Expense,120,CNY"))
        XCTAssertTrue(report.contains("Income,200,CNY"))
        XCTAssertTrue(report.contains("Balance,80,CNY"))
        XCTAssertTrue(report.contains("Record Count,3,"))
    }
}
