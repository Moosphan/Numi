import SwiftUI
import NumiCore

// MARK: - Distribution Row

public struct InsightsDistributionRow: Identifiable, Equatable {
    public let categoryID: UUID
    public let categoryName: String
    public let iconName: String
    public let amount: Money
    public let percentage: Double

    public var id: UUID { categoryID }

    public init(categoryID: UUID, categoryName: String, iconName: String, amount: Money, percentage: Double) {
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.iconName = iconName
        self.amount = amount
        self.percentage = percentage
    }
}

// MARK: - Time Dimension

public enum InsightsTimeDimension: String, CaseIterable, Identifiable {
    case day = "日"
    case week = "周"
    case month = "月"
    case quarter = "季"
    case year = "年"

    public var id: String { rawValue }
}

// MARK: - Insights View

public struct InsightsView: View {
    private let summary: TransactionSummary
    private let expenseDistribution: [InsightsDistributionRow]
    private let incomeDistribution: [InsightsDistributionRow]
    private let periodTitle: String
    private let onPreviousPeriod: () -> Void
    private let onNextPeriod: () -> Void
    private let onTimeDimensionChange: (InsightsTimeDimension) -> Void
    private let onSelectCategory: (InsightsDistributionRow, String) -> Void

    @State private var selectedDimension: InsightsTimeDimension = .month

    public init(
        summary: TransactionSummary,
        distribution: [InsightsDistributionRow],
        incomeDistribution: [InsightsDistributionRow] = [],
        periodTitle: String = "",
        onPreviousPeriod: @escaping () -> Void = {},
        onNextPeriod: @escaping () -> Void = {},
        onTimeDimensionChange: @escaping (InsightsTimeDimension) -> Void = { _ in },
        onSelectCategory: @escaping (InsightsDistributionRow, String) -> Void = { _, _ in }
    ) {
        self.summary = summary
        self.expenseDistribution = distribution
        self.incomeDistribution = incomeDistribution
        self.periodTitle = periodTitle
        self.onPreviousPeriod = onPreviousPeriod
        self.onNextPeriod = onNextPeriod
        self.onTimeDimensionChange = onTimeDimensionChange
        self.onSelectCategory = onSelectCategory
    }

    public var body: some View {
        NumiBottomAccessoryTrackingScrollView(accessibilityIdentifier: "scroll.insightsHome") {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                // Time dimension - capsule style with sliding indicator
                CapsuleTabPicker(
                    options: InsightsTimeDimension.allCases.map { $0.rawValue },
                    selectedIndex: InsightsTimeDimension.allCases.firstIndex(of: selectedDimension) ?? 0
                ) { index in
                    let dim = InsightsTimeDimension.allCases[index]
                    selectedDimension = dim
                    onTimeDimensionChange(dim)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)

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
                }
                .padding(.horizontal, NumiSpacing.s4)

                // Summary grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: NumiSpacing.s3) {
                    NumiSummaryTile(title: "支出", value: summary.expense.formatted(), variant: .expense)
                    NumiSummaryTile(title: "收入", value: summary.income.formatted(), variant: .income)
                    NumiSummaryTile(title: "结余", value: summary.balance.formatted(), variant: summary.balance.minorUnits < 0 ? .negative : .neutral)
                    NumiSummaryTile(title: "记账次数", value: "\(summary.recordCount)", variant: .neutral)
                }

                // Expense distribution
                if !expenseDistribution.isEmpty {
                    distributionSection(
                        title: "支出分布",
                        rows: expenseDistribution,
                        accentColor: NumiColor.expenseText,
                        type: "expense"
                    )
                }

