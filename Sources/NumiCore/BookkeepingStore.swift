import Foundation

public enum CategoryKind: String, Codable, Sendable {
    case expense
    case income
}

public struct Ledger: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var currencyCode: String

    public init(id: UUID = UUID(), name: String, currencyCode: String) {
        self.id = id
        self.name = name
        self.currencyCode = currencyCode.uppercased()
    }
}

public struct Category: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var kind: CategoryKind
    public var name: String
    public var icon: String
    public var isHidden: Bool
    public var sortOrder: Int

    public init(id: UUID = UUID(), kind: CategoryKind, name: String, icon: String, isHidden: Bool = false, sortOrder: Int) {
        self.id = id
        self.kind = kind
        self.name = name
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
    public var type: AccountType
    public var balance: Money
    public var isIncludedInAssets: Bool
    public var isHidden: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        balance: Money,
        isIncludedInAssets: Bool = true,
        isHidden: Bool = false
    ) {
        self.id = id
        self.name = name
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

    public init(ledgers: [Ledger], categories: [Category], accounts: [Account], transactions: [Transaction]) {
        self.ledgers = ledgers
        self.categories = categories
        self.accounts = accounts
        self.transactions = transactions
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

        ledgers = [Ledger(name: "默认账本", currencyCode: currencyCode)]
        categories = Self.defaultExpenseCategories.enumerated().map { index, item in
            Category(kind: .expense, name: item.name, icon: item.icon, sortOrder: index)
        } + Self.defaultIncomeCategories.enumerated().map { index, item in
            Category(kind: .income, name: item.name, icon: item.icon, sortOrder: index)
        }
        accounts = [
            Account(name: "现金", type: .cash, balance: .zero(currencyCode: currencyCode)),
            Account(name: "银行卡", type: .debitCard, balance: .zero(currencyCode: currencyCode))
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
            note: note
        )
        transactions.append(transaction)
        try applyBalanceEffect(of: transaction)
        return transaction
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

    private static let defaultExpenseCategories: [(name: String, icon: String)] = [
        ("餐饮", "fork.knife"),
        ("交通", "bus"),
        ("购物", "bag"),
        ("日用品", "shippingbox"),
        ("住房", "house"),
        ("医疗", "cross.case"),
        ("娱乐", "party.popper"),
        ("学习", "book"),
        ("数码", "iphone"),
        ("旅行", "airplane"),
        ("人情", "gift"),
        ("宠物", "pawprint"),
        ("运动", "figure.run"),
        ("美容", "sparkles"),
        ("订阅", "repeat"),
        ("其他", "ellipsis.circle")
    ]

    private static let defaultIncomeCategories: [(name: String, icon: String)] = [
        ("工资", "banknote"),
        ("副业", "briefcase"),
        ("奖金", "trophy"),
        ("报销", "doc.text"),
        ("退款", "arrow.uturn.backward"),
        ("投资收益", "chart.line.uptrend.xyaxis"),
        ("礼金", "giftcard"),
        ("其他", "ellipsis.circle")
    ]
}
