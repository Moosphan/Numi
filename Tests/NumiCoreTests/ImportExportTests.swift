import XCTest
@testable import NumiCore

final class ImportExportTests: XCTestCase {
    func testJSONExportRoundTripsTransactions() throws {
        let store = InMemoryBookkeepingStore()
        try store.seedDefaultsIfNeeded()
        let accountID = try XCTUnwrap(store.accounts.first?.id)
        _ = try store.createTransaction(
            type: .expense,
            amount: Money(decimalString: "19.90", currencyCode: "CNY"),
            categoryID: nil,
            accountID: accountID,
            ledgerID: store.ledgers.first!.id,
            note: "咖啡"
        )

        let data = try NumiJSONExporter.exportSnapshot(from: store.snapshot())
        let imported = try NumiJSONExporter.importSnapshot(from: data)

        XCTAssertEqual(imported.transactions.count, 1)
        XCTAssertEqual(imported.transactions[0].amount.formatted(), "¥19.90")
        XCTAssertEqual(imported.transactions[0].note, "咖啡")
    }

    func testCSVExportIncludesHeaderAndRows() throws {
        let transaction = Transaction.sample(
            type: .expense,
            amount: try Money(decimalString: "12.34", currencyCode: "CNY"),
            categoryID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )

        let csv = NumiCSVExporter.exportTransactions([transaction])

        XCTAssertTrue(csv.contains("id,type,amount,currency,occurredAt,categoryID,accountID,targetAccountID,note"))
        XCTAssertTrue(csv.contains(",expense,12.34,CNY,"))
    }

    func testCSVImporterReportsInvalidRows() {
        let csv = """
        type,amount,currency,note
        expense,12.30,CNY,午餐
        income,broken,CNY,错误
        """

        let result = NumiCSVImporter.importTransactions(csv: csv)

        XCTAssertEqual(result.transactions.count, 1)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(result.errors[0].lineNumber, 3)
    }
}
