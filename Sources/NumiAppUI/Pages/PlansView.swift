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

    private let budgets: [BudgetCardModel]
    private let onSaveBudget: (BudgetPeriod, Money, Bool) -> Void

    public init(
        budgets: [BudgetCardModel],
        onSaveBudget: @escaping (BudgetPeriod, Money, Bool) -> Void = { _, _, _ in }
    ) {
        self.budgets = budgets
        self.onSaveBudget = onSaveBudget
    }

    public var body: some View {
        ScrollView {
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
                trailingText: "暂无订阅",
                accessibilityIdentifier: "plans.section.subscriptions"
            )

            PlanEmptyStateCard(
                iconName: "repeat",
                title: "当前没有订阅项目",
                message: "新增后会在这里显示下一次扣费时间与金额。",
                accessibilityIdentifier: "plans.empty.subscriptions"
            )
        }
    }

    private var installmentsSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            PlanSectionHeader(
                title: "分期进度",
                trailingText: "暂无分期",
                accessibilityIdentifier: "plans.section.installments"
            )

            PlanEmptyStateCard(
                iconName: "creditcard",
                title: "当前没有分期项目",
                message: "新增后会在这里显示剩余期数与每月应付金额。",
                accessibilityIdentifier: "plans.empty.installments"
            )
        }
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
