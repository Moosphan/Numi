import SwiftUI
import NumiCore

public struct BudgetCardModel: Identifiable, Equatable {
    public var id: BudgetPeriod { period }
    public let period: BudgetPeriod
    public let amount: Money
    public let spent: Money
    public let status: BudgetStatus
    public let isEnabled: Bool

    public init(
        period: BudgetPeriod,
        amount: Money,
        spent: Money,
        status: BudgetStatus,
        isEnabled: Bool
    ) {
        self.period = period
        self.amount = amount
        self.spent = spent
        self.status = status
        self.isEnabled = isEnabled
    }
}

public struct PlansView: View {
    @State private var editingDraft: BudgetDraft?
    @State private var showAddSubscription = false
    @State private var showAddInstallment = false
    @State private var editingSubscription: Subscription?
    @State private var editingInstallment: InstallmentPlan?
    @State private var selectedSubscription: Subscription?
    @State private var selectedInstallmentPlan: InstallmentPlan?
    @State private var pendingDeleteSubscription: Subscription?
    @State private var pendingDeleteInstallment: InstallmentPlan?

    private let budgets: [BudgetCardModel]
    private let subscriptions: [Subscription]
    private let installmentPlans: [InstallmentPlan]
    private let installmentPeriods: [InstallmentPeriod]
    private let categories: [NumiCore.Category]
    private let accounts: [Account]
    private let onSaveBudget: (BudgetPeriod, Money, Bool) -> Void
    private let onAddSubscription: (Subscription) -> Void
    private let onUpdateSubscription: (Subscription) -> Void
    private let onDeleteSubscription: (UUID) -> Void
    private let onAddInstallmentPlan: (InstallmentPlan) -> Void
    private let onUpdateInstallmentPlan: (InstallmentPlan) -> Void
    private let onDeleteInstallmentPlan: (UUID) -> Void

    public init(
        budgets: [BudgetCardModel],
        subscriptions: [Subscription] = [],
        installmentPlans: [InstallmentPlan] = [],
        installmentPeriods: [InstallmentPeriod] = [],
        categories: [NumiCore.Category] = [],
        accounts: [Account] = [],
        onSaveBudget: @escaping (BudgetPeriod, Money, Bool) -> Void = { _, _, _ in },
        onAddSubscription: @escaping (Subscription) -> Void = { _ in },
        onUpdateSubscription: @escaping (Subscription) -> Void = { _ in },
        onDeleteSubscription: @escaping (UUID) -> Void = { _ in },
        onAddInstallmentPlan: @escaping (InstallmentPlan) -> Void = { _ in },
        onUpdateInstallmentPlan: @escaping (InstallmentPlan) -> Void = { _ in },
        onDeleteInstallmentPlan: @escaping (UUID) -> Void = { _ in }
    ) {
        self.budgets = budgets
        self.subscriptions = subscriptions
        self.installmentPlans = installmentPlans
        self.installmentPeriods = installmentPeriods
        self.categories = categories
        self.accounts = accounts
        self.onSaveBudget = onSaveBudget
        self.onUpdateSubscription = onUpdateSubscription
        self.onAddSubscription = onAddSubscription
        self.onDeleteSubscription = onDeleteSubscription
        self.onAddInstallmentPlan = onAddInstallmentPlan
        self.onUpdateInstallmentPlan = onUpdateInstallmentPlan
        self.onDeleteInstallmentPlan = onDeleteInstallmentPlan
    }

