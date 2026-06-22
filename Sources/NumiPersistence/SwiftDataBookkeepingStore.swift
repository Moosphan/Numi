import Foundation
import SwiftData
import NumiCore

@Model
final class LedgerEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var currencyCode: String

    init(id: UUID, name: String, currencyCode: String) {
        self.id = id
        self.name = name
        self.currencyCode = currencyCode
    }
}

@Model
final class CategoryEntity {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var name: String
    var icon: String
    var isHidden: Bool
    var sortOrder: Int

    init(id: UUID, kind: CategoryKind, name: String, icon: String, isHidden: Bool, sortOrder: Int) {
        self.id = id
        self.kindRawValue = kind.rawValue
        self.name = name
        self.icon = icon
        self.isHidden = isHidden
        self.sortOrder = sortOrder
    }
}

@Model
final class AccountEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRawValue: String
    var balanceMinorUnits: Int64
    var currencyCode: String
    var isIncludedInAssets: Bool
    var isHidden: Bool

    init(
        id: UUID,
        name: String,
        type: AccountType,
        balance: Money,
        isIncludedInAssets: Bool,
        isHidden: Bool
    ) {
        self.id = id
        self.name = name
        self.typeRawValue = type.rawValue
        self.balanceMinorUnits = balance.minorUnits
        self.currencyCode = balance.currencyCode
        self.isIncludedInAssets = isIncludedInAssets
        self.isHidden = isHidden
    }
}

@Model
final class TransactionEntity {
    @Attribute(.unique) var id: UUID
    var typeRawValue: String
    var amountMinorUnits: Int64
    var currencyCode: String
    var occurredAt: Date
    var categoryID: UUID?
    var accountID: UUID?
    var targetAccountID: UUID?
    var note: String
    var isSoftDeleted: Bool

    init(
        id: UUID,
        type: TransactionType,
        amount: Money,
        occurredAt: Date,
        categoryID: UUID?,
        accountID: UUID?,
        targetAccountID: UUID?,
        note: String,
        isSoftDeleted: Bool
    ) {
        self.id = id
        self.typeRawValue = type.rawValue
        self.amountMinorUnits = amount.minorUnits
        self.currencyCode = amount.currencyCode
        self.occurredAt = occurredAt
        self.categoryID = categoryID
        self.accountID = accountID
        self.targetAccountID = targetAccountID
        self.note = note
        self.isSoftDeleted = isSoftDeleted
    }
}

@Model
final class BudgetSettingEntity {
    @Attribute(.unique) var id: UUID
    var periodRawValue: String
    var amountMinorUnits: Int64
    var currencyCode: String
    var isEnabled: Bool

    init(id: UUID, period: BudgetPeriod, amount: Money, isEnabled: Bool) {
        self.id = id
        self.periodRawValue = period.rawValue
        self.amountMinorUnits = amount.minorUnits
        self.currencyCode = amount.currencyCode
        self.isEnabled = isEnabled
    }
}

@Model
final class SubscriptionEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var amountMinorUnits: Int64
    var currencyCode: String
    var cycleRawValue: String
    var categoryID: UUID?
    var accountID: UUID?
    var nextBillingDate: Date
    var isEnabled: Bool
    var note: String

    init(id: UUID, name: String, amountMinorUnits: Int64, currencyCode: String, cycleRawValue: String, categoryID: UUID?, accountID: UUID?, nextBillingDate: Date, isEnabled: Bool, note: String) {
        self.id = id
        self.name = name
        self.amountMinorUnits = amountMinorUnits
        self.currencyCode = currencyCode
        self.cycleRawValue = cycleRawValue
        self.categoryID = categoryID
        self.accountID = accountID
        self.nextBillingDate = nextBillingDate
        self.isEnabled = isEnabled
        self.note = note
    }
}

