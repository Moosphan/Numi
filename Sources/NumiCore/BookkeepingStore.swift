import Foundation

public enum CategoryKind: String, Codable, Sendable {
    case expense
    case income
}

public struct Ledger: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var builtInKey: String?
    public var currencyCode: String

    public init(id: UUID = UUID(), name: String, builtInKey: String? = nil, currencyCode: String) {
        self.id = id
        self.name = name
        self.builtInKey = builtInKey
        self.currencyCode = currencyCode.uppercased()
    }
}

public struct Category: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var kind: CategoryKind
    public var name: String
    public var builtInKey: String?
    public var icon: String
    public var isHidden: Bool
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        kind: CategoryKind,
        name: String,
        builtInKey: String? = nil,
        icon: String,
        isHidden: Bool = false,
        sortOrder: Int
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.builtInKey = builtInKey
        self.icon = icon
        self.isHidden = isHidden
        self.sortOrder = sortOrder
    }
}

public enum AccountType: String, Codable, Sendable {
    case cash
    case debitCard
    case creditCard
    case wechat
    case alipay
    case virtual
    case liability
    case other
}

public struct Account: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var builtInKey: String?
    public var type: AccountType
    public var balance: Money
    public var isIncludedInAssets: Bool
    public var isHidden: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        builtInKey: String? = nil,
        type: AccountType,
        balance: Money,
        isIncludedInAssets: Bool = true,
        isHidden: Bool = false
    ) {
        self.id = id
        self.name = name
        self.builtInKey = builtInKey
        self.type = type
        self.balance = balance
        self.isIncludedInAssets = isIncludedInAssets
        self.isHidden = isHidden
    }
}

public struct BookkeepingSnapshot: Codable, Equatable, Sendable {
    public var ledgers: [Ledger]
    public var categories: [Category]
    public var accounts: [Account]
    public var transactions: [Transaction]
    public var budgetSettings: [BudgetSetting]
    public var subscriptions: [Subscription]
    public var installmentPlans: [InstallmentPlan]
    public var installmentPeriods: [InstallmentPeriod]
    public let exportedAt: Date

    public init(
        ledgers: [Ledger] = [],
        categories: [Category] = [],
        accounts: [Account] = [],
        transactions: [Transaction] = [],
        budgetSettings: [BudgetSetting] = [],
        subscriptions: [Subscription] = [],
        installmentPlans: [InstallmentPlan] = [],
        installmentPeriods: [InstallmentPeriod] = [],
        exportedAt: Date = Date()
    ) {
        self.ledgers = ledgers
        self.categories = categories
        self.accounts = accounts
        self.transactions = transactions
        self.budgetSettings = budgetSettings
        self.subscriptions = subscriptions
        self.installmentPlans = installmentPlans
        self.installmentPeriods = installmentPeriods
        self.exportedAt = exportedAt
    }
}

public final class InMemoryBookkeepingStore {
    public private(set) var ledgers: [Ledger] = []
    public private(set) var categories: [Category] = []
    public private(set) var accounts: [Account] = []
    public private(set) var transactions: [Transaction] = []
    private var deletedTransactionIDs: Set<UUID> = []

    public init() {}

    public var visibleTransactions: [Transaction] {
        transactions.filter { !deletedTransactionIDs.contains($0.id) }
    }

    public func seedDefaultsIfNeeded(currencyCode: String = "CNY") throws {
        guard ledgers.isEmpty, categories.isEmpty, accounts.isEmpty else { return }

        ledgers = [Ledger(name: NumiLocalized.string( "ledger.default.name"), builtInKey: NumiBuiltInCatalog.defaultLedgerKey, currencyCode: currencyCode)]
        categories = Self.defaultExpenseCategories().enumerated().map { index, item in
            Category(kind: .expense, name: item.name, builtInKey: item.key, icon: item.icon, sortOrder: index)
        } + Self.defaultIncomeCategories().enumerated().map { index, item in
            Category(kind: .income, name: item.name, builtInKey: item.key, icon: item.icon, sortOrder: index)
        }
        accounts = [
            Account(name: NumiLocalized.string( "account.default.cash"), builtInKey: "account.default.cash", type: .cash, balance: .zero(currencyCode: currencyCode)),
            Account(name: NumiLocalized.string( "account.default.bankCard"), builtInKey: "account.default.bankCard", type: .debitCard, balance: .zero(currencyCode: currencyCode))
        ]
    }

