import SwiftUI
import NumiCore

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

public struct InsightsView: View {
    private let summary: TransactionSummary
    private let distribution: [InsightsDistributionRow]

    public init(summary: TransactionSummary, distribution: [InsightsDistributionRow]) {
        self.summary = summary
        self.distribution = distribution
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: NumiSpacing.s3) {
                    NumiSummaryTile(title: "支出", value: summary.expense.formatted(), variant: .expense)
                    NumiSummaryTile(title: "收入", value: summary.income.formatted(), variant: .income)
                    NumiSummaryTile(title: "结余", value: summary.balance.formatted(), variant: summary.balance.minorUnits < 0 ? .negative : .neutral)
                    NumiSummaryTile(title: "记账次数", value: "\(summary.recordCount)", variant: .neutral)
                }
                distributionSection
            }
            .padding(NumiSpacing.s5)
        }
        .background(NumiColor.surfacePage)
        .navigationTitle("洞悉")
        .modifier(LargeTitleNavigationChrome())
    }

    private var distributionSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text("支出分布")
                .font(NumiFont.bodyStrong)
                .foregroundStyle(NumiColor.textPrimary)
                .accessibilityIdentifier("insights.distribution.title")
            ForEach(distribution) { item in
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
                            .fill(NumiColor.accentDeep)
                            .frame(width: proxy.size.width * item.percentage)
                    }
                    .frame(height: 6)
                    .background(NumiColor.surfaceCardSubtle)
                    .clipShape(Capsule())
                }
                .padding(NumiSpacing.s4)
                .background(NumiColor.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
            }
        }
    }
}
