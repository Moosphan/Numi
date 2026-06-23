import Foundation
import NumiCore

public enum DemoDataProfile: String, CaseIterable, Sendable {
    case empty
    case showcase
    case screenshotShowcase = "screenshot_showcase"
    case plansFocus = "plans_focus"
}

@MainActor
public enum DemoDataSeeder {
    public static func seed(
        profile: DemoDataProfile,
        into store: SwiftDataBookkeepingStore,
        resetBeforeSeeding: Bool
    ) throws {
        if resetBeforeSeeding {
            try store.resetAllData()
        }

        try store.seedDefaultsIfNeeded()

        switch profile {
        case .empty:
            return
        case .showcase:
            if isAlreadySeeded(store, marker: showcaseMarker) { return }
            try seedShowcase(into: store)
        case .screenshotShowcase:
            if isAlreadySeeded(store, marker: screenshotMarker) { return }
            try seedScreenshotShowcase(into: store)
        case .plansFocus:
            if isAlreadySeeded(store, marker: plansMarker) { return }
            try seedPlansFocus(into: store)
        }
    }

    public static func profile(from environment: [String: String]) -> DemoDataProfile? {
        guard let rawValue = environment["NUMI_SEED_PROFILE"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return nil
        }
        return DemoDataProfile(rawValue: rawValue)
    }