    public var body: some View {
        NumiBottomAccessoryTrackingScrollView(accessibilityIdentifier: "scroll.plansHome") {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                if let monthlyBudget {
                    BudgetProgressCard(
                        model: monthlyBudget,
                        style: .hero,
                        accessibilityIdentifier: "plans.hero.monthBudget"
                    ) {
                        editingDraft = BudgetDraft(model: monthlyBudget)
                    }
                }
                budgetOverviewSection
                subscriptionsSection
                installmentsSection
            }
            .padding(NumiSpacing.s5)
            .padding(.bottom, 96)
        }
        .background(NumiColor.surfacePage)
        .navigationTitle("计划")
        .modifier(LargeTitleNavigationChrome())
        .navigationDestination(item: $selectedSubscription) { sub in
            SubscriptionDetailView(
                subscription: sub,
                categories: categories,
                accounts: accounts,
                onEdit: {
                    selectedSubscription = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        editingSubscription = sub
                    }
                },
                onDelete: {
                    onDeleteSubscription(sub.id)
                    selectedSubscription = nil
                }
            )
        }
        .navigationDestination(item: $selectedInstallmentPlan) { plan in
            let periods = installmentPeriods.filter { $0.planID == plan.id }
            InstallmentDetailView(
                plan: plan,
                periods: periods,
                categories: categories,
                onEdit: {
                    selectedInstallmentPlan = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        editingInstallment = plan
                    }
                },
                onDelete: {
                    onDeleteInstallmentPlan(plan.id)
                    selectedInstallmentPlan = nil
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showAddSubscription = true
                    } label: {
                        Label("添加订阅", systemImage: "repeat")
                    }
                    Button {
                        showAddInstallment = true
                    } label: {
                        Label("添加分期", systemImage: "creditcard")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NumiColor.accentDeep)
                }
            }
        }
        .sheet(item: $editingDraft) { draft in
            BudgetFormView(draft: draft) { savedDraft in
                guard let amount = try? Money(decimalString: savedDraft.amountText, currencyCode: savedDraft.currencyCode) else {
                    return
                }
                onSaveBudget(savedDraft.period, amount, savedDraft.isEnabled)
                editingDraft = nil
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddSubscription) {
            SubscriptionFormView(categories: categories, accounts: accounts) { sub in
                onAddSubscription(sub)
                showAddSubscription = false
            }
            .presentationDetents([.large])
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showAddInstallment) {
            InstallmentFormView(categories: categories, accounts: accounts) { plan in
                onAddInstallmentPlan(plan)
                showAddInstallment = false
            }
            .presentationDetents([.large])
            .presentationCornerRadius(28)
        }
        .sheet(item: $editingSubscription) { sub in
            SubscriptionFormView(
                categories: categories,
                accounts: accounts,
                existing: sub
            ) { updated in
                onUpdateSubscription(updated)
                editingSubscription = nil
            }
            .presentationDetents([.large])
            .presentationCornerRadius(28)
        }
        .sheet(item: $editingInstallment) { plan in
            InstallmentFormView(
                categories: categories,
                accounts: accounts,
                existing: plan
            ) { updated in
                onUpdateInstallmentPlan(updated)
                editingInstallment = nil
            }
            .presentationDetents([.large])
            .presentationCornerRadius(28)
        }
    }

    private var budgetOverviewSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            PlanSectionHeader(
                title: "预算总览",
                trailingText: secondaryBudgets.isEmpty ? "暂无其他预算" : "\(secondaryBudgets.count) 个预算",
                accessibilityIdentifier: "plans.section.budgetOverview"
            )

            ForEach(secondaryBudgets) { budget in
                BudgetProgressCard(model: budget, style: .regular, accessibilityIdentifier: nil) {
                    editingDraft = BudgetDraft(model: budget)
                }
            }
        }
    }

    private var subscriptionsSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            PlanSectionHeader(
                title: "订阅",
                trailingText: subscriptions.isEmpty ? "暂无订阅" : "\(subscriptions.count) 个订阅",
                accessibilityIdentifier: "plans.section.subscriptions"
            )

            if subscriptions.isEmpty {
                PlanEmptyStateCard(
                    iconName: "repeat",
                    title: "当前没有订阅项目",
                    message: "新增后会在这里显示下一次扣费时间与金额。",
                    accessibilityIdentifier: "plans.empty.subscriptions"
                )
            } else {
                ForEach(subscriptions) { sub in
                    subscriptionRow(sub)
                }
            }
        }
    }

    private func subscriptionRow(_ sub: Subscription) -> some View {
        Button {
            selectedSubscription = sub
        } label: {
            HStack(spacing: NumiSpacing.s3) {
                PlanSymbolBadge(
                    iconName: "repeat",
                    tint: sub.isEnabled ? NumiColor.accentDeep : NumiColor.textTertiary,
                    background: sub.isEnabled ? NumiColor.iconBackground : NumiColor.surfaceCardSubtle,
                    size: 36
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(sub.name)
                        .font(NumiFont.bodyStrong)
                        .foregroundStyle(sub.isEnabled ? NumiColor.textPrimary : NumiColor.textTertiary)
                    Text("\(sub.cycle.displayName) · \(sub.amount.formatted())")
                        .font(NumiFont.bodySmall)
                        .foregroundStyle(NumiColor.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("下次扣费")
                        .font(NumiFont.caption)
                        .foregroundStyle(NumiColor.textTertiary)
                    Text(sub.nextBillingDate.formatted(.dateTime.month().day()))
                        .font(NumiFont.bodySmall)
                        .foregroundStyle(NumiColor.textPrimary)
                }
            }
            .padding(NumiSpacing.s4)
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                selectedSubscription = sub
            } label: {
                Label("查看详情", systemImage: "info.circle")
            }

            Button {
                editingSubscription = sub
            } label: {
                Label("编辑", systemImage: "square.and.pencil")
            }

            Button {
                UIPasteboard.general.string = shareText(sub)
            } label: {
                Label("分享", systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                pendingDeleteSubscription = sub
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "删除「\(sub.name)」？",
            isPresented: Binding(
                get: { pendingDeleteSubscription?.id == sub.id },
                set: { if !$0 { pendingDeleteSubscription = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除订阅", role: .destructive) {
                onDeleteSubscription(sub.id)
                pendingDeleteSubscription = nil
            }
            Button("取消", role: .cancel) {
                pendingDeleteSubscription = nil
            }
        } message: {
            Text("删除后不可恢复。")
        }
    }

    private var installmentsSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            PlanSectionHeader(
                title: "分期进度",
                trailingText: installmentPlans.isEmpty ? "暂无分期" : "\(installmentPlans.count) 个分期",
                accessibilityIdentifier: "plans.section.installments"
            )

            if installmentPlans.isEmpty {
                PlanEmptyStateCard(
                    iconName: "creditcard",
                    title: "当前没有分期项目",
                    message: "新增后会在这里显示剩余期数与每月应付金额。",
                    accessibilityIdentifier: "plans.empty.installments"
                )
            } else {
                ForEach(installmentPlans) { plan in
                    installmentRow(plan)
                }
            }
        }
    }

    private func installmentRow(_ plan: InstallmentPlan) -> some View {
        let periods = installmentPeriods.filter { $0.planID == plan.id }
        let paidCount = periods.filter { $0.isPaid }.count
        let progress = plan.periodCount > 0 ? CGFloat(paidCount) / CGFloat(plan.periodCount) : 0

        return Button {
            selectedInstallmentPlan = plan
        } label: {
            VStack(alignment: .leading, spacing: NumiSpacing.s3) {
                HStack(spacing: NumiSpacing.s3) {
                    PlanSymbolBadge(
                        iconName: "creditcard",
                        tint: NumiColor.accentDeep,
                        background: NumiColor.iconBackground,
                        size: 36
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.name)
                            .font(NumiFont.bodyStrong)
                            .foregroundStyle(NumiColor.textPrimary)
                        Text("每期 \(plan.amountPerPeriod.formatted())")
                            .font(NumiFont.bodySmall)
                            .foregroundStyle(NumiColor.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(paidCount)/\(plan.periodCount) 期")
                            .font(NumiFont.bodyStrong)
                            .foregroundStyle(NumiColor.textPrimary)
                        Text("剩余 \(plan.periodCount - paidCount) 期")
                            .font(NumiFont.caption)
                            .foregroundStyle(NumiColor.textTertiary)
                    }
                }

                // Progress bar
                GeometryReader { proxy in
                    Capsule()
                        .fill(NumiColor.surfaceCardSubtle)
                    Capsule()
                        .fill(NumiColor.accentPrimary)
                        .frame(width: max(6, proxy.size.width * progress))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
                .frame(height: 6)
            }
        .padding(NumiSpacing.s4)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                selectedInstallmentPlan = plan
            } label: {
                Label("查看详情", systemImage: "info.circle")
            }

            Button {
                editingInstallment = plan
            } label: {
                Label("编辑", systemImage: "square.and.pencil")
            }

            Button {
                UIPasteboard.general.string = shareText(plan)
            } label: {
                Label("分享", systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                pendingDeleteInstallment = plan
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "删除「\(plan.name)」？",
            isPresented: Binding(
                get: { pendingDeleteInstallment?.id == plan.id },
                set: { if !$0 { pendingDeleteInstallment = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除分期", role: .destructive) {
                onDeleteInstallmentPlan(plan.id)
                pendingDeleteInstallment = nil
            }
            Button("取消", role: .cancel) {
                pendingDeleteInstallment = nil
            }
        } message: {
            Text("删除后不可恢复，所有期次记录将一并删除。")
        }
    }

    // MARK: - Share Text

    private func shareText(_ sub: Subscription) -> String {
        """
        【订阅】\(sub.name)
        金额：\(sub.amount.formatted())
        周期：\(sub.cycle.displayName)
        下次扣费：\(sub.nextBillingDate.formatted(.dateTime.year().month().day()))
        """
    }

    private func shareText(_ plan: InstallmentPlan) -> String {
        let periods = installmentPeriods.filter { $0.planID == plan.id }
        let paid = periods.filter { $0.isPaid }.count
        return """
        【分期】\(plan.name)
        总金额：\(plan.totalAmount.formatted())
        每期：\(plan.amountPerPeriod.formatted())
        进度：\(paid)/\(plan.periodCount) 期
        """
    }

    private var orderedBudgets: [BudgetCardModel] {
        budgets.sorted { lhs, rhs in
            periodOrder(lhs.period) < periodOrder(rhs.period)
        }
    }

    private var monthlyBudget: BudgetCardModel? {
        orderedBudgets.first { $0.period == .month } ?? orderedBudgets.first
    }

    private var secondaryBudgets: [BudgetCardModel] {
        orderedBudgets.filter { budget in
            guard let monthlyBudget else { return true }
            return budget.id != monthlyBudget.id
        }
    }

    private func periodOrder(_ period: BudgetPeriod) -> Int {
        switch period {
        case .week: 0
        case .month: 1
        }
    }

}

private struct PlanSectionHeader: View {
    let title: String
    let trailingText: String
    let accessibilityIdentifier: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(NumiFont.bodyStrong)
                .foregroundStyle(NumiColor.textPrimary)
                .accessibilityIdentifier(accessibilityIdentifier)
            Spacer()
            Text(trailingText)
                .font(NumiFont.footnote)
                .foregroundStyle(NumiColor.textTertiary)
        }
    }
}

private struct PlanSymbolBadge: View {
    let iconName: String
    let tint: Color
    let background: Color
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(tint)
            .symbolRenderingMode(.monochrome)
            .frame(width: size, height: size)
            .background(background)
            .clipShape(Circle())
    }
}

private enum BudgetCardStyle {
    case hero
    case regular
}

private struct BudgetProgressCard: View {
    let model: BudgetCardModel
    let style: BudgetCardStyle
    let accessibilityIdentifier: String?
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: style == .hero ? NumiSpacing.s5 : NumiSpacing.s3) {
            topRow
            amountBlock
            progressBlock
        }
        .padding(style == .hero ? NumiSpacing.s5 : NumiSpacing.s4)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "budget.card.\(model.period.rawValue)")
    }

    private var topRow: some View {
        HStack(alignment: .top, spacing: NumiSpacing.s3) {
            PlanSymbolBadge(
                iconName: iconName,
                tint: iconTint,
                background: iconBackground,
                size: style == .hero ? 40 : 36
            )

            VStack(alignment: .leading, spacing: NumiSpacing.s1) {
                HStack(spacing: NumiSpacing.s2) {
                    Text(title)
                        .font(style == .hero ? NumiFont.bodyStrong : NumiFont.body)
                        .foregroundStyle(NumiColor.textPrimary)
                    if style == .hero {
                        statusBadge
                    }
                }
                Text(subtitle)
                    .font(NumiFont.footnote)
                    .foregroundStyle(NumiColor.textTertiary)
            }

            Spacer(minLength: NumiSpacing.s3)

            Button {
                onEdit()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NumiColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(NumiColor.surfaceCardSubtle.opacity(style == .hero ? 0.7 : 1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("编辑\(title)")
            .accessibilityIdentifier("action.editBudget.\(model.period.rawValue)")
        }
    }

    private var amountBlock: some View {
        HStack(alignment: .top, spacing: NumiSpacing.s3) {
            VStack(alignment: .leading, spacing: NumiSpacing.s1) {
                HStack(alignment: .firstTextBaseline, spacing: NumiSpacing.s2) {
                    Text(model.spent.formatted())
                        .font(style == .hero ? NumiFont.amountLarge : NumiFont.amount)
                        .foregroundStyle(primaryAmountColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                        .accessibilityIdentifier("budget.\(model.period.rawValue).spent")
                    Text("/")
                        .font(style == .hero ? NumiFont.body : NumiFont.bodySmall)
                        .foregroundStyle(NumiColor.textTertiary)
                    Text(model.amount.formatted())
                        .font(style == .hero ? NumiFont.body : NumiFont.bodySmall)
                        .foregroundStyle(NumiColor.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityIdentifier("budget.\(model.period.rawValue).amount")
                }
                Text("已用 / 预算")
                    .font(NumiFont.footnote)
                    .foregroundStyle(NumiColor.textTertiary)
            }
            Spacer(minLength: NumiSpacing.s3)
            VStack(alignment: .trailing, spacing: NumiSpacing.s1) {
                Text(model.status.remaining.formatted())
                    .font(style == .hero ? NumiFont.bodyStrong.monospacedDigit() : NumiFont.bodySmall.monospacedDigit())
                    .foregroundStyle(remainingColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .accessibilityIdentifier("budget.\(model.period.rawValue).remaining")
                Text(remainingLabel)
                    .font(NumiFont.footnote)
                    .foregroundStyle(NumiColor.textTertiary)
            }
        }
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s2) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(NumiColor.surfaceCardSubtle)
                    Capsule()
                        .fill(progressColor)
                        .frame(width: max(10, proxy.size.width * progress))
                }
            }
            .frame(height: style == .hero ? 10 : 8)

            HStack {
                Text(progressSummary)
                    .font(NumiFont.footnote)
                    .foregroundStyle(NumiColor.textSecondary)
                Spacer()
                if style == .regular {
                    Text(stateLabel)
                        .font(NumiFont.footnote)
                        .foregroundStyle(model.status.isOverBudget ? NumiColor.negativeText : NumiColor.textTertiary)
                }
            }
        }
    }

    private var title: String {
        switch model.period {
        case .week: "周预算"
        case .month: "月预算"
        }
    }

    private var subtitle: String {
        switch model.period {
        case .week: "本周支出"
        case .month: "本月支出"
        }
    }

    private var iconName: String {
        "wallet.bifold"
    }

    private var progress: CGFloat {
        guard model.amount.minorUnits > 0 else { return 0 }
        let spent = max(model.spent.minorUnits, 0)
        return min(CGFloat(Double(spent) / Double(model.amount.minorUnits)), 1)
    }

    private var progressColor: Color {
        model.status.isOverBudget ? NumiColor.negativeText : NumiColor.accentPrimary
    }

    private var cornerRadius: CGFloat {
        style == .hero ? NumiRadius.xl : NumiRadius.lg
    }

    private var borderColor: Color {
        model.status.isOverBudget ? NumiColor.negativeText.opacity(0.2) : NumiColor.textPrimary.opacity(style == .hero ? 0.08 : 0.04)
    }

    private var primaryAmountColor: Color {
        model.isEnabled ? NumiColor.textPrimary : NumiColor.textSecondary
    }

    private var remainingColor: Color {
        model.status.isOverBudget ? NumiColor.negativeText : NumiColor.textPrimary
    }

    private var remainingLabel: String {
        model.status.isOverBudget ? "已超出" : "剩余"
    }

    private var progressSummary: String {
        if model.status.isOverBudget {
            return "超出 \(overBudgetAmount.formatted())"
        }
        return "已用 \(usedPercent)%"
    }

    private var usedPercent: Int {
        guard model.amount.minorUnits > 0 else { return 0 }
        let ratio = Double(max(model.spent.minorUnits, 0)) / Double(model.amount.minorUnits)
        return min(Int(ratio * 100), 100)
    }

    private var stateLabel: String {
        if !model.isEnabled {
            return "已关闭"
        }
        return model.status.isOverBudget ? "超支" : "正常"
    }

    private var statusBadge: some View {
        Text(stateLabel)
            .font(NumiFont.caption)
            .foregroundStyle(model.status.isOverBudget ? NumiColor.negativeText : NumiColor.accentDeep)
            .padding(.horizontal, NumiSpacing.s2)
            .padding(.vertical, 4)
            .background(
                (model.status.isOverBudget ? NumiColor.negativeBackground : NumiColor.accentPrimary.opacity(0.18))
            )
            .clipShape(Capsule())
    }

    private var iconTint: Color {
        model.status.isOverBudget ? NumiColor.negativeText : NumiColor.accentDeep
    }

    private var iconBackground: Color {
        model.status.isOverBudget ? NumiColor.negativeBackground.opacity(0.9) : NumiColor.surfaceCardSubtle
    }

    private var overBudgetAmount: Money {
        Money(
            minorUnits: max(-model.status.remaining.minorUnits, 0),
            currencyCode: model.status.remaining.currencyCode
        )
    }
}

private struct PlanEmptyStateCard: View {
    let iconName: String
    let title: String
    let message: String
    var accessibilityIdentifier: String?

    var body: some View {
        HStack(alignment: .top, spacing: NumiSpacing.s3) {
            PlanSymbolBadge(
                iconName: iconName,
                tint: NumiColor.textSecondary,
                background: NumiColor.surfaceCardSubtle,
                size: 40
            )

            VStack(alignment: .leading, spacing: NumiSpacing.s1) {
                Text(title)
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)
                Text(message)
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: NumiSpacing.s3)
        }
        .padding(NumiSpacing.s4)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous)
                .stroke(NumiColor.textPrimary.opacity(0.04), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
    }
}

