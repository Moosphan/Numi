import SwiftUI
import Foundation
import NumiCore

public struct AccountManagementView: View {
    @State private var localAccounts: [Account]
    @State private var editingDraft: AccountDraft?
    @State private var pendingDelete: Account?

    private let accounts: [Account]
    private let transactions: [NumiCore.Transaction]
    private let categories: [NumiCore.Category]
    private let onVisibilityChange: (Account, Bool) -> Void
    private let onCreate: (AccountDraft) -> Void
    private let onUpdate: (Account, AccountDraft) -> Void
    private let onDelete: ((Account) -> Void)?

    public init(
        accounts: [Account],
        transactions: [NumiCore.Transaction] = [],
        categories: [NumiCore.Category] = [],
        onVisibilityChange: @escaping (Account, Bool) -> Void,
        onCreate: @escaping (AccountDraft) -> Void = { _ in },
        onUpdate: @escaping (Account, AccountDraft) -> Void = { _, _ in },
        onDelete: ((Account) -> Void)? = nil
    ) {
        self.accounts = accounts
        self.transactions = transactions
        self.categories = categories
        self._localAccounts = State(initialValue: accounts)
        self.onVisibilityChange = onVisibilityChange
        self.onCreate = onCreate
        self.onUpdate = onUpdate
        self.onDelete = onDelete
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                VStack(alignment: .leading, spacing: NumiSpacing.s3) {
                    Text("总资产")
                        .font(NumiFont.bodySmall)
                        .foregroundStyle(NumiColor.textSecondary)
                    Text(totalAssets.formatted())
                        .font(NumiFont.title)
                        .foregroundStyle(NumiColor.textPrimary)
                        .monospacedDigit()

                    Text("仅统计已开启\u{201C}计入资产\u{201D}的账户；隐藏账户不会出现在记账页账户选择器中，历史记录仍保留原账户。")
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textTertiary)
                        .padding(.top, NumiSpacing.s1)
                }
                .padding(NumiSpacing.s5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NumiColor.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)

