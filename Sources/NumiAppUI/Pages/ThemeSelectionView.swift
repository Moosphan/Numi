import SwiftUI
import NumiCore

public struct ThemeSelectionView: View {
    @AppStorage("app.theme.id") private var themeID = NumiTheme.defaultTheme.id
    @ObservedObject private var themeController = NumiThemeController.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                VStack(alignment: .leading, spacing: NumiSpacing.s3) {
                    VStack(spacing: 0) {
                        ForEach(Array(NumiTheme.allCases.enumerated()), id: \.element.id) { index, theme in
                            let isSelected = themeID == theme.id
                            Button {
                                themeController.apply(theme: theme)
                                themeID = theme.id
                            } label: {
                                HStack(spacing: NumiSpacing.s3) {
                                    themeSwatch(theme)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(theme.displayName)
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundStyle(NumiColor.textPrimary)
                                        Text(description(for: theme))
                                            .font(NumiFont.footnote)
                                            .foregroundStyle(NumiColor.textTertiary)
                                    }
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(NumiColor.accentDeep)
                                    }
                                }
                                .padding(.horizontal, NumiSpacing.s4)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(NumiColor.surfaceCard)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("theme.\(theme.id)")
                            .accessibilityValue(isSelected ? "selected" : "unselected")

                            if index < NumiTheme.allCases.count - 1 {
                                Divider().padding(.leading, 54 + NumiSpacing.s3)
                            }
                        }
                    }
                    .background(NumiColor.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)

                    Text("切换后会同步更新基础控件、工具栏、输入面板和弹窗配色。")
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textTertiary)
                        .padding(.horizontal, NumiSpacing.s1)
                }
            }
            .padding(.horizontal, NumiSpacing.s5)
            .padding(.top, NumiSpacing.s4)
            .padding(.bottom, 120)
        }
        .background(NumiColor.surfacePage)
        .navigationTitle("主题")
        .modifier(LargeTitleNavigationChrome())
    }

    private func themeSwatch(_ theme: NumiTheme) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color(theme.primaryHex))
            Circle()
                .fill(color(theme.accentHex))
            Circle()
                .fill(color(theme.backgroundHex))
        }
        .frame(width: 54, height: 24)
    }

    private func description(for theme: NumiTheme) -> String {
        switch theme.id {
        case NumiTheme.brandWarm.id:
            return "暖杏主色、奶油底色和更柔和的工具栏强调色。"
        default:
            return "保留当前清爽浅色基调，适合作为默认工作主题。"
        }
    }

    private func color(_ hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else {
            return .clear
        }

        return Color(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }
}
