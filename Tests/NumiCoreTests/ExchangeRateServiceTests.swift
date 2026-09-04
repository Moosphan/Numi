import XCTest
@testable import NumiCore

final class ExchangeRateServiceTests: XCTestCase {
    func testHistorySelectsLatestSnapshotAtOrBeforeDate() throws {
        let firstDate = Date(timeIntervalSince1970: 1_700_000_000)
        let secondDate = firstDate.addingTimeInterval(86_400)
        let history = ExchangeRateHistory(snapshots: [
            ExchangeRateSnapshot(baseCode: "CNY", rates: ["CNY": 1, "USD": 0.14], effectiveDate: firstDate),
            ExchangeRateSnapshot(baseCode: "CNY", rates: ["CNY": 1, "USD": 0.15], effectiveDate: secondDate)
        ])

        XCTAssertEqual(history.snapshot(baseCode: "CNY", on: secondDate.addingTimeInterval(1))?.rates["USD"], 0.15)
        XCTAssertEqual(history.snapshot(baseCode: "CNY", on: secondDate.addingTimeInterval(-1))?.rates["USD"], 0.14)
        XCTAssertNil(history.snapshot(baseCode: "CNY", on: firstDate.addingTimeInterval(-1)))
    }

    func testHistoryConvertsMoneyUsingSnapshotAndTargetCurrencyScale() throws {
        let history = ExchangeRateHistory(snapshots: [
            ExchangeRateSnapshot(
                baseCode: "CNY",
                rates: ["CNY": 1, "JPY": 21.5],
                effectiveDate: Date(timeIntervalSince1970: 1_700_000_000)
            )
        ])

        let converted = try XCTUnwrap(
            history.convert(
                Money(decimalString: "100.00", currencyCode: "CNY"),
                to: "JPY",
                on: Date(timeIntervalSince1970: 1_700_000_001)
            )
        )

        XCTAssertEqual(converted, Money(minorUnits: 2_150, currencyCode: "JPY"))
    }
}
