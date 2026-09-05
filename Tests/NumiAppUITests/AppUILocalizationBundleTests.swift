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

    func testAppUIKeyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": "数据",
            "en": "Data",
            "zh-Hant": "資料",
            "ja": "データ"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("setting.data", locale: Locale(identifier: language)),
                expected,
                "Missing App UI localization for \(language)"
            )
        }
    }

    func testStringLiteralOverloadUsesRawLocalizationKey() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.string("setting.stat.days"), "记账天数")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.string("setting.data"), "Data")
    }

    func testInstallmentPaymentActionIsLocalized() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("installment.record.payment"), "记录还款")

        UserDefaults.standard.set("zh-Hant", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("installment.record.payment"), "記錄還款")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("installment.record.payment"), "Record Payment")

        UserDefaults.standard.set("ja", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("installment.record.payment"), "支払いを記録")

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.string("error.installment.record.fail", "账户不可用"), "记录还款失败：账户不可用")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.string("error.installment.record.fail", "Account unavailable"), "Unable to record payment: Account unavailable")

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("installment.settle"), "提前结清")
        XCTAssertEqual(NumiLocalized.string("installment.settle.confirm", "相机分期"), "确认提前结清“相机分期”？")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("installment.settle"), "Settle Early")
        XCTAssertEqual(NumiLocalized.string("installment.settle.confirm", "Camera Plan"), "Settle “Camera Plan” early?")

        UserDefaults.standard.set("zh-Hant", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("installment.settle"), "提前結清")

        UserDefaults.standard.set("ja", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("installment.settle"), "繰り上げ完済")

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("installment.skip"), "跳过")
        XCTAssertEqual(NumiLocalized.lookup("installment.skipped"), "已跳过")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("installment.skip"), "Skip")
        XCTAssertEqual(NumiLocalized.lookup("installment.skipped"), "Skipped")

        UserDefaults.standard.set("zh-Hant", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("installment.skip"), "跳過")

        UserDefaults.standard.set("ja", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("installment.skip"), "スキップ")

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.string("error.installment.skip.fail", "期次不存在"), "跳过期次失败：期次不存在")
    }

    func testSubscriptionPauseActionsAreLocalized() {
        let expectedValues = [
            "zh-Hans": (pause: "暂停订阅", resume: "恢复订阅"),
            "en": (pause: "Pause Subscription", resume: "Resume Subscription"),
            "zh-Hant": (pause: "暫停訂閱", resume: "恢復訂閱"),
            "ja": (pause: "サブスクを一時停止", resume: "サブスクを再開")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("subscription.pause", locale: locale), expected.pause)
            XCTAssertEqual(NumiLocalized.lookup("subscription.resume", locale: locale), expected.resume)
        }
    }

    func testSubscriptionReminderCopyIsLocalized() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("subscription.reminder.enable"), "开启到期提醒")
        XCTAssertEqual(NumiLocalized.string("subscription.reminder.title"), "订阅提醒")
        XCTAssertEqual(NumiLocalized.string("subscription.reminder.body", "音乐会员", "¥30.00"), "音乐会员将于明天扣费（¥30.00）")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("subscription.reminder.enable"), "Enable Billing Reminder")
        XCTAssertEqual(NumiLocalized.string("subscription.reminder.title"), "Subscription Reminder")
        XCTAssertEqual(NumiLocalized.string("subscription.reminder.body", "Music", "$3.00"), "Music will be billed tomorrow ($3.00)")
    }

    func testFormattedLookupUsesCatalogKeyAndArguments() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.string("setting.ai.test.fail", 401), "连接失败：401")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(
            NumiLocalized.string("language.switch.success", "Simplified Chinese"),
            "Switched to Simplified Chinese"
        )
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