@Model
final class InstallmentPlanEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var totalAmountMinorUnits: Int64
    var currencyCode: String
    var feePerPeriodMinorUnits: Int64
    var periodCount: Int
    var firstPaymentDate: Date
    var accountID: UUID?
    var categoryID: UUID?
    var note: String

    init(id: UUID, name: String, totalAmountMinorUnits: Int64, currencyCode: String, feePerPeriodMinorUnits: Int64, periodCount: Int, firstPaymentDate: Date, accountID: UUID?, categoryID: UUID?, note: String) {
        self.id = id
        self.name = name
        self.totalAmountMinorUnits = totalAmountMinorUnits
        self.currencyCode = currencyCode
        self.feePerPeriodMinorUnits = feePerPeriodMinorUnits
        self.periodCount = periodCount
        self.firstPaymentDate = firstPaymentDate
        self.accountID = accountID
        self.categoryID = categoryID
        self.note = note
    }
}

@Model
final class InstallmentPeriodEntity {
    @Attribute(.unique) var id: UUID
    var planID: UUID
    var periodIndex: Int
    var dueDate: Date
    var isRecorded: Bool
    var isPaid: Bool
    var transactionID: UUID?

    init(id: UUID, planID: UUID, periodIndex: Int, dueDate: Date, isRecorded: Bool, isPaid: Bool, transactionID: UUID?) {
        self.id = id
        self.planID = planID
        self.periodIndex = periodIndex
        self.dueDate = dueDate
        self.isRecorded = isRecorded
        self.isPaid = isPaid
        self.transactionID = transactionID
    }
}

@MainActor
public final class SwiftDataBookkeepingStore: ObservableObject {
    @Published public private(set) var changeRevision = 0

    private let container: ModelContainer
    private let context: ModelContext

    public init(inMemory: Bool = false, enableCloudSync: Bool = false) throws {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else if enableCloudSync {
            configuration = ModelConfiguration(
                "NumiCloud",
                cloudKitDatabase: .private("iCloud.com.local.Numi")
            )
        } else {
            configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        }
        self.container = try ModelContainer(
            for: LedgerEntity.self,
            CategoryEntity.self,
            AccountEntity.self,
            TransactionEntity.self,
            BudgetSettingEntity.self,
            SubscriptionEntity.self,
            InstallmentPlanEntity.self,
            InstallmentPeriodEntity.self,
            configurations: configuration
        )
        self.context = ModelContext(container)
    }

    public init(storeURL: URL) throws {
        let configuration = ModelConfiguration(url: storeURL)
        self.container = try ModelContainer(
            for: LedgerEntity.self,
            CategoryEntity.self,
            AccountEntity.self,
            TransactionEntity.self,
            BudgetSettingEntity.self,
            SubscriptionEntity.self,
            InstallmentPlanEntity.self,
            InstallmentPeriodEntity.self,
            configurations: configuration
        )
        self.context = ModelContext(container)
    }

    public var ledgers: [Ledger] {
        fetchLedgerEntities().map(\.domainModel)
    }

    public var categories: [NumiCore.Category] {
        fetchCategoryEntities().map(\.domainModel)
    }

    public var accounts: [Account] {
        fetchAccountEntities().map(\.domainModel)
    }

    public var visibleTransactions: [Transaction] {
        fetchTransactionEntities(includeDeleted: false).map(\.domainModel)
    }

    public var allTransactions: [Transaction] {
        fetchTransactionEntities(includeDeleted: true).map(\.domainModel)
    }

    public var budgetSettings: [BudgetSetting] {
        fetchBudgetSettingEntities().map(\.domainModel)
    }

    public func seedDefaultsIfNeeded(currencyCode: String = "CNY") throws {
        guard fetchLedgerEntities().isEmpty,
              fetchCategoryEntities().isEmpty,
              fetchAccountEntities().isEmpty
        else { return }

        context.insert(LedgerEntity(id: UUID(), name: "默认账本", currencyCode: currencyCode))
        for (index, item) in Self.defaultExpenseCategories.enumerated() {
            context.insert(CategoryEntity(id: UUID(), kind: .expense, name: item.name, icon: item.icon, isHidden: false, sortOrder: index))
        }
        for (index, item) in Self.defaultIncomeCategories.enumerated() {
            context.insert(CategoryEntity(id: UUID(), kind: .income, name: item.name, icon: item.icon, isHidden: false, sortOrder: index))
        }
        context.insert(AccountEntity(
            id: UUID(),
            name: "现金",
            type: .cash,
            balance: .zero(currencyCode: currencyCode),
            isIncludedInAssets: true,
            isHidden: false
        ))
        context.insert(AccountEntity(
            id: UUID(),
            name: "银行卡",
            type: .debitCard,
            balance: .zero(currencyCode: currencyCode),
            isIncludedInAssets: true,
            isHidden: false
        ))
        try save()
    }

