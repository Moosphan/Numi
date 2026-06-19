import SwiftUI

public struct NumiBottomSheet<Content: View>: View {
    private let title: String
    private let accessibilityPrefix: String?
    private let dismissAccessibilitySuffix: String
    private let titleAccessibilitySuffix: String
    private let confirmAccessibilitySuffix: String
    private let dismissTitle: String
    private let confirmTitle: String?
    private let onDismiss: () -> Void
    private let onConfirm: (() -> Void)?
    private let content: Content

    public init(
        title: String,
        showsGrabber: Bool = true,
        accessibilityPrefix: String? = nil,
        dismissAccessibilitySuffix: String = "close",
        titleAccessibilitySuffix: String = "title",
        confirmAccessibilitySuffix: String = "confirm",
        dismissTitle: String = "关闭",
        confirmTitle: String? = nil,
        onDismiss: @escaping () -> Void,
        onConfirm: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.accessibilityPrefix = accessibilityPrefix
        self.dismissAccessibilitySuffix = dismissAccessibilitySuffix
        self.titleAccessibilitySuffix = titleAccessibilitySuffix
        self.confirmAccessibilitySuffix = confirmAccessibilitySuffix
        self.dismissTitle = dismissTitle
        self.confirmTitle = confirmTitle
        self.onDismiss = onDismiss
        self.onConfirm = onConfirm
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: NumiSpacing.s3) {
                Button(action: onDismiss) {
                    Text(dismissTitle)
                }
                .font(NumiFont.body)
                .foregroundStyle(NumiColor.toolbarIcon)
                .modifier(AccessibilityIDModifier(identifier: accessibilityID(dismissAccessibilitySuffix)))

                Spacer(minLength: NumiSpacing.s2)

                Text(title)
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)
                    .lineLimit(1)
                    .modifier(AccessibilityIDModifier(identifier: accessibilityID(titleAccessibilitySuffix)))

                Spacer(minLength: NumiSpacing.s2)

                if let confirmTitle, let onConfirm {
                    Button(action: onConfirm) {
                        Text(confirmTitle)
                    }
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.accentDeep)
                    .modifier(AccessibilityIDModifier(identifier: accessibilityID(confirmAccessibilitySuffix)))
                } else {
                    Color.clear
                        .frame(width: 44, height: 28)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, NumiSpacing.s4)
            .padding(.vertical, 12)

            content
        }
        .background(NumiColor.surfacePage)
        .presentationBackground(NumiColor.surfacePage)
        .presentationDragIndicator(.visible)
        .tint(NumiColor.accentDeep)
    }

    private func accessibilityID(_ suffix: String) -> String {
        guard let accessibilityPrefix else { return "" }
        return "\(accessibilityPrefix).\(suffix)"
    }
}

private struct AccessibilityIDModifier: ViewModifier {
    let identifier: String

    func body(content: Content) -> some View {
        if identifier.isEmpty {
            content
        } else {
            content.accessibilityIdentifier(identifier)
        }
    }
}
