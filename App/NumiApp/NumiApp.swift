import SwiftUI
import UIKit
import NumiCore
import NumiAppUI

@main
struct NumiApp: App {
    @AppStorage("app.theme.id") private var themeID = NumiTheme.default.id
    @AppStorage("app.colorSchemeMode") private var colorSchemeMode: ColorSchemeMode = .system
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appearanceBridge = UIKitAppearanceBridge()

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
            .task {
                appearanceBridge.start()
                applyColorScheme(colorSchemeMode)
            }
            .onChange(of: colorSchemeMode) { _, newValue in
                applyColorScheme(newValue)
            }
            .onChange(of: scenePhase) { _, _ in
                applyColorScheme(colorSchemeMode)
            }
        }
    }

    /// 通过 UIKit 层设置外观，确保系统弹窗（Menu、confirmationDialog）也能适配
    private func applyColorScheme(_ mode: ColorSchemeMode) {
        DispatchQueue.main.async {
            let style = mode.uiKitStyle
            appearanceBridge.apply(style: style)
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .forEach { $0.overrideUserInterfaceStyle = style }
        }
    }
}

@MainActor
private final class UIKitAppearanceBridge: ObservableObject {
    private var isStarted = false
    private var observers: [NSObjectProtocol] = []
    private var currentStyle: UIUserInterfaceStyle = .unspecified

    func start() {
        guard !isStarted else { return }
        isStarted = true

        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: UIWindow.didBecomeVisibleNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard
                    let self,
                    let window = notification.object as? UIWindow
                else { return }

                window.overrideUserInterfaceStyle = self.currentStyle
            }
        )
    }

    func apply(style: UIUserInterfaceStyle) {
        currentStyle = style
    }

    deinit {
        let center = NotificationCenter.default
        observers.forEach(center.removeObserver)
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

    var uiKitStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}
