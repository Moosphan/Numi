import Foundation
import SwiftData
import NumiCore

/// 跨进程共享的账单创建服务（通过 App Group 共享 SwiftData）
public final class TransactionService: @unchecked Sendable {
    public static let shared = TransactionService()

    private static let appGroupID = "group.com.numi.shared"
    private let container: ModelContainer?
    private let context: ModelContext?

    public init() {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) else {
            self.container = nil
            self.context = nil
            return
        }

        let store = Self.makeStore(at: containerURL.appendingPathComponent("Numi.store"))
        self.container = store.container
        self.context = store.context
    }

    /// Creates a service for the same store URL used by the main app.
    /// This initializer keeps the cross-process write path testable without an App Group entitlement.
    public init(storeURL: URL) {
        let store = Self.makeStore(at: storeURL)
        self.container = store.container
        self.context = store.context
    }

    private static func makeStore(at url: URL) -> (container: ModelContainer?, context: ModelContext?) {
        do {
            let config = ModelConfiguration(url: url)
            let container = try ModelContainer(
                for: LedgerEntity.self,
                CategoryEntity.self,
                AccountEntity.self,
                TransactionEntity.self,
                BudgetSettingEntity.self,
                SubscriptionEntity.self,
                InstallmentPlanEntity.self,
                InstallmentPeriodEntity.self,
                configurations: config
            )
            return (container, ModelContext(container))
        } catch {
            return (nil, nil)
        }
    }

    public var isAvailable: Bool {
        context != nil
    }

    // MARK: - 查询

    /// 获取当前所有可见分类名称
    public func availableCategoryNames() -> [String] {
        guard let context else { return [] }
        let desc = FetchDescriptor<CategoryEntity>(
            predicate: #Predicate { !$0.isHidden }
        )
        guard let categories = try? context.fetch(desc) else { return [] }
        return categories
            .map(categoryModel)
            .localizedCategoryNames()
    }

    // MARK: - 创建

    /// 从 AI 解析结果创建账单，返回是否成功
    @discardableResult
    public func createTransaction(from parsed: ParsedTransaction) throws -> Money {
        guard let context else {
            throw TransactionServiceError.initializationFailed
        }
        let category = resolveCategory(parsed.categoryName)
        let account = resolveAccount(parsed.accountName) ?? defaultAccount()
        let ledger = defaultLedger()

        guard let account else {
            throw TransactionServiceError.noAccount
        }
        guard let ledger else {
            throw TransactionServiceError.noLedger
        }

        let targetAccount: AccountEntity?
        if parsed.type == .transfer {
            targetAccount = resolveAccount(parsed.targetAccountName)
            guard let targetAccount,
                  targetAccount.id != account.id,
                  targetAccount.currencyCode == ledger.currencyCode,
                  account.currencyCode == ledger.currencyCode else {
                throw TransactionServiceError.noAccount
            }
        } else {
            targetAccount = nil
        }

        let money = try Money(
            decimalString: "\(parsed.amount)", currencyCode: ledger.currencyCode
        )

        let entity = TransactionEntity(
            id: UUID(),
            type: parsed.type,
            amount: money,
            occurredAt: parsed.occurredAt,
            categoryID: category?.id,
            accountID: account.id,
            targetAccountID: targetAccount?.id,
            ledgerID: ledger.id,
            note: parsed.note,
            isSoftDeleted: false
        )

        context.insert(entity)

        // 更新账户余额
        switch parsed.type {
        case .expense:
            account.balanceMinorUnits -= money.minorUnits
        case .income:
            account.balanceMinorUnits += money.minorUnits
        case .transfer:
            account.balanceMinorUnits -= money.minorUnits
            targetAccount?.balanceMinorUnits += money.minorUnits
        }

        try context.save()
        return money
    }

    // MARK: - 匹配

    private func resolveCategory(_ name: String) -> CategoryEntity? {
        guard let context else { return nil }
        let all = FetchDescriptor<CategoryEntity>(
            predicate: #Predicate { !$0.isHidden }
        )
        guard let categories = try? context.fetch(all) else { return nil }
        guard let match = categories
            .map(categoryModel)
            .resolveLocalizedCategory(named: name) else {
            return nil
        }
        return categories.first { $0.id == match.id }
    }

    private func resolveAccount(_ name: String?) -> AccountEntity? {
        guard let context else { return nil }
        guard let name, !name.isEmpty else { return nil }
        let desc = FetchDescriptor<AccountEntity>(
            predicate: #Predicate { !$0.isHidden }
        )
        guard let accounts = try? context.fetch(desc) else { return nil }
        guard let match = accounts
            .map(accountModel)
            .resolveLocalizedAccount(named: name) else {
            return nil
        }
        return accounts.first { $0.id == match.id }
    }

    private func defaultAccount() -> AccountEntity? {
        guard let context else { return nil }
        let desc = FetchDescriptor<AccountEntity>(
            predicate: #Predicate { !$0.isHidden }
        )
        return try? context.fetch(desc).first
    }

    private func defaultLedger() -> LedgerEntity? {
        guard let context else { return nil }
        let desc = FetchDescriptor<LedgerEntity>(sortBy: [SortDescriptor(\.name)])
        return try? context.fetch(desc).first
    }

    private func categoryModel(_ entity: CategoryEntity) -> NumiCore.Category {
        NumiCore.Category(
            id: entity.id,
            kind: CategoryKind(rawValue: entity.kindRawValue) ?? .expense,
            name: entity.name,
            builtInKey: entity.builtInKey,
            icon: entity.icon,
            isHidden: entity.isHidden,
            sortOrder: entity.sortOrder
        )
    }

    private func accountModel(_ entity: AccountEntity) -> Account {
        Account(
            id: entity.id,
            name: entity.name,
            builtInKey: entity.builtInKey,
            type: AccountType(rawValue: entity.typeRawValue) ?? .other,
            balance: Money(minorUnits: entity.balanceMinorUnits, currencyCode: entity.currencyCode),
            isIncludedInAssets: entity.isIncludedInAssets,
            isHidden: entity.isHidden
        )
    }
}

// MARK: - Errors

public enum TransactionServiceError: Error, LocalizedError {
    case noAccount
    case noLedger
    case initializationFailed

    public var errorDescription: String? {
        switch self {
        case .noAccount: return NumiLocalized.string("error.transaction.no.account")
        case .noLedger: return NumiLocalized.string("error.transaction.no.ledger")
        case .initializationFailed: return NumiLocalized.string("error.transaction.initialization.failed")
        }
    }
}
