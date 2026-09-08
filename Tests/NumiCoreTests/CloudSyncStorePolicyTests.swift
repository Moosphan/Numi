import XCTest
@testable import NumiCore

final class CloudSyncStorePolicyTests: XCTestCase {
    func testSharedAppGroupIsUsedWhenCloudSyncIsDisabled() {
        XCTAssertEqual(
            CloudSyncStorePolicy.storageMode(isCloudSyncEnabled: false),
            .sharedAppGroup
        )
    }

    func testCloudKitIsUsedWhenCloudSyncIsEnabled() {
        XCTAssertEqual(
            CloudSyncStorePolicy.storageMode(isCloudSyncEnabled: true),
            .cloudKit
        )
    }
}