                VStack(alignment: .leading, spacing: NumiSpacing.s3) {
                    Text("账户")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(NumiColor.textSecondary)

                    VStack(spacing: 0) {
                        ForEach(visibleRows) { account in
                            NavigationLink {
                                AccountDetailView(
                                    account: account,
                                    transactions: transactionsForAccount(account),
                                    categories: categories
                                )
                            } label: {
                                accountRow(account)
                            }
                            .buttonStyle(.plain)
                            if account.id != visibleRows.last?.id {
                                Divider().padding(.leading, 36 + NumiSpacing.s3)
                            }
                        }
                    }
                    .background(NumiColor.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                }
            }
            .padding(.horizontal, NumiSpacing.s5)
            .padding(.top, NumiSpacing.s4)
            .padding(.bottom, 120)
        }
        .background(NumiColor.surfacePage)
        .navigationTitle("账户管理")
        .modifier(LargeTitleNavigationChrome())
        .tint(NumiColor.accentDeep)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingDraft = .new(currencyCode: localAccounts.first?.balance.currencyCode ?? "CNY")
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("新增账户")
                .accessibilityIdentifier("action.addAccount")
            }
        }
        .sheet(item: $editingDraft) { draft in
            AccountFormView(draft: draft) { savedDraft in
                save(savedDraft)
            }
        }
        .confirmationDialog(
            "删除这个账户？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { account in
            Button("删除", role: .destructive) {
                onDelete?(account)
                pendingDelete = nil
            }
            Button("取消", role: .cancel) {
                pendingDelete = nil
            }
        } message: { account in
            Text("删除「\(account.name)」后不可恢复，关联的历史账单仍会保留该账户信息。")
        }
        .onChange(of: accounts) { _, newValue in
            localAccounts = newValue
        }
    }

    private var visibleRows: [Account] {
        localAccounts.sorted { lhs, rhs in
            if lhs.isHidden == rhs.isHidden {
                lhs.name < rhs.name
            } else {
                !lhs.isHidden && rhs.isHidden
            }
        }
    }

    private var totalAssets: Money {
        let included = localAccounts.filter { $0.isIncludedInAssets }
        guard let first = included.first else {
            return .zero(currencyCode: "CNY")
        }
        return included.dropFirst().reduce(first.balance) { partial, account in
            (try? partial.adding(account.balance)) ?? partial
        }
    }

    private func accountRow(_ account: Account) -> some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: iconName(for: account.type))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(NumiColor.toolbarIcon)
                .frame(width: 36, height: 36)
                .background(NumiColor.surfaceCardSubtle)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: NumiSpacing.s1) {
                    Text(account.name)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(NumiColor.textPrimary)

                    if isAccountHidden(account.id) {
                        Text("已隐藏")
                            .font(NumiFont.caption)
                            .foregroundStyle(NumiColor.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(NumiColor.surfaceCardSubtle)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: NumiSpacing.s1) {
                    Text(typeName(for: account.type))
                    Text("·")
                    Text(account.isIncludedInAssets ? "计入资产" : "不计入资产")
                        .accessibilityIdentifier("account.includedStatus.\(account.name)")
                }
                .font(NumiFont.footnote)
                .foregroundStyle(NumiColor.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("余额")
                    .font(NumiFont.caption)
                    .foregroundStyle(NumiColor.textTertiary)
                Text(account.balance.formatted())
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NumiColor.surfaceCard)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                editingDraft = .existing(account)
            } label: {
                Label("编辑", systemImage: "square.and.pencil")
            }

            Button {
                let nextHidden = !isAccountHidden(account.id)
                setAccountHidden(account, isHidden: nextHidden)
                onVisibilityChange(account, nextHidden)
            } label: {
                Label(isAccountHidden(account.id) ? "显示" : "隐藏",
                      systemImage: isAccountHidden(account.id) ? "eye" : "eye.slash")
            }

            Divider()

            Button(role: .destructive) {
                pendingDelete = account
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .accessibilityIdentifier("account.\(account.name)")
    }

    private func transactionsForAccount(_ account: Account) -> [NumiCore.Transaction] {
        transactions
            .filter { $0.accountID == account.id || $0.targetAccountID == account.id }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    private func save(_ draft: AccountDraft) {
        guard let balance = try? Money(decimalString: draft.balanceText, currencyCode: draft.currencyCode),
              !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        let sanitized = draft.sanitized(balance: balance)
        if let sourceAccount = draft.sourceAccount {
            updateLocalAccount(sourceAccount, with: sanitized)
            onUpdate(sourceAccount, sanitized)
        } else {
            onCreate(sanitized)
        }
        editingDraft = nil
    }

    private func updateLocalAccount(_ account: Account, with draft: AccountDraft) {
        guard let balance = try? Money(decimalString: draft.balanceText, currencyCode: draft.currencyCode),
              let index = localAccounts.firstIndex(where: { $0.id == account.id })
        else { return }

        localAccounts[index].name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        localAccounts[index].type = draft.type
        localAccounts[index].balance = balance
        localAccounts[index].isIncludedInAssets = draft.isIncludedInAssets
        localAccounts[index].isHidden = draft.isHidden
    }

    private func isAccountHidden(_ accountID: UUID) -> Bool {
        localAccounts.first { $0.id == accountID }?.isHidden ?? true
    }

    private func setAccountHidden(_ account: Account, isHidden: Bool) {
        guard let index = localAccounts.firstIndex(where: { $0.id == account.id }) else {
            return
        }
        localAccounts[index].isHidden = isHidden
    }

    private func iconName(for type: AccountType) -> String {
        switch type {
        case .cash: "centsign.circle"
        case .debitCard: "creditcard"
        case .creditCard: "creditcard.trianglebadge.exclamationmark"
        case .wechat: "message"
        case .alipay: "qrcode"
        case .virtual: "wallet.pass"
        case .liability: "minus.circle"
        case .other: "ellipsis.circle"
        }
    }

    private func typeName(for type: AccountType) -> String {
        switch type {
        case .cash: "现金"
        case .debitCard: "储蓄卡"
        case .creditCard: "信用卡"
        case .wechat: "微信"
        case .alipay: "支付宝"
        case .virtual: "虚拟账户"
        case .liability: "负债"
        case .other: "其他"
        }
    }
}

public struct AccountDraft: Identifiable {
    public let id: UUID
    public let sourceAccount: Account?
    public var name: String
    public var type: AccountType
    public var balanceText: String
    public var currencyCode: String
    public var isIncludedInAssets: Bool
    public var isHidden: Bool

    public init(
        id: UUID = UUID(),
        sourceAccount: Account? = nil,
        name: String,
        type: AccountType,
        balanceText: String,
        currencyCode: String,
        isIncludedInAssets: Bool,
        isHidden: Bool
    ) {
        self.id = id
        self.sourceAccount = sourceAccount
        self.name = name
        self.type = type
        self.balanceText = balanceText
        self.currencyCode = currencyCode
        self.isIncludedInAssets = isIncludedInAssets
        self.isHidden = isHidden
    }

    static func new(currencyCode: String) -> AccountDraft {
        AccountDraft(
            name: "",
            type: .cash,
            balanceText: "0",
            currencyCode: currencyCode,
            isIncludedInAssets: true,
            isHidden: false
        )
    }

    static func existing(_ account: Account) -> AccountDraft {
        AccountDraft(
            sourceAccount: account,
            name: account.name,
            type: account.type,
            balanceText: decimalText(for: account.balance),
            currencyCode: account.balance.currencyCode,
            isIncludedInAssets: account.isIncludedInAssets,
            isHidden: account.isHidden
        )
    }

    func sanitized(balance: Money) -> AccountDraft {
        AccountDraft(
            id: id,
            sourceAccount: sourceAccount,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            balanceText: Self.decimalText(for: balance),
            currencyCode: currencyCode,
            isIncludedInAssets: isIncludedInAssets,
            isHidden: isHidden
        )
    }

    private static func decimalText(for money: Money) -> String {
        let scale = Money.scale(for: money.currencyCode)
        let sign = money.minorUnits < 0 ? "-" : ""
        let absolute = abs(money.minorUnits)
        let whole = absolute / scale
        let fractionDigits = Money.fractionDigits(for: money.currencyCode)
        guard fractionDigits > 0 else { return "\(sign)\(whole)" }
        let fraction = absolute % scale
        return "\(sign)\(whole).\(String(format: "%0\(fractionDigits)lld", fraction))"
    }
}

private struct AccountFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: AccountDraft

    private let onSave: (AccountDraft) -> Void

    init(draft: AccountDraft, onSave: @escaping (AccountDraft) -> Void) {
        self._draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("账户名称", text: $draft.name)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("input.accountName")

                    Picker("账户类型", selection: $draft.type) {
                        ForEach(accountTypes, id: \.self) { type in
                            Label(typeName(for: type), systemImage: iconName(for: type))
                                .tag(type)
                        }
                    }
                    .accessibilityIdentifier("picker.accountType")
                } header: {
                    Text("账户信息")
                }

                Section {
                    TextField("当前余额", text: $draft.balanceText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .monospacedDigit()
                        .accessibilityIdentifier("input.accountBalance")

                    toggleRow(
                        title: "计入总资产",
                        subtitle: "关闭后不参与总资产汇总",
                        isOn: $draft.isIncludedInAssets,
                        accessibilityIdentifier: "toggle.accountIncludedInAssets"
                    )

                    toggleRow(
                        title: "隐藏账户",
                        subtitle: "隐藏后不出现在记账页账户选择器",
                        isOn: $draft.isHidden,
                        accessibilityIdentifier: "toggle.accountHidden"
                    )
                } header: {
                    Text("余额")
                } footer: {
                    Text("调整余额会直接更新账户当前余额；已有账单仍保留在明细中。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(NumiColor.surfacePage)
            .navigationTitle(draft.sourceAccount == nil ? "新增账户" : "编辑账户")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(draft)
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("action.saveAccount")
                }
            }
        }
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (try? Money(decimalString: draft.balanceText, currencyCode: draft.currencyCode)) != nil
    }

    private func toggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        accessibilityIdentifier: String
    ) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: NumiSpacing.s3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textTertiary)
                }
                Spacer()
                Toggle(title, isOn: isOn)
                    .labelsHidden()
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var accountTypes: [AccountType] {
        [.cash, .debitCard, .creditCard, .wechat, .alipay, .virtual, .liability, .other]
    }

    private func iconName(for type: AccountType) -> String {
        switch type {
        case .cash: "centsign.circle"
        case .debitCard: "creditcard"
        case .creditCard: "creditcard.trianglebadge.exclamationmark"
        case .wechat: "message"
        case .alipay: "qrcode"
        case .virtual: "wallet.pass"
        case .liability: "minus.circle"
        case .other: "ellipsis.circle"
        }
    }

    private func typeName(for type: AccountType) -> String {
        switch type {
        case .cash: "现金"
        case .debitCard: "储蓄卡"
        case .creditCard: "信用卡"
        case .wechat: "微信"
        case .alipay: "支付宝"
        case .virtual: "虚拟账户"
        case .liability: "负债"
        case .other: "其他"
        }
    }
}

