import XCTest
import NumiCore
@testable import NumiAppUI

final class AutomaticExchangeRateRefreshPolicyTests: XCTestCase {
    func testEnabledAutoRefreshRunsForGrantedMembershipAccess() {
        XCTAssertTrue(AutomaticExchangeRateRefreshPolicy.shouldRefresh(
            isEnabled: true,
            accessDecision: .granted
        ))
    }

    func testDisabledOrBlockedAutoRefreshNeverRuns() {
        XCTAssertFalse(AutomaticExchangeRateRefreshPolicy.shouldRefresh(
            isEnabled: false,
            accessDecision: .granted
        ))
        XCTAssertFalse(AutomaticExchangeRateRefreshPolicy.shouldRefresh(
            isEnabled: true,
            accessDecision: .blocked(context: .autoExchangeRate)
        ))
    }

    func testNetworkRateFetchRequiresGrantedExchangeRateAccess() {
        XCTAssertTrue(ExchangeRateNetworkAccessPolicy.mayFetchRates(
            accessDecision: .granted
        ))
        XCTAssertFalse(ExchangeRateNetworkAccessPolicy.mayFetchRates(
            accessDecision: .blocked(context: .autoExchangeRate)
        ))
    }
}
