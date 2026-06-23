import Foundation
import SwiftData
import NumiCore

/// 跨进程共享的账单创建服务（通过 App Group 共享 SwiftData）
public final class TransactionService: @unchecked Sendable {
    public static let shared = TransactionService()

    private let appGroupID = "group.com.numi.shared"
    private let container: ModelContainer
    private let context: ModelContext

    public init() {
        let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)!
            .appendingPathComponent("Numi.store")
        let config = ModelConfiguration(url: url)
        self.container = try! ModelContainer(
            for: LedgerEntity.self, TransactionEntity.self, CategoryEntity.self, AccountEntity.self,
            configurations: config
        )
        self.context = ModelContext(container)
    }

    // MARK: - 查询

    /// 获取当前所有可见分类名称
    public func availableCategoryNames() -> [String] {
        let desc = FetchDescriptor<CategoryEntity>(
            predicate: #Predicate { !$0.isHidden }
        )
        return (try? context.fetch(desc).map(\.name)) ?? []
    }

    // MARK: - 创建

    /// 从 AI 解析结果创建账单，返回是否成功
    public func createTransaction(from parsed: ParsedTransaction) throws {
        let category = resolveCategory(parsed.categoryName)
        let account = resolveAccount(parsed.accountName) ?? defaultAccount()
        let ledger = defaultLedger()

        guard let account else {
            throw TransactionServiceError.noAccount
        }
        guard let ledger else {
            throw TransactionServiceError.noLedger
        }

        let money = try Money(
            decimalString: "\(parsed.amount)", currencyCode: "CNY"
        )

        let entity = TransactionEntity(
            id: UUID(),
            type: parsed.type,
            amount: money,
            occurredAt: parsed.occurredAt,
            categoryID: category?.id,
            accountID: account.id,
            targetAccountID: nil,
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
            break
        }

        try context.save()
    }

    // MARK: - 匹配

    private func resolveCategory(_ name: String) -> CategoryEntity? {
        // 精确匹配
        let exact = FetchDescriptor<CategoryEntity>(
            predicate: #Predicate { $0.name == name && !$0.isHidden }
        )
        if let found = try? context.fetch(exact).first {
            return found
        }
        // 模糊匹配
        let all = FetchDescriptor<CategoryEntity>(
            predicate: #Predicate { !$0.isHidden }
        )
        guard let categories = try? context.fetch(all) else { return nil }
        return categories.first { $0.name.contains(name) || name.contains($0.name) }
    }

    private func resolveAccount(_ name: String?) -> AccountEntity? {
        guard let name, !name.isEmpty else { return nil }
        let desc = FetchDescriptor<AccountEntity>(
            predicate: #Predicate { $0.name == name && !$0.isHidden }
        )
        return try? context.fetch(desc).first
    }

    private func defaultAccount() -> AccountEntity? {
        let desc = FetchDescriptor<AccountEntity>(
            predicate: #Predicate { !$0.isHidden }
        )
        return try? context.fetch(desc).first
    }

    private func defaultLedger() -> LedgerEntity? {
        let desc = FetchDescriptor<LedgerEntity>(sortBy: [SortDescriptor(\.name)])
        return try? context.fetch(desc).first
    }
}

// MARK: - Errors

public enum TransactionServiceError: Error, LocalizedError {
    case noAccount
    case noLedger

    public var errorDescription: String? {
        switch self {
        case .noAccount: return "没有可用账户"
        case .noLedger: return "没有可用账本"
        }
    }
}