    public static func shouldReset(from environment: [String: String]) -> Bool {
        let rawValue = environment["NUMI_SEED_RESET"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return rawValue == "1" || rawValue == "true" || rawValue == "yes"
    }

    private static let showcaseMarker = "__numi_demo_showcase__"
    private static let screenshotMarker = "__numi_demo_screenshot_showcase__"
    private static let plansMarker = "__numi_demo_plans_focus__"

    private static func seedShowcase(into store: SwiftDataBookkeepingStore) throws {
        guard let ledgerID = store.defaultLedger()?.id else { return }
        let cash = try account(named: "现金", in: store)
        let bank = try account(named: "银行卡", in: store)
        let food = try category(named: "餐饮", in: store)
        let transport = try category(named: "交通", in: store)
        let shopping = try category(named: "购物", in: store)
        let housing = try category(named: "住房", in: store)
        let subscription = try category(named: "订阅", in: store)
        let salary = try category(named: "工资", in: store)
        let refund = try category(named: "退款", in: store)
        let sideJob = try category(named: "副业", in: store)

        let card = try store.updateAccount(
            id: bank.id,
            name: "招商银行卡",
            type: .debitCard,
            balance: Money(decimalString: "6480.25", currencyCode: "CNY"),
            isIncludedInAssets: true,
            isHidden: false
        )
        let alipay = try store.createAccount(
            name: "支付宝",
            type: .alipay,
            balance: Money(decimalString: "1320.60", currencyCode: "CNY"),
            isIncludedInAssets: true,
            isHidden: false
        )
        let wechat = try store.createAccount(
            name: "微信钱包",
            type: .wechat,
            balance: Money(decimalString: "486.20", currencyCode: "CNY"),
            isIncludedInAssets: true,
            isHidden: false
        )
        let credit = try store.createAccount(
            name: "招商信用卡",
            type: .creditCard,
            balance: Money(decimalString: "-1688.40", currencyCode: "CNY"),
            isIncludedInAssets: false,
            isHidden: false
        )

        let now = Date()
        try createExpense(store, amount: "18.00", categoryID: food.id, accountID: cash.id, ledgerID: ledgerID, note: "早餐 豆浆油条", daysAgo: 0, now: now)
        try createExpense(store, amount: "32.00", categoryID: food.id, accountID: card.id, ledgerID: ledgerID, note: "午餐 轻食沙拉", daysAgo: 0, now: now)
        try createExpense(store, amount: "24.50", categoryID: food.id, accountID: alipay.id, ledgerID: ledgerID, note: "下午咖啡", daysAgo: 1, now: now)
        try createExpense(store, amount: "14.00", categoryID: transport.id, accountID: wechat.id, ledgerID: ledgerID, note: "地铁通勤", daysAgo: 1, now: now)
        try createExpense(store, amount: "399.00", categoryID: shopping.id, accountID: card.id, ledgerID: ledgerID, note: "收纳补货", daysAgo: 2, now: now)
        try createExpense(store, amount: "980.00", categoryID: housing.id, accountID: bank.id, ledgerID: ledgerID, note: "房租分摊", daysAgo: 4, now: now)
        try createExpense(store, amount: "68.00", categoryID: subscription.id, accountID: credit.id, ledgerID: ledgerID, note: "iCloud+ 年费分摊", daysAgo: 5, now: now)

        try createIncome(store, amount: "9200.00", categoryID: salary.id, accountID: card.id, ledgerID: ledgerID, note: "六月工资", daysAgo: 8, now: now)
        try createIncome(store, amount: "600.00", categoryID: sideJob.id, accountID: alipay.id, ledgerID: ledgerID, note: "周末拍摄", daysAgo: 6, now: now)
        try createIncome(store, amount: "88.00", categoryID: refund.id, accountID: wechat.id, ledgerID: ledgerID, note: "外卖退款", daysAgo: 3, now: now)

        _ = try store.createTransaction(
            type: .transfer,
            amount: Money(decimalString: "2000.00", currencyCode: "CNY"),
            categoryID: nil,
            accountID: card.id,
            targetAccountID: alipay.id,
            ledgerID: ledgerID,
            note: "月初转入日常消费",
            occurredAt: offsetDate(now, daysAgo: 7)
        )

        try store.upsertBudgetSetting(
            period: .week,
            amount: Money(decimalString: "500.00", currencyCode: "CNY"),
            isEnabled: true,
            ledgerID: ledgerID
        )
        try store.upsertBudgetSetting(
            period: .month,
            amount: Money(decimalString: "4800.00", currencyCode: "CNY"),
            isEnabled: true,
            ledgerID: ledgerID
        )

        try createMarkerTransaction(store, accountID: cash.id, ledgerID: ledgerID, note: showcaseMarker, now: now)
    }

    private static func seedPlansFocus(into store: SwiftDataBookkeepingStore) throws {
        guard let ledgerID = store.defaultLedger()?.id else { return }
        let bank = try account(named: "银行卡", in: store)
        let food = try category(named: "餐饮", in: store)
        let shopping = try category(named: "购物", in: store)
        let transport = try category(named: "交通", in: store)
        let salary = try category(named: "工资", in: store)

        let now = Date()
        try createIncome(store, amount: "8600.00", categoryID: salary.id, accountID: bank.id, ledgerID: ledgerID, note: "月收入", daysAgo: 9, now: now)
        try createExpense(store, amount: "980.00", categoryID: food.id, accountID: bank.id, ledgerID: ledgerID, note: "餐饮累计", daysAgo: 1, now: now)
        try createExpense(store, amount: "1280.00", categoryID: shopping.id, accountID: bank.id, ledgerID: ledgerID, note: "家居采购", daysAgo: 2, now: now)
        try createExpense(store, amount: "360.00", categoryID: transport.id, accountID: bank.id, ledgerID: ledgerID, note: "打车与通勤", daysAgo: 3, now: now)

        try store.upsertBudgetSetting(
            period: .week,
            amount: Money(decimalString: "350.00", currencyCode: "CNY"),
            isEnabled: true,
            ledgerID: ledgerID
        )
        try store.upsertBudgetSetting(
            period: .month,
            amount: Money(decimalString: "2400.00", currencyCode: "CNY"),
            isEnabled: true,
            ledgerID: ledgerID
        )

        try createMarkerTransaction(store, accountID: bank.id, ledgerID: ledgerID, note: plansMarker, now: now)
    }

    private static func seedScreenshotShowcase(into store: SwiftDataBookkeepingStore) throws {
        guard let ledgerID = store.defaultLedger()?.id else { return }
        let cash = try account(named: "现金", in: store)
        let bank = try account(named: "银行卡", in: store)
        let food = try category(named: "餐饮", in: store)
        let transport = try category(named: "交通", in: store)
        let shopping = try category(named: "购物", in: store)
        let entertainment = try category(named: "娱乐", in: store)
        let housing = try category(named: "住房", in: store)
        let salary = try category(named: "工资", in: store)
        let sideJob = try category(named: "副业", in: store)
        let refund = try category(named: "退款", in: store)

        let mainBank = try store.updateAccount(
            id: bank.id,
            name: "招商银行卡",
            type: .debitCard,
            balance: Money(decimalString: "12580.90", currencyCode: "CNY"),
            isIncludedInAssets: true,
            isHidden: false
        )
        let alipay = try store.createAccount(
            name: "支付宝",
            type: .alipay,
            balance: Money(decimalString: "1680.80", currencyCode: "CNY"),
            isIncludedInAssets: true,
            isHidden: false
        )
        let wechat = try store.createAccount(
            name: "微信钱包",
            type: .wechat,
            balance: Money(decimalString: "860.30", currencyCode: "CNY"),
            isIncludedInAssets: true,
            isHidden: false
        )
        let emergency = try store.createAccount(
            name: "应急金",
            type: .virtual,
            balance: Money(decimalString: "5000.00", currencyCode: "CNY"),
            isIncludedInAssets: true,
            isHidden: false
        )
        let credit = try store.createAccount(
            name: "招商信用卡",
            type: .creditCard,
            balance: Money(decimalString: "-920.50", currencyCode: "CNY"),
            isIncludedInAssets: false,
            isHidden: false
        )

        let now = Date()
        try createExpense(store, amount: "28.00", categoryID: food.id, accountID: cash.id, ledgerID: ledgerID, note: "早餐 三明治和美式", daysAgo: 0, now: now)
        try createExpense(store, amount: "76.50", categoryID: food.id, accountID: alipay.id, ledgerID: ledgerID, note: "团队午餐", daysAgo: 1, now: now)
        try createExpense(store, amount: "32.00", categoryID: food.id, accountID: wechat.id, ledgerID: ledgerID, note: "夜间水果补给", daysAgo: 3, now: now)
        try createExpense(store, amount: "46.00", categoryID: transport.id, accountID: wechat.id, ledgerID: ledgerID, note: "周内通勤", daysAgo: 2, now: now)
        try createExpense(store, amount: "410.00", categoryID: shopping.id, accountID: credit.id, ledgerID: ledgerID, note: "书桌收纳整理", daysAgo: 4, now: now)
        try createExpense(store, amount: "114.00", categoryID: entertainment.id, accountID: alipay.id, ledgerID: ledgerID, note: "周末市集和展览", daysAgo: 5, now: now)
        try createExpense(store, amount: "960.00", categoryID: housing.id, accountID: mainBank.id, ledgerID: ledgerID, note: "本月房租分摊", daysAgo: 7, now: now)
        try createExpense(store, amount: "1400.00", categoryID: shopping.id, accountID: mainBank.id, ledgerID: ledgerID, note: "年度设备维护", daysAgo: 9, now: now)

        try createIncome(store, amount: "9800.00", categoryID: salary.id, accountID: mainBank.id, ledgerID: ledgerID, note: "六月工资", daysAgo: 10, now: now)
        try createIncome(store, amount: "1580.00", categoryID: sideJob.id, accountID: alipay.id, ledgerID: ledgerID, note: "品牌插画项目", daysAgo: 6, now: now)
        try createIncome(store, amount: "350.00", categoryID: refund.id, accountID: wechat.id, ledgerID: ledgerID, note: "差旅报销", daysAgo: 2, now: now)

        _ = try store.createTransaction(
            type: .transfer,
            amount: Money(decimalString: "1500.00", currencyCode: "CNY"),
            categoryID: nil,
            accountID: mainBank.id,
            targetAccountID: emergency.id,
            ledgerID: ledgerID,
            note: "月初储蓄分配",
            occurredAt: offsetDate(now, daysAgo: 8)
        )
        _ = try store.createTransaction(
            type: .transfer,
            amount: Money(decimalString: "600.00", currencyCode: "CNY"),
            categoryID: nil,
            accountID: mainBank.id,
            targetAccountID: alipay.id,
            ledgerID: ledgerID,
            note: "补充日常开销",
            occurredAt: offsetDate(now, daysAgo: 1)
        )

        try store.upsertBudgetSetting(
            period: .week,
            amount: Money(decimalString: "850.00", currencyCode: "CNY"),
            isEnabled: true,
            ledgerID: ledgerID
        )
        try store.upsertBudgetSetting(
            period: .month,
            amount: Money(decimalString: "5200.00", currencyCode: "CNY"),
            isEnabled: true,
            ledgerID: ledgerID
        )

        try createMarkerTransaction(store, accountID: cash.id, ledgerID: ledgerID, note: screenshotMarker, now: now)
    }

    private static func isAlreadySeeded(_ store: SwiftDataBookkeepingStore, marker: String) -> Bool {
        store.allTransactions.contains { $0.note == marker }
    }

    private static func account(named name: String, in store: SwiftDataBookkeepingStore) throws -> Account {
        guard let account = store.accounts.first(where: { $0.name == name }) else {
            throw DemoDataSeederError.missingAccount(name)
        }
        return account
    }

    private static func category(named name: String, in store: SwiftDataBookkeepingStore) throws -> NumiCore.Category {
        guard let category = store.categories.first(where: { $0.name == name }) else {
            throw DemoDataSeederError.missingCategory(name)
        }
        return category
    }

    private static func createExpense(
        _ store: SwiftDataBookkeepingStore,
        amount: String,
        categoryID: UUID,
        accountID: UUID,
        ledgerID: UUID,
        note: String,
        daysAgo: Int,
        now: Date
    ) throws {
        _ = try store.createTransaction(
            type: .expense,
            amount: Money(decimalString: amount, currencyCode: "CNY"),
            categoryID: categoryID,
            accountID: accountID,
            ledgerID: ledgerID,
            note: note,
            occurredAt: offsetDate(now, daysAgo: daysAgo)
        )
    }

    private static func createIncome(
        _ store: SwiftDataBookkeepingStore,
        amount: String,
        categoryID: UUID,
        accountID: UUID,
        ledgerID: UUID,
        note: String,
        daysAgo: Int,
        now: Date
    ) throws {
        _ = try store.createTransaction(
            type: .income,
            amount: Money(decimalString: amount, currencyCode: "CNY"),
            categoryID: categoryID,
            accountID: accountID,
            ledgerID: ledgerID,
            note: note,
            occurredAt: offsetDate(now, daysAgo: daysAgo)
        )
    }

    private static func createMarkerTransaction(
        _ store: SwiftDataBookkeepingStore,
        accountID: UUID,
        ledgerID: UUID,
        note: String,
        now: Date
    ) throws {
        let marker = try store.createTransaction(
            type: .income,
            amount: Money(decimalString: "0.01", currencyCode: "CNY"),
            categoryID: nil,
            accountID: accountID,
            ledgerID: ledgerID,
            note: note,
            occurredAt: offsetDate(now, daysAgo: 20)
        )
        try store.softDeleteTransaction(id: marker.id)
    }

    private static func offsetDate(_ base: Date, daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: base) ?? base
    }
}

public enum DemoDataSeederError: Error, Equatable {
    case missingAccount(String)
    case missingCategory(String)
}
