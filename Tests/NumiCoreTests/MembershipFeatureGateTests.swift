import XCTest
@testable import NumiCore

final class MembershipFeatureGateTests: XCTestCase {
    func testFreeTierBlocksTheThirdLedger() {
        let gate = MembershipFeatureGate(status: .free)

        XCTAssertEqual(
            gate.decision(for: .createLedger(currentCount: 2)),
            .blocked(context: .limitLedger)
        )
    }

    func testFreeTierAllowsUsageBelowEachDocumentedLimit() {
        let gate = MembershipFeatureGate(status: .free)

        XCTAssertEqual(gate.decision(for: .createLedger(currentCount: 1)), .granted)
        XCTAssertEqual(gate.decision(for: .createAccount(currentCount: 19)), .granted)
        XCTAssertEqual(gate.decision(for: .createSubscription(currentCount: 2)), .granted)
        XCTAssertEqual(gate.decision(for: .createInstallment(currentCount: 1)), .granted)
        XCTAssertEqual(gate.decision(for: .createRecurringRule(currentCount: 1)), .granted)
    }

    func testFreeTierBlocksPremiumCapabilitiesWithRelevantPaywallContexts() {
        let gate = MembershipFeatureGate(status: .free)

        XCTAssertEqual(gate.decision(for: .openMultiCurrency), .blocked(context: .multiCurrency))
        XCTAssertEqual(gate.decision(for: .openICloudSync), .blocked(context: .sync))
        XCTAssertEqual(gate.decision(for: .openEncryptedBackup), .blocked(context: .backup))
    }

    func testProTierGrantsEveryDocumentedCapabilityAndRemovesLimits() {
        let tier = MembershipTier.proLifetime
        let gate = MembershipFeatureGate(status: MembershipStatus(tier: tier))

        XCTAssertEqual(MembershipCapabilityResolver.capabilities(for: tier), Set(MembershipCapability.allCases))
        XCTAssertEqual(gate.decision(for: .createLedger(currentCount: 2)), .granted)
        XCTAssertEqual(gate.decision(for: .createAccount(currentCount: 20)), .granted)
        XCTAssertEqual(gate.decision(for: .openMultiCurrency), .granted)
    }
}
