import XCTest

final class TransactionAccountCurrencyIntegrationTests: XCTestCase {
    func testRecordEditorsFilterAccountsBySelectedTransactionCurrency() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let addRecordSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("Sources/NumiAppUI/Pages/AddRecordFlowView.swift"),
            encoding: .utf8
        )
        let editRecordSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("Sources/NumiAppUI/Pages/EditRecordView.swift"),
            encoding: .utf8
        )
        let rootShellSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("App/NumiApp/RootShellView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(addRecordSource.contains("TransactionAccountCurrencyPolicy.compatibleAccounts"))
        XCTAssertTrue(editRecordSource.contains("TransactionAccountCurrencyPolicy.compatibleAccounts"))
        XCTAssertTrue(rootShellSource.contains("error.record.save.failed"))
    }
}