private struct BudgetDraft: Identifiable {
    let id: BudgetPeriod
    var period: BudgetPeriod
    var amountText: String
    var currencyCode: String
    var isEnabled: Bool

    init(model: BudgetCardModel) {
        self.id = model.period
        self.period = model.period
        self.amountText = Self.decimalText(for: model.amount)
        self.currencyCode = model.amount.currencyCode
        self.isEnabled = model.isEnabled
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

private struct BudgetFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BudgetDraft

    private let onSave: (BudgetDraft) -> Void

    init(draft: BudgetDraft, onSave: @escaping (BudgetDraft) -> Void) {
        self._draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("预算金额", text: $draft.amountText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .monospacedDigit()
                        .accessibilityIdentifier("input.budgetAmount")

                    Button {
                        draft.isEnabled.toggle()
                    } label: {
                        HStack(spacing: NumiSpacing.s3) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("启用预算")
                                Text("关闭后仍保留金额，计划页不计入提醒")
                                    .font(NumiFont.footnote)
                                    .foregroundStyle(NumiColor.textTertiary)
                            }
                            Spacer()
                            Toggle("启用预算", isOn: $draft.isEnabled)
                                .labelsHidden()
                                .allowsHitTesting(false)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("toggle.budgetEnabled")
                } header: {
                    Text(title)
                } footer: {
                    Text("预算仅保存在本机，按自然周和自然月统计支出。")
                }
            }
            .navigationTitle("编辑预算")
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
                    .accessibilityIdentifier("action.saveBudget")
                }
            }
        }
    }

    private var title: String {
        switch draft.period {
        case .week: "周预算"
        case .month: "月预算"
        }
    }

    private var canSave: Bool {
        guard let amount = try? Money(decimalString: draft.amountText, currencyCode: draft.currencyCode) else {
            return false
        }
        return amount.minorUnits >= 0
    }
}

