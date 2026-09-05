import XCTest
@testable import NumiAppUI

final class SyncPreflightTests: XCTestCase {
    func testExecutionPolicyRejectsConcurrentSync() {
        XCTAssertFalse(SyncExecutionPolicy.canStart(status: .syncing))
        XCTAssertTrue(SyncExecutionPolicy.canStart(status: .idle))
        XCTAssertTrue(SyncExecutionPolicy.canStart(status: .success(Date())))
        XCTAssertTrue(SyncExecutionPolicy.canStart(status: .failure(.syncFailed)))
    }

    func testPreflightReportsNetworkBeforeCloudAndCellularFailures() {
        XCTAssertEqual(
            SyncPreflight.failure(
                isNetworkAvailable: false,
                isICloudAvailable: false,
                networkType: .cellular,
                isCellularSyncEnabled: false
            ),
            .networkUnavailable
        )
        XCTAssertEqual(
            SyncPreflight.failure(
                isNetworkAvailable: true,
                isICloudAvailable: false,
                networkType: .wifi,
                isCellularSyncEnabled: false
            ),
            .iCloudUnavailable
        )
        XCTAssertEqual(
            SyncPreflight.failure(
                isNetworkAvailable: true,
                isICloudAvailable: true,
                networkType: .cellular,
                isCellularSyncEnabled: false
            ),
            .cellularDisabled
        )
    }

    func testPreflightAllowsAvailableWiFiAndAllowedCellular() {
        XCTAssertNil(
            SyncPreflight.failure(
                isNetworkAvailable: true,
                isICloudAvailable: true,
                networkType: .wifi,
                isCellularSyncEnabled: false
            )
        )
        XCTAssertNil(
            SyncPreflight.failure(
                isNetworkAvailable: true,
                isICloudAvailable: true,
                networkType: .cellular,
                isCellularSyncEnabled: true
            )
        )
    }
}
