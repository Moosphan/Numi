import XCTest
import SwiftUI
import NumiCore
@testable import NumiAppUI

@MainActor
final class NumiThemeControllerTests: XCTestCase {
    func testThemeControllerPublishesWhenApplyingTheme() {
        let controller = NumiThemeController.shared
        let originalTheme = controller.theme
        let candidate = originalTheme == NumiTheme.default ? NumiTheme.brandWarm : NumiTheme.default
        let expectation = expectation(description: "theme update")
        let cancellable = controller.objectWillChange.sink { expectation.fulfill() }

        controller.apply(theme: candidate)

        wait(for: [expectation], timeout: 1)
        cancellable.cancel()
        controller.apply(theme: originalTheme)
    }

    func testApplyingThemeUpdatesCurrentPaletteImmediately() {
        let controller = NumiThemeController.shared
        let originalTheme = controller.theme
        let candidate = originalTheme == NumiTheme.default ? NumiTheme.brandWarm : NumiTheme.default
        let before = controller.currentPalette.background

        controller.apply(theme: candidate)

        XCTAssertEqual(controller.theme, candidate)
        XCTAssertNotEqual(controller.currentPalette.background, before)

        controller.apply(theme: originalTheme)
    }

    func testUpdatingColorSchemeUpdatesCurrentPaletteImmediately() {
        let controller = NumiThemeController.shared
        let originalScheme = controller.colorScheme
        let candidate: ColorScheme = originalScheme == .dark ? .light : .dark
        let before = controller.currentPalette.background

        controller.updateColorScheme(candidate)

        XCTAssertEqual(controller.colorScheme, candidate)
        XCTAssertNotEqual(controller.currentPalette.background, before)

        controller.updateColorScheme(originalScheme)
    }
}
