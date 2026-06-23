import XCTest
@testable import NumiApp

final class RootShellStoreRecoveryTests: XCTestCase {
    func testAppStoreDirectoryURLEndsWithNumiContainer() throws {
        let directory = try RootShellView.appStoreDirectoryURL(fileManager: .default)

        XCTAssertEqual(directory.lastPathComponent, "Numi")
    }
}
