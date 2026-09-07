import XCTest
import NumiCore
@testable import NumiAppUI

final class AIRecordPrivacyPolicyTests: XCTestCase {
    func testRequiresDisclosureUntilTheSelectedProviderIsAcknowledged() {
        XCTAssertTrue(AIRecordPrivacyPolicy.requiresDisclosure(
            providerID: "claude",
            acknowledgedProviderID: nil
        ))
        XCTAssertTrue(AIRecordPrivacyPolicy.requiresDisclosure(
            providerID: "qwen",
            acknowledgedProviderID: "claude"
        ))
        XCTAssertFalse(AIRecordPrivacyPolicy.requiresDisclosure(
            providerID: "claude",
            acknowledgedProviderID: "claude"
        ))
    }

    func testRecordDraftKeepsAIParsedValuesForUserReview() throws {
        let accountID = UUID()
        let date = Date(timeIntervalSince1970: 1_725_000_000)
        let amount = try Money(decimalString: "28.50", currencyCode: "CNY")
        let draft = TransactionDraft(
            type: .expense,
            categoryID: UUID(),
            amount: amount,
            accountID: accountID,
            occurredAt: date,
            note: "午餐"
        )

        XCTAssertEqual(draft.amount, amount)
        XCTAssertEqual(draft.accountID, accountID)
        XCTAssertEqual(draft.occurredAt, date)
        XCTAssertEqual(draft.note, "午餐")
    }
}
