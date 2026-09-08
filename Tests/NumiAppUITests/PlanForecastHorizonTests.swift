import XCTest
@testable import NumiAppUI

final class PlanForecastHorizonTests: XCTestCase {
    func testResolvesStoredHorizonOrFallsBackToThirtyDays() {
        XCTAssertEqual(PlanForecastHorizon.resolve(rawValue: 90), .ninetyDays)
        XCTAssertEqual(PlanForecastHorizon.resolve(rawValue: 365), .oneYear)
        XCTAssertEqual(PlanForecastHorizon.resolve(rawValue: 14), .thirtyDays)
    }

    func testProvidesStableOrderedChoicesForTheForecastControl() {
        XCTAssertEqual(PlanForecastHorizon.allCases, [.thirtyDays, .ninetyDays, .oneYear])
    }
}