    @discardableResult
    public func createCategory(
        kind: CategoryKind,
        name: String,
        icon: String,
        isHidden: Bool = false
    ) throws -> NumiCore.Category {
        let existing = fetchCategoryEntities().filter { $0.kindRawValue == kind.rawValue }
        let maxOrder = existing.map(\.sortOrder).max() ?? 0
        let entity = CategoryEntity(
            id: UUID(),
            kind: kind,
            name: name,
            icon: icon,
            isHidden: isHidden,
            sortOrder: maxOrder + 1
        )
        context.insert(entity)
        try save()
        changeRevision += 1
        objectWillChange.send()
        return entity.domainModel
    }

    public func deleteCategory(id: UUID) throws {
        guard let entity = fetchCategoryEntities().first(where: { $0.id == id }) else { return }
        context.delete(entity)
        try save()
        changeRevision += 1
        objectWillChange.send()
    }

    // MARK: - Subscriptions

    public var subscriptions: [Subscription] {
        fetchSubscriptionEntities().map(\.domainModel)
    }

    public func createSubscription(_ sub: Subscription) throws {
        let entity = SubscriptionEntity(
            id: sub.id,
            name: sub.name,
            amountMinorUnits: sub.amount.minorUnits,
            currencyCode: sub.amount.currencyCode,
            cycleRawValue: sub.cycle.rawValue,
            categoryID: sub.categoryID,
            accountID: sub.accountID,
            nextBillingDate: sub.nextBillingDate,
            isEnabled: sub.isEnabled,
            note: sub.note
        )
        context.insert(entity)
        try save()
        changeRevision += 1
        objectWillChange.send()
    }

    public func updateSubscription(_ sub: Subscription) throws {
        guard let entity = fetchSubscriptionEntities().first(where: { $0.id == sub.id }) else { return }
        entity.name = sub.name
        entity.amountMinorUnits = sub.amount.minorUnits
        entity.currencyCode = sub.amount.currencyCode
        entity.cycleRawValue = sub.cycle.rawValue
        entity.categoryID = sub.categoryID
        entity.accountID = sub.accountID
        entity.nextBillingDate = sub.nextBillingDate
        entity.isEnabled = sub.isEnabled
        entity.note = sub.note
        try save()
        changeRevision += 1
        objectWillChange.send()
    }

    public func deleteSubscription(id: UUID) throws {
        guard let entity = fetchSubscriptionEntities().first(where: { $0.id == id }) else { return }
        context.delete(entity)
        try save()
        changeRevision += 1
        objectWillChange.send()
    }

    private func fetchSubscriptionEntities() -> [SubscriptionEntity] {
        (try? context.fetch(FetchDescriptor<SubscriptionEntity>())) ?? []
    }

    // MARK: - Installment Plans

    public var installmentPlans: [InstallmentPlan] {
        fetchInstallmentPlanEntities().map(\.domainModel)
    }

    public var installmentPeriods: [InstallmentPeriod] {
        fetchInstallmentPeriodEntities().map(\.domainModel)
    }

    public func createInstallmentPlan(_ plan: InstallmentPlan) throws {
        let entity = InstallmentPlanEntity(
            id: plan.id,
            name: plan.name,
            totalAmountMinorUnits: plan.totalAmount.minorUnits,
            currencyCode: plan.totalAmount.currencyCode,
            feePerPeriodMinorUnits: plan.feePerPeriod.minorUnits,
            periodCount: plan.periodCount,
            firstPaymentDate: plan.firstPaymentDate,
            accountID: plan.accountID,
            categoryID: plan.categoryID,
            note: plan.note
        )
        context.insert(entity)

        // 自动生成每期记录
        let dueDates = plan.generateDueDates()
        for (index, date) in dueDates.enumerated() {
            let period = InstallmentPeriodEntity(
                id: UUID(),
                planID: plan.id,
                periodIndex: index,
                dueDate: date,
                isRecorded: false,
                isPaid: false,
                transactionID: nil
            )
            context.insert(period)
        }

        try save()
        changeRevision += 1
        objectWillChange.send()
    }

