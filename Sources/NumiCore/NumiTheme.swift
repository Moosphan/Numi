import SwiftUI

// MARK: - Color Scheme Mode

public enum ColorSchemeMode: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return NumiLocalized.string( "theme.follow.system")
        case .light: return NumiLocalized.string( "theme.light")
        case .dark: return NumiLocalized.string( "theme.dark")
        }
    }

    public func resolve(systemScheme: ColorScheme) -> ColorScheme {
        switch self {
        case .system: return systemScheme
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Theme Palette

/// 单个配色方案的色值集合
public struct ThemePalette: Equatable, Sendable {
    public let primary: String
    public let background: String
    public let accent: String
    public let positive: String
    public let warning: String
    public let textPrimary: String

    public init(primary: String, background: String, accent: String, positive: String, warning: String, textPrimary: String) {
        self.primary = primary
        self.background = background
        self.accent = accent
        self.positive = positive
        self.warning = warning
        self.textPrimary = textPrimary
    }
}

// MARK: - Theme Protocol

/// 主题协议，每个主题只需提供 light/dark 两个 palette
public protocol AppTheme: Identifiable, Equatable, Sendable {
    var id: String { get }
    var displayName: String { get }
    var light: ThemePalette { get }
    var dark: ThemePalette { get }

    /// 根据当前 colorScheme 选择 palette
    func palette(for scheme: ColorScheme) -> ThemePalette
}

extension AppTheme {
    public func palette(for scheme: ColorScheme) -> ThemePalette {
        scheme == .dark ? dark : light
    }
}

// MARK: - Default Theme Implementation

public struct NumiTheme: AppTheme {
    public let id: String
    public let displayName: String
    public let light: ThemePalette
    public let dark: ThemePalette

    public var primaryHex: String { light.primary }
    public var backgroundHex: String { light.background }
    public var accentHex: String { light.accent }
    public var positiveHex: String { light.positive }
    public var warningHex: String { light.warning }
    public var textPrimaryHex: String { light.textPrimary }

    public init(id: String, displayName: String, light: ThemePalette, dark: ThemePalette) {
        self.id = id
        self.displayName = displayName
        self.light = light
        self.dark = dark
    }

    // MARK: - Built-in Themes

    public static var `default`: NumiTheme {
        NumiTheme(
            id: "default",
            displayName: NumiLocalized.string( "theme.default"),
            light: ThemePalette(
                primary: "#79D983",
                background: "#FBF9F3",
                accent: "#296956",
                positive: "#93C9A1",
                warning: "#D38A63",
                textPrimary: "#1E211F"
            ),
            dark: ThemePalette(
                primary: "#5CB86A",
                background: "#1A1D1B",
                accent: "#3D8B72",
                positive: "#6BAF7A",
                warning: "#D4956E",
                textPrimary: "#E8E8E8"
            )
        )
    }

    public static var defaultTheme: NumiTheme {
        .default
    }

    public static var brandWarm: NumiTheme {
        NumiTheme(
            id: "brandWarm",
            displayName: NumiLocalized.string( "theme.warm"),
            light: ThemePalette(
                primary: "#F0A050",
                background: "#FCF6EF",
                accent: "#C87A6E",
                positive: "#A8C3A2",
                warning: "#E08B5A",
                textPrimary: "#3D2C26"
            ),
            dark: ThemePalette(
                primary: "#E8963F",
                background: "#1E1B18",
                accent: "#D4887C",
                positive: "#8AAF85",
                warning: "#E09A6E",
                textPrimary: "#E8E0D8"
            )
        )
    }

    // MARK: - Registry

    public static var allCases: [NumiTheme] {
        [
            .default,
            .brandWarm
        ]
    }

    public static func theme(for id: String) -> NumiTheme {
        allCases.first(where: { $0.id == id }) ?? .default
    }
}
