import SwiftUI
import UIKit
import NumiCore
import NumiAppUI

@main
struct NumiApp: App {
    @AppStorage("app.theme.id") private var themeID = NumiTheme.default.id
    @AppStorage("app.colorSchemeMode") private var colorSchemeMode: ColorSchemeMode = .system

    init() {
        applyColorScheme(colorSchemeMode)
    }

    var body: some Scene {
        WindowGroup {
            NumiThemeScope(theme: NumiTheme.theme(for: themeID)) {
                RootShellView()
                    .onOpenURL { url in
                        NotificationCenter.default.post(
                            name: .init("NumiIncomingURL"),
                            object: url
                        )
                    }
            }
            .preferredColorScheme(colorSchemeMode.swiftUIScheme)
            .onChange(of: colorSchemeMode) { _, newValue in
                applyColorScheme(newValue)
            }
        }
    }

    /// 通过 UIKit 层设置外观，确保系统弹窗（Menu、confirmationDialog）也能适配
    private func applyColorScheme(_ mode: ColorSchemeMode) {
        DispatchQueue.main.async {
            let style: UIUserInterfaceStyle
            switch mode {
            case .system: style = .unspecified
            case .light: style = .light
            case .dark: style = .dark
            }
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .forEach { $0.overrideUserInterfaceStyle = style }
        }
    }
}

// MARK: - ColorSchemeMode Extension

extension ColorSchemeMode {
    var swiftUIScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
