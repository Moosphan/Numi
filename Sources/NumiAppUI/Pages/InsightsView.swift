import SwiftUI
import NumiCore

// MARK: - Distribution Row

public struct InsightsDistributionRow: Identifiable, Equatable {
    public let categoryID: UUID
    public let fallbackCategoryName: String
    public let fallbackIconName: String
    public let amount: Money
    public let percentage: Double

    public var id: UUID { categoryID }

    public init(categoryID: UUID, fallbackCategoryName: String, fallbackIconName: String, amount: Money, percentage: Double) {
        self.categoryID = categoryID
        self.fallbackCategoryName = fallbackCategoryName
        self.fallbackIconName = fallbackIconName
        self.amount = amount
        self.percentage = percentage
    }
}

// MARK: - Time Dimension

public enum InsightsTimeDimension: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case quarter
    case year

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .day: NumiLocalized.string("insight.dim.day")
        case .week: NumiLocalized.string("insight.dim.week")
        case .month: NumiLocalized.string("insight.dim.month")
        case .quarter: NumiLocalized.string("insight.dim.quarter")
        case .year: NumiLocalized.string("insight.dim.year")
        }
    }
}

// MARK: - Insights View

public struct InsightsView: View {
    @Environment(\.privacyAmountDisplayPolicy) private var privacyAmountDisplayPolicy
    @ObservedObject private var membership = MembershipController.shared
    private let summary: TransactionSummary
    private let previousPeriodSummary: TransactionSummary?
    private let trendPoints: [CashflowTrendPoint]
    private let hasUnavailableHistoricalRate: Bool
    private let expenseDistribution: [InsightsDistributionRow]
    private let incomeDistribution: [InsightsDistributionRow]
    private let categories: [NumiCore.Category]
    private let accounts: [Account]
    private let periodTitle: String
    private let customRange: InsightsCustomRange?
    private let selectedAccountID: UUID?
    private let onPreviousPeriod: () -> Void
    private let onNextPeriod: () -> Void
    private let onTimeDimensionChange: (InsightsTimeDimension) -> Void
    private let onApplyCustomRange: (InsightsCustomRange) -> Void
    private let onClearCustomRange: () -> Void
    private let onApplyAccountFilter: (UUID?) -> Void
    private let onSelectCategory: (InsightsDistributionRow, String) -> Void

    @State private var selectedDimension: InsightsTimeDimension = .month
    @State private var customRangeStart = Date()
    @State private var customRangeEnd = Date()
    @State private var showsCustomRangeEditor = false
    @State private var showsAdvancedOptions = false
    @State private var showsModuleCustomizer = false
    @State private var showsAccountFilterPicker = false
    @State private var draftAccountID: UUID?
    @State private var draftModuleOrder = InsightsModule.allCases
    @State private var draftShowsExpenseDistribution = true
    @State private var draftShowsIncomeDistribution = true
    @State private var membershipPaywallContext: MembershipPaywallContext?
    @AppStorage("insights.module.order") private var moduleOrderRaw = ""
    @AppStorage("insights.module.expenseDistribution.visible") private var showsExpenseDistribution = true
    @AppStorage("insights.module.incomeDistribution.visible") private var showsIncomeDistribution = true

    public init(
        summary: TransactionSummary,
        previousPeriodSummary: TransactionSummary? = nil,
        trendPoints: [CashflowTrendPoint] = [],
        hasUnavailableHistoricalRate: Bool = false,
        distribution: [InsightsDistributionRow],
        incomeDistribution: [InsightsDistributionRow] = [],
        categories: [NumiCore.Category] = [],
        accounts: [Account] = [],
        periodTitle: String = "",
        customRange: InsightsCustomRange? = nil,
        selectedAccountID: UUID? = nil,
        onPreviousPeriod: @escaping () -> Void = {},
        onNextPeriod: @escaping () -> Void = {},
        onTimeDimensionChange: @escaping (InsightsTimeDimension) -> Void = { _ in },
        onApplyCustomRange: @escaping (InsightsCustomRange) -> Void = { _ in },
        onClearCustomRange: @escaping () -> Void = {},
        onApplyAccountFilter: @escaping (UUID?) -> Void = { _ in },
        onSelectCategory: @escaping (InsightsDistributionRow, String) -> Void = { _, _ in }
    ) {
        self.summary = summary
        self.previousPeriodSummary = previousPeriodSummary
        self.trendPoints = trendPoints
        self.hasUnavailableHistoricalRate = hasUnavailableHistoricalRate
        self.expenseDistribution = distribution
        self.incomeDistribution = incomeDistribution
        self.categories = categories
        self.accounts = accounts
        self.periodTitle = periodTitle
        self.customRange = customRange
        self.selectedAccountID = selectedAccountID
        self.onPreviousPeriod = onPreviousPeriod
        self.onNextPeriod = onNextPeriod
        self.onTimeDimensionChange = onTimeDimensionChange
        self.onApplyCustomRange = onApplyCustomRange
        self.onClearCustomRange = onClearCustomRange
        self.onApplyAccountFilter = onApplyAccountFilter
        self.onSelectCategory = onSelectCategory
    }

