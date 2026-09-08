import Foundation
import XCTest
@testable import NumiAppUI

final class InsightsReportFileExporterTests: XCTestCase {
    func testWritesCSVToProvidedDirectoryWithCSVExtension() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = try InsightsReportFileExporter.write(
            csv: "period,metric\n2026-09,Expense",
            date: Date(timeIntervalSince1970: 0),
            directory: directory
        )

        XCTAssertEqual(url.pathExtension, "csv")
        XCTAssertTrue(url.lastPathComponent.hasPrefix("Numi_Insights_"))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "period,metric\n2026-09,Expense")
    }
}
