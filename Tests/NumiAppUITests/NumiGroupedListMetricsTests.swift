import XCTest
@testable import NumiAppUI

final class NumiGroupedListMetricsTests: XCTestCase {
    func testDefaultSeparatorInsetsAlignWithGroupedRowContent() {
        XCTAssertEqual(NumiGroupedListMetrics.separatorLeadingInset, 76)
        XCTAssertEqual(NumiGroupedListMetrics.separatorTrailingInset, 16)
    }
}
