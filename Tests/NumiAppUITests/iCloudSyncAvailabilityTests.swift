import CloudKit
import XCTest
@testable import NumiAppUI

final class iCloudSyncAvailabilityTests: XCTestCase {
    func testOnlyAvailableCloudKitAccountStatusIsUsable() {
        XCTAssertTrue(iCloudAccountStatusEvaluator.isUsable(.available))
        XCTAssertFalse(iCloudAccountStatusEvaluator.isUsable(.noAccount))
        XCTAssertFalse(iCloudAccountStatusEvaluator.isUsable(.restricted))
        XCTAssertFalse(iCloudAccountStatusEvaluator.isUsable(.couldNotDetermine))
    }
}
