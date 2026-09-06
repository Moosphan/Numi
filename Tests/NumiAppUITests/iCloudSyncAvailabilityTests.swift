import CloudKit
import XCTest
@testable import NumiAppUI

final class iCloudSyncAvailabilityTests: XCTestCase {
    func testSimulatorDoesNotQueryCloudKitWithoutRuntimeEntitlements() {
        XCTAssertFalse(iCloudRuntimeAvailabilityPolicy.shouldQueryCloudKit(isSimulator: true))
        XCTAssertTrue(iCloudRuntimeAvailabilityPolicy.shouldQueryCloudKit(isSimulator: false))
    }

    func testOnlyAvailableCloudKitAccountStatusIsUsable() {
        XCTAssertTrue(iCloudAccountStatusEvaluator.isUsable(.available))
        XCTAssertFalse(iCloudAccountStatusEvaluator.isUsable(.noAccount))
        XCTAssertFalse(iCloudAccountStatusEvaluator.isUsable(.restricted))
        XCTAssertFalse(iCloudAccountStatusEvaluator.isUsable(.couldNotDetermine))
    }
}