// MARK: - Subscription Form

private struct SubscriptionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amountText = ""
    @State private var cycle: SubscriptionCycle = .monthly
    @State private var categoryID: UUID?
    @State private var accountID: UUID?
    @State private var nextBillingDate = Date()
    @State private var isEnabled = true

    private let categories: [NumiCore.Category]
    private let accounts: [Account]
    private let existing: Subscription?
    private let onSave: (Subscription) -> Void

    init(categories: [NumiCore.Category], accounts: [Account], existing: Subscription? = nil, onSave: @escaping (Subscription) -> Void) {
        self.categories = categories
        self.accounts = accounts
        self.existing = existing
        self.onSave = onSave
        if let sub = existing {
            _name = State(initialValue: sub.name)
            _amountText = State(initialValue: Self.decimalText(for: sub.amount))
            _cycle = State(initialValue: sub.cycle)
            _categoryID = State(initialValue: sub.categoryID)
            _accountID = State(initialValue: sub.accountID)
            _nextBillingDate = State(initialValue: sub.nextBillingDate)
            _isEnabled = State(initialValue: sub.isEnabled)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("订阅名称", text: $name)
                        .accessibilityIdentifier("input.subscriptionName")
                    TextField("每期金额", text: $amountText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .monospacedDigit()
                        .accessibilityIdentifier("input.subscriptionAmount")
                } header: {
                    Text("订阅信息")
                }

                Section {
                    Picker("扣费周期", selection: $cycle) {
                        ForEach(SubscriptionCycle.allCases, id: \.self) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                    .accessibilityIdentifier("picker.subscriptionCycle")

                    DatePicker("下次扣费", selection: $nextBillingDate, displayedComponents: .date)
                        .accessibilityIdentifier("picker.subscriptionNextDate")
                } header: {
                    Text("扣费设置")
                } footer: {
                    Text("订阅记录保存在本地，到期后可手动记录为支出。")
                }
            }
            .navigationTitle(existing == nil ? "添加订阅" : "编辑订阅")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existing == nil ? "添加" : "保存") {
                        guard let amount = try? Money(decimalString: amountText, currencyCode: "CNY") else { return }
                        let sub = Subscription(
                            id: existing?.id ?? UUID(),
                            name: name,
                            amount: amount,
                            cycle: cycle,
                            categoryID: categoryID,
                            accountID: accountID,
                            nextBillingDate: nextBillingDate,
                            isEnabled: isEnabled
                        )
                        onSave(sub)
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("action.saveSubscription")
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (try? Money(decimalString: amountText, currencyCode: "CNY")) != nil
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

// MARK: - Installment Form

private struct InstallmentFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var totalAmountText = ""
    @State private var periodCountText = "12"
    @State private var feePerPeriodText = "0"
    @State private var firstPaymentDate = Date()
    @State private var accountID: UUID?
    @State private var categoryID: UUID?

    private let categories: [NumiCore.Category]
    private let existing: InstallmentPlan?
    private let accounts: [Account]
    private let onSave: (InstallmentPlan) -> Void

    init(categories: [NumiCore.Category], accounts: [Account], existing: InstallmentPlan? = nil, onSave: @escaping (InstallmentPlan) -> Void) {
        self.categories = categories
        self.accounts = accounts
        self.existing = existing
        self.onSave = onSave
        if let plan = existing {
            _name = State(initialValue: plan.name)
            _totalAmountText = State(initialValue: Self.decimalText(for: plan.totalAmount))
            _periodCountText = State(initialValue: "\(plan.periodCount)")
            _feePerPeriodText = State(initialValue: Self.decimalText(for: plan.feePerPeriod))
            _firstPaymentDate = State(initialValue: plan.firstPaymentDate)
            _accountID = State(initialValue: plan.accountID)
            _categoryID = State(initialValue: plan.categoryID)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("分期名称", text: $name)
                        .accessibilityIdentifier("input.installmentName")
                    TextField("总金额", text: $totalAmountText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .monospacedDigit()
                        .accessibilityIdentifier("input.installmentTotal")
                } header: {
                    Text("分期信息")
                }

                Section {
                    TextField("期数", text: $periodCountText)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .accessibilityIdentifier("input.installmentPeriods")
                    TextField("每期手续费", text: $feePerPeriodText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .monospacedDigit()
                        .accessibilityIdentifier("input.installmentFee")
                    DatePicker("首期日期", selection: $firstPaymentDate, displayedComponents: .date)
                        .accessibilityIdentifier("picker.installmentFirstDate")
                } header: {
                    Text("分期设置")
                } footer: {
                    Text("每期应付 = 总金额 ÷ 期数 + 手续费。系统会自动生成每期记录。")
                }
            }
            .navigationTitle(existing == nil ? "添加分期" : "编辑分期")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existing == nil ? "添加" : "保存") {
                        guard let total = try? Money(decimalString: totalAmountText, currencyCode: "CNY"),
                              let count = Int(periodCountText), count > 0 else { return }
                        let fee = (try? Money(decimalString: feePerPeriodText.isEmpty ? "0" : feePerPeriodText, currencyCode: "CNY")) ?? .zero(currencyCode: "CNY")
                        let plan = InstallmentPlan(
                            id: existing?.id ?? UUID(),
                            name: name,
                            totalAmount: total,
                            feePerPeriod: fee,
                            periodCount: count,
                            firstPaymentDate: firstPaymentDate,
                            accountID: accountID,
                            categoryID: categoryID
                        )
                        onSave(plan)
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("action.saveInstallment")
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (try? Money(decimalString: totalAmountText, currencyCode: "CNY")) != nil
            && (Int(periodCountText) ?? 0) > 0
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

// MARK: - Subscription Detail View

private struct SubscriptionDetailView: View {
    let subscription: Subscription
    let categories: [NumiCore.Category]
    let accounts: [Account]
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                // Info card
                VStack(alignment: .leading, spacing: NumiSpacing.s3) {
                    HStack(spacing: NumiSpacing.s3) {
                        PlanSymbolBadge(
                            iconName: "repeat",
                            tint: subscription.isEnabled ? NumiColor.accentDeep : NumiColor.textTertiary,
                            background: subscription.isEnabled ? NumiColor.iconBackground : NumiColor.surfaceCardSubtle,
                            size: 48
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(subscription.name)
                                .font(NumiFont.title)
                                .foregroundStyle(NumiColor.textPrimary)
                            Text(subscription.isEnabled ? "启用中" : "已暂停")
                                .font(NumiFont.bodySmall)
                                .foregroundStyle(subscription.isEnabled ? NumiColor.positiveText : NumiColor.textTertiary)
                        }
                    }

                    Divider()

                    detailRow("每期金额", value: subscription.amount.formatted())
                    detailRow("扣费周期", value: subscription.cycle.displayName)
                    detailRow("下次扣费", value: subscription.nextBillingDate.formatted(.dateTime.year().month().day()))

                    if let cat = categories.first(where: { $0.id == subscription.categoryID }) {
                        detailRow("分类", value: cat.name)
                    }
                    if let acc = accounts.first(where: { $0.id == subscription.accountID }) {
                        detailRow("扣费账户", value: acc.name)
                    }
                    if !subscription.note.isEmpty {
                        detailRow("备注", value: subscription.note)
                    }
                }
                .padding(NumiSpacing.s5)
                .background(NumiColor.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)

                // Delete button
                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Text("删除订阅")
                            .font(NumiFont.bodyStrong)
                            .foregroundStyle(NumiColor.negativeText)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(NumiColor.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(NumiSpacing.s5)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("scroll.subscriptionDetail")
        .numiBottomAccessoryVisibility(true)
        .background(NumiColor.surfacePage)
        .navigationTitle("订阅详情")
        .confirmationDialog("删除「\(subscription.name)」？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除订阅", role: .destructive) { onDelete() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后不可恢复。")
        }
        .modifier(LargeTitleNavigationChrome())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: NumiSpacing.s3) {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NumiColor.accentDeep)
                    }

                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NumiColor.accentDeep)
                    }
                }
            }
        }
    }

    private var shareText: String {
        """
        【订阅】\(subscription.name)
        金额：\(subscription.amount.formatted())
        周期：\(subscription.cycle.displayName)
        下次扣费：\(subscription.nextBillingDate.formatted(.dateTime.year().month().day()))
        """
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(NumiFont.body)
                .foregroundStyle(NumiColor.textSecondary)
            Spacer()
            Text(value)
                .font(NumiFont.body)
                .foregroundStyle(NumiColor.textPrimary)
        }
    }
}

