import XCTest
@testable import NumiAppUI

@MainActor
final class NumiBottomAccessoryNavigationDepthTests: XCTestCase {
    func testNavigationSourceHiddenWhenDepthGreaterThanZero() {
        let controller = NumiBottomAccessoryController()

        controller.setHidden(false, source: .navigation)
        XCTAssertFalse(controller.isHidden)

        controller.setHidden(true, source: .navigation)
        XCTAssertTrue(controller.isHidden)

        controller.setHidden(false, source: .navigation)
        XCTAssertFalse(controller.isHidden)
    }

    func testScrollAndNavigationSourcesCompose() {
        let controller = NumiBottomAccessoryController()

        controller.setHidden(true, source: .scroll)
        controller.setHidden(true, source: .navigation)
        XCTAssertTrue(controller.isHidden)

        controller.setHidden(false, source: .scroll)
        XCTAssertTrue(controller.isHidden)

        controller.setHidden(false, source: .navigation)
        XCTAssertFalse(controller.isHidden)
    }
}