// MARK: - AccountDetailView

struct AccountDetailView: View {
    let account: Account
    let transactions: [NumiCore.Transaction]
    let categories: [NumiCore.Category]

    private var expenseTotal: Money {
        let filtered = transactions.filter { $0.type == .expense }
        guard let first = filtered.first else { return .zero(currencyCode: account.balance.currencyCode) }
        return filtered.dropFirst().reduce(first.amount) { partial, tx in
            (try? partial.adding(tx.amount)) ?? partial
        }
    }

    private var incomeTotal: Money {
        let filtered = transactions.filter { $0.type == .income }
        guard let first = filtered.first else { return .zero(currencyCode: account.balance.currencyCode) }
        return filtered.dropFirst().reduce(first.amount) { partial, tx in
            (try? partial.adding(tx.amount)) ?? partial
        }
    }

    /// 初始金额 = 当前余额 - 收入 + 支出
    private var initialBalance: Money {
        let code = account.balance.currencyCode
        var result = account.balance
        // 减去收入
        for tx in transactions where tx.type == .income {
            result = (try? result.subtracting(tx.amount)) ?? result
        }
        // 加回支出
        for tx in transactions where tx.type == .expense {
            result = (try? result.adding(tx.amount)) ?? result
        }
        return result
    }

    /// 按时间正序排列的交易，用于计算每笔后的余额
    private var sortedTransactions: [NumiCore.Transaction] {
        transactions.sorted { $0.occurredAt < $1.occurredAt }
    }

