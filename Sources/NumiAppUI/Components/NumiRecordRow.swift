import SwiftUI
import NumiCore

public struct NumiRecordRow: View {
    public enum Style {
        case card
        case grouped
    }

    private let transaction: NumiCore.Transaction
    private let categoryName: String
    private let iconName: String
    private let subtitle: String?
    private let style: Style

    public init(
        transaction: NumiCore.Transaction,
        categoryName: String,
        iconName: String,
        subtitle: String? = nil,
        style: Style = .card
    ) {
        self.transaction = transaction
        self.categoryName = categoryName
        self.iconName = iconName
        self.subtitle = subtitle
        self.style = style
    }

    public var body: some View {
        HStack(spacing: NumiSpacing.s3) {
            CategoryIconView(iconName: iconName, size: style == .grouped ? NumiGroupedListMetrics.groupedIconFrame : 36)
                .background(NumiColor.surfaceCardSubtle)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))

            VStack(alignment: .leading, spacing: NumiSpacing.s1) {
                Text(categoryName)
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)
                if let secondaryText {
                    Text(secondaryText)
                        .font(NumiFont.bodySmall)
                        .foregroundStyle(NumiColor.textTertiary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: NumiSpacing.s3)

            Text(amountText)
                .font(NumiFont.body.monospacedDigit())
                .foregroundStyle(amountColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .accessibilityIdentifier("record.amount.\(categoryName)")
        }
        .padding(.horizontal, style == .grouped ? NumiGroupedListMetrics.rowHorizontalPadding : 14)
        .padding(.vertical, style == .grouped ? 12 : 14)
        .frame(minHeight: style == .grouped ? 80 : nil)
        .background(rowBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier("record.\(categoryName)")
    }

    @ViewBuilder
    private var rowBackground: some View {
        if style.usesOwnBackground {
            if style == .card {
                NumiColor.surfaceCard
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
            } else {
                NumiColor.surfaceCard
            }
        } else {
            Color.clear
        }
    }

    private var amountText: String {
        switch transaction.type {
        case .expense:
            return "-" + transaction.amount.formatted()
        case .income:
            return transaction.amount.formatted()
        case .transfer:
            return transaction.amount.formatted()
        }
    }

    private var secondaryText: String? {
        let timeText = Self.timeFormatter.string(from: transaction.occurredAt)
        if let subtitle, !subtitle.isEmpty {
            if transaction.note.isEmpty {
                return "\(timeText) · \(subtitle)"
            }
            return "\(timeText) · \(subtitle) · \(transaction.note)"
        }
        return transaction.note.isEmpty ? timeText : "\(timeText) · \(transaction.note)"
    }

    private var amountColor: Color {
        switch transaction.type {
        case .expense:
            return NumiColor.textPrimary
        case .income:
            return NumiColor.textPrimary
        case .transfer:
            return NumiColor.textPrimary
        }
    }

    private var accessibilitySummary: String {
        if let secondaryText, !secondaryText.isEmpty {
            return "\(categoryName)，\(secondaryText)，\(amountText)"
        }
        return "\(categoryName)，\(amountText)"
    }

    private static var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}

extension NumiRecordRow.Style {
    var usesOwnBackground: Bool {
        switch self {
        case .card, .grouped:
            return true
        }
    }
}
