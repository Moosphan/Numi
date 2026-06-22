import XCTest
@testable import NumiAppUI

final class NumiRecordRowStyleTests: XCTestCase {
    func testGroupedRowsOwnBackgroundForContextMenuHighlighting() {
        XCTAssertTrue(NumiRecordRow.Style.grouped.usesOwnBackground)
    }
}
