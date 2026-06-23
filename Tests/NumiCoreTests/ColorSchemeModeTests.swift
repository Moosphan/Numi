import XCTest
import SwiftUI
@testable import NumiCore

final class ColorSchemeModeTests: XCTestCase {
    func testResolveUsesSystemSchemeForSystemMode() {
        XCTAssertEqual(ColorSchemeMode.system.resolve(systemScheme: .dark), .dark)
        XCTAssertEqual(ColorSchemeMode.system.resolve(systemScheme: .light), .light)
    }

    func testResolveUsesExplicitSchemeForManualModes() {
        XCTAssertEqual(ColorSchemeMode.light.resolve(systemScheme: .dark), .light)
        XCTAssertEqual(ColorSchemeMode.dark.resolve(systemScheme: .light), .dark)
    }
}
