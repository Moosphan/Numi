import XCTest
@testable import NumiAppUI
@testable import NumiCore

final class CSVImportTargetLedgerTests: XCTestCase {
    func testResolvesTheCurrentLedgerInsteadOfTheFirstExportedLedger() {
        let firstLedger = Ledger(name: "Personal", currencyCode: "CNY")
        let currentLedger = Ledger(name: "Travel", currencyCode: "USD")

        let resolved = CSVImportTargetLedger.resolve(
            currentLedgerID: currentLedger.id,
            from: [firstLedger, currentLedger]
        )

        XCTAssertEqual(resolved, currentLedger)
    }

    func testFallsBackToTheFirstLedgerWhenTheCurrentLedgerIsUnavailable() {
        let fallbackLedger = Ledger(name: "Personal", currencyCode: "CNY")

        let resolved = CSVImportTargetLedger.resolve(
            currentLedgerID: UUID(),
            from: [fallbackLedger]
        )

        XCTAssertEqual(resolved, fallbackLedger)
    }
}
