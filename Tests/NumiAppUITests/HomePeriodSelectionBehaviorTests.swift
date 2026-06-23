import XCTest
@testable import NumiAppUI

final class HomePeriodSelectionBehaviorTests: XCTestCase {
    func testAnchorResetsToNowWhenPeriodChanges() {
        let formatter = ISO8601DateFormatter()
        let currentAnchorDate = formatter.date(from: "2026-06-01T00:00:00Z")!
        let now = formatter.date(from: "2026-06-23T12:00:00Z")!

        let anchor = HomePeriodSelectionBehavior.anchorDate(
            currentPeriod: .month,
            selectedPeriod: .week,
            currentAnchorDate: currentAnchorDate,
            now: now
        )

        XCTAssertEqual(anchor, now)
    }

    func testAnchorStaysWhenPeriodDoesNotChange() {
        let formatter = ISO8601DateFormatter()
        let currentAnchorDate = formatter.date(from: "2026-06-01T00:00:00Z")!
        let now = formatter.date(from: "2026-06-23T12:00:00Z")!

        let anchor = HomePeriodSelectionBehavior.anchorDate(
            currentPeriod: .month,
            selectedPeriod: .month,
            currentAnchorDate: currentAnchorDate,
            now: now
        )

        XCTAssertEqual(anchor, currentAnchorDate)
    }
}
