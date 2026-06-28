import XCTest
import NumiCore
@testable import NumiAppUI

final class AppUILocalizationBundleTests: XCTestCase {
    private let languageKey = "app.language"
    private var originalLanguage: String?

    override func setUp() {
        super.setUp()
        originalLanguage = UserDefaults.standard.string(forKey: languageKey)
        NumiAppUILocalization.registerBundle()
    }

    override func tearDown() {
        if let originalLanguage {
            UserDefaults.standard.set(originalLanguage, forKey: languageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: languageKey)
        }
        super.tearDown()
    }

    func testAppUIBundleParticipatesInRuntimeLookup() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("setting.data"), "数据")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("setting.data"), "Data")
    }

    func testStringLiteralOverloadUsesRawLocalizationKey() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.string("setting.stat.days"), "记账天数")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.string("setting.data"), "Data")
    }

    func testFormattedLookupUsesCatalogKeyAndArguments() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.string("period.quarter", 2026, 2), "2026年第2季度")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.string("error.ai.record.success", "Dining", "+", "¥35.00"), "Recorded Dining +¥35.00")
    }

    func testDatePickerDisplayTextUsesRuntimeLanguagePreference() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 9, minute: 30)))

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertTrue(
            NumiDatePickerRow.displayText(for: date, calendar: calendar, includesTime: false).contains("3月"),
            "Simplified Chinese runtime language should render a Chinese month label."
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertTrue(
            NumiDatePickerRow.displayText(for: date, calendar: calendar, includesTime: false).localizedCaseInsensitiveContains("Mar"),
            "English runtime language should render an English month label."
        )
    }

    func testDatePickerUsesDedicatedDayBeforeYesterdayLabel() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try XCTUnwrap(calendar.date(byAdding: .day, value: -2, to: Date()))

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(NumiDatePickerRow.displayText(for: date, calendar: calendar, includesTime: false), "前天")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(NumiDatePickerRow.displayText(for: date, calendar: calendar, includesTime: false), "The day before yesterday")
    }

    func testDatePickerKeepsYesterdayLabelSeparateFromDayBeforeYesterday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: Date()))

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(NumiDatePickerRow.displayText(for: date, calendar: calendar, includesTime: false), "昨天")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(NumiDatePickerRow.displayText(for: date, calendar: calendar, includesTime: false), "Yesterday")
    }

    func testCategoryIconDisplayNameTracksRuntimeLanguage() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(CategoryIcon.acaiBowl.displayName, "餐饮")
        XCTAssertEqual(CategoryIcon.icon(named: "餐饮"), .acaiBowl)

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(CategoryIcon.acaiBowl.displayName, "Dining")
        XCTAssertEqual(CategoryIcon.icon(named: "Dining"), .acaiBowl)
    }

    func testCategoryIconDescriptionTracksRuntimeLanguage() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(CategoryIcon.acaiBowl.description, "早餐、午餐、晚餐、外卖、零食、饮料")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(CategoryIcon.acaiBowl.description, "Breakfast, lunch, dinner, takeout, snacks, and drinks")
    }

    func testCurrencyLastUpdatedTextUsesRuntimeLanguagePreference() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 9, minute: 30)))

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        let chineseText = CurrencyManagementView.lastUpdatedText(for: date)
        XCTAssertTrue(
            chineseText.contains("3") && (chineseText.contains("月") || chineseText.contains("3月")),
            "Simplified Chinese runtime language should render Chinese date fragments."
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        let englishText = CurrencyManagementView.lastUpdatedText(for: date)
        XCTAssertTrue(
            englishText.localizedCaseInsensitiveContains("Mar"),
            "English runtime language should render English month abbreviations."
        )
    }

    func testCurrencyRateTextUsesLocaleAwareDecimalSeparator() {
        let french = Locale(identifier: "fr_FR")

        XCTAssertEqual(
            CurrencyManagementView.rateText(for: 7.25, locale: french),
            "1:7,25"
        )
        XCTAssertEqual(
            CurrencyManagementView.rateText(for: 0.1234, locale: french),
            "1:0,1234"
        )
    }

    func testAppLanguageDisplayNameTracksRuntimeLanguage() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(NumiAppLanguage.displayName(for: "system"), "跟随系统")
        XCTAssertEqual(NumiAppLanguage.displayName(for: "en"), "English")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(NumiAppLanguage.displayName(for: "system"), "Follow System")
        XCTAssertEqual(NumiAppLanguage.displayName(for: "zh-Hans"), "Simplified Chinese")
    }

    func testLanguageSwitchSuccessMessageTracksRuntimeLanguage() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(
            NumiLocalized.string("language.switch.success", NumiAppLanguage.displayName(for: "en")),
            "已切换为 English"
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(
            NumiLocalized.string("language.switch.success", NumiAppLanguage.displayName(for: "zh-Hans")),
            "Switched to Simplified Chinese"
        )
    }

    func testAIProviderDisplayNamesTrackRuntimeLanguage() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(SettingsView.providerDisplayName(for: "claude"), "Claude")
        XCTAssertEqual(SettingsView.providerDisplayName(for: "qwen"), "通义千问")
        XCTAssertEqual(SettingsView.providerDisplayName(for: "deepseek"), "DeepSeek")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(SettingsView.providerDisplayName(for: "claude"), "Claude")
        XCTAssertEqual(SettingsView.providerDisplayName(for: "qwen"), "Qwen")
        XCTAssertEqual(SettingsView.providerDisplayName(for: "deepseek"), "DeepSeek")
    }

    func testAIKeyTestFailureDisplayMessageTracksRuntimeLanguageWithoutDoublePrefix() {
        let httpFailure = SettingsView.AIKeyTestFailure.httpStatus(401)
        let unauthorized = SettingsView.AIKeyTestFailure.unauthorized

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(httpFailure.displayMessage, "连接失败：401")
        XCTAssertEqual(unauthorized.displayMessage, "API Key 无效或未授权")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(httpFailure.displayMessage, "Connection failed: 401")
        XCTAssertEqual(unauthorized.displayMessage, "Invalid or unauthorized API key")
    }

    func testSyncFailureMessageTracksRuntimeLanguageWithoutMutatingStoredStatus() {
        let status = SyncStatus.failure(.networkUnavailable)

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(status.displayMessage, "网络不可用")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(status.displayMessage, "Network unavailable")
    }

    func testRuntimeDisplayPrefersCurrentLocalizedCategoryAndAccountNamesOverStaleFallbackStrings() {
        let category = Category(
            kind: .expense,
            name: "__legacy_dining__",
            builtInKey: "category.default.expense.dining",
            icon: "acai-bowl",
            sortOrder: 0
        )
        let sourceAccount = Account(
            name: "__legacy_cash__",
            builtInKey: "account.default.cash",
            type: .cash,
            balance: .zero(currencyCode: "CNY")
        )
        let targetAccount = Account(
            name: "__legacy_card__",
            builtInKey: "account.default.bankCard",
            type: .debitCard,
            balance: .zero(currencyCode: "CNY")
        )
        let transaction = Transaction(
            type: .expense,
            amount: .zero(currencyCode: "CNY"),
            occurredAt: Date(),
            categoryID: category.id,
            accountID: sourceAccount.id,
            targetAccountID: targetAccount.id,
            ledgerID: UUID(),
            note: ""
        )

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(
            RuntimeLocalizedDisplay.categoryName(
                for: transaction,
                categories: [category],
                fallbackCategoryName: "Dining"
            ),
            "餐饮"
        )
        XCTAssertEqual(
            RuntimeLocalizedDisplay.accountName(for: sourceAccount.id, accounts: [sourceAccount, targetAccount]),
            "现金"
        )
        XCTAssertEqual(
            RuntimeLocalizedDisplay.transferAccountFlowText(
                sourceAccountID: sourceAccount.id,
                targetAccountID: targetAccount.id,
                accounts: [sourceAccount, targetAccount]
            ),
            "现金 -> 银行卡"
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(
            RuntimeLocalizedDisplay.categoryName(
                for: transaction,
                categories: [category],
                fallbackCategoryName: "餐饮"
            ),
            "Dining"
        )
        XCTAssertEqual(
            RuntimeLocalizedDisplay.accountName(for: sourceAccount.id, accounts: [sourceAccount, targetAccount]),
            "Cash"
        )
        XCTAssertEqual(
            RuntimeLocalizedDisplay.transferAccountFlowText(
                sourceAccountID: sourceAccount.id,
                targetAccountID: targetAccount.id,
                accounts: [sourceAccount, targetAccount]
            ),
            "Cash -> Bank Card"
        )
    }

    func testRuntimeDisplayFallsBackWhenCurrentCategorySourceIsUnavailable() {
        let transaction = Transaction(
            type: .expense,
            amount: .zero(currencyCode: "CNY"),
            occurredAt: Date(),
            categoryID: UUID(),
            accountID: nil,
            targetAccountID: nil,
            ledgerID: UUID(),
            note: ""
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(
            RuntimeLocalizedDisplay.categoryName(
                for: transaction,
                categories: [],
                fallbackCategoryName: "Archived Category"
            ),
            "Archived Category"
        )
        XCTAssertEqual(
            RuntimeLocalizedDisplay.categoryIconName(
                for: transaction,
                categories: [],
                fallbackCategoryIcon: "archivebox"
            ),
            "archivebox"
        )
    }

    func testRuntimeTransferSubtitleTracksCurrentLocalizedAccountNames() {
        let sourceAccount = Account(
            name: "__legacy_cash__",
            builtInKey: "account.default.cash",
            type: .cash,
            balance: .zero(currencyCode: "CNY")
        )
        let targetAccount = Account(
            name: "__legacy_card__",
            builtInKey: "account.default.bankCard",
            type: .debitCard,
            balance: .zero(currencyCode: "CNY")
        )
        let transaction = Transaction(
            type: .transfer,
            amount: .zero(currencyCode: "CNY"),
            occurredAt: Date(),
            categoryID: nil,
            accountID: sourceAccount.id,
            targetAccountID: targetAccount.id,
            ledgerID: UUID(),
            note: ""
        )

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(
            RuntimeLocalizedDisplay.transferSubtitle(
                for: transaction,
                accounts: [sourceAccount, targetAccount],
                fallbackSubtitle: "Cash -> Bank Card"
            ),
            "现金 -> 银行卡"
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(
            RuntimeLocalizedDisplay.transferSubtitle(
                for: transaction,
                accounts: [sourceAccount, targetAccount],
                fallbackSubtitle: "现金 -> 银行卡"
            ),
            "Cash -> Bank Card"
        )
    }
}
