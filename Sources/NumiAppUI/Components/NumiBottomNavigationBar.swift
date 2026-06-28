import SwiftUI

public struct NumiBottomNavigationBar: View {
    public struct Item: Identifiable, Equatable {
        public let id: String
        public let title: String
        public let systemImage: String

        public init(id: String, title: String, systemImage: String) {
            self.id = id
            self.title = title
            self.systemImage = systemImage
        }
    }

    private let items: [Item]
    private let selectedID: String
    private let onSelect: (String) -> Void
    private let trailingActionTitle: String
    private let trailingActionSystemImage: String
    private let trailingAction: () -> Void

    @Namespace private var selectionNamespace

    public init(
        items: [Item],
        selectedID: String,
        onSelect: @escaping (String) -> Void,
        trailingActionTitle: String,
        trailingActionSystemImage: String,
        trailingAction: @escaping () -> Void
    ) {
        self.items = items
        self.selectedID = selectedID
        self.onSelect = onSelect
        self.trailingActionTitle = trailingActionTitle
        self.trailingActionSystemImage = trailingActionSystemImage
        self.trailingAction = trailingAction
    }

    public var body: some View {
        HStack(alignment: .center, spacing: NumiChromeMetrics.tabBarOuterSpacing) {
            rail
            trailingButton
        }
        .padding(.horizontal, NumiChromeMetrics.tabBarContainerHorizontalPadding)
        .padding(.top, NumiChromeMetrics.tabBarTopPadding)
        .padding(.bottom, NumiChromeMetrics.tabBarBottomPadding)
        .background(.clear)
    }

    private var rail: some View {
        ZStack {
            HStack(spacing: NumiSpacing.s1) {
                ForEach(items) { item in
                    Button {
                        onSelect(item.id)
                    } label: {
                        VStack(spacing: NumiChromeMetrics.tabBarLabelSpacing) {
                            Image(systemName: item.systemImage)
                                .font(.system(size: NumiChromeMetrics.tabBarSymbolSize, weight: .medium))

                            Text(item.title)
                                .font(.system(size: 11, weight: selectedID == item.id ? .medium : .regular))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedID == item.id ? NumiColor.textPrimary : NumiColor.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: NumiChromeMetrics.tabBarItemMinHeight)
                        .background {
                            if selectedID == item.id {
                                Capsule()
                                    .fill(NumiColor.accentPrimary.opacity(0.14))
                                    .matchedGeometryEffect(id: "selected-tab", in: selectionNamespace)
                                    .padding(.vertical, 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tab.\(item.id)")
                }
            }
        }
        .padding(.horizontal, NumiChromeMetrics.tabBarRailHorizontalPadding)
        .padding(.vertical, NumiChromeMetrics.tabBarRailVerticalPadding)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(NumiColor.separator.opacity(0.65), lineWidth: 0.8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tab.rail")
    }

    private var trailingButton: some View {
        NumiFloatingActionButton(
            title: trailingActionTitle,
            systemImage: trailingActionSystemImage,
            action: trailingAction
        )
        .accessibilityIdentifier("button.addRecord")
    }
}
