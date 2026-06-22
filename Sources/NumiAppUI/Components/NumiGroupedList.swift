import SwiftUI

public enum NumiGroupedListMetrics {
    public static let rowHorizontalPadding: CGFloat = NumiSpacing.s4
    public static let groupedIconFrame: CGFloat = 48
    public static let rowContentSpacing: CGFloat = NumiSpacing.s3
    public static let separatorLeadingInset: CGFloat = rowHorizontalPadding + groupedIconFrame + rowContentSpacing
    public static let separatorTrailingInset: CGFloat = NumiSpacing.s4
}

public struct NumiGroupedCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(NumiColor.separator.opacity(0.55), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.035), radius: 12, x: 0, y: 5)
    }
}

public struct NumiInsetDivider: View {
    @Environment(\.displayScale) private var displayScale

    private let leadingInset: CGFloat
    private let trailingInset: CGFloat

    public init(
        leadingInset: CGFloat = NumiGroupedListMetrics.separatorLeadingInset,
        trailingInset: CGFloat = NumiGroupedListMetrics.separatorTrailingInset
    ) {
        self.leadingInset = leadingInset
        self.trailingInset = trailingInset
    }

    public var body: some View {
        Rectangle()
            .fill(NumiColor.separator)
            .frame(height: 1 / max(displayScale, 1))
            .padding(.leading, leadingInset)
            .padding(.trailing, trailingInset)
            .accessibilityHidden(true)
    }
}
