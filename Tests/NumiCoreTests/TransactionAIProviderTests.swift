import XCTest
@testable import NumiCore

final class TransactionAIProviderTests: XCTestCase {
    func testResolverPrefersSelectedProviderWhenItsKeyIsAvailable() {
        XCTAssertEqual(
            TransactionAIProvider.resolve(
                preferredProvider: "qwen",
                hasClaudeKey: true,
                hasQwenKey: true,
                hasDeepSeekKey: true
            ),
            .qwen
        )
    }

    func testResolverFallsBackToAvailableProviderInStableOrder() {
        XCTAssertEqual(
            TransactionAIProvider.resolve(
                preferredProvider: "claude",
                hasClaudeKey: false,
                hasQwenKey: true,
                hasDeepSeekKey: true
            ),
            .deepSeek
        )
        XCTAssertNil(
            TransactionAIProvider.resolve(
                preferredProvider: "claude",
                hasClaudeKey: false,
                hasQwenKey: false,
                hasDeepSeekKey: false
            )
        )
    }
}