    public func deleteInstallmentPlan(id: UUID) throws {
        // 删除关联的期次
        let periods = fetchInstallmentPeriodEntities().filter { $0.planID == id }
        for period in periods {
            context.delete(period)
        }
        // 删除计划
        if let entity = fetchInstallmentPlanEntities().first(where: { $0.id == id }) {
            context.delete(entity)
        }
        try save()
        changeRevision += 1
        objectWillChange.send()
    }

    public func updateInstallmentPeriod(_ period: InstallmentPeriod) throws {
        guard let entity = fetchInstallmentPeriodEntities().first(where: { $0.id == period.id }) else { return }
        entity.isRecorded = period.isRecorded
        entity.isPaid = period.isPaid
        entity.transactionID = period.transactionID
        try save()
        changeRevision += 1
        objectWillChange.send()
    }

    private func fetchInstallmentPlanEntities() -> [InstallmentPlanEntity] {
        (try? context.fetch(FetchDescriptor<InstallmentPlanEntity>())) ?? []
    }

    private func fetchInstallmentPeriodEntities() -> [InstallmentPeriodEntity] {
        (try? context.fetch(FetchDescriptor<InstallmentPeriodEntity>())) ?? []
    }

    public func deleteAccount(id: UUID) throws {
        guard let entity = fetchAccountEntities().first(where: { $0.id == id }) else { return }
        context.delete(entity)
        try save()
        changeRevision += 1
        objectWillChange.send()
    }

    // MARK: - Snapshot

    public func exportSnapshot() -> BookkeepingSnapshot {
        BookkeepingSnapshot(
            ledgers: ledgers,
            categories: categories,
            accounts: accounts,
            transactions: allTransactions,
            budgetSettings: budgetSettings,
            subscriptions: subscriptions,
            installmentPlans: installmentPlans,
            installmentPeriods: installmentPeriods
        )
    }

    public func importSnapshot(_ snapshot: BookkeepingSnapshot) throws {
        // 清空现有数据
        try resetAllData()

        // 导入账本
        for ledger in snapshot.ledgers {
            let entity = LedgerEntity(id: ledger.id, name: ledger.name, currencyCode: ledger.currencyCode)
            context.insert(entity)
        }

        // 导入分类
        for cat in snapshot.categories {
            let entity = CategoryEntity(
                id: cat.id, kind: cat.kind, name: cat.name,
                icon: cat.icon, isHidden: cat.isHidden, sortOrder: cat.sortOrder
            )
            context.insert(entity)
        }

        // 导入账户
        for acc in snapshot.accounts {
            let entity = AccountEntity(
                id: acc.id, name: acc.name, type: acc.type,
                balance: acc.balance, isIncludedInAssets: acc.isIncludedInAssets,
                isHidden: acc.isHidden
            )
            context.insert(entity)
        }

        // 导入交易
        for tx in snapshot.transactions {
            let entity = TransactionEntity(
                id: tx.id, type: tx.type, amount: tx.amount,
                occurredAt: tx.occurredAt, categoryID: tx.categoryID,
                accountID: tx.accountID, targetAccountID: tx.targetAccountID,
                note: tx.note, isSoftDeleted: false
            )
            context.insert(entity)
        }

        // 导入预算
        for budget in snapshot.budgetSettings {
            let entity = BudgetSettingEntity(
                id: budget.id, period: budget.period,
                amount: budget.amount, isEnabled: budget.isEnabled
            )
            context.insert(entity)
        }

        // 导入订阅
        for sub in snapshot.subscriptions {
            let entity = SubscriptionEntity(
                id: sub.id, name: sub.name,
                amountMinorUnits: sub.amount.minorUnits,
                currencyCode: sub.amount.currencyCode,
                cycleRawValue: sub.cycle.rawValue,
                categoryID: sub.categoryID,
                accountID: sub.accountID,
                nextBillingDate: sub.nextBillingDate,
                isEnabled: sub.isEnabled,
                note: sub.note
            )
            context.insert(entity)
        }

        // 导入分期计划
        for plan in snapshot.installmentPlans {
            let entity = InstallmentPlanEntity(
                id: plan.id, name: plan.name,
                totalAmountMinorUnits: plan.totalAmount.minorUnits,
                currencyCode: plan.totalAmount.currencyCode,
                feePerPeriodMinorUnits: plan.feePerPeriod.minorUnits,
                periodCount: plan.periodCount,
                firstPaymentDate: plan.firstPaymentDate,
                accountID: plan.accountID,
                categoryID: plan.categoryID,
                note: plan.note
            )
            context.insert(entity)
        }

        // 导入分期期次
        for period in snapshot.installmentPeriods {
            let entity = InstallmentPeriodEntity(
                id: period.id, planID: period.planID,
                periodIndex: period.periodIndex, dueDate: period.dueDate,
                isRecorded: period.isRecorded, isPaid: period.isPaid,
                transactionID: period.transactionID
            )
            context.insert(entity)
        }

        try save()
        changeRevision += 1
        objectWillChange.send()
    }

