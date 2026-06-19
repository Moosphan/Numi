import SwiftUI
import NumiCore

public final class NumiThemeController: ObservableObject {
    public static let shared = NumiThemeController()

    @Published public private(set) var theme: NumiTheme

    private init(initialTheme: NumiTheme = .defaultTheme) {
        theme = initialTheme
    }

    public func apply(theme: NumiTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
    }
}

public struct NumiThemeScope<Content: View>: View {
    @ObservedObject private var controller = NumiThemeController.shared
    private let theme: NumiTheme
    private let content: () -> Content

    public init(theme: NumiTheme, @ViewBuilder content: @escaping () -> Content) {
        self.theme = theme
        self.content = content
    }

    public var body: some View {
        let _ = controller.theme.id
        content()
            .environmentObject(NumiThemeController.shared)
            .tint(NumiColor.accentDeep)
            .overlay(alignment: .topLeading) {
                Text(controller.theme.id)
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .accessibilityIdentifier("app.theme.active")
            }
            .onAppear {
                NumiThemeController.shared.apply(theme: theme)
            }
            .onChange(of: theme.id) { _, _ in
                NumiThemeController.shared.apply(theme: theme)
            }
    }
}
