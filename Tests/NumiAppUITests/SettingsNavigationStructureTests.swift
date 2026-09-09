import XCTest
import NumiCore
@testable import NumiAppUI

final class SettingsNavigationStructureTests: XCTestCase {
    override func setUp() {
        super.setUp()
        NumiAppUILocalization.registerBundle()
    }

    func testSettingsCategoriesExposeSixTopLevelDestinations() {
        XCTAssertEqual(
            SettingsCategory.allCases.map(\.rawValue),
            ["featureExtensions", "dataManagement", "appearance", "security", "notifications", "aiLab"]
        )
    }

    func testPlanSettingsUsesExistingGlobalPreferenceKeys() {
        XCTAssertEqual(PlanSettingsView.preferenceKeys.forecastHorizon, "plans.forecast.horizon.days")
        XCTAssertEqual(PlanSettingsView.preferenceKeys.subscriptionConfirmation, "app.subscription.requiresConfirmation")
    }

    func testCategoryTitlesAndSummariesHaveRuntimeTranslations() {
        let locale = Locale(identifier: "zh-Hans")
        XCTAssertEqual(NumiLocalized.lookup("setting.category.featureExtensions", locale: locale), "功能扩展")
        XCTAssertEqual(NumiLocalized.lookup("setting.category.dataManagement", locale: locale), "数据管理")
        XCTAssertEqual(NumiLocalized.lookup("setting.category.notifications.summary", locale: locale), "订阅与分期提醒")
        XCTAssertEqual(NumiLocalized.lookup("setting.category.planSettings", locale: locale), "计划设置")
    }
}
