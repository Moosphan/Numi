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

    func testJSONExportRoundTripsExchangeRateHistory() throws {
        let effectiveDate = Date(timeIntervalSince1970: 1_700_000_000)
        let history = ExchangeRateHistory(snapshots: [
            ExchangeRateSnapshot(baseCode: "CNY", rates: ["CNY": 1, "USD": 0.14], effectiveDate: effectiveDate)
        ])
        var snapshot = BookkeepingSnapshot()
        snapshot.exchangeRateHistory = history

        let data = try NumiJSONExporter.exportSnapshot(from: snapshot)
        let imported = try NumiJSONExporter.importSnapshot(from: data)

        XCTAssertEqual(imported.exchangeRateHistory, history)
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

    func testCSVImporterUsesInjectedDefaultCurrencyWhenColumnIsAbsent() throws {
        let result = NumiCSVImporter.importTransactions(
            csv: "type,amount\nexpense,12.30",
            currencyCode: "USD"
        )

        XCTAssertEqual(result.transactions.count, 1)
        XCTAssertEqual(result.transactions[0].amount, try Money(decimalString: "12.30", currencyCode: "USD"))
    }

    func testCSVImporterMapsQuotedValuesAndResolvesNames() throws {
        let category = Category(kind: .expense, name: "餐饮", icon: "fork.knife", sortOrder: 0)
        let account = Account(name: "现金", type: .cash, balance: .zero(currencyCode: "CNY"))
        let ledger = Ledger(name: "默认账本", currencyCode: "CNY")
        let document = try CSVImportDocument(csv: "kind,total,day,category_name,wallet,memo\nexpense,12.30,2026-09-01,餐饮,现金,\"午餐,咖啡\"")
        var mapping = CSVImportMapping(headers: document.headers)
        mapping.assign(.type, to: "kind")
        mapping.assign(.amount, to: "total")
        mapping.assign(.date, to: "day")
        mapping.assign(.category, to: "category_name")
        mapping.assign(.account, to: "wallet")
        mapping.assign(.note, to: "memo")

        let result = NumiCSVImporter.preview(
            document: document,
            mapping: mapping,
            context: CSVImportContext(ledger: ledger, categories: [category], accounts: [account])
        )

        XCTAssertEqual(result.transactions.count, 1)
        XCTAssertEqual(result.transactions[0].categoryID, category.id)
        XCTAssertEqual(result.transactions[0].accountID, account.id)
        XCTAssertEqual(result.transactions[0].note, "午餐,咖啡")
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testCSVImporterKeepsValidRowsWhenOtherRowsAreInvalid() throws {
        let ledger = Ledger(name: "默认账本", currencyCode: "CNY")
        let document = try CSVImportDocument(csv: "type,amount,category\nexpense,12.30,不存在\nincome,bad,\nexpense,8.00,")

        let result = NumiCSVImporter.preview(
            document: document,
            mapping: CSVImportMapping(headers: document.headers),
            context: CSVImportContext(ledger: ledger, categories: [], accounts: [])
        )

        XCTAssertEqual(result.transactions.count, 1)
        XCTAssertEqual(result.errors.map(\.lineNumber), [2, 3])
    }

    func testCSVImporterPreservesTransactionIDWhenProvided() throws {
        let transactionID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let csv = "id,type,amount,currency\n\(transactionID.uuidString),expense,12.30,USD"

        let result = NumiCSVImporter.importTransactions(csv: csv)

        XCTAssertEqual(result.transactions.count, 1)
        XCTAssertEqual(result.transactions.first?.id, transactionID)
    }

    func testCSVRoundTripPreservesReimbursementAndRefundLinks() throws {
        let reimbursementID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let refundID = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!
        let transaction = Transaction(
            type: .expense,
            amount: try Money(decimalString: "12.30", currencyCode: "USD"),
            reimbursementID: reimbursementID,
            refundOfTransactionID: refundID
        )
        let csv = NumiCSVExporter.exportTransactions([transaction])
        let result = NumiCSVImporter.importTransactions(csv: csv)

        XCTAssertEqual(result.transactions.first?.reimbursementID, reimbursementID)
        XCTAssertEqual(result.transactions.first?.refundOfTransactionID, refundID)
    }

    func testCSVRoundTripPreservesTransferTargetAccount() throws {
        let sourceAccountID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let targetAccountID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let transaction = Transaction(
            type: .transfer,
            amount: try Money(decimalString: "12.30", currencyCode: "USD"),
            accountID: sourceAccountID,
            targetAccountID: targetAccountID
        )
        let csv = NumiCSVExporter.exportTransactions([transaction])
        let source = Account(id: sourceAccountID, name: "Source", type: .cash, balance: .zero(currencyCode: "USD"))
        let target = Account(id: targetAccountID, name: "Target", type: .debitCard, balance: .zero(currencyCode: "USD"))
        let result = NumiCSVImporter.preview(
            document: try CSVImportDocument(csv: csv),
            mapping: CSVImportMapping(headers: try CSVImportDocument(csv: csv).headers),
            context: CSVImportContext(ledger: Ledger(name: "Ledger", currencyCode: "USD"), categories: [], accounts: [source, target])
        )

        XCTAssertEqual(result.transactions.count, 1)
        XCTAssertEqual(result.transactions.first?.type, .transfer)
        XCTAssertEqual(result.transactions.first?.accountID, sourceAccountID)
        XCTAssertEqual(result.transactions.first?.targetAccountID, targetAccountID)
    }
}
