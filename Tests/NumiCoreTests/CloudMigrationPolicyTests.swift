import XCTest
@testable import NumiCore

final class CloudMigrationPolicyTests: XCTestCase {
    func testEmptyCloudSnapshotImportsLocalWithoutConflict() {
        let local = BookkeepingSnapshot(transactions: [Transaction(type: .expense, amount: Money(minorUnits: 500, currencyCode: "CNY"))])

        XCTAssertEqual(
            CloudMigrationPolicy.assessment(local: local, cloud: BookkeepingSnapshot()).resolution,
            .importLocal
        )
    }

    func testTwoNonEmptySnapshotsRequireAnExplicitConflictChoice() {
        let local = BookkeepingSnapshot(
            accounts: [Account(name: "Cash", type: .cash, balance: Money(minorUnits: 500, currencyCode: "CNY"))],
            transactions: [Transaction(type: .expense, amount: Money(minorUnits: 500, currencyCode: "CNY"))],
            installmentPlans: [InstallmentPlan(name: "Phone", totalAmount: Money(minorUnits: 1_200, currencyCode: "CNY"), feePerPeriod: .zero(currencyCode: "CNY"), periodCount: 2, firstPaymentDate: Date())]
        )
        let cloud = BookkeepingSnapshot(
            accounts: [Account(name: "Card", type: .debitCard, balance: Money(minorUnits: 800, currencyCode: "CNY"))],
            transactions: [Transaction(type: .income, amount: Money(minorUnits: 800, currencyCode: "CNY"))]
        )

        XCTAssertEqual(
            CloudMigrationPolicy.assessment(local: local, cloud: cloud).resolution,
            .requiresDecision
        )
        let assessment = CloudMigrationPolicy.assessment(local: local, cloud: cloud)
        XCTAssertEqual(assessment.localAccountCount, 1)
        XCTAssertEqual(assessment.cloudAccountCount, 1)
        XCTAssertEqual(assessment.localInstallmentPlanCount, 1)
        XCTAssertEqual(assessment.cloudInstallmentPlanCount, 0)
    }

    func testConflictStrategySelectsOneCompleteSnapshotOrCancels() {
        let local = BookkeepingSnapshot(ledgers: [Ledger(name: "This device", currencyCode: "CNY")])
        let cloud = BookkeepingSnapshot(ledgers: [Ledger(name: "iCloud", currencyCode: "USD")])

        XCTAssertEqual(
            CloudMigrationPolicy.snapshotToApply(local: local, cloud: cloud, strategy: .preferLocal),
            local
        )
        XCTAssertEqual(
            CloudMigrationPolicy.snapshotToApply(local: local, cloud: cloud, strategy: .preferICloud),
            cloud
        )
        XCTAssertNil(CloudMigrationPolicy.snapshotToApply(local: local, cloud: cloud, strategy: .cancel))
    }
}