    public func resetAllData() throws {
        try delete(fetchTransactionEntities(includeDeleted: true))
        try delete(fetchBudgetSettingEntities())
        try delete(fetchAccountEntities())
        try delete(fetchCategoryEntities())
        try delete(fetchLedgerEntities())
        changeRevision += 1
        objectWillChange.send()
    }

    @discardableResult
    public func createAccount(
        name: String,
        type: AccountType,
        balance: Money,
        isIncludedInAssets: Bool = true,
        isHidden: Bool = false
    ) throws -> Account {
        let account = AccountEntity(
            id: UUID(),
            name: name,
            type: type,
            balance: balance,
            isIncludedInAssets: isIncludedInAssets,
            isHidden: isHidden
        )
        context.insert(account)
        try save()
        objectWillChange.send()
        return account.domainModel
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
        let transaction = TransactionEntity(
            id: UUID(),
            type: type,
            amount: amount,
            occurredAt: occurredAt,
            categoryID: categoryID,
            accountID: accountID,
            targetAccountID: targetAccountID,
            note: note,
            isSoftDeleted: false
        )
        context.insert(transaction)
        try applyBalanceEffect(type: type, amount: amount, accountID: accountID, targetAccountID: targetAccountID)
        try save()
        objectWillChange.send()
        return transaction.domainModel
    }

    @discardableResult
    public func updateTransaction(
        id: UUID,
        type: TransactionType,
        amount: Money,
        categoryID: UUID?,
        accountID: UUID,
        targetAccountID: UUID? = nil,
        note: String,
        occurredAt: Date? = nil
    ) throws -> Transaction {
        guard let transaction = fetchTransactionEntity(id: id) else {
            throw SwiftDataBookkeepingStoreError.transactionNotFound
        }

        let oldDomain = transaction.domainModel
        let updatedDomain = Transaction(
            id: transaction.id,
            type: type,
            amount: amount,
            occurredAt: occurredAt ?? transaction.occurredAt,
            categoryID: categoryID,
            accountID: accountID,
            targetAccountID: targetAccountID,
            note: note
        )

        if !transaction.isSoftDeleted {
            try updateBalances(reversing: oldDomain, applying: updatedDomain)
        }

        transaction.typeRawValue = type.rawValue
        transaction.amountMinorUnits = amount.minorUnits
        transaction.currencyCode = amount.currencyCode
        transaction.occurredAt = occurredAt ?? transaction.occurredAt
        transaction.categoryID = categoryID
        transaction.accountID = accountID
        transaction.targetAccountID = targetAccountID
        transaction.note = note
        try save()
        objectWillChange.send()
        return transaction.domainModel
    }

    public func softDeleteTransaction(id: UUID) throws {
        guard let transaction = fetchTransactionEntity(id: id), !transaction.isSoftDeleted else { return }
        try updateBalances(reversing: transaction.domainModel, applying: nil)
        transaction.isSoftDeleted = true
        try save()
        objectWillChange.send()
    }

