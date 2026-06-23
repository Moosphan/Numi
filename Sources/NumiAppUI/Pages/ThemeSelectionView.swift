import SwiftUI
import NumiCore

public struct ThemeSelectionView: View {
    @AppStorage("app.theme.id") private var themeID = NumiTheme.default.id
    @AppStorage("app.colorSchemeMode") private var colorSchemeMode: ColorSchemeMode = .system
    @ObservedObject private var themeController = NumiThemeController.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                // 外观模式
                appearanceSection

                // 主题列表
                themeSection
            }
            .padding(.horizontal, NumiSpacing.s5)
            .padding(.top, NumiSpacing.s4)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("scroll.themeSelection")
        .background(NumiColor.surfacePage)
        .numiBottomAccessoryVisibility(true)
        .navigationTitle("主题")
        .modifier(LargeTitleNavigationChrome())
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s2) {
            Text("外观模式")
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)

            HStack(spacing: 0) {
                ForEach(ColorSchemeMode.allCases) { mode in
                    let isSelected = colorSchemeMode == mode
                    Button {
                        colorSchemeMode = mode
                    } label: {
                        HStack(spacing: NumiSpacing.s1) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 14, weight: .medium))
                            Text(mode.displayName)
                                .font(isSelected ? NumiFont.bodyStrong : NumiFont.body)
                        }
                        .foregroundStyle(isSelected ? .white : NumiColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(NumiColor.accentDeep)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(NumiColor.surfaceCard)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text("主题风格")
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)

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

    // MARK: - Helpers

    private func themeSwatch(_ theme: NumiTheme) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color(theme.light.primary))
            Circle()
                .fill(color(theme.light.accent))
            Circle()
                .fill(color(theme.light.background))
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

// MARK: - ColorSchemeMode Icon Extension

extension ColorSchemeMode {
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}
