import Foundation

public enum NumiBuiltInCatalog {
    public static let supportedLanguageCodes = ["zh-Hans", "en", "zh-Hant", "ja"]

    public static let defaultLedgerKey = "ledger.default.name"

    public static let defaultAccountKeysByType: [AccountType: String] = [
        .cash: "account.default.cash",
        .debitCard: "account.default.bankCard"
    ]

    public static let defaultExpenseCategories: [(key: String, icon: String)] = [
        ("category.default.expense.dining", "acai-bowl"),
        ("category.default.expense.transport", "articulated-bus"),
        ("category.default.expense.shopping", "bag-of-groceries"),
        ("category.default.expense.housing", "apartment-building"),
        ("category.default.expense.utilities", "digital-billboard"),
        ("category.default.expense.telecom", "cell-phone-cleaning-kit"),
        ("category.default.expense.medical", "medicine-capsule"),
        ("category.default.expense.sports", "ab-bench"),
        ("category.default.expense.education", "book"),
        ("category.default.expense.entertainment", "cinema-clapperboard"),
        ("category.default.expense.travel", "airplane"),
        ("category.default.expense.gaming", "game-controller"),
        ("category.default.expense.digital", "desktop-computer"),
        ("category.default.expense.beauty", "lipstick"),
        ("category.default.expense.clothing", "button-down-shirt"),
        ("category.default.expense.haircut", "barber"),
        ("category.default.expense.gifts", "gift-box"),
        ("category.default.expense.children", "baby"),
        ("category.default.expense.pets", "cat"),
        ("category.default.expense.home", "armchair"),
        ("category.default.expense.repair", "computer-technician"),
        ("category.default.expense.office", "desk"),
        ("category.default.expense.insurance", "insurance"),
        ("category.default.expense.tax", "cash-register"),
        ("category.default.expense.charity", "charity-ball"),
        ("category.default.expense.subscription", "digital-certificate"),
        ("category.default.expense.vehicle", "black-car"),
        ("category.default.expense.other", "coins")
    ]

    public static let defaultIncomeCategories: [(key: String, icon: String)] = [
        ("category.default.income.salary", "cash"),
        ("category.default.income.bonus", "trophy"),
        ("category.default.income.overtime", "digital-alarm-clock"),
        ("category.default.income.investment", "stock-trading-candlestick"),
        ("category.default.income.interest", "coin-jar"),
        ("category.default.income.rental", "farmhouse"),
        ("category.default.income.sidejob", "briefcase"),
        ("category.default.income.creative", "calligraphy-practice-book"),
        ("category.default.income.consulting", "accountant"),
        ("category.default.income.reimbursement", "checkbook"),
        ("category.default.income.refund", "atm-cash-machine"),
        ("category.default.income.claim", "health-insurance-card"),
        ("category.default.income.giftmoney", "unboxing-gift"),
        ("category.default.income.prize", "bingo-ball"),
        ("category.default.income.loanRepaid", "coin-purse"),
        ("category.default.income.resale", "flea-market"),
        ("category.default.income.subsidy", "award-ceremony"),
        ("category.default.income.inheritance", "golden-heart"),
        ("category.default.income.other", "money")
    ]

    public static func localizedLedgerName(_ name: String) -> String {
        localizedLedgerName(name, builtInKey: nil)
    }

    public static func localizedLedgerName(_ name: String, builtInKey: String?) -> String {
        guard let key = builtInKey ?? builtInLedgerKey(name: name) else { return name }
        return NumiLocalized.lookup(key)
    }

    public static func localizedAccountName(name: String, type: AccountType) -> String {
        localizedAccountName(name: name, builtInKey: nil, type: type)
    }

    public static func localizedAccountName(name: String, builtInKey: String?, type: AccountType) -> String {
        guard let key = builtInKey ?? builtInAccountKey(name: name, type: type) else { return name }
        return NumiLocalized.lookup(key)
    }

    public static func localizedCategoryName(name: String, icon: String) -> String {
        localizedCategoryName(name: name, builtInKey: nil, icon: icon)
    }

    public static func localizedCategoryName(name: String, builtInKey: String?, icon: String) -> String {
        guard let key = builtInKey ?? builtInCategoryKey(name: name, icon: icon) else { return name }
        return NumiLocalized.lookup(key)
    }

    public static func isBuiltInLedgerName(_ name: String) -> Bool {
        builtInLedgerKey(name: name) != nil
    }

    public static func isBuiltInAccountName(_ name: String, type: AccountType) -> Bool {
        builtInAccountKey(name: name, type: type) != nil
    }

    public static func isBuiltInCategoryName(_ name: String, icon: String) -> Bool {
        builtInCategoryKey(name: name, icon: icon) != nil
    }

    public static func builtInLedgerKey(name: String) -> String? {
        isBuiltInName(name, for: defaultLedgerKey) ? defaultLedgerKey : nil
    }

    public static func builtInAccountKey(name: String, type: AccountType) -> String? {
        guard let key = defaultAccountKeysByType[type], isBuiltInName(name, for: key) else {
            return nil
        }
        return key
    }

    public static func builtInCategoryKey(name: String, icon: String) -> String? {
        guard let key = (defaultExpenseCategories + defaultIncomeCategories).first(where: { $0.icon == icon })?.key,
              isBuiltInName(name, for: key) else {
            return nil
        }
        return key
    }

    public static func isBuiltInName(_ name: String, for key: String) -> Bool {
        matchesBuiltInName(name, key: key)
    }

    private static func matchesBuiltInName(_ name: String, key: String) -> Bool {
        supportedLanguageCodes
            .map { NumiLocalized.lookup(key, locale: Locale(identifier: $0)) }
            .contains(name)
    }
}

public extension Category {
    var localizedDisplayName: String {
        NumiBuiltInCatalog.localizedCategoryName(name: name, builtInKey: builtInKey, icon: icon)
    }
}

public extension Account {
    var localizedDisplayName: String {
        NumiBuiltInCatalog.localizedAccountName(name: name, builtInKey: builtInKey, type: type)
    }
}

public extension Ledger {
    var localizedDisplayName: String {
        NumiBuiltInCatalog.localizedLedgerName(name, builtInKey: builtInKey)
    }
}
