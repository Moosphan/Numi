import XCTest
@testable import NumiCore

final class RuntimeLocalizationTests: XCTestCase {
    private let languageKey = "app.language"
    private var originalLanguage: String?

    override func setUp() {
        super.setUp()
        originalLanguage = UserDefaults.standard.string(forKey: languageKey)
    }

    override func tearDown() {
        if let originalLanguage {
            UserDefaults.standard.set(originalLanguage, forKey: languageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: languageKey)
        }
        super.tearDown()
    }

    func testCurrencyNameTracksRuntimeLanguageChanges() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        let chineseName = CurrencyDefinition.usd.name

        UserDefaults.standard.set("en", forKey: languageKey)
        let englishName = CurrencyDefinition.usd.name

        XCTAssertEqual(chineseName, "美元")
        XCTAssertEqual(englishName, "US Dollar")
    }

    func testThemeDisplayNameTracksRuntimeLanguageChanges() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        let chineseName = NumiTheme.default.displayName

        UserDefaults.standard.set("en", forKey: languageKey)
        let englishName = NumiTheme.default.displayName

        XCTAssertEqual(chineseName, "默认")
        XCTAssertEqual(englishName, "Default")
    }

    func testStringLiteralOverloadUsesRawLocalizationKey() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.string("currency.name.USD"), "美元")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.string("currency.name.USD"), "US Dollar")
    }

    func testFormattedLookupUsesCatalogKeyAndArguments() {
        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.string("error.backup.fail", "磁盘已满"), "备份失败：磁盘已满")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.string("error.backup.fail", "Disk full"), "Backup failed: Disk full")
    }

    func testBackupOperationFailureDisplayMessageTracksRuntimeLanguage() {
        let backupFailure = BackupOperationFailure.createBackup("Disk full")
        let exportFailure = BackupOperationFailure.export("Permission denied")
        let restoreFailure = BackupOperationFailure.restoreBackup

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(backupFailure.displayMessage, "备份失败：Disk full")
        XCTAssertEqual(exportFailure.displayMessage, "导出失败：Permission denied")
        XCTAssertEqual(restoreFailure.displayMessage, "恢复失败：密码错误或文件损坏")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(backupFailure.displayMessage, "Backup failed: Disk full")
        XCTAssertEqual(exportFailure.displayMessage, "Export failed: Permission denied")
        XCTAssertEqual(restoreFailure.displayMessage, "Restore failed: incorrect password or corrupted file")
    }

    func testFetchRateFailureDisplayMessageTracksRuntimeLanguage() {
        let invalidURL = FetchRateFailure.invalidURL
        let httpStatus = FetchRateFailure.httpStatus(503)
        let network = FetchRateFailure.network("offline")

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(invalidURL.displayMessage, "URL 无效")
        XCTAssertEqual(httpStatus.displayMessage, "连接失败：503")
        XCTAssertEqual(network.displayMessage, "offline")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(invalidURL.displayMessage, "Invalid URL")
        XCTAssertEqual(httpStatus.displayMessage, "Connection failed: 503")
        XCTAssertEqual(network.displayMessage, "offline")
    }

    func testRegisteredBundleTakesPartInRuntimeLookup() throws {
        let bundleURL = temporaryLocalizationBundle(
            identifier: "ExtraLocalization.bundle",
            localizations: [
                "zh-Hans": ["setting.data": "数据"],
                "en": ["setting.data": "Data"]
            ]
        )
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))

        NumiLocalized.register(bundle: bundle)

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("setting.data"), "数据")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(NumiLocalized.lookup("setting.data"), "Data")
    }

    func testLookupFallsBackFromUnderscoreLocaleIdentifierToLanguageCode() throws {
        let bundleURL = temporaryLocalizationBundle(
            identifier: "UnderscoreLocaleFallback.bundle",
            localizations: [
                "en": ["setting.data": "Data"]
            ]
        )
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))

        NumiLocalized.register(bundle: bundle)

        XCTAssertEqual(
            NumiLocalized.lookup("setting.data", locale: Locale(identifier: "en_US")),
            "Data"
        )
    }

    func testLookupFallsBackFromScriptRegionLocaleIdentifierToScriptLanguageCode() throws {
        let bundleURL = temporaryLocalizationBundle(
            identifier: "ScriptRegionLocaleFallback.bundle",
            localizations: [
                "zh-Hans": ["setting.data": "数据"],
                "zh-Hant": ["setting.data": "資料"]
            ]
        )
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))

        NumiLocalized.register(bundle: bundle)

        XCTAssertEqual(
            NumiLocalized.lookup("setting.data", locale: Locale(identifier: "zh-Hans-CN")),
            "数据"
        )
        XCTAssertEqual(
            NumiLocalized.lookup("setting.data", locale: Locale(identifier: "zh_Hant_TW")),
            "資料"
        )
    }

    func testLookupInfersChineseScriptFromRegionWhenSystemLocaleOmitsScript() throws {
        let bundleURL = temporaryLocalizationBundle(
            identifier: "ChineseRegionInference.bundle",
            localizations: [
                "zh-Hans": ["setting.data": "数据"],
                "zh-Hant": ["setting.data": "資料"]
            ]
        )
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))

        NumiLocalized.register(bundle: bundle)

        XCTAssertEqual(
            NumiLocalized.lookup("setting.data", locale: Locale(identifier: "zh_CN")),
            "数据"
        )
        XCTAssertEqual(
            NumiLocalized.lookup("setting.data", locale: Locale(identifier: "zh_TW")),
            "資料"
        )
    }

    func testBuiltInCategoryDisplayNameTracksRuntimeLanguage() {
        let dining = Category(
            kind: .expense,
            name: "Dining",
            icon: "acai-bowl",
            sortOrder: 0
        )

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(dining.localizedDisplayName, "餐饮")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(dining.localizedDisplayName, "Dining")
    }

    func testBuiltInLedgerAndAccountDisplayNamesTrackRuntimeLanguage() {
        let ledger = Ledger(name: "Default Ledger", currencyCode: "CNY")
        let cash = Account(name: "Cash", type: .cash, balance: .zero(currencyCode: "CNY"))

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(ledger.localizedDisplayName, "默认账本")
        XCTAssertEqual(cash.localizedDisplayName, "现金")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(ledger.localizedDisplayName, "Default Ledger")
        XCTAssertEqual(cash.localizedDisplayName, "Cash")
    }

    func testBuiltInKeyCanDriveRuntimeDisplayNameWithoutMatchingStoredName() {
        let ledger = Ledger(
            name: "__legacy_default_ledger__",
            builtInKey: "ledger.default.name",
            currencyCode: "CNY"
        )
        let category = Category(
            kind: .expense,
            name: "__legacy_dining__",
            builtInKey: "category.default.expense.dining",
            icon: "acai-bowl",
            sortOrder: 0
        )
        let account = Account(
            name: "__legacy_cash__",
            builtInKey: "account.default.cash",
            type: .cash,
            balance: .zero(currencyCode: "CNY")
        )

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual(ledger.localizedDisplayName, "默认账本")
        XCTAssertEqual(category.localizedDisplayName, "餐饮")
        XCTAssertEqual(account.localizedDisplayName, "现金")

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual(ledger.localizedDisplayName, "Default Ledger")
        XCTAssertEqual(category.localizedDisplayName, "Dining")
        XCTAssertEqual(account.localizedDisplayName, "Cash")
    }

    func testResolveLocalizedCategoryMatchesBuiltInNamesAcrossRuntimeLanguages() {
        let dining = Category(
            kind: .expense,
            name: "__legacy_dining__",
            builtInKey: "category.default.expense.dining",
            icon: "acai-bowl",
            sortOrder: 0
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual([dining].resolveLocalizedCategory(named: "Dining")?.id, dining.id)
        XCTAssertEqual([dining].resolveLocalizedCategory(named: "餐饮")?.id, dining.id)

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual([dining].resolveLocalizedCategory(named: "Dining")?.id, dining.id)
        XCTAssertEqual([dining].resolveLocalizedCategory(named: "餐饮")?.id, dining.id)
    }

    func testLocalizedCategoryNamesKeepCustomNamesWhileLocalizingBuiltIns() {
        let builtIn = Category(
            kind: .expense,
            name: "__legacy_dining__",
            builtInKey: "category.default.expense.dining",
            icon: "acai-bowl",
            sortOrder: 0
        )
        let custom = Category(
            kind: .expense,
            name: "Coffee Beans",
            icon: "cup-and-saucer",
            sortOrder: 1
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual([builtIn, custom].localizedCategoryNames(), ["Dining", "Coffee Beans"])

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual([builtIn, custom].localizedCategoryNames(), ["餐饮", "Coffee Beans"])
        XCTAssertEqual([builtIn, custom].resolveLocalizedCategory(named: "Coffee Beans")?.id, custom.id)
    }

    func testResolveLocalizedAccountMatchesBuiltInNamesAcrossRuntimeLanguages() {
        let cash = Account(
            name: "__legacy_cash__",
            builtInKey: "account.default.cash",
            type: .cash,
            balance: .zero(currencyCode: "CNY")
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual([cash].resolveLocalizedAccount(named: "Cash")?.id, cash.id)
        XCTAssertEqual([cash].resolveLocalizedAccount(named: "现金")?.id, cash.id)

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual([cash].resolveLocalizedAccount(named: "Cash")?.id, cash.id)
        XCTAssertEqual([cash].resolveLocalizedAccount(named: "现金")?.id, cash.id)
    }

    func testLocalizedAccountNamesKeepCustomNamesWhileLocalizingBuiltIns() {
        let builtIn = Account(
            name: "__legacy_cash__",
            builtInKey: "account.default.cash",
            type: .cash,
            balance: .zero(currencyCode: "CNY")
        )
        let custom = Account(
            name: "Travel Wallet",
            type: .other,
            balance: .zero(currencyCode: "CNY")
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual([builtIn, custom].localizedAccountNames(), ["Cash", "Travel Wallet"])

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        XCTAssertEqual([builtIn, custom].localizedAccountNames(), ["现金", "Travel Wallet"])
        XCTAssertEqual([builtIn, custom].resolveLocalizedAccount(named: "Travel Wallet")?.id, custom.id)
    }

    func testResolveLocalizedTransferAccountsUsesExplicitSourceAndTargetWhenBothProvided() {
        let cash = Account(
            name: "__legacy_cash__",
            builtInKey: "account.default.cash",
            type: .cash,
            balance: .zero(currencyCode: "CNY")
        )
        let card = Account(
            name: "__legacy_card__",
            builtInKey: "account.default.bankCard",
            type: .debitCard,
            balance: .zero(currencyCode: "CNY")
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        let resolution = [cash, card].resolveLocalizedTransferAccounts(
            parsedAccountName: "Cash",
            parsedTargetAccountName: "Bank Card"
        )

        XCTAssertEqual(resolution?.source.id, cash.id)
        XCTAssertEqual(resolution?.target.id, card.id)
    }

    func testResolveLocalizedTransferAccountsTreatsLegacySingleAccountAsTargetAndFallsBackSource() {
        let cash = Account(
            name: "__legacy_cash__",
            builtInKey: "account.default.cash",
            type: .cash,
            balance: .zero(currencyCode: "CNY")
        )
        let card = Account(
            name: "__legacy_card__",
            builtInKey: "account.default.bankCard",
            type: .debitCard,
            balance: .zero(currencyCode: "CNY")
        )

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        let resolution = [cash, card].resolveLocalizedTransferAccounts(
            parsedAccountName: "银行卡",
            parsedTargetAccountName: nil
        )

        XCTAssertEqual(resolution?.source.id, cash.id)
        XCTAssertEqual(resolution?.target.id, card.id)
    }

    func testResolveLocalizedTransferAccountsReturnsNilWhenNoDistinctSourceAccountExists() {
        let card = Account(
            name: "__legacy_card__",
            builtInKey: "account.default.bankCard",
            type: .debitCard,
            balance: .zero(currencyCode: "CNY")
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        let resolution = [card].resolveLocalizedTransferAccounts(
            parsedAccountName: "Bank Card",
            parsedTargetAccountName: nil
        )

        XCTAssertNil(resolution)
    }

    func testLocalizedAccountSortingUsesRuntimeDisplayNameInsteadOfStoredName() {
        let cash = Account(
            name: "__aaa__",
            builtInKey: "account.default.cash",
            type: .cash,
            balance: .zero(currencyCode: "CNY")
        )
        let card = Account(
            name: "__zzz__",
            builtInKey: "account.default.bankCard",
            type: .debitCard,
            balance: .zero(currencyCode: "CNY")
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual([cash, card].sortedForLocalizedDisplay().map(\.localizedDisplayName), ["Bank Card", "Cash"])
    }

    func testLocalizedCategorySortingUsesRuntimeDisplayNameInsteadOfStoredName() {
        let dining = Category(
            kind: .expense,
            name: "__zzz__",
            builtInKey: "category.default.expense.dining",
            icon: "acai-bowl",
            sortOrder: 0
        )
        let shopping = Category(
            kind: .expense,
            name: "__aaa__",
            builtInKey: "category.default.expense.shopping",
            icon: "shopping-bags",
            sortOrder: 0
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual([dining, shopping].sortedForLocalizedDisplay().map(\.localizedDisplayName), ["Dining", "Shopping"])
    }

    func testLocalizedLedgerSortingUsesRuntimeDisplayNameInsteadOfStoredName() {
        let builtIn = Ledger(
            name: "__aaa__",
            builtInKey: "ledger.default.name",
            currencyCode: "CNY"
        )
        let custom = Ledger(
            name: "Cash Ledger",
            currencyCode: "CNY"
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        XCTAssertEqual([builtIn, custom].sortedForLocalizedDisplay().map(\.localizedDisplayName), ["Cash Ledger", "Default Ledger"])
    }

    func testDateFormatStyleTracksRuntimeLanguage() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 9, minute: 30)))

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        let chineseText = date.numiFormatted(.dateTime.year().month().day())
        XCTAssertTrue(
            chineseText.contains("2026") && chineseText.contains("3") && chineseText.contains("月"),
            "Runtime date formatting should respect the Simplified Chinese app language."
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        let englishText = date.numiFormatted(.dateTime.year().month().day())
        XCTAssertTrue(
            englishText.localizedCaseInsensitiveContains("Mar"),
            "Runtime date formatting should respect the English app language."
        )
    }

    func testTimeFormattingTracksRuntimeLanguage() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 21, minute: 30)))

        UserDefaults.standard.set("zh-Hans", forKey: languageKey)
        let chineseText = date.numiTimeText()
        XCTAssertTrue(
            chineseText.contains("21") || chineseText.contains("晚上"),
            "Runtime time formatting should respect the Simplified Chinese app language."
        )

        UserDefaults.standard.set("en", forKey: languageKey)
        let englishText = date.numiTimeText()
        XCTAssertTrue(
            englishText.localizedCaseInsensitiveContains("PM") || englishText.contains("21"),
            "Runtime time formatting should respect the English app language."
        )
    }

    func testPercentFormattingCanUseLocaleAwareSpacingAndSeparator() {
        let frenchText = NumiLocalized.percent(0.256, maximumFractionDigits: 1, locale: Locale(identifier: "fr_FR"))
        XCTAssertTrue(frenchText.contains("25"))
        XCTAssertTrue(frenchText.contains("%"))
        XCTAssertTrue(frenchText.contains(",") || frenchText.contains("\u{00A0}") || frenchText.contains("\u{202F}"))
    }

    private func temporaryLocalizationBundle(
        identifier: String,
        localizations: [String: [String: String]],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(identifier, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            for (language, strings) in localizations {
                let lproj = root.appendingPathComponent("\(language).lproj", isDirectory: true)
                try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
                let contents = strings
                    .map { "\"\($0.key)\" = \"\($0.value)\";" }
                    .joined(separator: "\n")
                try contents.write(
                    to: lproj.appendingPathComponent("Localizable.strings"),
                    atomically: true,
                    encoding: .utf8
                )
            }
        } catch {
            XCTFail("Failed to create localization bundle: \(error)", file: file, line: line)
        }

        return root
    }
}
