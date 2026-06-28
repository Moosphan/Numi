import SwiftUI
import NumiCore

public enum NumiSheetContentMode {
    case fit
    case scroll
}

private enum NumiSheetLayout {
    static let grabberWidth: CGFloat = 36
    static let grabberHeight: CGFloat = 5
    static let grabberTopPadding: CGFloat = 9
    static let grabberBottomPadding: CGFloat = 0
    static let toolbarSlotWidth: CGFloat = 60
    static let toolbarHeight: CGFloat = 44
    static let headerBottomPadding: CGFloat = 10
}

public struct NumiBottomSheet<Content: View>: View {
    private let title: String
    private let showsGrabber: Bool
    private let contentMode: NumiSheetContentMode
    private let grabberTopPadding: CGFloat
    private let grabberBottomPadding: CGFloat
    private let headerBottomPadding: CGFloat
    private let accessibilityPrefix: String?
    private let dismissAccessibilitySuffix: String
    private let titleAccessibilitySuffix: String
    private let confirmAccessibilitySuffix: String
    private let dismissTitle: String?
    private let confirmTitle: String?
    private let onDismiss: () -> Void
    private let onConfirm: (() -> Void)?
    private let content: Content

    public init(
        title: String,
        showsGrabber: Bool = true,
        contentMode: NumiSheetContentMode = .scroll,
        grabberTopPadding: CGFloat = 9,
        grabberBottomPadding: CGFloat = 0,
        headerBottomPadding: CGFloat = 10,
        accessibilityPrefix: String? = nil,
        dismissAccessibilitySuffix: String = "close",
        titleAccessibilitySuffix: String = "title",
        confirmAccessibilitySuffix: String = "confirm",
        dismissTitle: String? = nil,
        confirmTitle: String? = nil,
        onDismiss: @escaping () -> Void,
        onConfirm: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showsGrabber = showsGrabber
        self.contentMode = contentMode
        self.grabberTopPadding = grabberTopPadding
        self.grabberBottomPadding = grabberBottomPadding
        self.headerBottomPadding = headerBottomPadding
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
        NumiSheetScaffold(
            title: title,
            showsGrabber: showsGrabber,
            contentMode: contentMode,
            grabberTopPadding: grabberTopPadding,
            grabberBottomPadding: grabberBottomPadding,
            headerBottomPadding: headerBottomPadding,
            accessibilityPrefix: accessibilityPrefix,
            dismissTitle: dismissTitle ?? NumiLocalized.string("common.close"),
            dismissAccessibilityID: accessibilityID(dismissAccessibilitySuffix),
            onDismiss: onDismiss,
            confirmTitle: confirmTitle,
            confirmAccessibilityID: accessibilityID(confirmAccessibilitySuffix),
            onConfirm: onConfirm,
            titleAccessibilityID: accessibilityID(titleAccessibilitySuffix)
        ) {
            content
        }
    }

    private func accessibilityID(_ suffix: String) -> String {
        guard let accessibilityPrefix else { return "" }
        return "\(accessibilityPrefix).\(suffix)"
    }
}

private struct NumiSheetScaffold<Content: View>: View {
    private let title: String
    private let showsGrabber: Bool
    private let contentMode: NumiSheetContentMode
    private let grabberTopPadding: CGFloat
    private let grabberBottomPadding: CGFloat
    private let headerBottomPadding: CGFloat
    private let accessibilityPrefix: String?
    private let dismissTitle: String
    private let dismissAccessibilityID: String
    private let onDismiss: () -> Void
    private let confirmTitle: String?
    private let confirmAccessibilityID: String
    private let onConfirm: (() -> Void)?
    private let titleAccessibilityID: String
    private let content: Content

    init(
        title: String,
        showsGrabber: Bool,
        contentMode: NumiSheetContentMode,
        grabberTopPadding: CGFloat,
        grabberBottomPadding: CGFloat,
        headerBottomPadding: CGFloat,
        accessibilityPrefix: String?,
        dismissTitle: String,
        dismissAccessibilityID: String,
        onDismiss: @escaping () -> Void,
        confirmTitle: String?,
        confirmAccessibilityID: String,
        onConfirm: (() -> Void)?,
        titleAccessibilityID: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showsGrabber = showsGrabber
        self.contentMode = contentMode
        self.grabberTopPadding = grabberTopPadding
        self.grabberBottomPadding = grabberBottomPadding
        self.headerBottomPadding = headerBottomPadding
        self.accessibilityPrefix = accessibilityPrefix
        self.dismissTitle = dismissTitle
        self.dismissAccessibilityID = dismissAccessibilityID
        self.onDismiss = onDismiss
        self.confirmTitle = confirmTitle
        self.confirmAccessibilityID = confirmAccessibilityID
        self.onConfirm = onConfirm
        self.titleAccessibilityID = titleAccessibilityID
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsGrabber {
                Capsule()
                    .fill(NumiColor.separator.opacity(0.9))
                    .frame(width: NumiSheetLayout.grabberWidth, height: NumiSheetLayout.grabberHeight)
                    .padding(.top, grabberTopPadding)
                    .padding(.bottom, grabberBottomPadding)
                    .accessibilityHidden(true)
            }

            HStack(spacing: NumiSpacing.s2) {
                toolbarButton(
                    title: dismissTitle,
                    color: NumiColor.toolbarIcon,
                    identifier: dismissAccessibilityID,
                    alignment: .leading,
                    action: onDismiss
                )

                Spacer(minLength: NumiSpacing.s2)

                Text(title)
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .modifier(AccessibilityIDModifier(identifier: titleAccessibilityID))

                Spacer(minLength: NumiSpacing.s2)

                if let confirmTitle, let onConfirm {
                    toolbarButton(
                        title: confirmTitle,
                        color: NumiColor.accentDeep,
                        identifier: confirmAccessibilityID,
                        alignment: .trailing,
                        action: onConfirm
                    )
                } else {
                    Color.clear
                        .frame(width: NumiSheetLayout.toolbarSlotWidth, height: NumiSheetLayout.toolbarHeight)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: NumiSheetLayout.toolbarHeight, alignment: .center)
            .padding(.horizontal, NumiSpacing.s4)
            .padding(.bottom, headerBottomPadding)

            contentContainer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(NumiColor.surfacePage)
        .presentationBackground(NumiColor.surfacePage)
        .presentationDragIndicator(.hidden)
        .tint(NumiColor.accentDeep)
        .accessibilityElement(children: .contain)
        .modifier(AccessibilityIDModifier(identifier: accessibilityPrefix ?? ""))
    }

    @ViewBuilder
    private var contentContainer: some View {
        switch contentMode {
        case .fit:
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case .scroll:
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.bottom, NumiSpacing.s4)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func toolbarButton(
        title: String,
        color: Color,
        identifier: String,
        alignment: Alignment,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(NumiFont.body)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        }
        .frame(width: NumiSheetLayout.toolbarSlotWidth, height: NumiSheetLayout.toolbarHeight)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .modifier(AccessibilityIDModifier(identifier: identifier))
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