    /// 计算每笔交易后的余额快照
    private var balanceSnapshots: [UUID: Money] {
        var snapshots: [UUID: Money] = [:]
        var running = initialBalance
        for tx in sortedTransactions {
            switch tx.type {
            case .expense:
                running = (try? running.subtracting(tx.amount)) ?? running
            case .income:
                running = (try? running.adding(tx.amount)) ?? running
            case .transfer:
                if tx.accountID == account.id {
                    running = (try? running.subtracting(tx.amount)) ?? running
                } else if tx.targetAccountID == account.id {
                    running = (try? running.adding(tx.amount)) ?? running
                }
            }
            snapshots[tx.id] = running
        }
        return snapshots
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                // 账户信息卡片
                VStack(alignment: .leading, spacing: NumiSpacing.s3) {
                    HStack(spacing: NumiSpacing.s3) {
                        Image(systemName: iconName)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(NumiColor.accentDeep)
                            .frame(width: 48, height: 48)
                            .background(NumiColor.surfaceCardSubtle)
                            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name)
                                .font(NumiFont.title)
                                .foregroundStyle(NumiColor.textPrimary)
                            Text(typeName)
                                .font(NumiFont.bodySmall)
                                .foregroundStyle(NumiColor.textTertiary)
                        }
                    }

                    VStack(alignment: .leading, spacing: NumiSpacing.s2) {
                        Text("当前余额")
                            .font(NumiFont.bodySmall)
                            .foregroundStyle(NumiColor.textSecondary)
                        Text(account.balance.formatted())
                            .font(NumiFont.amountLarge)
                            .foregroundStyle(NumiColor.textPrimary)
                            .monospacedDigit()
                    }

                    Divider()