    public func restoreTransaction(id: UUID) throws {
        guard let transaction = fetchTransactionEntity(id: id), transaction.isSoftDeleted else { return }
        try updateBalances(reversing: nil, applying: transaction.domainModel)
        transaction.isSoftDeleted = false
        try save()
        objectWillChange.send()
    }

    @discardableResult
    public func updateCategoryVisibility(id: UUID, isHidden: Bool) throws -> NumiCore.Category {
        guard let category = fetchCategoryEntity(id: id) else {
            throw SwiftDataBookkeepingStoreError.categoryNotFound
        }

        category.isHidden = isHidden
        try save()
        changeRevision += 1
        objectWillChange.send()
        return category.domainModel
    }

    @discardableResult
    public func updateAccountVisibility(id: UUID, isHidden: Bool) throws -> Account {
        guard let account = fetchAccountEntity(id: id) else {
            throw SwiftDataBookkeepingStoreError.accountNotFound
        }

        account.isHidden = isHidden
        try save()
        changeRevision += 1
        objectWillChange.send()
        return account.domainModel
    }

    @discardableResult
    public func updateAccount(
        id: UUID,
        name: String,
        type: AccountType,
        balance: Money,
        isIncludedInAssets: Bool,
        isHidden: Bool
    ) throws -> Account {
        guard let account = fetchAccountEntity(id: id) else {
            throw SwiftDataBookkeepingStoreError.accountNotFound
        }

        account.name = name
        account.typeRawValue = type.rawValue
        account.balanceMinorUnits = balance.minorUnits
        account.currencyCode = balance.currencyCode
        account.isIncludedInAssets = isIncludedInAssets
        account.isHidden = isHidden
        try save()
        changeRevision += 1
        objectWillChange.send()
        return account.domainModel
    }

    @discardableResult
    public func upsertBudgetSetting(
        period: BudgetPeriod,
        amount: Money,
        isEnabled: Bool
    ) throws -> BudgetSetting {
        let setting: BudgetSettingEntity
        if let existing = fetchBudgetSettingEntity(period: period) {
            setting = existing
        } else {
            setting = BudgetSettingEntity(id: UUID(), period: period, amount: amount, isEnabled: isEnabled)
            context.insert(setting)
        }

        setting.periodRawValue = period.rawValue
        setting.amountMinorUnits = amount.minorUnits
        setting.currencyCode = amount.currencyCode
        setting.isEnabled = isEnabled
        try save()
        changeRevision += 1
        objectWillChange.send()
        return setting.domainModel
    }

    private func applyBalanceEffect(type: TransactionType, amount: Money, accountID: UUID, targetAccountID: UUID?) throws {
        let transaction = Transaction(type: type, amount: amount, accountID: accountID, targetAccountID: targetAccountID)
        try updateBalances(reversing: nil, applying: transaction)
    }

    private func updateBalances(reversing oldTransaction: Transaction?, applying newTransaction: Transaction?) throws {
        var balancesByAccountID: [UUID: Money] = [:]

        func balance(for accountID: UUID) throws -> Money? {
            if let balance = balancesByAccountID[accountID] {
                return balance
            }
            guard let account = fetchAccountEntity(id: accountID) else { return nil }
            let balance = Money(minorUnits: account.balanceMinorUnits, currencyCode: account.currencyCode)
            balancesByAccountID[accountID] = balance
            return balance
        }

        if let oldTransaction {
            try oldTransaction.reversalAdjustments().forEach { accountID, effect in
                guard var current = try balance(for: accountID) else { return }
                current = try effect.apply(to: current)
                balancesByAccountID[accountID] = current
            }
        }

        if let newTransaction {
            try newTransaction.balanceAdjustments().forEach { accountID, effect in
                guard var current = try balance(for: accountID) else { return }
                current = try effect.apply(to: current)
                balancesByAccountID[accountID] = current
            }
        }

        for (accountID, balance) in balancesByAccountID {
            guard let account = fetchAccountEntity(id: accountID) else { continue }
            account.balanceMinorUnits = balance.minorUnits
            account.currencyCode = balance.currencyCode
        }
    }

