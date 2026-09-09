import SwiftUI
import NumiCore

public enum SettingsCategory: String, CaseIterable, Identifiable {
    case featureExtensions
    case dataManagement
    case appearance
    case security
    case notifications
    case aiLab

    public var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .featureExtensions: "setting.category.featureExtensions"
        case .dataManagement: "setting.category.dataManagement"
        case .appearance: "setting.category.appearance"
        case .security: "setting.category.security"
        case .notifications: "setting.category.notifications"
        case .aiLab: "setting.category.aiLab"
        }
    }

    var summaryKey: String {
        switch self {
        case .featureExtensions: "setting.category.featureExtensions.summary"
        case .dataManagement: "setting.category.dataManagement.summary"
        case .appearance: "setting.category.appearance.summary"
        case .security: "setting.category.security.summary"
        case .notifications: "setting.category.notifications.summary"
        case .aiLab: "setting.category.aiLab.summary"
        }
    }

    var iconName: String {
        switch self {
        case .featureExtensions: "puzzlepiece.extension"
        case .dataManagement: "externaldrive"
        case .appearance: "paintpalette"
        case .security: "lock.shield"
        case .notifications: "bell.badge"
        case .aiLab: "sparkles"
        }
    }
}

public struct SettingsCategoryCard: View {
    @ObservedObject private var themeController = NumiThemeController.shared
    let category: SettingsCategory

    public init(category: SettingsCategory) {
        self.category = category
    }

    public var body: some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: category.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(NumiColor.accentPrimary)
                .frame(width: 36, height: 36)
                .background(NumiColor.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(NumiLocalized.string(category.titleKey))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NumiColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(NumiLocalized.string(category.summaryKey))
                    .font(NumiFont.caption)
                    .foregroundStyle(NumiColor.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: NumiSpacing.s3)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NumiColor.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, NumiSpacing.s2)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        .contentShape(Rectangle())
    }
}

public struct SettingsCategoryPage<Content: View>: View {
    @ObservedObject private var themeController = NumiThemeController.shared
    private let category: SettingsCategory
    private let content: Content

    public init(category: SettingsCategory, @ViewBuilder content: () -> Content) {
        self.category = category
        self.content = content()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s3) {
                Text(NumiLocalized.string(category.summaryKey))
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.textSecondary)
                    .padding(.horizontal, NumiSpacing.s1)

                VStack(spacing: 0) { content }
                    .background(NumiColor.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
                    .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
            }
            .padding(NumiSpacing.s5)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(NumiColor.surfacePage)
        .navigationTitle(NumiLocalized.string(category.titleKey))
        .modifier(LargeTitleNavigationChrome())
        .accessibilityIdentifier("scroll.settingsCategory.\(category.rawValue)")
    }
}

public struct PlanSettingsView: View {
    @ObservedObject private var themeController = NumiThemeController.shared
    @AppStorage("plans.forecast.horizon.days") private var forecastHorizonDays = PlanForecastHorizon.thirtyDays.rawValue
    @AppStorage("app.subscription.requiresConfirmation") private var requiresSubscriptionConfirmation = false

    public static let preferenceKeys = (
        forecastHorizon: "plans.forecast.horizon.days",
        subscriptionConfirmation: "app.subscription.requiresConfirmation"
    )

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                settingGroup(title: NumiLocalized.string("setting.category.planSettings.preview")) {
                    Picker(NumiLocalized.string("plans.forecast.horizon"), selection: $forecastHorizonDays) {
                        ForEach(PlanForecastHorizon.allCases) { horizon in
                            Text(NumiLocalized.string("plans.forecast.horizon.\(horizon.rawValue)"))
                                .tag(horizon.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settings.planSettings.forecastHorizon")
                }

                settingGroup(title: NumiLocalized.string("setting.category.planSettings.subscription")) {
                    Toggle(isOn: $requiresSubscriptionConfirmation) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NumiLocalized.string("subscription.confirmation.mode"))
                                .font(NumiFont.bodyStrong)
                                .foregroundStyle(NumiColor.textPrimary)
                            Text(NumiLocalized.string("subscription.confirmation.mode.detail"))
                                .font(NumiFont.caption)
                                .foregroundStyle(NumiColor.textSecondary)
                        }
                    }
                    .tint(NumiColor.accentDeep)
                    .accessibilityIdentifier("settings.planSettings.subscriptionConfirmation")
                }
            }
            .padding(NumiSpacing.s5)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(NumiColor.surfacePage)
        .navigationTitle(NumiLocalized.string("setting.category.planSettings"))
        .modifier(LargeTitleNavigationChrome())
        .accessibilityIdentifier("scroll.settingsPlanSettings")
    }

    @ViewBuilder
    private func settingGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text(title)
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)
            VStack { content() }
                .padding(NumiSpacing.s4)
                .background(NumiColor.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        }
    }
}
