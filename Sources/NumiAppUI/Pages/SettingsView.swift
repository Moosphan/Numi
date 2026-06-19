import SwiftUI
import NumiCore

public struct SettingsView: View {
    private let categories: [NumiCore.Category]
    private let accounts: [Account]
    private let onCategoryVisibilityChange: (NumiCore.Category, Bool) -> Void
    private let onAccountVisibilityChange: (Account, Bool) -> Void
    private let onAccountCreate: (AccountDraft) -> Void
    private let onAccountUpdate: (Account, AccountDraft) -> Void

    public init(
        categories: [NumiCore.Category] = [],
        accounts: [Account] = [],
        onCategoryVisibilityChange: @escaping (NumiCore.Category, Bool) -> Void = { _, _ in },
        onAccountVisibilityChange: @escaping (Account, Bool) -> Void = { _, _ in },
        onAccountCreate: @escaping (AccountDraft) -> Void = { _ in },
        onAccountUpdate: @escaping (Account, AccountDraft) -> Void = { _, _ in }
    ) {
        self.categories = categories
        self.accounts = accounts
        self.onCategoryVisibilityChange = onCategoryVisibilityChange
        self.onAccountVisibilityChange = onAccountVisibilityChange
        self.onAccountCreate = onAccountCreate
        self.onAccountUpdate = onAccountUpdate
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                settingsSection(
                    title: "数据",
                    accessibilityID: "settings.section.data",
                    cardAccessibilityID: "settings.card.data"
                ) {
                    NavigationLink {
                        CategoryManagementView(
                            categories: categories,
                            onVisibilityChange: onCategoryVisibilityChange
                        )
                    } label: {
                        settingsRow("分类管理", icon: "square.grid.2x2")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.categories")

                    NavigationLink {
                        AccountManagementView(
                            accounts: accounts,
                            onVisibilityChange: onAccountVisibilityChange,
                            onCreate: onAccountCreate,
                            onUpdate: onAccountUpdate
                        )
                    } label: {
                        settingsRow("账户管理", icon: "creditcard")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.accounts")

                    settingsRow("导入与导出", icon: "square.and.arrow.up")
                    settingsRow("本地备份", icon: "lock.doc")
                }

                settingsSection(
                    title: "安全",
                    accessibilityID: "settings.section.security",
                    cardAccessibilityID: "settings.card.security"
                ) {
                    settingsRow("隐私锁", icon: "faceid")
                    settingsRow("后台自动模糊", icon: "eye.slash")
                }

                settingsSection(
                    title: "外观",
                    accessibilityID: "settings.section.appearance",
                    cardAccessibilityID: "settings.card.appearance"
                ) {
                    NavigationLink {
                        ThemeSelectionView()
                    } label: {
                        settingsRow("主题", icon: "paintpalette")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.theme")
                }
            }
            .padding(.horizontal, NumiSpacing.s5)
            .padding(.top, NumiSpacing.s4)
            .padding(.bottom, 120)
        }
        .background(NumiColor.surfacePage)
        .navigationTitle("我的")
        .modifier(LargeTitleNavigationChrome())
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        accessibilityID: String,
        cardAccessibilityID: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(NumiColor.textSecondary)
                .accessibilityIdentifier(accessibilityID)

            VStack(spacing: 0) {
                content()
            }
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(NumiColor.separator, lineWidth: 1)
            }
            .accessibilityIdentifier(cardAccessibilityID)
        }
    }

    private func settingsRow(_ title: String, icon: String) -> some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(NumiColor.surfaceCardSubtle)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                .foregroundStyle(NumiColor.toolbarIcon)

            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(NumiColor.textPrimary)

            Spacer(minLength: NumiSpacing.s3)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NumiColor.textTertiary)
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NumiColor.surfaceCard)
    }
}

struct LargeTitleNavigationChrome: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        content.navigationBarTitleDisplayMode(.large)
        #else
        content
        #endif
    }
}