    private func fetchLedgerEntities() -> [LedgerEntity] {
        let descriptor = FetchDescriptor<LedgerEntity>(sortBy: [SortDescriptor(\.name)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchCategoryEntities() -> [CategoryEntity] {
        let descriptor = FetchDescriptor<CategoryEntity>(sortBy: [
            SortDescriptor(\.kindRawValue),
            SortDescriptor(\.sortOrder)
        ])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchCategoryEntity(id: UUID) -> CategoryEntity? {
        let descriptor = FetchDescriptor<CategoryEntity>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func fetchAccountEntities() -> [AccountEntity] {
        let descriptor = FetchDescriptor<AccountEntity>(sortBy: [SortDescriptor(\.name)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchTransactionEntities(includeDeleted: Bool) -> [TransactionEntity] {
        var descriptor = FetchDescriptor<TransactionEntity>(sortBy: [SortDescriptor(\.occurredAt, order: .reverse)])
        if !includeDeleted {
            descriptor.predicate = #Predicate { !$0.isSoftDeleted }
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchBudgetSettingEntities() -> [BudgetSettingEntity] {
        let descriptor = FetchDescriptor<BudgetSettingEntity>(sortBy: [SortDescriptor(\.periodRawValue)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchBudgetSettingEntity(period: BudgetPeriod) -> BudgetSettingEntity? {
        let rawValue = period.rawValue
        let descriptor = FetchDescriptor<BudgetSettingEntity>(predicate: #Predicate { $0.periodRawValue == rawValue })
        return try? context.fetch(descriptor).first
    }

    private func fetchTransactionEntity(id: UUID) -> TransactionEntity? {
        fetchTransactionEntities(includeDeleted: true).first { $0.id == id }
    }

    private func fetchAccountEntity(id: UUID) -> AccountEntity? {
        let descriptor = FetchDescriptor<AccountEntity>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    private func delete<T: PersistentModel>(_ models: [T]) throws {
        for model in models {
            context.delete(model)
        }
        try save()
    }

    private static let defaultExpenseCategories: [(name: String, icon: String)] = [
        ("餐饮", "acai-bowl"),
        ("交通", "articulated-bus"),
        ("购物", "bag-of-groceries"),
        ("住房", "apartment-building"),
        ("水电燃气", "digital-billboard"),
        ("通讯", "cell-phone-cleaning-kit"),
        ("医疗", "medicine-capsule"),
        ("运动", "ab-bench"),
        ("学习", "book"),
        ("娱乐", "cinema-clapperboard"),
        ("旅行", "airplane"),
        ("游戏", "game-controller"),
        ("数码", "desktop-computer"),
        ("美容", "lipstick"),
        ("服饰", "button-down-shirt"),
        ("美发", "barber"),
        ("人情", "gift-box"),
        ("育儿", "baby"),
        ("宠物", "cat"),
        ("家居", "armchair"),
        ("维修", "computer-technician"),
        ("办公", "desk"),
        ("保险", "insurance"),
        ("税费", "cash-register"),
        ("慈善", "charity-ball"),
        ("订阅", "digital-certificate"),
        ("车辆", "black-car"),
        ("其他", "coins")
    ]

    private static let defaultIncomeCategories: [(name: String, icon: String)] = [
        ("工资", "cash"),
        ("奖金", "trophy"),
        ("加班补贴", "digital-alarm-clock"),
        ("投资收益", "stock-trading-candlestick"),
        ("利息分红", "coin-jar"),
        ("租金收入", "farmhouse"),
        ("副业", "briefcase"),
        ("创作稿费", "calligraphy-practice-book"),
        ("咨询服务", "accountant"),
        ("报销", "checkbook"),
        ("退款", "atm-cash-machine"),
        ("赔偿理赔", "health-insurance-card"),
        ("礼金", "unboxing-gift"),
        ("中奖", "bingo-ball"),
        ("借款收回", "coin-purse"),
        ("闲置出售", "flea-market"),
        ("政府补贴", "award-ceremony"),
        ("继承赠与", "golden-heart"),
        ("其他", "money")
    ]
}

public enum SwiftDataBookkeepingStoreError: Error, Equatable {
    case accountNotFound
    case categoryNotFound
    case transactionNotFound
}

private enum BalanceAdjustment {
    case add(Money)
    case subtract(Money)

    func apply(to balance: Money) throws -> Money {
        switch self {
        case .add(let money):
            try balance.adding(money)
        case .subtract(let money):
            try balance.subtracting(money)
        }
    }
}

private extension Transaction {
    func balanceAdjustments() -> [(UUID, BalanceAdjustment)] {
        switch type {
        case .expense:
            guard let accountID else { return [] }
            return [(accountID, .subtract(amount))]
        case .income:
            guard let accountID else { return [] }
            return [(accountID, .add(amount))]
        case .transfer:
            guard let accountID, let targetAccountID else { return [] }
            return [
                (accountID, .subtract(amount)),
                (targetAccountID, .add(amount))
            ]
        }
    }

    func reversalAdjustments() -> [(UUID, BalanceAdjustment)] {
        switch type {
        case .expense:
            guard let accountID else { return [] }
            return [(accountID, .add(amount))]
        case .income:
            guard let accountID else { return [] }
            return [(accountID, .subtract(amount))]
        case .transfer:
            guard let accountID, let targetAccountID else { return [] }
            return [
                (accountID, .add(amount)),
                (targetAccountID, .subtract(amount))
            ]
        }
    }
}

private extension LedgerEntity {
    var domainModel: Ledger {
        Ledger(id: id, name: name, currencyCode: currencyCode)
    }
}

private extension CategoryEntity {
    var domainModel: NumiCore.Category {
        NumiCore.Category(
            id: id,
            kind: CategoryKind(rawValue: kindRawValue) ?? .expense,
            name: name,
            icon: icon,
            isHidden: isHidden,
            sortOrder: sortOrder
        )
    }
}

private extension AccountEntity {
    var domainModel: Account {
        Account(
            id: id,
            name: name,
            type: AccountType(rawValue: typeRawValue) ?? .other,
            balance: Money(minorUnits: balanceMinorUnits, currencyCode: currencyCode),
            isIncludedInAssets: isIncludedInAssets,
            isHidden: isHidden
        )
    }
}

private extension TransactionEntity {
    var domainModel: Transaction {
        Transaction(
            id: id,
            type: TransactionType(rawValue: typeRawValue) ?? .expense,
            amount: Money(minorUnits: amountMinorUnits, currencyCode: currencyCode),
            occurredAt: occurredAt,
            categoryID: categoryID,
            accountID: accountID,
            targetAccountID: targetAccountID,
            note: note
        )
    }
}

private extension BudgetSettingEntity {
    var domainModel: BudgetSetting {
        BudgetSetting(
            id: id,
            period: BudgetPeriod(rawValue: periodRawValue) ?? .month,
            amount: Money(minorUnits: amountMinorUnits, currencyCode: currencyCode),
            isEnabled: isEnabled
        )
    }
}

private extension SubscriptionEntity {
    var domainModel: Subscription {
        Subscription(
            id: id,
            name: name,
            amount: Money(minorUnits: amountMinorUnits, currencyCode: currencyCode),
            cycle: SubscriptionCycle(rawValue: cycleRawValue) ?? .monthly,
            categoryID: categoryID,
            accountID: accountID,
            nextBillingDate: nextBillingDate,
            isEnabled: isEnabled,
            note: note
        )
    }
}

private extension InstallmentPlanEntity {
    var domainModel: InstallmentPlan {
        InstallmentPlan(
            id: id,
            name: name,
            totalAmount: Money(minorUnits: totalAmountMinorUnits, currencyCode: currencyCode),
            feePerPeriod: Money(minorUnits: feePerPeriodMinorUnits, currencyCode: currencyCode),
            periodCount: periodCount,
            firstPaymentDate: firstPaymentDate,
            accountID: accountID,
            categoryID: categoryID,
            note: note
        )
    }
}

private extension InstallmentPeriodEntity {
    var domainModel: InstallmentPeriod {
        InstallmentPeriod(
            id: id,
            planID: planID,
            periodIndex: periodIndex,
            dueDate: dueDate,
            isRecorded: isRecorded,
            isPaid: isPaid,
            transactionID: transactionID
        )
    }
}