                    HStack(spacing: NumiSpacing.s4) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("初始金额")
                                .font(NumiFont.caption)
                                .foregroundStyle(NumiColor.textTertiary)
                            Text(initialBalance.formatted())
                                .font(NumiFont.bodyStrong)
                                .foregroundStyle(NumiColor.textPrimary)
                                .monospacedDigit()
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 2) {
                            Text("累计支出")
                                .font(NumiFont.caption)
                                .foregroundStyle(NumiColor.textTertiary)
                            Text(expenseTotal.formatted())
                                .font(NumiFont.bodyStrong)
                                .foregroundStyle(NumiColor.expenseText)
                                .monospacedDigit()
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 2) {
                            Text("累计收入")
                                .font(NumiFont.caption)
                                .foregroundStyle(NumiColor.textTertiary)
                            Text(incomeTotal.formatted())
                                .font(NumiFont.bodyStrong)
                                .foregroundStyle(NumiColor.incomeText)
                                .monospacedDigit()
                        }
                    }

                    HStack(spacing: NumiSpacing.s4) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("交易笔数")
                                .font(NumiFont.caption)
                                .foregroundStyle(NumiColor.textTertiary)
                            Text("\(transactions.count)")
                                .font(NumiFont.bodyStrong)
                                .foregroundStyle(NumiColor.textPrimary)
                        }

                        Spacer()
                    }
                }
                .padding(NumiSpacing.s5)
                .background(NumiColor.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)

                // 最近交易记录
                if !transactions.isEmpty {
                    VStack(alignment: .leading, spacing: NumiSpacing.s3) {
                        Text("最近交易")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(NumiColor.textSecondary)

                        VStack(spacing: 0) {
                            ForEach(Array(transactions.prefix(20).enumerated()), id: \.element.id) { index, tx in
                                transactionRow(tx)
                                if index < min(transactions.count, 20) - 1 {
                                    Divider().padding(.leading, 48 + NumiSpacing.s3)
                                }
                            }
                        }
                        .background(NumiColor.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                    }
                }
            }
            .padding(.horizontal, NumiSpacing.s5)
            .padding(.top, NumiSpacing.s4)
            .padding(.bottom, 120)
        }
        .background(NumiColor.surfacePage)
        .navigationTitle("账户详情")
        .modifier(LargeTitleNavigationChrome())
    }

    private func transactionRow(_ tx: NumiCore.Transaction) -> some View {
        let category = categories.first { $0.id == tx.categoryID }
        let isIncome = tx.type == .income
        let prefix = isIncome ? "+" : (tx.type == .transfer ? "" : "-")
        let balance = balanceSnapshots[tx.id]

        return HStack(spacing: NumiSpacing.s3) {
            CategoryIconView(iconName: category?.icon ?? "ellipsis.circle", size: 36)
                .foregroundStyle(NumiColor.textPrimary)
                .background(NumiColor.surfaceCardSubtle)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(category?.name ?? (tx.type == .transfer ? "转账" : "其他"))
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)
                HStack(spacing: NumiSpacing.s1) {
                    Text(dateFormatter.string(from: tx.occurredAt))
                    if !tx.note.isEmpty {
                        Text("·")
                        Text(tx.note)
                    }
                }
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textTertiary)
                .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(prefix)\(tx.amount.formatted())")
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)
                    .monospacedDigit()
                if let balance {
                    Text("余额 \(balance.formatted())")
                        .font(NumiFont.caption)
                        .foregroundStyle(NumiColor.textTertiary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, 12)
    }

    private var iconName: String {
        switch account.type {
        case .cash: "centsign.circle"
        case .debitCard: "creditcard"
        case .creditCard: "creditcard.trianglebadge.exclamationmark"
        case .wechat: "message"
        case .alipay: "qrcode"
        case .virtual: "wallet.pass"
        case .liability: "minus.circle"
        case .other: "ellipsis.circle"
        }
    }

    private var typeName: String {
        switch account.type {
        case .cash: "现金"
        case .debitCard: "储蓄卡"
        case .creditCard: "信用卡"
        case .wechat: "微信"
        case .alipay: "支付宝"
        case .virtual: "虚拟账户"
        case .liability: "负债"
        case .other: "其他"
        }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }
}

#Preview {
    NavigationStack {
        AccountManagementView(
            accounts: NumiPreviewData.store().accounts,
            onVisibilityChange: { _, _ in }
        )
    }
}
