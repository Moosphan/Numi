import XCTest
@testable import NumiCore

final class ThemePaletteTests: XCTestCase {
    func testBrandWarmThemeUsesProvidedBrandPalette() {
        let theme = NumiTheme.brandWarm

        XCTAssertEqual(theme.primaryHex, "#F0A050")
        XCTAssertEqual(theme.backgroundHex, "#FCF6EF")
        XCTAssertEqual(theme.accentHex, "#C87A6E")
        XCTAssertEqual(theme.positiveHex, "#A8C3A2")
        XCTAssertEqual(theme.warningHex, "#E08B5A")
        XCTAssertEqual(theme.textPrimaryHex, "#3D2C26")
    }

    func testThemeIdentifiersStayStableForPersistence() {
        XCTAssertEqual(NumiTheme.defaultTheme.id, "default")
        XCTAssertEqual(NumiTheme.brandWarm.id, "brandWarm")
    }
}