    @discardableResult
    public func createAccount(
        name: String,
        type: AccountType,
        balance: Money,
        isIncludedInAssets: Bool = true,
        isHidden: Bool = false
    ) throws -> Account {
        let account = Account(
            name: name,
            type: type,
            balance: balance,
            isIncludedInAssets: isIncludedInAssets,
            isHidden: isHidden
        )
        accounts.append(account)
        return account
    }

    @discardableResult
    public func createTransaction(
        type: TransactionType,
        amount: Money,
        categoryID: UUID?,
        accountID: UUID,
        targetAccountID: UUID? = nil,
        ledgerID: UUID,
        note: String,
        occurredAt: Date = Date()
    ) throws -> Transaction {
        let transaction = Transaction(
            type: type,
            amount: amount,
            occurredAt: occurredAt,
            categoryID: categoryID,
            accountID: accountID,
            targetAccountID: targetAccountID,
            ledgerID: ledgerID,
            note: note
        )
        transactions.append(transaction)
        try applyBalanceEffect(of: transaction)
        return transaction
    }

    public func transactions(for ledgerID: UUID) -> [Transaction] {
        visibleTransactions.filter { $0.ledgerID == ledgerID }
    }

    public func softDeleteTransaction(id: UUID) throws {
        guard let transaction = transactions.first(where: { $0.id == id }),
              !deletedTransactionIDs.contains(id)
        else { return }
        deletedTransactionIDs.insert(id)
        try reverseBalanceEffect(of: transaction)
    }

    public func restoreTransaction(id: UUID) throws {
        guard let transaction = transactions.first(where: { $0.id == id }),
              deletedTransactionIDs.contains(id)
        else { return }
        deletedTransactionIDs.remove(id)
        try applyBalanceEffect(of: transaction)
    }

    public func snapshot() -> BookkeepingSnapshot {
        BookkeepingSnapshot(
            ledgers: ledgers,
            categories: categories,
            accounts: accounts,
            transactions: visibleTransactions
        )
    }

    private func applyBalanceEffect(of transaction: Transaction) throws {
        switch transaction.type {
        case .expense:
            guard let accountID = transaction.accountID,
                  let index = accounts.firstIndex(where: { $0.id == accountID })
            else { return }
            accounts[index].balance = try accounts[index].balance.subtracting(transaction.amount)
        case .income:
            guard let accountID = transaction.accountID,
                  let index = accounts.firstIndex(where: { $0.id == accountID })
            else { return }
            accounts[index].balance = try accounts[index].balance.adding(transaction.amount)
        case .transfer:
            guard let sourceID = transaction.accountID,
                  let targetID = transaction.targetAccountID,
                  let sourceIndex = accounts.firstIndex(where: { $0.id == sourceID }),
                  let targetIndex = accounts.firstIndex(where: { $0.id == targetID })
            else { return }
            accounts[sourceIndex].balance = try accounts[sourceIndex].balance.subtracting(transaction.amount)
            accounts[targetIndex].balance = try accounts[targetIndex].balance.adding(transaction.amount)
        }
    }

    private func reverseBalanceEffect(of transaction: Transaction) throws {
        switch transaction.type {
        case .expense:
            guard let accountID = transaction.accountID,
                  let index = accounts.firstIndex(where: { $0.id == accountID })
            else { return }
            accounts[index].balance = try accounts[index].balance.adding(transaction.amount)
        case .income:
            guard let accountID = transaction.accountID,
                  let index = accounts.firstIndex(where: { $0.id == accountID })
            else { return }
            accounts[index].balance = try accounts[index].balance.subtracting(transaction.amount)
        case .transfer:
            guard let sourceID = transaction.accountID,
                  let targetID = transaction.targetAccountID,
                  let sourceIndex = accounts.firstIndex(where: { $0.id == sourceID }),
                  let targetIndex = accounts.firstIndex(where: { $0.id == targetID })
            else { return }
            accounts[sourceIndex].balance = try accounts[sourceIndex].balance.adding(transaction.amount)
            accounts[targetIndex].balance = try accounts[targetIndex].balance.subtracting(transaction.amount)
        }
    }

    private static func defaultExpenseCategories() -> [(key: String, name: String, icon: String)] {
        NumiBuiltInCatalog.defaultExpenseCategories.map { item in
            (key: item.key, name: NumiLocalized.string(item.key), icon: item.icon)
        }
    }

    private static func defaultIncomeCategories() -> [(key: String, name: String, icon: String)] {
        NumiBuiltInCatalog.defaultIncomeCategories.map { item in
            (key: item.key, name: NumiLocalized.string(item.key), icon: item.icon)
        }
    }
}
