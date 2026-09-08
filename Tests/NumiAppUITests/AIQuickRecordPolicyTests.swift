import XCTest
import NumiCore
@testable import NumiAppUI

final class AIQuickRecordPolicyTests: XCTestCase {
    func testPromptNormalizationTrimsMeaningfulInputAndRejectsWhitespace() {
        XCTAssertEqual(AIQuickRecordPrompt.normalized("  lunch 28  "), "lunch 28")
        XCTAssertNil(AIQuickRecordPrompt.normalized(" \n \t "))
    }

    func testLaunchPolicyRequiresProBeforeCheckingProviderConfiguration() {
        XCTAssertEqual(
            AIQuickRecordLaunchPolicy.destination(
                accessDecision: .blocked(context: .aiRecord),
                hasConfiguredProvider: true
            ),
            .upgrade(.aiRecord)
        )
    }

    func testLaunchPolicyGuidesGrantedUserWithoutProviderConfiguration() {
        XCTAssertEqual(
            AIQuickRecordLaunchPolicy.destination(
                accessDecision: .granted,
                hasConfiguredProvider: false
            ),
            .configureProvider
        )
    }

    func testLaunchPolicyAllowsGrantedUserWithConfiguredProviderToParse() {
        XCTAssertEqual(
            AIQuickRecordLaunchPolicy.destination(
                accessDecision: .granted,
                hasConfiguredProvider: true
            ),
            .parse
        )
    }
}
