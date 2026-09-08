import XCTest
@testable import NumiAppUI

final class HomeSummaryCardOrderPolicyTests: XCTestCase {
    func testParsesKnownCardsOnceThenAppendsMissingDefaults() {
        let cards = HomeSummaryCardOrderPolicy.cards(from: "recordCount,unknown,expense,recordCount")

        XCTAssertEqual(cards, [.recordCount, .expense, .income, .balance])
    }

    func testSerializesAndRestoresUserOrder() {
        let serialized = HomeSummaryCardOrderPolicy.serialized([
            .balance,
            .income,
            .recordCount,
            .expense
        ])

        XCTAssertEqual(serialized, "balance,income,recordCount,expense")
        XCTAssertEqual(
            HomeSummaryCardOrderPolicy.cards(from: serialized),
            [.balance, .income, .recordCount, .expense]
        )
    }
}