    public var body: some View {
        NumiBottomAccessoryTrackingScrollView(accessibilityIdentifier: "scroll.insightsHome") {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                // Time dimension - capsule style with sliding indicator
                HStack(spacing: NumiSpacing.s2) {
                    CapsuleTabPicker(
                        options: InsightsTimeDimension.allCases.map(\.displayName),
                        selectedIndex: InsightsTimeDimension.allCases.firstIndex(of: selectedDimension) ?? 0
                    ) { index in
                        let dim = InsightsTimeDimension.allCases[index]
                        selectedDimension = dim
                        onTimeDimensionChange(dim)
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)

                    Button {
                        openAdvancedOptions()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(NumiColor.accentDeep)
                            .frame(width: 42, height: 42)
                            .background(NumiColor.surfaceCardSubtle)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(NumiLocalized.string("insight.advanced.options"))
                    .accessibilityIdentifier("action.insightsAdvancedOptions")
                }

                // Period navigation
                HStack(spacing: NumiSpacing.s3) {
                    Button {
                        onPreviousPeriod()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(NumiColor.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(NumiColor.surfaceCard)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(customRange != nil)

                    Spacer()

                    Text(periodTitle)
                        .font(NumiFont.bodyStrong)
                        .foregroundStyle(NumiColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    Button {
                        onNextPeriod()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(NumiColor.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(NumiColor.surfaceCard)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(customRange != nil)
                }
                .padding(.horizontal, NumiSpacing.s4)

                if selectedAccountID != nil {
                    activeAccountFilterChip
                }

                // Summary grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: NumiSpacing.s3) {
                    NumiSummaryTile(title: NumiLocalized.string( "insight.expense"), value: summary.expense.formatted(), variant: .expense, accessibilityKey: "insights.expense", amount: summary.expense)
                    NumiSummaryTile(title: NumiLocalized.string( "insight.income"), value: summary.income.formatted(), variant: .income, accessibilityKey: "insights.income", amount: summary.income)
                    NumiSummaryTile(title: NumiLocalized.string( "insight.balance"), value: summary.balance.formatted(), variant: summary.balance.minorUnits < 0 ? .negative : .neutral, accessibilityKey: "insights.balance", amount: summary.balance)
                    NumiSummaryTile(title: NumiLocalized.string( "insight.record.count"), value: "\(summary.recordCount)", variant: .neutral, accessibilityKey: "insights.recordCount")
                }

                if customRange != nil, let previousPeriodSummary {
                    periodComparisonSection(previousPeriodSummary)
                }

                if customRange != nil, !trendPoints.isEmpty {
                    cashflowTrendSection
                }

                if hasUnavailableHistoricalRate {
                    Label(NumiLocalized.string("currency.summary.unavailable"), systemImage: "exclamationmark.triangle.fill")
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(NumiSpacing.s3)
                        .background(NumiColor.surfaceCardSubtle, in: RoundedRectangle(cornerRadius: NumiRadius.lg))
                        .accessibilityIdentifier("insights.currencySummaryUnavailable")
                }

                ForEach(orderedModules) { module in
                    switch module {
                    case .expenseDistribution:
                        if showsExpenseDistribution, !expenseDistribution.isEmpty {
                            distributionSection(
                                title: NumiLocalized.string( "insight.expense.distribution"),
                                rows: expenseDistribution,
                                accentColor: NumiColor.expenseText,
                                type: "expense"
                            )
                        }
                    case .incomeDistribution:
                        if showsIncomeDistribution, !incomeDistribution.isEmpty {
                            distributionSection(
                                title: NumiLocalized.string( "insight.income.distribution"),
                                rows: incomeDistribution,
                                accentColor: NumiColor.incomeText,
                                type: "income"
                            )
                        }
                    }
                }
            }
            .padding(NumiSpacing.s5)
            .padding(.bottom, 120)
        }
        .background(NumiColor.surfacePage)
        .navigationTitle(Text(NumiLocalized.string("insight.title")))
        .modifier(LargeTitleNavigationChrome())
        .sheet(isPresented: $showsAdvancedOptions) {
            NavigationStack {
                List {
                    Section {
                        Button {
                            presentCustomRangeEditor()
                        } label: {
                            advancedOptionRow(
                                title: NumiLocalized.string("insight.custom.range"),
                                systemImage: "calendar.badge.clock"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("action.insightsCustomRange")

                        if customRange != nil {
                            Button {
                                onClearCustomRange()
                                showsAdvancedOptions = false
                            } label: {
                                advancedOptionRow(
                                    title: NumiLocalized.string("insight.custom.range.clear"),
                                    systemImage: "calendar"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Section {
                        Button {
                            presentAccountFilterPicker()
                        } label: {
                            advancedOptionRow(
                                title: NumiLocalized.string("insight.account.filter.title"),
                                detail: selectedAccountID == nil ? nil : selectedAccountName,
                                systemImage: "building.2"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("action.insightsAccountFilter")

                        Button {
                            presentModuleCustomizer()
                        } label: {
                            advancedOptionRow(
                                title: NumiLocalized.string("insight.customize.modules"),
                                systemImage: "rectangle.3.group"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("action.insightsCustomizeModules")

                        ShareLink(item: insightsReportText) {
                            advancedOptionRow(
                                title: NumiLocalized.string("insight.report.share"),
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        .accessibilityIdentifier("action.insightsShareReport")
                    }
                }
                .navigationTitle(NumiLocalized.string("insight.advanced.options"))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(NumiLocalized.string("common.done")) {
                            showsAdvancedOptions = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showsCustomRangeEditor) {
            NavigationStack {
                Form {
                    DatePicker("insight.custom.range.from", selection: $customRangeStart, displayedComponents: .date)
                    DatePicker("insight.custom.range.to", selection: $customRangeEnd, displayedComponents: .date)
                }
                .navigationTitle(NumiLocalized.string("insight.custom.range.title"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(NumiLocalized.string("common.cancel")) {
                            showsCustomRangeEditor = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(NumiLocalized.string("common.done")) {
                            onApplyCustomRange(InsightsCustomRange(start: customRangeStart, end: customRangeEnd))
                            showsCustomRangeEditor = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showsModuleCustomizer) {
            NavigationStack {
                List {
                    Section {
                        Text(NumiLocalized.string("insight.customize.modules.hint"))
                            .font(NumiFont.bodySmall)
                            .foregroundStyle(NumiColor.textSecondary)
                    }

                    Section {
                        ForEach(draftModuleOrder) { module in
                            HStack(spacing: NumiSpacing.s2) {
                                Toggle(moduleDisplayName(for: module), isOn: moduleVisibilityBinding(for: module))
                                    .accessibilityIdentifier("insights.module.\(module.rawValue).visible")
                                VStack(spacing: 0) {
                                    Button {
                                        moveDraftModule(module, by: -1)
                                    } label: {
                                        Image(systemName: "chevron.up")
                                            .font(.system(size: 11, weight: .bold))
                                            .frame(width: 28, height: 22)
                                    }
                                    .disabled(draftModuleOrder.first == module)
                                    .accessibilityLabel(NumiLocalized.string("insight.customize.modules.move.up"))

                                    Button {
                                        moveDraftModule(module, by: 1)
                                    } label: {
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 11, weight: .bold))
                                            .frame(width: 28, height: 22)
                                    }
                                    .disabled(draftModuleOrder.last == module)
                                    .accessibilityLabel(NumiLocalized.string("insight.customize.modules.move.down"))
                                }
                                .foregroundStyle(NumiColor.accentDeep)
                            }
                        }
                    }
                }
                .navigationTitle(NumiLocalized.string("insight.customize.modules.title"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(NumiLocalized.string("common.cancel")) {
                            showsModuleCustomizer = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(NumiLocalized.string("common.done")) {
                            moduleOrderRaw = InsightsModuleOrderPolicy.serialized(draftModuleOrder)
                            showsExpenseDistribution = draftShowsExpenseDistribution
                            showsIncomeDistribution = draftShowsIncomeDistribution
                            showsModuleCustomizer = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showsAccountFilterPicker) {
            NavigationStack {
                List {
                    Button {
                        draftAccountID = nil
                    } label: {
                        accountFilterOption(
                            title: NumiLocalized.string("insight.account.all"),
                            isSelected: draftAccountID == nil
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(accounts) { account in
                        Button {
                            draftAccountID = account.id
                        } label: {
                            accountFilterOption(
                                title: account.localizedDisplayName,
                                isSelected: draftAccountID == account.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .navigationTitle(NumiLocalized.string("insight.account.filter.title"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(NumiLocalized.string("common.cancel")) {
                            showsAccountFilterPicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(NumiLocalized.string("common.done")) {
                            onApplyAccountFilter(draftAccountID)
                            showsAccountFilterPicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .task { await membership.start() }
        .membershipPaywall(context: $membershipPaywallContext)
    }

    @ViewBuilder
    private func periodComparisonSection(_ previous: TransactionSummary) -> some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(NumiLocalized.string("insight.comparison.title"))
                        .font(NumiFont.bodyStrong)
                        .foregroundStyle(NumiColor.textPrimary)
                    Text(NumiLocalized.string("insight.comparison.subtitle"))
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NumiColor.accentDeep)
            }

            comparisonRow(
                title: NumiLocalized.string("insight.expense"),
                current: summary.expense,
                previous: previous.expense,
                tint: NumiColor.expenseText,
                accessibilityKey: "expense"
            )
            comparisonRow(
                title: NumiLocalized.string("insight.income"),
                current: summary.income,
                previous: previous.income,
                tint: NumiColor.incomeText,
                accessibilityKey: "income"
            )
            comparisonRow(
                title: NumiLocalized.string("insight.balance"),
                current: summary.balance,
                previous: previous.balance,
                tint: summary.balance.minorUnits >= previous.balance.minorUnits ? NumiColor.incomeText : NumiColor.expenseText,
                accessibilityKey: "balance"
            )
        }
        .padding(NumiSpacing.s4)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        .accessibilityIdentifier("insights.periodComparison")
    }

    private var cashflowTrendSection: some View {
        let maximum = max(
            1,
            trendPoints.map { max($0.expense.minorUnits, $0.income.minorUnits) }.max() ?? 1
        )

        return VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            VStack(alignment: .leading, spacing: 3) {
                Text(NumiLocalized.string("insight.trend.title"))
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)
                Text(NumiLocalized.string("insight.trend.subtitle"))
                    .font(NumiFont.footnote)
                    .foregroundStyle(NumiColor.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: NumiSpacing.s2) {
                    ForEach(trendPoints) { point in
                        VStack(spacing: NumiSpacing.s2) {
                            HStack(alignment: .bottom, spacing: 3) {
                                trendBar(
                                    amount: point.expense.minorUnits,
                                    maximum: maximum,
                                    color: NumiColor.expenseText
                                )
                                trendBar(
                                    amount: point.income.minorUnits,
                                    maximum: maximum,
                                    color: NumiColor.incomeText
                                )
                            }
                            Text(point.date.numiFormatted(.dateTime.month().day()))
                                .font(NumiFont.caption)
                                .foregroundStyle(NumiColor.textTertiary)
                                .lineLimit(1)
                        }
                        .frame(width: 40)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(point.date.numiFormatted(.dateTime.month().day())): \(NumiLocalized.string("insight.expense")) \(privacyAmountDisplayPolicy.display(point.expense)), \(NumiLocalized.string("insight.income")) \(privacyAmountDisplayPolicy.display(point.income))")
                    }
                }
                .frame(height: 126, alignment: .bottom)
            }
        }
        .padding(NumiSpacing.s4)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        .accessibilityIdentifier("insights.cashflowTrend")
    }

    private func trendBar(amount: Int64, maximum: Int64, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(width: 12, height: max(3, 82 * CGFloat(amount) / CGFloat(maximum)))
    }

    @ViewBuilder
    private func comparisonRow(
        title: String,
        current: Money,
        previous: Money,
        tint: Color,
        accessibilityKey: String
    ) -> some View {
        let delta = current.minorUnits - previous.minorUnits
        let deltaAmount = Money(minorUnits: abs(delta), currencyCode: current.currencyCode)

        HStack(spacing: NumiSpacing.s3) {
            Circle()
                .fill(tint.opacity(0.14))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.textPrimary)
                Text(NumiLocalized.string(
                    "insight.comparison.previous",
                    privacyAmountDisplayPolicy.display(previous)
                ))
                .font(NumiFont.footnote)
                .foregroundStyle(NumiColor.textSecondary)
            }
            Spacer()
            Text(delta == 0 ? "–" : "\(delta > 0 ? "+" : "−")\(privacyAmountDisplayPolicy.display(deltaAmount))")
                .font(NumiFont.bodyStrong)
                .foregroundStyle(delta == 0 ? NumiColor.textSecondary : tint)
                .accessibilityIdentifier("insights.periodComparison.\(accessibilityKey)")
        }
    }

    private func startCustomRangeSelection() {
        switch membership.decision(for: .openAdvancedInsights) {
        case .granted:
            let selectedRange = customRange ?? InsightsCustomRange(start: Date(), end: Date())
            customRangeStart = selectedRange.start
            customRangeEnd = selectedRange.end
            showsCustomRangeEditor = true
        case .blocked(let context):
            membershipPaywallContext = context
        }
    }

    private func openAdvancedOptions() {
        switch membership.decision(for: .openAdvancedInsights) {
        case .granted:
            showsAdvancedOptions = true
        case .blocked(let context):
            membershipPaywallContext = context
        }
    }

    private func presentCustomRangeEditor() {
        showsAdvancedOptions = false
        DispatchQueue.main.async {
            startCustomRangeSelection()
        }
    }

    private func presentAccountFilterPicker() {
        showsAdvancedOptions = false
        DispatchQueue.main.async {
            startAccountFilterSelection()
        }
    }

    private func presentModuleCustomizer() {
        showsAdvancedOptions = false
        DispatchQueue.main.async {
            startModuleCustomization()
        }
    }

    @ViewBuilder
    private func advancedOptionRow(title: String, detail: String? = nil, systemImage: String) -> some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NumiColor.accentDeep)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)
                if let detail {
                    Text(detail)
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NumiColor.textTertiary)
        }
        .contentShape(Rectangle())
    }

    private var selectedAccountName: String {
        guard let selectedAccountID else {
            return NumiLocalized.string("insight.account.all")
        }
        return accounts.first { $0.id == selectedAccountID }?.localizedDisplayName
            ?? NumiLocalized.string("insight.account.all")
    }

    private var insightsReportText: String {
        InsightsReportFormatter.text(
            periodTitle: periodTitle,
            accountName: selectedAccountID == nil ? nil : selectedAccountName,
            summary: summary,
            previousSummary: previousPeriodSummary
        )
    }

    private var activeAccountFilterChip: some View {
        Button {
            onApplyAccountFilter(nil)
        } label: {
            HStack(spacing: NumiSpacing.s2) {
                Image(systemName: "building.2")
                Text(selectedAccountName)
                    .lineLimit(1)
                Image(systemName: "xmark.circle.fill")
            }
            .font(NumiFont.bodySmall)
            .foregroundStyle(NumiColor.accentDeep)
            .padding(.horizontal, NumiSpacing.s3)
            .frame(height: 32)
            .background(NumiColor.surfaceCardSubtle)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, NumiSpacing.s4)
        .accessibilityIdentifier("insights.activeAccountFilter")
    }

    private func startAccountFilterSelection() {
        switch membership.decision(for: .openAdvancedInsights) {
        case .granted:
            draftAccountID = selectedAccountID
            showsAccountFilterPicker = true
        case .blocked(let context):
            membershipPaywallContext = context
        }
    }

    @ViewBuilder
    private func accountFilterOption(title: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
                .font(NumiFont.bodyStrong)
                .foregroundStyle(NumiColor.textPrimary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(NumiColor.accentDeep)
            }
        }
        .contentShape(Rectangle())
    }

    private var orderedModules: [InsightsModule] {
        InsightsModuleOrderPolicy.modules(from: moduleOrderRaw)
    }

    private func startModuleCustomization() {
        switch membership.decision(for: .openAdvancedInsights) {
        case .granted:
            draftModuleOrder = orderedModules
            draftShowsExpenseDistribution = showsExpenseDistribution
            draftShowsIncomeDistribution = showsIncomeDistribution
            showsModuleCustomizer = true
        case .blocked(let context):
            membershipPaywallContext = context
        }
    }

    private func moduleDisplayName(for module: InsightsModule) -> String {
        switch module {
        case .expenseDistribution:
            NumiLocalized.string("insight.expense.distribution")
        case .incomeDistribution:
            NumiLocalized.string("insight.income.distribution")
        }
    }

    private func moduleVisibilityBinding(for module: InsightsModule) -> Binding<Bool> {
        Binding(
            get: {
                switch module {
                case .expenseDistribution: draftShowsExpenseDistribution
                case .incomeDistribution: draftShowsIncomeDistribution
                }
            },
            set: { isVisible in
                switch module {
                case .expenseDistribution: draftShowsExpenseDistribution = isVisible
                case .incomeDistribution: draftShowsIncomeDistribution = isVisible
                }
            }
        )
    }

    private func moveDraftModule(_ module: InsightsModule, by offset: Int) {
        guard let index = draftModuleOrder.firstIndex(of: module) else { return }
        let destination = index + offset
        guard draftModuleOrder.indices.contains(destination) else { return }
        draftModuleOrder.swapAt(index, destination)
    }

    // MARK: - Distribution Section

    @ViewBuilder
    private func distributionSection(
        title: String,
        rows: [InsightsDistributionRow],
        accentColor: Color,
        type: String
    ) -> some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text(title)
                .font(NumiFont.bodyStrong)
                .foregroundStyle(NumiColor.textPrimary)
                .accessibilityIdentifier("insights.distribution.\(type)")

            ForEach(rows) { item in
                Button {
                    onSelectCategory(item, type)
                } label: {
                    VStack(alignment: .leading, spacing: NumiSpacing.s2) {
                        HStack(spacing: NumiSpacing.s3) {
                            CategoryIconView(iconName: resolvedIconName(for: item), size: 36)
                                .foregroundStyle(NumiColor.textPrimary)
                                .background(NumiColor.surfaceCardSubtle)
                                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                                .accessibilityIdentifier("insights.categoryIcon.\(item.categoryID.uuidString)")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(resolvedCategoryName(for: item))
                                    .font(NumiFont.bodyStrong)
                                    .foregroundStyle(NumiColor.textPrimary)
                                    .accessibilityIdentifier("insights.category.\(item.categoryID.uuidString)")
                                Text(privacyAmountDisplayPolicy.display(item.amount))
                                    .font(NumiFont.bodySmall)
                                    .foregroundStyle(NumiColor.textSecondary)
                            }
                            Spacer()
                            Text(NumiLocalized.percent(item.percentage))
                                .font(NumiFont.bodySmall)
                                .foregroundStyle(NumiColor.textTertiary)
                        }
                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: 999)
                                .fill(accentColor)
                                .frame(width: proxy.size.width * item.percentage)
                        }
                        .frame(height: 6)
                        .background(NumiColor.surfaceCardSubtle)
                        .clipShape(Capsule())
                    }
                    .padding(NumiSpacing.s4)
                    .background(NumiColor.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func resolvedCategoryName(for row: InsightsDistributionRow) -> String {
        RuntimeLocalizedDisplay.categoryName(
            for: row.categoryID,
            categories: categories,
            fallbackCategoryName: row.fallbackCategoryName
        )
    }

    private func resolvedIconName(for row: InsightsDistributionRow) -> String {
        RuntimeLocalizedDisplay.categoryIconName(
            for: row.categoryID,
            categories: categories,
            fallbackCategoryIcon: row.fallbackIconName
        )
    }
}

// MARK: - Category Transactions Detail View

public struct CategoryTransactionsDetailView: View {
    @Environment(\.privacyAmountDisplayPolicy) private var privacyAmountDisplayPolicy
    private let categoryID: UUID
    private let transactions: [NumiCore.Transaction]
    private let categories: [NumiCore.Category]
    private let accentColor: Color
    private let totalAmount: Money
    private let currencyCode: String
    private let exchangeRateHistory: ExchangeRateHistory
    private let transactionType: TransactionType
    private let periodTitle: String
    private let fallbackCategoryName: String?
    private let fallbackIconName: String?

    public init(
        categoryID: UUID,
        transactions: [NumiCore.Transaction],
        categories: [NumiCore.Category],
        accentColor: Color,
        totalAmount: Money,
        currencyCode: String,
        exchangeRateHistory: ExchangeRateHistory,
        transactionType: TransactionType,
        periodTitle: String = "",
        fallbackCategoryName: String? = nil,
        fallbackIconName: String? = nil
    ) {
        self.categoryID = categoryID
        self.transactions = transactions
        self.categories = categories
        self.accentColor = accentColor
        self.totalAmount = totalAmount
        self.currencyCode = currencyCode
        self.exchangeRateHistory = exchangeRateHistory
        self.transactionType = transactionType
        self.periodTitle = periodTitle
        self.fallbackCategoryName = fallbackCategoryName
        self.fallbackIconName = fallbackIconName
    }

    private var sortedTransactions: [NumiCore.Transaction] {
        transactions.sorted { $0.occurredAt > $1.occurredAt }
    }

    /// 按日期分组
    private var groupedTransactions: [(date: Date, transactions: [NumiCore.Transaction])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: sortedTransactions) { cal.startOfDay(for: $0.occurredAt) }
        return grouped
            .map { (date: $0.key, transactions: $0.value) }
            .sorted { $0.date > $1.date }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s4) {
                // Summary card
                VStack(alignment: .leading, spacing: NumiSpacing.s3) {
                    HStack(spacing: NumiSpacing.s3) {
                        CategoryIconView(iconName: iconName, size: 48)
                            .foregroundStyle(NumiColor.textPrimary)
                            .background(NumiColor.surfaceCardSubtle)
                            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(categoryName)
                                .font(NumiFont.title)
                                .foregroundStyle(NumiColor.textPrimary)
                            HStack(spacing: NumiSpacing.s1) {
                                if !periodTitle.isEmpty {
                                    Text(periodTitle)
                                        .font(NumiFont.bodySmall)
                                        .foregroundStyle(NumiColor.textTertiary)
                                    Text("·")
                                        .font(NumiFont.bodySmall)
                                        .foregroundStyle(NumiColor.textTertiary)
                                }
                                Text(NumiLocalized.string("insight.transaction.count", sortedTransactions.count))
                                    .font(NumiFont.bodySmall)
                                    .foregroundStyle(NumiColor.textTertiary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(NumiLocalized.string("insight.total.amount"))
                            .font(NumiFont.bodySmall)
                            .foregroundStyle(NumiColor.textSecondary)
                        Text(privacyAmountDisplayPolicy.display(totalAmount))
                            .font(NumiFont.amountLarge)
                            .foregroundStyle(accentColor)
                            .monospacedDigit()
                    }
                    .padding(.top, NumiSpacing.s2)
                }
                .padding(NumiSpacing.s5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NumiColor.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)

                // Transactions grouped by date
                ForEach(groupedTransactions, id: \.date) { group in
                    let dayTotal = dailyTotal(for: group.transactions)

                    VStack(alignment: .leading, spacing: 0) {
                        // Date header with daily totals
                        HStack {
                            Text(sectionDateTitle(group.date))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(NumiColor.textSecondary)

                            Spacer()

                            if let dayTotal {
                                Text(privacyAmountDisplayPolicy.display(dayTotal, prefix: totalPrefix))
                                    .font(NumiFont.caption)
                                    .foregroundStyle(accentColor)
                                    .monospacedDigit()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(transactionType == .income ? NumiColor.incomeBackground : NumiColor.expenseBackground)
                                    .clipShape(Capsule())
                            } else {
                                Text(NumiLocalized.string("insight.exchange.rate.unavailable"))
                                    .font(NumiFont.caption)
                                    .foregroundStyle(NumiColor.textTertiary)
                            }
                        }
                        .padding(.horizontal, NumiSpacing.s4)
                        .padding(.top, NumiSpacing.s3)
                        .padding(.bottom, NumiSpacing.s2)

                        VStack(spacing: 0) {
                            ForEach(Array(group.transactions.enumerated()), id: \.element.id) { index, tx in
                                transactionRow(tx)
                                if index < group.transactions.count - 1 {
                                    Divider().padding(.leading, 48 + NumiSpacing.s3)
                                }
                            }
                        }
                    }
                    .background(NumiColor.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
                    .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                }

                if sortedTransactions.isEmpty {
                    VStack(spacing: NumiSpacing.s3) {
                        Image(systemName: "tray")
                            .font(.system(size: 36))
                            .foregroundStyle(NumiColor.textTertiary)
                        Text(NumiLocalized.string("insight.no.transactions"))
                            .font(NumiFont.body)
                            .foregroundStyle(NumiColor.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(NumiSpacing.s6)
                }
            }
            .padding(NumiSpacing.s5)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("scroll.insightsCategoryDetail")
        .background(NumiColor.surfacePage)
        .navigationTitle(categoryName)
        .modifier(LargeTitleNavigationChrome())
    }

    // MARK: - Transaction Row

    private func transactionRow(_ tx: NumiCore.Transaction) -> some View {
        let isIncome = tx.type == .income
        let prefix = isIncome ? "+" : (tx.type == .transfer ? "" : "-")

        return HStack(spacing: NumiSpacing.s3) {
            CategoryIconView(iconName: iconName, size: 40)
                .foregroundStyle(NumiColor.textPrimary)
                .background(NumiColor.surfaceCardSubtle)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(categoryName)
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)
                HStack(spacing: NumiSpacing.s1) {
                    Text(tx.occurredAt.numiTimeText())
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

            Text(privacyAmountDisplayPolicy.display(tx.amount, prefix: prefix))
                .font(NumiFont.bodyStrong)
                .foregroundStyle(NumiColor.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private var totalPrefix: String {
        transactionType == .income ? "+" : "-"
    }

    private func dailyTotal(for transactions: [NumiCore.Transaction]) -> Money? {
        guard transactionType != .transfer,
              let summary = try? TransactionSummary.monthly(
                  transactions: transactions,
                  currencyCode: currencyCode,
                  exchangeRateHistory: exchangeRateHistory
              )
        else {
            return nil
        }
        return transactionType == .income ? summary.income : summary.expense
    }

    private func sectionDateTitle(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return NumiLocalized.string( "date.today") }
        if cal.isDateInYesterday(date) { return NumiLocalized.string( "date.yesterday") }
        return dateTitleFormatter.string(from: date)
    }

    private var dateTitleFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = NumiLocalized.currentLocale
        f.setLocalizedDateFormatFromTemplate("MMMMdEEEE")
        return f
    }

    private var categoryName: String {
        RuntimeLocalizedDisplay.categoryName(
            for: categoryID,
            categories: categories,
            fallbackCategoryName: fallbackCategoryName
        )
    }

    private var iconName: String {
        RuntimeLocalizedDisplay.categoryIconName(
            for: categoryID,
            categories: categories,
            fallbackCategoryIcon: fallbackIconName
        )
    }
}

// MARK: - AnyShapeShape Helper

private struct AnyShapeShape: Shape {
    private let pathBuilder: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathBuilder = { rect in shape.path(in: rect) }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}

// MARK: - Capsule Tab Picker

struct CapsuleTabPicker: View {
    let options: [String]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let count = CGFloat(options.count)
            let tabWidth = geo.size.width / count

            ZStack(alignment: .leading) {
                // Sliding indicator
                Capsule()
                    .fill(NumiColor.accentDeep)
                    .frame(width: tabWidth - 4, height: geo.size.height - 4)
                    .offset(x: CGFloat(selectedIndex) * tabWidth + 2)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedIndex)

                // Tab buttons
                HStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        let isSelected = selectedIndex == index
                        Button {
                            onSelect(index)
                        } label: {
                            Text(option)
                                .font(isSelected ? NumiFont.bodyStrong : NumiFont.body)
                                .foregroundStyle(isSelected ? .white : NumiColor.textSecondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(height: 36)
        .background(NumiColor.surfaceCard)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
