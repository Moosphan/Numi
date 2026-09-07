import XCTest
@testable import NumiAppUI

final class InsightsModuleOrderPolicyTests: XCTestCase {
    func testParsesKnownModulesOnceThenAppendsMissingDefaults() {
        let modules = InsightsModuleOrderPolicy.modules(from: "incomeDistribution,unknown,incomeDistribution")

        XCTAssertEqual(modules, [.incomeDistribution, .expenseDistribution])
    }

    func testSerializesAndRestoresUserOrder() {
        let serialized = InsightsModuleOrderPolicy.serialized([
            .incomeDistribution,
            .expenseDistribution
        ])

        XCTAssertEqual(serialized, "incomeDistribution,expenseDistribution")
        XCTAssertEqual(
            InsightsModuleOrderPolicy.modules(from: serialized),
            [.incomeDistribution, .expenseDistribution]
        )
    }
}