                // Income distribution
                if !incomeDistribution.isEmpty {
                    distributionSection(
                        title: "收入分布",
                        rows: incomeDistribution,
                        accentColor: NumiColor.incomeText,
                        type: "income"
                    )
                }
            }
            .padding(NumiSpacing.s5)
            .padding(.bottom, 120)
        }
        .background(NumiColor.surfacePage)
        .navigationTitle("洞悉")
        .modifier(LargeTitleNavigationChrome())
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
                .accessibilityIdentifier("insights.distribution.\(title)")

            ForEach(rows) { item in
                Button {
                    onSelectCategory(item, type)
                } label: {
                    VStack(alignment: .leading, spacing: NumiSpacing.s2) {
                        HStack(spacing: NumiSpacing.s3) {
                            CategoryIconView(iconName: item.iconName, size: 36)
                                .foregroundStyle(NumiColor.textPrimary)
                                .background(NumiColor.surfaceCardSubtle)
                                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                                .accessibilityIdentifier("insights.categoryIcon.\(item.categoryName)")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.categoryName)
                                    .font(NumiFont.bodyStrong)
                                    .foregroundStyle(NumiColor.textPrimary)
                                    .accessibilityIdentifier("insights.category.\(item.categoryName)")
                                Text(item.amount.formatted())
                                    .font(NumiFont.bodySmall)
                                    .foregroundStyle(NumiColor.textSecondary)
                            }
                            Spacer()
                            Text("\(Int(item.percentage * 100))%")
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
}

// MARK: - Category Transactions Detail View

public struct CategoryTransactionsDetailView: View {
    private let categoryName: String
    private let iconName: String
    private let transactions: [NumiCore.Transaction]
    private let categories: [NumiCore.Category]
    private let accentColor: Color
    private let periodTitle: String

    public init(
        categoryName: String,
        iconName: String,
        transactions: [NumiCore.Transaction],
        categories: [NumiCore.Category],
        accentColor: Color,
        periodTitle: String = ""
    ) {
        self.categoryName = categoryName
        self.iconName = iconName
        self.transactions = transactions
        self.categories = categories
        self.accentColor = accentColor
        self.periodTitle = periodTitle
    }

    private var sortedTransactions: [NumiCore.Transaction] {
        transactions.sorted { $0.occurredAt > $1.occurredAt }
    }

    private var totalAmount: Money {
        guard let first = sortedTransactions.first else { return .zero(currencyCode: "CNY") }
        return sortedTransactions.dropFirst().reduce(first.amount) { partial, tx in
            (try? partial.adding(tx.amount)) ?? partial
        }
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
                                Text("\(sortedTransactions.count) 笔交易")
                                    .font(NumiFont.bodySmall)
                                    .foregroundStyle(NumiColor.textTertiary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("总金额")
                            .font(NumiFont.bodySmall)
                            .foregroundStyle(NumiColor.textSecondary)
                        Text(totalAmount.formatted())
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
                    let dayTotals = dailyTotals(for: group.transactions)

                    VStack(alignment: .leading, spacing: 0) {
                        // Date header with daily totals
                        HStack {
                            Text(sectionDateTitle(group.date))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(NumiColor.textSecondary)

                            Spacer()

                            HStack(spacing: NumiSpacing.s1) {
                                if dayTotals.expenseMinor > 0 {
                                    let m = Money(minorUnits: dayTotals.expenseMinor, currencyCode: "CNY")
                                    Text("-\(m.formatted())")
                                        .font(NumiFont.caption)
                                        .foregroundStyle(NumiColor.expenseText)
                                        .monospacedDigit()
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(NumiColor.expenseBackground)
                                        .clipShape(Capsule())
                                }
                                if dayTotals.incomeMinor > 0 {
                                    let m = Money(minorUnits: dayTotals.incomeMinor, currencyCode: "CNY")
                                    Text("+\(m.formatted())")
                                        .font(NumiFont.caption)
                                        .foregroundStyle(NumiColor.incomeText)
                                        .monospacedDigit()
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(NumiColor.incomeBackground)
                                        .clipShape(Capsule())
                                }
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
                        Text("暂无交易记录")
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
                    Text(timeFormatter.string(from: tx.occurredAt))
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

            Text("\(prefix)\(tx.amount.formatted())")
                .font(NumiFont.bodyStrong)
                .foregroundStyle(NumiColor.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func dailyTotals(for transactions: [NumiCore.Transaction]) -> (expenseMinor: Int64, incomeMinor: Int64) {
        var expenseMinor: Int64 = 0
        var incomeMinor: Int64 = 0
        for tx in transactions {
            switch tx.type {
            case .expense: expenseMinor += tx.amount.minorUnits
            case .income: incomeMinor += tx.amount.minorUnits
            case .transfer: break
            }
        }
        return (expenseMinor, incomeMinor)
    }

    private func sectionDateTitle(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "今天" }
        if cal.isDateInYesterday(date) { return "昨天" }
        return dateTitleFormatter.string(from: date)
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }

    private var dateTitleFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f
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
