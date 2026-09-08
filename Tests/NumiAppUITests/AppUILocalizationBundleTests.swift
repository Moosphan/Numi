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

    func testMembershipStatusCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": (tier: "免费版", description: "基础记账完整可用，Pro 解锁更多效率与安全能力"),
            "en": (tier: "Free", description: "All core bookkeeping is available; Pro unlocks more efficiency and security."),
            "zh-Hant": (tier: "免費版", description: "基礎記帳完整可用，Pro 解鎖更多效率與安全能力"),
            "ja": (tier: "無料版", description: "基本の家計管理はすべて利用可能。Proで効率性と安全性をさらに高められます。")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("membership.free", locale: locale), expected.tier)
            XCTAssertEqual(NumiLocalized.lookup("membership.free.description", locale: locale), expected.description)
        }
    }

    func testMembershipDetailsCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": (title: "Numi Pro", benefit: "加密备份", plan: "选择方案"),
            "en": (title: "Numi Pro", benefit: "Encrypted backups", plan: "Choose a plan"),
            "zh-Hant": (title: "Numi Pro", benefit: "加密備份", plan: "選擇方案"),
            "ja": (title: "Numi Pro", benefit: "暗号化バックアップ", plan: "プランを選択")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("membership.details.title", locale: locale), expected.title)
            XCTAssertEqual(NumiLocalized.lookup("membership.benefit.security.title", locale: locale), expected.benefit)
            XCTAssertEqual(NumiLocalized.lookup("membership.plan.title", locale: locale), expected.plan)
        }
    }

    func testSiriShortcutGuideCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": (title: "Siri 与快捷指令记账", summary: "用语音或快捷指令快速记录一笔账", example: "用 Numi 记录午餐 28 元"),
            "en": (title: "Siri & Shortcuts", summary: "Record a transaction quickly with voice or Shortcuts", example: "Record lunch for 28 with Numi"),
            "zh-Hant": (title: "Siri 與捷徑記帳", summary: "使用語音或捷徑快速記錄一筆帳", example: "用 Numi 記錄午餐 28 元"),
            "ja": (title: "Siriとショートカット", summary: "音声またはショートカットで取引をすばやく記録", example: "Numiでランチを28元で記録" )
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("siri.shortcuts.title", locale: locale), expected.title)
            XCTAssertEqual(NumiLocalized.lookup("siri.shortcuts.summary", locale: locale), expected.summary)
            XCTAssertEqual(NumiLocalized.lookup("siri.shortcuts.example", locale: locale), expected.example)
        }
    }

    func testCurrencyPreviewBadgeCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": "功能预览",
            "en": "Preview",
            "zh-Hant": "功能預覽",
            "ja": "プレビュー"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("membership.benefit.preview.badge", locale: Locale(identifier: language)),
                expected,
                "Missing currency-preview badge for \(language)"
            )
        }
    }

    func testAIQuickRecordComposerCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": (title: "AI 快速记账", review: "AI 只会生成可编辑草稿，保存前请确认每一项。", configure: "先配置 AI 服务", loading: "正在生成可编辑草稿…", retry: "重试"),
            "en": (title: "AI Quick Record", review: "AI creates an editable draft only. Review every detail before saving.", configure: "Configure AI Service First", loading: "Creating editable draft…", retry: "Retry"),
            "zh-Hant": (title: "AI 快速記帳", review: "AI 只會產生可編輯草稿，儲存前請確認每一項。", configure: "先設定 AI 服務", loading: "正在產生可編輯草稿…", retry: "重試"),
            "ja": (title: "AIクイック記帳", review: "AIは編集可能な下書きのみを作成します。保存前にすべて確認してください。", configure: "先にAIサービスを設定", loading: "編集可能な下書きを作成中…", retry: "再試行")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("ai.quickRecord.title", locale: locale), expected.title)
            XCTAssertEqual(NumiLocalized.lookup("ai.quickRecord.review", locale: locale), expected.review)
            XCTAssertEqual(NumiLocalized.lookup("ai.quickRecord.configure", locale: locale), expected.configure)
            XCTAssertEqual(NumiLocalized.lookup("ai.quickRecord.loading", locale: locale), expected.loading)
            XCTAssertEqual(NumiLocalized.lookup("ai.quickRecord.failure.retry", locale: locale), expected.retry)
        }
    }

    func testManualExchangeRateCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": (action: "手动设置汇率", description: "离线时可自行设置当前汇率，保存后将关闭自动更新", save: "保存汇率", source: "汇率数据来源：手动设置"),
            "en": (action: "Set a Manual Rate", description: "Set the current rate yourself when offline; saving turns off automatic updates", save: "Save Rate", source: "Rate data source: Set manually"),
            "zh-Hant": (action: "手動設定匯率", description: "離線時可自行設定目前匯率，儲存後將關閉自動更新", save: "儲存匯率", source: "匯率資料來源：手動設定"),
            "ja": (action: "手動レートを設定", description: "オフライン時に現在のレートを設定でき、保存すると自動更新がオフになります", save: "レートを保存", source: "為替レートデータソース：手動設定")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("currency.manual.rate", locale: locale), expected.action)
            XCTAssertEqual(NumiLocalized.lookup("currency.manual.rate.desc", locale: locale), expected.description)
            XCTAssertEqual(NumiLocalized.lookup("currency.manual.rate.save", locale: locale), expected.save)
            XCTAssertEqual(NumiLocalized.lookup("currency.source.manual", locale: locale), expected.source)
        }
    }

    func testBudgetRolloverCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": (title: "结转未用预算", detail: "仅结转上一周期基础预算的未用余额；超支不抵扣下期，结转不跨期累计", carried: "已结转 %@", available: "已用 / 含结转可用额度"),
            "en": (title: "Roll Over Unused Budget", detail: "Carry over only unused funds from the previous period’s base budget. Overspending is not deducted and carryover does not compound.", carried: "%@ carried over", available: "Used / Available incl. rollover"),
            "zh-Hant": (title: "結轉未用預算", detail: "僅結轉上一期基礎預算的未用餘額；超支不扣抵下期，結轉不跨期累計", carried: "已結轉 %@", available: "已用 / 含結轉可用額度"),
            "ja": (title: "未使用予算を繰り越す", detail: "前期の基本予算の未使用額のみを繰り越します。超過分は次期から差し引かれず、繰り越しは累積しません。", carried: "%@ を繰り越し", available: "使用済み / 繰り越しを含む利用可能額")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("budget.rollover.title", locale: locale), expected.title)
            XCTAssertEqual(NumiLocalized.lookup("budget.rollover.detail", locale: locale), expected.detail)
            XCTAssertEqual(NumiLocalized.lookup("budget.rollover.carried", locale: locale), expected.carried)
            XCTAssertEqual(NumiLocalized.lookup("budget.used.available", locale: locale), expected.available)
        }
    }

    func testPremiumThemeCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": (ocean: "海湾蓝", iris: "鸢尾紫", oceanDetail: "冷静的海湾蓝与清透底色，适合专注查看资产和趋势。"),
            "en": (ocean: "Ocean Blue", iris: "Iris Violet", oceanDetail: "Calm ocean blue and a clear canvas for focused reviews of balances and trends."),
            "zh-Hant": (ocean: "海灣藍", iris: "鳶尾紫", oceanDetail: "冷靜的海灣藍與清透底色，適合專注查看資產與趨勢。"),
            "ja": (ocean: "オーシャンブルー", iris: "アイリスバイオレット", oceanDetail: "落ち着いた海の青と澄んだ背景。残高や推移を集中して確認できます。")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("theme.ocean", locale: locale), expected.ocean)
            XCTAssertEqual(NumiLocalized.lookup("theme.iris", locale: locale), expected.iris)
            XCTAssertEqual(NumiLocalized.lookup("theme.ocean.desc", locale: locale), expected.oceanDetail)
        }
    }

    func testMissingHistoricalRateCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": "缺少历史汇率，无法汇总",
            "en": "Historical rate unavailable",
            "zh-Hant": "缺少歷史匯率，無法彙總",
            "ja": "過去の為替レートがないため集計できません"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("insight.exchange.rate.unavailable", locale: Locale(identifier: language)),
                expected,
                "Missing historical-rate state for \(language)"
            )
        }
    }

    func testIncompleteCurrencySummaryCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": "部分汇总未包含：缺少历史汇率",
            "en": "Some totals are excluded because historical rates are unavailable",
            "zh-Hant": "部分彙總未包含：缺少歷史匯率",
            "ja": "過去の為替レートがないため、一部の集計を除外しています"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("currency.summary.unavailable", locale: Locale(identifier: language)),
                expected,
                "Missing incomplete-summary state for \(language)"
            )
        }
    }

    func testInsightsComparisonCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": (title: "与上一周期对比", previous: "上一期：¥100.00"),
            "en": (title: "Compare with Previous Period", previous: "Previous: ¥100.00"),
            "zh-Hant": (title: "與上一期比較", previous: "上一期：¥100.00"),
            "ja": (title: "前の期間と比較", previous: "前の期間：¥100.00")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("insight.comparison.title", locale: locale), expected.title)
            XCTAssertEqual(
                NumiLocalized.format(
                    "insight.comparison.previous",
                    arguments: ["¥100.00"],
                    locale: locale
                ),
                expected.previous
            )
        }
    }

    func testInsightsModuleCustomizationCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": (action: "自定义洞悉模块", title: "自定义洞悉"),
            "en": (action: "Customize Insight Modules", title: "Customize Insights"),
            "zh-Hant": (action: "自訂洞悉模組", title: "自訂洞悉"),
            "ja": (action: "洞察モジュールをカスタマイズ", title: "洞察をカスタマイズ")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("insight.customize.modules", locale: locale), expected.action)
            XCTAssertEqual(NumiLocalized.lookup("insight.customize.modules.title", locale: locale), expected.title)
            XCTAssertNotEqual(NumiLocalized.lookup("insight.customize.modules.hint", locale: locale), "insight.customize.modules.hint")
        }
    }

    func testInsightsAccountFilterCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": (all: "全部账户", title: "筛选账户"),
            "en": (all: "All Accounts", title: "Filter Accounts"),
            "zh-Hant": (all: "全部帳戶", title: "篩選帳戶"),
            "ja": (all: "すべての口座", title: "口座を絞り込む")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("insight.account.all", locale: locale), expected.all)
            XCTAssertEqual(NumiLocalized.lookup("insight.account.filter.title", locale: locale), expected.title)
        }
    }

    func testInsightsTrendCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": "收支趋势",
            "en": "Cash Flow Trend",
            "zh-Hant": "收支趨勢",
            "ja": "収支の推移"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("insight.trend.title", locale: Locale(identifier: language)),
                expected
            )
            XCTAssertNotEqual(
                NumiLocalized.lookup("insight.trend.subtitle", locale: Locale(identifier: language)),
                "insight.trend.subtitle"
            )
        }
    }

    func testCSVForeignCurrencyImportWarningCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": (
                title: "外币记录会保留原币种",
                message: "CSV 不包含历史汇率快照；导入后跨币种历史汇总需要已有或补充的历史汇率。"
            ),
            "en": (
                title: "Foreign-currency records keep their original currency",
                message: "CSV does not include historical rate snapshots. Historical cross-currency totals require existing or added rates after import."
            ),
            "zh-Hant": (
                title: "外幣記錄會保留原幣別",
                message: "CSV 不包含歷史匯率快照；匯入後跨幣別歷史彙總需要既有或補充的歷史匯率。"
            ),
            "ja": (
                title: "外貨建ての記録は元の通貨で保持されます",
                message: "CSVには過去の為替レートのスナップショットは含まれません。インポート後の通貨換算集計には、既存または追加した過去のレートが必要です。"
            )
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("io.import.csv.currency.warning.title", locale: locale), expected.title)
            XCTAssertEqual(NumiLocalized.lookup("io.import.csv.currency.warning.message", locale: locale), expected.message)
        }
    }

    func testCSVAccountCurrencyMismatchCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": "交易币种与所选账户币种不一致",
            "en": "The transaction currency does not match the selected account",
            "zh-Hant": "交易幣別與所選帳戶幣別不一致",
            "ja": "取引通貨が選択した口座の通貨と一致しません"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("io.import.csv.error.account.currency.mismatch", locale: Locale(identifier: language)),
                expected,
                "Missing account-currency mismatch copy for \(language)"
            )
        }
    }

    func testCSVRecordedConversionCurrencyMismatchCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": "固定折算金额的币种必须与目标账本币种一致",
            "en": "The recorded converted amount must use the target ledger currency",
            "zh-Hant": "固定換算金額的幣別必須與目標帳本幣別一致",
            "ja": "記録時換算額の通貨は対象の帳簿通貨と一致する必要があります"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("io.import.csv.error.converted.amount.currency.mismatch", locale: Locale(identifier: language)),
                expected,
                "Missing recorded-conversion currency mismatch copy for \(language)"
            )
        }
    }

    func testSnapshotRecordedConversionCurrencyMismatchCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": "备份中的固定折算金额币种与所属账本不一致",
            "en": "A recorded converted amount in this backup does not match its ledger currency",
            "zh-Hant": "備份中的固定換算金額幣別與所屬帳本不一致",
            "ja": "バックアップ内の記録時換算額の通貨が帳簿通貨と一致しません"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("io.import.error.converted.amount.currency.mismatch", locale: Locale(identifier: language)),
                expected,
                "Missing snapshot conversion currency mismatch copy for \(language)"
            )
        }
    }

    func testRecordSaveFailureCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": "无法保存记录，请检查账户币种和必填项后重试。",
            "en": "Unable to save this record. Check the account currency and required fields, then try again.",
            "zh-Hant": "無法儲存記錄，請檢查帳戶幣別和必填欄位後再試。",
            "ja": "記録を保存できません。口座の通貨と必須項目を確認して、もう一度お試しください。"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("error.record.save.failed", locale: Locale(identifier: language)),
                expected,
                "Missing record-save failure copy for \(language)"
            )
        }
    }

    func testNoCompatibleAccountCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": "没有与所选币种匹配的账户，请先创建对应币种账户。",
            "en": "No account matches the selected currency. Create an account in that currency first.",
            "zh-Hant": "沒有與所選幣別相符的帳戶，請先建立對應幣別帳戶。",
            "ja": "選択した通貨に一致する口座がありません。先にその通貨の口座を作成してください。"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("record.account.currency.unavailable", locale: Locale(identifier: language)),
                expected,
                "Missing unavailable-account copy for \(language)"
            )
        }
    }

    func testBatchEditCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": (title: "批量编辑", action: "修改分类", hint: "仅修改同一收支类型的分类"),
            "en": (title: "Batch Edit", action: "Change Category", hint: "Only categories for matching transaction types can be changed."),
            "zh-Hant": (title: "批次編輯", action: "修改分類", hint: "僅修改相同收支類型的分類"),
            "ja": (title: "一括編集", action: "カテゴリを変更", hint: "同じ取引タイプのカテゴリのみ変更できます。")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("batch.edit", locale: locale), expected.title)
            XCTAssertEqual(NumiLocalized.lookup("batch.edit.apply", locale: locale), expected.action)
            XCTAssertEqual(NumiLocalized.lookup("batch.edit.hint", locale: locale), expected.hint)
        }
    }

    func testBatchEditPreviewCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": (title: "确认修改分类", apply: "确认修改", undo: "撤销"),
            "en": (title: "Confirm Category Change", apply: "Confirm Change", undo: "Undo"),
            "zh-Hant": (title: "確認修改分類", apply: "確認修改", undo: "復原"),
            "ja": (title: "カテゴリ変更を確認", apply: "変更を確定", undo: "取り消す")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("batch.edit.preview.title", locale: locale), expected.title)
            XCTAssertEqual(NumiLocalized.lookup("batch.edit.preview.apply", locale: locale), expected.apply)
            XCTAssertEqual(NumiLocalized.lookup("batch.edit.undo", locale: locale), expected.undo)
        }
    }

    func testRecordDetailRuntimeCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": (title: "账单详情", close: "关闭", edit: "编辑"),
            "en": (title: "Record Details", close: "Close", edit: "Edit"),
            "zh-Hant": (title: "帳單詳情", close: "關閉", edit: "編輯"),
            "ja": (title: "記録詳細", close: "閉じる", edit: "編集")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("record.detail", locale: locale), expected.title)
            XCTAssertEqual(NumiLocalized.lookup("common.close", locale: locale), expected.close)
            XCTAssertEqual(NumiLocalized.lookup("common.edit", locale: locale), expected.edit)
        }
    }

    func testRecordedConversionCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": "记账时折算",
            "en": "Converted at Record Time",
            "zh-Hant": "記帳時折算",
            "ja": "記録時の換算額"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("record.converted.amount", locale: Locale(identifier: language)),
                expected,
                "Missing recorded-conversion copy for \(language)"
            )
        }
    }

    func testRuntimeLocalizedSwiftUIKeysDoNotUseDirectLiterals() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceDirectories = [
            sourceRoot.appendingPathComponent("Sources/NumiAppUI"),
            sourceRoot.appendingPathComponent("App/NumiApp")
        ]
        let pattern = #"\b(?:Text|Button|Label|Toggle|Picker|Section|Menu|NavigationLink|GroupBox|LabeledContent|ShareLink|alert|confirmationDialog|navigationTitle|accessibilityLabel|accessibilityHint)\s*\(\s*\"([a-z][A-Za-z0-9_.-]*\.[A-Za-z0-9_.-]*)\""#
        let expression = try NSRegularExpression(pattern: pattern)
        var violations = [String]()

        for directory in sourceDirectories {
            let files = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: nil
            )?.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []

            for file in files {
                let source = try String(contentsOf: file, encoding: .utf8)
                let range = NSRange(source.startIndex..., in: source)
                for match in expression.matches(in: source, range: range) {
                    let line = source[..<Range(match.range, in: source)!.lowerBound]
                        .reduce(into: 1) { count, character in
                            if character == "\n" { count += 1 }
                        }
                    violations.append("\(file.path.replacingOccurrences(of: sourceRoot.path + "/", with: "")):\(line)")
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "Direct SwiftUI localization key literals bypass NumiLocalized:\n\(violations.sorted().joined(separator: "\n"))"
        )
    }

    func testMembershipBannerCopySeparatesReleasedBenefitsFromFeaturePreviews() {
        let expectedValues = [
            "zh-Hans": (bills: "订阅与分期，一处掌控", sync: "跨设备同步", ai: "AI 快速记账", preview: "功能预览 · 暂未包含在 Pro 中"),
            "en": (bills: "Subscriptions & installments, in one place", sync: "Cross-device sync", ai: "AI quick record", preview: "Preview · not included in Pro"),
            "zh-Hant": (bills: "訂閱與分期，一處掌控", sync: "跨裝置同步", ai: "AI 快速記帳", preview: "功能預覽 · 尚未包含在 Pro 中"),
            "ja": (bills: "サブスクと分割払いを一元管理", sync: "デバイス間同期", ai: "AIクイック記帳", preview: "プレビュー・現在はPro対象外")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("membership.benefit.scheduledBills.title", locale: locale), expected.bills)
            XCTAssertEqual(NumiLocalized.lookup("membership.benefit.sync.title", locale: locale), expected.sync)
            XCTAssertEqual(NumiLocalized.lookup("membership.benefit.ai.title", locale: locale), expected.ai)
            XCTAssertEqual(NumiLocalized.lookup("membership.benefit.preview.notIncluded", locale: locale), expected.preview)
        }
    }

    func testMembershipAnnualSavingsCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": "节省 %lld%%",
            "en": "Save %lld%%",
            "zh-Hant": "節省 %lld%%",
            "ja": "%lld%% お得"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("membership.plan.yearly.savings", locale: Locale(identifier: language)),
                expected,
                "Missing annual savings copy for \(language)"
            )
        }
    }

    func testAccountCurrencyPickerUsesExistingLocalizedLabel() {
        let expectedValues = [
            "zh-Hans": "货币",
            "en": "Currency",
            "zh-Hant": "貨幣",
            "ja": "通貨"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("ledger.currency", locale: Locale(identifier: language)),
                expected,
                "Missing existing currency label for \(language)"
            )
        }
    }

    func testMembershipCommerceCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": (success: "订阅已生效，Pro 权益现已解锁。", ledgerLimit: "免费版最多可创建 2 个账本，升级 Pro 后可无限创建。"),
            "en": (success: "Your subscription is active and Pro features are unlocked.", ledgerLimit: "Free includes up to 2 ledgers. Upgrade to Pro for unlimited ledgers."),
            "zh-Hant": (success: "訂閱已生效，Pro 權益現已解鎖。", ledgerLimit: "免費版最多可建立 2 個帳本，升級 Pro 後可無限建立。"),
            "ja": (success: "サブスクリプションが有効になり、Pro機能が利用できます。", ledgerLimit: "無料版では帳簿を2個まで作成できます。Proにアップグレードすると無制限です。")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("membership.commerce.purchase.success", locale: locale), expected.success)
            XCTAssertEqual(NumiLocalized.lookup("membership.limit.ledgers", locale: locale), expected.ledgerLimit)
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

    func testCustomSubscriptionIntervalFormLabelsAreLocalized() {
        let expectedValues = [
            "zh-Hans": (value: "每隔", unit: "单位"),
            "en": (value: "Every", unit: "Unit"),
            "zh-Hant": (value: "每隔", unit: "單位"),
            "ja": (value: "間隔", unit: "単位")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("subscription.interval.value", locale: locale), expected.value)
            XCTAssertEqual(NumiLocalized.lookup("subscription.interval.unit", locale: locale), expected.unit)
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

    func testReminderPermissionDeniedCopyIsLocalized() {
        let expectedValues = [
            "zh-Hans": "未获得通知权限，请在系统设置中开启通知后重试。",
            "en": "Notifications are not allowed. Enable them in Settings and try again.",
            "zh-Hant": "未取得通知權限，請在系統設定中開啟通知後再試。",
            "ja": "通知が許可されていません。設定で通知を有効にしてからもう一度お試しください。"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("reminder.permission.denied", locale: Locale(identifier: language)),
                expected
            )
        }
    }

    func testInstallmentReminderCopyIsLocalized() {
        let expectedValues = [
            "zh-Hans": (title: "分期提醒", enable: "开启分期提醒", body: "Plan的第 2 期将于明天到期（$40.00）"),
            "en": (title: "Installment Reminder", enable: "Enable Installment Reminder", body: "Plan Period 2 is due tomorrow ($40.00)"),
            "zh-Hant": (title: "分期提醒", enable: "開啟分期提醒", body: "Plan的第 2 期將於明天到期（$40.00）"),
            "ja": (title: "分割払いのリマインダー", enable: "分割払いリマインダーを有効化", body: "Planの第2回は明日が支払期日です（$40.00）")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("installment.reminder.title", locale: locale), expected.title)
            XCTAssertEqual(NumiLocalized.lookup("installment.reminder.enable", locale: locale), expected.enable)
            XCTAssertEqual(
                NumiLocalized.format(
                    "installment.reminder.body",
                    arguments: [
                        "Plan",
                        NumiLocalized.format("installment.period.n", arguments: [2], locale: locale),
                        "$40.00"
                    ],
                    locale: locale
                ),
                expected.body
            )
        }
    }

    func testInstallmentReminderPreferenceCopyIsLocalized() {
        let expectedValues = [
            "zh-Hans": (section: "提醒", label: "分期还款提醒", detail: "在下一笔待还分期到期前通知你", value: "提前 3 天", onDate: "当天提醒"),
            "en": (section: "Reminders", label: "Installment due reminder", detail: "Get notified before your next unpaid installment is due.", value: "3 days before", onDate: "On the day"),
            "zh-Hant": (section: "提醒", label: "分期還款提醒", detail: "在下一筆待還分期到期前通知你", value: "提前 3 天", onDate: "當天提醒"),
            "ja": (section: "リマインダー", label: "分割払いの返済通知", detail: "次の未払い分割払いの期日前に通知します。", value: "3日前", onDate: "当日に通知")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("setting.reminders", locale: locale), expected.section)
            XCTAssertEqual(NumiLocalized.lookup("setting.installment.reminder.days", locale: locale), expected.label)
            XCTAssertEqual(NumiLocalized.lookup("setting.installment.reminder.days.desc", locale: locale), expected.detail)
            XCTAssertEqual(NumiLocalized.lookup("setting.reminder.days.onDate", locale: locale), expected.onDate)
            XCTAssertEqual(
                NumiLocalized.format("setting.installment.reminder.days.value", arguments: [3], locale: locale),
                expected.value
            )
        }
    }

    func testSubscriptionReminderPreferenceCopyIsLocalized() {
        let expectedValues = [
            "zh-Hans": (label: "订阅扣费提醒", detail: "在订阅下一次扣费前通知你"),
            "en": (label: "Subscription billing reminder", detail: "Get notified before your next subscription billing date."),
            "zh-Hant": (label: "訂閱扣款提醒", detail: "在訂閱下一次扣款前通知你"),
            "ja": (label: "サブスク請求通知", detail: "次のサブスク請求日前に通知します。")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("setting.subscription.reminder.days", locale: locale), expected.label)
            XCTAssertEqual(NumiLocalized.lookup("setting.subscription.reminder.days.desc", locale: locale), expected.detail)
        }
    }

    func testReminderLeadTimeValueCopyIsLocalized() {
        let expectedValues = [
            "zh-Hans": "提前 3 天",
            "en": "3 days before",
            "zh-Hant": "提前 3 天",
            "ja": "3日前"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.format(
                    "setting.reminder.days.value",
                    arguments: [3],
                    locale: Locale(identifier: language)
                ),
                expected
            )
        }
    }

    func testSubscriptionBillingConfirmationActionIsLocalized() {
        let expectedValues = [
            "zh-Hans": "确认扣费",
            "en": "Confirm Billing",
            "zh-Hant": "確認扣款",
            "ja": "請求を確認"
        ]

        for (language, expected) in expectedValues {
            XCTAssertEqual(
                NumiLocalized.lookup("subscription.record.billing", locale: Locale(identifier: language)),
                expected
            )
        }
    }

    func testSubscriptionConfirmationModeCopyIsLocalized() {
        let expectedValues = [
            "zh-Hans": (title: "扣费需确认", detail: "开启后，到期订阅不会自动记账，需要手动确认。"),
            "en": (title: "Confirm Billing Manually", detail: "When enabled, due subscriptions wait for your confirmation before recording."),
            "zh-Hant": (title: "扣款需確認", detail: "開啟後，到期訂閱不會自動記帳，需要手動確認。"),
            "ja": (title: "請求を手動確認", detail: "有効にすると、期限のサブスクは確認するまで自動記録されません。")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("subscription.confirmation.mode", locale: locale), expected.title)
            XCTAssertEqual(NumiLocalized.lookup("subscription.confirmation.mode.detail", locale: locale), expected.detail)
        }
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

    func testScheduledICloudSyncCopyMakesCompletionUncertaintyExplicitInEveryLanguage() {
        let expectedValues = [
            "zh-Hans": (scheduled: "已请求 iCloud 同步；完成状态暂不可用", completed: "检测到 iCloud 同步活动已完成", requested: "已请求", requestedAt: "请求于 %@", lastCompleted: "上次完成：%@"),
            "en": (scheduled: "iCloud sync requested; completion status is unavailable", completed: "iCloud sync activity completed", requested: "Requested", requestedAt: "Requested %@", lastCompleted: "Last completed: %@"),
            "zh-Hant": (scheduled: "已請求 iCloud 同步；完成狀態暫不可用", completed: "偵測到 iCloud 同步活動已完成", requested: "已請求", requestedAt: "請求於 %@", lastCompleted: "上次完成：%@"),
            "ja": (scheduled: "iCloud同期を要求しました。完了状態は利用できません", completed: "iCloud同期アクティビティの完了を検出しました", requested: "リクエスト済み", requestedAt: "リクエスト日時：%@", lastCompleted: "前回の完了：%@")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("sync.status.scheduled", locale: locale), expected.scheduled)
            XCTAssertEqual(NumiLocalized.lookup("sync.status.success", locale: locale), expected.completed)
            XCTAssertEqual(NumiLocalized.lookup("sync.requested", locale: locale), expected.requested)
            XCTAssertEqual(NumiLocalized.lookup("sync.requested.at", locale: locale), expected.requestedAt)
            XCTAssertEqual(NumiLocalized.lookup("sync.last.completed", locale: locale), expected.lastCompleted)
        }
    }

    func testAdvancedPlanForecastCopyCoversAllSupportedRuntimeLanguages() {
        let expectedValues = [
            "zh-Hans": (title: "未来 30 天计划支出", detail: "此卡仅用于预览，不会因查看而创建交易；订阅仍按各自设置执行", locked: "解锁计划支出预览", total: "CNY 预计合计", excludedOnly: "未来 30 天有 2 笔其他币种计划支出，未计入 CNY 预计合计", showingNearest: "共 5 笔计划支出，显示最近 3 笔"),
            "en": (title: "Planned Spending, Next 30 Days", detail: "This is a preview only. Viewing it creates no transactions; subscriptions follow their own billing settings", locked: "Unlock planned spending preview", total: "CNY expected total", excludedOnly: "2 planned payment(s) use another currency and are excluded from the CNY expected total", showingNearest: "5 planned payments; showing the next 3"),
            "zh-Hant": (title: "未來 30 天計畫支出", detail: "此卡僅用於預覽，不會因查看而建立交易；訂閱仍依各自設定執行", locked: "解鎖計畫支出預覽", total: "CNY 預計合計", excludedOnly: "未來 30 天有 2 筆其他幣種計畫支出，未計入 CNY 預計合計", showingNearest: "共 5 筆計畫支出，顯示最近 3 筆"),
            "ja": (title: "今後30日間の予定支出", detail: "このカードはプレビュー専用です。表示しても取引は作成されず、サブスクリプションは各設定どおりに処理されます", locked: "予定支出プレビューをアンロック", total: "CNY の予定合計", excludedOnly: "今後30日間の他通貨による予定支出2件は、CNYの予定合計に含まれていません", showingNearest: "予定支出は5件。直近3件を表示しています")
        ]

        for (language, expected) in expectedValues {
            let locale = Locale(identifier: language)
            XCTAssertEqual(NumiLocalized.lookup("plans.forecast.title", locale: locale), expected.title)
            XCTAssertEqual(NumiLocalized.lookup("plans.forecast.detail", locale: locale), expected.detail)
            XCTAssertEqual(NumiLocalized.lookup("plans.forecast.locked", locale: locale), expected.locked)
            XCTAssertEqual(NumiLocalized.format("plans.forecast.total", arguments: ["CNY"], locale: locale), expected.total)
            XCTAssertEqual(NumiLocalized.format("plans.forecast.excluded.only", arguments: [Int64(2), "CNY"], locale: locale), expected.excludedOnly)
            XCTAssertEqual(NumiLocalized.format("plans.forecast.showing.nearest", arguments: [Int64(5), Int64(3)], locale: locale), expected.showingNearest)
        }
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
