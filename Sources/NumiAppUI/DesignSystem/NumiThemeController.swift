import SwiftUI
import NumiCore

// MARK: - Theme Controller

public final class NumiThemeController: ObservableObject {
    public static let shared = NumiThemeController()

    @Published public private(set) var theme: NumiTheme
    @Published public private(set) var colorScheme: ColorScheme = .light

    private init(initialTheme: NumiTheme = .default) {
        theme = initialTheme
    }

    public func apply(theme: NumiTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
    }

    public func updateColorScheme(_ scheme: ColorScheme) {
        guard self.colorScheme != scheme else { return }
        self.colorScheme = scheme
    }

    /// 当前生效的 palette
    public var currentPalette: ThemePalette {
        theme.palette(for: colorScheme)
    }
}

// MARK: - Theme Scope

public struct NumiThemeScope<Content: View>: View {
    @ObservedObject private var controller = NumiThemeController.shared
    @AppStorage("app.colorSchemeMode") private var colorSchemeMode: ColorSchemeMode = .system
    @Environment(\.colorScheme) private var systemColorScheme

    private let theme: NumiTheme
    private let content: () -> Content

    public init(theme: NumiTheme, @ViewBuilder content: @escaping () -> Content) {
        self.theme = theme
        self.content = content
    }

    public var body: some View {
        let resolvedScheme = colorSchemeMode.resolve(systemScheme: systemColorScheme)

        content()
            .environmentObject(controller)
            .tint(NumiColor.accentDeep)
            .overlay(alignment: .topLeading) {
                Text(controller.theme.id)
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .accessibilityIdentifier("app.theme.active")
            }
            .onAppear {
                controller.apply(theme: theme)
                controller.updateColorScheme(resolvedScheme)
            }
            .onChange(of: theme.id) { _, _ in
                controller.apply(theme: theme)
            }
            .onChange(of: systemColorScheme) { _, newValue in
                controller.updateColorScheme(colorSchemeMode.resolve(systemScheme: newValue))
            }
            .onChange(of: colorSchemeMode) { _, _ in
                controller.updateColorScheme(colorSchemeMode.resolve(systemScheme: systemColorScheme))
            }
    }
}
