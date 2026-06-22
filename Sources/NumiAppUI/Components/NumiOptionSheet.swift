import SwiftUI
import NumiCore

// MARK: - Option Item

public struct NumiOptionItem: Identifiable {
    public let id: String
    let icon: String
    let title: String
    let subtitle: String?
    let isDisabled: Bool

    public init(
        id: String,
        icon: String,
        title: String,
        subtitle: String? = nil,
        isDisabled: Bool = false
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isDisabled = isDisabled
    }
}

// MARK: - Option Sheet

public struct NumiOptionSheet: View {
    private let title: String
    private let options: [NumiOptionItem]
    private let selectedID: String?
    private let onSelect: (NumiOptionItem) -> Void
    private let onDismiss: () -> Void

    public init(
        title: String,
        options: [NumiOptionItem],
        selectedID: String? = nil,
        onSelect: @escaping (NumiOptionItem) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.options = options
        self.selectedID = selectedID
        self.onSelect = onSelect
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NumiBottomSheet(
            title: title,
            contentMode: .scroll,
            accessibilityPrefix: "sheet.optionSheet",
            dismissTitle: "取消",
            onDismiss: onDismiss
        ) {
            VStack(spacing: NumiSpacing.s2) {
                ForEach(options) { option in
                    Button {
                        guard !option.isDisabled else { return }
                        onSelect(option)
                    } label: {
                        HStack(spacing: NumiSpacing.s3) {
                            Image(systemName: option.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .background(option.isDisabled ? Color.clear : NumiColor.surfaceCardSubtle)
                                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                                .foregroundStyle(option.isDisabled ? NumiColor.textTertiary : NumiColor.toolbarIcon)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(NumiFont.bodyStrong)
                                    .foregroundStyle(option.isDisabled ? NumiColor.textTertiary : NumiColor.textPrimary)
                                if let subtitle = option.subtitle {
                                    Text(subtitle)
                                        .font(NumiFont.footnote)
                                        .foregroundStyle(option.isDisabled ? NumiColor.textTertiary : NumiColor.textTertiary)
                                }
                            }

                            Spacer()

                            if option.id == selectedID && !option.isDisabled {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(NumiColor.accentDeep)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                        .padding(.horizontal, NumiSpacing.s4)
                        .background(
                            RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous)
                                .fill(option.id == selectedID && !option.isDisabled ? NumiColor.surfaceCardSubtle : NumiColor.surfaceCard)
                        )
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("sheet.optionSheet.option.\(option.id)")
                    .accessibilityLabel(option.title)
                    .accessibilityHint(option.subtitle ?? "")
                    .accessibilityValue(option.id == selectedID ? "selected" : "")
                    .buttonStyle(.plain)
                    .disabled(option.isDisabled)
                }
            }
            .padding(.horizontal, NumiSpacing.s4)
            .padding(.bottom, NumiSpacing.s4)
        }
    }
}