// MARK: - Installment Detail View

private struct InstallmentDetailView: View {
    let plan: InstallmentPlan
    let periods: [InstallmentPeriod]
    let categories: [NumiCore.Category]
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    private var sortedPeriods: [InstallmentPeriod] {
        periods.sorted { $0.periodIndex < $1.periodIndex }
    }

    private var paidCount: Int {
        periods.filter { $0.isPaid }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                // Info card
                VStack(alignment: .leading, spacing: NumiSpacing.s3) {
                    HStack(spacing: NumiSpacing.s3) {
                        PlanSymbolBadge(
                            iconName: "creditcard",
                            tint: NumiColor.accentDeep,
                            background: NumiColor.iconBackground,
                            size: 48
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.name)
                                .font(NumiFont.title)
                                .foregroundStyle(NumiColor.textPrimary)
                            Text("\(paidCount)/\(plan.periodCount) 期")
                                .font(NumiFont.bodySmall)
                                .foregroundStyle(NumiColor.textTertiary)
                        }
                    }

                    Divider()

                    detailRow("总金额", value: plan.totalAmount.formatted())
                    detailRow("每期金额", value: plan.amountPerPeriod.formatted())
                    detailRow("期数", value: "\(plan.periodCount) 期")
                    if plan.feePerPeriod.minorUnits > 0 {
                        detailRow("每期手续费", value: plan.feePerPeriod.formatted())
                    }
                    detailRow("首期日期", value: plan.firstPaymentDate.formatted(.dateTime.year().month().day()))

                    if let cat = categories.first(where: { $0.id == plan.categoryID }) {
                        detailRow("分类", value: cat.name)
                    }
                    if !plan.note.isEmpty {
                        detailRow("备注", value: plan.note)
                    }

                    // Progress
                    let progress = plan.periodCount > 0 ? CGFloat(paidCount) / CGFloat(plan.periodCount) : 0
                    VStack(alignment: .leading, spacing: NumiSpacing.s2) {
                        Text("还款进度")
                            .font(NumiFont.bodySmall)
                            .foregroundStyle(NumiColor.textSecondary)
                        GeometryReader { proxy in
                            Capsule()
                                .fill(NumiColor.surfaceCardSubtle)
                            Capsule()
                                .fill(NumiColor.accentPrimary)
                                .frame(width: max(6, proxy.size.width * progress))
                        }
                        .frame(height: 8)
                    }
                }
                .padding(NumiSpacing.s5)
                .background(NumiColor.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)

