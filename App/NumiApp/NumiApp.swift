import SwiftUI
import NumiCore
import NumiAppUI

@main
struct NumiApp: App {
    @AppStorage("app.theme.id") private var themeID = NumiTheme.defaultTheme.id

    var body: some Scene {
        WindowGroup {
            NumiThemeScope(theme: NumiTheme.theme(for: themeID)) {
                RootShellView()
                    .onOpenURL { url in
                        // URL Scheme: numi://record?text=xxx
                        NotificationCenter.default.post(
                            name: .init("NumiIncomingURL"),
                            object: url
                        )
                    }
            }
        }
    }
}
