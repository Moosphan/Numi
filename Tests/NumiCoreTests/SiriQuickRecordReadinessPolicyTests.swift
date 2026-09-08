import XCTest
@testable import NumiCore

final class SiriQuickRecordReadinessPolicyTests: XCTestCase {
    func testEmptyLocalStoreGuidesUserToSetUpCategories() {
        XCTAssertEqual(
            SiriQuickRecordReadinessPolicy.state(
                hasCategories: false,
                storageMode: .sharedAppGroup
            ),
            .setUpCategories
        )
    }

    func testEmptyCloudStoreWaitsForInitialSyncInsteadOfMisleadingSetup() {
        XCTAssertEqual(
            SiriQuickRecordReadinessPolicy.state(
                hasCategories: false,
                storageMode: .cloudKit
            ),
            .waitForCloudData
        )
    }

    func testCategoriesMakeQuickRecordReadyInEitherStorageMode() {
        XCTAssertEqual(
            SiriQuickRecordReadinessPolicy.state(
                hasCategories: true,
                storageMode: .cloudKit
            ),
            .ready
        )
    }
}
