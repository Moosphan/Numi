import XCTest
import NumiCore
@testable import NumiAppUI

final class SyncPreflightTests: XCTestCase {
    func testExecutionPolicyRejectsConcurrentSync() {
        XCTAssertFalse(SyncExecutionPolicy.canStart(status: .syncing))
        XCTAssertTrue(SyncExecutionPolicy.canStart(status: .idle))
        XCTAssertTrue(SyncExecutionPolicy.canStart(status: .success(Date())))
        XCTAssertTrue(SyncExecutionPolicy.canStart(status: .failure(.syncFailed)))
    }

    func testScheduledCloudSyncIsNotReportedAsCompleted() {
        let scheduled = SyncStatus.scheduled(Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(scheduled.displayMessage, NumiLocalized.string("sync.status.scheduled"))
        XCTAssertFalse(SyncExecutionPolicy.canStart(status: scheduled))
    }

    func testObservedCloudKitEventMapsOnlyFinishedSuccessfulWorkToSuccess() {
        let completedAt = Date(timeIntervalSince1970: 1_700_000_001)

        XCTAssertEqual(
            CloudSyncEventStatusMapper.status(for: .started),
            .syncing
        )
        XCTAssertEqual(
            CloudSyncEventStatusMapper.status(for: .succeeded(completedAt)),
            .success(completedAt)
        )
        XCTAssertEqual(
            CloudSyncEventStatusMapper.status(for: .failed),
            .failure(.syncFailed)
        )
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
