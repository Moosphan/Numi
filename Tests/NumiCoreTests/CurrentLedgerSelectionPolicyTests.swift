import XCTest
@testable import NumiCore

final class CurrentLedgerSelectionPolicyTests: XCTestCase {
    func testPrefersTheRequestedLedgerOverTheFirstAvailableLedger() {
        let firstLedger = Ledger(name: "Default", currencyCode: "CNY")
        let selectedLedger = Ledger(name: "Travel", currencyCode: "USD")

        let resolved = CurrentLedgerSelectionPolicy.resolve(
            currentLedgerID: selectedLedger.id,
            from: [firstLedger, selectedLedger]
        )

        XCTAssertEqual(resolved, selectedLedger)
    }
}
