import XCTest
@testable import NumiAppUI

final class InsightsCustomRangePolicyTests: XCTestCase {
    func testNormalizesReversedDatesAndIncludesTheEntireEndDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let earlier = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let later = calendar.date(from: DateComponents(year: 2025, month: 1, day: 4))!
        let dayAfterLater = calendar.date(from: DateComponents(year: 2025, month: 1, day: 5))!

        let interval = InsightsCustomRangePolicy.dateInterval(
            start: later,
            end: earlier,
            calendar: calendar
        )

        XCTAssertEqual(interval.start, earlier)
        XCTAssertEqual(interval.end, dayAfterLater)
        XCTAssertTrue(InsightsCustomRangePolicy.contains(dayAfterLater.addingTimeInterval(-1), in: interval))
        XCTAssertFalse(InsightsCustomRangePolicy.contains(interval.end, in: interval))
    }
}
