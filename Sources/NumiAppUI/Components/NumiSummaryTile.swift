import SwiftUI
import NumiCore

public enum NumiSummaryTileVariant {
    case expense
    case income
    case negative
    case neutral
}

public struct NumiSummaryTile: View {
    private let title: String
    private let value: String
    private let systemImage: String?
    private let variant: NumiSummaryTileVariant

    public init(title: String, value: String, systemImage: String? = nil, variant: NumiSummaryTileVariant) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.variant = variant
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s2) {
            HStack(spacing: NumiSpacing.s2) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .medium))
                }
                Text(title)
                    .font(NumiFont.bodySmall)
            }
            .foregroundStyle(NumiColor.textSecondary)

            Text(value)
                .font(NumiFont.amount)
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .accessibilityIdentifier("summary.\(title).value")
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private var backgroundColor: Color {
        switch variant {
        case .expense:
            return NumiColor.expenseBackground
        case .income:
            return NumiColor.incomeBackground
        case .negative:
            return NumiColor.negativeBackground
        case .neutral:
            return NumiColor.surfaceCard
        }
    }

    private var textColor: Color {
        switch variant {
        case .expense:
            return NumiColor.textPrimary
        case .income:
            return NumiColor.textPrimary
        case .negative:
            return NumiColor.negativeText
        case .neutral:
            return NumiColor.textPrimary
        }
    }
}
