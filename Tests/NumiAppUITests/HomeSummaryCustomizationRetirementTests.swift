import XCTest

final class HomeSummaryCustomizationRetirementTests: XCTestCase {
    func testHomeSummaryCustomizationIsAbsentFromTheShippedProduct() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let homeSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("Sources/NumiAppUI/Pages/TransactionsHomeView.swift"),
            encoding: .utf8
        )
        let membershipSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("Sources/NumiCore/Membership/Membership.swift"),
            encoding: .utf8
        )
        let benefitsSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("Sources/NumiAppUI/Pages/MembershipBenefitsView.swift"),
            encoding: .utf8
        )
        let catalogSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("Sources/NumiAppUI/Localizable.xcstrings"),
            encoding: .utf8
        )
        let backlogSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("docs/backlog/current-priority-backlog.md"),
            encoding: .utf8
        )
        let prdSource = try String(
            contentsOf: sourceRoot.appendingPathComponent("docs/prd/numi-pro-membership-feature-spec.md"),
            encoding: .utf8
        )

        XCTAssertFalse(homeSource.contains("customizeHomeSummary"))
        XCTAssertFalse(homeSource.contains("home.summary.customize"))
        XCTAssertFalse(membershipSource.contains("homeSummaryCustomization"))
        XCTAssertFalse(membershipSource.contains("openHomeSummaryCustomization"))
        XCTAssertFalse(benefitsSource.contains("membership.comparison.homeSummary"))
        XCTAssertFalse(catalogSource.contains("home.summary.customize"))
        XCTAssertFalse(catalogSource.contains("membership.comparison.homeSummary"))
        XCTAssertFalse(backlogSource.contains("首页摘要现提供独立 Pro 权限"))
        XCTAssertFalse(prdSource.contains("首页摘要卡"))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: sourceRoot.appendingPathComponent("Sources/NumiAppUI/HomeSummaryCardOrderPolicy.swift").path
        ))
    }
}
