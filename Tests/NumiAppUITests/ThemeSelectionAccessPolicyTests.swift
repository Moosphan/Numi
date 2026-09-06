import XCTest
import NumiCore
@testable import NumiAppUI

final class ThemeSelectionAccessPolicyTests: XCTestCase {
    func testChangingFromDefaultToWarmRequestsPremiumThemes() {
        XCTAssertEqual(
            ThemeSelectionAccessPolicy.featureRequest(
                currentThemeID: NumiTheme.default.id,
                candidateThemeID: NumiTheme.brandWarm.id
            ),
            .openPremiumThemes
        )
    }

    func testKeepingWarmThemeAfterDowngradeDoesNotNeedAnotherRequest() {
        XCTAssertNil(
            ThemeSelectionAccessPolicy.featureRequest(
                currentThemeID: NumiTheme.brandWarm.id,
                candidateThemeID: NumiTheme.brandWarm.id
            )
        )
    }

    func testSelectingDefaultThemeNeverNeedsARequest() {
        XCTAssertNil(
            ThemeSelectionAccessPolicy.featureRequest(
                currentThemeID: NumiTheme.brandWarm.id,
                candidateThemeID: NumiTheme.default.id
            )
        )
    }
}