                // Periods list
                VStack(alignment: .leading, spacing: NumiSpacing.s3) {
                    Text("分期明细")
                        .font(NumiFont.bodyStrong)
                        .foregroundStyle(NumiColor.textPrimary)

                    VStack(spacing: 0) {
                        ForEach(Array(sortedPeriods.enumerated()), id: \.element.id) { index, period in
                            HStack(spacing: NumiSpacing.s3) {
                                Text("第 \(period.periodIndex + 1) 期")
                                    .font(NumiFont.bodyStrong)
                                    .foregroundStyle(period.isPaid ? NumiColor.textTertiary : NumiColor.textPrimary)

                                Spacer()

                                Text(period.dueDate.formatted(.dateTime.year().month().day()))
                                    .font(NumiFont.bodySmall)
                                    .foregroundStyle(NumiColor.textTertiary)

                                Text(period.isPaid ? "已还" : "待还")
                                    .font(NumiFont.caption)
                                    .foregroundStyle(period.isPaid ? NumiColor.positiveText : NumiColor.textTertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(period.isPaid ? NumiColor.positiveBackground : NumiColor.surfaceCardSubtle)
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, NumiSpacing.s4)
                            .padding(.vertical, 12)

                            if index < sortedPeriods.count - 1 {
                                Divider().padding(.leading, NumiSpacing.s4)
                            }
                        }
                    }
                    .background(NumiColor.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
                    .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                }

                // Delete button
                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Text("删除分期")
                            .font(NumiFont.bodyStrong)
                            .foregroundStyle(NumiColor.negativeText)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(NumiColor.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(NumiSpacing.s5)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("scroll.installmentDetail")
        .numiBottomAccessoryVisibility(true)
        .background(NumiColor.surfacePage)
        .navigationTitle("分期详情")
        .modifier(LargeTitleNavigationChrome())
        .confirmationDialog("删除「\(plan.name)」？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除分期", role: .destructive) { onDelete() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后不可恢复，所有期次记录将一并删除。")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: NumiSpacing.s3) {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NumiColor.accentDeep)
                    }

                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NumiColor.accentDeep)
                    }
                }
            }
        }
    }

    private var shareText: String {
        """
        【分期】\(plan.name)
        总金额：\(plan.totalAmount.formatted())
        每期：\(plan.amountPerPeriod.formatted())
        进度：\(paidCount)/\(plan.periodCount) 期
        """
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(NumiFont.body)
                .foregroundStyle(NumiColor.textSecondary)
            Spacer()
            Text(value)
                .font(NumiFont.body)
                .foregroundStyle(NumiColor.textPrimary)
        }
    }
}
